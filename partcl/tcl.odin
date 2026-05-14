package partcl

import "core:c"

when ODIN_OS == .Windows do foreign import lib "windows/libpartcl.a"
when ODIN_OS == .Linux do foreign import lib "linux/libpartcl.a"

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
	init    :: proc(tcl: ^Tcl) --- // Initialize interpreter
	destroy :: proc(tcl: ^Tcl) --- // Clean up resources
	
	
	eval  :: proc(tcl: ^Tcl, script: cstring, script_len: c.size_t) -> Control_Flow --- // Evaluate script
	
	
	register :: proc(tcl: ^Tcl, name: cstring, fn: Cmd_Fn, arity: c.int, arg: rawptr) --- // Registers a new native Tcl command.
	
	
	/* Raw string values */
	
	
	alloc  :: proc(s: cstring, len: c.size_t) -> Value ---
	dup    :: proc(v: Value) -> Value ---
	append :: proc(v: Value, tail: Value) -> Value ---
	length :: proc(v: Value) -> c.int --- // Returns the length of a tcl.result value's string
	free   :: proc(v: Value) --- // Frees a Tcl value returned by the library.
	
	
	/* Helpers to access raw string or numeric value */
	

	@(link_name="tcl_int")
	to_int    :: proc(v: Value) -> c.int --- // Converts a Tcl value to an integer
	@(link_name="tcl_string")
	to_string :: proc(v: Value) -> cstring --- // Returns the raw C string of a tcl.result value
	
	
	/* List values */
	
	
	list_alloc  :: proc() -> Value ---
	list_append :: proc(v: Value, tail: Value) -> Value ---
	list_at     :: proc(v: Value, index: c.int) -> Value ---
	list_length :: proc(v: Value) -> c.int ---
	list_free   :: proc(v: Value) ---
	

	/* Miscellaneous */
	
	
	var :: proc(tcl: ^Tcl, name: Value, value: Value) -> Value ---
	
	
	result :: proc(tcl: ^Tcl, flow: Control_Flow, value: Value) -> Control_Flow --- // Sets the interpreter's result value and returns a flow control code.
	
	
	subst :: proc(tcl: ^Tcl, s: cstring, len: c.size_t) -> Control_Flow ---
}
