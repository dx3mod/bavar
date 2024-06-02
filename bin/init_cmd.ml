open Core
open Bavar

let rec initialize_new_project ~path ~target ~forced () =
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

    Out_channel.with_file "LabAvrProject" ~f:(fun ch ->
        fprintf ch "(name %s)\n" proj_name;
        Option.iter target ~f:(fprintf ch "(target %s)\n");

        Out_channel.write_all
          (Filename.concat config.layout.root_dir "main.c")
          ~data:{|int main(void) {
  while (1) {
    // code
  }
}
|});

    printf "Entering directory '%s'\n" path;
    Ocolor_format.printf
      "@{<green>Success@}: initialized project @{<blue>%s@}\n" proj_name;
    Ocolor_format.pp_print_flush Ocolor_format.std_formatter ()

and entry_to_dir path =
  Core_unix.mkdir_p path;
  Core_unix.chdir path

let command =
  Command.basic ~summary:"initialize a new project"
    (let%map_open.Command target =
       flag "-target" (optional string) ~doc:"mcu:freq MCU and frequency values"
     and force = flag "-f" no_arg ~doc:"force"
     and path = anon ("path" %: string) in
     initialize_new_project ~path ~target ~forced:force)
