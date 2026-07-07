package game

import "core:math"
import scrapbot "scrapbot:scrapbot_native"

motion_fields := []scrapbot.Component_Field{
	{name = "origin", field_type = .Vec3},
	{name = "amplitude", field_type = .Vec3},
	{name = "phase", field_type = .Float},
	{name = "speed", field_type = .Float},
}

native_move_reads := []string{"motion", "boost"}
native_move_writes := []string{"scrapbot.transform"}
native_move_query := []string{"scrapbot.transform", "motion", "boost"}

elapsed_seconds: f32 = 0.0

native_move :: proc "c" (ctx: ^scrapbot.System_Context) -> bool {
	elapsed_seconds += ctx.delta_seconds
	cursor := 0
	for {
		entity, found := scrapbot.query_next(ctx, native_move_query[:], &cursor)
		if !found {
			break
		}
		origin, origin_ok := scrapbot.get_vec3(ctx, entity, "motion", "origin")
		amplitude, amplitude_ok := scrapbot.get_vec3(ctx, entity, "motion", "amplitude")
		phase, phase_ok := scrapbot.get_float(ctx, entity, "motion", "phase")
		speed, speed_ok := scrapbot.get_float(ctx, entity, "motion", "speed")
		boost, boost_ok := scrapbot.get_float(ctx, entity, "boost", "amount")
		if !origin_ok || !amplitude_ok || !phase_ok || !speed_ok || !boost_ok {
			return false
		}
		t := elapsed_seconds * speed * boost + phase
		next := scrapbot.Vec3{
			x = origin.x + amplitude.x * f32(math.sin(f64(t))),
			y = origin.y + amplitude.y * f32(math.cos(f64(t * 1.17))),
			z = origin.z + amplitude.z * f32(math.sin(f64(t * 0.73))),
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
		id = "motion",
		fields = motion_fields[:],
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
