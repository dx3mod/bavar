type avr_project = { main : Project_unit.t; depends : Project_unit.t list }
[@@deriving show]

let rec resolve_avr_project (ctx : Build_context.t) =
  let globs = Util.globs ~path:(Build_context.source_dir ctx) in

  let c_files = globs [ "*.{c,cpp,cxx,s}"; "**/*.{c,cpp,cxx,s}" ] in
  let h_files = globs [ "*.{h,hpp,hxx}"; "**/*.{h,hpp,hxx}" ] in

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
          if String.starts_with ~prefix:"/" path then path
          else Unix.realpath @@ Filename.concat ctx.root_dir path
        in

        if Sys.file_exists @@ Filename.concat path "LabAvrProject" then
          let config_file_path = Filename.concat path "LabAvrProject" in
          let config = Project_config.of_file config_file_path in

          let avr_project =
            resolve_avr_project @@ Build_context.make ~root_dir:path ~config
          in
          avr_project.main :: List.append depend_units avr_project.depends
        else resolve_external_library path :: depend_units
    | _ -> failwith "not implement yet"
  in

  List.fold_left resolve_dep [] ctx.config.depends

and resolve_external_library path =
  Project_unit.make ~kind:`External ~path
    ~files:(Util.globs ~path [ "*.{c,cpp,cxx,s,o}" ])
    ()
