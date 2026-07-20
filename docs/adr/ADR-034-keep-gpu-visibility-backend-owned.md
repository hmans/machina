# ADR-034: Keep GPU visibility backend-owned

**Date:** 2026-07-19

## Context

The first WGPU renderer rebuilt per-instance matrix and material arrays on the CPU every frame, capped a frame at 64 instances, and submitted direct indexed draws. ECS render membership was already change-driven and resource ownership was already backend-neutral, but the frame packet forced stable scene data back through a small transient uniform allocation.

GPU-driven rendering needs persistent instance identity, scalable visibility, and indirect draw counts without moving GPU buffers into ECS or making project data aware of a specific backend.

## Decision

Keep ECS responsible for stable render-instance slots, structural dirty tracking, and backend-neutral render data. Let each capable backend own its persistent GPU instance table, visibility buffers, batch metadata, compute pipelines, and indirect arguments.

The WGPU backend retains geometry/material batches and instance-to-LOD batch mappings until world topology or geometry-LOD topology changes. The batch table and its visibility/indirect buffers grow geometrically instead of imposing a fixed batch ceiling. It coalesces nearby changed instance-table slots into bounded uploads, retains compact render and culling uniforms until their values change, computes camera and shadow visibility into separate compacted per-batch slices, and issues one indexed indirect draw per retained batch. Indirect `firstInstance` remains zero; aligned visibility-buffer slices provide batch-local instance indexing without requiring the optional WebGPU `indirect-first-instance` feature.

Run a depth prepass and build a max-depth Hi-Z pyramid when the scene is large enough to amortize it. The compute visibility pass consumes the previous completed pyramid only while the camera matrix and persistent instance records remain unchanged; a camera, transform, render-membership, geometry, material, or LOD change disables occlusion for that frame so stale depth cannot reject visible objects. Bounding spheres remain conservative.

Treat LOD as geometry-resource data, not an entity or backend-specific component. A UUID-backed `scrapbot.geometry_lod` project resource owns an icosphere level chain and descending screen-radius thresholds. ECS entities still reference one stable geometry handle. The persistent GPU instance record carries the resolved alternate batch indices and thresholds, and the visibility shader selects the draw batch from projected screen radius before compaction. The CPU reference path implements the same selection rule.

Use optional WebGPU timestamp queries and asynchronous multi-frame readback rings for per-pass GPU execution time and visibility/LOD counters. Never block the render loop waiting for diagnostic data. A frame without completed readback retains the most recent valid sample.

Keep a CPU implementation of the same bounding-sphere/frustum test as a deterministic correctness oracle. CPU editor picking remains independent because it needs exact triangle hits and entity identity rather than render visibility.

## Consequences

Renderable count and draw-batch count are no longer constrained by the old uniform arrays, steady-state instance data remains resident on the GPU, and frustum, occlusion, LOD, and count work scale on the GPU while ECS and resource boundaries stay portable. Authored LOD changes preserve the base runtime handle and advance a geometry-topology revision so retained batches rebuild without scanning unrelated ECS membership.

The implementation still submits one CPU-known draw per geometry/material/LOD batch because portable WebGPU does not provide core multi-draw-count submission. It retains an explicit backend limit of 131,072 instance slots. Structural topology changes and draw-database growth rebuild batch visibility slices; stable frames do not. Hi-Z currently requires a stable camera for one frame and project-authored geometry LODs currently generate icosphere levels. Imported meshes, offline simplification, bindless materials, meshlets, skinning, and a GPU-authored draw-count submission path remain future work.
