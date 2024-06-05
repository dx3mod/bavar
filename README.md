# bavar

A domain-specific build system for AVR C/C++ projects with a strong opinion about how to build them.

- Opinionated projects organization
- Build with resolution of external dependencies
  - Automatic inclusion of header files
  - Bundling resources into the firmware
- Firmware upload (powered by avrdude)
- Integration (support generation compile_flags.txt)

The project is currently in active development. :construction:

## Usage

Initialize a new AVR C project.

```console
$ bavar init -target attiny2313a blink
```

```
blink/
├── avr-project
└── src
    └── main.c
```

Configuration file `avr-project`.

```lisp
(name blink)
(target attiny2313a 1mhz)
```

Compile the current project (release by default).

```console
$ bavar build
```

[Read the user guide.](./GUIDE.md)

## Installation

This should already be installed on your system:

- AVR GCC toolchain (for compile)
- avrdude utility (for upload firmware to mcu)
- Git (optional) (for download a project's dependencies)

#### Prebuilt binaries

To get prebuilt binaries, see the [releases page](https://github.com/dx3mod/bavar/releases).

#### Build from source

using [OPAM](https://opam.ocaml.org/) package manager.

```console
$ git clone https://github.com/dx3mod/bavar.git
$ opam install ./bavar
```

## Related

The project is being developed as part of the [LabAvrPlatform](https://github.com/dx3mod/LabAvrPlatform) platform.

## Development

bavar written in modern OCaml 5 with use Dune build-system and OPAM package manager.

```bash
# Create virtual environment for project.
$ opam create switch . --deps-only
# Build the project.
$ dune build
```
