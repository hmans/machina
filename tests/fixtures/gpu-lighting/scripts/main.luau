local cube = scrapbot.geometry.cube("cube", 1)
local ground = scrapbot.geometry.plane("ground", 16, 16)
local white = scrapbot.material.lit("white", 0.8, 0.8, 0.8, 1)
local spawned = false

scrapbot.system({
	name = "spawn_lighting_fixture",
	writes = {
		scrapbot.transform,
		scrapbot.geometry_component,
		scrapbot.material_component,
		scrapbot.shadow_caster,
		scrapbot.shadow_receiver,
	},
}, function()
	if spawned then
		return
	end
	spawned = true
	scrapbot.spawn({
		name = "Caster",
		components = {
			["scrapbot.transform"] = { position = { x = 0, y = 1, z = 0 } },
			["scrapbot.geometry"] = cube,
			["scrapbot.material"] = white,
			["scrapbot.shadow_caster"] = {},
			["scrapbot.shadow_receiver"] = {},
		},
	})
	scrapbot.spawn({
		name = "Ground",
		components = {
			["scrapbot.transform"] = {},
			["scrapbot.geometry"] = ground,
			["scrapbot.material"] = white,
			["scrapbot.shadow_receiver"] = {},
		},
	})
end)
