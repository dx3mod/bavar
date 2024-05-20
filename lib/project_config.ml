type build_options = {
  opt_level : char; [@default 's']
  lto : bool; [@default false]
  no_std : bool; [@default false]
  custom : string list; [@default []]
}
[@@deriving show, make]

type target = { mcu : string; hz : int option } [@@deriving show, make]

type layout = {
  root_dir : string; [@default "src"]
  out_dir : string; [@default "_build"]
}
[@@deriving show, make]

type build_configurations = {
  release : build_options;
  debug : build_options;
  custom : build_options option;
}
[@@deriving show]

let release_build_options = make_build_options ~lto:true ()
let debug_build_options = make_build_options ~opt_level:'1' ()

type t = {
  name : string;
  target : target option;
  layout : layout; [@default make_layout ()]
  build : build_configurations;
      [@default
        {
          release = release_build_options;
          debug = debug_build_options;
          custom = None;
        }]
  lang : string option;
  strict : bool; [@default true]
  envs : (string * string) list; [@default []]
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
      D.field_opt_or "build.release" ~default:release_build_options
        (build_options_decoder release_build_options)
    in

    let* custom_build =
      D.field_opt "build" (build_options_decoder @@ debug_build_options)
    in

    let* envs = D.field_opt_or "envs" ~default:[] envs_decoder in

    D.succeed
      {
        name;
        target;
        layout = make_layout ();
        build = { debug; release; custom = custom_build };
        lang;
        strict;
        envs;
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
    | Sexp.List [ Sexp.Atom "lto"; Sexp.Atom (("false" | "true") as flag) ] ->
        Ok { origin with lto = Bool.of_string flag }
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

let of_file filename =
  let open Base in
  let file = In_channel.open_text filename in
  let sexp = In_channel.input_all file |> Sexplib.Sexp.of_string_many in
  of_sexp @@ Sexplib.Sexp.List sexp
