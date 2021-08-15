(***********************************************************************)
(*                                                                     *)
(*                   OCaml interface to Sundials                       *)
(*                                                                     *)
(*  Timothy Bourke (Inria), Jun Inoue (Inria), and Marc Pouzet (LIENS) *)
(*                                                                     *)
(*  Copyright 2014 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under a New BSD License, refer to the file LICENSE.                *)
(*                                                                     *)
(***********************************************************************)

type cnvec
type ('data, 'kind) nvector =
  NV of { payload: 'data;
          cptr: cnvec;
          check: (('data, 'kind) nvector -> bool);
          clone: ('data, 'kind) t -> ('data, 'kind) t;
        }
and ('data, 'kind) t = ('data, 'kind) nvector

let unwrap (NV { payload; _ }) = payload

exception IncompatibleNvector

let check (NV { check; _ }) nv2 =
  if not (check nv2) then raise IncompatibleNvector

let clone (NV { clone; _ } as nv) = clone nv

let _ = Callback.register "Nvector.clone" clone

type nvector_id =
    Serial
  | Parallel
  | OpenMP
  | Pthreads
  | ParHyp
  | PETSc
  | CUDA
  | RAJA
  | OpenMPdev
  | Trilinos
  | ManyVector
  | MpiManyVector
  | MpiPlusX
  | Custom

external get_id : ('data, 'kind) t -> nvector_id
  = "sunml_nvec_get_id"

module type NVECTOR_OPS =
  sig (* {{{ *)
    type t

    val clone        : t -> t
    val linearsum    : float -> t -> float -> t -> t -> unit
    val const        : float -> t -> unit
    val prod         : t -> t -> t -> unit
    val div          : t -> t -> t -> unit
    val scale        : float -> t -> t -> unit
    val abs          : t -> t -> unit
    val inv          : t -> t -> unit
    val addconst     : t -> float -> t -> unit
    val dotprod      : t -> t -> float
    val maxnorm      : t -> float
    val wrmsnorm     : t -> t -> float
    val min          : t -> float
    val compare      : float -> t -> t -> unit
    val invtest      : t -> t -> bool

    val wl2norm      : t -> t -> float
    val l1norm       : t -> float
    val wrmsnormmask : t -> t -> t -> float
    val constrmask   : t -> t -> t -> bool
    val minquotient  : t -> t -> float

    val space        : t -> int * int
    val getlength    : t -> int

    val linearcombination
      : Sundials.RealArray.t -> t array -> t -> unit
    val scaleaddmulti
      : Sundials.RealArray.t -> t -> t array -> t array -> unit
    val dotprodmulti
      : t -> t array -> Sundials.RealArray.t -> unit

    val linearsumvectorarray
      : float -> t array -> float -> t array -> t array -> unit
    val scalevectorarray
      : Sundials.RealArray.t -> t array -> t array -> unit
    val constvectorarray
      : float -> t array -> unit
    val wrmsnormvectorarray
      : t array -> t array -> Sundials.RealArray.t -> unit
    val wrmsnormmaskvectorarray
      : t array -> t array -> t -> Sundials.RealArray.t -> unit
    val scaleaddmultivectorarray
      : Sundials.RealArray.t -> t array -> t array array -> t array array -> unit
    val linearcombinationvectorarray
      : Sundials.RealArray.t -> t array array -> t array -> unit

    module Local : sig
      val dotprod     : t -> t -> float
      val maxnorm     : t -> float
      val min         : t -> float
      val l1norm      : t -> float
      val invtest     : t -> t -> bool
      val constrmask  : t -> t -> t -> bool
      val minquotient : t -> t -> float
      val wsqrsum     : t -> t -> float
      val wsqrsummask : t -> t -> t -> float
    end
  end (* }}} *)

module type NVECTOR =
  sig (* {{{ *)
    type kind
    type data
    type t = (data, kind) nvector
    val wrap : ?with_fused_ops:bool -> data -> t
    val enable :
         ?with_fused_ops                       : bool
      -> ?with_linear_combination              : bool
      -> ?with_scale_add_multi                 : bool
      -> ?with_dot_prod_multi                  : bool
      -> ?with_linear_sum_vector_array         : bool
      -> ?with_scale_vector_array              : bool
      -> ?with_const_vector_array              : bool
      -> ?with_wrms_norm_vector_array          : bool
      -> ?with_wrms_norm_mask_vector_array     : bool
      -> ?with_scale_add_multi_vector_array    : bool
      -> ?with_linear_combination_vector_array : bool
      -> t
      -> unit
    module Ops : NVECTOR_OPS with type t = t
    module DataOps : NVECTOR_OPS with type t = data
  end (* }}} *)

(* Hack to ensure that Sundials.c_init_module is executed so that the global
   exceptions are properly registered. *)
let e = Sundials.RecoverableFailure

(* {{{ *)

external has_linearcombination            : ('d, 'k) t -> bool
    = "sunml_nvec_has_linearcombination" [@@noalloc]
external has_scaleaddmulti                : ('d, 'k) t -> bool
    = "sunml_nvec_has_scaleaddmulti" [@@noalloc]
external has_dotprodmulti                 : ('d, 'k) t -> bool
    = "sunml_nvec_has_dotprodmulti" [@@noalloc]
external has_linearsumvectorarray         : ('d, 'k) t -> bool
    = "sunml_nvec_has_linearsumvectorarray" [@@noalloc]
external has_scalevectorarray             : ('d, 'k) t -> bool
    = "sunml_nvec_has_scalevectorarray" [@@noalloc]
external has_constvectorarray             : ('d, 'k) t -> bool
    = "sunml_nvec_has_constvectorarray" [@@noalloc]
external has_wrmsnormvectorarray          : ('d, 'k) t -> bool
    = "sunml_nvec_has_wrmsnormvectorarray" [@@noalloc]
external has_wrmsnormmaskvectorarray      : ('d, 'k) t -> bool
    = "sunml_nvec_has_wrmsnormmaskvectorarray" [@@noalloc]
external has_scaleaddmultivectorarray     : ('d, 'k) t -> bool
    = "sunml_nvec_has_scaleaddmultivectorarray" [@@noalloc]
external has_linearcombinationvectorarray : ('d, 'k) t -> bool
    = "sunml_nvec_has_linearcombinationvectorarray" [@@noalloc]

module Local = struct
  external has_dotprod      : ('d, 'k) t -> bool
    = "sunml_nvec_has_dotprodlocal" [@@noalloc]
  external has_maxnorm      : ('d, 'k) t -> bool
    = "sunml_nvec_has_maxnormlocal" [@@noalloc]
  external has_min          : ('d, 'k) t -> bool
    = "sunml_nvec_has_minlocal" [@@noalloc]
  external has_l1norm       : ('d, 'k) t -> bool
    = "sunml_nvec_has_l1normlocal" [@@noalloc]
  external has_invtest      : ('d, 'k) t -> bool
    = "sunml_nvec_has_invtestlocal" [@@noalloc]
  external has_constrmask   : ('d, 'k) t -> bool
    = "sunml_nvec_has_constrmasklocal" [@@noalloc]
  external has_minquotient  : ('d, 'k) t -> bool
    = "sunml_nvec_has_minquotientlocal" [@@noalloc]
  external has_wsqrsum      : ('d, 'k) t -> bool
    = "sunml_nvec_has_wsqrsumlocal" [@@noalloc]
  external has_wsqrsummask  : ('d, 'k) t -> bool
    = "sunml_nvec_has_wsqrsummasklocal" [@@noalloc]
end

(* }}} *)

type gdata = ..
type gdata += RA of Sundials.RealArray.t
type gkind
type any = (gdata, gkind) t
exception BadGenericType

exception OperationNotProvided

module Any = struct (* {{{ *)
  type t = any

  external has_linearcombination            : t -> bool
      = "sunml_nvec_has_linearcombination" [@@noalloc]
  external has_scaleaddmulti                : t -> bool
      = "sunml_nvec_has_scaleaddmulti" [@@noalloc]
  external has_dotprodmulti                 : t -> bool
      = "sunml_nvec_has_dotprodmulti" [@@noalloc]
  external has_linearsumvectorarray         : t -> bool
      = "sunml_nvec_has_linearsumvectorarray" [@@noalloc]
  external has_scalevectorarray             : t -> bool
      = "sunml_nvec_has_scalevectorarray" [@@noalloc]
  external has_constvectorarray             : t -> bool
      = "sunml_nvec_has_constvectorarray" [@@noalloc]
  external has_wrmsnormvectorarray          : t -> bool
      = "sunml_nvec_has_wrmsnormvectorarray" [@@noalloc]
  external has_wrmsnormmaskvectorarray      : t -> bool
      = "sunml_nvec_has_wrmsnormmaskvectorarray" [@@noalloc]
  external has_scaleaddmultivectorarray     : t -> bool
      = "sunml_nvec_has_scaleaddmultivectorarray" [@@noalloc]
  external has_linearcombinationvectorarray : t -> bool
      = "sunml_nvec_has_linearcombinationvectorarray" [@@noalloc]

  module Local = struct
    external has_dotprod      : t -> bool
      = "sunml_nvec_has_dotprodlocal" [@@noalloc]
    external has_maxnorm      : t -> bool
      = "sunml_nvec_has_maxnormlocal" [@@noalloc]
    external has_min          : t -> bool
      = "sunml_nvec_has_minlocal" [@@noalloc]
    external has_l1norm       : t -> bool
      = "sunml_nvec_has_l1normlocal" [@@noalloc]
    external has_invtest      : t -> bool
      = "sunml_nvec_has_invtestlocal" [@@noalloc]
    external has_constrmask   : t -> bool
      = "sunml_nvec_has_constrmasklocal" [@@noalloc]
    external has_minquotient  : t -> bool
      = "sunml_nvec_has_minquotientlocal" [@@noalloc]
    external has_wsqrsum      : t -> bool
      = "sunml_nvec_has_wsqrsumlocal" [@@noalloc]
    external has_wsqrsummask  : t -> bool
      = "sunml_nvec_has_wsqrsummasklocal" [@@noalloc]
  end
end (* }}} *)

module Ops = struct (* {{{ *)
  type t = any

  let clone = clone

  external c_linearsum    : float -> t -> float -> t -> t -> unit
    = "sunml_nvec_any_linearsum" [@@noalloc]

  let linearsum a (x : t) b (y : t) (z : t) =
    if Sundials_configuration.safe then (check x y; check x z);
    c_linearsum a x b y z

  external const          : float -> t -> unit
    = "sunml_nvec_any_const" [@@noalloc]

  external c_prod         : t -> t -> t -> unit
    = "sunml_nvec_any_prod" [@@noalloc]

  let prod (x : t) (y : t) (z : t) =
    if Sundials_configuration.safe then (check x y; check x z);
    c_prod x y z

  external c_div          : t -> t -> t -> unit
    = "sunml_nvec_any_div" [@@noalloc]

  let div (x : t) (y : t) (z : t) =
    if Sundials_configuration.safe then (check x y; check x z);
    c_div x y z

  external c_scale        : float -> t -> t -> unit
    = "sunml_nvec_any_scale" [@@noalloc]

  let scale c (x : t) (z : t) =
    if Sundials_configuration.safe then check x z;
    c_scale c x z

  external c_abs          : t -> t -> unit
    = "sunml_nvec_any_abs" [@@noalloc]

  let abs (x : t) (z : t) =
    if Sundials_configuration.safe then check x z;
    c_abs x z

  external c_inv          : t -> t -> unit
    = "sunml_nvec_any_inv" [@@noalloc]

  let inv (x : t) (z : t) =
    if Sundials_configuration.safe then check x z;
    c_inv x z

  external c_addconst     : t -> float -> t -> unit
    = "sunml_nvec_any_addconst" [@@noalloc]

  let addconst (x : t) b (z : t) =
    if Sundials_configuration.safe then check x z;
    c_addconst x b z

  external c_dotprod      : t -> t -> float
    = "sunml_nvec_any_dotprod"

  let dotprod (x : t) (y : t) =
    if Sundials_configuration.safe then check x y;
    c_dotprod x y

  external maxnorm        : t -> float
    = "sunml_nvec_any_maxnorm"

  external c_wrmsnorm     : t -> t -> float
    = "sunml_nvec_any_wrmsnorm"

  let wrmsnorm (x : t) (w : t) =
    if Sundials_configuration.safe then check x w;
    c_wrmsnorm x w

  external c_wrmsnormmask : t -> t -> t -> float
    = "sunml_nvec_any_wrmsnormmask"

  let wrmsnormmask (x : t) (w : t) (id : t) =
    if Sundials_configuration.safe then (check x w; check x id);
    c_wrmsnormmask x w id

  external min            : t -> float
    = "sunml_nvec_any_min"

  external c_wl2norm      : t -> t -> float
    = "sunml_nvec_any_wl2norm"

  let wl2norm (x : t) (w : t) =
    if Sundials_configuration.safe then check x w;
    c_wl2norm x w

  external l1norm         : t -> float
    = "sunml_nvec_any_l1norm"

  external c_compare      : float -> t -> t -> unit
    = "sunml_nvec_any_compare" [@@noalloc]

  let compare c (x : t) (z : t) =
    if Sundials_configuration.safe then check x z;
    c_compare c x z

  external c_invtest      : t -> t -> bool
    = "sunml_nvec_any_invtest" [@@noalloc]

  let invtest (x : t) (z : t) =
    if Sundials_configuration.safe then check x z;
    c_invtest x z

  external c_constrmask   : t -> t -> t -> bool
    = "sunml_nvec_any_constrmask" [@@noalloc]

  let constrmask (c : t) (x : t) (m : t) =
    if Sundials_configuration.safe then (check c x; check c m);
    c_constrmask c x m

  external c_minquotient  : t -> t -> float
    = "sunml_nvec_any_minquotient"

  let minquotient (n : t) (d : t) =
    if Sundials_configuration.safe then check n d;
    c_minquotient n d

  external space  : t -> int * int
    = "sunml_nvec_any_space" [@@noalloc]

  external getlength : t -> int
    = "sunml_nvec_any_getlength"

  external c_linearcombination
    : Sundials.RealArray.t -> t array -> t -> unit
    = "sunml_nvec_any_linearcombination"

  let linearcombination ca (xa : t array) (z : t) =
    if Sundials_impl.Versions.sundials_lt400
      then raise Sundials.Config.NotImplementedBySundialsVersion;
    if Sundials_configuration.safe then Array.iter (check z) xa;
    c_linearcombination ca xa z

  external c_scaleaddmulti
    : Sundials.RealArray.t -> t -> t array -> t array -> unit
    = "sunml_nvec_any_scaleaddmulti"

  let scaleaddmulti aa (x : t) (ya : t array) (za : t array) =
    if Sundials_impl.Versions.sundials_lt400
      then raise Sundials.Config.NotImplementedBySundialsVersion;
    if Sundials_configuration.safe then
      (Array.iter (check x) ya; Array.iter (check x) za);
    c_scaleaddmulti aa x ya za

  external c_dotprodmulti
    : t -> t array -> Sundials.RealArray.t -> unit
    = "sunml_nvec_any_dotprodmulti"

  let dotprodmulti (x : t) (ya : t array) dp =
    if Sundials_impl.Versions.sundials_lt400
      then raise Sundials.Config.NotImplementedBySundialsVersion;
    if Sundials_configuration.safe then Array.iter (check x) ya;
    c_dotprodmulti x ya dp

  external c_linearsumvectorarray
    : float -> t array -> float -> t array -> t array -> unit
    = "sunml_nvec_any_linearsumvectorarray"

  let linearsumvectorarray a (xa : t array) b (ya : t array) (za : t array) =
    if Sundials_impl.Versions.sundials_lt400
      then raise Sundials.Config.NotImplementedBySundialsVersion;
    let xa0 = Array.get xa 0 in
    if Sundials_configuration.safe
    then (Array.iter (check xa0) xa;
          Array.iter (check xa0) ya;
          Array.iter (check xa0) za);
    c_linearsumvectorarray a xa b ya za

  external c_scalevectorarray
    : Sundials.RealArray.t -> t array -> t array -> unit
    = "sunml_nvec_any_scalevectorarray"

  let scalevectorarray c (xa : t array) (za : t array) =
    if Sundials_impl.Versions.sundials_lt400
      then raise Sundials.Config.NotImplementedBySundialsVersion;
    let xa0 = Array.get xa 0 in
    if Sundials_configuration.safe
    then (Array.iter (check xa0) xa;
          Array.iter (check xa0) za);
    c_scalevectorarray c xa za

  external c_constvectorarray
    : float -> t array -> unit
    = "sunml_nvec_any_constvectorarray"

  let constvectorarray c (za : t array) =
    if Sundials_impl.Versions.sundials_lt400
      then raise Sundials.Config.NotImplementedBySundialsVersion;
    let za0 = Array.get za 0 in
    if Sundials_configuration.safe
    then Array.iter (check za0) za;
    c_constvectorarray c za

  external c_wrmsnormvectorarray
    : t array -> t array -> Sundials.RealArray.t -> unit
    = "sunml_nvec_any_wrmsnormvectorarray"

  let wrmsnormvectorarray (xa : t array) (wa : t array) nrm =
    if Sundials_impl.Versions.sundials_lt400
      then raise Sundials.Config.NotImplementedBySundialsVersion;
    let xa0 = Array.get xa 0 in
    if Sundials_configuration.safe
    then (Array.iter (check xa0) xa;
          Array.iter (check xa0) wa);
    c_wrmsnormvectorarray xa wa nrm

  external c_wrmsnormmaskvectorarray
    : t array -> t array -> t -> Sundials.RealArray.t -> unit
    = "sunml_nvec_any_wrmsnormmaskvectorarray"

  let wrmsnormmaskvectorarray (xa : t array) (wa : t array) (id : t) nrm =
    if Sundials_impl.Versions.sundials_lt400
      then raise Sundials.Config.NotImplementedBySundialsVersion;
    if Sundials_configuration.safe
    then (Array.iter (check id) xa;
          Array.iter (check id) wa);
    c_wrmsnormmaskvectorarray xa wa id nrm

  external c_scaleaddmultivectorarray
    : Sundials.RealArray.t -> t array -> t array array -> t array array -> unit
    = "sunml_nvec_any_scaleaddmultivectorarray"

  let scaleaddmultivectorarray ra (xa : t array) (yaa : t array array)
                                     (zaa : t array array) =
    if Sundials_impl.Versions.sundials_lt400
      then raise Sundials.Config.NotImplementedBySundialsVersion;
    let xa0 = Array.get xa 0 in
    if Sundials_configuration.safe
    then (Array.iter (check xa0) xa;
          Array.iter (Array.iter (check xa0)) yaa;
          Array.iter (Array.iter (check xa0)) zaa);
    c_scaleaddmultivectorarray ra xa yaa zaa

  external c_linearcombinationvectorarray
    : Sundials.RealArray.t -> t array array -> t array -> unit
    = "sunml_nvec_any_linearcombinationvectorarray"

  let linearcombinationvectorarray ca (xaa : t array array) (za : t array) =
    if Sundials_impl.Versions.sundials_lt400
      then raise Sundials.Config.NotImplementedBySundialsVersion;
    let za0 = Array.get za 0 in
    if Sundials_configuration.safe
    then (Array.iter (check za0) za;
          Array.iter (Array.iter (check za0)) xaa);
    c_linearcombinationvectorarray ca xaa za

  module Local = struct

    external c_dotprod      : t -> t -> float
      = "sunml_nvec_any_dotprodlocal"

    let dotprod (x : t) (y : t) =
      if Sundials_configuration.safe then check x y;
      if Any.Local.has_dotprod x then c_dotprod x y
      else raise OperationNotProvided

    external c_maxnorm        : t -> float
      = "sunml_nvec_any_maxnormlocal"

    let maxnorm (x : t) =
      if Any.Local.has_invtest x then c_maxnorm x
      else raise OperationNotProvided

    external c_min            : t -> float
      = "sunml_nvec_any_minlocal"

    let min (x : t) =
      if Any.Local.has_min x then c_min x
      else raise OperationNotProvided

    external c_l1norm         : t -> float
      = "sunml_nvec_any_l1normlocal"

    let l1norm (x : t) =
      if Any.Local.has_l1norm x then c_l1norm x
      else raise OperationNotProvided

    external c_invtest      : t -> t -> bool
      = "sunml_nvec_any_invtestlocal"

    let invtest (x : t) (z : t) =
      if Sundials_configuration.safe then check x z;
      if Any.Local.has_invtest x then c_invtest x z
      else raise OperationNotProvided

    external c_constrmask   : t -> t -> t -> bool
      = "sunml_nvec_any_constrmasklocal"

    let constrmask (c : t) (x : t) (m : t) =
      if Sundials_configuration.safe then (check c x; check c m);
      if Any.Local.has_constrmask c then c_constrmask c x m
      else raise OperationNotProvided

    external c_minquotient  : t -> t -> float
      = "sunml_nvec_any_minquotientlocal"

    let minquotient (n : t) (d : t) =
      if Sundials_configuration.safe then check n d;
      if Any.Local.has_minquotient n then c_minquotient n d
      else raise OperationNotProvided

    external c_wsqrsum      : t -> t -> float
      = "sunml_nvec_any_wsqrsumlocal"

    let wsqrsum (x : t) (w : t) =
      if Sundials_configuration.safe then check x w;
      if Any.Local.has_wsqrsum x then c_wsqrsum x w
      else raise OperationNotProvided

    external c_wsqrsummask  : t -> t -> t -> float
      = "sunml_nvec_any_wsqrsummasklocal"

    let wsqrsummask (x : t) (w : t) (id : t) =
      if Sundials_configuration.safe then (check x w; check x id);
      if Any.Local.has_wsqrsummask x then c_wsqrsummask x w id
      else raise OperationNotProvided
  end
end (* }}} *)

