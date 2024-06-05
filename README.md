# bavar

A domain-specific build system for AVR C/C++ projects with a strong opinion about how to build them.

- Opinionated projects organization
- Build with resolution of external dependencies
  - Automatic inclusion of header files
  - Bundling resources into the firmware
- Firmware upload (powered by avrdude)

The project is currently in active development. :construction:

## Usage

Initialize a new AVR C project.

```console
$ bavar init -target attiny2313a blink
```

```
blink/
├── LabAvrProject
└── src
    └── main.c
```

Configuration file `LabAvrProject`.

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

#### From source

by [OPAM](https://opam.ocaml.org/) package manager.

```console
$ git clone https://github.com/dx3mod/bavar.git
$ opam install ./bavar
```

## Related

The project is being developed as part of the [LabAvrPlatform](https://github.com/dx3mod/LabAvrPlatform) platform.

## Contributing

1. Fork this repository
2. Create your feature branch
   (`git checkout -b feature/fooBar`)
3. Commit your changes and push to the branch
4. Create a new Pull Request

#### Development

Create virtual environment for project.

```console
$ opam create switch . --deps-only
```

Build the project.

```console
$ dune build
```
