if not minetest.is_singleplayer() then
    error("This game doesn't support multiplayer.")
end
if not minetest.settings:get_bool("enable_damage") or
        not minetest.settings:get_bool("creative_mode") then
    error("enable_damage and creative_mode must be set to true")
end

local hud_id

minetest.register_on_newplayer(function(player)
    player:get_inventory():add_item("main", "shooter:machine_gun")
    while player:get_inventory():add_item("main", "shooter:ammo 99"):get_count() == 0 do end
end)

minetest.register_on_joinplayer(function(player, last_login)
    player:set_sky({ type = "skybox", textures = { "skybox_down.png", "skybox_up.png", "skybox_left.png", "skybox_right.png", "skybox_back.png", "skybox_front.png"}})
    -- minetest.sound_play("aargh", { to_player = player:get_player_name(), loop = true })
    hud_id = player:hud_add({
        hud_elem_type = "text",
        position = {x = 0, y = 1},
        text = "0",
        scale = {x = 10000000, y = 100000},
        alignment = {x = 1,y = -1},
        size = {x = 5, y = 0},
        number = 0xFFFFFF,
        offset = { x = 10, y = -10},
    })
end)

minetest.register_node("szombie_core:stone", {
    tiles = { "trak2_tile1b.tga" },
})

minetest.set_mapgen_setting("mg_name", "singlenode", true)
minetest.register_alias_force("mapgen_singlenode", "air")

local vm_data

minetest.register_on_generated(function(pos_min, pos_max)
    local vm, vm_pos_min, vm_pos_max = minetest.get_mapgen_object("voxelmanip")
    local vm_area = VoxelArea:new{MinEdge = vm_pos_min, MaxEdge = vm_pos_max}
    vm_data = vm:get_data(vm_data)

    local stone = minetest.get_content_id("szombie_core:stone")

    for x = pos_min.x, pos_max.x do
        for y = pos_min.y, pos_max.y do
            for z = pos_min.z, pos_max.z do
                local index = vm_area:index(x, y, z)

                if y <= -3 then
                    vm_data[index] = stone
                end
            end
        end
    end

    vm:set_data(vm_data)
    vm:write_to_map()
end)

local function spawn_monster(player)
    local position_auf_kreis = math.random(-2 * math.pi, 2 * math.pi)
    local distanz = math.random(10, 20)
    local spieler_position = player:get_pos()
    local position_in_welt = vector.new(
        spieler_position.x + math.sin(position_auf_kreis) * distanz,
        0,
        spieler_position.z + math.cos(position_auf_kreis) * distanz
    )
    minetest.add_entity(position_in_welt, "mobs_monster:dirt_monster")
end

local hud_blinking = false
local hud_blinking_t = 0

local SPAWN_RATE = 10
local dtime_accu = SPAWN_RATE

minetest.register_globalstep(function(dtime)
    local players = minetest.get_connected_players()
    if #players == 0 then
        return
    end

    for _, player in ipairs(players) do
        if not hud_blinking then
            player:hud_change(hud_id, "number", "0xFFFFFF")
            player:hud_change(hud_id, "size", {x = 5})
        else
            hud_blinking_t = hud_blinking_t + dtime
            if hud_blinking_t < 2 then
                if math.round(minetest.get_us_time() / 250000) % 2 == 0 then
                    player:hud_change(hud_id, "number", "0xFF0000")
                    player:hud_change(hud_id, "size", {x = 30})
                else
                    player:hud_change(hud_id, "number", "0xFFFFFF")
                    player:hud_change(hud_id, "size", {x = 30})
                end
            else
                hud_blinking_t = 0
                hud_blinking = false
                player:hud_change(hud_id, "number", "0xFFFFFF")
                player:hud_change(hud_id, "size", {x = 5})
            end
        end
    end

    dtime_accu = dtime_accu + dtime
    if dtime_accu < SPAWN_RATE then
        return
    end
    dtime_accu = 0

    for _, player in ipairs(players) do
        for i = 1, 15 do
            spawn_monster(player)
        end
    end
end)

local dead_monsters = 0

local function update_hud(player)
    player:hud_change(hud_id, "text", tostring(dead_monsters))
end

szombie_core = {}
szombie_core.on_monster_die = function()
    dead_monsters = dead_monsters + 1
    update_hud(minetest.get_connected_players()[1])
    hud_blinking = true
end

minetest.register_on_respawnplayer(function()
    minetest.clear_objects()
    dtime_accu = SPAWN_RATE
    dead_monsters = 0
    update_hud(minetest.get_connected_players()[1])
end)

-- Override the hand item registered in the engine in builtin/game/register.lua
minetest.override_item("", {
	wield_scale = {x=1,y=1,z=2.5},
	tool_capabilities = {
		full_punch_interval = 0,
		max_drop_level = 0,
		groupcaps = {
			crumbly = {times={[2]=3.00, [3]=0.70}, uses=0, maxlevel=1},
			snappy = {times={[3]=0.40}, uses=0, maxlevel=1},
			oddly_breakable_by_hand = {times={[1]=3.50,[2]=2.00,[3]=0.70}, uses=0}
		},
		damage_groups = {fleshy=1},
	}
})
