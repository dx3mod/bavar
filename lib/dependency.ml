open Core

type t = Local of string | Git of string [@@deriving show]

exception Parse_error of { value : string; message : string }

(** Valid values:
   - local path
   - [https://github.com/*]
   - [http*.git]
*)
let parse input =
  let is_http_git_repo value =
    if String.is_prefix ~prefix:"http" value then
      if String.is_suffix ~suffix:".git" value then true
      else
        raise
        @@ Parse_error
             { value; message = "the dependency cannot be a URL address" }
    else false
  in

  if String.is_prefix ~prefix:"https://github.com" input then
    Git (input ^ ".git")
  else if is_http_git_repo input then Git input
  else Local input
