# FDR-003: Pluggable rendering backends

**Status:** Active
**Last reviewed:** 2026-07-12

## Overview

Pluggable rendering backends allow Scrapbot to start with `wgpu-native` while keeping rendering replaceable enough for offscreen verification, editor viewports, and future experiments.

## Behavior

- The runtime can submit frame data through a renderer boundary.
- The current implementation supports the null backend.
- Users can select a renderer backend from the CLI.
- The `wgpu` backend opens an SDL3 window, creates a `wgpu-native` surface, and renders ECS cube renderables with a perspective camera.
- The `wgpu` backend can also render a headless final-frame PNG with `--framegrab`.
- The `wgpu` backend currently requires `--window` or `--framegrab`.
- Renderer runs can be limited with `--frames`; windowed `0` means run until the window closes, while headless `0` captures one frame.
- Users can request a short-lived SDL3 window with the null backend for platform smoke checks.
- Future backends should not require scene files or gameplay code to know backend-specific GPU handles.

## Design Decisions

### 1. Start with a null renderer

**Decision:** The initial runtime submits a frame summary to a null renderer.
**Why:** This proves project loading, ECS world construction, and runtime flow before introducing GPU setup. See ADR-003.
**Tradeoff:** It does not verify graphics output yet.

### 2. Make wgpu-native the first real backend

**Decision:** Implement the first headful renderer with `wgpu-native`.
**Why:** It matches the desired WebGPU direction, supports modern native graphics backends, and is available through Odin's vendor bindings. See ADR-003.
**Tradeoff:** WebGPU concepts and validation rules shape the renderer abstraction early.

### 3. Use SDL3 for the first window path

**Decision:** Open platform windows through SDL3.
**Why:** SDL3 is available through Odin's vendor bindings and gives the renderer a portable surface path. See ADR-005.
**Tradeoff:** Headful runtime work now depends on SDL3 being available in development and distribution environments.

### 4. Promote the WGPU smoke path into an ECS cube renderer

**Decision:** The current `wgpu` backend creates a WGSL pipeline, uploads a built-in cube mesh, and draws ECS renderables that have both transform and mesh components.
**Why:** This keeps the renderer driven by ECS state while still avoiding a premature asset, material, or batching system.
**Tradeoff:** Only cube primitives are drawn for now; general mesh, material, and batching work remains follow-up work.

### 5. Keep headless framegrabs on the same render path

**Decision:** Headless WGPU renders the same ECS cube pipeline into an offscreen texture, reads the final frame back to CPU memory, and writes a PNG.
**Why:** This gives agents and tests a visual artifact that exercises the same scene-driven renderer path as the windowed backend.
**Tradeoff:** On macOS, the current implementation creates a hidden SDL3 window for Metal adapter bootstrap even though the captured frame is rendered offscreen.

### 6. Use ECS renderable queries as the first backend boundary

**Decision:** The world builder records per-entity component indexes and derives renderables from entities with both transform and mesh components. ECS builds a short-lived render list from those renderables, and render backends consume that list instead of reconstructing component relationships themselves.
**Why:** Backends need coherent scene instances, not just global component counts, and this keeps GPU code out of ECS storage.
**Tradeoff:** The render list is deliberately narrow and will need to evolve into a fuller render packet or view once materials, lights, multiple mesh types, and culling exist.

### 7. Share geometry and material resources by handle

**Decision:** Keep full geometry and material descriptions outside entity storage and let ECS components reference them with generational handles, as established by ADR-010. Primitive helpers produce ordinary indexed geometry rather than backend-specific primitive markers.
**Why:** Many entities should share one CPU description and one backend GPU allocation without putting GPU ownership into the ECS.
**Tradeoff:** Rendering needs an explicit reconciliation step and backend resource caches before the current cube-only path can be retired.

## Related

- **ADRs:** ADR-003, ADR-005, ADR-010
- **FDRs:** FDR-001, FDR-002

## Open Questions

- What render packet shape should replace the current cube render list once renderer-owned resources exist?
- How should offscreen render output be compared once scene rendering exists?
- How long should the headful runtime loop live before the editor and game loop exist?
