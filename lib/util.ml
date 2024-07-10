open Core

let globs ~path =
  let f files pattern =
    match
      Option.try_with @@ fun () ->
      Globlon.glob (Filename.concat path pattern) ~glob_brace:true
    with
    | None -> files
    | Some files' -> Array.append files' files
  in
  List.fold ~f ~init:[||]

let join_paths paths =
  List.reduce paths ~f:Filename.concat
  |> Option.value_exn ~message:"join_paths paths must be >= 2"

exception Not_found_config of { path : string }

let valid_configuration_file_names =
  [ "LabAvrProject"; "avr-project"; "bavar"; "bavar-project" ]

let get_config_filename_at_dir dirpath =
  let findings = globs ~path:dirpath valid_configuration_file_names in
  match findings with
  | [||] -> None
  | [| path |] -> Some path
  | _ -> failwith "found many configuration files at directory!"

let read_project_config_exn ~root_dir =
  let config_filename =
    get_config_filename_at_dir root_dir
    |> Option.value_or_thunk ~default:(fun () ->
           raise (Not_found_config { path = root_dir }))
  in

  Project_config.of_file config_filename

let read_project_config ~root_dir =
  try read_project_config_exn ~root_dir with
  | Not_found_config { path } ->
      eprintf "Not found configuration file at '%s' directory!\n" path;
      exit 1
  | Project_config.Read_error err ->
      eprintf "Failed to read config: %s.\nAt '%s' file.\n" err.message err.path;
      exit 1

let detect_project_type ~proj_name files =
  let check_ext = function
    | "c" -> `C
    | "cpp" | "cxx" -> `Cpp
    | "s" | "asm" -> `Asm
    | _ -> failwith "invalid file ext!"
  in

  Array.find_map
    ~f:(fun filename ->
      match String.rsplit2_exn ~on:'.' @@ Filename.basename filename with
      | "main", ext -> Some (`Executable, check_ext ext)
      | name, ext when String.equal name proj_name ->
          Some (`Library, check_ext ext)
      | _ -> None)
    files

let print_command_log ~prog args =
  String.concat ~sep:" " args
  |> Ocolor_format.printf "[@{<cyan> %s @}] %s\n\n" prog;

  Ocolor_format.pp_print_flush Ocolor_format.std_formatter ()

let hash_path = Md5.(Fn.compose to_hex digest_string)

let exit_with_message ?(code = 1) msg =
  Ocolor_format.eprintf "@{<red> %s @}\n" msg;
  Ocolor_format.pp_print_flush Ocolor_format.err_formatter ();
  exit code
