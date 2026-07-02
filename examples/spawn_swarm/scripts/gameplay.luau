--!strict

local Transform = ecs.component<<MachinaTransform>>("machina.transform")
local Geometry = ecs.component<<MachinaGeometryPrimitive>>("machina.geometry.primitive")
local Material = ecs.component<<MachinaSurfaceMaterial>>("machina.material.surface")
local ShadowCaster = ecs.component<<MachinaShadowCaster>>("machina.shadow.caster")
local ShadowReceiver = ecs.component<<MachinaShadowReceiver>>("machina.shadow.receiver")

local SwarmMotion = ecs.component("swarm_motion", {
  fields = ecs.fields({
    home = "vec3",
    velocity = "vec3",
    phase = "f32",
    orbit_radius = "f32",
    speed = "f32",
  }),
})

local Swarm = ecs.query(Transform, SwarmMotion)
local elapsed = 0

local function palette(index: number): { number }
  local bucket = index % 6
  if bucket == 0 then
    return { 1.0, 0.42, 0.08 }
  elseif bucket == 1 then
    return { 0.08, 0.58, 1.0 }
  elseif bucket == 2 then
    return { 0.48, 0.92, 0.38 }
  elseif bucket == 3 then
    return { 1.0, 0.82, 0.18 }
  elseif bucket == 4 then
    return { 0.8, 0.44, 1.0 }
  else
    return { 0.04, 0.86, 0.78 }
  end
end

local function primitiveFor(index: number): (string, number, number)
  local bucket = index % 4
  if bucket == 0 then
    return "uv_sphere", 14, 8
  elseif bucket == 1 then
    return "box", 0, 0
  elseif bucket == 2 then
    return "ico_sphere", 2, 0
  else
    return "box", 0, 0
  end
end

ecs.system("spawn_swarm", {
  phase = "startup",
  writes = ecs.refs(Transform, Geometry, Material, ShadowCaster, ShadowReceiver, SwarmMotion),
  run = function(world, _dt)
    local floor = world.spawn("swarm-floor", "Swarm Floor")
    floor:add(Transform, {
      position = { 0.0, -1.18, -0.25 },
      rotation = { 0.0, 0.0, 0.0 },
      scale = { 9.5, 1.0, 6.2 },
    })
    floor:add(Geometry, {
      primitive = "plane",
      segments = 0,
      rings = 0,
    })
    floor:add(Material, {
      base_color = { 0.12, 0.18, 0.26 },
    })
    floor:add(ShadowReceiver)

    for ring = 1, 5 do
      local members = 18 + ring * 6
      local ring_radius = 0.7 + ring * 0.54
      for slot = 1, members do
        local index = (ring - 1) * 48 + slot
        local angle = (slot / members) * math.pi * 2.0 + ring * 0.23
        local lift = -0.64 + ring * 0.38
        local home = {
          math.cos(angle) * ring_radius * 1.18,
          lift + math.sin(slot * 0.61) * 0.2,
          -0.7 + math.sin(angle) * ring_radius * 0.82 + math.sin(angle * 2.0) * 0.18,
        }
        local primitive, segments, rings = primitiveFor(index)
        local entity = world.spawn("swarm-" .. tostring(index), "Swarm " .. tostring(index))
        local scale = 0.1 + ring * 0.012

        entity:add(Transform, {
          position = home,
          rotation = { angle * 0.25, ring * 0.18, slot * 0.07 },
          scale = { scale, scale, scale },
        })
        entity:add(Geometry, {
          primitive = primitive,
          segments = segments,
          rings = rings,
        })
        entity:add(Material, {
          base_color = palette(index),
        })
        entity:add(ShadowCaster)
        entity:add(SwarmMotion, {
          home = home,
          velocity = {
            math.sin(angle) * 0.22,
            math.cos(slot * 0.37) * 0.08,
            math.cos(angle) * 0.18,
          },
          phase = ring * 0.71 + slot * 0.19,
          orbit_radius = 0.16 + ring * 0.035,
          speed = 0.72 + ring * 0.05 + (slot % 5) * 0.025,
        })
      end
    end
  end,
})

ecs.system("animate_swarm", {
  phase = "update",
  query = Swarm,
  writes = ecs.refs(Transform, SwarmMotion),
  run = function(world, dt)
    elapsed += dt

    for _entity, transform, motion in Swarm:iter(world) do
      local t = elapsed * motion.speed + motion.phase
      local orbit_x = math.cos(t) * motion.orbit_radius
      local orbit_z = math.sin(t * 0.91) * motion.orbit_radius
      local bob = math.sin(t * 1.7) * 0.18
      local drift = {
        motion.velocity[1] * dt,
        motion.velocity[2] * dt,
        motion.velocity[3] * dt,
      }
      local next_position = {
        motion.home[1] + orbit_x + drift[1],
        motion.home[2] + bob + drift[2],
        motion.home[3] + orbit_z + drift[3],
      }

      transform.position = next_position
      transform.rotation = {
        transform.rotation[1] + dt * (0.55 + motion.speed * 0.35),
        transform.rotation[2] + dt * (0.9 + motion.orbit_radius),
        transform.rotation[3] + dt * (0.25 + math.sin(t) * 0.2),
      }

      motion.velocity = {
        motion.velocity[1] * 0.985 + (motion.home[1] - next_position[1]) * dt * 0.22,
        motion.velocity[2] * 0.965 + (motion.home[2] - next_position[2]) * dt * 0.18,
        motion.velocity[3] * 0.985 + (motion.home[3] - next_position[3]) * dt * 0.22,
      }
    end
  end,
})
