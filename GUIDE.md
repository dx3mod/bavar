# User Guide

## LabAvrProject file specification

```clojure
(name <name>)
(target <mcu> <hz/n-mhz>?)
;; (target attiny13) | (target ... 1_000_000) | (target ... 1mhz)

(lang <standard>)
(strict <bool>)

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
```

## Project Layout

- `_build` - artifact's directory
- `src/` - source files
