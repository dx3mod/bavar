type t = { root_dir : string; config : Project_config.t }
[@@deriving show, make]

let source_dir ctx = Filename.concat ctx.root_dir ctx.config.layout.root_dir
