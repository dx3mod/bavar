open Core
open Bavar

let current_path = Core_unix.getcwd ()

let rec compile_the_project ~root_dir ~target ~debug () =
  let config_file_path = Filename.concat root_dir "LabAvrProject" in
  let _ = target in

  if Sys_unix.file_exists_exn config_file_path then (
    try
      let config = Project_config.of_file config_file_path in
      let build_context = Build_context.make ~root_dir ~config in
      let build_profile = if debug then `Debug else `Release in

      let avr_project = Resolver.resolve_avr_project build_context in

      Core_unix.mkdir_p @@ Build_context.output_dir build_context build_profile;

      let main_args, _ =
        Builder.compile avr_project ~ctx:build_context ~mode:build_profile
      in

      Out_channel.write_lines
        (Filename.concat root_dir "compile_flags.txt")
        (Clangd.to_compile_flags_txt main_args);

      display_section_sizes @@ Builder.Toolchain.size main_args.output
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

and display_section_sizes section_sizes =
  Ocolor_format.printf "[@{<blue> MEMORY USAGE @}] %s bytes\n\n"
    section_sizes.all;
  Ocolor_format.pp_print_flush Ocolor_format.std_formatter ();

  printf " .text  :        %s bytes\n" section_sizes.text;
  printf " .data  :        %s bytes\n" section_sizes.data;
  printf " .bss   :        %s bytes\n" section_sizes.bss

let command =
  Command.basic ~summary:"compile the current project"
    (let%map_open.Command root_dir =
       flag "-root-dir"
         (optional_with_default current_path string)
         ~doc:"path to project"
     and debug =
       flag "-debug" no_arg ~doc:"enable debug profile for compilation"
     and target = anon @@ maybe ("target" %: string) in
     compile_the_project ~root_dir ~target ~debug)
