dofile(core.get_modpath(core.get_current_modname()) .. "/env.lua")
dofile(core.get_modpath(core.get_current_modname()) .. "/mapgen.lua")
if not core.settings:get_bool("creative_mode") then
    dofile(core.get_modpath(core.get_current_modname()) .. "/gamelogic.lua")
end
