# bavar

A domain-specific build system for AVR C/C++ projects with a strong opinion about how to build them.

- Opinionated projects organization
- Build with resolution of external dependencies
  - Automatic inclusion of header files
  - Bundling resources into a firmware with some image conversions 
- Firmware upload (powered by avrdude)
- Integration with text editors (support generations)
  - compile_flags.txt for clangd
  - c_cpp_properties.json for VSCode C/C++ extension

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

```clojure
(name blink)
(target attiny2313a 1mhz)
```

Compile and upload the current project (compile in release by default and use usbasp programmer).

```console
$ bavar build @upload
```

[Read the user guide.](./GUIDE.md)

## Installation

This should already be installed on your system: AVR GCC toolchain for development projects, avrdude utility for uploading firmware to a microcontroller.

Optional requirements with additional features: Git for downloading a project's dependencies, Python3 (and PIL module) for image conventions.

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
See [Managing Dependencies With opam](https://ocaml.org/docs/managing-dependencies) for details. See also [development guide](./DEV.md).
