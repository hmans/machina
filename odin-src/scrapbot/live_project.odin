package main

import "core:os"
import "core:time"

Source_File_Stamp :: struct {
	size:                i64,
	modification_time_ns: i64,
}

Live_Reload_Info :: struct {
	scripts_reloaded: bool,
	native_reloaded:  bool,
	entity_count:     int,
	system_count:     int,
}

Live_Reload_Result :: struct {
	changed: bool,
	info:    Live_Reload_Info,
}

Live_Project :: struct {
	check:                 Project_Check_Result,
	native_stamp:          Source_File_Stamp,
	has_native_stamp:      bool,
	last_failed_native:    Source_File_Stamp,
	has_last_failed_native: bool,
	last_diagnostic:       Script_Diagnostic,
}

live_project_init :: proc(root_path: string) -> (Live_Project, Project_Error) {
	check := check_project(root_path)
	if check.err != .None {
		return Live_Project{check = check}, check.err
	}
	stamp, has_stamp, stamp_ok := live_project_stat_native(check.project)
	if !stamp_ok {
		free_check_result(check)
		return Live_Project{}, .Missing_Native
	}
	return Live_Project{
		check = check,
		native_stamp = stamp,
		has_native_stamp = has_stamp,
	}, .None
}

live_project_free :: proc(project: ^Live_Project) {
	free_check_result(project.check)
	script_diagnostic_free(&project.last_diagnostic)
	project^ = Live_Project{}
}

live_project_poll_native_source :: proc(project: ^Live_Project) -> (Live_Reload_Result, Project_Error) {
	if !project.has_native_stamp || project.check.project.native == "" {
		return Live_Reload_Result{}, .None
	}

	next_stamp, has_stamp, stamp_ok := live_project_stat_native(project.check.project)
	if !stamp_ok || !has_stamp {
		return Live_Reload_Result{}, .Missing_Native
	}
	if source_file_stamp_equal(next_stamp, project.native_stamp) {
		return Live_Reload_Result{}, .None
	}
	if project.has_last_failed_native && source_file_stamp_equal(next_stamp, project.last_failed_native) {
		return Live_Reload_Result{}, .None
	}

	next_check := check_project(project.check.project.root_path)
	if next_check.err != .None {
		live_project_store_failed_diagnostic(project, &next_check)
		project.last_failed_native = next_stamp
		project.has_last_failed_native = true
		free_check_result(next_check)
		return Live_Reload_Result{}, next_check.err
	}

	live_project_clear_diagnostic(project)
	live_project_swap_check_preserving_scene(project, next_check)
	project.native_stamp = next_stamp
	project.has_native_stamp = true
	project.has_last_failed_native = false
	return Live_Reload_Result{
		changed = true,
		info = Live_Reload_Info{
			scripts_reloaded = true,
			native_reloaded = true,
			entity_count = runtime_world_entity_count(project.check.scene.world),
			system_count = runtime_system_schedule_system_count(project.check.update_schedule),
		},
	}, .None
}

live_project_update :: proc(project: ^Live_Project, frames: int, delta_seconds: f32) -> Simulation_Run_Result {
	return run_script_simulation(&project.check, frames, delta_seconds)
}

live_project_last_diagnostic :: proc(project: ^Live_Project) -> (Script_Diagnostic, bool) {
	return project.last_diagnostic, script_diagnostic_present(project.last_diagnostic)
}

live_project_stat_native :: proc(project: Project) -> (Source_File_Stamp, bool, bool) {
	if project.native == "" {
		return Source_File_Stamp{}, false, true
	}
	path := project_relative_path(project.root_path, project.native)
	defer delete(path)
	return source_file_stamp(path)
}

source_file_stamp :: proc(path: string) -> (Source_File_Stamp, bool, bool) {
	info, stat_err := os.stat(path, context.allocator)
	if stat_err != nil {
		return Source_File_Stamp{}, false, false
	}
	defer os.file_info_delete(info, context.allocator)
	return Source_File_Stamp{
		size = info.size,
		modification_time_ns = time.to_unix_nanoseconds(info.modification_time),
	}, true, true
}

source_file_stamp_equal :: proc(left, right: Source_File_Stamp) -> bool {
	return left.size == right.size && left.modification_time_ns == right.modification_time_ns
}

live_project_store_failed_diagnostic :: proc(project: ^Live_Project, failed: ^Project_Check_Result) {
	live_project_clear_diagnostic(project)
	project.last_diagnostic = failed.diagnostic
	failed.diagnostic = Script_Diagnostic{}
}

live_project_clear_diagnostic :: proc(project: ^Live_Project) {
	script_diagnostic_free(&project.last_diagnostic)
}

live_project_swap_check_preserving_scene :: proc(project: ^Live_Project, next_check: Project_Check_Result) {
	preserved_scene := project.check.scene
	old_check := project.check
	old_check.scene = Scene{}

	validation_scene := next_check.scene
	next := next_check
	next.scene = preserved_scene

	project.check = next
	free_scene(validation_scene)
	free_check_result(old_check)
}
