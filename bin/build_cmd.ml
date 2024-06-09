open Core
open Bavar

let current_path = Core_unix.getcwd ()

let rec compile_the_project ~root_dir ~target ~debug ~clangd_support
    ~c_cpp_properties_support () =
  try
    let config = Util.read_project_config ~root_dir in
    let build_context = Build_context.make ~root_dir ~config in
    let build_profile = if debug then `Debug else `Release in

    let project = Resolver.resolve_avr_project build_context in

    Core_unix.mkdir_p @@ Build_context.output_dir build_context build_profile;

    target |> ignore;

    let generate_compile_flags_txt () =
      Out_channel.write_lines
        (Filename.concat root_dir "compile_flags.txt")
        (Integrations.Clangd.to_compile_flags_txt ~config project)
    in

    let generate_c_cpp_properties () =
      Core_unix.mkdir_p ".vscode";

      Out_channel.with_file ".vscode/c_cpp_properties.json" ~f:(fun ch ->
          Integrations.Vs_code.of_project ~config project
          |> Integrations.Vs_code.to_yojson
          |> Yojson.Safe.pretty_to_channel ch)
    in

    let build () =
      if config.dev.clangd_support || clangd_support then
        generate_compile_flags_txt ();

      let result = Builder.build ~build_context ~project ~build_profile in
      display_section_sizes @@ Toolchain.size result.output;

      if config.dev.vscode_support || c_cpp_properties_support then
        generate_c_cpp_properties ();

      result
    in

    let program output =
      Toolchain.avrdude ~programmer:config.program.programmer_id
        ~port:config.program.port ~firmware:(`Elf output) ()
    in

    match target with
    | Some "@compile_flags.txt" -> generate_compile_flags_txt ()
    | Some "@c_cpp_properties" -> generate_c_cpp_properties ()
    | Some "@upload" -> build () |> fun r -> program Builder.(r.output)
    | Some _ -> failwith "invalid target value for build!"
    | None -> build () |> ignore
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
  | Resolver.Resolve_error { message } ->
      eprintf "Failed to resolve project: %s!\n" message;
      exit 1
  | Dependency.Parse_error { value; message } ->
      eprintf "Invalid '%s' value: %s!\n" value message;
      exit 1
  | Sys_error e ->
      eprintf "Sys_error. %s.\n" e;
      exit 1

and display_section_sizes section_sizes =
  let open Toolchain in
  Ocolor_format.printf "\n[@{<blue> MEMORY USAGE @}] %s bytes\n\n"
    section_sizes.all;
  Ocolor_format.pp_print_flush Ocolor_format.std_formatter ();

  printf " .text  :        %s bytes\n" section_sizes.text;
  printf " .data  :        %s bytes\n" section_sizes.data;
  printf " .bss   :        %s bytes\n" section_sizes.bss

let command =
  Command.basic ~summary:"compile the current project"
    ~readme:(fun () -> {|Targets: '@compile_flags.txt', '@c_cpp_properties'.|})
    (let%map_open.Command root_dir =
       flag "-root-dir"
         (optional_with_default current_path string)
         ~doc:"path to project"
     and debug =
       flag "-debug" no_arg ~doc:"enable debug profile for compilation"
     and clangd_support =
       flag "-compile-flags" no_arg ~doc:"enable clangd config build"
     and c_cpp_properties_support =
       flag "-c-cpp-properties" no_arg
         ~doc:"enable vscode/c_cpp_properties.json config build"
     and target = anon @@ maybe ("@target" %: string) in
     compile_the_project ~root_dir ~target ~debug ~clangd_support
       ~c_cpp_properties_support)
