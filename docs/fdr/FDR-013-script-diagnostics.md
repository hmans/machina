# FDR-013: Script Diagnostics

**Status:** Active
**Last reviewed:** 2026-07-01

## Overview

Script diagnostics report Luau and script-ECS failures in a form that humans, command-line workflows, editor UI, and coding agents can act on. The feature exists so invalid script edits point back to the relevant stage, file, system, and error message without requiring a restart or manual debugger session.

## Behavior

- Project validation can report script diagnostics for invalid Luau source or invalid script ECS declarations.
- Live script reload can report why a changed script failed while keeping the last known good script program active.
- Runtime system failures can report the failing system id and source script path when available.
- Diagnostics identify the failure stage as load, registration, schedule, or runtime.
- Diagnostics include a human-readable message from Luau or the engine validation layer.
- Successful subsequent operations clear stale live diagnostics.
- Command-line commands render diagnostics as text.
- The diagnostic model is intended for future editor panels and machine-readable output.

## Design Decisions

### 1. Keep diagnostics structured below the CLI

**Decision:** The runtime stores diagnostics as structured data and leaves text formatting to command surfaces.
**Why:** The same failure needs to serve stderr output, editor UI, automated tests, and future machine-readable modes. This follows ADR-011.
**Tradeoff:** Callers must manage diagnostic ownership instead of receiving only a simple error code.

### 2. Track failure stage explicitly

**Decision:** Diagnostics include the stage where the failure occurred: load, registration, schedule, or runtime.
**Why:** "Invalid script" is too broad. Knowing the stage tells the user whether they broke Luau syntax, ECS declarations, dependency scheduling, or executing system logic.
**Tradeoff:** New script lifecycle stages must be added deliberately when the scripting pipeline grows.

### 3. Preserve last-known-good runtime state

**Decision:** Failed script validation or reload reports diagnostics but does not replace the active script program. Runtime failures report diagnostics for the frame without corrupting component state.
**Why:** Live reload should be repairable in place. This follows ADR-009 and ADR-011.
**Tradeoff:** The runtime must retain diagnostic state separately from active game state.

### 4. Start with path and system identity before full source spans

**Decision:** Initial diagnostics include script path, system id when relevant, stage, and message, but not precise line and column spans yet.
**Why:** These fields unblock the current debugging loop and establish the ownership model. Source ranges and stack traces can extend the same structure later.
**Tradeoff:** Syntax errors still rely on Luau's message text for line details until source location fields are promoted.

## Related

- **ADRs:** ADR-001, ADR-006, ADR-009, ADR-011
- **FDRs:** FDR-010, FDR-011

## Open Questions

- What stable diagnostic codes should Machina expose for editor and agent tooling?
- How should Luau stack traces and source spans be represented?
- Should headless commands support JSON diagnostics output?
