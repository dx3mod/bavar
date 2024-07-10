open Core

module Resource = struct
  let variable_name filename =
    filename
    |> String.substr_replace_all ~pattern:"_" ~with_:"_"
    |> String.substr_replace_all ~pattern:"." ~with_:"_"
    |> String.uppercase

  let format_variable ~name ~data =
    sprintf "static const unsigned char %s[] PROGMEM = {%s};" name data

  let generate_binary ~name ~for':filename ~to':output =
    (* FIXME: read all file is bloat *)
    let resource_contents = In_channel.read_all filename in

    let char_to_hex = Fn.compose (sprintf "0x%x") int_of_char in

    let data =
      resource_contents
      |> String.fold ~init:"" ~f:(fun str byte ->
             String.append str @@ (char_to_hex byte) ^ ",")
    in

    Out_channel.write_all output
      ~data:(format_variable ~name:(variable_name name) ~data);

    ()

  let generate_bmp1bit ~name ~for':filename ~to':output =
    let data = Toolchain.bmp2bit [ filename ] |> List.hd_exn in

    Out_channel.write_all output
      ~data:(format_variable ~name:(variable_name name) ~data);

    ()
end
