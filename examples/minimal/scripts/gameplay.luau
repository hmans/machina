ecs.component("spin", {
  fields = {
    angular_velocity = "vec3",
  },
})

ecs.system("autorotate", {
  phase = "update",
  reads = { "spin" },
  writes = { "machina.transform" },
  run = function(world, dt)
    for entity in world.query("machina.transform", "spin") do
      local rotation = entity.get_vec3("machina.transform", "rotation")
      local angular_velocity = entity.get_vec3("spin", "angular_velocity")
      entity.set_vec3("machina.transform", "rotation", {
        rotation[1] + angular_velocity[1] * dt,
        rotation[2] + angular_velocity[2] * dt,
        rotation[3] + angular_velocity[3] * dt,
      })
    end
  end,
})

ecs.system("observe_cubes", {
  phase = "update",
  reads = { "machina.transform", "machina.render.cube" },
  after = { "autorotate" },
})
