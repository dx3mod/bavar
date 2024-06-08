type avr_project = {
  kind : [ `Bavar of Project_config.t | `External ];
  root_dir : string;
  includes : string array; [@default [||]]
  files : string array; [@default [||]]
  depends : avr_project list; [@default []]
  resources : string list; [@default []]
}
[@@deriving show, make]

let make_external = make_avr_project ~kind:`External
