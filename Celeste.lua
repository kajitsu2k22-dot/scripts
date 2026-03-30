---@diagnostic disable: undefined-global

local VERSION = "4.2.0"
local DEBUG_PREFIX = "[Celeste]"
local HERO_ID = 81
local UNIT_METER = 37.7358490566
local READY_EPSILON = 0.05
local TARGET_STICKY_FOV_BUFFER = 8.0
local TARGET_STICKY_RANGE_BUFFER_M = 5.0
local DEFAULT_TARGET_POINT_Z = 45.0
local DEFAULT_EYE_HEIGHT = 60.0
local DEFAULT_A3_REPRESS_DELAY = 0.35
local DEFAULT_ULT_SPEED = 1200.0
local DEFAULT_ULT_AOE = 400.0
local GUARD_BUFF_NAME = "modifier_unicorn_prismatic_guard_buff"

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
}

local BIT = {
    A1 = InputBitMask_t.IN_ABILITY1,
    A2 = InputBitMask_t.IN_ABILITY2,
    A3 = InputBitMask_t.IN_ABILITY3,
    A4 = InputBitMask_t.IN_ABILITY4,
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
    BUSY_WITH_ACTION = (EModifierState and EModifierState.MODIFIER_STATE_BUSY_WITH_ACTION) or 55,
    BULLET_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_BULLET_INVULNERABLE) or 85,
    UNIT_STATUS_HIDDEN = (EModifierState and EModifierState.MODIFIER_STATE_UNIT_STATUS_HIDDEN) or 108,
    NO_INCOMING_DAMAGE = (EModifierState and EModifierState.MODIFIER_STATE_NO_INCOMING_DAMAGE) or 136,
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
    SHIELD = "\u{f132}",
    BLAST = "\u{f0e7}",
    DAGGER = "\u{f71b}",
    STAR = "\u{f005}",
    PSILENT = "\u{f05b}",
    STEER = "\u{f57d}",
    NET = "\u{f1eb}",
    DEBUG = "\u{f188}",
}

local BONE_PRIORITY = {
    "spine_2",
    "spine_1",
    "chest",
    "neck_0",
    "head",
}

local celeste = {
    target = nil,
    target_lock_expires = 0,
    last_cast_time = 0,
    ability_cast_times = {
        a1 = 0,
        a2 = 0,
        a3 = 0,
        a4 = 0,
    },
}

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

local hero_root = Menu.Find("Heroes", "Hero List", "Celeste")
if not hero_root then
    hero_root = Menu.Create("Heroes", "Hero List", "Celeste")
end

local groups = {
    tab = find_or_create_third_tab(hero_root, "Prismatic Core"),
}

groups.general = find_or_create_group(groups.tab, "General")
groups.targeting = find_or_create_group(groups.tab, "Targeting")
groups.guard = find_or_create_group(groups.tab, "Prismatic Guard (2)")
groups.a1 = find_or_create_group(groups.tab, "Radiant Blast (1)")
groups.a3 = find_or_create_group(groups.tab, "Radiant Daggers (3)")
groups.a4 = find_or_create_group(groups.tab, "Shining Wonder (4)")
groups.prediction = find_or_create_group(groups.tab, "Prediction")
groups.debug = find_or_create_group(groups.tab, "Debug")

set_widget_icon(groups.tab, ICON.TAB, false)

local ui_enable = groups.general:Switch("Enable Script", true, ICON.ENABLE)
local ui_combo_key = groups.general:Bind("Combo Key", Enum.ButtonCode.KEY_X, ICON.KEY)
local ui_cast_debounce_ms = groups.general:Slider("Cast Debounce (ms)", 0, 250, 80, "%d", ICON.CLOCK)

local ui_target_lock = groups.targeting:Switch("Sticky Target", true, ICON.LOCK)
local ui_target_sticky_ms = groups.targeting:Slider("Stick Time (ms)", 50, 600, 280, "%d", ICON.CLOCK)
local ui_target_prio = groups.targeting:Combo("Priority", { "FOV", "HP%", "Distance" }, 0, ICON.TARGET)
local ui_target_fov = groups.targeting:Slider("Engagement FOV", 1, 180, 25, "%d", ICON.FOV)
local ui_target_range_m = groups.targeting:Slider("Max Distance (m)", 5, 70, 40, "%d", ICON.RANGE)

local ui_guard = groups.guard:Switch("Auto Prismatic Guard (2)", true, ICON.SHIELD)
local guard_gear = ui_guard:Gear("Guard Logic")
local ui_guard_hp = guard_gear:Slider("HP Threshold %", 1, 100, 70, "%d", ICON.HP)
local ui_guard_range_m = guard_gear:Slider("Threat Range (m)", 5, 35, 18, "%d", ICON.RANGE)
local ui_guard_min_enemies = guard_gear:Slider("Min Nearby Enemies", 1, 6, 1, "%d", ICON.GROUP)

local ui_a1 = groups.a1:Switch("Use Radiant Blast (1)", true, ICON.BLAST)
local a1_gear = ui_a1:Gear("Blast Logic")
local ui_a1_require_vis = a1_gear:Switch("Require Visibility", true)

local ui_a3 = groups.a3:Switch("Use Radiant Daggers (3)", true, ICON.DAGGER)
local a3_gear = ui_a3:Gear("Daggers Logic")
local ui_a3_pred = a3_gear:Switch("Use Prediction", true)
local ui_a3_delay = a3_gear:Slider("Formation Delay (s)", 0.05, 1.50, 0.80, "%.2f", ICON.CLOCK)
local ui_a3_repress_delay = a3_gear:Slider("Recast Delay (s)", 0.05, 1.00, DEFAULT_A3_REPRESS_DELAY, "%.2f", ICON.CLOCK)
local ui_a3_require_vis = a3_gear:Switch("Require Ground Visibility", true)

local ui_a4 = groups.a4:Switch("Use Shining Wonder (4)", true, ICON.STAR)
local a4_gear = ui_a4:Gear("Ultimate Logic")
local ui_a4_pred = a4_gear:Switch("Use Prediction", true)
local ui_a4_min_enemies = a4_gear:Slider("Min Enemies to Cast", 1, 6, 1, "%d", ICON.GROUP)
local ui_a4_psilent = a4_gear:Switch("Use P-Silent When Possible", true, ICON.PSILENT)
local ui_a4_hardlock = a4_gear:Switch("Hard Lock Fallback", true, ICON.TARGET)
local ui_a4_hardlock_fov = a4_gear:Slider("Hard Lock FOV", 1, 45, 16, "%d", ICON.FOV)
local ui_a4_steer = a4_gear:Switch("Steer Active Orb", true, ICON.STEER)
local ui_a4_steer_fov = a4_gear:Slider("Steer FOV", 1, 45, 20, "%d", ICON.FOV)

local ui_predict_latency = groups.prediction:Switch("Latency Compensation", true, ICON.NET)
local ui_predict_bias_ms = groups.prediction:Slider("Extra Bias (ms)", 0, 200, 0, "%d", ICON.CLOCK)
local ui_predict_max_time = groups.prediction:Slider("Max Predict Time (s)", 0.05, 1.50, 0.60, "%.2f", ICON.CLOCK)

local ui_debug = groups.debug:Switch("Debug Logging", false, ICON.DEBUG)

ui_target_lock:SetCallback(function(self)
    ui_target_sticky_ms:Visible(self:Get())
end, true)

ui_a4_hardlock:SetCallback(function(self)
    ui_a4_hardlock_fov:Visible(self:Get())
end, true)

ui_a4_steer:SetCallback(function(self)
    ui_a4_steer_fov:Visible(self:Get())
end, true)

local function is_menu_open()
    return Menu.Opened and Menu.Opened() or false
end

local function get_now()
    local now = nil
    pcall(function()
        now = global_vars.curtime()
    end)
    return type(now) == "number" and now or os.clock()
end

local function debug_log(message)
    if not ui_debug:Get() then
        return
    end

    print(string.format("%s %s", DEBUG_PREFIX, message))
end

local function meters_to_units(value)
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

local function safe_has_state(ent, state)
    if not ent or not state then
        return false
    end

    local ok, result = pcall(function()
        return ent:has_modifier_state(state)
    end)
    return ok and result or false
end

local function has_any_state(ent, states)
    for _, state in ipairs(states) do
        if safe_has_state(ent, state) then
            return true
        end
    end
    return false
end

local function get_target_name(target)
    if not target then
        return "unknown"
    end

    local name = ""
    pcall(function()
        name = target:get_name()
    end)
    if type(name) == "string" and name ~= "" then
        return name
    end

    pcall(function()
        name = target:get_vdata_class_name()
    end)
    if type(name) == "string" and name ~= "" then
        return name
    end

    local idx = -1
    pcall(function()
        idx = target:get_index()
    end)
    return "target#" .. tostring(idx)
end

local function clear_target_lock()
    celeste.target = nil
    celeste.target_lock_expires = 0
end

local function can_issue_action()
    return (get_now() - celeste.last_cast_time) >= (ui_cast_debounce_ms:Get() / 1000)
end

local function can_repress_ability(cast_key, delay)
    if not cast_key then
        return true
    end

    local last_time = celeste.ability_cast_times[cast_key] or 0
    return (get_now() - last_time) >= (delay or 0)
end

local function mark_action(action_name, target, cast_key)
    local now = get_now()
    celeste.last_cast_time = now
    if cast_key then
        celeste.ability_cast_times[cast_key] = now
    end
    debug_log(string.format("Action: %s -> %s", action_name, get_target_name(target)))
end

local function is_playing_celeste(me)
    if not me or not me.valid or not me:valid() then
        return false
    end

    local hero_comp = me.m_CCitadelHeroComponent
    local spawned_hero = hero_comp and hero_comp.m_spawnedHero or nil
    local hero_id = spawned_hero and spawned_hero.m_nHeroID and spawned_hero.m_nHeroID.m_Value or nil
    return hero_id == HERO_ID
end

local function get_eye_pos(me)
    if not me or not me.valid or not me:valid() then
        return nil
    end
    return me:get_origin() + Vector(0, 0, DEFAULT_EYE_HEIGHT)
end

local function get_camera_context(me, cmd)
    local cam_pos = nil
    local cam_ang = nil

    pcall(function()
        cam_pos = utils.get_camera_pos()
    end)
    if not cam_pos then
        cam_pos = get_eye_pos(me)
    end

    pcall(function()
        cam_ang = utils.get_camera_angles()
    end)
    if not cam_ang and cmd then
        cam_ang = cmd.viewangles
    end

    return cam_pos, cam_ang
end

local function is_target_untargetable(ent)
    return has_any_state(ent, {
        MODSTATE.INVULNERABLE,
        MODSTATE.TECH_INVULNERABLE,
        MODSTATE.TECH_DAMAGE_INVULNERABLE,
        MODSTATE.STATUS_IMMUNE,
        MODSTATE.OUT_OF_GAME,
        MODSTATE.BULLET_INVULNERABLE,
        MODSTATE.UNIT_STATUS_HIDDEN,
        MODSTATE.NO_INCOMING_DAMAGE,
    })
end

local function is_target_static(ent)
    return has_any_state(ent, {
        MODSTATE.STUNNED,
        MODSTATE.IMMOBILIZED,
    })
end

local function is_self_disabled(me)
    return has_any_state(me, {
        MODSTATE.BUSY_WITH_ACTION,
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
    if me.m_iTeamNum == ent.m_iTeamNum then
        return false
    end
    if is_target_untargetable(ent) then
        return false
    end
    return true
end

local function get_target_point(target)
    if not target or not target.valid or not target:valid() then
        return nil
    end

    for _, bone_name in ipairs(BONE_PRIORITY) do
        local bone = nil
        pcall(function()
            bone = target:get_bone_pos(bone_name)
        end)
        if bone and not bone:IsInvalid() and bone:LengthSqr() > 0 then
            return bone
        end
    end

    return target:get_origin() + Vector(0, 0, DEFAULT_TARGET_POINT_Z)
end

local function is_visible_point(me, start_pos, end_pos)
    if not me or not start_pos or not end_pos then
        return false
    end
    return trace.bullet(start_pos, end_pos, 1.0, me)
end

local function is_target_visible(me, target, start_pos, target_point)
    local aim_from = start_pos or get_eye_pos(me)
    local aim_to = target_point or get_target_point(target)
    return is_visible_point(me, aim_from, aim_to)
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
    if type(level) == "number" and level <= 0 then
        return false, status, cooldown, level
    end

    if status == STATUS.READY then
        return true, status, cooldown, level
    end

    if type(cooldown) == "number"
        and cooldown <= READY_EPSILON
        and status ~= STATUS.COOLDOWN
        and status ~= STATUS.PASSIVE then
        return true, status, cooldown, level
    end

    return false, status, cooldown, level
end

local function is_ability_busy(ability)
    local status, _, level = get_ability_state(ability)
    return type(level) == "number" and level > 0 and status == STATUS.BUSY
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

local function get_effective_cast_range(ability, fallback)
    local range = nil
    pcall(function()
        range = ability:get_cast_range()
    end)
    if type(range) == "number" and range > 0 then
        return range
    end

    return get_scaled_property(ability, {
        "m_flCastRange",
        "m_flAbilityCastRange",
        "CastRange",
        "m_flRange",
    }) or fallback
end

local function get_effective_aoe_radius(ability, fallback)
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
    }) or fallback
end

local function get_projectile_speed(ability, fallback)
    return get_scaled_property(ability, {
        "m_flProjectileSpeed",
        "m_flSpeed",
        "m_flBulletSpeed",
    }) or fallback
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

local function clamp_predict_time(value)
    return math.max(0, math.min(value or 0, ui_predict_max_time:Get()))
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

local function predict_projectile_target(me, target, ability, fallback_speed)
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
    pcall(function()
        predicted = utils.predict_bullet(src, base_pos, target:get_velocity(), speed)
    end)

    if predicted and not predicted:IsInvalid() then
        local extra = get_prediction_extra_time()
        if extra > 0 then
            local velocity = Vector(0, 0, 0)
            pcall(function()
                velocity = target:get_velocity()
            end)
            predicted = predicted + (velocity * extra)
        end
        return predicted
    end

    local travel_time = (speed and speed > 0) and (distance_2d(src, base_pos) / speed) or 0
    return predict_linear_target(target, base_pos, travel_time, false)
end

local function get_target_score(me, target, cam_pos, cam_ang)
    local target_point = get_target_point(target)
    if not target_point then
        return nil
    end

    local max_distance = meters_to_units(ui_target_range_m:Get())
    local distance = distance_2d(me:get_origin(), target:get_origin())
    if distance > max_distance then
        return nil
    end

    local fov = utils.get_fov(cam_ang, utils.calc_angle(cam_pos, target_point))
    if fov > ui_target_fov:Get() then
        return nil
    end

    if not is_target_visible(me, target, cam_pos, target_point) then
        return nil
    end

    local mode = ui_target_prio:Get()
    if mode == 1 then
        local max_hp = math.max(target:get_max_health() or 1, 1)
        local hp_pct = (target.m_iHealth / max_hp) * 100
        return hp_pct + (fov * 0.05)
    end
    if mode == 2 then
        return distance
    end

    return fov
end

local function can_keep_target(me, target, cam_pos, cam_ang)
    if not is_valid_enemy(me, target) then
        return false
    end

    local target_point = get_target_point(target)
    if not target_point then
        return false
    end

    local max_distance = meters_to_units(ui_target_range_m:Get() + TARGET_STICKY_RANGE_BUFFER_M)
    local distance = distance_2d(me:get_origin(), target:get_origin())
    if distance > max_distance then
        return false
    end

    local fov = utils.get_fov(cam_ang, utils.calc_angle(cam_pos, target_point))
    if fov > (ui_target_fov:Get() + TARGET_STICKY_FOV_BUFFER) then
        return false
    end

    return is_target_visible(me, target, cam_pos, target_point)
end

local function acquire_target(me, cmd)
    local cam_pos, cam_ang = get_camera_context(me, cmd)
    if not cam_pos or not cam_ang then
        return nil
    end

    local now = get_now()
    if ui_target_lock:Get()
        and celeste.target
        and now < celeste.target_lock_expires
        and can_keep_target(me, celeste.target, cam_pos, cam_ang) then
        return celeste.target
    end

    local best_target = nil
    local best_score = math.huge

    for _, enemy in ipairs(entity_list.by_class_name("C_CitadelPlayerPawn")) do
        if is_valid_enemy(me, enemy) then
            local score = get_target_score(me, enemy, cam_pos, cam_ang)
            if score and score < best_score then
                best_score = score
                best_target = enemy
            end
        end
    end

    celeste.target = best_target
    celeste.target_lock_expires = best_target and (now + (ui_target_sticky_ms:Get() / 1000)) or 0
    return best_target
end

local function count_enemies_in_radius(me, center, radius)
    local count = 0
    for _, enemy in ipairs(entity_list.by_class_name("C_CitadelPlayerPawn")) do
        if is_valid_enemy(me, enemy) and distance_2d(center, enemy:get_origin()) <= radius then
            count = count + 1
        end
    end
    return count
end

local function try_guard(cmd, me, a2)
    if not ui_guard:Get() or not can_issue_action() then
        return false
    end

    local ready = is_ability_ready(a2)
    if not ready then
        return false
    end

    local hp_pct = (me.m_iHealth / math.max(me:get_max_health() or 1, 1)) * 100
    if hp_pct > ui_guard_hp:Get() then
        return false
    end

    if me:has_modifier(GUARD_BUFF_NAME) then
        return false
    end

    local nearby_enemies = count_enemies_in_radius(me, me:get_origin(), meters_to_units(ui_guard_range_m:Get()))
    if nearby_enemies < ui_guard_min_enemies:Get() then
        return false
    end

    cmd:add_buttonstate1(BIT.A2)
    mark_action("Prismatic Guard", me, "a2")
    return true
end

local function try_blast(cmd, me, target, a1)
    if not ui_a1:Get() or not can_issue_action() then
        return false
    end

    local ready = is_ability_ready(a1)
    if not ready then
        return false
    end

    local cam_pos = select(1, get_camera_context(me, cmd))
    local cast_pos = get_target_point(target)
    if not cam_pos or not cast_pos then
        return false
    end

    local cast_range = get_effective_cast_range(a1, 0)
    if cast_range > 0 and distance_2d(me:get_origin(), target:get_origin()) > cast_range then
        return false
    end

    if ui_a1_require_vis:Get() and not is_target_visible(me, target, cam_pos, cast_pos) then
        return false
    end

    if not cmd:can_psilent_at_pos(cast_pos) then
        return false
    end

    cmd:set_psilent_at_pos(cast_pos)
    cmd:add_buttonstate1(BIT.A1)
    mark_action("Radiant Blast", target, "a1")
    return true
end

local function try_daggers(cmd, me, target, a3)
    if not ui_a3:Get() or not can_issue_action() then
        return false
    end

    local ready = is_ability_ready(a3)
    if not ready then
        return false
    end

    if not can_repress_ability("a3", ui_a3_repress_delay:Get()) then
        return false
    end

    local base_pos = target:get_origin()
    local cast_pos = ui_a3_pred:Get()
        and predict_linear_target(target, base_pos, ui_a3_delay:Get(), true)
        or base_pos

    local cast_range = get_effective_cast_range(a3, 0)
    if cast_range > 0 and distance_2d(me:get_origin(), cast_pos) > cast_range then
        return false
    end

    local eye_pos = get_eye_pos(me)
    if ui_a3_require_vis:Get() and not is_visible_point(me, eye_pos, cast_pos) then
        return false
    end

    if not cmd:can_psilent_at_pos(cast_pos) then
        return false
    end

    cmd:set_psilent_at_pos(cast_pos)
    cmd:add_buttonstate1(BIT.A3)
    mark_action("Radiant Daggers", target, "a3")
    return true
end

local function hardlock_to_pos(cmd, me, pos, max_fov)
    local cam_pos, cam_ang = get_camera_context(me, cmd)
    if not cam_pos or not cam_ang or not pos then
        return false, math.huge
    end

    local aim_angle = utils.calc_angle(cam_pos, pos)
    local fov = utils.get_fov(cam_ang, aim_angle)
    if max_fov and fov > max_fov then
        return false, fov
    end

    utils.set_camera_angles(aim_angle)
    cmd.viewangles = aim_angle
    return true, fov
end

local function try_ult_steer(cmd, me, target, a4)
    if not ui_a4:Get() or not ui_a4_steer:Get() or not target then
        return false
    end

    if not is_ability_busy(a4) then
        return false
    end

    local steer_pos = ui_a4_pred:Get()
        and predict_projectile_target(me, target, a4, DEFAULT_ULT_SPEED)
        or get_target_point(target)
    if not steer_pos then
        return false
    end

    local cam_pos, cam_ang = get_camera_context(me, cmd)
    if not cam_pos or not cam_ang then
        return false
    end

    if not is_visible_point(me, cam_pos, steer_pos) then
        return false
    end

    local steer_angle = utils.calc_angle(cam_pos, steer_pos)
    local fov = utils.get_fov(cam_ang, steer_angle)
    if fov > ui_a4_steer_fov:Get() then
        return false
    end

    utils.set_camera_angles(steer_angle)
    cmd.viewangles = steer_angle
    return true
end

local function try_ult_cast(cmd, me, target, a4)
    if not ui_a4:Get() or not can_issue_action() then
        return false
    end

    local ready = is_ability_ready(a4)
    if not ready then
        return false
    end

    local cast_pos = ui_a4_pred:Get()
        and predict_projectile_target(me, target, a4, DEFAULT_ULT_SPEED)
        or get_target_point(target)
    if not cast_pos then
        return false
    end

    local cast_range = get_effective_cast_range(a4, 0)
    if cast_range > 0 and distance_2d(me:get_origin(), cast_pos) > cast_range then
        return false
    end

    local aoe_radius = get_effective_aoe_radius(a4, DEFAULT_ULT_AOE)
    local enemy_count = count_enemies_in_radius(me, cast_pos, aoe_radius)
    if enemy_count < ui_a4_min_enemies:Get() then
        return false
    end

    local cam_pos, cam_ang = get_camera_context(me, cmd)
    if not cam_pos or not cam_ang then
        return false
    end

    if not is_visible_point(me, cam_pos, cast_pos) then
        return false
    end

    if ui_a4_psilent:Get() and cmd:can_psilent_at_pos(cast_pos) then
        cmd:set_psilent_at_pos(cast_pos)
        cmd:add_buttonstate1(BIT.A4)
        mark_action("Shining Wonder", target, "a4")
        return true
    end

    if ui_a4_hardlock:Get() then
        local aimed = hardlock_to_pos(cmd, me, cast_pos, ui_a4_hardlock_fov:Get())
        if aimed then
            cmd:add_buttonstate1(BIT.A4)
            mark_action("Shining Wonder", target, "a4")
            return true
        end
    end

    return false
end

local function on_createmove(cmd)
    if not ui_enable:Get() or is_menu_open() then
        clear_target_lock()
        return
    end

    local me = entity_list.local_pawn()
    if not me or not me.valid or not me:valid() or not me:is_alive() then
        clear_target_lock()
        return
    end

    if not is_playing_celeste(me) then
        clear_target_lock()
        return
    end

    local a1 = me:get_ability_by_slot(SLOT.A1)
    local a2 = me:get_ability_by_slot(SLOT.A2)
    local a3 = me:get_ability_by_slot(SLOT.A3)
    local a4 = me:get_ability_by_slot(SLOT.A4)

    local combo_active = ui_combo_key:IsDown()
    local target = nil
    if combo_active then
        target = acquire_target(me, cmd)
    else
        clear_target_lock()
    end

    if combo_active and target and try_ult_steer(cmd, me, target, a4) then
        return
    end

    if is_self_disabled(me) then
        return
    end

    if try_guard(cmd, me, a2) then
        return
    end

    if not combo_active or not target then
        return
    end

    if try_ult_cast(cmd, me, target, a4) then
        return
    end

    if try_daggers(cmd, me, target, a3) then
        return
    end

    if try_blast(cmd, me, target, a1) then
        return
    end
end

local function on_remove_entity(ent)
    if not ent or not ent.valid or not ent:valid() then
        return
    end

    if celeste.target and ent:get_index() == celeste.target:get_index() then
        clear_target_lock()
    end
end

callback.on_createmove:set(on_createmove)
callback.on_remove_entity:set(on_remove_entity)

print(string.format("%s v%s loaded.", DEBUG_PREFIX, VERSION))
