if not minetest.settings:get_bool("enable_damage") or
        minetest.settings:get_bool("creative_mode") then
    error("enable_damage = true and creative_mode = false are required")
end


-- disable sfinv so it doesn't interfere with our set_inventory call
sfinv.enabled = false

core.register_on_joinplayer(function(player, last_login)
    core.set_timeofday(0.75)

    local inv = player:get_inventory()

    inv:set_size("main", 2)
    inv:set_size("craft", 0)
    inv:set_size("craftpreview", 0)
    inv:set_size("craftresult", 0)
    player:set_inventory_formspec("")

    player:hud_set_hotbar_itemcount(2)
    player:hud_set_hotbar_image("")
    player:hud_set_hotbar_selected_image("")
end)


local function player_start(player)
    local inv = player:get_inventory()
    inv:set_list("main", {"shooter:machine_gun", ""})

    for _, ent in pairs(core.luaentities) do
        if ent.name == MONSTER_NAME and ent.szombie_victim == player then
            ent.object:remove()
        end
    end
end

core.register_on_newplayer(function(player)
    player_start(player)
end)
core.register_on_respawnplayer(function(player)
    player_start(player)
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


local CHECK_COVERED_Y_OFFSETS = {0, 1}
local CHECK_FREE_Y_OFFSETS = {2, 3}

local function is_spawner_possible(spawner_pos)
    print("is_spawner_possible called for " .. vector.to_string(spawner_pos))

    if not is_spawner_free(spawner_pos) then
        print("    not free of monsters, discarding.")
        return false
    end

    for _, offset in ipairs(CHECK_COVERED_Y_OFFSETS) do
        local node = core.get_node(spawner_pos:offset(0, offset, 0))
        local def = core.registered_nodes[node.name]
        if not def or def.drawtype ~= "normal" or
                (def.use_texture_alpha ~= nil and def.use_texture_alpha ~= "opaque") then
            print("    spawn-spot not covered by solid nodes, discarding.")
            return false
        end
    end

    for _, offset in ipairs(CHECK_FREE_Y_OFFSETS) do
        local node = core.get_node(spawner_pos:offset(0, offset, 0))
        if node.name ~= "air" then
            print("    come-out-spot not free, discarding.")
            return false
        end
    end

    print("    possible!")
    return true
end


local MAX_SPAWN_TRIES = 100
-- ordered by descending usefulness & likelyhood
local SPAWN_TRY_Y_OFFSETS = {-2, 0, -1, -3, -4, 1, 2, 3, 4}

local function spawn_monsters(player, max_count)
    local player_pos = player:get_pos()
    local num_spawned = 0
    local num_tries = 0

    while num_spawned < max_count and num_tries < MAX_SPAWN_TRIES do
        local spawn_dir

        local control = player:get_player_control()
        local movement_dir = vector.new(control.movement_x, 0, control.movement_y)

        if movement_dir ~= vector.zero() and math.random(1, 2) == 1 then
            movement_dir = movement_dir:rotate(vector.new(0, player:get_look_horizontal(), 0))
    
            -- random direction on 90° circle sector centered around player's walking direction
            spawn_dir = movement_dir:rotate(vector.new(0, math.random() * math.pi/2 - math.pi/4, 0))
        else
            -- random direction on circle
            spawn_dir = vector.new(0, 0, 1)
            spawn_dir = spawn_dir:rotate(vector.new(0, math.random() * 2*math.pi, 0))
        end

        local distance = math.random() * 10 + 10
        local base_spawner_pos = player_pos + spawn_dir * distance

        for _, offset in ipairs(SPAWN_TRY_Y_OFFSETS) do
            local spawner_pos = base_spawner_pos:offset(0, offset, 0)

            if is_spawner_possible(spawner_pos) then
                -- y+0.5 to fix sinking into ground
                local obj = core.add_entity(vector.offset(spawner_pos, 0, 0.5, 0), MONSTER_NAME)
                obj:get_luaentity().szombie_victim = player
                obj:add_velocity(vector.new(0, 5, 0))

                -- core.set_node(spawner_pos, {name = "air"})
                -- core.set_node(spawner_pos:offset(0, 1, 0), {name = "air"})

                num_spawned = num_spawned + 1
                break
            end
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
