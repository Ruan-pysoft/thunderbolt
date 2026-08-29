package quickjs

import "core:c"
import "core:math"

foreign import quickjs {
	"src/libquickjs.a",
}

Bool     :: c.int
Runtime  :: distinct rawptr
Context  :: distinct rawptr
Class    :: distinct rawptr
Class_Id :: distinct u32
Atom     :: distinct u32

Tag :: enum c.int {
	First            = -9,
	BigInt           = -9,
	Symbol           = -8,
	String           = -7,
	StringRope       = -6,
	Module           = -3,
	FunctionBytecode = -2,
	Object           = -1,

	Int           = 0,
	Bool          = 1,
	Null          = 2,
	Undefined     = 3,
	Uninitialized = 4,
	CatchOffset   = 5,
	Exception     = 6,
	ShortBigInt   = 7,
	Float64       = 8,
}

Ref_Count_Header :: struct {
	ref_count: c.int,
}

FLOAT64_NAN :: math.nan_f64

SHORT_BIG_INT_BITS :: 64 when size_of(rawptr) >= size_of(i64) else 32

Short_Big_Int_T :: i32 when SHORT_BIG_INT_BITS == 32 else i64

Value_Union :: struct #raw_union {
	uint64: u64,
	float64: c.double,
	ptr: rawptr,
	short_big_int: Short_Big_Int_T,
}

Value :: struct {
	using u: Value_Union,
	tag: i64,
}

Value_Const :: Value

value_get_tag :: #force_inline proc(v: Value) -> Tag {
	return Tag(v.tag)
}
value_get_norm_tag :: #force_inline proc(v: Value) -> Tag {
	return value_get_tag(v)
}
value_get_int :: #force_inline proc(v: Value) -> int {
	return int(v.uint64)
}
value_get_bool :: #force_inline proc(v: Value) -> bool {
	return bool(v.uint64)
}
value_get_float64 :: #force_inline proc(v: Value) -> f64 {
	return v.float64
}
value_get_short_big_int :: #force_inline proc(v: Value) -> Short_Big_Int_T {
	return v.short_big_int
}
value_get_ptr :: #force_inline proc(v: Value) -> rawptr {
	return v.ptr
}

mkval :: #force_inline proc(tag: Tag, val: u32) -> Value {
	return {
		{ uint64 = u64(val) },
		i64(tag),
	}
}
mkptr :: #force_inline proc(tag: Tag, p: rawptr) -> Value {
	return {
		{ ptr = p },
		i64(tag),
	}
}

__new_float64 :: #force_inline proc(ctx: ^Context, d: c.double) -> Value {
	v: Value
	v.tag = i64(Tag.Float64)
	v.u.float64 = d
	return v
}
__new_short_big_int :: #force_inline proc(ctx: ^Context, d: i64) -> Value {
	v: Value
	v.tag = i64(Tag.ShortBigInt)
	v.u.short_big_int = Short_Big_Int_T(d)
	return v
}

value_has_ref_count :: #force_inline proc(v: Value) -> bool {
	return (transmute(c.uint) value_get_tag(v)) >= (transmute(c.uint) Tag.First)
}

Eval_Type :: enum c.int {
	Global   = 0,
	Module   = 1,
	Direct   = 2,
	Indirect = 3,
}
Eval_Flags :: bit_field c.int {
	type: Eval_Type         | 2,
	_: int                  | 1,
	strict: bool            | 1,
	_: int                  | 1,
	compile_only: bool      | 1,
	backtrace_barrier: bool | 1,
	async: bool             | 1,
}

@(link_prefix="JS_")
foreign quickjs {
	NewRuntime :: proc() -> Runtime ---
	FreeRuntime :: proc(rt: Runtime) ---

	NewContext :: proc(rt: Runtime) -> Context ---
	FreeContext :: proc(s: Context) ---

	Eval :: proc(ctx: Context, input: ^u8, input_len: c.size_t, filename: cstring, eval_flags: Eval_Flags) -> Value ---

	GetException :: proc(ctx: Context) -> Value ---

	GetPropertyStr :: proc(ctx: Context, this_obj: Value_Const, prop: cstring) -> Value ---

	ToCStringLen2 :: proc(ctx: Context, plen: ^c.size_t, val1: Value_Const, cesu8: Bool) -> cstring ---
	FreeCString :: proc(ctx: Context, ptr: cstring) ---
}

@(link_prefix="__JS")
@(private)
foreign quickjs {
	_FreeValue :: proc(ctx: Context, v: Value) ---
}

IsNull :: #force_inline proc(v: Value_Const) -> bool {
	return value_get_tag(v) == .Undefined
}
IsUndefined :: #force_inline proc(v: Value_Const) -> bool {
	return value_get_tag(v) == .Undefined
}
IsException :: #force_inline proc(v: Value_Const) -> bool {
	// TODO: some way to emulate js_unlikely?
	return value_get_tag(v) == .Exception
}

@(private)
_rc :: #force_inline proc(ptr: rawptr) -> ^Ref_Count_Header {
	return cast(^Ref_Count_Header) &((cast([^]u32)ptr)[-1])
}
FreeValue :: #force_inline proc(ctx: Context, v: Value) {
	if value_has_ref_count(v) {
		p := _rc(value_get_ptr(v))
		p.ref_count -= 1
		if p.ref_count <= 0 {
			_FreeValue(ctx, v)
		}
	}
}

ToCString :: #force_inline proc(ctx: Context, val1: Value_Const) -> cstring {
	return ToCStringLen2(ctx, nil, val1, 0)
}
