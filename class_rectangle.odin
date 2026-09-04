package thunderbolt

import "core:fmt"

import rl "vendor:raylib"

import js "vendor/quickjs_odin"

cRectangle := Class {
	def = { class_name = "Rectangle" },
	ctor = ctor_of("Rectangle", proc(
		ctx: js.Context,
		new_target: js.Value_Const,
		args: ..js.Value_Const,
	) -> js.Value {
		// TODO: respect subclassed prototype or whatever it's called
		rect: rl.Rectangle

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
				"new Rectangle(...) expected argument %d to be a number",
				n
			), false
		}

		munch :: proc(
			ctx: js.Context,
			args: []js.Value_Const,
			n: int,
		) -> (
			component: f32,
			err: js.Value,
			ok: bool,
		) {
			fval: f64
			fval, ok = js.ToF64(ctx, args[n])
			if !ok {
				// TODO: stringify the offending value?
				return 0, js.ThrowTypeError(
					ctx,
					"new Rectangle(...) failed to interpret argument %d as a float",
					n,
				), false
			}
			return f32(fval), {}, true
		}

		if len(args) != 4 do return js.ThrowTypeError(
			ctx,
			"new Rectangle(...) expected 4 arguments, but %d was given",
			len(args)
		)

		err: js.Value
		ok: bool

		#unroll for i in 0..<4 {
			err, ok = typecheck(ctx, args, i)
			if !ok do return err
		}

		rect.x, err, ok = munch(ctx, args, 0)
		if !ok do return err
		rect.y, err, ok = munch(ctx, args, 1)
		if !ok do return err
		rect.width, err, ok = munch(ctx, args, 2)
		if !ok do return err
		rect.height, err, ok = munch(ctx, args, 3)
		if !ok do return err

		res := js.NewObjectClass(ctx, cRectangle.id)
		if js.IsException(res) do return res

		if !cRectangle_set_rectangle(ctx, res, rect) {
			dump_exception(ctx)
			assert(false, "cRectangle_set_rectangle in cRectangle.ctor")
		}

		return res
	}),
	funcs = {
		js.raw_getset_def("x", cRectangle_get_x, cRectangle_set_x),
		js.raw_getset_def("y", cRectangle_get_y, cRectangle_set_y),
		js.raw_getset_def("w", cRectangle_get_width, cRectangle_set_width),
		js.raw_getset_def("width", cRectangle_get_width, cRectangle_set_width),
		js.raw_getset_def("h", cRectangle_get_height, cRectangle_set_height),
		js.raw_getset_def("height", cRectangle_get_height, cRectangle_set_height),

		js.raw_func_def("toString", 0, js.native_to_raw_function(cRectangle_toString)),
	},
}

cRectangle_make :: proc(ctx: js.Context, rect: rl.Rectangle) -> js.Value {
	res := js.NewObjectClass(ctx, cRectangle.id)
	assert(!js.IsException(res))
	if !cRectangle_set_rectangle(ctx, res, rect) {
		dump_exception(ctx)
		assert(false, "cRectangle_set_rectangle is cRectangle_make failed??")
	}
	return res
}

cRectangle_get_rectangle :: proc"contextless"(
	ctx: js.Context,
	rectangle_obj: js.Value_Const,
	throw := true,
) -> (
	rectangle: rl.Rectangle,
	ok: bool,
) #optional_ok {
	if !IsOfClass(cRectangle, rectangle_obj) {
		if throw do js.ThrowTypeError(
			ctx,
			"Tried transforming a non-Rectangle object into a raylib Rectangle",
		)
		return {}, false
	}

	rectangle.x, ok = _cRectangle_get_f32_comp(ctx, rectangle_obj, "x", throw=throw)
	if !ok do return {}, false
	rectangle.y, ok = _cRectangle_get_f32_comp(ctx, rectangle_obj, "y", throw=throw)
	if !ok do return {}, false
	rectangle.width, ok = _cRectangle_get_f32_comp(
		ctx, rectangle_obj, "width", throw=throw,
	)
	if !ok do return {}, false
	rectangle.height, ok = _cRectangle_get_f32_comp(
		ctx, rectangle_obj, "height", throw=throw,
	)
	if !ok do return {}, false

	return rectangle, true
}
cRectangle_set_rectangle :: proc"contextless"(
	ctx: js.Context,
	rectangle_obj: js.Value_Const,
	rectangle: rl.Rectangle,
	throw := true
) -> (ok: bool) {
	if !IsOfClass(cRectangle, rectangle_obj) {
		if throw do js.ThrowTypeError(
			ctx,
			"Tried transforming a raylib Rectangle to a non-Rectangle object",
		)
		return false
	}

	_cRectangle_set_f32_comp(
		ctx, rectangle_obj, "x", rectangle.x, throw=throw,
	) or_return
	_cRectangle_set_f32_comp(
		ctx, rectangle_obj, "y", rectangle.y, throw=throw,
	) or_return
	_cRectangle_set_f32_comp(
		ctx, rectangle_obj, "width", rectangle.width, throw=throw,
	) or_return
	_cRectangle_set_f32_comp(
		ctx, rectangle_obj, "height", rectangle.height, throw=throw,
	) or_return

	return true
}

@(private="file")
_cRectangle_get_f32_comp :: #force_inline proc"contextless"(
	ctx: js.Context,
	this: js.Value_Const,
	$comp_name: cstring,
	throw: bool,
) -> (
	comp: f32,
	ok: bool,
) {
	#assert(
		comp_name == "x" ||
		comp_name == "y" ||
		comp_name == "width" ||
		comp_name == "height"
	)

	assert_contextless(IsOfClass(cRectangle, this))

	js_comp := js.GetPropertyStr(ctx, this, "__" + comp_name)
	if !js.IsNumber(js_comp) {
		if throw do js.ThrowTypeError(
			ctx,
			"Rectangle." + comp_name + " is not a number!",
		)
		return 0, false
	}
	fval: f64
	fval, ok = js.ToF64(ctx, js_comp)
	assert_contextless(ok)

	return f32(fval), true
}
@(private="file")
_cRectangle_set_f32_comp :: #force_inline proc"contextless"(
	ctx: js.Context,
	this: js.Value_Const,
	$comp_name: cstring,
	comp: f32,
	throw: bool,
) -> (ok: bool) {
	#assert(
		comp_name == "x" ||
		comp_name == "y" ||
		comp_name == "width" ||
		comp_name == "height"
	)

	assert_contextless(IsOfClass(cRectangle, this))

	js_comp := js.NewF64(ctx, f64(comp))
	if !js.IsNumber(js_comp) {
		if throw do js.ThrowTypeError(
			ctx,
			"failed converting %f to JS number",
			comp,
		)
		return false
	}

	if !js.SetPropertyStr(ctx, this, "__" + comp_name, js_comp) {
		if throw do js.ThrowTypeError(
			ctx,
			"failed setting Rectangle." + comp_name,
		)
		return false
	}

	return true
}

@(private="file")
_cRectangle_setter_body :: #force_inline proc"contextless"(
	ctx: js.Context,
	this: js.Value_Const,
	val: js.Value_Const,
	$comp_name: cstring,
) -> js.Value {
	#assert(
		comp_name == "x" ||
		comp_name == "y" ||
		comp_name == "width" ||
		comp_name == "height"
	)

	if !js.IsNumber(val) do return js.ThrowTypeError(
		ctx,
		"Can only set Rectangle." + comp_name + " to a number value",
	)

	if !js.SetPropertyStr(ctx, this, "__" + comp_name, val) {
		return js.ThrowTypeError(
			ctx,
			"failed setting Rectangle." + comp_name,
		)
	}

	return js.UNDEFINED
}

cRectangle_get_x :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return js.GetPropertyCStr(ctx, this, "__x")
}
cRectangle_set_x :: proc"c"(
	ctx: js.Context,
	this: js.Value_Const,
	val: js.Value_Const,
) -> js.Value {
	return _cRectangle_setter_body(ctx, this, val, "x")
}
cRectangle_get_y :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return js.GetPropertyCStr(ctx, this, "__y")
}
cRectangle_set_y :: proc"c"(
	ctx: js.Context,
	this: js.Value_Const,
	val: js.Value_Const,
) -> js.Value {
	return _cRectangle_setter_body(ctx, this, val, "y")
}
cRectangle_get_width :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return js.GetPropertyCStr(ctx, this, "__width")
}
cRectangle_set_width :: proc"c"(
	ctx: js.Context,
	this: js.Value_Const,
	val: js.Value_Const,
) -> js.Value {
	return _cRectangle_setter_body(ctx, this, val, "width")
}
cRectangle_get_height :: proc"c"(ctx: js.Context, this: js.Value_Const) -> js.Value {
	return js.GetPropertyCStr(ctx, this, "__height")
}
cRectangle_set_height :: proc"c"(
	ctx: js.Context,
	this: js.Value_Const,
	val: js.Value_Const,
) -> js.Value {
	return _cRectangle_setter_body(ctx, this, val, "height")
}
cRectangle_toString :: proc(
	ctx: js.Context,
	this: js.Value_Const,
	args: ..js.Value_Const,
) -> js.Value {
	if len(args) != 0 do return js.ThrowTypeError(
		ctx,
		"Rectangle.toString() expected 0 arguments, but %d was given",
		len(args),
	)

	r, ok := cRectangle_get_rectangle(ctx, this)
	if !ok do return js.EXCEPTION
	print_buf: [128]u8
	str := fmt.bprintf(print_buf[:], "Rectangle %c x: %f, y: %f, width: %f, height: %f %c", '{', r.x, r.y, r.width, r.height, '}')

	return js.NewString(ctx, str)
}
