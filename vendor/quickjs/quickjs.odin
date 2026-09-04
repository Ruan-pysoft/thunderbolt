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

FLOAT64_NAN := math.nan_f64()

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

value_get_tag :: #force_inline proc"contextless"(v: Value) -> Tag {
	return Tag(v.tag)
}
value_get_norm_tag :: #force_inline proc"contextless"(v: Value) -> Tag {
	return value_get_tag(v)
}
value_get_int :: #force_inline proc"contextless"(v: Value) -> int {
	return int(v.uint64)
}
value_get_bool :: #force_inline proc"contextless"(v: Value) -> bool {
	return bool(v.uint64)
}
value_get_float64 :: #force_inline proc"contextless"(v: Value) -> f64 {
	return v.float64
}
value_get_short_big_int :: #force_inline proc"contextless"(v: Value) -> Short_Big_Int_T {
	return v.short_big_int
}
value_get_ptr :: #force_inline proc"contextless"(v: Value) -> rawptr {
	return v.ptr
}

mkval :: #force_inline proc "contextless" (tag: Tag, val: u32) -> Value {
	return {
		{ uint64 = u64(val) },
		i64(tag),
	}
}
mkptr :: #force_inline proc "contextless" (tag: Tag, p: rawptr) -> Value {
	return {
		{ ptr = p },
		i64(tag),
	}
}

__new_float64 :: #force_inline proc"contextless"(ctx: Context, d: c.double) -> Value {
	v: Value
	v.tag = i64(Tag.Float64)
	v.u.float64 = d
	return v
}
__new_short_big_int :: #force_inline proc"contextless"(ctx: Context, d: i64) -> Value {
	v: Value
	v.tag = i64(Tag.ShortBigInt)
	v.u.short_big_int = Short_Big_Int_T(d)
	return v
}

value_has_ref_count :: #force_inline proc"contextless"(v: Value) -> bool {
	return (transmute(c.uint) value_get_tag(v)) >= (transmute(c.uint) Tag.First)
}

NULL          := mkval(.Null, 0)
UNDEFINED     := mkval(.Undefined, 0)
FALSE         := mkval(.Bool, 0)
TRUE          := mkval(.Bool, 1)
EXCEPTION     := mkval(.Exception, 0)
UNINITIALIZED := mkval(.Uninitialized, 0)

GC_Object_Header :: distinct rawptr

Mark_Func             :: #type proc(rt: Runtime, gp: GC_Object_Header)
Class_Finalizer       :: #type proc"c"(rt: Runtime, val: Value)
Class_GC_Mark         :: #type proc"c"(rt: Runtime, val: Value_Const, mark_func: Mark_Func)
CALL_FLAG_CONSTRUCTOR :: 1<<0
Class_Call            :: #type proc"c"(ctx: Context, func_obj: Value_Const, this: Value_Const, argc: c.int, argv: [^]Value_Const, flags: c.int)
Property_Enum         :: struct {
	is_enumerable: Bool,
	atom: Atom,
}
Property_Descriptor   :: struct {
	flags: c.int,
	value: Value,
	getter: Value,
	Setter: Value,
}
Class_Exotic_Methods  :: struct {
	get_own_property: proc"c"(ctx: Context, desc: ^Property_Descriptor, obj: Value_Const, prop: Atom) -> c.int,
	get_own_property_names: proc"c"(ctx: Context, ptab: ^^Property_Enum, plen: ^c.uint32_t, obj: Value_Const) -> c.int,
	delete_property: proc"c"(ctx: Context, obj: Value_Const, prop: Atom) -> c.int,
	define_own_property: proc"c"(ctx: Context, this: Value_Const, prop: Atom, val: Value_Const, getter: Value_Const, setter: Value_Const, flags: c.int) -> c.int,
	has_property: proc"c"(ctx: Context, obj: Value_Const, atom: Atom) -> c.int,
	get_property: proc"c"(ctx: Context, obj: Value_Const, atom: Atom, receiver: Value_Const) -> Value,
	set_property: proc"c"(ctx: Context, obj: Value_Const, atom: Atom, value: Value_Const, receiver: Value_Const, flags: c.int) -> c.int,
	get_prototype: proc"c"(ctx: Context, obj: Value_Const) -> Value,
	set_prototype: proc"c"(ctx: Context, obj: Value_Const, proto_val: Value_Const) -> c.int,
	is_extensible: proc"c"(ctx: Context, obj: Value_Const) -> c.int,
	prevent_extensions: proc"c"(ctx: Context, obj: Value_Const) -> c.int,
}
Class_Def             :: struct {
	class_name: cstring,
	finalizer: Class_Finalizer,
	gc_mark: Class_GC_Mark,
	call: Class_Call,
	exotic: Class_Exotic_Methods,
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

C_Function :: #type proc"c"(ctx: Context, this_val: Value_Const, argc: c.int, argv: [^]Value_Const) -> Value
C_Function_Magic :: #type proc"c"(ctx: Context, this_val: Value_Const, argc: c.int, argv: [^]Value_Const, magic: c.int) -> Value
C_Function_Data :: #type proc"c"(ctx: Context, this_val: Value_Const, argc: c.int, argv: [^]Value_Const, magic: c.int, func_data: ^Value) -> Value

C_Function_Enum :: enum c.int {
	generic,
	generic_magic,
	constructor,
	constructor_magic,
	constructor_or_func,
	constructor_or_func_magic,
	f_f,
	f_f_f,
	getter,
	setter,
	getter_magic,
	setter_magic,
	iterator_next,
}

C_Function_Type :: struct #raw_union {
	generic: C_Function,
	generic_magic: proc"c"(ctx: Context, this_val: Value_Const, argc: c.int, argv: [^]Value_Const, magic: c.int) -> Value,
	constructor: C_Function,
	constructor_magic: proc"c"(ctx: Context, this_val: Value_Const, argc: c.int, argv: [^]Value_Const, magic: c.int) -> Value,
	constructor_or_func: C_Function,
	f_f: proc"c"(c.double) -> c.double,
	f_f_f: proc"c"(c.double, c.double) -> c.double,
	getter: proc"c"(ctx: Context, this_val: Value_Const) -> Value,
	setter: proc"c"(ctx: Context, this_val: Value_Const, val: Value_Const) -> Value,
	getter_magic: proc"c"(ctx: Context, this_val: Value_Const, magic: c.int) -> Value,
	setter_magic: proc"c"(ctx: Context, this_val: Value_Const, val: Value_Const, magic: c.int) -> Value,
	iterator_next: proc"c"(ctx: Context, this_val: Value_Const, val: Value_Const, magic: c.int) -> Value,
}
PROP_CONFIGURABLE :: 1<<0
PROP_WRITABLE     :: 1<<1
PROP_ENUMERABLE   :: 1<<2
PROP_C_W_E        :: PROP_CONFIGURABLE | PROP_WRITABLE | PROP_ENUMERABLE
PROP_LENGTH       :: 1<<3
PROP_TMASK        :: 3<<4
PROP_NORMAL       :: 0<<4
PROP_GETSET       :: 1<<4
PROP_VARREF       :: 2<<4
PROP_AUTOINIT     :: 3<<4
/*...*/
/*...*/
PROP_THROW        :: 1<<14
PROP_THROW_STRICT :: 1<<15
C_Function_List_Entry :: struct {
	name: cstring,
	prop_flags: c.uint8_t,
	def_type: c.uint8_t,
	magic: c.uint16_t,
	u: struct #raw_union {
		func: struct {
			length: c.uint8_t,
			cproto: c.uint8_t,
			cfunc: C_Function_Type,
		},
		getset: struct {
			get: C_Function_Type,
			set: C_Function_Type,
		},
		alias: struct {
			name: cstring,
			base: c.int,
		},
		prop_list: struct {
			tab: [^]C_Function_List_Entry,
			len: c.int,
		},
		str: cstring,
		i32: c.int32_t,
		i64: c.int64_t,
		f64: c.double,
	},
}

DEF_CFUNC          :: 0
DEF_CGETSET        :: 1
DEF_CGETSET_MAGIC  :: 2
DEF_PROP_STRING    :: 3
DEF_PROP_INT32     :: 4
DEF_PROP_INT64     :: 5
DEF_PROP_DOUBLE    :: 6
DEF_PROP_UNDEFINED :: 7
DEF_OBJECT         :: 8
DEF_ALIAS          :: 9
DEF_PROP_ATOM      :: 10
DEF_PROP_BOOL      :: 11

cfunc_def :: #force_inline proc"contextless"(name: cstring, len: c.int, func1: C_Function) -> C_Function_List_Entry {
	return {
		name,
		PROP_WRITABLE | PROP_CONFIGURABLE,
		DEF_CFUNC,
		0,
		{ func = {
			u8(len),
			u8(C_Function_Enum.generic),
			{ generic = func1 },
		} },
	}
}
cgetset_def :: #force_inline proc"contextless"(name: cstring, fgetter: proc"c"(ctx: Context, this_val: Value_Const) -> Value, fsetter: proc"c"(ctx: Context, this_val: Value_Const, val: Value_Const) -> Value) -> C_Function_List_Entry {
	return {
		name,
		PROP_CONFIGURABLE,
		DEF_CGETSET,
		0,
		{ getset = {
			get = { getter = fgetter },
			set = { setter = fsetter },
		} },
	}
}

INVALID_CLASS_ID :: Class_Id(0)

@(link_prefix="JS_")
foreign quickjs {
	NewRuntime :: proc() -> Runtime ---
	FreeRuntime :: proc(rt: Runtime) ---
	GetRuntimeOpaque :: proc(rt: Runtime) -> rawptr ---
	SetRuntimeOpaque :: proc(rt: Runtime, opaque: rawptr) ---

	NewContext :: proc(rt: Runtime) -> Context ---
	FreeContext :: proc(s: Context) ---
	DupContext :: proc(ctx: Context) -> Context ---
	GetContextOpaque :: proc(ctx: Context) -> rawptr ---
	SetContextOpaque :: proc(ctx: Context, opaque: rawptr) ---
	GetRuntime :: proc(ctx: Context) -> Runtime ---
	SetClassProto :: proc(ctx: Context, class_id: Class_Id, obj: Value) ---
	GetClassProto :: proc(ctx: Context, class_id: Class_Id) -> Value ---

	ValueToAtom :: proc(ctx: Context, val: Value_Const) -> Atom ---

	NewClassID :: proc(pclass_id: ^Class_Id) -> Class_Id ---
	GetClassID :: proc(v: Value) -> Class_Id ---
	NewClass :: proc(rt: Runtime, class_id: Class_Id, #by_ptr class_def: Class_Def) -> c.int ---

	Throw :: proc(ctx: Context, obj: Value) -> Value ---
	GetException :: proc(ctx: Context) -> Value ---
	NewError :: proc(ctx: Context) -> Value ---
	ThrowSyntaxError :: proc(ctx: Context, fmt: cstring, #c_vararg args: ..any) -> Value ---
	ThrowTypeError :: proc(ctx: Context, fmt: cstring, #c_vararg args: ..any) -> Value ---
	ThrowReferenceError :: proc(ctx: Context, fmt: cstring, #c_vararg args: ..any) -> Value ---
	ThrowRangeError :: proc(ctx: Context, fmt: cstring, #c_vararg args: ..any) -> Value ---
	ThrowInternalError :: proc(ctx: Context, fmt: cstring, #c_vararg args: ..any) -> Value ---
	ThrowOutOfMemory :: proc(ctx: Context) -> Value ---

	@(private)
	GetPropertyInternal :: proc(ctx: Context, obj: Value_Const, prop: Atom, receiver: Value_Const, throw_ref_error: Bool) -> Value ---
	GetPropertyStr :: proc(ctx: Context, this_obj: Value_Const, prop: cstring) -> Value ---
	@(private)
	SetPropertyInternal :: proc(ctx: Context, obj: Value_Const, prop: Atom, val: Value, this_obj: Value_Const, flags: c.int) -> c.int ---
	SetPropertyStr :: proc(ctx: Context, this_obj: Value_Const, prop: cstring, val: Value) -> c.int ---

	NewStringLen :: proc(ctx: Context, str1: cstring, len1: c.size_t) -> Value ---
	ToString :: proc(ctx: Context, val: Value_Const) -> Value ---
	ToCStringLen2 :: proc(ctx: Context, plen: ^c.size_t, val1: Value_Const, cesu8: Bool) -> cstring ---
	FreeCString :: proc(ctx: Context, ptr: cstring) ---

	NewObject :: proc(ctx: Context) -> Value ---
	NewObjectClass :: proc(ctx: Context, class_id: c.int) -> Value ---
	NewBigInt64 :: proc(ctx: Context, v: c.int64_t) -> Value ---
	NewBigUint64 :: proc(ctx: Context, v: c.uint64_t) -> Value ---

	IsFunction :: proc(ctx: Context, val: Value_Const) -> Bool ---

	Call :: proc(ctx: Context, func_obj: Value_Const, this_obj: Value_Const, argc: c.int, argv: [^]Value_Const) -> Value ---
	Eval :: proc(ctx: Context, input: ^u8, input_len: c.size_t, filename: cstring, eval_flags: Eval_Flags) -> Value ---
	GetGlobalObject :: proc(ctx: Context) -> Value ---

	ToBool :: proc(ctx: Context, val: Value_Const) -> c.int --- // return -1 for EXCEPTION
	ToInt32 :: proc(ctx: Context, pres: ^i32, val: Value_Const) -> c.int ---
	ToInt64 :: proc(ctx: Context, plen: ^i64, val: Value_Const) -> c.int ---
	ToIndex :: proc(ctx: Context, plen: ^u64, val: Value_Const) -> c.int ---
	ToFloat64 :: proc(ctx: Context, pres: ^f64, val: Value_Const) -> c.int ---
	ToBigInt64 :: proc(ctx: Context, pres: ^i64, val: Value_Const) -> c.int ---
	ToInt64Ext :: proc(ctx: Context, pres: ^i64, val: Value_Const) -> c.int ---

	IsJobPending :: proc(rt: Runtime) -> Bool ---
	ExecutePendingJob :: proc(rt: Runtime, ctx: ^Context) -> c.int ---

	NewCFunction2 :: proc(ctx: Context, func: C_Function, name: cstring, length: c.int, cproto: C_Function_Enum, magic: c.int) -> Value ---
	NewCFunctionData :: proc(ctx: Context, func: C_Function_Data, length: c.int, magic: c.int, data_len: c.int, data: ^Value_Const) -> Value ---
	SetConstructor :: proc(ctx: Context, func_obj: Value_Const, proto: Value_Const) -> c.int ---

	SetPropertyFunctionList :: proc(ctx: Context, obj: Value_Const, tab: [^]C_Function_List_Entry, len: c.int) -> c.int ---
}

@(link_prefix="__JS")
@(private)
foreign quickjs {
	_FreeValue :: proc(ctx: Context, v: Value) ---
}

NewBool :: #force_inline proc"contextless"(ctx: Context, val: Bool) -> Value {
	return mkval(.Bool, u32(val != 0))
}
NewInt32 :: #force_inline proc"contextless"(ctx: Context, val: i32) -> Value {
	return mkval(.Int, transmute(u32) val)
}
NewInt64 :: #force_inline proc"contextless"(ctx: Context, val: i64) -> Value {
	v: Value
	if val == i64(i32(val)) {
		v = NewInt32(ctx, i32(val))
	} else {
		v = __new_float64(ctx, f64(val))
	}
	return v
}
NewFloat64 :: #force_inline proc"contextless"(ctx: Context, d: f64) -> Value {
	val: i32
	u, t: struct #raw_union {
		d: f64,
		u: u64,
	}

	if d >= f64(c.INT32_MIN) && d <= f64(c.INT32_MAX) {
		u.d = d
		val = i32(d)
		t.d = f64(val)
		if u.u == t.u do return mkval(.Int, transmute(u32) val)
	}
	return __new_float64(ctx, d)
}

IsNumber :: #force_inline proc"contextless"(v: Value_Const) -> bool {
	tag := value_get_tag(v)
	return tag == .Int || tag == .Float64
}
IsBigInt :: #force_inline proc"contextless"(ctx: Context, v: Value_Const) -> bool {
	tag := value_get_tag(v)
	return tag == .BigInt || tag == .ShortBigInt
}
IsNull :: #force_inline proc"contextless"(v: Value_Const) -> bool {
	return value_get_tag(v) == .Undefined
}
IsUndefined :: #force_inline proc"contextless"(v: Value_Const) -> bool {
	return value_get_tag(v) == .Undefined
}
IsException :: #force_inline proc"contextless"(v: Value_Const) -> bool {
	// TODO: some way to emulate js_unlikely?
	return value_get_tag(v) == .Exception
}
IsUninitialized :: #force_inline proc"contextless"(v: Value_Const) -> bool {
	// TODO: some way to emulate js_unlikely?
	return value_get_tag(v) == .Uninitialized
}
IsString :: #force_inline proc"contextless"(v: Value_Const) -> bool {
	return value_get_tag(v) == .String || value_get_tag(v) == .StringRope
}
IsObject :: #force_inline proc"contextless"(v: Value_Const) -> bool {
	return value_get_tag(v) == .Object
}

@(private)
_rc :: #force_inline proc"contextless"(ptr: rawptr) -> ^Ref_Count_Header {
	return cast(^Ref_Count_Header) &((cast([^]u32)ptr)[-1])
}
FreeValue :: #force_inline proc"contextless"(ctx: Context, v: Value) {
	if value_has_ref_count(v) {
		p := _rc(value_get_ptr(v))
		p.ref_count -= 1
		if p.ref_count <= 0 {
			_FreeValue(ctx, v)
		}
	}
}

DupValue :: #force_inline proc"contextless"(ctx: Context, v: Value) -> Value {
	if value_has_ref_count(v) {
		p := _rc(value_get_ptr(v))
		p.ref_count += 1
	}
	return v
}

ToUint32 :: #force_inline proc"contextless"(ctx: Context, pres: ^u32, val: Value_Const) -> c.int {
	return ToInt32(ctx, cast(^i32)pres, val)
}

GetProperty :: #force_inline proc"contextless"(ctx: Context, this_obj: Value_Const, prop: Atom) -> Value {
	return GetPropertyInternal(ctx, this_obj, prop, this_obj, 0)
}
SetProperty :: #force_inline proc"contextless"(ctx: Context, this_obj: Value_Const, prop: Atom, val: Value) -> c.int {
	return SetPropertyInternal(ctx, this_obj, prop, val, this_obj, PROP_THROW)
}

NewString :: #force_inline proc"contextless"(ctx: Context, str: cstring) -> Value {
	return NewStringLen(ctx, str, len(str))
}
ToCString :: #force_inline proc"contextless"(ctx: Context, val1: Value_Const) -> cstring {
	return ToCStringLen2(ctx, nil, val1, 0)
}

NewCFunction :: proc"contextless"(ctx: Context, func: C_Function, name: cstring, length: c.int) -> Value {
	return NewCFunction2(ctx, func, name, length, .generic, 0)
}
