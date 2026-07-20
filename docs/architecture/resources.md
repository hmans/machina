# Resources and Registries

**Last verified:** 2026-07-20  
**Persistent declarations:** `shared.Project_Resource` and `project.load_project_resources`  
**Runtime authority:** `resources.Registry`

Scrapbot resources live outside ECS. Persistent project files use stable UUIDs; ECS components store resolved generational handles into runtime registries. Project resources, transient runtime resources, built-ins, and derived backend caches have different identities and lifetimes.

## Identity layers

| Layer | Identity | Authority | Lifetime |
| --- | --- | --- | --- |
| Project declaration | `Resource_UUID` plus a relative `resources/**/*.resource.toml` source | Project files on disk; in-memory authoring is authoritative until Save/Revert | Survives runs and editor sessions |
| Runtime registry entry | `{index, generation}` handle plus per-entry `version` | `resources.Registry` | One engine runtime; slots may survive reload while generations invalidate dead handles |
| ECS reference | Geometry or Material handle | Active ECS world | Entity/component lifetime; resolved again when a world is rebuilt |
| Backend cache | Handle/generation/version keyed records | Renderer backend | Renderer lifetime; refreshed from exact resource versions/topology changes |
| Font atlas product | Project font name and generated MTSDF files | Project config/source font plus `.scrapbot/cache/fonts` build products | Regenerated product; runtime Font handle is not persistent identity |

## Persistent project resource kinds

<!-- inventory:project-resource-kinds:start -->
| Source kind | TOML `type` | Runtime family | ECS reference | Editor persistence |
| --- | --- | --- | --- | --- |
| `Material` | `scrapbot.material` | Material | `scrapbot.material` | Create, duplicate, rename/move, edit, delete, Undo/Redo, Save/Revert |
| `Geometry_LOD` | `scrapbot.geometry_lod` | Geometry plus internal LOD Geometry entries | `scrapbot.geometry` | Loaded/hot-reloaded and referenceable; full inline authoring is not yet symmetric with materials |
<!-- inventory:project-resource-kinds:end -->

The recursive project loader rejects duplicate UUIDs. Scene validation resolves Material UUIDs and accepts Geometry resource UUIDs for authored LOD geometry. Resource file paths are relative to `resources/`; material textures are safe PNG paths under `assets/`.

## Runtime registry families

<!-- inventory:runtime-resource-families:start -->
| Family | Persistent identity | Runtime identity/versioning | Primary consumers |
| --- | --- | --- | --- |
| `Geometry` | Optional UUID/source when authored; name for transient/built-in registration | `Geometry_Handle`, generation, entry version, registry-wide geometry topology revision | Render-instance extraction, bounds/picking, LOD selection, GPU geometry and draw caches |
| `Material` | Optional UUID/source when authored; name for transient/built-in registration | `Material_Handle`, generation, entry version | Render-instance extraction, material/texture GPU cache, world shading and bloom |
| `Font` | Project-config font name/source; generated atlas is derived | `Font_Handle`, generation, entry version | UI measurement, glyph lookup, MTSDF atlas upload and UI rendering |
<!-- inventory:runtime-resource-families:end -->

## Registration contracts

### Geometry

- Built-in/transient geometry registers by unique name and may be replaced in place only when it is not authored.
- Authored `Geometry_LOD` declarations register by UUID and name. The base entry owns authored identity; additional LOD entries use internal names and handles.
- Content replacement increments the entry version. LOD membership, addition, disappearance, or other batch-shape changes also increment `geometry_topology_revision`.
- Missing authored declarations mark prior entries dead, increment generation/version, and invalidate old handles without compacting registry indexes.
- Render preparation and the WGPU backend consume exact handle/version/topology changes; stable geometry is neither re-extracted nor re-uploaded.
- Source/tests: `resources/resources.odin`; `resources/resources_test.odin`, `render/render_test.odin`.

### Material

- Built-in/transient materials register by unique name and cannot replace an authored material with the same name.
- Authored materials register by UUID, name, and source path. Reload updates an existing UUID in place, preserving its slot/generation while incrementing version.
- Deletion/disappearance marks the entry dead and increments generation/version. Reappearance by UUID reuses its registry slot through the authored registration path.
- Editor history stores deep `Project_Material_Snapshot` values. Save derives create/write/delete files from the disk baseline and dirty UUID candidates.
- Base color, HDR emissive value, or texture changes increment version; backend material/texture caches update only affected entries.
- Source/tests: `resources/resources.odin`, `ui/editor_resource_authoring.odin`, `project_save.odin`; `resources/resources_test.odin`, `project_save_test.odin`.

### Font

- Project config names source fonts. `prepare_project_fonts` builds fixed-size MTSDF atlas/metadata products under `.scrapbot/cache/fonts`.
- Runtime registration validates atlas dimensions, complete supported glyph coverage, ascender, and RGBA8 byte count.
- Re-registering a font name replaces atlas pixels in place and increments entry version; the handle generation remains stable while alive.
- UI retains font-dependent measurement/paint state; changed font resources invalidate their atlas/cache consumers rather than unrelated ECS membership.
- Inter remains the baked fallback when a project font is absent or unavailable.
- Source/tests: `project/fonts.odin`, `resources/resources.odin`, `ui/font_data.odin`; `project/project_test.odin`, `resources/resources_test.odin`, `ui/ui_test.odin`.

## Resolution and invalidation

```text
project resource UUID/name
          │ parse + validation
          ▼
resources.Registry slot ── {index, generation} ──> ECS component
          │ version/topology revision                    │ exact entity dirtiness
          └──────────────────────────────┬───────────────┘
                                         ▼
                             retained render/UI consumer
                                         │ dirty cache entry
                                         ▼
                                   backend GPU cache
```

- A handle is valid only when its index is in range, the slot is alive, and generations match.
- Entry `version` means content at a still-valid identity changed.
- `geometry_topology_revision` means geometry/LOD batch shape may have changed globally.
- Authored UUIDs never become runtime storage indexes in persistent files.
- Resource disappearance must invalidate exact ECS/backend consumers; registry arrays are not compacted merely to remove dead entries.

## Persistence and playback

- **Save** serializes only dirty authored resource UUIDs, validates resulting scene references, and commits scene/resource file changes through one recoverable project transaction.
- **Revert** reloads project resource declarations from disk, updates/deactivates runtime entries, then rebuilds the scene world and rebinds the existing script runtime.
- **Play** captures authored Material base color and emissive values in the in-memory playback baseline alongside authored scene entities.
- **Stop** restores those captured base color/emissive values by UUID and increments a material version only when restored content differs. It does not reread resource files or reload Luau/native code.
- **Hot reload** re-registers fonts, materials, and LOD geometry before replacing the world/runtime. Failed project/world reload keeps or restores the last-good runtime path.

See [Lifecycle matrix](lifecycle.md), [State ownership](state-ownership.md), [FDR-009](../fdr/FDR-009-project-resources.md), and [ADR-030](../adr/ADR-030-identify-project-resources-by-uuid-outside-the-ecs.md).
