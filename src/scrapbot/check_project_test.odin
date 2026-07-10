package scrapbot

import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

@(test)
test_check_project_refreshes_luau_types_from_script_registry :: proc(t: ^testing.T) {
	root, parent := make_check_project_test_project(t)
	defer delete(root)
	defer os.remove_all(parent)

	types_path := join_check_project_path(t, root, DEFAULT_LUAU_TYPES)
	defer delete(types_path)
	write_err := os.write_entire_file(types_path, "-- stale\n")
	testing.expect(t, write_err == nil)

	check_err := check_project(root)
	testing.expect(t, check_err == "")

	types_bytes, read_err := os.read_entire_file(types_path, context.temp_allocator)
	testing.expect(t, read_err == nil)
	types_text := string(types_bytes)
	testing.expect(t, strings.contains(types_text, "export type Autorotate = {"))
	testing.expect(t, strings.contains(types_text, "\tvelocity: Vec3,"))
	testing.expect(t, strings.contains(types_text, "export type AutorotateComponent = ScrapbotComponent<Autorotate>"))
}

@(test)
test_check_project_validates_project_level_components_with_script_registry :: proc(t: ^testing.T) {
	root, parent := make_check_project_test_project(t)
	defer delete(root)
	defer os.remove_all(parent)

	script_path := join_check_project_path(t, root, DEFAULT_SCRIPT)
	defer delete(script_path)
	write_err := os.write_entire_file(script_path, `scrapbot.log("no component schema")`)
	testing.expect(t, write_err == nil)

	check_err := check_project(root)
	testing.expect(
		t,
		check_err == `scene component "autorotate" is not defined by scripts/main.luau; add scrapbot.component("autorotate", schema)`,
	)
}

make_check_project_test_project :: proc(t: ^testing.T) -> (string, string) {
	parent, temp_err := os.make_directory_temp("", "scrapbot-check-*", context.temp_allocator)
	if !testing.expect(t, temp_err == nil) {
		testing.fail_now(t)
	}

	root, join_err := filepath.join({parent, "project"})
	if !testing.expect(t, join_err == nil) {
		testing.fail_now(t)
	}

	init_err := init_project(root, "Check Test")
	if !testing.expectf(t, init_err == "", "init_project failed: %s", init_err) {
		testing.fail_now(t)
	}
	return root, parent
}

join_check_project_path :: proc(t: ^testing.T, root, path: string) -> string {
	out, join_err := filepath.join({root, path})
	testing.expect(t, join_err == nil)
	return out
}
