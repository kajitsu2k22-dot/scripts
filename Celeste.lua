-- [[ Celeste.lua | High-End Hero Module v4.1 Final ]]
-- Optimized & Cleaned production version by Antigravity

local Celeste = {
    Target = nil,
    UNIT_METER = 37.7358490566,
    GRAVITY = 750,
    EntityData = {},
    HERO_ID = 81, -- Celeste / Unicorn ID
}

-- [[ UI Configuration ]]
local settings_tab = Menu.Create("Heroes", "Hero List", "Celeste", "Settings")

-- Group: Combo
local grp_combo = settings_tab:Create("Combo Settings", 0)
local enable = grp_combo:Switch("Enable Celeste Logic", true, "\xef\x99\x81")
local combo_key = grp_combo:Bind("Combo Hotkey", Enum.ButtonCode.KEY_X, "\xef\x84\x9c")

-- Group: Targeting
local grp_tgt = settings_tab:Create("Targeting Settings", 0)
local target_prio = grp_tgt:Combo("Target Priority", { "FOV", "HP%", "Distance" }, 0, "\xef\x80\xab")
local aim_fov = grp_tgt:Slider("Engagement FOV", 1, 180, 25, "%d", "\xef\x83\xbe")

-- Group: Abilities
local grp_abs = settings_tab:Create("Ability Settings", 1)

local s1_blast = grp_abs:Switch("Radiant Blast (1)", true, "\xef\x81\xad")
local s2_guard = grp_abs:Switch("Prismatic Guard (2)", true, "\xef\x83\xa7")
local s2_hp = s2_guard:Gear("Guard Logic"):Slider("HP Threshold %", 1, 100, 70)

local s3_daggers = grp_abs:Switch("Radiant Daggers (3)", true, "\xef\x82\x91")
local s3_gear = s3_daggers:Gear("Daggers Logic")
local use_pred_s3 = s3_gear:Switch("Enable Prediction", true)
local daggers_delay = s3_gear:Slider("Formation Delay (s)", 0.1, 2.0, 0.8)

local s4_orb = grp_abs:Switch("Shining Wonder (4)", true, "\xef\x80\x85")
local s4_gear = s4_orb:Gear("Orb Logic")
local use_pred_s4 = s4_gear:Switch("Enable Prediction", true)
local orb_min = s4_gear:Slider("Min Enemies to Cast", 1, 6, 1)
local orb_speed = s4_gear:Slider("Projectile Speed", 500, 3000, 1200)

-- [[ Core Logic Helpers ]]

local function is_playing_celeste(me)
    if not me or not me:valid() then return false end
    local hero_comp = me.m_CCitadelHeroComponent
    if not hero_comp or not hero_comp.m_spawnedHero then return false end
    return hero_comp.m_spawnedHero.m_nHeroID.m_Value == Celeste.HERO_ID
end

local function update_entity_data(ent)
    local idx = ent:get_index()
    local data = Celeste.EntityData[idx] or { last_velocity = Vector(0,0,0), acceleration = Vector(0,0,0), smoothed_velocity = Vector(0,0,0) }
    local cur_v = ent:get_velocity()
    local dt = global_vars.interval_per_tick() or 0.015625
    local lerp_factor = 0.25
    data.smoothed_velocity = (data.smoothed_velocity * (1 - lerp_factor)) + (cur_v * lerp_factor)
    data.acceleration = (cur_v - data.last_velocity) / dt
    data.last_velocity = cur_v
    Celeste.EntityData[idx] = data
    return data
end

local function get_center_pos(target)
    local bone = target:get_bone_pos("spine_2")
    if bone and bone:Length() > 0 then return bone end
    return target:get_origin() + Vector(0, 0, 45)
end

local function is_visible(start, target)
    if not start or not target or not target:valid() then return false end
    local tp = get_center_pos(target)
    local status, result = pcall(function() return trace.bullet(start, tp, 1, entity_list.local_pawn()) end)
    if not status or not result then return false end
    if type(result) == "boolean" then return result end
    return result.fraction > 0.95 or (result:hit_entity() and result:hit_entity():get_index() == target:get_index())
end

local function predict_enhanced(target, time, is_ground)
    local pos = is_ground and target:get_origin() or get_center_pos(target)
    if target:has_modifier_state(18) or target:has_modifier_state(30) or target:has_modifier_state(147) then return pos end
    local data = update_entity_data(target)
    local vel = data.smoothed_velocity
    local acc = data.acceleration
    local v_off = 0
    if not is_ground and math.abs(vel.z) > 10 then 
        v_off = (vel.z * time) - (0.5 * Celeste.GRAVITY * time * time)
    end
    local h_off = (Vector(vel.x, vel.y, 0) * time) + (Vector(acc.x, acc.y, 0) * 0.5 * time * time)
    local final_pos = pos + h_off
    final_pos.z = final_pos.z + v_off
    return final_pos
end

local function get_best_target()
    local me = entity_list.local_pawn()
    local enemies = entity_list.by_class_name("C_CitadelPlayerPawn")
    local best, score = nil, 999999
    local cp, ca, mt = utils.get_camera_pos(), utils.get_camera_angles(), me.m_iTeamNum
    for _, e in ipairs(enemies) do
        if e and e:valid() and e:is_alive() and not e:is_dormant() and e.m_iTeamNum ~= mt then
            local ep = get_center_pos(e)
            if not is_visible(cp, e) then goto next_e end
            local fov = utils.get_fov(ca, utils.calc_angle(cp, ep))
            if fov <= aim_fov:Get() then
                local dist = me:get_origin():Distance(e:get_origin()) / Celeste.UNIT_METER
                local p = target_prio:Get()
                local current_score = (p == 0 and fov) or (p == 1 and (e.m_iHealth/e:get_max_health()*100)) or dist
                if current_score < score then score = current_score; best = e end
            end
        end
        ::next_e::
    end
    return best
end

-- [[ Combat Dispatcher ]]
callback.on_createmove:set(function(cmd)
    if not enable:Get() or Menu.Opened() then return end
    local me = entity_list.local_pawn()
    
    -- Hero Check: Only run logic if playing Celeste (81)
    if not is_playing_celeste(me) or not me:is_alive() then return end
    
    if not combo_key:IsDown() then Celeste.Target = nil; return end

    Celeste.Target = get_best_target()
    local target = Celeste.Target
    if not target then return end
    
    local cap = utils.get_camera_pos()
    local s1, s2, s3, s4 = me:get_ability_by_slot(0), me:get_ability_by_slot(1), me:get_ability_by_slot(2), me:get_ability_by_slot(3)

    -- Ability 4
    if s4_orb:Get() and s4 then
        local st = s4:can_be_executed()
        if (st == 0 or st == 10) and is_visible(cap, target) then
            local e_count = 0
            for _, e in ipairs(entity_list.by_class_name("C_CitadelPlayerPawn")) do
                if e:valid() and e:is_alive() and e.m_iTeamNum ~= me.m_iTeamNum and e:get_origin():Distance(target:get_origin()) <= 400 then e_count = e_count + 1 end
            end
            if st == 10 or (st == 0 and e_count >= orb_min:Get()) then
                local d = me:get_origin():Distance(target:get_origin())
                local tp = (use_pred_s4:Get() and predict_enhanced(target, d / orb_speed:Get(), false)) or get_center_pos(target)
                local ta = utils.calc_angle(cap, tp)
                utils.set_camera_angles(ta)
                cmd.viewangles = ta
                if st == 0 then cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY4) end
            end
        end
    end

    -- Ability 3
    local a3_st = s3 and s3:can_be_executed() or -1
    if s3_daggers:Get() and s3 and (a3_st == 0 or a3_st == 23) then
        local tp = use_pred_s3:Get() and predict_enhanced(target, daggers_delay:Get(), true) or target:get_origin()
        if is_visible(me:get_origin() + Vector(0,0,60), target) and cmd:can_psilent_at_pos(tp) then
            cmd:set_psilent_at_pos(tp)
            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY3)
        end
    end

    -- Ability 2
    if s2_guard:Get() and s2 and s2:can_be_executed() == 0 then
        local hp_pct = (me.m_iHealth / (me:get_max_health() or 1)) * 100
        if hp_pct <= s2_hp:Get() and not me:has_modifier("modifier_unicorn_prismatic_guard_buff") then
            cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY2)
        end
    end

    -- Ability 1
    if s1_blast:Get() and s1 and s1:can_be_executed() == 0 then
        local tp = get_center_pos(target)
        if me:get_origin():Distance(tp) <= s1:get_cast_range() and is_visible(cap, target) then
            if cmd:can_psilent_at_pos(tp) then
                 cmd:set_psilent_at_pos(tp)
                 cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY1)
            end
        end
    end
end)

print("[Celeste] Module v4.1 - Hero Guard Active.")
