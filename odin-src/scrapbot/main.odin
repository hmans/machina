package main

import "core:fmt"
import "core:os"
import "core:strings"

VERSION :: "0.0.0-odin-migration"

main :: proc() {
	exit_code := run(os.args)
	if exit_code != 0 {
		os.exit(exit_code)
	}
}

run :: proc(args: []string) -> int {
	return run_with_output(args, true)
}

run_with_output :: proc(args: []string, emit_output: bool) -> int {
	if len(args) <= 1 {
		if emit_output {
			print_help()
		}
		return 0
	}

	command := args[1]
	if command == "--version" {
		fmt.println(VERSION)
		return 0
	}
	if command == "help" || command == "--help" {
		if emit_output {
			print_help()
		}
		return 0
	}
	if command == "check" {
		return run_check(args[2:])
	}
	if command == "init" {
		return run_init(args[2:], emit_output)
	}
	if command == "build" {
		return run_build(args[2:], emit_output)
	}

	if emit_output {
		fmt.eprintf("unknown command: %s\n", command)
		print_help()
	}
	return 1
}

print_help :: proc() {
	fmt.println(`scrapbot - agent-native game engine

Usage:
  scrapbot --version
  scrapbot help
  scrapbot init [path]
  scrapbot check [path] [--format text|json]
  scrapbot build [path] [--output DIR] [--name NAME] [--force] [--format text|json]

Odin migration status:
  init, check, and build currently cover text project creation, validation, and packaging slices.
  Runtime run loops, scripting execution, rendering, editor, and test execution are still being ported.`)
}

run_init :: proc(args: []string, emit_output: bool) -> int {
	target_path := "."
	if len(args) > 1 {
		if emit_output {
			fmt.eprintln("unknown argument")
		}
		return 1
	}
	if len(args) == 1 {
		target_path = args[0]
	}

	name := project_name_from_path(target_path)
	err := init_project(target_path, name)
	if err != .None {
		if emit_output {
			fmt.eprintf("init failed: %s: %s\n", target_path, project_error_message(err))
		}
		return 1
	}

	if emit_output {
		fmt.printf("Initialized Scrapbot project at %s\n", target_path)
	}
	return 0
}

run_build :: proc(args: []string, emit_output: bool) -> int {
	options := Build_Options{target_path = "."}
	format: Check_Output_Format = .Text

	i := 0
	for i < len(args) {
		arg := args[i]
		if arg == "--force" {
			options.force = true
			i += 1
			continue
		}
		if strings.has_prefix(arg, "--output=") {
			options.output_root = arg[len("--output="):]
			i += 1
			continue
		}
		if arg == "--output" {
			if i + 1 >= len(args) {
				if emit_output {
					fmt.eprintln("missing value for --output")
				}
				return 1
			}
			options.output_root = args[i + 1]
			i += 2
			continue
		}
		if strings.has_prefix(arg, "--name=") {
			options.name = arg[len("--name="):]
			i += 1
			continue
		}
		if arg == "--name" {
			if i + 1 >= len(args) {
				if emit_output {
					fmt.eprintln("missing value for --name")
				}
				return 1
			}
			options.name = args[i + 1]
			i += 2
			continue
		}
		if strings.has_prefix(arg, "--format=") {
			parsed, ok := parse_output_format(arg[len("--format="):])
			if !ok {
				if emit_output {
					fmt.eprintf("invalid --format: %s\n", arg[len("--format="):])
				}
				return 1
			}
			format = parsed
			i += 1
			continue
		}
		if arg == "--format" {
			if i + 1 >= len(args) {
				if emit_output {
					fmt.eprintln("missing value for --format")
				}
				return 1
			}
			parsed, ok := parse_output_format(args[i + 1])
			if !ok {
				if emit_output {
					fmt.eprintf("invalid --format: %s\n", args[i + 1])
				}
				return 1
			}
			format = parsed
			i += 2
			continue
		}
		if len(arg) > 0 && arg[0] == '-' {
			if emit_output {
				fmt.eprintf("unknown argument: %s\n", arg)
			}
			return 1
		}
		if options.target_path != "." {
			if emit_output {
				fmt.eprintf("unexpected argument: %s\n", arg)
			}
			return 1
		}
		options.target_path = arg
		i += 1
	}

	result, err := build_project(options)
	if err != .None {
		if emit_output {
			print_build_error(err, options.target_path, format)
		}
		return 1
	}
	defer free_build_result(result)

	if emit_output {
		print_build_result(result, format)
	}
	return 0
}

run_check :: proc(args: []string) -> int {
	target_path := "."
	format: Check_Output_Format = .Text

	i := 0
	for i < len(args) {
		arg := args[i]
		if arg == "--format" {
			if i + 1 >= len(args) {
				fmt.eprintln("missing value for --format")
				return 1
			}
			switch args[i + 1] {
			case "text":
				format = .Text
			case "json":
				format = .JSON
			case:
				fmt.eprintf("invalid --format: %s\n", args[i + 1])
				return 1
			}
			i += 2
			continue
		}
		if len(arg) > 0 && arg[0] == '-' {
			fmt.eprintf("unknown argument: %s\n", arg)
			return 1
		}
		if target_path != "." {
			fmt.eprintf("unexpected argument: %s\n", arg)
			return 1
		}
		target_path = arg
		i += 1
	}

	result := check_project(target_path)
	defer free_project(result.project)
	if result.err != .None {
		print_check_error(result.err, target_path, format)
		return 1
	}

	project := result.project
	scene := result.scene
	switch format {
	case .Text:
		fmt.printf("Project OK: %s\n", project.name)
		fmt.printf("Default scene: %s\n", project.default_scene)
		fmt.printf("Scene: %s\n", scene.name)
		fmt.printf("Entities: %d\n", scene.entity_count)
		fmt.printf("Components: %d\n", scene.component_instance_count)
		fmt.printf("Renderable cubes: %d\n", scene.renderable_cube_count)
		fmt.printf("Scripts: %d\n", len(project.scripts))
		if project.native != "" {
			fmt.printf("Native source: %s\n", project.native)
		}
		if project.native_artifact != "" {
			fmt.printf("Native artifact: %s\n", project.native_artifact)
		}
		fmt.println("Runtime validation: pending Odin port")
	case .JSON:
		fmt.print(`{"ok":true,"project":`)
		fmt.print(`{"name":"`)
		json_print(project.name, false)
		fmt.print(`","default_scene":"`)
		json_print(project.default_scene, false)
		fmt.printf(`","scripts":%d`, len(project.scripts))
		fmt.print(`},"scene":`)
		fmt.print(`{"name":"`)
		json_print(scene.name, false)
		fmt.printf(
			`","entities":%d,"components":%d,"renderable_cubes":%d`,
			scene.entity_count,
			scene.component_instance_count,
			scene.renderable_cube_count,
		)
		fmt.println(`},"runtime_validation":"pending_odin_port"}`)
	}

	return 0
}

parse_output_format :: proc(value: string) -> (Check_Output_Format, bool) {
	switch value {
	case "text":
		return .Text, true
	case "json":
		return .JSON, true
	}
	return .Text, false
}

print_build_error :: proc(err: Project_Error, target_path: string, format: Check_Output_Format) {
	message := project_error_message(err)
	switch format {
	case .Text:
		fmt.eprintf("%s: %s\n", target_path, message)
	case .JSON:
		fmt.print(`{"ok":false,"error":"`)
		json_print(message, false)
		fmt.print(`","path":"`)
		json_print(target_path, false)
		fmt.println(`"}`)
	}
}

print_build_result :: proc(result: Build_Result, format: Check_Output_Format) {
	switch format {
	case .Text:
		fmt.printf("Build OK: %s\n", result.project_name)
		fmt.printf("Bundle: %s\n", result.bundle_path)
		fmt.printf("Project: %s\n", result.project_path)
		fmt.printf("Runtime: %s\n", result.runtime_path)
		fmt.printf("Launcher: %s\n", result.launcher_path)
		if result.sdl3_warning != "" {
			fmt.printf("Warning: %s\n", result.sdl3_warning)
		}
	case .JSON:
		fmt.print(`{"ok":true,"project":"`)
		json_print(result.project_name, false)
		fmt.print(`","bundle":"`)
		json_print(result.bundle_path, false)
		fmt.print(`","project_path":"`)
		json_print(result.project_path, false)
		fmt.print(`","runtime":"`)
		json_print(result.runtime_path, false)
		fmt.print(`","launcher":"`)
		json_print(result.launcher_path, false)
		fmt.print(`","native_artifact":null,"sdl3_bundled":false,"sdl3_warning":"`)
		json_print(result.sdl3_warning, false)
		fmt.println(`"}`)
	}
}

print_check_error :: proc(err: Project_Error, target_path: string, format: Check_Output_Format) {
	message := project_error_message(err)
	switch format {
	case .Text:
		fmt.eprintf("Project invalid: %s: %s\n", target_path, message)
	case .JSON:
		fmt.eprint(`{"ok":false,"error":"`)
		json_print(message, true)
		fmt.eprint(`","path":"`)
		json_print(target_path, true)
		fmt.eprintln(`"}`)
	}
}

json_print :: proc(value: string, stderr: bool) {
	for c in value {
		switch c {
		case '"':
			print_json_fragment(`\"`, stderr)
		case '\\':
			print_json_fragment(`\\`, stderr)
		case '\n':
			print_json_fragment(`\n`, stderr)
		case '\r':
			print_json_fragment(`\r`, stderr)
		case '\t':
			print_json_fragment(`\t`, stderr)
		case:
			if stderr {
				fmt.eprintf("%c", c)
			} else {
				fmt.printf("%c", c)
			}
		}
	}
}

print_json_fragment :: proc(fragment: string, stderr: bool) {
	if stderr {
		fmt.eprint(fragment)
	} else {
		fmt.print(fragment)
	}
}
