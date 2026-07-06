package main

import odin_runtime "base:runtime"
import "core:c"
import "core:os"
import "core:strings"

LUAU_BRIDGE_LIB :: "../../odin-out/luau-bridge/libscrapbot_luau_bridge.a"

when !#exists(LUAU_BRIDGE_LIB) {
	#panic("missing Odin Luau bridge library; run `mise build-odin-luau-bridge`")
}

when ODIN_OS == .Darwin {
	foreign import luau_bridge {
		LUAU_BRIDGE_LIB,
		"system:c++",
	}
} else when ODIN_OS == .Linux {
	foreign import luau_bridge {
		LUAU_BRIDGE_LIB,
		"system:stdc++",
	}
} else {
	foreign import luau_bridge {
		LUAU_BRIDGE_LIB,
		"system:c++",
	}
}

Luau_Bridge_Query_Next_Proc :: #type proc "c" (
	ctx: rawptr,
	world: rawptr,
	component_ids: [^]cstring,
	component_count: c.size_t,
	cursor: ^u32,
	out_entity: ^u32,
	out_entity_generation: ^u32,
) -> c.int

Luau_Bridge_Field_Tag :: enum c.int {
	Boolean = 1,
	Int = 2,
	Float = 3,
	Vec3 = 4,
	String = 5,
	Number = 6,
}

Luau_Bridge_Field_Value :: struct {
	tag:           Luau_Bridge_Field_Tag,
	boolean_value: c.int,
	int_value:     i32,
	number_value:  f64,
	string_data:   cstring,
	string_len:    c.size_t,
	vec3_value:    [3]f32,
}

Luau_Bridge_Get_Field_Proc :: #type proc "c" (
	ctx: rawptr,
	world: rawptr,
	entity: u32,
	entity_generation: u32,
	component_id: cstring,
	field_name: cstring,
	out_value: ^Luau_Bridge_Field_Value,
) -> c.int

Luau_Bridge_Set_Field_Proc :: #type proc "c" (
	ctx: rawptr,
	world: rawptr,
	entity: u32,
	entity_generation: u32,
	component_id: cstring,
	field_name: cstring,
	value: ^Luau_Bridge_Field_Value,
) -> c.int

Luau_Bridge_Host_Error_Proc :: #type proc "c" (ctx: rawptr) -> cstring

Luau_Bridge_Callbacks :: struct {
	query_next:                 Luau_Bridge_Query_Next_Proc,
	prepare_query:              rawptr,
	query_next_prepared:        rawptr,
	query_plan_generation:      rawptr,
	read_f32_view:              rawptr,
	write_f32_view:             rawptr,
	read_vec3_view:             rawptr,
	write_vec3_view:            rawptr,
	get_vec3:                   rawptr,
	set_vec3:                   rawptr,
	get_field:                  Luau_Bridge_Get_Field_Proc,
	get_field_resolved:         rawptr,
	set_field:                  Luau_Bridge_Set_Field_Proc,
	set_field_resolved:         rawptr,
	spawn_entity:               rawptr,
	despawn_entity:             rawptr,
	add_component:              rawptr,
	remove_component:           rawptr,
	host_error:                 Luau_Bridge_Host_Error_Proc,
}

@(default_calling_convention = "c")
foreign luau_bridge {
	scrapbot_luau_create :: proc(callbacks: Luau_Bridge_Callbacks) -> rawptr ---
	scrapbot_luau_destroy :: proc(vm: rawptr) ---
	scrapbot_luau_set_callback_context :: proc(vm: rawptr, ctx: rawptr) ---
	scrapbot_luau_load :: proc(vm: rawptr, chunk_name: cstring, source: cstring, source_len: c.size_t) -> c.int ---
	scrapbot_luau_last_error :: proc(vm: rawptr) -> cstring ---

	scrapbot_luau_component_count :: proc(vm: rawptr) -> c.size_t ---
	scrapbot_luau_component_id :: proc(vm: rawptr, component_index: c.size_t) -> cstring ---
	scrapbot_luau_component_version :: proc(vm: rawptr, component_index: c.size_t) -> u32 ---
	scrapbot_luau_component_line :: proc(vm: rawptr, component_index: c.size_t) -> c.int ---
	scrapbot_luau_component_field_count :: proc(vm: rawptr, component_index: c.size_t) -> c.size_t ---
	scrapbot_luau_component_field_name :: proc(vm: rawptr, component_index, field_index: c.size_t) -> cstring ---
	scrapbot_luau_component_field_type :: proc(vm: rawptr, component_index, field_index: c.size_t) -> cstring ---

	scrapbot_luau_system_count :: proc(vm: rawptr) -> c.size_t ---
	scrapbot_luau_system_id :: proc(vm: rawptr, system_index: c.size_t) -> cstring ---
	scrapbot_luau_system_phase :: proc(vm: rawptr, system_index: c.size_t) -> cstring ---
	scrapbot_luau_system_runner_ref :: proc(vm: rawptr, system_index: c.size_t) -> u32 ---
	scrapbot_luau_system_line :: proc(vm: rawptr, system_index: c.size_t) -> c.int ---
	scrapbot_luau_system_reads_count :: proc(vm: rawptr, system_index: c.size_t) -> c.size_t ---
	scrapbot_luau_system_reads_item :: proc(vm: rawptr, system_index, item_index: c.size_t) -> cstring ---
	scrapbot_luau_system_writes_count :: proc(vm: rawptr, system_index: c.size_t) -> c.size_t ---
	scrapbot_luau_system_writes_item :: proc(vm: rawptr, system_index, item_index: c.size_t) -> cstring ---
	scrapbot_luau_system_before_count :: proc(vm: rawptr, system_index: c.size_t) -> c.size_t ---
	scrapbot_luau_system_before_item :: proc(vm: rawptr, system_index, item_index: c.size_t) -> cstring ---
	scrapbot_luau_system_after_count :: proc(vm: rawptr, system_index: c.size_t) -> c.size_t ---
	scrapbot_luau_system_after_item :: proc(vm: rawptr, system_index, item_index: c.size_t) -> cstring ---

	scrapbot_luau_call_system :: proc(vm: rawptr, runner_ref: u32, world: rawptr, delta_seconds: f64) -> c.int ---
}

Luau_Bridge_Register_Result :: struct {
	err:        Project_Error,
	diagnostic: Script_Diagnostic,
}

Script_System_Origin :: struct {
	id:         string,
	path:       string,
	line:       int,
	runner_ref: u32,
}

Script_Program :: struct {
	vm:                 rawptr,
	system_origins:     [dynamic]Script_System_Origin,
	active_registry:    ^Runtime_Component_Registry,
	active_system:      Runtime_Scheduled_System,
	has_active_system:  bool,
	host_error_storage: [512]byte,
	host_error_len:     int,
	has_host_error:     bool,
	odin_context:       odin_runtime.Context,
}

Script_Run_Result :: struct {
	ok:         bool,
	diagnostic: Script_Diagnostic,
}

script_program_init :: proc() -> (Script_Program, Script_Diagnostic, bool) {
	program := Script_Program{odin_context = context}
	vm := scrapbot_luau_create(luau_bridge_callbacks())
	if vm == nil {
		return program, script_load_diagnostic("", "failed to create Luau VM"), false
	}
	program.vm = vm
	return program, Script_Diagnostic{}, true
}

script_program_free :: proc(program: ^Script_Program) {
	if program.vm != nil {
		scrapbot_luau_destroy(program.vm)
	}
	for origin in program.system_origins {
		if origin.id != "" {
			delete(origin.id)
		}
		if origin.path != "" {
			delete(origin.path)
		}
	}
	if program.system_origins != nil {
		delete(program.system_origins)
	}
	script_program_clear_host_error(program)
	program^ = Script_Program{}
}

script_program_load_file :: proc(
	program: ^Script_Program,
	registry: ^Runtime_Component_Registry,
	file_system_path: string,
	diagnostic_path: string,
) -> Luau_Bridge_Register_Result {
	contents, read_err := os.read_entire_file(file_system_path, context.allocator)
	if read_err != nil {
		return Luau_Bridge_Register_Result{err = .Missing_Script}
	}
	defer delete(contents)

	chunk_name_storage := make([]byte, len(diagnostic_path) + 1)
	if chunk_name_storage == nil {
		return Luau_Bridge_Register_Result{
			err = .Invalid_Script,
			diagnostic = script_load_diagnostic(diagnostic_path, "failed to allocate Luau chunk name"),
		}
	}
	defer delete(chunk_name_storage)
	copy(chunk_name_storage, diagnostic_path)
	chunk_name := cstring(raw_data(chunk_name_storage))

	source := cstring(raw_data(contents))
	component_start := int(scrapbot_luau_component_count(program.vm))
	system_start := int(scrapbot_luau_system_count(program.vm))
	if scrapbot_luau_load(program.vm, chunk_name, source, c.size_t(len(contents))) == 0 {
		message := clone_luau_cstring(scrapbot_luau_last_error(program.vm))
		if message != "" {
			diagnostic := script_load_diagnostic(diagnostic_path, message)
			delete(message)
			return Luau_Bridge_Register_Result{
				err = .Invalid_Script,
				diagnostic = diagnostic,
			}
		}
		return Luau_Bridge_Register_Result{
			err = .Invalid_Script,
			diagnostic = script_load_diagnostic(diagnostic_path, "failed to load Luau script"),
		}
	}

	component_err, component_diagnostic := register_luau_bridge_components(registry, program.vm, diagnostic_path, component_start)
	if component_err != .None {
		return Luau_Bridge_Register_Result{err = component_err, diagnostic = component_diagnostic}
	}
	system_err, system_diagnostic := register_luau_bridge_systems(program, registry, program.vm, diagnostic_path, system_start)
	if system_err != .None {
		return Luau_Bridge_Register_Result{err = system_err, diagnostic = system_diagnostic}
	}
	return Luau_Bridge_Register_Result{}
}

register_luau_bridge_components :: proc(
	registry: ^Runtime_Component_Registry,
	vm: rawptr,
	diagnostic_path: string,
	component_start: int,
) -> (Project_Error, Script_Diagnostic) {
	component_count := int(scrapbot_luau_component_count(vm))
	for component_index := component_start; component_index < component_count; component_index += 1 {
		id := clone_luau_cstring(scrapbot_luau_component_id(vm, c.size_t(component_index)))
		if id == "" {
			return .Invalid_Script, script_registration_diagnostic_line(diagnostic_path, 0, "script component declaration is missing an id")
		}
		defer delete(id)

		if runtime_is_engine_type_id(id) {
			continue
		}

		fields, fields_ok := luau_bridge_component_fields(vm, component_index)
		if !fields_ok {
			return .Invalid_Script, script_registration_diagnostic_line(diagnostic_path, int(scrapbot_luau_component_line(vm, c.size_t(component_index))), "script component fields are invalid")
		}
		defer luau_bridge_field_definitions_free(fields)

		runtime_err := runtime_register_project_component(registry, Runtime_Component_Definition{
			id = id,
			version = int(scrapbot_luau_component_version(vm, c.size_t(component_index))),
			fields = fields,
		})
		if runtime_err != .None {
			return .Invalid_Script, script_registration_diagnostic_line(diagnostic_path, int(scrapbot_luau_component_line(vm, c.size_t(component_index))), "script component declaration is invalid")
		}
	}
	return .None, Script_Diagnostic{}
}

register_luau_bridge_systems :: proc(
	program: ^Script_Program,
	registry: ^Runtime_Component_Registry,
	vm: rawptr,
	diagnostic_path: string,
	system_start: int,
) -> (Project_Error, Script_Diagnostic) {
	system_count := int(scrapbot_luau_system_count(vm))
	for system_index := system_start; system_index < system_count; system_index += 1 {
		system_id := clone_luau_cstring(scrapbot_luau_system_id(vm, c.size_t(system_index)))
		if system_id == "" {
			return .Invalid_Script, script_registration_diagnostic_line(diagnostic_path, 0, "script system declaration is missing an id")
		}
		defer delete(system_id)

		phase_text := clone_luau_cstring(scrapbot_luau_system_phase(vm, c.size_t(system_index)))
		defer if phase_text != "" do delete(phase_text)
		phase, phase_ok := parse_script_system_phase(phase_text)
		if !phase_ok {
			return .Invalid_Script, script_system_registration_diagnostic_line(diagnostic_path, int(scrapbot_luau_system_line(vm, c.size_t(system_index))), system_id, "system phase is not supported")
		}

		reads, reads_ok := luau_bridge_system_string_list(vm, system_index, scrapbot_luau_system_reads_count, scrapbot_luau_system_reads_item)
		if !reads_ok {
			return .Invalid_Script, script_system_registration_diagnostic_line(diagnostic_path, int(scrapbot_luau_system_line(vm, c.size_t(system_index))), system_id, "system reads are invalid")
		}
		defer runtime_string_list_free(reads)

		writes, writes_ok := luau_bridge_system_string_list(vm, system_index, scrapbot_luau_system_writes_count, scrapbot_luau_system_writes_item)
		if !writes_ok {
			return .Invalid_Script, script_system_registration_diagnostic_line(diagnostic_path, int(scrapbot_luau_system_line(vm, c.size_t(system_index))), system_id, "system writes are invalid")
		}
		defer runtime_string_list_free(writes)

		before, before_ok := luau_bridge_system_string_list(vm, system_index, scrapbot_luau_system_before_count, scrapbot_luau_system_before_item)
		if !before_ok {
			return .Invalid_Script, script_system_registration_diagnostic_line(diagnostic_path, int(scrapbot_luau_system_line(vm, c.size_t(system_index))), system_id, "system before list is invalid")
		}
		defer runtime_string_list_free(before)

		after, after_ok := luau_bridge_system_string_list(vm, system_index, scrapbot_luau_system_after_count, scrapbot_luau_system_after_item)
		if !after_ok {
			return .Invalid_Script, script_system_registration_diagnostic_line(diagnostic_path, int(scrapbot_luau_system_line(vm, c.size_t(system_index))), system_id, "system after list is invalid")
		}
		defer runtime_string_list_free(after)

		runner_ref := scrapbot_luau_system_runner_ref(vm, c.size_t(system_index))
		runtime_err := runtime_register_project_system(registry, Runtime_System_Definition{
			id = system_id,
			phase = phase,
			reads = reads,
			writes = writes,
			before = before,
			after = after,
			runner = luau_bridge_system_runner(runner_ref),
		})
		if runtime_err != .None {
			return .Invalid_Script, script_system_registration_diagnostic_line(diagnostic_path, int(scrapbot_luau_system_line(vm, c.size_t(system_index))), system_id, "script system declaration is invalid")
		}
		origin_ok := script_program_append_system_origin(
			program,
			system_id,
			diagnostic_path,
			int(scrapbot_luau_system_line(vm, c.size_t(system_index))),
			runner_ref,
		)
		if !origin_ok {
			return .Invalid_Script, script_system_registration_diagnostic_line(diagnostic_path, int(scrapbot_luau_system_line(vm, c.size_t(system_index))), system_id, "failed to record script system origin")
		}
	}
	return .None, Script_Diagnostic{}
}

luau_bridge_system_runner :: proc(runner_ref: u32) -> Runtime_System_Runner {
	if runner_ref == 0 {
		return Runtime_System_Runner{}
	}
	return Runtime_System_Runner{kind = .Luau, ref = runner_ref}
}

script_program_append_system_origin :: proc(program: ^Script_Program, id, path: string, line: int, runner_ref: u32) -> bool {
	owned_id, id_err := strings.clone(id)
	if id_err != nil {
		return false
	}
	owned_path, path_err := strings.clone(path)
	if path_err != nil {
		delete(owned_id)
		return false
	}
	append(&program.system_origins, Script_System_Origin{
		id = owned_id,
		path = owned_path,
		line = line,
		runner_ref = runner_ref,
	})
	return true
}

script_program_run_schedule :: proc(
	program: ^Script_Program,
	registry: ^Runtime_Component_Registry,
	world: ^Runtime_World,
	schedule: Runtime_System_Schedule,
	delta_seconds: f32,
) -> Script_Run_Result {
	if program.vm == nil {
		return Script_Run_Result{ok = true}
	}
	for batch in schedule.batches {
		for system in batch.systems {
			if system.runner.kind == .None {
				continue
			}
			if system.runner.kind != .Luau {
				return Script_Run_Result{
					ok = false,
					diagnostic = script_runtime_diagnostic("", system.id, 0, "native Odin system execution is not ported yet"),
				}
			}

			script_program_clear_host_error(program)
			program.active_registry = registry
			program.active_system = system
			program.has_active_system = true
			scrapbot_luau_set_callback_context(program.vm, rawptr(program))
			ok := scrapbot_luau_call_system(program.vm, system.runner.ref, rawptr(world), f64(delta_seconds)) != 0
			program.has_active_system = false
			program.active_registry = nil
			if !ok {
				diagnostic := script_program_runtime_diagnostic(program, system)
				script_program_clear_host_error(program)
				return Script_Run_Result{ok = false, diagnostic = diagnostic}
			}
			script_program_clear_host_error(program)
		}
	}
	return Script_Run_Result{ok = true}
}

script_program_runtime_diagnostic :: proc(program: ^Script_Program, system: Runtime_Scheduled_System) -> Script_Diagnostic {
	message := ""
	message_owned := false
	if program.has_host_error {
		message = string(program.host_error_storage[:program.host_error_len])
	} else {
		message = clone_luau_cstring(scrapbot_luau_last_error(program.vm))
		if message != "" {
			message_owned = true
		}
	}
	if message == "" {
		message = "script runtime failed"
	}
	path := ""
	line := 0
	if origin, ok := script_program_find_system_origin(program^, system.id, system.runner.ref); ok {
		path = origin.path
		line = origin.line
	}
	diagnostic := script_runtime_diagnostic(path, system.id, line, message)
	if message_owned {
		delete(message)
	}
	return diagnostic
}

script_program_find_system_origin :: proc(program: Script_Program, system_id: string, runner_ref: u32) -> (Script_System_Origin, bool) {
	for origin in program.system_origins {
		if (runner_ref != 0 && origin.runner_ref == runner_ref) || origin.id == system_id {
			return origin, true
		}
	}
	return Script_System_Origin{}, false
}

script_program_active_system_allows_read :: proc(program: ^Script_Program, component_id: string) -> bool {
	if !program.has_active_system || program.active_registry == nil {
		return false
	}
	index := program.active_system.registry_index
	if index < 0 || index >= len(program.active_registry.systems) {
		return false
	}
	system := program.active_registry.systems[index]
	return runtime_contains_string(system.reads, component_id) || runtime_contains_string(system.writes, component_id)
}

script_program_active_system_allows_write :: proc(program: ^Script_Program, component_id: string) -> bool {
	if !program.has_active_system || program.active_registry == nil {
		return false
	}
	index := program.active_system.registry_index
	if index < 0 || index >= len(program.active_registry.systems) {
		return false
	}
	system := program.active_registry.systems[index]
	return runtime_contains_string(system.writes, component_id)
}

script_program_clear_host_error :: proc(program: ^Script_Program) {
	program.host_error_len = 0
	program.has_host_error = false
	program.host_error_storage[0] = 0
}

script_program_set_host_error :: proc(program: ^Script_Program, message: string) {
	script_program_clear_host_error(program)
	count := len(message)
	if count >= len(program.host_error_storage) {
		count = len(program.host_error_storage) - 1
	}
	copy(program.host_error_storage[:count], message[:count])
	program.host_error_storage[count] = 0
	program.host_error_len = count
	program.has_host_error = true
}

luau_bridge_callbacks :: proc() -> Luau_Bridge_Callbacks {
	return Luau_Bridge_Callbacks{
		query_next = luau_bridge_query_next,
		get_field = luau_bridge_get_field,
		set_field = luau_bridge_set_field,
		host_error = luau_bridge_host_error,
	}
}

luau_bridge_query_next :: proc "c" (
	ctx: rawptr,
	world: rawptr,
	component_ids: [^]cstring,
	component_count: c.size_t,
	cursor: ^u32,
	out_entity: ^u32,
	out_entity_generation: ^u32,
) -> c.int {
	program := cast(^Script_Program)ctx
	runtime_world := cast(^Runtime_World)world
	if program == nil || runtime_world == nil || cursor == nil || out_entity == nil || out_entity_generation == nil || component_ids == nil {
		return -1
	}
	context = program.odin_context
	count := int(component_count)
	if count <= 0 || count > 32 {
		script_program_set_host_error(program, "world query has invalid component count")
		return -1
	}
	ids := make([]string, count)
	if ids == nil {
		script_program_set_host_error(program, "world query failed to allocate component list")
		return -1
	}
	defer delete(ids)
	for index := 0; index < count; index += 1 {
		id := clone_luau_cstring(component_ids[index])
		if id == "" {
			for copied in ids[:index] {
				if copied != "" do delete(copied)
			}
			script_program_set_host_error(program, "world query has invalid component id")
			return -1
		}
		if !script_program_active_system_allows_read(program, id) {
			delete(id)
			for copied in ids[:index] {
				if copied != "" do delete(copied)
			}
			script_program_set_host_error(program, "system tried to query a component without declaring read access")
			return -1
		}
		ids[index] = id
	}
	defer {
		for id in ids {
			if id != "" do delete(id)
		}
	}

	cursor_value := int(cursor^)
	entity, found := runtime_world_query_next(runtime_world^, ids, &cursor_value)
	cursor^ = u32(cursor_value)
	if !found {
		return 0
	}
	out_entity^ = entity.index
	out_entity_generation^ = entity.generation
	return 1
}

luau_bridge_get_field :: proc "c" (
	ctx: rawptr,
	world: rawptr,
	entity: u32,
	entity_generation: u32,
	component_id: cstring,
	field_name: cstring,
	out_value: ^Luau_Bridge_Field_Value,
) -> c.int {
	program := cast(^Script_Program)ctx
	runtime_world := cast(^Runtime_World)world
	if program == nil || runtime_world == nil || out_value == nil {
		return 0
	}
	context = program.odin_context
	component := clone_luau_cstring(component_id)
	field := clone_luau_cstring(field_name)
	defer if component != "" do delete(component)
	defer if field != "" do delete(field)
	if component == "" || field == "" {
		script_program_set_host_error(program, "component field read has invalid field identity")
		return 0
	}
	if !script_program_active_system_allows_read(program, component) {
		script_program_set_host_error(program, "system tried to read a component field without declaring read access")
		return 0
	}
	value, err := runtime_world_get_component_field_value(runtime_world^, Entity_Handle{index = entity, generation = entity_generation}, component, field)
	if err != .None {
		script_program_set_host_error(program, "component field read failed")
		return 0
	}
	luau_value, ok := luau_bridge_field_value_from_runtime(value)
	if !ok {
		script_program_set_host_error(program, "component field read returned unsupported value")
		return 0
	}
	out_value^ = luau_value
	return 1
}

luau_bridge_set_field :: proc "c" (
	ctx: rawptr,
	world: rawptr,
	entity: u32,
	entity_generation: u32,
	component_id: cstring,
	field_name: cstring,
	value: ^Luau_Bridge_Field_Value,
) -> c.int {
	program := cast(^Script_Program)ctx
	runtime_world := cast(^Runtime_World)world
	if program == nil || runtime_world == nil || value == nil {
		return 0
	}
	context = program.odin_context
	component := clone_luau_cstring(component_id)
	field := clone_luau_cstring(field_name)
	defer if component != "" do delete(component)
	defer if field != "" do delete(field)
	if component == "" || field == "" {
		script_program_set_host_error(program, "component field write has invalid field identity")
		return 0
	}
	if !script_program_active_system_allows_write(program, component) {
		script_program_set_host_error(program, "system tried to write a component field without declaring write access")
		return 0
	}
	current, current_err := runtime_world_get_component_field_value(runtime_world^, Entity_Handle{index = entity, generation = entity_generation}, component, field)
	if current_err != .None {
		script_program_set_host_error(program, "component field write failed")
		return 0
	}
	runtime_value, value_ok := luau_bridge_field_value_to_runtime(value^, current.value_type)
	if !value_ok {
		script_program_set_host_error(program, "component field write value has unsupported type")
		return 0
	}
	err := runtime_world_set_component_field_value(runtime_world, Entity_Handle{index = entity, generation = entity_generation}, component, field, runtime_value)
	runtime_component_value_free(runtime_value)
	if err != .None {
		script_program_set_host_error(program, "component field write failed")
		return 0
	}
	return 1
}

luau_bridge_host_error :: proc "c" (ctx: rawptr) -> cstring {
	program := cast(^Script_Program)ctx
	if program == nil || !program.has_host_error {
		return nil
	}
	return cstring(raw_data(program.host_error_storage[:]))
}

luau_bridge_field_value_from_runtime :: proc(value: Runtime_Component_Value) -> (Luau_Bridge_Field_Value, bool) {
	switch value.value_type {
	case .Boolean:
		return Luau_Bridge_Field_Value{tag = .Boolean, boolean_value = c.int(1 if value.boolean else 0)}, true
	case .Int:
		return Luau_Bridge_Field_Value{tag = .Int, int_value = i32(value.int_value)}, true
	case .Float:
		return Luau_Bridge_Field_Value{tag = .Float, number_value = f64(value.float)}, true
	case .Vec3:
		return Luau_Bridge_Field_Value{tag = .Vec3, vec3_value = value.vec3}, true
	case .String:
		return Luau_Bridge_Field_Value{
			tag = .String,
			string_data = cstring(raw_data(value.string_value)),
			string_len = c.size_t(len(value.string_value)),
		}, true
	}
	return Luau_Bridge_Field_Value{}, false
}

luau_bridge_field_value_to_runtime :: proc(value: Luau_Bridge_Field_Value, expected_type: Runtime_Field_Type) -> (Runtime_Component_Value, bool) {
	switch expected_type {
	case .Boolean:
		if value.tag == .Boolean {
			return runtime_component_value_boolean(value.boolean_value != 0), true
		}
	case .Int:
		if value.tag == .Int {
			return runtime_component_value_int(int(value.int_value)), true
		}
		if value.tag == .Number {
			return runtime_component_value_int(int(value.number_value)), true
		}
	case .Float:
		if value.tag == .Float || value.tag == .Number {
			return runtime_component_value_float(f32(value.number_value)), true
		}
	case .Vec3:
		if value.tag == .Vec3 {
			return runtime_component_value_vec3(value.vec3_value), true
		}
	case .String:
		if value.tag == .String {
			if value.string_len > 0 && value.string_data == nil {
				return Runtime_Component_Value{}, false
			}
			text := ""
			if value.string_len > 0 {
				bytes := transmute([^]u8)value.string_data
				text = string(bytes[:int(value.string_len)])
			}
			owned, err := strings.clone(text)
			if err != nil {
				return Runtime_Component_Value{}, false
			}
			return Runtime_Component_Value{value_type = .String, string_value = owned}, true
		}
	}
	return Runtime_Component_Value{}, false
}

Luau_Bridge_List_Count_Proc :: #type proc "c" (vm: rawptr, system_index: c.size_t) -> c.size_t
Luau_Bridge_List_Item_Proc :: #type proc "c" (vm: rawptr, system_index, item_index: c.size_t) -> cstring

luau_bridge_system_string_list :: proc(
	vm: rawptr,
	system_index: int,
	count_proc: Luau_Bridge_List_Count_Proc,
	item_proc: Luau_Bridge_List_Item_Proc,
) -> ([]string, bool) {
	count := int(count_proc(vm, c.size_t(system_index)))
	values := make([]string, count)
	if values == nil && count > 0 {
		return nil, false
	}
	copied := 0
	for item_index := 0; item_index < count; item_index += 1 {
		value := clone_luau_cstring(item_proc(vm, c.size_t(system_index), c.size_t(item_index)))
		if value == "" {
			runtime_string_list_free(values[:copied])
			if values != nil {
				delete(values)
			}
			return nil, false
		}
		values[item_index] = value
		copied += 1
	}
	return values, true
}

luau_bridge_component_fields :: proc(vm: rawptr, component_index: int) -> ([]Runtime_Component_Field_Definition, bool) {
	field_count := int(scrapbot_luau_component_field_count(vm, c.size_t(component_index)))
	fields := make([]Runtime_Component_Field_Definition, field_count)
	if fields == nil && field_count > 0 {
		return nil, false
	}
	copied := 0
	for field_index := 0; field_index < field_count; field_index += 1 {
		name := clone_luau_cstring(scrapbot_luau_component_field_name(vm, c.size_t(component_index), c.size_t(field_index)))
		field_type_text := clone_luau_cstring(scrapbot_luau_component_field_type(vm, c.size_t(component_index), c.size_t(field_index)))
		if name == "" || field_type_text == "" {
			if name != "" do delete(name)
			if field_type_text != "" do delete(field_type_text)
			luau_bridge_field_definitions_free(fields[:copied])
			if fields != nil {
				delete(fields)
			}
			return nil, false
		}
		field_type, field_type_ok := component_field_type_from_script(field_type_text)
		delete(field_type_text)
		if !field_type_ok {
			delete(name)
			luau_bridge_field_definitions_free(fields[:copied])
			if fields != nil {
				delete(fields)
			}
			return nil, false
		}
		fields[field_index] = Runtime_Component_Field_Definition{name = name, value_type = field_type}
		copied += 1
	}
	return fields, true
}

luau_bridge_field_definitions_free :: proc(fields: []Runtime_Component_Field_Definition) {
	for field in fields {
		if field.name != "" {
			delete(field.name)
		}
	}
	if fields != nil {
		delete(fields)
	}
}

clone_luau_cstring :: proc(value: cstring) -> string {
	if value == nil {
		return ""
	}
	owned, err := strings.clone_from_cstring(value)
	if err != nil {
		return ""
	}
	return owned
}
