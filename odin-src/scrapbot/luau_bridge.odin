package main

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

Luau_Bridge_Callbacks :: struct {
	query_next:                 rawptr,
	prepare_query:              rawptr,
	query_next_prepared:        rawptr,
	query_plan_generation:      rawptr,
	read_f32_view:              rawptr,
	write_f32_view:             rawptr,
	read_vec3_view:             rawptr,
	write_vec3_view:            rawptr,
	get_vec3:                   rawptr,
	set_vec3:                   rawptr,
	get_field:                  rawptr,
	get_field_resolved:         rawptr,
	set_field:                  rawptr,
	set_field_resolved:         rawptr,
	spawn_entity:               rawptr,
	despawn_entity:             rawptr,
	add_component:              rawptr,
	remove_component:           rawptr,
	host_error:                 rawptr,
}

@(default_calling_convention = "c")
foreign luau_bridge {
	scrapbot_luau_create :: proc(callbacks: Luau_Bridge_Callbacks) -> rawptr ---
	scrapbot_luau_destroy :: proc(vm: rawptr) ---
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
}

Luau_Bridge_Register_Result :: struct {
	err:        Project_Error,
	diagnostic: Script_Diagnostic,
}

register_script_components_with_luau_bridge :: proc(
	registry: ^Runtime_Component_Registry,
	file_system_path: string,
	diagnostic_path: string,
) -> Luau_Bridge_Register_Result {
	contents, read_err := os.read_entire_file(file_system_path, context.allocator)
	if read_err != nil {
		return Luau_Bridge_Register_Result{err = .Missing_Script}
	}
	defer delete(contents)

	vm := scrapbot_luau_create(Luau_Bridge_Callbacks{})
	if vm == nil {
		return Luau_Bridge_Register_Result{
			err = .Invalid_Script,
			diagnostic = script_load_diagnostic(diagnostic_path, "failed to create Luau VM"),
		}
	}
	defer scrapbot_luau_destroy(vm)

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
	if scrapbot_luau_load(vm, chunk_name, source, c.size_t(len(contents))) == 0 {
		message := clone_luau_cstring(scrapbot_luau_last_error(vm))
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

	component_err, component_diagnostic := register_luau_bridge_components(registry, vm, diagnostic_path)
	if component_err != .None {
		return Luau_Bridge_Register_Result{err = component_err, diagnostic = component_diagnostic}
	}
	system_err, system_diagnostic := register_luau_bridge_systems(registry, vm, diagnostic_path)
	if system_err != .None {
		return Luau_Bridge_Register_Result{err = system_err, diagnostic = system_diagnostic}
	}
	return Luau_Bridge_Register_Result{}
}

register_luau_bridge_components :: proc(
	registry: ^Runtime_Component_Registry,
	vm: rawptr,
	diagnostic_path: string,
) -> (Project_Error, Script_Diagnostic) {
	component_count := int(scrapbot_luau_component_count(vm))
	for component_index := 0; component_index < component_count; component_index += 1 {
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
	registry: ^Runtime_Component_Registry,
	vm: rawptr,
	diagnostic_path: string,
) -> (Project_Error, Script_Diagnostic) {
	system_count := int(scrapbot_luau_system_count(vm))
	for system_index := 0; system_index < system_count; system_index += 1 {
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
	}
	return .None, Script_Diagnostic{}
}

luau_bridge_system_runner :: proc(runner_ref: u32) -> Runtime_System_Runner {
	if runner_ref == 0 {
		return Runtime_System_Runner{}
	}
	return Runtime_System_Runner{kind = .Luau, ref = runner_ref}
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
