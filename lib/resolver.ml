open Core
open Project

exception Resolve_error of { message : string }

let rec resolve_avr_project (ctx : Build_context.t) =
  let globs_src = Util.globs ~path:(Build_context.source_dir ctx) in
  let globs_include = Util.globs ~path:(Build_context.include_dir ctx) in

  let c_files = globs_src [ "*.{c,cpp,cxx,s}"; "**/*.{c,cpp,cxx,s}" ] in
  let h_files = globs_src [ "*.{h,hpp,hxx}"; "**/*.{h,hpp,hxx}" ] in
  let h_files' = globs_include [ "*.{h,hpp,hxx}"; "**/*.{h,hpp,hxx}" ] in

  let root_dir = ctx.root_dir in

  let resources =
    resolver_resources ~root_dir:ctx.root_dir ctx.config.resources
  in

  {
    kind = `Bavar ctx.config;
    root_dir;
    files = c_files;
    includes = Array.concat [ h_files; h_files' ];
    depends = resolve_dependencies ~ctx ctx.config.depends;
    resources;
  }

and resolve_dependencies ~(ctx : Build_context.t) (depends : Dependency.t list)
    =
  let resolve_local_depend path =
    let path =
      (* FIXME: work only on Unix? *)
      if String.is_prefix ~prefix:"/" path then path
      else Caml_unix.realpath @@ Filename.concat ctx.root_dir path
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

  let resolve_git_depend url =
    let name = String.split ~on:'/' url |> List.last_exn in
    let output = Filename.concat (Build_context.build_dir ctx) name in

    if not @@ Sys_unix.file_exists_exn output then
      Toolchain.git_clone url ~to':output;

    resolve_local_depend output
  in

  List.map depends ~f:(function
    | Dependency.Local path -> resolve_local_depend path
    | Dependency.Git url -> resolve_git_depend url)

and resolve_external_library root_dir =
  let source_dir =
    let matches =
      Util.globs ~path:root_dir [ "src"; "Src"; "Source"; "SRC"; "source" ]
    in
    match matches with
    | [||] -> None
    | [| path |] ->
        let files =
          Util.globs ~path [ "*.{c,cpp,cxx,s,o}"; "**/*.{c,cpp,cxx,s,o}" ]
        in
        Some (Project.make_external ~root_dir:path ~files ())
    | _ -> failwith "many source directories"
  in

  match source_dir with
  | Some project -> project
  | None ->
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
