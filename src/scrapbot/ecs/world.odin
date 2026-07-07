package ecs

import "core:math"
import shared "../shared"

Scene :: shared.Scene
World :: shared.World
World_Entity :: shared.World_Entity
Entity :: shared.Entity
Render_Frame :: shared.Render_Frame
Renderable :: shared.Renderable
Render_Instance :: shared.Render_Instance
Camera_Instance :: shared.Camera_Instance

CUBE_ROTATION_SPEED_RADIANS_PER_SECOND :: f32(math.PI / 2)
INVALID_COMPONENT_INDEX :: -1

destroy_world :: proc(world: ^World) {
	delete(world.entities)
	delete(world.transforms)
	delete(world.cameras)
	delete(world.meshes)
	delete(world.renderables)
	world^ = {}
}

build_world :: proc(scene: ^Scene) -> World {
	world: World
	for entity in scene.entities {
		id := Entity{index = u32(len(world.entities)), generation = 1}
		world_entity := World_Entity {
			id              = id,
			name            = entity.name,
			transform_index = INVALID_COMPONENT_INDEX,
			camera_index    = INVALID_COMPONENT_INDEX,
			mesh_index      = INVALID_COMPONENT_INDEX,
		}

		if entity.has_transform {
			world_entity.transform_index = len(world.transforms)
			append_soa(&world.transforms, entity.transform)
		}
		if entity.has_camera {
			world_entity.camera_index = len(world.cameras)
			append(&world.cameras, entity.camera)
		}
		if entity.has_mesh {
			world_entity.mesh_index = len(world.meshes)
			append(&world.meshes, entity.mesh)
		}

		append(&world.entities, world_entity)
		if world_entity.transform_index != INVALID_COMPONENT_INDEX &&
		   world_entity.mesh_index != INVALID_COMPONENT_INDEX {
			append(
				&world.renderables,
				Renderable {
					entity_index    = int(id.index),
					transform_index = world_entity.transform_index,
					mesh_index      = world_entity.mesh_index,
				},
			)
		}
	}
	return world
}

render_frame_from_world :: proc(world: ^World) -> Render_Frame {
	return Render_Frame {
		entity_count     = len(world.entities),
		camera_count     = len(world.cameras),
		mesh_count       = len(world.meshes),
		renderable_count = len(world.renderables),
	}
}

step_world :: proc(world: ^World, delta_seconds: f32) {
	for renderable in world.renderables {
		if renderable.transform_index < 0 || renderable.transform_index >= len(world.transforms) {
			continue
		}
		if renderable.mesh_index < 0 || renderable.mesh_index >= len(world.meshes) {
			continue
		}

		mesh := world.meshes[renderable.mesh_index]
		if mesh.primitive != "cube" {
			continue
		}

		transform := world.transforms[renderable.transform_index]
		transform.rotation.y = wrap_radians(transform.rotation.y + CUBE_ROTATION_SPEED_RADIANS_PER_SECOND * delta_seconds)
		world.transforms[renderable.transform_index] = transform
	}
}

first_render_instance :: proc(world: ^World) -> (instance: Render_Instance, ok: bool) {
	for renderable in world.renderables {
		if renderable.entity_index < 0 || renderable.entity_index >= len(world.entities) {
			continue
		}
		if renderable.transform_index < 0 || renderable.transform_index >= len(world.transforms) {
			continue
		}
		if renderable.mesh_index < 0 || renderable.mesh_index >= len(world.meshes) {
			continue
		}

		mesh := world.meshes[renderable.mesh_index]
		if mesh.primitive != "cube" {
			continue
		}

		return Render_Instance {
			entity    = world.entities[renderable.entity_index],
			transform = world.transforms[renderable.transform_index],
			mesh      = mesh,
		}, true
	}
	return {}, false
}

first_camera_instance :: proc(world: ^World) -> (instance: Camera_Instance, ok: bool) {
	for entity in world.entities {
		if entity.camera_index < 0 || entity.camera_index >= len(world.cameras) {
			continue
		}
		if entity.transform_index < 0 || entity.transform_index >= len(world.transforms) {
			continue
		}

		return Camera_Instance {
			entity    = entity,
			transform = world.transforms[entity.transform_index],
			camera    = world.cameras[entity.camera_index],
		}, true
	}
	return {}, false
}

wrap_radians :: proc(value: f32) -> f32 {
	full_turn := f32(2 * math.PI)
	wrapped := value
	for wrapped >= full_turn {
		wrapped -= full_turn
	}
	for wrapped < 0 {
		wrapped += full_turn
	}
	return wrapped
}
