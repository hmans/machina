package scrapbot

import ecs "./ecs"
import project "./project"
import shared "./shared"
import "core:fmt"
import "core:os"
import "core:strings"

scene_has_structural_changes :: proc(
	world: ^shared.World,
	baseline: ^shared.Scene,
	dirty_entities: []shared.Entity_UUID,
) -> bool {
	for id in dirty_entities {
		baseline_entity, baseline_found := scene_entity_by_uuid(baseline, id)
		entity_index, current_found := ecs.entity_index_by_uuid(world, id)
		if baseline_found != current_found {
			return true
		}
		if !baseline_found {
			continue
		}
		current := world.entities[entity_index]
		if current.origin != .Scene ||
		   scene_entity_structure_differs(baseline_entity, world, entity_index) {
			return true
		}
	}
	return false
}

scene_entity_structure_differs :: proc(
	baseline: ^shared.Scene_Entity,
	world: ^shared.World,
	entity_index: int,
) -> bool {
	snapshot, ok := ecs.capture_entity_snapshot(world, entity_index)
	if !ok {
		return true
	}
	defer ecs.destroy_entity_snapshot(&snapshot)
	current := &snapshot.entity
	if baseline.name != current.name ||
	   baseline.has_transform != current.has_transform ||
	   baseline.has_camera != current.has_camera ||
	   baseline.has_ambient_light != current.has_ambient_light ||
	   baseline.has_directional_light != current.has_directional_light ||
	   baseline.has_point_light != current.has_point_light ||
	   baseline.has_mesh != current.has_mesh ||
	   baseline.has_geometry != current.has_geometry ||
	   baseline.has_material != current.has_material ||
	   baseline.has_shadow_caster != current.has_shadow_caster ||
	   baseline.has_shadow_receiver != current.has_shadow_receiver ||
	   baseline.has_ui_layout != current.has_ui_layout ||
	   baseline.has_ui_hstack != current.has_ui_hstack ||
	   baseline.has_ui_vstack != current.has_ui_vstack ||
	   baseline.has_ui_scroll_area != current.has_ui_scroll_area ||
	   baseline.has_ui_panel != current.has_ui_panel ||
	   baseline.has_ui_table != current.has_ui_table ||
	   baseline.has_ui_list != current.has_ui_list ||
	   baseline.has_ui_progress != current.has_ui_progress ||
	   baseline.has_ui_text != current.has_ui_text ||
	   baseline.has_ui_button != current.has_ui_button ||
	   baseline.has_ui_input != current.has_ui_input ||
	   baseline.has_ui_checkbox != current.has_ui_checkbox ||
	   len(baseline.custom_components) != len(current.custom_components) {
		return true
	}
	for component in baseline.custom_components {
		found := false
		for candidate in current.custom_components {
			if candidate.name == component.name {
				found = true
				break
			}
		}
		if !found {
			return true
		}
	}
	return false
}

save_scene_world_structural :: proc(
	scene_path, source: string,
	world: ^shared.World,
	baseline: ^shared.Scene,
	dirty: map[shared.Entity_UUID]bool,
	dirty_order: []shared.Entity_UUID,
) -> string {
	headers: [dynamic]int
	defer delete(headers)
	find_scene_entity_headers(source, &headers)
	if len(headers) != len(baseline.entities) {
		return "scene entity blocks no longer match the parsed scene"
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	preamble_end := len(source)
	if len(headers) > 0 { preamble_end = headers[0] }
	strings.write_string(&builder, source[:preamble_end])
	baseline_lookup := make(map[shared.Entity_UUID]bool, len(baseline.entities))
	defer delete(baseline_lookup)
	for entity, ordinal in baseline.entities {
		baseline_lookup[entity.id] = true
		start := headers[ordinal]
		end := len(source)
		if ordinal + 1 < len(headers) { end = headers[ordinal + 1] }
		if !dirty[entity.id] {
			strings.write_string(&builder, source[start:end])
			continue
		}
		entity_index, found := ecs.entity_index_by_uuid(world, entity.id)
		if !found || world.entities[entity_index].origin != .Scene {
			continue
		}
		_ = write_scene_world_entity(&builder, world, entity_index)
		strings.write_rune(&builder, '\n')
	}
	appending_started := false
	for id in dirty_order {
		if baseline_lookup[id] {
			continue
		}
		entity_index, found := ecs.entity_index_by_uuid(world, id)
		if !found || world.entities[entity_index].origin != .Scene {
			continue
		}
		if !appending_started && strings.builder_len(builder) > 0 {
			strings.write_rune(&builder, '\n')
		}
		appending_started = true
		_ = write_scene_world_entity(&builder, world, entity_index)
		strings.write_rune(&builder, '\n')
	}
	return write_scene_atomically(scene_path, strings.to_string(builder))
}

find_scene_entity_headers :: proc(source: string, headers: ^[dynamic]int) {
	line_start := 0
	for cursor := 0; cursor <= len(source); cursor += 1 {
		if cursor < len(source) && source[cursor] != '\n' {
			continue
		}
		line := source[line_start:cursor]
		clean := project.strip_comment(strings.trim_space(line))
		if clean == "[[entities]]" {
			append(headers, line_start)
		}
		line_start = cursor + 1
	}
}

write_scene_atomically :: proc(scene_path, source: string) -> string {
	temp_path, clone_err := strings.concatenate({scene_path, ".scrapbot-save.tmp"})
	if clone_err != nil {
		return "failed to allocate temporary scene path"
	}
	defer delete(temp_path)
	defer os.remove(temp_path)
	if write_err := os.write_entire_file(temp_path, source); write_err != nil {
		return fmt.tprintf("failed to write temporary scene: %v", write_err)
	}
	if rename_err := os.rename(temp_path, scene_path); rename_err != nil {
		return fmt.tprintf("failed to replace scene file: %v", rename_err)
	}
	return ""
}

scene_entity_by_uuid :: proc(
	scene: ^shared.Scene,
	id: shared.Entity_UUID,
) -> (
	^shared.Scene_Entity,
	bool,
) {
	if scene == nil {
		return nil, false
	}
	for &entity in scene.entities {
		if entity.id == id {
			return &entity, true
		}
	}
	return nil, false
}
