# SAS '21 Artifact Description

The artifact is a VirtualBox Image based on Ubuntu 20.04.1. The login is `goblint:goblint`.

## Validation

### Step by Step Instructions
Navigate to the folder `~/analyzer`. All paths are given relative to it.

1. Run the script `../bench/update_bench_traces.rb`. This takes ~25 min (see note below).
2. Open the results HTML `../bench/bench_result/index.html`.
3. Validate results with the paper:
    1. The table cells give analysis time in seconds for each benchmark (along the left) and each analysis (along the top). These are illustrated by Figure 2 in the paper.

        The mapping between analysis names in the paper and in the results is given by the following table:

        | Name in paper    | Name in results |
        | ---------------- | --------------- |
        | Protection-Based | `protection`    |
        | Miné             | `mine-W`        |
        | Lock-Centered    | `lock`          |
        | Write-Centered   | `write`         |
        | Combined         | `write+lock`    |

    2. The last column of the table links to the automatic pairwise precision comparison output of the analyses for each benchmark. These are described in Section 5 in the paper.

        For example, consider the following comparison output:

            pfscan_comb.c:1269 pqb: protection more precise than mine-W
              protection: [FULL OUTPUT OMITTED HERE]
              more precise than
              mine-W: [FULL OUTPUT OMITTED HERE]
              reverse diff: {Map: occupied =
                            (Unknown int([-31,31]),not {} ([-31,31])) instead of (Not {0}([-31,31]),not {} ([-31,31])) ...}

        This means that in `pfscan_comb.c` on line 1269 for the global variable `pqb` Protection-Based reads a more precise value than Miné.
        Skipping over the full output of the struct in both cases, the "reverse diff" line highlights the difference:
        for the field `occupied` Protection-Based can exclude the value 0 (indicated by `Not {0}`) while Miné cannot (indicated by `Unknown int`).

    3. The last number (after `=`) in parenthesis in the table cells gives the logical LoC. These are mentioned in Section 5 in the paper.

        The column "Size" of the table only gives physical LoC, which includes excessive struct and extern function declarations.


### Notes
* The source code for benchmarks can be found in `../bench/pthread/` and `../bench/svcomp/`.
* Although it takes ~25 min to run all the benchmarks, the script continually updates the results HTML. Therefore it's possible to observe the first results in the partially-filled table without having to wait for the script to finish.
* If you get messages such as `dune: command not found` run `eval $(opam env)`


## Extension

**Goblint is a general framework for Abstract Interpretation and has been used to implement a wide variety of analyses. For extending Goblint with some entirely different analysis,
one can use `./src/analyses/constants.ml` as a jumping-off point showing how to specify an analysis in the framework.**

The following description is specifically about extending one of the thread-modular analyses presented in the paper at hand.

### Implementation of Analyses in the Paper
The OCaml source code for the core of the analyses is found in `./src/analyses/basePriv.ml`.
Each one is an appropriately-named module, e.g. `ProtectionBasedPriv`, with the following members:

* The inner module `D` defines the domain of any analysis-specific additions to the local state on top of the σ component. (e.g., for Write-Centered Reading, this would be the `P` and `W` components of the local state).
 The rest of the implementation uses `st.priv` to access the `D` components and `st.cpa` to access the σ component of the local state.
* The inner module `G` defines the global domain: In contrast to the paper, there is only one constraint system unknown per global in the implementation.
 Hence, for example for Protection-Based Reading, the global constraint system unknowns [g] and [g]' in the paper are implemented by a pair of abstract values stored at the constraint system unknown [g].
* The function `startstate` defines "init" for `D`.
* The functions `read_global` and `write_global` define "x = g" and "g = x", respectively. These implicitly include the surrounding "lock(m_g)" and "unlock(m_g)".
* The functions `lock` and `unlock` define "lock(a)" and "unlock(a)" for (a != m_g), respectively.
* The function `threadenter` defines the side-effected initial state for u_1 in "x = create(u_1)".
* The remaining functions `enter_multithreaded`, `escape` and `sync` implement other Goblint features necessary to soundly analyze real-world C programs.

Besides the five analyses presented in the paper, the `basePriv.ml` file already contains a handful of other experimental implementations, showing that the framework and its thread-modularity is extensible
and a wide range of ideas can be expressed in this setting.

Any of the modules in `basePriv.ml` can then be passed to the functor `MainFunctor` in `base.ml`. This base analysis then uses the functions described above to handle accesses to global variables as well as locking
and unlocking. This provides a separation of concerns, making it possible to prototype new analyses such as the ones
presented in the paper quickly.

### Step by Step Instructions to Extending these Analyses

1. Modify or add thread-modular analyses in `./src/analyses/basePriv.ml`. (In case of addition also add to a case distinction in `priv_module` at the end of this file.)
2. Run `make` and `make privPrecCompare`.
3. Observe updated behavior, either:
    * Re-run the benchmarking as described above under Validation.

        or

    * Run the script `./scripts/privPrecCompare.sh --conf conf/traces.json ../bench/pthread/ypbind_comb.c` to run the analyses and their comparison on a single C program with the Goblint configuration file used for this evaluation.

        or

    * Run some of the regression tests in `tests/regression/13-privatized` by calling `./regtest.sh 13 xx` where `xx` is the number of the test. Especially `xx > 16` are interesting, these were added with the paper and highlight
      differences between different approaches. Use the `--sets exp.privatization chosenname` option to choose which thread-modular analysis to use.

### Outline of how the code is structured
Lastly, we give a general outline of how code in the Goblint framework is organized:
The source code is in the directory `./src`, where the subdirectories are structured as follows:

The most relevant directories are:

- `./src/solvers`: Different fix-point solvers that can be used by Goblint (default is TD3)
- `./src/domains`: Various generic abstract domains: Sets, Maps, ...
- `./src/cdomains`: Abstract domains for C programs (e.g. Integers, Addresses, ...)
- `./src/analyses`: Different analyses supported by Goblint
- `./src/framework`: The code of the analysis framework

Other, not directly relevant, directories:

- `./src/extract`: Related to extracting Promela models from C code
- `./src/incremental`: Related to Incremental Analysis
- `./src/spec`: Related to parsing Specifications for an automata-based analysis of liveness properties
- `./src/transform`: Specify transformations to run based on the analysis results
- `./src/util`: Various utility modules
- `./src/witness`: Related to witness generation
