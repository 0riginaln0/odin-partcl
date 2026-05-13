// $ rlwrap odin run repl
package main

import "base:runtime"
import "../partcl"
import "core:bufio"
import "core:fmt"
import "core:os"
import "core:strings"

// Truthy values are all values except for "0" and empty string ""
cmd_true :: proc "c" (tcl: ^partcl.Tcl, args: partcl.Value, arg: rawptr) -> partcl.Control_Flow {	
	val := partcl.list_at(args, 1)
	defer partcl.free(val)
	
	truthy: bool
	s := partcl.string(val)
	if s == "" || s == "0" {
		truthy = false
	} else {
		truthy = true
	}

	return partcl.result(tcl, .FNORMAL, partcl.alloc(truthy ? "1" : "0", 1))
}

// I want to compare values, not only mathematical
cmd_equal :: proc "c" (tcl: ^partcl.Tcl, args: partcl.Value, arg: rawptr) -> partcl.Control_Flow {	
	val1 := partcl.list_at(args, 1)
	val2 := partcl.list_at(args, 2)
	defer partcl.free(val1)
	defer partcl.free(val2)

	equal := partcl.string(val1) == partcl.string(val2)

	return partcl.result(tcl, .FNORMAL, partcl.alloc(equal ? "1" : "0", 1))
}

main :: proc() {
	ctx: partcl.Tcl
	partcl.init(&ctx)
	defer partcl.destroy(&ctx)

	partcl.register(&ctx, "true?", cmd_true, 2, nil)
	partcl.register(&ctx, "equal?", cmd_equal, 3, nil)

	stdin_stream := os.to_stream(os.stdin)
	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, stdin_stream, context.temp_allocator)
	defer bufio.scanner_destroy(&scanner)

	script_builder: strings.Builder
	strings.builder_init(&script_builder)

	fmt.println("Enter text (type 'q' to quit). Empty line executes script.")

	for {
		fmt.printf("> ")

		if !bufio.scanner_scan(&scanner) do break

		line := bufio.scanner_text(&scanner)

		if line == "q" do break

		if line == "" {
			script := strings.to_cstring(&script_builder)
			result := partcl.eval(&ctx, script, len(script))

			if result != .FERROR {
				result_str := partcl.string(ctx.result)
				result_len := partcl.length(ctx.result)
				fmt.println(string(result_str), result_len)
			} else {
				fmt.println("Error evaluating script")
				err_str := partcl.string(ctx.result)
				err_len := partcl.length(ctx.result)
				if err_len > 0 {
					fmt.print("Error message: \"", string(err_str), "\"\n")
				}
			}

			strings.builder_reset(&script_builder)
		} else {
			strings.write_string(&script_builder, line)
			strings.write_rune(&script_builder, '\n')
		}
	}

	if err := bufio.scanner_error(&scanner); err != nil {
		fmt.eprintfln("Error scanning input: %v", err)
	}
}
