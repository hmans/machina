# ECS Stress Test

This example keeps roughly 3,000 short-lived renderable entities active at the default settings. Project-native Odin systems emit them, integrate their transforms and velocities, rotate them, age them, and despawn them through Scrapbot's retained 64-entity query plans and four-lane SIMD helpers.

Run it with the editor and open the Systems and Performance panels:

```sh
mise scrapbot run examples/ecs-stress --editor
```

Select **Stress Emitter** to tune `spawn_rate`, `lifetime`, and `launch_speed` live. Runtime entities stay out of the Scene list unless explicitly selected, so the editor does not attempt to materialize thousands of transient rows.

For a bounded CPU run with native-query counters:

```sh
bin/scrapbot run examples/ecs-stress \
  --backend null \
  --headless \
  --no-hot-reload \
  --frames 2000 \
  --runtime-stats \
  --json
```
