scrapbot.geometry.pyramid("scraproids.ship", 1.2, 1.8, 0.8)
local AsteroidGeometrySmooth = scrapbot.geometry.icosphere("scraproids.asteroid", 1.0, 1)
local AsteroidGeometryChunky = scrapbot.geometry.icosphere("scraproids.asteroid.chunky", 1.0, 0)
local AsteroidFragmentMaterial = scrapbot.material.lit("scraproids.asteroid.fragments", 0.42, 0.34, 0.28, 1.0)
local BulletGeometry = scrapbot.geometry.cylinder("scraproids.bullet", 0.11, 0.55, 10)
local BulletMaterial = scrapbot.material.emissive("scraproids.bullet", 0.1, 0.85, 1.6, 5.0)

local Ship = scrapbot.component("ship", {
	speed = scrapbot.field(scrapbot.number, { draggable = true, minimum = 0, maximum = 20, step = 0.1 }),
	response = scrapbot.field(scrapbot.number, { draggable = true, minimum = 1, maximum = 30, step = 0.5 }),
	lean = scrapbot.field(scrapbot.number, { draggable = true, minimum = 0, maximum = 1, step = 0.05 }),
	fire_interval = scrapbot.field(scrapbot.number, { draggable = true, minimum = 0.04, maximum = 1, step = 0.01 }),
	cooldown = scrapbot.number,
})
local Asteroid = scrapbot.component("asteroid", { radius = scrapbot.number })
local Velocity = scrapbot.component("velocity", { value = scrapbot.vec3 })
local Bullet = scrapbot.component("bullet", { age = scrapbot.number, radius = scrapbot.number }, { advanced = true })
local Spin = scrapbot.component("spin", { value = scrapbot.vec3 })
local SpawnPop = scrapbot.component("spawn_pop", {
	age = scrapbot.number,
	duration = scrapbot.number,
	target_scale = scrapbot.vec3,
}, { advanced = true })
local CameraShake = scrapbot.component("camera_shake", {
	base_position = scrapbot.vec3,
	base_rotation = scrapbot.vec3,
	trauma = scrapbot.number,
}, { advanced = true })
local ShakeImpulse = scrapbot.component("shake_impulse", { amount = scrapbot.number }, { advanced = true })
local Hud = scrapbot.component("hud", {})
local score = 0
local random_state = 7331

local function random01(): number
	random_state = (random_state * 48271) % 2147483647
	return random_state / 2147483647
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function damp(a: number, b: number, sharpness: number, delta_time: number): number
	return lerp(a, b, 1 - math.exp(-sharpness * delta_time))
end

local function ease_out_back(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	local shifted = t - 1
	return 1 + c3 * shifted * shifted * shifted + c1 * shifted * shifted
end

local Player = scrapbot.query(scrapbot.transform, Ship, Velocity)
scrapbot.system(Player, {
	name = "control",
	reads = { scrapbot.keyboard_input },
	writes = {
		scrapbot.transform,
		scrapbot.geometry_component,
		scrapbot.material_component,
		Ship,
		Velocity,
		Bullet,
	},
}, function(time: ScrapbotTime, _entity: ScrapbotEntity, transform: ScrapbotTransform, ship: Ship, velocity: Velocity)
	local x = 0
	local y = 0
	if scrapbot.input.key_down("a") or scrapbot.input.key_down("left") then x -= 1 end
	if scrapbot.input.key_down("d") or scrapbot.input.key_down("right") then x += 1 end
	if scrapbot.input.key_down("s") or scrapbot.input.key_down("down") then y -= 1 end
	if scrapbot.input.key_down("w") or scrapbot.input.key_down("up") then y += 1 end
	if x ~= 0 and y ~= 0 then
		x *= 0.70710678
		y *= 0.70710678
	end
	velocity.value.x = damp(velocity.value.x, x * ship.speed, ship.response, time.delta_time)
	velocity.value.y = damp(velocity.value.y, y * ship.speed, ship.response, time.delta_time)
	transform.rotation.z = damp(transform.rotation.z, -x * ship.lean, ship.response * 0.7, time.delta_time)
	ship.cooldown = math.max(ship.cooldown - time.delta_time, 0)
	if scrapbot.input.key_down("space") and ship.cooldown <= 0 then
		ship.cooldown = ship.fire_interval
		scrapbot.spawn({
			name = "Photon Bolt",
			components = {
				["scrapbot.transform"] = {
					position = { x = transform.position.x, y = transform.position.y + 0.62, z = 0 },
					rotation = { x = 1.5707963, y = 0, z = 0 },
					scale = { x = 1, y = 1, z = 1 },
				},
				["scrapbot.geometry"] = BulletGeometry,
				["scrapbot.material"] = BulletMaterial,
				velocity = { value = { x = 0, y = 10.5, z = 0 } },
				bullet = { age = 0, radius = 0.18 },
			},
		})
	end
end)

local Moving = scrapbot.query(scrapbot.transform, Velocity)
scrapbot.system(Moving, {
	name = "move",
	writes = { scrapbot.transform },
	reads = { Velocity },
}, function(time: ScrapbotTime, _entity: ScrapbotEntity, transform: ScrapbotTransform, velocity: Velocity)
	transform.position.x += velocity.value.x * time.delta_time
	transform.position.y += velocity.value.y * time.delta_time
	if transform.position.x < -6.4 then transform.position.x = 6.4 end
	if transform.position.x > 6.4 then transform.position.x = -6.4 end
	if transform.position.y < -4.2 then transform.position.y = 4.2 end
	if transform.position.y > 5.2 then transform.position.y = -4.2 end
end)

local Spinning = scrapbot.query(scrapbot.transform, Spin)
scrapbot.system(Spinning, {
	name = "spin",
	writes = { scrapbot.transform },
	reads = { Spin },
}, function(time: ScrapbotTime, _entity: ScrapbotEntity, transform: ScrapbotTransform, spin: Spin)
	transform.rotation.x += spin.value.x * time.delta_time
	transform.rotation.y += spin.value.y * time.delta_time
	transform.rotation.z += spin.value.z * time.delta_time
end)

local Popping = scrapbot.query(scrapbot.transform, SpawnPop)
scrapbot.system(Popping, {
	name = "spawn_pop",
	writes = { scrapbot.transform, SpawnPop },
}, function(time: ScrapbotTime, entity: ScrapbotEntity, transform: ScrapbotTransform, pop: SpawnPop)
	pop.age += time.delta_time
	local t = math.min(pop.age / math.max(pop.duration, 0.001), 1)
	local eased = ease_out_back(t)
	transform.scale.x = pop.target_scale.x * eased
	transform.scale.y = pop.target_scale.y * eased
	transform.scale.z = pop.target_scale.z * eased
	if t >= 1 then
		scrapbot.remove_component(entity, SpawnPop)
	end
end)

local Asteroids = scrapbot.query(scrapbot.transform, Asteroid, Velocity)
local Bullets = scrapbot.query(scrapbot.transform, Bullet)
local collision_frame = -1
local destroyed_asteroids = {}
scrapbot.system(Bullets, {
	name = "collide",
	writes = {
		scrapbot.transform,
		scrapbot.geometry_component,
		scrapbot.material_component,
		scrapbot.shadow_caster,
		Asteroid,
		Bullet,
		Velocity,
		Spin,
		SpawnPop,
		ShakeImpulse,
	},
	reads = { scrapbot.transform, Asteroid, Velocity },
}, function(time: ScrapbotTime, bullet_entity: ScrapbotEntity, bullet_transform: ScrapbotTransform, bullet: Bullet)
	if collision_frame ~= time.frame_index then
		collision_frame = time.frame_index
		destroyed_asteroids = {}
	end
	bullet.age += time.delta_time
	if bullet.age > 1.4 then
		scrapbot.despawn(bullet_entity)
		return
	end
	for _, item in scrapbot.view(Asteroids) do
		if destroyed_asteroids[item.entity.id] then continue end
		local asteroid_transform = item.components[1]
		local asteroid = item.components[2]
		local asteroid_velocity = item.components[3]
		local dx = bullet_transform.position.x - asteroid_transform.position.x
		local dy = bullet_transform.position.y - asteroid_transform.position.y
		local radius = bullet.radius + asteroid.radius
		if dx * dx + dy * dy <= radius * radius then
			destroyed_asteroids[item.entity.id] = true
			scrapbot.despawn(bullet_entity)
			scrapbot.despawn(item.entity)
			if asteroid.radius > 0.26 then
				local child_radius = asteroid.radius * 0.56
				local child_count = 2 + math.floor(random01() * 2)
				for child_index = 1, child_count do
					local angle = random01() * math.pi * 2 + child_index * (math.pi * 2 / child_count)
					local burst_speed = 1.25 + random01() * 1.15
					local target_scale = { x = child_radius, y = child_radius, z = child_radius }
					scrapbot.spawn({
						name = "Asteroid Fragment",
						components = {
							["scrapbot.transform"] = {
								position = {
									x = asteroid_transform.position.x + math.cos(angle) * child_radius * 0.45,
									y = asteroid_transform.position.y + math.sin(angle) * child_radius * 0.45,
									z = asteroid_transform.position.z,
								},
								rotation = {
									x = random01() * math.pi,
									y = random01() * math.pi,
									z = random01() * math.pi,
								},
								scale = {
									x = child_radius * 0.18,
									y = child_radius * 0.18,
									z = child_radius * 0.18,
								},
							},
							["scrapbot.geometry"] = if child_radius > 0.25 then AsteroidGeometrySmooth else AsteroidGeometryChunky,
							["scrapbot.material"] = AsteroidFragmentMaterial,
							["scrapbot.shadow_caster"] = {},
							asteroid = { radius = child_radius },
							velocity = {
								value = {
									x = asteroid_velocity.value.x + math.cos(angle) * burst_speed,
									y = asteroid_velocity.value.y + math.sin(angle) * burst_speed,
									z = 0,
								},
							},
							spin = {
								value = {
									x = (random01() - 0.5) * 2.8,
									y = (random01() - 0.5) * 2.8,
									z = (random01() - 0.5) * 2.8,
								},
							},
							spawn_pop = { age = 0, duration = 0.24, target_scale = target_scale },
						}
					})
				end
			end
			scrapbot.spawn({
				name = "Camera Shake",
				components = { shake_impulse = { amount = math.min(0.28 + asteroid.radius * 0.38, 0.7) } },
			})
			score += math.floor(120 / asteroid.radius)
			return
		end
	end
end)

local ShakeImpulses = scrapbot.query(ShakeImpulse)
local ShakingCameras = scrapbot.query(scrapbot.transform, CameraShake)
scrapbot.system(ShakingCameras, {
	name = "camera_shake",
	writes = { scrapbot.transform, CameraShake },
	reads = { ShakeImpulse },
}, function(time: ScrapbotTime, _entity: ScrapbotEntity, transform: ScrapbotTransform, shake: CameraShake)
	for _, item in scrapbot.view(ShakeImpulses) do
		shake.trauma = math.min(shake.trauma + item.component.amount, 1)
		scrapbot.despawn(item.entity)
	end
	shake.trauma = math.max(shake.trauma - time.delta_time * 1.85, 0)
	local strength = shake.trauma * shake.trauma
	local phase = time.elapsed_time * 48
	transform.position.x = shake.base_position.x + math.sin(phase * 1.13) * 0.16 * strength
	transform.position.y = shake.base_position.y + math.sin(phase * 1.71 + 1.9) * 0.12 * strength
	transform.position.z = shake.base_position.z
	transform.rotation.x = shake.base_rotation.x
	transform.rotation.y = shake.base_rotation.y
	transform.rotation.z = shake.base_rotation.z + math.sin(phase * 2.07 + 0.7) * 0.018 * strength
end)

local Score = scrapbot.query(scrapbot.ui_text, Hud)
scrapbot.system(Score, {
	name = "score",
	writes = { scrapbot.ui_text },
	reads = { Hud },
}, function(_time: ScrapbotTime, _entity: ScrapbotEntity, text: ScrapbotUiText, _hud: Hud)
	text.text = string.format("SCRAPROIDS  /  SCORE %04d", score)
end)
