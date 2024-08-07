open Core
open Bavar

let rec initialize_new_project ~path ~target ~forced ~cpp ~kind () =
  if (not forced) && Sys_unix.is_directory_exn path then
    Util.exit_with_message
    @@ sprintf "The '%s' directory already exist! Can't initialize a project.\n"
         path
  else
    let proj_name = Filename.basename path in
    let config = Project_config.make ~name:proj_name () in
    let target =
      let open Option.Let_syntax in
      let%map target = target in

      match String.rsplit2 ~on:':' target with
      | Some (mcu, freq) -> sprintf "%s %s" mcu freq
      | None -> sprintf "%s 1mhz" target
    in

    entry_to_dir path;

    let is_lib = Project.is_lib_kind kind in

    if Option.is_none target && not is_lib then
      Util.waring
        "Warning: for a firmware type project, the target MCU must be \
         specified.";

    Core_unix.mkdir_p config.layout.root_dir;
    if is_lib then Core_unix.mkdir_p config.layout.headers_dir;

    Out_channel.with_file "avr-project" ~f:(fun ch ->
        fprintf ch "(name %s)\n" proj_name;
        Option.iter target ~f:(fprintf ch "(target %s)\n"));

    (match kind with
    | Project.Firmware -> write_main_c ~source_dir:config.layout.root_dir ~cpp
    | Project.Library ->
        write_lib_files ~source_dir:config.layout.root_dir
          ~header_dir:config.layout.headers_dir ~cpp ~name:config.name);

    printf "Entering directory '%s'\n" path;
    printf "%s: initialized %s project named %s\n" Color_text.keyword_success
      (Project.project_kind_to_string kind)
      Color_text.(colorize bold_blue proj_name)

and entry_to_dir path =
  Core_unix.mkdir_p path;
  Core_unix.chdir path

and write_main_c ~source_dir ~cpp =
  let filename =
    ("main." ^ if cpp then "cpp" else "c") |> Filename.concat source_dir
  in

  let contents = "int main(void) {\n  while (1) {\n  }\n}\n" in

  Out_channel.write_all filename ~data:contents

and write_lib_files ~source_dir ~header_dir ~cpp ~name =
  let c_ext, h_ext = if cpp then ("cpp", "hpp") else ("c", "h") in

  let src_file = sprintf "%s/%s.%s" source_dir name c_ext in
  let header_file = sprintf "%s/%s.%s" header_dir name h_ext in

  Out_channel.write_all src_file ~data:"";
  Out_channel.write_all header_file ~data:""

let kind_arg =
  Command.Arg_type.create (function
    | "firmware" -> Project.Firmware
    | "library" -> Project.Library
    | _ -> failwith "Invalid project kind value. Expected: firmware or library")

let command =
  Command.basic ~summary:"initialize a new project"
    ~readme:(fun () ->
      {|To set an alternative configuration file name, set the 
environment variable to any valid value.|})
    (let%map_open.Command target =
       flag "-target" (optional string) ~doc:"mcu:freq MCU and frequency values"
     and force = flag "-f" no_arg ~doc:"force"
     and cpp = flag "-x" no_arg ~doc:"as C++ project"
     (* and lib = flag "-l" no_arg ~doc:"as library" *)
     and kind = anon ("kind" %: kind_arg)
     and path = anon ("path" %: string) in
     initialize_new_project ~path ~target ~forced:force ~cpp ~kind)
