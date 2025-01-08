local old_get_current_modname = core.get_current_modname
core.get_current_modname = function() return "mtzip" end
dofile(core.get_modpath("mtzip") .. "/init.lua")
core.get_current_modname = function() return "mapblock_lib" end
dofile(core.get_modpath("mapblock_lib") .. "/szombie_init_async.lua")
core.get_current_modname = old_get_current_modname

local base_names = {"citychunk1", "citychunk2", "citychunk_garden"}
local variant_suffixes = {"", "_r90", "_r180", "_r270"}
local schema_names = {}

for _, base_name in ipairs(base_names) do
    for _, suffix in ipairs(variant_suffixes) do
        table.insert(schema_names, base_name .. suffix)
    end
end

local catalogs = {}
for i, name in ipairs(schema_names) do
    catalogs[i] = assert(mapblock_lib.get_catalog(core.get_modpath("szombie_core") .. "/schematics/" .. name .. ".zip"))
end

local GROUND_LEVEL = -18
local CHUNKSIZE = 48

local function storage_get_selection(chunkpos)
    return core.ipc_get("szombie_core:chunk_selection:" .. chunkpos:to_string())
end

local function storage_set_selection(chunkpos, selection)
    core.ipc_set("szombie_core:chunk_selection:" .. chunkpos:to_string(), selection)
end

local function is_valid(chunkpos, selection)
    local neighbors = {vector.new(-1, 0, 0), vector.new(1, 0, 0), vector.new(0, 0, -1), vector.new(0, 0, 1)}
    for _, offset in ipairs(neighbors) do
        local neighbor_chunkpos = chunkpos + offset
        local neighbor_selection = storage_get_selection(neighbor_chunkpos)
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

core.register_on_generated(function(vmanip, pos_min, pos_max, blockseed)
    local t1 = core.get_us_time()

    for x = pos_min.x, pos_max.x do
    for y = pos_min.y, pos_max.y do
    for z = pos_min.z, pos_max.z do
        local pos_in_mapblock = vector.new(x % core.MAP_BLOCKSIZE, y % core.MAP_BLOCKSIZE, z % core.MAP_BLOCKSIZE)

        if pos_in_mapblock == vector.new(0, 0, 0) then
            local chunkpos = vector.new(math.floor(x / CHUNKSIZE), 0, math.floor(z / CHUNKSIZE))
            local schema_index = get_schema_index(chunkpos)

            local pos_in_chunk = vector.new(x % CHUNKSIZE, y - GROUND_LEVEL, z % CHUNKSIZE)
            local mapblockpos_in_chunk = vector.new(math.floor(pos_in_chunk.x / core.MAP_BLOCKSIZE), math.floor(pos_in_chunk.y / core.MAP_BLOCKSIZE), math.floor(pos_in_chunk.z / core.MAP_BLOCKSIZE))

            local mapblockpos = vector.new(math.floor(x / core.MAP_BLOCKSIZE), math.floor(y / core.MAP_BLOCKSIZE), math.floor(z / core.MAP_BLOCKSIZE))

            if catalogs[schema_index]:has_mapblock(mapblockpos_in_chunk) then
                assert(catalogs[schema_index]:deserialize(mapblockpos_in_chunk, mapblockpos, {mapgen_voxelmanip = vmanip}))
            end
        end
    end
    end
    end


    local t2 = core.get_us_time()
    print("delta = " .. ((t2 - t1) / 1000) .. " ms")
end)
