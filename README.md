# partcl-odin

Odin bindings for the [ParTcl](https://github.com/zserge/partcl) -  a micro Tcl implementation.

References:
- The [post](https://zserge.com/posts/tcl-interpreter/) of the ParTcl author.
- [Tcl the Misunderstood](https://antirez.com/articoli/tclmisunderstood.html) article.

## My modifications to ParTcl

- Division by zero now safely returns 0 instead of crashing

## Tutorial


1. Compile tcl.c into static library:

```sh
cd tcl
```
```sh
gcc -c -std=c99 -O3 tcl.c -o tcl.o && ar rcs libpartcl.a tcl.o
```

MINGW64 shell was used to compile the ParTcl on Windows.

2. Use it

```odin
package main

import "base:runtime"
import "core:fmt"
import "partcl"

main :: proc() {
	ctx: partcl.Tcl

	partcl.init(&ctx)
	defer partcl.destroy(&ctx)

	partcl.register(&ctx, "custom_command", custom_command, 0, nil)

	script: cstring = `custom_command; set x 4; puts [+ [* $x 10] 2];`
	result := partcl.eval(&ctx, script, len(script))

	if result != .FERROR {
		result_str := partcl.string(ctx.result)
		result_len := partcl.length(ctx.result)
		fmt.println(string(result_str), result_len)
		fmt.println(partcl.int(ctx.result))
	} else {
		fmt.println("Error evaluating script")
	}
}

custom_command :: proc "c" (tcl: ^partcl.Tcl, args: partcl.Value, arg: rawptr) -> partcl.Control_Flow {
	context = runtime.default_context()
	fmt.println("Custom command called!")
	return .FNORMAL
}
```

3. More or less full ParTcl overview [main.odin](/main.odin).

4. Reference REPL implementation [repl.odin](/repl/repl.odin)


```powershell
> odin run repl
```

```sh
$ rlwrap odin run repl
```
