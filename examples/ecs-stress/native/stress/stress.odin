package stress

import "base:intrinsics"
import "core:math"
import scrapbot "scrapbot:extension"

Motion_Component :: scrapbot.Component {
	name = "stress.motion",
}
Motion_Velocity :: scrapbot.Vec3_Field {
	component = Motion_Component,
	name = "velocity",
}

Spin_Component :: scrapbot.Component {
	name = "stress.spin",
}
Spin_Velocity :: scrapbot.Vec3_Field {
	component = Spin_Component,
	name = "velocity",
}

Lifetime_Component :: scrapbot.Component {
	name = "stress.lifetime",
	advanced = true,
}
Lifetime_Age :: scrapbot.Number_Field {
	component = Lifetime_Component,
	name = "age",
}
Lifetime_Duration :: scrapbot.Number_Field {
	component = Lifetime_Component,
	name = "duration",
}

Emitter_Component :: scrapbot.Component {
	name = "stress.emitter",
	advanced = true,
}
Emitter_Elapsed :: scrapbot.Number_Field {
	component = Emitter_Component,
	name = "elapsed",
}
Emitter_Sequence :: scrapbot.Number_Field {
	component = Emitter_Component,
	name = "sequence",
}

Settings_Component :: scrapbot.Component {
	name = "stress.settings",
}
Settings_Spawn_Rate :: scrapbot.Number_Field {
	component = Settings_Component,
	name = "spawn_rate",
}
Settings_Lifetime :: scrapbot.Number_Field {
	component = Settings_Component,
	name = "lifetime",
}
Settings_Launch_Speed :: scrapbot.Number_Field {
	component = Settings_Component,
	name = "launch_speed",
}

Particle_Geometry: scrapbot.Resource_Handle
Particle_Materials: [3]scrapbot.Resource_Handle

@(export)
scrapbot_extension_register :: proc "c" (api: ^scrapbot.API) -> cstring {
	return scrapbot.register(api, register)
}

register :: proc "contextless" (ctx: ^scrapbot.Context) -> cstring {
	reg := scrapbot.registry(ctx)
	cube := scrapbot.cube_geometry(1)
	Particle_Geometry = scrapbot.register_generated_geometry(&reg, "stress.particle", &cube)
	Particle_Materials[0] = scrapbot.emissive_material(&reg, "stress.cyan", {0.05, 1.4, 1.8})
	Particle_Materials[1] = scrapbot.emissive_material(&reg, "stress.magenta", {1.6, 0.08, 1.2})
	Particle_Materials[2] = scrapbot.emissive_material(&reg, "stress.gold", {1.8, 0.75, 0.04})

	motion_fields := [?]scrapbot.Field{scrapbot.vec3(Motion_Velocity)}
	scrapbot.component(&reg, Motion_Component, motion_fields[:])
	spin_fields := [?]scrapbot.Field{scrapbot.vec3(Spin_Velocity)}
	scrapbot.component(&reg, Spin_Component, spin_fields[:])
	lifetime_fields := [?]scrapbot.Field {
		scrapbot.number(Lifetime_Age),
		scrapbot.number(Lifetime_Duration),
	}
	scrapbot.component(&reg, Lifetime_Component, lifetime_fields[:])
	emitter_fields := [?]scrapbot.Field {
		scrapbot.number(Emitter_Elapsed),
		scrapbot.number(Emitter_Sequence),
	}
	scrapbot.component(&reg, Emitter_Component, emitter_fields[:])
	settings_fields := [?]scrapbot.Field {
		scrapbot.number_draggable(Settings_Spawn_Rate, 10, 0, 5000),
		scrapbot.number_draggable(Settings_Lifetime, 0.1, 0.1, 30),
		scrapbot.number_draggable(Settings_Launch_Speed, 0.1, 0, 20),
	}
	scrapbot.component(&reg, Settings_Component, settings_fields[:])

	integrate_accesses := [?]scrapbot.Access {
		scrapbot.write(scrapbot.Transform_Component),
		scrapbot.write(Motion_Component),
	}
	scrapbot.system(&reg, "integrate", integrate_accesses[:], integrate_system)
	autorotate_accesses := [?]scrapbot.Access {
		scrapbot.write(scrapbot.Transform_Component),
		scrapbot.read(Spin_Component),
	}
	scrapbot.system(&reg, "autorotate", autorotate_accesses[:], autorotate_system)
	age_accesses := [?]scrapbot.Access {
		scrapbot.read(Lifetime_Component),
		scrapbot.write(Lifetime_Component),
	}
	scrapbot.system(&reg, "age", age_accesses[:], age_system)
	emit_accesses := [?]scrapbot.Access {
		scrapbot.write(scrapbot.Transform_Component),
		scrapbot.write(scrapbot.Component{name = "scrapbot.geometry"}),
		scrapbot.write(scrapbot.Component{name = "scrapbot.material"}),
		scrapbot.read(Emitter_Component),
		scrapbot.write(Emitter_Component),
		scrapbot.read(Settings_Component),
		scrapbot.write(Motion_Component),
		scrapbot.write(Spin_Component),
		scrapbot.write(Lifetime_Component),
	}
	scrapbot.system(&reg, "emit", emit_accesses[:], emit_system)
	return scrapbot.err(&reg)
}

integrate_system :: proc "contextless" (ctx: ^scrapbot.System_Context) -> cstring {
	components := [?]scrapbot.Component{scrapbot.Transform_Component, Motion_Component}
	chunk: scrapbot.Query_Chunk
	if !scrapbot.init_query_chunk(&chunk, scrapbot.query(components[:])) {
		return "failed to initialize integration chunk"
	}
	transforms: [scrapbot.MAX_QUERY_CHUNK_ENTITIES]scrapbot.Transform
	velocities: [scrapbot.MAX_QUERY_CHUNK_ENTITIES]scrapbot.Vec3
	transform_binding, transform_ok := scrapbot.bind_transform(&chunk, transforms[:], .Write)
	velocity_binding, velocity_ok := scrapbot.bind_vec3(
		&chunk,
		Motion_Velocity,
		velocities[:],
		.Write,
	)
	if !transform_ok || !velocity_ok {
		return "failed to bind integration chunk"
	}
	delta := scrapbot.F32x4(ctx.time.delta_time)
	gravity := scrapbot.F32x4(3.8 * ctx.time.delta_time)
	drag := scrapbot.F32x4(0.999)
	for {
		count, err := scrapbot.next_chunk(ctx, &chunk)
		if err != nil {
			return err
		}
		if count == 0 {
			break
		}
		lane := 0
		for lane + 4 <= count {
			position := scrapbot.load_transform_positions_x4(transforms[:], lane)
			velocity := scrapbot.load_vec3x4(velocities[:], lane)
			position.x = intrinsics.fused_mul_add(velocity.x, delta, position.x)
			position.y = intrinsics.fused_mul_add(velocity.y, delta, position.y)
			position.z = intrinsics.fused_mul_add(velocity.z, delta, position.z)
			velocity.y = intrinsics.simd_sub(velocity.y, gravity)
			velocity.x = intrinsics.simd_mul(velocity.x, drag)
			velocity.z = intrinsics.simd_mul(velocity.z, drag)
			scrapbot.store_transform_positions_x4(transforms[:], position, lane)
			scrapbot.store_vec3x4(velocities[:], velocity, lane)
			lane += 4
		}
		for lane < count {
			transforms[lane].position.x += velocities[lane].x * ctx.time.delta_time
			transforms[lane].position.y += velocities[lane].y * ctx.time.delta_time
			transforms[lane].position.z += velocities[lane].z * ctx.time.delta_time
			velocities[lane].y -= 3.8 * ctx.time.delta_time
			velocities[lane].x *= 0.999
			velocities[lane].z *= 0.999
			lane += 1
		}
		scrapbot.chunk_write_all(&chunk, transform_binding)
		scrapbot.chunk_write_all(&chunk, velocity_binding)
		if err := scrapbot.commit_chunk(ctx, &chunk); err != nil {
			return err
		}
	}
	return nil
}

autorotate_system :: proc "contextless" (ctx: ^scrapbot.System_Context) -> cstring {
	components := [?]scrapbot.Component{scrapbot.Transform_Component, Spin_Component}
	chunk: scrapbot.Query_Chunk
	if !scrapbot.init_query_chunk(&chunk, scrapbot.query(components[:])) {
		return "failed to initialize autorotate chunk"
	}
	transforms: [scrapbot.MAX_QUERY_CHUNK_ENTITIES]scrapbot.Transform
	velocities: [scrapbot.MAX_QUERY_CHUNK_ENTITIES]scrapbot.Vec3
	transform_binding, transform_ok := scrapbot.bind_transform(&chunk, transforms[:], .Write)
	_, velocity_ok := scrapbot.bind_vec3(&chunk, Spin_Velocity, velocities[:])
	if !transform_ok || !velocity_ok {
		return "failed to bind autorotate chunk"
	}
	delta := scrapbot.F32x4(ctx.time.delta_time)
	for {
		count, err := scrapbot.next_chunk(ctx, &chunk)
		if err != nil {
			return err
		}
		if count == 0 {
			break
		}
		lane := 0
		for lane + 4 <= count {
			rotation := scrapbot.load_transform_rotations_x4(transforms[:], lane)
			velocity := scrapbot.load_vec3x4(velocities[:], lane)
			rotation.x = intrinsics.fused_mul_add(velocity.x, delta, rotation.x)
			rotation.y = intrinsics.fused_mul_add(velocity.y, delta, rotation.y)
			rotation.z = intrinsics.fused_mul_add(velocity.z, delta, rotation.z)
			scrapbot.store_transform_rotations_x4(transforms[:], rotation, lane)
			lane += 4
		}
		for lane < count {
			transforms[lane].rotation.x += velocities[lane].x * ctx.time.delta_time
			transforms[lane].rotation.y += velocities[lane].y * ctx.time.delta_time
			transforms[lane].rotation.z += velocities[lane].z * ctx.time.delta_time
			lane += 1
		}
		scrapbot.chunk_write_all(&chunk, transform_binding)
		if err := scrapbot.commit_chunk(ctx, &chunk); err != nil {
			return err
		}
	}
	return nil
}

age_system :: proc "contextless" (ctx: ^scrapbot.System_Context) -> cstring {
	components := [?]scrapbot.Component{Lifetime_Component}
	chunk: scrapbot.Query_Chunk
	if !scrapbot.init_query_chunk(&chunk, scrapbot.query(components[:])) {
		return "failed to initialize age chunk"
	}
	ages: [scrapbot.MAX_QUERY_CHUNK_ENTITIES]f32
	durations: [scrapbot.MAX_QUERY_CHUNK_ENTITIES]f32
	age_binding, age_ok := scrapbot.bind_number(&chunk, Lifetime_Age, ages[:], .Write)
	_, duration_ok := scrapbot.bind_number(&chunk, Lifetime_Duration, durations[:])
	if !age_ok || !duration_ok {
		return "failed to bind age chunk"
	}
	delta := scrapbot.F32x4(ctx.time.delta_time)
	for {
		count, err := scrapbot.next_chunk(ctx, &chunk)
		if err != nil {
			return err
		}
		if count == 0 {
			break
		}
		expired_mask: u64
		lane := 0
		for lane + 4 <= count {
			age := scrapbot.F32x4{ages[lane], ages[lane + 1], ages[lane + 2], ages[lane + 3]}
			duration := scrapbot.F32x4 {
				durations[lane],
				durations[lane + 1],
				durations[lane + 2],
				durations[lane + 3],
			}
			age = intrinsics.simd_add(age, delta)
			expired_mask |=
				scrapbot.simd_mask_bits(intrinsics.simd_lanes_ge(age, duration)) << u64(lane)
			age_values := transmute([4]f32)age
			for offset in 0 ..< 4 {
				ages[lane + offset] = age_values[offset]
			}
			lane += 4
		}
		for lane < count {
			ages[lane] += ctx.time.delta_time
			if ages[lane] >= durations[lane] {
				expired_mask |= u64(1) << u64(lane)
			}
			lane += 1
		}
		scrapbot.chunk_write_mask(&chunk, age_binding, ~expired_mask)
		if err := scrapbot.commit_chunk(ctx, &chunk); err != nil {
			return err
		}
		for expired_lane in 0 ..< count {
			if expired_mask & (u64(1) << u64(expired_lane)) == 0 {
				continue
			}
			if err := scrapbot.despawn(ctx, chunk.entities[expired_lane]); err != nil {
				return err
			}
		}
	}
	return nil
}

emit_system :: proc "contextless" (ctx: ^scrapbot.System_Context) -> cstring {
	components := [?]scrapbot.Component {
		scrapbot.Transform_Component,
		Emitter_Component,
		Settings_Component,
	}
	query := scrapbot.query(components[:])
	cursor: scrapbot.Query_Cursor
	for {
		entity, ok := scrapbot.next(ctx, query, &cursor)
		if !ok {
			break
		}
		transform, transform_ok := scrapbot.get(ctx, entity, scrapbot.Transform_Component)
		elapsed, elapsed_ok := scrapbot.get(ctx, entity, Emitter_Elapsed)
		sequence, sequence_ok := scrapbot.get(ctx, entity, Emitter_Sequence)
		spawn_rate, spawn_rate_ok := scrapbot.get(ctx, entity, Settings_Spawn_Rate)
		lifetime, lifetime_ok := scrapbot.get(ctx, entity, Settings_Lifetime)
		launch_speed, launch_speed_ok := scrapbot.get(ctx, entity, Settings_Launch_Speed)
		if !transform_ok ||
		   !elapsed_ok ||
		   !sequence_ok ||
		   !spawn_rate_ok ||
		   !lifetime_ok ||
		   !launch_speed_ok {
			return "failed to read stress emitter"
		}
		spawn_rate = clamp(spawn_rate, f32(0), f32(5000))
		if spawn_rate <= 0 {
			continue
		}
		elapsed += ctx.time.delta_time
		interval := 1 / spawn_rate
		spawn_count := 0
		for elapsed >= interval && spawn_count < 64 {
			elapsed -= interval
			if err := spawn_particle(
				ctx,
				transform,
				i32(sequence),
				max(lifetime, 0.1),
				launch_speed,
			); err != nil {
				return err
			}
			sequence += 1
			spawn_count += 1
		}
		if spawn_count == 64 && elapsed >= interval {
			elapsed = 0
		}
		if !scrapbot.set(ctx, entity, Emitter_Elapsed, elapsed) ||
		   !scrapbot.set(ctx, entity, Emitter_Sequence, sequence) {
			return "failed to write stress emitter"
		}
	}
	return nil
}

spawn_particle :: proc "contextless" (
	ctx: ^scrapbot.System_Context,
	emitter: scrapbot.Transform,
	sequence: i32,
	lifetime, launch_speed: f32,
) -> cstring {
	angle := f32(sequence) * 2.3999631
	phase := f32(sequence % 31) / 30
	radius := 0.15 + phase * 0.8
	scale := 0.045 + phase * 0.065
	transform := scrapbot.Transform {
		position = {
			emitter.position.x + math.cos(angle) * radius,
			emitter.position.y,
			emitter.position.z + math.sin(angle) * radius,
		},
		rotation = {angle, angle * 0.7, angle * 0.3},
		scale = {scale, scale, scale},
	}
	velocity := scrapbot.Vec3 {
		x = math.cos(angle) * (0.7 + phase * 1.6),
		y = launch_speed + phase * 2.2,
		z = math.sin(angle) * (0.7 + phase * 1.6),
	}
	spin := scrapbot.Vec3 {
		x = 1.5 + phase * 3,
		y = 2.2 + phase * 4,
		z = 0.8 + phase * 2,
	}
	motion_fields := [?]scrapbot.Component_Vec3_Field {
		scrapbot.vec3_value(Motion_Velocity, velocity),
	}
	spin_fields := [?]scrapbot.Component_Vec3_Field{scrapbot.vec3_value(Spin_Velocity, spin)}
	lifetime_fields := [?]scrapbot.Component_Number_Field {
		scrapbot.number_value(Lifetime_Age, 0),
		scrapbot.number_value(Lifetime_Duration, lifetime + phase),
	}
	payloads := [?]scrapbot.Component_Payload {
		scrapbot.payload(Motion_Component, motion_fields[:]),
		scrapbot.payload(Spin_Component, spin_fields[:]),
		scrapbot.payload(Lifetime_Component, nil, lifetime_fields[:]),
	}
	material := &Particle_Materials[int(sequence % 3)]
	options := scrapbot.spawn_options(
		"Stress Particle",
		&transform,
		&Particle_Geometry,
		material,
		payloads[:],
	)
	return scrapbot.spawn(ctx, &options)
}
