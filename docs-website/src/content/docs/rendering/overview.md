---
title: Rendering Overview
description: How Machina turns ECS scene data into WebGPU rendering.
---

Machina renders through `wgpu-native` behind an engine-owned renderer boundary.

The public scene authoring model is ECS data:

- `machina.transform`
- `machina.geometry.primitive`
- `machina.material.surface`
- `machina.camera`
- `machina.light.directional`
- `machina.shadow.caster`
- `machina.shadow.receiver`
- UI components such as `machina.ui.rect` and `machina.ui.text`

## Render Flow

Rendering uses an internal render world and render-phase schedule built with the same runtime ECS implementation as game worlds.

Each frame, render systems:

1. Extract renderable scene data into the render world.
2. Prepare mesh resources and instance buffers.
3. Queue mesh draw batches.
4. Process UI interaction state.
5. Prepare UI draw data.
6. Queue UI draw commands.
7. Draw queued meshes and UI.

The editor/debug overlay includes render-system timings from this internal render schedule.

## Headful and Offscreen

Headful runs create a platform window and present to a surface:

```sh
machina run examples/showcase --editor
```

Offscreen rendering writes BMP artifacts:

```sh
machina render examples/showcase zig-out/showcase.bmp
```

Offscreen verification checks for visible rendered content:

```sh
machina render-test examples/showcase zig-out/showcase-render-test.bmp
```

Use offscreen verification before relying on visible-window inspection for renderer changes.

## Camera and Lighting

If a scene provides a camera entity with `machina.transform` and `machina.camera`, the renderer uses it.

If a scene provides a directional light with `machina.light.directional`, the renderer uses it.

Fallback camera and light defaults exist so simple scenes can render before they author explicit camera/light data.

## UI Overlay

UI renders after 3D content as screen-space ECS data. The first UI system supports:

- Canvas markers.
- Rectangles.
- Text labels.
- Button markers.
- Command ids.
- Runtime command events.
- Engine-owned editor/debug overlay.
