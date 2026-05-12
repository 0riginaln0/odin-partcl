package partcl

import "core:c"
foreign import lib "libpartcl.a"

Tcl :: struct {
	env:    rawptr,
	cmds:   rawptr,
	result: Value,
}

Control_Flow :: enum c.int {
	FERROR  = 0, // An error occurred during evaluation
	FNORMAL = 1, // Normal command completion
	FRETURN = 2, // The 'return' command was encountered
	FBREAK  = 3, // The 'break' command was encountered
	FAGAIN  = 4, // The 'continue' command was encountered
}

Value :: rawptr

Cmd_Fn :: #type proc "c" (tcl: ^Tcl, args: Value, arg: rawptr) -> Control_Flow

@(link_prefix = "tcl_")
@(default_calling_convention = "c")
foreign lib {
	init :: proc(tcl: ^Tcl) --- // Initialize interpreter
	destroy :: proc(tcl: ^Tcl) --- // Clean up resources

	eval :: proc(tcl: ^Tcl, script: cstring, script_len: c.size_t) -> Control_Flow --- // Evaluate script

	string :: proc(v: rawptr) -> cstring --- // Returns the raw C string of a tcl.result value
	length :: proc(v: rawptr) -> c.int --- // Returns the length of a tcl.result value's string
	free :: proc(v: rawptr) --- // Frees a Tcl value returned by the library.
	int :: proc(v: rawptr) -> c.int --- // Converts a Tcl value to an integer

	result :: proc(tcl: ^Tcl, flow: Control_Flow, value: Value) -> Control_Flow --- // Sets the interpreter's result value and returns a flow control code.
	register :: proc(tcl: ^Tcl, name: cstring, fn: Cmd_Fn, arity: c.int, arg: rawptr) --- // Registers a new native Tcl command.
}
