open Core

let commands =
  Command.group ~preserve_subcommand_order:()
    ~summary:"A domain-specific build system for AVR C/C++ projects."
    [ ("init", Init_cmd.command); ("build", Build_cmd.command) ]

let () = Command_unix.run commands
