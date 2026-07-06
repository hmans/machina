package main

import "core:os"
import "core:testing"

@(test)
test_run_init_command_creates_checkable_project :: proc(t: ^testing.T) {
	root := make_test_project_root(t, "cli-init-project")
	defer os.remove_all(root)
	defer delete(root)

	exit_code := run_with_output([]string{"scrapbot", "init", root}, false)
	testing.expect_value(t, exit_code, 0)

	result := check_project(root)
	defer free_check_result(result)
	testing.expect_value(t, result.err, Project_Error.None)
	testing.expect_value(t, result.project.name, "cli-init-project")
}

@(test)
test_run_init_command_rejects_extra_arguments :: proc(t: ^testing.T) {
	root := make_test_project_root(t, "cli-init-extra")
	defer os.remove_all(root)
	defer delete(root)

	exit_code := run_with_output([]string{"scrapbot", "init", root, "extra"}, false)
	testing.expect_value(t, exit_code, 1)
	testing.expect_value(t, os.exists(root), false)
}
