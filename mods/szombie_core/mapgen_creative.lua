local shared = dofile(core.get_modpath("szombie_core") .. "/mapgen_shared.lua")

minetest.set_mapgen_setting("mg_name", "singlenode", true)
minetest.register_alias_force("mapgen_singlenode", "air")
-- reset configuration set by survival mapgen
core.set_mapgen_setting("chunksize", 5, true)

local vm_data

local CHUNKSIZE = shared.chunksize
local GROUND_LEVEL = -3

local ROADWIDTH = 3
local BLOCKSIZE = 64
local ROAD_1 = ROADWIDTH - 1
local ROAD_2 = BLOCKSIZE - ROADWIDTH

local DEBUG_ONE_BLOCK_ONLY = false

minetest.register_on_generated(function(pos_min, pos_max)
    local vm, vm_pos_min, vm_pos_max = minetest.get_mapgen_object("voxelmanip")
    local vm_area = VoxelArea:new{MinEdge = vm_pos_min, MaxEdge = vm_pos_max}
    vm_data = vm:get_data(vm_data)

    local sand = minetest.get_content_id("default:sand")
    local dark = minetest.get_content_id("hightech:dark")
    local stripe = minetest.get_content_id("hightech:dark_stripe_top_autoconnect_0000")

    local stripe_poss = {}

    for x = pos_min.x, pos_max.x do
        for y = pos_min.y, pos_max.y do
            for z = pos_min.z, pos_max.z do
                local index = vm_area:index(x, y, z)

                if y == GROUND_LEVEL then
                    local blockpos = vector.new(math.floor(x / BLOCKSIZE), 0, math.floor(z / BLOCKSIZE))
                    local pos_in_block = vector.new(x % BLOCKSIZE, 0, z % BLOCKSIZE)

                    if (pos_in_block.x < ROAD_1 or
                            pos_in_block.z < ROAD_1 or
                            pos_in_block.x > ROAD_2 or
                            pos_in_block.z > ROAD_2) and
                            (not DEBUG_ONE_BLOCK_ONLY or blockpos == vector.new(0, 0, 0)) then
                        vm_data[index] = dark
                    elseif (pos_in_block.x == ROAD_1 or
                            pos_in_block.z == ROAD_1 or
                            pos_in_block.x == ROAD_2 or
                            pos_in_block.z == ROAD_2) and
                            (not DEBUG_ONE_BLOCK_ONLY or blockpos == vector.new(0, 0, 0)) then
                        vm_data[index] = stripe
                        table.insert(stripe_poss, vector.new(x, y, z))
                    else
                        vm_data[index] = sand
                    end
                elseif y < GROUND_LEVEL then
                    vm_data[index] = sand
                end
            end
        end
    end

    vm:set_data(vm_data)
    vm:write_to_map()

    for _, pos in ipairs(stripe_poss) do
        -- just update_autoconnect_stripe_node caused artifacts, idk why
        hightech.internal.update_surrounding_autoconnect_stripe_nodes("hightech:dark_stripe_top_autoconnect", pos)
    end
end)