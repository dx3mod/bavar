open Core
open Bavar

let rec initialize_new_project ~path ~target ~forced ~cpp () =
  if (not forced) && Sys_unix.is_directory_exn path then (
    eprintf "The '%s' directory already exist! Can't initialize a project.\n"
      path;
    exit 1)
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

    Core_unix.mkdir_p config.layout.root_dir;

    Out_channel.with_file Util.configuration_filename ~f:(fun ch ->
        fprintf ch "(name %s)\n" proj_name;
        Option.iter target ~f:(fprintf ch "(target %s)\n"));

    write_main_c ~source_dir:(Filename.concat path config.layout.root_dir) ~cpp;

    printf "Entering directory '%s'\n" path;
    Ocolor_format.printf
      "@{<green>Success@}: initialized project @{<blue>%s@}\n" proj_name;
    Ocolor_format.pp_print_flush Ocolor_format.std_formatter ()

and entry_to_dir path =
  Core_unix.mkdir_p path;
  Core_unix.chdir path

and write_main_c ~source_dir ~cpp =
  let filename =
    ("main." ^ if cpp then "cpp" else "c") |> Filename.concat source_dir
  in

  let contents = "int main(void) {\n  while (1) {\n  }\n}\n" in

  Out_channel.write_all filename ~data:contents

let command =
  Command.basic ~summary:"initialize a new project"
    ~readme:(fun () ->
      {|To set an alternative configuration file name, set the $BAVAR_CONFIG_NAME
environment variable to any valid value.|})
    (let%map_open.Command target =
       flag "-target" (optional string) ~doc:"mcu:freq MCU and frequency values"
     and force = flag "-f" no_arg ~doc:"force"
     and cpp = flag "-cpp" no_arg ~doc:"as C++ project"
     and path = anon ("path" %: string) in
     initialize_new_project ~path ~target ~forced:force ~cpp)
