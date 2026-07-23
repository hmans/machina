# ADR-029: Postprocess the HDR world before UI composition

**Date:** 2026-07-16

## Context

Bloom needs scene brightness above display white, but the original geometry shader tone-mapped each object directly into the presentation target. That discarded HDR information before a screen-space effect could use it. Applying bloom after all drawing would also blur editor and project UI, making text and controls less legible.

## Decision

Render world geometry into a linear floating-point HDR target. Reconstruct view-space positions and normals from the existing scene-depth prepass, evaluate ambient occlusion at half resolution, and apply separable depth-aware bilateral blur. Build a five-level filtered bloom pyramid, apply contrast-adaptive FXAA to the HDR world, composite ambient visibility and the bloom scales, and tone map once into the presentation target. Render project UI, gizmos, and editor chrome afterward as an ordinary display-referred overlay.

Keep emissive radiance in shared material resources and all intermediate textures, pipelines, and bind groups in the WGPU backend.

## Consequences

Emissive colors can exceed display white and create stable bloom without depending on scene lights. Broad multi-scale halos retain saturated color, geometry edges receive inexpensive postprocess antialiasing, and depth-reconstructed ambient occlusion adds contact and crevice grounding without another geometry pass. Its bilateral blur rejects depth discontinuities instead of smearing silhouettes. UI remains crisp and unaffected by world postprocessing. Headless framegrabs exercise the same composite path as visible windows.

The backend owns several size-dependent floating-point bloom textures, half-resolution ambient-occlusion textures, compute bind groups, and a final composite pass. Window resize or replacement of the sampled depth target must rebuild the affected bindings. Ambient-occlusion, exposure, bloom, and antialiasing controls still need an explicit project-facing post-processing surface. Consolidating compute work avoids the command-finalization cost of many short render passes.
