package thunderbolt

import "core:c"
import "core:fmt"
import "core:slice"

import js "vendor/quickjs_odin"

Class :: struct {
	id: js.Class_Id,
	def: js.Class_Def,
	ctor: Constructor,
	funcs: []js.Raw_Function_List_Entry,
	setup: Setup_Proc,
}

Constructor :: js.Raw_Function
Setup_Proc  :: #type proc(
	ctx: js.Context,
	global_obj: js.Value_Const,
	class: ^Class,
	proto, ctor: js.Value,
) -> (ok: bool)

ctor_of :: proc"contextless"(
	$name: string,
	$ctor: js.Native_Function_Stateless,
) -> Constructor {
	raw_func :: proc"c"(ctx: js.Context, this: js.Value_Const, argc: c.int, argv: [^]js.Value_Const) -> js.Value {
		state := js.GetRuntimeOpaque(^js.Context_Wrapper, js.GetRuntime(ctx))

		context = state.ctx

		args := slice.from_ptr(argv, int(argc))

		return ctor(ctx, this, ..args)
	}

	return raw_func
}

IsOfClass :: proc"contextless"(class: Class, val: js.Value) -> bool {
	if !js.IsObject(val) do return false
	class_id, ok := js.GetClassID(val)
	return ok && class_id == class.id
}

class_registry := [?]^Class {
	&cColor,
	&cRectangle,
}

register_class :: proc(
	rt: js.Runtime,
	ctx: js.Context,
	global_obj: js.Value_Const,
	class: ^Class
) -> (ok: bool) {
	fmt.assertf(class.id == 0, "register_class shouldn't be called more than once per class! called again with class %s.", class.def.class_name)

	js.NewClassID(&class.id)

	js.NewClass(rt, class.id, class.def) or_return

	proto := js.NewObject(ctx)

	js.SetPropertyFunctionList(ctx, proto, class.funcs)
	
	Symbol := js.GetPropertyCStr(ctx, global_obj, "Symbol")
	defer js.FreeValue(ctx, Symbol)
	to_string_tag := js.GetPropertyCStr(ctx, Symbol, "toStringTag")
	defer js.FreeValue(ctx, to_string_tag)
	assert(!js.IsException(to_string_tag))
	js.SetProperty(
		ctx,
		proto,
		js.ValueToAtom(ctx, to_string_tag),
		js.NewString(ctx, class.def.class_name),
	)

	js.SetClassProto(ctx, class.id, proto)

	ctor := js.NewRawFunction2(
		ctx,
		class.ctor,
		"Color",
		0,
		.constructor,
		0,
	)

	//js.SetConstructor2(ctx, ctor, proto, js.PROP_WRITABLE | js.PROP_CONFIGURABLE)
	js.SetConstructor(ctx, ctor, proto)

	js.SetPropertyStr(ctx, global_obj, class.def.class_name, ctor)

	if class.setup != nil do class.setup(ctx, global_obj, class, proto, ctor) or_return

	return true
}
