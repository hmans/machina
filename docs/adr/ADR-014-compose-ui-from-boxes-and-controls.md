# ADR-014: Compose UI from boxes and controls

**Date:** 2026-07-13

## Context

Scrapbot's first retained UI slice combined box styling and row, column, or overlay behavior in one layout component. Expanding that model with controls would make one component responsible for geometry, container behavior, content, and future interaction state. UI entities instead need a consistent box model and composable roles that fit the ECS.

## Decision

Every UI entity has one layout component defining its rectangular box, parent, position, size, per-edge margin and padding, optional background, SDF border, corner radius, and hidden state. Hiding a box removes its complete descendant subtree from layout, painting, and interaction without changing entity lifetime. Independent horizontal-stack, vertical-stack, table, panel, text, and button components add container, decoration, or content behavior. An entity without a flow container overlays its children. Overlay children are positioned inside the parent's padded content box. Stacks may opt into proportional fill and draggable gaps; retained split weights change at runtime without mutating scene-authored sizes. Tables place children in row-major order across one or more equal-width columns. Panels reserve an optional title band while remaining compatible with a stack or table child layout.

Pointer hit testing operates on every retained element box. The topmost hit element receives hover state. Primary-button press captures active state on that element until release. These states belong to the element; individual controls decide whether to render or act on them. Buttons are the first consumer through optional hover and active colors.

Backgrounds and inset borders share one signed-distance rounded-rectangle evaluation in the UI fragment shader. Font glyphs continue to use the separately precomputed MTSDF atlas described by ADR-013.

## Consequences

All controls share one predictable box model and interaction state, and new container, decoration, or content roles can be added without growing a single tagged control type. Scene validation must reject conflicting flow containers such as simultaneous horizontal, vertical, or table layout and conflicting content such as text and button labels. Button press feedback is immediate, while activation still depends on the future UI command-event system.
