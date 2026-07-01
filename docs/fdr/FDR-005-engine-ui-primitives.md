# FDR-005: Engine UI Primitives

**Status:** Planned
**Last reviewed:** 2026-07-01

## Overview

Engine UI primitives provide the controls and layout capabilities needed for runtime overlays, debug tools, and the future editor. They exist so Machina can build tooling with its own rendering and input systems instead of depending on a separate editor application stack.

## Behavior

- The engine can render UI controls in an interactive window.
- UI primitives support common tool surfaces such as panels, buttons, lists, trees, inspectors, property controls, text labels, text inputs, menus, and overlays.
- UI can be used for runtime diagnostics before a full editor exists.
- UI input behavior is integrated with the engine input model.
- UI definitions that are part of projects or tools follow the text-first project model.

## Design Decisions

### 1. Use engine-hosted UI for tooling

**Decision:** Editor and runtime tools are built with Machina UI primitives.
**Why:** This keeps tooling portable and integrated with the engine. It follows ADR-007.
**Tradeoff:** Early editor work depends on maturing an engine UI system first.

### 2. Support debug overlays before full editor panels

**Decision:** The first UI milestone should support runtime diagnostics and inspection overlays.
**Why:** Overlays exercise rendering, input, layout, and engine state presentation with a smaller surface than a full editor.
**Tradeoff:** Overlay-first design must still leave room for complex editor workflows.

## Related

- **ADRs:** ADR-001, ADR-004, ADR-007
- **FDRs:** FDR-001, FDR-003

## Open Questions

- Should the first UI model be retained, immediate, or a hybrid?
- What text editing capability is needed before the editor becomes practical?
