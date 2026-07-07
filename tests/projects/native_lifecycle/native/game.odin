package game

import scrapbot "scrapbot:scrapbot_native"

stats_fields := []scrapbot.Component_Field{
	{name = "spawned_count", field_type = .Int},
	{name = "removed_count", field_type = .Int},
	{name = "despawned_count", field_type = .Int},
	{name = "ready", field_type = .Bool},
	{name = "label", field_type = .String},
	{name = "gain", field_type = .Float},
	{name = "direction", field_type = .Vec3},
}

payload_fields := []scrapbot.Component_Field{
	{name = "count", field_type = .Int},
	{name = "enabled", field_type = .Bool},
	{name = "speed", field_type = .Float},
	{name = "direction", field_type = .Vec3},
	{name = "label", field_type = .String},
}

marker_fields := []scrapbot.Component_Field{
	{name = "value", field_type = .Int},
}

lifecycle_writes := []string{"native_stats", "native_payload", "native_marker"}
stats_query := []string{"native_stats"}
marker_query := []string{"native_marker"}

native_lifecycle :: proc "c" (ctx: ^scrapbot.System_Context) -> bool {
	cursor := 0
	for {
		stats_entity, found := scrapbot.query_next(ctx, stats_query[:], &cursor)
		if !found {
			break
		}

		ready, ready_ok := scrapbot.get_bool(ctx, stats_entity, "native_stats", "ready")
		label, label_ok := scrapbot.get_string(ctx, stats_entity, "native_stats", "label")
		gain, gain_ok := scrapbot.get_float(ctx, stats_entity, "native_stats", "gain")
		direction, direction_ok := scrapbot.get_vec3(ctx, stats_entity, "native_stats", "direction")
		if !ready_ok || !label_ok || !gain_ok || !direction_ok || !ready || label != "ready" {
			return false
		}

		survivor, survivor_ok := scrapbot.spawn_entity(ctx, "native-survivor", "Native Survivor")
		if !survivor_ok {
			return false
		}
		payload := []scrapbot.Field_Value{
			scrapbot.field_int("count", 7),
			scrapbot.field_bool("enabled", true),
			scrapbot.field_float("speed", gain + 0.25),
			scrapbot.field_vec3("direction", scrapbot.Vec3{x = direction.x + 2.0, y = direction.y, z = direction.z - 2.0}),
			scrapbot.field_string("label", "spawned"),
		}
		if !scrapbot.add_component(ctx, survivor, "native_payload", payload[:]) {
			return false
		}

		doomed, doomed_ok := scrapbot.spawn_entity(ctx, "native-doomed", "Native Doomed")
		if !doomed_ok {
			return false
		}
		marker := []scrapbot.Field_Value{
			scrapbot.field_int("value", 3),
		}
		if !scrapbot.add_component(ctx, doomed, "native_marker", marker[:]) {
			return false
		}
		if !scrapbot.despawn_entity(ctx, doomed) {
			return false
		}

		marker_cursor := 0
		removed_count := 0
		for {
			marker_entity, marker_found := scrapbot.query_next(ctx, marker_query[:], &marker_cursor)
			if !marker_found {
				break
			}
			if !scrapbot.remove_component(ctx, marker_entity, "native_marker") {
				return false
			}
			removed_count += 1
			break
		}

		if !scrapbot.set_int(ctx, stats_entity, "native_stats", "spawned_count", 2) ||
		   !scrapbot.set_int(ctx, stats_entity, "native_stats", "removed_count", removed_count) ||
		   !scrapbot.set_int(ctx, stats_entity, "native_stats", "despawned_count", 1) ||
		   !scrapbot.set_bool(ctx, stats_entity, "native_stats", "ready", false) ||
		   !scrapbot.set_string(ctx, stats_entity, "native_stats", "label", "done") ||
		   !scrapbot.set_float(ctx, stats_entity, "native_stats", "gain", gain + 1.0) ||
		   !scrapbot.set_vec3(ctx, stats_entity, "native_stats", "direction", scrapbot.Vec3{x = direction.x, y = direction.y + 1.5, z = direction.z}) {
			return false
		}
	}
	return true
}

@(export)
scrapbot_register :: proc "c" (api: ^scrapbot.Register_Api) -> bool {
	if !scrapbot.register_component(api, {
		id = "native_stats",
		fields = stats_fields[:],
	}) {
		return false
	}
	if !scrapbot.register_component(api, {
		id = "native_payload",
		fields = payload_fields[:],
	}) {
		return false
	}
	if !scrapbot.register_component(api, {
		id = "native_marker",
		fields = marker_fields[:],
	}) {
		return false
	}
	if !scrapbot.register_system(api, {
		id = "native_lifecycle",
		phase = .Startup,
		writes = lifecycle_writes[:],
		run = native_lifecycle,
	}) {
		return false
	}
	return true
}
