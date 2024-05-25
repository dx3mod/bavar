type t = {
  kind : [ `Bavar of Project_config.t | `External ];
  path : string;
  includes : string array; [@default [||]]
  files : string array; [@default [||]]
}
[@@deriving show, make]
