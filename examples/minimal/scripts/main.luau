scrapbot.log("hello from examples/minimal")
scrapbot.log("entities: " .. tostring(scrapbot.entity_count()))
scrapbot.log("renderables: " .. tostring(scrapbot.renderable_count()))

local AutorotateComponent = scrapbot.component("autorotate", {
	velocity = "vec3",
}) :: AutorotateComponent

-- Scheduling metadata: this system reads project autorotate data and writes engine transforms.
-- Systems whose declared component access does not conflict can share a scheduler batch.
scrapbot.system({
	reads = { AutorotateComponent },
	writes = { "scrapbot.transform" },
}, function(delta_seconds)
	scrapbot.query(scrapbot.transform, AutorotateComponent, function(entity, transform: ScrapbotTransform, autorotate: Autorotate)
		local rotation = transform.rotation
		rotation.x += autorotate.velocity.x * delta_seconds
		rotation.y += autorotate.velocity.y * delta_seconds
		rotation.z += autorotate.velocity.z * delta_seconds
		scrapbot.set_rotation(entity, rotation)
	end)
end)
