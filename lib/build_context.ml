type t = { root_dir : Fpath.t; config : Project_config.t } [@@deriving show]

let make ~root_dir ~config = { root_dir = Util.to_fpath_exn root_dir; config }
let source_dir ctx = Fpath.(ctx.root_dir / ctx.config.layout.root_dir)
