# bavar

A domain-specific build system for AVR C/C++ projects with a strong opinion about how to build them.
It is developed as part of the [LabAvrPlatform](https://github.com/dx3mod/LabAvrPlatform) project, but can be used separately.

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

You should already have the AVR GCC toolchain and the avrdude utility installed on your system. Bavar does not know how to manage environments for you.

And know only works on Linux/*nix systems.

#### From source

```console
$ git clone https://github.com/dx3mod/bavar.git
$ opam install ./bavar
```
