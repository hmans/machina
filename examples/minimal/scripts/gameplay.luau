type Spin = {
  angular_velocity: MachinaVec3,
}

local Transform = ecs.component<<MachinaTransform>>("machina.transform")
local RenderCube = ecs.component<<MachinaRenderCube>>("machina.render.cube")
local Spin = ecs.component<<Spin>>("spin", {
  fields = {
    angular_velocity = "vec3",
  },
})

ecs.system("autorotate", {
  phase = "update",
  reads = { Spin },
  writes = { Transform },
  run = function(world, dt)
    for _entity, transform, spin in world.query(Transform, Spin) do
      transform.rotation = {
        transform.rotation[1] + spin.angular_velocity[1] * dt,
        transform.rotation[2] + spin.angular_velocity[2] * dt,
        transform.rotation[3] + spin.angular_velocity[3] * dt,
      }
    end
  end,
})

ecs.system("observe_cubes", {
  phase = "update",
  reads = { Transform, RenderCube },
  after = { "autorotate" },
})
