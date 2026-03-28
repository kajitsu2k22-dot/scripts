-- Paige Script
-- No external libraries, full native Deadlock API aligned with Umbrella definitions

local paige = {}

-- Menu Elements
local main_menu = Menu.Create("Heroes", "Hero List", "Paige", "Main Settings", "General")
local enable_script = main_menu:Switch("Enable Script", true)

-- Combo Settings (Hunt for the core cheat's combo key)
local combo_key = nil
local combo_enable = nil

local paths_to_try = {
    {"Heroes", "Hero List", "Paige", "Combo Key"},
    {"Heroes", "Hero List", "Paige", "Main Settings", "Combo Key"},
    {"Heroes", "Hero List", "Paige", "Combo Settings", "Combo Key"}
}

for _, path in ipairs(paths_to_try) do
    local key = Menu.Find(table.unpack(path))
    if key then 
        combo_key = key
        -- Try to find the matching 'Enable' switch next to it
        local enable_path = {table.unpack(path)}
        enable_path[#enable_path] = "Enable"
        combo_enable = Menu.Find(table.unpack(enable_path))
        break 
    end
end

-- Fallback safely only if absolutely nothing was found (prevents duplicates)
if not combo_key then
    local combo_menu = Menu.Create("Heroes", "Hero List", "Paige", "Main Settings", "Combo Settings")
    combo_enable = combo_menu:Switch("Enable", true)
    combo_key = combo_menu:Bind("Combo Key", Enum.ButtonCode.KEY_NONE)
end

-- A1 - Bookwyrm
local a1_menu = Menu.Create("Heroes", "Hero List", "Paige", "Main Settings", "Bookwyrm (1)")
local enable_a1 = a1_menu:Switch("Use in Combo", true, "\xef\x81\xad") -- fire/dragon
local a1_strict_combo = a1_menu:Switch("Strict Combo (Wait for Stun)", false)
local a1_mode = a1_menu:Combo("Targeting", {"In front of Hero", "Silent Aim", "At Enemy Feet"}, 0)
local a1_max_range = a1_menu:Slider("Max Cast Range", 500, 3000, 1500, "%d")
local a1_speed = a1_menu:Slider("Projectile Speed (For Prediction)", 500, 5000, 1800, "%d")

-- A2 - Plot Armor
local a2_menu = Menu.Create("Heroes", "Hero List", "Paige", "Main Settings", "Plot Armor (2)")
local enable_a2 = a2_menu:Switch("Auto Cast on Low HP", false, "\xef\x83\xbe") -- shield
local a2_hp_threshold = a2_menu:Slider("HP % Threshold (Self/Ally)", 10, 90, 50, "%d%%")

-- A3 - Captivating Read
local a3_menu = Menu.Create("Heroes", "Hero List", "Paige", "Main Settings", "Captivating Read (3)")
local enable_a3 = a3_menu:Switch("Enable in Combo", true, "\xef\x80\xa2") -- book
local a3_mode = a3_menu:Combo("Targeting", {"At Enemy Player", "Silent Aim"}, 0)
local a3_max_range = a3_menu:Slider("Max Range", 500, 3000, 1500, "%d")
local a3_pred_time = a3_menu:Slider("Cast Delay Prediction", 0.0, 1.5, 0.3, "%.1f")

-- A4 - Rallying Charge
local a4_menu = Menu.Create("Heroes", "Hero List", "Paige", "Main Settings", "Rallying Charge (4)")
local enable_a4 = a4_menu:Switch("Enable in Combo", true, "\xef\x83\xa7") -- lightning bolt/charge
local a4_mode = a4_menu:Combo("Targeting", {"At Enemy Player", "Silent Aim"}, 0)
local a4_min_enemies = a4_menu:Slider("Minimum Enemies in Radius", 1, 5, 2, "%d")
local a4_max_range = a4_menu:Slider("Max Range", 500, 3000, 1500, "%d")
local a4_pred_time = a4_menu:Slider("Dash Prediction Time", 0.0, 1.5, 0.2, "%.1f")

local target_priority = main_menu:Combo("Target Priority", {"Distance", "Lowest HP", "Crosshair FOV", "Effective HP (EHP)"}, 2)
local target_lock_enable = main_menu:Switch("Enable Target Lock", false)
local combo_fov = main_menu:Slider("Combo Max FOV", 10, 360, 90, "%d°")
local fov_tolerance = main_menu:Slider("Aim Accuracy (Lower = Precise, Higher = Fast)", 1.0, 15.0, 3.0, "%.1f°")
local enable_debug = main_menu:Switch("Show Debug Logs", false)

local last_cast_times = { a1 = 0.0, a2 = 0.0, a3 = 0.0, a4 = 0.0 }
local CAST_DELAY = 0.3

-- Hero Caching state
local is_paige = false
local has_checked_hero = false

-- Function to check if the current hero is Paige (internally called 'bookworm')
local function check_is_paige()
    if has_checked_hero then return is_paige end

    local lp = entity_list.local_pawn()
    if not lp then return false end

    local abilities = lp:get_abilities()
    if not abilities then return false end

    for _, ability in pairs(abilities) do
        if ability and type(ability.get_name) == "function" then
            local name_str = ability:get_name()
            if name_str then
                local name = string.lower(name_str)
                if string.find(name, "bookworm") or 
                   string.find(name, "dragonfire") or 
                   string.find(name, "knightbarrier") or 
                   string.find(name, "aoemagic") or 
                   string.find(name, "knightcharge") then
                    is_paige = true
                    break
                end
            end
        end
    end

    has_checked_hero = true
    return is_paige
end

local function on_createmove(cmd)
    if not enable_script:Get() then return end
    if not check_is_paige() then return end

    local lp = entity_list.local_pawn()
    if not lp or not lp:is_alive() then return end

    local should_log = (cmd.client_tick % 64 == 0)

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

    local a1 = lp:get_ability_by_slot(0)
    local a2 = lp:get_ability_by_slot(1)
    local a3 = lp:get_ability_by_slot(2)
    local a4 = lp:get_ability_by_slot(3)
    
    local MAX_FOV = combo_fov:Get()

    local function GetEntityHP(ent)
        if Entity and Entity.GetHealth then return Entity.GetHealth(ent) end
        if ent.get_health then return ent:get_health() end
        local ok, hp = pcall(function() return ent.m_iHealth end)
        if ok and hp then return hp end
        return 1000
    end
    
    local function GetEntityEHP(ent)
        -- In Deadlock, calculate basic Spirit/Bullet effective HP
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
    
    local function GetEntityMaxHP(ent)
        if Entity and Entity.GetMaxHealth then return Entity.GetMaxHealth(ent) end
        if ent.get_max_health then return ent:get_max_health() end
        local ok, hp = pcall(function() return ent.m_iMaxHealth end)
        if ok and hp then return hp end
        return 1000
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

    local locked_target_index = nil

    local function FindBestTarget(max_fov, max_dist)
        local priority_mode = target_priority:Get()
        local best_val = 999999.0
        local best_ent = nil
        local players = entity_list.by_class_name("C_CitadelPlayerPawn")
        local src = lp:get_origin()

        -- Target Lock Logic
        local is_lock_enabled = false
        pcall(function() is_lock_enabled = target_lock_enable:Get() end)
        
        if is_lock_enabled and is_combo then
            if not locked_target_index then
                -- Find the closest to crosshair to lock
                local lock_val = 999999.0
                if players then
                    for _, p in pairs(players) do
                        if p and p:is_alive() and not p:is_dormant() then
                            -- Determine if enemy manually
                            local is_enemy = false
                            local m_ok, m_team = pcall(function() return lp.m_iTeamNum end)
                            local t_ok, t_team = pcall(function() return p.m_iTeamNum end)
                            if m_ok and t_ok and m_team and t_team and m_team ~= t_team then
                                is_enemy = true
                            end
                            
                            if is_enemy then
                                local fov = 360.0
                                if cmd.viewangles then fov = utils.get_fov(cmd.viewangles, utils.calc_angle(utils.get_camera_pos(), p:get_origin())) end
                                if fov < lock_val and p:get_origin():Distance(src) <= max_dist then
                                    lock_val = fov
                                    locked_target_index = p:get_index()
                                end
                            end
                        end
                    end
                end
            end
        else
            locked_target_index = nil -- Release lock if setting is off or combo isn't held
        end

        local eye_pos = src
        if Vector then
            local ok, v = pcall(function() return Vector(src.x, src.y, src.z + 60) end)
            if ok and v then eye_pos = v end
        end

        if players then
            for _, p in pairs(players) do
                local is_enemy = false
                local my_team_ok, my_team = pcall(function() return lp.m_iTeamNum end)
                local their_team_ok, their_team = pcall(function() return p.m_iTeamNum end)
                
                if my_team_ok and their_team_ok and my_team and their_team then
                    if my_team ~= their_team then
                        is_enemy = true
                    end
                else
                    -- Fallback if team numbers fail
                    if p and type(p.is_enemy) == "function" then
                        local ok, is_enemy_res = pcall(function() return p:is_enemy() end)
                        if ok and is_enemy_res == true then
                            is_enemy = true
                        end
                    else
                        is_enemy = true -- Safer to default to enemy for targeting logic if unknown
                    end
                end

                local is_invulnerable = false
                pcall(function()
                    is_invulnerable = p:has_modifier_state(24) or p:has_modifier_state(30) or p:has_modifier_state(108)
                end)

                if p and p:is_alive() and is_enemy and not p:is_dormant() and not is_invulnerable and p:get_index() ~= lp:get_index() then
                    local fov_to_p = 360.0
                    if cmd.viewangles then
                        fov_to_p = utils.get_fov(cmd.viewangles, utils.calc_angle(utils.get_camera_pos(), p:get_origin()))
                    end
                    
                    local dist_to_p = p:get_origin():Distance(lp:get_origin())
                    
                    if fov_to_p < max_fov and dist_to_p <= max_dist then
                        local is_visible = true
                        if trace and trace.bullet then
                            local dst_trace = p:get_origin()
                            if Vector then
                                local ok, v = pcall(function() return Vector(dst_trace.x, dst_trace.y, dst_trace.z + 50) end)
                                if ok and v then dst_trace = v end
                            end
                            if not trace.bullet(eye_pos, dst_trace, 0, lp) then
                                is_visible = false
                            end
                        end
                        
                        if is_visible then
                            if locked_target_index and p:get_index() == locked_target_index then
                                return p -- Instantly return the locked target ignoring priority
                            end

                            local val = 999999.0
                            if priority_mode == 0 then -- Distance
                                val = dist_to_p
                            elseif priority_mode == 1 then -- Lowest HP
                                val = GetEntityHP(p)
                            elseif priority_mode == 2 then -- FOV
                                val = fov_to_p
                            elseif priority_mode == 3 then -- EHP
                                val = GetEntityEHP(p)
                            end
                            
                            if not locked_target_index and val < best_val then
                                best_val = val
                                best_ent = p
                            end
                        end
                    end
                end
            end
        end
        return best_ent
    end

    local function PredictPosition(target, duration)
        local pos = target:get_origin()
        local ok, pred = pcall(function() return prediction.predict_player(target, duration) end)
        if ok and pred and type(pred) == "userdata" and pred.x then
            return pred
        end
        -- Fallback to velocity
        local ok2, vel = pcall(function() return target:get_velocity() end)
        if ok2 and vel and type(vel) == "userdata" and vel.x and Vector then
            local ok3, res = pcall(function() return Vector(pos.x + vel.x * duration, pos.y + vel.y * duration, pos.z + vel.z * duration) end)
            if ok3 and res then return res end
        end
        return pos
    end

    local target = FindBestTarget(MAX_FOV, 10000) -- Fallback if needed for debug logs
    if target and target:is_alive() then
        if enable_debug:Get() and should_log then
            local t_name = "Unknown"
            pcall(function() t_name = target:get_vdata_class_name() end)
            print("[Paige Debug] Target Found: " .. t_name .. " at FOV " .. tostring(utils.get_fov(cmd.viewangles, utils.calc_angle(utils.get_camera_pos(), target:get_origin()))))
        end
    end

    if is_combo and a1 and enable_a1:Get() then
        -- can_be_executed() returns weird enums in Deadlock (7, 23, etc)
        -- The safest way to check if ready is verifying cooldown is 0 and level > 0
        local is_ready = false
        pcall(function()
            local cd = a1:get_cooldown()
            local lvl = a1:get_level()
            if cd == 0 and lvl > 0 then
                is_ready = true
            end
        end)
        
        if is_ready and (os.clock() - last_cast_times.a1) > CAST_DELAY then
            local current_range = GetAbilityRange(a1, a1_max_range:Get())
            local a1_target = FindBestTarget(MAX_FOV, current_range)
            if a1_target and a1_target:is_alive() then
                -- Smart Sequencing Logic
                local is_stunned = false
                pcall(function() 
                    is_stunned = a1_target:has_modifier_state(18) or a1_target:has_modifier_state(30)
                end) -- 18 = STUNNED, 30 = IMMOBILIZED
                
                local can_cast_a1 = true
                if a1_strict_combo:Get() then
                    local a3_ready = false
                    local a3_recently_cast = false
                    if a3 and enable_a3:Get() then
                        pcall(function()
                            if a3:get_cooldown() == 0 and a3:get_level() > 0 then
                                a3_ready = true
                            end
                        end)
                        if last_cast_times.a3 and (os.clock() - last_cast_times.a3) < 2.0 then
                            a3_recently_cast = true
                        end
                    end
                    -- Hold A1 if A3 is ready or was recently cast (waiting for projectile to hit)
                    if (a3_ready or a3_recently_cast) and not is_stunned then
                        can_cast_a1 = false
                    end
                end
                
                if can_cast_a1 then
                local target_angle = utils.calc_angle(utils.get_camera_pos(), a1_target:get_origin())
                local current_view = cmd.viewangles
                
                -- Check if the actual enemy is in our FOV first
                if current_view and utils.get_fov(current_view, target_angle) < MAX_FOV then
                    local mode = a1_mode:Get()
                    
                    local src = lp:get_origin()
                    local dist = a1_target:get_origin():Distance(src)
                    local time_to_hit = dist / a1_speed:Get()
                    local dst = PredictPosition(a1_target, time_to_hit)
                    
                    local cast_pos = src
                    if mode == 0 or mode == 1 then -- In front of Hero or Silent Aim
                        -- Flatten Z so we don't cast into the ground if target is falling or moving vertically
                        local dirX = dst.x - src.x
                        local dirY = dst.y - src.y
                        local len = math.sqrt(dirX*dirX + dirY*dirY)
                        if len and len > 0.001 then
                            dirX = dirX / len
                            dirY = dirY / len
                        else
                            dirX = 1
                            dirY = 0
                        end
                        -- Cast 150 units forward, 60 units up (chest height) to avoid getting stuck
                        if Vector then
                            local ok, v = pcall(function() return Vector(src.x + dirX * 150, src.y + dirY * 150, src.z + 60) end)
                            if ok and v then cast_pos = v end
                        end
                    elseif mode == 2 then -- At Enemy Feet
                        cast_pos = dst
                    end
                    
                    local aim_angle = utils.calc_angle(utils.get_camera_pos(), cast_pos)
                    
                    -- Sanity check cast_pos for NaN before passing to engine
                    if cast_pos and type(cast_pos.x) == "number" and cast_pos.x == cast_pos.x then
                        if mode == 1 then
                            if cmd:can_psilent_at_pos(cast_pos) then
                                cmd:set_psilent_at_pos(cast_pos)
                                cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY1)
                                last_cast_times.a1 = os.clock()
                                if enable_debug:Get() then print("[Paige Debug] A1 Psilent Fired") end
                            end
                        else
                            cmd:smooth_aim(aim_angle, 0.5)
                            local fov_to_cast = utils.get_fov(cmd.viewangles, aim_angle)
                            if fov_to_cast <= fov_tolerance:Get() then
                                cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY1)
                                last_cast_times.a1 = os.clock()
                                if enable_debug:Get() then print("[Paige Debug] A1 Smooth Fired") end
                            end
                        end
                    end
                end
                end
            end
        end
    end

    if a2 and enable_a2:Get() then
        local is_ready = false
        pcall(function()
            local cd = a2:get_cooldown()
            local lvl = a2:get_level()
            if cd == 0 and lvl > 0 then
                is_ready = true
            end
        end)

        if is_ready then
            local threshold = a2_hp_threshold:Get()
            
            local max_hp = GetEntityMaxHP(lp)
            local cur_hp = GetEntityHP(lp)
            local cast_on_self = false
            
            if enable_debug:Get() and should_log then
                print("[Paige Debug] A2 Check Self: HP=" .. tostring(cur_hp) .. ", MaxHP=" .. tostring(max_hp) .. ", Threshold=" .. tostring(threshold))
            end
            
            if max_hp and cur_hp and max_hp > 0 then
                local hp_pct = (cur_hp / max_hp) * 100
                if enable_debug:Get() and should_log then
                    print("[Paige Debug] A2 Self PCT: " .. tostring(hp_pct) .. "%")
                end
                if hp_pct <= threshold then
                    cast_on_self = true
                end
            end
            
            if cast_on_self then
                if (os.clock() - last_cast_times.a2) > CAST_DELAY then
                    cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY2)
                    last_cast_times.a2 = os.clock()
                    if enable_debug:Get() then print("[Paige Debug] A2 Cast on Self triggered by HP PCT") end
                end
            else
                -- Check allies in crosshair or nearby strictly via API
                local players = entity_list.by_class_name("C_CitadelPlayerPawn")
                if players then
                    for _, p in pairs(players) do
                        local is_ally = false
                        
                        -- Try checking if their team == our team
                        local my_team_ok, my_team = pcall(function() return lp.m_iTeamNum end)
                        local their_team_ok, their_team = pcall(function() return p.m_iTeamNum end)
                        
                        if my_team_ok and their_team_ok and my_team and their_team then
                            if my_team == their_team then
                                is_ally = true
                            end
                        end
                        
                        -- Fallback to is_enemy if property read failed somehow
                        if not is_ally and p and type(p.is_enemy) == "function" then
                            local ok, is_enemy_res = pcall(function() return p:is_enemy() end)
                            if ok and is_enemy_res == false then
                                is_ally = true
                            end
                        end
                        
                        if p and p:is_alive() and is_ally and p:get_index() ~= lp:get_index() then
                            local a_max = GetEntityMaxHP(p)
                            local a_cur = GetEntityHP(p)
                            if a_max and a_cur and a_max > 0 then
                                local a_pct = (a_cur / a_max) * 100
                                if a_pct <= threshold then
                                    local p_pos = p:get_origin()
                                    local my_pos = lp:get_origin()
                                    if p_pos:Distance(my_pos) < 2500 then
                                        local ally_angle = utils.calc_angle(utils.get_camera_pos(), p_pos)
                                        local current_view = cmd.viewangles
                                        
                                        if current_view and utils.get_fov(current_view, ally_angle) < MAX_FOV then
                                            cmd:smooth_aim(ally_angle, 0.5)
                                            
                                            if utils.get_fov(cmd.viewangles, ally_angle) < 2.0 then
                                                if (os.clock() - last_cast_times.a2) > CAST_DELAY then
                                                    cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY2)
                                                    last_cast_times.a2 = os.clock()
                                                    if enable_debug:Get() then print("[Paige Debug] A2 Cast on Ally " .. p:get_vdata_class_name()) end
                                                end
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local function FindAoETarget(radius, min_enemies, max_fov, max_dist, pred_time)
        pred_time = pred_time or 0.0
        local best_pos = nil
        local best_count = 0
        local best_fov = max_fov
        
        local players = entity_list.by_class_name("C_CitadelPlayerPawn")
        if not players then return nil, 0 end
        
        -- Filter valid enemies and get their predicted positions
        local valid_enemies = {}
        for _, p in pairs(players) do
            local is_enemy = false
            local my_team_ok, my_team = pcall(function() return lp.m_iTeamNum end)
            local their_team_ok, their_team = pcall(function() return p.m_iTeamNum end)
            
            local is_invulnerable = false
            pcall(function()
                is_invulnerable = p:has_modifier_state(24) or p:has_modifier_state(30) or p:has_modifier_state(108)
            end)

            if my_team_ok and their_team_ok and my_team and their_team then
                if my_team ~= their_team then is_enemy = true end
            else
                is_enemy = true
            end
            
            if p and p:is_alive() and is_enemy and not p:is_dormant() and not is_invulnerable and p:get_index() ~= lp:get_index() then
                local dst = p:get_origin()
                
                -- Visibility Check (RayTrace)
                local is_visible = true
                if trace and trace.bullet then
                    local src = lp:get_origin()
                    local eye_pos = src
                    if Vector then
                        local ok, v = pcall(function() return Vector(src.x, src.y, src.z + 60) end)
                        if ok and v then eye_pos = v end
                    end
                    local dst_trace = dst
                    if Vector then
                        local ok, v = pcall(function() return Vector(dst_trace.x, dst_trace.y, dst_trace.z + 50) end)
                        if ok and v then dst_trace = v end
                    end
                    if not trace.bullet(eye_pos, dst_trace, 0, lp) then
                        is_visible = false
                    end
                end

                if is_visible and dst:Distance(lp:get_origin()) <= max_dist then
                    local pred_pos = dst
                    if pred_time > 0 then
                        pred_pos = PredictPosition(p, pred_time)
                    end
                    table.insert(valid_enemies, {ent = p, pos = pred_pos})
                end
            end
        end
        
        -- Cluster computing
        for _, center in ipairs(valid_enemies) do
            local current_fov = 360.0
            if cmd.viewangles then
                current_fov = utils.get_fov(cmd.viewangles, utils.calc_angle(utils.get_camera_pos(), center.pos))
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

    -- A3 Logic (AoE Magic): Captivating Read
    if is_combo and a3 and enable_a3:Get() then
        local is_ready = false
        pcall(function()
            local cd = a3:get_cooldown()
            local lvl = a3:get_level()
            if cd == 0 and lvl > 0 then
                is_ready = true
            end
        end)

        if is_ready and (os.clock() - last_cast_times.a3) > CAST_DELAY then
            local current_range = GetAbilityRange(a3, a3_max_range:Get())
            local pred_time = a3_pred_time:Get()
            local a3_pos, hit_count = FindAoETarget(600.0, 1, MAX_FOV, current_range, pred_time)
            
            if a3_pos then
                local aim_angle = utils.calc_angle(utils.get_camera_pos(), a3_pos)
                local current_view = cmd.viewangles
                local mode = a3_mode:Get()
                
                if current_view and utils.get_fov(current_view, aim_angle) < MAX_FOV then
                    if mode == 1 then -- Silent Aim
                        if cmd:can_psilent_at_pos(a3_pos) then
                            cmd:set_psilent_at_pos(a3_pos)
                            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY3)
                            last_cast_times.a3 = os.clock()
                            if enable_debug:Get() then print("[Paige Debug] A3 Psilent Fired (AoE hits: " .. hit_count .. ")") end
                        end
                    else
                        cmd:smooth_aim(aim_angle, 0.5)
                        
                        if cmd.viewangles then
                            if utils.get_fov(cmd.viewangles, aim_angle) <= fov_tolerance:Get() then
                                cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY3)
                                last_cast_times.a3 = os.clock()
                                if enable_debug:Get() then print("[Paige Debug] A3 Smooth Fired (AoE hits: " .. hit_count .. ")") end
                            end
                        else
                            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY3)
                            last_cast_times.a3 = os.clock()
                            if enable_debug:Get() then print("[Paige Debug] A3 Fallback Fired (AoE hits: " .. hit_count .. ")") end
                        end
                    end
                end
            end
        end
    end



    -- A4 Logic (Knight Charge): Rallying Charge
    if is_combo and a4 and enable_a4:Get() then
        local is_ready = false
        pcall(function()
            local cd = a4:get_cooldown()
            local lvl = a4:get_level()
            if cd == 0 and lvl > 0 then
                is_ready = true
            end
        end)

        if is_ready and (os.clock() - last_cast_times.a4) > CAST_DELAY then
            local min_hits = a4_min_enemies:Get()
            local current_range = GetAbilityRange(a4, a4_max_range:Get())
            local pred_time = a4_pred_time:Get()
            local a4_pos, hit_count = FindAoETarget(800.0, min_hits, MAX_FOV, current_range, pred_time)
            
            if a4_pos then
                
                local aim_angle = utils.calc_angle(utils.get_camera_pos(), a4_pos)
                local current_view = cmd.viewangles
                local mode = a4_mode:Get()
                
                if current_view and utils.get_fov(current_view, aim_angle) < MAX_FOV then
                    if mode == 1 then -- Silent Aim
                        if cmd:can_psilent_at_pos(a4_pos) then
                            cmd:set_psilent_at_pos(a4_pos)
                            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY4)
                            last_cast_times.a4 = os.clock()
                            if enable_debug:Get() then print("[Paige Debug] A4 Psilent Fired (AoE hits: " .. hit_count .. ")") end
                        end
                    else
                        cmd:smooth_aim(aim_angle, 0.5)
                        
                        if cmd.viewangles then
                            if utils.get_fov(cmd.viewangles, aim_angle) <= fov_tolerance:Get() then
                                cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY4)
                                last_cast_times.a4 = os.clock()
                                if enable_debug:Get() then print("[Paige Debug] A4 Smooth Fired (AoE hits: " .. hit_count .. ")") end
                            end
                        else
                            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY4)
                            last_cast_times.a4 = os.clock()
                            if enable_debug:Get() then print("[Paige Debug] A4 Fallback Fired (AoE hits: " .. hit_count .. ")") end
                        end
                    end
                end
            end
        end
    end
end

local function on_draw()
    if not enable_script:Get() then return end
    if not check_is_paige() then return end

    local lp = entity_list.local_pawn()
    if not lp or not lp:is_alive() then return end

end

-- Register Callbacks
if callback.on_createmove then
    callback.on_createmove:set(on_createmove)
end

if callback.on_draw then
    callback.on_draw:set(on_draw)
end

print("[Paige] Script Initialized using correct Umbrella native API.")
