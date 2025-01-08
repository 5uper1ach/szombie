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

local function is_view_blocked(pos1, pos2)
    local ray = core.raycast(pos1, pos2, false, false)
    for pointed in ray do
        if pointed.type == "node" then
            local node = core.get_node(pointed.under)
            local def = core.registered_nodes[node.name]
            if node.name ~= "szombie_core:spawner" and
                    (not def or def.drawtype ~= "airlike") then
                return true
            end
        end
    end
    return false
end

local function get_eye_pos(player)
    local pos = player:get_pos()
    pos.y = pos.y + player:get_properties().eye_height
    -- https://dev.luanti.org/docs/classes/raycast/#redo-tool-raycasts
    local first_person = player:get_eye_offset()
    pos = pos + first_person/10
    return pos
end

local function is_spawner_hidden(player, spawner_pos)
    print("spawner check for " .. vector.to_string(spawner_pos))

    local eye_pos = get_eye_pos(player)

    -- player too close, they'll definitely notice
    if vector.distance(eye_pos, spawner_pos) < 3 then
        print("player too close, discarding")
        return false
    end

    -- player looks away, they won't notice if the view isn't blocked
    local bad_dir = vector.direction(eye_pos, spawner_pos)
    local actual_dir = player:get_look_dir()
    if vector.dot(bad_dir, actual_dir) < 0 then
        print("player looks away, okay")
        return true
    end

    if is_view_blocked(eye_pos, spawner_pos) then
        print("view is blocked, okay")
        return true
    end

    print("neither looking away nor view blocked, discarding")
    return false
end

local function spawn_monsters(player, max_count)
    local playerpos = player:get_pos()
    local blockpos = mapblock_lib.get_mapblock(playerpos)

    local avail_spawners = {}
    for _, offset in ipairs(offsets) do
        local blockpos2 = blockpos + offset
        local spawners = szombie_core.spawner_poss[blockpos2:to_string()]
        if spawners then
            table.insert_all(avail_spawners, spawners)
        end
    end
    table.sort(avail_spawners, function(a, b)
        return vector.distance(playerpos, a) < vector.distance(playerpos, b)
    end)

    local num_spawned = 0

    for _, spawner_pos in ipairs(avail_spawners) do
        if is_spawner_hidden(player, spawner_pos) and
                is_spawner_hidden(player, vector.offset(spawner_pos, 0, 1, 0)) then
            core.add_entity(spawner_pos, "mobs_monster:dirt_monster")
            num_spawned = num_spawned + 1
        end

        if num_spawned >= max_count then
            break
        end
    end
    
    print("spawned " .. num_spawned .. " monsters, maximum was ".. max_count)
end

local player_states = {}

local JOIN_WAIT = 4
local SPAWN_RATE = 5
local SPAWN_COUNT = 5

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
            spawn_monsters(player, state.to_be_spawned)
            state.to_be_spawned = 0
        end
    end
end)

szombie_core.on_monster_die = function()
    -- TODO?
end
