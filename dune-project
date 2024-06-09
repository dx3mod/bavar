(lang dune 3.15)

(name bavar)

(version 0.4.1)

(generate_opam_files true)

(source
 (github dx3mod/bavar))

(authors "Mihail Lopatin <dx3mod@bk.ru>")

; (maintainers "Maintainer Name")

(license MIT)

(documentation https://url/to/documentation)

(package
 (name bavar)
 (synopsis "AVR C/C++ project builder")
 (description "A domain-specific build system for AVR C/C++ projects")
 (depends
  ocaml
  dune
  core
  core_unix
  sexplib
  ppx_deriving
  decoders-sexplib
  re
  globlon
  spawn
  ocolor
  yojson
  ppx_deriving_yojson)
 (tags
  (labavrplatform avr build-system)))
