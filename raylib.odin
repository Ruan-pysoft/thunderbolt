package thunderbolt

import "core:c"
import "core:fmt"

import rl "vendor:raylib"

import js "vendor/quickjs"

raylib_start :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)

	js_target_fps := js.GetPropertyStr(ctx, global_obj, "fps")
	defer js.FreeValue(ctx, js_target_fps)
	js_window_name := js.GetPropertyStr(ctx, global_obj, "window_title")
	defer js.FreeValue(ctx, js_window_name)
	js_window_width := js.GetPropertyStr(ctx, global_obj, "window_width")
	defer js.FreeValue(ctx, js_window_width)
	js_window_height := js.GetPropertyStr(ctx, global_obj, "window_height")
	defer js.FreeValue(ctx, js_window_height)

	target_fps: c.int = 60
	if js.IsNumber(js_target_fps) {
		int32: i32
		assert(js.ToInt32(ctx, &int32, js_target_fps) == 0)
		target_fps = c.int(int32)
	} else if !js.IsUndefined(js_target_fps) {
		fmt.eprintln("WARNING: `fps` should be initialised with a number, defaulting to 60")
	}

	window_name: cstring = "THUNDERBOLT WINDOW"
	defer if js.IsString(js_window_name) do js.FreeCString(ctx, window_name)
	if js.IsString(js_window_name) {
		window_name = js.ToCString(ctx, js_window_name)
	} else if !js.IsUndefined(js_window_name) {
		fmt.eprintln("WARNING: `window_title` should be initialised with a string")
	}

	window_width: c.int = 800
	if js.IsNumber(js_window_width) {
		int32: i32
		assert(js.ToInt32(ctx, &int32, js_window_width) == 0)
		window_width = c.int(int32)
	} else if !js.IsUndefined(js_window_width) {
		fmt.eprintln("WARNING: `window_width` should be initialised with a number, defaulting to 800")
	}

	window_height: c.int = 600
	if js.IsNumber(js_window_height) {
		int32: i32
		assert(js.ToInt32(ctx, &int32, js_window_height) == 0)
		window_height = c.int(int32)
	} else if !js.IsUndefined(js_window_height) {
		fmt.eprintln("WARNING: `window_height` should be initialised with a number, defaulting to 800")
	}

	rl.SetTargetFPS(target_fps)
	rl.InitWindow(window_width, window_height, window_name)
}

raylib_end :: proc() {
	rl.CloseWindow()
}

raylib_run_eventloop :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)

	js_update_fn := js.GetPropertyStr(ctx, global_obj, "update")
	defer js.FreeValue(ctx, js_update_fn)
	js_draw_fn := js.GetPropertyStr(ctx, global_obj, "draw")
	defer js.FreeValue(ctx, js_draw_fn)

	if js.IsUndefined(js_update_fn) {
		fmt.eprintln("ERROR: define an `update` function to handle your game's logic")
		// TODO: throw exception
		panic("no update function")
	}
	if js.IsFunction(ctx, js_update_fn) == 0 {
		fmt.eprintln("ERROR: `update` should be a function")
		// TODO: throw exception
		panic("no update function")
	}

	if js.IsUndefined(js_draw_fn) {
		fmt.eprintln("ERROR: define an `draw` function to handle your game's rendering")
		// TODO: throw exception
		panic("no draw function")
	}
	if js.IsFunction(ctx, js_draw_fn) == 0 {
		fmt.eprintln("ERROR: `draw` should be a function")
		// TODO: throw exception
		panic("no draw function")
	}

	js.FreeValue(ctx, js.Call(ctx, js_update_fn, js.UNDEFINED, 0, nil))
	rl.BeginDrawing()
	js.FreeValue(ctx, js.Call(ctx, js_draw_fn, js.UNDEFINED, 0, nil))
	rl.EndDrawing()
}

js_ClearBackground :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 3)
	assert(js.IsNumber(args[0]))
	assert(js.IsNumber(args[1]))
	assert(js.IsNumber(args[2]))

	// TODO: support alpha argumet
	// TODO: handle float in range [0.0, 1.0] and int in range [0, 255] different
	// TODO: range checks
	// TODO: Color type?

	int32: i32

	assert(js.ToInt32(ctx, &int32, args[0]) == 0)
	r := u8(int32)
	assert(js.ToInt32(ctx, &int32, args[1]) == 0)
	g := u8(int32)
	assert(js.ToInt32(ctx, &int32, args[2]) == 0)
	b := u8(int32)

	rl.ClearBackground({ r, g, b, 255 })

	return js.UNDEFINED
}

js_DrawRectangle :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 7)
	assert(js.IsNumber(args[0]))
	assert(js.IsNumber(args[1]))
	assert(js.IsNumber(args[2]))
	assert(js.IsNumber(args[3]))
	assert(js.IsNumber(args[4]))
	assert(js.IsNumber(args[5]))
	assert(js.IsNumber(args[6]))

	// TODO: support alpha argumet
	// TODO: handle float in range [0.0, 1.0] and int in range [0, 255] different
	// TODO: range checks
	// TODO: Color type?

	int32: i32

	assert(js.ToInt32(ctx, &int32, args[0]) == 0)
	x := c.int(int32)
	assert(js.ToInt32(ctx, &int32, args[1]) == 0)
	y := c.int(int32)
	assert(js.ToInt32(ctx, &int32, args[2]) == 0)
	width := c.int(int32)
	assert(js.ToInt32(ctx, &int32, args[3]) == 0)
	height := c.int(int32)
	assert(js.ToInt32(ctx, &int32, args[4]) == 0)
	r := u8(int32)
	assert(js.ToInt32(ctx, &int32, args[5]) == 0)
	g := u8(int32)
	assert(js.ToInt32(ctx, &int32, args[6]) == 0)
	b := u8(int32)

	rl.DrawRectangle(x, y, width, height, { r, g, b, 255 })

	return js.UNDEFINED
}

install_raylib :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)
	ClearBackground_fn := js.NewCFunction(ctx, to_js_c_function(js_ClearBackground), "ClearBackground", 1)
	DrawRectangle_fn := js.NewCFunction(ctx, to_js_c_function(js_DrawRectangle), "DrawRectangle", 1)

	js.SetPropertyStr(ctx, global_obj, "ClearBackground", ClearBackground_fn)
	js.SetPropertyStr(ctx, global_obj, "DrawRectangle", DrawRectangle_fn)
}
