# Spawn Swarm

This example keeps the authored scene nearly empty: only the camera and light
live in TOML. A Luau startup system spawns the floor and roughly 800 renderable
entities, then an update system makes the swarm orbit, bob, and weave while the
renderer collapses repeated geometry into a few instanced batches.
