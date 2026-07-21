package native

import ecs "../ecs"
import api "../extension_api"
import schedule "../schedule"
import shared "../shared"
import "core:testing"

@(test)
test_native_input_callbacks_read_world_singletons :: proc(t: ^testing.T) {
	world: shared.World
	defer ecs.destroy_world(&world)
	frame: shared.Input_Frame
	frame.keyboard.available = true
	shared.input_button_set(&frame.keyboard.buttons.down, int(shared.Input_Key.A))
	frame.pointer.available = true
	frame.pointer.delta = {3, -4}
	shared.input_button_set(
		&frame.pointer.buttons.pressed,
		int(shared.Input_Pointer_Button.Primary),
	)
	testing.expect(t, ecs.update_input(&world, frame))
	system: Native_System
	system.declaration.accesses[0] = {
		component = "scrapbot.keyboard_input",
		mode = schedule.Access_Mode.Read,
	}
	system.declaration.accesses[1] = {
		component = "scrapbot.pointer_input",
		mode = schedule.Access_Mode.Read,
	}
	system.declaration.access_count = 2
	step := Step_Context {
		world = &world,
		system = &system,
	}
	ctx := api.System_Context {
		host = &step,
	}
	key: api.Input_Key_State
	testing.expect(t, system_input_key_state(&ctx, "a", &key) != 0)
	testing.expect(t, key.down != 0 && key.pressed == 0 && key.released == 0)
	pointer: api.Pointer_Input
	testing.expect(t, system_input_pointer(&ctx, &pointer) != 0)
	testing.expect(t, pointer.available != 0 && pointer.delta == api.Vec2{3, -4})
	testing.expect(t, pointer.primary.pressed != 0)
}
