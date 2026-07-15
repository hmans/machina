# ADR-027: Use authoring transactions for editor changes

**Date:** 2026-07-15

## Context

ADR-022 introduced bounded undo for numeric inspector gestures, but editor changes now also include booleans, transform gizmos, dirty tracking, and scene persistence. Treating these as separate mechanisms would duplicate target identity, gesture boundaries, and before/after values. Using undo history itself as the persistence source would also be unsafe: history is bounded, edits can be reverted, Save should retain undo, and future changes may not all share the same history lifetime.

## Decision

Represent each completed editor gesture as an authoring transaction containing one or more typed changes. Field changes identify their target by stable project UUID, record the component-membership revision and field path, and store before and after values. Structural changes own before and after entity snapshots under the same UUID. Valid previews continue to update the active ECS world immediately, but typing, stepping, scrubbing, boolean changes, complete gizmo drags, and entity/component operations each enter history once at their natural commit boundary.

Undo and redo apply complete transactions by resolving UUIDs against the current world and rejecting stale component incarnations. The history remains bounded and editor-owned. Play captures component-membership revisions with the authoring baseline, and Stop restores those revisions with the authored entities, so history survives a playback round trip. Save also retains history so an edit can still be undone after saving.

Transactions mark authored or explicitly promoted UUIDs as dirty candidates while stopped. Persistence does not serialize the transaction journal. Instead, Save semantically compares candidate entities with the freshly parsed authored baseline. Value-only edits patch differing fields; structural edits rewrite only dirty UUID-scoped entity blocks according to ADR-028. Candidate membership uses constant-time UUID lookup, and the source file is scanned and atomically replaced only during explicit Save.

ADR-027 supersedes ADR-022.

## Consequences

Inspector controls and gizmos share one undo boundary and one stable identity model. Reverted previews, float representation differences, and unchanged fields cannot create source churn because the baseline comparison remains the final persistence authority. Runtime-spawned entities remain outside persistence through origin filtering.

The current transaction value set covers numeric and boolean property changes, including three-axis transform gestures. Structural entity/component operations and multi-selection will require additional change variants and larger transaction payloads, but they can extend the same transaction, history, dirty-candidate, and baseline-comparison flow without changing the persistence boundary.
