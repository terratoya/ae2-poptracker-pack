ENABLE_DEBUG_LOG = false

print("-- Ape Escape 2 Tracker --")
print("Loaded variant: " .. Tracker.ActiveVariantUID)

ScriptHost:LoadScript("scripts/logic/generated_data.lua")
ScriptHost:LoadScript("scripts/logic/logic.lua")

Tracker:AddItems("items/items.jsonc")
Tracker:AddMaps("maps/maps.jsonc")
Tracker:AddLocations("locations/logic/monkeys.jsonc")
Tracker:AddLocations("locations/logic/phones.jsonc")
Tracker:AddLocations("locations/logic/gotcha_box.jsonc")
Tracker:AddLocations("locations/ui/levels.jsonc")
Tracker:AddLocations("locations/ui/phones.jsonc")
Tracker:AddLocations("locations/ui/gotcha_box.jsonc")
if Tracker.ActiveVariantUID ~= "var_itemsonly" and Tracker.ActiveVariantUID ~= "var_1_levelselect" then
    Tracker:AddLocations("locations/levels/01_liberty_island.jsonc")
    Tracker:AddLocations("locations/levels/02_breezy_village.jsonc")
    Tracker:AddLocations("locations/levels/03_port_calm.jsonc")
    Tracker:AddLocations("locations/levels/04_viva_apespania.jsonc")
    Tracker:AddLocations("locations/levels/05_blue_monkey_battle.jsonc")
    Tracker:AddLocations("locations/levels/06_castle_frightmare.jsonc")
    Tracker:AddLocations("locations/levels/07_vita_z_factory.jsonc")
    Tracker:AddLocations("locations/levels/08_casino_city.jsonc")
    Tracker:AddLocations("locations/levels/09_ninja_hideout.jsonc")
    Tracker:AddLocations("locations/levels/10_yellow_monkey_battle.jsonc")
    Tracker:AddLocations("locations/levels/11_snowball_mountain.jsonc")
    Tracker:AddLocations("locations/levels/12_lookout_valley.jsonc")
    Tracker:AddLocations("locations/levels/13_the_blue_baboon.jsonc")
    Tracker:AddLocations("locations/levels/14_pink_monkey_battle.jsonc")
    Tracker:AddLocations("locations/levels/15_enter_the_monkey.jsonc")
    Tracker:AddLocations("locations/levels/16_simian_citadel.jsonc")
    Tracker:AddLocations("locations/levels/17_panic_pyramid.jsonc")
    Tracker:AddLocations("locations/levels/18_white_monkey_battle.jsonc")
    Tracker:AddLocations("locations/levels/19_pirate_isle.jsonc")
    Tracker:AddLocations("locations/levels/20_land_of_the_apes.jsonc")
    Tracker:AddLocations("locations/levels/21_the_lost_world.jsonc")
    Tracker:AddLocations("locations/levels/22_red_monkey_battle.jsonc")
    Tracker:AddLocations("locations/levels/23_skyscraper_city.jsonc")
    Tracker:AddLocations("locations/levels/24_code_c_h_i_m_p.jsonc")
    Tracker:AddLocations("locations/levels/25_giant_yellow_monkey_battle.jsonc")
    Tracker:AddLocations("locations/levels/26_moon_base.jsonc")
    Tracker:AddLocations("locations/levels/27_showdown_with_specter.jsonc")
    Tracker:AddLocations("locations/levels/28_final_showdown_with_specter.jsonc")
end
Tracker:AddLayouts("layouts/items.jsonc")
if Tracker.ActiveVariantUID ~= "var_itemsonly" then
    Tracker:AddItems("items/entrances.jsonc")
    Tracker:AddLayouts("layouts/entrances.jsonc")
end
ScriptHost:LoadScript("scripts/entrance_data.lua")
ScriptHost:LoadScript("scripts/entrances.lua")
Tracker:AddLayouts("layouts/tracker.jsonc")
if Tracker.ActiveVariantUID == "var_itemsonly" then
    Tracker:AddLayouts("layouts/tracker_items_only.jsonc")
elseif Tracker.ActiveVariantUID == "var_1_levelselect" then
    Tracker:AddLayouts("layouts/tracker_level_select.jsonc")
end
ScriptHost:LoadScript("scripts/layout.lua")

if Archipelago ~= nil then
    ScriptHost:LoadScript("scripts/autotracking.lua")
end
