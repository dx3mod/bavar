open Core

let strict_flags = [| "-Wall"; "-Wextra"; "-Wpedantic" |]

type build_mode = Release | Debug

let rec cc_args ~files ~includes ~options ~target ~strict ~output ~headers
    ~custom =
  let open Printf in
  let open Project_config in
  Array.concat
    [
      (* options *)
      Option.value_map target ~default:[||] ~f:(fun target ->
          match target with
          | { mcu; hz = Some hz } ->
              [| sprintf "-mmcu=%s" mcu; sprintf "-DF_CPU=%d" hz |]
          | { mcu; hz = None } -> [| sprintf "-mmcu=%s" mcu |]);
      (if strict then strict_flags else [||]);
      (if options.lto then [| "-flto" |] else [||]);
      (if options.no_std then [| "-e"; "_start"; "-nostdlib" |] else [||]);
      [| sprintf "-O%c" options.opt_level |];
      List.map headers ~f:(sprintf "-I%s") |> List.to_array;
      custom;
      (* files *)
      files;
      includes_to_cc_options includes;
      (* output *)
      [| "-o"; output |];
    ]

and includes_to_cc_options =
  Array.fold ~init:[||] ~f:(fun files filename ->
      Array.append files [| "-include"; filename |])

let rec build (ctx : Build_context.t) (project : Resolver.avr_project) mode =
  let open Printf in
  let build_options =
    match mode with
    | Release -> ctx.config.build.release
    | Debug -> ctx.config.build.debug
  in

  let _proj_kind, lang =
    find_entry_file project.main.files ~proj_name:ctx.config.name
    |> Option.value_exn ~message:"not found entry point file at project!"
  in

  let is_cpp = match lang with `C -> false | _ -> true in

  let build_dir =
    Filename.concat ctx.root_dir
    @@ Filename.concat ctx.config.layout.out_dir
         (match mode with Release -> "release" | Debug -> "debug")
  in

  let cc_depend_unit =
    cc_args ~options:build_options ~target:ctx.config.target
      ~strict:ctx.config.strict ~custom:[| "-c" |]
  in

  let depends =
    List.filter_map project.depends ~f:(fun proj_unit ->
        let hash_name = Stdlib.Digest.(to_hex @@ string proj_unit.path) in
        let output = sprintf "%s/%s.o" build_dir hash_name in

        (* TODO: implement more advance *)
        if Stdlib.Sys.file_exists output then None
        else
          match proj_unit.kind with
          | `External ->
              Some
                (cc_depend_unit ~includes:[||] ~files:proj_unit.files
                   ~headers:[ proj_unit.path ] ~output)
          | _ -> failwith "not implement yet")
  in

  List.iter
    ~f:(fun args ->
      cc ~cpp:is_cpp ~cwd:ctx.root_dir ~args:(List.of_array args) |> ignore)
    depends;

  let main_args =
    Array.concat
      [
        cc_args ~files:project.main.files ~includes:project.main.includes
          ~options:build_options ~target:ctx.config.target
          ~strict:ctx.config.strict ~headers:[ project.main.path ] ~custom:[||]
          ~output:
            (sprintf "%s/%s/firmware.elf" ctx.config.layout.out_dir
               (match mode with Release -> "release" | Debug -> "debug"));
        List.to_array build_options.custom;
        find_object_files build_dir;
      ]
  in

  cc ~cwd:ctx.root_dir ~args:(List.of_array main_args) ~cpp:is_cpp |> ignore;

  List.append [ main_args ] depends

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

and cc ~cwd ~args ~cpp =
  let prog = if cpp then "avr-g++" else "avr-gcc" in

  Spawn.spawn () ~cwd:(Spawn.Working_dir.Path cwd) ~prog:("/usr/bin/" ^ prog)
    ~argv:(prog :: args)
  |> Caml_unix.waitpid []
