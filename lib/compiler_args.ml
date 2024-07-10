open Core
open Project_config
open Project

type t = string list

let strict_flags = [ "-Wall"; "-Wextra"; "-Wpedantic" ]

let default_include_headers =
  [ "avr/io.h"; "stdint.h"; "stddef.h"; "avr/pgmspace.h" ]

let of_target =
  let f = function
    | { mcu; hz = Some hz } ->
        [ sprintf "-mmcu=%s" (String.lowercase mcu); sprintf "-DF_CPU=%d" hz ]
    | { mcu; hz = None } -> [ sprintf "-mmcu=%s" (String.lowercase mcu) ]
  in
  Option.value_map ~default:[] ~f

let to_includes = Array.fold ~init:[] ~f:(fun list h -> "-include" :: h :: list)
let to_headers = List.fold ~init:[] ~f:(fun list h -> "-I" :: h :: list)

let of_build_options { lto; no_std; opt_level; _ } =
  List.concat
    [
      (if lto then [ "-flto" ] else []);
      (if no_std then [ "-e"; "_start"; "-nostdlib" ] else []);
      [ sprintf "-O%c" opt_level ];
    ]

let of_avr_project ~profile:(build_opts, is_debug) ~output
    (project : main_avr_project) =
  let rec depends_to_args =
    List.fold ~init:[] ~f:(fun args depend ->
        List.concat
          [
            args;
            List.of_array depend.source_files;
            to_headers depend.include_dirs;
            depends_to_args depend.depends;
          ])
  in

  let args =
    List.concat
      [
        of_target project.config.target;
        of_build_options build_opts;
        (if is_debug then [ "-g" ] else []);
        build_opts.custom;
        (if project.config.strict then strict_flags else []);
        (* default includes *)
        to_includes @@ List.to_array default_include_headers;
        (* output *)
        [ "-o"; output ];
        (* ... *)
        to_headers
          [
            ".";
            project.config.layout.root_dir;
            project.config.layout.headers_dir;
          ];
        List.of_array project.source_files;
        depends_to_args project.depends;
      ]
  in

  args
