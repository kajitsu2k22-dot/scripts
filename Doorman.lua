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

local HERO_DOORMAN = "hero_doorman"
local ABILITY_BOMB = "ability_doorman_bomb"
local ABILITY_DOORWAY = "ability_doorman_doorway"
local ABILITY_LUGGAGE = "ability_doorman_luggage_cart"
local ABILITY_HOTEL = "ability_doorman_hotel"

local AIM_MODE_PSILENT_ONLY = 0
local AIM_MODE_HARD_LOCK_FALLBACK = 1

local STATUS_READY = 0
local STATUS_COOLDOWN = 2
local STATUS_PASSIVE = 3
local STATUS_BUSY = 10

local SLOT_A1 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_1) or 0
local SLOT_A3 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_3) or 2
local SLOT_A4 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_4) or 3

local STATE_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_INVULNERABLE) or 18
local STATE_TECH_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_TECH_INVULNERABLE) or 19
local STATE_TECH_DAMAGE_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_TECH_DAMAGE_INVULNERABLE) or 20
local STATE_STATUS_IMMUNE = (EModifierState and EModifierState.MODIFIER_STATE_STATUS_IMMUNE) or 22
local STATE_OUT_OF_GAME = (EModifierState and EModifierState.MODIFIER_STATE_OUT_OF_GAME) or 24
local STATE_UNIT_STATUS_HIDDEN = (EModifierState and EModifierState.MODIFIER_STATE_UNIT_STATUS_HIDDEN) or 108
local STATE_NO_INCOMING_DAMAGE = (EModifierState and EModifierState.MODIFIER_STATE_NO_INCOMING_DAMAGE) or 136

local AIM_MODE_ITEMS = {
    "P-Silent Only",
    "Hard Lock Fallback",
}

local ICON_TAB = "\u{f562}"
local ICON_ENABLE = "\u{f00c}"
local ICON_DEBUG = "\u{f188}"
local ICON_KEY = "\u{f084}"
local ICON_FOV = "\u{f06e}"
local ICON_RANGE = "\u{f124}"
local ICON_PSILENT = "\u{f05b}"
local ICON_HP = "\u{f21e}"
local ICON_ISOLATION = "\u{f0c0}"
local ICON_HOTEL_COMBO = "\u{f0e7}"

local IMAGE_CALL_BELL = "panorama/images/spellicons/ability_doorman_bomb_png.vtex_c"
local IMAGE_LUGGAGE = "panorama/images/spellicons/ability_doorman_luggage_cart_png.vtex_c"
local IMAGE_HOTEL = "panorama/images/spellicons/ability_doorman_hotel_png.vtex_c"

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

local doorman_tab = find_or_create_third_tab(hero_root, "Doorman")
local general_group = find_or_create_group(doorman_tab, "General")
local combo_group = find_or_create_group(doorman_tab, "Combo Settings")
local call_bell_group = find_or_create_group(doorman_tab, "Call Bell (1)")
local luggage_group = find_or_create_group(doorman_tab, "Luggage Cart (3)")
local hotel_group = find_or_create_group(doorman_tab, "Hotel Guest (4)")

set_widget_icon(doorman_tab, ICON_TAB, false)

local enable_script = general_group:Switch("Enable Script", true, ICON_ENABLE)
local debug_logging = general_group:Switch("Debug Logging", false, ICON_DEBUG)

local combo_key = combo_group:Bind("Combo Key", Enum.ButtonCode.KEY_NONE, ICON_KEY)
local target_fov = combo_group:Slider("Target FOV", 1, 180, 28, "%d")
local target_max_distance_m = combo_group:Slider("Target Max Distance (m)", 5, 75, 40, "%d")
local target_sticky_ms = combo_group:Slider("Sticky Target (ms)", 100, 400, 280, "%d")

local call_bell_enabled = call_bell_group:Switch("Use Call Bell (1)", true, IMAGE_CALL_BELL)
local call_bell_gear = call_bell_enabled:Gear("Call Bell Settings")
local call_bell_mode = call_bell_gear:Combo("Aim Mode", AIM_MODE_ITEMS, AIM_MODE_HARD_LOCK_FALLBACK)
local call_bell_fov = call_bell_gear:Slider("Aim FOV", 1, 180, 28, "%d")
local call_bell_max_psilent = call_bell_gear:Slider("Max PSilent Degree", 1, 90, 24, "%d")
local call_bell_max_range_m = call_bell_gear:Slider("Max Range (m)", 5, 40, 18, "%d")

local luggage_enabled = luggage_group:Switch("Use Luggage Cart (3)", true, IMAGE_LUGGAGE)
local luggage_gear = luggage_enabled:Gear("Luggage Cart Settings")
local luggage_mode = luggage_gear:Combo("Aim Mode", AIM_MODE_ITEMS, AIM_MODE_HARD_LOCK_FALLBACK)
local luggage_fov = luggage_gear:Slider("Aim FOV", 1, 180, 30, "%d")
local luggage_force_below_hp = luggage_gear:Slider("Force Cast If HP Below (%)", 1, 100, 55, "%d")
local luggage_max_psilent = luggage_gear:Slider("Max PSilent Degree", 1, 90, 26, "%d")
local luggage_max_range_m = luggage_gear:Slider("Max Range (m)", 5, 50, 25, "%d")
local luggage_prefer_wall = luggage_gear:Switch("Prefer Wall Impact", true)
local luggage_prefer_wall_score = luggage_gear:Switch("Prefer Wall Impact (score)", false)

local hotel_enabled = hotel_group:Switch("Auto Hotel Guest (4)", true, IMAGE_HOTEL)
local hotel_gear = hotel_enabled:Gear("Hotel Guest Settings")
local hotel_use_in_combo = hotel_gear:Switch("Use in Combo", false)
local hotel_target_fov = hotel_gear:Slider("Target FOV", 1, 180, 42, "%d")
local hotel_target_max_distance_m = hotel_gear:Slider("Target Max Distance (m)", 5, 75, 45, "%d")
local hotel_hp_threshold = hotel_gear:Slider("HP Threshold (%)", 1, 100, 42, "%d")
local hotel_isolation_radius_m = hotel_gear:Slider("Isolation Radius (m)", 1, 20, 8, "%d")
local hotel_max_nearby = hotel_gear:Slider("Max Nearby Enemies", 0, 5, 1, "%d")

set_widget_icon(target_fov, ICON_FOV, false)
set_widget_icon(target_max_distance_m, ICON_RANGE, false)
set_widget_icon(target_sticky_ms, ICON_KEY, false)

set_widget_icon(call_bell_mode, "\u{f0f3}", false)
set_widget_icon(call_bell_fov, ICON_FOV, false)
set_widget_icon(call_bell_max_psilent, ICON_PSILENT, false)
set_widget_icon(call_bell_max_range_m, ICON_RANGE, false)

set_widget_icon(luggage_mode, "\u{f07a}", false)
set_widget_icon(luggage_fov, ICON_FOV, false)
set_widget_icon(luggage_force_below_hp, ICON_HP, false)
set_widget_icon(luggage_max_psilent, ICON_PSILENT, false)
set_widget_icon(luggage_max_range_m, ICON_RANGE, false)
set_widget_icon(luggage_prefer_wall, "\u{f6d9}", false)
set_widget_icon(luggage_prefer_wall_score, "\u{f201}", false)

set_widget_icon(hotel_use_in_combo, ICON_HOTEL_COMBO, false)
set_widget_icon(hotel_target_fov, ICON_FOV, false)
set_widget_icon(hotel_target_max_distance_m, ICON_RANGE, false)
set_widget_icon(hotel_hp_threshold, ICON_HP, false)
set_widget_icon(hotel_isolation_radius_m, ICON_RANGE, false)
set_widget_icon(hotel_max_nearby, ICON_ISOLATION, false)

enable_script:ToolTip("Master switch for the whole Doorman module.")
debug_logging:ToolTip("Print cast decisions and skip reasons into the Lua console.")
combo_key:ToolTip("Hold to run the main combat sequence.")
target_fov:ToolTip("Maximum FOV allowed for target selection.")
target_max_distance_m:ToolTip("Maximum target distance used by combo target selection.")
target_sticky_ms:ToolTip("Keep the current combo target for a short time before retargeting.")
call_bell_enabled:ToolTip("Enable Call Bell automation inside combo.")
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
    a3 = 0.0,
    a4 = 0.0,
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

local function is_doorman_ability_name(name)
    local normalized = normalize_name(name)
    if not normalized then
        return false
    end

    return normalized == ABILITY_BOMB
        or normalized == ABILITY_DOORWAY
        or normalized == ABILITY_LUGGAGE
        or normalized == ABILITY_HOTEL
end

local function is_doorman_hero_name(name)
    return normalize_name(name) == HERO_DOORMAN
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
        STATE_INVULNERABLE,
        STATE_TECH_INVULNERABLE,
        STATE_TECH_DAMAGE_INVULNERABLE,
        STATE_STATUS_IMMUNE,
        STATE_OUT_OF_GAME,
        STATE_UNIT_STATUS_HIDDEN,
        STATE_NO_INCOMING_DAMAGE,
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

    if status == STATUS_READY then
        return true
    end

    return type(cooldown) == "number"
        and cooldown <= READY_EPSILON
        and status ~= STATUS_COOLDOWN
        and status ~= STATUS_PASSIVE
        and status ~= STATUS_BUSY
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

    debug_log("target_lock", string.format("Holding sticky target at %.1fm / %.1f FOV.", snapshot.distance / UNIT_METER, snapshot.fov), 0.75)
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
    local locked_target, locked_fov, locked_distance = get_locked_combo_target(lp, cmd, max_fov_deg, max_distance_units)
    if locked_target then
        return locked_target, locked_fov, locked_distance
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
        set_combo_target_lock(best_target, sticky_ms)
        debug_log("target", string.format("Selected target at %.1fm / %.1f FOV.", best_distance / UNIT_METER, best_fov), 0.75)
    else
        clear_combo_target_lock()
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
    if mode == AIM_MODE_PSILENT_ONLY then
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

local function try_cast_luggage(lp, cmd, target, ability)
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
    luggage_prefer_wall_score:Visible(luggage_prefer_wall:Get())
end

luggage_prefer_wall:SetCallback(update_mode_visibility, true)

callback.on_createmove:set(function(cmd)
    if not enable_script:Get() or Menu.Opened() then
        clear_hardlock_state()
        return
    end

    if not cmd or cmd.in_shop then
        clear_hardlock_state()
        return
    end

    local lp = entity_list.local_pawn()
    if not lp or not lp.valid or not lp:valid() or not lp:is_alive() then
        clear_combo_target_lock()
        clear_hardlock_state()
        return
    end

    if not is_doorman_hero(lp) then
        clear_combo_target_lock()
        clear_hardlock_state()
        return
    end

    if has_any_modifier_state(lp, {
        STATE_OUT_OF_GAME,
        STATE_UNIT_STATUS_HIDDEN,
    }) then
        clear_combo_target_lock()
        clear_hardlock_state()
        return
    end

    local a1 = get_ability(lp, ABILITY_BOMB, SLOT_A1)
    local a3 = get_ability(lp, ABILITY_LUGGAGE, SLOT_A3)
    local a4 = get_ability(lp, ABILITY_HOTEL, SLOT_A4)

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

    if combo_active and combo_target then
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

        if call_bell_enabled:Get() and a1 then
            local bell_casted, bell_reason = try_cast_call_bell(lp, cmd, combo_target, a1)
            if bell_casted or bell_reason == "aligning" then
                return
            end
        end
    elseif combo_active then
        debug_log("combo_no_target", "Combo active but no valid target found.", 0.75)
        clear_hardlock_state()
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
end)

callback.on_scripts_loaded:set(function()
    update_mode_visibility()
    print(DEBUG_PREFIX .. " Loaded.")
end)

print(DEBUG_PREFIX .. " Script initialized.")
