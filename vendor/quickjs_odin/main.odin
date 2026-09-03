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

Raw_Function_List_Entry :: qjs.C_Function_List_Entry
raw_func_def            :: qjs.cfunc_def
raw_getset_def          :: qjs.cgetset_def

Class_Def :: qjs.Class_Def

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

NewContext    :: qjs.NewContext
FreeContext   :: qjs.FreeContext
DupContext    :: qjs.DupContext
// Get/SetContextOpaqu
GetRuntime    :: qjs.GetRuntime
SetClassProto :: qjs.SetClassProto
GetClassProto :: qjs.GetClassProto

ValueToAtom :: qjs.ValueToAtom

NewClassID :: qjs.NewClassID
GetClassID :: proc"contextless"(v: Value) -> (id: Class_Id, ok: bool) {
	if id = qjs.GetClassID(v); id == qjs.INVALID_CLASS_ID {
		return 0, false
	} else do return id, true
}
NewClass :: proc"contextless"(rt: Runtime, class_id: Class_Id, #by_ptr class_def: Class_Def) -> (ok: bool) {
	return qjs.NewClass(rt, class_id, class_def) == 0
}

IsJobPending      :: proc"contextless"(rt: Runtime) -> bool {
	return qjs.IsJobPending(rt) != 0
}
ExecutePendingJob :: proc"contextless"(rt: Runtime, ctx: ^Context) -> (ok: bool) {
	return qjs.ExecutePendingJob(rt, ctx) == 0
}

GetException :: qjs.GetException

GetProperty     :: qjs.GetProperty
GetPropertyCStr :: qjs.GetPropertyStr
GetPropertyOStr :: proc(ctx: Context, obj: Value_Const, prop: string) -> Value {
	cprop := strings.clone_to_cstring(prop)
	defer free(rawptr(cprop))
	return qjs.GetPropertyStr(ctx, obj, cprop)
}
GetPropertyStr  :: proc { GetPropertyCStr, GetPropertyOStr }
SetProperty     :: proc"contextless"(ctx: Context, obj: Value_Const, prop: Atom, val: Value) -> (ok: bool) {
	return qjs.SetProperty(ctx, obj, prop, val) == 0
}
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
NewObjectClass  :: proc"contextless"(ctx: Context, class_id: Class_Id) -> Value {
	return qjs.NewObjectClass(ctx, c.int(class_id))
}
NewBool         :: proc"contextless"(ctx: Context, val: bool) -> Value {
	return raw_value(.Bool, { uint64 = u64(val) })
}
NewInt          :: proc"contextless"(ctx: Context, val: int) -> Value {
	return qjs.NewInt64(ctx, i64(val))
}
NewI32          :: qjs.NewInt32
NewBigInt_Int   :: proc"contextless"(ctx: Context, val: int) -> Value {
	return qjs.NewBigInt64(ctx, i64(val))
}
NewBigInt_UInt   :: proc"contextless"(ctx: Context, val: uint) -> Value {
	return qjs.NewBigUint64(ctx, u64(val))
}
NewBigInt_I64   :: qjs.NewBigInt64
NewBigInt_U64   :: qjs.NewBigUint64
NewBigInt       :: proc { NewBigInt_Int, NewBigInt_UInt, NewBigInt_I64, NewBigInt_U64 }
NewF64          :: qjs.NewFloat64
NewRawFunction2 :: proc"contextless"(ctx: Context, func: Raw_Function, name: cstring, no_of_non_optional_params: int, cproto: Raw_Function_Enum, magic: int) -> Value {
	return qjs.NewCFunction2(ctx, func, name, c.int(no_of_non_optional_params), cproto, c.int(magic))
}
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
IsBigInt        :: qjs.IsBigInt
IsNull          :: qjs.IsNull
IsUndefined     :: qjs.IsUndefined
IsException     :: qjs.IsException
IsUninitialized :: qjs.IsUninitialized
IsString        :: qjs.IsString
IsObject        :: qjs.IsObject
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
ToI32       :: proc"contextless"(ctx: Context, val: Value_Const) -> (res: i32, ok: bool) {
	int32: i32
	if qjs.ToInt32(ctx, &int32, val) != 0 do return {}, false
	else do return int32, true
}
ToF64       :: proc"contextless"(ctx: Context, val: Value_Const) -> (res: f64, ok: bool) {
	float64: f64
	if qjs.ToFloat64(ctx, &float64, val) != 0 do return {}, false
	else do return float64, true
}
ToBigI64    :: proc"contextless"(ctx: Context, val: Value_Const) -> (res: i64, ok: bool) {
	int64: i64
	if qjs.ToBigInt64(ctx, &int64, val) != 0 do return {}, false
	else do return int64, true
}
ToBigInt    :: proc"contextless"(ctx: Context, val: Value_Const) -> (res: int, ok: bool) {
	return int(ToBigI64(ctx, val) or_return), true
}
ToCString   :: qjs.ToCString
ToString    :: proc(ctx: Context, val: Value_Const) -> (res: string, ok: bool) {
	cres := ToCString(ctx, val)
	if cres == nil do return "", false
	defer FreeCString(ctx, cres)
	return strings.clone_from(cres), true
}
FreeCString :: qjs.FreeCString

SetPropertyFunctionList :: proc"contextless"(ctx: Context, obj: Value_Const, tab: []Raw_Function_List_Entry) -> (ok: bool) {
	return qjs.SetPropertyFunctionList(ctx, obj, raw_data(tab), c.int(len(tab))) == 0
}
SetConstructor  :: proc"contextless"(ctx: Context, func_obj: Value_Const, proto: Value_Const) -> (ok: bool) {
	return qjs.SetConstructor(ctx, func_obj, proto) == 0
}
