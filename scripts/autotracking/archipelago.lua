-- Archipelago callbacks for Ape Escape 2.

ScriptHost:LoadScript("scripts/autotracking/item_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/location_mapping.lua")

local current_item_index = -1

local function debug_log(message)
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then print(message) end
end

local function reset_item(code)
    local item = Tracker:FindObjectForCode(code)
    if item == nil then
        debug_log("Could not reset unknown item: " .. code)
        return
    end

    if item.Type == "toggle" or item.Type == "toggle_badged" then
        item.Active = false
    elseif item.Type == "progressive" or item.Type == "progressive_toggle" then
        item.CurrentStage = 0
        item.Active = false
    elseif item.Type == "consumable" then
        item.AcquiredCount = 0
    else
        debug_log("Unsupported item type for reset: " .. tostring(item.Type))
    end
end

local function increment_item(code, multiplier)
    local item = Tracker:FindObjectForCode(code)
    if item == nil then
        debug_log("Could not increment unknown item: " .. code)
        return
    end

    if item.Type == "toggle" or item.Type == "toggle_badged" then
        item.Active = true
    elseif item.Type == "progressive" or item.Type == "progressive_toggle" then
        if item.Active then
            item.CurrentStage = item.CurrentStage + 1
        else
            item.Active = true
        end
    elseif item.Type == "consumable" then
        item.AcquiredCount = item.AcquiredCount + (multiplier or 1)
    else
        debug_log("Unsupported item type for increment: " .. tostring(item.Type))
    end
end

local function validate_connected_game()
    if Archipelago.GetPlayerGame == nil or Archipelago.PlayerNumber == nil then return end
    local game = Archipelago:GetPlayerGame(Archipelago.PlayerNumber)
    if game ~= nil and game ~= "Ape Escape 2" then
        print("Ape Escape 2 tracker connected to an unexpected game: " .. tostring(game))
    end
end

local function on_clear(slot_data)
    Tracker.BulkUpdate = true
    current_item_index = -1

    local reset_codes = {}
    for _, mappings in pairs(ITEM_MAPPING) do
        for _, mapping in ipairs(mappings) do
            local code = mapping[1]
            if code ~= nil and not reset_codes[code] then
                reset_item(code)
                reset_codes[code] = true
            end
        end
    end

    for _, mappings in pairs(LOCATION_MAPPING) do
        for _, mapping in ipairs(mappings) do
            local section = Tracker:FindObjectForCode(mapping[1])
            if section ~= nil then
                section.AvailableChestCount = section.ChestCount
                if section.Highlight ~= nil and Highlight ~= nil then
                    section.Highlight = Highlight.None
                end
            end
        end
    end

    apply_slot_data(slot_data)
    reset_entrance_checked_locations(Archipelago.CheckedLocations)
    set_active_locations(Archipelago.MissingLocations, Archipelago.CheckedLocations)
    local goal_item = Tracker:FindObjectForCode("setting_final_specter_goal")
    if goal_item ~= nil then
        goal_item.Active = Archipelago.MissingLocations ~= nil and
            (function()
                for _, location_id in ipairs(Archipelago.MissingLocations) do
                    if location_id == 308 then return true end
                end
                for _, location_id in ipairs(Archipelago.CheckedLocations or {}) do
                    if location_id == 308 then return true end
                end
                return false
            end)()
    end
    validate_connected_game()
    Tracker.BulkUpdate = false
end

local function on_item(index, item_id, item_name, player_number)
    if not AUTOTRACKER_ENABLE_ITEM_TRACKING or index <= current_item_index then return end
    current_item_index = index

    local mappings = ITEM_MAPPING[item_id]
    if mappings == nil then
        debug_log("No item mapping for " .. tostring(item_id) .. " (" .. tostring(item_name) .. ")")
        return
    end
    for _, mapping in ipairs(mappings) do increment_item(mapping[1], mapping[3]) end
end

local function on_location(location_id, location_name)
    if not AUTOTRACKER_ENABLE_LOCATION_TRACKING then return end
    on_entrance_location_checked(location_id)
    local mappings = LOCATION_MAPPING[location_id]
    if mappings == nil then
        debug_log("No location mapping for " .. tostring(location_id) .. " (" .. tostring(location_name) .. ")")
        return
    end

    for _, mapping in ipairs(mappings) do
        local section = Tracker:FindObjectForCode(mapping[1])
        if section ~= nil then section.AvailableChestCount = 0 end
    end
end

Archipelago:AddClearHandler("AE2 reset and slot data", on_clear)
Archipelago:AddItemHandler("AE2 items", on_item)
Archipelago:AddLocationHandler("AE2 locations", on_location)
