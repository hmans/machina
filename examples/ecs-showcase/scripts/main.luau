scrapbot.geometry.cube("cube", 2)
scrapbot.geometry.plane("ground", 12, 12)
scrapbot.geometry.icosphere("icosphere", 1, 2)
scrapbot.geometry.sphere("sphere", 1, 32, 20)
scrapbot.geometry.pyramid("pyramid", 1.5, 1.8, 1.5)
scrapbot.geometry.cylinder("cylinder", 0.7, 1.8, 32)
scrapbot.material.lit("marker", 1, 0.3, 0.15, 1)
scrapbot.material.lit("ground", 0.12, 0.18, 0.22, 1)
scrapbot.material.lit("icosphere", 0.12, 0.75, 0.42, 1)
scrapbot.material.lit("sphere", 0.2, 0.48, 1, 1)
scrapbot.material.lit("pyramid", 1, 0.72, 0.08, 1)
scrapbot.material.lit("cylinder", 0.72, 0.2, 0.92, 1)
scrapbot.material.lit("warm-light", 1, 0.12, 0.03, 1)
scrapbot.material.lit("cool-light", 0.03, 0.3, 1, 1)
scrapbot.material.lit("static-amber-light", 1, 0.48, 0.06, 1)
scrapbot.material.lit("static-green-light", 0.08, 1, 0.38, 1)
scrapbot.material.lit("static-violet-light", 0.72, 0.12, 1, 1)

scrapbot.log("hello from examples/ecs-showcase")
scrapbot.log("entities: " .. tostring(scrapbot.entity_count()))
scrapbot.log("renderables: " .. tostring(scrapbot.renderable_count()))

local FloatComponent = scrapbot.component("float", {
	origin = scrapbot.vec3,
	wave = scrapbot.vec3,
}) :: FloatComponent

local Floating = scrapbot.query(scrapbot.transform, FloatComponent)

scrapbot.system(Floating, {
	name = "floating",
	writes = { scrapbot.transform, FloatComponent },
}, function(time: ScrapbotTime, entity: ScrapbotEntity, transform: ScrapbotTransform, float: Float)
	float.wave.x += float.wave.y * time.delta_time
	transform.position.x = float.origin.x
	transform.position.y = float.origin.y + math.sin(float.wave.x) * float.wave.z
	transform.position.z = float.origin.z
end)
