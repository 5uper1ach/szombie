if not minetest.settings:get_bool("enable_damage") or
        minetest.settings:get_bool("creative_mode") then
    error("enable_damage = true and creative_mode = false are required")
end

minetest.register_on_newplayer(function(player)
    player:get_inventory():add_item("main", "shooter:machine_gun")
    player:get_inventory():add_item("main", "shooter:ammo 4")
end)

minetest.register_on_joinplayer(function(plaer, last_login)
    core.set_timeofday(0.75)
end)

core.register_node("szombie_core:spawner", {
    -- drawtype = "airlike",
    -- for debugging:
    drawtype = "normal",
    tiles = {"default_dirt.png"},
    light_source = core.LIGHT_MAX / 4,

    diggable = false,
    buildable_to = false,
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    pointable = false,
})

-- intentionally also includes 0, 0, 0
local offsets = {}
for x = -1, 1 do
for y = -1, 1 do
for z = -1, 1 do
    table.insert(offsets, vector.new(x, y, z))
end
end
end

local function spawn_monster(player)
    local blockpos = mapblock_lib.get_mapblock(player:get_pos())

    local avail_spawners = {}
    for _, offset in ipairs(offsets) do
        local blockpos2 = blockpos + offset
        local spawners = szombie_core.spawner_poss[blockpos2:to_string()]
        if spawners then
            table.insert_all(avail_spawners, spawners)
        end
    end

    local spawner_pos = avail_spawners[math.random(#avail_spawners)]
    core.add_entity(spawner_pos, "mobs_monster:dirt_monster")
end

local player_states = {}

local JOIN_WAIT = 4
local SPAWN_RATE = 10
local SPAWN_COUNT = 15

core.register_on_joinplayer(function(player)
    player_states[player:get_player_name()] = {
        dtime_accu = SPAWN_RATE - JOIN_WAIT,
        to_be_spawned = 0,
    }
end)

core.register_on_leaveplayer(function(player)
    player_states[player:get_player_name()] = nil
end)

core.register_globalstep(function(dtime)
    for _, player in ipairs(core.get_connected_players()) do
        local state = player_states[player:get_player_name()]

        state.dtime_accu = state.dtime_accu + dtime
        if state.dtime_accu >= SPAWN_RATE then
            state.to_be_spawned = SPAWN_COUNT
            state.dtime_accu = 0
        end

        if state.to_be_spawned > 0 then
            spawn_monster(player)
            state.to_be_spawned = state.to_be_spawned - 1
        end
    end
end)

szombie_core.on_monster_die = function()
    -- TODO?
end
