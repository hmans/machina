---
title: CLI Reference
description: Current Scrapbot command-line interface.
---

All commands run against a project directory. When omitted, the project path defaults to the current directory.

## Machine-readable output

`init`, `check`, `build`, and `run` accept `--json`. JSON mode emits exactly one document to stdout and suppresses project log lines:

```json
{
  "schema_version": 1,
  "command": "check",
  "ok": false,
  "diagnostics": [
    {
      "code": "SCRAPBOT_CHECK_FAILED",
      "severity": "error",
      "message": "failed to read project.toml",
      "path": "my-game"
    }
  ],
  "result": {}
}
```

Diagnostic codes are stable automation identifiers. Messages remain human-readable context. Successful command envelopes have an empty diagnostics array and command-specific result fields.

## `scrapbot init`

```sh
scrapbot init [path] [name] [--json]
```

Creates a project with:

- `project.toml`
- `scenes/main.scene.toml`
- `scripts/main.luau`
- `types/scrapbot.d.luau`
- `.vscode/settings.json`

## `scrapbot build`

```sh
scrapbot build [path] [--json]
```

Builds native extension targets declared in `project.toml` into `build/extensions`.

## `scrapbot check`

```sh
scrapbot check [path] [--json]
```

Performs project validation:

- reads `project.toml`;
- builds declared native extensions;
- loads native extension schemas and system declarations;
- builds the ECS world from the default scene;
- executes `scripts/main.luau` silently to collect schemas and systems;
- validates scene component data against the registry;
- refreshes `types/scrapbot.d.luau`;
- runs `luau-analyze` when available.

## `scrapbot run`

```sh
scrapbot run [path] [--backend null|wgpu] [--window] [--hot-reload] [--scheduler-trace] [--frames n] [--framegrab out.png] [--json]
```

Runs a project through the selected renderer backend after stepping registered native and Luau systems.

Options:

| Option | Meaning |
| --- | --- |
| `--backend null` | Use the headless null renderer. |
| `--backend wgpu` | Use the WebGPU renderer. |
| `--window` | Open a platform window. |
| `--headless` | Force headless mode. |
| `--hot-reload` | Poll project files, scripts, and native extension source/output changes while running. |
| `--scheduler-trace` | Print native worker count, parallel stage count, and maximum stage width. |
| `--frames n` | Limit renderer frames. |
| `--framegrab out.png` | Write the final headless WGPU frame to a PNG. |
| `--json` | Emit one versioned machine-readable result. |

## `scrapbot help`

```sh
scrapbot help <command>
scrapbot --version
```

Prints generated command help or the engine version.
