open Core

exception Compilation_error of int

let cc ~cwd ~lang args =
  let prog = match lang with `C | `Asm -> "avr-gcc" | `Cpp -> "avr-g++" in

  Ocolor_format.printf "[@{<cyan> %s @}] %s\n\n" (String.uppercase prog)
    (String.concat ~sep:" " args);
  Ocolor_format.pp_print_flush Ocolor_format.std_formatter ();

  (* FIXME: works only on Linux/*nix now *)
  Spawn.spawn () ~cwd:(Spawn.Working_dir.Path cwd) ~prog:("/usr/bin/" ^ prog)
    ~argv:(prog :: args)
  |> Pid.of_int

let rec wait_compilation pid = Core_unix.wait (`Pid pid) |> handle_compilation

and handle_compilation (_, status) =
  Result.iter_error status ~f:(function
    | `Exit_non_zero code -> raise (Compilation_error code)
    | _ -> failwith "failed process status")

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

let ar_rcs ~output files =
  Ocolor_format.printf "[@{<cyan> AR RCS @}] %s %s\n\n" output
    (String.concat ~sep:" " files);
  Ocolor_format.pp_print_flush Ocolor_format.std_formatter ();

  let info =
    Core_unix.create_process ~prog:"avr-gcc-ar" ~args:("rcs" :: output :: files)
  in
  match snd @@ Core_unix.wait (`Pid info.pid) with
  | Ok () -> ()
  | _ -> failwith "fail ar rcs"
