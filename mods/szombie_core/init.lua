if not minetest.is_singleplayer() then
    error("This game doesn't support multiplayer.")
end
if not minetest.settings:get_bool("enable_damage") or
        not minetest.settings:get_bool("creative_mode") then
    error("enable_damage and creative_mode must be set to true")
end

local hud_id

minetest.register_globalstep(function(dtime)
    for _, pop in ipairs(core.get_connected_players()) do
        local color = core.colorspec_to_table("#2f2f2f")
        local factor = core.time_to_day_night_ratio(core.get_timeofday())
        --print("factor = " ..dump(factor))
        --print("color before = " ..dump(color))
        color.r = color.r * factor
        color.g = color.g * factor
        color.b = color.b * factor
        --print("color after = " ..dump(color))
        pop:set_sky({
            type = "skybox",
            textures = {
                "skybox_up.png^[transformR90",
                "skybox_down.png^[transformR270",
                "skybox_right.png",
                "skybox_left.png",
                "skybox_front.png",
                "skybox_back.png",
            },
            -- make fog blend with floor
            base_color = color,
        })
    end 
end)

minetest.register_on_newplayer(function(player)
    player:get_inventory():add_item("main", "shooter:machine_gun")
    while player:get_inventory():add_item("main", "shooter:ammo 99"):get_count() == 0 do end
end)

minetest.register_on_joinplayer(function(plaer, last_login)
    plaer:set_lighting({
        saturation = 1,
        shadows = {
            intensity = 0.6,
            tint = "indianred",
        },   
        bloom = {
            intensity = 0.2,
            strength_factor = 2,
            radius = 2.2,
        },
        volumetric_light = {
            strength = 0.05,
        },
    })
    core.set_timeofday(0.75)
    plaer:set_sky({
        type = "skybox",
        textures = {
            "skybox_up.png^[transformR90",
            "skybox_down.png^[transformR270",
            "skybox_right.png",
            "skybox_left.png",
            "skybox_front.png",
            "skybox_back.png",
        },
    })
    plaer:set_sun({
        -- looks ugly on custom skybox
        sunrise_visible = false,
    })
    hud_id = plaer:hud_add({
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

    local stone = minetest.get_content_id("default:sand")

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
local SPAWN_COUNT = 15

local dtime_accu = SPAWN_RATE
local to_be_spawned = 0

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
    if dtime_accu >= SPAWN_RATE then
        to_be_spawned = SPAWN_COUNT
        dtime_accu = 0
    end

    if to_be_spawned > 0 then
        spawn_monster(minetest.get_connected_players()[1])
        to_be_spawned = to_be_spawned - 1
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
