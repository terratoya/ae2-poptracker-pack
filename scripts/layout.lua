local current_layout = nil
local show_restocks = true -- Keep manual tracking available before connecting.

function update_other_layout()
    local path = show_restocks and "layouts/others/default_restocks.jsonc" or
        "layouts/others/default.jsonc"
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

update_other_layout()
