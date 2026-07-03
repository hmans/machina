--!strict

local Transform = ecs.component<<MachinaTransform>>("machina.transform")
local Geometry = ecs.component<<MachinaGeometryPrimitive>>("machina.geometry.primitive")
local Material = ecs.component<<MachinaSurfaceMaterial>>("machina.material.surface")
local ShadowCaster = ecs.component<<MachinaShadowCaster>>("machina.shadow.caster")
local ShadowReceiver = ecs.component<<MachinaShadowReceiver>>("machina.shadow.receiver")

local CometMotion = ecs.component("comet_motion", {
  fields = ecs.fields({
    origin = "vec3",
    velocity = "vec3",
    spin = "vec3",
    phase = "f32",
    age = "f32",
    lifespan = "f32",
    orbit_radius = "f32",
  }),
})

local Comets = ecs.query(Transform, CometMotion)

local elapsed = 0
local next_comet_id = 0
local spawn_clock = 0
local max_comets = 220

local function palette(index: number): { number }
  local bucket = index % 7
  if bucket == 0 then
    return { 1.0, 0.38, 0.08 }
  elseif bucket == 1 then
    return { 0.04, 0.74, 1.0 }
  elseif bucket == 2 then
    return { 0.54, 0.96, 0.34 }
  elseif bucket == 3 then
    return { 1.0, 0.82, 0.16 }
  elseif bucket == 4 then
    return { 0.82, 0.45, 1.0 }
  elseif bucket == 5 then
    return { 0.06, 0.9, 0.72 }
  else
    return { 1.0, 0.58, 0.18 }
  end
end

local function primitiveFor(index: number): (string, number, number)
  local bucket = index % 5
  if bucket == 0 then
    return "uv_sphere", 18, 9
  elseif bucket == 1 then
    return "ico_sphere", 2, 0
  else
    return "box", 0, 0
  end
end

local function spawnComet(world: MachinaWorld, burst: number)
  next_comet_id += 1
  local index = next_comet_id
  local angle = index * 2.399963 + burst * 0.19
  local lane = index % 9
  local radius = 0.72 + lane * 0.42
  local origin = {
    math.cos(angle) * radius * 1.14,
    -0.72 + lane * 0.18 + math.sin(index * 0.37) * 0.16,
    -0.42 + math.sin(angle) * radius * 0.82,
  }
  local velocity = {
    math.cos(angle + math.pi * 0.5) * (0.18 + lane * 0.016),
    0.18 + (index % 5) * 0.024,
    math.sin(angle + math.pi * 0.5) * (0.14 + lane * 0.012),
  }
  local scale = 0.094 + (index % 6) * 0.01
  local primitive, segments, rings = primitiveFor(index)
  local entity = world.spawn("comet-" .. tostring(index), "Comet " .. tostring(index))

  entity:add(Transform, {
    position = origin,
    rotation = { angle * 0.18, lane * 0.11, index * 0.07 },
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
  entity:add(CometMotion, {
    origin = origin,
    velocity = velocity,
    spin = {
      0.55 + lane * 0.04,
      0.9 + (index % 4) * 0.1,
      0.3 + (index % 3) * 0.08,
    },
    phase = angle,
    age = 0.0,
    lifespan = 5.5 + (index % 8) * 0.35,
    orbit_radius = 0.12 + lane * 0.018,
  })
end

ecs.system("build_garden", {
  phase = "startup",
  writes = ecs.refs(Transform, Geometry, Material, ShadowCaster, ShadowReceiver, CometMotion),
  run = function(world, _dt)
    local floor = world.spawn("comet-floor", "Comet Floor")
    floor:add(Transform, {
      position = { 0.0, -1.18, -0.58 },
      rotation = { 0.0, 0.0, 0.0 },
      scale = { 11.0, 1.0, 7.4 },
    })
    floor:add(Geometry, {
      primitive = "plane",
      segments = 0,
      rings = 0,
    })
    floor:add(Material, {
      base_color = { 0.11, 0.16, 0.24 },
    })
    floor:add(ShadowReceiver)

    local gate = world.spawn("comet-gate", "Comet Gate")
    gate:add(Transform, {
      position = { 0.0, 0.18, -0.75 },
      rotation = { 0.0, 0.0, 0.0 },
      scale = { 0.38, 0.38, 0.38 },
    })
    gate:add(Geometry, {
      primitive = "uv_sphere",
      segments = 24,
      rings = 12,
    })
    gate:add(Material, {
      base_color = { 0.02, 0.76, 1.0 },
    })
    gate:add(ShadowCaster)

    for index = 1, 144 do
      spawnComet(world, index)
    end
  end,
})

ecs.system("emit_and_cull_comets", {
  phase = "update",
  query = Comets,
  writes = ecs.refs(Transform, Geometry, Material, ShadowCaster, CometMotion),
  before = { "animate_comets" },
  run = function(world, dt)
    spawn_clock += dt
    local alive = 0

    for entity, _transform, motion in Comets:iter(world) do
      alive += 1
      local next_age = motion.age + dt
      if next_age > motion.lifespan then
        entity:despawn()
      else
        motion.age = next_age
      end
    end

    while spawn_clock >= 0.075 and alive < max_comets do
      spawn_clock -= 0.075
      alive += 1
      spawnComet(world, alive)
    end
  end,
})

ecs.system("animate_comets", {
  phase = "update",
  query = Comets,
  writes = ecs.refs(Transform),
  after = { "emit_and_cull_comets" },
  run = function(world, dt)
    elapsed += dt

    local view = Comets:view(world)
    local count = view:count()
    local origins = view:read_vec3(CometMotion, "origin")
    local velocities = view:read_vec3(CometMotion, "velocity")
    local spins = view:read_vec3(CometMotion, "spin")
    local phases = view:read_f32(CometMotion, "phase")
    local ages = view:read_f32(CometMotion, "age")
    local lifespans = view:read_f32(CometMotion, "lifespan")
    local orbit_radii = view:read_f32(CometMotion, "orbit_radius")
    local positions = view:read_vec3(Transform, "position")
    local rotations = view:read_vec3(Transform, "rotation")

    for index = 0, count - 1 do
      local f32_offset = index * 4
      local vec3_offset = index * 12
      local origin_x = buffer.readf32(origins, vec3_offset)
      local origin_y = buffer.readf32(origins, vec3_offset + 4)
      local origin_z = buffer.readf32(origins, vec3_offset + 8)
      local velocity_x = buffer.readf32(velocities, vec3_offset)
      local velocity_y = buffer.readf32(velocities, vec3_offset + 4)
      local velocity_z = buffer.readf32(velocities, vec3_offset + 8)
      local spin_x = buffer.readf32(spins, vec3_offset)
      local spin_y = buffer.readf32(spins, vec3_offset + 4)
      local spin_z = buffer.readf32(spins, vec3_offset + 8)
      local phase = buffer.readf32(phases, f32_offset)
      local age = buffer.readf32(ages, f32_offset)
      local lifespan = buffer.readf32(lifespans, f32_offset)
      local orbit_radius = buffer.readf32(orbit_radii, f32_offset)
      local life_t = age / lifespan
      local glow = math.sin(life_t * math.pi)
      local t = elapsed * (0.8 + orbit_radius * 3.0) + phase

      buffer.writef32(positions, vec3_offset, origin_x + velocity_x * age + math.cos(t) * orbit_radius)
      buffer.writef32(positions, vec3_offset + 4, origin_y + velocity_y * age + math.sin(t * 1.7) * 0.16 + glow * 0.34)
      buffer.writef32(positions, vec3_offset + 8, origin_z + velocity_z * age + math.sin(t * 0.91) * orbit_radius)

      buffer.writef32(rotations, vec3_offset, buffer.readf32(rotations, vec3_offset) + spin_x * dt)
      buffer.writef32(rotations, vec3_offset + 4, buffer.readf32(rotations, vec3_offset + 4) + spin_y * dt)
      buffer.writef32(rotations, vec3_offset + 8, buffer.readf32(rotations, vec3_offset + 8) + spin_z * dt)
    end

    view:write_vec3(Transform, "position", positions)
    view:write_vec3(Transform, "rotation", rotations)
  end,
})
