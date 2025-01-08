minetest.register_node("szombie_core:checkerboard", {
    tiles = { "trak2_tile1b.tga" },
})
minetest.register_alias("szombie_core:stone", "szombie_core:checkerboard")

local GENERATE_VARIANTS_MODE = false

if GENERATE_VARIANTS_MODE then
    dofile(core.get_modpath("szombie_core") .. "/mapgen_generate_schematic_variants.lua")
elseif core.settings:get_bool("creative_mode") then
    dofile(core.get_modpath("szombie_core") .. "/mapgen_creative.lua")
else
    dofile(core.get_modpath("szombie_core") .. "/mapgen_survival.lua")
end
