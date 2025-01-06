if not minetest.is_singleplayer() then
    error("This game doesn't support multiplayer.")
end
if not minetest.settings:get_bool("enable_damage") or
        minetest.settings:get_bool("creative_mode") then
    error("enable_damage = true and creative_mode = false are required")
end

local hud_id

minetest.register_on_newplayer(function(player)
    player:get_inventory():add_item("main", "shooter:machine_gun")
    while player:get_inventory():add_item("main", "shooter:ammo 99"):get_count() == 0 do end
end)

minetest.register_on_joinplayer(function(plaer, last_login)
    core.set_timeofday(0.75)

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
