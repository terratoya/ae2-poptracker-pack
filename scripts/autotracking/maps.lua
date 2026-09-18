-- Follow the actual stage published by the AE2 client through AP Data Storage.
local map_key = nil
local current_level = nil

local function activate_current_map()
    if Tracker.ActiveVariantUID ~= "standard" or current_level == nil then return end
    local setting = Tracker:FindObjectForCode("setting_auto_map_switch")
    if setting == nil or not setting.Active then return end
    Tracker:UiHint("ActivateTab", current_level)
end

local function on_map_value(key, value)
    if key ~= map_key then return end
    if type(value) ~= "string" or
        (value ~= "Travel Station" and LEVEL_DATA[value] == nil) then
        current_level = nil
        return
    end
    if value == current_level then return end
    current_level = value
    activate_current_map()
end

local function on_map_clear()
    map_key = nil
    current_level = nil
    if Tracker.ActiveVariantUID ~= "standard" then return end
    if Archipelago.TeamNumber == nil or Archipelago.PlayerNumber == nil or
        Archipelago.TeamNumber < 0 or Archipelago.PlayerNumber < 0 then return end
    map_key = "ae2_current_level_" .. Archipelago.TeamNumber .. "_" .. Archipelago.PlayerNumber
    Archipelago:SetNotify({map_key})
    Archipelago:Get({map_key})
end

Archipelago:AddClearHandler("AE2 map subscription", on_map_clear)
Archipelago:AddRetrievedHandler("AE2 initial map", on_map_value)
Archipelago:AddSetReplyHandler("AE2 map changes", on_map_value)
ScriptHost:AddWatchForCode("AE2 automatic map setting", "setting_auto_map_switch", activate_current_map)
