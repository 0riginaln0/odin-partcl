package main

import "../partcl"
import "core:bufio"
import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
	ctx: partcl.Tcl
	partcl.init(&ctx)
	defer partcl.destroy(&ctx)

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
