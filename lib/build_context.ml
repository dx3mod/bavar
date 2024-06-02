type t = { root_dir : string; config : Project_config.t }
[@@deriving show, make]

let source_dir ctx = Filename.concat ctx.root_dir ctx.config.layout.root_dir
let build_dir ctx = Filename.concat ctx.root_dir ctx.config.layout.out_dir

let output_dir ctx mode =
  Filename.concat (build_dir ctx)
    (match mode with `Debug -> "debug" | `Release -> "release")
