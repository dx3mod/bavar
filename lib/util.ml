open Base

let globs ~path =
  let f files pattern =
    match
      Option.try_with @@ fun () ->
      Globlon.glob (Stdlib.Filename.concat path pattern) ~glob_brace:true
    with
    | None -> files
    | Some files' -> Array.append files' files
  in
  List.fold ~f ~init:[||]

let to_fpath_exn path =
  match Fpath.of_string path with
  | Error (`Msg msg) -> failwith msg
  | Ok path -> path
