package thunderbolt

import "core:fmt"

import rl "vendor:raylib"

import js "vendor/quickjs_odin"

cColor := Class {
	def = { class_name = "Color" },
	ctor = js.native_to_raw_function(proc(
		ctx: js.Context,
		new_target: js.Value_Const,
		args: ..js.Value_Const,
	) -> js.Value {
		// TODO: respect subclassed prototype or whatever it's called
		color: rl.Color

		typecheck :: proc(
			ctx: js.Context,
			args: []js.Value_Const,
			n: int,
		) -> (
			err: js.Value,
			ok: bool,
		) {
			if js.IsNumber(args[n]) do return {}, true
			// TODO: stringify the offending value?
			return js.ThrowTypeError(
				ctx,
				"new Color(...) expected argument %d to be a number",
				n,
			), false
		}

		munch :: proc(
			ctx: js.Context,
			args: []js.Value_Const,
			n: int,
		) -> (
			component: u8,
			err: js.Value,
			ok: bool,
		) {
			ival: i32
			ival, ok = js.ToI32(ctx, args[n])
			if !ok {
				// TODO: stringify the offending value?
				return 0, js.ThrowTypeError(
					ctx,
					"new Color(...) failed to interpret argument %d as an integer",
					n,
				), false
			}
			if ival < 0 || 255 < ival {
				return 0, js.ThrowTypeError(
					ctx,
					"new Color(...) %d should be in the range [0, 255], but got %d",
					n, ival,
				), false
			}
			return u8(ival), {}, true
		}

		if len(args) == 0 || len(args) > 4 {
			return js.ThrowTypeError(
				ctx,
				"new Color(...) expected between 1 and 4 arguments, but %d given",
				len(args),
			)
		}

		r, g, b, a: u8
		err: js.Value
		ok: bool

		for i in 0..<len(args) {
			err, ok = typecheck(ctx, args, i)
			if !ok do return err
		}

		switch len(args) {
		case 1:
			g, err, ok = munch(ctx, args, 0)
			if !ok do return err

			color = { g, g, g, 255 }
		case 2:
			g, err, ok = munch(ctx, args, 0)
			if !ok do return err
			a, err, ok = munch(ctx, args, 1)
			if !ok do return err

			color = { g, g, g, a }
		case 3:
			r, err, ok = munch(ctx, args, 0)
			if !ok do return err
			g, err, ok = munch(ctx, args, 1)
			if !ok do return err
			b, err, ok = munch(ctx, args, 2)
			if !ok do return err

			color = { r, g, b, 255 }
		case 4:
			r, err, ok = munch(ctx, args, 0)
			if !ok do return err
			g, err, ok = munch(ctx, args, 1)
			if !ok do return err
			b, err, ok = munch(ctx, args, 2)
			if !ok do return err
			a, err, ok = munch(ctx, args, 3)
			if !ok do return err

			color = { r, g, b, a }
		}

		res := js.NewObjectClass(ctx, cColor.id)
		if js.IsException(res) do return res

		assert(cColor_set_color(ctx, res, color))

		return res
	}),
	funcs = {
		js.raw_getset_def("r", cColor_get_r, cColor_set_r),
		js.raw_getset_def("g", cColor_get_g, cColor_set_g),
		js.raw_getset_def("b", cColor_get_b, cColor_set_b),
		js.raw_getset_def("a", cColor_get_a, cColor_set_a),

		js.raw_func_def("toString", 0, js.native_to_raw_function(cColor_toString)),
	},
	setup = proc(
		ctx: js.Context,
		global_obj: js.Value_Const,
		_: ^Class,
		_, ctor: js.Value,
	) -> (ok: bool) {
		for elem in default_colors {
			js.SetPropertyStr(
				ctx,
				global_obj,
				elem.name,
				cColor_make(ctx, elem.color),
			)
			js.SetPropertyStr(ctx,
				ctor,
				elem.name,
				cColor_make(ctx, elem.color),
			)
		}

		return true
	}
}

cColor_make :: proc(ctx: js.Context, color: rl.Color) -> js.Value {
	res := js.NewObjectClass(ctx, cColor.id)
	assert(!js.IsException(res))
	if !cColor_set_color(ctx, res, color) {
		dump_exception(ctx)
		assert(false, "cColor_set_color in cColor_make failed??")
	}
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

color_to_raw_value :: proc"contextless"(ctx: js.Context, color: rl.Color) -> js.Value {
	return js.NewI32(ctx, transmute(i32) color)
}
raw_value_to_color :: proc"contextless"(
	ctx: js.Context,
	v: js.Value_Const,
) -> (
	res: rl.Color,
	ok: bool,
) {
	return transmute(rl.Color) js.ToI32(ctx, v) or_return, true
}
IsRawColor :: proc(v: js.Value_Const) -> bool {
	return js.tag_of(v) == .Int
}

cColor_get_color :: proc"contextless"(
	ctx: js.Context,
	color_obj: js.Value_Const,
	throw := true,
) -> (
	color: rl.Color,
	ok: bool,
) #optional_ok {
	defer if throw && !ok {
		js.ThrowTypeError(ctx, "Tried getting the internal color value of a non-Color object or an invalid Color object")
	}

	if !IsOfClass(cColor, color_obj) do return {}, false

	raw_color := js.GetPropertyCStr(ctx, color_obj, "__raw_color")
	if js.tag_of(raw_color) != .Int do return {}, false

	return raw_value_to_color(ctx, raw_color)
}
cColor_set_color :: proc"contextless"(
	ctx: js.Context,
	color_obj: js.Value_Const,
	color: rl.Color,
	throw := true,
) -> (ok: bool) {
	if !IsOfClass(cColor, color_obj) {
		if throw do js.ThrowTypeError(
			ctx,
			"Tried setting the internal color value of a non-Color object",
		)
		return false
	}

	raw_color := color_to_raw_value(ctx, color)

	if !js.SetPropertyCStr(ctx, color_obj, "__raw_color", raw_color) {
		if throw do js.ThrowInternalError(
			ctx,
			"Failed setting the __raw_color attribute of a Color object"
		)

		return false
	}

	return true
}

@(private="file")
_cColor_get_comp :: #force_inline proc"contextless"(
	ctx: js.Context,
	this: js.Value_Const,
	$comp_no: int,
) -> js.Value {
	color, ok := cColor_get_color(ctx, this)
	if !ok do return js.EXCEPTION
	return js.NewInt(ctx, int(color[comp_no]))
}
@(private="file")
_cColor_set_comp :: #force_inline proc"contextless"(
	ctx: js.Context,
	this: js.Value_Const,
	val: js.Value_Const,
	$comp_no: int,
	$comp_name: cstring,
) -> js.Value {
	if !js.IsNumber(val) do return js.ThrowTypeError(
		ctx,
		"Can only set the "+comp_name+" component of a Color to a number value",
	)

	comp: i32
	ok: bool
	comp, ok = js.ToI32(ctx, val)
	if !ok do return js.ThrowTypeError(
		ctx,
		"Failed to interpret ??? as an integer", // TODO: stringify val for display
	)

	if comp < 0 || 255 < comp do return js.ThrowTypeError(
		ctx,
		"Can only set the "+comp_name+" component of a Color to a value in the range [0, 255], got %d",
		comp
	)

	color: rl.Color
	color, ok = cColor_get_color(ctx, this)
	if !ok do return js.EXCEPTION

	color[comp_no] = u8(comp)

	assert_contextless(cColor_set_color(ctx, this, color))

	return js.UNDEFINED
}

cColor_get_r :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return _cColor_get_comp(ctx, this, 0)
}
cColor_set_r :: proc"c"(
	ctx: js.Context,
	this: js.Value_Const,
	val: js.Value_Const,
) -> js.Value {
	return _cColor_set_comp(ctx, this, val, 0, "r")
}
cColor_get_g :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return _cColor_get_comp(ctx, this, 1)
}
cColor_set_g :: proc"c"(
	ctx: js.Context,
	this: js.Value_Const, val: js.Value_Const,
) -> js.Value {
	return _cColor_set_comp(ctx, this, val, 1, "g")
}
cColor_get_b :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return _cColor_get_comp(ctx, this, 2)
}
cColor_set_b :: proc"c"(
	ctx: js.Context,
	this: js.Value_Const,
	val: js.Value_Const,
) -> js.Value {
	return _cColor_set_comp(ctx, this, val, 2, "b")
}
cColor_get_a :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return _cColor_get_comp(ctx, this, 3)
}
cColor_set_a :: proc"c"(
	ctx: js.Context,
	this: js.Value_Const,
	val: js.Value_Const,
) -> js.Value {
	return _cColor_set_comp(ctx, this, val, 3, "a")
}
cColor_toString :: proc(
	ctx: js.Context,
	this: js.Value_Const,
	args: ..js.Value_Const,
) -> js.Value {
	if len(args) != 0 do return js.ThrowTypeError(
		ctx,
		"Color.toString() expected 0 arguments, but %d given",
		len(args),
	)

	c, ok := cColor_get_color(ctx, this)
	if !ok do return js.EXCEPTION
	print_buf: [128]u8
	str := fmt.bprintf(print_buf[:], "Color %c r: %d, g: %d, b: %d, a: %d %c", '{', c.r, c.g, c.b, c.a, '}')

	return js.NewString(ctx, str)
}
