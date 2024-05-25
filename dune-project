(lang dune 3.15)

(name bavar)

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
 (depends ocaml dune sexplib ppx_deriving decoders-sexplib re globlon base)
 (tags
  (labavrplatform avr build-system)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
