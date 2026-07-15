package scrapbot

import ecs "./ecs"
import script "./script"
import shared "./shared"
import "core:fmt"

Playback_Baseline_Entity :: struct {
	snapshot: ecs.Entity_Snapshot,
	component_revision: u64,
	has_geometry: bool,
	geometry: shared.Geometry_Handle,
	has_material: bool,
	material: shared.Material_Handle,
}

Playback_Baseline :: struct {
	entities: [dynamic]Playback_Baseline_Entity,
	valid: bool,
}

capture_playback_baseline :: proc(baseline: ^Playback_Baseline, world: ^shared.World) -> string {
	if baseline == nil || world == nil {
		return "cannot capture an unavailable authoring world"
	}
	next: Playback_Baseline
	for entity, entity_index in world.entities {
		if !entity.alive || entity.origin != .Scene {
			continue
		}
		snapshot, captured := ecs.capture_entity_snapshot(world, entity_index)
		if !captured {
			destroy_playback_baseline(&next)
			return fmt.tprintf("failed to capture authored entity %d", entity_index)
		}
		entry := Playback_Baseline_Entity {
			snapshot = snapshot,
			component_revision = entity.component_revision,
		}
		if entity.geometry_index >= 0 && entity.geometry_index < len(world.geometries) {
			entry.has_geometry = true
			entry.geometry = world.geometries[entity.geometry_index].handle
		}
		if entity.material_index >= 0 && entity.material_index < len(world.materials) {
			entry.has_material = true
			entry.material = world.materials[entity.material_index].handle
		}
		append(&next.entities, entry)
	}
	next.valid = true
	destroy_playback_baseline(baseline)
	baseline^ = next
	return ""
}

restore_playback_baseline :: proc(
	baseline: ^Playback_Baseline,
	runtime: ^script.Runtime,
	world: ^shared.World,
) -> string {
	if baseline == nil || !baseline.valid || runtime == nil || world == nil {
		return "cannot restore an unavailable authoring baseline"
	}
	scene: shared.Scene
	defer delete(scene.entities)
	for entry in baseline.entities {
		append(&scene.entities, entry.snapshot.entity)
	}
	next_world := ecs.build_world(&scene)
	for entry, entity_index in baseline.entities {
		if entity_index >= len(next_world.entities) {
			ecs.destroy_world(&next_world)
			return "authoring baseline restored an incomplete world"
		}
		if entry.has_geometry {
			ecs.add_geometry(&next_world, entity_index, entry.geometry)
		}
		if entry.has_material {
			ecs.add_material(&next_world, entity_index, entry.material)
		}
		next_world.entities[entity_index].component_revision = entry.component_revision
	}
	if err := script.validate_runtime_world(runtime, &next_world); err != "" {
		ecs.destroy_world(&next_world)
		return err
	}
	ecs.destroy_world(world)
	world^ = next_world
	script.bind_runtime_world(runtime, world)
	return ""
}

destroy_playback_baseline :: proc(baseline: ^Playback_Baseline) {
	if baseline == nil {
		return
	}
	for &entry in baseline.entities {
		ecs.destroy_entity_snapshot(&entry.snapshot)
	}
	delete(baseline.entities)
	baseline^ = {}
}
