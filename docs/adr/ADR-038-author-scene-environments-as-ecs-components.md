# ADR-038: Author scene environments as ECS components

**Date:** 2026-07-22

## Context

Environment resources are project-owned imported data, but selecting the lighting and visible sky is scene authoring state. Keeping that selection in `project.toml` makes it global, hides it from ordinary entity inspection and history, and gives the renderer a configuration path unrelated to other authored scene data.

## Decision

Represent scene environment selection with one authored `scrapbot.world_environment` ECS component. A scene may contain at most one. It references Environment resources by stable UUID and owns lighting intensity/rotation, base exposure, visible-background selection and presentation controls.

The fixed `scrapbot.environment` engine phase retains the selected entity and its component revision. Structural changes rediscover the singleton; value changes resolve only its resource UUIDs and mutate a renderer-facing resource-registry cache. Stable frames perform no complete-world or resource scan. Environment resources remain outside the ECS and the renderer continues to consume generational handles and a monotonic environment revision.

With no assigned background Environment, an enabled background uses the renderer-native procedural haze sky. Assigning a background UUID selects the imported panorama instead.

## Consequences

Environment state participates in scene persistence, automatic type-inspected editor panels, playback restore, and component membership rules. Projects can use different environments per scene without changing their manifest. Duplicate environment components and invalid resource references fail validation instead of producing an order-dependent winner.

The implementation retains a small resolved cache in the resource registry and a retained singleton index/revision in the World. Future fog, tone mapping, clouds, and postprocessing can remain separate components/systems rather than turning this component into an unbounded render-settings bag.
