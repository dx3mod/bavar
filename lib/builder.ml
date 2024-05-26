open Base

let strict_flags = [| "-Wall"; "-Wextra"; "-Wpedantic" |]

type build_mode = Release | Debug

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

  let depend_files =
    List.fold project.depends ~init:[||] ~f:(fun files proj_unit ->
        match proj_unit.kind with
        | `External -> Array.append files proj_unit.files
        | `Bavar _ ->
            Array.concat
              [
                files;
                proj_unit.files;
                includes_to_cc_options proj_unit.includes;
              ])
  in

  let main_args =
    Array.concat
      [
        [| "avr-gcc" |];
        (* options *)
        (if is_cpp then [| "-x"; "c++" |] else [||]);
        Option.value_map ctx.config.target ~default:[||] ~f:(fun target ->
            match target with
            | { mcu; hz = Some hz } ->
                [| sprintf "-mmcu=%s" mcu; sprintf "-DF_CPU=%d" hz |]
            | { mcu; hz = None } -> [| sprintf "-mmcu=%s" mcu |]);
        (if ctx.config.strict then strict_flags else [||]);
        (if build_options.lto then [| "-flto" |] else [||]);
        (if build_options.no_std then [| "-e_start"; "-nostdlib" |] else [||]);
        [| sprintf "-O%c" build_options.opt_level |];
        build_options.custom |> Array.of_list;
        (* files *)
        includes_to_cc_options project.main.includes;
        project.main.files;
        depend_files;
        (* output *)
        [|
          "-o";
          sprintf "%s/%s/firmware.elf" ctx.config.layout.out_dir
            (match mode with Release -> "release" | Debug -> "debug");
        |];
      ]
  in

  [ main_args ]

and find_entry_file ~proj_name files =
  let check_ext = function
    | "c" -> `C
    | "cpp" | "cxx" -> `Cpp
    | _ -> failwith "invalid file ext!"
  in

  Array.find_map
    ~f:(fun filename ->
      match
        Base.String.rsplit2_exn ~on:'.' @@ Stdlib.Filename.basename filename
      with
      | "main", ext -> Some (`Executable, check_ext ext)
      | name, ext when String.equal name proj_name ->
          Some (`Library, check_ext ext)
      | _ -> None)
    files

and includes_to_cc_options =
  Array.fold ~init:[||] ~f:(fun files filename ->
      Array.append files [| "-include"; filename |])
