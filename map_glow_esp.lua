---@diagnostic disable
local SCRIPT_VERSION = "1.0.0"

-- ==========================================
-- Required Libraries
-- ==========================================
-- No external custom libraries used

if not Menu or not Menu.Find then
    print("[Map Glow ESP] Error: Required API components not found.")
    return
end

-- ==========================================
-- Menu Setup (Refactored)
-- ==========================================
local menu_general   = Menu.Create("Miscellaneous", "Utility", "Visuals", "Map Glow ESP", "⚙ General")
local ui_enable      = menu_general:Switch("Enable ESP", true)
local ui_bind        = menu_general:Bind("Toggle Key", Enum.ButtonCode.BUTTON_CODE_NONE)
local ui_range       = menu_general:Slider("Max Distance (m)", 10, 500, 150)
local ui_font_size   = menu_general:Slider("Font Size", 10, 24, 14, "%d px")

local menu_visuals    = Menu.Create("Miscellaneous", "Utility", "Visuals", "Map Glow ESP", "🎨 Visuals")
local ui_esp_style    = menu_visuals:Combo("Marker Style", { "None", "Corner Box", "Dot (Circle)" }, 1)
local ui_dot_radius   = menu_visuals:Slider("Dot Radius", 2, 10, 4)
local ui_show_names   = menu_visuals:Switch("Show Names", true)
local ui_show_dist    = menu_visuals:Switch("Show Distance", true)
local ui_glow_intensity = menu_visuals:Slider("Glow Intensity (%)", 0, 100, 80)
local ui_pulse_speed  = menu_visuals:Slider("Pulse Speed", 1, 10, 4)

local menu_radar      = Menu.Create("Miscellaneous", "Utility", "Visuals", "Map Glow ESP", "🗺 Radar")
local ui_radar_timers = menu_radar:Switch("Show Timers on Radar", true)
local ui_map_off_x    = menu_radar:Slider("Map Translation X", -2000, 2000, 0)
local ui_map_off_y    = menu_radar:Slider("Map Translation Y", -2000, 2000, 0)
local ui_map_scale    = menu_radar:Slider("Map Zoom/Scale", 0.5, 2.0, 1.0, "%.2fx")

local menu_ghosting   = Menu.Create("Miscellaneous", "Utility", "Visuals", "Map Glow ESP", "👻 Ghosting")
local ui_ghost_enable = menu_ghosting:Switch("Enable Dormant Objects", true)
local ui_ghost_time   = menu_ghosting:Slider("Ghost Duration (s)", 1, 60, 15)
local ui_ghost_alpha  = menu_ghosting:Slider("Ghost Max Alpha", 5, 200, 80)

local menu_crates      = Menu.Create("Miscellaneous", "Utility", "Visuals", "Map Glow ESP", "📦 Crates")
local ui_crates_enable = menu_crates:Switch("Enable Crates", true)
local ui_crates_color  = menu_crates:ColorPicker("Crate Color", Color(255, 200, 50, 180))
local ui_statues_enable = menu_crates:Switch("Enable Statues", true)
local ui_statues_color  = menu_crates:ColorPicker("Statue Color", Color(200, 200, 255, 180))
local ui_gold_enable   = menu_crates:Switch("Enable Golden Crates", true)
local ui_gold_color    = menu_crates:ColorPicker("Golden Crate Color", Color(255, 215, 0, 200))
local ui_sinner_enable = menu_crates:Switch("Enable Sinner's Sacrifice", true)
local ui_sinner_color  = menu_crates:ColorPicker("Sinner's Color", Color(50, 255, 100, 180))

local menu_camps      = Menu.Create("Miscellaneous", "Utility", "Visuals", "Map Glow ESP", "🐺 Neutral Camps")
local ui_camps_enable = menu_camps:Switch("Enable Camps", true)
local ui_camps_color  = menu_camps:ColorPicker("Camp Color", Color(255, 100, 100, 150))

local menu_timers       = Menu.Create("Miscellaneous", "Utility", "Visuals", "Map Glow ESP", "⏱ Timers")
local ui_timers_enable  = menu_timers:Switch("Enable 3D Respawn Timers", true)
local ui_timer_color    = menu_timers:ColorPicker("Timer Color", Color(255, 255, 255, 200))

-- ==========================================
-- Constants and State
-- ==========================================
local UNIT_METER = 37.7358490566
local FONT_MAIN  = Render.LoadFont([[fonts\MuseoSansEx 500.ttf]], Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)

-- Neutral categories mapping (Logic simplified)

-- Optimization State
local last_scan_time = 0
local scan_interval  = 0.5 -- Update entity list every 500ms
local cached_ents    = {}

local last_camp_time = 0
local camp_interval  = 0.1 
local cached_camps   = {}
local respawn_timers = {} 
local ghost_ents     = {} -- { [id] = { pos, category, last_seen, alpha_mult, name, class } }

local RESPAWN_DELAYS = {
    ["small"]  = 120, -- 2 min
    ["medium"] = 240, -- 4 min
    ["large"]  = 480, -- 8 min
    ["safe"]   = 240, -- 4 min
}

-- Minimap State (from discovery: minimap_container is at 1510, 655 | 380x380)
-- Deadlock map world bounds (approximate, symmetric)
local MINIMAP = {
    screen_x    = 1510,
    screen_y    = 655,
    screen_w    = 380,
    screen_h    = 380,
    -- Deadlock's playable map world coordinates (approximate)
    world_min_x = -8100,
    world_max_x = 8100,
    world_min_y = -8100,
    world_max_y = 8100,
}

local minimap_panel = nil
local minimap_last_check = 0

local function get_minimap_panel()
    local cur_time = global_vars.curtime()
    if minimap_panel and minimap_panel:is_valid() then return minimap_panel end
    if cur_time - minimap_last_check < 2 then return nil end
    minimap_last_check = cur_time
    minimap_panel = panorama.get_panel_by_id("minimap_container")
    return minimap_panel
end

local function world_to_radar(world_pos)
    local mm = MINIMAP
    local panel = get_minimap_panel()
    if panel and panel:is_valid() then
        local ok, pos, sz = pcall(function() return panel:get_bounds() end)
        if ok and pos and sz then
            mm.screen_x = pos.x
            mm.screen_y = pos.y
            mm.screen_w = sz.x
            mm.screen_h = sz.y
        end
    end

    local off_x = ui_map_off_x:Get() or 0
    local off_y = ui_map_off_y:Get() or 0
    local scale = ui_map_scale:Get() or 1.0

    local norm_x = (world_pos.x + off_x - mm.world_min_x) / (mm.world_max_x - mm.world_min_x)
    local norm_y = (world_pos.y + off_y - mm.world_min_y) / (mm.world_max_y - mm.world_min_y)
    
    -- Zoom / Scale from center
    norm_x = 0.5 + (norm_x - 0.5) * scale
    norm_y = 0.5 + (norm_y - 0.5) * scale

    -- Y axis inversion
    norm_y = 1.0 - norm_y
    
    local sx = mm.screen_x + norm_x * mm.screen_w
    local sy = mm.screen_y + norm_y * mm.screen_h
    return Vec2(sx, sy)
end

local CLASS_MAPPINGS = {
    ["C_Citadel_Crate"]                  = "crate",
    ["C_Citadel_Stash"]                  = "crate",
    ["C_Citadel_BreakableProp"]          = "crate",
    ["C_NPC_Neutral_SinnersSacrifice"]   = "sinner",
    ["C_Citadel_BreakblePropGoldPickup"] = "gold_crate",
    
    -- Neutrals / Camps
    ["C_NPC_Neutral_Small"]  = "neutral",
    ["C_NPC_Neutral_Medium"] = "neutral",
    ["C_NPC_Neutral_Large"]  = "neutral",
    ["C_NPC_Super_Neutral"]  = "neutral",
}

local CAMP_CLASSES = { "C_NPC_TrooperNeutral", "C_NPC_Neutral_Small", "C_NPC_Neutral_Medium", "C_NPC_Neutral_Large",
    "C_NPC_Super_Neutral" }

local FRIENDLY_NAMES = {
    ["C_NPC_Neutral_SinnersSacrifice"]   = "Sinner's Sacrifice",
    ["C_Citadel_BreakblePropGoldPickup"] = "Golden Crate",
    ["C_Citadel_Crate"]                  = "Statue",
    ["C_Citadel_BreakableProp"]          = "Crate",
    ["crate"]                            = "Crate",
    ["statue"]                           = "Statue",
    ["gold_crate"]                       = "Golden Crate",
    ["sinner"]                           = "Sinner's Sacrifice",
    ["camp"]                             = "Neutral Camp",
}

-- ==========================================
-- Premium Visuals
-- ==========================================

local function get_pulse(speed_mult, min_val, max_val)
    local speed = (ui_pulse_speed:Get() or 4) * (speed_mult or 1)
    local t = global_vars.curtime() * speed
    local val = (math.sin(t) * 0.5 + 0.5)
    return min_val + val * (max_val - min_val)
end


local function draw_soft_glow(screen_pos, color, size, intensity_mult)
    local intensity = (ui_glow_intensity:Get() or 80) / 100 * (intensity_mult or 1)
    local alpha = math.floor(color.a * intensity)
    
    -- Multi-layered ShadowCircle for volumetric glow effect
    Render.ShadowCircle(screen_pos, size * 1.5, Color(color.r, color.g, color.b, math.floor(alpha * 0.2)), size * 0.8, 16)
    Render.ShadowCircle(screen_pos, size * 1.0, Color(color.r, color.g, color.b, math.floor(alpha * 0.4)), size * 0.5, 16)
    Render.ShadowCircle(screen_pos, size * 0.6, Color(color.r, color.g, color.b, alpha), size * 0.3, 16)
end

local function draw_dot_marker(screen_pos, color, size, pulse)
    local clr = Color(color.r, color.g, color.b, math.floor(color.a * pulse))
    local radius = ui_dot_radius:Get() or 4
    Render.FilledCircle(screen_pos, radius, clr)
    Render.Circle(screen_pos, radius + 1, Color(0, 0, 0, 150), 1)
end

local function draw_premium_box(screen_pos, color, size, pulse)
    if ui_esp_style:Get() ~= 1 then return end 

    local clr = Color(color.r, color.g, color.b, math.floor(color.a * pulse))
    local s = size * pulse

    -- Corner-based Box
    local corners = {
        { Vec2(-1, -1), Vec2(0.3, 0) }, { Vec2(-1, -1), Vec2(0, 0.3) }, 
        { Vec2(1, -1), Vec2(-0.3, 0) }, { Vec2(1, -1), Vec2(0, 0.3) }, 
        { Vec2(-1, 1), Vec2(0.3, 0) }, { Vec2(-1, 1), Vec2(0, -0.3) }, 
        { Vec2(1, 1), Vec2(-0.3, 0) }, { Vec2(1, 1), Vec2(0, -0.3) }, 
    }

    local thick = 2
    for _, c in ipairs(corners) do
        local start = Vec2(screen_pos.x + c[1].x * s, screen_pos.y + c[1].y * s)
        local end_ = Vec2(start.x + c[2].x * s, start.y + c[2].y * s)
        Render.Line(start, end_, clr, thick)
    end
end

local function draw_premium_label(pos, text, subtext, color, pulse)
    if not FONT_MAIN or FONT_MAIN == 0 then return end
    if not pos then return end

    local screen_pos, visible = Render.WorldToScreen(pos)
    if not visible or not screen_pos then return end

    local font_size = ui_font_size:Get() or 14
    local full_text = tostring(text or "Object")
    if subtext then full_text = full_text .. " [" .. tostring(subtext) .. "]" end

    local text_size = Render.TextSize(FONT_MAIN, font_size, full_text)
    if not text_size then return end

    local padding = 6
    local box_w = text_size.x + padding * 2
    local box_h = text_size.y + padding * 2
    local box_x = screen_pos.x - box_w / 2
    local box_y = screen_pos.y - box_h - 20 * pulse

    local bg_clr = Color(20, 20, 25, math.floor(180 * pulse))
    local border_clr = Color(color.r, color.g, color.b, math.floor(200 * pulse))

    Render.FilledRect(Vec2(box_x, box_y), Vec2(box_x + box_w, box_y + box_h), bg_clr, 4)
    Render.Rect(Vec2(box_x, box_y), Vec2(box_x + box_w, box_y + box_h), border_clr, 4)

    Render.Text(FONT_MAIN, font_size, full_text, Vec2(box_x + padding + 1, box_y + padding + 1), Color(0, 0, 0, 150))
    Render.Text(FONT_MAIN, font_size, full_text, Vec2(box_x + padding, box_y + padding), Color(255, 255, 255, 230))
end

local function draw_respawn_timer(origin, time_left, color)
    local screen_pos, visible = Render.WorldToScreen(origin)
    if not visible then return end

    local minutes = math.floor(time_left / 60)
    local seconds = math.floor(time_left % 60)
    local text = string.format("%d:%02d", minutes, seconds)
    
    local font_size = 18
    local text_size = Render.TextSize(FONT_MAIN, font_size, text)
    
    -- Draw a small clock icon / circle bg
    Render.FilledCircle(screen_pos, 20, Color(20, 20, 20, 180))
    Render.Circle(screen_pos, 20, color, 2)
    
    Render.Text(FONT_MAIN, font_size, text, Vec2(screen_pos.x - text_size.x/2, screen_pos.y - text_size.y/2), Color(255, 255, 255, 230))
end

local function draw_radar_timer(origin, time_left, color)
    local radar_pos = world_to_radar(origin)
    if not radar_pos then return end

    local minutes = math.floor(time_left / 60)
    local seconds = math.floor(time_left % 60)
    local text = string.format("%d:%02d", minutes, seconds)

    local font_size = 11
    local text_size = Render.TextSize(FONT_MAIN, font_size, text)
    local r = 10

    -- Pulsing icon background
    local urgency = math.min(1.0, (60 - math.min(time_left, 60)) / 60)
    local icon_color = Color(
        math.floor(200 + 55 * urgency),
        math.floor(50 * (1 - urgency)),
        50,
        200
    )

    Render.FilledCircle(radar_pos, r + 1, Color(0, 0, 0, 120))
    Render.FilledCircle(radar_pos, r, icon_color)
    Render.Circle(radar_pos, r, Color(255, 255, 255, 180), 1)

    if text_size then
        Render.Text(FONT_MAIN, font_size, text,
            Vec2(radar_pos.x - text_size.x / 2, radar_pos.y - text_size.y / 2),
            Color(255, 255, 255, 240))
    end
end

local function draw_premium_silhouette(pos, color, base_scale, category, name, dist, show_label, pulse_slow, pulse_fast, is_ghost)
    local screen_pos, visible = Render.WorldToScreen(pos)
    
    local alpha_mult = 1.0
    if is_ghost then
        alpha_mult = (ui_ghost_alpha:Get() or 80) / 255
    end
    
    local clr = Color(color.r, color.g, color.b, math.floor(color.a * alpha_mult))
    local p_fast = pulse_fast * (is_ghost and 0.6 or 1.0)
    local p_slow = pulse_slow * (is_ghost and 0.6 or 1.0)

    if visible then
        -- 1. Soft Volumetric Glow
        draw_soft_glow(screen_pos, clr, base_scale, p_fast)

        -- 2. Style-based Marker
        local style = ui_esp_style:Get()
        if style == 1 then
            draw_premium_box(screen_pos, clr, base_scale, p_fast)
        elseif style == 2 then
            draw_dot_marker(screen_pos, clr, base_scale, p_fast)
        end

        -- 3. Info Labels
        if ui_show_names:Get() and show_label ~= false then
            local label_pos = Vector(pos.x, pos.y, pos.z + 65)
            local dist_str = ui_show_dist:Get() and string.format("%dm", math.floor((dist or 0) / UNIT_METER)) or nil
            local display_name = name
            if is_ghost then display_name = display_name .. " (Dormant)" end
            draw_premium_label(label_pos, display_name, dist_str, clr, p_slow)
        end
    end
end

local last_bind_state = false

local state = {
    _cached_range = 60,
    _cached_crates_en = true,
    _cached_statues_en = true,
    _cached_gold_en = true,
    _cached_sinner_en = true,
    _cached_camps_en = true,
    _cached_timers_en = true,
    _cached_timers_rad = true,
}

callback.on_draw:set(function()
    local current_bind_state = ui_bind:IsPressed()
    if current_bind_state and not last_bind_state then
        ui_enable:Set(not ui_enable:Get())
    end
    last_bind_state = current_bind_state

    local status, err = pcall(function()
        if not ui_enable:Get() then return end

        local lp = entity_list.local_pawn()
        if not lp or not lp:valid() then return end

        local cur_time = global_vars.curtime()
        local my_pos = lp:get_origin()

        local pulse_slow = get_pulse(0.8, 0.8, 1.0)
        local pulse_fast = get_pulse(1.2, 0.7, 1.0)

        -- 1. Scanning & Ghosting Logic
        if cur_time - last_scan_time > scan_interval then
            last_scan_time = cur_time
            cached_ents = {}
            
            -- Ghost cleanup
            local max_ghost_time = ui_ghost_time:Get() or 15
            for id, ghost in pairs(ghost_ents) do
                if cur_time - ghost.last_seen > max_ghost_time then
                    ghost_ents[id] = nil
                end
            end

            local all_ents = entity_list.get_all()
            for _, ent in ipairs(all_ents) do
                if ent and ent:valid() then
                    local is_dormant = ent:is_dormant()
                    local id = ent:get_index()
                    
                    local class = ent:get_class_name()
                    local vclass = ent.get_vdata_class_name and ent:get_vdata_class_name() or ""
                    local category = CLASS_MAPPINGS[class] or CLASS_MAPPINGS[vclass]

                    if not category then
                        local obj_name = (ent:get_name() or ""):lower()
                        if string.find(obj_name, "sacrifice") then category = "sinner"
                        elseif string.find(obj_name, "statue") then category = "statue" end
                    end
                    
                    if category == "crate" then
                        local model = (ent.get_model_name and ent:get_model_name() or ""):lower()
                        if string.find(model, "statue") or string.find(model, "urn") or string.find(model, "pot") or string.find(model, "idol") then
                            category = "statue"
                        elseif model ~= "" and not string.find(model, "crate") and not string.find(model, "wood") and not string.find(model, "box") then
                            category = "statue"
                        end
                    end

                    if category then
                        local origin = ent:get_origin()
                        if not is_dormant then
                            -- Update Ghosting info
                            ghost_ents[id] = {
                                pos = origin,
                                category = category,
                                class = class,
                                last_seen = cur_time,
                                name = FRIENDLY_NAMES[class] or FRIENDLY_NAMES[category] or "Object"
                            }
                            table.insert(cached_ents, id)
                        end
                    end
                end
            end

            -- Neutral Camp grouping (existing logic)
            if ui_camps_enable:Get() then
                local current_camps = {}
                local CAMP_CLASSES_INT = { "C_NPC_TrooperNeutral", "C_NPC_Neutral_Small", "C_NPC_Neutral_Medium", "C_NPC_Neutral_Large", "C_NPC_Super_Neutral" }
                for _, cls in ipairs(CAMP_CLASSES_INT) do
                    local ents = entity_list.by_class_name(cls)
                    if ents then
                        for _, ent in ipairs(ents) do
                            if ent and ent:valid() and not ent:is_dormant() and (ent.m_iHealth or 0) > 0 then
                                local pos = ent:get_origin()
                                if pos then
                                    local found = false
                                    for _, camp in ipairs(current_camps) do
                                        local camp_dist = math.sqrt((pos.x - camp.origin.x)^2 + (pos.y - camp.origin.y)^2 + (pos.z - camp.origin.z)^2)
                                        if camp_dist < 600 then
                                            camp.count = camp.count + 1
                                            found = true
                                            break
                                        end
                                    end
                                    if not found then
                                        local type = "medium"
                                        if string.find(cls, "Small") then type = "small"
                                        elseif string.find(cls, "Large") or string.find(cls, "Super") then type = "large"
                                        end
                                        table.insert(current_camps, { origin = pos, count = 1, type = type })
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- Timers detection
                for _, old_camp in ipairs(cached_camps) do
                    local still_active = false
                    for _, cur_camp in ipairs(current_camps) do
                        if math.sqrt((old_camp.origin.x - cur_camp.origin.x)^2 + (old_camp.origin.y - cur_camp.origin.y)^2) < 100 then still_active = true; break end
                    end
                    if not still_active and ui_timers_enable:Get() then
                        local key = string.format("%.0f,%.0f", old_camp.origin.x, old_camp.origin.y)
                        if not respawn_timers[key] then
                            respawn_timers[key] = { expires_at = cur_time + (RESPAWN_DELAYS[old_camp.type] or 240), origin = old_camp.origin, type = old_camp.type }
                        end
                    end
                end
                cached_camps = current_camps
            end
        end

        local max_dist = (ui_range:Get() or 150) * UNIT_METER
        
        -- 2. Render Ghosted & Active Entities
        local active_map = {}
        for _, id in ipairs(cached_ents) do active_map[id] = true end

        for id, data in pairs(ghost_ents) do
            local is_ghost = not active_map[id]
            if is_ghost and not ui_ghost_enable:Get() then goto continue end

            local ent_pos = data.pos
            local dist = math.sqrt((my_pos.x - ent_pos.x)^2 + (my_pos.y - ent_pos.y)^2 + (my_pos.z - ent_pos.z)^2)

            if dist <= max_dist then
                local clr = ui_crates_color:Get()
                local en = ui_crates_enable:Get()
                
                if data.category == "statue" then clr = ui_statues_color:Get(); en = ui_statues_enable:Get()
                elseif data.category == "gold_crate" then clr = ui_gold_color:Get(); en = ui_gold_enable:Get()
                elseif data.category == "sinner" then clr = ui_sinner_color:Get(); en = ui_sinner_enable:Get()
                elseif data.category == "neutral" then clr = ui_camps_color:Get(); en = ui_camps_enable:Get()
                end

                if en then
                    draw_premium_silhouette(ent_pos, clr, 40, data.category, data.name, dist, true, pulse_slow, pulse_fast, is_ghost)
                end
            end
            ::continue::
        end

        -- 3. Render Camps
        if ui_camps_enable:Get() then
            local camp_clr = ui_camps_color:Get()
            for _, camp in ipairs(cached_camps) do
                local dist = math.sqrt((my_pos.x - camp.origin.x)^2 + (my_pos.y - camp.origin.y)^2 + (my_pos.z - camp.origin.z)^2)
                if dist <= max_dist then
                    local screen_pos, visible = Render.WorldToScreen(camp.origin)
                    if visible then
                        draw_soft_glow(screen_pos, camp_clr, 45, pulse_fast)
                        if ui_show_names:Get() then
                            draw_premium_label(Vector(camp.origin.x, camp.origin.y, camp.origin.z + 65), "Neutral Camp (" .. camp.count .. ")", ui_show_dist:Get() and string.format("%dm", math.floor(dist / UNIT_METER)) or nil, camp_clr, pulse_slow)
                        end
                    end
                end
            end
        end

        -- 4. Respawn Timers
        if ui_timers_enable:Get() then
            local timer_clr = ui_timer_color:Get()
            for key, timer in pairs(respawn_timers) do
                local time_left = timer.expires_at - cur_time
                if time_left > 0 then
                    local dist = math.sqrt((my_pos.x - timer.origin.x)^2 + (my_pos.y - timer.origin.y)^2 + (my_pos.z - timer.origin.z)^2)
                    if dist <= max_dist then draw_respawn_timer(timer.origin, time_left, timer_clr) end
                    if ui_radar_timers:Get() then draw_radar_timer(timer.origin, time_left, timer_clr) end
                else respawn_timers[key] = nil end
            end
        end
    end)
    if not status then print("[Map Glow ESP] Draw Error: ", err) end
end)

print(string.format("[Map Glow ESP] v%s Loaded Successfully", SCRIPT_VERSION))
