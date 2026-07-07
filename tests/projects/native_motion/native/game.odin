package game

import scrapbot "scrapbot:scrapbot_native"

velocity_fields := []scrapbot.Component_Field{
	{name = "linear", field_type = .Vec3},
}

native_move_reads := []string{"velocity", "boost"}
native_move_writes := []string{"scrapbot.transform"}
native_move_query := []string{"scrapbot.transform", "velocity", "boost"}

native_move :: proc "c" (ctx: ^scrapbot.System_Context) -> bool {
	cursor := 0
	for {
		entity, found := scrapbot.query_next(ctx, native_move_query[:], &cursor)
		if !found {
			break
		}
		position, position_ok := scrapbot.get_vec3(ctx, entity, "scrapbot.transform", "position")
		linear, linear_ok := scrapbot.get_vec3(ctx, entity, "velocity", "linear")
		boost, boost_ok := scrapbot.get_float(ctx, entity, "boost", "amount")
		if !position_ok || !linear_ok || !boost_ok {
			return false
		}
		next := scrapbot.Vec3{
			x = position.x + linear.x * boost * ctx.delta_seconds,
			y = position.y + linear.y * boost * ctx.delta_seconds,
			z = position.z + linear.z * boost * ctx.delta_seconds,
		}
		if !scrapbot.set_vec3(ctx, entity, "scrapbot.transform", "position", next) {
			return false
		}
	}
	return true
}

@(export)
scrapbot_register :: proc "c" (api: ^scrapbot.Register_Api) -> bool {
	if !scrapbot.register_component(api, {
		id = "velocity",
		fields = velocity_fields[:],
	}) {
		return false
	}
	if !scrapbot.register_system(api, {
		id = "native_move",
		phase = .Update,
		reads = native_move_reads[:],
		writes = native_move_writes[:],
		run = native_move,
	}) {
		return false
	}
	return true
}
