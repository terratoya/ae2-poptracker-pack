-- Ape Escape 2 access logic.

LOGIC_SETTINGS = {
    logic_difficulty = 0,
    damage_boost_logic = true,
    air_crawl_logic = false,
    boost_jump_logic = false,
    boost_fly_logic = false,
    long_jump_logic = false,
    hidden_monkey_logic = false,
    gotcha_box_locations = 0,
    gotcha_box_gating = 1,
    world_key_requirements = {},
    randomised_starting_rooms = {},
    randomised_gates = {}
}

local ITEM_CODES = {
    ["Monkey Net"] = "monkey_net", ["Stun Club"] = "stun_club",
    ["Monkey Radar"] = "monkey_radar", ["Water Net"] = "water_net",
    ["Dash Hoop"] = "dash_hoop", ["Sky Flyer"] = "sky_flyer",
    ["R.C. Car"] = "rc_car", ["Bananarang"] = "bananarang",
    ["Water Cannon"] = "water_cannon", ["Electro Magnet"] = "electro_magnet",
    ["Power Punch"] = "power_punch", ["Pipotchi"] = "character_hikaru",
    ["See-All Scope"] = "see_all_scope", ["Air Crawl"] = "air_crawl"
}

local GLITCH_MODE = false
local UNKNOWN_REQUIREMENTS = {}
local ACTIVE_LOCATION_IDS = nil
local function item_count(code) return Tracker:ProviderCountForCode(code) end
function has_item(code) return item_count(code) > 0 end

local function has_archipelago_item(name)
    if name == "Catapult" then
        return has_item("catapult") or has_item("progressive_catapult")
    end
    local code = ITEM_CODES[name]
    return code ~= nil and has_item(code)
end

local function is_hard_logic()
    return GLITCH_MODE or has_item("logic_hard") or has_item("logic_expert")
end
local function is_expert_logic() return GLITCH_MODE or has_item("logic_expert") end

local function can_air_crawl()
    if not GLITCH_MODE and not has_item("setting_air_crawl") then return false end
    return (has_item("catapult") and has_item("air_crawl")) or
        has_item("progressive_catapult_2")
end

local function can_long_jump()
    return has_archipelago_item("Dash Hoop") and
        (GLITCH_MODE or has_item("setting_long_jump"))
end

local function has_non_net_gadget()
    local names = {"Stun Club", "Monkey Radar", "Dash Hoop", "Catapult", "Sky Flyer",
        "R.C. Car", "Bananarang", "Water Cannon", "Electro Magnet", "Power Punch"}
    for _, name in ipairs(names) do
        if has_archipelago_item(name) then return true end
    end
    return false
end

local function can_boost_fly()
    if GLITCH_MODE then return has_archipelago_item("Sky Flyer") end
    return has_archipelago_item("Sky Flyer") and
        has_item("setting_boost_fly") and
        (has_archipelago_item("Monkey Net") or has_archipelago_item("Electro Magnet") or
            has_archipelago_item("Stun Club") or has_archipelago_item("Power Punch"))
end

local function can_boost_jump()
    return has_archipelago_item("Monkey Net") and has_non_net_gadget() and
        (GLITCH_MODE or has_item("setting_boost_jump"))
end

local function requirement_met(requirement)
    if requirement:sub(1, 1) ~= "*" then return has_archipelago_item(requirement) end

    if requirement == "*Air Crawl" then return can_air_crawl()
    elseif requirement == "*Damage Boost" then
        return GLITCH_MODE or has_item("setting_damage_boost")
    elseif requirement == "*Boost Fly" then return can_boost_fly()
    elseif requirement == "*Boost Jump" then return can_boost_jump()
    elseif requirement == "*Long Jump" then return can_long_jump()
    elseif requirement == "*Hard" then return is_hard_logic()
    elseif requirement == "*Expert" then return is_expert_logic()
    elseif requirement == "*Attack" then
        return has_archipelago_item("Stun Club") or has_archipelago_item("Power Punch") or
            has_archipelago_item("Dash Hoop")
    elseif requirement == "*Punch" then
        return has_archipelago_item("Power Punch") and
            (has_archipelago_item("See-All Scope") or GLITCH_MODE or not has_item("setting_hidden_monkeys"))
    elseif requirement == "*Radar" then
        return has_archipelago_item("Monkey Radar") or GLITCH_MODE or not has_item("setting_hidden_monkeys")
    elseif requirement == "*Non-Net" then return has_non_net_gadget()
    elseif requirement == "*Gear" then
        return has_archipelago_item("Stun Club") or has_archipelago_item("Power Punch")
    elseif requirement == "*Bull Fight" then
        return has_archipelago_item("Catapult") or has_archipelago_item("Stun Club") or
            has_archipelago_item("Power Punch") or has_archipelago_item("Dash Hoop") or
            (has_archipelago_item("Sky Flyer") and is_expert_logic())
    elseif requirement == "*UFO" then
        return is_hard_logic() or has_archipelago_item("Catapult") or
            has_archipelago_item("Stun Club") or has_archipelago_item("Power Punch")
    elseif requirement == "*Valley Gap" then
        return (has_archipelago_item("Sky Flyer") and has_archipelago_item("Catapult")) or
            (is_expert_logic() and (((has_archipelago_item("Power Punch") or
                has_archipelago_item("Sky Flyer")) and has_archipelago_item("Water Net")) or
                has_archipelago_item("Catapult"))) or can_air_crawl() or
            (is_expert_logic() and can_long_jump() and
                (has_archipelago_item("Pipotchi") or has_archipelago_item("Stun Club")))
    elseif requirement == "*Valley Island" then
        return has_archipelago_item("Water Net") or
            (is_hard_logic() and has_archipelago_item("Sky Flyer")) or can_air_crawl() or
            (is_expert_logic() and can_long_jump())
    elseif requirement == "*Valley Boat" then
        return has_archipelago_item("Water Net") or
            (is_hard_logic() and has_archipelago_item("Sky Flyer")) or can_air_crawl()
    elseif requirement == "*Valley Button" then
        return has_archipelago_item("Catapult") or
            (is_hard_logic() and has_archipelago_item("Water Net") and
                (has_archipelago_item("Sky Flyer") or has_archipelago_item("Stun Club"))) or
            can_air_crawl()
    elseif requirement == "*Valley Stalag" then
        return has_archipelago_item("R.C. Car") or
            (is_hard_logic() and has_archipelago_item("Sky Flyer")) or can_air_crawl()
    elseif requirement == "*Pyramid Sarcophagus" then
        return has_archipelago_item("Catapult") or
            (can_boost_fly() and has_archipelago_item("Sky Flyer") and is_hard_logic())
    elseif requirement == "*Moon Fire" then
        return has_archipelago_item("Water Cannon") or
            GLITCH_MODE or has_item("setting_damage_boost") or can_air_crawl()
    end

    if not UNKNOWN_REQUIREMENTS[requirement] then
        UNKNOWN_REQUIREMENTS[requirement] = true
        print("Unknown Ape Escape 2 logic requirement: " .. requirement)
    end
    return false
end

local function alternatives_met(alternatives)
    for _, requirements in ipairs(alternatives or {}) do
        local all_met = true
        for _, requirement in ipairs(requirements) do
            if not requirement_met(requirement) then all_met = false break end
        end
        if all_met then return true end
    end
    return false
end

local function starting_entrance(level_name, level)
    local index = LOGIC_SETTINGS.randomised_starting_rooms[level_name]
    if index ~= nil and level.room_entrances[index + 1] ~= nil then
        return level.room_entrances[index + 1].name
    end
    return "Entry from Spawn"
end

local function reachable_entrances(level_name)
    local level = LEVEL_DATA[level_name]
    local reachable = {[starting_entrance(level_name, level)] = true}
    local changed = true
    while changed do
        changed = false
        for _, source in ipairs(level.room_entrances) do
            if reachable[source.name] then
                for destination, alternatives in pairs(source.connection_requirements) do
                    local gate_key = destination .. " - " .. level_name
                    local actual_destination = LOGIC_SETTINGS.randomised_gates[gate_key] or destination
                    actual_destination = actual_destination:gsub(" %- " .. level_name .. "$", "")
                    if not reachable[actual_destination] and alternatives_met(alternatives) then
                        reachable[actual_destination] = true
                        changed = true
                    end
                end
            end
        end
    end
    return reachable
end

local function can_access_level(level_name)
    return item_count("world_key") >= (LOGIC_SETTINGS.world_key_requirements[level_name] or 0)
end

function set_active_locations(missing_locations, checked_locations)
    if missing_locations == nil and checked_locations == nil then
        ACTIVE_LOCATION_IDS = nil
        return
    end

    ACTIVE_LOCATION_IDS = {}
    for _, location_id in ipairs(missing_locations or {}) do ACTIVE_LOCATION_IDS[location_id] = true end
    for _, location_id in ipairs(checked_locations or {}) do ACTIVE_LOCATION_IDS[location_id] = true end
end

function is_location_active(location_id)
    return ACTIVE_LOCATION_IDS == nil or ACTIVE_LOCATION_IDS[tonumber(location_id)] == true
end

function is_level_active(level_name)
    if ACTIVE_LOCATION_IDS == nil then
        return level_name ~= "Final Showdown with Specter!" or has_item("setting_final_specter_goal")
    end
    for location_id, monkey in pairs(MONKEY_DATA) do
        if monkey.level == level_name and ACTIVE_LOCATION_IDS[location_id] then return true end
    end
    return false
end

function is_phone_level_active(level_name)
    if ACTIVE_LOCATION_IDS == nil then return has_item("setting_message_phones") end
    for location_id, phone in pairs(PHONE_DATA) do
        if phone.level == level_name and ACTIVE_LOCATION_IDS[location_id] then return true end
    end
    return false
end

function is_gotcha_box_range_active(first_number, last_number)
    if ACTIVE_LOCATION_IDS == nil then return false end
    for number = tonumber(first_number), tonumber(last_number) do
        if ACTIVE_LOCATION_IDS[2000 + number] then return true end
    end
    return false
end

local function can_reach_monkey_core(monkey_id)
    local monkey = MONKEY_DATA[tonumber(monkey_id)]
    if monkey == nil or not can_access_level(monkey.level) then return false end
    local reachable = reachable_entrances(monkey.level)
    for entrance, alternatives in pairs(monkey.connection_requirements) do
        if reachable[entrance] and alternatives_met(alternatives) then return true end
    end
    return false
end

function can_reach_monkey(monkey_id)
    monkey_id = tonumber(monkey_id)
    local monkey = MONKEY_DATA[monkey_id]
    if monkey == nil then return false end

    if monkey.level == "Final Showdown with Specter!" then
        for other_id, _ in pairs(MONKEY_DATA) do
            if other_id ~= monkey_id and is_location_active(other_id) and
                not can_reach_monkey_core(other_id) then
                return false
            end
        end
    end
    return can_reach_monkey_core(monkey_id)
end

function can_reach_phone(phone_id)
    local phone = PHONE_DATA[tonumber(phone_id)]
    if phone == nil or not can_access_level(phone.level) then return false end
    local reachable = reachable_entrances(phone.level)
    for entrance, alternatives in pairs(phone.connection_requirements) do
        if reachable[entrance] and alternatives_met(alternatives) then return true end
    end
    return false
end

local CATCHABLE_CACHE = {signature = nil, count = 0}

local function logic_signature()
    local codes = {
        "monkey_net", "stun_club", "monkey_radar", "water_net", "dash_hoop",
        "catapult", "progressive_catapult", "progressive_catapult_2", "sky_flyer",
        "rc_car", "bananarang", "water_cannon", "electro_magnet", "power_punch",
        "character_hikaru", "see_all_scope", "air_crawl", "world_key",
        "logic_normal", "logic_hard", "logic_expert", "setting_hidden_monkeys",
        "setting_damage_boost", "setting_air_crawl", "setting_boost_jump",
        "setting_boost_fly", "setting_long_jump"
    }
    local values = {tostring(GLITCH_MODE)}
    for _, code in ipairs(codes) do values[#values + 1] = tostring(item_count(code)) end
    return table.concat(values, ":")
end

local function count_catchable_monkeys()
    local signature = logic_signature()
    if CATCHABLE_CACHE.signature == signature then return CATCHABLE_CACHE.count end
    local count = 0
    for monkey_id, monkey in pairs(MONKEY_DATA) do
        if monkey.level ~= "Final Showdown with Specter!" and is_location_active(monkey_id) and
            can_reach_monkey_core(monkey_id) then
            count = count + 1
        end
    end
    CATCHABLE_CACHE.signature = signature
    CATCHABLE_CACHE.count = count
    return count
end

local function unlocked_level_count()
    local keys = item_count("world_key")
    local count = 0
    for _, requirement in pairs(LOGIC_SETTINGS.world_key_requirements) do
        if requirement <= keys then count = count + 1 end
    end
    return count
end

function can_reach_gotcha_box(zero_based_number)
    zero_based_number = tonumber(zero_based_number)
    local total = LOGIC_SETTINGS.gotcha_box_locations
    if total == nil or total <= 0 or zero_based_number >= total then return false end
    local percentage = zero_based_number / total
    local unlocked = unlocked_level_count()

    if LOGIC_SETTINGS.gotcha_box_gating == 1 then
        if unlocked < math.floor(26 * percentage) then return false end
    elseif LOGIC_SETTINGS.gotcha_box_gating == 2 then
        if item_count("gotcha_box_restock") < math.floor(zero_based_number / 10) then return false end
    end

    if GLITCH_MODE then return true end
    local expected_levels = math.floor(math.sqrt(percentage) * 26)
    return unlocked > expected_levels and count_catchable_monkeys() > 300 * (percentage - 0.05)
end

local function set_toggle(code, active)
    local item = Tracker:FindObjectForCode(code)
    if item ~= nil then item.Active = active end
end

local function set_stage(code, stage)
    local item = Tracker:FindObjectForCode(code)
    if item ~= nil then item.CurrentStage = stage end
end

function apply_slot_data(slot_data)
    slot_data = slot_data or {}
    CATCHABLE_CACHE.signature = nil
    LOGIC_SETTINGS.logic_difficulty = slot_data.logic_difficulty or 0
    LOGIC_SETTINGS.damage_boost_logic = slot_data.damage_boost_logic ~= false and
        slot_data.damage_boost_logic ~= 0
    LOGIC_SETTINGS.air_crawl_logic = slot_data.air_crawl_logic == true or slot_data.air_crawl_logic == 1
    LOGIC_SETTINGS.boost_jump_logic = slot_data.boost_jump_logic == true or slot_data.boost_jump_logic == 1
    LOGIC_SETTINGS.boost_fly_logic = slot_data.boost_fly_logic == true or slot_data.boost_fly_logic == 1
    LOGIC_SETTINGS.long_jump_logic = slot_data.long_jump_logic == true or slot_data.long_jump_logic == 1
    LOGIC_SETTINGS.hidden_monkey_logic = slot_data.hidden_monkey_logic == true or
        slot_data.hidden_monkey_logic == 1
    LOGIC_SETTINGS.world_key_requirements = slot_data.world_key_requirements or {}
    LOGIC_SETTINGS.randomised_starting_rooms = slot_data.randomised_starting_rooms or {}
    LOGIC_SETTINGS.randomised_gates = slot_data.randomised_gates or {}
    LOGIC_SETTINGS.gotcha_box_locations = slot_data.gotcha_box_locations or 0
    LOGIC_SETTINGS.gotcha_box_gating = slot_data.gotcha_box_gating or 1

    set_stage("logic_normal", LOGIC_SETTINGS.logic_difficulty)
    if slot_data.character == 0 or slot_data.character == 1 then
        set_stage("character_hikaru", slot_data.character)
    end
    set_toggle("setting_hidden_monkeys", LOGIC_SETTINGS.hidden_monkey_logic)
    set_toggle("setting_air_crawl", LOGIC_SETTINGS.air_crawl_logic)
    set_toggle("setting_message_phones", slot_data.message_phone_locations == true or
        slot_data.message_phone_locations == 1)
    set_toggle("setting_damage_boost", LOGIC_SETTINGS.damage_boost_logic)
    set_toggle("setting_boost_jump", LOGIC_SETTINGS.boost_jump_logic)
    set_toggle("setting_boost_fly", LOGIC_SETTINGS.boost_fly_logic)
    set_toggle("setting_long_jump", LOGIC_SETTINGS.long_jump_logic)
    apply_layout_slot_data(slot_data)
    apply_entrance_slot_data(slot_data)
end

-- Evaluate normal access before the world's Glitched Item rules.
-- Reachability helpers stay boolean so internal graph traversal cannot treat 0 as true.
local function location_accessibility(check, id)
    if check(id) then return AccessibilityLevel.Normal end
    GLITCH_MODE = true
    local ok, reachable = pcall(check, id)
    GLITCH_MODE = false
    if not ok then error(reachable) end
    return reachable and AccessibilityLevel.SequenceBreak or AccessibilityLevel.None
end

function monkey_accessibility(id)
    return location_accessibility(can_reach_monkey, id)
end

function phone_accessibility(id)
    return location_accessibility(can_reach_phone, id)
end

function gotcha_box_accessibility(id)
    return location_accessibility(can_reach_gotcha_box, id)
end
