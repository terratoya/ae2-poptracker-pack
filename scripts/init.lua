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
end
ScriptHost:LoadScript("scripts/layout.lua")

if Archipelago ~= nil then
    ScriptHost:LoadScript("scripts/autotracking.lua")
end
