-- Dirt Monster by PilzAdam

mobs:register_mob("mobs_monster:dirt_monster", {
	type = "monster",
	passive = false,
	attack_type = "dogfight",
	-- 2 would mean GRIEFING TOO
	-- pathfinding = 2,
	pathfinding = 1,
	reach = 2,
	damage = 2,
	hp_min = 6,
	hp_max = 6,
	armor = 100,
	collisionbox = {-0.4, -1, -0.4, 0.4, 0.8, 0.4},
	visual = "mesh",
	mesh = "mobs_stone_monster.b3d",
	textures = {
		{"mobs_dirt_monster.png"},
		{"mobs_dirt_monster2.png"}
	},
	makes_footstep_sound = true,
	sounds = {
		random = "mobs_dirtmonster",
		damage = "aargh",
		death = "aargh",
		distance = 32,
	},
	view_range = 256,
	walk_velocity = 1,
	run_velocity = 3,
	jump = true,
	water_damage = 0,
	lava_damage = 0,
	light_damage = 0,
	fear_height = 4,
	animation = {
		speed_normal = 15,
		speed_run = 15,
		stand_start = 0,
		stand_end = 14,
		walk_start = 15,
		walk_end = 38,
		run_start = 40,
		run_end = 63,
		punch_start = 40,
		punch_end = 63
	},
	-- when digging down, don't kill yourself
	fall_damage = false,
	fear_height = 0,

	on_die = function(self)
		szombie_core.on_monster_die()
	end,
})
