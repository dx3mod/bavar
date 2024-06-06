open Core
open Project_config

let strict_flags = [ "-Wall"; "-Wextra"; "-Wpedantic" ]
let default_include_headers = [ "avr/io.h"; "stdint.h"; "stddef.h" ]

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
