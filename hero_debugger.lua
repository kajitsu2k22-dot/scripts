---@diagnostic disable: undefined-global
-- ==========================================
-- Hero Debugger Pro v2.0.1
-- Optimized for zero visibility issues
-- ==========================================

local VERSION = "3.0.0"
local UNIT_METER = 37.7358490566

-- 1. Forward declarations for Variables
local ui_hud_enable, ui_bone_esp, ui_cmd_mon, ui_dump_vdata, ui_search_key, ui_hero_focus
local ui_part_enable, ui_bull_enable, ui_phys_enable, ui_mod_enable, ui_ptr_mode, ui_ptr_bind
local is_pointer_active = false
local FONT_HUD = Render.LoadFont([[fonts\MuseoSansEx 500.ttf]], Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)
local current_cmd_bits = 0
local custom_vdata_keywords = {}

-- Storage for Debug Layers
local active_particles = {}
local active_bullets    = {}
local active_modifiers  = {}
local tracked_entities  = {}

-- Draggable HUD State & Sakura Theme
local is_dragging = false
local drag_offset = Vec2(0, 0)
local active_panel_id = nil -- "main", "mod", "part"

local ui_hud_locked
db.hero_hud_pos = db.hero_hud_pos or Vec2(50, 150)
db.hero_mod_pos = db.hero_mod_pos or Vec2(50, 450)
db.hero_part_pos = db.hero_part_pos or Vec2(400, 150)

local SAKURA_PINK = Color(255, 183, 197, 255)
local SAKURA_DARK = Color(255, 105, 180, 255)
local SAKURA_BG   = Color(20, 15, 15, 200) -- Dark Sakura Glass
local SAKURA_ACC  = Color(255, 192, 203, 230)

-- 2. Constants & Data
local BIT_FLAGS = {
    { bit = InputBitMask_t.IN_ATTACK, name = "ATTACK" },
    { bit = InputBitMask_t.IN_ATTACK2, name = "ATTACK2" },
    { bit = InputBitMask_t.IN_JUMP, name = "JUMP" },
    { bit = InputBitMask_t.IN_DUCK, name = "DUCK" },
    { bit = InputBitMask_t.IN_FORWARD, name = "FWD" },
    { bit = InputBitMask_t.IN_BACK, name = "BACK" },
    { bit = InputBitMask_t.IN_MOVELEFT, name = "LEFT" },
    { bit = InputBitMask_t.IN_MOVERIGHT, name = "RIGHT" },
    { bit = InputBitMask_t.IN_ABILITY1, name = "A1" },
    { bit = InputBitMask_t.IN_ABILITY2, name = "A2" },
    { bit = InputBitMask_t.IN_ABILITY3, name = "A3" },
    { bit = InputBitMask_t.IN_ABILITY4, name = "A4" },
    { bit = InputBitMask_t.IN_RELOAD, name = "RELOAD" },
    { bit = InputBitMask_t.IN_USE, name = "USE" },
}

local MODIFIER_STATES = {
    { state = 17, name = "STUN" },
    { state = 14, name = "SILENCE" },
    { state = 18, name = "INVUL" },
    { state = 56, name = "SLOW" },
    { state = 157, name = "COMBAT" },
}

local VDATA_KEYWORDS = {
    -- Common Distances/Sizes
    "m_flRadius", "m_flRadiusMax", "m_flRadiusMin", "m_flRange", "m_flRangeMax", "m_flRangeMin",
    "m_flExplodeRadius", "m_flImpactRadius", "m_flProjectileRadius", "m_flSearchRadius",
    "m_flAuraRadius", "m_flEffectRadius", "m_flSpreadScale", "m_flTargetRange",
    
    -- Common Timings
    "m_flAbilityDuration", "m_flChannelTime", "m_flCastDelay", "m_flCastPeriod",
    "m_flCooldownTime", "m_flActiveDuration", "m_flStunDuration", "m_flDebuffDuration",
    "m_flBuffDuration", "m_flTransformationDuration", "m_flNetDuration", "m_flLingerDuration",
    
    -- Common Stats/Speeds
    "m_flSpeed", "m_flProjectileSpeed", "m_flTravelDistance", "m_flBulletSpeed",
    "m_flProcChance", "m_iMaxLevel", "m_iAbilityCharges", "m_iMaxCharges",
    "m_flDamage", "m_flImpactDamage", "m_flAreaDamage", "m_flTechDamage",
    "m_flHealthOverTime", "m_flHealAmount", "m_flLifestealPercent",
    
    -- WIP Hero Specifics (Fuzzy guess)
    "m_flLeapDistance", "m_flLeapSpeed", "m_flMaulDamage", "m_flBiteDamage"
}

-- ==========================================
-- Utility Functions
-- ==========================================

local function handle_dragging(id, pos, size)
    if ui_hud_locked and ui_hud_locked:Get() then 
        is_dragging = false
        active_panel_id = nil
        return 
    end

    local cursor = input.cursor_pos()
    
    if not is_dragging then
        local is_hovered = input.cursor_in_bounds(pos, pos + size)
        if is_hovered and input.is_pressed(Enum.ButtonCode.KEY_MOUSE1) then
            is_dragging = true
            active_panel_id = id
            drag_offset = cursor - pos
        end
    else
        if not input.is_down(Enum.ButtonCode.KEY_MOUSE1) then
            is_dragging = false
            active_panel_id = nil
        elseif active_panel_id == id then
            if id == "main" then db.hero_hud_pos = cursor - drag_offset
            elseif id == "mod" then db.hero_mod_pos = cursor - drag_offset
            elseif id == "part" then db.hero_part_pos = cursor - drag_offset end
        end
    end
end

local function draw_text_box(pos, title, rows, color, draggable, id, clear_callback)
    local padding = 14
    local font_size = 14
    local line_h = 19
    
    -- 1. Calculate size
    local max_w = Render.TextSize(FONT_HUD, font_size + 4, title).x
    for _, row in ipairs(rows) do
        max_w = math.max(max_w, Render.TextSize(FONT_HUD, font_size, row).x)
    end
    local box_w = math.max(280, max_w + (padding * 2))
    local box_h = (line_h * (#rows + 1)) + (padding * 2) + 10

    -- 2. Dragging (only if enabled for this panel)
    if draggable then
        handle_dragging(id or "main", pos, Vec2(box_w, box_h))
    end
    
    -- 3. Sakura Visuals
    Render.Blur(pos, pos + Vec2(box_w, box_h), 1.0, 0.4, 8)
    Render.Shadow(pos, pos + Vec2(box_w, box_h), SAKURA_DARK:AlphaModulate(0.15), 15, 8)
    Render.FilledRect(pos, pos + Vec2(box_w, box_h), SAKURA_BG, 8, Enum.DrawFlags.RoundCornersAll)
    
    -- Decorative Sakura Petal (Top Left)
    Render.Text(FONT_HUD, 16, "🌸", pos + Vec2(-10, -10), Color(255, 255, 255, 255))
    
    -- Bloom Accent (Light pink border)
    Render.Rect(pos, pos + Vec2(box_w, box_h), SAKURA_PINK:AlphaModulate(0.3), 8, 0, 1)

    -- Sakura Header (Gradient)
    local header_h = 28
    Render.Gradient(pos, pos + Vec2(box_w, header_h), SAKURA_DARK:AlphaModulate(0.6), SAKURA_PINK:AlphaModulate(0.3), SAKURA_PINK:AlphaModulate(0.0), SAKURA_PINK:AlphaModulate(0.0), 8, Enum.DrawFlags.RoundCornersTop)
    
    -- Title rendering (No hardcoded prefix)
    Render.Text(FONT_HUD, font_size + 2, title, pos + Vec2(padding, 6), Color(255, 255, 255, 255))
    
    -- 4. Utility Buttons (Copy & Clear)
    local copy_btn_pos = pos + Vec2(box_w - 26, 6)
    local is_copy_hov = input.cursor_in_bounds(copy_btn_pos, copy_btn_pos + Vec2(20, 20))
    Render.Text(FONT_HUD, 15, "📑", copy_btn_pos, is_copy_hov and Color(255, 255, 255, 255) or SAKURA_PINK:AlphaModulate(0.6))
    
    if is_copy_hov and input.is_pressed(Enum.ButtonCode.KEY_MOUSE1) then
        local copy_text = string.format("🌸 Sakura Hero Intel Export: %s 🌸\n------------------------------\n%s", 
                            title, table.concat(rows, "\n"))
        print("\n" .. copy_text .. "\n")
        Notification({duration=2.5, primary_text="📋 Stats exported to Console!"})
    end

    -- 4.2 Clear Button (Optional)
    if clear_callback then
        local clear_btn_pos = pos + Vec2(box_w - 50, 6)
        local is_clear_hov = input.cursor_in_bounds(clear_btn_pos, clear_btn_pos + Vec2(20, 20))
        Render.Text(FONT_HUD, 15, "🧹", clear_btn_pos, is_clear_hov and Color(255, 255, 255, 255) or SAKURA_PINK:AlphaModulate(0.6))
        
        if is_clear_hov and input.is_pressed(Enum.ButtonCode.KEY_MOUSE1) then
            clear_callback()
            Notification({duration=2.0, primary_text="🧹 Panel cleared!"})
        end
    end

    -- 5. Content
    for i, row in ipairs(rows) do
        local is_sep = row:find("---")
        local t_color = is_sep and SAKURA_DARK or Color(240, 240, 250, 255)
        local y_off = pos.y + padding + (line_h * i) + 8
        
        if not is_sep then
            -- Subtle indicator for ability rows
            if row:find("%[%d%]") then 
                Render.FilledRect(Vec2(pos.x + 4, y_off + 4), Vec2(pos.x + 8, y_off + 12), SAKURA_PINK:AlphaModulate(0.8), 2)
            end
        end
        
        Render.Text(FONT_HUD, font_size, row, Vec2(pos.x + (is_sep and padding or padding + 8), y_off), t_color)
    end
end

local function draw_3d_arrow(start, end_, color, head_size)
    local s_start, v_start = Render.WorldToScreen(start)
    local s_end, v_end     = Render.WorldToScreen(end_)
    
    if v_start and v_end then
        Render.Line(s_start, s_end, color, 2.0)
        -- Simplified 2D head for performance
        Render.Circle(s_end, head_size or 4, color, 1.5)
    end
end

local function render_debug_layers(lp)
    local cur_time = global_vars.curtime()
    local cam_pos  = utils.get_camera_pos()

    -- 1. Particle Layer
    if ui_part_enable and ui_part_enable:Get() then
        for idx, part in pairs(active_particles) do
            local dist = (part.pos - cam_pos):Length() / UNIT_METER
            if dist < 50 then -- Only nearby
                local s_pos, vis = Render.WorldToScreen(part.pos)
                if vis then
                    local alpha = math.max(0, 255 - (dist * 4))
                    Render.Text(FONT_HUD, 10, string.format("✨ [%d] %s", idx, part.name), s_pos, SAKURA_PINK:AlphaModulate(alpha / 255))
                end
            end
        end
    end

    -- 2. Bullet Layer
    if ui_bull_enable and ui_bull_enable:Get() then
        for _, bull in ipairs(active_bullets) do
            local age = cur_time - bull.time
            if age < 2.0 then
                local speed = bull.speed or 3000
                local dist  = bull.dist  or 5000
                local end_pos = bull.start + (bull.dir * math.min(dist, age * speed))
                local s_start, v_start = Render.WorldToScreen(bull.start)
                local s_end, v_end     = Render.WorldToScreen(end_pos)
                
                if v_start and v_end then
                    local alpha = math.max(0, 255 - (age * 120))
                    Render.Line(s_start, s_end, Color(255, 255, 255, alpha), 1.0)
                    Render.FilledCircle(s_end, 2, Color(255, 100, 100, alpha))
                end
            end
        end
    end

    -- 3. Physics / Velocity Layer
    if ui_phys_enable and ui_phys_enable:Get() then
        local ents = entity_list.get_all()
        for _, ent in ipairs(ents) do
            if ent:valid() and ent:is_alive() and not ent:is_dormant() then
                local vel = ent:get_velocity()
                if vel and vel:Length() > 50 then
                    local start = ent:get_origin() + Vector(0, 0, 30)
                    local end_  = start + (vel * 0.2) -- 0.2s prediction vector
                    draw_3d_arrow(start, end_, Color(0, 255, 120, 180), 3)
                end
            end
        end
    end
end

local function dump_ability_deep(abil, name_label)
    if not abil or not abil:valid() then return end
    print(string.format("\n      [Ability Analysis: %s]", tostring(name_label)))
    
    -- Native Getters
    local aoe = abil:get_aoe_radius()
    local rng = abil:get_cast_range()
    if aoe and aoe > 0 then print(string.format("          - Native AoE: %.1f", aoe)) end
    if rng and rng > 0 then print(string.format("          - Native Range: %.1f", rng)) end
    
    -- Property Scanner
    for _, field in ipairs(VDATA_KEYWORDS) do
        local prop = abil:get_property(field)
        if prop then print(string.format("          - Property [%s] found", field)) end
        
        local scaled = abil:get_scaled_property(field)
        if scaled and scaled ~= 0 then print(string.format("          - Scaled %s: %s", field, tostring(scaled))) end
    end
    
    -- Upgrades Scanner
    local upgrades = abil:get_upgrades()
    if upgrades and #upgrades > 0 then
        print("          - Upgrade Modifiers Found:")
        for _, upg in ipairs(upgrades) do
            for k, v in pairs(upg) do
                print(string.format("              %s -> %s", tostring(k), tostring(v)))
            end
        end
    end

    -- Custom Search Results
    if ui_search_key then
        local key = ui_search_key:Get()
        if key and #key > 0 then
            local prop = abil:get_property(key)
            if prop then print(string.format("          - [Custom] Property [%s] found", key)) end
            local scaled = abil:get_scaled_property(key)
            if scaled and scaled ~= 0 then print(string.format("          - [Custom] Scaled %s: %s", key, tostring(scaled))) end
        end
    end
end

local function print_hero_info(pawn, label)
    if not pawn or not pawn:valid() then return end

    print("\n" .. string.rep("=", 60))
    print(string.format(" HERO: %s (vData: %s)", tostring(label), tostring(pawn:get_vdata_class_name())))
    print(string.rep("-", 60))
    print(string.format("  - Index: %d", pawn:get_index()))
    print(string.format("  - Class: %s", pawn:get_class_name()))
    print(string.format("  - Health: %d / %d", pawn.m_iHealth or 0, pawn:get_max_health() or 0))

    local abilities = (pawn.get_abilities ~= nil) and pawn:get_abilities() or nil
    if abilities then
        print("\n  --- Abilities ---")
        for i, abil in ipairs(abilities) do
            if abil and abil:valid() then
                local cd = abil:get_cooldown() or 0
                local level = abil:get_level() or 0
                print(string.format("  [%d] %s (Level %d, CD %.1fs)", i, abil:get_name() or "None", level, cd))
                dump_ability_deep(abil, abil:get_name() or ("Slot " .. i))
            end
        end
    end
    print(string.rep("=", 60) .. "\n")
    Notification({duration=2.0, primary_text="Dumped info for " .. label})
end

local function export_hero_template(pawn)
    if not pawn or not pawn:valid() then return end
    
    local hero_class = pawn:get_vdata_class_name() or "UnknownHero"
    local clean_hero_name = hero_class:gsub("C_CitadelPlayerPawn", ""):gsub("C_Citadel_Pawn_", ""):gsub("CCitadel_Pawn_", "")
    
    local abilities = pawn.get_abilities and pawn:get_abilities() or nil
    local abil_defs = ""
    local combo_logic = ""
    
    if abilities then
        for i, abil in ipairs(abilities) do
            if abil and abil:valid() then
                local name = abil:get_name() or "Ability"
                local var_name = "abil_" .. i
                -- Deadlock usually has 4 main abilities at slots 0-3
                local slot = i - 1 
                
                abil_defs = abil_defs .. string.format("local %s = nil -- %s\n", var_name, name)
                
                combo_logic = combo_logic .. string.format([[
        -- Logic for %s
        %s = lp:get_ability_by_slot(%d)
        if %s and %s:can_be_executed() == 0 then
            local range = %s:get_cast_range()
            local dist = (lp:get_origin() - target:get_origin()):Length()
            if dist <= range then
                -- cmd:add_buttonstate1(InputBitMask_t.IN_ABILITY%d)
            end
        end
    ]], name, var_name, slot, var_name, var_name, var_name, i)
            end
        end
    end

    local template = string.format([[
---@diagnostic disable: undefined-global
-- ========================================================
-- [AUTO-GEN] Template: %s
-- Generated by Hero Debugger Pro v3.0
-- ========================================================

local UI_ENABLE = Menu.Create("%s", "Scripts", "Main", "", "Master"):Switch("Enable Script", false)
local UI_DEBUG  = Menu.Create("%s", "Scripts", "Main", "", "Master"):Switch("Debug Mode", true)

-- 1. Constants & Prediction Data
local UNIT_METER = 37.7358490566

%s

-- 2. Utility: Prediction Helper
local function get_predicted_pos(target, abil)
    if not target or not target:valid() then return nil end
    local lp = entity_list.local_pawn()
    if not lp then return nil end
    
    -- Using native predict_bullet if ability has property
    local speed = abil:get_scaled_property("m_flProjectileSpeed") or 3000
    return utils.predict_bullet(lp:get_origin(), target:get_origin(), target:get_velocity(), speed)
end

callback.on_createmove:set(function(cmd)
    if not UI_ENABLE:Get() or Menu.Opened() then return end
    
    local lp = entity_list.local_pawn()
    if not lp or not lp:valid() or not lp:is_alive() then return end
    
    local target = utils.find_nearest_visible_enemy()
    if not target or not target:valid() then return end

%s
end)

print("[Script] %s Template Loaded.")
]], clean_hero_name, clean_hero_name, clean_hero_name, abil_defs, combo_logic, clean_hero_name)

    print("\n" .. string.rep("=", 60))
    print("--- HERO LUA TEMPLATE (Copy from console) ---")
    print(template)
    print(string.rep("=", 60) .. "\n")
    Notification({duration=5.0, primary_text="Boilerplate exported to Console!"})
end

local function render_local_hero_focus(lp, screen)
    if not lp or not lp:valid() then return end
    
    local rows = {}
    
    -- 1. Hero identity
    table.insert(rows, string.format("Hero: %s (vData: %s)", tostring(lp:get_name() or "None"), tostring(lp:get_vdata_class_name())))
    table.insert(rows, string.format("Health: %d / %d", lp.m_iHealth or 0, lp:get_max_health() or 0))
    
    -- 2. Core Stats (for scaling)
    local tech = lp:get_scaling_stat(59) -- ETechPower
    local dps  = lp:get_scaling_stat(0)  -- EWeaponDPS
    local stam = lp:get_scaling_stat(50) -- EStamina
    table.insert(rows, string.format("Stats: Tech %.0f | DPS %.0f | Stam %.0f", tech, dps, stam))
    
    -- 3. Detailed Ability Inspection
    table.insert(rows, "--- Abilities [Active Slots] ---")
    for i = 0, 3 do -- Main abilities
        local abil = lp:get_ability_by_slot(i)
        if abil and abil:valid() then
            local name = abil:get_name() or ("Slot " .. (i + 1))
            local cd = abil:get_cooldown() or 0
            local rng = abil:get_cast_range() or 0
            local aoe = abil:get_aoe_radius() or 0
            local state = abil:can_be_executed()
            
            local status_text = "Ready"
            if state == 2 then status_text = "CD"
            elseif state == 10 then status_text = "Busy/Channel"
            elseif cd > 0 then status_text = "Wait" end
            
            -- Format: [1] AbilityName (R: 1000 A: 300) STATUS [CD: 5.0]
            local str = string.format("[%d] %s (R:%.0f A:%.0f) %s", i+1, name, rng, aoe, status_text)
            if cd > 0 then str = str .. string.format(" [%.1fs]", cd) end
            table.insert(rows, str)
        end
    end

    -- 4. Modifiers (Active States)
    local mods = lp:get_modifiers()
    if mods and #mods > 0 then
        table.insert(rows, "--- Active Modifiers (Top 5) ---")
        for m_idx = 1, math.min(#mods, 5) do
            table.insert(rows, "- " .. mods[m_idx]:get_name())
        end
    end

    draw_text_box(db.hero_hud_pos, "🌸 SAKURA HERO INTEL: " .. tostring(lp:get_name() or "None"), rows, SAKURA_PINK, true, "main")
end

local function render_modifier_monitor()
    if not ui_mod_enable or not ui_mod_enable:Get() then return end
    
    local rows = {}
    local lp = entity_list.local_pawn()
    if not lp or not lp:valid() then return end
    
    local tid = lp:get_index()
    local mods = active_modifiers[tid]
    
    if not mods or next(mods) == nil then 
        table.insert(rows, "No active modifiers.")
    else
        -- 1. Aggregation (Grouping duplicates)
        local counts = {}
        local order = {}
        for _, m in pairs(mods) do
            if not counts[m.name] then
                table.insert(order, m.name)
                counts[m.name] = 1
            else
                counts[m.name] = counts[m.name] + 1
            end
        end
        
        -- 2. Formatting
        for _, name in ipairs(order) do
            local count = counts[name]
            local str = "• " .. name
            if count > 1 then str = str .. string.format(" (x%d)", count) end
            table.insert(rows, str)
        end
    end
    
    local clear_fn = function() active_modifiers[tid] = {} end
    draw_text_box(db.hero_mod_pos, "🛡️ MODIFIER TRACKER", rows, Color(100, 200, 255, 255), true, "mod", clear_fn)
end

local function render_particle_monitor()
    if not ui_part_enable or not ui_part_enable:Get() then return end
    
    local rows = {}
    local count = 0
    for idx, p in pairs(active_particles) do
        count = count + 1
        if count <= 10 then -- Show top 10
            table.insert(rows, string.format("[%d] %s", idx, p.name:sub(1, 25)))
        end
    end
    
    if count > 10 then table.insert(rows, string.format("... and %d more", count - 10)) end
    if count == 0 then table.insert(rows, "No active particles.") end
    
    local clear_fn = function() active_particles = {} end
    draw_text_box(db.hero_part_pos, "✨ PARTICLE LIST", rows, SAKURA_PINK, true, "part", clear_fn)
end

local function handle_pointer_mode()
    if ui_ptr_bind then
        local key = ui_ptr_bind:Get()
        if key ~= 0 and input.is_pressed(key) then
            is_pointer_active = not is_pointer_active
        end
    end

    if not is_pointer_active then return end
    
    -- Visual Status Indicator
    local ss = Render.ScreenSize()
    Render.Text(FONT_HUD, 14, "🌸 POINTER MODE: ON (BLOCKING INPUT) 🌸", Vec2(ss.x/2 - 120, 40), SAKURA_PINK)
    
    local screen = Render.ScreenSize()
    local point = screen / 2
    
    -- 1. Sakura Cursor Render
    local cursor_color = SAKURA_DARK:AlphaModulate(0.9)
    Render.Circle(point, 6, cursor_color, 2.0)
    Render.Circle(point, 12, SAKURA_PINK:AlphaModulate(0.5), 1.0)
    Render.Text(FONT_HUD, 22, "🌸", point + Vec2(10, 10), Color(255, 255, 255, 255))
    
    -- Crosshair Lines
    Render.Line(point - Vec2(20, 0), point + Vec2(20, 0), SAKURA_PINK:AlphaModulate(0.6), 1)
    Render.Line(point - Vec2(0, 20), point + Vec2(0, 20), SAKURA_PINK:AlphaModulate(0.6), 1)

    -- 2. Advanced Selection Logic (Check Head or Origin)
    local best_ent = nil
    local best_dist = 80 -- Increased search radius
    
    local ents = entity_list.get_all()
    for _, ent in ipairs(ents) do
        if ent:valid() and ent:get_index() ~= entity_list.local_pawn():get_index() then
            -- Try to get head, fallback to center or origin
            local world_anchor = ent:get_bone_pos("head") or (ent:get_origin() + Vector(0,0,45))
            local s_pos, vis = Render.WorldToScreen(world_anchor)
            
            if vis then
                local d = (s_pos - point):Length()
                if d < best_dist then
                    best_dist = d
                    best_ent = ent
                end
            end
        end
    end
    
    if best_ent then
        -- Highlighting
        local anchor = best_ent:get_bone_pos("head") or best_ent:get_origin()
        local s_anchor, v_anchor = Render.WorldToScreen(anchor)
        if v_anchor then
            Render.Circle(s_anchor, 10, Color(255, 255, 255, 255), 2.5)
            Render.Text(FONT_HUD, 14, "Dump: " .. tostring(best_ent:get_name() or "Entity"), s_anchor + Vec2(15, -15), SAKURA_PINK)
        end
        
        if input.is_pressed(Enum.ButtonCode.KEY_MOUSE1) then
            print_hero_info(best_ent, best_ent:get_name() or "Selected Entity")
        end
    end
end

local function render_cmd_monitor()
    if not ui_cmd_mon or not ui_cmd_mon:Get() then return end
    local screen = Render.ScreenSize()
    local x, y = 20, screen.y - 30
    
    local active_text = "INPUT: "
    for _, flag in ipairs(BIT_FLAGS) do
        if (current_cmd_bits & flag.bit) ~= 0 then
            active_text = active_text .. flag.name .. "  "
        end
    end
    
    Render.Text(FONT_HUD, 16, active_text, Vec2(x + 1, y + 1), Color(0, 0, 0, 150))
    Render.Text(FONT_HUD, 16, active_text, Vec2(x, y), Color(0, 255, 150, 255))
end

-- 4. Menu Setup (Now variables already in scope)
local menu_general  = Menu.Create("Miscellaneous", "Developer", "Hero Debugger Pro", "Settings", "🌸 General")
ui_hud_enable = menu_general:Switch("Target Inspector", true)
ui_hero_focus = menu_general:Switch("Hero Intel (Local)", true)
ui_hud_locked = menu_general:Switch("Lock Panels", false)
ui_ptr_bind   = menu_general:Bind("Pointer Mode Key", Enum.ButtonCode.KEY_NONE)
menu_general:Button("Reset All HUD Positions", function()
    db.hero_hud_pos = Vec2(50, 150)
    db.hero_mod_pos = Vec2(50, 450)
    db.hero_part_pos = Vec2(400, 150)
end)

local menu_layers = Menu.Create("Miscellaneous", "Developer", "Hero Debugger Pro", "Settings", "🔮 Debug Layers")
ui_part_enable = menu_layers:Switch("Particle Tracker (3D)", true)
ui_bull_enable = menu_layers:Switch("Bullet Tracers (3D)", true)
ui_phys_enable = menu_layers:Switch("Velocity Vectors (3D)", true)
ui_mod_enable  = menu_layers:Switch("Modifier Monitor (HUD)", true)
ui_bone_esp    = menu_layers:Switch("Bone Visualizer", false)
ui_cmd_mon     = menu_layers:Switch("Input Monitor", true)

local menu_dump     = Menu.Create("Miscellaneous", "Developer", "Hero Debugger Pro", "Extraction", "📂 Extraction")
menu_dump:Button("Dump Local Hero Info", function()
    print_hero_info(entity_list.local_pawn(), "Local Hero")
end)
menu_dump:Button("Export Hero Code Template", function()
    export_hero_template(entity_list.local_pawn())
end)
menu_dump:Button("Dump All Heroes", function()
    local pawns = entity_list.get_all()
    for _, p in ipairs(pawns) do
        if p and p:valid() and p:get_class_name() == "C_CitadelPlayerPawn" then
            print_hero_info(p, p:get_name() or "Enemy")
        end
    end
end)
ui_dump_vdata = menu_dump:Switch("Full vData Dump (Heavy)", false)

local menu_scan     = Menu.Create("Miscellaneous", "Developer", "Hero Debugger Pro", "Scanner", "🔍 Dynamic Scanner")
ui_search_key = menu_scan:Input("Custom vData Key", "m_flRadius")
menu_scan:Button("Run Custom Key Scan", function()
    local lp = entity_list.local_pawn()
    if lp then print_hero_info(lp, "Local Hero (Custom Scan)") end
end)

-- 5. Callbacks & Main Logic

callback.on_draw:set(function()
    local lp = entity_list.local_pawn()
    if not lp or not lp:valid() then return end
    
    local ss = Render.ScreenSize()
    local center = ss / 2

    -- 1. World HUD (Target Selection & Radar)
    if ui_hud_enable and ui_hud_enable:Get() then
        local target_candidate = nil
        local best_dist_px = 150 -- Screen distance threshold (pixels)
        
        -- Use get_all() for broad support, filter manually
        local all_ents = entity_list.get_all()
        for _, ent in ipairs(all_ents) do
            if ent:valid() and ent:get_index() ~= lp:get_index() then
                local cname = ent:get_class_name()
                -- Target Heroes or NPCs with health
                if cname == "C_CitadelPlayerPawn" or (ent.m_iHealth and ent.m_iHealth > 0) then
                    local w_pos = ent:get_origin() + Vector(0, 0, 50) 
                    local s_pos, visible = Render.WorldToScreen(w_pos)
                    
                    if visible then
                        local screen_dist = (s_pos - center):Length()
                        if screen_dist < best_dist_px then
                            best_dist_px = screen_dist
                            target_candidate = ent
                        end
                    end
                end
            end
        end

        -- Filter 2: Occlusion Check for the best candidate
        if target_candidate then
            local camera_pos = lp.vec_camera_position or lp:get_origin() + Vector(0, 0, 64)
            -- Anchor to head if possible, otherwise origin
            local head_pos = target_candidate:get_bone_pos("head") or (target_candidate:get_origin() + Vector(0,0,60))
            
            local tr = trace.line(camera_pos, head_pos, 0x1, lp:get_index(), 0, 0, 0, function() return false end)
            
            -- Visibility check
            if tr.fraction > 0.95 or (tr:hit_entity() and tr:hit_entity():get_index() == target_candidate:get_index()) then
                local s_head, v_head = Render.WorldToScreen(head_pos)
                if v_head then
                    local dist_m = (target_candidate:get_origin() - camera_pos):Length() / UNIT_METER
                    local rows = {
                        string.format("Class: %s", target_candidate:get_class_name()),
                        string.format("Health: %d / %d", target_candidate.m_iHealth or 0, target_candidate:get_max_health() or 2000),
                        string.format("Distance: %.1fm", dist_m)
                    }
                    
                    local is_hero = target_candidate:get_class_name() == "C_CitadelPlayerPawn"
                    local hud_color = is_hero and Color(255, 130, 0, 230) or Color(30, 180, 255, 230)
                    
                    draw_text_box(Vec2(s_head.x + 25, s_head.y - 30), "🎯 [ TARGET INSPECTOR ]", rows, hud_color, false)
                    
                    -- Bones if enabled (with distance and transparency optimization)
                    if ui_bone_esp and ui_bone_esp:Get() and dist_m < 12 then
                        local bones = target_candidate:get_bones()
                        if bones then
                            for bname, bpos in pairs(bones) do
                                local b_screen, b_vis = Render.WorldToScreen(bpos)
                                if b_vis then
                                    local alpha = math.max(0, 180 - (dist_m * 8))
                                    Render.FilledCircle(b_screen, 1.5, Color(255, 255, 255, alpha))
                                    Render.Text(FONT_HUD, 8, bname, b_screen, Color(255, 255, 255, math.floor(alpha * 0.7)))
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- 2. Local Hero Focus
    if ui_hero_focus and ui_hero_focus:Get() then
        render_local_hero_focus(lp, ss)
    end
    
    -- 3. Commands Monitor
    render_cmd_monitor()

    -- 4. New V3 Debug Layers
    render_debug_layers(lp)
    
    -- 5. Monitor Panels
    render_modifier_monitor()
    render_particle_monitor()
    
    -- 6. Tools
    handle_pointer_mode()
end)

callback.on_createmove:set(function(cmd)
    current_cmd_bits = cmd.button_state1
    
    -- Block hero actions during Pointer Mode
    if is_pointer_active then
        cmd.button_state0 = 0
        cmd.button_state1 = 0
        cmd.button_state2 = 0
        cmd.forwardmove = 0
        cmd.leftmove = 0
        cmd.upmove = 0
    end
end)

-- ==========================================
-- New V3.0 Event Hooks
-- ==========================================

callback.on_particle_create:set(function(info)
    if not ui_part_enable or not ui_part_enable:Get() then return end
    active_particles[info.index] = {
        name = info.name,
        ent  = info.entity,
        time = global_vars.curtime(),
        pos  = info.entity and info.entity:get_origin() or Vector(0,0,0)
    }
end)

callback.on_particle_update:set(function(info)
    if active_particles[info.index] then
        active_particles[info.index].pos = info.position
    end
end)

callback.on_particle_destroy:set(function(info)
    active_particles[info.index] = nil
end)

callback.on_bullet_create:set(function(info)
    if not ui_bull_enable or not ui_bull_enable:Get() then return end
    if not info.start_pos or not info.direction then return end
    
    table.insert(active_bullets, {
        start = info.start_pos,
        dir   = info.direction,
        speed = info.speed or 3000,
        dist  = info.max_distance or 5000,
        time  = global_vars.curtime(),
        unit  = info.shooter
    })
    
    -- Limit bullet history
    if #active_bullets > 20 then table.remove(active_bullets, 1) end
end)

callback.on_add_modifier:set(function(mod, target, owner)
    if not ui_mod_enable or not ui_mod_enable:Get() then return end
    if not mod or not target or not target:valid() then return end
    
    local tid = target:get_index()
    active_modifiers[tid] = active_modifiers[tid] or {}
    active_modifiers[tid][mod] = {
        name = mod:get_name(),
        time = global_vars.curtime(),
        obj  = mod
    }
end)

callback.on_remove_modifier:set(function(mod)
    if not mod then return end
    for tid, mods in pairs(active_modifiers) do
        if mods[mod] then
            mods[mod] = nil
            return
        end
    end
end)

print(string.format("[Hero Debugger Pro] v%s Initialized.", VERSION))
