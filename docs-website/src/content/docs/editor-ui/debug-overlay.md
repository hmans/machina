---
title: Editor UI Overlay
description: Use Machina's ECS-hosted debug overlay for FPS and system performance inspection.
---

Machina's first editor UI is an engine-owned debug overlay rendered with Machina UI primitives.

It is hidden by default.

Show it at startup:

```sh
machina run examples/spawn_swarm --editor
```

Toggle it during a headful run:

```txt
Ctrl+Tab
```

## What It Shows

The current overlay shows:

- FPS.
- Active project system count.
- Rolling average runtime over the profiling window.
- Last runtime sample.
- Project Luau and native systems.
- Engine-internal render systems.

System timings are captured at scheduler dispatch boundaries. Render system timings are captured from the render ECS schedule and displayed alongside project systems.

## UI Is ECS Data

The editor overlay is generated into the render ECS world, but the same retained UI primitives are available to projects:

- `machina.ui.canvas`
- `machina.ui.rect`
- `machina.ui.text`
- `machina.ui.button`
- `machina.ui.command`

Text uses an embedded Spleen-derived bitmap font.

## Scene-Authored UI Example

```toml
[[entities]]
id = "debug-panel"
name = "Debug Panel"

[entities.components."machina.ui.rect"]
position = [12.0, 12.0, 0.0]
size = [320.0, 120.0, 0.0]
color = [0.059, 0.09, 0.165]

[[entities]]
id = "debug-label"
name = "Debug Label"

[entities.components."machina.ui.text"]
position = [28.0, 24.0, 0.0]
size = 1.5
color = [0.93, 0.969, 1.0]
value = "MACHINA UI"
```

## Command Buttons

Buttons are ECS-shaped too:

```toml
[entities.components."machina.ui.button"]

[entities.components."machina.ui.command"]
command = "open.debug.panel"
```

When a command button is pressed, Machina emits transient `machina.ui.command_event` data into the live project world before update systems run.

Do not author `machina.ui.command_event` in scene files. It is runtime-only transient data.

## Design Constraints

Editor/debug UI should stay legible. The built-in bitmap text should not be used below `1.0` scale for editor surfaces, and primary readouts should be larger.
