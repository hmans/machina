package ecs

import shared "../shared"
import "core:testing"

@(test)
test_input_singletons_update_without_allocating_entity_slots :: proc(t: ^testing.T) {
	world: World
	defer destroy_world(&world)
	frame: shared.Input_Frame
	frame.keyboard.available = true
	frame.keyboard.focused = true
	shared.input_button_set(&frame.keyboard.buttons.down, int(shared.Input_Key.W))
	shared.input_button_set(&frame.keyboard.buttons.pressed, int(shared.Input_Key.Space))
	frame.pointer.available = true
	frame.pointer.position = {320, 180}
	frame.pointer.delta = {4, -2}
	frame.pointer.wheel = {0, 1}
	shared.input_button_set(
		&frame.pointer.buttons.released,
		int(shared.Input_Pointer_Button.Primary),
	)

	testing.expect(t, update_input(&world, frame))
	testing.expect(t, len(world.entities) == 0)
	keyboard, keyboard_ok := keyboard_input(&world)
	testing.expect(t, keyboard_ok && keyboard.available && keyboard.focused)
	w_down, _, _ := shared.input_key_state(keyboard, .W)
	_, space_pressed, _ := shared.input_key_state(keyboard, .Space)
	testing.expect(t, w_down && space_pressed)
	pointer, pointer_ok := pointer_input(&world)
	testing.expect(t, pointer_ok && pointer.position == shared.Vec2{320, 180})
	_, _, primary_released := shared.input_pointer_button_state(pointer, .Primary)
	testing.expect(t, primary_released)
}
