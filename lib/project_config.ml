(* build *)

type build_options = {
  opt_level : char; [@default 's']
  lto : bool; [@default false]
  no_std : bool; [@default false]
  custom : string list; [@default []]
  artifacts : artifacts; [@default { intermixed = false; intel_hex = false }]
}
[@@deriving show, make]

and artifacts = { intermixed : bool; intel_hex : bool } [@@deriving show]

type build_configurations = { release : build_options; debug : build_options }
[@@deriving show]

let release_build_options = make_build_options ~lto:true ()
let debug_build_options = make_build_options ~opt_level:'1' ()

(* program *)

type program_options = { programmer_id : string; port : string option }
[@@deriving show]

(* development options *)

type dev_options = {
  clangd_support : bool; [@default false]
  vscode_support : bool; [@default false]
}
[@@deriving show, make]

let dev_options_default = make_dev_options ()

(* other *)

type target = { mcu : string; hz : int option } [@@deriving show, make]

type layout = {
  root_dir : string; [@default "src"]
  out_dir : string; [@default "_build"]
  headers_dir : string; [@default "include"]
}
[@@deriving show, make]

type resource = { path : string } [@@deriving show, make]

(* configuration type *)

type t = {
  name : string;
  target : target option;
  layout : layout; [@default make_layout ()]
  build : build_configurations;
      [@default
        { release = release_build_options; debug = debug_build_options }]
  program : program_options;
      [@default { programmer_id = "usbasp"; port = None }]
  lang : string option;
  strict : bool; [@default true]
  envs : (string * string) list; [@default []]
  depends : Dependency.t list; [@default []]
  resources : resource list; [@default []]
  dev : dev_options; [@default dev_options_default]
}
[@@deriving show, make]

module D = Decoders_sexplib.Decode
open D.Infix
open Sexplib

let rec of_sexp sexp =
  let config_decoder =
    let* name = D.field "name" D.string in
    let* target = D.field_opt "target" target_decoder in
    let* lang = D.field_opt "lang" D.string in
    let* strict = D.field_opt_or "strict" ~default:true D.bool in

    let* debug =
      D.field_opt_or "build.debug" ~default:debug_build_options
        (build_options_decoder debug_build_options)
    in
    let* release =
      D.field_opt_or "build" ~default:release_build_options
        (build_options_decoder release_build_options)
    in

    let* programmer_id =
      D.field_opt_or "program.id" ~default:"usbasp" D.string
    in
    let* program_port = D.field_opt "program.port" D.string in

    let* envs = D.field_opt_or "envs" ~default:[] envs_decoder in
    let* depends = D.field_opt_or "depends" ~default:[] depends_decoder in

    let* resources = D.field_opt_or "resources" ~default:[] resources_decoder in

    let* dev_options =
      D.field_opt_or "dev" ~default:dev_options_default
        (dev_options_decoder dev_options_default)
    in

    D.succeed
      {
        name;
        target;
        layout = make_layout ();
        build = { debug; release };
        program = { programmer_id; port = program_port };
        lang;
        strict;
        envs;
        depends;
        dev = dev_options;
        resources;
      }
  in

  D.decode_value config_decoder sexp

and target_decoder =
  let parse_freq freq =
    if String.ends_with ~suffix:"mhz" freq then
      let open Base.Option.Let_syntax in
      Base.String.chop_suffix ~suffix:"mhz" freq >>= fun mhz ->
      int_of_string_opt mhz >>| ( * ) 1_000_000
    else int_of_string_opt freq
  in

  D.value >>= function
  | Sexp.List [ Sexp.Atom mcu ] | Sexp.Atom mcu ->
      D.succeed @@ make_target ~mcu ()
  | Sexp.List [ Sexp.Atom mcu; Sexp.Atom freq ] -> (
      match parse_freq freq with
      | Some hz -> D.succeed @@ make_target ~mcu ~hz ()
      | None -> D.fail "Expected Hz (number) value")
  | _ -> D.fail_with @@ Decoders.Error.make "Empty target structure!"

and build_options_decoder default =
  let open Base in
  let parse origin = function
    | Sexp.Atom "lto" -> Ok { origin with lto = true }
    | Sexp.Atom ("no_std" | "nostd") -> Ok { origin with no_std = true }
    | Sexp.Atom x when String.is_prefix x ~prefix:"O" && String.length x = 2 ->
        Ok { origin with opt_level = String.get x 1 }
    | Sexp.Atom ("intel_hex" | "ihex") ->
        Ok
          { origin with artifacts = { origin.artifacts with intel_hex = true } }
    | Sexp.Atom "intermixed" ->
        Ok
          {
            origin with
            artifacts = { origin.artifacts with intermixed = true };
          }
    | Sexp.List [ Sexp.Atom "lto"; Sexp.Atom (("false" | "true") as flag) ] ->
        Ok { origin with lto = Bool.of_string flag }
    | Sexp.Atom arg when String.is_prefix ~prefix:"-" arg ->
        Ok { origin with custom = arg :: origin.custom }
    | _ ->
        Error
          (Decoders.Error.make
             "Invalid build option. Expected 'lto', 'no_std', 'O<n>'.")
  in

  let* value = D.value in

  let build_options =
    match value with
    | Sexp.Atom _ as atom -> parse default atom
    | Sexp.List xs -> Base.List.fold_result xs ~init:default ~f:parse
  in
  match build_options with
  | Ok build_options -> D.succeed build_options
  | Error msg -> D.fail_with msg

and envs_decoder =
  D.value >>= function
  | Sexp.List [ Sexp.Atom name; Sexp.Atom value ] -> D.succeed [ (name, value) ]
  | Sexp.List xs -> (
      match
        Base.List.fold_result xs ~init:[] ~f:(fun acc -> function
          | Sexp.List [ Sexp.Atom name; Sexp.Atom value ] ->
              Ok ((name, value) :: acc)
          | _ -> Error "invalid pair env")
      with
      | Ok x -> D.succeed x
      | Error e -> D.fail e)
  | _ -> failwith "envs decoder"

and depends_decoder =
  D.value >>= function
  | Sexp.Atom value -> D.succeed [ Dependency.parse value ]
  | Sexp.List atoms ->
      D.succeed
      @@ List.map
           (function
             | Sexp.Atom value -> Dependency.parse value
             | _ -> failwith "invalid dependency value!")
           atoms

and dev_options_decoder default =
  let open Base in
  let parse opts = function
    | Sexp.Atom ("clangd" | "compile_flags.txt") ->
        Ok { opts with clangd_support = true }
    | Sexp.Atom ("vscode" | "c_cpp_properties") ->
        Ok { opts with vscode_support = true }
    | _ ->
        Error
          (Decoders.Error.make
             "Invalid dev option. Expected 'clangd' or 'compile_flags.txt'.")
  in

  let* value = D.value in
  match
    match value with
    | Sexp.Atom _ as atom -> parse default atom
    | Sexp.List xs -> Base.List.fold_result xs ~init:default ~f:parse
  with
  | Ok dev_options -> D.succeed dev_options
  | Error msg -> D.fail_with msg

and resources_decoder =
  let rec parse_sexp = function
    | Sexp.Atom path -> [ make_resource ~path ]
    | Sexp.List atoms ->
        Core.List.bind atoms ~f:(function
          | Sexp.List _ -> failwith "invalid resource value!"
          | atom -> parse_sexp atom)
  in

  D.value >>= fun atom -> D.succeed @@ parse_sexp atom

exception Read_error of { message : string; path : string }

(** Raises [Read_error], [Sys_error]. *)
let of_file filename =
  let read_error message = Read_error { message; path = filename } in

  try
    let file = In_channel.open_text filename in
    let sexp = In_channel.input_all file |> Sexplib.Sexp.of_string_many in

    match of_sexp (Sexplib.Sexp.List sexp) with
    | Ok config -> config
    | Error err -> raise (read_error @@ Format.asprintf "%a" D.pp_error err)
  with Parsexp.Parse_error e ->
    raise (read_error @@ Parsexp.Parse_error.message e)
