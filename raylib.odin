package thunderbolt

import "core:c"
import "core:fmt"

import rl "vendor:raylib"

import js "vendor/quickjs_odin"

raylib_start :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)

	js_target_fps := js.GetPropertyCStr(ctx, global_obj, "fps")
	defer js.FreeValue(ctx, js_target_fps)
	js_window_name := js.GetPropertyCStr(ctx, global_obj, "window_title")
	defer js.FreeValue(ctx, js_window_name)
	js_window_width := js.GetPropertyCStr(ctx, global_obj, "window_width")
	defer js.FreeValue(ctx, js_window_width)
	js_window_height := js.GetPropertyCStr(ctx, global_obj, "window_height")
	defer js.FreeValue(ctx, js_window_height)

	target_fps: c.int = 60
	if js.IsNumber(js_target_fps) {
		res, ok := js.ToInt(ctx, js_target_fps)
		assert(ok)
		target_fps = c.int(res)
	} else if !js.IsUndefined(js_target_fps) {
		fmt.eprintln("WARNING: `fps` should be initialised with a number, defaulting to 60")
	} else {
		v := js.NewInt(ctx, int(target_fps))
		js.SetPropertyCStr(ctx, global_obj, "fps", v)
	}

	window_name: cstring = "THUNDERBOLT WINDOW"
	defer if js.IsString(js_window_name) do js.FreeCString(ctx, window_name)
	if js.IsString(js_window_name) {
		window_name = js.ToCString(ctx, js_window_name)
	} else if !js.IsUndefined(js_window_name) {
		fmt.eprintln("WARNING: `window_title` should be initialised with a string")
	} else {
		v := js.NewString(ctx, window_name)
		js.SetPropertyCStr(ctx, global_obj, "window_title", v)
	}

	window_width: c.int = 800
	if js.IsNumber(js_window_width) {
		fmt.eprintln("width is number")
		res, ok := js.ToInt(ctx, js_window_width)
		assert(ok)
		window_width = c.int(res)
	} else if !js.IsUndefined(js_window_width) {
		fmt.eprintln("WARNING: `window_width` should be initialised with a number, defaulting to 800")
	} else {
		fmt.eprintln("width is not number")
		v := js.NewInt(ctx, int(window_width))
		js.SetPropertyCStr(ctx, global_obj, "window_width", v)
	}

	window_height: c.int = 600
	if js.IsNumber(js_window_height) {
		res, ok := js.ToInt(ctx, js_window_height)
		assert(ok)
		window_height = c.int(res)
	} else if !js.IsUndefined(js_window_height) {
		fmt.eprintln("WARNING: `window_height` should be initialised with a number, defaulting to 800")
	} else {
		v := js.NewInt(ctx, int(window_height))
		js.SetPropertyCStr(ctx, global_obj, "window_height", v)
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

	js_update_fn := js.GetPropertyCStr(ctx, global_obj, "update")
	defer js.FreeValue(ctx, js_update_fn)
	js_draw_fn := js.GetPropertyCStr(ctx, global_obj, "draw")
	defer js.FreeValue(ctx, js_draw_fn)

	if js.IsUndefined(js_update_fn) {
		fmt.eprintln("ERROR: define an `update` function to handle your game's logic")
		// TODO: throw exception
		panic("no update function")
	}
	if !js.IsFunction(ctx, js_update_fn) {
		fmt.eprintln("ERROR: `update` should be a function")
		// TODO: throw exception
		panic("no update function")
	}

	if js.IsUndefined(js_draw_fn) {
		fmt.eprintln("ERROR: define an `draw` function to handle your game's rendering")
		// TODO: throw exception
		panic("no draw function")
	}
	if !js.IsFunction(ctx, js_draw_fn) {
		fmt.eprintln("ERROR: `draw` should be a function")
		// TODO: throw exception
		panic("no draw function")
	}

	js.FreeValue(ctx, js.Call(ctx, js_update_fn, js.UNDEFINED))

	{ rl.BeginDrawing()
		js.FreeValue(ctx, js.Call(ctx, js_draw_fn, js.UNDEFINED))
	rl.EndDrawing() }
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

	i: int
	ok: bool

	i, ok = js.ToInt(ctx, args[0])
	assert(ok)
	r := u8(i)
	i, ok = js.ToInt(ctx, args[1])
	assert(ok)
	g := u8(i)
	i, ok = js.ToInt(ctx, args[2])
	assert(ok)
	b := u8(i)

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

	i: int
	ok: bool

	i, ok = js.ToInt(ctx, args[0])
	assert(ok)
	x := c.int(i)
	i, ok = js.ToInt(ctx, args[1])
	assert(ok)
	y := c.int(i)
	i, ok = js.ToInt(ctx, args[2])
	assert(ok)
	width := c.int(i)
	i, ok = js.ToInt(ctx, args[3])
	assert(ok)
	height := c.int(i)
	i, ok = js.ToInt(ctx, args[4])
	assert(ok)
	r := u8(i)
	i, ok = js.ToInt(ctx, args[5])
	assert(ok)
	g := u8(i)
	i, ok = js.ToInt(ctx, args[6])
	assert(ok)
	b := u8(i)

	rl.DrawRectangle(x, y, width, height, { r, g, b, 255 })

	return js.UNDEFINED
}

install_raylib :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)
	ClearBackground_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_ClearBackground), "ClearBackground", 1)
	DrawRectangle_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_DrawRectangle), "DrawRectangle", 1)

	js.SetPropertyCStr(ctx, global_obj, "ClearBackground", ClearBackground_fn)
	js.SetPropertyCStr(ctx, global_obj, "DrawRectangle", DrawRectangle_fn)
}
