---
name: scrapbot-architecture-inventory
description: Maintain and audit Scrapbot's source-oriented architecture inventory in docs/architecture. Use when adding, removing, renaming, or changing engine systems, component registrations, component ownership/lifecycle, project resources, runtime registries, UUID/handle/version semantics, load/spawn/playback/persistence/hot-reload lifecycles, authoritative or derived state, dirty queues/revisions/caches, frame/render/UI data flows, package responsibilities, or architectural documentation; also use for architecture overviews and inventory drift audits.
---

# Scrapbot Architecture Inventory

Keep `docs/architecture/` an accurate present-tense map from architectural concepts to source. Treat it as orientation and ownership documentation, not as a substitute for ADR rationale, FDR behavior, public API reference, or roadmap status.

## Workflow

1. Read `AGENTS.md`, `docs/architecture/INDEX.md`, and the inventory pages relevant to the task.
2. Trace the changed behavior from canonical source before editing prose. Do not infer architecture from names, screenshots, or old records when code can answer it.
3. Update every affected inventory page in the same change:
   - `systems.md` for engine profile phases, frame order, scheduler boundaries, execution ownership, inputs/outputs, stable-frame behavior, backend/thread boundaries, or tests.
   - `components.md` for registry membership, ownership, storage kind, lifecycle, producers/consumers, invalidation, public availability, or tests.
   - `resources.md` for persistent resource kinds, runtime registries, UUID/handle/version semantics, persistence, hot reload, or cache consumers.
   - `lifecycle.md` for project load, entity/component lifecycle, playback, Save/Revert, hot reload, world replacement, or shutdown boundaries.
   - `state-ownership.md` for authoritative state, derived structures, invalidation, lifetime, or stable-frame work.
   - `data-flows.md` for project load, simulation, ECS mutation, render/UI extraction, playback, or persistence paths.
   - `source-map.md` for package/file responsibilities or dependency direction.
4. Update each touched page's `Last verified` date. Keep source anchors current and link to ADRs/FDRs/public docs instead of copying their detailed rationale or field inventories.
5. Run `node .agents/skills/scrapbot-architecture-inventory/scripts/check_inventory.mjs`.
6. When components change, also run the canonical public component audit from `scrapbot-feature-development`. When public behavior changes, update/build `docs-website/` normally.
7. Review the diff for statements the script cannot verify: execution order, ownership, invalidation, stable-frame behavior, and dependency direction.

## Inventory Rules

- Keep the marked system/component tables exact and complete; the audit compares them with source.
- Keep exactly one standardized detail entry for every registered engine component and fixed engine system. Preserve all required labels so coverage remains machine-checkable.
- Describe engine systems as profiled execution phases unless they are actually scheduler registrations. Keep dynamic native/Luau project systems out of the fixed engine table.
- Distinguish authored, public read-only derived, and internal derived components.
- Distinguish persistent project-resource UUIDs, runtime generational handles, per-entry content versions, registry topology revisions, and backend cache identity.
- Keep the lifecycle matrix explicit about which state is retained, rebuilt, rebound, persisted, or rolled back at every boundary. Record partial rollback behavior as a current limitation rather than implying stronger transactions than source provides.
- Name both the authoritative owner and the invalidation/lifetime mechanism for derived state.
- Treat code as authority for names, fields, lifecycle, phase order, and ownership. Do not create a manually maintained JSON/YAML mirror. Prefer extracting structured facts from source or a compiled engine schema command.
- Keep engineering contracts in `docs/architecture/`: producers, consumers, invalidation, execution/backend boundaries, and source/test anchors. Keep public authoring syntax, exhaustive fields/defaults, constraints, and examples in `docs-website/`. Link instead of copying across the boundary.
- Preserve the change-driven invariant: do not document a full stable-frame scan/rebuild as normal unless an ADR/FDR explicitly accepts it.
- Prefer stable package/procedure anchors over line numbers.
- Remove stale entries rather than leaving historical notes. History belongs in Git and decision records.

## Audit Scope

The bundled script enforces:

- exact engine-system names and order from `engine_system_profile_name`;
- exact engine-component names and order from `init_registry`;
- one labeled engineering-contract entry per engine system and component;
- authored/derived component lifecycle and user-availability classification;
- exact public-component membership in the website's canonical inventory;
- exact project-resource kinds and runtime resource-registry families from source;
- coverage of the required load, entity, playback, persistence, hot-reload, and shutdown boundaries;
- presence and index linkage of all required architecture pages.

It intentionally cannot prove prose-level responsibilities or data flow. Audit those against source manually.
