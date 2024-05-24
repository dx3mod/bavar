open Base

type project_files = {
  include_files : string array;
  files : string array;
  resource_imports : Resource_import.t array;
}
[@@deriving show]

let rec resolve_project (ctx : Build_context.t) =
  let globs =
    Util.globs ~path:(Fpath.to_string @@ Build_context.source_dir ctx)
  in

  let c_files = globs [ "*.{c,cpp,cxx,s}"; "**/*.{c,cpp,cxx,s}" ] in
  let h_files = globs [ "*.{h,hpp,hxx}"; "**/*.{h,hpp,hxx}" ] in

  let resolve_resource_imports_of_files files =
    Array.map ~f:(resolve_resource_imports ctx) files
    |> Array.concat_map ~f:List.to_array
  in

  let imports =
    Array.append
      (resolve_resource_imports_of_files c_files)
      (resolve_resource_imports_of_files h_files)
  in

  let c_files, include_c_files =
    Array.partition_tf c_files ~f:(fun filename ->
        match String.rsplit2_exn ~on:'.' filename with
        | _, "s" -> true
        | name, _
          when String.equal (Stdlib.Filename.basename name) "main"
               || String.equal (Stdlib.Filename.basename name) ctx.config.name
          ->
            true
        | name, _ -> Array.exists h_files ~f:(String.is_prefix ~prefix:name))
  in

  {
    include_files = Array.append include_c_files h_files;
    files = c_files;
    resource_imports = imports;
  }

and resolve_resource_imports ctx filename =
  let source_dir = Build_context.source_dir ctx in

  let file = In_channel.open_text filename in
  let resource_imports =
    In_channel.fold_lines
      (fun resource_imports line ->
        match Resource_import.parse_from_line line with
        | Some resource_import -> (
            match resource_import with
            | Resource_import.Local path when Fpath.is_rel path ->
                let dirname = Fpath.parent @@ Util.to_fpath_exn filename in
                let path = Fpath.normalize @@ Fpath.(dirname // path) in
                if Fpath.is_prefix source_dir path then resource_imports
                else Resource_import.Local path :: resource_imports
            | import -> import :: resource_imports)
        | None -> resource_imports)
      [] file
  in

  In_channel.close file;
  resource_imports
