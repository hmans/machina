# ADR-029: Postprocess the HDR world before UI composition

**Date:** 2026-07-16

## Context

Bloom needs scene brightness above display white, but the original geometry shader tone-mapped each object directly into the presentation target. That discarded HDR information before a screen-space effect could use it. Applying bloom after all drawing would also blur editor and project UI, making text and controls less legible.

## Decision

Render world geometry into a linear floating-point HDR target with an eight-sample subpixel projection-jitter sequence. Reconstruct view-space positions and normals from the existing scene-depth prepass, evaluate a per-pixel rotated ambient-occlusion pattern at half resolution, and cross both separable blur and full-resolution upsampling only through depth-similar neighbors. Fold that ambient visibility into the current HDR signal before resolving it into retained history. The temporal resolve reconstructs world position from depth, reprojects through the previous camera, rejects mismatched previous depth, clamps retained color to the current 3×3 neighborhood, and reduces history weight during screen-space motion. Camera cuts, world replacement, output resize, and depth-target replacement invalidate history. Keep frustum/Hi-Z culling on the unjittered camera so the sample sequence cannot change visibility.

Write one additional floating-point surface target during world shading with octahedrally encoded view-space normal, filtered roughness, and metallic. When enabled, screen-space reflections reconstruct each visible surface from depth, reflect the camera ray, march a bounded path through the same depth buffer, and sample current-frame HDR color only for depth-confirmed hits. Fade hits by material roughness, Fresnel response, distance, and screen edge before feeding them into temporal resolution. Do not apply the effect to project UI, gizmos, or editor chrome.

Build a five-level filtered bloom pyramid from the temporally resolved HDR world, composite the bloom scales, and tone map once into the presentation target. Render project UI, gizmos, and editor chrome afterward as an ordinary display-referred overlay.

Make temporal antialiasing, current-frame fast antialiasing, ambient occlusion, screen-space reflections, and bloom authored fields of `scrapbot.camera`. The active project camera owns the view policy. While the editor fly camera supplies an editor viewport's pose and lens, it inherits the active project camera's exposure and render-feature switches so live inspector edits remain visible. TAA takes precedence over fast antialiasing when both switches are on. A disabled feature must avoid its unnecessary jitter, history copy, or compute dispatch rather than merely hiding its output.

Keep emissive radiance in shared material resources and all intermediate textures, pipelines, and bind groups in the WGPU backend.

## Consequences

Emissive colors can exceed display white and create stable bloom without depending on scene lights. Broad multi-scale halos retain saturated color, temporal supersampling stabilizes subpixel geometry and texture detail during camera motion, and depth-reconstructed ambient occlusion adds contact and crevice grounding without another geometry pass. AO rotates a low-discrepancy view-space sample pattern per pixel, uses squared radius falloff, and crosses both half-resolution blur and full-resolution upsampling only through depth-similar neighbors. This prevents coherent screen-space bands and silhouette leakage before AO joins the temporally resolved world color. SSR supplies responsive local reflections without probes or ray tracing, but cannot recover off-screen, occluded, or previously visible radiance; confidence fades make those omissions explicit. Depth rejection and neighborhood clamping bound disocclusion history; moving geometry without motion vectors may still lose accumulation or show limited residual ghosting. UI remains crisp and unaffected by world postprocessing. Headless framegrabs exercise the same deterministic jitter and composite path as visible windows.

The backend owns full-resolution surface/reflection/resolved/history color and depth textures, several size-dependent floating-point bloom textures, half-resolution ambient-occlusion textures, compute bind groups, and a final composite pass. Window resize or replacement of the sampled depth target rebuilds the affected bindings and rejects stale history. Camera fields now provide coarse feature switches and exposure; AO radius/intensity/quality, SSR distance/thickness/roughness/quality, bloom threshold/intensity/scatter, temporal history/quality, and automatic exposure remain future authored controls. Consolidating compute work avoids the command-finalization cost of many short render passes.
