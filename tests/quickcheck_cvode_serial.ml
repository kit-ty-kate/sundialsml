(* Compile CVODE test cases into OCaml that uses Cvode_serial.  *)
module Cvode = Cvode_serial
module Carray = Cvode_serial.Carray
module Roots = Cvode.Roots
open Pprint
open Quickcheck
open Quickcheck_sundials
open Pprint_cvode
open Quickcheck_cvode
open Camlp4.PreCast
open Syntax
open Ast
open Expr_of
open Expr_of_sundials
open Expr_of_cvode
open Expr_of_cvode_model
module Camlp4aux = Camlp4aux.Make (Camlp4.PreCast.Syntax)
open Camlp4aux

let _loc = Loc.ghost

let semis when_empty ctor = function
  | [] -> when_empty
  | e::es -> ctor (List.fold_left (fun e1 e2 -> Ast.ExSem (_loc, e1, e2)) e es)

let expr_array es = semis <:expr<[||]>> (fun e -> Ast.ExArr (_loc, e)) es

let expr_list es =
  List.fold_right (fun e es -> <:expr<$e$::$es$>>) es <:expr<[]>>

let expr_seq es = semis <:expr<()>> (fun e -> Ast.ExSeq (_loc, e)) es

let rec expr_of_rhsfn_impl = function
  | RhsFnLinear slopes ->
    (* forall i. vec'.{i} = slopes.{i} *)
    let neqs = Carray.length slopes in
    let go i = <:expr<vec'.{$`int:i$} <- $`flo:slopes.{i}$>>
    in <:expr<fun t vec vec' -> $expr_seq (List.map go (enum 0 (neqs-1)))$>>
  | RhsFnExpDecay coefs ->
    (* forall i. vec'.{i} = - coefs.{i} * vec.{i} *)
    let neqs = Carray.length coefs in
    let go i = <:expr<vec'.{$`int:i$}
                         (* This 0. is needed for some reason.  Looks like a
                            bug in camlp4's quotation parser.  *)
                         <- 0. -. $`flo:coefs.{i}$ *. vec.{$`int:i$}>>
    in <:expr<fun t vec vec' -> $expr_seq (List.map go (enum 0 (neqs-1)))$>>
  | RhsFnDie ->
    <:expr<fun _ _ _ ->
            failwith "exception raised on purpose from rhs function"
            >>

let jac_expr_of_rhsfn get set neqs rhsfn =
  let rec go rhsfn =
    match rhsfn with
    | RhsFnLinear slopes ->
      (* forall i. vec'.{i} = slopes.{i} *)
      fun i j -> <:expr<$set$ jac ($`int:i$, $`int:j$) 0.>>
    | RhsFnExpDecay coefs ->
      (* forall i. vec'.{i} = - coefs.{i} * vec.{i} *)
      fun i j -> if i = j then <:expr<$set$ jac ($`int:i$, $`int:j$)
                                                (0. -. $`flo:coefs.{i}$)>>
                 else <:expr<$set$ jac ($`int:i$, $`int:j$) 0.>>
    | RhsFnDie -> assert false
  and ixs = enum 0 (neqs - 1) in
  match rhsfn with
  | RhsFnDie -> <:expr<fun _ -> failwith "exception raised on purpose from \
                                          dense jacobian function">>
  | RhsFnLinear _ | RhsFnExpDecay _ ->
     <:expr<fun jac_arg jac ->
            let vec = jac_arg.Cvode.jac_y
            and t = jac_arg.Cvode.jac_t in
            $expr_seq
              (List.concat
                (List.map (fun i -> List.map (go rhsfn i) ixs) ixs))$>>

let expr_of_linear_solver model solver =
  let neqs = Carray.length model.vec in
  let dense_jac = function
    | false -> <:expr<None>>
    | true ->
      let dense_get = <:expr<Cvode.Densematrix.get>>
      and dense_set = <:expr<Cvode.Densematrix.set>> in
      <:expr<Some $jac_expr_of_rhsfn dense_get dense_set neqs model.rhsfn$>>
  in
  match solver with
  | MDense user_def -> <:expr<Cvode.Dense $dense_jac user_def$>>
  | MLapackDense user_def ->
    <:expr<Cvode.LapackDense $dense_jac user_def$>>
  | MDiag -> <:expr<Cvode.Diag>>
  | MBand _ | MLapackBand _ ->
    failwith "linear solver not implemented"

let expr_of_iter model = function
  | MFunctional -> <:expr<Cvode.Functional>>
  | MNewton s -> <:expr<Cvode.Newton $expr_of_linear_solver model s$>>

let expr_of_roots model roots =
  let n = Array.length roots in
  let set i =
    match roots.(i) with
    | r, Roots.Rising -> <:expr<g.{$`int:i$} <- t -. $`flo:r$>>
    | r, Roots.Falling -> <:expr<g.{$`int:i$} <- $`flo:r$ -. t>>
    | _, Roots.NoRoot -> assert false
  in
  let f ss i = <:expr<$ss$; $set i$>> in
  if n = 0 then <:expr<Cvode.no_roots>>
  else if model.root_fails then
    <:expr<($`int:n$,
            (fun _ _ _ ->
              failwith "exception raised on purpose from root function"))>>
  else
    <:expr<($`int:n$,
               (fun t vec g ->
                  $Fstream.fold_left f (set 0)
                    (Fstream.enum 1 (n-1))$))>>

(* Generate the test code that executes a given command.  *)
let expr_of_cmd_impl model = function
  | SolveNormalBadVector (t, n) ->
    <:expr<let tret, flag = Cvode.solve_normal session $`flo:t$
                              (Carray.create $`int:n$) in
           Aggr [Float tret; SolverResult flag; carray vec]>>
  | SolveNormal t ->
    <:expr<let tret, flag = Cvode.solve_normal session $`flo:t$ vec in
           Aggr [Float tret; SolverResult flag; carray vec]>>
  | GetRootInfo ->
    <:expr<let roots = Cvode.Roots.create (Cvode.nroots session) in
           Cvode.get_root_info session roots;
           RootInfo roots>>
  | GetNRoots ->
    <:expr<Int (Cvode.nroots session)>>
  | SetAllRootDirections dir ->
    <:expr<Cvode.set_all_root_directions session $expr_of_root_direction dir$;
           Unit>>
  | ReInit params ->
    let roots =
      match params.reinit_roots with
      | None -> Ast.ExNil _loc
      | Some r -> <:expr<~roots:$expr_of_roots model r$>>
    in
    let vec0 =
      match params.reinit_vec0_badlen with
      | None -> expr_of_carray params.reinit_vec0
      | Some n -> <:expr<Carray.create $`int:n$>>
    in
    <:expr<Cvode.reinit session
           ~iter_type:$expr_of_iter model params.reinit_iter$
           $roots$
           $`flo:params.reinit_t0$
           $vec0$;
           Unit
           >>
  | SetRootDirection dirs ->
    <:expr<Cvode.set_root_direction session
           $expr_array (List.map expr_of_root_direction (Array.to_list dirs))$;
           Unit>>
  | SetStopTime t ->
    <:expr<Cvode.set_stop_time session $`flo:t$; Unit>>

let expr_of_cmds_impl model = function
  | [] -> <:expr<()>>
  | cmds ->
    let sandbox exp = <:expr<do_cmd (lazy $exp$)>> in
    expr_seq (List.map (fun cmd -> sandbox (expr_of_cmd_impl model cmd))
                cmds)

let _ =
  register_expr_of_exn (fun cont -> function
      | Invalid_argument msg -> <:expr<Invalid_argument $`str:msg$>>
      | Not_found -> <:expr<Not_found>>
      | Cvode.IllInput -> <:expr<Cvode.IllInput>>
      | Cvode.TooMuchWork -> <:expr<Cvode.TooMuchWork>>
      | Cvode.TooClose -> <:expr<Cvode.TooClose>>
      | Cvode.TooMuchAccuracy -> <:expr<Cvode.TooMuchAccuracy>>
      | Cvode.ErrFailure -> <:expr<Cvode.ErrFailure>>
      | Cvode.ConvergenceFailure -> <:expr<Cvode.ConvergenceFailure>>
      | Cvode.LinearSetupFailure -> <:expr<Cvode.LinearSetupFailure>>
      | Cvode.LinearInitFailure -> <:expr<Cvode.LinearInitFailure>>
      | Cvode.LinearSolveFailure -> <:expr<Cvode.LinearSolveFailure>>
      | Cvode.FirstRhsFuncErr -> <:expr<Cvode.FirstRhsFuncErr>>
      | Cvode.RepeatedRhsFuncErr -> <:expr<Cvode.RepeatedRhsFuncErr>>
      | Cvode.UnrecoverableRhsFuncErr -> <:expr<Cvode.UnrecoverableRhsFuncErr>>
      | Cvode.RootFuncFailure -> <:expr<Cvode.RootFuncFailure>>
      | Cvode.BadK -> <:expr<Cvode.BadK>>
      | Cvode.BadT -> <:expr<Cvode.BadT>>
      | Cvode.BadDky -> <:expr<Cvode.BadDky>>
      | exn -> cont exn
    )

let ml_of_script (model, cmds) =
  <:str_item<
    module Cvode = Cvode_serial
    module Carray = Cvode.Carray
    open Quickcheck_sundials
    open Quickcheck_cvode
    open Pprint
    let model = $expr_of_model model$
    let cmds = $expr_of_array expr_of_cmd (Array.of_list cmds)$
    let do_cmd, finish, err_handler = test_case_driver model cmds
    let _ =
      let vec  = $expr_of_carray model.vec0$ in
      let session = Cvode.init
                    $expr_of_lmm model.lmm$
                    $expr_of_iter model model.iter$
                    $expr_of_rhsfn_impl model.rhsfn$
                    ~roots:$expr_of_roots model model.roots$
                    ~t0:$`flo:model.t0$
                    vec
      in
      Cvode.ss_tolerances session 1e-9 1e-9;
      Cvode.set_err_handler_fn session err_handler;
      do_cmd (lazy (Aggr [Float (Cvode.get_current_time session);
                          carray vec]));
      $expr_of_cmds_impl model cmds$;
      exit (finish ())
   >>

let randseed =
  Random.self_init ();
  ref (Random.int ((1 lsl 30) - 1))

let ml_file_of_script script src_file =
  Camlp4.PreCast.Printers.OCaml.print_implem ~output_file:src_file
    (ml_of_script script);
  let chan = open_out_gen [Open_text; Open_append; Open_wronly] 0 src_file in
  Printf.fprintf chan "\n(* generated with random seed %d, test case %d *)\n"
    !randseed !test_case_number;
  close_out chan

;;
let _ =
  let max_tests = ref 50 in
  let options = [("--exec-file", Arg.Set_string test_exec_file,
                  "test executable name \
                   (must be absolute, prefixed with ./, or on path)");
                 ("--failed-file", Arg.Set_string test_failed_file,
                  "file in which to dump the failed test case");
                 ("--compiler", Arg.Set_string test_compiler,
                  "compiler name with compilation options");
                 ("--rand-seed", Arg.Set_int randseed,
                  "seed value for random generator");
                 ("--verbose", Arg.Set verbose,
                  "print each test script before trying it");
                 ("--read-write-invariance", Arg.Set read_write_invariance,
                  "print data in a format that can be fed to ocaml toplevel");
                ] in
  Arg.parse options (fun n -> max_tests := int_of_string n)
    "randomly generate programs using CVODE and check if they work as expected";

  Printf.printf "random generator seed value = %d\n" !randseed;
  flush stdout;
  Random.init !randseed;
  size := 1;
  quickcheck_script ml_file_of_script !max_tests

