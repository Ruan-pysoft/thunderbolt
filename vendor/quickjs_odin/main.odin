package quickjs_odin

import "base:runtime"

import "core:c"
import "core:slice"
import "core:strings"

import qjs "../quickjs"

Context  :: qjs.Context
Runtime  :: qjs.Runtime
Class    :: qjs.Class
Class_Id :: qjs.Class_Id
Atom     :: qjs.Atom
Tag      :: qjs.Tag

Value       :: qjs.Value
Value_Const :: qjs.Value_Const

Eval_Type  :: qjs.Eval_Type
Eval_Flags :: qjs.Eval_Flags

Raw_Function       :: qjs.C_Function
Raw_Function_Magic :: qjs.C_Function_Magic
Raw_Function_Data  :: qjs.C_Function_Data
Raw_Function_Enum  :: qjs.C_Function_Enum

// WARN: the code becomes a bit gnarly here... there is probably a better way to do this

// WARN: any state struct should have a Context_Wrapper as its first field
Context_Wrapper :: struct {
	ctx: runtime.Context,
}

Native_Function_Stateful  :: #type proc(ctx: Context, state: ^Context_Wrapper, this: Value_Const, args: ..Value_Const) -> Value
Native_Function_Stateless :: #type proc(ctx: Context, this: Value_Const, args: ..Value_Const) -> Value
native_to_raw_function_stateful :: proc"contextless"($fn: Native_Function_Stateful) -> Raw_Function {
	raw_func :: proc"c"(ctx: Context, this: Value_Const, argc: c.int, argv: [^]Value_Const) -> Value {
		state := GetRuntimeOpaque(^Context_Wrapper, GetRuntime(ctx))

		context = state.ctx

		args := slice.from_ptr(argv, int(argc))

		return fn(ctx, state, this, ..args)
	}

	return raw_func
}
native_poly_to_raw_function_stateful :: proc"contextless"($State: typeid/Context_Wrapper, $fn: proc(ctx: Context, state: ^State, this: Value_Const, args: ..Value_Const) -> Value) -> Raw_Function {
	raw_func :: proc"c"(ctx: Context, this: Value_Const, argc: c.int, argv: [^]Value_Const) -> Value {
		state := GetRuntimeOpaque(^State, GetRuntime(ctx))

		context = (cast(^Context_Wrapper) state).ctx

		args := slice.from_ptr(argv, int(argc))

		return fn(ctx, state, this, ..args)
	}

	return raw_func
}
native_to_raw_function_stateless :: proc"contextless"($fn: Native_Function_Stateless) -> Raw_Function {
	raw_func :: proc"c"(ctx: Context, this: Value_Const, argc: c.int, argv: [^]Value_Const) -> Value {
		state := GetRuntimeOpaque(^Context_Wrapper, GetRuntime(ctx))

		context = state.ctx

		args := slice.from_ptr(argv, int(argc))

		return fn(ctx, this, ..args)
	}

	return raw_func
}
native_to_raw_function :: proc {
	native_to_raw_function_stateful,
	native_poly_to_raw_function_stateful,
	native_to_raw_function_stateless,
}

FLOAT64_NAN   := qjs.FLOAT64_NAN
NULL          := qjs.NULL
UNDEFINED     := qjs.UNDEFINED
FALSE         := qjs.FALSE
TRUE          := qjs.TRUE
EXCEPTION     := qjs.EXCEPTION
UNINITIALIZED := qjs.UNINITIALIZED

tag_of :: proc"contextless"(v: Value) -> Tag {
	return qjs.value_get_tag(v)
}
int_of :: proc"contextless"(v: Value) -> int {
	return qjs.value_get_int(v)
}
bool_of :: proc"contextless"(v: Value) -> bool {
	return qjs.value_get_bool(v)
}
f64_of :: proc"contextless"(v: Value) -> f64 {
	return qjs.value_get_float64(v)
}
ptr_of :: proc"contextless"(v: Value) -> rawptr {
	return qjs.value_get_ptr(v)
}

raw_value :: proc"contextless"(tag: Tag, val: qjs.Value_Union) -> Value {
	return { val, i64(tag) }
}

NewRuntime       :: qjs.NewRuntime
FreeRuntime      :: qjs.FreeRuntime
SetRuntimeOpaque :: proc"contextless"(rt: Runtime, opaque: ^$T) {
	qjs.SetRuntimeOpaque(rt, opaque)
}
GetRuntimeOpaque :: proc"contextless"($T: typeid, rt: Runtime) -> T {
	return cast(T) qjs.GetRuntimeOpaque(rt)
}

NewContext  :: qjs.NewContext
FreeContext :: qjs.FreeContext
GetRuntime  :: qjs.GetRuntime

IsJobPending      :: proc"contextless"(rt: Runtime) -> bool {
	return qjs.IsJobPending(rt) != 0
}
ExecutePendingJob :: proc"contextless"(rt: Runtime, ctx: ^Context) -> (ok: bool) {
	return qjs.ExecutePendingJob(rt, ctx) == 0
}

GetException :: qjs.GetException

GetPropertyCStr :: qjs.GetPropertyStr
GetPropertyOStr :: proc(ctx: Context, obj: Value_Const, prop: string) -> Value {
	cprop := strings.clone_to_cstring(prop)
	defer free(rawptr(cprop))
	return qjs.GetPropertyStr(ctx, obj, cprop)
}
GetPropertyStr :: proc { GetPropertyCStr, GetPropertyOStr }
SetPropertyCStr :: qjs.SetPropertyStr
SetPropertyOStr :: proc(ctx: Context, obj: Value_Const, prop: string, val: Value) -> (ok: bool) {
	cprop := strings.clone_to_cstring(prop)
	defer free(rawptr(cprop))
	return qjs.SetPropertyStr(ctx, obj, cprop, val) == 0
}
SetPropertyStr :: proc { SetPropertyCStr, SetPropertyOStr }

ToStringValue   :: qjs.ToString
NewString_Len   :: proc"contextless"(ctx: Context, str: [^]u8, len: int) -> Value {
	return qjs.NewStringLen(ctx, cast(cstring) str, c.size_t(len))
}
NewString_Slice :: proc"contextless"(ctx: Context, str: []u8) -> Value {
	return qjs.NewStringLen(ctx, cast(cstring) raw_data(str), len(str))
}
NewString_CStr  :: proc"contextless"(ctx: Context, str: cstring) -> Value {
	return qjs.NewStringLen(ctx, str, len(str))
}
NewString_OStr  :: proc"contextless"(ctx: Context, str: string) -> Value {
	return qjs.NewStringLen(ctx, cast(cstring) raw_data(str), len(str))
}
NewString       :: proc {
	NewString_Len, NewString_Slice, NewString_CStr, NewString_OStr,
}
NewObject       :: qjs.NewObject
NewBool         :: proc"contextless"(ctx: Context, val: bool) -> Value {
	return raw_value(.Bool, { uint64 = u64(val) })
}
NewInt          :: proc"contextless"(ctx: Context, val: int) -> Value {
	return qjs.NewInt64(ctx, i64(val))
}
NewF64          :: qjs.NewFloat64
NewRawFunction  :: proc"contextless"(ctx: Context, func: Raw_Function, name: cstring, no_of_non_optional_params: int) -> Value {
	return qjs.NewCFunction(ctx, func, name, c.int(no_of_non_optional_params))
}
/*NewNativeFunction_Stateful :: proc"contextless"(ctx: Context, $func: Native_Function_Stateful, name: cstring, no_of_non_optional_params: int) -> Value {
	return NewRawFunction(ctx, native_to_raw_function(func), name, no_of_non_optional_params)
}
NewNativeFunction_PolyStateful :: proc"contextless"(ctx: Context, $State: typeid/Context_Wrapper, $func: proc(ctx: Context, state: ^State, this: Value_Const, args: ..Value_Const) -> Value, name: cstring, no_of_non_optional_params: int) -> Value {
	return NewRawFunction(ctx, native_to_raw_function(State, func), name, no_of_non_optional_params)
}
NewNativeFunction_Stateless :: proc"contextless"(ctx: Context, $func: Native_Function_Stateless, name: cstring, no_of_non_optional_params: int) -> Value {
	return NewRawFunction(ctx, native_to_raw_function(func), name, no_of_non_optional_params)
}
NewNativeFunction :: proc {
	NewNativeFunction_Stateful,
	NewNativeFunction_PolyStateful,
	NewNativeFunction_Stateless,
}*/
DupValue        :: qjs.DupValue
FreeValue       :: qjs.FreeValue

IsNumber        :: qjs.IsNumber
IsNull          :: qjs.IsNull
IsUndefined     :: qjs.IsUndefined
IsException     :: qjs.IsException
IsUninitialized :: qjs.IsUninitialized
IsString        :: qjs.IsString
IsFunction      :: proc"contextless"(ctx: Context, val: Value_Const) -> bool {
	return qjs.IsFunction(ctx, val) != 0
}

Call            :: proc"contextless"(ctx: Context, func: Value_Const, this: Value_Const, args: ..Value_Const) -> Value {
	return qjs.Call(ctx, func, this, c.int(len(args)), raw_data(args))
}
// TODO: split eval into several functions for different kinds of strings etc
Eval            :: proc"contextless"(ctx: Context, input: string, filename: cstring, eval_flags: Eval_Flags) -> Value {
	return qjs.Eval(ctx, raw_data(input), len(input), filename, eval_flags)
}
GetGlobalObject :: qjs.GetGlobalObject

ToBool      :: proc"contextless"(ctx: Context, val: Value_Const) -> (res: bool, ok: bool) {
	if cbool := qjs.ToBool(ctx, val); cbool == -1 do return {}, false
	else do return cbool != 0, true
}
ToInt       :: proc"contextless"(ctx: Context, val: Value_Const) -> (res: int, ok: bool) {
	int64: i64
	if qjs.ToInt64(ctx, &int64, val) != 0 do return {}, false
	else do return int(int64), true
}
ToF64       :: proc"contextless"(ctx: Context, val: Value_Const) -> (res: f64, ok: bool) {
	float64: f64
	if qjs.ToFloat64(ctx, &float64, val) != 0 do return {}, false
	else do return float64, true
}
ToCString   :: qjs.ToCString
ToString    :: proc(ctx: Context, val: Value_Const) -> (res: string, ok: bool) {
	cres := ToCString(ctx, val)
	if cres == nil do return "", false
	defer FreeCString(ctx, cres)
	return strings.clone_from(cres), true
}
FreeCString :: qjs.FreeCString
