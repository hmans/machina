# Machina Batching Demo

This project demonstrates automatic renderer batching. The scene authors many
independent ECS entities with repeated geometry/material component pairs, then a
Luau ECS system animates their transforms. The renderer groups those entities
into shared GPU draw batches automatically.

```sh
mise machina check examples/batching
mise machina step examples/batching --frames 8 --dt 0.05
mise machina run examples/batching --frames 240
mise machina render examples/batching zig-out/batching.bmp
mise machina render-test examples/batching zig-out/batching-render-test.bmp
```
