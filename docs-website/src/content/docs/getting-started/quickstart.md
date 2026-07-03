---
title: Quickstart
description: Build the CLI, run an example project, and verify a scene with Machina's headless tools.
---

Machina uses `mise` for local tool versions and task shortcuts.

## Build the CLI

From the repository root:

```sh
mise build
```

This builds the optimized `machina` CLI into `zig-out/bin/machina`.

For Debug safety checks, use:

```sh
mise build-debug
```

## Run a Project

Run the showcase example in a headful window:

```sh
mise machina run examples/showcase
```

Show the editor/debug overlay on startup:

```sh
mise machina run examples/showcase --editor
```

In a headful run, press `Ctrl+Tab` to toggle the overlay. The overlay shows FPS plus rolling system timings for project systems and engine-internal render systems.

## Validate and Step

Check project metadata, scene data, script declarations, native registrations, and schedule construction:

```sh
mise machina check examples/showcase
```

Step a project headlessly:

```sh
mise machina step examples/showcase --frames 8 --dt 0.05
```

JSON output is available for agent and editor workflows:

```sh
mise machina check examples/showcase --format json
mise machina step examples/showcase --frames 8 --format json
```

## Render and Verify

Render one deterministic BMP artifact:

```sh
mise machina render examples/showcase zig-out/showcase.bmp
```

Run an offscreen render verification:

```sh
mise machina render-test examples/showcase zig-out/showcase-render-test.bmp
```

Render tests check that a frame is nonblank and has expected visible foreground content. They are the preferred automation surface for renderer changes.

## Run the Suite

Run all automated coverage currently wired into the repository:

```sh
mise test
```

The full suite includes Zig tests, project-shaped gameplay tests, a benchmark smoke test, and offscreen render verifications for the example projects.

## Useful Examples

- `examples/minimal/`: canonical smoke-test project.
- `examples/showcase/`: text-authored renderables, scripted animation, camera, and lighting.
- `examples/comet_garden/`: startup-spawned entities, deferred lifecycle commands, and buffer-backed hot loops.
- `examples/spawn_swarm/`: larger script-spawned scene with batching and editor profiling.
- `examples/native_motion/`: project-local Zig native module.
- `examples/ui_overlay/`: retained ECS UI primitives.
