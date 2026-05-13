package main

import "base:runtime"
import "core:fmt"
import "partcl"

eval_and_print :: proc(ctx: ^partcl.Tcl, script: cstring, desc: string) {
	fmt.print("\n--- ", desc, " ---\n")
	fmt.println("Script:", script)

	result_code := partcl.eval(ctx, script, len(script))

	switch result_code {
	case .FNORMAL:
		res_str := partcl.string(ctx.result)
		res_len := partcl.length(ctx.result)
		fmt.printfln("Result: %s", string(res_str))
	case .FERROR:
		fmt.print("Error evaluating script\n")
		err_str := partcl.string(ctx.result)
		err_len := partcl.length(ctx.result)
		if err_len > 0 {
			fmt.print("Error message: \"", string(err_str), "\"\n")
		}
	case .FRETURN:
		fmt.print("Script returned (FRETURN)\n")
	case .FBREAK:
		fmt.print("Script broke out (FBREAK)\n")
	case .FAGAIN:
		fmt.print("Script continued (FAGAIN)\n")
	}
}

custom_command :: proc "c" (
	tcl: ^partcl.Tcl,
	args: partcl.Value,
	arg: rawptr,
) -> partcl.Control_Flow {
	context = runtime.default_context()
	fmt.println("Custom command called from Tcl!")
	return .FNORMAL
}

main :: proc() {
	ctx: partcl.Tcl
	partcl.init(&ctx)
	defer partcl.destroy(&ctx)

	// -------- 1. set command --------
	eval_and_print(&ctx, `set x 42;`, "set variable x = 42")
	eval_and_print(&ctx, `set x;`, "get variable x")
	// The braces { } tell Tcl to treat everything between them as a single, literal name.
	eval_and_print(&ctx, `set {var with spaces} "hello world";`, "set variable with spaces")
	eval_and_print(&ctx, `set {var with spaces};`, "get variable with spaces")

	// -------- 2. subst command --------
	eval_and_print(&ctx, `set a hello;`, "prepare a")
	eval_and_print(&ctx, `subst $a;`, "simple variable substitution")
	eval_and_print(&ctx, `set b world;`, "prepare b")
	eval_and_print(&ctx, `subst "$a $b";`, "multiple variables")
	eval_and_print(&ctx, `set {x y} foobar;`, "set var with space")
	eval_and_print(&ctx, `subst ${x y};`, "braced variable name")
	eval_and_print(&ctx, `subst hello[subst world];`, "command substitution inside subst")
	eval_and_print(&ctx, `subst $a[]$b;`, "empty command as separator")

	// -------- 3. puts command --------
	fmt.println("\n--- puts command (output to stdout) ---")
	puts1: cstring = `puts "Hello from Tcl";`
	partcl.eval(&ctx, puts1, len(puts1))
	puts2: cstring = `puts {braced literal with spaces};`
	partcl.eval(&ctx, puts2, len(puts2))
	puts3: cstring = `puts "[set a] [set b]";`
	partcl.eval(&ctx, puts3, len(puts3))

	// -------- 4. proc command --------
	eval_and_print(&ctx, `proc greet {} { subst "Hello from proc" };`, "define proc greet")
	eval_and_print(&ctx, `greet;`, "call greet")
	eval_and_print(&ctx, `proc square {x} { * $x $x };`, "define square")
	eval_and_print(&ctx, `square 7;`, "call square 7")
	eval_and_print(&ctx, `proc sum {a b} { + $a $b };`, "define sum")
	eval_and_print(&ctx, `sum 25 44;`, "call sum 25 44")
	eval_and_print(&ctx, `proc sum {a b} {
			return [+ $a $b]
		};`, "define sum multiline")
	eval_and_print(&ctx, `sum 25 44;`, "call multiline sum 25 44")
	eval_and_print(&ctx, `proc local_var {} { set l 5; subst $l };`, "local variable")
	eval_and_print(&ctx, `local_var;`, "call, should print 5")
	eval_and_print(&ctx, `set l;`, "check global l (should be empty)")

	// -------- 5. if command --------
	eval_and_print(&ctx, `set cond 1;`, "set cond = 1")
	eval_and_print(&ctx, `if {== $cond 1} {subst true} {subst false};`, "if-else")
	eval_and_print(&ctx, `set cond 0;`, "set cond = 0")
	eval_and_print(&ctx, `if {== $cond 1} {subst true} {subst false};`, "if-else again")
	eval_and_print(
		&ctx,
		//  if cond      true        elseif cond     true          else
		`if {< 1 2} {puts "less"}   {== 1 1}    {puts equal} {puts greater};`,
		"if-then-elseif-then-else chain",
	)
	eval_and_print(&ctx, `if {> 10 5} { subst "greater" };`, "if without else")
	eval_and_print(&ctx, `if {> 10 20} { subst "greater" };`, "if false without else returns 0")

	// -------- 6. while loop with break/continue --------
	eval_and_print(&ctx, `set i 0;`, "init i")
	eval_and_print(
		&ctx,
		`while {< $i 5} { puts "i = $i"; set i [+ $i 1] };`,
		"while loop counting to 5",
	)
	eval_and_print(&ctx, `set i 0;`, "reset i")
	eval_and_print(
		&ctx,
		`while {< $i 10} { set i [+ $i 1]; if {== $i 5} { puts "i = $i"; break } };`,
		"while with break at 5",
	)
	eval_and_print(&ctx, `set i 0; set result "";`, "init for continue demo")
	eval_and_print(
		&ctx,
		`
while {< $i 5} {
	set i [+ $i 1]
	if {== $i 3} {
		continue
	}
	set result "$result $i"
}
subst $result
`,
		"while with continue (skip 3)",
	)

	// -------- 7. return command --------
	eval_and_print(
		&ctx,
		`
	proc retval {} {
		set i 0;
		while {< $i 5} {
			set i [+ $i 1]
			if {== $i 3} {
				return $i
			}
		}
		return condition_was_not_triggered
	}
	retval;`,
		"retval 3",
	)

	// -------- 8. math operators (prefix) --------
	eval_and_print(&ctx, `+ 1 2;`, "addition")
	eval_and_print(&ctx, `- 7 2;`, "subtraction")
	eval_and_print(&ctx, `* 4 2;`, "multiplication")
	eval_and_print(&ctx, `/ 7 2;`, "integer division")
	eval_and_print(&ctx, `< 1 2;`, "less than")
	eval_and_print(&ctx, `<= 1 1;`, "less or equal")
	eval_and_print(&ctx, `> 1 2;`, "greater than")
	eval_and_print(&ctx, `>= 1 1;`, "greater or equal")
	eval_and_print(&ctx, `== 1 1;`, "equal")
	eval_and_print(&ctx, `!= 1 1;`, "not equal")
	eval_and_print(
		&ctx,
		`set a 5; set b 7; subst [- [* 4 [+ $a $b]] 6];`,
		"nested math: 4*(5+7)-6 = 42",
	)

	// -------- 9. Braces --------
	eval_and_print(
		&ctx,
		`set literal {this is {braced} text with $no substitution};`,
		"braced literal",
	)
	eval_and_print(
		&ctx,
		`subst $literal;`,
		"subst on braced literal (no variable expansion inside braces)",
	)

	// -------- 10. Command substitution and concatenation --------
	eval_and_print(&ctx, `set name "world";`, "set name")
	eval_and_print(&ctx, `subst "Hello [set name]!";`, "command substitution inside quotes")
	eval_and_print(&ctx, `subst "Result: [+ 5 3]";`, "math inside command substitution")
	eval_and_print(
		&ctx,
		`set x 10; set y 20; subst "Sum = [* $x $y]";`,
		"nested variables and command sub",
	)
	eval_and_print(
		&ctx,
		`set prefix "Hello"; set suffix "World"; subst $prefix$suffix;`,
		"implicit concatenation",
	)
	eval_and_print(
		&ctx,
		`
	proc somecommand {} {
		puts "hello from some command"
		return success
	};
	set a some
	set b command
	$a$b;`,
		"call command via concatenated name",
	)

	// -------- 11. Custom command --------
	partcl.register(&ctx, "custom_cmd", custom_command, 1, nil)
	eval_and_print(&ctx, `custom_cmd;`, "calling custom command")

	// -------- 12. Error handling demo --------
	fmt.println("\n--- Error non-existing cmd ---")
	bad_script: cstring = `non-existing-cmd;`
	fmt.println("Script:", bad_script)
	result := partcl.eval(&ctx, bad_script, len(bad_script))
	if result == .FERROR {
		fmt.println("Expected error evaluating script")
		err_str := partcl.string(ctx.result)
		err_len := partcl.length(ctx.result)
		if err_len > 0 {
			fmt.println("Error message: \"", string(err_str), "\"")
		}
	} else {
		fmt.println("Unexpected success")
	}

	fmt.println("\n--- Error division by zero ---")
	bad_script = `/ 1 0;`
	fmt.println("Script:", bad_script)
	result = partcl.eval(&ctx, bad_script, len(bad_script))
	if result == .FERROR {
		fmt.println("Expected error evaluating script")
		err_str := partcl.string(ctx.result)
		err_len := partcl.length(ctx.result)
		if err_len > 0 {
			fmt.println("Error message: \"", string(err_str), "\"")
		}
	} else {
		fmt.println("Unexpected success")
	}
}
