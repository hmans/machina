package main

import "core:strings"

Script_Diagnostic_Stage :: enum {
	None,
	Load,
	Native_Build,
	Native_Load,
	Native_Registration,
	Registration,
	Schedule,
	Runtime,
}

Script_Diagnostic_Position :: struct {
	line:       int,
	column:     int,
	has_column: bool,
}

Script_Diagnostic :: struct {
	stage:     Script_Diagnostic_Stage,
	path:      string,
	path_owned: bool,
	system_id: string,
	system_id_owned: bool,
	start:     Script_Diagnostic_Position,
	has_start: bool,
	message:   string,
	message_owned: bool,
}

script_diagnostic_present :: proc(diagnostic: Script_Diagnostic) -> bool {
	return diagnostic.stage != .None && diagnostic.message != ""
}

script_diagnostic_free :: proc(diagnostic: ^Script_Diagnostic) {
	if diagnostic.path_owned && diagnostic.path != "" {
		delete(diagnostic.path)
	}
	if diagnostic.system_id_owned && diagnostic.system_id != "" {
		delete(diagnostic.system_id)
	}
	if diagnostic.message_owned && diagnostic.message != "" {
		delete(diagnostic.message)
	}
	diagnostic^ = Script_Diagnostic{}
}

script_diagnostic_stage_name :: proc(stage: Script_Diagnostic_Stage) -> string {
	switch stage {
	case .Load:
		return "load"
	case .Native_Build:
		return "native_build"
	case .Native_Load:
		return "native_load"
	case .Native_Registration:
		return "native_registration"
	case .Registration:
		return "registration"
	case .Schedule:
		return "schedule"
	case .Runtime:
		return "runtime"
	case .None:
		return "none"
	}
	return "none"
}

script_diagnostic_stage_label :: proc(stage: Script_Diagnostic_Stage) -> string {
	switch stage {
	case .Load:
		return "script load"
	case .Native_Build:
		return "native build"
	case .Native_Load:
		return "native load"
	case .Native_Registration:
		return "native registration"
	case .Registration:
		return "script registration"
	case .Schedule:
		return "script schedule"
	case .Runtime:
		return "script runtime"
	case .None:
		return "script"
	}
	return "script"
}

script_diagnostic_line_from_offset :: proc(contents: string, absolute_offset: int) -> int {
	line := 1
	limit := absolute_offset
	if limit < 0 {
		limit = 0
	}
	if limit > len(contents) {
		limit = len(contents)
	}
	for index := 0; index < limit; index += 1 {
		if contents[index] == '\n' {
			line += 1
		}
	}
	return line
}

script_registration_diagnostic :: proc(path, contents: string, absolute_offset: int, message: string) -> Script_Diagnostic {
	return script_registration_diagnostic_line(path, script_diagnostic_line_from_offset(contents, absolute_offset), message)
}

script_registration_diagnostic_line :: proc(path: string, line: int, message: string) -> Script_Diagnostic {
	owned_path, path_owned := script_diagnostic_clone(path)
	return Script_Diagnostic{
		stage = .Registration,
		path = owned_path,
		path_owned = path_owned,
		start = Script_Diagnostic_Position{line = line},
		has_start = line > 0,
		message = message,
	}
}

script_system_registration_diagnostic :: proc(path, contents: string, absolute_offset: int, system_id: string, message: string) -> Script_Diagnostic {
	return script_system_registration_diagnostic_line(path, script_diagnostic_line_from_offset(contents, absolute_offset), system_id, message)
}

script_system_registration_diagnostic_line :: proc(path: string, line: int, system_id: string, message: string) -> Script_Diagnostic {
	diagnostic := script_registration_diagnostic_line(path, line, message)
	diagnostic.system_id, diagnostic.system_id_owned = script_diagnostic_clone(system_id)
	return diagnostic
}

script_load_diagnostic :: proc(path: string, message: string) -> Script_Diagnostic {
	owned_path, path_owned := script_diagnostic_clone(path)
	owned_message, message_owned := script_diagnostic_clone(message)
	if owned_message == "" {
		owned_message = message
	}
	line, has_line := script_luau_diagnostic_line(message)
	return Script_Diagnostic{
		stage = .Load,
		path = owned_path,
		path_owned = path_owned,
		start = Script_Diagnostic_Position{line = line},
		has_start = has_line,
		message = owned_message,
		message_owned = message_owned,
	}
}

script_schedule_diagnostic :: proc(phase: Runtime_System_Phase, message: string) -> Script_Diagnostic {
	return Script_Diagnostic{
		stage = .Schedule,
		message = script_schedule_message(phase, message),
	}
}

script_runtime_diagnostic :: proc(path: string, system_id: string, line: int, message: string) -> Script_Diagnostic {
	owned_path, path_owned := script_diagnostic_clone(path)
	owned_system_id, system_id_owned := script_diagnostic_clone(system_id)
	owned_message, message_owned := script_diagnostic_clone(message)
	if owned_message == "" {
		owned_message = message
	}
	effective_line := line
	parsed_line, has_parsed_line := script_luau_diagnostic_line(message)
	if has_parsed_line {
		effective_line = parsed_line
	}
	return Script_Diagnostic{
		stage = .Runtime,
		path = owned_path,
		path_owned = path_owned,
		system_id = owned_system_id,
		system_id_owned = system_id_owned,
		start = Script_Diagnostic_Position{line = effective_line},
		has_start = effective_line > 0,
		message = owned_message,
		message_owned = message_owned,
	}
}

script_schedule_message :: proc(phase: Runtime_System_Phase, message: string) -> string {
	if message != "failed to build script schedule" {
		return message
	}
	switch phase {
	case .Startup:
		return "failed to build script schedule: startup"
	case .Update:
		return "failed to build script schedule: update"
	case .Fixed_Update:
		return "failed to build script schedule: fixed_update"
	case .Render:
		return "failed to build script schedule: render"
	}
	return message
}

script_diagnostic_clone :: proc(value: string) -> (string, bool) {
	if value == "" {
		return "", false
	}
	owned, err := strings.clone(value)
	if err != nil {
		return "", false
	}
	return owned, true
}

script_luau_diagnostic_line :: proc(message: string) -> (int, bool) {
	index := strings.index_byte(message, ':')
	for index >= 0 && index + 1 < len(message) {
		number_start := index + 1
		if !script_ascii_digit(message[number_start]) {
			next := strings.index_byte(message[index + 1:], ':')
			if next < 0 {
				return 0, false
			}
			index = index + 1 + next
			continue
		}

		number_end := number_start
		line := 0
		for number_end < len(message) && script_ascii_digit(message[number_end]) {
			line = line * 10 + int(message[number_end] - '0')
			number_end += 1
		}
		if number_end < len(message) && message[number_end] == ':' && line > 0 {
			return line, true
		}

		next := strings.index_byte(message[number_end:], ':')
		if next < 0 {
			return 0, false
		}
		index = number_end + next
	}
	return 0, false
}

script_ascii_digit :: proc(value: byte) -> bool {
	return value >= '0' && value <= '9'
}
