type main_avr_project = {
  config : Project_config.t;
  source_files : string array;
  depends : avr_project_depend list;
}
[@@deriving show]

and avr_project_depend = {
  root_dir : string;
  source_files : string array;
  include_dirs : string list;
  depends : avr_project_depend list;
}

and project_kind = Firmware | Library

let is_lib_kind = function Library -> true | Firmware -> false

let project_kind_to_string = function
  | Library -> "library"
  | Firmware -> "firmware"
