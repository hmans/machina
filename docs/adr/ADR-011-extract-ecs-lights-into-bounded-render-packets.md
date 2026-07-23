# ADR-011: Extract ECS lights into bounded render packets

**Date:** 2026-07-12
**Last amended:** 2026-07-23

## Context

Lights are scene data that systems may create, remove, or animate, but rendering backends need compact, backend-neutral frame input rather than direct access to ECS storage. An initial renderer also needs explicit limits so uniform allocation and shader loops stay predictable.

## Decision

ADR-039 amends the original capacity and backend representation while preserving this ECS-to-renderer ownership boundary.

Represent ambient, directional, and point lights as public engine ECS components. Before rendering, extract alive lights into the retained render list: accumulate ambient contributions, copy bounded directional inputs, and retain a growable compact point-light list with positions taken from transforms. Rendering backends consume this packet and own the GPU representation. The current limits and scalable WGPU representation are specified by ADR-039.

## Consequences

Gameplay systems can query and animate lights through the same ECS used for other scene state, while renderer backends remain independent of world storage. Ambient lights do not require transforms; point lights do. Backends may derive scalable visibility and storage without moving authoritative light state out of ECS.
