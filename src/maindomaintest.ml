open! Defaults (* Enums / ... need initialized conf *)

module type FiniteSetElems =
sig
  type t
  val elems: t list
end

module FiniteSet (E:Printable.S) (Elems:FiniteSetElems with type t = E.t) =
struct
  module E =
  struct
    include E
    let arbitrary () = QCheck.oneofl Elems.elems
  end

  include SetDomain.Make (E)
  let top () = of_list Elems.elems
  let is_top x = equal x (top ())
end

module PrintableChar =
struct
  type t = char [@@deriving eq, to_yojson]
  let name () = "char"
  let show x = String.make 1 x

  module P =
  struct
    type t' = t
    let name = name
    let show = show
  end
  include Printable.StdPolyCompare
  include Printable.PrintSimple (P)

  let hash = Char.code
end

module ArbitraryLattice = FiniteSet (PrintableChar) (
  struct
    type t = char
    let elems = ['a'; 'b'; 'c'; 'd']
  end
)

module HoareArbitrary = HoareDomain.Set_LiftTop (ArbitraryLattice) (struct let topname = "Top" end)
module HoareArbitrary_NoTop = HoareDomain.Set (ArbitraryLattice)

let domains: (module Lattice.S) list = [
  (* (module IntDomainProperties.IntegerSet); (* TODO: top properties error *) *)
  (module IntDomain.Lifted); (* not abstraction of IntegerSet *)

  (* TODO: move to intDomains if passing *)
  (module IntDomain.Booleans);

  (* TODO: fix *)
  (* (module IntDomain.Enums); *)
  (* (module IntDomain.IntDomTuple); *)

  (module ArbitraryLattice);
  (module HoareArbitrary);
  (module HoareArbitrary_NoTop);
  (module HoareDomain.MapBot (ArbitraryLattice) (HoareArbitrary));
  (module HoareDomain.MapBot (ArbitraryLattice) (HoareArbitrary_NoTop));
]

let nonAssocDomains: (module Lattice.S) list = []

let intDomains: (module IntDomainProperties.S) list = [
  (module IntDomain.Interval);
  (module IntDomain.Enums);
  (* (module IntDomain.Flattened); *)
  (* (module IntDomain.Interval32); *)
  (* (module IntDomain.Booleans); *)
  (* (module IntDomain.IntDomTuple); *)
]

let nonAssocIntDomains: (module IntDomainProperties.S) list = [
  (module IntDomain.DefExc);
]

(* TODO: make arbitrary ikind part of domain test for better efficiency *)
let ikinds: Cil.ikind list = [
  (* TODO: enable more, some seem to break things *)
  IChar;
  ISChar;
  (* IUChar; *)
  (* IBool; *)
  IInt;
  (* IUInt; *)
  IShort;
  (* IUShort; *)
  (* ILong; *)
  (* IULong; *)
  (* ILongLong; *)
  (* IULongLong; *)
]

let testsuite =
  domains
  |> List.map (fun d ->
      let module D = (val d: Lattice.S) in
      let module DP = DomainProperties.All (D) in
      DP.tests
    )
  |> List.flatten
let nonAssocTestsuite =
  nonAssocDomains
  |> List.map (fun d ->
      let module D = (val d: Lattice.S) in
      let module DP = DomainProperties.AllNonAssoc (D) in
      DP.tests
    )
  |> List.flatten

let old_intdomains intDomains =
  BatList.cartesian_product intDomains ikinds
  |> List.map (fun (d, ik) ->
      let module D = (val d: IntDomainProperties.S) in
      let module Ikind = struct let ikind () = ik end in
      (module IntDomainProperties.WithIkind (D) (Ikind): IntDomainProperties.OldS)
    )
let intTestsuite =
  old_intdomains intDomains
  |> List.map (fun d ->
      let module D = (val d: IntDomainProperties.OldS) in
      let module DP = IntDomainProperties.All (D) in
      DP.tests
    )
  |> List.flatten
let nonAssocIntTestsuite =
  old_intdomains nonAssocIntDomains
  |> List.map (fun d ->
      let module D = (val d: IntDomainProperties.OldS) in
      let module DP = IntDomainProperties.AllNonAssoc (D) in
      DP.tests
    )
  |> List.flatten
let () =
  QCheck_base_runner.run_tests_main ~argv:Sys.argv (testsuite @ nonAssocTestsuite @ intTestsuite @ nonAssocIntTestsuite)
