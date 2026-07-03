---
title: Testing and Verification
description: Validate projects, step simulations, run game-shaped tests, benchmark scenes, and verify renderer output.
---

Machina's headless commands are built for human, CI, editor, and agent workflows.

## Check

Validate a project:

```sh
machina check examples/showcase
```

Check covers project metadata, scene data, component schemas, scripts, native registrations, and schedule construction.

Use JSON when a tool needs structured output:

```sh
machina check examples/showcase --format json
```

## Step

Run deterministic simulation frames without opening a window:

```sh
machina step examples/showcase --frames 8 --dt 0.05
```

Use `step` for narrow ECS and script debugging.

## Project Tests

`machina test` runs game-shaped fixtures from `tests/projects/`.

Each test project has:

- `project.machina.toml`
- A scene.
- Optional scripts.
- Optional native module.
- `test.machina.toml` with frame count, timestep, and ECS field assertions.

Example manifest:

```toml
frames = 1
dt = 1.0

[[expect.field]]
entity = "stats"
component = "lifecycle_stats"
field = "spawned_count"
equals_int = 2
```

Run all project tests:

```sh
machina test tests/projects
```

Run one fixture:

```sh
machina test tests/projects/native_lifecycle
```

## Benchmarks

`machina bench` runs headless performance smoke coverage:

```sh
machina bench examples/spawn_swarm --frames 240
```

Benchmark output includes scene counts, renderable counts, render batch counts, startup time, update time, and time per frame.

## Render Tests

Render one BMP:

```sh
machina render examples/showcase zig-out/showcase.bmp
```

Render and verify visible output:

```sh
machina render-test examples/showcase zig-out/showcase-render-test.bmp
```

Render tests are deterministic and should be used before relying on headful screenshots for renderer work.

## Full Suite

The repository-level suite is:

```sh
mise test
```

It currently runs:

- Zig unit tests.
- Optimized CLI build.
- All `tests/projects/` fixtures.
- A benchmark smoke test.
- Offscreen render tests for key examples.
