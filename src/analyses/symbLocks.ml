(** Symbolic lock-sets for use in per-element patterns. *)

module LF = LibraryFunctions
module LP = Exp.LockingPattern
module Exp = Exp.Exp
module VarEq = VarEq.Spec

module PS = SetDomain.ToppedSet (LP) (struct let topname = "All" end)

open Prelude.Ana
open Analyses

(* Note: This is currently more conservative than varEq --- but
   it should suffice for tests. *)
module Spec =
struct
  include Analyses.DefaultSpec

  exception Top

  module D = LockDomain.Symbolic
  module C = LockDomain.Symbolic
  module G = Lattice.Unit

  let name () = "symb_locks"

  let startstate v = D.top ()
  let threadenter ctx lval f args = [D.top ()]
  let threadspawn ctx lval f args fctx = ctx.local
  let exitstate  v = D.top ()

  let branch ctx exp tv = ctx.local
  let body   ctx f = ctx.local

  let invalidate_exp ask exp st =
    D.filter (fun e -> not (VarEq.may_change ask exp e)) st

  let invalidate_lval ask lv st =
    invalidate_exp ask (mkAddrOf lv) st

  let assign ctx lval rval = invalidate_lval (Analyses.ask_of_ctx ctx) lval ctx.local

  let return ctx exp fundec =
    List.fold_right D.remove_var (fundec.sformals@fundec.slocals) ctx.local

  let enter ctx lval f args = [(ctx.local,ctx.local)]
  let combine ctx lval fexp f args fc st2 = ctx.local

  let get_locks e st =
    let add_perel x xs =
      match LP.from_exps e x with
      | Some x -> PS.add x xs
      | None -> xs
    in
    D.fold add_perel st (PS.empty ())

  let get_all_locks (ask: Queries.ask) e st : PS.t =
    let exps =
      match ask.f (Queries.EqualSet e) with
      | a when not (Queries.ES.is_bot a) -> Queries.ES.add e a
      | _ -> Queries.ES.singleton e
    in
    let add_locks x xs = PS.union (get_locks x st) xs in
    Queries.ES.fold add_locks exps (PS.empty ())

  let same_unknown_index (ask: Queries.ask) exp slocks =
    let uk_index_equal i1 i2 = ask.f (Queries.MustBeEqual (i1, i2)) in
    let lock_index ei ee x xs =
      match Exp.one_unknown_array_index x with
      | Some (true, i, e) when uk_index_equal ei i ->
        PS.add (zero, ee, e) xs
      | _ -> xs
    in
    match Exp.one_unknown_array_index exp with
    | Some (_, i, e) -> D.fold (lock_index i e) slocks (PS.empty ())
    | _ -> PS.empty ()

  let special ctx lval f arglist =
    match LF.classify f.vname arglist with
    | `Lock _ ->
      D.add (Analyses.ask_of_ctx ctx) (List.hd arglist) ctx.local
    | `Unlock ->
      D.remove (Analyses.ask_of_ctx ctx) (List.hd arglist) ctx.local
    | `Unknown fn when VarEq.safe_fn fn ->
      Messages.warn ("Assume that "^fn^" does not change lockset.");
      ctx.local
    | `Unknown x -> begin
        let st =
          match lval with
          | Some lv -> invalidate_lval (Analyses.ask_of_ctx ctx) lv ctx.local
          | None -> ctx.local
        in
        let write_args =
          match LF.get_invalidate_action f.vname with
          | Some fnc -> fnc `Write arglist
          | _ -> arglist
        in
        List.fold_left (fun st e -> invalidate_exp (Analyses.ask_of_ctx ctx) e st) st write_args
      end
    | _ ->
      ctx.local

  module ExpSet = BatSet.Make (Exp)
  let type_inv_tbl = Hashtbl.create 13
  let type_inv (c:compinfo) : Lval.CilLval.t list =
    try [Hashtbl.find type_inv_tbl c,`NoOffset]
    with Not_found ->
      let i = Goblintutil.create_var (makeGlobalVar ("(struct "^c.cname^")") (TComp (c,[]))) in
      Hashtbl.add type_inv_tbl c i;
      [i, `NoOffset]

  let rec conv_const_offset x =
    match x with
    | NoOffset    -> `NoOffset

    | Index (Const  (CInt64 (i,ikind,s)),o) -> `Index (IntDomain.of_const (i,ikind,s), conv_const_offset o)
    | Index (_,o) -> `Index (ValueDomain.IndexDomain.top (), conv_const_offset o)
    | Field (f,o) -> `Field (f, conv_const_offset o)

  let one_perelem ask (e,a,l) es =
    (* Type invariant variables. *)
    let b_comp = Exp.base_compinfo e a in
    let f es (v,o) =
      match Exp.fold_offs (Exp.replace_base (v,o) e l) with
      | Some (v,o) -> ExpSet.add (Lval (Var v,o)) es
      | None -> es
    in
    match b_comp with
    | Some ci -> List.fold_left f es (type_inv ci)
    | None -> es

  let one_lockstep (_,a,m) ust =
    let rec conv_const_offset x =
      match x with
      | NoOffset    -> `NoOffset
      | Index (Const  (CInt64 (i,ikind,s)),o) -> `Index (IntDomain.of_const (i,ikind,s), conv_const_offset o)
      | Index (_,o) -> `Index (ValueDomain.IndexDomain.top (), conv_const_offset o)
      | Field (f,o) -> `Field (f, conv_const_offset o)
    in
    match m with
    | AddrOf (Var v,o) ->
      LockDomain.Lockset.add (ValueDomain.Addr.from_var_offset (v, conv_const_offset o),true) ust
    | _ ->
      ust

  let add_per_element_access ctx e rw =
    let module LSSet = Access.LSSet in
    (* Per-element returns a triple of exps, first are the "element" pointers,
       in the second and third positions are the respectively access and mutex.
       Access and mutex expressions have exactly the given "elements" as "prefixes".

       To know if a access-mutex pair matches our per-element pattern we listify
       the offset (adding dereferencing to our special offset type). Then we take
       the longest common prefix till a dereference and check if the rest is "concrete".
    *)
    let one_perelem (e,a,l) xs =
      (* ignore (printf "one_perelem (%a,%a,%a)\n" Exp.pretty e Exp.pretty a Exp.pretty l); *)
      match Exp.fold_offs (Exp.replace_base (dummyFunDec.svar,`NoOffset) e l) with
      | Some (v, o) ->
        let l = Pretty.sprint 80 (d_offset (text "*") () o) in
        (* ignore (printf "adding lock %s\n" l); *)
        LSSet.add ("p-lock",l) xs
      | None -> xs
    in
    (* Array lockstep also returns a triple of exps. Second and third elements in
       triples are access and mutex exps. Common index is replaced with *.
       First element is unused.

       To find if this pattern matches, we try to separate the base variable and
       the index from both -- access exp and mutex exp. We check if indexes match
       and the rest is concrete. Then replace the common index with *. *)
    let one_lockstep (_,a,m) xs =
      match m with
      | AddrOf (Var v,o) ->
        let lock = ValueDomain.Addr.from_var_offset (v, conv_const_offset o) in
        LSSet.add ("i-lock",ValueDomain.Addr.show lock) xs
      | _ ->
        Messages.warn "Internal error: found a strange lockstep pattern.";
        xs
    in
    let do_perel e xs =
      match get_all_locks (Analyses.ask_of_ctx ctx) e ctx.local with
      | a
        when not (PS.is_top a || PS.is_empty a)
        -> PS.fold one_perelem a xs
      | _ -> xs
    in
    let do_lockstep e xs =
      match same_unknown_index (Analyses.ask_of_ctx ctx) e ctx.local with
      | a
        when not (PS.is_top a || PS.is_empty a)
        -> PS.fold one_lockstep a xs
      | _ -> xs
    in
    let matching_exps =
      Queries.ES.meet
        (match ctx.ask (Queries.EqualSet e) with
         | es when not (Queries.ES.is_top es || Queries.ES.is_empty es)
           -> Queries.ES.add e es
         | _ -> Queries.ES.singleton e)
        (match ctx.ask (Queries.Regions e) with
         | ls when not (Queries.LS.is_top ls || Queries.LS.is_empty ls)
           -> let add_exp x xs =
                try Queries.ES.add (Lval.CilLval.to_exp x) xs
                with Lattice.BotValue -> xs
           in begin
             try Queries.LS.fold add_exp ls (Queries.ES.singleton e)
             with Lattice.TopValue -> Queries.ES.top () end
         | _ -> Queries.ES.singleton e)
    in
    Queries.ES.fold do_lockstep matching_exps
      (Queries.ES.fold do_perel matching_exps (LSSet.empty ()))

  let part_access ctx e v _ =
    let open Access in
    let ls = add_per_element_access ctx e false in
    (* ignore (printf "bla %a %a = %a\n" d_exp e D.pretty ctx.local LSSet.pretty ls); *)
    (LSSSet.singleton (LSSet.empty ()), ls)

  let query ctx (type a) (q: a Queries.t): a Queries.result =
    match q with
    | Queries.PartAccess {exp; var_opt; write} ->
      part_access ctx exp var_opt write
    | _ -> Queries.Result.top q
end

let _ =
  MCP.register_analysis (module Spec : MCPSpec)
