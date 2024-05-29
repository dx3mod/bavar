open Core
open Bavar

let current_path = Core_unix.getcwd ()

let compile_the_project ~root_dir ~target () =
  let config_file_path = Filename.concat root_dir "LabAvrProject" in

  if Sys_unix.file_exists_exn config_file_path then (
    printf "target: %s\nroot_dir: %s\n"
      (Option.value target ~default:"none")
      root_dir;

    Stdlib.print_newline ();

    try
      let config = Project_config.of_file config_file_path in
      let build_context = Build_context.make ~root_dir ~config in

      let avr_project = Resolver.resolve_avr_project build_context in

      Builder.build build_context avr_project Builder.Release
      |> List.iter ~f:(fun u ->
             Array.iter ~f:(Printf.printf "%s ") u;
             print_endline "\n")
    with
    | Bavar.Project_config.Read_error err ->
        Printf.eprintf "Failed to read config: %s.\nAt '%s' file.\n" err.message
          err.path;
        exit 1
    | Sys_error e ->
        Printf.eprintf "Sys_error. %s.\n" e;
        exit 1)
  else (
    eprintf "Not found 'LabAvrProject' configuration file at %s.\n"
      (if Filename.equal root_dir current_path then "current directory"
       else root_dir);
    exit 1)

let build_command =
  Command.basic ~summary:"compile the current project"
    (let%map_open.Command root_dir =
       flag "-root-dir"
         (optional_with_default current_path string)
         ~doc:"path to project"
     and target = anon @@ maybe ("target" %: string) in
     compile_the_project ~root_dir ~target)

let commands =
  Command.group
    ~summary:"A domain-specific build system for AVR C/C++ projects."
    [ ("build", build_command) ]

let () = Command_unix.run commands
