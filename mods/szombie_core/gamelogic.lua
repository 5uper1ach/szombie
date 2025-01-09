if not minetest.settings:get_bool("enable_damage") or
        minetest.settings:get_bool("creative_mode") then
    error("enable_damage = true and creative_mode = false are required")
end

minetest.register_on_newplayer(function(player)
    player:get_inventory():add_item("main", "shooter:machine_gun")
end)

minetest.register_on_joinplayer(function(plaer, last_login)
    core.set_timeofday(0.75)
end)



local SPAWNER_NAME = "szombie_core:spawner"
local MONSTER_NAME = "mobs_monster:dirt_monster"



core.register_node(SPAWNER_NAME, {
    drawtype = "airlike",
    -- for debugging:
    -- drawtype = "normal",
    -- tiles = {"default_dirt.png"},
    -- light_source = core.LIGHT_MAX / 4,

    diggable = false,
    buildable_to = false,
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    pointable = false,
})

core.register_node("szombie_core:loot", {
    paramtype = "light",
    light_source = 1,
    paramtype2 = "facedir",
    legacy_facedir_simple = true,
    drop = "shooter:ammo",
    groups = {dig_immediate = 3},
    tiles = {
        "default_chest_top.png",
        "default_chest_top.png",
        "default_chest_side.png^[transformFX",
        "default_chest_side.png",
        "default_chest_side.png",
        "default_chest_front.png"
    },
})


local function is_spawner_free(spawner_pos)
    for _, obj in ipairs(core.get_objects_inside_radius(spawner_pos, 8)) do
        local ent = obj:get_luaentity()
        if ent and ent.name == MONSTER_NAME then
            return false
        end
    end
    return true
end

local function get_eye_pos(player)
    local pos = player:get_pos()
    pos.y = pos.y + player:get_properties().eye_height
    -- https://dev.luanti.org/docs/classes/raycast/#redo-tool-raycasts
    local first_person = player:get_eye_offset()
    pos = pos + first_person/10
    return pos
end

local function is_view_blocked(pos1, pos2)
    local ray = core.raycast(pos1, pos2, false, false)
    for pointed in ray do
        if pointed.type == "node" then
            local node = core.get_node(pointed.under)
            local def = core.registered_nodes[node.name]
            if node.name ~= SPAWNER_NAME and
                    -- TODO: add use_texture_alpha check?
                    -- so that semi/clip-transparent nodes like glass don't count as blocking the view
                    (not def or def.drawtype ~= "airlike") then
                return true
            end
        end
    end
    return false
end

local function is_spawner_hidden(player, spawner_pos)
    -- print("    checking visibility of " .. vector.to_string(spawner_pos) .. " for " .. player:get_player_name())

    local eye_pos = get_eye_pos(player)

    -- player too close, they'll definitely notice
    if vector.distance(eye_pos, spawner_pos) < 3 then
        -- print("        player too close, not okay.")
        return false
    end

    -- player looks away, they won't notice even if the view isn't blocked
    local bad_dir = vector.direction(eye_pos, spawner_pos)
    local actual_dir = player:get_look_dir()
    if vector.dot(bad_dir, actual_dir) < 0 then
        -- print("        player looks away, okay.")
        return true
    end

    if is_view_blocked(eye_pos, spawner_pos) then
        -- print("        view is blocked, okay.")
        return true
    end

    -- print("        neither looking away nor view blocked, not okay.")
    return false
end

local function is_spawner_possible(spawner_pos)
    -- print("is_spawner_possible called for " .. vector.to_string(spawner_pos))

    if not is_spawner_free(spawner_pos) then
        -- print("    not free, discarding.")
        return false
    end

    for _, player in ipairs(core.get_connected_players()) do
        -- monster is two nodes tall
        if not is_spawner_hidden(player, spawner_pos) or
                not is_spawner_hidden(player, vector.offset(spawner_pos, 0, 1, 0)) then
            -- print("    not hidden for " .. player:get_player_name() .. ", discarding.")
            return false
        end
    end

    -- print("    possible!")
    return true
end



-- intentionally also includes 0, 0, 0
local offsets = {}
for x = -1, 1 do
for y = -1, 1 do
for z = -1, 1 do
    table.insert(offsets, vector.new(x, y, z))
end
end
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
        if is_spawner_possible(spawner_pos) then
            -- y+0.5 to fix sinking into ground
            local obj = core.add_entity(vector.offset(spawner_pos, 0, 0.5, 0), MONSTER_NAME)
            obj:get_luaentity().szombie_victim = player
            num_spawned = num_spawned + 1
        end

        if num_spawned >= max_count then
            break
        end
    end
    
    print("spawned " .. num_spawned .. " monsters, maximum was ".. max_count)
end



-- returns active monster count
local function manage_active_monsters()
    local count = 0
    for _, ent in pairs(core.luaentities) do
        if ent.name == MONSTER_NAME then
            local monster_pos = ent.object:get_pos()
            local victim_pos = ent.szombie_victim and ent.szombie_victim:get_pos()
            if not monster_pos or not victim_pos then
                ent.object:remove()
            elseif vector.distance(monster_pos, victim_pos) > 16 then
                print(">>>>>>>>>>> removing monster at " .. vector.to_string(monster_pos) .. ", too far away.")
                ent.object:remove()
            else
                count = count + 1
            end
        end
    end
    return count
end



-- per-player
local SPAWN_RATE = 1
-- not per-player, global cap because of bad performance of mob library
local MAX_MONSTERS = 10

local player_states = {}

core.register_on_joinplayer(function(player)
    player_states[player:get_player_name()] = {
        dtime_accu = 0,
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
            local num_active = manage_active_monsters()
            if num_active < MAX_MONSTERS then
                print(">>> " .. player:get_player_name())
                print(">>> global active monster count = " .. num_active)
                spawn_monsters(player, 1)
            end
            state.dtime_accu = 0
        end
    end
end)

szombie_core.on_monster_die = function()
    -- TODO?
end

core.is_protected = function(pos, name)
    if name == "" then -- monsters can edit everything except loot
        return core.get_node(pos).name == "szombie_core:loot"
    end
    return core.get_node(pos).name ~= "szombie_core:loot" -- players can't edit anything except loot
end
