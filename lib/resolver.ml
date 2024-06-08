open Core
open Project

exception Resolve_error of { message : string }

let rec resolve_avr_project (ctx : Build_context.t) =
  let globs = Util.globs ~path:(Build_context.source_dir ctx) in

  let c_files = globs [ "*.{c,cpp,cxx,s}"; "**/*.{c,cpp,cxx,s}" ] in
  let h_files = globs [ "*.{h,hpp,hxx}"; "**/*.{h,hpp,hxx}" ] in

  let c_files, c_includes =
    Array.partition_tf c_files ~f:(fun filename ->
        let path, _ = String.rsplit2_exn ~on:'.' filename in

        (* TODO: is slow? *)
        if
          String.is_suffix ~suffix:"main" path
          || String.is_suffix ~suffix:ctx.config.name path
        then true
        else
          Array.find h_files ~f:(String.is_prefix ~prefix:path)
          |> Option.is_some)
  in

  let root_dir = ctx.root_dir in

  let resources =
    resolver_resources ~root_dir:ctx.root_dir ctx.config.resources
  in

  {
    kind = `Bavar ctx.config;
    root_dir;
    files = c_files;
    includes = Array.concat [ h_files; c_includes ];
    depends = resolve_dependencies ~root_dir ctx.config.depends;
    resources;
  }

and resolve_dependencies ~root_dir (depends : Dependency.t list) =
  let resolve_local_dep path =
    let path =
      (* FIXME: work only on Unix? *)
      if String.is_prefix ~prefix:"/" path then path
      else Caml_unix.realpath @@ Filename.concat root_dir path
    in

    if
      Sys_unix.file_exists_exn
      @@ Filename.concat path Util.configuration_filename
    then
      let proj_avr =
        let config = Util.read_project_config ~root_dir:path in
        let build_context = Build_context.make ~root_dir:path ~config in
        resolve_avr_project build_context
      in

      proj_avr
    else resolve_external_library path
  in

  List.map depends ~f:(function
    | Dependency.Local path -> resolve_local_dep path
    | _ -> failwith "not implemented another dependency type yet!")

and resolve_external_library root_dir =
  let files = Util.globs ~path:root_dir [ "*.{c,cpp,cxx,s,o}" ] in
  Project.make_external ~root_dir ~files ()

and resolver_resources ~root_dir (resources : Project_config.resource list) =
  let open Project_config in
  let resolve_resource resource =
    let full_path = Filename.concat root_dir resource.path in

    if Sys_unix.is_file_exn full_path then full_path
    else
      raise
      @@ Resolve_error
           { message = sprintf "unknown '%s' resource path" resource.path }
  in

  List.map resources ~f:resolve_resource
