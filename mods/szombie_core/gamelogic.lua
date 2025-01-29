if not minetest.settings:get_bool("enable_damage") or
        minetest.settings:get_bool("creative_mode") then
    error("enable_damage = true and creative_mode = false are required")
end

minetest.register_on_newplayer(function(player)
    local inv = player:get_inventory()
    inv:set_size("main", 2)
    inv:add_item("main", "shooter:machine_gun")
    player:hud_set_hotbar_itemcount(2)
end)

minetest.register_on_joinplayer(function(plaer, last_login)
    core.set_timeofday(0.75)
end)



local SPAWNER_NAME = "szombie_core:spawner"
local LOOT_NAME = "szombie_core:loot"
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

core.register_node(LOOT_NAME, {
    paramtype = "light",
    light_source = 1,
    paramtype2 = "facedir",
    legacy_facedir_simple = true,
    drop = "shooter:ammo",
    sounds = default.node_sound_wood_defaults(),
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


local CHECK_COVERED_OFFSETS = {vector.new(0, 0, 0), vector.new(0, 1, 0)}
local CHECK_FREE_OFFSETS = {vector.new(0, 2, 0), vector.new(0, 3, 0)}

local function is_spawner_possible(spawner_pos)
    print("is_spawner_possible called for " .. vector.to_string(spawner_pos))

    if not is_spawner_free(spawner_pos) then
        print("    not free of monsters, discarding.")
        return false
    end

    for _, offset in ipairs(CHECK_COVERED_OFFSETS) do
        local node = core.get_node(spawner_pos + offset)
        local def = core.registered_nodes[node.name]
        if not def or def.drawtype ~= "normal" or
                (def.use_texture_alpha ~= nil and def.use_texture_alpha ~= "opaque") then
            print("    spawn-spot not covered by solid nodes, discarding.")
            return false
        end
    end

    for _, offset in ipairs(CHECK_FREE_OFFSETS) do
        local node = core.get_node(spawner_pos + offset)
        if node.name ~= "air" then
            print("    come-out-spot not free, discarding.")
            return false
        end
    end

    print("    possible!")
    return true
end


local MAX_SPAWN_TRIES = 100

local function spawn_monsters(player, max_count)
    local player_pos = player:get_pos()
    local num_spawned = 0
    local num_tries = 0

    while num_spawned < max_count and num_tries < MAX_SPAWN_TRIES do
        local angle = math.random() * 2*math.pi
        local distance = math.random() * 10 + 10
        local monster_pos = vector.new(
            math.round(player_pos.x + math.sin(angle) * distance),
            math.round(player_pos.y - 2),
            math.round(player_pos.z + math.cos(angle) * distance)
        )

        if is_spawner_possible(monster_pos) then
            -- y+0.5 to fix sinking into ground
            local obj = core.add_entity(vector.offset(monster_pos, 0, 0.5, 0), MONSTER_NAME)
            obj:get_luaentity().szombie_victim = player
            num_spawned = num_spawned + 1

            core.set_node(monster_pos, {name = "air"})
            core.set_node(monster_pos:offset(0, 1, 0), {name = "air"})
        end

        num_tries = num_tries + 1
    end

    print("spawned " .. num_spawned .. " monsters, maximum was ".. max_count .. ", " .. num_tries .. " tries")
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
        return core.get_node(pos).name == LOOT_NAME
    end
    return core.get_node(pos).name ~= LOOT_NAME -- players can't edit anything except loot
end

-- no dropped items except from loot wanted
-- (monsters can dig nodes)
core.register_on_mods_loaded(function()
    for name in ipairs(core.registered_nodes) do
        if name ~= LOOT_NAME then
            core.override_item(name, {
                drop = "",
            })
        end
    end
end)
