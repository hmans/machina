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

local CameraDolly = scrapbot.component("camera_dolly", {
	origin = scrapbot.vec3,
	direction = scrapbot.vec3,
	distance = scrapbot.number,
	duration = scrapbot.number,
}, { advanced = true }) :: CameraDollyComponent

local DollyCameras = scrapbot.query(
	scrapbot.transform,
	CameraDolly
)

scrapbot.system(DollyCameras, {
	name = "camera_dolly",
	writes = { scrapbot.transform },
	reads = { CameraDolly },
}, function(
	time: ScrapbotTime,
	_entity: ScrapbotEntity,
	transform: ScrapbotTransform,
	dolly: CameraDolly
)
	local duration = math.max(dolly.duration, 0.001)
	local progress = math.min(time.elapsed_time / duration, 1)
	local eased = progress * progress * (3 - 2 * progress)
	local travel = dolly.distance * eased
	transform.position.x = dolly.origin.x + dolly.direction.x * travel
	transform.position.y = dolly.origin.y + dolly.direction.y * travel
	transform.position.z = dolly.origin.z + dolly.direction.z * travel
end)

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
