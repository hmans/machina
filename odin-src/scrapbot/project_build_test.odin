package main

import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

@(test)
test_build_project_creates_host_bundle :: proc(t: ^testing.T) {
	root := make_test_project_root(t, "build-project-source")
	defer os.remove_all(root)
	defer delete(root)
	output_root := make_test_project_root(t, "build-project-output")
	defer os.remove_all(output_root)
	defer delete(output_root)

	testing.expect_value(t, init_project(root, "Bundle Game"), Project_Error.None)
	extra_path := project_relative_path(root, "assets/data.txt")
	defer delete(extra_path)
	testing.expect_value(t, os.write_entire_file(extra_path, "asset data"), nil)

	result, err := build_project(Build_Options{
		target_path = root,
		output_root = output_root,
		name = "bundle-game",
	})
	defer free_build_result(result)
	testing.expect_value(t, err, Project_Error.None)

	marker_path := join_test_path(t, result.bundle_path, BUILD_BUNDLE_MARKER)
	defer delete(marker_path)
	runtime_path := result.runtime_path
	launcher_path := result.launcher_path
	manifest_path := join_test_path(t, result.bundle_path, BUILD_MANIFEST_PATH)
	defer delete(manifest_path)
	copied_asset_path := join_test_path(t, result.project_path, "assets/data.txt")
	defer delete(copied_asset_path)

	testing.expect_value(t, os.exists(marker_path), true)
	testing.expect_value(t, os.exists(runtime_path), true)
	testing.expect_value(t, os.exists(launcher_path), true)
	testing.expect_value(t, os.exists(manifest_path), true)
	testing.expect_value(t, os.exists(copied_asset_path), true)

	packaged := check_project(result.project_path)
	defer free_check_result(packaged)
	testing.expect_value(t, packaged.err, Project_Error.None)
	testing.expect_value(t, packaged.project.name, "Bundle Game")

	manifest, read_err := os.read_entire_file(manifest_path, context.allocator)
	testing.expect_value(t, read_err, nil)
	defer delete(manifest)
	testing.expect(t, strings.contains(string(manifest), `"schema": "scrapbot.build.v1"`))
	testing.expect(t, strings.contains(string(manifest), `"native_artifact": null`))
	testing.expect(t, strings.contains(string(manifest), `"sdl3_bundled": false`))
}

@(test)
test_build_project_default_output_skips_project_build_tree :: proc(t: ^testing.T) {
	root := make_test_project_root(t, "build-default-output")
	defer os.remove_all(root)
	defer delete(root)

	testing.expect_value(t, init_project(root, "Default Build"), Project_Error.None)
	generated_root := project_relative_path(root, BUILD_DEFAULT_OUTPUT_DIR)
	defer delete(generated_root)
	testing.expect_value(t, ensure_directory(generated_root), true)
	should_skip := project_relative_path(root, "build/old.txt")
	defer delete(should_skip)
	testing.expect_value(t, os.write_entire_file(should_skip, "old"), nil)

	result, err := build_project(Build_Options{target_path = root, name = "default-build"})
	defer free_build_result(result)
	testing.expect_value(t, err, Project_Error.None)

	copied_build_tree := join_test_path(t, result.project_path, BUILD_DEFAULT_OUTPUT_DIR)
	defer delete(copied_build_tree)
	testing.expect_value(t, os.exists(copied_build_tree), false)
}

@(test)
test_build_project_requires_force_for_existing_bundle :: proc(t: ^testing.T) {
	root := make_test_project_root(t, "build-existing-source")
	defer os.remove_all(root)
	defer delete(root)
	output_root := make_test_project_root(t, "build-existing-output")
	defer os.remove_all(output_root)
	defer delete(output_root)

	testing.expect_value(t, init_project(root, "Existing Build"), Project_Error.None)

	first, first_err := build_project(Build_Options{target_path = root, output_root = output_root, name = "existing"})
	free_build_result(first)
	testing.expect_value(t, first_err, Project_Error.None)
	second, second_err := build_project(Build_Options{target_path = root, output_root = output_root, name = "existing"})
	free_build_result(second)
	testing.expect_value(t, second_err, Project_Error.Already_Exists)
	third, third_err := build_project(Build_Options{target_path = root, output_root = output_root, name = "existing", force = true})
	defer free_build_result(third)
	testing.expect_value(t, third_err, Project_Error.None)
}

@(test)
test_build_project_rejects_nested_in_project_output_root :: proc(t: ^testing.T) {
	root := make_test_project_root(t, "build-nested-output")
	defer os.remove_all(root)
	defer delete(root)

	testing.expect_value(t, init_project(root, "Nested Output"), Project_Error.None)
	nested_output := project_relative_path(root, "assets/build")
	defer delete(nested_output)

	result, err := build_project(Build_Options{target_path = root, output_root = nested_output, name = "nested"})
	free_build_result(result)
	testing.expect_value(t, err, Project_Error.Invalid_Build_Output)
}

join_test_path :: proc(t: ^testing.T, left, right: string) -> string {
	joined, err := filepath.join([]string{left, right})
	if err != nil {
		testing.fail_now(t, "failed to join path")
	}
	return joined
}
