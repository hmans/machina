# FDR-008: Editor shell

**Status:** Active
**Last reviewed:** 2026-07-14

## Overview

The editor shell turns a running Scrapbot project into its own editing workspace without stopping play. It keeps the project visible in the center while transient editor-origin ECS UI entities provide the surrounding tools.

## Behavior

- A windowed WGPU project starts with editor chrome hidden unless `--editor` is passed.
- Pressing `Ctrl+Esc` toggles the editor shell without restarting or pausing the project.
- The shell provides a top bar, bottom status bar, left scene sidebar, and right entity/component inspector sidebar.
- The vertical boundaries around the project viewport are draggable. Resizing either sidebar preserves a minimum center viewport and the center automatically fills the remaining width.
- Editor chrome uses neutral near-black and charcoal surfaces, gray-to-white text, quiet gray selection, and restrained mint accents for a dense professional tool aesthetic.
- Header bands, inspector surfaces, viewport seams, and selection use the shared ECS box border fields; pooled browser rows use hidden subtrees rather than leaving the ECS lifecycle.
- The running project's world and project-authored UI always share the complete available viewport. With the editor closed that is the full window; with the editor open it is the remaining center workspace.
- Editor chrome and the project viewport follow the current drawable size when the window is resized. The camera derives its aspect ratio from the live viewport instead of enforcing a fixed ratio.
- Visible windows request a native high-pixel-density backbuffer. Editor chrome keeps logical dimensions while text and controls paint at the display's physical pixel density.
- Project pointer coordinates are remapped into the project viewport, and pointer interaction is unavailable over editor chrome.
- Opening the editor creates an editor-origin scene camera entity with Transform, Camera, and Editor Scene Camera components. Its initial view matches the project's camera, but subsequent editor navigation does not mutate the project camera.
- Holding the right mouse button inside the viewport captures relative pointer input. While captured, mouse movement changes pitch and yaw, WASD moves along the view, Space moves up, and Ctrl moves down.
- Releasing the right mouse button restores normal pointer interaction. Closing and reopening the editor preserves the scene-camera viewpoint for the current run.
- Project cameras derive their view direction from transform rotation, and rendering, viewport picking, and transform gizmos use the same camera orientation.
- The scene sidebar lists scene-authored and runtime-spawned entities and supports pixel-continuous pointer-wheel and trackpad scrolling, clipped partial rows, hover, and stable selection.
- Scene-authored entity names use normal white editor text and runtime-spawned entity names use muted gray. Editor-origin entities are hidden from the browser and cannot be selected in the inspector.
- Selection follows the entity's generation-aware identity and clears if that entity despawns.
- The inspector shows the selected entity's name, identity, provenance, attached components, field names, and current values. Components are vertically stacked titled panels, and each panel renders its fields in a two-column property table inside an independently scrollable sidebar.
- Entity membership, names, status counts, and formatted inspector values refresh from the running world every 200 ms. Opening the editor or changing selection refreshes immediately; hover, scrolling, picking, and gizmo input remain frame-rate responsive.
- The scene browser and component inspector have independent pixel offsets and targets, frame-time smoothing without row or field snapping, clipping, and proportional scrollbars. Selecting a different entity resets the inspector to its beginning.
- Clicking rendered geometry in the live viewport selects the nearest intersected entity using the active camera and current viewport dimensions.
- Viewport selection reveals the entity in the scene browser; clicking empty viewport space clears selection.
- A selected entity with a Transform displays a transform gizmo in the viewport. W selects world-axis translation rails, E selects axis rotation rings, and R selects scale rails with square handles.
- Move and scale modes include XY, XZ, and YZ plane walls. Their center handle provides camera-plane free translation in move mode and uniform XYZ scaling in scale mode.
- The editor expresses gizmo ownership as a transient `EditorTransformGizmo` component on the selected entity; changing selection or closing the editor removes it.
- Hovering emphasizes the nearest axis, plane, or center handle. Dragging captures the pointer and updates position, rotation, or scale according to the gizmo's ECS-visible mode. Mode shortcuts are ignored during RMB fly-camera capture.
- Gizmo changes affect the running world only; scene persistence, snapping, and undo are not part of this slice.
- Headless WGPU runs can combine `--editor` with `--framegrab` for deterministic editor-shell screenshots.

## Design Decisions

### 1. Make editing a mode of `run`

**Decision:** Toggle editor chrome around the same runtime launched by `scrapbot run` instead of introducing a separate editor executable.
**Why:** The editor should inspect the actual running world, systems, renderer, and hot-reload lifecycle rather than a parallel simulation.
**Tradeoff:** Tool and game input routing must coexist in one window.

### 2. Build chrome from transient ECS UI

**Decision:** Construct editor chrome as transient `.Editor` entities with the same UI components and retained reconciler as project UI, following ADR-021.
**Why:** The editor should prove the ECS UI system while retaining a distinct lifecycle, coordinate domain, paint order, and internal semantic bindings.
**Tradeoff:** The world contains editor UI entities, so project-facing browsers, inspectors, counts, and selection paths must filter by origin.

### 3. Use all available game space

**Decision:** Use the entire available rectangle for world projection, project UI, clipping, and pointer remapping, whether editor chrome is visible or not.
**Why:** The game should adapt to the actual window or workspace aspect ratio rather than wasting space through letterboxing.
**Tradeoff:** Until project UI gains responsive anchors and sizing policies, its 1280×720 logical coordinates scale to the live viewport dimensions.

### 4. Show authored and ephemeral entities together

**Decision:** Present one live entity list while distinguishing scene-authored and runtime-spawned entities by name color according to ADR-016.
**Why:** Debugging the running world requires access to ephemeral entities, while provenance tells users which entities belong to source data and which exist only in the current run.
**Tradeoff:** A busy runtime can produce a long, rapidly changing list, so search, grouping, and hierarchy remain important follow-up work.

### 5. Keep initial inspection read-only

**Decision:** Selection exposes component fields and live values without allowing mutation yet.
**Why:** This makes the inspector useful for debugging while avoiding premature commitments around validation, persistence, and undo semantics.
**Tradeoff:** Users can diagnose current world state but cannot change it from the inspector yet.

### 6. Pick exact rendered triangles

**Decision:** Use nearest CPU triangle-ray intersections for initial viewport picking, following ADR-017.
**Why:** Exact geometry picking matches transformed meshes more closely than screen-space bounds and avoids a GPU readback pipeline at this stage.
**Tradeoff:** Picking work grows with triangle count until a broad phase or GPU identity pass is introduced.

### 7. Keep manipulation handles screen-legible

**Decision:** Reconcile an engine-owned gizmo component onto the selected entity, then let a dedicated editor system project fixed-apparent-size translation rails, rotation rings, or scale rails and manipulate the chosen Transform axis, following ADR-018.
**Why:** Tool ownership remains ECS-visible—including in the component inspector—while the controls stay consistently hittable and separate from serialized project components and lighting.
**Tradeoff:** The gizmo supports single-axis, two-axis plane, free camera-plane translation, axis rotation, per-axis scaling, and uniform scaling without local orientation switching, persistence, snapping, or undo.

### 8. Give the editor an ECS-owned scene camera

**Decision:** Use a transient editor-origin entity for the scene camera and run captured fly navigation through a dedicated ECS system, following ADR-019.
**Why:** The camera remains inspectable and composable without mutating the project's gameplay camera or hiding tool state inside the renderer.
**Tradeoff:** The world contains engine-owned entities during editing, so provenance and camera selection must explicitly distinguish project and editor ownership.

### 9. Reserve color for identity and state

**Decision:** Build editor hierarchy from neutral dark surfaces and legible gray text, using Scrapbot mint as a thin identity and status signal rather than a panel tint.
**Why:** Low-chroma chrome keeps attention on live project content and dense inspection data while retaining a recognizable Scrapbot accent.
**Tradeoff:** Provenance and gizmo colors remain intentionally saturated semantic exceptions and must continue to meet contrast requirements.

### 10. Snapshot inspection data at tool cadence

**Decision:** Rebuild the scene-browser and formatted component-inspector snapshots at 5 Hz, with immediate refreshes when the editor opens or selection changes, while repainting and processing interaction every frame.
**Why:** World scans and value formatting do not need render-frame precision, but pointer feedback and manipulation do.
**Tradeoff:** Passive entity and field changes can take up to 200 ms to appear in the editor.

### 11. Reuse split-group layout behavior for workspace panes

**Decision:** Drive the editor's left, center, and right allocation through an editor-origin fill-enabled UI stack with draggable separators.
**Why:** Sidebars need direct manipulation and automatic center fill, and using the ordinary stack behavior proves that the same component works for application-scale layouts.
**Tradeoff:** Pane sizes persist only for the current run; project-level workspace persistence remains future work.

### 12. Compose inspection from reusable panel and table entities

**Decision:** Pool editor-origin panel, table, and text-cell entities and rebuild their values at the editor's snapshot cadence.
**Why:** Dogfooding the public UI primitives gives components real visual hierarchy and makes future editable property controls a cell-level evolution instead of a multiline-text rewrite.
**Tradeoff:** The initial property tables use two equal-width columns and read-only text cells; configurable proportions and editors come later.

## Related

- **ADRs:** ADR-003, ADR-005, ADR-014, ADR-016, ADR-017, ADR-018, ADR-019, ADR-021
- **FDRs:** FDR-001, FDR-003, FDR-007

## Open Questions

- How should editor edit commands cross into the running ECS?
- Which panel layout and sizing state should persist per project?
- How should editor camera speed, bookmarks, and focus-selection navigation persist?
