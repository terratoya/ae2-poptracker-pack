local automatic = false
local automatic_stages = {}
local key_requirements = {}
local checked_monkeys = {}
local stage_for_name = {}
for stage, name in ipairs(ENTRANCE_LEVEL_NAMES) do stage_for_name[name] = stage end

local function set_destination(slot, stage)
    local item = Tracker:FindObjectForCode("entrance_destination_" .. slot)
    if item ~= nil then item.CurrentStage = stage end
end

function update_entrance_visibility()
    if not automatic then return end
    local keys = Tracker:ProviderCountForCode("world_key")
    local final_unlocked = checked_monkeys[308] == true
    if not final_unlocked then
        final_unlocked = true
        for id = 1, 307 do
            if not checked_monkeys[id] then final_unlocked = false; break end
        end
    end
    for slot = 1, 28 do
        local stage = automatic_stages[slot]
        local visible = false
        if stage == 28 then
            visible = final_unlocked
        elseif stage ~= nil then
            local cost = key_requirements[ENTRANCE_LEVEL_NAMES[stage]]
            visible = type(cost) == "number" and cost >= 0 and keys >= cost
        end
        set_destination(slot, visible and stage or 0)
    end
end

function reset_entrance_checked_locations(checked_locations)
    checked_monkeys = {}
    for _, id in ipairs(checked_locations or {}) do checked_monkeys[id] = true end
    update_entrance_visibility()
end

function on_entrance_location_checked(location_id)
    checked_monkeys[location_id] = true
    if location_id >= 1 and location_id <= 308 then update_entrance_visibility() end
end

local function validate_order(order)
    if type(order) ~= "table" then return nil end
    local count = #order
    if count ~= 27 and count ~= 28 then return nil end
    local seen, stages = {}, {}
    for key, name in pairs(order) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > count then return nil end
        if type(name) ~= "string" or stage_for_name[name] == nil or seen[name] then return nil end
        seen[name] = true
        stages[key] = stage_for_name[name]
    end
    for slot = 1, count do if stages[slot] == nil then return nil end end
    -- Only Final Showdown may be omitted by the Specter goal.
    if count == 27 and seen[ENTRANCE_LEVEL_NAMES[28]] then return nil end
    return stages
end

function apply_entrance_slot_data(slot_data)
    local order = (slot_data or {}).level_order
    local stages = validate_order(order)
    if stages ~= nil then
        automatic_stages = stages
        key_requirements = type(slot_data.world_key_requirements) == "table" and
            slot_data.world_key_requirements or {}
        checked_monkeys = {}
        automatic = true
        update_entrance_visibility()
        print("AE2: AP level destinations will be revealed as levels unlock.")
    else
        -- Clear automatic destinations when the slot has no valid mapping.
        -- Preserve manual selections across reconnects.
        if automatic then
            for slot = 1, 28 do set_destination(slot, 0) end
        end
        automatic = false
        if order ~= nil then print("AE2: invalid level_order; using manual entrance tracking.") end
    end
end

ScriptHost:AddWatchForCode("AE2 entrance unlocks", "world_key", update_entrance_visibility)
