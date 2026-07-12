scrapbot.log("hello from examples/minimal")
scrapbot.log("entities: " .. tostring(scrapbot.entity_count()))
scrapbot.log("renderables: " .. tostring(scrapbot.renderable_count()))

-- Luau-defined project component and system.
local DriftComponent = scrapbot.component("drift", {
	velocity = scrapbot.vec3,
}) :: DriftComponent

local SpinComponent = scrapbot.component_handle("scrappyphysics.spin") :: ScrappyphysicsSpinComponent
local RigidbodyComponent = scrapbot.component_handle("scrappyphysics.rigidbody") :: ScrappyphysicsRigidbodyComponent

local Drifting = scrapbot.query(scrapbot.transform, DriftComponent)
local Spinners = scrapbot.query(SpinComponent)
local Rigidbodies = scrapbot.query(RigidbodyComponent)

scrapbot.system(Drifting, {
	writes = { scrapbot.transform },
}, function(delta_seconds: number, entity: ScrapbotEntity, transform: ScrapbotTransform, drift: Drift)
	transform.position.x += drift.velocity.x * delta_seconds
	transform.position.y += drift.velocity.y * delta_seconds
	transform.position.z += drift.velocity.z * delta_seconds
end)

-- Scheduling metadata: this system reads native extension component data.
-- Systems whose declared component access does not conflict can share a scheduler batch.
scrapbot.system(Spinners, function(delta_seconds: number, entity: ScrapbotEntity, spin: ReadonlyScrappyphysicsSpin)
	assert(spin.angular_velocity.y >= -10)
end)

scrapbot.system(Rigidbodies, function(delta_seconds: number, entity: ScrapbotEntity, rigidbody: ReadonlyScrappyphysicsRigidbody)
	assert(rigidbody.velocity.y >= -100)
end)
