# ADR-006: Embeddable Scripting Language for Game Logic

**Date:** 2026-07-01

## Context

Machina needs a way for game projects to define behavior without recompiling the engine. The scripting layer should be text-based, embeddable, suitable for hot reload, and practical for agent-authored gameplay logic.

Candidate languages include Lua, Luau, Wren, and similar small embeddable languages. Lua and Luau have strong game-scripting precedent and broad familiarity. Wren has a clean class-based design and an embedding-oriented implementation. The final language choice affects sandboxing, type checking, binding ergonomics, debugging, packaging, and editor tooling.

## Decision

Machina will support an embeddable scripting language for game logic. The initial implementation will be chosen from the Lua/Luau/Wren family after a focused prototype validates embedding, diagnostics, hot reload, sandboxing, and agent-generated script quality.

Scripts are behavior files, not authoritative scene storage. Scenes and prefabs reference script components, while structural project data remains in engine-defined text formats.

## Consequences

Machina keeps runtime behavior editable and reloadable without requiring native recompilation.

Deferring the exact language avoids locking the project into a scripting runtime before the engine has validated binding and tooling needs.

The engine must design script APIs carefully so they remain stable, testable, and understandable to both humans and agents. Script failures need structured diagnostics that work in both interactive and headless modes.
