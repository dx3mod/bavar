# Development guide

## To-Do

- [ ] Improve artifact names (now it's the MD5 hash of the path)
- [ ] Improve error handling
- Move to cross-platform
  - [ ] Rewrite Unix-dependent parts of the code
- Fix performance issues
  - [ ] resources generation code
  - [ ] resolver
  - [ ] parallel dependency building (now it's blocked by the wait pid function)
- [ ] Images conversion (aka [image2cpp](https://github.com/javl/image2cpp))
  - [x] naive horizontal 1 bit conversion
- [ ] Integrate simulation (powered by simavr)
- [ ] Advance support debugging features
- [ ] Improve dependencies solver
  - [ ] Control version of depend
- [ ] Write tutorials

## Build prebuilt binaries

```console
$ ./build.dist.ml -out <dir>
```
