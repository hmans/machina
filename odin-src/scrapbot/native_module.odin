package main

import odin_runtime "base:runtime"
import "core:dynlib"
import "core:strings"

Native_ABI_Field_Type :: enum {
	Boolean,
	Bool,
	Int,
	Float,
	String,
	Vec3,
}

Native_ABI_System_Phase :: enum {
	Startup,
	Update,
	Fixed_Update,
	Render,
}

Native_ABI_Entity :: struct {
	index:      u32,
	generation: u32,
}

Native_ABI_Component_Field :: struct {
	name:       string,
	field_type: Native_ABI_Field_Type,
}

Native_ABI_Component_Registration :: struct {
	id:      string,
	version: int,
	fields:  []Native_ABI_Component_Field,
}

Native_ABI_System_Context :: struct {
	host_context:  rawptr,
	api:           ^Native_ABI_System_Api,
	delta_seconds: f32,
	system_id:     string,
}

Native_ABI_System_Run_Proc :: proc "c" (ctx: ^Native_ABI_System_Context) -> bool

Native_ABI_System_Registration :: struct {
	id:     string,
	phase:  Native_ABI_System_Phase,
	reads:  []string,
	writes: []string,
	before: []string,
	after:  []string,
	run:    Native_ABI_System_Run_Proc,
}

Native_ABI_Register_Component_Proc :: proc "c" (ctx: rawptr, registration: ^Native_ABI_Component_Registration) -> bool
Native_ABI_Register_System_Proc :: proc "c" (ctx: rawptr, registration: ^Native_ABI_System_Registration) -> bool

Native_ABI_Register_Api :: struct {
	user_context:       rawptr,
	register_component: Native_ABI_Register_Component_Proc,
	register_system:    Native_ABI_Register_System_Proc,
}

Native_ABI_Register_Proc :: proc "c" (api: ^Native_ABI_Register_Api) -> bool

Native_ABI_Query_Next_Proc :: proc "c" (ctx: rawptr, component_ids: []string, cursor: ^int, out_entity: ^Native_ABI_Entity) -> bool
Native_ABI_Get_Int_Proc :: proc "c" (ctx: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, out_value: ^int) -> bool
Native_ABI_Set_Int_Proc :: proc "c" (ctx: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, value: int) -> bool
Native_ABI_Get_Float_Proc :: proc "c" (ctx: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, out_value: ^f32) -> bool
Native_ABI_Set_Float_Proc :: proc "c" (ctx: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, value: f32) -> bool
Native_ABI_Get_Bool_Proc :: proc "c" (ctx: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, out_value: ^bool) -> bool
Native_ABI_Set_Bool_Proc :: proc "c" (ctx: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, value: bool) -> bool

Native_ABI_System_Api :: struct {
	query_next: Native_ABI_Query_Next_Proc,
	get_int:    Native_ABI_Get_Int_Proc,
	set_int:    Native_ABI_Set_Int_Proc,
	get_float:  Native_ABI_Get_Float_Proc,
	set_float:  Native_ABI_Set_Float_Proc,
	get_bool:   Native_ABI_Get_Bool_Proc,
	set_bool:   Native_ABI_Set_Bool_Proc,
}

Native_Loaded_Module :: struct {
	path:   string,
	handle: dynlib.Library,
}

Native_Loaded_System :: struct {
	system_id:  string,
	runner_ref: u32,
	run:        Native_ABI_System_Run_Proc,
	path:       string,
	line:       int,
}

Native_Module_Load_Context :: struct {
	registry:        ^Runtime_Component_Registry,
	program:         ^Script_Program,
	path:            string,
	next_runner_ref: u32,
	odin_context:    odin_runtime.Context,
	error_message:   string,
}

Native_Runtime_Context :: struct {
	program:  ^Script_Program,
	registry: ^Runtime_Component_Registry,
	world:    ^Runtime_World,
	system:   Runtime_Scheduled_System,
}

script_program_load_native_artifact :: proc(
	program: ^Script_Program,
	registry: ^Runtime_Component_Registry,
	file_system_path, diagnostic_path: string,
) -> Project_Error {
	library, library_ok := dynlib.load_library(file_system_path)
	if !library_ok {
		return .Invalid_Native_Artifact
	}
	keep_library := false
	defer {
		if !keep_library {
			dynlib.unload_library(library)
		}
	}

	symbol, symbol_ok := dynlib.symbol_address(library, "scrapbot_register")
	if !symbol_ok || symbol == nil {
		return .Invalid_Native_Artifact
	}
	register := cast(Native_ABI_Register_Proc)symbol

	load_context := Native_Module_Load_Context{
		registry = registry,
		program = program,
		path = diagnostic_path,
		next_runner_ref = native_next_runner_ref(program^),
		odin_context = program.odin_context,
	}
	api := Native_ABI_Register_Api{
		user_context = rawptr(&load_context),
		register_component = native_register_component_callback,
		register_system = native_register_system_callback,
	}
	if !register(&api) {
		if load_context.error_message != "" {
			delete(load_context.error_message)
		}
		return .Invalid_Native_Artifact
	}
	if load_context.error_message != "" {
		delete(load_context.error_message)
		return .Invalid_Native_Artifact
	}

	owned_path, path_err := strings.clone(diagnostic_path)
	if path_err != nil {
		return .Invalid_Native_Artifact
	}
	append(&program.native_modules, Native_Loaded_Module{
		path = owned_path,
		handle = library,
	})
	keep_library = true
	return .None
}

native_run_loaded_system :: proc(
	program: ^Script_Program,
	registry: ^Runtime_Component_Registry,
	world: ^Runtime_World,
	system: Runtime_Scheduled_System,
	loaded_system: Native_Loaded_System,
	delta_seconds: f32,
) -> Script_Run_Result {
	context_storage := Native_Runtime_Context{
		program = program,
		registry = registry,
		world = world,
		system = system,
	}
	system_context := Native_ABI_System_Context{
		host_context = rawptr(&context_storage),
		api = &NATIVE_SYSTEM_API,
		delta_seconds = delta_seconds,
		system_id = system.id,
	}

	script_program_clear_host_error(program)
	program.active_registry = registry
	program.active_system = system
	program.has_active_system = true
	ok := loaded_system.run(&system_context)
	program.has_active_system = false
	program.active_registry = nil
	if !ok {
		runtime_deferred_discard(&program.deferred, world)
		message := "native Odin system failed"
		if program.has_host_error {
			message = string(program.host_error_storage[:program.host_error_len])
		}
		diagnostic := script_runtime_diagnostic(loaded_system.path, system.id, loaded_system.line, message)
		script_program_clear_host_error(program)
		return Script_Run_Result{ok = false, diagnostic = diagnostic}
	}
	flush_err := runtime_deferred_flush(&program.deferred, world, registry^)
	if flush_err != .None {
		message := runtime_error_label(flush_err)
		diagnostic := script_runtime_diagnostic(loaded_system.path, system.id, loaded_system.line, message)
		script_program_clear_host_error(program)
		return Script_Run_Result{ok = false, diagnostic = diagnostic}
	}
	script_program_clear_host_error(program)
	return Script_Run_Result{ok = true}
}

native_find_loaded_system :: proc(program: Script_Program, system: Runtime_Scheduled_System) -> (Native_Loaded_System, bool) {
	for loaded in program.native_loaded_systems {
		if (system.runner.ref != 0 && loaded.runner_ref == system.runner.ref) || loaded.system_id == system.id {
			return loaded, true
		}
	}
	return {}, false
}

native_loaded_modules_free :: proc(modules: []Native_Loaded_Module) {
	for module in modules {
		if module.handle != nil {
			dynlib.unload_library(module.handle)
		}
		if module.path != "" {
			delete(module.path)
		}
	}
}

native_loaded_systems_free :: proc(systems: []Native_Loaded_System) {
	for system in systems {
		if system.system_id != "" {
			delete(system.system_id)
		}
		if system.path != "" {
			delete(system.path)
		}
	}
}

native_next_runner_ref :: proc(program: Script_Program) -> u32 {
	ref := u32(len(program.native_loaded_systems) + len(program.native_operations) + 1)
	if ref == 0 {
		return 1
	}
	return ref
}

native_register_component_callback :: proc "c" (raw_context: rawptr, registration: ^Native_ABI_Component_Registration) -> bool {
	load_context := cast(^Native_Module_Load_Context)raw_context
	if load_context == nil || registration == nil {
		return false
	}
	context = load_context.odin_context

	fields := make([]Runtime_Component_Field_Definition, len(registration.fields))
	if fields == nil && len(registration.fields) > 0 {
		native_load_set_error(load_context, "failed to allocate native component fields")
		return false
	}
	defer if fields != nil do delete(fields)
	for field, index in registration.fields {
		value_type, type_ok := native_abi_field_type_to_runtime(field.field_type)
		if !type_ok {
			native_load_set_error(load_context, "native component field has unsupported type")
			return false
		}
		fields[index] = Runtime_Component_Field_Definition{name = field.name, value_type = value_type}
	}

	version := registration.version
	if version == 0 {
		version = 1
	}
	err := runtime_register_project_component(load_context.registry, Runtime_Component_Definition{
		id = registration.id,
		version = version,
		fields = fields,
	})
	if err != .None {
		native_load_set_error(load_context, runtime_error_label(err))
		return false
	}
	return true
}

native_register_system_callback :: proc "c" (raw_context: rawptr, registration: ^Native_ABI_System_Registration) -> bool {
	load_context := cast(^Native_Module_Load_Context)raw_context
	if load_context == nil || registration == nil {
		return false
	}
	context = load_context.odin_context
	if registration.run == nil {
		native_load_set_error(load_context, "native system registration is missing a run callback")
		return false
	}
	phase, phase_ok := native_abi_phase_to_runtime(registration.phase)
	if !phase_ok {
		native_load_set_error(load_context, "native system phase is not supported")
		return false
	}

	runner_ref := load_context.next_runner_ref
	if runner_ref == 0 {
		runner_ref = 1
	}
	err := runtime_register_project_system(load_context.registry, Runtime_System_Definition{
		id = registration.id,
		phase = phase,
		reads = registration.reads,
		writes = registration.writes,
		before = registration.before,
		after = registration.after,
		runner = Runtime_System_Runner{kind = .Native, ref = runner_ref},
	})
	if err != .None {
		native_load_set_error(load_context, runtime_error_label(err))
		return false
	}

	owned_id, id_err := strings.clone(registration.id)
	if id_err != nil {
		native_load_set_error(load_context, "failed to store native system id")
		return false
	}
	owned_path, path_err := strings.clone(load_context.path)
	if path_err != nil {
		delete(owned_id)
		native_load_set_error(load_context, "failed to store native system path")
		return false
	}
	append(&load_context.program.native_loaded_systems, Native_Loaded_System{
		system_id = owned_id,
		runner_ref = runner_ref,
		run = registration.run,
		path = owned_path,
		line = 0,
	})
	load_context.next_runner_ref = runner_ref + 1
	return true
}

native_load_set_error :: proc(load_context: ^Native_Module_Load_Context, message: string) {
	if load_context.error_message != "" {
		delete(load_context.error_message)
	}
	owned, err := strings.clone(message)
	if err != nil {
		load_context.error_message = ""
		return
	}
	load_context.error_message = owned
}

native_abi_field_type_to_runtime :: proc(value: Native_ABI_Field_Type) -> (Runtime_Field_Type, bool) {
	switch value {
	case .Boolean, .Bool:
		return .Boolean, true
	case .Int:
		return .Int, true
	case .Float:
		return .Float, true
	case .String:
		return .String, true
	case .Vec3:
		return .Vec3, true
	}
	return .Boolean, false
}

native_abi_phase_to_runtime :: proc(value: Native_ABI_System_Phase) -> (Runtime_System_Phase, bool) {
	switch value {
	case .Startup:
		return .Startup, true
	case .Update:
		return .Update, true
	case .Fixed_Update:
		return .Fixed_Update, true
	case .Render:
		return .Render, true
	}
	return .Update, false
}

native_abi_entity_to_runtime :: proc(entity: Native_ABI_Entity) -> Entity_Handle {
	return Entity_Handle{index = entity.index, generation = entity.generation}
}

native_runtime_entity_to_abi :: proc(entity: Entity_Handle) -> Native_ABI_Entity {
	return Native_ABI_Entity{index = entity.index, generation = entity.generation}
}

NATIVE_SYSTEM_API: Native_ABI_System_Api = Native_ABI_System_Api{
	query_next = native_host_query_next,
	get_int = native_host_get_int,
	set_int = native_host_set_int,
	get_float = native_host_get_float,
	set_float = native_host_set_float,
	get_bool = native_host_get_bool,
	set_bool = native_host_set_bool,
}

native_host_context :: proc(raw_context: rawptr) -> ^Native_Runtime_Context {
	return cast(^Native_Runtime_Context)raw_context
}

native_host_query_next :: proc "c" (raw_context: rawptr, component_ids: []string, cursor: ^int, out_entity: ^Native_ABI_Entity) -> bool {
	host := cast(^Native_Runtime_Context)raw_context
	if host == nil || cursor == nil || out_entity == nil {
		return false
	}
	context = host.program.odin_context
	for component_id in component_ids {
		if !script_program_active_system_allows_read(host.program, component_id) {
			script_program_set_host_errorf(host.program, "native system tried to query undeclared component '%s'", component_id)
			return false
		}
	}
	entity, found := runtime_world_query_next(host.world^, component_ids, cursor)
	if !found {
		return false
	}
	out_entity^ = native_runtime_entity_to_abi(entity)
	return true
}

native_host_get_int :: proc "c" (raw_context: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, out_value: ^int) -> bool {
	if out_value == nil {
		return false
	}
	host := cast(^Native_Runtime_Context)raw_context
	if host == nil {
		return false
	}
	context = host.program.odin_context
	value, ok := native_host_get_field(raw_context, entity, component_id, field_name, .Int)
	if !ok {
		return false
	}
	out_value^ = value.int_value
	return true
}

native_host_set_int :: proc "c" (raw_context: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, value: int) -> bool {
	host := cast(^Native_Runtime_Context)raw_context
	if host == nil {
		return false
	}
	context = host.program.odin_context
	return native_host_set_field(raw_context, entity, component_id, field_name, runtime_component_value_int(value))
}

native_host_get_float :: proc "c" (raw_context: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, out_value: ^f32) -> bool {
	if out_value == nil {
		return false
	}
	host := cast(^Native_Runtime_Context)raw_context
	if host == nil {
		return false
	}
	context = host.program.odin_context
	value, ok := native_host_get_field(raw_context, entity, component_id, field_name, .Float)
	if !ok {
		return false
	}
	out_value^ = value.float
	return true
}

native_host_set_float :: proc "c" (raw_context: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, value: f32) -> bool {
	host := cast(^Native_Runtime_Context)raw_context
	if host == nil {
		return false
	}
	context = host.program.odin_context
	return native_host_set_field(raw_context, entity, component_id, field_name, runtime_component_value_float(value))
}

native_host_get_bool :: proc "c" (raw_context: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, out_value: ^bool) -> bool {
	if out_value == nil {
		return false
	}
	host := cast(^Native_Runtime_Context)raw_context
	if host == nil {
		return false
	}
	context = host.program.odin_context
	value, ok := native_host_get_field(raw_context, entity, component_id, field_name, .Boolean)
	if !ok {
		return false
	}
	out_value^ = value.boolean
	return true
}

native_host_set_bool :: proc "c" (raw_context: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, value: bool) -> bool {
	host := cast(^Native_Runtime_Context)raw_context
	if host == nil {
		return false
	}
	context = host.program.odin_context
	return native_host_set_field(raw_context, entity, component_id, field_name, runtime_component_value_boolean(value))
}

native_host_get_field :: proc(raw_context: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, expected_type: Runtime_Field_Type) -> (Runtime_Component_Value, bool) {
	host := native_host_context(raw_context)
	if host == nil {
		return Runtime_Component_Value{}, false
	}
	context = host.program.odin_context
	if !script_program_active_system_allows_read(host.program, component_id) {
		script_program_set_host_errorf(host.program, "native system tried to read undeclared component '%s'", component_id)
		return Runtime_Component_Value{}, false
	}
	value, err := runtime_world_get_component_field_value(host.world^, native_abi_entity_to_runtime(entity), component_id, field_name)
	if err != .None {
		script_program_set_host_error(host.program, runtime_error_label(err))
		return Runtime_Component_Value{}, false
	}
	if value.value_type != expected_type {
		script_program_set_host_error(host.program, "native system field type mismatch")
		return Runtime_Component_Value{}, false
	}
	return value, true
}

native_host_set_field :: proc(raw_context: rawptr, entity: Native_ABI_Entity, component_id, field_name: string, value: Runtime_Component_Value) -> bool {
	host := native_host_context(raw_context)
	if host == nil {
		return false
	}
	context = host.program.odin_context
	if !script_program_active_system_allows_write(host.program, component_id) {
		script_program_set_host_errorf(host.program, "native system tried to write undeclared component '%s'", component_id)
		return false
	}
	err := runtime_world_set_component_field_value(host.world, native_abi_entity_to_runtime(entity), component_id, field_name, value)
	if err != .None {
		script_program_set_host_error(host.program, runtime_error_label(err))
		return false
	}
	return true
}
