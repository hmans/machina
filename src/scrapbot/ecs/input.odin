package ecs

import shared "../shared"

update_input :: proc(world: ^World, frame: shared.Input_Frame) -> bool {
	if world == nil {
		return false
	}
	world.input_initialized = true
	world.keyboard_input = frame.keyboard
	world.pointer_input = frame.pointer
	return true
}

keyboard_input :: proc "contextless" (world: ^World) -> (shared.Keyboard_Input_Component, bool) {
	if world == nil {
		return {}, false
	}
	if !world.input_initialized {
		return {}, false
	}
	return world.keyboard_input, true
}

pointer_input :: proc "contextless" (world: ^World) -> (shared.Pointer_Input_Component, bool) {
	if world == nil {
		return {}, false
	}
	if !world.input_initialized {
		return {}, false
	}
	return world.pointer_input, true
}
