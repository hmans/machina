package main

import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import "core:time"

BUILD_DEFAULT_OUTPUT_DIR :: "build"
BUILD_BUNDLE_MARKER :: ".scrapbot-build-bundle"
BUILD_PROJECT_DIR :: "project"
BUILD_BIN_DIR :: "bin"
BUILD_LIB_DIR :: "lib"
BUILD_MANIFEST_PATH :: "scrapbot-build.json"
BUILD_NATIVE_ARTIFACT_DIR :: ".scrapbot/build/native"
BUILD_ODIN_NATIVE_SDK_DIR :: ".scrapbot/build/odin-sdk"
BUILD_ODIN_NATIVE_COLLECTION :: "scrapbot"

Build_Options :: struct {
	target_path: string,
	output_root: string,
	name: string,
	force: bool,
}

Build_Result :: struct {
	project_name: string,
	bundle_path: string,
	project_path: string,
	runtime_path: string,
	launcher_path: string,
	native_artifact: string,
	sdl3_bundled: bool,
	sdl3_warning: string,
}

free_build_result :: proc(result: Build_Result) {
	if result.project_name != "" {
		delete(result.project_name)
	}
	if result.bundle_path != "" {
		delete(result.bundle_path)
	}
	if result.project_path != "" {
		delete(result.project_path)
	}
	if result.runtime_path != "" {
		delete(result.runtime_path)
	}
	if result.launcher_path != "" {
		delete(result.launcher_path)
	}
	if result.native_artifact != "" {
		delete(result.native_artifact)
	}
	if result.sdl3_warning != "" {
		delete(result.sdl3_warning)
	}
}

build_project :: proc(options: Build_Options) -> (Build_Result, Project_Error) {
	check := check_project(options.target_path)
	defer free_check_result(check)
	if check.err != .None {
		return Build_Result{}, check.err
	}

	bundle_name := options.name
	owned_bundle_name := ""
	if bundle_name == "" {
		generated, generated_ok := default_build_bundle_name(check.project.name)
		if !generated_ok {
			return Build_Result{}, .Io_Error
		}
		owned_bundle_name = generated
		defer delete(owned_bundle_name)
		bundle_name = owned_bundle_name
	}
	if !is_safe_bundle_name(bundle_name) {
		return Build_Result{}, .Invalid_Project_Name
	}

	output_root := options.output_root
	owned_output_root := ""
	if output_root == "" {
		joined, join_err := filepath.join([]string{check.project.root_path, BUILD_DEFAULT_OUTPUT_DIR})
		if join_err != nil {
			return Build_Result{}, .Io_Error
		}
		owned_output_root = joined
		defer delete(owned_output_root)
		output_root = owned_output_root
	}

	bundle_path, bundle_join_err := filepath.join([]string{output_root, bundle_name})
	if bundle_join_err != nil {
		return Build_Result{}, .Io_Error
	}
	keep_bundle_path := false
	defer {
		if !keep_bundle_path {
			delete(bundle_path)
		}
	}

	if os.exists(bundle_path) {
		if !options.force || !is_scrapbot_build_bundle(bundle_path) {
			return Build_Result{}, .Already_Exists
		}
		if os.remove_all(bundle_path) != nil {
			return Build_Result{}, .Io_Error
		}
	}

	keep_bundle_tree := false
	defer {
		if !keep_bundle_tree {
			os.remove_all(bundle_path)
		}
	}

	if !ensure_directory(bundle_path) {
		return Build_Result{}, .Io_Error
	}
	marker_path, marker_err := filepath.join([]string{bundle_path, BUILD_BUNDLE_MARKER})
	if marker_err != nil {
		return Build_Result{}, .Io_Error
	}
	defer delete(marker_path)
	if os.write_entire_file(marker_path, "scrapbot build bundle\n") != nil {
		return Build_Result{}, .Io_Error
	}

	project_bundle_path, project_bundle_err := filepath.join([]string{bundle_path, BUILD_PROJECT_DIR})
	if project_bundle_err != nil {
		return Build_Result{}, .Io_Error
	}
	keep_project_bundle_path := false
	defer {
		if !keep_project_bundle_path {
			delete(project_bundle_path)
		}
	}
	bin_path, bin_err := filepath.join([]string{bundle_path, BUILD_BIN_DIR})
	if bin_err != nil {
		return Build_Result{}, .Io_Error
	}
	defer delete(bin_path)
	lib_path, lib_err := filepath.join([]string{bundle_path, BUILD_LIB_DIR})
	if lib_err != nil {
		return Build_Result{}, .Io_Error
	}
	defer delete(lib_path)
	if !ensure_directory(project_bundle_path) ||
	   !ensure_directory(bin_path) ||
	   !ensure_directory(lib_path) {
		return Build_Result{}, .Io_Error
	}

	skip_root_entry, output_ok := output_root_entry_to_skip(check.project.root_path, output_root, bundle_path)
	if !output_ok {
		return Build_Result{}, .Invalid_Build_Output
	}
	defer {
		if skip_root_entry != "" {
			delete(skip_root_entry)
		}
	}
	if !copy_project_tree(check.project.root_path, project_bundle_path, skip_root_entry) {
		return Build_Result{}, .Io_Error
	}

	native_artifact := ""
	keep_native_artifact := false
	defer {
		if !keep_native_artifact && native_artifact != "" {
			delete(native_artifact)
		}
	}
	if check.project.native_artifact != "" {
		if !copy_packaged_native_artifact(check.project.root_path, project_bundle_path, check.project.native_artifact) {
			return Build_Result{}, .Io_Error
		}
		owned_native_artifact := strings.clone(check.project.native_artifact)
		if owned_native_artifact == "" {
			return Build_Result{}, .Io_Error
		}
		native_artifact = owned_native_artifact
	} else if check.project.native != "" && strings.has_suffix(check.project.native, ".odin") {
		built_native_artifact, native_build_ok := build_odin_native_artifact(project_bundle_path, check.project.native)
		if !native_build_ok {
			return Build_Result{}, .Invalid_Native
		}
		native_artifact = built_native_artifact
		if !rewrite_packaged_project_manifest(project_bundle_path, native_artifact) {
			return Build_Result{}, .Io_Error
		}
	}

	executable_path, executable_err := os.get_executable_path(context.allocator)
	if executable_err != nil {
		return Build_Result{}, .Io_Error
	}
	defer delete(executable_path)
	runtime_bundle_path, runtime_join_err := filepath.join([]string{bundle_path, BUILD_BIN_DIR, executable_file_name()})
	if runtime_join_err != nil {
		return Build_Result{}, .Io_Error
	}
	keep_runtime_bundle_path := false
	defer {
		if !keep_runtime_bundle_path {
			delete(runtime_bundle_path)
		}
	}
	if os.copy_file(runtime_bundle_path, executable_path) != nil {
		return Build_Result{}, .Io_Error
	}

	packaged_check := check_project(project_bundle_path)
	if packaged_check.err != .None {
		free_check_result(packaged_check)
		return Build_Result{}, packaged_check.err
	}
	free_check_result(packaged_check)

	launcher_path, launcher_err := filepath.join([]string{bundle_path, launcher_file_name()})
	if launcher_err != nil {
		return Build_Result{}, .Io_Error
	}
	keep_launcher_path := false
	defer {
		if !keep_launcher_path {
			delete(launcher_path)
		}
	}
	if !write_launcher(launcher_path) {
		return Build_Result{}, .Io_Error
	}

	manifest_path, manifest_err := filepath.join([]string{bundle_path, BUILD_MANIFEST_PATH})
	if manifest_err != nil {
		return Build_Result{}, .Io_Error
	}
	defer delete(manifest_path)
	sdl3_bundled := copy_discoverable_sdl3(lib_path)
	sdl3_warning := ""
	if !sdl3_bundled {
		sdl3_warning = strings.clone("SDL3 was not copied; the target machine must provide a compatible SDL3 runtime library.")
	}
	keep_sdl3_warning := false
	defer {
		if !keep_sdl3_warning {
			if sdl3_warning != "" {
				delete(sdl3_warning)
			}
		}
	}
	if !write_build_manifest(manifest_path, check.project.name, bundle_path, runtime_bundle_path, project_bundle_path, native_artifact, sdl3_bundled, sdl3_warning) {
		return Build_Result{}, .Io_Error
	}

	project_name := strings.clone(check.project.name)
	keep_project_name := false
	defer {
		if !keep_project_name {
			delete(project_name)
		}
	}

	keep_bundle_tree = true
	keep_bundle_path = true
	keep_project_bundle_path = true
	keep_runtime_bundle_path = true
	keep_launcher_path = true
	keep_native_artifact = true
	keep_sdl3_warning = true
	keep_project_name = true
	return Build_Result{
		project_name = project_name,
		bundle_path = bundle_path,
		project_path = project_bundle_path,
		runtime_path = runtime_bundle_path,
		launcher_path = launcher_path,
		native_artifact = native_artifact,
		sdl3_bundled = sdl3_bundled,
		sdl3_warning = sdl3_warning,
	}, .None
}

default_build_bundle_name :: proc(project_name: string) -> (string, bool) {
	sanitized := sanitize_bundle_segment(project_name)
	defer delete(sanitized)
	if sanitized == "" {
		return "", false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	strings.write_string(&builder, sanitized)
	strings.write_rune(&builder, '-')
	strings.write_string(&builder, host_triple())
	return strings.clone(strings.to_string(builder)), true
}

sanitize_bundle_segment :: proc(value: string) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	last_dash := false
	wrote := false
	for c in value {
		next: rune
		if c >= 'A' && c <= 'Z' {
			next = c + ('a' - 'A')
		} else if (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '.' || c == '_' {
			next = c
		} else {
			next = '-'
		}
		if next == '-' {
			if last_dash || !wrote {
				continue
			}
			last_dash = true
		} else {
			last_dash = false
		}
		strings.write_rune(&builder, next)
		wrote = true
	}
	out := strings.clone(strings.to_string(builder))
	for len(out) > 0 && out[len(out) - 1] == '-' {
		out = out[:len(out) - 1]
	}
	if out == "" {
		delete(out)
		return strings.clone("scrapbot-project")
	}
	return out
}

host_triple :: proc() -> string {
	when ODIN_OS == .Darwin {
		when ODIN_ARCH == .arm64 {
			return "aarch64-macos"
		} else when ODIN_ARCH == .amd64 {
			return "x86_64-macos"
		}
		return "macos"
	}
	when ODIN_OS == .Linux {
		when ODIN_ARCH == .arm64 {
			return "aarch64-linux"
		} else when ODIN_ARCH == .amd64 {
			return "x86_64-linux"
		}
		return "linux"
	}
	when ODIN_OS == .Windows {
		when ODIN_ARCH == .arm64 {
			return "aarch64-windows-msvc"
		} else when ODIN_ARCH == .amd64 {
			return "x86_64-windows-msvc"
		}
		return "windows-msvc"
	}
	return "unknown"
}

is_safe_bundle_name :: proc(name: string) -> bool {
	if name == "" || name == "." || name == ".." || filepath.is_abs(name) {
		return false
	}
	return !strings.contains(name, "/") && !strings.contains(name, "\\")
}

is_scrapbot_build_bundle :: proc(bundle_path: string) -> bool {
	marker_path, err := filepath.join([]string{bundle_path, BUILD_BUNDLE_MARKER})
	if err != nil {
		return false
	}
	defer delete(marker_path)
	return os.exists(marker_path)
}

output_root_entry_to_skip :: proc(project_root_path, output_root, bundle_path: string) -> (string, bool) {
	project_abs, project_abs_err := filepath.abs(project_root_path)
	if project_abs_err != nil {
		return "", false
	}
	defer delete(project_abs)
	output_abs, output_abs_err := filepath.abs(output_root)
	if output_abs_err != nil {
		return "", false
	}
	defer delete(output_abs)
	bundle_abs, bundle_abs_err := filepath.abs(bundle_path)
	if bundle_abs_err != nil {
		return "", false
	}
	defer delete(bundle_abs)

	if paths_equal(output_abs, project_abs) {
		rel, rel_err := filepath.rel(project_abs, bundle_abs)
		if rel_err != .None {
			return "", false
		}
		defer delete(rel)
		return strings.clone(first_path_segment(rel)), true
	}
	if path_is_inside(output_abs, project_abs) {
		rel, rel_err := filepath.rel(project_abs, output_abs)
		if rel_err != .None {
			return "", false
		}
		defer delete(rel)
		if strings.contains(rel, "/") || strings.contains(rel, "\\") {
			return "", false
		}
		return strings.clone(rel), true
	}
	if path_is_inside(bundle_abs, project_abs) {
		rel, rel_err := filepath.rel(project_abs, bundle_abs)
		if rel_err != .None {
			return "", false
		}
		defer delete(rel)
		return strings.clone(first_path_segment(rel)), true
	}
	return "", true
}

path_is_inside :: proc(path, parent: string) -> bool {
	if len(path) <= len(parent) || !strings.has_prefix(path, parent) {
		return false
	}
	separator := path[len(parent)]
	return separator == '/' || separator == '\\'
}

paths_equal :: proc(a, b: string) -> bool {
	return a == b
}

first_path_segment :: proc(path: string) -> string {
	for c, index in path {
		if c == '/' || c == '\\' {
			return path[:index]
		}
	}
	return path
}

copy_project_tree :: proc(source_root_path, dest_root_path, skip_root_entry: string) -> bool {
	source_abs, source_abs_err := filepath.abs(source_root_path)
	if source_abs_err != nil {
		return false
	}
	defer delete(source_abs)
	walker := os.walker_create_path(source_abs)
	defer os.walker_destroy(&walker)
	for info in os.walker_walk(&walker) {
		if _, walk_err := os.walker_error(&walker); walk_err != nil {
			return false
		}
		rel, rel_err := filepath.rel(source_abs, info.fullpath)
		if rel_err != .None {
			return false
		}
		defer delete(rel)
		if rel == "." {
			continue
		}
		root_entry := first_path_segment(rel)
		if should_skip_project_root_entry(root_entry, skip_root_entry) {
			if info.type == .Directory {
				os.walker_skip_dir(&walker)
			}
			continue
		}
		dest_path, dest_err := filepath.join([]string{dest_root_path, rel})
		if dest_err != nil {
			return false
		}
		defer delete(dest_path)
		#partial switch info.type {
		case .Directory:
			if !ensure_directory(dest_path) {
				return false
			}
		case .Regular:
			parent := os.dir(dest_path)
			if !ensure_directory(parent) {
				return false
			}
			if os.copy_file(dest_path, info.fullpath) != nil {
				return false
			}
		case:
		}
	}
	if _, walk_err := os.walker_error(&walker); walk_err != nil {
		return false
	}
	return true
}

should_skip_project_root_entry :: proc(name, skip_root_entry: string) -> bool {
	if skip_root_entry != "" && name == skip_root_entry {
		return true
	}
	switch name {
	case ".scrapbot", ".git", ".zig-cache", "zig-cache", "zig-out":
		return true
	}
	return false
}

copy_packaged_native_artifact :: proc(project_root_path, project_bundle_path, artifact_path: string) -> bool {
	source_path := project_relative_path(project_root_path, artifact_path)
	defer delete(source_path)
	dest_path := project_relative_path(project_bundle_path, artifact_path)
	defer delete(dest_path)
	parent := os.dir(dest_path)
	if !ensure_directory(parent) {
		return false
	}
	if os.exists(dest_path) {
		os.remove(dest_path)
	}
	return os.copy_file(dest_path, source_path) == nil
}

build_odin_native_artifact :: proc(project_bundle_path, native_path: string) -> (string, bool) {
	native_artifact_project_path, artifact_path_ok := build_native_artifact_project_path()
	if !artifact_path_ok {
		return "", false
	}
	keep_artifact_project_path := false
	defer {
		if !keep_artifact_project_path {
			delete(native_artifact_project_path)
		}
	}

	artifact_full_path := project_relative_path(project_bundle_path, native_artifact_project_path)
	defer delete(artifact_full_path)
	artifact_parent := os.dir(artifact_full_path)
	if !ensure_directory(artifact_parent) {
		return "", false
	}
	if os.exists(artifact_full_path) {
		os.remove(artifact_full_path)
	}

	if !write_odin_native_sdk(project_bundle_path) {
		return "", false
	}

	native_source_dir := os.dir(native_path)
	if native_source_dir == "" {
		native_source_dir = "."
	}
	collection_arg := build_odin_collection_arg()
	if collection_arg == "" {
		return "", false
	}
	defer delete(collection_arg)
	output_arg := build_prefixed_string("-out:", native_artifact_project_path)
	if output_arg == "" {
		return "", false
	}
	defer delete(output_arg)
	command := []string{
		"odin",
		"build",
		native_source_dir,
		"-build-mode:dll",
		output_arg,
		collection_arg,
	}
	state, stdout, stderr, exec_err := os.process_exec(os.Process_Desc{
		working_dir = project_bundle_path,
		command = command,
	}, context.allocator)
	if stdout != nil {
		delete(stdout)
	}
	if stderr != nil {
		delete(stderr)
	}
	if exec_err != nil || !state.exited || state.exit_code != 0 || !os.exists(artifact_full_path) {
		return "", false
	}

	keep_artifact_project_path = true
	return native_artifact_project_path, true
}

build_development_odin_native_artifact :: proc(project_root_path, native_path: string) -> (string, Script_Diagnostic, bool) {
	native_artifact_project_path, artifact_path_ok := build_development_native_artifact_project_path()
	if !artifact_path_ok {
		return "", script_native_diagnostic(.Native_Build, native_path, "failed to create native artifact path"), false
	}
	keep_artifact_project_path := false
	defer {
		if !keep_artifact_project_path {
			delete(native_artifact_project_path)
		}
	}

	artifact_full_path := project_relative_path(project_root_path, native_artifact_project_path)
	defer delete(artifact_full_path)
	artifact_parent := os.dir(artifact_full_path)
	if !ensure_directory(artifact_parent) {
		return "", script_native_diagnostic(.Native_Build, native_path, "failed to create native artifact directory"), false
	}

	if !write_odin_native_sdk(project_root_path) {
		return "", script_native_diagnostic(.Native_Build, native_path, "failed to write Odin native SDK"), false
	}

	native_source_dir := os.dir(native_path)
	if native_source_dir == "" {
		native_source_dir = "."
	}
	collection_arg := build_odin_collection_arg()
	if collection_arg == "" {
		return "", script_native_diagnostic(.Native_Build, native_path, "failed to create Odin native SDK collection argument"), false
	}
	defer delete(collection_arg)
	output_arg := build_prefixed_string("-out:", native_artifact_project_path)
	if output_arg == "" {
		return "", script_native_diagnostic(.Native_Build, native_path, "failed to create Odin native artifact output argument"), false
	}
	defer delete(output_arg)
	command := []string{
		"odin",
		"build",
		native_source_dir,
		"-build-mode:dll",
		output_arg,
		collection_arg,
	}
	state, stdout, stderr, exec_err := os.process_exec(os.Process_Desc{
		working_dir = project_root_path,
		command = command,
	}, context.allocator)
	defer {
		if stdout != nil {
			delete(stdout)
		}
		if stderr != nil {
			delete(stderr)
		}
	}
	if exec_err != nil || !state.exited || state.exit_code != 0 || !os.exists(artifact_full_path) {
		return "", native_build_diagnostic(native_path, stdout, stderr, exec_err != nil), false
	}

	keep_artifact_project_path = true
	return native_artifact_project_path, Script_Diagnostic{}, true
}

build_native_artifact_project_path :: proc() -> (string, bool) {
	path, err := filepath.join([]string{BUILD_NATIVE_ARTIFACT_DIR, dynamic_library_file_name()})
	if err != nil {
		return "", false
	}
	return path, true
}

build_development_native_artifact_project_path :: proc() -> (string, bool) {
	stamp_buffer: [32]byte
	stamp := strconv.write_int(stamp_buffer[:], time.to_unix_nanoseconds(time.now()), 10)
	path, err := filepath.join([]string{BUILD_NATIVE_ARTIFACT_DIR, "dev", stamp, dynamic_library_file_name()})
	if err != nil {
		return "", false
	}
	return path, true
}

native_build_diagnostic :: proc(native_path: string, stdout, stderr: []byte, exec_failed: bool) -> Script_Diagnostic {
	detail := strings.trim_space(string(stderr))
	if detail == "" {
		detail = strings.trim_space(string(stdout))
	}
	if detail == "" {
		if exec_failed {
			detail = "failed to execute Odin compiler"
		} else {
			detail = "Odin compiler did not produce a native artifact"
		}
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	strings.write_string(&builder, "failed to build Odin native module")
	if detail != "" {
		strings.write_string(&builder, ": ")
		strings.write_string(&builder, detail)
	}
	return script_native_diagnostic(.Native_Build, native_path, strings.to_string(builder))
}

build_odin_collection_arg :: proc() -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	strings.write_string(&builder, "-collection:")
	strings.write_string(&builder, BUILD_ODIN_NATIVE_COLLECTION)
	strings.write_rune(&builder, '=')
	strings.write_string(&builder, BUILD_ODIN_NATIVE_SDK_DIR)
	return strings.clone(strings.to_string(builder))
}

build_prefixed_string :: proc(prefix, value: string) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	strings.write_string(&builder, prefix)
	strings.write_string(&builder, value)
	return strings.clone(strings.to_string(builder))
}

dynamic_library_file_name :: proc() -> string {
	when ODIN_OS == .Windows {
		return "scrapbot_project.dll"
	}
	when ODIN_OS == .Darwin {
		return "libscrapbot_project.dylib"
	}
	return "libscrapbot_project.so"
}

write_odin_native_sdk :: proc(project_bundle_path: string) -> bool {
	sdk_package_path, sdk_package_err := filepath.join([]string{project_bundle_path, BUILD_ODIN_NATIVE_SDK_DIR, "scrapbot_native"})
	if sdk_package_err != nil {
		return false
	}
	defer delete(sdk_package_path)
	if !ensure_directory(sdk_package_path) {
		return false
	}
	sdk_file_path, sdk_file_err := filepath.join([]string{sdk_package_path, "scrapbot_native.odin"})
	if sdk_file_err != nil {
		return false
	}
	defer delete(sdk_file_path)
	return os.write_entire_file(sdk_file_path, ODIN_NATIVE_SDK_SOURCE) == nil
}

rewrite_packaged_project_manifest :: proc(project_bundle_path, native_artifact_path: string) -> bool {
	metadata_name := project_metadata_file_name(project_bundle_path)
	if metadata_name == "" {
		return false
	}
	metadata_path := project_relative_path(project_bundle_path, metadata_name)
	defer delete(metadata_path)
	contents, read_err := os.read_entire_file(metadata_path, context.allocator)
	if read_err != nil {
		return false
	}
	defer delete(contents)

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	remaining := string(contents)
	for line in strings.split_lines_iterator(&remaining) {
		_, has_native_artifact := read_key_value(line, "native_artifact")
		if has_native_artifact {
			continue
		}
		strings.write_string(&builder, line)
		strings.write_rune(&builder, '\n')
	}
	strings.write_string(&builder, `native_artifact = "`)
	write_toml_basic_string_contents(&builder, native_artifact_path)
	strings.write_string(&builder, "\"\n")
	return os.write_entire_file(metadata_path, strings.to_string(builder)) == nil
}

executable_file_name :: proc() -> string {
	when ODIN_OS == .Windows {
		return "scrapbot.exe"
	}
	return "scrapbot"
}

launcher_file_name :: proc() -> string {
	when ODIN_OS == .Windows {
		return "run.cmd"
	}
	return "run"
}

write_launcher :: proc(path: string) -> bool {
	when ODIN_OS == .Windows {
		return os.write_entire_file(path, "@echo off\r\nset \"SCRIPT_DIR=%~dp0\"\r\nset \"PATH=%SCRIPT_DIR%lib;%SCRIPT_DIR%bin;%PATH%\"\r\n\"%SCRIPT_DIR%bin\\scrapbot.exe\" run \"%SCRIPT_DIR%project\" %*\r\n") == nil
	}
	when ODIN_OS == .Darwin {
		return os.write_entire_file(path, "#!/bin/sh\nset -eu\nDIR=\"$(CDPATH= cd -- \"$(dirname -- \"$0\")\" && pwd)\"\nexport DYLD_LIBRARY_PATH=\"$DIR/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}\"\nexec \"$DIR/bin/scrapbot\" run \"$DIR/project\" \"$@\"\n", os.Permissions_Read_All + os.Permissions_Write_All + os.Permissions_Execute_All) == nil
	}
	when ODIN_OS == .Linux {
		return os.write_entire_file(path, "#!/bin/sh\nset -eu\nDIR=\"$(CDPATH= cd -- \"$(dirname -- \"$0\")\" && pwd)\"\nexport LD_LIBRARY_PATH=\"$DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}\"\nexec \"$DIR/bin/scrapbot\" run \"$DIR/project\" \"$@\"\n", os.Permissions_Read_All + os.Permissions_Write_All + os.Permissions_Execute_All) == nil
	}
	ok := os.write_entire_file(path, "#!/bin/sh\nset -eu\nDIR=\"$(CDPATH= cd -- \"$(dirname -- \"$0\")\" && pwd)\"\nexec \"$DIR/bin/scrapbot\" run \"$DIR/project\" \"$@\"\n", os.Permissions_Read_All + os.Permissions_Write_All + os.Permissions_Execute_All) == nil
	return ok
}

copy_discoverable_sdl3 :: proc(lib_path: string) -> bool {
	when ODIN_OS == .Darwin {
		candidates := [?]string{
			"/opt/homebrew/opt/sdl3/lib/libSDL3.0.dylib",
			"/opt/homebrew/opt/sdl3/lib/libSDL3.dylib",
			"/opt/homebrew/lib/libSDL3.0.dylib",
			"/opt/homebrew/lib/libSDL3.dylib",
			"/usr/local/opt/sdl3/lib/libSDL3.0.dylib",
			"/usr/local/opt/sdl3/lib/libSDL3.dylib",
			"/usr/local/lib/libSDL3.0.dylib",
			"/usr/local/lib/libSDL3.dylib",
		}
		return copy_discoverable_sdl3_from_candidates(lib_path, candidates[:])
	}
	when ODIN_OS == .Linux {
		candidates := [?]string{
			"/usr/lib/libSDL3.so.0",
			"/usr/lib/libSDL3.so",
			"/usr/lib/x86_64-linux-gnu/libSDL3.so.0",
			"/usr/lib/x86_64-linux-gnu/libSDL3.so",
			"/usr/lib/aarch64-linux-gnu/libSDL3.so.0",
			"/usr/lib/aarch64-linux-gnu/libSDL3.so",
		}
		return copy_discoverable_sdl3_from_candidates(lib_path, candidates[:])
	}
	when ODIN_OS == .Windows {
		candidates := [?]string{"SDL3.dll"}
		return copy_discoverable_sdl3_from_candidates(lib_path, candidates[:])
	}
	return false
}

copy_discoverable_sdl3_from_candidates :: proc(lib_path: string, candidates: []string) -> bool {
	copied := false
	for candidate in candidates {
		if !os.exists(candidate) {
			continue
		}
		name := filepath.base(candidate)
		if name == "" {
			continue
		}
		dest_path, dest_err := filepath.join([]string{lib_path, name})
		if dest_err != nil {
			return copied
		}
		if os.exists(dest_path) {
			os.remove(dest_path)
		}
		if os.copy_file(dest_path, candidate) == nil {
			copied = true
		}
		delete(dest_path)
	}
	return copied
}

write_build_manifest :: proc(path, project_name, bundle_path, runtime_path, project_path, native_artifact: string, sdl3_bundled: bool, sdl3_warning: string) -> bool {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	strings.write_string(&builder, "{\n")
	strings.write_string(&builder, `  "schema": "scrapbot.build.v1",` + "\n")
	strings.write_string(&builder, `  "project": "`)
	write_json_string_contents(&builder, project_name)
	strings.write_string(&builder, `",` + "\n")
	strings.write_string(&builder, `  "host": "`)
	write_json_string_contents(&builder, host_triple())
	strings.write_string(&builder, `",` + "\n")
	strings.write_string(&builder, `  "bundle_path": "`)
	write_json_string_contents(&builder, bundle_path)
	strings.write_string(&builder, `",` + "\n")
	strings.write_string(&builder, `  "runtime_path": "`)
	write_json_string_contents(&builder, runtime_path)
	strings.write_string(&builder, `",` + "\n")
	strings.write_string(&builder, `  "project_path": "`)
	write_json_string_contents(&builder, project_path)
	strings.write_string(&builder, `",` + "\n")
	strings.write_string(&builder, `  "native_artifact": `)
	if native_artifact == "" {
		strings.write_string(&builder, `null`)
	} else {
		strings.write_rune(&builder, '"')
		write_json_string_contents(&builder, native_artifact)
		strings.write_rune(&builder, '"')
	}
	strings.write_string(&builder, "," + "\n")
	if sdl3_bundled {
		strings.write_string(&builder, `  "sdl3_bundled": true,` + "\n")
	} else {
		strings.write_string(&builder, `  "sdl3_bundled": false,` + "\n")
	}
	strings.write_string(&builder, `  "sdl3_warning": `)
	if sdl3_warning == "" {
		strings.write_string(&builder, `null`)
	} else {
		strings.write_rune(&builder, '"')
		write_json_string_contents(&builder, sdl3_warning)
		strings.write_rune(&builder, '"')
	}
	strings.write_string(&builder, "\n}\n")
	return os.write_entire_file(path, strings.to_string(builder)) == nil
}

ODIN_NATIVE_SDK_SOURCE :: `package scrapbot_native

Field_Type :: enum {
    Boolean,
    Bool,
    Int,
    Float,
    String,
    Vec3,
}

Entity :: struct {
    index: u32,
    generation: u32,
}

Vec3 :: struct {
    x: f32,
    y: f32,
    z: f32,
}

Field_Value :: struct {
    name: string,
    field_type: Field_Type,
    boolean_value: bool,
    int_value: int,
    float_value: f32,
    vec3_value: Vec3,
    string_value: string,
}

System_Phase :: enum {
    Startup,
    Update,
    Fixed_Update,
    Render,
}

Component_Field :: struct {
    name: string,
    field_type: Field_Type,
}

Component_Registration :: struct {
    id: string,
    version: int,
    fields: []Component_Field,
}

System_Context :: struct {
    host_context: rawptr,
    api: ^System_Api,
    delta_seconds: f32,
    system_id: string,
}

System_Run_Proc :: proc "c" (ctx: ^System_Context) -> bool

System_Registration :: struct {
    id: string,
    phase: System_Phase,
    reads: []string,
    writes: []string,
    before: []string,
    after: []string,
    run: System_Run_Proc,
}

Register_Component_Proc :: proc "c" (ctx: rawptr, registration: ^Component_Registration) -> bool
Register_System_Proc :: proc "c" (ctx: rawptr, registration: ^System_Registration) -> bool

Register_Api :: struct {
    user_context: rawptr,
    register_component: Register_Component_Proc,
    register_system: Register_System_Proc,
}

Query_Next_Proc :: proc "c" (ctx: rawptr, component_ids: []string, cursor: ^int, out_entity: ^Entity) -> bool
Get_Int_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id, field_name: string, out_value: ^int) -> bool
Set_Int_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id, field_name: string, value: int) -> bool
Get_Float_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id, field_name: string, out_value: ^f32) -> bool
Set_Float_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id, field_name: string, value: f32) -> bool
Get_Bool_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id, field_name: string, out_value: ^bool) -> bool
Set_Bool_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id, field_name: string, value: bool) -> bool
Get_Vec3_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id, field_name: string, out_value: ^Vec3) -> bool
Set_Vec3_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id, field_name: string, value: Vec3) -> bool
Get_String_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id, field_name: string, out_value: ^string) -> bool
Set_String_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id, field_name: string, value: string) -> bool
Spawn_Entity_Proc :: proc "c" (ctx: rawptr, id, name: string, out_entity: ^Entity) -> bool
Despawn_Entity_Proc :: proc "c" (ctx: rawptr, entity: Entity) -> bool
Add_Component_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id: string, fields: []Field_Value) -> bool
Remove_Component_Proc :: proc "c" (ctx: rawptr, entity: Entity, component_id: string) -> bool

System_Api :: struct {
    query_next: Query_Next_Proc,
    get_int: Get_Int_Proc,
    set_int: Set_Int_Proc,
    get_float: Get_Float_Proc,
    set_float: Set_Float_Proc,
    get_bool: Get_Bool_Proc,
    set_bool: Set_Bool_Proc,
    get_vec3: Get_Vec3_Proc,
    set_vec3: Set_Vec3_Proc,
    get_string: Get_String_Proc,
    set_string: Set_String_Proc,
    spawn_entity: Spawn_Entity_Proc,
    despawn_entity: Despawn_Entity_Proc,
    add_component: Add_Component_Proc,
    remove_component: Remove_Component_Proc,
}

register_component :: proc "c" (api: ^Register_Api, registration: Component_Registration) -> bool {
    if api == nil || api.register_component == nil {
        return false
    }
    local_registration := registration
    return api.register_component(api.user_context, &local_registration)
}

register_system :: proc "c" (api: ^Register_Api, registration: System_Registration) -> bool {
    if api == nil || api.register_system == nil {
        return false
    }
    local_registration := registration
    return api.register_system(api.user_context, &local_registration)
}

query_next :: proc "c" (ctx: ^System_Context, component_ids: []string, cursor: ^int) -> (Entity, bool) {
    if ctx == nil || ctx.api == nil || ctx.api.query_next == nil {
        return {}, false
    }
    entity: Entity
    ok := ctx.api.query_next(ctx.host_context, component_ids, cursor, &entity)
    return entity, ok
}

get_int :: proc "c" (ctx: ^System_Context, entity: Entity, component_id, field_name: string) -> (int, bool) {
    if ctx == nil || ctx.api == nil || ctx.api.get_int == nil {
        return 0, false
    }
    value: int
    ok := ctx.api.get_int(ctx.host_context, entity, component_id, field_name, &value)
    return value, ok
}

set_int :: proc "c" (ctx: ^System_Context, entity: Entity, component_id, field_name: string, value: int) -> bool {
    if ctx == nil || ctx.api == nil || ctx.api.set_int == nil {
        return false
    }
    return ctx.api.set_int(ctx.host_context, entity, component_id, field_name, value)
}

get_float :: proc "c" (ctx: ^System_Context, entity: Entity, component_id, field_name: string) -> (f32, bool) {
    if ctx == nil || ctx.api == nil || ctx.api.get_float == nil {
        return 0, false
    }
    value: f32
    ok := ctx.api.get_float(ctx.host_context, entity, component_id, field_name, &value)
    return value, ok
}

set_float :: proc "c" (ctx: ^System_Context, entity: Entity, component_id, field_name: string, value: f32) -> bool {
    if ctx == nil || ctx.api == nil || ctx.api.set_float == nil {
        return false
    }
    return ctx.api.set_float(ctx.host_context, entity, component_id, field_name, value)
}

get_bool :: proc "c" (ctx: ^System_Context, entity: Entity, component_id, field_name: string) -> (bool, bool) {
    if ctx == nil || ctx.api == nil || ctx.api.get_bool == nil {
        return false, false
    }
    value: bool
    ok := ctx.api.get_bool(ctx.host_context, entity, component_id, field_name, &value)
    return value, ok
}

set_bool :: proc "c" (ctx: ^System_Context, entity: Entity, component_id, field_name: string, value: bool) -> bool {
    if ctx == nil || ctx.api == nil || ctx.api.set_bool == nil {
        return false
    }
    return ctx.api.set_bool(ctx.host_context, entity, component_id, field_name, value)
}

get_vec3 :: proc "c" (ctx: ^System_Context, entity: Entity, component_id, field_name: string) -> (Vec3, bool) {
    if ctx == nil || ctx.api == nil || ctx.api.get_vec3 == nil {
        return {}, false
    }
    value: Vec3
    ok := ctx.api.get_vec3(ctx.host_context, entity, component_id, field_name, &value)
    return value, ok
}

set_vec3 :: proc "c" (ctx: ^System_Context, entity: Entity, component_id, field_name: string, value: Vec3) -> bool {
    if ctx == nil || ctx.api == nil || ctx.api.set_vec3 == nil {
        return false
    }
    return ctx.api.set_vec3(ctx.host_context, entity, component_id, field_name, value)
}

get_string :: proc "c" (ctx: ^System_Context, entity: Entity, component_id, field_name: string) -> (string, bool) {
    if ctx == nil || ctx.api == nil || ctx.api.get_string == nil {
        return "", false
    }
    value: string
    ok := ctx.api.get_string(ctx.host_context, entity, component_id, field_name, &value)
    return value, ok
}

set_string :: proc "c" (ctx: ^System_Context, entity: Entity, component_id, field_name: string, value: string) -> bool {
    if ctx == nil || ctx.api == nil || ctx.api.set_string == nil {
        return false
    }
    return ctx.api.set_string(ctx.host_context, entity, component_id, field_name, value)
}

spawn_entity :: proc "c" (ctx: ^System_Context, id, name: string) -> (Entity, bool) {
    if ctx == nil || ctx.api == nil || ctx.api.spawn_entity == nil {
        return {}, false
    }
    entity: Entity
    ok := ctx.api.spawn_entity(ctx.host_context, id, name, &entity)
    return entity, ok
}

despawn_entity :: proc "c" (ctx: ^System_Context, entity: Entity) -> bool {
    if ctx == nil || ctx.api == nil || ctx.api.despawn_entity == nil {
        return false
    }
    return ctx.api.despawn_entity(ctx.host_context, entity)
}

add_component :: proc "c" (ctx: ^System_Context, entity: Entity, component_id: string, fields: []Field_Value) -> bool {
    if ctx == nil || ctx.api == nil || ctx.api.add_component == nil {
        return false
    }
    return ctx.api.add_component(ctx.host_context, entity, component_id, fields)
}

remove_component :: proc "c" (ctx: ^System_Context, entity: Entity, component_id: string) -> bool {
    if ctx == nil || ctx.api == nil || ctx.api.remove_component == nil {
        return false
    }
    return ctx.api.remove_component(ctx.host_context, entity, component_id)
}

field_bool :: proc "c" (name: string, value: bool) -> Field_Value {
    return Field_Value{name = name, field_type = .Bool, boolean_value = value}
}

field_int :: proc "c" (name: string, value: int) -> Field_Value {
    return Field_Value{name = name, field_type = .Int, int_value = value}
}

field_float :: proc "c" (name: string, value: f32) -> Field_Value {
    return Field_Value{name = name, field_type = .Float, float_value = value}
}

field_vec3 :: proc "c" (name: string, value: Vec3) -> Field_Value {
    return Field_Value{name = name, field_type = .Vec3, vec3_value = value}
}

field_string :: proc "c" (name: string, value: string) -> Field_Value {
    return Field_Value{name = name, field_type = .String, string_value = value}
}
`

write_json_string_contents :: proc(builder: ^strings.Builder, value: string) {
	for c in value {
		switch c {
		case '"':
			strings.write_string(builder, `\"`)
		case '\\':
			strings.write_string(builder, `\\`)
		case '\n':
			strings.write_string(builder, `\n`)
		case '\r':
			strings.write_string(builder, `\r`)
		case '\t':
			strings.write_string(builder, `\t`)
		case:
			strings.write_rune(builder, c)
		}
	}
}
