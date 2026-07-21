# ADR-035: Model runtime input as ECS singletons

**Date:** 2026-07-21

## Context

SDL input was consumed directly by editor camera and UI code. Projects had no backend-neutral gameplay input, and adding another consumer would have created another platform-specific event path. Ordinary entity storage is the wrong place for process-wide keyboard and pointer snapshots because a synthetic entity would perturb scene indices, counts, persistence, and authoring.

## Decision

Register `scrapbot.keyboard_input` and `scrapbot.pointer_input` as engine-owned, derived singleton components stored once on the ECS World. They are scheduler-visible component resources, not entity-attached components: systems declare read access to express ordering, but cannot query, author, add, remove, persist, or mutate them.

Sample the platform once at the frame boundary before project systems run. Publish held state plus press/release edges for backend-neutral physical key names, and pointer availability, capture, pixel position/delta, wheel delta, and button edges. Null/headless execution publishes an unavailable zero snapshot. Tests may inject a complete snapshot through the renderer frame configuration without OS automation.

Expose the same authoritative snapshot through Luau and the native extension ABI. Keep UI text/navigation input and editor shortcut interpretation as downstream consumers; they do not own gameplay input state. Future action mapping and controllers must derive from or extend these singleton resources rather than introduce a parallel event bus.

## Consequences

Every system in a frame sees one coherent input snapshot, held and edge queries are deterministic, and input access participates in scheduling without allocating or scanning entity slots. The initial slice intentionally exposes keyboard and pointer only. Text composition, action maps, rebinding, controller devices, and input consumption/focus policy remain later layers.
