local S = minetest.get_translator("hightech")

doors.register(
	"hightech:door",
	{
		description = S("Hightech Door"),
		tiles = {"hightech_door.png"},
		inventory_image = "hightech_door_inv.png",
		use_texture_alpha = "blend",
		paramtype = "light",
		light_source = hightech.internal.max_light,
		groups = {cracky = 3},
		sounds = default.node_sound_stone_defaults(),
	}
)
minetest.register_craft({
	recipe = {
		{"hightech:glass", "hightech:glass"},
		{"hightech:dark", "hightech:dark"},
		{"hightech:dark", "hightech:dark"},
	},
	output = "hightech:door",
})

doors.register(
	"hightech:door_no_window",
	{
		description = S("Hightech Door\n(no window)"),
		tiles = {"hightech_door_no_window.png"},
		inventory_image = "hightech_door_no_window_inv.png",
		groups = {cracky = 3},
		sounds = default.node_sound_stone_defaults(),
	}
)
minetest.register_craft({
	recipe = {
		{"hightech:dark", "hightech:dark"},
		{"hightech:dark", "hightech:dark"},
		{"hightech:dark", "hightech:dark"},
	},
	output = "hightech:door_no_window",
})
