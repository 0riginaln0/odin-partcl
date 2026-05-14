// $ rlwrap odin run repl
package main

import "../partcl"
import "base:runtime"
import "core:bufio"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"

// Truthy values are all values except for "0" and empty string ""
cmd_true :: proc "c" (tcl: ^partcl.Tcl, args: partcl.Value, arg: rawptr) -> partcl.Control_Flow {
	val := partcl.list_at(args, 1)
	defer partcl.free(val)

	truthy: bool
	s := partcl.to_string(val)
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

	equal := partcl.to_string(val1) == partcl.to_string(val2)

	return partcl.result(tcl, .FNORMAL, partcl.alloc(equal ? "1" : "0", 1))
}

// Set your favourite prompt!
//  >
//  =>
//  $
//  %
//  >>>
//  partcl>
cmd_change_prompt :: proc "c" (
	tcl: ^partcl.Tcl,
	args: partcl.Value,
	arg: rawptr,
) -> partcl.Control_Flow {
	new_prompt_val := partcl.list_at(args, 1)
	defer partcl.free(new_prompt_val)

	context = runtime.default_context()
	new_prompt_odin := strings.clone_from_cstring(partcl.to_string(new_prompt_val))

	prompt_ptr := cast(^string)arg
	prompt_ptr^ = new_prompt_odin

	return partcl.result(tcl, .FNORMAL, partcl.alloc("", 0))
}

prompt: string = ">"

// Extension for floating point math support
to_f64 :: proc "c" (val: partcl.Value) -> (res: f64) {
	if val == nil do return
	context = runtime.default_context()
	str_val := partcl.to_string(val)
	res = strconv.parse_f64(string(str_val)) or_else 0
	return
}

cmd_fmath :: proc "c" (tcl: ^partcl.Tcl, args: partcl.Value, arg: rawptr) -> partcl.Control_Flow {
	cmd_val := partcl.list_at(args, 0)
	a_val := partcl.list_at(args, 1)
	b_val := partcl.list_at(args, 2)
	defer partcl.free(cmd_val)
	defer partcl.free(a_val)
	defer partcl.free(b_val)

	cmd := partcl.to_string(cmd_val)
	a := to_f64(a_val)
	b := to_f64(b_val)

	buf: [64]byte
	res: f64 = 0
	is_comparison := false
	bool_result: bool

	switch cmd {
		case "+.": res = a + b
		case "-.": res = a - b
		case "*.": res = a * b
		case "/.":
			if b == 0 {
				return partcl.result(tcl, .FERROR, partcl.alloc("division by zero", 16))
			}
			res = a / b
		case ">.":  bool_result = a > b;  is_comparison = true
		case "<.":  bool_result = a < b;  is_comparison = true
		case ">=.": bool_result = a >= b; is_comparison = true
		case "<=.": bool_result = a <= b; is_comparison = true
		case "==.": bool_result = a == b; is_comparison = true
		case "!=.": bool_result = a != b; is_comparison = true
	}

	if is_comparison {
		return partcl.result(tcl, .FNORMAL, partcl.alloc(bool_result ? "1" : "0", 1))
	}
	context = runtime.default_context()
	n := fmt.bprintf(buf[:], "%g", res)
	fmt.println(n, len(n))
	return partcl.result(tcl, .FNORMAL, partcl.alloc(cstring(&buf[0]), len(n)))
}

main :: proc() {
	track: mem.Tracking_Allocator; mem.tracking_allocator_init(&track, context.allocator)
	temp_track: mem.Tracking_Allocator; mem.tracking_allocator_init(&temp_track, context.temp_allocator)
	context.allocator = mem.tracking_allocator(&track)
	context.temp_allocator = mem.tracking_allocator(&temp_track)
	defer review_tracking_allocators(&track, &temp_track)

	ctx: partcl.Tcl
	partcl.init(&ctx)
	defer {fmt.println("destroying..."); partcl.destroy(&ctx)}

	partcl.register(&ctx, "true?", cmd_true, 2, nil)
	partcl.register(&ctx, "equal?", cmd_equal, 3, nil)
	partcl.register(&ctx, "change-prompt", cmd_change_prompt, 2, &prompt)

	partcl.register(&ctx, "+.",  cmd_fmath, 3, nil)
	partcl.register(&ctx, "-.",  cmd_fmath, 3, nil)
	partcl.register(&ctx, "*.",  cmd_fmath, 3, nil)
	partcl.register(&ctx, "/.",  cmd_fmath, 3, nil)
	partcl.register(&ctx, ">.",  cmd_fmath, 3, nil)
	partcl.register(&ctx, ">=.", cmd_fmath, 3, nil)
	partcl.register(&ctx, "<.",  cmd_fmath, 3, nil)
	partcl.register(&ctx, "<=.", cmd_fmath, 3, nil)
	partcl.register(&ctx, "==.", cmd_fmath, 3, nil)
	partcl.register(&ctx, "!=.", cmd_fmath, 3, nil)

	stdin_stream := os.to_stream(os.stdin)
	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, stdin_stream, context.temp_allocator)

	script_builder: strings.Builder
	strings.builder_init(&script_builder)
	defer strings.builder_destroy(&script_builder)

	fmt.println("Enter text (type 'q' to quit). Empty line executes script.")

	for {
		defer free_all(context.temp_allocator)
		fmt.printf("%s ", prompt)

		if !bufio.scanner_scan(&scanner) do break

		line := bufio.scanner_text(&scanner)

		if line == "q" do break

		if line == "" {
			script := strings.to_cstring(&script_builder)
			result := partcl.eval(&ctx, script, len(script))

			if result != .FERROR {
				result_str := partcl.to_string(ctx.result)
				result_len := partcl.length(ctx.result)
				fmt.println(string(result_str), result_len)
			} else {
				fmt.println("Error evaluating script")
				err_str := partcl.to_string(ctx.result)
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

review_tracking_allocators :: proc(track, temp_track: ^mem.Tracking_Allocator) {
	if len(track.allocation_map) > 0 {
		fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
		for _, entry in track.allocation_map {
			fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
		}
	}
	if len(track.bad_free_array) > 0 {
		fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
		for entry in track.bad_free_array {
			fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
		}
	}
	mem.tracking_allocator_destroy(track)

	if len(temp_track.allocation_map) > 0 {
		fmt.eprintf("=== %v temp allocations not freed:!!! ===\n", len(temp_track.allocation_map))
		for _, entry in temp_track.allocation_map {
			fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
		}
	}
	if len(temp_track.bad_free_array) > 0 {
		fmt.eprintf("=== %v temp incorrect frees: ===\n", len(temp_track.bad_free_array))
		for entry in temp_track.bad_free_array {
			fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
		}
	}
	mem.tracking_allocator_destroy(temp_track)
}
