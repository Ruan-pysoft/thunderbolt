package thunderbolt

import "base:runtime"

import "core:c"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"

import js "vendor/quickjs"

// Following the following tutorial:
// https://healeycodes.com/building-a-runtime-with-quickjs

Runtime_State :: struct {
	ctx: runtime.Context,
	startup_time: time.Tick,
}

main :: proc() {
	exit_code: int
	defer os.exit(exit_code)

	rt := js.NewRuntime()
	assert(rt != nil)
	defer js.FreeRuntime(rt)
	ctx := js.NewContext(rt)
	assert(ctx != nil)
	defer js.FreeContext(ctx)

	runtime_state: Runtime_State
	install_runtime(rt, &runtime_state)

	install_console(ctx)
	install_process(ctx)

	exit_code = run_file(ctx, os.args[1])
}

run_file :: proc(ctx: js.Context, file: string) -> (exit_code: int) {
	result: js.Value
	exit_code = 1
	path := strings.clone_to_cstring(file, context.temp_allocator)

	file_data, file_err := os.read_entire_file(file, context.temp_allocator)
	if file_err != nil {
		fmt.eprintln("Error reading source file: ", file_err)
		return 1;
	}

	result = js.Eval(
		ctx,
		raw_data(file_data),
		len(file_data),
		path,
		{ type = .Global },
	)

	if js.IsException(result) {
		dump_exception(ctx)
	} else do exit_code = 0

	js.FreeValue(ctx, result)

	return exit_code
}

dump_exception :: proc(ctx: js.Context) {
	exception := js.GetException(ctx)
	defer js.FreeValue(ctx, exception)
	stack := js.GetPropertyStr(ctx, exception, "stack")
	defer js.FreeValue(ctx, stack)
	message := transmute([^]u8) js.ToCString(ctx, exception)
	defer if message != nil do js.FreeCString(ctx, transmute(cstring) message)
	stack_text: [^]u8
	defer if stack_text != nil do js.FreeCString(ctx, transmute(cstring) stack_text)

	if !js.IsUndefined(stack) && !js.IsNull(stack) {
		stack_text = transmute([^]u8) js.ToCString(ctx, stack)
	}

	if message != nil && message[0] != 0 {
		fmt.eprintln(transmute(cstring) message)
	} else if stack_text == nil || stack_text[0] == 0 {
		fmt.eprintln("JavaScript exception")
	}

	if stack_text != nil && stack_text[0] != 0 {
		if message == nil || message[0] == 0 || string(transmute(cstring) message) != string(transmute(cstring) stack_text) {
			fmt.eprintln(transmute(cstring) stack_text)
		}
	}
}

js_console_log :: proc"c"(ctx: js.Context, this_val: js.Value_Const, argc: c.int, argv: [^]js.Value_Const) -> js.Value {
	context = runtime.default_context()

	args := slice.from_ptr(argv, int(argc))

	for arg, i in args {
		if i > 0 do fmt.print(' ')

		string_value := js.ToString(ctx, arg)
		defer js.FreeValue(ctx, string_value)
		text := js.ToCString(ctx, string_value)
		defer js.FreeCString(ctx, text)

		fmt.print(text)
	}

	fmt.println()

	return js.UNDEFINED
}

install_console :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)
	console_obj := js.NewObject(ctx)
	log_fn := js.NewCFunction(ctx, js_console_log, "log", 1)

	js.SetPropertyStr(ctx, console_obj, "log", log_fn)
	js.SetPropertyStr(ctx, global_obj, "console", console_obj)
}

install_runtime :: proc(rt: js.Runtime, state: ^Runtime_State) {
	state^ = {
		ctx = context,
		startup_time = time.tick_now(),
	}

	js.SetRuntimeOpaque(rt, state)
}

js_process_uptime :: proc"c"(ctx: js.Context, this_val: js.Value_Const, argc: c.int, argv: [^]js.Value_Const) -> js.Value {
	state := cast(^Runtime_State) js.GetRuntimeOpaque(js.GetRuntime(ctx))

	now := time.tick_now()

	uptime_nanos := time.tick_diff(state.startup_time, now)

	return js.NewFloat64(ctx, f64(uptime_nanos) / f64(time.Second))
}

install_process :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)
	process_obj := js.NewObject(ctx)
	uptime_fn := js.NewCFunction(ctx, js_process_uptime, "uptime", 1)

	js.SetPropertyStr(ctx, process_obj, "uptime", uptime_fn)
	js.SetPropertyStr(ctx, global_obj, "process", process_obj)
}
