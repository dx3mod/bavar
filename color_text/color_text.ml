(* https://gist.github.com/JBlond/2fea43a3049b38287e5e9cefc87b2124 *)

let normal = "\x1b[m"
let yellow = "\x1b[33m"
let red = "\x1b[31m"
let blue = "\x1b[34m"
let bold_blue = "\x1b[1;94m"
let green = "\x1b[32m"
let cyan = "\x1b[36m"
let magenta = "\x1b[35m"
let colorize p s = Printf.sprintf "%s%s%s" p s normal
let colorize_yellow = colorize yellow
let colorize_cyan = colorize cyan
let colorize_red = colorize red
let colorize_blue = colorize blue
let colorize_magenta = colorize magenta
let colorize_green = colorize green
let keyword_success = colorize_green "Success"
