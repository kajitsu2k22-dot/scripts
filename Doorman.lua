---@diagnostic disable: undefined-global

local doorman = {}

local UNIT_METER = 37.7358490566
local DEBUG_PREFIX = "[Doorman]"
local HERO_RECHECK_INTERVAL = 0.75
local READY_EPSILON = 0.05
local GLOBAL_CAST_DELAY = 0.08
local A3_REPRESS_DELAY = 0.35
local WALL_SCORE_THRESHOLD = 0.08
local TARGET_STICKY_FOV_BUFFER = 8.0
local TARGET_STICKY_RANGE_BUFFER_M = 4.0
local HARDLOCK_SETTLE_DELAY = 0.03
local HARDLOCK_CAST_FOV = 1.75
local DOORWAY_ITEM_SETTLE_DELAY = 0.08
local DOORWAY_CONFIRM_SETTLE_DELAY = 0.03
local DOORWAY_POST_CONFIRM_DELAY = 0.03
local DOORWAY_RETRY_DELAY = 0.04
local DOORWAY_ACCEPT_TIMEOUT = 0.16
local DOORWAY_A3_HOLD_DELAY = 0.03
local DOORWAY_VORTEX_ACCEPT_TIMEOUT = 0.24
local VORTEX_WALL_SCORE_THRESHOLD = 0.02
local VORTEX_WEB_CODENAME = "upgrade_aoe_root"
local VORTEX_WEB_FALLBACK_RANGE = 1362.5
local VORTEX_WEB_FALLBACK_AOE = 545.0

local IDS = {
    HERO_DOORMAN = "hero_doorman",
    ABILITY_BOMB = "ability_doorman_bomb",
    ABILITY_DOORWAY = "ability_doorman_doorway",
    ABILITY_LUGGAGE = "ability_doorman_luggage_cart",
    ABILITY_HOTEL = "ability_doorman_hotel",
}

local MODE = {
    AIM_MODE_PSILENT_ONLY = 0,
    AIM_MODE_HARD_LOCK_FALLBACK = 1,
    CALL_BELL_USE_COMBO = 0,
    CALL_BELL_USE_AUTO = 1,
    DOORWAY_FOLLOWUP_AUTO = 0,
    DOORWAY_FOLLOWUP_A3_ONLY = 1,
    DOORWAY_FOLLOWUP_VORTEX_A3 = 2,
}

local STATUS = {
    READY = 0,
    COOLDOWN = 2,
    PASSIVE = 3,
    BUSY = 10,
}

local SLOT = {
    A1 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_1) or 0,
    A2 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_2) or 1,
    A3 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_3) or 2,
    A4 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_4) or 3,
    ITEM1 = 4,
    ITEM2 = 5,
    ITEM3 = 6,
    ITEM4 = 7,
}

local MODSTATE = {
    INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_INVULNERABLE) or 18,
    TECH_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_TECH_INVULNERABLE) or 19,
    TECH_DAMAGE_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_TECH_DAMAGE_INVULNERABLE) or 20,
    STATUS_IMMUNE = (EModifierState and EModifierState.MODIFIER_STATE_STATUS_IMMUNE) or 22,
    OUT_OF_GAME = (EModifierState and EModifierState.MODIFIER_STATE_OUT_OF_GAME) or 24,
    UNIT_STATUS_HIDDEN = (EModifierState and EModifierState.MODIFIER_STATE_UNIT_STATUS_HIDDEN) or 108,
    NO_INCOMING_DAMAGE = (EModifierState and EModifierState.MODIFIER_STATE_NO_INCOMING_DAMAGE) or 136,
}

local MENU_ITEMS = {
    AIM_MODE = {
        "P-Silent Only",
        "Hard Lock Fallback",
    },
    CALL_BELL_USE = {
        "Combo",
        "Auto",
    },
    DOORWAY_FOLLOWUP = {
        "Auto",
        "A3 Only",
        "Vortex + A3",
    },
}

local ICON = {
    TAB = "\u{f562}",
    ENABLE = "\u{f00c}",
    DEBUG = "\u{f188}",
    KEY = "\u{f084}",
    FOV = "\u{f06e}",
    RANGE = "\u{f124}",
    PSILENT = "\u{f05b}",
    HP = "\u{f21e}",
    ISOLATION = "\u{f0c0}",
    HOTEL_COMBO = "\u{f0e7}",
}

local IMAGE = {
    CALL_BELL = "panorama/images/spellicons/ability_doorman_bomb_png.vtex_c",
    DOORWAY = "panorama/images/spellicons/ability_doorman_doorway_png.vtex_c",
    LUGGAGE = "panorama/images/spellicons/ability_doorman_luggage_cart_png.vtex_c",
    HOTEL = "panorama/images/spellicons/ability_doorman_hotel_png.vtex_c",
}

local BONE_PRIORITY = {
    "spine_2",
    "spine_1",
    "chest",
    "neck_0",
    "head",
}

local WALL_DIRECTIONS = {
    Vector(1, 0, 0),
    Vector(-1, 0, 0),
    Vector(0, 1, 0),
    Vector(0, -1, 0),
    Vector(0.707, 0.707, 0),
    Vector(0.707, -0.707, 0),
    Vector(-0.707, 0.707, 0),
    Vector(-0.707, -0.707, 0),
}

local hero_root = Menu.Find("Heroes", "Hero List", "Doorman")
if not hero_root then
    hero_root = Menu.Create("Heroes", "Hero List", "Doorman")
end

local function find_or_create_third_tab(parent, name)
    local tab = parent and parent:Find(name) or nil
    if not tab then
        tab = parent:Create(name)
    end
    return tab
end

local function find_or_create_group(parent, name)
    local group = parent and parent:Find(name) or nil
    if not group then
        group = parent:Create(name)
    end
    return group
end

local function set_widget_icon(widget, icon, use_image)
    if not widget or not icon then
        return
    end

    pcall(function()
        if use_image and widget.Image then
            widget:Image(icon)
        elseif widget.Icon then
            widget:Icon(icon)
        end
    end)
end

local groups = {
    tab = find_or_create_third_tab(hero_root, "Doorman"),
}
groups.general = find_or_create_group(groups.tab, "General")
groups.combo = find_or_create_group(groups.tab, "Combo Settings")
groups.call_bell = find_or_create_group(groups.tab, "Call Bell (1)")
groups.doorway = find_or_create_group(groups.tab, "Doorway (2)")
groups.luggage = find_or_create_group(groups.tab, "Luggage Cart (3)")
groups.hotel = find_or_create_group(groups.tab, "Hotel Guest (4)")

set_widget_icon(groups.tab, ICON.TAB, false)

local enable_script = groups.general:Switch("Enable Script", true, ICON.ENABLE)
local debug_logging = groups.general:Switch("Debug Logging", false, ICON.DEBUG)

local combo_key = groups.combo:Bind("Combo Key", Enum.ButtonCode.KEY_NONE, ICON.KEY)
local target_fov = groups.combo:Slider("Target FOV", 1, 180, 28, "%d")
local target_max_distance_m = groups.combo:Slider("Target Max Distance (m)", 5, 75, 40, "%d")
local target_sticky_ms = groups.combo:Slider("Sticky Target (ms)", 100, 400, 280, "%d")

local call_bell_enabled = groups.call_bell:Switch("Use Call Bell (1)", true, IMAGE.CALL_BELL)
local doorway_enabled = groups.doorway:Switch("Use Doorway (2)", false, IMAGE.DOORWAY)
local luggage_enabled = groups.luggage:Switch("Use Luggage Cart (3)", true, IMAGE.LUGGAGE)
local hotel_enabled = groups.hotel:Switch("Auto Hotel Guest (4)", true, IMAGE.HOTEL)

local gear = {
    call_bell = call_bell_enabled:Gear("Call Bell Settings"),
    doorway = doorway_enabled:Gear("Doorway Settings"),
    luggage = luggage_enabled:Gear("Luggage Cart Settings"),
    hotel = hotel_enabled:Gear("Hotel Guest Settings"),
}

local call_bell_usage_mode = gear.call_bell:Combo("Usage Mode", MENU_ITEMS.CALL_BELL_USE, MODE.CALL_BELL_USE_COMBO)
local call_bell_mode = gear.call_bell:Combo("Aim Mode", MENU_ITEMS.AIM_MODE, MODE.AIM_MODE_HARD_LOCK_FALLBACK)
local call_bell_fov = gear.call_bell:Slider("Aim FOV", 1, 180, 28, "%d")
local call_bell_max_psilent = gear.call_bell:Slider("Max PSilent Degree", 1, 90, 24, "%d")
local call_bell_max_range_m = gear.call_bell:Slider("Max Range (m)", 5, 40, 18, "%d")
local call_bell_auto_shoot = gear.call_bell:Switch("Auto Shoot Bell", false)
local call_bell_min_shoot_enemies = gear.call_bell:Slider("Shoot Bell If Enemies >=", 1, 5, 2, "%d")

local doorway_use_in_combo = gear.doorway:Switch("Use in Combo", false)
local doorway_key = gear.doorway:Bind("Force Doorway Key", Enum.ButtonCode.KEY_NONE, ICON.KEY)
local doorway_confirm_delay_ms = gear.doorway:Slider("Confirm Delay (ms)", 0, 500, 0, "%d")
local doorway_item_delay_ms = gear.doorway:Slider("Item Delay (ms)", 0, 500, 0, "%d")
local doorway_offset_m = gear.doorway:Slider("Door Offset (m)", -15.0, 15.0, 0.0, "%.1f")
local doorway_followup_mode = gear.doorway:Combo("Follow-up Mode", MENU_ITEMS.DOORWAY_FOLLOWUP, MODE.DOORWAY_FOLLOWUP_AUTO)

local luggage_mode = gear.luggage:Combo("Aim Mode", MENU_ITEMS.AIM_MODE, MODE.AIM_MODE_HARD_LOCK_FALLBACK)
local luggage_fov = gear.luggage:Slider("Aim FOV", 1, 180, 30, "%d")
local luggage_force_below_hp = gear.luggage:Slider("Force Cast If HP Below (%)", 1, 100, 55, "%d")
local luggage_max_psilent = gear.luggage:Slider("Max PSilent Degree", 1, 90, 26, "%d")
local luggage_max_range_m = gear.luggage:Slider("Max Range (m)", 5, 50, 25, "%d")
local luggage_prefer_wall = gear.luggage:Switch("Prefer Wall Impact", true)
local luggage_prefer_wall_score = gear.luggage:Switch("Prefer Wall Impact (score)", false)

local hotel_use_in_combo = gear.hotel:Switch("Use in Combo", false)
local hotel_target_fov = gear.hotel:Slider("Target FOV", 1, 180, 42, "%d")
local hotel_target_max_distance_m = gear.hotel:Slider("Target Max Distance (m)", 5, 75, 45, "%d")
local hotel_hp_threshold = gear.hotel:Slider("HP Threshold (%)", 1, 100, 42, "%d")
local hotel_isolation_radius_m = gear.hotel:Slider("Isolation Radius (m)", 1, 20, 8, "%d")
local hotel_max_nearby = gear.hotel:Slider("Max Nearby Enemies", 0, 5, 1, "%d")

set_widget_icon(target_fov, ICON.FOV, false)
set_widget_icon(target_max_distance_m, ICON.RANGE, false)
set_widget_icon(target_sticky_ms, ICON.KEY, false)

set_widget_icon(call_bell_usage_mode, ICON.KEY, false)
set_widget_icon(call_bell_mode, "\u{f0f3}", false)
set_widget_icon(call_bell_fov, ICON.FOV, false)
set_widget_icon(call_bell_max_psilent, ICON.PSILENT, false)
set_widget_icon(call_bell_max_range_m, ICON.RANGE, false)
set_widget_icon(call_bell_auto_shoot, "\u{f04b}", false)
set_widget_icon(call_bell_min_shoot_enemies, ICON.ISOLATION, false)

set_widget_icon(doorway_use_in_combo, ICON.HOTEL_COMBO, false)
set_widget_icon(doorway_confirm_delay_ms, ICON.KEY, false)
set_widget_icon(doorway_item_delay_ms, ICON.KEY, false)
set_widget_icon(doorway_offset_m, ICON.RANGE, false)
set_widget_icon(doorway_followup_mode, IMAGE.LUGGAGE, true)

set_widget_icon(luggage_mode, "\u{f07a}", false)
set_widget_icon(luggage_fov, ICON.FOV, false)
set_widget_icon(luggage_force_below_hp, ICON.HP, false)
set_widget_icon(luggage_max_psilent, ICON.PSILENT, false)
set_widget_icon(luggage_max_range_m, ICON.RANGE, false)
set_widget_icon(luggage_prefer_wall, "\u{f6d9}", false)
set_widget_icon(luggage_prefer_wall_score, "\u{f201}", false)

set_widget_icon(hotel_use_in_combo, ICON.HOTEL_COMBO, false)
set_widget_icon(hotel_target_fov, ICON.FOV, false)
set_widget_icon(hotel_target_max_distance_m, ICON.RANGE, false)
set_widget_icon(hotel_hp_threshold, ICON.HP, false)
set_widget_icon(hotel_isolation_radius_m, ICON.RANGE, false)
set_widget_icon(hotel_max_nearby, ICON.ISOLATION, false)

enable_script:ToolTip("Master switch for the whole Doorman module.")
debug_logging:ToolTip("Print cast decisions and skip reasons into the Lua console.")
combo_key:ToolTip("Hold to run the main combat sequence.")
target_fov:ToolTip("Maximum FOV allowed for target selection.")
target_max_distance_m:ToolTip("Maximum target distance used by combo target selection.")
target_sticky_ms:ToolTip("Keep the current combo target for a short time before retargeting.")
call_bell_enabled:ToolTip("Enable Call Bell automation for the selected usage mode.")
call_bell_usage_mode:ToolTip("Combo casts A1 only with the combo key. Auto casts it automatically when a valid target is in bell range.")
call_bell_auto_shoot:ToolTip("Automatically shoot an active bell when enough enemies are inside its radius.")
call_bell_min_shoot_enemies:ToolTip("Minimum enemies required inside the bell radius before auto-shoot triggers.")
doorway_enabled:ToolTip("Enable Doorway automation using the doormancart-style placement flow.")
doorway_use_in_combo:ToolTip("Use Doorway as a combo opener before the rest of the sequence.")
doorway_key:ToolTip("Force Doorway placement on the current best target.")
doorway_confirm_delay_ms:ToolTip("Delay between pressing A2 and confirming the doorway with attack.")
doorway_item_delay_ms:ToolTip("Delay after the pre-door Vortex Web before casting Doorway.")
doorway_offset_m:ToolTip("Offset doorway placement along the line to the target. Negative values place it closer to you.")
doorway_followup_mode:ToolTip("Auto uses A3 only in close range and Vortex + A3 at longer range. Other modes force the chosen follow-up.")
luggage_enabled:ToolTip("Enable Luggage Cart automation inside combo.")
hotel_enabled:ToolTip("Enable isolated target checks for Hotel Guest.")
hotel_target_fov:ToolTip("Maximum FOV used by Hotel Guest target selection.")
hotel_target_max_distance_m:ToolTip("Maximum distance used by Hotel Guest target selection.")

local hero_cache = {
    handle = nil,
    is_doorman = false,
    last_check = 0.0,
}

local debug_state = {}
local last_cast_times = {
    a1 = 0.0,
    a2 = 0.0,
    a3 = 0.0,
    a4 = 0.0,
    bell_shot = 0.0,
    global = 0.0,
}

local combo_target_lock = {
    handle = nil,
    expires_at = 0.0,
}

local hardlock_state = {
    cast_key = nil,
    target_handle = nil,
    ready_at = 0.0,
}

local target_log_state = {
    selected_handle = nil,
    selected_fov = math.huge,
    selected_distance = math.huge,
    selected_logged_at = 0.0,
    sticky_handle = nil,
    sticky_fov = math.huge,
    sticky_distance = math.huge,
    sticky_logged_at = 0.0,
}

local doorway_state = {
    active = false,
    phase = nil,
    pos = nil,
    door_pos = nil,
    confirm_at = 0.0,
    next_action_at = 0.0,
    expires_at = 0.0,
    psilent_until = 0.0,
    phase_started_at = 0.0,
    retry_at = 0.0,
    cast_attempts = 0,
    vortex_confirm_attempted = false,
    target_handle = nil,
    vortex_handle = nil,
    reason = nil,
    used_vortex = false,
    last_key_down = false,
}

local function to_units(meters)
    return meters * UNIT_METER
end

local function now_seconds()
    return os.clock()
end

local function debug_log(key, message, min_interval)
    if not debug_logging:Get() then
        return
    end

    local now = now_seconds()
    min_interval = min_interval or 0.35

    if key then
        local last_time = debug_state[key] or 0.0
        if (now - last_time) < min_interval then
            return
        end
        debug_state[key] = now
    end

    print(string.format("%s %s", DEBUG_PREFIX, message))
end

local function debug_target_log(kind, target, fov, distance, template)
    if not debug_logging:Get() or not target then
        return
    end

    local handle = nil
    local ok_handle, raw_handle = pcall(function()
        return target:get_handle()
    end)
    if ok_handle and type(raw_handle) == "number" then
        handle = raw_handle
    else
        local ok_index, raw_index = pcall(function()
            return target:get_index()
        end)
        if ok_index and type(raw_index) == "number" then
            handle = raw_index
        end
    end

    if not handle then
        return
    end

    local state = (kind == "sticky") and target_log_state or target_log_state
    local handle_key = (kind == "sticky") and "sticky_handle" or "selected_handle"
    local fov_key = (kind == "sticky") and "sticky_fov" or "selected_fov"
    local distance_key = (kind == "sticky") and "sticky_distance" or "selected_distance"
    local time_key = (kind == "sticky") and "sticky_logged_at" or "selected_logged_at"

    local now = now_seconds()
    local handle_changed = state[handle_key] ~= handle
    local fov_changed = math.abs((state[fov_key] or math.huge) - (fov or math.huge)) >= 2.0
    local distance_changed = math.abs((state[distance_key] or math.huge) - (distance or math.huge)) >= to_units(2.0)
    local long_gap = (now - (state[time_key] or 0.0)) >= 2.0

    if not handle_changed and not fov_changed and not distance_changed and not long_gap then
        return
    end

    state[handle_key] = handle
    state[fov_key] = fov or math.huge
    state[distance_key] = distance or math.huge
    state[time_key] = now

    print(string.format("%s " .. template, DEBUG_PREFIX, (distance or 0) / UNIT_METER, fov or 0))
end

local function get_entity_handle(ent)
    if not ent or not ent.valid or not ent:valid() then
        return nil
    end

    local ok_handle, handle = pcall(function()
        return ent:get_handle()
    end)
    if ok_handle and type(handle) == "number" then
        return handle
    end

    local ok_index, index = pcall(function()
        return ent:get_index()
    end)
    if ok_index and type(index) == "number" then
        return index
    end

    return nil
end

local function safe_string_call(obj, method_name)
    if not obj or type(obj[method_name]) ~= "function" then
        return nil
    end

    local ok, value = pcall(function()
        return obj[method_name](obj)
    end)

    if ok and type(value) == "string" and value ~= "" and value ~= "Unknown" then
        return value
    end

    return nil
end

local function normalize_name(value)
    if type(value) ~= "string" or value == "" or value == "Unknown" then
        return nil
    end

    return string.lower(value)
end

local function name_contains(value, needle)
    local normalized = normalize_name(value)
    if not normalized or type(needle) ~= "string" or needle == "" then
        return false
    end

    return string.find(normalized, string.lower(needle), 1, true) ~= nil
end

local function is_doorman_ability_name(name)
    local normalized = normalize_name(name)
    if not normalized then
        return false
    end

    return normalized == IDS.ABILITY_BOMB
        or normalized == IDS.ABILITY_DOORWAY
        or normalized == IDS.ABILITY_LUGGAGE
        or normalized == IDS.ABILITY_HOTEL
end

local function is_doorman_hero_name(name)
    return normalize_name(name) == IDS.HERO_DOORMAN
end

local function get_spawned_hero_name(lp)
    local ok, value = pcall(function()
        local hero_comp = lp.m_CCitadelHeroComponent
        if not hero_comp or not hero_comp.m_spawnedHero then
            return nil
        end

        local spawned_hero = hero_comp.m_spawnedHero
        return safe_string_call(spawned_hero, "get_name")
            or safe_string_call(spawned_hero, "get_vdata_class_name")
            or safe_string_call(spawned_hero, "get_class_name")
    end)

    return ok and value or nil
end

local function is_doorman_hero(lp)
    if not lp or not lp.valid or not lp:valid() then
        hero_cache.handle = nil
        hero_cache.is_doorman = false
        hero_cache.last_check = 0.0
        return false
    end

    local handle = get_entity_handle(lp)
    if handle ~= hero_cache.handle then
        hero_cache.handle = handle
        hero_cache.is_doorman = false
        hero_cache.last_check = 0.0
    end

    local now = now_seconds()
    if (now - hero_cache.last_check) < HERO_RECHECK_INTERVAL then
        return hero_cache.is_doorman
    end

    hero_cache.last_check = now

    local detected = false
    local hero_names = {
        safe_string_call(lp, "get_name"),
        safe_string_call(lp, "get_vdata_class_name"),
        get_spawned_hero_name(lp),
    }

    for _, name in ipairs(hero_names) do
        if is_doorman_hero_name(name) then
            detected = true
            break
        end
    end

    if not detected then
        local abilities = nil
        pcall(function()
            abilities = lp:get_abilities()
        end)

        if abilities then
            for _, ability in ipairs(abilities) do
                local ability_names = {
                    safe_string_call(ability, "get_name"),
                    safe_string_call(ability, "get_class_name"),
                    safe_string_call(ability, "get_vdata_class_name"),
                }

                for _, name in ipairs(ability_names) do
                    if is_doorman_ability_name(name) then
                        detected = true
                        break
                    end
                end

                if detected then
                    break
                end
            end
        end
    end

    if detected and not hero_cache.is_doorman then
        debug_log(nil, "Detected hero_doorman profile.")
    end

    hero_cache.is_doorman = detected
    return detected
end

local function get_team_num(ent)
    local ok, team = pcall(function()
        return ent.m_iTeamNum
    end)

    if ok and type(team) == "number" then
        return team
    end

    return nil
end

local function get_health(ent)
    local ok, health = pcall(function()
        return ent.m_iHealth
    end)

    if ok and type(health) == "number" then
        return health
    end

    return 0
end

local function get_health_percent(ent)
    local max_health = 0
    pcall(function()
        max_health = ent:get_max_health()
    end)
    if type(max_health) ~= "number" or max_health <= 0 then
        return 100
    end
    return (get_health(ent) / max_health) * 100
end

local function get_entity_by_handle(handle)
    if type(handle) ~= "number" then
        return nil
    end

    local ok_handle, ent = pcall(function()
        return entity_list.by_handle(handle)
    end)

    if ok_handle and ent and ent.valid and ent:valid() then
        return ent
    end

    local ok_index, indexed_ent = pcall(function()
        return entity_list.by_index(handle)
    end)

    if ok_index and indexed_ent and indexed_ent.valid and indexed_ent:valid() then
        return indexed_ent
    end

    return nil
end

local function has_any_modifier_state(ent, states)
    for _, state in ipairs(states) do
        local ok, has_state = pcall(function()
            return ent:has_modifier_state(state)
        end)
        if ok and has_state then
            return true
        end
    end
    return false
end

local function is_target_untargetable(ent)
    return has_any_modifier_state(ent, {
        MODSTATE.INVULNERABLE,
        MODSTATE.TECH_INVULNERABLE,
        MODSTATE.TECH_DAMAGE_INVULNERABLE,
        MODSTATE.STATUS_IMMUNE,
        MODSTATE.OUT_OF_GAME,
        MODSTATE.UNIT_STATUS_HIDDEN,
        MODSTATE.NO_INCOMING_DAMAGE,
    })
end

local function get_target_point(ent)
    if not ent or not ent.valid or not ent:valid() then
        return nil
    end

    for _, bone_name in ipairs(BONE_PRIORITY) do
        local ok, bone_pos = pcall(function()
            return ent:get_bone_pos(bone_name)
        end)
        if ok and bone_pos then
            local valid = true
            pcall(function()
                valid = not bone_pos:IsInvalid()
            end)
            if valid then
                return bone_pos
            end
        end
    end

    local origin = ent:get_origin()
    return origin + Vector(0, 0, 55)
end

local function get_camera_pos()
    local ok, pos = pcall(function()
        return utils.get_camera_pos()
    end)
    if ok and pos then
        return pos
    end

    local lp = entity_list.local_pawn()
    if lp and lp.valid and lp:valid() then
        return lp:get_origin() + Vector(0, 0, 64)
    end

    return Vector(0, 0, 0)
end

local function get_view_angles(cmd)
    if cmd and cmd.viewangles then
        return cmd.viewangles
    end

    local ok, ang = pcall(function()
        return utils.get_camera_angles()
    end)
    if ok and ang then
        return ang
    end

    return Angle(0, 0, 0)
end

local function is_entity_visible(ent)
    if not ent or not ent.valid or not ent:valid() then
        return false
    end

    local ok, visible = pcall(function()
        return ent:is_visible()
    end)

    if ok and type(visible) == "boolean" then
        return visible
    end

    return true
end

local function can_see_point(lp, start_pos, end_pos, target)
    if target and not is_entity_visible(target) then
        return false
    end

    local ok_bullet, bullet_result = pcall(function()
        return trace.bullet(start_pos, end_pos, 1.0, lp)
    end)

    if ok_bullet then
        if type(bullet_result) == "boolean" then
            if bullet_result then
                return true
            end
        elseif bullet_result and bullet_result.fraction and bullet_result.fraction > 0.98 then
            return true
        end
    end

    local local_index = 0
    pcall(function()
        local_index = lp:get_index()
    end)

    local ok_line, tr = pcall(function()
        return trace.line(start_pos, end_pos, 0x1, local_index, 0, 0, 0, function()
            return false
        end)
    end)

    if not ok_line or not tr then
        return false
    end

    if tr.fraction and tr.fraction > 0.98 then
        return true
    end

    local hit_ent = nil
    pcall(function()
        hit_ent = tr:hit_entity()
    end)

    if target and hit_ent and hit_ent.valid and hit_ent:valid() then
        local hit_idx = get_entity_handle(hit_ent)
        local target_idx = get_entity_handle(target)
        if hit_idx and target_idx and hit_idx == target_idx and tr.fraction and tr.fraction > 0.97 then
            return true
        end
    end

    return false
end

local function get_ability_state(ability)
    local status = -1
    local cooldown = math.huge
    local level = 0

    pcall(function()
        status = ability:can_be_executed()
    end)
    pcall(function()
        cooldown = ability:get_cooldown()
    end)
    pcall(function()
        level = ability:get_level()
    end)

    return status, cooldown, level
end

local function is_ability_ready(ability)
    if not ability or not ability.valid or not ability:valid() then
        return false
    end

    local status, cooldown, level = get_ability_state(ability)
    if type(level) == "number" and level <= 0 then
        return false
    end

    if status == STATUS.READY then
        return true
    end

    return type(cooldown) == "number"
        and cooldown <= READY_EPSILON
        and status ~= STATUS.COOLDOWN
        and status ~= STATUS.PASSIVE
        and status ~= STATUS.BUSY
end

local function is_ability_consumed(ability)
    if not ability or not ability.valid or not ability:valid() then
        return false
    end

    local status, cooldown = get_ability_state(ability)
    if status == STATUS.BUSY then
        return true
    end

    return type(cooldown) == "number" and cooldown > READY_EPSILON
end

local function get_ability(lp, ability_name, slot)
    local ability = nil

    if type(ability_name) == "string" and ability_name ~= "" then
        pcall(function()
            ability = lp:get_ability(ability_name)
        end)
    end

    if not ability then
        pcall(function()
            ability = lp:get_ability_by_slot(slot)
        end)
    end

    return ability
end

local function get_item_input_bit(slot)
    if slot == SLOT.ITEM1 then
        return InputBitMask_t.IN_ITEM1
    elseif slot == SLOT.ITEM2 then
        return InputBitMask_t.IN_ITEM2
    elseif slot == SLOT.ITEM3 then
        return InputBitMask_t.IN_ITEM3
    elseif slot == SLOT.ITEM4 then
        return InputBitMask_t.IN_ITEM4
    end

    return nil
end

local function is_vortex_web_item_name(name)
    local normalized = normalize_name(name)
    return normalized == VORTEX_WEB_CODENAME
        or name_contains(name, "upgrade_aoe_root")
        or name_contains(name, "aoe_root")
        or name_contains(name, "vortex")
        or name_contains(name, "vortex_web")
        or name_contains(name, "web")
end

local function find_vortex_web_item(lp)
    local item_slots = { SLOT.ITEM1, SLOT.ITEM2, SLOT.ITEM3, SLOT.ITEM4 }

    for _, slot in ipairs(item_slots) do
        local item = get_ability(lp, nil, slot)
        if item and item.valid and item:valid() then
            local item_names = {
                safe_string_call(item, "get_name"),
                safe_string_call(item, "get_class_name"),
                safe_string_call(item, "get_vdata_class_name"),
            }

            for _, name in ipairs(item_names) do
                if is_vortex_web_item_name(name) then
                    return item, slot
                end
            end
        end
    end

    return nil, nil
end

local function get_effective_cast_range(ability, fallback_units)
    local range = nil
    pcall(function()
        range = ability:get_cast_range()
    end)

    if type(range) ~= "number" or range <= 0 then
        return fallback_units
    end

    if fallback_units and fallback_units > 0 then
        return math.min(range, fallback_units)
    end

    return range
end

local function get_effective_aoe_radius(ability, fallback_radius)
    local radius = nil
    pcall(function()
        radius = ability:get_aoe_radius()
    end)

    if type(radius) ~= "number" or radius <= 0 then
        pcall(function()
            radius = ability:get_scaled_property("m_flRadius")
        end)
    end

    if type(radius) ~= "number" or radius <= 0 then
        return fallback_radius
    end

    return radius
end

local function get_vortex_web_profile(item)
    local range = get_effective_cast_range(item, VORTEX_WEB_FALLBACK_RANGE)
    local aoe = get_effective_aoe_radius(item, VORTEX_WEB_FALLBACK_AOE)
    return range, aoe
end

local function get_scaled_property(ability, property_name)
    local value = nil
    pcall(function()
        value = ability:get_scaled_property(property_name)
    end)
    if type(value) == "number" and value > 0 then
        return value
    end
    return nil
end

local function get_projectile_speed(ability, fallback_speed)
    local property_names = {
        "m_flProjectileSpeed",
        "m_flSpeed",
        "m_flBulletSpeed",
    }

    for _, name in ipairs(property_names) do
        local value = get_scaled_property(ability, name)
        if value then
            return value
        end
    end

    return fallback_speed
end

local function predict_position(target, travel_time)
    local point = get_target_point(target)
    if not point then
        return nil
    end

    local velocity = Vector(0, 0, 0)
    pcall(function()
        velocity = target:get_velocity()
    end)

    if not velocity then
        velocity = Vector(0, 0, 0)
    end

    return point + (velocity * math.max(travel_time, 0))
end

local function predict_origin_position(target, travel_time)
    local origin = target:get_origin()

    local velocity = Vector(0, 0, 0)
    pcall(function()
        velocity = target:get_velocity()
    end)

    if not velocity then
        velocity = Vector(0, 0, 0)
    end

    return origin + (velocity * math.max(travel_time, 0))
end

local function is_valid_enemy(lp, enemy)
    if not enemy or not enemy.valid or not enemy:valid() then
        return false
    end

    if not enemy:is_alive() or enemy:is_dormant() then
        return false
    end

    local enemy_handle = get_entity_handle(enemy)
    local local_handle = get_entity_handle(lp)
    if enemy_handle and local_handle and enemy_handle == local_handle then
        return false
    end

    local local_team = get_team_num(lp)
    local enemy_team = get_team_num(enemy)
    if local_team and enemy_team and local_team == enemy_team then
        return false
    end

    if is_target_untargetable(enemy) then
        return false
    end

    return true
end

local function get_target_snapshot(lp, enemy, camera_pos, view_angles, max_fov_deg, max_distance_units)
    if not is_valid_enemy(lp, enemy) then
        return nil
    end

    local point = get_target_point(enemy)
    if not point or not can_see_point(lp, camera_pos, point, enemy) then
        return nil
    end

    local distance = lp:get_origin():Distance(enemy:get_origin())
    if distance > max_distance_units then
        return nil
    end

    local aim_angle = utils.calc_angle(camera_pos, point)
    local fov = utils.get_fov(view_angles, aim_angle)
    if fov > max_fov_deg then
        return nil
    end

    return {
        target = enemy,
        point = point,
        distance = distance,
        fov = fov,
    }
end

local function clear_combo_target_lock()
    combo_target_lock.handle = nil
    combo_target_lock.expires_at = 0.0
end

local function clear_hardlock_state()
    hardlock_state.cast_key = nil
    hardlock_state.target_handle = nil
    hardlock_state.ready_at = 0.0
end

local function clear_doorway_state()
    doorway_state.active = false
    doorway_state.phase = nil
    doorway_state.pos = nil
    doorway_state.door_pos = nil
    doorway_state.confirm_at = 0.0
    doorway_state.next_action_at = 0.0
    doorway_state.expires_at = 0.0
    doorway_state.psilent_until = 0.0
    doorway_state.phase_started_at = 0.0
    doorway_state.retry_at = 0.0
    doorway_state.cast_attempts = 0
    doorway_state.vortex_confirm_attempted = false
    doorway_state.target_handle = nil
    doorway_state.vortex_handle = nil
    doorway_state.reason = nil
    doorway_state.used_vortex = false
end

local function get_locked_combo_target(lp, cmd, max_fov_deg, max_distance_units)
    if not combo_target_lock.handle then
        return nil
    end

    if now_seconds() >= combo_target_lock.expires_at then
        clear_combo_target_lock()
        return nil
    end

    local locked_target = get_entity_by_handle(combo_target_lock.handle)
    if not locked_target then
        clear_combo_target_lock()
        return nil
    end

    local sticky_fov = math.min(180, max_fov_deg + TARGET_STICKY_FOV_BUFFER)
    local sticky_range = max_distance_units + to_units(TARGET_STICKY_RANGE_BUFFER_M)
    local snapshot = get_target_snapshot(lp, locked_target, get_camera_pos(), get_view_angles(cmd), sticky_fov, sticky_range)
    if not snapshot then
        clear_combo_target_lock()
        return nil
    end

    debug_target_log("sticky", snapshot.target, snapshot.fov, snapshot.distance, "Holding sticky target at %.1fm / %.1f FOV.")
    return snapshot.target, snapshot.fov, snapshot.distance
end

local function set_combo_target_lock(target, sticky_ms)
    local handle = get_entity_handle(target)
    if not handle then
        clear_combo_target_lock()
        return
    end

    combo_target_lock.handle = handle
    combo_target_lock.expires_at = now_seconds() + math.max(sticky_ms or 0, 0) / 1000
end

local function get_best_target(lp, cmd, max_fov_deg, max_distance_units, sticky_ms)
    if sticky_ms and sticky_ms > 0 then
        local locked_target, locked_fov, locked_distance = get_locked_combo_target(lp, cmd, max_fov_deg, max_distance_units)
        if locked_target then
            return locked_target, locked_fov, locked_distance
        end
    end

    local camera_pos = get_camera_pos()
    local view_angles = get_view_angles(cmd)
    local best_target = nil
    local best_fov = math.huge
    local best_distance = math.huge

    for _, enemy in ipairs(entity_list.by_class_name("C_CitadelPlayerPawn")) do
        local snapshot = get_target_snapshot(lp, enemy, camera_pos, view_angles, max_fov_deg, max_distance_units)
        if snapshot then
            if snapshot.fov < best_fov or (math.abs(snapshot.fov - best_fov) <= 0.01 and snapshot.distance < best_distance) then
                best_target = snapshot.target
                best_fov = snapshot.fov
                best_distance = snapshot.distance
            end
        end
    end

    if best_target then
        if sticky_ms and sticky_ms > 0 then
            set_combo_target_lock(best_target, sticky_ms)
        end
        debug_target_log("selected", best_target, best_fov, best_distance, "Selected target at %.1fm / %.1f FOV.")
    else
        if sticky_ms and sticky_ms > 0 then
            clear_combo_target_lock()
        end
    end

    return best_target, best_fov, best_distance
end

local function apply_aim(cmd, cast_pos, aim_mode_widget, aim_fov_widget, max_psilent_widget, cast_key, target)
    local camera_pos = get_camera_pos()
    local view_angles = get_view_angles(cmd)
    local aim_angle = utils.calc_angle(camera_pos, cast_pos)
    local fov = utils.get_fov(view_angles, aim_angle)

    if fov > aim_fov_widget:Get() then
        return false, "fov"
    end

    if fov <= max_psilent_widget:Get() and cmd:can_psilent_at_pos(cast_pos) then
        cmd:set_psilent_at_pos(cast_pos)
        return true, "psilent"
    end

    local mode = aim_mode_widget:Get()
    if mode == MODE.AIM_MODE_PSILENT_ONLY then
        clear_hardlock_state()
        return false, "psilent_only"
    end

    local target_handle = get_entity_handle(target)
    local now = now_seconds()

    utils.set_camera_angles(aim_angle)
    cmd.viewangles = aim_angle

    if cast_key and target_handle
        and hardlock_state.cast_key == cast_key
        and hardlock_state.target_handle == target_handle
        and now >= hardlock_state.ready_at
        and fov <= HARDLOCK_CAST_FOV then
        return true, "hardlock"
    end

    hardlock_state.cast_key = cast_key
    hardlock_state.target_handle = target_handle
    hardlock_state.ready_at = now + HARDLOCK_SETTLE_DELAY
    return false, "hardlock_aligning"
end

local function can_cast_now(cast_key, min_delay)
    local now = now_seconds()
    local last_ability_cast = last_cast_times[cast_key] or 0.0
    min_delay = min_delay or GLOBAL_CAST_DELAY
    return (now - last_ability_cast) >= min_delay
        and (now - last_cast_times.global) >= GLOBAL_CAST_DELAY
end

local function mark_cast(cast_key)
    local now = now_seconds()
    last_cast_times[cast_key] = now
    last_cast_times.global = now
    clear_hardlock_state()
end

local function prepare_standard_ability_cast(cmd)
    cmd:clear_buttonstate1(InputBitMask_t.IN_ALT_CAST)
    cmd:clear_buttonstate1(InputBitMask_t.IN_ABILITY_HELD)
    cmd:clear_buttonstate1(InputBitMask_t.IN_CANCEL_ABILITY)
end

local function get_wall_score(lp, cast_pos)
    local local_index = 0
    pcall(function()
        local_index = lp:get_index()
    end)

    local best_score = 0.0
    local probe_distance = to_units(3.5)
    local probe_start_offset = 3.0
    local probe_heights = { 0, 18, 36 }

    for _, height in ipairs(probe_heights) do
        local elevated_pos = cast_pos + Vector(0, 0, height)

        for _, dir in ipairs(WALL_DIRECTIONS) do
            local start_pos = elevated_pos + (dir * probe_start_offset)
            local end_pos = elevated_pos + (dir * probe_distance)

            local ok, tr = pcall(function()
                return trace.line(start_pos, end_pos, 0x1, local_index, 0, 0, 0, function()
                    return false
                end)
            end)

            if ok and tr and tr.fraction and tr.fraction < 0.98 then
                local hit_ent = nil
                pcall(function()
                    hit_ent = tr:hit_entity()
                end)

                local hit_name = hit_ent and safe_string_call(hit_ent, "get_class_name") or nil
                if not hit_name or hit_name ~= "C_CitadelPlayerPawn" then
                    best_score = math.max(best_score, 1.0 - tr.fraction)
                end
            end
        end
    end

    return best_score
end

local function get_directional_wall_score(lp, impact_pos)
    local shooter_pos = lp:get_origin()
    local shot_dir = Vector(impact_pos.x - shooter_pos.x, impact_pos.y - shooter_pos.y, 0)
    if shot_dir:Length2D() < 1.0 then
        return 0.0
    end

    shot_dir:Normalize()
    local left_dir = Vector(-shot_dir.y, shot_dir.x, 0)
    local right_dir = Vector(shot_dir.y, -shot_dir.x, 0)

    local probe_dirs = {
        shot_dir,
        left_dir,
        right_dir,
        (shot_dir + left_dir):Normalized(),
        (shot_dir + right_dir):Normalized(),
    }

    local local_index = 0
    pcall(function()
        local_index = lp:get_index()
    end)

    local elevated_pos = impact_pos + Vector(0, 0, 24)
    local start_offset = 2.0
    local end_offset = to_units(5.0)
    local best_score = 0.0

    for _, dir in ipairs(probe_dirs) do
        local start_pos = elevated_pos + (dir * start_offset)
        local end_pos = elevated_pos + (dir * end_offset)

        local ok, tr = pcall(function()
            return trace.line(start_pos, end_pos, 0x1, local_index, 0, 0, 0, function()
                return false
            end)
        end)

        if ok and tr and tr.fraction and tr.fraction < 0.99 then
            local hit_ent = nil
            pcall(function()
                hit_ent = tr:hit_entity()
            end)

            local hit_name = hit_ent and safe_string_call(hit_ent, "get_class_name") or nil
            if not hit_name or hit_name ~= "C_CitadelPlayerPawn" then
                best_score = math.max(best_score, 1.0 - tr.fraction)
            end
        end
    end

    return best_score
end

local function get_luggage_wall_score(lp, cast_pos, impact_pos)
    local score = get_wall_score(lp, cast_pos)
    score = math.max(score, get_wall_score(lp, impact_pos))
    score = math.max(score, get_directional_wall_score(lp, impact_pos))
    return score
end

local function choose_vortex_web_cast(lp, target, item, max_range_units, aoe_radius)
    local target_origin = target and target:get_origin() or nil
    if not target_origin then
        return nil, "no_origin"
    end

    local camera_pos = get_camera_pos()
    local projectile_speed = get_projectile_speed(item, 1200)
    local distance = camera_pos:Distance(target_origin)
    local base_time = distance / math.max(projectile_speed, 1)
    local sample_times = {
        math.max(0.0, base_time * 0.4),
        math.max(0.0, base_time * 0.75),
        math.max(0.0, base_time),
        math.max(0.0, base_time + 0.1),
        math.max(0.0, base_time + 0.2),
    }

    local best_candidate = nil
    local best_soft_candidate = nil
    local max_reach = math.max(math.min(aoe_radius * 0.78, to_units(9.0)), to_units(2.0))
    local search_radii = {
        0.0,
        math.max(max_reach * 0.22, to_units(1.25)),
        math.max(max_reach * 0.4, to_units(2.5)),
        math.max(max_reach * 0.58, to_units(4.0)),
        max_reach,
    }

    for _, sample_time in ipairs(sample_times) do
        local impact_pos = predict_origin_position(target, sample_time)
        if impact_pos then
            local shot_dir = Vector(impact_pos.x - lp:get_origin().x, impact_pos.y - lp:get_origin().y, 0)
            if shot_dir:Length2D() >= 1.0 then
                shot_dir:Normalize()
            else
                shot_dir = Vector(1, 0, 0)
            end

            local left_dir = Vector(-shot_dir.y, shot_dir.x, 0)
            local right_dir = Vector(shot_dir.y, -shot_dir.x, 0)
            local backward_dir = shot_dir * -1
            local diag_left = (shot_dir + left_dir):Normalized()
            local diag_right = (shot_dir + right_dir):Normalized()
            local back_diag_left = (backward_dir + left_dir):Normalized()
            local back_diag_right = (backward_dir + right_dir):Normalized()
            local search_dirs = {
                Vector(0, 0, 0),
                shot_dir,
                backward_dir,
                left_dir,
                right_dir,
                diag_left,
                diag_right,
                back_diag_left,
                back_diag_right,
            }

            for _, radius in ipairs(search_radii) do
                for _, dir in ipairs(search_dirs) do
                    local cast_pos = radius <= 0.0 and impact_pos or (impact_pos + (dir * radius))
                    if cast_pos
                        and lp:get_origin():Distance(cast_pos) <= max_range_units
                        and impact_pos:Distance(cast_pos) <= aoe_radius
                        and can_see_point(lp, camera_pos, cast_pos, nil) then
                        local wall_score = math.max(
                            get_wall_score(lp, cast_pos),
                            get_wall_score(lp, impact_pos),
                            get_directional_wall_score(lp, cast_pos),
                            get_directional_wall_score(lp, impact_pos)
                        )
                        local proximity_bonus = math.max(0.0, (aoe_radius - impact_pos:Distance(cast_pos)) / math.max(aoe_radius, 1)) * 0.08
                        local total_score = wall_score + proximity_bonus

                        if wall_score > 0.003 then
                            if not best_soft_candidate or total_score > best_soft_candidate.score then
                                best_soft_candidate = {
                                    pos = cast_pos,
                                    score = total_score,
                                }
                            end
                        end

                        if wall_score >= VORTEX_WALL_SCORE_THRESHOLD then
                            if not best_candidate or total_score > best_candidate.score then
                                best_candidate = {
                                    pos = cast_pos,
                                    score = total_score,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    if best_candidate then
        return best_candidate.pos, "wall"
    end

    if best_soft_candidate then
        return best_soft_candidate.pos, "soft-wall"
    end

    return nil, "no_wall"
end

local function choose_luggage_cast(lp, target, ability, max_range_units)
    local prefer_wall = luggage_prefer_wall:Get()
    local wall_score_mode = luggage_prefer_wall_score:Get()
    local low_hp_override = get_health_percent(target) <= luggage_force_below_hp:Get()

    local direct_pos = get_target_point(target)
    if not direct_pos then
        return nil, "no_point", false
    end

    local camera_pos = get_camera_pos()
    local distance = camera_pos:Distance(direct_pos)
    local projectile_speed = get_projectile_speed(ability, 1400)
    local base_time = distance / math.max(projectile_speed, 1)

    local sample_times = {
        math.max(0.0, base_time * 0.5),
        math.max(0.0, base_time),
        math.max(0.0, base_time + 0.12),
        math.max(0.0, base_time + 0.24),
    }

    local best_wall_candidate = nil
    local first_wall_candidate = nil

    for _, sample_time in ipairs(sample_times) do
        local cast_pos = predict_position(target, sample_time)
        local impact_pos = predict_origin_position(target, sample_time)
        if cast_pos then
            local distance_to_cast = lp:get_origin():Distance(cast_pos)
            if distance_to_cast <= max_range_units and can_see_point(lp, camera_pos, cast_pos, target) then
                local wall_score = get_luggage_wall_score(lp, cast_pos, impact_pos)
                if wall_score >= WALL_SCORE_THRESHOLD then
                    local candidate = {
                        pos = cast_pos,
                        score = wall_score,
                    }

                    if not first_wall_candidate then
                        first_wall_candidate = candidate
                    end

                    if not best_wall_candidate or wall_score > best_wall_candidate.score then
                        best_wall_candidate = candidate
                    end
                end
            end
        end
    end

    local chosen_wall_candidate = wall_score_mode and best_wall_candidate or first_wall_candidate
    if prefer_wall and chosen_wall_candidate then
        return chosen_wall_candidate.pos, "wall", true
    end

    if lp:get_origin():Distance(direct_pos) <= max_range_units and can_see_point(lp, camera_pos, direct_pos, target) then
        return direct_pos, "direct", false
    end

    if chosen_wall_candidate then
        return chosen_wall_candidate.pos, "wall-fallback", true
    end

    return nil, low_hp_override and "direct_failed" or "no_wall", false
end

local try_cast_luggage

local function try_cast_doorway_luggage(lp, cmd, target, ability)
    if not is_ability_ready(ability) or not can_cast_now("a3", A3_REPRESS_DELAY) then
        return false
    end

    local max_range_units = get_effective_cast_range(ability, to_units(luggage_max_range_m:Get()))
    local target_point = get_target_point(target)
    local door_pos = doorway_state.door_pos
    local camera_pos = get_camera_pos()
    local candidates = {}

    if door_pos and target_point then
        table.insert(candidates, Vector(door_pos.x, door_pos.y, target_point.z))
        table.insert(candidates, Vector(
            (door_pos.x + target_point.x) * 0.5,
            (door_pos.y + target_point.y) * 0.5,
            target_point.z
        ))
    elseif door_pos then
        table.insert(candidates, door_pos)
    end

    if target_point then
        table.insert(candidates, target_point)
    end

    for _, cast_pos in ipairs(candidates) do
        local visible = can_see_point(lp, camera_pos, cast_pos, target)
            or can_see_point(lp, camera_pos, cast_pos, nil)
        if cast_pos and lp:get_origin():Distance(cast_pos) <= max_range_units and visible then
            local aimed, mode_used = apply_aim(cmd, cast_pos, luggage_mode, luggage_fov, luggage_max_psilent, "a3", target)
            if aimed then
                prepare_standard_ability_cast(cmd)
                cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY3)
                cmd:add_buttonstate1(InputBitMask_t.IN_ATTACK)
                mark_cast("a3")
                debug_log(nil, string.format("Cast A3 Doorway follow-up via %s.", mode_used))
                return true, mode_used
            end

            if mode_used == "hardlock_aligning" then
                return false, "aligning"
            end
        end
    end

    return false, "no_followup_angle"
end

local function count_other_enemies_near(lp, target, radius_units)
    local local_team = get_team_num(lp)
    local count = 0
    local target_handle = get_entity_handle(target)
    local target_origin = target:get_origin()

    for _, enemy in ipairs(entity_list.by_class_name("C_CitadelPlayerPawn")) do
        if enemy and enemy.valid and enemy:valid() and enemy:is_alive() and not enemy:is_dormant() then
            local enemy_handle = get_entity_handle(enemy)
            local enemy_team = get_team_num(enemy)

            if enemy_handle ~= target_handle and local_team and enemy_team and enemy_team ~= local_team then
                if enemy:get_origin():Distance(target_origin) <= radius_units then
                    count = count + 1
                end
            end
        end
    end

    return count
end

local function count_enemies_in_radius(lp, origin, radius_units)
    local count = 0

    for _, enemy in ipairs(entity_list.by_class_name("C_CitadelPlayerPawn")) do
        if is_valid_enemy(lp, enemy) and enemy:get_origin():Distance(origin) <= radius_units then
            count = count + 1
        end
    end

    return count
end

local function get_bell_radius(ability)
    local radius = nil
    pcall(function()
        radius = ability:get_aoe_radius()
    end)

    if type(radius) == "number" and radius > 0 then
        return radius
    end

    radius = get_scaled_property(ability, "m_flRadius")
    if type(radius) == "number" and radius > 0 then
        return radius
    end

    return nil
end

local function get_best_bell_projectile(lp, ability, min_enemies)
    local radius = get_bell_radius(ability)
    if not radius then
        return nil
    end

    local best_bell = nil
    local best_enemy_count = 0
    local best_distance = math.huge
    local camera_pos = get_camera_pos()

    for _, bell in ipairs(entity_list.by_class_name("CDoormanBombProjectile")) do
        if bell and bell.valid and bell:valid() then
            local bell_pos = bell:get_origin()
            local enemy_count = count_enemies_in_radius(lp, bell_pos, radius)
            local distance = camera_pos:Distance(bell_pos)

            if enemy_count >= min_enemies then
                if enemy_count > best_enemy_count or (enemy_count == best_enemy_count and distance < best_distance) then
                    best_bell = {
                        entity = bell,
                        pos = bell_pos,
                        enemy_count = enemy_count,
                    }
                    best_enemy_count = enemy_count
                    best_distance = distance
                end
            end
        end
    end

    return best_bell
end

local function try_auto_shoot_bell(lp, cmd, ability)
    if not call_bell_auto_shoot:Get() or not can_cast_now("bell_shot", 0.05) then
        return false
    end

    local bell = get_best_bell_projectile(lp, ability, call_bell_min_shoot_enemies:Get())
    if not bell then
        return false
    end

    if not can_see_point(lp, get_camera_pos(), bell.pos, nil) then
        debug_log("bell_visibility", "Skip Bell Shot: bell projectile is not visible.", 0.5)
        return false
    end

    local aimed, mode_used = apply_aim(cmd, bell.pos, call_bell_mode, call_bell_fov, call_bell_max_psilent, "bell_shot", bell.entity)
    if not aimed then
        if mode_used == "hardlock_aligning" then
            debug_log("bell_align", "Hold Bell Shot: waiting for aim to settle.", 0.2)
            return false, "aligning"
        end

        debug_log("bell_aim", "Skip Bell Shot: aim helper did not find a valid shot.", 0.5)
        return false, mode_used
    end

    cmd:add_buttonstate1(InputBitMask_t.IN_ATTACK)
    mark_cast("bell_shot")
    debug_log(nil, string.format("Shot Bell on %d enemies via %s.", bell.enemy_count, mode_used))
    return true, mode_used
end

local function get_doorway_position(lp, target)
    local pawn_pos = lp:get_origin()
    local target_pos = target:get_origin()
    local direction = Vector(target_pos.x - pawn_pos.x, target_pos.y - pawn_pos.y, 0)

    if direction:Length2D() < 1.0 then
        return target_pos
    end

    direction:Normalize()
    return target_pos + (direction * to_units(doorway_offset_m:Get()))
end

local function should_use_doorway_vortex(lp, target)
    local mode = doorway_followup_mode:Get()
    if mode == MODE.DOORWAY_FOLLOWUP_A3_ONLY then
        return false
    end

    if mode == MODE.DOORWAY_FOLLOWUP_VORTEX_A3 then
        return true
    end

    local target_origin = target and target:get_origin() or nil
    if not target_origin then
        return false
    end

    return lp:get_origin():Distance(target_origin) > to_units(7.0)
end

local function cast_doorway_ability(cmd)
    local doorway_pos = doorway_state.door_pos or doorway_state.pos
    if not doorway_pos then
        return false
    end

    doorway_state.pos = doorway_pos
    pcall(function()
        cmd:set_psilent_at_pos(doorway_pos)
    end)

    prepare_standard_ability_cast(cmd)
    cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY2)
    doorway_state.phase = "confirm"
    doorway_state.phase_started_at = now_seconds()
    doorway_state.cast_attempts = doorway_state.cast_attempts + 1
    doorway_state.retry_at = doorway_state.phase_started_at + DOORWAY_RETRY_DELAY
    doorway_state.confirm_at = doorway_state.phase_started_at + math.max(doorway_confirm_delay_ms:Get() / 1000.0, DOORWAY_CONFIRM_SETTLE_DELAY)
    doorway_state.next_action_at = doorway_state.confirm_at
    doorway_state.psilent_until = doorway_state.confirm_at + 0.12
    debug_log(nil, string.format("Cast A2 Doorway (%s).", doorway_state.reason or "manual"))
    return true
end

local function start_doorway_sequence(lp, cmd, target, ability, reason)
    if not doorway_enabled:Get() or doorway_state.active then
        return false
    end

    if not is_ability_ready(ability) or not can_cast_now("a2", 0.1) then
        debug_log("a2_ready", "Skip A2: doorway is not ready.", 0.5)
        return false
    end

    local doorway_pos = get_doorway_position(lp, target)
    if not doorway_pos then
        debug_log("a2_pos", "Skip A2: failed to calculate doorway position.", 0.5)
        return false
    end

    clear_hardlock_state()
    doorway_state.active = true
    doorway_state.phase = nil
    doorway_state.pos = doorway_pos
    doorway_state.door_pos = doorway_pos
    doorway_state.confirm_at = 0.0
    doorway_state.next_action_at = 0.0
    doorway_state.expires_at = now_seconds() + 1.6
    doorway_state.psilent_until = 0.0
    doorway_state.phase_started_at = now_seconds()
    doorway_state.retry_at = 0.0
    doorway_state.cast_attempts = 0
    doorway_state.vortex_confirm_attempted = false
    doorway_state.target_handle = get_entity_handle(target)
    doorway_state.vortex_handle = nil
    doorway_state.reason = reason or "manual"
    doorway_state.used_vortex = false

    local use_vortex = should_use_doorway_vortex(lp, target)
    if use_vortex then
        doorway_state.expires_at = doorway_state.expires_at + 0.4
    end
    if use_vortex then
        local vortex_item, vortex_slot = find_vortex_web_item(lp)
        local item_bit = get_item_input_bit(vortex_slot)
        local item_pos = nil
        local item_range, item_aoe = nil, nil
        local item_reason = "no_item"

        if vortex_item then
            item_range, item_aoe = get_vortex_web_profile(vortex_item)
            item_pos, item_reason = choose_vortex_web_cast(lp, target, vortex_item, item_range, item_aoe)
        end

        if vortex_item and item_bit and item_pos and is_ability_ready(vortex_item) and lp:get_origin():Distance(item_pos) <= item_range then
            doorway_state.used_vortex = true
            doorway_state.phase = "door_cast"
            doorway_state.pos = item_pos
            doorway_state.phase_started_at = now_seconds()
            doorway_state.vortex_handle = get_entity_handle(vortex_item)
            doorway_state.vortex_confirm_attempted = false
            doorway_state.next_action_at = doorway_state.phase_started_at + math.max(doorway_item_delay_ms:Get() / 1000.0, DOORWAY_ITEM_SETTLE_DELAY)
            doorway_state.retry_at = doorway_state.next_action_at
            doorway_state.psilent_until = doorway_state.next_action_at + 0.1

            pcall(function()
                cmd:set_psilent_at_pos(item_pos)
            end)

            prepare_standard_ability_cast(cmd)
            cmd:add_buttonstate1(item_bit)
            debug_log(nil, string.format("Used Vortex Web before A2 from item slot %d via %s point (range %.0f / aoe %.0f).", vortex_slot - SLOT.ITEM1 + 1, item_reason or "wall", item_range, item_aoe))
            return true
        elseif not vortex_item or not item_bit or (vortex_item and not is_ability_ready(vortex_item)) then
            debug_log("a2_vortex_pre", "Skip pre-door Vortex: item not found or not ready.", 0.75)
        elseif item_pos and item_range and lp:get_origin():Distance(item_pos) > item_range then
            debug_log("a2_vortex_pre_range", "Skip pre-door Vortex: target is outside item range.", 0.75)
        else
            debug_log("a2_vortex_pre_wall", string.format("Skip pre-door Vortex: %s.", tostring(item_reason or "no reliable wall point")), 0.75)
        end
    end

    return cast_doorway_ability(cmd)
end

local function process_doorway_sequence(lp, cmd, a2, a3)
    if not doorway_state.active or not doorway_state.pos then
        return false
    end

    if doorway_state.phase == "door_cast" then
        -- Keep aiming at the enemy position while waiting for the pre-door item to deploy.
    elseif doorway_state.phase ~= "confirm" then
        local follow_target = get_entity_by_handle(doorway_state.target_handle)
        if follow_target and is_valid_enemy(lp, follow_target) then
            local follow_pos = get_target_point(follow_target)
            if follow_pos then
                doorway_state.pos = follow_pos
            end
        end
    end

    pcall(function()
        cmd:set_psilent_at_pos(doorway_state.pos)
    end)

    doorway_state.psilent_until = math.max(doorway_state.psilent_until, now_seconds() + 0.05)

    if doorway_state.phase == "confirm" and now_seconds() < doorway_state.confirm_at then
        return true
    end

    if doorway_state.phase == "door_cast" then
        if now_seconds() < doorway_state.next_action_at then
            return true
        end

        local vortex_item = get_entity_by_handle(doorway_state.vortex_handle)
        if doorway_state.used_vortex and vortex_item then
            if is_ability_consumed(vortex_item) then
                return cast_doorway_ability(cmd)
            end

            if not doorway_state.vortex_confirm_attempted and now_seconds() >= doorway_state.retry_at then
                prepare_standard_ability_cast(cmd)
                cmd:add_buttonstate1(InputBitMask_t.IN_ATTACK)
                doorway_state.vortex_confirm_attempted = true
                doorway_state.retry_at = now_seconds() + DOORWAY_RETRY_DELAY
                doorway_state.next_action_at = doorway_state.retry_at
                doorway_state.psilent_until = doorway_state.next_action_at + 0.08
                debug_log("a2_vortex_confirm", "Confirm Vortex Web before A2.", 0.1)
                return true
            end

            if now_seconds() < (doorway_state.phase_started_at + DOORWAY_VORTEX_ACCEPT_TIMEOUT) then
                doorway_state.next_action_at = now_seconds() + 0.01
                return true
            end
        end

        return cast_doorway_ability(cmd)
    end

    if doorway_state.phase == "confirm" then
        local a2_consumed = a2 and is_ability_consumed(a2)
        if not a2_consumed and doorway_state.cast_attempts < 3 and now_seconds() >= doorway_state.retry_at and now_seconds() < (doorway_state.phase_started_at + DOORWAY_ACCEPT_TIMEOUT) then
            debug_log("a2_retry", "Retry A2: doorway input was not accepted yet.", 0.1)
            return cast_doorway_ability(cmd)
        end

        prepare_standard_ability_cast(cmd)
        cmd:add_buttonstate1(InputBitMask_t.IN_ATTACK)
        mark_cast("a2")
        doorway_state.phase = "luggage"
        doorway_state.phase_started_at = now_seconds()
        doorway_state.next_action_at = doorway_state.phase_started_at + DOORWAY_POST_CONFIRM_DELAY
        doorway_state.psilent_until = doorway_state.next_action_at + 0.1
        debug_log(nil, "Confirmed A2 Doorway.")
        return true
    end

    if doorway_state.phase == "luggage" then
        if now_seconds() < doorway_state.next_action_at then
            return true
        end

        if doorway_state.expires_at > 0 and now_seconds() > doorway_state.expires_at then
            debug_log("a2_timeout", "Abort Doorway follow-up: sequence timed out.", 0.5)
            clear_doorway_state()
            return false
        end

        local target = get_entity_by_handle(doorway_state.target_handle)
        if not target or not is_valid_enemy(lp, target) then
            debug_log("a2_target", "Abort Doorway follow-up: target is no longer valid.", 0.5)
            clear_doorway_state()
            return false
        end

        if not a3 or not a3.valid or not a3:valid() then
            debug_log("a2_luggage_ready", "Abort Doorway follow-up: A3 handle is invalid.", 0.5)
            clear_doorway_state()
            return false
        end

        if not is_ability_ready(a3) then
            doorway_state.next_action_at = now_seconds() + DOORWAY_A3_HOLD_DELAY
            debug_log("a2_luggage_hold", "Hold Doorway follow-up: waiting for A3 to become ready.", 0.2)
            return true
        end

        if not can_cast_now("a3", A3_REPRESS_DELAY) then
            doorway_state.next_action_at = now_seconds() + 0.015
            return true
        end

        local luggage_casted, luggage_reason = try_cast_doorway_luggage(lp, cmd, target, a3)
        if luggage_casted then
            debug_log(nil, string.format("Completed Doorway follow-up (%s).", doorway_state.reason or "manual"))
            clear_doorway_state()
            return true
        end

        if luggage_reason == "aligning" then
            return true
        end

        local normal_casted, normal_reason = try_cast_luggage(lp, cmd, target, a3)
        if normal_casted then
            debug_log(nil, string.format("Completed Doorway follow-up (%s).", doorway_state.reason or "manual"))
            clear_doorway_state()
            return true
        end

        if normal_reason == "aligning" then
            return true
        end

        doorway_state.next_action_at = now_seconds() + 0.03
        debug_log("a2_luggage_retry", string.format("Hold Doorway follow-up: waiting for A3 setup (%s / %s).", tostring(luggage_reason or "no_followup"), tostring(normal_reason or "normal_failed")), 0.25)
        return true
    end

    clear_doorway_state()
    return false
end

local function get_hotel_target(lp, cmd, max_fov_deg, max_distance_units, hp_threshold_pct, isolation_radius_units, max_nearby_enemies)
    local camera_pos = get_camera_pos()
    local view_angles = get_view_angles(cmd)
    local best_target = nil
    local best_hp = math.huge
    local best_fov = math.huge

    for _, enemy in ipairs(entity_list.by_class_name("C_CitadelPlayerPawn")) do
        local snapshot = get_target_snapshot(lp, enemy, camera_pos, view_angles, max_fov_deg, max_distance_units)
        if snapshot then
            local hp_pct = get_health_percent(enemy)
            if hp_pct <= hp_threshold_pct then
                local nearby_enemies = count_other_enemies_near(lp, enemy, isolation_radius_units)
                if nearby_enemies <= max_nearby_enemies then
                    if hp_pct < best_hp or (math.abs(hp_pct - best_hp) <= 0.1 and snapshot.fov < best_fov) then
                        best_target = enemy
                        best_hp = hp_pct
                        best_fov = snapshot.fov
                    end
                end
            end
        end
    end

    return best_target
end

local function try_cast_call_bell(lp, cmd, target, ability)
    if not is_ability_ready(ability) or not can_cast_now("a1") then
        return false
    end

    local cast_pos = get_target_point(target)
    if not cast_pos then
        debug_log("a1_no_point", "Skip A1: no target point.", 0.75)
        return false
    end

    local max_range_units = get_effective_cast_range(ability, to_units(call_bell_max_range_m:Get()))
    local distance = lp:get_origin():Distance(cast_pos)
    if distance > max_range_units then
        debug_log("a1_range", string.format("Skip A1: target out of range (%.1fm > %.1fm).", distance / UNIT_METER, max_range_units / UNIT_METER), 0.75)
        return false
    end

    local aimed, mode_used = apply_aim(cmd, cast_pos, call_bell_mode, call_bell_fov, call_bell_max_psilent, "a1", target)
    if not aimed then
        if mode_used == "hardlock_aligning" then
            debug_log("a1_align", "Hold A1: waiting for hard lock to settle.", 0.2)
            return false, "aligning"
        end
        debug_log("a1_aim", "Skip A1: aim helper did not find a valid cast.", 0.75)
        return false, mode_used
    end

    cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY1)
    mark_cast("a1")
    debug_log(nil, string.format("Cast A1 Call Bell via %s.", mode_used))
    return true, mode_used
end

try_cast_luggage = function(lp, cmd, target, ability)
    if not is_ability_ready(ability) or not can_cast_now("a3", A3_REPRESS_DELAY) then
        return false
    end

    local max_range_units = get_effective_cast_range(ability, to_units(luggage_max_range_m:Get()))
    local cast_pos, reason, used_wall = choose_luggage_cast(lp, target, ability, max_range_units)
    if not cast_pos then
        debug_log("a3_pick", string.format("Skip A3: %s.", reason), 0.75)
        return false
    end

    local aimed, mode_used = apply_aim(cmd, cast_pos, luggage_mode, luggage_fov, luggage_max_psilent, "a3", target)
    if not aimed then
        if mode_used == "hardlock_aligning" then
            debug_log("a3_align", "Hold A3: waiting for hard lock to settle.", 0.2)
            return false, "aligning"
        end
        debug_log("a3_aim", "Skip A3: aim helper did not find a valid cast.", 0.75)
        return false, mode_used
    end

    prepare_standard_ability_cast(cmd)
    cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY3)
    cmd:add_buttonstate1(InputBitMask_t.IN_ATTACK)
    mark_cast("a3")
    debug_log(nil, string.format("Cast A3 Luggage Cart via %s%s.", mode_used, used_wall and " with wall preference" or ""))
    return true, mode_used
end

local function try_cast_hotel(lp, cmd, target, ability, max_fov_deg, max_distance_units)
    if not is_ability_ready(ability) or not can_cast_now("a4") then
        return false
    end

    local cast_pos = get_target_point(target)
    if not cast_pos then
        debug_log("a4_no_point", "Skip A4: no target point.", 0.75)
        return false
    end

    local max_range_units = get_effective_cast_range(ability, max_distance_units)
    local distance = lp:get_origin():Distance(cast_pos)
    if distance > max_range_units then
        debug_log("a4_range", string.format("Skip A4: target out of range (%.1fm > %.1fm).", distance / UNIT_METER, max_range_units / UNIT_METER), 0.75)
        return false
    end

    local camera_pos = get_camera_pos()
    if not can_see_point(lp, camera_pos, cast_pos, target) then
        debug_log("a4_visibility", "Skip A4: target not visible.", 0.75)
        return false
    end

    local aim_angle = utils.calc_angle(camera_pos, cast_pos)
    local fov = utils.get_fov(get_view_angles(cmd), aim_angle)
    if fov > max_fov_deg then
        debug_log("a4_fov", string.format("Skip A4: target outside FOV (%.1f > %d).", fov, max_fov_deg), 0.75)
        return false
    end

    utils.set_camera_angles(aim_angle)
    cmd.viewangles = aim_angle
    cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY4)
    mark_cast("a4")
    debug_log(nil, "Cast A4 Hotel Guest.")
    return true
end

local function update_mode_visibility()
    call_bell_min_shoot_enemies:Visible(call_bell_auto_shoot:Get())
    luggage_prefer_wall_score:Visible(luggage_prefer_wall:Get())
end

call_bell_auto_shoot:SetCallback(update_mode_visibility, true)
luggage_prefer_wall:SetCallback(update_mode_visibility, true)

callback.on_pre_createmove:set(function(cmd)
    if not enable_script:Get() or Menu.Opened() or not cmd or not doorway_state.active or not doorway_state.pos then
        return
    end

    if now_seconds() > doorway_state.psilent_until then
        return
    end

    pcall(function()
        cmd:set_psilent_at_pos(doorway_state.pos)
    end)
end)

callback.on_createmove:set(function(cmd)
    if not enable_script:Get() or Menu.Opened() then
        clear_doorway_state()
        clear_hardlock_state()
        return
    end

    if not cmd or cmd.in_shop then
        clear_doorway_state()
        clear_hardlock_state()
        return
    end

    local lp = entity_list.local_pawn()
    if not lp or not lp.valid or not lp:valid() or not lp:is_alive() then
        clear_combo_target_lock()
        clear_doorway_state()
        clear_hardlock_state()
        return
    end

    if not is_doorman_hero(lp) then
        clear_combo_target_lock()
        clear_doorway_state()
        clear_hardlock_state()
        return
    end

    if has_any_modifier_state(lp, {
        MODSTATE.OUT_OF_GAME,
        MODSTATE.UNIT_STATUS_HIDDEN,
    }) then
        clear_combo_target_lock()
        clear_doorway_state()
        clear_hardlock_state()
        return
    end

    local a1 = get_ability(lp, IDS.ABILITY_BOMB, SLOT.A1)
    local a2 = get_ability(lp, IDS.ABILITY_DOORWAY, SLOT.A2)
    local a3 = get_ability(lp, IDS.ABILITY_LUGGAGE, SLOT.A3)
    local a4 = get_ability(lp, IDS.ABILITY_HOTEL, SLOT.A4)

    if doorway_state.active then
        if process_doorway_sequence(lp, cmd, a2, a3) then
            return
        end
        clear_doorway_state()
    end

    local combo_active = combo_key:IsDown()
    local max_distance_units = to_units(target_max_distance_m:Get())
    local hotel_max_distance_units = to_units(hotel_target_max_distance_m:Get())

    local combo_target = nil
    if combo_active then
        combo_target = get_best_target(lp, cmd, target_fov:Get(), max_distance_units, target_sticky_ms:Get())
    else
        clear_combo_target_lock()
        clear_hardlock_state()
    end

    local doorway_key_down = doorway_key:IsDown()
    local manual_doorway_pressed = doorway_key_down and not doorway_state.last_key_down
    doorway_state.last_key_down = doorway_key_down

    if doorway_enabled:Get() and a2 and manual_doorway_pressed then
        local doorway_target = get_best_target(lp, cmd, target_fov:Get(), max_distance_units, 0)
        if doorway_target and start_doorway_sequence(lp, cmd, doorway_target, a2, "manual") then
            return
        end
        if not doorway_target then
            debug_log("a2_manual_target", "Skip A2: no valid manual doorway target.", 0.5)
        end
    end

    if combo_active and combo_target then
        if doorway_enabled:Get() and doorway_use_in_combo:Get() and a2 then
            if start_doorway_sequence(lp, cmd, combo_target, a2, "combo") then
                return
            end
        end

        if a1 then
            local bell_shot, bell_reason = try_auto_shoot_bell(lp, cmd, a1)
            if bell_shot or bell_reason == "aligning" then
                return
            end
        end

        if hotel_enabled:Get() and hotel_use_in_combo:Get() and a4 then
            local hotel_range = get_effective_cast_range(a4, hotel_max_distance_units)
            local hotel_target = get_hotel_target(
                lp,
                cmd,
                hotel_target_fov:Get(),
                hotel_range,
                hotel_hp_threshold:Get(),
                to_units(hotel_isolation_radius_m:Get()),
                hotel_max_nearby:Get()
            )

            if hotel_target and try_cast_hotel(lp, cmd, hotel_target, a4, hotel_target_fov:Get(), hotel_range) then
                return
            end
        end

        if luggage_enabled:Get() and a3 then
            local luggage_casted, luggage_reason = try_cast_luggage(lp, cmd, combo_target, a3)
            if luggage_casted or luggage_reason == "aligning" then
                return
            end
        end

        if call_bell_enabled:Get() and a1 and call_bell_usage_mode:Get() == MODE.CALL_BELL_USE_COMBO then
            local bell_casted, bell_reason = try_cast_call_bell(lp, cmd, combo_target, a1)
            if bell_casted or bell_reason == "aligning" then
                return
            end
        end
    elseif combo_active then
        debug_log("combo_no_target", "Combo active but no valid target found.", 0.75)
        clear_hardlock_state()
    end

    if not combo_active and a1 then
        local bell_shot, bell_reason = try_auto_shoot_bell(lp, cmd, a1)
        if bell_shot or bell_reason == "aligning" then
            return
        end
    end

    if hotel_enabled:Get() and a4 and is_ability_ready(a4) then
        local allow_auto_hotel = not combo_active or hotel_use_in_combo:Get()
        if allow_auto_hotel then
            local hotel_range = get_effective_cast_range(a4, hotel_max_distance_units)
            local hotel_target = get_hotel_target(
                lp,
                cmd,
                hotel_target_fov:Get(),
                hotel_range,
                hotel_hp_threshold:Get(),
                to_units(hotel_isolation_radius_m:Get()),
                hotel_max_nearby:Get()
            )

            if hotel_target then
                try_cast_hotel(lp, cmd, hotel_target, a4, hotel_target_fov:Get(), hotel_range)
            end
        end
    end

    if not combo_active
        and call_bell_enabled:Get()
        and call_bell_usage_mode:Get() == MODE.CALL_BELL_USE_AUTO
        and a1 then
        local bell_range = get_effective_cast_range(a1, to_units(call_bell_max_range_m:Get()))
        local bell_target = get_best_target(lp, cmd, call_bell_fov:Get(), bell_range, 0)

        if bell_target then
            local bell_casted, bell_reason = try_cast_call_bell(lp, cmd, bell_target, a1)
            if bell_casted or bell_reason == "aligning" then
                return
            end
        end
    end
end)

callback.on_scripts_loaded:set(function()
    update_mode_visibility()
    print(DEBUG_PREFIX .. " Loaded.")
end)

print(DEBUG_PREFIX .. " Script initialized.")
