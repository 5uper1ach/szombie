local schema_names = {"citychunk1", "citychunk2"}
local catalogs = {}
for i, name in ipairs(schema_names) do
    catalogs[i] = assert(mapblock_lib.get_catalog(core.get_modpath("szombie_core") .. "/schematics/" .. name .. ".zip"))
end

minetest.register_node("szombie_core:checkerboard", {
    tiles = { "trak2_tile1b.tga" },
})
minetest.register_alias("szombie_core:stone", "szombie_core:checkerboard")

minetest.set_mapgen_setting("mg_name", "singlenode", true)
minetest.register_alias_force("mapgen_singlenode", "air")

local vm_data

local GROUND_LEVEL = -3
local CHUNKSIZE = 48

local chunk_schema_selections = {}

minetest.register_on_generated(function(pos_min, pos_max)
    for x = pos_min.x, pos_max.x do
        for y = pos_min.y, pos_max.y do
            for z = pos_min.z, pos_max.z do
                local pos_in_mapblock = vector.new(x % core.MAP_BLOCKSIZE, y % core.MAP_BLOCKSIZE, z % core.MAP_BLOCKSIZE)

                if pos_in_mapblock == vector.new(0, 0, 0) then
                    local chunkpos = vector.new(math.floor(x / CHUNKSIZE), 0, math.floor(z / CHUNKSIZE))
                    if not chunk_schema_selections[chunkpos:to_string()] then
                        chunk_schema_selections[chunkpos:to_string()] = math.random(#schema_names)
                    end
                    local schema_index = chunk_schema_selections[chunkpos:to_string()]

                    local pos_in_chunk = vector.new(x % CHUNKSIZE, y - GROUND_LEVEL, z % CHUNKSIZE)
                    local mapblockpos_in_chunk = vector.new(math.floor(pos_in_chunk.x / core.MAP_BLOCKSIZE), math.floor(pos_in_chunk.y / core.MAP_BLOCKSIZE), math.floor(pos_in_chunk.z / core.MAP_BLOCKSIZE))

                    local mapblockpos = vector.new(math.floor(x / core.MAP_BLOCKSIZE), math.floor(y / core.MAP_BLOCKSIZE), math.floor(z / core.MAP_BLOCKSIZE))

                    if catalogs[schema_index]:has_mapblock(mapblockpos_in_chunk) then
                        assert(catalogs[schema_index]:deserialize(mapblockpos_in_chunk, mapblockpos, {}))
                    end
                end
            end
        end
    end
end)
