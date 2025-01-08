if not minetest.settings:get_bool("enable_damage") or
        minetest.settings:get_bool("creative_mode") then
    error("enable_damage = true and creative_mode = false are required")
end

minetest.register_on_newplayer(function(player)
    player:get_inventory():add_item("main", "shooter:machine_gun")
    player:get_inventory():add_item("main", "shooter:ammo 4")
end)

minetest.register_on_joinplayer(function(plaer, last_login)
    core.set_timeofday(0.75)
end)

core.register_node("szombie_core:spawner", {
    -- drawtype = "airlike",
    -- for debugging:
    drawtype = "normal",
    tiles = {"default_dirt.png"},
    light_source = core.LIGHT_MAX / 4,

    diggable = false,
    buildable_to = false,
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    pointable = false,
})
core.register_alias_force("stairs:stair_inner_glass", "szombie_core:spawner")
