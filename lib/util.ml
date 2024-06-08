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

let read_project_config_exn ~root_dir =
  let config_file_path =
    let findings = globs ~path:root_dir valid_configuration_file_names in

    match findings with
    | [| path |] -> path
    | [||] -> raise (Not_found_config { path = root_dir })
    | _ -> failwith "found many configuration files at directory!"
  in

  if not @@ Sys_unix.file_exists_exn config_file_path then
    raise (Not_found_config { path = root_dir });

  Project_config.of_file config_file_path

let read_project_config ~root_dir =
  try read_project_config_exn ~root_dir with
  | Not_found_config { path } ->
      eprintf "Not found configuration file at '%s' directory!\n" path;
      exit 1
  | Project_config.Read_error err ->
      eprintf "Failed to read config: %s.\nAt '%s' file.\n" err.message err.path;
      exit 1

let configuration_filename =
  Sys.getenv "BAVAR_CONFIG_NAME" |> Option.value ~default:"avr-project"

let find_entry_file ~proj_name files =
  let check_ext = function
    | "c" -> `C
    | "cpp" | "cxx" -> `Cpp
    | "s" | "asm" -> `Asm
    | _ -> failwith "invalid file ext!"
  in

  Array.find_map
    ~f:(fun filename ->
      match Base.String.rsplit2_exn ~on:'.' @@ Filename.basename filename with
      | "main", ext -> Some (`Executable, check_ext ext)
      | name, ext when String.equal name proj_name ->
          Some (`Library, check_ext ext)
      | _ -> None)
    files

let find_entry_file_exn ~proj_name files =
  find_entry_file ~proj_name files
  |> Option.value_exn ~message:"not found entry file!"

let print_command_log ~prog args =
  String.concat ~sep:" " args
  |> Ocolor_format.printf "\n[@{<cyan> %s @}] %s\n" prog;

  Ocolor_format.pp_print_flush Ocolor_format.std_formatter ()

let hash_path = Md5.(Fn.compose to_hex digest_string)
