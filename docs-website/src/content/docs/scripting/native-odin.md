---
title: Project-Local Odin
description: Register native Odin components and systems that interoperate with Luau and scenes.
---

Scrapbot projects can declare one project-local native Odin module:

```toml
native = "native/game.odin"
```

During development, Scrapbot builds that source file as a dynamic library under `.scrapbot/build/native/dev/`, loads it, and calls `scrapbot_register`.

Dynamic native module loading is supported on macOS, Linux, and Windows MSVC. Windows GNU is not a primary support target for this development loop.

## Registration Entry Point

```odin
package game

import scrapbot "scrapbot:scrapbot_native"

velocity_fields := []scrapbot.Component_Field{
	{name = "linear", field_type = .Vec3},
}

native_move_reads := []string{"velocity", "boost"}
native_move_writes := []string{"scrapbot.transform"}

@(export)
scrapbot_register :: proc "c" (api: ^scrapbot.Register_Api) -> bool {
	if !scrapbot.register_component(api, {
		id = "velocity",
		fields = velocity_fields[:],
	}) {
		return false
	}

	return scrapbot.register_system(api, {
		id = "native_move",
		phase = .Update,
		reads = native_move_reads[:],
		writes = native_move_writes[:],
		run = native_move,
	})
}
```

Project native code imports the generated `scrapbot:scrapbot_native` API. It does not import engine internals.

## Native System Callback

```odin
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
```

## Host API Surface

Native systems use an access-checked host facade.

Typed field helpers:

- `get_bool` / `set_bool`
- `get_int` / `set_int`
- `get_float` / `set_float`
- `get_vec3` / `set_vec3`
- `get_string` / `set_string`

Lifecycle helpers:

- `spawn_entity`
- `despawn_entity`
- `add_component`
- `remove_component`

Query helper:

- `query_next`

The host checks declared reads and writes at query, read, write, and lifecycle command time. Declared writes also allow reads for that component.

## Add Components from Odin

Use typed `scrapbot.Field_Value` values:

```odin
entity, entity_ok := scrapbot.spawn_entity(ctx, "native-survivor", "Native Survivor")
if !entity_ok {
	return false
}

fields := []scrapbot.Field_Value{
	scrapbot.field_int("count", 7),
	scrapbot.field_bool("enabled", true),
	scrapbot.field_float("speed", 1.75),
	scrapbot.field_vec3("direction", scrapbot.Vec3{x = 3.0, y = 2.0, z = 1.0}),
	scrapbot.field_string("label", "spawned"),
}

if !scrapbot.add_component(ctx, entity, "native_payload", fields[:]) {
	return false
}
```

Structural commands use the same semantics as Luau:

- Spawns happen immediately and are rolled back if the system fails.
- Add/remove component and despawn commands are queued.
- Queued commands flush only after the native system returns success.

## Live Reload

When native source changes during `scrapbot run`, Scrapbot rebuilds and reloads the module, rebuilds the ECS program, validates the current scene, and swaps only if every stage succeeds.

Failed native builds, loads, or registrations keep the last-known-good program active and report diagnostics.

## Static Build Direction

Dynamic loading is the development loop. `scrapbot build` currently packages host-platform bundles with a prebuilt native dynamic library artifact, so the bundled project can load native systems without rebuilding source on the target machine.

The registration entry point and source-level API are still designed for a future SDK/static build path that can statically link the same project-native source on platforms where dynamic code loading is impossible or forbidden.
