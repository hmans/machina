# FDR-003: Pluggable rendering backends

**Status:** Planned
**Last reviewed:** 2026-07-07

## Overview

Pluggable rendering backends allow Scrapbot to start with `wgpu-native` while keeping rendering replaceable enough for offscreen verification, editor viewports, and future experiments.

## Behavior

- The runtime can submit frame data through a renderer boundary.
- The current implementation uses a null renderer for the headless slice.
- The first real backend is planned to use `wgpu-native`.
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

## Related

- **ADRs:** ADR-003
- **FDRs:** FDR-001, FDR-002

## Open Questions

- Should SDL3 or GLFW own the first windowing path?
- What render packet shape should bridge ECS state into renderer-owned resources?
- How soon should offscreen rendering become part of verification?
