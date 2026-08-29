package thunderbolt

import "core:fmt"
import "core:os"
import "core:strings"

import js "vendor/quickjs"

// Following the following tutorial:
// https://healeycodes.com/building-a-runtime-with-quickjs

main :: proc() {
	exit_code: int
	defer os.exit(exit_code)

	rt := js.NewRuntime()
	assert(rt != nil)
	defer js.FreeRuntime(rt)
	ctx := js.NewContext(rt)
	assert(ctx != nil)
	defer js.FreeContext(ctx)

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
