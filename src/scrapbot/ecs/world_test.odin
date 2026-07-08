package ecs

import "core:testing"
import project "../project"
import shared "../shared"

MULTI_CUBE_SCENE :: `[[entities]]
name = "Main Camera"

[entities.transform]
position = [0, 2, 6]
rotation = [0, 0, 0]
scale = [1, 1, 1]

[entities.camera]
fov = 60
near = 0.1
far = 100

[[entities]]
name = "Left Cube"

[entities.transform]
position = [-1.25, 0, 0]
rotation = [0, 0, 0]
scale = [1, 1, 1]

[entities.mesh]
primitive = "cube"

[[entities]]
name = "Right Cube"

[entities.transform]
position = [1.25, 0, 0]
rotation = [0, 0, 0]
scale = [1, 1, 1]

[entities.mesh]
primitive = "cube"
`

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
test_render_list_includes_multiple_cube_renderables :: proc(t: ^testing.T) {
	scene, result := project.parse_scene(MULTI_CUBE_SCENE)
	defer delete(scene.entities)

	testing.expect(t, result.err == .None)
	testing.expect(t, len(scene.entities) == 3)

	world := build_world(&scene)
	defer destroy_world(&world)

	testing.expect(t, len(world.entities) == 3)
	testing.expect(t, len(world.transforms) == 3)
	testing.expect(t, len(world.meshes) == 2)
	testing.expect(t, len(world.renderables) == 2)

	render_list := build_render_list(&world)
	defer destroy_render_list(&render_list)

	testing.expect(t, render_list.has_camera)
	testing.expect(t, len(render_list.instances) == 2)
	testing.expect(t, render_list.instances[0].entity.name == "Left Cube")
	testing.expect(t, render_list.instances[1].entity.name == "Right Cube")
}

@(test)
test_step_world_rotates_cube_renderables :: proc(t: ^testing.T) {
	scene, result := project.parse_scene(MULTI_CUBE_SCENE)
	defer delete(scene.entities)

	testing.expect(t, result.err == .None)

	world := build_world(&scene)
	defer destroy_world(&world)

	left_before := world.transforms[world.entities[1].transform_index].rotation.y
	right_before := world.transforms[world.entities[2].transform_index].rotation.y
	step_world(&world, 1)
	left_after := world.transforms[world.entities[1].transform_index].rotation.y
	right_after := world.transforms[world.entities[2].transform_index].rotation.y

	testing.expect(t, left_after > left_before)
	testing.expect(t, right_after > right_before)

	camera, camera_ok := first_camera_instance(&world)
	testing.expect(t, camera_ok)
	testing.expect(t, camera.camera.fov == 60)
}
