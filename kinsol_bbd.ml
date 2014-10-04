(***********************************************************************)
(*                                                                     *)
(*                   OCaml interface to Sundials                       *)
(*                                                                     *)
(*  Timothy Bourke (Inria), Jun Inoue (Inria), and Marc Pouzet (LIENS) *)
(*                                                                     *)
(*  Copyright 2014 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under a BSD 2-Clause License, refer to the file LICENSE.           *)
(*                                                                     *)
(***********************************************************************)

include Kinsol_impl
include KinsolBbdTypes

type data = Nvector_parallel.data
type kind = Nvector_parallel.kind
type parallel_session = (data, kind) session
type parallel_linear_solver = (data, kind) linear_solver

module Impl = KinsolBbdParamTypes
type local_fn = data Impl.local_fn
type comm_fn = data Impl.comm_fn
type callbacks =
  {
    local_fn : local_fn;
    comm_fn  : comm_fn option;
  }

let bbd_callbacks { local_fn; comm_fn } =
  { Impl.local_fn = local_fn; Impl.comm_fn = comm_fn }

let call_bbdlocal session u gval =
  let session = read_weak_ref session in
  match session.ls_callbacks with
  | BBDCallback { Impl.local_fn = f } ->
      adjust_retcode session true (f u) gval
  | _ -> assert false

let call_bbdcomm session u =
  let session = read_weak_ref session in
  match session.ls_callbacks with
  | BBDCallback { Impl.comm_fn = Some f } -> adjust_retcode session true f u
  | _ -> assert false

external c_bbd_prec_init
    : parallel_session -> int -> bandwidths -> float -> bool -> unit
    = "c_kinsol_bbd_prec_init"

external c_set_max_restarts : ('a, 'k) session -> int -> unit
    = "c_kinsol_spils_set_max_restarts"

external c_spils_spgmr : ('a, 'k) session -> int -> unit
  = "c_kinsol_spils_spgmr"

external c_spils_spbcg : ('a, 'k) session -> int -> unit
  = "c_kinsol_spils_spbcg"

external c_spils_sptfqmr : ('a, 'k) session -> int -> unit
  = "c_kinsol_spils_sptfqmr"

let spgmr ?(maxl=0) ?max_restarts ?(dqrely=0.0) bws cb session onv =
  let localn =
    match onv with
      None -> 0
    | Some nv -> let ba, _, _ = Nvector.unwrap nv in
                 Sundials.RealArray.length ba
  in
  c_spils_spgmr session maxl;
  (match max_restarts with
   | Some m -> c_set_max_restarts session m
   | None -> ());
  c_bbd_prec_init session localn bws dqrely (cb.comm_fn <> None);
  session.ls_callbacks <- BBDCallback (bbd_callbacks cb)

let spbcg ?(maxl=0) ?(dqrely=0.0) bws cb session onv =
  let localn =
    match onv with
      None -> 0
    | Some nv -> let ba, _, _ = Nvector.unwrap nv in
                 Sundials.RealArray.length ba
  in
  c_spils_spbcg session maxl;
  c_bbd_prec_init session localn bws dqrely (cb.comm_fn <> None);
  session.ls_callbacks <- BBDCallback (bbd_callbacks cb)

let sptfqmr ?(maxl=0) ?(dqrely=0.0) bws cb session onv =
  let localn =
    match onv with
      None -> 0
    | Some nv -> let ba, _, _ = Nvector.unwrap nv in
                 Sundials.RealArray.length ba
  in
  c_spils_sptfqmr session maxl;
  c_bbd_prec_init session localn bws dqrely (cb.comm_fn <> None);
  session.ls_callbacks <- BBDCallback (bbd_callbacks cb)

external get_work_space : parallel_session -> int * int
    = "c_kinsol_bbd_get_work_space"

external get_num_gfn_evals : parallel_session -> int
    = "c_kinsol_bbd_get_num_gfn_evals"

(* Let C code know about some of the values in this module.  *)
type fcn = Fcn : 'a -> fcn
external c_init_module : fcn array -> unit =
  "c_kinsol_bbd_init_module"

let _ =
  c_init_module
    (* Functions must be listed in the same order as
       callback_index in kinsol_bbd_ml.c.  *)
    [|Fcn call_bbdlocal;
      Fcn call_bbdcomm;
    |]
