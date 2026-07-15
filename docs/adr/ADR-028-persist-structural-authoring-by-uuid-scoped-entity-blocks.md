# ADR-028: Persist structural authoring by UUID-scoped entity blocks

**Status:** Accepted
**Date:** 2026-07-15

## Context

Stopped-mode authoring can now create, duplicate, rename, delete, and promote entities as well as add or remove components. Rewriting a complete scene after each Save would produce noisy diffs, discard hand-authored comments, and scale poorly as scenes grow. Field-level patches alone cannot represent entity or component membership changes.

## Decision

Represent each structural editor operation as one UUID-addressed authoring transaction with owned before and after entity snapshots. Apply snapshots directly to the active ECS, preserving the entity UUID and updating existing component slots where possible. Undo and redo use the same bounded history as property and gizmo edits.

Keep dirty UUIDs as conservative candidates. On Save, parse the current scene and compare candidate entities with the active world. If membership and names are unchanged, retain field-level semantic patches. If any structural change exists, scan the source once, preserve every clean entity block verbatim, and serialize only dirty entity blocks. Deleted blocks are omitted; newly authored and explicitly promoted runtime entities are appended in transaction order. Replace the scene atomically.

Promotion changes a runtime entity to scene origin only through an explicit stopped-mode action. Named geometry and material references are resolved when possible; runtime-generated resources are not implicitly converted into project resource declarations.

## Consequences

Large scenes pay one linear source scan at explicit Save rather than per-frame reconciliation or whole-world serialization. Unrelated entities remain byte-for-byte stable, while a structurally changed entity block is normalized to Scrapbot's canonical TOML form. Stable UUIDs make rename, duplicate names, deletion, and history replay unambiguous.

Snapshots own their string and custom-component data, so history eviction, branching, playback-baseline replacement, and editor teardown must destroy them explicitly. Stop preserves authoring history and restores captured component revisions; unrelated structural changes can still invalidate older field transactions through the existing stale-history rules.
