# Architecture Inventory

**Last verified:** 2026-07-20

This directory is the source-oriented map of Scrapbot's current architecture. It answers what exists, where it lives, who owns it, and how it changes. It does not replace ADRs, which explain durable decisions, FDRs, which describe feature behavior and rationale, or the public documentation website.

## Documentation boundary

| Fact | Authority |
| --- | --- |
| Registered names, reflected fields, lifecycle, ownership, and fixed phase order | Odin source and runtime descriptors |
| Producers, consumers, invalidation, execution boundaries, implementation and test anchors | This architecture inventory |
| Public TOML/Luau/native usage, fields/defaults, constraints, and examples | `docs-website/` |
| Durable rationale | ADRs |
| Supported feature behavior | FDRs |

Do not introduce a hand-maintained schema catalog beside the registry. Automated documentation should extract machine facts from source or a compiled engine schema interface, then combine them with the audience-specific prose owned here or on the public website.

## Inventory

- [Engine systems](systems.md): profiled engine frame phases, execution order, and scheduling boundaries.
- [Components](components.md): engine component registry, ownership, lifecycle, and project availability.
- [State ownership](state-ownership.md): authoritative state, derived structures, invalidation, and stable-frame expectations.
- [Data flows](data-flows.md): project loading, frame execution, mutation, rendering, and authoring persistence.
- [Source map](source-map.md): package and top-level file responsibilities.

## Maintenance

Use the `scrapbot-architecture-inventory` skill when changing or auditing engine systems, component registration, ownership boundaries, lifecycle/invalidation, frame ordering, package responsibilities, or major data flows. Run:

```sh
node .agents/skills/scrapbot-architecture-inventory/scripts/check_inventory.mjs
```

The audit enforces exact membership for the engine-system and engine-component tables. The other pages require source-first review because their relationships cannot be validated from names alone.

Keep these pages present-tense and compact. Put rationale in `docs/adr/`, detailed behavior in `docs/fdr/`, public API reference in `docs-website/`, and roadmap status in `README.md` or `docs/TODO.md`.
