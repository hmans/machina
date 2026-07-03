---
title: Project Files
description: Reference for project manifests, scene files, scripts, native modules, and test manifests.
---

## `project.machina.toml`

```toml
name = "Showcase"
version = 1
default_scene = "scenes/main.scene.toml"
scripts = ["scripts/gameplay.luau"]
native = "native/game.zig"
```

| Key | Required | Notes |
| --- | --- | --- |
| `name` | Yes | Human-readable project name. |
| `version` | Yes | Project schema version. Current examples use `1`. |
| `default_scene` | Yes | Path to the scene loaded by default. |
| `scripts` | No | List of Luau script paths. |
| `native` | No | Path to one project-local Zig native module. |

## Scene Files

Scene files use TOML:

```toml
name = "Main"
version = 1

[[entities]]
id = "entity-id"
name = "Entity Name"

[entities.components."machina.transform"]
position = [0.0, 0.0, 0.0]
rotation = [0.0, 0.0, 0.0]
scale = [1.0, 1.0, 1.0]
```

Entity component tables must match registered component schemas.

## Scripts

Scripts are Luau source files listed by the project manifest:

```toml
scripts = ["scripts/gameplay.luau"]
```

Scripts register ECS components and systems through the `ecs` API.

## Native Modules

Native modules are Zig source files declared by the project manifest:

```toml
native = "native/game.zig"
```

Native modules export:

```zig
export fn machina_register(api: *const machina.RegisterApi) callconv(.c) c_int
```

During development, Machina builds generated dynamic library output under `.machina/native/`.

## Test Manifests

Project test fixtures use `test.machina.toml`:

```toml
frames = 4
dt = 0.25

[[expect.field]]
entity = "mover"
component = "machina.transform"
field = "position"
equals_vec3 = [3.0, -1.5, 0.75]
```

Supported expected values:

- `equals_bool`
- `equals_int`
- `equals_float`
- `equals_vec3`
- `equals_string`
