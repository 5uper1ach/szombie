local shared = dofile(core.get_modpath("szombie_core") .. "/mapgen_shared.lua")

local old_get_current_modname = core.get_current_modname

core.get_current_modname = function() return "mtzip" end
dofile(core.get_modpath("mtzip") .. "/init.lua")

core.get_current_modname = function() return "mapblock_lib" end
dofile(core.get_modpath("mapblock_lib") .. "/szombie_init_async.lua")

core.get_current_modname = old_get_current_modname

local schema_names = {}

for _, base_name in ipairs(shared.base_names) do
    for _, suffix in ipairs(shared.variant_suffixes) do
        table.insert(schema_names, base_name .. suffix)
    end
end

local catalogs = {}
for i, name in ipairs(schema_names) do
    catalogs[i] = assert(mapblock_lib.get_catalog(core.get_modpath("szombie_core") .. "/schematics/" .. name .. ".zip"))
end

local CHUNKSIZE = shared.chunksize
local GROUND_LEVEL = -18

-- not thread-safe I guess

local function storage_get_selection(chunkpos)
    local selections = core.ipc_get("szombie_core:chunk_selections")
    return selections[chunkpos:to_string()]
end

local function storage_set_selection(chunkpos, selection)
    local selections = core.ipc_get("szombie_core:chunk_selections")
    selections[chunkpos:to_string()] = selection
    core.ipc_set("szombie_core:chunk_selections", selections)
end

local function is_valid(chunkpos, selection)
    -- only horizontal, no diagonals
    local neighbors = {vector.new(-1, 0, 0), vector.new(1, 0, 0), vector.new(0, 0, -1), vector.new(0, 0, 1)}
    for _, offset in ipairs(neighbors) do
        local neighbor_chunkpos = chunkpos + offset
        local neighbor_selection = storage_get_selection(neighbor_chunkpos)
        -- intentionally only considered the same when rotation suffix is also the same
        -- (simply don't have enough different chunks otherwise)
        if neighbor_selection and neighbor_selection == selection then
            -- print("disallowing " .. schema_names[selection] .. " for " .. chunkpos:to_string() .. " because " .. neighbor_chunkpos:to_string() .. " is also " .. schema_names[selection])
            return false
        end
    end
    return true
end

local function get_schema_index(chunkpos)
    local stored = storage_get_selection(chunkpos)
    if stored then
        return stored
    end

    local index
    repeat
        index = math.random(#schema_names)
    until is_valid(chunkpos, index)

    storage_set_selection(chunkpos, index)

    return index
end

local replacements = {
    ["stairs:stair_inner_glass"] = "szombie_core:spawner",
}
for name in pairs(core.registered_nodes) do
    -- mobs can't open doors for now, so remove them
    if core.get_item_group(name, "door") ~= 0 then
        replacements[name] = "air"
    end
end

local vm_data

core.register_on_generated(function(vmanip, pos_min, pos_max, blockseed)
    -- local t1 = core.get_us_time()

    local blockpos_min = mapblock_lib.get_mapblock(pos_min)
    local blockpos_max = mapblock_lib.get_mapblock(pos_max)

    local check_blockposs = {}

    for block_x = blockpos_min.x, blockpos_max.x do
    for block_y = blockpos_min.y, blockpos_max.y do
    for block_z = blockpos_min.z, blockpos_max.z do
        local x = block_x * core.MAP_BLOCKSIZE
        local y = block_y * core.MAP_BLOCKSIZE
        local z = block_z * core.MAP_BLOCKSIZE

        local chunkpos = vector.new(math.floor(x / CHUNKSIZE), 0, math.floor(z / CHUNKSIZE))
        local schema_index = get_schema_index(chunkpos)

        local pos_in_chunk = vector.new(x % CHUNKSIZE, y - GROUND_LEVEL, z % CHUNKSIZE)
        local mapblockpos_in_chunk = mapblock_lib.get_mapblock(pos_in_chunk)

        local mapblockpos = vector.new(block_x, block_y, block_z)

        if catalogs[schema_index]:has_mapblock(mapblockpos_in_chunk) then
            assert(catalogs[schema_index]:deserialize(mapblockpos_in_chunk, mapblockpos, {
                mapgen_voxelmanip = vmanip,
                transform = {
                    replace = replacements,
                },
            }))
            table.insert(check_blockposs, mapblockpos)
        end
    end
    end
    end

    local emin, emax = vmanip:get_emerged_area()
    local vm_area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
    -- we batch finding spawners after all mapblocks are written so that we only
    -- have to call get_data once
    vm_data = vmanip:get_data(vm_data)

    local spawner = core.get_content_id("szombie_core:spawner")
    local spawner_poss = {}

    for _, blockpos in ipairs(check_blockposs) do
        local pos_min, pos_max = mapblock_lib.get_mapblock_bounds_from_mapblock(blockpos)
        local list = {}

        for x = pos_min.x, pos_max.x do
        for y = pos_min.y, pos_max.y do
        for z = pos_min.z, pos_max.z do
            if vm_data[vm_area:index(x, y, z)] == spawner then
                table.insert(list, vector.new(x, y, z))
            end
        end
        end
        end

        if #list > 0 then
            spawner_poss[blockpos:to_string()] = list
        end
    end

    assert(core.save_gen_notify("szombie_core:spawner_poss", spawner_poss))

    -- local t2 = core.get_us_time()
    -- print("delta = " .. ((t2 - t1) / 1000) .. " ms")
end)
