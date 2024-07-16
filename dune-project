(lang dune 3.15)

(name bavar)

(version 0.5.0)

(generate_opam_files true)

(source
 (github dx3mod/bavar))

(authors "Mikhail Lopatin <dx3mod@bk.ru>")

(maintainers "Mikhail Lopatin <dx3mod@bk.ru>")

(license MIT)

; (documentation https://url/to/documentation)

(package
 (name bavar)
 (synopsis "AVR C/C++ project builder")
 (description "A domain-specific build system for AVR C/C++ projects")
 (depends
  (ocaml
   (>= 5.2.0))
  dune
  (core
   (>= 0.16.2))
  core_unix
  sexplib
  ppx_deriving
  decoders-sexplib
  re
  globlon
  spawn
  yojson
  ppx_deriving_yojson)
 (tags
  (labavrplatform avr build-system)))
