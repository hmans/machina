local LightMotion = scrapbot.component("light_motion", {
	origin = scrapbot.vec3,
	amplitude = scrapbot.vec3,
	phase = scrapbot.number,
	speed = scrapbot.number,
	base_intensity = scrapbot.number,
}, { advanced = true }) :: LightMotionComponent

local MovingLights = scrapbot.query(
	scrapbot.transform,
	scrapbot.point_light,
	LightMotion
)

scrapbot.system(MovingLights, {
	name = "animate_lights",
	writes = { scrapbot.transform, scrapbot.point_light },
	reads = { LightMotion },
}, function(
	time: ScrapbotTime,
	_entity: ScrapbotEntity,
	transform: ScrapbotTransform,
	light: ScrapbotPointLight,
	motion: LightMotion
)
	local angle = time.elapsed_time * motion.speed + motion.phase
	transform.position.x = motion.origin.x + math.sin(angle) * motion.amplitude.x
	transform.position.y = motion.origin.y + math.sin(angle * 0.73 + 1.2) * motion.amplitude.y
	transform.position.z = motion.origin.z + math.cos(angle * 0.87) * motion.amplitude.z
	light.intensity = motion.base_intensity * (0.86 + math.sin(angle * 1.61 + 0.4) * 0.14)
end)
