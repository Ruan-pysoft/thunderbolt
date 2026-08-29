package thunderbolt

import "core:c"

import rl "vendor:raylib"

import js "vendor/quickjs"

js_InitWindow :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 3)
	assert(js.IsNumber(args[0]))
	assert(js.IsNumber(args[1]))
	assert(js.IsString(args[2]))

	int32: i32

	assert(js.ToInt32(ctx, &int32, args[0]) == 0)
	width := c.int(int32)
	assert(js.ToInt32(ctx, &int32, args[1]) == 0)
	height := c.int(int32)
	title := js.ToCString(ctx, args[2])
	defer js.FreeCString(ctx, title)

	rl.InitWindow(width, height, title)

	return js.UNDEFINED
}

js_WindowShouldClose :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 0)

	return js.NewBool(ctx, i32(rl.WindowShouldClose()))
}

install_raylib :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)
	InitWindow_fn := js.NewCFunction(ctx, to_js_c_function(js_InitWindow), "InitWindow", 1)
	WindowShouldClose_fn := js.NewCFunction(ctx, to_js_c_function(js_WindowShouldClose), "WindowShouldClose", 1)

	js.SetPropertyStr(ctx, global_obj, "InitWindow", InitWindow_fn)
	js.SetPropertyStr(ctx, global_obj, "WindowShouldClose", WindowShouldClose_fn)
}
