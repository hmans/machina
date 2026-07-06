package main

Frame_Input_Pointer :: struct {
	position:           [2]f32,
	delta:              [2]f32,
	has_position:       bool,
	primary_down:       bool,
	primary_pressed:    bool,
	primary_released:   bool,
	secondary_down:     bool,
	secondary_pressed:  bool,
	secondary_released: bool,
	wheel_delta:        [2]f32,
}

Frame_Input_Keyboard :: struct {
	ctrl_down:             bool,
	shift_down:            bool,
	alt_down:              bool,
	super_down:            bool,
	move_forward:          bool,
	move_back:             bool,
	move_left:             bool,
	move_right:            bool,
	move_up:               bool,
	move_down:             bool,
	editor_toggle_pressed: bool,
}

Frame_Input :: struct {
	pointer:                   Frame_Input_Pointer,
	keyboard:                  Frame_Input_Keyboard,
	ui_visible:                bool,
	debug_overlay_visible:     bool,
	viewport_width:            f32,
	viewport_height:           f32,
	pixel_scale:               f32,
	system_profile_count_hint: int,
}

Step_Input_Frame :: struct {
	frame: int,
	input: Frame_Input,
}

frame_input_default :: proc() -> Frame_Input {
	return Frame_Input{
		ui_visible = true,
		pixel_scale = 1.0,
	}
}

write_frame_input :: proc(world: ^Runtime_World, input: Frame_Input) -> Runtime_Error {
	handle, found := runtime_world_find_entity_by_id(world^, INPUT_ENTITY_ID)
	if !found {
		create_err: Runtime_Error
		handle, create_err = runtime_world_create_entity(world, INPUT_ENTITY_ID, "Input")
		if create_err != .None {
			return create_err
		}
	}

	pointer_fields := [?]Runtime_Component_Field_Value{
		{name = "position", value = Runtime_Component_Value{value_type = .Vec3, vec3 = {input.pointer.position[0], input.pointer.position[1], 0}}},
		{name = "delta", value = Runtime_Component_Value{value_type = .Vec3, vec3 = {input.pointer.delta[0], input.pointer.delta[1], 0}}},
		{name = "has_position", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.pointer.has_position}},
		{name = "primary_down", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.pointer.primary_down}},
		{name = "primary_pressed", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.pointer.primary_pressed}},
		{name = "primary_released", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.pointer.primary_released}},
		{name = "secondary_down", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.pointer.secondary_down}},
		{name = "secondary_pressed", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.pointer.secondary_pressed}},
		{name = "secondary_released", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.pointer.secondary_released}},
		{name = "wheel_delta", value = Runtime_Component_Value{value_type = .Vec3, vec3 = {input.pointer.wheel_delta[0], input.pointer.wheel_delta[1], 0}}},
	}
	err := runtime_world_set_component(world, handle, INPUT_POINTER_COMPONENT_ID, pointer_fields[:])
	if err != .None {
		return err
	}

	keyboard_fields := [?]Runtime_Component_Field_Value{
		{name = "ctrl_down", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.keyboard.ctrl_down}},
		{name = "shift_down", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.keyboard.shift_down}},
		{name = "alt_down", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.keyboard.alt_down}},
		{name = "super_down", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.keyboard.super_down}},
		{name = "move_forward", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.keyboard.move_forward}},
		{name = "move_back", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.keyboard.move_back}},
		{name = "move_left", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.keyboard.move_left}},
		{name = "move_right", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.keyboard.move_right}},
		{name = "move_up", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.keyboard.move_up}},
		{name = "move_down", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.keyboard.move_down}},
		{name = "editor_toggle_pressed", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.keyboard.editor_toggle_pressed}},
	}
	err = runtime_world_set_component(world, handle, INPUT_KEYBOARD_COMPONENT_ID, keyboard_fields[:])
	if err != .None {
		return err
	}

	frame_fields := [?]Runtime_Component_Field_Value{
		{name = "ui_visible", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.ui_visible}},
		{name = "debug_overlay_visible", value = Runtime_Component_Value{value_type = .Boolean, boolean = input.debug_overlay_visible}},
		{name = "viewport", value = Runtime_Component_Value{value_type = .Vec3, vec3 = {input.viewport_width, input.viewport_height, 0}}},
		{name = "pixel_scale", value = Runtime_Component_Value{value_type = .Float, float = input.pixel_scale}},
	}
	return runtime_world_set_component(world, handle, INPUT_FRAME_COMPONENT_ID, frame_fields[:])
}

step_input_for_frame :: proc(input_frames: []Step_Input_Frame, frame: int) -> Frame_Input {
	for input_frame in input_frames {
		if input_frame.frame == frame {
			return input_frame.input
		}
	}
	return frame_input_default()
}
