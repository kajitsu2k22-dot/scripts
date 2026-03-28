-- Graves Script
-- Native Deadlock API aligned with Umbrella definitions

local graves = {}

-- General Elements
local general_menu = Menu.Create("Heroes", "Hero List", "Graves", "Main Settings", "General")
local enable_script = general_menu:Switch("Enable Script", true, "\xef\x81\xad")
local target_priority = general_menu:Combo("Target Priority", {"Distance", "Lowest HP", "Crosshair FOV", "Effective HP (EHP)"}, 2)
local sticky_target = general_menu:Switch("Sticky Target (Lock)", true)
local combo_fov = general_menu:Slider("Combo Max FOV", 10, 360, 90, "%d°")

-- Combo Elements
local combo_menu = Menu.Create("Heroes", "Hero List", "Graves", "Main Settings", "Combo & Skills")
local combo_enable = combo_menu:Switch("Enable Combo", true, "\xef\x81\xad")
local combo_key = combo_menu:Bind("Combo Key", Enum.ButtonCode.KEY_LALT)
local smart_combo_enable = combo_menu:Switch("Smart Sequence (A2 First)", true)

local enable_a1 = combo_menu:Switch("Jar of Dead (1)", true, "\xef\x95\xae")
local a1_gear = enable_a1:Gear("Settings##1")
local a1_mode = a1_gear:Combo("Targeting Strategy", {"pSilent", "Hard Lock"}, 1)
local a1_speed = a1_gear:Slider("Proj. Speed", 500, 5000, 1500, "%d u/s")
local a1_delay = a1_gear:Slider("Cast Delay", 0.0, 1.5, 0.2, "%.1f sec")
local a1_max_range = a1_gear:Slider("Limiter", 500, 3000, 1500, "%.0f radius")

local enable_a2 = combo_menu:Switch("Grasping Hands (2)", true, "\xef\x81\x9b")
local a2_gear = enable_a2:Gear("Settings##2")
local a2_mode = a2_gear:Combo("Targeting Strategy", {"pSilent", "Hard Lock"}, 1)
local a2_speed = a2_gear:Slider("Proj. Speed", 500, 5000, 2000, "%d u/s")
local a2_delay = a2_gear:Slider("Cast Delay", 0.0, 1.5, 0.3, "%.1f sec")
local a2_max_range = a2_gear:Slider("Limiter", 500, 3000, 1500, "%.0f radius")

local enable_a4 = combo_menu:Switch("Borrowed Decree (4)", true, "\xef\x87\xa2")
local a4_gear = enable_a4:Gear("Settings##4")
local a4_mode = a4_gear:Combo("Targeting Strategy", {"pSilent", "Hard Lock"}, 1)
local a4_min_enemies = a4_gear:Slider("Min Splash Enemies", 1, 5, 1, "%d heroes")
local a4_delay = a4_gear:Slider("Cast Delay", 0.0, 5.0, 0.4, "%.1f sec")
local a4_max_range = a4_gear:Slider("Limiter", 500, 3000, 1500, "%.0f radius")

local other_menu = Menu.Create("Heroes", "Hero List", "Graves", "Main Settings", "Other")
local enable_debug = other_menu:Switch("Prediction Debug", true, "\xef\x86\x88")

local last_cast_times = { a1 = 0.0, a2 = 0.0, a3 = 0.0, a4 = 0.0, global = 0.0 }
local CAST_DELAY = 0.05

local is_graves = false
local has_checked_hero = false
local locked_target = nil

local function check_is_graves()
    if has_checked_hero then return is_graves end

    local lp = entity_list.local_pawn()
    if not lp then return false end

    local abilities = lp:get_abilities()
    if not abilities then return false end

    for _, ability in pairs(abilities) do
        local name_str = ""
        pcall(function() name_str = ability:get_class_name() end)
        if name_str == "" or name_str == "Unknown" then
            pcall(function() name_str = ability:get_name() end)
        end
        if type(name_str) == "string" then
            local name = string.lower(name_str)
            if string.find(name, "necro") or string.find(name, "graves") then
                is_graves = true
                break
            end
        end
    end

    has_checked_hero = true
    return is_graves
end

local function GetAbilityRange(ability, fallback_range)
    if not ability then return fallback_range end
    local r = nil
    local props_to_check = { "m_flCastRange", "m_flAbilityCastRange", "CastRange", "m_flRange" }
    for _, prop in ipairs(props_to_check) do
        pcall(function()
            local val = ability:get_property(prop)
            if not val or val <= 0 then
                val = ability:get_scaled_property(prop)
            end
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
    if Entity and Entity.GetHealth then return Entity.GetHealth(ent) end
    if ent.get_health then return ent:get_health() end
    local ok, hp = pcall(function() return ent.m_iHealth end)
    if ok and hp then return hp end
    return 1000
end

local function GetEntityEHP(ent)
    local hp = GetEntityHP(ent)
    local total_resist = 0
    pcall(function() total_resist = total_resist + (ent:get_property("m_flBulletResist") or 0) end)
    pcall(function() total_resist = total_resist + (ent:get_property("m_flTechResist") or 0) end)
    local ehp = hp
    if total_resist > 0 and total_resist < 100 then
        ehp = hp / (1.0 - (total_resist / 100.0))
    end
    return ehp
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
local function FindBestTarget(max_fov, max_dist)
    local lp = entity_list.local_pawn()
    if not lp then return nil end
    local lp_origin = lp:get_origin()
    local eye_pos = lp_origin + Vector(0,0,60)
    local cam_pos = utils.get_camera_pos()
    local v_angles = utils.get_camera_angles()
    
    -- 1. Validate Sticky Lock
    if sticky_target:Get() and locked_target then
        local still_valid = false
        pcall(function()
            if locked_target:valid() and locked_target:is_alive() and not locked_target:is_dormant() then
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
                -- Team check
                local is_enemy = (lp.m_iTeamNum ~= p.m_iTeamNum)
                local is_invul = p:has_modifier_state(24) or p:has_modifier_state(30) or p:has_modifier_state(108)

                if is_enemy and not is_invul then
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
                                val = p.m_iHealth
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
    
    if best_ent and sticky_target:Get() then
        locked_target = best_ent
    end
    
    return best_ent
end

local function PredictPosition(target, duration)
    local pos = target:get_origin()
    local ok, pred = pcall(function() return prediction.predict_player(target, duration) end)
    if ok and pred and type(pred) == "userdata" and pred.x then
        return pred
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

    local valid_enemies = {}
    for _, p in pairs(players) do
        local is_enemy = false
        pcall(function() if lp.m_iTeamNum ~= p.m_iTeamNum then is_enemy = true end end)
        if not is_enemy then pcall(function() if p:is_enemy() then is_enemy = true end end) end

        local is_invulnerable = false
        pcall(function() is_invulnerable = p:has_modifier_state(24) or p:has_modifier_state(30) or p:has_modifier_state(108) end)
        
        if p and p:is_alive() and is_enemy and not p:is_dormant() and not is_invulnerable and p:get_index() ~= lp:get_index() then
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

local function on_draw()
    if not enable_script:Get() then return end
    if not check_is_graves() then return end
    
    local lp = entity_list.local_pawn()
    if not lp then return end

    if enable_debug:Get() then
        if not debug_font and Render and Render.LoadFont then
            debug_font = Render.LoadFont("Verdana", 0, 400)
        end
        
        local font_handle = debug_font or 0

        local my_class = "Unknown"
        pcall(function() my_class = lp:get_vdata_class_name() end)
        if my_class == "Unknown" then
            pcall(function() my_class = lp:get_class_name() end)
        end
        
        local my_id = lp:get_index()
        
        if Render and Render.Text and Vec2 and Color then
            Render.Text(font_handle, 16, "[Graves Debug] Hero Class: " .. tostring(my_class) .. " (ID: " .. tostring(my_id) .. ")", Vec2(10, 300), Color(255, 100, 100, 255))
            
            local abilities = lp:get_abilities()
            local y_offset = 320
            if abilities then
                Render.Text(font_handle, 16, "Abilities:", Vec2(10, y_offset), Color(255, 255, 0, 255))
                y_offset = y_offset + 20
                for i, ability in pairs(abilities) do
                    local name = "Unknown"
                    pcall(function() name = ability:get_class_name() end)
                    if name == "Unknown" then
                        pcall(function() name = ability:get_name() end)
                    end
                    local lvl = 0
                    pcall(function() lvl = ability:get_level() end)
                    local cd = 0
                    pcall(function() cd = ability:get_cooldown() end)
                    
                    Render.Text(font_handle, 14, "["..tostring(i).."] " .. tostring(name) .. " | Lvl: " .. tostring(lvl) .. " | CD: " .. string.format("%.1f", cd), Vec2(20, y_offset), Color(200, 200, 200, 255))
                    y_offset = y_offset + 20
                end
            else
                Render.Text(font_handle, 16, "No abilities array found", Vec2(10, y_offset), Color(255, 0, 0, 255))
            end
        end
    end
end

local function on_createmove(cmd)
    if not enable_script:Get() then return end
    if not check_is_graves() then return end

    local lp = entity_list.local_pawn()
    if not lp or not lp:is_alive() then return end

    local is_combo = false
    if combo_key and combo_enable:Get() then
        local ok, is_down = pcall(function() return combo_key:IsDown() end)
        if ok and is_down then
            is_combo = true
        else
            local ok2, val = pcall(function() return combo_key:Get() end)
            if ok2 and type(val) == "boolean" and val == true then
                is_combo = true
            end
        end
    end

    if not is_combo then 
        locked_target = nil
        return 
    end

    if (os.clock() - last_cast_times.global) < CAST_DELAY then return end

    local MAX_FOV = combo_fov:Get()
    local target = FindBestTarget(MAX_FOV, 2500)
    if not target or not target:is_alive() then return end

    local src = lp:get_origin()
    local eye_pos = src
    pcall(function() eye_pos = Vector(eye_pos.x, eye_pos.y, eye_pos.z + 60) end)
    local cam_pos = src
    pcall(function() cam_pos = utils.get_camera_pos() end)

    local casted_this_tick = false

    -- A2 logic
    local a2 = lp:get_ability_by_slot(1)
    if a2 and enable_a2:Get() and not casted_this_tick then
        local is_ready = false
        pcall(function() if a2:can_be_executed() == 0 then is_ready = true end end)
        
        if is_ready and (os.clock() - last_cast_times.a2) > CAST_DELAY then
            local current_range = GetAbilityRange(a2, a2_max_range:Get())
            local dist = target:get_origin():Distance(src)
            
            if dist <= current_range then
                local time_to_hit = a2_delay:Get() + (dist / a2_speed:Get())
                local cast_pos = PredictPosition(target, time_to_hit)
                
                if IsPredictVisible(lp, eye_pos, cast_pos) then
                    local aim_angle = utils.calc_angle(cam_pos, cast_pos)
                    local current_view = cmd.viewangles
                    
                    if current_view and utils.get_fov(current_view, aim_angle) < MAX_FOV then
                        local mode = a2_mode:Get()
                        local casted = false
                        if mode == 0 then
                            if cmd:can_psilent_at_pos(cast_pos) then
                                cmd:set_psilent_at_pos(cast_pos)
                                casted = true
                            end
                        end
                        
                        -- Fallback to Hard Lock if pSilent fails or Hard Lock is selected
                        if not casted then
                            utils.set_camera_angles(aim_angle)
                            cmd.viewangles = aim_angle
                            casted = true
                        end

                        if casted then
                            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY2)
                            last_cast_times.a2 = os.clock()
                            last_cast_times.global = os.clock()
                            casted_this_tick = true
                        end
                    end
                end
            end
        end
    end

    if smart_combo_enable:Get() and casted_this_tick then return end

    -- A1 logic
    local a1 = lp:get_ability_by_slot(0)
    if a1 and enable_a1:Get() and not casted_this_tick then
        local is_ready = false
        pcall(function() if a1:can_be_executed() == 0 then is_ready = true end end)
        
        if is_ready and (os.clock() - last_cast_times.a1) > CAST_DELAY then
            local current_range = GetAbilityRange(a1, a1_max_range:Get())
            local dist = target:get_origin():Distance(src)
            
            if dist <= current_range then
                local time_to_hit = a1_delay:Get() + (dist / a1_speed:Get())
                local cast_pos = PredictPosition(target, time_to_hit)
                
                if IsPredictVisible(lp, eye_pos, cast_pos) then
                    local aim_angle = utils.calc_angle(cam_pos, cast_pos)
                    local current_view = cmd.viewangles
                    
                    if current_view and utils.get_fov(current_view, aim_angle) < MAX_FOV then
                        local mode = a1_mode:Get()
                        if cast_pos and type(cast_pos.x) == "number" then
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
                                cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY1)
                                last_cast_times.a1 = os.clock()
                                last_cast_times.global = os.clock()
                                casted_this_tick = true
                            end
                        end
                    end
                end
            end
        end
    end

    if smart_combo_enable:Get() and casted_this_tick then return end

    -- A4 logic
    local a4 = lp:get_ability_by_slot(3)
    if a4 and enable_a4:Get() and not casted_this_tick then
        local is_ready = false
        pcall(function() if a4:can_be_executed() == 0 then is_ready = true end end)
        
        if is_ready and (os.clock() - last_cast_times.a4) > CAST_DELAY then
            local current_range = GetAbilityRange(a4, a4_max_range:Get())
            local pred_time = a4_delay:Get()
            local a4_pos, hit_count = FindAoETarget(650.0, a4_min_enemies:Get(), MAX_FOV, current_range, pred_time)
            
            -- Fallback to primary target if clump search yielded no position
            if not a4_pos and target then
                a4_pos = PredictPosition(target, pred_time)
            end

            if a4_pos then
                if IsPredictVisible(lp, eye_pos, a4_pos) then
                    local aim_angle = utils.calc_angle(cam_pos, a4_pos)
                    local current_view = cmd.viewangles
                    
                    if current_view and utils.get_fov(current_view, aim_angle) < MAX_FOV then
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
                            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY4)
                            last_cast_times.a4 = os.clock()
                            last_cast_times.global = os.clock()
                            casted_this_tick = true
                        end
                    end
                end
            end
        end
    end
end

if callback.on_createmove then
    callback.on_createmove:set(on_createmove)
end

if callback.on_draw then
    callback.on_draw:set(on_draw)
end

print("[Graves] Script Initialized using correct Umbrella native API.")
