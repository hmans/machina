package native

import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"
import component "../component"
import api "../extension_api"

EXTENSIONS_DIR :: "build/extensions"
REGISTER_SYMBOL :: "scrapbot_extension_register"
MAX_EXTENSIONS :: 32

Extension_Stamp :: struct {
	exists: bool,
	modified_ns: i64,
	size: i64,
}

Extension :: struct {
	path: string,
	stamp: Extension_Stamp,
	library: dynlib.Library,
}

Extension_Set :: struct {
	extensions: [MAX_EXTENSIONS]Extension,
	extension_count: int,
	registry: ^component.Registry,
}

Load_Result :: struct {
	loaded_count: int,
	err: string,
}

load_project_extensions :: proc(set: ^Extension_Set, root: string, registry: ^component.Registry) -> Load_Result {
	destroy_extension_set(set)
	set.registry = registry
	defer set.registry = nil

	extension_paths, paths_err := project_extension_paths(root)
	if paths_err != "" {
		return Load_Result{err = paths_err}
	}
	defer destroy_extension_paths(extension_paths)

	for path in extension_paths {
		if set.extension_count >= MAX_EXTENSIONS {
			return Load_Result{loaded_count = set.extension_count, err = "too many native extensions"}
		}
		if err := load_extension(set, path); err != "" {
			return Load_Result{loaded_count = set.extension_count, err = err}
		}
	}

	return Load_Result{loaded_count = set.extension_count}
}

destroy_extension_set :: proc(set: ^Extension_Set) {
	if set == nil {
		return
	}
	for &extension in set.extensions[:set.extension_count] {
		if extension.library != nil {
			dynlib.unload_library(extension.library)
		}
		delete(extension.path)
	}
	set^ = {}
}

project_extensions_changed :: proc(set: ^Extension_Set, root: string) -> bool {
	extension_paths, paths_err := project_extension_paths(root)
	if paths_err != "" {
		return set != nil && set.extension_count > 0
	}
	defer destroy_extension_paths(extension_paths)

	if set == nil {
		return len(extension_paths) > 0
	}
	if len(extension_paths) != set.extension_count {
		return true
	}

	for path, index in extension_paths {
		if set.extensions[index].path != path {
			return true
		}
		if !extension_stamps_equal(set.extensions[index].stamp, extension_stamp(path)) {
			return true
		}
	}
	return false
}

load_extension :: proc(set: ^Extension_Set, path: string) -> string {
	library, ok := dynlib.load_library(path)
	if !ok {
		return fmt.tprintf("failed to load native extension %s: %s", path, dynlib.last_error())
	}

	symbol, found := dynlib.symbol_address(library, REGISTER_SYMBOL)
	if !found {
		dynlib.unload_library(library)
		return fmt.tprintf("native extension %s does not export %s", path, REGISTER_SYMBOL)
	}

	register := cast(api.Register_Proc)symbol
	host_api := api.API {
		abi_version = api.ABI_VERSION,
		userdata = set,
		register_library_component = extension_register_library_component,
	}
	if register_err := register(&host_api); register_err != nil {
		dynlib.unload_library(library)
		return fmt.tprintf("native extension %s failed to register: %s", path, string(register_err))
	}

	cloned_path, clone_err := strings.clone(path)
	if clone_err != nil {
		dynlib.unload_library(library)
		return "failed to retain native extension path"
	}

	set.extensions[set.extension_count] = Extension {
		path = cloned_path,
		stamp = extension_stamp(path),
		library = library,
	}
	set.extension_count += 1
	return ""
}

extension_register_library_component :: proc "c" (
	host_api: ^api.API,
	definition: ^api.Component_Definition,
) -> cstring {
	if host_api == nil || host_api.userdata == nil || definition == nil {
		return "native extension registration API is not available"
	}
	set := cast(^Extension_Set)host_api.userdata
	if set.registry == nil {
		return "native extension component registry is not available"
	}
	if definition.name == nil {
		return "native extension component name is required"
	}
	if definition.field_count < 0 || definition.field_count > api.MAX_COMPONENT_FIELDS {
		return "native extension component has too many fields"
	}

	component_definition: component.Definition
	component_definition.name = string(definition.name)
	component_definition.field_count = int(definition.field_count)
	for i in 0..<component_definition.field_count {
		field := definition.fields[i]
		if field.name == nil {
			return "native extension component field name is required"
		}
		field_type, field_type_ok := extension_field_type(field.field_type)
		if !field_type_ok {
			return "native extension component field type is not supported"
		}
		component_definition.fields[i] = component.Field_Definition {
			name = string(field.name),
			field_type = field_type,
		}
	}

	if err := component.register_library_component(set.registry, component_definition); err != "" {
		return "native extension component registration failed"
	}
	return nil
}

extension_field_type :: proc "c" (field_type: api.Field_Type) -> (component.Field_Type, bool) {
	#partial switch field_type {
	case .Vec3:
		return .Vec3, true
	}
	return {}, false
}

project_extension_paths :: proc(root: string) -> (paths: []string, err: string) {
	extensions_dir, join_err := filepath.join({root, EXTENSIONS_DIR})
	if join_err != nil {
		return nil, "failed to allocate native extension directory path"
	}
	defer delete(extensions_dir)

	if !os.exists(extensions_dir) {
		return nil, ""
	}

	entries, read_err := os.read_all_directory_by_path(extensions_dir, context.temp_allocator)
	if read_err != nil {
		return nil, fmt.tprintf("failed to read native extension directory: %v", read_err)
	}

	builder: [dynamic]string
	for entry in entries {
		if entry.type != .Regular {
			continue
		}
		if !strings.has_suffix(entry.name, "." + dynlib.LIBRARY_FILE_EXTENSION) {
			continue
		}
		path, path_err := filepath.join({extensions_dir, entry.name})
		if path_err != nil {
			destroy_extension_paths(builder[:])
			return nil, "failed to allocate native extension path"
		}
		append(&builder, path)
	}

	paths = make([]string, len(builder))
	copy(paths, builder[:])
	delete(builder)
	sort_strings(paths)
	return paths, ""
}

destroy_extension_paths :: proc(paths: []string) {
	for path in paths {
		delete(path)
	}
	delete(paths)
}

sort_strings :: proc(values: []string) {
	for i in 1..<len(values) {
		value := values[i]
		j := i
		for j > 0 && values[j - 1] > value {
			values[j] = values[j - 1]
			j -= 1
		}
		values[j] = value
	}
}

extension_stamp :: proc(path: string) -> Extension_Stamp {
	fi, err := os.stat(path, context.temp_allocator)
	if err != nil {
		return {}
	}
	defer os.file_info_delete(fi, context.temp_allocator)

	return Extension_Stamp {
		exists = true,
		modified_ns = time.to_unix_nanoseconds(fi.modification_time),
		size = fi.size,
	}
}

extension_stamps_equal :: proc(a, b: Extension_Stamp) -> bool {
	return a.exists == b.exists && a.modified_ns == b.modified_ns && a.size == b.size
}
