package thunderbolt

import "core:c"
import "core:fmt"

import rl "vendor:raylib"

import js "vendor/quickjs_odin"

ColorToRawValue :: proc"contextless"(ctx: js.Context, color: rl.Color) -> js.Value {
	return js.NewI32(ctx, transmute(i32) color)
}
RawValueToColor :: proc"contextless"(ctx: js.Context, v: js.Value_Const) -> (res: rl.Color, ok: bool) {
	return transmute(rl.Color) js.ToI32(ctx, v) or_return, true
}
IsRawColor :: proc(v: js.Value_Const) -> bool {
	return js.tag_of(v) == .Int
}

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
		res, ok := js.ToInt(ctx, js_window_width)
		assert(ok)
		window_width = c.int(res)
	} else if !js.IsUndefined(js_window_width) {
		fmt.eprintln("WARNING: `window_width` should be initialised with a number, defaulting to 800")
	} else {
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
	assert(len(args) == 1)
	assert(js.IsObject(args[0]))
	args0_class, args0_class_ok := js.GetClassID(args[0])
	assert(args0_class_ok && args0_class == color_class_id)

	rl.ClearBackground(_get_color(ctx, args[0]))

	return js.UNDEFINED
}

js_DrawRectangle :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 5)
	assert(js.IsNumber(args[0]))
	assert(js.IsNumber(args[1]))
	assert(js.IsNumber(args[2]))
	assert(js.IsNumber(args[3]))
	args4_class, args4_class_ok := js.GetClassID(args[4])
	assert(args4_class_ok && args4_class == color_class_id)

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

	rl.DrawRectangle(x, y, width, height, _get_color(ctx, args[4]))

	return js.UNDEFINED
}

install_raylib :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)
	ClearBackground_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_ClearBackground), "ClearBackground", 1)
	DrawRectangle_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_DrawRectangle), "DrawRectangle", 1)

	js.SetPropertyCStr(ctx, global_obj, "ClearBackground", ClearBackground_fn)
	js.SetPropertyCStr(ctx, global_obj, "DrawRectangle", DrawRectangle_fn)

	define_color_class(js.GetRuntime(ctx), ctx, global_obj)
}

color_class_id: js.Class_Id
color_class_def := js.Class_Def {
	class_name = "Color",
}
_get_color :: proc"contextless"(ctx: js.Context, color_obj: js.Value_Const) -> rl.Color {
	// TODO: ...
	assert_contextless(js.IsObject(color_obj))
	obj_class, obj_class_ok := js.GetClassID(color_obj)
	assert_contextless(obj_class_ok && obj_class == color_class_id)

	raw_color := js.GetPropertyCStr(ctx, color_obj, "__raw_color")
	assert_contextless(js.tag_of(raw_color) == .Int)

	color, ok := RawValueToColor(ctx, raw_color)
	assert_contextless(ok)

	return color
}
_set_color :: proc"contextless"(ctx: js.Context, color_obj: js.Value_Const, color: rl.Color) {
	// TODO: ...
	assert_contextless(js.IsObject(color_obj))
	obj_class, obj_class_ok := js.GetClassID(color_obj)
	assert_contextless(obj_class_ok && obj_class == color_class_id)

	raw_color := ColorToRawValue(ctx, color)

	js.SetPropertyCStr(ctx, color_obj, "__raw_color", raw_color)
}
color_class_constructor :: proc(ctx: js.Context, new_target: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: respect subclassed prototype or whatever it's called
	color: rl.Color

	if len(args) == 1 {
		// TODO: throw exception, don't assert
		assert(js.IsNumber(args[0]))

		g, ok := js.ToI32(ctx, args[0])
		assert(ok)
		assert(0 <= g && g < 256)
		color = { u8(g), u8(g), u8(g), 255 }
	} else if len(args) == 2 {
		// TODO: throw exception, don't assert
		assert(js.IsNumber(args[0]))
		assert(js.IsNumber(args[1]))

		g, a: i32
		ok: bool
		g, ok = js.ToI32(ctx, args[0])
		assert(ok)
		assert(0 <= g && g < 256)
		a, ok = js.ToI32(ctx, args[1])
		assert(ok)
		assert(0 <= a && a < 256)
		color = { u8(g), u8(g), u8(g), u8(a) }
	} else if len(args) == 3 {
		// TODO: throw exception, don't assert
		assert(js.IsNumber(args[0]))
		assert(js.IsNumber(args[1]))
		assert(js.IsNumber(args[2]))

		r, g, b: i32
		ok: bool
		r, ok = js.ToI32(ctx, args[0])
		assert(ok)
		assert(0 <= r && r < 256)
		g, ok = js.ToI32(ctx, args[1])
		assert(ok)
		assert(0 <= g && g < 256)
		b, ok = js.ToI32(ctx, args[2])
		assert(ok)
		assert(0 <= b && b < 256)
		color = { u8(r), u8(g), u8(b), 255 }
	} else if len(args) == 4 {
		// TODO: throw exception, don't assert
		assert(js.IsNumber(args[0]))
		assert(js.IsNumber(args[1]))
		assert(js.IsNumber(args[2]))
		assert(js.IsNumber(args[3]))

		r, g, b, a: i32
		ok: bool
		r, ok = js.ToI32(ctx, args[0])
		assert(ok)
		assert(0 <= r && r < 256)
		g, ok = js.ToI32(ctx, args[1])
		assert(ok)
		assert(0 <= g && g < 256)
		b, ok = js.ToI32(ctx, args[2])
		assert(ok)
		assert(0 <= b && b < 256)
		a, ok = js.ToI32(ctx, args[3])
		assert(ok)
		assert(0 <= a && a < 256)
		color = { u8(r), u8(g), u8(b), u8(a) }
	} else do panic("too many arguments")

	res := js.NewObjectClass(ctx, color_class_id)
	if js.IsException(res) do return res

	_set_color(ctx, res, color)

	return res
}
color_class_get_r :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return js.NewInt(ctx, int(_get_color(ctx, this).r))
}
color_class_set_r :: proc"c"(ctx: js.Context, this: js.Value_Const, val: js.Value_Const) -> js.Value {
	// TODO: etc etc
	assert_contextless(js.IsNumber(val))

	r: i32
	ok: bool
	r, ok = js.ToI32(ctx, val)
	assert_contextless(ok)
	assert_contextless(0 <= r && r < 256)

	color := _get_color(ctx, this)

	color.r = u8(r)

	_set_color(ctx, this, color)

	return js.UNDEFINED
}
color_class_get_g :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return js.NewInt(ctx, int(_get_color(ctx, this).g))
}
color_class_set_g :: proc"c"(ctx: js.Context, this: js.Value_Const, val: js.Value_Const) -> js.Value {
	// TODO: etc etc
	assert_contextless(js.IsNumber(val))

	g: i32
	ok: bool
	g, ok = js.ToI32(ctx, val)
	assert_contextless(ok)
	assert_contextless(0 <= g && g < 256)

	color := _get_color(ctx, this)

	color.g = u8(g)

	_set_color(ctx, this, color)

	return js.UNDEFINED
}
color_class_get_b :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return js.NewInt(ctx, int(_get_color(ctx, this).b))
}
color_class_set_b :: proc"c"(ctx: js.Context, this: js.Value_Const, val: js.Value_Const) -> js.Value {
	// TODO: etc etc
	assert_contextless(js.IsNumber(val))

	b: i32
	ok: bool
	b, ok = js.ToI32(ctx, val)
	assert_contextless(ok)
	assert_contextless(0 <= b && b < 256)

	color := _get_color(ctx, this)

	color.b = u8(b)

	_set_color(ctx, this, color)

	return js.UNDEFINED
}
color_class_get_a :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return js.NewInt(ctx, int(_get_color(ctx, this).a))
}
color_class_set_a :: proc"c"(ctx: js.Context, this: js.Value_Const, val: js.Value_Const) -> js.Value {
	// TODO: etc etc
	assert_contextless(js.IsNumber(val))

	a: i32
	ok: bool
	a, ok = js.ToI32(ctx, val)
	assert_contextless(ok)
	assert_contextless(0 <= a && a < 256)

	color := _get_color(ctx, this)

	color.a = u8(a)

	_set_color(ctx, this, color)

	return js.UNDEFINED
}
color_class_to_string :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 0)

	c := _get_color(ctx, this)
	print_buf: [128]u8
	str := fmt.bprintf(print_buf[:], "Color %c r: %d, g: %d, b: %d, a: %d %c", '{', c.r, c.g, c.b, c.a, '}')

	return js.NewString(ctx, str)
}
color_proto_funcs := [?]js.Raw_Function_List_Entry {
	js.raw_getset_def("r", color_class_get_r, color_class_set_r),
	js.raw_getset_def("g", color_class_get_g, color_class_set_g),
	js.raw_getset_def("b", color_class_get_b, color_class_set_b),
	js.raw_getset_def("a", color_class_get_a, color_class_set_a),

	js.raw_func_def("toString", 0, js.native_to_raw_function(color_class_to_string)),
}
define_color_class :: proc(rt: js.Runtime, ctx: js.Context, global_obj: js.Value) {
	assert(color_class_id == 0, "define_color_class shouldn't be called more than once!")

	js.NewClassID(&color_class_id) // should this return value be used??

	assert(js.NewClass(rt, color_class_id, color_class_def))

	proto := js.NewObject(ctx)

	js.SetPropertyFunctionList(
		ctx,
		proto,
		color_proto_funcs[:],
	)
	Symbol := js.GetPropertyCStr(ctx, global_obj, "Symbol")
	defer js.FreeValue(ctx, Symbol)
	to_string_tag := js.GetPropertyCStr(ctx, Symbol, "toStringTag")
	defer js.FreeValue(ctx, to_string_tag)
	assert(!js.IsException(to_string_tag))
	js.SetProperty(ctx, proto, js.ValueToAtom(ctx, to_string_tag), js.NewString_OStr(ctx, "Color"))

	js.SetClassProto(ctx, color_class_id, proto)

	ctor := js.NewRawFunction2(
		ctx,
		js.native_to_raw_function_stateless(color_class_constructor),
		"Color",
		0,
		.constructor,
		0,
	)

	//js.SetConstructor2(ctx, ctor, proto, js.PROP_WRITABLE | js.PROP_CONFIGURABLE)
	js.SetConstructor(ctx, ctor, proto)

	js.SetPropertyCStr(ctx, global_obj, "Color", ctor)
}
