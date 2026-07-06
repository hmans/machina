package main

import "core:os"
import "core:strings"

Native_System_Operation_Kind :: enum {
	None,
	Set_Field,
	Lifecycle,
}

Native_Field_Assignment :: struct {
	name:       string,
	value_text: string,
}

Native_System_Operation :: struct {
	system_id:          string,
	path:               string,
	line:               int,
	runner_ref:         u32,
	kind:               Native_System_Operation_Kind,
	entity_id:          string,
	component_id:       string,
	field_name:         string,
	value_text:         string,
	has_spawn:          bool,
	spawn_entity_id:    string,
	spawn_entity_name:  string,
	spawn_component_id: string,
	spawn_fields:       [dynamic]Native_Field_Assignment,
	has_remove:         bool,
	remove_entity_id:   string,
	remove_component_id: string,
	has_despawn:        bool,
	despawn_entity_id:  string,
}

script_program_load_native_file :: proc(program: ^Script_Program, file_system_path, diagnostic_path: string) -> Project_Error {
	contents, read_err := os.read_entire_file(file_system_path, context.allocator)
	if read_err != nil {
		return .Missing_Native
	}
	defer delete(contents)
	return script_program_load_native_contents(program, string(contents), diagnostic_path)
}

script_program_load_native_contents :: proc(program: ^Script_Program, contents, diagnostic_path: string) -> Project_Error {
	remaining := contents
	remaining_offset := 0
	native_runner_ref := u32(1)
	for {
		call_index := strings.index(remaining, "scrapbot.register_system")
		if call_index < 0 {
			break
		}
		absolute_index := remaining_offset + call_index
		fragment := remaining[call_index:]
		block_start := strings.index_byte(fragment, '{')
		if block_start < 0 {
			return .Invalid_Native
		}
		block_end := strings.index(fragment[block_start:], "})")
		if block_end < 0 {
			return .Invalid_Native
		}
		block := fragment[block_start:block_start + block_end]
		system_id, id_ok := parse_native_component_id(block)
		if !id_ok {
			return .Invalid_Native
		}
		line := line_number_for_offset(contents, absolute_index)
		if !script_program_append_system_origin(program, system_id, diagnostic_path, line, native_runner_ref) {
			return .Invalid_Native
		}
		if operation, found, ok := parse_native_execute_operation(block, system_id, diagnostic_path, line, native_runner_ref); !ok {
			return .Invalid_Native
		} else if found {
			append(&program.native_operations, operation)
		}
		native_runner_ref += 1
		advance := block_start + block_end + len("})")
		remaining = fragment[advance:]
		remaining_offset = absolute_index + advance
	}
	return .None
}

parse_native_execute_operation :: proc(
	block, system_id, diagnostic_path: string,
	line: int,
	runner_ref: u32,
) -> (Native_System_Operation, bool, bool) {
	execute_key := native_assignment_key_index(block, "execute")
	if execute_key < 0 {
		return {}, false, true
	}
	open_offset := strings.index_byte(block[execute_key:], '{')
	if open_offset < 0 {
		return {}, false, false
	}
	execute_start := execute_key + open_offset
	execute_end, execute_ok := matching_brace_index(block, execute_start)
	if !execute_ok {
		return {}, false, false
	}
	execute_block := block[execute_start:execute_end + 1]

	entity_id, entity_ok := parse_native_string_field_value(execute_block, "entity")
	component_id, component_ok := parse_native_string_field_value(execute_block, "component")
	field_name, field_ok := parse_native_string_field_value(execute_block, "field")
	value_text, value_ok := parse_native_execute_value_text(execute_block, "value")
	if entity_ok && component_ok && field_ok && value_ok {
		operation := Native_System_Operation{
			line = line,
			runner_ref = runner_ref,
			kind = .Set_Field,
		}
		if !clone_native_operation_string(&operation.system_id, system_id) ||
		   !clone_native_operation_string(&operation.path, diagnostic_path) ||
		   !clone_native_operation_string(&operation.entity_id, entity_id) ||
		   !clone_native_operation_string(&operation.component_id, component_id) ||
		   !clone_native_operation_string(&operation.field_name, field_name) ||
		   !clone_native_operation_string(&operation.value_text, value_text) {
			native_system_operation_free(operation)
			return {}, false, false
		}
		return operation, true, true
	}

	operation, lifecycle_ok := parse_native_lifecycle_operation(execute_block, system_id, diagnostic_path, line, runner_ref)
	if !lifecycle_ok {
		return {}, false, false
	}
	return operation, true, true
}

parse_native_lifecycle_operation :: proc(
	execute_block, system_id, diagnostic_path: string,
	line: int,
	runner_ref: u32,
) -> (Native_System_Operation, bool) {
	operation := Native_System_Operation{
		line = line,
		runner_ref = runner_ref,
		kind = .Lifecycle,
	}
	if !clone_native_operation_string(&operation.system_id, system_id) ||
	   !clone_native_operation_string(&operation.path, diagnostic_path) {
		native_system_operation_free(operation)
		return {}, false
	}

	if spawn_block, spawn_found, spawn_ok := parse_native_block_field_value(execute_block, "spawn"); !spawn_ok {
		native_system_operation_free(operation)
		return {}, false
	} else if spawn_found {
		entity_id, entity_ok := parse_native_string_field_value(spawn_block, "entity")
		component_id, component_ok := parse_native_string_field_value(spawn_block, "component")
		if !entity_ok || !component_ok {
			native_system_operation_free(operation)
			return {}, false
		}
		entity_name, name_ok := parse_native_string_field_value(spawn_block, "name")
		if !name_ok {
			entity_name = entity_id
		}
		if !clone_native_operation_string(&operation.spawn_entity_id, entity_id) ||
		   !clone_native_operation_string(&operation.spawn_entity_name, entity_name) ||
		   !clone_native_operation_string(&operation.spawn_component_id, component_id) {
			native_system_operation_free(operation)
			return {}, false
		}
		if fields_block, fields_found, fields_ok := parse_native_block_field_value(spawn_block, "fields"); !fields_ok {
			native_system_operation_free(operation)
			return {}, false
		} else if fields_found {
			fields, parse_fields_ok := parse_native_field_assignments(fields_block)
			if !parse_fields_ok {
				native_system_operation_free(operation)
				return {}, false
			}
			operation.spawn_fields = fields
		}
		operation.has_spawn = true
	}

	if remove_block, remove_found, remove_ok := parse_native_block_field_value(execute_block, "remove"); !remove_ok {
		native_system_operation_free(operation)
		return {}, false
	} else if remove_found {
		entity_id, entity_ok := parse_native_string_field_value(remove_block, "entity")
		component_id, component_ok := parse_native_string_field_value(remove_block, "component")
		if !entity_ok || !component_ok ||
		   !clone_native_operation_string(&operation.remove_entity_id, entity_id) ||
		   !clone_native_operation_string(&operation.remove_component_id, component_id) {
			native_system_operation_free(operation)
			return {}, false
		}
		operation.has_remove = true
	}

	if despawn_block, despawn_found, despawn_ok := parse_native_block_field_value(execute_block, "despawn"); !despawn_ok {
		native_system_operation_free(operation)
		return {}, false
	} else if despawn_found {
		entity_id, entity_ok := parse_native_string_field_value(despawn_block, "entity")
		if !entity_ok || !clone_native_operation_string(&operation.despawn_entity_id, entity_id) {
			native_system_operation_free(operation)
			return {}, false
		}
		operation.has_despawn = true
	}

	if !operation.has_spawn && !operation.has_remove && !operation.has_despawn {
		native_system_operation_free(operation)
		return {}, false
	}
	return operation, true
}

parse_native_block_field_value :: proc(block, key: string) -> (string, bool, bool) {
	key_index := native_assignment_key_index(block, key)
	if key_index < 0 {
		return "", false, true
	}
	eq_index := strings.index_byte(block[key_index:], '=')
	if eq_index < 0 {
		return "", false, false
	}
	after_eq := key_index + eq_index + 1
	raw := strings.trim_space(block[after_eq:])
	if raw == "" || raw[0] != '{' {
		return "", false, false
	}
	open_index := after_eq + strings.index_byte(block[after_eq:], '{')
	close_index, close_ok := matching_brace_index(block, open_index)
	if !close_ok {
		return "", false, false
	}
	return block[open_index:close_index + 1], true, true
}

parse_native_field_assignments :: proc(fields_block: string) -> ([dynamic]Native_Field_Assignment, bool) {
	fields := make([dynamic]Native_Field_Assignment)
	if len(fields_block) < 2 || fields_block[0] != '{' || fields_block[len(fields_block) - 1] != '}' {
		return fields, false
	}
	remaining := fields_block[1:len(fields_block) - 1]
	for {
		remaining = strings.trim_space(remaining)
		for strings.has_prefix(remaining, ",") {
			remaining = strings.trim_space(remaining[1:])
		}
		if remaining == "" {
			break
		}
		name_end := 0
		for name_end < len(remaining) && is_script_identifier_byte(remaining[name_end]) {
			name_end += 1
		}
		if name_end == 0 {
			native_field_assignments_free(fields[:])
			delete(fields)
			return nil, false
		}
		name := remaining[:name_end]
		after_name := strings.trim_space(remaining[name_end:])
		if after_name == "" || after_name[0] != '=' {
			native_field_assignments_free(fields[:])
			delete(fields)
			return nil, false
		}
		raw_value := strings.trim_space(after_name[1:])
		value_text, consumed, value_ok := parse_native_execute_value_prefix(raw_value)
		if !value_ok {
			native_field_assignments_free(fields[:])
			delete(fields)
			return nil, false
		}
		field := Native_Field_Assignment{}
		if !clone_native_operation_string(&field.name, name) ||
		   !clone_native_operation_string(&field.value_text, value_text) {
			native_field_assignment_free(field)
			native_field_assignments_free(fields[:])
			delete(fields)
			return nil, false
		}
		append(&fields, field)
		after_value := strings.trim_space(raw_value[consumed:])
		if strings.has_prefix(after_value, ",") {
			remaining = after_value[1:]
		} else {
			remaining = after_value
		}
	}
	return fields, true
}

parse_native_execute_value_text :: proc(block, key: string) -> (string, bool) {
	key_index := native_assignment_key_index(block, key)
	if key_index < 0 {
		return "", false
	}
	eq_index := strings.index_byte(block[key_index:], '=')
	if eq_index < 0 {
		return "", false
	}
	raw := strings.trim_space(block[key_index + eq_index + 1:])
	if raw == "" {
		return "", false
	}
	value, _, ok := parse_native_execute_value_prefix(raw)
	return value, ok
}

parse_native_execute_value_prefix :: proc(raw: string) -> (string, int, bool) {
	if raw == "" {
		return "", 0, false
	}
	if raw[0] == '"' {
		_, consumed, ok := parse_quoted_prefix(raw)
		if !ok {
			return "", 0, false
		}
		return raw[:consumed], consumed, true
	}
	if raw[0] == '[' {
		close_index := strings.index_byte(raw, ']')
		if close_index < 0 {
			return "", 0, false
		}
		return strings.trim_space(raw[:close_index + 1]), close_index + 1, true
	}
	end := 0
	for end < len(raw) {
		byte := raw[end]
		if byte == ',' || byte == '\n' || byte == '\r' || byte == '}' {
			break
		}
		end += 1
	}
	value := strings.trim_space(raw[:end])
	return value, end, value != ""
}

matching_brace_index :: proc(text: string, open_index: int) -> (int, bool) {
	if open_index < 0 || open_index >= len(text) || text[open_index] != '{' {
		return -1, false
	}
	depth := 0
	for index := open_index; index < len(text); index += 1 {
		switch text[index] {
		case '{':
			depth += 1
		case '}':
			depth -= 1
			if depth == 0 {
				return index, true
			}
		}
	}
	return -1, false
}

script_program_run_native_system :: proc(
	program: ^Script_Program,
	registry: ^Runtime_Component_Registry,
	world: ^Runtime_World,
	system: Runtime_Scheduled_System,
) -> Script_Run_Result {
	operation, operation_ok := script_program_find_native_operation(program^, system)
	if !operation_ok {
		path, line := script_program_origin_for_system(program^, system.id, system.runner.ref)
		return Script_Run_Result{
			ok = false,
			diagnostic = script_runtime_diagnostic(path, system.id, line, "native Odin system execution is not ported yet"),
		}
	}
	switch operation.kind {
	case .Set_Field:
		return script_program_run_native_set_field(program, registry, world, system, operation)
	case .Lifecycle:
		return script_program_run_native_lifecycle(program, registry, world, system, operation)
	case .None:
	}
	return Script_Run_Result{
		ok = false,
		diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, "native Odin system operation is not supported"),
	}
}

script_program_run_native_set_field :: proc(
	program: ^Script_Program,
	registry: ^Runtime_Component_Registry,
	world: ^Runtime_World,
	system: Runtime_Scheduled_System,
	operation: Native_System_Operation,
) -> Script_Run_Result {
	if !runtime_scheduled_system_allows_write(registry^, system, operation.component_id) {
		message := strings.clone("native Odin system tried to write a component it did not declare")
		defer if message != "" do delete(message)
		return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, message)}
	}
	entity, entity_ok := runtime_world_find_entity_by_id(world^, operation.entity_id)
	if !entity_ok {
		return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, "native Odin system target entity was not found")}
	}
	current, current_err := runtime_world_get_component_field_value(world^, entity, operation.component_id, operation.field_name)
	if current_err != .None {
		return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, runtime_error_label(current_err))}
	}
	value, value_ok := read_scene_component_runtime_value(operation.value_text, current.value_type)
	if !value_ok {
		return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, "native Odin system value does not match target field type")}
	}
	set_err := runtime_world_set_component_field_value(world, entity, operation.component_id, operation.field_name, value)
	if set_err != .None {
		return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, runtime_error_label(set_err))}
	}
	return Script_Run_Result{ok = true}
}

script_program_run_native_lifecycle :: proc(
	program: ^Script_Program,
	registry: ^Runtime_Component_Registry,
	world: ^Runtime_World,
	system: Runtime_Scheduled_System,
	operation: Native_System_Operation,
) -> Script_Run_Result {
	system_definition, system_ok := runtime_scheduled_system_definition(registry^, system)
	if !system_ok {
		return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, "native Odin system definition was not found")}
	}

	spawned_entity := Entity_Handle{}
	if operation.has_spawn {
		entity, spawn_err := runtime_world_create_entity(world, operation.spawn_entity_id, operation.spawn_entity_name)
		if spawn_err != .None {
			return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, runtime_error_label(spawn_err))}
		}
		spawned_entity = entity
		record_err := runtime_deferred_record_immediate_spawn(&program.deferred, entity)
		if record_err != .None {
			_ = runtime_world_remove_entity(world, entity)
			return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, runtime_error_label(record_err))}
		}

		fields, fields_ok, fields_err := native_operation_runtime_fields(registry^, operation.spawn_component_id, operation.spawn_fields[:])
		if !fields_ok {
			runtime_deferred_discard(&program.deferred, world)
			return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, runtime_error_label(fields_err))}
		}
		defer runtime_component_field_values_free(fields)
		defer if fields != nil do delete(fields)

		queue_err := runtime_deferred_queue_add_component(&program.deferred, system_definition^, entity, operation.spawn_component_id, fields)
		if queue_err != .None {
			runtime_deferred_discard(&program.deferred, world)
			return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, runtime_error_label(queue_err))}
		}
	}

	if operation.has_remove {
		entity, entity_ok := runtime_world_find_entity_by_id(world^, operation.remove_entity_id)
		if !entity_ok {
			runtime_deferred_discard(&program.deferred, world)
			return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, "native Odin system remove target entity was not found")}
		}
		queue_err := runtime_deferred_queue_remove_component(&program.deferred, system_definition^, entity, operation.remove_component_id)
		if queue_err != .None {
			runtime_deferred_discard(&program.deferred, world)
			return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, runtime_error_label(queue_err))}
		}
	}

	if operation.has_despawn {
		entity, entity_ok := runtime_world_find_entity_by_id(world^, operation.despawn_entity_id)
		if !entity_ok {
			runtime_deferred_discard(&program.deferred, world)
			return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, "native Odin system despawn target entity was not found")}
		}
		if operation.has_spawn && entity.index == spawned_entity.index && entity.generation == spawned_entity.generation {
			runtime_deferred_discard(&program.deferred, world)
			return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, "native Odin lifecycle operation cannot despawn its immediate spawn")}
		}
		queue_err := runtime_deferred_queue_despawn_entity(&program.deferred, world^, system_definition^, entity)
		if queue_err != .None {
			runtime_deferred_discard(&program.deferred, world)
			return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, runtime_error_label(queue_err))}
		}
	}

	flush_err := runtime_deferred_flush(&program.deferred, world, registry^)
	if flush_err != .None {
		return Script_Run_Result{ok = false, diagnostic = script_runtime_diagnostic(operation.path, system.id, operation.line, runtime_error_label(flush_err))}
	}
	return Script_Run_Result{ok = true}
}

native_operation_runtime_fields :: proc(
	registry: Runtime_Component_Registry,
	component_id: string,
	assignments: []Native_Field_Assignment,
) -> ([]Runtime_Component_Field_Value, bool, Runtime_Error) {
	definition, definition_ok := runtime_find_component(registry, component_id)
	if !definition_ok {
		return nil, false, .Unknown_Component_Type
	}
	if len(assignments) != len(definition.fields) {
		return nil, false, .Unknown_Field
	}
	fields := make([]Runtime_Component_Field_Value, len(definition.fields))
	if fields == nil && len(definition.fields) > 0 {
		return nil, false, .Out_Of_Memory
	}
	copied_count := 0
	for field_definition, index in definition.fields {
		assignment, assignment_ok := native_field_assignment_find(assignments, field_definition.name)
		if !assignment_ok {
			runtime_component_field_values_free(fields[:copied_count])
			delete(fields)
			return nil, false, .Unknown_Field
		}
		value, value_ok := read_scene_component_runtime_value(assignment.value_text, field_definition.value_type)
		if !value_ok {
			runtime_component_field_values_free(fields[:copied_count])
			delete(fields)
			return nil, false, .Invalid_Field_Type
		}
		owned_value, value_err := runtime_component_value_clone(value)
		if value_err != .None {
			runtime_component_field_values_free(fields[:copied_count])
			delete(fields)
			return nil, false, value_err
		}
		owned_name, name_err := strings.clone(field_definition.name)
		if name_err != nil {
			runtime_component_value_free(owned_value)
			runtime_component_field_values_free(fields[:copied_count])
			delete(fields)
			return nil, false, .Out_Of_Memory
		}
		fields[index] = Runtime_Component_Field_Value{name = owned_name, value = owned_value}
		copied_count += 1
	}
	return fields, true, .None
}

native_field_assignment_find :: proc(assignments: []Native_Field_Assignment, name: string) -> (Native_Field_Assignment, bool) {
	for assignment in assignments {
		if assignment.name == name {
			return assignment, true
		}
	}
	return {}, false
}

runtime_scheduled_system_allows_write :: proc(
	registry: Runtime_Component_Registry,
	system: Runtime_Scheduled_System,
	component_id: string,
) -> bool {
	if system.registry_index < 0 || system.registry_index >= len(registry.systems) {
		return false
	}
	definition := registry.systems[system.registry_index]
	return runtime_contains_string(definition.writes, component_id)
}

runtime_scheduled_system_definition :: proc(
	registry: Runtime_Component_Registry,
	system: Runtime_Scheduled_System,
) -> (^Runtime_System_Definition, bool) {
	if system.registry_index < 0 || system.registry_index >= len(registry.systems) {
		return nil, false
	}
	return &registry.systems[system.registry_index], true
}

script_program_find_native_operation :: proc(program: Script_Program, system: Runtime_Scheduled_System) -> (Native_System_Operation, bool) {
	for operation in program.native_operations {
		if (system.runner.ref != 0 && operation.runner_ref == system.runner.ref) || operation.system_id == system.id {
			return operation, true
		}
	}
	return {}, false
}

script_program_origin_for_system :: proc(program: Script_Program, system_id: string, runner_ref: u32) -> (string, int) {
	if origin, ok := script_program_find_system_origin(program, system_id, runner_ref); ok {
		return origin.path, origin.line
	}
	return "", 0
}

line_number_for_offset :: proc(contents: string, offset: int) -> int {
	line := 1
	limit := native_min_int(offset, len(contents))
	for index := 0; index < limit; index += 1 {
		if contents[index] == '\n' {
			line += 1
		}
	}
	return line
}

native_min_int :: proc(left, right: int) -> int {
	if left < right {
		return left
	}
	return right
}

clone_native_operation_string :: proc(target: ^string, value: string) -> bool {
	owned, err := strings.clone(value)
	if err != nil {
		return false
	}
	target^ = owned
	return true
}

native_system_operations_free :: proc(operations: []Native_System_Operation) {
	for operation in operations {
		native_system_operation_free(operation)
	}
}

native_system_operation_free :: proc(operation: Native_System_Operation) {
	if operation.system_id != "" do delete(operation.system_id)
	if operation.path != "" do delete(operation.path)
	if operation.entity_id != "" do delete(operation.entity_id)
	if operation.component_id != "" do delete(operation.component_id)
	if operation.field_name != "" do delete(operation.field_name)
	if operation.value_text != "" do delete(operation.value_text)
	if operation.spawn_entity_id != "" do delete(operation.spawn_entity_id)
	if operation.spawn_entity_name != "" do delete(operation.spawn_entity_name)
	if operation.spawn_component_id != "" do delete(operation.spawn_component_id)
	native_field_assignments_free(operation.spawn_fields[:])
	if operation.spawn_fields != nil do delete(operation.spawn_fields)
	if operation.remove_entity_id != "" do delete(operation.remove_entity_id)
	if operation.remove_component_id != "" do delete(operation.remove_component_id)
	if operation.despawn_entity_id != "" do delete(operation.despawn_entity_id)
}

native_field_assignments_free :: proc(fields: []Native_Field_Assignment) {
	for field in fields {
		native_field_assignment_free(field)
	}
}

native_field_assignment_free :: proc(field: Native_Field_Assignment) {
	if field.name != "" do delete(field.name)
	if field.value_text != "" do delete(field.value_text)
}
