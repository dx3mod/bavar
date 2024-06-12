#!/usr/bin/env ocaml

open Printf

let outdir = ref ""
let speclist = [ ("-out", Arg.Set_string outdir, "<dir>") ]

let () =
  Arg.parse speclist ignore "build.dist.ml -out <dir>";

  if !outdir = "" then (
    print_endline "Set output directory for artifacts!";
    exit 1);

  let cwd = Sys.getcwd () in
  let exe_path = cwd ^ "/_build/default/bin/main.exe" in

  let cmd args =
    printf "[CMD] %s\n" args;
    flush stdout;

    match Sys.command args with
    | 0 -> ()
    | code ->
        printf "\nFailed to execute command: %d code!\n" code;
        exit code
  in

  cmd "dune build --profile=release";

  cmd @@ sprintf "rm -rf %s" !outdir;
  cmd @@ sprintf "mkdir %s" !outdir;
  Sys.chdir !outdir;

  cmd @@ "mkdir bin";

  cmd @@ sprintf "cp --no-preserve=mode,ownershi %s ./bin/" exe_path;
  cmd "strip ./bin/main.exe";
  cmd "chmod +x ./bin/main.exe";
  cmd "mv ./bin/main.exe ./bin/bavar";

  cmd "COMMAND_OUTPUT_INSTALLATION_BASH=1 ./bin/bavar > bavar-completion.sh";

  cmd @@ sprintf "cp %s/tools/* ./bin/" cwd;

  cmd "tree";
  printf "\nOpen: %s\n" !outdir
