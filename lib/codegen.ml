open Core

let gen_resource_header ~name ~for':filename ~to':output =
  (* FIXME: read all file is bloat *)
  let resource_contents = In_channel.read_all filename in
  let variable_name =
    name
    |> String.substr_replace_all ~pattern:"_" ~with_:"_"
    |> String.substr_replace_all ~pattern:"." ~with_:"_"
    |> String.uppercase
  in

  let bytes =
    String.to_sequence resource_contents
    |> Sequence.map ~f:(Fn.compose (sprintf "0x%x") int_of_char)
    |> Sequence.fold ~init:"" ~f:(fun str byte ->
           String.append str @@ byte ^ ",")
  in

  Out_channel.write_all output
    ~data:
      (sprintf "const unsigned char %s[] PROGMEM = {%s};" variable_name bytes);

  ()
