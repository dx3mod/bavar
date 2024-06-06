open Core
open Bavar

let current_path = Core_unix.getcwd ()

let rec compile_the_project ~root_dir ~target ~debug () =
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
        (Clangd.to_compile_flags_txt ~config project)
    in

    match target with
    | Some "@clangd" -> generate_compile_flags_txt ()
    | Some _ -> failwith "invalid target value for build!"
    | None ->
        let result = Builder.build ~build_context ~project ~build_profile in
        display_section_sizes @@ Toolchain.size result.output;

        if config.dev.clangd_support then generate_compile_flags_txt ()
  with
  | Toolchain.Compilation_error code ->
      eprintf "\nFailed to compile the project: %d exit code.\n" code;
      exit code
  | Sys_error e ->
      eprintf "Sys_error. %s.\n" e;
      exit 1

and display_section_sizes section_sizes =
  let open Toolchain in
  Ocolor_format.printf "[@{<blue> MEMORY USAGE @}] %s bytes\n\n"
    section_sizes.all;
  Ocolor_format.pp_print_flush Ocolor_format.std_formatter ();

  printf " .text  :        %s bytes\n" section_sizes.text;
  printf " .data  :        %s bytes\n" section_sizes.data;
  printf " .bss   :        %s bytes\n" section_sizes.bss

let command =
  Command.basic ~summary:"compile the current project"
    ~readme:(fun () -> {|Targets: '@clangd'.|})
    (let%map_open.Command root_dir =
       flag "-root-dir"
         (optional_with_default current_path string)
         ~doc:"path to project"
     and debug =
       flag "-debug" no_arg ~doc:"enable debug profile for compilation"
     and target = anon @@ maybe ("@target" %: string) in
     compile_the_project ~root_dir ~target ~debug)
