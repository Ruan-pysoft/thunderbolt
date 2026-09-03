package thunderbolt

import "core:c"
import "core:fmt"
import "core:strings"

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

DEFAULT_FPS :: c.int(16)
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

	raylib_update_properties(ctx)

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
	assert(js.IsObject(args[4]))
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

js_DrawCircle :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 4)
	assert(js.IsNumber(args[0]))
	assert(js.IsNumber(args[1]))
	assert(js.IsNumber(args[2]))
	assert(js.IsObject(args[3]))
	args3_class, args3_class_ok := js.GetClassID(args[3])
	assert(args3_class_ok && args3_class == color_class_id)

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

	rl.DrawCircle(x, y, f32(radius), _get_color(ctx, args[3]))

	return js.UNDEFINED
}

js_DrawText :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 5)
	assert(js.IsString(args[0]))
	assert(js.IsNumber(args[1]))
	assert(js.IsNumber(args[2]))
	assert(js.IsNumber(args[3]))
	assert(js.IsObject(args[4]))
	args4_class, args4_class_ok := js.GetClassID(args[4])
	assert(args4_class_ok && args4_class == color_class_id)

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
	color := _get_color(ctx, args[4])

	rl.DrawText(text, x, y, font_size, color)

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

install_raylib :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)
	ClearBackground_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_ClearBackground), "ClearBackground", 1)
	DrawRectangle_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_DrawRectangle), "DrawRectangle", 5)
	DrawCircle_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_DrawCircle), "DrawCircle", 4)
	DrawText_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_DrawText), "DrawText", 5)
	MeasureText_fn := js.NewRawFunction(ctx, js.native_to_raw_function(js_MeasureText), "MeasureText", 2)

	js.SetPropertyCStr(ctx, global_obj, "ClearBackground", ClearBackground_fn)
	js.SetPropertyCStr(ctx, global_obj, "DrawRectangle", DrawRectangle_fn)
	js.SetPropertyCStr(ctx, global_obj, "DrawCircle", DrawCircle_fn)
	js.SetPropertyCStr(ctx, global_obj, "DrawText", DrawText_fn)
	js.SetPropertyCStr(ctx, global_obj, "MeasureText", MeasureText_fn)

	js.SetPropertyCStr(ctx, global_obj, "fps", js.NewInt(ctx, int(DEFAULT_FPS)))
	js.SetPropertyCStr(ctx, global_obj, "window_width", js.NewInt(ctx, int(DEFAULT_WIDTH)))
	js.SetPropertyCStr(ctx, global_obj, "window_height", js.NewInt(ctx, int(DEFAULT_HEIGHT)))
	js.SetPropertyCStr(ctx, global_obj, "window_title", js.NewString(ctx, DEFAULT_TITLE))

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
make_js_color :: proc(ctx: js.Context, color: rl.Color) -> js.Value {
	res := js.NewObjectClass(ctx, color_class_id)
	assert(!js.IsException(res)) // TODO: ...
	_set_color(ctx, res, color)
	return res
}
default_colors := [?]struct { name: string, color: rl.Color } {
	{ "LIGHTGRAY", rl.LIGHTGRAY },
	{ "GRAY", rl.GRAY },
	{ "DARKGRAY", rl.DARKGRAY },
	{ "YELLOW", rl.YELLOW },
	{ "GOLD", rl.GOLD },
	{ "ORANGE", rl.ORANGE },
	{ "PINK", rl.PINK },
	{ "RED", rl.RED },
	{ "MAROON", rl.MAROON },
	{ "GREEN", rl.GREEN },
	{ "LIME", rl.LIME },
	{ "DARKGREEN", rl.DARKGREEN },
	{ "SKYBLUE", rl.SKYBLUE },
	{ "BLUE", rl.BLUE },
	{ "DARKBLUE", rl.DARKBLUE },
	{ "PURPLE", rl.PURPLE },
	{ "VIOLET", rl.VIOLET },
	{ "DARKPURPLE", rl.DARKPURPLE },
	{ "BEIGE", rl.BEIGE },
	{ "BROWN", rl.BROWN },
	{ "DARKBROWN", rl.DARKBROWN },

	{ "WHITE", rl.WHITE },
	{ "BLACK", rl.BLACK },
	{ "BLANK", rl.BLANK },
	{ "MAGENTA", rl.MAGENTA },
	{ "RAYWHITE", rl.RAYWHITE },
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

	for elem in default_colors {
		js.SetPropertyStr(ctx, global_obj, elem.name, make_js_color(ctx, elem.color))
		js.SetPropertyStr(ctx, ctor, elem.name, make_js_color(ctx, elem.color))
	}
}
