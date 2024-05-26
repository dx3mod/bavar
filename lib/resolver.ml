open Base

type avr_project = { main : Project_unit.t; depends : Project_unit.t list }
[@@deriving show]

let rec resolve_avr_project (ctx : Build_context.t) =
  let globs = Util.globs ~path:(Build_context.source_dir ctx) in

  let c_files = globs [ "*.{c,cpp,cxx,s}"; "**/*.{c,cpp,cxx,s}" ] in
  let h_files = globs [ "*.{h,hpp,hxx}"; "**/*.{h,hpp,hxx}" ] in

  (* let c_files, c_includes =
       Array.partition_tf c_files ~f:(fun filename ->
           match String.rsplit2_exn ~on:'.' filename with
           | _, "s" -> true
           | name, _
             when String.equal (Stdlib.Filename.basename name) "main"
                  || String.equal (Stdlib.Filename.basename name) ctx.config.name
             ->
               true
           | name, _ -> Array.exists h_files ~f:(String.is_prefix ~prefix:name))
     in *)
  {
    main =
      Project_unit.make ~kind:(`Bavar ctx.config) ~path:ctx.root_dir
        ~files:c_files ~includes:(Array.concat [ h_files ]) ();
    depends = resolve_dependencies ctx;
  }

and resolve_dependencies (ctx : Build_context.t) =
  let resolve_dep depend_units = function
    | Dependency.Local path ->
        let path =
          (* FIXME: work only on Unix *)
          if String.is_prefix ~prefix:"/" path then path
          else Unix.realpath @@ Stdlib.Filename.concat ctx.root_dir path
        in

        if Stdlib.(Sys.file_exists @@ Filename.concat path "LabAvrProject") then
          let config_file_path = Stdlib.Filename.concat path "LabAvrProject" in
          let config =
            match Project_config.of_file config_file_path with
            | Ok config -> config
            | Error _ -> failwith "not parsed"
          in

          let avr_project =
            resolve_avr_project @@ Build_context.make ~root_dir:path ~config
          in
          avr_project.main :: List.append depend_units avr_project.depends
        else resolve_external_library path :: depend_units
    | _ -> failwith "not implement yet"
  in

  List.fold ctx.config.depends ~init:[] ~f:resolve_dep

and resolve_external_library path =
  Project_unit.make ~kind:`External ~path
    ~files:(Util.globs ~path [ "*.{c,cpp,cxx,s,o}" ])
    ()
