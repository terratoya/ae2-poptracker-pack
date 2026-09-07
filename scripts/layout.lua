local current_layout = nil
local show_restocks = true -- Keep manual tracking available before connecting.

function update_other_layout()
    local behaviour = Tracker:FindObjectForCode("air_crawl_behaviour_default")
    local stage = behaviour and behaviour.CurrentStage or 0
    local mode = "default"
    if stage == 2 then mode = "item"
    elseif stage == 3 then mode = "progressive" end
    local path = "layouts/others/" .. mode ..
        (show_restocks and "_restocks" or "") .. ".jsonc"
    if path ~= current_layout then
        Tracker:AddLayouts(path)
        current_layout = path
    end
end

function apply_layout_slot_data(slot_data)
    slot_data = slot_data or {}
    -- The world generates restocks only for item gating and > 10 checks.
    show_restocks = slot_data.gotcha_box_gating == nil or
        slot_data.gotcha_box_locations == nil or
        (slot_data.gotcha_box_gating == 2 and slot_data.gotcha_box_locations > 10)
    update_other_layout()
end

ScriptHost:AddWatchForCode("AE2 other items layout",
    "air_crawl_behaviour_default", update_other_layout)
update_other_layout()
