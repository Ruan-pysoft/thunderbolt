package thunderbolt

import "core:c"
import "core:fmt"
import "core:reflect"
import "core:strings"

import rl "vendor:raylib"

import js "vendor/quickjs_odin"

DEFAULT_FPS :: c.int(60)
DEFAULT_WIDTH :: c.int(800)
DEFAULT_HEIGHT :: c.int(600)
DEFAULT_TITLE :: cstring("THUNDERBOLT_TITLE")

Raylib_Properties :: struct {
	fps: c.int,
	width, height: c.int,
	title: cstring,
}

DEFAULT_PROPERTIES :: Raylib_Properties {
	DEFAULT_FPS,
	DEFAULT_WIDTH, DEFAULT_HEIGHT,
	DEFAULT_TITLE,
}

raylib_fetch_properties :: proc(ctx: js.Context) -> (props: Raylib_Properties, must_free_title: bool) {
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

	target_fps := DEFAULT_FPS
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

	window_name := DEFAULT_TITLE
	must_free_title = js.IsString(js_window_name)
	if js.IsString(js_window_name) {
		window_name = js.ToCString(ctx, js_window_name)
	} else if !js.IsUndefined(js_window_name) {
		fmt.eprintln("WARNING: `window_title` should be initialised with a string")
	} else {
		v := js.NewString(ctx, window_name)
		js.SetPropertyCStr(ctx, global_obj, "window_title", v)
	}

	window_width := DEFAULT_WIDTH
	if js.IsNumber(js_window_width) {
		res, ok := js.ToInt(ctx, js_window_width)
		assert(ok)
		window_width = c.int(res)
	} else if !js.IsUndefined(js_window_width) {
		fmt.eprintln("WARNING: `window_width` should be initialised with a number, defaulting to 800")
	} else {
		v := js.NewInt(ctx, int(window_width))
		js.SetPropertyCStr(ctx, global_obj, "window_width", v)
	}

	window_height := DEFAULT_HEIGHT
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

	return {
		fps = target_fps,
		width = window_width,
		height = window_height,
		title = window_name,
	}, must_free_title
}
raylib_update_properties :: proc(ctx: js.Context) {
	@(static) old: Raylib_Properties

	props, must_free_title := raylib_fetch_properties(ctx)

	if props.fps != old.fps {
		fmt.eprintln("SetTargetFPS", props.fps)
		rl.SetTargetFPS(props.fps)
		old.fps = props.fps
	}

	if props.width != old.width || props.height != old.height {
		rl.SetWindowSize(props.width, props.height)
		old.width, old.height = props.width, props.height
	}

	if props.title != old.title && must_free_title {
		rl.SetWindowTitle(props.title)
		if old.title != nil do js.FreeCString(ctx, old.title)
		old.title = props.title
	} else if must_free_title do js.FreeCString(ctx, props.title)
}

raylib_start :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)

	props, must_free_title := raylib_fetch_properties(ctx)
	defer if must_free_title do js.FreeCString(ctx, props.title)

	fmt.eprintln("(init) SetTargetFPS", props.fps)
	rl.SetTargetFPS(props.fps)
	rl.InitWindow(props.width, props.height, props.title)
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

	update_res := js.Call(ctx, js_update_fn, js.UNDEFINED)
	defer js.FreeValue(ctx, update_res)
	if js.IsException(update_res) {
		dump_exception(ctx)
		panic("exception hit!")
	}

	raylib_update_properties(ctx)

	{ rl.BeginDrawing()
		draw_res := js.Call(ctx, js_draw_fn, js.UNDEFINED)
		defer js.FreeValue(ctx, draw_res)
		if js.IsException(draw_res) {
			dump_exception(ctx)
			panic("exception hit!")
		}
	rl.EndDrawing() }
}

js_ClearBackground :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 1)
	assert(IsOfClass(cColor, args[0]))

	rl.ClearBackground(cColor_get_color(ctx, args[0]))

	return js.UNDEFINED
}

js_DrawRectangle :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 5)
	assert(js.IsNumber(args[0]))
	assert(js.IsNumber(args[1]))
	assert(js.IsNumber(args[2]))
	assert(js.IsNumber(args[3]))
	assert(IsOfClass(cColor, args[4]))

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

	rl.DrawRectangle(x, y, width, height, cColor_get_color(ctx, args[4]))

	return js.UNDEFINED
}

js_DrawCircle :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 4)
	assert(js.IsNumber(args[0]))
	assert(js.IsNumber(args[1]))
	assert(js.IsNumber(args[2]))
	assert(IsOfClass(cColor, args[3]))

	i: int
	radius: f64
	ok: bool

	i, ok = js.ToInt(ctx, args[0])
	assert(ok)
	x := c.int(i)
	i, ok = js.ToInt(ctx, args[1])
	assert(ok)
	y := c.int(i)
	radius, ok = js.ToF64(ctx, args[2])
	assert(ok)

	rl.DrawCircle(x, y, f32(radius), cColor_get_color(ctx, args[3]))

	return js.UNDEFINED
}

js_DrawText :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 5)
	assert(js.IsString(args[0]))
	assert(js.IsNumber(args[1]))
	assert(js.IsNumber(args[2]))
	assert(js.IsNumber(args[3]))
	assert(IsOfClass(cColor, args[4]))

	i: int
	text: cstring
	ok: bool

	text = js.ToCString(ctx, args[0])
	defer js.FreeCString(ctx, text)
	i, ok = js.ToInt(ctx, args[1])
	assert(ok)
	x := c.int(i)
	i, ok = js.ToInt(ctx, args[2])
	assert(ok)
	y := c.int(i)
	i, ok = js.ToInt(ctx, args[3])
	assert(ok)
	font_size := c.int(i)
	color := cColor_get_color(ctx, args[4])

	rl.DrawText(text, x, y, font_size, color)

	return js.UNDEFINED
}

js_DrawFPS :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 2)
	assert(js.IsNumber(args[0]))
	assert(js.IsNumber(args[1]))

	i: int
	ok: bool

	i, ok = js.ToInt(ctx, args[0])
	assert(ok)
	x := c.int(i)
	i, ok = js.ToInt(ctx, args[1])
	assert(ok)
	y := c.int(i)

	rl.DrawFPS(x, y)

	return js.UNDEFINED
}

js_MeasureText :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 2)
	assert(js.IsString(args[0]))
	assert(js.IsNumber(args[1]))

	i: int
	text: cstring
	ok: bool

	text = js.ToCString(ctx, args[0])
	defer js.FreeCString(ctx, text)
	i, ok = js.ToInt(ctx, args[1])
	assert(ok)
	font_size := c.int(i)

	width := rl.MeasureText(text, font_size)

	return js.NewInt(ctx, int(width))
}

js_IsKeyDown :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 1)
	assert(js.IsNumber(args[0]))

	i: int
	ok: bool

	i, ok = js.ToInt(ctx, args[0])
	assert(ok)
	key := rl.KeyboardKey(i)

	return js.NewBool(ctx, rl.IsKeyDown(key))
}

register_keyboard_keys :: proc(ctx: js.Context, global_obj: js.Value) {
	// TODO: do some sort of proper thing here to better emulate an enum?

	key := js.NewObject(ctx)

	for key_field in reflect.enum_fields_zipped(rl.KeyboardKey) {
		as_js_int := js.NewInt(ctx, int(key_field.value))

		js.SetPropertyStr(ctx, key, key_field.name, as_js_int)
	}

	object := js.GetPropertyCStr(ctx, global_obj, "Object")
	defer js.FreeValue(ctx, object)
	freeze := js.GetPropertyCStr(ctx, object, "freeze")
	defer js.FreeValue(ctx, freeze)
	assert(js.IsFunction(ctx, freeze))
	js.FreeValue(ctx, js.Call(ctx, freeze, object, key))

	js.SetPropertyCStr(ctx, global_obj, "Key", key)
}

install_raylib :: proc(ctx: js.Context) {
	rt := js.GetRuntime(ctx)
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)
	ClearBackground_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_ClearBackground), "ClearBackground", 1)
	DrawRectangle_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_DrawRectangle), "DrawRectangle", 5)
	DrawCircle_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_DrawCircle), "DrawCircle", 4)
	DrawText_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_DrawText), "DrawText", 5)
	DrawFPS_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_DrawFPS), "DrawFPS", 2)
	MeasureText_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_MeasureText), "MeasureText", 2)
	IsKeyDown_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_IsKeyDown), "IsKeyDown", 1)

	js.SetPropertyCStr(ctx, global_obj, "ClearBackground", ClearBackground_fn)
	js.SetPropertyCStr(ctx, global_obj, "DrawRectangle", DrawRectangle_fn)
	js.SetPropertyCStr(ctx, global_obj, "DrawCircle", DrawCircle_fn)
	js.SetPropertyCStr(ctx, global_obj, "DrawText", DrawText_fn)
	js.SetPropertyCStr(ctx, global_obj, "DrawFPS", DrawFPS_fn)
	js.SetPropertyCStr(ctx, global_obj, "MeasureText", MeasureText_fn)
	js.SetPropertyCStr(ctx, global_obj, "IsKeyDown", IsKeyDown_fn)

	js.SetPropertyCStr(ctx, global_obj, "fps", js.NewInt(ctx, int(DEFAULT_FPS)))
	js.SetPropertyCStr(ctx, global_obj, "window_width", js.NewInt(ctx, int(DEFAULT_WIDTH)))
	js.SetPropertyCStr(ctx, global_obj, "window_height", js.NewInt(ctx, int(DEFAULT_HEIGHT)))
	js.SetPropertyCStr(ctx, global_obj, "window_title", js.NewString(ctx, DEFAULT_TITLE))

	for class in class_registry {
		register_class(rt, ctx, global_obj, class)
	}

	register_keyboard_keys(ctx, global_obj)
}
