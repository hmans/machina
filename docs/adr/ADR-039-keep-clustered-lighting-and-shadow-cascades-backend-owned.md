# ADR-039: Keep clustered lighting and shadow cascades backend-owned

**Date:** 2026-07-22

## Context

The original frame packet placed sixteen point lights directly in a render uniform and rendered one fixed orthographic directional shadow map. That kept the first renderer simple, but it discarded additional authored lights, made fragment cost proportional to every retained point light, and could not preserve useful directional-shadow resolution across a camera's depth range.

ECS light components and their compact active sets remain the authoritative project-facing state. Cluster membership, cascade splits, shadow textures, and per-cascade visibility are renderer-derived data and must not become gameplay state or weaken Odin/Luau access to lights.

## Decision

Keep backend-neutral extraction change-driven and bounded, but raise its point-light packet capacity to 256. Capable backends own the scalable GPU representation.

WGPU uploads changed point-light records into a storage buffer. A cluster-centric compute pass builds deterministic per-cluster light lists for a 16×9×24 view-space grid, with at most 64 point lights per cluster. Each GPU invocation owns one cluster and visits lights in stable packet order; the CPU never calculates cluster membership. The cluster pass reruns only when the camera, viewport, or point-light payload changes.

Render the first directional light through four camera-relative cascades in one depth-texture array. Compute practical logarithmic/uniform splits out to 80 world units, stabilize each light projection to shadow texels, GPU-cull casters independently for every cascade, and select the cascade plus a 3×3 PCF footprint in the world shader. `--cpu-culling` retains a deterministic reference implementation of the same four cascade visibility volumes; it does not replace GPU cluster construction.

Keep all cluster buffers, cascade textures, matrices, visibility lists, indirect arguments, and diagnostics inside WGPU. Public Ambient, Directional, Point Light, Shadow Caster, and Shadow Receiver components remain backend-neutral.

## Consequences

Scenes may use substantially more point lights without evaluating every light in every fragment, and directional shadows retain useful near-camera resolution over larger views. Stable camera/light frames do not rebuild cluster lists, and ordinary ECS membership remains change-driven.

The backend reserves storage for 3,456 cluster counts and 64 indices per cluster, renders four directional shadow passes, and still has explicit limits: 256 extracted point lights, 64 point lights affecting one cluster, four cascades, one shadowed directional light, and an 80-unit shadow distance. Point-light shadows, adaptive cluster dimensions, overflow diagnostics, cascade blending, and user-facing quality settings remain future work.
