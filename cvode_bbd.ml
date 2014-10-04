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

include Cvode_impl
include CvodeBbdTypes

(* These types can't be defined in Cvode_impl because they introduce
   dependence on Mpi.  Some duplication is unavoidable.  *)
type data = Nvector_parallel.data
type kind = Nvector_parallel.kind

type parallel_session = (data, kind) session
type parallel_preconditioner = (data, kind) Cvode.Spils.preconditioner

module Impl = CvodeBbdParamTypes
type local_fn = data Impl.local_fn
type comm_fn = data Impl.comm_fn
type callbacks =
  {
    local_fn : local_fn;
    comm_fn : comm_fn option;
  }

let bbd_callbacks { local_fn; comm_fn } =
  { Impl.local_fn = local_fn; Impl.comm_fn = comm_fn }

let call_bbdlocal session t y glocal =
  let session = read_weak_ref session in
  match session.ls_callbacks with
  | BBDCallback { Impl.local_fn = f } ->
      adjust_retcode session true (f t y) glocal
  | _ -> assert false

let call_bbdcomm session t y =
  let session = read_weak_ref session in
  match session.ls_callbacks with
  | BBDCallback { Impl.comm_fn = Some f } -> adjust_retcode session true (f t) y
  | _ -> assert false

external c_bbd_prec_init
    : parallel_session -> int -> bandwidths -> float -> bool -> unit
    = "c_cvode_bbd_prec_init"

external c_spils_spgmr
  : ('a, 'k) session -> int -> Spils.preconditioning_type -> unit
  = "c_cvode_spils_spgmr"

external c_spils_spbcg
  : ('a, 'k) session -> int -> Spils.preconditioning_type -> unit
  = "c_cvode_spils_spbcg"

external c_spils_sptfqmr
  : ('a, 'k) session -> int -> Spils.preconditioning_type -> unit
  = "c_cvode_spils_sptfqmr"

let init_preconditioner maxl dqrely bandwidths callbacks session nv =
  let ba, _, _ = Nvector.unwrap nv in
  let localn   = Sundials.RealArray.length ba in
  c_bbd_prec_init session localn bandwidths dqrely (callbacks.comm_fn <> None);
  session.ls_callbacks <- BBDCallback (bbd_callbacks callbacks)

let prec_left ?(maxl=0) ?(dqrely=0.0) bandwidths callbacks =
  SpilsTypes.InternalPrecLeft
    (init_preconditioner maxl dqrely bandwidths callbacks)
let prec_right ?(maxl=0) ?(dqrely=0.0) bandwidths callbacks =
  SpilsTypes.InternalPrecRight
    (init_preconditioner maxl dqrely bandwidths callbacks)
let prec_both ?(maxl=0) ?(dqrely=0.0) bandwidths callbacks =
  SpilsTypes.InternalPrecBoth
    (init_preconditioner maxl dqrely bandwidths callbacks)

external c_bbd_prec_reinit
    : parallel_session -> int -> int -> float -> unit
    = "c_cvode_bbd_prec_reinit"

let reinit s ?(dqrely=0.0) mudq mldq =
  match s.ls_callbacks with
  | BBDCallback _ -> c_bbd_prec_reinit s mudq mldq dqrely
  | _ -> invalid_arg "BBD preconditioner not in use"

external get_work_space : parallel_session -> int * int
    = "c_cvode_bbd_get_work_space"

external get_num_gfn_evals : parallel_session -> int
    = "c_cvode_bbd_get_num_gfn_evals"


(* Let C code know about some of the values in this module.  *)
type fcn = Fcn : 'a -> fcn
external c_init_module : fcn array -> unit =
  "c_cvode_bbd_init_module"

let _ =
  c_init_module
    (* Functions must be listed in the same order as
       callback_index in cvode_bbd_ml.c.  *)
    [|Fcn call_bbdlocal;
      Fcn call_bbdcomm;
    |]
