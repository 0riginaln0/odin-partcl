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