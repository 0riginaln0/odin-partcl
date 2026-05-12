# partcl-odin

1. Compile tcl.c into static library:

```sh
cd tcl
```
```sh
clang -c -std=c99 -Os tcl.c -o tcl.o && ar rcs libpartcl.a tcl.o
```

2. Use it

