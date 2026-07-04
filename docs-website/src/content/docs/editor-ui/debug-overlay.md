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
- Project Luau and native systems.
- Engine-internal render systems.
- A visible scrollbar when the system list overflows.

System timings are captured at scheduler dispatch boundaries. Render system timings are captured from the render ECS schedule and displayed alongside project systems.

The visible table updates at a throttled cadence for readability while the underlying profiler keeps sampling every frame.

## UI Is ECS Data

The editor overlay is generated into the render ECS world, but the same retained UI primitives are available to projects:

- `machina.ui.canvas`
- `machina.ui.rect`
- `machina.ui.border`
- `machina.ui.text`
- `machina.ui.button`
- `machina.ui.command`
- `machina.ui.scroll_view`
- `machina.ui.vbox`
- `machina.ui.stack`
- `machina.ui.layout.item`
- `machina.ui.spacer`
- `machina.ui.text_block`
- `machina.ui.toggle`
- `machina.ui.progress_bar`
- `machina.ui.separator`

Text uses an embedded Spleen-derived bitmap font.

Editor controls are built from the same retained primitives as project UI. For example, playback button labels are text children of their button rects instead of separate absolute overlays.

## Scene-Authored UI Example

```toml
[[entities]]
id = "debug-panel"
name = "Debug Panel"

[entities.components."machina.ui.canvas"]
design_size = [640.0, 480.0, 0.0]
scale_mode = "fit"

[entities.components."machina.ui.rect"]
position = [12.0, 12.0, 0.0]
size = [320.0, 120.0, 0.0]
color = [0.059, 0.09, 0.165]
corner_radius = 6.0

[entities.components."machina.ui.border"]
color = [0.148, 0.2, 0.282]
thickness = 1.0

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
