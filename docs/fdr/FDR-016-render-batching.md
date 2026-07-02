# FDR-016: Render Batching

**Status:** Active
**Last reviewed:** 2026-07-02

## Overview

Render batching lets Machina draw many scene-authored entities that share compatible geometry and pipeline-affecting render state as a single instanced render batch. It keeps the ECS authoring model simple while giving renderer internals a scalable path for scenes with repeated objects.

## Behavior

- Projects author normal renderable ECS entities with transform, geometry, and material component data.
- The renderer automatically groups renderable entities that use the same built-in geometry primitive settings and compatible pipeline-affecting state.
- Each render batch preserves per-entity transform and base color through instance data.
- Current base-color-only material data does not split batches.
- Shadow caster/receiver state participates in render batch compatibility.
- The render schedule queues one internal draw command per batch, not one command per renderable entity.
- Legacy cube renderables participate in batching after being normalized to box geometry and material data.
- The batching demo example contains many independent animated scene entities that collapse into a small number of render batches.
- Offscreen render verification covers the batching demo as part of the standard test suite.
- Headless benchmark output reports renderable and render-batch counts so batching regressions are visible without opening a window.

## Design Decisions

### 1. Batch below the scene authoring surface

**Decision:** Scene authors continue to create independent ECS entities; batching is an automatic renderer behavior.
**Why:** Authoring, scripting, live reload, and editor tooling should reason about real entities, not renderer optimization groups. This follows ADR-008 and ADR-013.
**Tradeoff:** The renderer must rebuild or validate batch plans when renderable scene data changes.

### 2. Keep per-instance material data out of the key

**Decision:** The current batching key is built-in primitive parameters plus shadow caster/receiver state. Base color is per-instance data and does not split batches.
**Why:** Base color is already carried through the instance buffer, so splitting otherwise-compatible renderables by color creates unnecessary batches without changing visual output. This follows FDR-015 and FDR-017.
**Tradeoff:** Future material properties, mesh assets, textures, and shader variants that affect buffers, bindings, or pipelines will need to become part of the key before they can batch safely.

### 3. Keep batching inside the render ECS schedule

**Decision:** Batches are planned during render preparation and queued as internal render-world draw command entities.
**Why:** Renderer data flow should keep using Machina's shared ECS scheduler instead of reintroducing an ad hoc object list. This follows ADR-013.
**Tradeoff:** GPU buffers remain renderer-owned side resources until Machina has explicit native/internal component storage for non-serializable values.

## Related

- **ADRs:** ADR-004, ADR-008, ADR-013
- **FDRs:** FDR-007, FDR-008, FDR-009, FDR-015, FDR-017

## Open Questions

- How should mesh asset identifiers, material assets, textures, and shader variants extend the batching key?
- Should render diagnostics expose per-batch instance counts, geometry keys, and pipeline keys for editor inspection?
