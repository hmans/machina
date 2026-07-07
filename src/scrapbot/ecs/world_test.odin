package ecs

import "core:testing"
import project "../project"
import shared "../shared"

@(test)
test_scene_builds_world_with_soa_transforms :: proc(t: ^testing.T) {
	scene, result := project.parse_scene(project.default_scene_template())
	defer delete(scene.entities)

	testing.expect(t, result.err == .None)
	testing.expect(t, len(scene.entities) == 2)

	world := build_world(&scene)
	defer destroy_world(&world)

	testing.expect(t, len(world.entities) == 2)
	testing.expect(t, len(world.transforms) == 2)
	testing.expect(t, len(world.cameras) == 1)
	testing.expect(t, len(world.meshes) == 1)
	testing.expect(t, len(world.renderables) == 1)
	testing.expect(t, world.entities[0].camera_index == 0)
	testing.expect(t, world.entities[1].transform_index == 1)
	testing.expect(t, world.entities[1].mesh_index == 0)
	testing.expect(t, world.renderables[0].entity_index == 1)
	testing.expect(t, world.transforms[1].position == shared.Vec3{0, 0, 0})
}

@(test)
test_step_world_rotates_cube_renderables :: proc(t: ^testing.T) {
	scene, result := project.parse_scene(project.default_scene_template())
	defer delete(scene.entities)

	testing.expect(t, result.err == .None)

	world := build_world(&scene)
	defer destroy_world(&world)

	instance, ok := first_render_instance(&world)
	testing.expect(t, ok)
	testing.expect(t, instance.mesh.primitive == "cube")

	before := world.transforms[instance.entity.transform_index].rotation.y
	step_world(&world, 1)
	after := world.transforms[instance.entity.transform_index].rotation.y

	testing.expect(t, after > before)

	camera, camera_ok := first_camera_instance(&world)
	testing.expect(t, camera_ok)
	testing.expect(t, camera.camera.fov == 60)
}
