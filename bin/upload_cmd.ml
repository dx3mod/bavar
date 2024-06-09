open Core
open Bavar

let normalize_mcu mcu =
  let mcu = String.lowercase mcu in

  if String.is_suffix ~suffix:"a" mcu then
    String.slice mcu 0 (String.length mcu - 1)
  else mcu

let upload ~root_dir ~programmer ~port ~debug ~custom () =
  let config = Util.read_project_config ~root_dir in
  let build_profile = if debug then "debug" else "release" in

  let mcu =
    match config.target with
    | Some { mcu; _ } -> normalize_mcu mcu
    | _ -> failwith "for upload you must select mcu!"
  in

  let firmware =
    sprintf "%s/%s/%s/firmware.elf" root_dir config.layout.out_dir build_profile
  in

  let custom = Option.value_map custom ~default:[] ~f:(String.split ~on:' ') in

  try
    Toolchain.avrdude ~programmer ~port ~firmware:(`Elf firmware) ~custom ~mcu
      ()
  with Toolchain.Program_error code ->
    eprintf "\nFailed to program the project: %d exit code.\n" code;
    exit code

let command =
  Command.basic ~summary:"upload the project into microcontoller"
    (let%map_open.Command programmer =
       flag "-prog-id" ~doc:"programmer id"
         (optional_with_default "usbasp" string)
     and port = flag "-port" ~doc:" connection port" (optional string)
     and debug = flag "-debug" ~doc:"use debug artifact" no_arg
     and root_dir =
       flag "-root-dir" ~doc:"path to project"
         (optional_with_default (Sys_unix.getcwd ()) string)
     and custom = flag "-custom" ~doc:"string user's args" (optional string) in

     upload ~root_dir ~programmer ~port ~debug ~custom)
