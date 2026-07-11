package ecs

import "core:strings"
import shared "../shared"

Scene :: shared.Scene
World :: shared.World
World_Entity :: shared.World_Entity
Entity :: shared.Entity
Render_Frame :: shared.Render_Frame
Renderable :: shared.Renderable
Render_Instance :: shared.Render_Instance
Camera_Instance :: shared.Camera_Instance
Render_List :: shared.Render_List
Custom_Component :: shared.Custom_Component
Vec3 :: shared.Vec3
Named_Vec3 :: shared.Named_Vec3
Transform_Component :: shared.Transform_Component

INVALID_COMPONENT_INDEX :: -1

destroy_world :: proc(world: ^World) {
	for entity in world.entities {
		delete(entity.name)
	}
	for mesh in world.meshes {
		delete(mesh.primitive)
	}
	for &component in world.custom_components {
		delete(component.name)
		for field in component.vec3_fields {
			delete(field.name)
		}
		delete(component.vec3_fields)
	}
	delete(world.entities)
	delete(world.transforms)
	delete(world.cameras)
	delete(world.meshes)
	delete(world.renderables)
	delete(world.custom_components)
	world^ = {}
}

build_world :: proc(scene: ^Scene) -> World {
	world: World
	for entity in scene.entities {
		id := Entity{index = u32(len(world.entities)), generation = 1}
		world_entity := World_Entity {
			id              = id,
			alive           = true,
			name            = clone_world_string(entity.name),
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
			mesh := entity.mesh
			mesh.primitive = clone_world_string(entity.mesh.primitive)
			append(&world.meshes, mesh)
		}
		for component in entity.custom_components {
			world_component := Custom_Component {
				entity_index = int(id.index),
				name         = clone_world_string(component.name),
			}
			for field in component.vec3_fields {
				world_field := field
				world_field.name = clone_world_string(field.name)
				append(&world_component.vec3_fields, world_field)
			}
			append(&world.custom_components, world_component)
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

clone_world_string :: proc(value: string) -> string {
	if value == "" {
		return ""
	}
	cloned, err := strings.clone(value)
	if err != nil {
		return ""
	}
	return cloned
}

render_frame_from_world :: proc(world: ^World) -> Render_Frame {
	return Render_Frame {
		entity_count     = alive_entity_count(world),
		camera_count     = alive_camera_count(world),
		mesh_count       = alive_mesh_count(world),
		renderable_count = alive_renderable_count(world),
	}
}

entity_is_alive :: proc "c" (world: ^World, entity_index: int) -> bool {
	if world == nil || entity_index < 0 || entity_index >= len(world.entities) {
		return false
	}
	return world.entities[entity_index].alive
}

entity_is_current :: proc "c" (world: ^World, entity_index: int, generation: u32) -> bool {
	return entity_is_alive(world, entity_index) && world.entities[entity_index].id.generation == generation
}

alive_entity_count :: proc "c" (world: ^World) -> int {
	count := 0
	for entity in world.entities {
		if entity.alive {
			count += 1
		}
	}
	return count
}

alive_renderable_count :: proc "c" (world: ^World) -> int {
	count := 0
	for renderable in world.renderables {
		if _, ok := render_instance_from_renderable(world, renderable); ok {
			count += 1
		}
	}
	return count
}

alive_camera_count :: proc(world: ^World) -> int {
	count := 0
	for entity in world.entities {
		if entity.alive && entity.camera_index >= 0 {
			count += 1
		}
	}
	return count
}

alive_mesh_count :: proc(world: ^World) -> int {
	count := 0
	for entity in world.entities {
		if entity.alive && entity.mesh_index >= 0 {
			count += 1
		}
	}
	return count
}

build_render_list :: proc(world: ^World) -> Render_List {
	list: Render_List
	list.camera, list.has_camera = first_camera_instance(world)

	for renderable in world.renderables {
		if !entity_is_alive(world, renderable.entity_index) {
			continue
		}
		instance, ok := render_instance_from_renderable(world, renderable)
		if !ok {
			continue
		}
		append(&list.instances, instance)
	}

	return list
}

destroy_render_list :: proc(list: ^Render_List) {
	delete(list.instances)
	list^ = {}
}

render_instance_from_renderable :: proc "c" (world: ^World, renderable: Renderable) -> (instance: Render_Instance, ok: bool) {
	if renderable.entity_index < 0 || renderable.entity_index >= len(world.entities) {
		return {}, false
	}
	if !world.entities[renderable.entity_index].alive {
		return {}, false
	}
	if world.entities[renderable.entity_index].transform_index != renderable.transform_index ||
	   world.entities[renderable.entity_index].mesh_index != renderable.mesh_index {
		return {}, false
	}
	if renderable.transform_index < 0 || renderable.transform_index >= len(world.transforms) {
		return {}, false
	}
	if renderable.mesh_index < 0 || renderable.mesh_index >= len(world.meshes) {
		return {}, false
	}

	return Render_Instance {
		entity    = world.entities[renderable.entity_index],
		transform = world.transforms[renderable.transform_index],
		mesh      = world.meshes[renderable.mesh_index],
	}, true
}

first_camera_instance :: proc(world: ^World) -> (instance: Camera_Instance, ok: bool) {
	for entity in world.entities {
		if !entity.alive {
			continue
		}
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

add_transform :: proc(world: ^World, entity_index: int, transform: Transform_Component) {
	if !entity_is_alive(world, entity_index) {
		return
	}

	entity := &world.entities[entity_index]
	if entity.transform_index >= 0 && entity.transform_index < len(world.transforms) {
		world.transforms[entity.transform_index] = transform
		return
	}

	entity.transform_index = len(world.transforms)
	append_soa(&world.transforms, transform)
	if entity.mesh_index >= 0 {
		append(
			&world.renderables,
			Renderable {
				entity_index    = entity_index,
				transform_index = entity.transform_index,
				mesh_index      = entity.mesh_index,
			},
		)
	}
}

remove_transform :: proc(world: ^World, entity_index: int) {
	if !entity_is_alive(world, entity_index) {
		return
	}
	world.entities[entity_index].transform_index = INVALID_COMPONENT_INDEX
}

add_custom_component :: proc(world: ^World, entity_index: int, command_component: ^Command_Component) {
	if !entity_is_alive(world, entity_index) {
		return
	}

	name := command_component_name(command_component)
	remove_custom_component(world, entity_index, name)

	world_component := Custom_Component {
		entity_index = entity_index,
		name         = clone_world_string(name),
	}
	for i in 0..<command_component.vec3_field_count {
		command_field := &command_component.vec3_fields[i]
		append(
			&world_component.vec3_fields,
			Named_Vec3 {
				name  = clone_world_string(command_field_name(command_field)),
				value = command_field.value,
			},
		)
	}
	append(&world.custom_components, world_component)
}

remove_custom_component :: proc(world: ^World, entity_index: int, name: string) {
	for &world_component in world.custom_components {
		if world_component.entity_index != entity_index || world_component.name != name {
			continue
		}
		delete(world_component.name)
		world_component.name = ""
		world_component.entity_index = INVALID_COMPONENT_INDEX
		for field in world_component.vec3_fields {
			delete(field.name)
		}
		delete(world_component.vec3_fields)
		world_component.vec3_fields = nil
	}
}
