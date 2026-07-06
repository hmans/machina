# ADR-023: Internal Renderer Backend Boundary

**Date:** 2026-07-06

## Context

Scrapbot's first renderer is built on `wgpu-native`, SDL-backed presentation, and offscreen native WebGPU rendering. Web exports need a browser player path where windowing, frame driving, file loading, and GPU access are different. Reusing the engine's ECS render extraction and scene/render components is still desirable, but binding every renderer module directly to the native backend makes browser work look like a full fork.

## Decision

Scrapbot introduces an internal renderer backend model with `native_wgpu` as the default backend and `web_poc` as the browser export proof-of-concept backend.

The current native renderer implementation lives in `src/render/native_wgpu.zig`. `src/render/engine.zig` remains the stable facade for existing imports and re-exports the native backend surface while exposing the backend enum.

This is not a public renderer plugin API. Scene data, ECS extraction, UI layout, editor render data, camera/config handling, and render validation stay engine-owned. Backend selection is an internal runtime/build concern so Scrapbot can add browser WebGPU without exposing native `wgpu` or browser APIs to projects.

## Consequences

Existing host rendering behavior remains unchanged while the source layout now has a place for browser-specific rendering and presentation work.

The facade has explicit re-export boilerplate until the renderer surface is narrowed further. Future slices should reduce what `src/render/engine.zig` needs to expose instead of expanding a public backend contract.

The first web export now uses the `web_poc` backend for a wasm player that steps scene/script runtime data and draws a Canvas2D preview from runtime renderable snapshots. Browser WebGPU rendering, full virtual filesystem packaging, and project-native static linking remain future work.
