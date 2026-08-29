package thunderbolt

import "base:runtime"

import "core:c"
import "core:container/priority_queue"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:time"

import js "vendor/quickjs"

// Following the following tutorial:
// https://healeycodes.com/building-a-runtime-with-quickjs

Timer :: struct {
	id: int,
	deadline: time.Tick,
	callback: js.Value,
}

Runtime_State :: struct {
	ctx: runtime.Context,
	startup_time: time.Tick,

	next_timer_id: int,
	timers: priority_queue.Priority_Queue(Timer),
}

main :: proc() {
	exit_code: int
	defer os.exit(exit_code)

	rt := js.NewRuntime()
	assert(rt != nil)
	defer js.FreeRuntime(rt)
	ctx := js.NewContext(rt)
	assert(ctx != nil)
	defer js.FreeContext(ctx)

	runtime_state: Runtime_State
	install_runtime(rt, &runtime_state)
	defer cleanup_runtime(&runtime_state)

	install_console(ctx)
	install_process(ctx)
	install_globals(ctx)

	exit_code = run_file(ctx, os.args[1])

	if !run_event_loop(ctx) do exit_code = 1
}

run_file :: proc(ctx: js.Context, file: string) -> (exit_code: int) {
	result: js.Value
	exit_code = 1
	path := strings.clone_to_cstring(file, context.temp_allocator)

	file_data, file_err := os.read_entire_file(file, context.temp_allocator)
	if file_err != nil {
		fmt.eprintln("Error reading source file: ", file_err)
		return 1;
	}

	result = js.Eval(
		ctx,
		raw_data(file_data),
		len(file_data),
		path,
		{ type = .Global },
	)

	if js.IsException(result) {
		dump_exception(ctx)
	} else do exit_code = 0

	js.FreeValue(ctx, result)

	return exit_code
}

dump_exception :: proc(ctx: js.Context) {
	exception := js.GetException(ctx)
	defer js.FreeValue(ctx, exception)
	stack := js.GetPropertyStr(ctx, exception, "stack")
	defer js.FreeValue(ctx, stack)
	message := transmute([^]u8) js.ToCString(ctx, exception)
	defer if message != nil do js.FreeCString(ctx, transmute(cstring) message)
	stack_text: [^]u8
	defer if stack_text != nil do js.FreeCString(ctx, transmute(cstring) stack_text)

	if !js.IsUndefined(stack) && !js.IsNull(stack) {
		stack_text = transmute([^]u8) js.ToCString(ctx, stack)
	}

	if message != nil && message[0] != 0 {
		fmt.eprintln(transmute(cstring) message)
	} else if stack_text == nil || stack_text[0] == 0 {
		fmt.eprintln("JavaScript exception")
	}

	if stack_text != nil && stack_text[0] != 0 {
		if message == nil || message[0] == 0 || string(transmute(cstring) message) != string(transmute(cstring) stack_text) {
			fmt.eprintln(transmute(cstring) stack_text)
		}
	}
}

Odin_Function_Stateful :: #type proc(ctx: js.Context, state: ^Runtime_State, this: js.Value_Const, args: ..js.Value_Const) -> js.Value
Odin_Function_Stateless :: #type proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value
to_js_c_function_stateful :: proc($fn: Odin_Function_Stateful) -> js.C_Function {
	js_c_func :: proc"c"(ctx: js.Context, this_val: js.Value_Const, argc: c.int, argv: [^]js.Value_Const) -> js.Value {
		state := cast(^Runtime_State) js.GetRuntimeOpaque(js.GetRuntime(ctx))

		context = state.ctx

		args := slice.from_ptr(argv, int(argc))

		return fn(ctx, state, this_val, ..args)
	}

	return js_c_func
}
to_js_c_function_stateless :: proc($fn: Odin_Function_Stateless) -> js.C_Function {
	js_c_func :: proc"c"(ctx: js.Context, this_val: js.Value_Const, argc: c.int, argv: [^]js.Value_Const) -> js.Value {
		state := cast(^Runtime_State) js.GetRuntimeOpaque(js.GetRuntime(ctx))

		context = state.ctx

		args := slice.from_ptr(argv, int(argc))

		return fn(ctx, this_val, ..args)
	}

	return js_c_func
}
to_js_c_function :: proc {
	to_js_c_function_stateful,
	to_js_c_function_stateless,
}

js_console_log :: proc(ctx: js.Context, this: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	for arg, i in args {
		if i > 0 do fmt.print(' ')

		string_value := js.ToString(ctx, arg)
		defer js.FreeValue(ctx, string_value)
		text := js.ToCString(ctx, string_value)
		defer js.FreeCString(ctx, text)

		fmt.print(text)
	}

	fmt.println()

	return js.UNDEFINED
}

install_console :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)
	console_obj := js.NewObject(ctx)
	log_fn := js.NewCFunction(ctx, to_js_c_function(js_console_log), "log", 1)

	js.SetPropertyStr(ctx, console_obj, "log", log_fn)
	js.SetPropertyStr(ctx, global_obj, "console", console_obj)
}

install_runtime :: proc(rt: js.Runtime, state: ^Runtime_State) {
	state^ = {
		ctx = context,
		startup_time = time.tick_now(),
	}

	priority_queue.init(&state.timers, proc(a, b: Timer) -> bool {
		return a.deadline._nsec < b.deadline._nsec
	}, priority_queue.default_swap_proc(Timer))

	js.SetRuntimeOpaque(rt, state)
}
cleanup_runtime :: proc(state: ^Runtime_State) {
	priority_queue.destroy(&state.timers)
}

js_process_uptime :: proc(ctx: js.Context, state: ^Runtime_State, this_val: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	now := time.tick_now()

	uptime_nanos := time.tick_diff(state.startup_time, now)

	return js.NewFloat64(ctx, f64(uptime_nanos) / f64(time.Second))
}

install_process :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)
	process_obj := js.NewObject(ctx)
	uptime_fn := js.NewCFunction(ctx, to_js_c_function(js_process_uptime), "uptime", 1)

	js.SetPropertyStr(ctx, process_obj, "uptime", uptime_fn)
	js.SetPropertyStr(ctx, global_obj, "process", process_obj)
}

js_set_timeout :: proc(ctx: js.Context, state: ^Runtime_State, this_val: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	timer: Timer

	// TODO: throw exception, don't assert
	assert(len(args) == 2)
	assert(js.IsFunction(ctx, args[0]) != 0)
	assert(js.IsNumber(args[1]))

	delay: time.Duration
	if js.value_get_tag(args[1]) == .Float64 {
		delay_ms: f64
		assert(js.ToFloat64(ctx, &delay_ms, args[1]) == 0)
		delay = time.Duration(f64(time.Millisecond) * delay_ms)
	} else {
		delay_ms: i64
		assert(js.ToInt64(ctx, &delay_ms, args[1]) == 0)
		delay = time.Duration(i64(time.Millisecond) * delay_ms)
	}

	timer.id = state.next_timer_id
	state.next_timer_id += 1
	timer.deadline = time.tick_add(time.tick_now(), delay)
	timer.callback = js.DupValue(ctx, args[0])

	priority_queue.push(&state.timers, timer)
	return js.NewInt32(ctx, i32(timer.id))
}
js_clear_timeout :: proc(ctx: js.Context, state: ^Runtime_State, this_val: js.Value_Const, args: ..js.Value_Const) -> js.Value {
	// TODO: throw exception, don't assert
	assert(len(args) == 1)
	assert(js.IsNumber(args[0]))

	id: int
	{
		id32: i32
		assert(js.ToInt32(ctx, &id32, args[0]) == 0)
		id = int(id32)
	}
	for timer, ix in state.timers.queue {
		if timer.id == id {
			js.FreeValue(ctx, timer.callback)
			priority_queue.remove(&state.timers, ix)

			break
		}
	}

	return js.UNDEFINED
}

install_globals :: proc(ctx: js.Context) {
	global_obj := js.GetGlobalObject(ctx)
	defer js.FreeValue(ctx, global_obj)
	set_timeout_fn := js.NewCFunction(ctx, to_js_c_function(js_set_timeout), "setTimeout", 1)
	clear_timeout_fn := js.NewCFunction(ctx, to_js_c_function(js_clear_timeout), "clearTimeout", 1)

	js.SetPropertyStr(ctx, global_obj, "setTimeout", set_timeout_fn)
	js.SetPropertyStr(ctx, global_obj, "clearTimeout", clear_timeout_fn)
}

run_expired_timers :: proc(ctx: js.Context) -> (ok: bool) {
	state := cast(^Runtime_State) js.GetRuntimeOpaque(js.GetRuntime(ctx))

	now := time.tick_now()

	for {
		timer := priority_queue.peek_safe(state.timers) or_break
		if time.tick_diff(now, timer.deadline) > 0 do break

		priority_queue.pop(&state.timers)

		result := js.Call(ctx, timer.callback, js.UNDEFINED, 0, nil)
		defer js.FreeValue(ctx, result)

		js.FreeValue(ctx, timer.callback)
		if js.IsException(result) {
			dump_exception(ctx)
			return false
		}

		drain_pending_jobs(js.GetRuntime(ctx)) or_return
		now = time.tick_now()
	}

	return true
}

drain_pending_jobs :: proc(rt: js.Runtime) -> (ok: bool) {
	ctx: js.Context

	for js.IsJobPending(rt) != 0 {
		ret := js.ExecutePendingJob(rt, &ctx)
		if ret < 0 {
			dump_exception(ctx)
			return false
		}
	}

	return true
}

run_event_loop :: proc(ctx: js.Context) -> (ok: bool) {
	rt := js.GetRuntime(ctx)
	state := cast(^Runtime_State) js.GetRuntimeOpaque(rt)

	for priority_queue.len(state.timers) != 0 || runtime_has_async_work(state) || js.IsJobPending(rt) != 0 {
		run_expired_timers(ctx)
		run_completed_file_jobs(ctx)
		drain_pending_jobs(rt)

		if priority_queue.len(state.timers) == 0 && !runtime_has_async_work(state) && js.IsJobPending(rt) == 0 {
			break
		}

		timeout := compute_wait_timeout(state)

		wait_for_events(state, timeout)
	}

	return true
}

runtime_has_async_work :: proc(state: ^Runtime_State) -> bool {
	return false
}

run_completed_file_jobs :: proc(ctx: js.Context) { }

compute_wait_timeout :: proc(state: ^Runtime_State) -> time.Tick {
	timer, ok := priority_queue.peek_safe(state.timers)
	assert(ok)

	return timer.deadline
}

wait_for_events :: proc(state: ^Runtime_State, timeout: time.Tick) {
	time.sleep(time.tick_diff(time.tick_now(), timeout))
}
