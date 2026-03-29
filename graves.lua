-- Graves Script
-- Native Deadlock API aligned with Umbrella definitions

local graves = {}

-- General Elements
local general_menu = Menu.Create("Heroes", "Hero List", "Graves", "Main Settings", "General")
local enable_script = general_menu:Switch("Enable Script", true, "\xef\x81\xad")
local target_priority = general_menu:Combo("Target Priority", {"Distance", "Lowest HP", "Crosshair FOV", "Effective HP (EHP)"}, 2)
local sticky_target = general_menu:Switch("Sticky Target (Lock)", true)
local combo_fov = general_menu:Slider("Combo Max FOV", 10, 360, 90, "%d deg")

-- Combo Elements
local combo_menu = Menu.Create("Heroes", "Hero List", "Graves", "Main Settings", "Combo & Skills")
local combo_enable = combo_menu:Switch("Enable Combo", true, "\xef\x81\xad")
local combo_key = combo_menu:Bind("Combo Key", Enum.ButtonCode.KEY_LALT)
local smart_combo_enable = combo_menu:Switch("Smart Sequence (A2 First)", true)

local enable_a1 = combo_menu:Switch("Haunting Skull (1)", true, "\xef\x95\xae")
local a1_gear = enable_a1:Gear("Settings##1")
local a1_mode = a1_gear:Combo("Targeting Strategy", {"pSilent", "Hard Lock"}, 1)
local a1_speed = a1_gear:Slider("Proj. Speed", 500, 5000, 1500, "%d u/s")
local a1_delay = a1_gear:Slider("Cast Delay", 0.0, 1.5, 0.2, "%.1f sec")
local a1_max_range = a1_gear:Slider("Limiter", 500, 3000, 1000, "%.0f radius")

local enable_a2 = combo_menu:Switch("Zombie Wall (2)", true, "\xef\x81\x9b")
local a2_gear = enable_a2:Gear("Settings##2")
local a2_mode = a2_gear:Combo("Targeting Strategy", {"pSilent", "Hard Lock"}, 1)
local a2_speed = a2_gear:Slider("Proj. Speed", 500, 5000, 2000, "%d u/s")
local a2_delay = a2_gear:Slider("Cast Delay", 0.0, 1.5, 0.3, "%.1f sec")
local a2_max_range = a2_gear:Slider("Limiter", 500, 3000, 1500, "%.0f radius")


local enable_a4 = combo_menu:Switch("Gravestone (4)", true, "\xef\x87\xa2")
local a4_gear = enable_a4:Gear("Settings##4")
local a4_mode = a4_gear:Combo("Targeting Strategy", {"pSilent", "Hard Lock"}, 1)
local a4_min_enemies = a4_gear:Slider("Min Splash Enemies", 1, 5, 1, "%d heroes")
local a4_delay = a4_gear:Slider("Cast Delay", 0.0, 5.0, 0.4, "%.1f sec")
local a4_max_range = a4_gear:Slider("Limiter", 500, 3000, 1500, "%.0f radius")

local other_menu = Menu.Create("Heroes", "Hero List", "Graves", "Main Settings", "Other")
local enable_debug = other_menu:Switch("Prediction Debug", true, "\xef\x86\x88")

local last_cast_times = { a1 = 0.0, a2 = 0.0, a3 = 0.0, a4 = 0.0, global = 0.0 }
local CAST_DELAY = 0.05
local HERO_RECHECK_DELAY = 1.0
local READY_EPSILON = 0.05

local is_graves = false
local last_hero_key = nil
local last_hero_check_time = 0.0
local locked_target = nil
local last_state_log_time = 0.0

local STATUS_READY = 0
local STATUS_COOLDOWN = 2
local STATUS_PASSIVE = 3
local STATUS_BUSY = 10

local SLOT_A1 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_1) or 0
local SLOT_A2 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_2) or 1
local SLOT_A4 = (EAbilitySlots_t and EAbilitySlots_t.ESlot_Signature_4) or 3

local STATE_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_INVULNERABLE) or 18
local STATE_TECH_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_TECH_INVULNERABLE) or 19
local STATE_TECH_DAMAGE_INVULNERABLE = (EModifierState and EModifierState.MODIFIER_STATE_TECH_DAMAGE_INVULNERABLE) or 20
local STATE_STATUS_IMMUNE = (EModifierState and EModifierState.MODIFIER_STATE_STATUS_IMMUNE) or 22
local STATE_OUT_OF_GAME = (EModifierState and EModifierState.MODIFIER_STATE_OUT_OF_GAME) or 24
local STATE_UNIT_STATUS_HIDDEN = (EModifierState and EModifierState.MODIFIER_STATE_UNIT_STATUS_HIDDEN) or 108
local STATE_NO_INCOMING_DAMAGE = (EModifierState and EModifierState.MODIFIER_STATE_NO_INCOMING_DAMAGE) or 136

local BULLET_RESIST_ENUM = (EModifierValue and EModifierValue.MODIFIER_VALUE_BULLET_ARMOR_DAMAGE_RESIST_PERCENT) or 89

local function get_hero_key(lp)
    local ok_handle, handle = pcall(function() return lp:get_handle() end)
    if ok_handle and type(handle) == "number" then
        return handle
    end

    local ok_index, index = pcall(function() return lp:get_index() end)
    if ok_index and type(index) == "number" then
        return index
    end

    return nil
end

local function name_matches_graves(name)
    if type(name) ~= "string" or name == "" or name == "Unknown" then
        return false
    end

    local lowered = string.lower(name)
    return string.find(lowered, "graves", 1, true) ~= nil
        or string.find(lowered, "necro", 1, true) ~= nil
end

local function get_team_num(ent)
    local ok, team = pcall(function() return ent.m_iTeamNum end)
    if ok and type(team) == "number" then
        return team
    end
    return nil
end

local function read_number_field(raw, field_name)
    local ok, value = pcall(function() return raw[field_name] end)
    if ok and type(value) == "number" then
        return value
    end
    return nil
end

local function get_ability_name(ability)
    if not ability then
        return "Unknown"
    end

    local name = ""
    pcall(function() name = ability:get_class_name() end)
    if not name_matches_graves(name) and (type(name) ~= "string" or name == "" or name == "Unknown") then
        pcall(function() name = ability:get_name() end)
    end
    if not name_matches_graves(name) and (type(name) ~= "string" or name == "" or name == "Unknown") then
        pcall(function() name = ability:get_vdata_class_name() end)
    end

    if type(name) == "string" and name ~= "" then
        return name
    end
    return "Unknown"
end

local function debug_log(message, min_interval)
    if not enable_debug:Get() then
        return
    end

    local now = os.clock()
    min_interval = min_interval or 0.75
    if (now - last_state_log_time) < min_interval then
        return
    end

    last_state_log_time = now
    print("[Graves Debug] " .. message)
end

local function has_any_modifier_state(ent, states)
    for _, state in ipairs(states) do
        local ok, has_state = pcall(function() return ent:has_modifier_state(state) end)
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

local function get_ability_state(ability)
    local status = -1
    local cooldown = math.huge
    local level = 0

    pcall(function() status = ability:can_be_executed() end)
    pcall(function() cooldown = ability:get_cooldown() end)
    pcall(function() level = ability:get_level() end)

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

local function get_ability_by_name_or_slot(lp, ability_name, slot)
    local ability = nil

    if type(ability_name) == "string" and ability_name ~= "" then
        pcall(function() ability = lp:get_ability(ability_name) end)
    end

    if not ability then
        pcall(function() ability = lp:get_ability_by_slot(slot) end)
    end

    return ability
end

local function get_ticks_for_duration(duration)
    if not global_vars or not global_vars.interval_per_tick then
        return nil
    end

    local ok, interval = pcall(function() return global_vars.interval_per_tick() end)
    if not ok or type(interval) ~= "number" or interval <= 0 then
        return nil
    end

    return math.max(1, math.floor((duration / interval) + 0.5))
end

local function check_is_graves()
    local lp = entity_list.local_pawn()
    if not lp or not lp:valid() then
        is_graves = false
        last_hero_key = nil
        return false
    end

    local hero_key = get_hero_key(lp)
    if hero_key ~= last_hero_key then
        is_graves = false
        last_hero_key = hero_key
        last_hero_check_time = 0.0
    end

    if is_graves then
        return true
    end

    local now = os.clock()
    if (now - last_hero_check_time) < HERO_RECHECK_DELAY then
        return false
    end
    last_hero_check_time = now

    local pawn_name = ""
    pcall(function() pawn_name = lp:get_name() end)
    if name_matches_graves(pawn_name) then
        is_graves = true
        return true
    end

    local pawn_vdata = ""
    pcall(function() pawn_vdata = lp:get_vdata_class_name() end)
    if name_matches_graves(pawn_vdata) then
        is_graves = true
        return true
    end

    local abilities = lp:get_abilities()
    if not abilities or #abilities == 0 then
        debug_log("Local pawn abilities are not ready yet; retrying hero detection.", 1.5)
        return false
    end

    for _, ability in pairs(abilities) do
        if name_matches_graves(get_ability_name(ability)) then
            is_graves = true
            return true
        end
    end

    debug_log("Graves markers were not found on the local hero yet; keeping detection alive.", 1.5)
    return false
end

local function GetAbilityRange(ability, fallback_range)
    if not ability then return fallback_range end
    local ok_range, direct_range = pcall(function() return ability:get_cast_range() end)
    if ok_range and type(direct_range) == "number" and direct_range > 0 then
        return direct_range
    end
    local r = nil
    local props_to_check = { "m_flCastRange", "m_flAbilityCastRange", "CastRange", "m_flRange" }
    for _, prop in ipairs(props_to_check) do
        pcall(function()
            local val = ability:get_scaled_property(prop)
            if type(val) == "number" and val > 0 then
                r = val
            end
        end)
        if r then break end
    end
    if r and type(r) == "number" and r > 0 then
        return r
    end
    return fallback_range
end

local function GetEntityHP(ent)
    local ok, hp = pcall(function() return ent.m_iHealth end)
    if ok and type(hp) == "number" then return hp end
    local ok_max, max_hp = pcall(function() return ent:get_max_health() end)
    if ok_max and type(max_hp) == "number" then return max_hp end
    return 0
end

local function GetEntityEHP(ent)
    local hp = GetEntityHP(ent)
    local bullet_resist = read_number_field(ent, "m_flBulletResist")
    if type(bullet_resist) ~= "number" then
        local ok_bullet, modifier_bullet = pcall(function()
            return ent:get_sum_modifier_value(BULLET_RESIST_ENUM, 0)
        end)
        if ok_bullet and type(modifier_bullet) == "number" then
            bullet_resist = modifier_bullet
        end
    end

    local tech_resist = read_number_field(ent, "m_flTechResist")
    if type(tech_resist) ~= "number" and ent.get_tech_resist then
        local ok_tech, native_tech = pcall(function() return ent:get_tech_resist() end)
        if ok_tech and type(native_tech) == "number" then
            tech_resist = native_tech
        end
    end

    bullet_resist = type(bullet_resist) == "number" and bullet_resist or 0
    tech_resist = type(tech_resist) == "number" and tech_resist or 0

    local total_resist = math.max(bullet_resist, tech_resist)
    if total_resist > 1 and total_resist < 100 then
        return hp / (1.0 - (total_resist / 100.0))
    end
    if total_resist > 0 and total_resist < 1 then
        return hp / (1.0 - total_resist)
    end

    return hp
end

local function IsTargetVisible(lp, eye_pos, target)
    if not trace or not trace.bullet then return true end
    local origin = target:get_origin()
    if not Vector then return true end
    
    -- Multi-Hitbox Scan (Feet/Base, Pelvis, Head)
    local offsets = {15, 40, 70}
    for _, z_off in ipairs(offsets) do
        local check_pos = nil
        pcall(function() check_pos = Vector(origin.x, origin.y, origin.z + z_off) end)
        if check_pos then
            local is_vis = false
            pcall(function()
                if trace.bullet(eye_pos, check_pos, 0, lp) then is_vis = true end
            end)
            if is_vis then return true end
        end
    end
    return false
end

local function IsComboDown()
    if not combo_enable:Get() or not combo_key then return false end
    
    -- Check if menu is open - priority safety
    if Menu.Opened and Menu.Opened() then return false end

    local key_code = combo_key:Get()
    
    -- Method 1: Native widget check (usually handles mouse bits correctly)
    local ok, is_down = pcall(function() return combo_key:IsDown() end)
    if ok and is_down then return true end

    -- Method 2: Global input state as fallback
    if type(key_code) == "number" and key_code > 0 then
        if input.is_down(key_code) then return true end
    end
    
    return false
end

local function FindBestTarget(max_fov, max_dist)
    local lp = entity_list.local_pawn()
    if not lp then return nil end
    local my_team = get_team_num(lp)
    if type(my_team) ~= "number" then
        debug_log("Local team number is not available yet; delaying target scan.", 1.5)
        return nil
    end
    local lp_origin = lp:get_origin()
    local eye_pos = lp_origin + Vector(0,0,60)
    local cam_pos = utils.get_camera_pos()
    local v_angles = utils.get_camera_angles()
    
    -- 1. Validate Sticky Lock
    if sticky_target:Get() and locked_target then
        local still_valid = false
        pcall(function()
            if locked_target:valid()
                and locked_target:is_alive()
                and not locked_target:is_dormant()
                and not is_target_untargetable(locked_target)
                and get_team_num(locked_target) ~= my_team then
                local dist = (locked_target:get_origin() - lp_origin):Length()
                local ang = utils.calc_angle(cam_pos, locked_target:get_origin())
                local fov = utils.get_fov(v_angles, ang)
                
                if dist <= max_dist and fov <= max_fov then
                    if IsTargetVisible(lp, eye_pos, locked_target) then
                        still_valid = true
                    end
                end
            end
        end)
        
        if still_valid then
            return locked_target
        else
            locked_target = nil
        end
    end

    -- 2. Acquisition Loop
    local best_ent = nil
    local best_val = 999999.0
    local priority_mode = target_priority:Get()
    local players = entity_list.by_class_name("C_CitadelPlayerPawn")
    
    if players then
        for _, p in pairs(players) do
            if p and p:valid() and p:is_alive() and not p:is_dormant() and p:get_index() ~= lp:get_index() then
                local enemy_team = get_team_num(p)
                local is_enemy = type(enemy_team) == "number" and enemy_team ~= my_team

                if is_enemy and not is_target_untargetable(p) then
                    local p_origin = p:get_origin()
                    local dist = (p_origin - lp_origin):Length()
                    local ang = utils.calc_angle(cam_pos, p_origin)
                    local fov = utils.get_fov(v_angles, ang)

                    if dist <= max_dist and fov <= max_fov then
                        if IsTargetVisible(lp, eye_pos, p) then
                            local val = 999999.0
                            if priority_mode == 0 then -- Distance
                                val = dist
                            elseif priority_mode == 1 then -- Lowest HP
                                val = GetEntityHP(p)
                            elseif priority_mode == 2 then -- FOV
                                val = fov
                            elseif priority_mode == 3 then -- EHP
                                val = GetEntityEHP(p)
                            end
                            
                            if val < best_val then
                                best_val = val; best_ent = p
                            end
                        end
                    end
                end
            end
        end
    end
    
    if best_ent and sticky_target:Get() and IsComboDown() then
        locked_target = best_ent
    end
    
    return best_ent
end

local function PredictPosition(target, duration)
    local pos = target:get_origin()

    local ticks_ahead = get_ticks_for_duration(duration)
    if ticks_ahead and target.simulate_movement then
        local predicted = nil
        local simulated_ticks = 0

        local ok_sim = pcall(function()
            target:simulate_movement(function(mv)
                simulated_ticks = simulated_ticks + 1
                predicted = mv:get_origin()
                return simulated_ticks < ticks_ahead
            end)
        end)

        if ok_sim and predicted then
            return predicted
        end
    end

    if prediction and prediction.predict_player then
        local ok, pred = pcall(function() return prediction.predict_player(target, duration) end)
        if ok and pred and type(pred) == "userdata" and pred.x then
            return pred
        end
    end

    local ok2, vel = pcall(function() return target:get_velocity() end)
    if ok2 and vel and type(vel) == "userdata" and vel.x and Vector then
        local ok3, res = pcall(function() return Vector(pos.x + vel.x * duration, pos.y + vel.y * duration, pos.z + vel.z * duration) end)
        if ok3 and res then return res end
    end
    return pos
end

local function IsPredictVisible(lp, eye_pos, pred_pos)
    local is_visible = true
    if trace and trace.bullet then
        local check_dst = pred_pos
        pcall(function() check_dst = Vector(pred_pos.x, pred_pos.y, pred_pos.z + 40) end)
        if not trace.bullet(eye_pos, check_dst, 0, lp) then
            is_visible = false
        end
    end
    return is_visible
end

local function FindAoETarget(radius, min_enemies, max_fov, max_dist, pred_time)
    pred_time = pred_time or 0.0
    local best_pos = nil
    local best_count = 0
    local best_fov = max_fov
    
    local players = entity_list.by_class_name("C_CitadelPlayerPawn")
    if not players then return nil, 0 end
    
    local lp = entity_list.local_pawn()
    if not lp then return nil, 0 end
    local my_team = get_team_num(lp)
    if type(my_team) ~= "number" then
        return nil, 0
    end

    local valid_enemies = {}
    for _, p in pairs(players) do
        local enemy_team = get_team_num(p)
        local is_enemy = type(enemy_team) == "number" and enemy_team ~= my_team
        
        if p and p:is_alive() and is_enemy and not p:is_dormant() and not is_target_untargetable(p) and p:get_index() ~= lp:get_index() then
            local dst = p:get_origin()
            local eye_pos = lp:get_origin()
            pcall(function() eye_pos = Vector(eye_pos.x, eye_pos.y, eye_pos.z + 60) end)
            local is_visible = IsTargetVisible(lp, eye_pos, p)

            if is_visible and dst:Distance(lp:get_origin()) <= max_dist then
                local pred_pos = dst
                if pred_time > 0 then
                    pred_pos = PredictPosition(p, pred_time)
                end
                
                local eye_pos = lp:get_origin()
                pcall(function() eye_pos = Vector(eye_pos.x, eye_pos.y, eye_pos.z + 60) end)
                if IsPredictVisible(lp, eye_pos, pred_pos) then
                    table.insert(valid_enemies, {ent = p, pos = pred_pos})
                end
            end
        end
    end
    
    for _, center in ipairs(valid_enemies) do
        local current_fov = 360.0
        local cam = utils.get_camera_pos()
        local v_angles = utils.get_camera_angles()
        if v_angles then
            current_fov = utils.get_fov(v_angles, utils.calc_angle(cam, center.pos))
        else
            current_fov = center.pos:Distance(lp:get_origin())
        end
        
        if current_fov < max_fov then
            local hit_count = 0
            local sum_x, sum_y, sum_z = 0, 0, 0
            
            for _, other in ipairs(valid_enemies) do
                if other.pos:Distance(center.pos) <= radius then
                    hit_count = hit_count + 1
                    sum_x = sum_x + other.pos.x
                    sum_y = sum_y + other.pos.y
                    sum_z = sum_z + other.pos.z
                end
            end
            
            if hit_count >= min_enemies then
                if hit_count > best_count then
                    best_count = hit_count
                    best_fov = current_fov
                    if Vector then
                        pcall(function() best_pos = Vector(sum_x / hit_count, sum_y / hit_count, sum_z / hit_count) end)
                    else
                        best_pos = center.pos
                    end
                elseif hit_count == best_count and current_fov < best_fov then
                    best_fov = current_fov
                    if Vector then
                        pcall(function() best_pos = Vector(sum_x / hit_count, sum_y / hit_count, sum_z / hit_count) end)
                    else
                        best_pos = center.pos
                    end
                end
            end
        end
    end
    return best_pos, best_count
end

local debug_font = nil

local function ensure_debug_font()
    if debug_font or not Render or not Render.LoadFont then
        return debug_font
    end

    local font_flags = 0
    if Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS then
        font_flags = Enum.FontCreate.FONTFLAG_ANTIALIAS
    end

    local ok, font = pcall(function() return Render.LoadFont("Verdana", font_flags, 700) end)
    if ok and type(font) == "number" then
        debug_font = font
    end

    return debug_font
end

local function on_draw()
    if Menu.Opened and Menu.Opened() then return end
    if not enable_script:Get() then return end
    if not check_is_graves() then return end
    
    local lp = entity_list.local_pawn()
    if not lp then return end

    -- Draw FOV
    if Render and Render.Circle and combo_fov then
        local screen_size = Render.ScreenSize()
        local center = Vec2(screen_size.x / 2, screen_size.y / 2)
        local fov_val = combo_fov:Get()
        local radius = utils.fov_to_pixel_radius(fov_val)
        Render.Circle(center, radius, Color(255, 255, 255, 50), 1.0)
    end

    -- Draw Target Indicator
    if locked_target and locked_target:valid() and locked_target:is_alive() then
        local origin = locked_target:get_origin()
        local screen_pos, visible = Render.WorldToScreen(origin)
        if visible then
            local font = ensure_debug_font() or 0
            Render.Circle(screen_pos, 40, Color(255, 0, 0, 150), 2.0)
            Render.Text(font, 14, "TARGET", screen_pos + Vec2(0, 45), Color(255, 0, 0, 255))
        end
    end
end

local last_log_time = 0

local function on_createmove(cmd)
    if not enable_script:Get() then return end
    if not check_is_graves() then return end

    local lp = entity_list.local_pawn()
    if not lp or not lp:is_alive() then return end

    local is_combo = IsComboDown()

    if not is_combo then 
        locked_target = nil
        return 
    end

    if (os.clock() - last_cast_times.global) < CAST_DELAY then return end

    local MAX_FOV = combo_fov:Get()
    local target = FindBestTarget(MAX_FOV, 2500)
    if not target or not target:is_alive() then 
        debug_log("Combo key is down, but no valid target was found in range/FOV.", 0.75)
        locked_target = nil
        return 
    end

    local src = lp:get_origin()
    local eye_pos = src
    pcall(function() eye_pos = Vector(eye_pos.x, eye_pos.y, eye_pos.z + 60) end)
    local cam_pos = src
    pcall(function() cam_pos = utils.get_camera_pos() end)

    local casted_this_tick = false
    local debug = enable_debug:Get()

    if debug and (os.clock() - last_log_time) > 0.5 then 
        last_log_time = os.clock()
        local current_abilities = lp:get_abilities()
        if current_abilities then
            for i, ability in pairs(current_abilities) do
                local name = get_ability_name(ability)
                local status, cooldown, level = get_ability_state(ability)
                print(string.format("[Graves Debug] [%d] %s | Status: %d | CD: %.2f | LVL: %d", i, tostring(name), status, cooldown or -1, level or -1))
            end
        end
        print(string.format("[Combo Log] Tick Started | Target: %s", tostring(target:get_model_name()))) 
    end

    -- A2 logic (Zombie Wall)
    local a2 = get_ability_by_name_or_slot(lp, "ability_necro_zombiewall", SLOT_A2)
    
    if a2 and enable_a2:Get() and not casted_this_tick then
        local is_ready = is_ability_ready(a2)
        
        if is_ready and (os.clock() - last_cast_times.a2) > CAST_DELAY then
            local current_range = GetAbilityRange(a2, a2_max_range:Get())
            local target_origin = target:get_origin()
            local dist = target_origin:Distance(src)
            
            if dist <= current_range then
                local time_to_hit = a2_delay:Get() + (dist / a2_speed:Get())
                local cast_pos = PredictPosition(target, time_to_hit)
                
                if IsPredictVisible(lp, eye_pos, cast_pos) then
                    local aim_angle = utils.calc_angle(cam_pos, cast_pos)
                    local fov_to_target = utils.get_fov(cmd.viewangles, aim_angle)
                    
                    if fov_to_target < MAX_FOV then
                        local mode = a2_mode:Get()
                        local casted = false
                        if mode == 0 then
                            if cmd:can_psilent_at_pos(cast_pos) then
                                cmd:set_psilent_at_pos(cast_pos)
                                casted = true
                            end
                        end
                        
                        if not casted then
                            utils.set_camera_angles(aim_angle)
                            cmd.viewangles = aim_angle
                            casted = true
                        end

                        if casted then
                            if debug then print("[Combo Log] Casted A2 (Zombie Wall)") end
                            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY2)
                            last_cast_times.a2 = os.clock()
                            last_cast_times.global = os.clock()
                            casted_this_tick = true
                        end
                    elseif debug then
                        print(string.format("[Combo Log] Skip A2 (Zombie Wall) | Out of FOV (%.1f > %.1f)", fov_to_target, MAX_FOV))
                    end
                elseif debug then
                    print("[Combo Log] Skip A2 (Zombie Wall) | Predicted Position Not Visible")
                end
            elseif debug then
                print(string.format("[Combo Log] Skip A2 (Zombie Wall) | Out of Range (%.1f > %.1f)", dist, current_range))
            end
        elseif debug and is_ready == false then
            local status, cooldown = get_ability_state(a2)
            print(string.format("[Combo Log] Skip A2 (Zombie Wall) | Ability Not Ready (Status: %d | CD: %.2f)", status, cooldown or -1))
        end
    end

    -- A1 logic (Haunting Skull)
    local a1 = get_ability_by_name_or_slot(lp, "ability_necro_hauntingskull", SLOT_A1)

    if a1 and enable_a1:Get() and not (smart_combo_enable:Get() and casted_this_tick) then
        local is_ready = is_ability_ready(a1)
        
        if is_ready and (os.clock() - last_cast_times.a1) > CAST_DELAY then
            local current_range = GetAbilityRange(a1, a1_max_range:Get())
            local target_origin = target:get_origin()
            local dist = target_origin:Distance(src)
            
            if dist <= current_range then
                local time_to_hit = a1_delay:Get() + (dist / a1_speed:Get())
                local cast_pos = PredictPosition(target, time_to_hit)
                
                if IsPredictVisible(lp, eye_pos, cast_pos) then
                    local aim_angle = utils.calc_angle(cam_pos, cast_pos)
                    local fov_to_target = utils.get_fov(cmd.viewangles, aim_angle)
                    
                    if fov_to_target < MAX_FOV then
                        local mode = a1_mode:Get()
                        local casted = false
                        if mode == 0 then
                            if cmd:can_psilent_at_pos(cast_pos) then
                                cmd:set_psilent_at_pos(cast_pos)
                                casted = true
                            end
                        end

                        if not casted then
                            utils.set_camera_angles(aim_angle)
                            cmd.viewangles = aim_angle
                            casted = true
                        end

                        if casted then
                            if debug then print("[Combo Log] Casted A1 (Haunting Skull)") end
                            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY1)
                            last_cast_times.a1 = os.clock()
                            last_cast_times.global = os.clock()
                            casted_this_tick = true
                        end
                    elseif debug then
                        print(string.format("[Combo Log] Skip A1 (Haunting Skull) | Out of FOV (%.1f > %.1f)", fov_to_target, MAX_FOV))
                    end
                elseif debug then
                    print("[Combo Log] Skip A1 (Haunting Skull) | Predicted Position Not Visible")
                end
            elseif debug then
                print(string.format("[Combo Log] Skip A1 (Haunting Skull) | Out of Range (%.1f > %.1f)", dist, current_range))
            end
        elseif debug and is_ready == false then
            local status, cooldown = get_ability_state(a1)
            print(string.format("[Combo Log] Skip A1 (Haunting Skull) | Ability Not Ready (Status: %d | CD: %.2f)", status, cooldown or -1))
        end
    end

    -- A4 logic (Gravestone)
    local a4 = get_ability_by_name_or_slot(lp, "ability_necro_gravestone", SLOT_A4)

    if a4 and enable_a4:Get() and not (smart_combo_enable:Get() and casted_this_tick) then
        local is_ready = is_ability_ready(a4)
        
        if is_ready and (os.clock() - last_cast_times.a4) > CAST_DELAY then
            local current_range = GetAbilityRange(a4, a4_max_range:Get())
            local pred_time = a4_delay:Get()
            local a4_pos, hit_count = FindAoETarget(650.0, a4_min_enemies:Get(), MAX_FOV, current_range, pred_time)
            
            if a4_pos then
                if IsPredictVisible(lp, eye_pos, a4_pos) then
                    local aim_angle = utils.calc_angle(cam_pos, a4_pos)
                    local fov_to_target = utils.get_fov(cmd.viewangles, aim_angle)
                    
                    if fov_to_target < MAX_FOV then
                        local mode = a4_mode:Get()
                        local casted = false
                        if mode == 0 then
                            if cmd:can_psilent_at_pos(a4_pos) then
                                cmd:set_psilent_at_pos(a4_pos)
                                casted = true
                            end
                        end

                        if not casted then
                            utils.set_camera_angles(aim_angle)
                            cmd.viewangles = aim_angle
                            casted = true
                        end

                        if casted then
                            if debug then print("[Combo Log] Casted A4 (Gravestone) | Hits: " .. tostring(hit_count)) end
                            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY4)
                            last_cast_times.a4 = os.clock()
                            last_cast_times.global = os.clock()
                            casted_this_tick = true
                        end
                    end
                end
            elseif debug then
                print(string.format("[Combo Log] Skip A4 (Gravestone) | Conditions Not Met (Min Enemies: %d)", a4_min_enemies:Get()))
            end
        elseif debug and is_ready == false then
            local status, cooldown = get_ability_state(a4)
            print(string.format("[Combo Log] Skip A4 (Gravestone) | Ability Not Ready (Status: %d | CD: %.2f)", status, cooldown or -1))
        end
    end
end

local function on_scripts_loaded()
    is_graves = false
    last_hero_key = nil
    last_hero_check_time = 0.0
    locked_target = nil
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

print("[Graves] Script Initialized using correct Umbrella native API.")
