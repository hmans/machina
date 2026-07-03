# Comet Garden

Script-spawned ECS scene that shows the current Luau runtime path:

- startup systems spawn the renderable world from an almost-empty scene,
- update systems add and remove entities through deferred structural commands,
- a later ordered system observes those flushed changes in the same phase,
- the animation hot loop uses `Query:view(...)` buffer reads/writes.

Run it with:

```sh
mise machina run examples/comet_garden --editor
```

Render-check it with:

```sh
mise machina render-test examples/comet_garden zig-out/comet-garden-render-test.bmp
```
