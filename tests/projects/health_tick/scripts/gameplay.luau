--!strict

local Health = ecs.component("health", {
  fields = ecs.fields({
    current = "f32",
    max = "f32",
  }),
})

local DamageOverTime = ecs.component("damage_over_time", {
  fields = ecs.fields({
    per_second = "f32",
  }),
})

local Regen = ecs.component("regen", {
  fields = ecs.fields({
    per_second = "f32",
  }),
})

local Damaged = ecs.query(Health, DamageOverTime)
local Regenerating = ecs.query(Health, Regen)

ecs.system("apply_damage", {
  query = Damaged,
  writes = ecs.refs(Health),
  run = function(world, dt)
    for _entity, health, damage in Damaged:iter(world) do
      local next_current = health.current - damage.per_second * dt
      if next_current < 0 then
        next_current = 0
      end
      health.current = next_current
    end
  end,
})

ecs.system("apply_regen", {
  query = Regenerating,
  writes = ecs.refs(Health),
  after = { "apply_damage" },
  run = function(world, dt)
    for _entity, health, regen in Regenerating:iter(world) do
      local next_current = health.current + regen.per_second * dt
      if next_current > health.max then
        next_current = health.max
      end
      health.current = next_current
    end
  end,
})
