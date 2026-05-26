# GCC Linux Hardened Variants

Builds three ELF executables from the same source with increasingly hardened
GCC/linker flags:

- `gcc_linux_baseline`
- `gcc_linux_relro_pie`
- `gcc_linux_hardened_lto`

```sh
sh build.sh build
```
