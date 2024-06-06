open Core
open Project

type build_unit = {
  root_dir : string;
  args : string list;
  depends : build_unit list;
  last_modify_time : float;
}
[@@deriving show]

let rec to_build_unit (project : avr_project) =
  let last_modify_time =
    Array.fold project.files ~init:0.0 ~f:(fun last_time filename ->
        Float.max last_time @@ (Core_unix.stat filename).st_mtime)
  in

  let make_build_unit ~depends ~headers =
    {
      root_dir = project.root_dir;
      args =
        List.concat
          [
            Compiler_args.to_headers headers;
            Compiler_args.to_includes project.includes;
            Array.to_list project.files;
          ];
      depends;
      last_modify_time;
    }
  in

  match project.kind with
  | `External -> make_build_unit ~depends:[] ~headers:[]
  | `Bavar config ->
      make_build_unit
        ~depends:(List.map project.depends ~f:to_build_unit)
        ~headers:
          (project.root_dir
          :: Filename.concat project.root_dir config.layout.root_dir
          :: List.map project.depends ~f:(fun p -> p.root_dir))

let rec find_last_modify_time (build_unit : build_unit) =
  let last_time = build_unit.last_modify_time in
  match build_unit.depends with
  | [] -> last_time
  | depends ->
      List.fold depends ~init:last_time ~f:(fun last_time u ->
          Float.max last_time (find_last_modify_time u))

type build_result = { output : string }

let build ~(build_context : Build_context.t) ~(project : avr_project)
    ~build_profile =
  let build_opts, is_debug =
    match build_profile with
    | `Release -> (build_context.config.build.release, false)
    | `Debug -> (build_context.config.build.debug, true)
  in
  let output_dir = Build_context.output_dir build_context build_profile in
  let kind, lang =
    Util.find_entry_file_exn ~proj_name:build_context.config.name project.files
  in

  let make_args ~output ?(custom = []) args =
    List.concat
      [
        Compiler_args.of_target build_context.config.target;
        Compiler_args.of_build_options build_opts;
        (if is_debug then [ "-g" ] else []);
        build_opts.custom;
        custom;
        (if build_context.config.strict then Compiler_args.strict_flags else []);
        Compiler_args.to_includes
        @@ List.to_array Compiler_args.default_include_headers;
        [ "-o"; output ];
        args;
      ]
  in

  let rec build_depends (depends : build_unit list) =
    List.map depends ~f:(fun build_unit ->
        let hashed_name = Md5.(to_hex @@ digest_string build_unit.root_dir) in
        let output_obj_path = sprintf "%s/%s.o" output_dir hashed_name in
        let output_a_path = sprintf "%s/%s.a" output_dir hashed_name in

        let depends = build_depends build_unit.depends in

        let last_output_a_modify =
          if Sys_unix.file_exists_exn output_a_path then
            (Core_unix.stat output_a_path).st_mtime
          else 0.0
        in

        if Float.(last_output_a_modify < find_last_modify_time build_unit) then (
          let args =
            make_args ~output:output_obj_path ~custom:[ "-c" ] build_unit.args
          in

          Toolchain.cc ~cwd:build_unit.root_dir ~lang args
          |> Toolchain.wait_compilation;

          Toolchain.ar_rcs ~output:output_a_path
          @@ List.append [ output_obj_path ] depends);

        output_a_path)
  in

  let build_unit = to_build_unit project in

  let output =
    match kind with
    | `Executable ->
        let output = sprintf "%s/firmware.elf" output_dir in
        Toolchain.cc ~cwd:build_unit.root_dir ~lang
          (List.concat [ build_unit.args; build_depends build_unit.depends ]
          |> make_args ~output)
        |> Toolchain.wait_compilation;

        output
    | `Library ->
        let output_o = sprintf "%s/%s.o" output_dir build_context.config.name in
        let output_a = sprintf "%s/%s.a" output_dir build_context.config.name in

        let depends = build_depends build_unit.depends in

        Toolchain.cc ~cwd:build_unit.root_dir ~lang
          (make_args ~output:output_o build_unit.args)
        |> Toolchain.wait_compilation;

        Toolchain.ar_rcs ~output:output_a @@ List.append [ output_o ] depends;

        output_a
  in

  { output }
