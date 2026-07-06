# ADR-022: Single-World Render Data Flow

**Date:** 2026-07-06

## Status

Accepted. Supersedes [ADR-013](ADR-013-shared-ecs-for-engine-internal-worlds.md).

## Context

ADR-013 kept the renderer on the shared ECS implementation, but it also introduced a second renderer-owned world that mirrored scene render data every frame. That preserved ECS-shaped render systems, but dense scenes made `scrapbot.render.extract` spend time copying stable mesh, camera, light, and renderer-setting components into an internal world before the next render systems scanned them again.

Scrapbot should keep one authoritative ECS world for scene entities. Engine subsystems may add engine-owned runtime components and keep backend side resources, but scene render state should not be duplicated into a second ECS world just to be consumed by the renderer.

## Decision

Scene-authored render data is resolved directly from the project scene `runtime.World`. Mesh batching, camera selection, lighting, shadow flags, and renderer settings use the scene world as the authoritative source.

The renderer may keep retained side state for GPU resources, render schedules, profiling, and temporary frame snapshots that are not an ECS world of scene clones. Renderable snapshots may be built from the scene world to avoid repeated scans inside a frame, but those snapshots are derived data, not authoritative entity storage.

Frame-local UI/editor overlay data may remain in renderer-owned transient ECS storage while Scrapbot lacks a first-class engine-transient entity lifecycle on the main world. That storage must not mirror scene mesh/camera/light/config data, and it is a compatibility step toward engine-owned transient entities in the single world.

Render draw submission should flow from prepared batch plans and renderer side resources instead of creating draw-command entities in a cloned render world.

## Consequences

- `scrapbot.render.extract` no longer pays to clone stable scene mesh, camera, light, or renderer-setting components each frame.
- Scene render data has one ECS owner, so stale render-world copies cannot diverge from the project world.
- Render systems still have schedule/profiling boundaries, but some systems operate on frame snapshots and renderer side resources instead of queried render-world entities.
- Engine-owned UI/editor overlay entities still need a follow-up migration to a main-world transient lifecycle.
- Backend resources remain outside serialized scene data and scripting APIs.
