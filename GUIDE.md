# User Guide

## Configuration file specification

Valid configuration file names: `LabAvrProject`, `avr-project`, `bavar`, `bavar-project`.

```clojure
(name <name>)
(target <mcu> <hz/n-mhz>?)
;; (target attiny13) | (target ... 1_000_000) | (target ... 1mhz)

(lang <standard>)
(strict <bool>) ; true by default

(build.debug <opts>) ; for debug
(build <opts>) ; for release
;; <opts>:
;;  O<n>          - optimization level
;;  lto           - enable lto (off for debug and on for release)
;;  (lto <bool>)
;;  no_std        - disable libc and set '_start' as entrypoint
;; (custom <...>) - custom user's arguments
;; intel_hex      - enable Intel HEX generation from ELF firmware
;; intermixed     - enable dissembled mix generation

(program.id <programmer-id>) ; usbasp by default
(program.port <path>)

(envs <key-value ...>) ; set defines
;; (envs (MAGIC_NUMBER 123) (SD x))

(depends <libraries>) ; import libraries for project
;; (libraries
;;   ./local/dir                    ; import local project
;;   https://github.com/user/repo)  ; auto-download from Internet
;;   http://192.168.0.0/private-repo.git

(resources <paths>) ; bundle resource files

(dev <opts>)
;; clangd or compile_flags.txt  - generate config for clangd
;; c_cpp_properties - generate config for vscode c/c++ extension
```

## Project Layout

- `_build` - artifact's directory
- `src/` - source files

## Resources

In configuration file.

```clojure
(resources image.bmp)
```

In code, you can reference the resource content using the `IMAGE_BMP` variable.

```c
IMAGE_BMP; // const unsigned char [] PROGMEM
```

## Depends

Allowable dependency values:

- Local paths (to be found from the root project directory)
- `https://github.com/*` (convert to `https://github.com/*.git`)
- `http*.git`

Remote dependencies are cloned into the `_build` directory. To update them, you need to clear the cache (remove the build directory).
