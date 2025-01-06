minetest.register_on_joinplayer(function(plaer, last_login)
    plaer:set_lighting({
        saturation = 1,
        shadows = {
            intensity = 0.33,
            -- tint = "indianred",
        },   
        bloom = {
            intensity = 0.05,
            strength_factor = 2,
            radius = 2.2,
        },
        volumetric_light = {
            strength = 0.05,
        },
    })
    plaer:set_sky({
        type = "skybox",
        textures = {
            "skybox_up.png^[transformR90",
            "skybox_down.png^[transformR270",
            "skybox_right.png",
            "skybox_left.png",
            "skybox_front.png",
            "skybox_back.png",
        },
    })
    plaer:set_sun({
        -- looks ugly on custom skybox
        sunrise_visible = false,
    })
end)

minetest.register_globalstep(function(dtime)
    for _, pop in ipairs(core.get_connected_players()) do
        local color = core.colorspec_to_table("#2f2f2f")
        local factor = core.time_to_day_night_ratio(core.get_timeofday())
        --print("factor = " ..dump(factor))
        --print("color before = " ..dump(color))
        color.r = color.r * factor
        color.g = color.g * factor
        color.b = color.b * factor
        --print("color after = " ..dump(color))
        pop:set_sky({
            type = "skybox",
            textures = {
                "skybox_up.png^[transformR90",
                "skybox_down.png^[transformR270",
                "skybox_right.png",
                "skybox_left.png",
                "skybox_front.png",
                "skybox_back.png",
            },
            -- make fog blend with floor
            base_color = color,
        })
    end 
end)
