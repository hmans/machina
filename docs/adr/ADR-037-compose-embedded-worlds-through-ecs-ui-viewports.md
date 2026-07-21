# ADR-037: Compose embedded worlds through ECS UI viewports

**Date:** 2026-07-21

## Context

Resource inspectors and project tools need real, interactive 3D previews. Reconstructing models as colored UI boxes loses geometry, materials, depth, and perspective, while editor-specific preview drawing would violate Scrapbot's single public ECS UI contract. Embedded views also need to remain correctly ordered, clipped, and scrolled with ordinary UI content without rebuilding the main UI stream or allocating renderer objects every frame.

## Decision

Add the authored public `scrapbot.ui_viewport` component. It targets either a Model resource UUID or a retained World, with optional root and camera entity UUIDs. The component owns declarative orbit, distance, clear color, and interaction policy; the shared retained UI system owns pointer orbit/zoom behavior.

WGPU owns a bounded texture array with one render layer per visible embedded viewport. It renders each target through ordinary geometry/material resources, then the normal UI shader samples that layer as a paint command. This preserves UI paint order, clipping, scrolling, and editor/project parity without per-control pipelines or bind-group switching. Static Model targets retain a cache keyed by component state, aspect ratio, model version, and geometry/material revisions. World targets remain live and render from the retained render list rather than scanning ECS storage.

## Consequences

Projects, Luau, native Odin extensions, and editor composition can use the same embedded viewport component. Model inspectors gain real perspective, lighting, orbit, and zoom, and future scene/minimap/material previews can share the path. The initial backend supports eight simultaneous 512-pixel layers and at most the backend's bounded preview draw capacity; richer sizing, textures, post-processing, and cached live-world invalidation remain future extensions. WGPU is the first implementing backend, while the public component remains backend-independent.
