minetest.set_mapgen_setting("mg_name", "singlenode", true)
minetest.register_alias_force("mapgen_singlenode", "air")

-- somehow mapgen ended up a lot slower after moving it into the async mapgen environment
-- (theory: "mapblock_lib.deserialize_part" can no longer copy the data straight since
-- the voxelmanip is no longer exactly one mapblock large)

-- somehow this makes it a lot faster again (obviously one on_generated callback takes
-- less time (lol), but it's also a lot faster in-game)

-- example:
-- with "movement_speed_fast = 60" and "chunksize = 2", I can still hit ignore
-- with "movement_speed_fast = 60" and "chunksize = 1", I don't hit ignore

core.set_mapgen_setting("chunksize", 1, true)

local storage = core.get_mod_storage()

do
    local data = core.deserialize(storage:get_string("szombie_core:chunk_selections")) or {}
    core.ipc_set("szombie_core:chunk_selections", data)
end
-- print("chunk selections read from mod storage: " .. dump(data))

local spawner_poss = core.deserialize(storage:get_string("szombie_core:spawner_poss")) or {}

local function save()
    local data = core.ipc_get("szombie_core:chunk_selections")
    storage:set_string("szombie_core:chunk_selections", core.serialize(data))
    -- print("chunk selections saved to mod storage: " .. dump(data))

    storage:set_string("szombie_core:spawner_poss", core.serialize(spawner_poss))

    core.after(5, save)
end

core.after(5, save)

core.set_gen_notify("custom", nil, {"szombie_core:spawner_poss"})

core.register_on_generated(function(pos_min, pos_max, blockseed)
    local spawner_poss = core.get_mapgen_object("gennotify").custom["szombie_core:spawner_poss"]

    for blockpos_str, pos_list in pairs(spawner_poss) do
        spawner_poss[blockpos_str] = pos_list

        -- print(blockpos_str .. " = " .. dump(spawner_poss))
        -- for _, p in ipairs(pos_list) do
        --     core.set_node(p, {name = "default:mese"})
        -- end
    end
end)

core.register_mapgen_script(core.get_modpath("szombie_core") .. "/mapgen_survival_async.lua")
