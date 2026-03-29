---@diagnostic disable: undefined-global
-- ==========================================
-- Werewolf Alpha Combat Script v2.0
-- Combo Chain + Kill Threshold
-- ==========================================

local VERSION      = "2.1.0"
local UNIT_METER   = 37.7358490566

-- ==========================================
-- Menu
-- ==========================================
local menu_gen     = Menu.Create("Heroes", "Hero List", "Silver", "Werewolf", "⚙ General")
local ui_enable    = menu_gen:Switch("Enable Script", true)
local ui_combo_key = menu_gen:Bind("Combo Key", Enum.ButtonCode.KEY_LALT)
local ui_visuals   = menu_gen:Switch("Show Visuals (FOV/Target)", true)
local ui_range     = menu_gen:Slider("Max Target Range (m)", 100, 1500, 800)
local ui_debug     = menu_gen:Switch("Debug Mode", false)

local menu_cbt     = Menu.Create("Heroes", "Hero List", "Silver", "Werewolf", "⚔ Combat")
local ui_chase     = menu_cbt:Switch("Auto Chase & Sprint (Wolf)", true)

local menu_hum     = Menu.Create("Heroes", "Hero List", "Silver", "Werewolf", "👤 Human Combo")
local ui_h_net     = menu_hum:Switch("S1: Net Shot (CC)", true)
local ui_h_unload  = menu_hum:Switch("S2: Unload Gun (DPS)", true)
local ui_h_kick    = menu_hum:Switch("S3: Kickflip (Finisher)", true)
local ui_kick_hp   = menu_hum:Slider("Kickflip HP% Threshold", 5, 100, 35)

local menu_wlf     = Menu.Create("Heroes", "Hero List", "Silver", "Werewolf", "🐺 Wolf Combo")
local ui_w_leap    = menu_wlf:Switch("S1: Mauling Leap (Gap)", true)
local ui_w_slash   = menu_wlf:Switch("S2: Crippling Slash (Disarm)", true)
local ui_w_frenzy  = menu_wlf:Switch("S3: Frenzy (Lifesteal)", true)
local ui_smart_fr  = menu_wlf:Switch("Smart Frenzy (melee only)", true)

local menu_ult     = Menu.Create("Heroes", "Hero List", "Silver", "Werewolf", "🔄 Transform")
local ui_auto_ult  = menu_ult:Switch("Auto Ultimate", true)
local ui_ult_hp    = menu_ult:Slider("Ult at HP %", 5, 50, 25)
local ui_ult_range = menu_ult:Slider("Ult Threat Range (m)", 0, 50, 15)

local menu_tgt     = Menu.Create("Heroes", "Hero List", "Silver", "Werewolf", "🎯 Targeting")
local ui_lock      = menu_tgt:Switch("Target Lock", true)
local ui_lock_mode = menu_tgt:Combo("Lock Mode", { "Range + Alive", "Until Key Re-press" }, 0)
local ui_priority  = menu_tgt:Combo("Target Priority", { "Closest to Crosshair (FOV)", "Lowest HP%", "Nearest Distance" }, 0)
local ui_execute   = menu_tgt:Switch("Kill Threshold", true)
local ui_resist    = menu_tgt:Switch("Account Tech Resist", true)
local ui_fov       = menu_tgt:Slider("Engagement FOV Limit", 1, 90, 15)
local ui_ovr_fov   = menu_tgt:Slider("Manual Override Gap", 10, 90, 35) -- If manual aim differs by this much, stop locking

local menu_ret     = Menu.Create("Heroes", "Hero List", "Silver", "Werewolf", "🏃 Retreat")
local ui_retreat   = menu_ret:Switch("Auto Retreat", true)
local ui_ret_hp    = menu_ret:Slider("Retreat HP %", 5, 40, 15)
local ui_ret_cnt   = menu_ret:Slider("Min Nearby Enemies", 1, 5, 2)
local ui_ret_range = menu_ret:Slider("Check Range (m)", 5, 30, 15)

-- ==========================================
-- Constants & State
-- ==========================================
local SLOTS        = {
    [EAbilitySlots_t.ESlot_Signature_1] = InputBitMask_t.IN_ABILITY1,
    [EAbilitySlots_t.ESlot_Signature_2] = InputBitMask_t.IN_ABILITY2,
    [EAbilitySlots_t.ESlot_Signature_3] = InputBitMask_t.IN_ABILITY3,
    [EAbilitySlots_t.ESlot_Signature_4] = InputBitMask_t.IN_ABILITY4,
}

local last_cast    = {}
local combo        = { form = nil, done = { false, false, false }, t = 0, active = false }
local locked       = { ent = nil, hp = 0 }
local retreating   = false
local key_prev     = false
local killable     = false
local font         = Render.LoadFont("Tahoma", Enum.FontCreate.FONTFLAG_ANTIALIAS, 800)

-- ==========================================
-- Helpers
-- ==========================================
local function find_ab(pawn, ss)
    for slot, bit in pairs(SLOTS) do
        local a = pawn:get_ability_by_slot(slot)
        if a and a:valid() then
            local n = a:get_name()
            if n and string.find(n, ss) then return a, bit end
        end
    end
    return nil, nil
end

local function is_werewolf(lp)
    for s, _ in pairs(SLOTS) do
        local a = lp:get_ability_by_slot(s)
        if a and a:valid() then
            local n = a:get_name()
            if n and string.find(n, "werewolf") then return true end
        end
    end
    return false
end

local function ok(a, id, t)
    if not a or not a:valid() then return false end
    if (t - (last_cast[id] or 0)) < 0.5 then return false end
    return a:can_be_executed() == 0
end

local function aim_cast(cmd, pos, bit, id, t, lp, target)
    if not pos or not bit then return "failed" end

    local cp = utils.get_camera_pos()
    local aim_angl = utils.calc_angle(cp, pos)
    local cur_angl = utils.get_camera_angles()
    local fov_to_target = utils.get_fov(cur_angl, aim_angl)

    -- Engagement Limit: Do not aim or shoot if target is outside allowed FOV
    if fov_to_target > ui_fov:Get() then
        return "failed"
    end

    -- Manual Override Safeguard: If user is pulling away fast (e.g. looking down for movement)
    -- Compare cmd viewangles (intent) with target angles
    local intent_fov = utils.get_fov(cmd.viewangles, aim_angl)
    if intent_fov > ui_ovr_fov:Get() then
        return "failed"
    end

    -- Visibility check (optimized)
    if lp and target then
        local my_pos = cp
        if not trace.bullet(my_pos, pos, 5, target) then return "failed" end
    end

    -- Hard Lock: Instant physical snap
    utils.set_camera_angles(aim_angl)
    cmd.viewangles = aim_angl

    cmd:add_buttonstate1(bit)
    last_cast[id] = t
    return "casted"
end

local function self_cast(cmd, bit, id, t)
    cmd:add_buttonstate1(bit)
    last_cast[id] = t
end

local function lead(pos, vel, dist, spd)
    return pos + (vel * (dist / spd))
end

local function dbg(msg)
    if ui_debug:Get() then
        Notification({ duration = 2.0, primary_text = msg })
        print("[Werewolf] " .. msg)
    end
end

local function is_wolf(lp)
    local a = find_ab(lp, "maulingleap")
    return a ~= nil
end

-- ==========================================
-- Targeting
-- ==========================================
local function find_best(lp, rm)
    local prio = ui_priority:Get() -- 0: FOV, 1: HP, 2: Dist
    local best, score = nil, 999999
    local mp, mt = lp:get_origin(), lp.m_iTeamNum
    local cur_ang = utils.get_camera_angles()
    local cp = utils.get_camera_pos()

    for _, e in ipairs(entity_list.by_class_name("C_CitadelPlayerPawn")) do
        if e and e:valid() and e:is_alive() and not e:is_dormant() and e.m_iTeamNum ~= mt then
            local ep = e:get_origin() + Vector(0, 0, 45)
            local d = (ep - mp):Length() / UNIT_METER
            
            if d <= rm then
                local fov = utils.get_fov(cur_ang, utils.calc_angle(cp, ep))
                if fov <= ui_fov:Get() or prio == 2 then -- Only consider targets within engagement FOV (unless distance priority)
                    -- Check visibility
                    if trace.bullet(cp, ep, 5, e) then
                        local current_score = 0
                        if prio == 0 then -- FOV
                            current_score = fov
                        elseif prio == 1 then -- HP
                            current_score = (e.m_iHealth / e:get_max_health()) * 100
                        else -- Distance
                            current_score = d
                        end

                        if current_score < score then
                            best = e
                            score = current_score
                        end
                    end
                end
            end
        end
    end
    return best
end

local function count_near(lp, rm)
    local c, mp, mt = 0, lp:get_origin(), lp.m_iTeamNum
    for _, e in ipairs(entity_list.by_class_name("C_CitadelPlayerPawn")) do
        if e and e:valid() and e:is_alive() and not e:is_dormant() and e.m_iTeamNum ~= mt then
            if (e:get_origin() - mp):Length() / UNIT_METER <= rm then c = c + 1 end
        end
    end
    return c
end

local function get_target(lp)
    local rm = ui_range:Get()
    if ui_lock:Get() and locked.ent and locked.ent:valid() and locked.ent:is_alive() and not locked.ent:is_dormant() then
        if ui_lock_mode:Get() == 1 then return locked.ent end
        if (locked.ent:get_origin() - lp:get_origin()):Length() / UNIT_METER <= rm then return locked.ent end
    end
    local n = find_best(lp, rm)
    if n then
        locked.ent = n; locked.hp = n.m_iHealth
    end
    return n
end

-- ==========================================
-- Anti-Kite
-- ==========================================
local function fleeing(target, mp)
    local v = target:get_velocity()
    if not v then return false end
    local s = v:Length()
    if s < 50 then return false end
    local d = mp - target:get_origin(); d.z = 0
    local l = d:Length()
    if l < 1 then return false end
    return (v.x * d.x + v.y * d.y) / (s * l) < -0.35
end

-- ==========================================
-- Kill Threshold
-- ==========================================
local function calc_burst(lp, target)
    local total = 0
    for _, ss in ipairs({ "net", "leap", "slash", "kick", "unload" }) do
        local a = find_ab(lp, ss)
        if a and a:valid() and a:can_be_executed() == 0 then
            local d = a:get_scaled_property("AbilityDamage") or a:get_scaled_property("Damage") or 0
            if d > 0 then total = total + d end
        end
    end
    if ui_resist:Get() and target then
        local r = target:get_tech_resist()
        if r and r > 0 then total = total * (1 - r / 100) end
    end
    return total
end

-- ==========================================
-- Retreat
-- ==========================================
local function try_retreat(cmd, lp, t)
    if not ui_retreat:Get() then
        retreating = false; return false
    end
    local hp_pct = (lp.m_iHealth / lp:get_max_health()) * 100
    if hp_pct > ui_ret_hp:Get() then
        retreating = false; return false
    end
    local ua = find_ab(lp, "transformation")
    if ua and ua:valid() and ua:can_be_executed() == 0 then
        retreating = false; return false
    end
    if count_near(lp, ui_ret_range:Get()) < ui_ret_cnt:Get() then
        retreating = false; return false
    end

    retreating = true
    local ne = utils.find_nearest_visible_enemy()
    if not ne or not ne:valid() then return true end

    local mp = lp:get_origin()
    local fd = mp - ne:get_origin(); fd.z = 0
    local fl = fd:Length()
    if fl > 0 then fd = fd * (1 / fl) end
    local fp = mp + fd * 500

    local la, lb = find_ab(lp, "leap")
    if la and lb and ok(la, "ret_leap", t) then
        local res = aim_cast(cmd, fp, lb, "ret_leap", t, lp, nil)
        if res == "casted" then
            dbg("RETREAT: Leap!")
            return true
        elseif res == "aiming" then
            return true
        end
    end

    cmd.forwardmove = 1.0
    cmd:add_buttonstate1(InputBitMask_t.IN_SPEED)
    cmd:smooth_aim(utils.calc_angle(utils.get_camera_pos(), fp), 0.5)
    return true
end

-- ==========================================
-- Combo Chains
-- ==========================================
local function reset_combo()
    combo.form = nil
    combo.done = { false, false, false }
    combo.t = 0
    combo.active = false
end

local function human_combo(cmd, lp, target, tp, dist, vel, t)
    local na, nb = find_ab(lp, "net")
    local ua, ub = find_ab(lp, "unload")
    local ka, kb = find_ab(lp, "kick")

    if not combo.done[1] and ui_h_net:Get() and na and nb and ok(na, "net", t) then
        local r = na:get_cast_range(); if not r or r <= 0 then r = 1500 end
        if dist <= r then
            local res = aim_cast(cmd, lead(tp, vel, dist, 2500), nb, "net", t, lp, target)
            if res == "casted" then
                combo.done[1] = true; combo.t = t; dbg("H1: Net Shot"); return true
            elseif res == "aiming" then
                return true
            end
        end
    end

    if not combo.done[2] and ui_h_unload:Get() and ua and ub and ok(ua, "unload", t) then
        if dist <= 25 * UNIT_METER then
            self_cast(cmd, ub, "unload", t)
            combo.done[2] = true; combo.t = t; dbg("H2: Unload"); return true
        end
    end

    -- If we are currently Unloading, maybe wait for a bit or allow manual aim
    -- Fenris Unload (human_2) usually lasts a few seconds.
    local has_unload = lp:get_modifier("modifier_werewolf_human_unload")
    if has_unload then 
        -- While Unloading, we might want to prioritize manual control or only Net if target moves away
        -- For now, let's just make sure we don't snap to Kickflip immediately if the user is trying to aim
        if not combo.done[1] then -- Try to Net if we haven't
             -- ... (Net logic is above)
        end
        return false 
    end

    if not combo.done[3] and ui_h_kick:Get() and ka and kb and ok(ka, "kick", t) then
        local hp_pct = (target.m_iHealth / target:get_max_health()) * 100
        if hp_pct <= ui_kick_hp:Get() or killable then
            local r = ka:get_cast_range(); if not r or r <= 0 then r = 417.3 end
            if dist <= r then
                local res = aim_cast(cmd, lead(tp, vel, dist, 2000), kb, "kick", t, lp, target)
                if res == "casted" then
                    combo.done[3] = true; combo.t = t; dbg("H3: Kickflip!"); return true
                elseif res == "aiming" then
                    return true
                end
            end
        end
    end
    return false
end

local function wolf_combo(cmd, lp, target, tp, dist, vel, t)
    local la, lb = find_ab(lp, "leap")
    local sa, sb = find_ab(lp, "slash")
    local fa, fb = find_ab(lp, "frenzy")
    local mp = lp:get_origin()
    local flee = fleeing(target, mp)

    -- Anti-kite: force leap
    if flee and not combo.done[1] and la and lb and ok(la, "leap", t) then
        local r = la:get_cast_range(); if not r or r <= 0 then r = 712.6 end
        if dist <= r then
            local res = aim_cast(cmd, lead(tp, vel, dist, 1600), lb, "leap", t, lp, target)
            if res == "casted" then
                combo.done[1] = true; combo.t = t; dbg("ANTI-KITE: Leap!"); return true
            elseif res == "aiming" then
                return true
            end
        end
    end

    if not combo.done[1] and ui_w_leap:Get() and la and lb and ok(la, "leap", t) then
        local r = la:get_cast_range(); if not r or r <= 0 then r = 712.6 end
        if dist <= r and dist > 4 * UNIT_METER then
            local res = aim_cast(cmd, lead(tp, vel, dist, 1600), lb, "leap", t, lp, target)
            if res == "casted" then
                combo.done[1] = true; combo.t = t; dbg("W1: Leap"); return true
            elseif res == "aiming" then
                return true
            end
        end
    end

    if not combo.done[2] and ui_w_slash:Get() and sa and sb and ok(sa, "slash", t) then
        local r = sa:get_cast_range(); if not r or r <= 0 then r = 250 end
        if dist <= r then
            local res = aim_cast(cmd, lead(tp, vel, dist, 3000), sb, "slash", t, lp, target)
            if res == "casted" then
                combo.done[2] = true; combo.t = t; dbg("W2: Slash"); return true
            elseif res == "aiming" then
                return true
            end
        end
    end

    if not combo.done[3] and ui_w_frenzy:Get() and fa and fb and ok(fa, "frenzy", t) then
        local mr = ui_smart_fr:Get() and (5 * UNIT_METER) or (20 * UNIT_METER)
        if dist <= mr then
            self_cast(cmd, fb, "frenzy", t)
            combo.done[3] = true; combo.t = t; dbg("W3: Frenzy"); return true
        end
    end
    return false
end

-- ==========================================
-- Main Combat
-- ==========================================
local function handle_combat(cmd, lp)
    if not ui_enable:Get() or not ui_combo_key:IsDown() or Menu.Opened() then return end
    local t = global_vars.curtime()

    -- Key re-press detection (unlock target in mode C)
    local kd = ui_combo_key:IsDown()
    if kd and not key_prev and ui_lock_mode:Get() == 1 then
        locked.ent = nil; locked.hp = 0
        reset_combo()
    end
    key_prev = kd

    -- CC / state protection
    if lp:has_modifier_state(EModifierState.MODIFIER_STATE_BUSY_WITH_ACTION)
        or lp:has_modifier_state(EModifierState.MODIFIER_STATE_STUNNED)
        or lp:has_modifier_state(EModifierState.MODIFIER_STATE_SILENCED) then
        return
    end

    -- Retreat check (before combat)
    if try_retreat(cmd, lp, t) then return end

    -- Survival Ult
    if ui_auto_ult:Get() then
        local hp_pct = (lp.m_iHealth / lp:get_max_health()) * 100
        if hp_pct <= ui_ult_hp:Get() then
            local tr = ui_ult_range:Get()
            local danger = tr == 0 or find_best(lp, tr) ~= nil
            if danger then
                local ua, ub = find_ab(lp, "transformation")
                if ua and ub and ok(ua, "ult", t) then
                    cmd:add_buttonstate1(ub); last_cast["ult"] = t; return
                end
            end
        end
    end

    -- Acquire target
    local target = get_target(lp)
    if not target then
        reset_combo(); return
    end

    local tp = target:get_bone_pos("Pelvis") or (target:get_origin() + Vector(0, 0, 45))
    local mp = lp:get_origin()
    local dist = (tp - mp):Length()
    local vel = target:get_velocity() or Vector(0, 0, 0)

    -- Update systems
    killable = ui_execute:Get() and calc_burst(lp, target) >= target.m_iHealth

    -- Determine form
    local wolf = is_wolf(lp)
    local form = wolf and "wolf" or "human"

    -- Reset combo on form change or timeout
    if combo.form ~= form then reset_combo() end
    if combo.t > 0 and (t - combo.t) > 4.0 then reset_combo() end
    if combo.done[1] and combo.done[2] and combo.done[3] then reset_combo() end

    combo.form = form
    combo.active = true

    -- Auto-chase (wolf only)
    if ui_chase:Get() and wolf and dist > 3 * UNIT_METER then
        cmd.forwardmove = 1.0
        cmd:add_buttonstate1(InputBitMask_t.IN_SPEED)
        cmd:smooth_aim(utils.calc_angle(utils.get_camera_pos(), tp), 0.5)
    end

    -- Run combo
    if wolf then
        wolf_combo(cmd, lp, target, tp, dist, vel, t)
    else
        human_combo(cmd, lp, target, tp, dist, vel, t)
    end
end

-- ==========================================
-- Callbacks
-- ==========================================

local function on_move(cmd)
    local lp = entity_list.local_pawn()
    if not lp or not lp:valid() or not lp:is_alive() then return end
    if not is_werewolf(lp) then return end
    handle_combat(cmd, lp)
end

callback.on_draw:set(function()
    if not ui_enable:Get() or not ui_visuals:Get() then return end
    
    local lp = entity_list.local_pawn()
    if not lp or not lp:valid() or not is_werewolf(lp) then return end

    -- Draw FOV
    local fov_val = ui_fov:Get()
    if fov_val > 0 then
        local radius = utils.fov_to_pixel_radius(fov_val)
        local center = Render.ScreenSize() * 0.5
        Render.Circle(center, radius, Color(255, 255, 255, 30), 1.0)
    end

    -- Draw Target Info
    if locked.ent and locked.ent:valid() and locked.ent:is_alive() then
        local op, vis = Render.WorldToScreen(locked.ent:get_origin() + Vector(0,0,80))
        if vis then
            local msg = string.format("TARGET: %s [%dm]", locked.ent:get_model_name() or "Hero", math.floor((locked.ent:get_origin() - lp:get_origin()):Length() / UNIT_METER))
            Render.Text(font, 14, msg, op - Vec2(0, 20), Color(255, 0, 0, 255))
            if killable then
                Render.Text(font, 18, "KILLABLE!", op, Color(255, 255, 0, 255))
            end
        end
    end
end)

callback.on_createmove:set(on_move)

print(string.format("[Werewolf Alpha] v%s loaded.", VERSION))
