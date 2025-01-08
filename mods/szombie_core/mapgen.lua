core.register_mapgen_script(core.get_modpath("szombie_core") .. "/mapgen_async.lua")

local storage = core.get_mod_storage()

local GENERATE_VARIANT_SCHEMATICS = false

local schema_names = {"citychunk1", "citychunk2", "citychunk_garden"}
if not GENERATE_VARIANT_SCHEMATICS then
    local variant_suffixes = {"", "_r90", "_r180", "_r270"}
    local all_names = {}
    for _, name in ipairs(schema_names) do
        for _, suffix in ipairs(variant_suffixes) do
            table.insert(all_names, name .. suffix)
        end
    end
    schema_names = all_names
end

local catalogs = {}
for i, name in ipairs(schema_names) do
    catalogs[i] = assert(mapblock_lib.get_catalog(core.get_modpath("szombie_core") .. "/schematics/" .. name .. ".zip"))
end

local function gen_variant(schema_index, root_blockpos, rotation)
    local name = schema_names[schema_index]
    local catalog = catalogs[schema_index]

    local root_pos = root_blockpos * core.MAP_BLOCKSIZE

    local blocksize = catalog:get_size()
    local size = blocksize * core.MAP_BLOCKSIZE

    local pos2 = root_pos + size:offset(-1, -1, -1)
    local blockpos2 = root_blockpos + blocksize:offset(-1, -1, -1)

    local emerge_done = false

    core.emerge_area(root_pos, root_pos + size, function(blockpos, action, calls_remaining)
        if calls_remaining == 0 then
            assert(not emerge_done)
            emerge_done = true

            print("area emerged for " .. name .. ", rotation " .. rotation)

            catalog:deserialize_all(root_blockpos, {
                delay = 0,
                callback = function(count, micros)
                    print(count .. " mapblocks loaded for " .. name .. ", rotation " .. rotation)

                    worldedit.rotate(root_pos, pos2, "y", rotation)
                    worldedit.orient(root_pos, pos2, rotation)
                    worldedit.luatransform(root_pos, pos2,
                        "hightech.internal.update_surrounding_autoconnect_stripe_nodes('hightech:dark_stripe_top_autoconnect', pos)")
                    worldedit.luatransform(root_pos, pos2,
                        "hightech.internal.update_surrounding_autoconnect_stripe_nodes('hightech:dark_stripe_bottom_autoconnect', pos)")

                    print("transformations applied for " .. name .. ", rotation " .. rotation)

                    local new_filename = core.get_worldpath() .. "/" .. name .. "_r" .. rotation .. ".zip"
                    mapblock_lib.create_catalog(new_filename, root_blockpos, blockpos2, {
                        delay = 0,
                        callback = function(total_count, micros)
                            print(total_count .. " mapblocks written to " .. new_filename)
                        end,
                    })
                end,
            })
        end
    end)
end

local function gen_variants()
    local rotations = {90, 180, 270}
    local root_blockpos = vector.new(0, 100, 0)

    for index in ipairs(schema_names) do
        for _, rotation in ipairs(rotations) do
            gen_variant(index, root_blockpos, rotation)

            root_blockpos = root_blockpos + vector.new(0, 0, 100)
        end
    end
end

if GENERATE_VARIANT_SCHEMATICS then
    core.after(0, gen_variants)
end

minetest.register_node("szombie_core:checkerboard", {
    tiles = { "trak2_tile1b.tga" },
})
minetest.register_alias("szombie_core:stone", "szombie_core:checkerboard")

minetest.set_mapgen_setting("mg_name", "singlenode", true)
minetest.register_alias_force("mapgen_singlenode", "air")
