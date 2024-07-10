open Core
open Project

let rec resolve_avr_project ctx : main_avr_project =
  let source_files =
    [ "*.{c,cpp,cxx,s}"; "**/*.{c,cpp,cxx,s}" ]
    |> Util.globs ~path:(Build_context.source_dir ctx)
  in

  {
    config = ctx.config;
    source_files;
    depends =
      List.map ctx.config.depends ~f:(function
        | Dependency.Local path -> resolve_depend ~root_dir:ctx.root_dir path
        | Dependency.Git url -> resolve_git_depend ~ctx url);
  }

and resolve_depend ~root_dir path =
  let path =
    (* FIXME: work only on Unix? *)
    if String.is_prefix ~prefix:"/" path then path
    else Caml_unix.realpath @@ Filename.concat root_dir path
  in

  match Util.get_config_filename_at_dir path with
  | Some _ ->
      (* resolve bavar-project *)
      let config = Util.read_project_config ~root_dir:path in
      let context = Build_context.make ~root_dir:path ~config in
      let project = resolve_avr_project context in

      {
        root_dir = path;
        source_files = project.source_files;
        include_dirs =
          [
            path;
            Build_context.source_dir context;
            Build_context.include_dir context;
          ];
        depends = project.depends;
      }
  | None ->
      (* resolve non bavar-project *)
      resolve_external_library path

and resolve_external_library root_dir =
  let glob_source_files =
    Util.globs [ "*.{c,cpp,cxx,s,o}"; "**/*.{c,cpp,cxx,s,o}" ]
  in

  match
    Util.globs ~path:root_dir [ "src"; "Src"; "Source"; "SRC"; "source" ]
  with
  | [| source_dir |] ->
      let source_dir = Filename.concat root_dir source_dir in

      {
        root_dir;
        source_files = glob_source_files ~path:source_dir;
        include_dirs =
          [ root_dir; source_dir; Filename.concat root_dir "include" ];
        depends = [];
      }
  | _ ->
      {
        root_dir;
        source_files = glob_source_files ~path:root_dir;
        include_dirs = [ root_dir ];
        depends = [];
      }

and resolve_git_depend ~ctx url =
  (* TODO: improve URL parsing *)
  let name = String.split ~on:'/' url |> List.last_exn in
  let depend_dir = Filename.concat (Build_context.build_dir ctx) name in

  if not @@ Sys_unix.file_exists_exn depend_dir then
    Toolchain.git_clone url ~to':depend_dir;

  resolve_external_library depend_dir
