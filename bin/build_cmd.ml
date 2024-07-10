open Core
open Bavar

let current_path = Core_unix.getcwd ()

let rec compile_the_project ~root_dir ~target ~debug () =
  try
    let root_dir = Caml_unix.realpath root_dir in
    let config = Util.read_project_config ~root_dir in

    let build () =
      let build_context = Build_context.make ~root_dir ~config in
      let build_profile = if debug then `Debug else `Release in

      let main_project = Project_resolver.resolve_avr_project build_context in
      let output_dir = Build_context.output_dir build_context build_profile in

      let build_opts =
        match build_profile with
        | `Release -> main_project.config.build.release
        | `Debug -> main_project.config.build.debug
      in

      let kind, lang =
        match
          Util.detect_project_type ~proj_name:build_context.config.name
            main_project.source_files
        with
        | Some (kind, lang) -> (kind, lang)
        | None ->
            Util.exit_with_message "Not found any entrypoint at the project!\n"
      in

      let output, build_opts =
        match kind with
        | `Executable ->
            (* executable projects must be have specific target *)
            if Option.is_none config.target then
              Util.exit_with_message
                "Failed to build a project without a specific target!";

            ( Filename.concat output_dir "firmware.elf",
              (* force disable lto for library *)
              { build_opts with lto = false } )
        | `Library ->
            (Filename.concat output_dir (sprintf "%s.o" config.name), build_opts)
      in

      let compiler_args =
        let profile = (build_opts, debug) in
        Compiler_args.of_avr_project ~profile ~output main_project
      in

      Core_unix.mkdir_p output_dir;
      Toolchain.cc ~cwd:root_dir ~lang compiler_args
      |> Toolchain.wait_compilation;

      (* В случае если не получилось создать бинарник, но компиляция завершилась успешно. Например, при использовании --syntax-only.dun *)
      if Sys_unix.file_exists_exn output then (
        let section_sizes = Toolchain.size output in
        display_section_sizes section_sizes;
        Some output)
      else None
    in

    let program output =
      let mcu =
        match config.target with
        | Some { mcu; _ } -> Upload_cmd.normalize_mcu mcu
        | _ -> Util.exit_with_message "\nFor upload you must select MCU!"
      in

      Toolchain.avrdude ~programmer:config.program.programmer_id ~mcu
        ~port:config.program.port ~firmware:(`Elf output) ()
    in

    match target with
    | None -> build () |> ignore
    | Some "@upload" -> Option.iter ~f:program (build ())
    | _ -> Util.exit_with_message "Unknown build's argument!"
  with
  | Toolchain.Compilation_error code ->
      eprintf "\nFailed to compile the project: %d exit code.\n" code;
      exit code
  | Toolchain.Program_error code ->
      eprintf "\nFailed to program the project: %d exit code.\n" code;
      exit code
  | Toolchain.Git_clone_error code ->
      eprintf "Failed to clone Git repository: %d exit code.\n" code;
      exit code
  | Dependency.Parse_error { value; message } ->
      eprintf "Invalid '%s' value: %s!\n" value message;
      exit 1
  | Sys_error e ->
      eprintf "Sys_error. %s.\n" e;
      exit 1

and display_section_sizes section_sizes =
  let open Toolchain in
  printf "\n[ %s ] %s bytes\n\n"
    (Color_text.colorize_blue "MEMORY USAGE")
    section_sizes.all;

  printf " .text  :        %s bytes\n" section_sizes.text;
  printf " .data  :        %s bytes\n" section_sizes.data;
  printf " .bss   :        %s bytes\n" section_sizes.bss;
  Out_channel.flush stdout

let command =
  Command.basic ~summary:"compile the current project"
    (let%map_open.Command root_dir =
       flag "-root-dir"
         (optional_with_default current_path string)
         ~doc:"path to project"
     and debug =
       flag "-debug" no_arg ~doc:"enable debug profile for compilation"
     and target = anon @@ maybe ("@target" %: string) in
     compile_the_project ~root_dir ~target ~debug)
