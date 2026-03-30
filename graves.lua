---@diagnostic disable: undefined-global

local UNIT_METER = 37.7358490566
local DEBUG_PREFIX = "[Graves]"
local HERO_RECHECK_INTERVAL = 0.75
local READY_EPSILON = 0.05
local TARGET_STICKY_FOV_BUFFER = 8.0
local TARGET_STICKY_RANGE_BUFFER_M = 4.0
local HARDLOCK_SETTLE_DELAY = 0.03
local DEFAULT_EYE_HEIGHT = 60.0
local DEFAULT_TARGET_POINT_Z = 45.0

local IDS = {
    HERO = "hero_necro",
    A1 = "ability_necro_hauntingskull",
    A2 = "ability_necro_zombiewall",
    A4 = "ability_necro_gravestone",
}

local MODE = {
    AIM_MODE_PSILENT_ONLY = 0,
    AIM_MODE_HARDLOCK_FALLBACK = 1,
}

local PRIORITY = {
    FOV = 0,
    HP_PERCENT = 1,
    DISTANCE = 2,
    TECH_EHP = 3,
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
    A4 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_4) or 3,
}

local BIT = {
    A1 = (InputBitMask_t and InputBitMask_t.IN_ABILITY1) or nil,
    A2 = (InputBitMask_t and InputBitMask_t.IN_ABILITY2) or nil,
    A4 = (InputBitMask_t and InputBitMask_t.IN_ABILITY4) or nil,
}

local MODSTATE = {
    IMMOBILIZED = (EModifierState and EModifierState.MODIFIER_STATE_IMMOBILIZED) or 10,
    SILENCED = (EModifierState and EModifierState.MODIFIER_STATE_SILENCED) or 14,
    STUNNED = (EModifierState and EModifierState.MODIFIER_STATE_STUNNED) or 17,
    INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_INVULNERABLE) or 18,
    TECH_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_TECH_INVULNERABLE) or 19,
    TECH_DAMAGE_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_TECH_DAMAGE_INVULNERABLE) or 20,
    STATUS_IMMUNE = (EModifierState and EModifierState.MODIFIER_STATE_STATUS_IMMUNE) or 22,
    OUT_OF_GAME = (EModifierState and EModifierState.MODIFIER_STATE_OUT_OF_GAME) or 24,
    COMMAND_RESTRICTED = (EModifierState and EModifierState.MODIFIER_STATE_COMMAND_RESTRICTED) or 25,
    UNIT_STATUS_HIDDEN = (EModifierState and EModifierState.MODIFIER_STATE_UNIT_STATUS_HIDDEN) or 108,
    NO_INCOMING_DAMAGE = (EModifierState and EModifierState.MODIFIER_STATE_NO_INCOMING_DAMAGE) or 136,
}

local MODVALUE = {
    TECH_RESIST_PERCENT = (EModifierValue and EModifierValue.MODIFIER_VALUE_TECH_ARMOR_DAMAGE_RESIST_PERCENT) or 83,
}

local ICON = {
    TAB = "\u{f7d9}",
    ENABLE = "\u{f00c}",
    KEY = "\u{f084}",
    CLOCK = "\u{f017}",
    LOCK = "\u{f023}",
    TARGET = "\u{f140}",
    FOV = "\u{f06e}",
    RANGE = "\u{f124}",
    HP = "\u{f21e}",
    GROUP = "\u{f0c0}",
    BLAST = "\u{f0e7}",
    STAR = "\u{f005}",
    PSILENT = "\u{f05b}",
    STEER = "\u{f57d}",
    NET = "\u{f1eb}",
    DEBUG = "\u{f188}",
}

local AIM_MODE_ITEMS = {
    "P-Silent Only",
    "Hard Lock Fallback",
}

local TARGET_PRIORITY_ITEMS = {
    "FOV",
    "HP %",
    "Distance",
    "Tech EHP",
}

local BONE_PRIORITY = {
    "spine_2",
    "spine_1",
    "chest",
    "neck_0",
    "head",
}

local graves = {
    hero_handle = nil,
    is_graves = false,
    last_hero_check = 0.0,
    target_handle = nil,
    target_expires_at = 0.0,
    debug_font = nil,
}

local hardlock_state = {
    cast_key = nil,
    target_handle = nil,
    ready_at = 0.0,
}

local last_cast_times = {
    global = 0.0,
    a1 = 0.0,
    a2 = 0.0,
    a4 = 0.0,
}

local debug_state = {}

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

local function set_widget_tooltip(widget, text)
    if not widget or not text then
        return
    end

    pcall(function()
        widget:ToolTip(text)
    end)
end

local hero_root = Menu.Find("Heroes", "Hero List", "Graves")
if not hero_root then
    hero_root = Menu.Create("Heroes", "Hero List", "Graves")
end

local groups = {
    tab = find_or_create_third_tab(hero_root, "Necrotic Core"),
}

groups.general = find_or_create_group(groups.tab, "General")
groups.targeting = find_or_create_group(groups.tab, "Targeting")
groups.prediction = find_or_create_group(groups.tab, "Prediction")
groups.a1 = find_or_create_group(groups.tab, "Haunting Skull (1)")
groups.a2 = find_or_create_group(groups.tab, "Zombie Wall (2)")
groups.a4 = find_or_create_group(groups.tab, "Gravestone (4)")
groups.visuals = find_or_create_group(groups.tab, "Visuals")
groups.debug = find_or_create_group(groups.tab, "Debug")

set_widget_icon(groups.tab, ICON.TAB, false)

local ui_enable = groups.general:Switch("Enable Script", true, ICON.ENABLE)
local ui_combo_key = groups.general:Bind("Combo Key", Enum.ButtonCode.KEY_LALT, ICON.KEY)
local ui_cast_debounce_ms = groups.general:Slider("Cast Debounce (ms)", 0, 250, 80, "%d", ICON.CLOCK)
local ui_open_with_a2 = groups.general:Switch("Open With Zombie Wall", true, ICON.STEER)

local ui_target_lock = groups.targeting:Switch("Sticky Target", true, ICON.LOCK)
local ui_target_sticky_ms = groups.targeting:Slider("Sticky Time (ms)", 50, 700, 320, "%d", ICON.CLOCK)
local ui_target_prio = groups.targeting:Combo("Priority", TARGET_PRIORITY_ITEMS, PRIORITY.FOV, ICON.TARGET)
local ui_target_fov = groups.targeting:Slider("Engagement FOV", 1, 180, 28, "%d", ICON.FOV)
local ui_target_range_m = groups.targeting:Slider("Max Distance (m)", 5, 75, 40, "%d", ICON.RANGE)

local ui_predict_latency = groups.prediction:Switch("Latency Compensation", true, ICON.NET)
local ui_predict_bias_ms = groups.prediction:Slider("Extra Bias (ms)", 0, 200, 0, "%d", ICON.CLOCK)
local ui_predict_max_time = groups.prediction:Slider("Max Predict Time (s)", 0.05, 1.50, 0.65, "%.2f", ICON.CLOCK)

local ui_a1 = groups.a1:Switch("Use Haunting Skull", true, ICON.BLAST)
local gear_a1 = ui_a1:Gear("Haunting Skull Logic")
local ui_a1_mode = gear_a1:Combo("Aim Mode", AIM_MODE_ITEMS, MODE.AIM_MODE_HARDLOCK_FALLBACK, ICON.TARGET)
local ui_a1_max_psilent = gear_a1:Slider("Max P-Silent FOV", 1, 90, 24, "%d", ICON.PSILENT)
local ui_a1_hardlock_fov = gear_a1:Slider("Hard Lock FOV", 1, 45, 16, "%d", ICON.FOV)
local ui_a1_range_m = gear_a1:Slider("Max Range (m)", 5, 60, 27, "%d", ICON.RANGE)
local ui_a1_speed = gear_a1:Slider("Fallback Speed", 500, 5000, 1500, "%d", ICON.STEER)
local ui_a1_delay = gear_a1:Slider("Cast Windup (s)", 0.00, 1.50, 0.20, "%.2f", ICON.CLOCK)
local ui_a1_require_vis = gear_a1:Switch("Require Visibility", true)

local ui_a2 = groups.a2:Switch("Use Zombie Wall", true, ICON.TARGET)
local gear_a2 = ui_a2:Gear("Zombie Wall Logic")
local ui_a2_mode = gear_a2:Combo("Aim Mode", AIM_MODE_ITEMS, MODE.AIM_MODE_HARDLOCK_FALLBACK, ICON.TARGET)
local ui_a2_max_psilent = gear_a2:Slider("Max P-Silent FOV", 1, 90, 26, "%d", ICON.PSILENT)
local ui_a2_hardlock_fov = gear_a2:Slider("Hard Lock FOV", 1, 45, 18, "%d", ICON.FOV)
local ui_a2_range_m = gear_a2:Slider("Max Range (m)", 5, 60, 40, "%d", ICON.RANGE)
local ui_a2_speed = gear_a2:Slider("Fallback Speed", 500, 5000, 2000, "%d", ICON.STEER)
local ui_a2_delay = gear_a2:Slider("Cast Windup (s)", 0.00, 1.50, 0.30, "%.2f", ICON.CLOCK)
local ui_a2_require_vis = gear_a2:Switch("Require Visibility", true)

local ui_a4 = groups.a4:Switch("Use Gravestone", true, ICON.STAR)
local gear_a4 = ui_a4:Gear("Gravestone Logic")
local ui_a4_mode = gear_a4:Combo("Aim Mode", AIM_MODE_ITEMS, MODE.AIM_MODE_HARDLOCK_FALLBACK, ICON.TARGET)
local ui_a4_max_psilent = gear_a4:Slider("Max P-Silent FOV", 1, 90, 24, "%d", ICON.PSILENT)
local ui_a4_hardlock_fov = gear_a4:Slider("Hard Lock FOV", 1, 45, 18, "%d", ICON.FOV)
local ui_a4_range_m = gear_a4:Slider("Max Range (m)", 5, 75, 40, "%d", ICON.RANGE)
local ui_a4_radius_m = gear_a4:Slider("Fallback Radius (m)", 4.0, 30.0, 17.0, "%.1f", ICON.GROUP)
local ui_a4_min_enemies = gear_a4:Slider("Min Enemies", 1, 6, 1, "%d", ICON.GROUP)
local ui_a4_delay = gear_a4:Slider("Prediction Delay (s)", 0.00, 2.00, 0.40, "%.2f", ICON.CLOCK)
local ui_a4_require_vis = gear_a4:Switch("Require Ground Visibility", true)

local ui_draw_fov = groups.visuals:Switch("Draw Target FOV", true, ICON.FOV)
local ui_draw_target = groups.visuals:Switch("Draw Locked Target", true, ICON.TARGET)

local ui_debug = groups.debug:Switch("Debug Logging", false, ICON.DEBUG)

set_widget_icon(ui_target_sticky_ms, ICON.CLOCK, false)
set_widget_icon(ui_target_prio, ICON.TARGET, false)
set_widget_icon(ui_target_fov, ICON.FOV, false)
set_widget_icon(ui_target_range_m, ICON.RANGE, false)
set_widget_icon(ui_cast_debounce_ms, ICON.CLOCK, false)
set_widget_icon(ui_open_with_a2, ICON.STEER, false)

set_widget_tooltip(ui_enable, "Master switch for the full Graves module.")
set_widget_tooltip(ui_combo_key, "Hold to run Graves combo logic.")
set_widget_tooltip(ui_cast_debounce_ms, "Minimum delay between casts. Helps prevent multi-cast spam in one short burst.")
set_widget_tooltip(ui_open_with_a2, "When enabled, Zombie Wall is tried before Haunting Skull.")
set_widget_tooltip(ui_target_lock, "Keep the current target briefly instead of retargeting every tick.")
set_widget_tooltip(ui_target_sticky_ms, "How long the combo keeps a valid target before switching.")
set_widget_tooltip(ui_target_prio, "Controls which enemy is preferred when multiple valid targets exist.")
set_widget_tooltip(ui_target_fov, "Maximum FOV used for target selection.")
set_widget_tooltip(ui_target_range_m, "Maximum distance used by the combo target selector.")
set_widget_tooltip(ui_predict_latency, "Adds live ping compensation to projectile prediction.")
set_widget_tooltip(ui_predict_bias_ms, "Extra manual prediction bias added on top of latency compensation.")
set_widget_tooltip(ui_predict_max_time, "Upper limit for any prediction time to avoid over-leading.")
set_widget_tooltip(ui_a1_speed, "Fallback projectile speed used if the ability API does not expose one.")
set_widget_tooltip(ui_a2_speed, "Fallback projectile speed used if the ability API does not expose one.")
set_widget_tooltip(ui_a4_radius_m, "Fallback AOE radius used when the ability radius cannot be read from the game.")
set_widget_tooltip(ui_a4_min_enemies, "Required number of enemies inside Gravestone radius before casting.")
set_widget_tooltip(ui_draw_fov, "Draw the target acquisition FOV circle on screen.")
set_widget_tooltip(ui_draw_target, "Highlight the currently locked combo target.")
set_widget_tooltip(ui_debug, "Print cast decisions and skip reasons into the Lua console.")

ui_target_lock:SetCallback(function(self)
    ui_target_sticky_ms:Visible(self:Get())
end, true)

local function bind_aim_mode_visibility(mode_widget, hardlock_widget)
    mode_widget:SetCallback(function(self)
        hardlock_widget:Visible(self:Get() == MODE.AIM_MODE_HARDLOCK_FALLBACK)
    end, true)
end

bind_aim_mode_visibility(ui_a1_mode, ui_a1_hardlock_fov)
bind_aim_mode_visibility(ui_a2_mode, ui_a2_hardlock_fov)
bind_aim_mode_visibility(ui_a4_mode, ui_a4_hardlock_fov)

local function is_menu_open()
    return Menu.Opened and Menu.Opened() or false
end

local function now_seconds()
    local now = nil
    pcall(function()
        now = global_vars.curtime()
    end)
    return type(now) == "number" and now or os.clock()
end

local function to_units(value)
    return (value or 0) * UNIT_METER
end

local function distance_2d(a, b)
    if not a or not b then
        return math.huge
    end

    if a.Distance2D then
        return a:Distance2D(b)
    end

    return a:Distance(b)
end

local function is_valid_vector(vec)
    if not vec then
        return false
    end

    local ok, invalid = pcall(function()
        return vec:IsInvalid()
    end)
    if ok then
        return not invalid
    end

    return vec.x ~= nil and vec.y ~= nil and vec.z ~= nil
end

local function debug_log(key, message, min_interval)
    if not ui_debug:Get() or not message then
        return
    end

    local now = now_seconds()
    if key then
        min_interval = min_interval or 0.75
        if (now - (debug_state[key] or 0.0)) < min_interval then
            return
        end
        debug_state[key] = now
    end

    print(string.format("%s %s", DEBUG_PREFIX, message))
end

local function clear_combo_target_lock()
    graves.target_handle = nil
    graves.target_expires_at = 0.0
end

local function clear_hardlock_state()
    hardlock_state.cast_key = nil
    hardlock_state.target_handle = nil
    hardlock_state.ready_at = 0.0
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

local function is_graves_hero_name(name)
    local normalized = normalize_name(name)
    if not normalized then
        return false
    end

    return normalized == IDS.HERO
        or name_contains(normalized, "graves")
        or name_contains(normalized, "necro")
end

local function is_graves_ability_name(name)
    local normalized = normalize_name(name)
    if not normalized then
        return false
    end

    return normalized == IDS.A1
        or normalized == IDS.A2
        or normalized == IDS.A4
end

local function get_ability_name(ability)
    if not ability then
        return nil
    end

    return safe_string_call(ability, "get_name")
        or safe_string_call(ability, "get_vdata_class_name")
        or safe_string_call(ability, "get_class_name")
end

local function is_graves_hero(lp)
    if not lp or not lp.valid or not lp:valid() then
        graves.hero_handle = nil
        graves.is_graves = false
        graves.last_hero_check = 0.0
        clear_combo_target_lock()
        return false
    end

    local handle = get_entity_handle(lp)
    if handle ~= graves.hero_handle then
        graves.hero_handle = handle
        graves.is_graves = false
        graves.last_hero_check = 0.0
        clear_combo_target_lock()
    end

    local now = now_seconds()
    if (now - graves.last_hero_check) < HERO_RECHECK_INTERVAL then
        return graves.is_graves
    end

    graves.last_hero_check = now

    local hero_name = get_spawned_hero_name(lp)
    if is_graves_hero_name(hero_name) then
        graves.is_graves = true
        return true
    end

    local fallback_name = safe_string_call(lp, "get_name")
        or safe_string_call(lp, "get_vdata_class_name")
        or safe_string_call(lp, "get_class_name")
    if is_graves_hero_name(fallback_name) then
        graves.is_graves = true
        return true
    end

    local abilities = nil
    pcall(function()
        abilities = lp:get_abilities()
    end)

    if abilities then
        for _, ability in pairs(abilities) do
            if is_graves_ability_name(get_ability_name(ability)) then
                graves.is_graves = true
                return true
            end
        end
    end

    graves.is_graves = false
    return false
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

local function read_number_field(raw, field_name)
    local ok, value = pcall(function()
        return raw[field_name]
    end)
    if ok and type(value) == "number" then
        return value
    end

    return nil
end

local function get_health(ent)
    local hp = read_number_field(ent, "m_iHealth")
    if type(hp) == "number" then
        return hp
    end

    local max_health = nil
    pcall(function()
        max_health = ent:get_max_health()
    end)
    return type(max_health) == "number" and max_health or 0
end

local function get_health_pct(ent)
    local max_health = nil
    pcall(function()
        max_health = ent:get_max_health()
    end)
    if type(max_health) ~= "number" or max_health <= 0 then
        return 100
    end

    return (get_health(ent) / max_health) * 100
end

local function get_tech_ehp(ent)
    local hp = get_health(ent)
    local tech_resist = read_number_field(ent, "m_flTechResist")

    if type(tech_resist) ~= "number" and ent.get_tech_resist then
        local ok, native_value = pcall(function()
            return ent:get_tech_resist()
        end)
        if ok and type(native_value) == "number" then
            tech_resist = native_value
        end
    end

    if type(tech_resist) ~= "number" and MODVALUE.TECH_RESIST_PERCENT then
        local ok, modifier_value = pcall(function()
            return ent:get_sum_modifier_value(MODVALUE.TECH_RESIST_PERCENT, 0)
        end)
        if ok and type(modifier_value) == "number" then
            tech_resist = modifier_value
        end
    end

    tech_resist = type(tech_resist) == "number" and tech_resist or 0
    if tech_resist > 1 and tech_resist < 100 then
        tech_resist = tech_resist / 100
    end

    tech_resist = math.max(0, math.min(tech_resist, 0.95))
    if tech_resist > 0 then
        return hp / (1.0 - tech_resist)
    end

    return hp
end

local function has_any_modifier_state(ent, states)
    if not ent then
        return false
    end

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

local function is_target_static(ent)
    return has_any_modifier_state(ent, {
        MODSTATE.STUNNED,
        MODSTATE.IMMOBILIZED,
    })
end

local function is_self_disabled(ent)
    return has_any_modifier_state(ent, {
        MODSTATE.STUNNED,
        MODSTATE.SILENCED,
        MODSTATE.COMMAND_RESTRICTED,
    })
end

local function is_valid_enemy(me, ent)
    if not me or not ent or not ent.valid or not ent:valid() then
        return false
    end

    if ent == me or not ent:is_alive() or ent:is_dormant() then
        return false
    end

    local my_team = get_team_num(me)
    local enemy_team = get_team_num(ent)
    if type(my_team) == "number" and type(enemy_team) == "number" and my_team == enemy_team then
        return false
    end

    if is_target_untargetable(ent) then
        return false
    end

    return true
end

local function get_eye_pos(me)
    if not me or not me.valid or not me:valid() then
        return nil
    end

    return me:get_origin() + Vector(0, 0, DEFAULT_EYE_HEIGHT)
end

local function get_camera_context(me, cmd)
    local camera_pos = nil
    local view_angles = nil

    pcall(function()
        camera_pos = utils.get_camera_pos()
    end)
    if not camera_pos then
        camera_pos = get_eye_pos(me)
    end

    pcall(function()
        view_angles = utils.get_camera_angles()
    end)
    if not view_angles and cmd then
        view_angles = cmd.viewangles
    end

    return camera_pos, view_angles
end

local function get_target_point(target)
    if not target or not target.valid or not target:valid() then
        return nil
    end

    for _, bone_name in ipairs(BONE_PRIORITY) do
        local bone_pos = nil
        pcall(function()
            bone_pos = target:get_bone_pos(bone_name)
        end)
        if is_valid_vector(bone_pos) then
            return bone_pos
        end
    end

    return target:get_origin() + Vector(0, 0, DEFAULT_TARGET_POINT_Z)
end

local function get_ground_target_point(target)
    if not target or not target.valid or not target:valid() then
        return nil
    end

    return target:get_origin()
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

local function can_see_point(me, start_pos, end_pos, target)
    if not me or not start_pos or not end_pos then
        return false
    end

    if target and not is_entity_visible(target) then
        return false
    end

    local ok_bullet, bullet_result = pcall(function()
        return trace.bullet(start_pos, end_pos, 1.0, me)
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
        local_index = me:get_index()
    end)

    local ok_line, tr = pcall(function()
        return trace.line(start_pos, end_pos, 0x1, local_index, 0, 0, 0, function()
            return false
        end)
    end)
    if not ok_line or not tr then
        return false
    end

    if tr.fraction and tr.fraction > 0.98 and not target then
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

local function is_target_visible(me, target, start_pos, target_point)
    local aim_from = start_pos or get_eye_pos(me)
    local aim_to = target_point or get_target_point(target)
    return can_see_point(me, aim_from, aim_to, target)
end

local function get_ability_state(ability)
    local status = -1
    local cooldown = math.huge
    local level = 0

    if not ability or not ability.valid or not ability:valid() then
        return status, cooldown, level
    end

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
    local status, cooldown, level = get_ability_state(ability)
    if type(level) ~= "number" or level <= 0 then
        return false, status, cooldown, level
    end

    if status == STATUS.READY then
        return true, status, cooldown, level
    end

    return false, status, cooldown, level
end

local function get_scaled_property(ability, names)
    if not ability or not ability.valid or not ability:valid() then
        return nil
    end

    if type(names) == "string" then
        names = { names }
    end

    for _, name in ipairs(names or {}) do
        local value = nil
        pcall(function()
            value = ability:get_scaled_property(name)
        end)
        if type(value) == "number" and value > 0 then
            return value
        end
    end

    return nil
end

local function get_effective_cast_range(ability, fallback_limit)
    local range = nil
    pcall(function()
        range = ability:get_cast_range()
    end)
    if type(range) ~= "number" or range <= 0 then
        range = get_scaled_property(ability, {
            "m_flCastRange",
            "m_flAbilityCastRange",
            "CastRange",
            "m_flRange",
        })
    end

    if type(range) == "number" and range > 0 then
        if type(fallback_limit) == "number" and fallback_limit > 0 then
            return math.min(range, fallback_limit)
        end
        return range
    end

    return fallback_limit
end

local function get_effective_aoe_radius(ability, fallback_radius)
    local radius = nil
    pcall(function()
        radius = ability:get_aoe_radius()
    end)
    if type(radius) == "number" and radius > 0 then
        return radius
    end

    return get_scaled_property(ability, {
        "m_flRadius",
        "Radius",
    }) or fallback_radius
end

local function get_projectile_speed(ability, fallback_speed)
    return get_scaled_property(ability, {
        "m_flProjectileSpeed",
        "m_flSpeed",
        "m_flBulletSpeed",
    }) or fallback_speed
end

local function clamp_predict_time(value)
    return math.max(0, math.min(value or 0, ui_predict_max_time:Get()))
end

local function get_prediction_extra_time()
    local extra = ui_predict_bias_ms:Get() / 1000
    if not ui_predict_latency:Get() then
        return math.min(extra, ui_predict_max_time:Get())
    end

    local latency = 0
    pcall(function()
        latency = net_channel.latency()
    end)
    if type(latency) == "number" and latency > 0 then
        extra = extra + math.max(0, latency - 0.015)
    end

    return math.min(extra, ui_predict_max_time:Get())
end

local function predict_linear_target(target, base_pos, travel_time, keep_ground)
    if not target or not base_pos then
        return base_pos
    end

    if is_target_static(target) then
        return base_pos
    end

    local velocity = Vector(0, 0, 0)
    pcall(function()
        velocity = target:get_velocity()
    end)

    local predict_time = clamp_predict_time((travel_time or 0) + get_prediction_extra_time())
    local predicted = base_pos + (velocity * predict_time)
    if keep_ground then
        predicted.z = base_pos.z
    end

    return predicted
end

local function predict_projectile_target(me, target, ability, fallback_speed, manual_delay)
    local src = nil
    pcall(function()
        src = utils.get_camera_pos()
    end)
    if not src then
        src = get_eye_pos(me)
    end

    local base_pos = get_target_point(target)
    if not src or not base_pos then
        return base_pos
    end

    if is_target_static(target) then
        return base_pos
    end

    local speed = get_projectile_speed(ability, fallback_speed)
    local predicted = nil
    if type(speed) == "number" and speed > 0 and utils.predict_bullet then
        pcall(function()
            predicted = utils.predict_bullet(src, base_pos, target:get_velocity(), speed)
        end)
    end

    if is_valid_vector(predicted) then
        local extra_delay = clamp_predict_time((manual_delay or 0) + get_prediction_extra_time())
        if extra_delay > 0 then
            local velocity = Vector(0, 0, 0)
            pcall(function()
                velocity = target:get_velocity()
            end)
            predicted = predicted + (velocity * extra_delay)
        end
        return predicted
    end

    local travel_time = 0
    if type(speed) == "number" and speed > 0 then
        travel_time = distance_2d(src, base_pos) / speed
    end

    return predict_linear_target(target, base_pos, travel_time + (manual_delay or 0), false)
end

local function predict_ground_projectile_target(me, target, ability, fallback_speed, manual_delay)
    local src = nil
    pcall(function()
        src = utils.get_camera_pos()
    end)
    if not src then
        src = get_eye_pos(me)
    end

    local base_pos = get_ground_target_point(target)
    if not src or not base_pos then
        return base_pos
    end

    if is_target_static(target) then
        return base_pos
    end

    local speed = get_projectile_speed(ability, fallback_speed)
    local predicted = nil
    if type(speed) == "number" and speed > 0 and utils.predict_bullet then
        pcall(function()
            predicted = utils.predict_bullet(src, base_pos, target:get_velocity(), speed)
        end)
    end

    if is_valid_vector(predicted) then
        local extra_delay = clamp_predict_time((manual_delay or 0) + get_prediction_extra_time())
        if extra_delay > 0 then
            local velocity = Vector(0, 0, 0)
            pcall(function()
                velocity = target:get_velocity()
            end)
            predicted = predicted + (velocity * extra_delay)
        end
        predicted.z = base_pos.z
        return predicted
    end

    local travel_time = 0
    if type(speed) == "number" and speed > 0 then
        travel_time = distance_2d(src, base_pos) / speed
    end

    return predict_linear_target(target, base_pos, travel_time + (manual_delay or 0), true)
end

local function get_target_name(target)
    if not target then
        return "unknown"
    end

    return safe_string_call(target, "get_name")
        or safe_string_call(target, "get_vdata_class_name")
        or ("target#" .. tostring(get_entity_handle(target) or -1))
end

local function get_target_score(me, target, camera_pos, view_angles, max_fov_deg, max_distance_units)
    if not is_valid_enemy(me, target) then
        return nil
    end

    local point = get_target_point(target)
    if not point then
        return nil
    end

    local distance = distance_2d(me:get_origin(), target:get_origin())
    if distance > max_distance_units then
        return nil
    end

    local fov = utils.get_fov(view_angles, utils.calc_angle(camera_pos, point))
    if fov > max_fov_deg then
        return nil
    end

    if not is_entity_visible(target) or not is_target_visible(me, target, camera_pos, point) then
        return nil
    end

    local mode = ui_target_prio:Get()
    if mode == PRIORITY.HP_PERCENT then
        return get_health_pct(target) + (fov * 0.05), point, fov, distance
    end
    if mode == PRIORITY.DISTANCE then
        return distance, point, fov, distance
    end
    if mode == PRIORITY.TECH_EHP then
        return get_tech_ehp(target) + (fov * 2.0), point, fov, distance
    end

    return fov, point, fov, distance
end

local function can_keep_target(me, target, cmd, max_fov_deg, max_distance_units)
    if not is_valid_enemy(me, target) then
        return false
    end

    local camera_pos, view_angles = get_camera_context(me, cmd)
    if not camera_pos or not view_angles then
        return false
    end

    local point = get_target_point(target)
    if not point then
        return false
    end

    local sticky_range = max_distance_units + to_units(TARGET_STICKY_RANGE_BUFFER_M)
    if distance_2d(me:get_origin(), target:get_origin()) > sticky_range then
        return false
    end

    local sticky_fov = math.min(180, max_fov_deg + TARGET_STICKY_FOV_BUFFER)
    local fov = utils.get_fov(view_angles, utils.calc_angle(camera_pos, point))
    if fov > sticky_fov then
        return false
    end

    return is_target_visible(me, target, camera_pos, point)
end

local function get_locked_combo_target(me, cmd, max_fov_deg, max_distance_units)
    if not ui_target_lock:Get() then
        clear_combo_target_lock()
        return nil
    end

    if not graves.target_handle then
        return nil
    end

    if now_seconds() >= graves.target_expires_at then
        clear_combo_target_lock()
        return nil
    end

    local target = get_entity_by_handle(graves.target_handle)
    if not target or not can_keep_target(me, target, cmd, max_fov_deg, max_distance_units) then
        clear_combo_target_lock()
        return nil
    end

    return target
end

local function set_combo_target_lock(target)
    if not ui_target_lock:Get() then
        return
    end

    local handle = get_entity_handle(target)
    if not handle then
        clear_combo_target_lock()
        return
    end

    graves.target_handle = handle
    graves.target_expires_at = now_seconds() + (ui_target_sticky_ms:Get() / 1000)
end

local function acquire_combo_target(me, cmd)
    local max_fov_deg = ui_target_fov:Get()
    local max_distance_units = to_units(ui_target_range_m:Get())

    local locked_target = get_locked_combo_target(me, cmd, max_fov_deg, max_distance_units)
    if locked_target then
        return locked_target
    end

    local camera_pos, view_angles = get_camera_context(me, cmd)
    if not camera_pos or not view_angles then
        return nil
    end

    local players = entity_list.by_class_name("C_CitadelPlayerPawn")
    if not players then
        return nil
    end

    local best_target = nil
    local best_score = math.huge

    for _, player in pairs(players) do
        local score = get_target_score(me, player, camera_pos, view_angles, max_fov_deg, max_distance_units)
        if score and score < best_score then
            best_score = score
            best_target = player
        end
    end

    if best_target then
        set_combo_target_lock(best_target)
        debug_log("target_select", string.format("Target -> %s", get_target_name(best_target)), 0.20)
    else
        clear_combo_target_lock()
    end

    return best_target
end

local function get_ability_by_name_or_slot(me, ability_name, slot)
    local ability = nil

    if type(ability_name) == "string" and ability_name ~= "" then
        pcall(function()
            ability = me:get_ability(ability_name)
        end)
    end

    if not ability then
        pcall(function()
            ability = me:get_ability_by_slot(slot)
        end)
    end

    return ability
end

local function is_combo_down()
    if not ui_enable:Get() or not ui_combo_key then
        return false
    end

    if is_menu_open() then
        return false
    end

    local ok, is_down = pcall(function()
        return ui_combo_key:IsDown()
    end)
    if ok and is_down then
        return true
    end

    local key_code = ui_combo_key:Get()
    return type(key_code) == "number" and key_code > 0 and input.is_down(key_code) or false
end

local function can_cast_now(cast_key)
    local now = now_seconds()
    local min_delay = ui_cast_debounce_ms:Get() / 1000
    return (now - (last_cast_times[cast_key] or 0.0)) >= min_delay
        and (now - last_cast_times.global) >= min_delay
end

local function mark_cast(cast_key)
    local now = now_seconds()
    last_cast_times[cast_key] = now
    last_cast_times.global = now
    clear_hardlock_state()
end

local function clear_button(cmd, bit)
    if not cmd or not bit or not cmd.clear_buttonstate1 then
        return
    end

    pcall(function()
        cmd:clear_buttonstate1(bit)
    end)
end

local function prepare_standard_ability_cast(cmd)
    clear_button(cmd, InputBitMask_t and InputBitMask_t.IN_ALT_CAST)
    clear_button(cmd, InputBitMask_t and InputBitMask_t.IN_ABILITY_HELD)
    clear_button(cmd, InputBitMask_t and InputBitMask_t.IN_CANCEL_ABILITY)
end

local function apply_aim(cmd, me, cast_pos, aim_mode_widget, max_psilent_widget, hardlock_fov_widget, cast_key, target)
    local camera_pos, view_angles = get_camera_context(me, cmd)
    if not camera_pos or not view_angles or not cast_pos then
        clear_hardlock_state()
        return false, "context", math.huge
    end

    local aim_angle = utils.calc_angle(camera_pos, cast_pos)
    local fov = utils.get_fov(view_angles, aim_angle)
    local psilent_limit = max_psilent_widget:Get()

    if fov <= psilent_limit and cmd:can_psilent_at_pos(cast_pos) then
        cmd:set_psilent_at_pos(cast_pos)
        clear_hardlock_state()
        return true, "psilent", fov
    end

    if aim_mode_widget:Get() == MODE.AIM_MODE_PSILENT_ONLY then
        clear_hardlock_state()
        return false, "psilent_only", fov
    end

    local hardlock_limit = hardlock_fov_widget:Get()
    if fov > hardlock_limit then
        clear_hardlock_state()
        return false, "hardlock_fov", fov
    end

    utils.set_camera_angles(aim_angle)
    cmd.viewangles = aim_angle

    local target_handle = get_entity_handle(target)
    local now = now_seconds()
    if cast_key == hardlock_state.cast_key
        and target_handle == hardlock_state.target_handle
        and now >= hardlock_state.ready_at then
        return true, "hardlock", fov
    end

    hardlock_state.cast_key = cast_key
    hardlock_state.target_handle = target_handle
    hardlock_state.ready_at = now + HARDLOCK_SETTLE_DELAY
    return false, "hardlock_aligning", fov
end

local function find_best_aoe_target(me, cmd, max_range_units, radius_units, min_enemies)
    local camera_pos, view_angles = get_camera_context(me, cmd)
    if not camera_pos or not view_angles then
        return nil, 0, nil
    end

    local predict_time = ui_a4_delay:Get()
    local players = entity_list.by_class_name("C_CitadelPlayerPawn")
    if not players then
        return nil, 0, nil
    end

    local candidates = {}
    for _, enemy in pairs(players) do
        if is_valid_enemy(me, enemy) then
            local predicted = predict_linear_target(enemy, enemy:get_origin(), predict_time, true)
            if predicted and distance_2d(me:get_origin(), predicted) <= max_range_units then
                local fov = utils.get_fov(view_angles, utils.calc_angle(camera_pos, predicted))
                if fov <= ui_target_fov:Get() and (not ui_a4_require_vis:Get() or can_see_point(me, camera_pos, predicted, enemy)) then
                    candidates[#candidates + 1] = {
                        ent = enemy,
                        pos = predicted,
                        fov = fov,
                        distance = distance_2d(me:get_origin(), predicted),
                    }
                end
            end
        end
    end

    local best_pos = nil
    local best_count = 0
    local best_fov = math.huge
    local best_distance = math.huge
    local best_anchor = nil

    for _, center in ipairs(candidates) do
        local hit_count = 0
        local sum_x = 0
        local sum_y = 0
        local sum_z = 0

        for _, other in ipairs(candidates) do
            if distance_2d(other.pos, center.pos) <= radius_units then
                hit_count = hit_count + 1
                sum_x = sum_x + other.pos.x
                sum_y = sum_y + other.pos.y
                sum_z = sum_z + other.pos.z
            end
        end

        if hit_count >= min_enemies then
            local avg_pos = center.pos
            pcall(function()
                avg_pos = Vector(sum_x / hit_count, sum_y / hit_count, sum_z / hit_count)
            end)

            local fov = utils.get_fov(view_angles, utils.calc_angle(camera_pos, avg_pos))
            local distance = distance_2d(me:get_origin(), avg_pos)
            if distance <= max_range_units and fov <= ui_target_fov:Get() then
                if hit_count > best_count
                    or (hit_count == best_count and fov < best_fov)
                    or (hit_count == best_count and math.abs(fov - best_fov) <= READY_EPSILON and distance < best_distance) then
                    best_count = hit_count
                    best_fov = fov
                    best_distance = distance
                    best_pos = avg_pos
                    best_anchor = center.ent
                end
            end
        end
    end

    return best_pos, best_count, best_anchor
end

local function try_cast_a1(cmd, me, target)
    if not BIT.A1 or not target or not ui_a1:Get() or not can_cast_now("a1") then
        return false
    end

    local ability = get_ability_by_name_or_slot(me, IDS.A1, SLOT.A1)
    local ready, status, cooldown = is_ability_ready(ability)
    if not ready then
        debug_log("a1_ready", string.format("Skip A1: status=%s cd=%.2f", tostring(status), cooldown or -1), 0.75)
        return false
    end

    local max_range_units = get_effective_cast_range(ability, to_units(ui_a1_range_m:Get()))
    local cast_pos = predict_projectile_target(me, target, ability, ui_a1_speed:Get(), ui_a1_delay:Get())
    if not cast_pos or distance_2d(me:get_origin(), cast_pos) > max_range_units then
        debug_log("a1_range", "Skip A1: predicted target outside range.", 0.50)
        return false
    end

    local camera_pos = select(1, get_camera_context(me, cmd))
    if ui_a1_require_vis:Get() and not can_see_point(me, camera_pos, cast_pos, target) then
        debug_log("a1_vis", "Skip A1: predicted point is not visible.", 0.50)
        return false
    end

    local applied, reason, fov = apply_aim(cmd, me, cast_pos, ui_a1_mode, ui_a1_max_psilent, ui_a1_hardlock_fov, "a1", target)
    if not applied then
        if reason ~= "hardlock_aligning" then
            debug_log("a1_aim", string.format("Skip A1: aim reason=%s fov=%.1f", tostring(reason), fov or -1), 0.40)
        end
        return false
    end

    prepare_standard_ability_cast(cmd)
    cmd:add_buttonstate1(BIT.A1)
    mark_cast("a1")
    debug_log(nil, string.format("Cast A1 -> %s via %s", get_target_name(target), reason))
    return true
end

local function try_cast_a2(cmd, me, target)
    if not BIT.A2 or not target or not ui_a2:Get() or not can_cast_now("a2") then
        return false
    end

    local ability = get_ability_by_name_or_slot(me, IDS.A2, SLOT.A2)
    local ready, status, cooldown = is_ability_ready(ability)
    if not ready then
        debug_log("a2_ready", string.format("Skip A2: status=%s cd=%.2f", tostring(status), cooldown or -1), 0.75)
        return false
    end

    local max_range_units = get_effective_cast_range(ability, to_units(ui_a2_range_m:Get()))
    local cast_pos = predict_ground_projectile_target(me, target, ability, ui_a2_speed:Get(), ui_a2_delay:Get())
    if not cast_pos or distance_2d(me:get_origin(), cast_pos) > max_range_units then
        debug_log("a2_range", "Skip A2: predicted target outside range.", 0.50)
        return false
    end

    local camera_pos = select(1, get_camera_context(me, cmd))
    if ui_a2_require_vis:Get() and not can_see_point(me, camera_pos, cast_pos, target) then
        debug_log("a2_vis", "Skip A2: predicted point is not visible.", 0.50)
        return false
    end

    local applied, reason, fov = apply_aim(cmd, me, cast_pos, ui_a2_mode, ui_a2_max_psilent, ui_a2_hardlock_fov, "a2", target)
    if not applied then
        if reason ~= "hardlock_aligning" then
            debug_log("a2_aim", string.format("Skip A2: aim reason=%s fov=%.1f", tostring(reason), fov or -1), 0.40)
        end
        return false
    end

    prepare_standard_ability_cast(cmd)
    cmd:add_buttonstate1(BIT.A2)
    mark_cast("a2")
    debug_log(nil, string.format("Cast A2 -> %s via %s", get_target_name(target), reason))
    return true
end

local function try_cast_a4(cmd, me)
    if not BIT.A4 or not ui_a4:Get() or not can_cast_now("a4") then
        return false
    end

    local ability = get_ability_by_name_or_slot(me, IDS.A4, SLOT.A4)
    local ready, status, cooldown = is_ability_ready(ability)
    if not ready then
        debug_log("a4_ready", string.format("Skip A4: status=%s cd=%.2f", tostring(status), cooldown or -1), 0.75)
        return false
    end

    local max_range_units = get_effective_cast_range(ability, to_units(ui_a4_range_m:Get()))
    local radius_units = get_effective_aoe_radius(ability, to_units(ui_a4_radius_m:Get()))
    local cast_pos, hit_count, anchor = find_best_aoe_target(me, cmd, max_range_units, radius_units, ui_a4_min_enemies:Get())
    if not cast_pos or hit_count < ui_a4_min_enemies:Get() then
        debug_log("a4_cluster", "Skip A4: no cluster satisfying the minimum enemy count.", 0.60)
        return false
    end

    local camera_pos = select(1, get_camera_context(me, cmd))
    if ui_a4_require_vis:Get() and not can_see_point(me, camera_pos, cast_pos, anchor) then
        debug_log("a4_vis", "Skip A4: ground point is not visible.", 0.50)
        return false
    end

    local applied, reason, fov = apply_aim(cmd, me, cast_pos, ui_a4_mode, ui_a4_max_psilent, ui_a4_hardlock_fov, "a4", anchor)
    if not applied then
        if reason ~= "hardlock_aligning" then
            debug_log("a4_aim", string.format("Skip A4: aim reason=%s fov=%.1f", tostring(reason), fov or -1), 0.40)
        end
        return false
    end

    prepare_standard_ability_cast(cmd)
    cmd:add_buttonstate1(BIT.A4)
    mark_cast("a4")
    debug_log(nil, string.format("Cast A4 on %d target(s) via %s", hit_count, reason))
    return true
end

local function ensure_debug_font()
    if graves.debug_font or not Render or not Render.LoadFont then
        return graves.debug_font
    end

    local font_flags = 0
    if Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS then
        font_flags = Enum.FontCreate.FONTFLAG_ANTIALIAS
    end

    local ok, font = pcall(function()
        return Render.LoadFont("Verdana", font_flags, 700)
    end)
    if ok and type(font) == "number" then
        graves.debug_font = font
    end

    return graves.debug_font
end

local function on_draw()
    if not ui_enable:Get() or not is_graves_hero(entity_list.local_pawn()) then
        return
    end

    if ui_draw_fov:Get() and Render and Render.Circle and utils.fov_to_pixel_radius then
        local screen_size = Render.ScreenSize()
        local center = Vec2(screen_size.x / 2, screen_size.y / 2)
        local radius = utils.fov_to_pixel_radius(ui_target_fov:Get())
        Render.Circle(center, radius, Color(255, 255, 255, 55), 1.0)
    end

    if not ui_draw_target:Get() or not graves.target_handle then
        return
    end

    local target = get_entity_by_handle(graves.target_handle)
    if not target or not target:is_alive() then
        return
    end

    local point = get_target_point(target) or target:get_origin()
    local screen_pos, visible = Render.WorldToScreen(point)
    if not visible then
        return
    end

    local font = ensure_debug_font() or 0
    Render.Circle(screen_pos, 38, Color(180, 70, 70, 180), 2.0)
    Render.Text(font, 14, "TARGET", screen_pos + Vec2(0, 42), Color(255, 120, 120, 255))
end

local function on_createmove(cmd)
    if not ui_enable:Get() then
        clear_combo_target_lock()
        clear_hardlock_state()
        return
    end

    if is_menu_open() then
        clear_hardlock_state()
        return
    end

    local me = entity_list.local_pawn()
    if not me or not me:is_alive() or not is_graves_hero(me) then
        clear_combo_target_lock()
        clear_hardlock_state()
        return
    end

    if is_self_disabled(me) then
        clear_hardlock_state()
        return
    end

    if not is_combo_down() then
        clear_combo_target_lock()
        clear_hardlock_state()
        return
    end

    local target = acquire_combo_target(me, cmd)
    local casted = false

    if ui_open_with_a2:Get() then
        casted = try_cast_a2(cmd, me, target)
        if not casted then
            casted = try_cast_a1(cmd, me, target)
        end
    else
        casted = try_cast_a1(cmd, me, target)
        if not casted then
            casted = try_cast_a2(cmd, me, target)
        end
    end

    if not casted then
        casted = try_cast_a4(cmd, me)
    end

    if not casted and not target then
        debug_log("combo_idle", "Combo key held, but no valid target or Gravestone cluster was found.", 0.75)
    end
end

local function on_scripts_loaded()
    graves.hero_handle = nil
    graves.is_graves = false
    graves.last_hero_check = 0.0
    clear_combo_target_lock()
    clear_hardlock_state()
    last_cast_times.global = 0.0
    last_cast_times.a1 = 0.0
    last_cast_times.a2 = 0.0
    last_cast_times.a4 = 0.0
    debug_state = {}
    ensure_debug_font()
end

if callback.on_scripts_loaded then
    callback.on_scripts_loaded:set(on_scripts_loaded)
end

if callback.on_createmove then
    callback.on_createmove:set(on_createmove)
end

if callback.on_draw then
    callback.on_draw:set(on_draw)
end

print("[Graves] Reworked module loaded.")
