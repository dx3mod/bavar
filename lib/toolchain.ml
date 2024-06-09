open Core

exception Compilation_error of int

let cc ~cwd ~lang args =
  let prog = match lang with `C | `Asm -> "avr-gcc" | `Cpp -> "avr-g++" in

  Util.print_command_log ~prog:(String.uppercase prog) args;

  (* FIXME: works only on Linux/*nix now *)
  Spawn.spawn () ~cwd:(Spawn.Working_dir.Path cwd) ~prog:"/usr/bin/env"
    ~argv:("/usr/bin/env" :: prog :: args)
  |> Pid.of_int

let rec wait_compilation pid = Core_unix.wait (`Pid pid) |> handle_compilation

and handle_compilation (_, status) =
  Result.iter_error status ~f:(function
    | `Exit_non_zero code -> raise (Compilation_error code)
    | _ -> failwith "failed compilation process")

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

exception Program_error of int

let avrdude ~programmer ~port ~firmware ?(custom = []) () =
  let args =
    List.concat
      [
        [
          "-c";
          programmer;
          (match firmware with `Elf path -> sprintf "-Uflash:w:%s:e" path);
        ];
        Option.value_map port ~default:[] ~f:(fun port -> [ "-P"; port ]);
        custom;
      ]
  in

  Util.print_command_log ~prog:"AVRDUDE" args;

  (* FIXME: it's works only on *nix *)
  let pid =
    Spawn.spawn () ~prog:"/usr/bin/env"
      ~argv:("/usr/bin/env" :: "avrdude" :: args)
  in

  match snd @@ Caml_unix.waitpid [] pid with
  | WEXITED 0 -> ()
  | WEXITED code -> raise (Program_error code)
  | _ -> failwith "failed avrdude program process"

exception Git_clone_error of int

let git_clone url ~to' =
  let args = [ "git"; "clone"; url; to' ] in

  Util.print_command_log ~prog:"GIT" args;

  let pid =
    Spawn.spawn () ~prog:"/usr/bin/env" ~argv:("/usr/bin/env" :: args)
  in

  let _, status = Caml_unix.waitpid [] pid in
  match status with
  | WEXITED 0 -> ()
  | WEXITED code -> raise @@ Git_clone_error code
  | _ -> failwith "failed git clone process"

let bmp2bit paths =
  Util.print_command_log ~prog:"BMP2BIT" paths;

  let ch =
    Core_unix.open_process_in
      (sprintf "bavar-bmp2bit %s" @@ String.concat ~sep:" " paths)
  in

  let lines = In_channel.input_lines ch in

  In_channel.close ch;

  lines
