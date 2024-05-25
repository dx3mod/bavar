# bavar

A domain-specific build system for AVR C/C++ projects with a strong opinion about how to build them.
It is developed as part of the [LabAvrPlatform](https://github.com/dx3mod/LabAvrPlatform) project, but can be used separately.

The project is currently in active development. :construction:

## Usage 

```console
$ bavar init lesson-twi
```


#### Project layout

```
.
├── LabAvrProject
└── src
    └── main.c
```

#### Add some fun

`main.c`
```c
#include <avr-i2c-library/twi/twi_master.h>

int main(void) {
  // code
}
```

`LabAvrProject`
```clojure
(name basic-project)
(target atmega328p 16mhz)

(depends
  https://github.com/Sovichea/avr-i2c-library/tree/master/twi)
```

#### Build and upload 

```console
$ bavar build @upload
```