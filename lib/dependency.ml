type t = Local of string | GitHub of string | BitMap of string
[@@deriving show]

let parse input =
  if String.starts_with ~prefix:"https://github.com" input then GitHub input
  else Local input (* TODO: check *)
