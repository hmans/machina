# FDR-021: Web Export Proof of Concept

**Status:** Active
**Last reviewed:** 2026-07-06

## Overview

The first web export is a browser-player proof of concept. It packages a validated Luau-only Scrapbot project into a web bundle, loads a headless Scrapbot wasm runtime, initializes the packaged scene and scripts, steps script frames in the browser, and draws a lightweight Canvas2D preview from runtime renderable snapshots. Browser WebGPU rendering is still not implemented.

## Behavior

- `scrapbot build [path] --target web` creates a web bundle. `--target host` is the default and preserves the existing host bundle behavior.
- Web bundles contain `index.html`, `player.js`, `scrapbot-web.json`, `project-data.json`, `scrapbot-web-player.wasm`, and a copied `project/` tree.
- `project-data.json` contains the default scene source and script sources so the browser player can initialize without direct filesystem access.
- The generated page loads the manifest, project data, and wasm player when served over HTTP, then reports runtime counters such as entity count, system count, and stepped frame count.
- The canvas draws a Canvas2D preview of runtime renderables from the stepped wasm world. The preview uses projected primitive shapes and scene colors; it is not the final browser renderer.
- Web builds reject projects with `native` or `native_artifact`, because project-local native modules need a future static-link/web SDK path.
- Build text and JSON output report the selected target. Web build output reports the generated browser entrypoint instead of runtime executable and launcher paths.

## Design Decisions

### 1. Ship a headless wasm player before browser rendering

**Decision:** The web export includes a wasm runtime that loads packaged project text, steps scene/script execution, and exposes compact renderable/camera snapshots for the generated JavaScript player to draw with Canvas2D.
**Why:** Runtime portability, project packaging, JavaScript host glue, and browser WebGPU are separate risks. A Canvas2D preview makes web output visually inspectable while keeping browser GPU rendering as a later backend implementation.
**Tradeoff:** The web output can display an approximate scene preview, but it does not use Scrapbot's native renderer pipeline, WebGPU shaders, batching, shadows, or postprocessing.

### 2. Package project text explicitly

**Decision:** Web builds emit `project-data.json` alongside the copied source tree.
**Why:** The wasm player needs a deterministic browser-readable handoff before Scrapbot has a full virtual filesystem package format. Keeping the copied project tree preserves inspectability while `project-data.json` gives the current player a direct bootstrap path.
**Tradeoff:** Scene and script text are duplicated in the bundle until the virtual filesystem design replaces the PoC data file.

### 3. Keep host builds unchanged by default

**Decision:** `host` remains the default build target.
**Why:** Current packaging and verification workflows depend on host bundles, SDL runtime discovery, native artifacts, and launcher scripts.
**Tradeoff:** Users must opt into the web PoC explicitly.

### 4. Reject project-native modules for web

**Decision:** Web PoC builds only support script/project data and reject native modules.
**Why:** The current native module flow builds and loads dynamic libraries. Browsers need a static-link or wasm component strategy that preserves the registered native ECS API without dynamic loading.
**Tradeoff:** Native-heavy projects cannot use the web target until the static-link design exists.

## Related

- **ADRs:** ADR-004, ADR-019, ADR-023
- **FDRs:** FDR-019

## Open Questions

- What file packaging and persistence model should replace `project-data.json`?
- How should project-local native Zig modules participate in restricted targets?
- Should wasm Luau diagnostics use a fuller C++ ABI/exception strategy instead of the current valid-project-only PoC stubs?
