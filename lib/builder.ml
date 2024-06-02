open Core

let strict_flags = [ "-Wall"; "-Wextra"; "-Wpedantic" ]
let default_includes = [ "avr/io.h"; "stdint.h" ]

module Toolchain = struct
  let cc ~cwd ~cpp args =
    let prog = if cpp then "avr-g++" else "avr-gcc" in

    Ocolor_format.printf "[@{<cyan> %s @}] %s\n\n" (String.uppercase prog)
      (String.concat ~sep:" " args);
    Ocolor_format.pp_print_flush Ocolor_format.std_formatter ();

    (* FIXME: works only on Linux/*nix now *)
    Spawn.spawn () ~cwd:(Spawn.Working_dir.Path cwd) ~prog:("/usr/bin/" ^ prog)
      ~argv:(prog :: args)
    |> Caml_unix.waitpid []

  type section_sizes = {
    text : string;
    data : string;
    bss : string;
    all : string;
  }

  let size path =
    let values =
      Core_unix.open_process_in (sprintf "avr-size %s" path)
      |> In_channel.input_lines |> List.last_exn |> String.split ~on:' '
      |> List.filter_map ~f:(fun c ->
             if String.is_empty c then None else Some (Stdlib.String.trim c))
    in

    match values with
    | [ text; data; bss; dec; _ ] -> { text; data; bss; all = dec }
    | _ -> failwith "failed to parse avr-size output"
end

module Compiler_args = struct
  open Project_config

  type t = {
    target : target option;
    build_options : build_options;
    strict : bool;
    headers : string list;
    custom : string list;
    files : string array;
    includes : string array;
    output : string;
    debug : bool;
  }

  let make ~target ~build_options ~strict ~headers ~custom ~files ~includes
      ~output ~debug =
    {
      target;
      build_options;
      strict;
      headers;
      custom;
      files;
      includes;
      output;
      debug;
    }

  let of_target =
    let f = function
      | { mcu; hz = Some hz } ->
          [ sprintf "-mmcu=%s" (String.lowercase mcu); sprintf "-DF_CPU=%d" hz ]
      | { mcu; hz = None } -> [ sprintf "-mmcu=%s" (String.lowercase mcu) ]
    in
    Option.value_map ~default:[] ~f

  let of_headers = List.fold ~init:[] ~f:(fun list h -> "-I" :: h :: list)

  let of_build_options { lto; no_std; opt_level; _ } =
    List.concat
      [
        (if lto then [ "-flto" ] else []);
        (if no_std then [ "-e"; "_start"; "-nostdlib" ] else []);
        [ sprintf "-O%c" opt_level ];
      ]

  let to_args_options t =
    List.concat
      [
        of_target t.target;
        (if t.strict then strict_flags else []);
        (if t.debug then [ "-g" ] else []);
        of_build_options t.build_options;
        of_headers t.headers;
        of_headers default_includes;
        t.custom;
        t.build_options.custom;
      ]

  let to_includes =
    Array.fold ~init:[] ~f:(fun list h -> "-include" :: h :: list)

  let to_args t =
    List.concat
      [
        to_args_options t;
        (* files *)
        Array.to_list t.files;
        to_includes t.includes;
        [ "-o"; t.output ];
      ]
end

let rec compile ~(ctx : Build_context.t) (project : Resolver.avr_project) ~mode
    =
  let open Printf in
  let build_options, debug =
    match mode with
    | `Release -> (ctx.config.build.release, false)
    | `Debug -> (ctx.config.build.debug, true)
  in

  let is_cpp =
    let _proj_kind, lang =
      find_entry_file project.main.files ~proj_name:ctx.config.name
      |> Option.value_exn ~message:"not found entry point file at project!"
    in
    match lang with `C -> false | _ -> true
  in

  let output_dir = Build_context.output_dir ctx mode in

  let depends =
    let depend_args =
      Compiler_args.make ~target:ctx.config.target ~build_options
        ~strict:ctx.config.strict ~custom:[ "-c" ] ~debug
    in

    List.filter_map project.depends ~f:(fun proj_unit ->
        let hash_name = Stdlib.Digest.(to_hex @@ string proj_unit.path) in
        let output = sprintf "%s/%s.o" output_dir hash_name in

        let last_modification_time_of_files =
          Array.fold proj_unit.files ~init:0.0 ~f:(fun last_time filename ->
              Float.max last_time @@ (Core_unix.stat filename).st_mtime)
        in

        if
          Sys_unix.file_exists_exn output
          && Float.(
               (Core_unix.stat output).st_mtime
               > last_modification_time_of_files)
        then None
        else
          match proj_unit.kind with
          | `External ->
              Some
                (depend_args ~includes:[||] ~files:proj_unit.files
                   ~headers:[ proj_unit.path ] ~output)
          | _ -> failwith "not implement yet")
  in

  List.iter
    ~f:(fun args ->
      Toolchain.cc ~cpp:is_cpp ~cwd:ctx.root_dir (Compiler_args.to_args args)
      |> ignore)
    depends;

  let main_args =
    Compiler_args.make ~target:ctx.config.target ~build_options
      ~strict:ctx.config.strict
      ~headers:
        (List.append
           [
             project.main.path;
             Util.join_paths [ ctx.root_dir; ctx.config.layout.root_dir ];
           ]
           (List.map project.depends ~f:(fun p -> p.path)))
      ~custom:[]
      ~files:(Array.append project.main.files @@ find_object_files output_dir)
      ~includes:project.main.includes ~debug
      ~output:(sprintf "%s/firmware.elf" output_dir)
  in

  Toolchain.cc ~cwd:ctx.root_dir (Compiler_args.to_args main_args) ~cpp:is_cpp
  |> ignore;

  (main_args, depends)

and find_entry_file ~proj_name files =
  let check_ext = function
    | "c" -> `C
    | "cpp" | "cxx" -> `Cpp
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

and find_object_files path = Util.globs ~path [ "*.o" ]
