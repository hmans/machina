ecs.component("health", {
  fields = {
    current = "f32",
    max = "f32",
  },
})

ecs.component("mood", {
  fields = {
    value = "string",
  },
})

ecs.system("rotate_cubes", {
  phase = "update",
  reads = { "machina.spin" },
  writes = { "machina.transform" },
  run = function(world, dt)
    world.rotate("machina.transform", "machina.spin", dt * 10)
  end,
})

ecs.system("observe_cubes", {
  phase = "update",
  reads = { "machina.transform", "machina.render.cube" },
  after = { "rotate_cubes" },
})

ecs.system("observe_health", {
  phase = "update",
  reads = { "health" },
})

ecs.system("health_regen", {
  phase = "update",
  reads = { "machina.transform" },
  writes = { "health" },
  after = { "observe_health" },
})
