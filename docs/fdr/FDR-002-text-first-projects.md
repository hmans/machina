# FDR-002: Text-first projects

**Status:** Active
**Last reviewed:** 2026-07-10

## Overview

Text-first projects let users run Scrapbot from an ordinary project directory containing a manifest and scene files. The format is meant to be inspectable and editable by humans and agents.

## Behavior

- A project has a `project.toml` manifest in its root directory.
- The manifest names the project and points at a default scene.
- The default generated scene lives at `scenes/main.scene.toml`.
- Scene files describe entities and known components in TOML.
- Project validation rejects missing manifests, unsafe scene paths, malformed project metadata, malformed scene data, unknown namespaced scene components, and scene data that does not match project Luau component schemas.
- Project validation refreshes generated Luau type definitions from the component registry.
- Example project directories live under `examples/` and can be used for smoke verification.

## Design Decisions

### 1. Use project.toml as the manifest

**Decision:** The project manifest is named `project.toml`.
**Why:** The name is short, conventional, and not tied to a prior engine name. See ADR-002.
**Tradeoff:** Generic filenames can collide with other tools in unusual project layouts, though this is unlikely for game project roots.

### 2. Start with a narrow TOML subset

**Decision:** The runtime currently parses only the schema subset Scrapbot generates.
**Why:** The first slice needed a small project contract without taking a dependency decision on a TOML parser. See ADR-002.
**Tradeoff:** Hand-authored files that use valid TOML features outside the subset may fail validation.

### 3. Validate scene components through the registry

**Decision:** `scrapbot check` validates dotted scene component names against the engine component registry and executes `scripts/main.luau` silently to collect project-level component schemas.
**Why:** Dotted names are reserved for engine and library components, and project component data is only meaningful if the script declares a matching schema.
**Tradeoff:** Project scripts should keep top-level work limited to registration and other check-safe setup. Future third-party libraries need a registration mechanism before their dotted component names can pass project validation.

## Related

- **ADRs:** ADR-002
- **FDRs:** FDR-001, FDR-004

## Open Questions

- Should Scrapbot adopt a full TOML parser or publish a formal supported scene subset?
- How should scene migrations be represented once project files evolve?
