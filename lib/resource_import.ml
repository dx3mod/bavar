open Base

type t = Local of Fpath.t | Http of string [@@deriving ord, show]

open Option.Let_syntax

let rec parse_from_line line =
  (match match_include line with
  | Some path -> Some path
  | None -> match_require_macro line)
  >>| fun path ->
  if String.is_prefix path ~prefix:"http" then Http path
  else Local (Util.to_fpath_exn path)

and match_require_macro line =
  match_first require_macro_regexp_pattern line >>= match_quote

and match_include line =
  let open Option.Let_syntax in
  match_first include_regexp_pattern line >>= match_quote

and match_first pattern input =
  Re.exec_opt pattern input
  |> Option.bind ~f:(fun group -> Re.Group.get_opt group 0)

and match_quote input =
  let open Option.Let_syntax in
  match_first quote_regexp_pattern input >>| String.strip ~drop:(Char.equal '"')

and include_regexp_pattern = Re.Pcre.regexp {|^\s*require\s*\(\s*".*"\s*\)\s*$|}
and require_macro_regexp_pattern = Re.Pcre.regexp {|^\s*#include\s+".*"\s*$|}
and quote_regexp_pattern = Re.Pcre.regexp {|".*"|}
