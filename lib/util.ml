open Core

let globs ~path =
  let f files pattern =
    match
      Option.try_with @@ fun () ->
      Globlon.glob (Filename.concat path pattern) ~glob_brace:true
    with
    | None -> files
    | Some files' -> Array.append files' files
  in
  List.fold ~f ~init:[||]

let join_paths paths =
  List.reduce paths ~f:Filename.concat
  |> Option.value_exn ~message:"join_paths paths must be >= 2"
