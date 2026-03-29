---@diagnostic disable

local SCRIPT_NAME = "Watermark"
local SCRIPT_VERSION = "1.2.0"

if not Menu or not Render or not callback or not entity_list or not input or not game_rules or not global_vars then
    print("[Watermark] Error: Required API components not found.")
    return
end

local DRAW_NONE = (Enum and Enum.DrawFlags and Enum.DrawFlags.None) or 0
local DRAW_TOP = (Enum and Enum.DrawFlags and Enum.DrawFlags.RoundCornersTop) or 0
local FONT_FLAGS = (Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS) or 0
local KEY_MOUSE1 = (Enum and Enum.ButtonCode and Enum.ButtonCode.KEY_MOUSE1) or 0
local LOGO_IMAGE_CANDIDATES = {
    [[images\watermark\wm_standart.png]],
    [[images/watermark/wm_standart.png]],
    [[.\images\watermark\wm_standart.png]],
    [[./images/watermark/wm_standart.png]],
}

local MIN_PLAYERS_FOR_MATCH = 4
local REFRESH_INTERVAL = 0.25

local menu_general = Menu.Create("Miscellaneous", "Utility", "Visuals", "Watermark", "General")
local ui_enable = menu_general:Switch("Enable", true)
local ui_layout_mode = menu_general:Combo("Layout Mode", { "Full", "Compact", "Minimal Branding" }, 0)
local ui_visibility_mode = menu_general:Combo("Visibility", { "Always", "Hide In Menu", "Only In Match" }, 0)
local ui_lock_position = menu_general:Switch("Lock Position", false)
local ui_blur_strength = menu_general:Slider("Blur Strength", 0, 10, 5)
local ui_opacity = menu_general:Slider("Opacity", 20, 100, 85, "%d%%")
local ui_scale = menu_general:Slider("Scale", 0.75, 1.50, 1.00, "%.2fx")
local ui_snap_edges = menu_general:Switch("Snap To Edges", true)
local ui_show_logo = menu_general:Switch("Show Logo", true)
local ui_show_state = menu_general:Switch("Show State", true)
local ui_show_portrait = menu_general:Switch("Use Hero Portrait", true)
local ui_smart_metric_colors = menu_general:Switch("Smart Metric Colors", true)

local menu_style = Menu.Create("Miscellaneous", "Utility", "Visuals", "Watermark", "Style")
local ui_sync_theme = menu_style:Switch("Sync With Menu Theme", true)
local ui_accent_color = menu_style:ColorPicker("Accent Color", Color(120, 190, 255, 255))
local ui_background_color = menu_style:ColorPicker("Background Color", Color(14, 18, 26, 170))
local ui_header_color = menu_style:ColorPicker("Header Color", Color(28, 36, 50, 195))

local menu_content = Menu.Create("Miscellaneous", "Utility", "Visuals", "Watermark", "Content")
local ui_show_hero = menu_content:Switch("Show Hero", true)
local ui_show_fps = menu_content:Switch("Show FPS", true)
local ui_show_ping = menu_content:Switch("Show Ping", true)
local ui_show_match_time = menu_content:Switch("Show Match Time", true)

local menu_position = Menu.Create("Miscellaneous", "Utility", "Visuals", "Watermark", "Position")
local ui_anchor_mode = menu_position:Combo("Anchor", { "Free", "Top Left", "Top Center", "Top Right" }, 1)
local ui_hud_x = menu_position:Slider("HUD X", 0, 3840, 24)
local ui_hud_y = menu_position:Slider("HUD Y", 0, 2160, 24)
local ui_anchor_off_x = menu_position:Slider("Anchor Offset X", -800, 800, 0)
local ui_anchor_off_y = menu_position:Slider("Anchor Offset Y", 0, 600, 24)
local ui_snap_distance = menu_position:Slider("Snap Distance", 4, 80, 18, "%d px")
local ui_layout_preset = menu_position:Combo("Layout Preset", { "Custom", "Full Glass", "Compact Top Bar", "Minimal Branding" }, 0)
local ui_apply_layout_preset = menu_position:Button("Apply Selected Preset", function() end)

local font_title = nil
local font_body = nil
local logo_image = nil
local portrait_cache = {}

local LAYOUT_FULL = 0
local LAYOUT_COMPACT = 1
local LAYOUT_MINIMAL = 2

local VISIBILITY_ALWAYS = 0
local VISIBILITY_HIDE_MENU = 1
local VISIBILITY_MATCH_ONLY = 2

local ANCHOR_FREE = 0
local ANCHOR_TOP_LEFT = 1
local ANCHOR_TOP_CENTER = 2
local ANCHOR_TOP_RIGHT = 3

local PRESET_CUSTOM = 0
local PRESET_FULL_GLASS = 1
local PRESET_COMPACT_TOP_BAR = 2
local PRESET_MINIMAL_BRANDING = 3

local HERO_PORTRAIT_ALIASES = {
    bookworm = { "bookworm", "bookwyrm", "paige" },
    bookwyrm = { "bookwyrm", "bookworm", "paige" },
    paige = { "paige", "bookworm", "bookwyrm" },
    graves = { "graves", "necro" },
    necro = { "necro", "graves" },
    bull = { "bull", "abrams" },
    abrams = { "abrams", "bull" },
    silver = { "silver", "werewolf" },
    werewolf = { "werewolf", "silver" },
    celeste = { "celeste" },
}

local HERO_PORTRAIT_PATHS = {
    "panorama/images/heroes/%s_sm_psd.vtex_c",
    "panorama/images/heroes/%s_sm_png.vtex_c",
    "panorama/images/heroes/%s_png.vtex_c",
    "panorama/images/heroes/%s.vtex_c",
    "panorama/images/heroes/icons/%s_png.vtex_c",
    "panorama/images/heroes/icons/%s.vtex_c",
}

local state = {
    last_refresh = -1.0,
    is_dragging = false,
    drag_offset = Vec2(0, 0),
    fade_started_at = 0.0,
    cached = {
        hero = "NONE",
        hero_slug = nil,
        hero_portrait = nil,
        fps = "--",
        ping = "--",
        match_time = "--:--",
        client_state = "IN CLIENT",
        in_match = false,
    },
}

local function update_style_widget_visibility()
    local manual_colors = not ui_sync_theme:Get()
    local anchor_free = ui_anchor_mode:Get() == ANCHOR_FREE
    local portrait_allowed = ui_show_hero:Get() and ui_layout_mode:Get() ~= LAYOUT_MINIMAL
    ui_accent_color:Visible(manual_colors)
    ui_background_color:Visible(manual_colors)
    ui_header_color:Visible(manual_colors)
    ui_hud_x:Visible(anchor_free)
    ui_hud_y:Visible(anchor_free)
    ui_anchor_off_x:Visible(not anchor_free)
    ui_anchor_off_y:Visible(not anchor_free)
    ui_show_portrait:Visible(portrait_allowed)
end

ui_sync_theme:SetCallback(update_style_widget_visibility, true)
ui_anchor_mode:SetCallback(update_style_widget_visibility, true)
ui_show_hero:SetCallback(update_style_widget_visibility, true)
ui_layout_mode:SetCallback(update_style_widget_visibility, true)
ui_enable:SetCallback(function(self)
    if self:Get() then
        state.fade_started_at = os.clock()
    else
        state.is_dragging = false
    end
end)

local function apply_layout_preset(preset)
    if preset == PRESET_FULL_GLASS then
        ui_layout_mode:Set(LAYOUT_FULL)
        ui_visibility_mode:Set(VISIBILITY_ALWAYS)
        ui_show_logo:Set(true)
        ui_show_state:Set(true)
        ui_show_portrait:Set(true)
        ui_show_hero:Set(true)
        ui_show_fps:Set(true)
        ui_show_ping:Set(true)
        ui_show_match_time:Set(true)
        ui_anchor_mode:Set(ANCHOR_TOP_LEFT)
        ui_anchor_off_x:Set(0)
        ui_anchor_off_y:Set(24)
        ui_scale:Set(1.0)
        ui_opacity:Set(85)
        ui_blur_strength:Set(5)
    elseif preset == PRESET_COMPACT_TOP_BAR then
        ui_layout_mode:Set(LAYOUT_COMPACT)
        ui_visibility_mode:Set(VISIBILITY_ALWAYS)
        ui_show_logo:Set(true)
        ui_show_state:Set(true)
        ui_show_portrait:Set(true)
        ui_show_hero:Set(true)
        ui_show_fps:Set(true)
        ui_show_ping:Set(true)
        ui_show_match_time:Set(true)
        ui_anchor_mode:Set(ANCHOR_TOP_CENTER)
        ui_anchor_off_x:Set(0)
        ui_anchor_off_y:Set(18)
        ui_scale:Set(0.95)
        ui_opacity:Set(88)
        ui_blur_strength:Set(4)
    elseif preset == PRESET_MINIMAL_BRANDING then
        ui_layout_mode:Set(LAYOUT_MINIMAL)
        ui_visibility_mode:Set(VISIBILITY_ALWAYS)
        ui_show_logo:Set(true)
        ui_show_state:Set(true)
        ui_show_portrait:Set(false)
        ui_show_hero:Set(false)
        ui_show_fps:Set(true)
        ui_show_ping:Set(true)
        ui_show_match_time:Set(true)
        ui_anchor_mode:Set(ANCHOR_TOP_RIGHT)
        ui_anchor_off_x:Set(0)
        ui_anchor_off_y:Set(18)
        ui_scale:Set(0.90)
        ui_opacity:Set(90)
        ui_blur_strength:Set(3)
    end

    update_style_widget_visibility()
end

ui_apply_layout_preset:SetCallback(function()
    local preset = ui_layout_preset:Get()
    if preset ~= PRESET_CUSTOM then
        apply_layout_preset(preset)
    end
end)

local function apply_widget_icons()
    if ui_enable.Icon then ui_enable:Icon("\u{f06e}") end

    if ui_layout_mode.Icon then ui_layout_mode:Icon("\u{f0db}") end
    if ui_visibility_mode.Icon then ui_visibility_mode:Icon("\u{f070}") end
    if ui_lock_position.Icon then ui_lock_position:Icon("\u{f023}") end
    if ui_blur_strength.Icon then ui_blur_strength:Icon("\u{f5fd}") end
    if ui_opacity.Icon then ui_opacity:Icon("\u{f043}") end
    if ui_scale.Icon then ui_scale:Icon("\u{f065}") end
    if ui_snap_edges.Icon then ui_snap_edges:Icon("\u{f0b2}") end
    if ui_show_logo.Icon then ui_show_logo:Icon("\u{f53f}") end
    if ui_show_state.Icon then ui_show_state:Icon("\u{f05a}") end
    if ui_show_portrait.Icon then ui_show_portrait:Icon("\u{f03e}") end
    if ui_smart_metric_colors.Icon then ui_smart_metric_colors:Icon("\u{f201}") end

    if ui_sync_theme.Icon then ui_sync_theme:Icon("\u{f53f}") end
    if ui_accent_color.Icon then ui_accent_color:Icon("\u{f53f}") end
    if ui_background_color.Icon then ui_background_color:Icon("\u{f111}") end
    if ui_header_color.Icon then ui_header_color:Icon("\u{f5fd}") end

    if ui_show_hero.Icon then ui_show_hero:Icon("\u{f2bd}") end
    if ui_show_fps.Icon then ui_show_fps:Icon("\u{f201}") end
    if ui_show_ping.Icon then ui_show_ping:Icon("\u{f1eb}") end
    if ui_show_match_time.Icon then ui_show_match_time:Icon("\u{f017}") end

    if ui_anchor_mode.Icon then ui_anchor_mode:Icon("\u{f5a0}") end
    if ui_hud_x.Icon then ui_hud_x:Icon("\u{f337}") end
    if ui_hud_y.Icon then ui_hud_y:Icon("\u{f338}") end
    if ui_anchor_off_x.Icon then ui_anchor_off_x:Icon("\u{f337}") end
    if ui_anchor_off_y.Icon then ui_anchor_off_y:Icon("\u{f338}") end
    if ui_snap_distance.Icon then ui_snap_distance:Icon("\u{f124}") end
    if ui_layout_preset.Icon then ui_layout_preset:Icon("\u{f1de}") end
    if ui_apply_layout_preset.Icon then ui_apply_layout_preset:Icon("\u{f00c}") end
end

apply_widget_icons()

local function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    end
    if value > max_value then
        return max_value
    end
    return value
end

local function round_to_int(value)
    if type(value) ~= "number" then
        return 0
    end
    return math.floor(value + 0.5)
end

local function color_with_opacity(color, opacity_scale)
    if not color then
        return Color(255, 255, 255, 255)
    end

    return Color(
        color.r or 255,
        color.g or 255,
        color.b or 255,
        clamp(math.floor((color.a or 255) * opacity_scale), 0, 255)
    )
end

local function color_with_alpha(color, alpha)
    if not color then
        return Color(255, 255, 255, clamp(alpha or 255, 0, 255))
    end

    return Color(
        color.r or 255,
        color.g or 255,
        color.b or 255,
        clamp(alpha or 255, 0, 255)
    )
end

local function mix_colors(a, b, weight, alpha_override)
    local t = clamp(weight or 0, 0, 1)
    local inv = 1 - t
    local ar = (a and a.r) or 255
    local ag = (a and a.g) or 255
    local ab = (a and a.b) or 255
    local aa = (a and a.a) or 255
    local br = (b and b.r) or 255
    local bg = (b and b.g) or 255
    local bb = (b and b.b) or 255
    local ba = (b and b.a) or 255

    return Color(
        clamp(math.floor(ar * inv + br * t + 0.5), 0, 255),
        clamp(math.floor(ag * inv + bg * t + 0.5), 0, 255),
        clamp(math.floor(ab * inv + bb * t + 0.5), 0, 255),
        clamp(alpha_override or math.floor(aa * inv + ba * t + 0.5), 0, 255)
    )
end

local function color_luminance(color)
    local function to_linear(channel)
        local value = clamp((channel or 0) / 255, 0, 1)
        if value <= 0.03928 then
            return value / 12.92
        end
        return ((value + 0.055) / 1.055) ^ 2.4
    end

    local r = to_linear(color and color.r or 0)
    local g = to_linear(color and color.g or 0)
    local b = to_linear(color and color.b or 0)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

local function contrast_ratio(a, b)
    local lum_a = color_luminance(a)
    local lum_b = color_luminance(b)
    if lum_a < lum_b then
        lum_a, lum_b = lum_b, lum_a
    end
    return (lum_a + 0.05) / (lum_b + 0.05)
end

local function choose_text_color(background)
    local light = Color(245, 248, 255, 255)
    local dark = Color(21, 25, 32, 255)
    if contrast_ratio(light, background) >= contrast_ratio(dark, background) then
        return light
    end
    return dark
end

local function ensure_contrast(color, background, preferred_text, min_ratio)
    local target_ratio = min_ratio or 2.2
    local candidate = Color(color.r or 255, color.g or 255, color.b or 255, color.a or 255)
    if contrast_ratio(candidate, background) >= target_ratio then
        return candidate
    end

    local text_anchor = preferred_text or choose_text_color(background)
    for _, weight in ipairs({0.18, 0.34, 0.5, 0.66, 0.82}) do
        local mixed = mix_colors(candidate, text_anchor, weight, candidate.a or 255)
        if contrast_ratio(mixed, background) >= target_ratio then
            return mixed
        end
    end

    return mix_colors(candidate, text_anchor, 0.82, candidate.a or 255)
end

local function style_color(style, key, fallback)
    local color = style and style[key]
    if color then
        return Color(color.r or fallback.r, color.g or fallback.g, color.b or fallback.b, color.a or fallback.a)
    end
    return Color(fallback.r, fallback.g, fallback.b, fallback.a)
end

local function resolve_theme_palette(opacity_scale)
    local accent = ui_accent_color:Get()
    local background = ui_background_color:Get()
    local header = ui_header_color:Get()
    local outline = Color(115, 135, 160, 255)
    local muted = Color(90, 108, 132, 255)
    local theme_text = Color(245, 248, 255, 255)

    if ui_sync_theme:Get() and Menu.Style then
        local ok, style = pcall(function()
            return Menu.Style()
        end)

        if ok and type(style) == "table" then
            accent = style_color(style, "primary", accent)
            background = style_color(style, "additional_background", background)
            outline = style_color(style, "outline", outline)
            muted = style_color(style, "slider_background", muted)
            theme_text = style_color(style, "primary_first_tab_text", theme_text)
            header = mix_colors(background, accent, 0.18, 255)
            header = mix_colors(header, outline, 0.20, 255)
        end
    end

    accent = color_with_opacity(accent, opacity_scale)
    background = color_with_opacity(background, opacity_scale)
    header = color_with_opacity(header, opacity_scale)
    outline = color_with_opacity(outline, opacity_scale)
    muted = color_with_opacity(muted, opacity_scale)
    theme_text = color_with_opacity(theme_text, opacity_scale)

    local primary_text = choose_text_color(background)
    if contrast_ratio(theme_text, background) > contrast_ratio(primary_text, background) then
        primary_text = Color(theme_text.r, theme_text.g, theme_text.b, primary_text.a)
    end

    local secondary_text = ensure_contrast(mix_colors(primary_text, background, 0.35, 255), background, primary_text, 3.0)
    local border = mix_colors(outline, accent, 0.30, clamp(math.floor(105 * opacity_scale), 40, 130))
    local pill_background = mix_colors(background, primary_text, 0.08, clamp(math.floor(34 * opacity_scale), 14, 52))
    local pill_border = mix_colors(outline, accent, 0.45, clamp(math.floor(82 * opacity_scale), 28, 110))
    local divider = ensure_contrast(accent, background, primary_text, 1.7)
    local label = ensure_contrast(mix_colors(accent, outline, 0.20, 255), pill_background, primary_text, 2.0)
    local badge_fill = mix_colors(accent, background, 0.18, clamp(math.floor(92 * opacity_scale), 48, 120))
    local badge_text = choose_text_color(badge_fill)
    local shadow = Color(0, 0, 0, clamp(math.floor(85 * opacity_scale), 18, 120))

    return {
        accent = accent,
        background = background,
        header = header,
        outline = outline,
        border = border,
        primary_text = primary_text,
        secondary_text = secondary_text,
        label = label,
        pill_background = pill_background,
        pill_border = pill_border,
        divider = divider,
        badge_fill = badge_fill,
        badge_text = badge_text,
        shadow = shadow,
    }
end

local function load_font(font_name, weight)
    local ok, handle = pcall(function()
        return Render.LoadFont(font_name, FONT_FLAGS, weight)
    end)

    if ok and type(handle) == "number" and handle > 0 then
        return handle
    end

    ok, handle = pcall(function()
        return Render.LoadFont("Verdana", FONT_FLAGS, weight)
    end)

    if ok and type(handle) == "number" and handle > 0 then
        return handle
    end

    return nil
end

local function load_image(paths)
    if type(paths) == "string" then
        paths = { paths }
    end

    for _, path in ipairs(paths or {}) do
        local ok, handle = pcall(function()
            return Render.LoadImage(path)
        end)

        if ok and type(handle) == "number" and handle > 0 then
            return handle
        end
    end

    return nil
end

local function ensure_fonts()
    if font_title and font_body then
        if not logo_image then
            logo_image = load_image(LOGO_IMAGE_CANDIDATES)
        end
        return true
    end

    font_title = font_title or load_font([[fonts\MuseoSansEx 500.ttf]], 700)
    font_body = font_body or load_font([[fonts\MuseoSansEx 500.ttf]], 600)
    logo_image = logo_image or load_image(LOGO_IMAGE_CANDIDATES)

    return font_title ~= nil and font_body ~= nil
end

local function sanitize_name(raw_name)
    if type(raw_name) ~= "string" or raw_name == "" then
        return "NONE"
    end

    local name = raw_name:gsub("\\", "/")
    name = name:match("([^/]+)$") or name
    name = name:gsub("%.[^%.]+$", "")
    name = name:gsub("^npc_dota_hero_", "")
    name = name:gsub("^hero_", "")
    name = name:gsub("^ability_", "")
    name = name:gsub("^C_NPC_Hero_", "")
    name = name:gsub("^C_CitadelPlayerPawn", "")
    name = name:gsub("^C_Citadel", "")
    name = name:gsub("^C_", "")
    name = name:gsub("^NPC_", "")
    name = name:gsub("_vdata$", "")
    name = name:gsub("_c$", "")
    name = name:gsub("_", " ")
    name = name:gsub("%s+", " ")
    name = name:gsub("^%s+", "")
    name = name:gsub("%s+$", "")
    name = string.upper(name)

    if name == "" then
        return "NONE"
    end

    local blocked = {
        ["PLAYERPAWN"] = true,
        ["PLAYER PAWN"] = true,
        ["CITADELPLAYERPAWN"] = true,
        ["CITADEL PLAYER PAWN"] = true,
        ["UNKNOWN"] = true,
        ["NONE"] = true,
    }

    if blocked[name] then
        return "NONE"
    end

    return name
end

local function normalize_slug(raw_name)
    if type(raw_name) ~= "string" or raw_name == "" then
        return nil
    end

    local name = raw_name:lower()
    name = name:gsub("\\", "/")
    name = name:match("([^/]+)$") or name
    name = name:gsub("%.[^%.]+$", "")
    name = name:gsub("^npc_dota_hero_", "")
    name = name:gsub("^hero_", "")
    name = name:gsub("^ability_", "")
    name = name:gsub("^c_npc_hero_", "")
    name = name:gsub("^c_citadelplayerpawn", "")
    name = name:gsub("^c_citadel", "")
    name = name:gsub("^c_", "")
    name = name:gsub("^npc_", "")
    name = name:gsub("_vdata$", "")
    name = name:gsub("_c$", "")
    name = name:gsub("%s+", "_")
    name = name:gsub("[^%w_]", "")
    name = name:gsub("_+", "_")
    name = name:gsub("^_+", "")
    name = name:gsub("_+$", "")

    if name == "" then
        return nil
    end

    local blocked = {
        playerpawn = true,
        citadelplayerpawn = true,
        unknown = true,
        none = true,
    }

    if blocked[name] then
        return nil
    end

    return name
end

local function append_unique(list, seen, value)
    if type(value) ~= "string" or value == "" then
        return
    end
    if seen[value] then
        return
    end

    seen[value] = true
    table.insert(list, value)
end

local function collect_local_hero_candidates()
    local pawn = entity_list.local_pawn()
    if not pawn or not pawn:valid() then
        return {}, {}
    end

    local display_candidates = {}
    local slug_candidates = {}
    local function push(list, value)
        if type(value) == "string" and value ~= "" then
            table.insert(list, value)
        end
    end

    pcall(function()
        local value = pawn:get_name()
        push(display_candidates, value)
        push(slug_candidates, value)
    end)
    pcall(function()
        local value = pawn:get_class_name()
        push(display_candidates, value)
        push(slug_candidates, value)
    end)
    pcall(function()
        local value = pawn:get_model_name()
        push(display_candidates, value)
        push(slug_candidates, value)
    end)

    pcall(function()
        local abilities = pawn:get_abilities()
        for _, ability in ipairs(abilities or {}) do
            if ability and ability.valid and ability:valid() then
                local ability_name = nil
                pcall(function()
                    ability_name = ability:get_name()
                end)
                push(slug_candidates, ability_name)
            end
        end
    end)

    return display_candidates, slug_candidates
end

local function get_local_hero_identity()
    local display_candidates, slug_candidates = collect_local_hero_candidates()
    local display_name = "NONE"
    local hero_slug = nil

    for _, candidate in ipairs(display_candidates) do
        local name = sanitize_name(candidate)
        if name ~= "NONE" then
            display_name = name
            break
        end
    end

    for _, candidate in ipairs(slug_candidates) do
        local normalized = normalize_slug(candidate)
        if normalized then
            hero_slug = normalized
            break
        end
    end

    if not hero_slug and display_name ~= "NONE" then
        hero_slug = normalize_slug(display_name)
    end

    return display_name, hero_slug
end

local function expand_hero_slug(value, list, seen)
    local normalized = normalize_slug(value)
    if not normalized then
        return
    end

    append_unique(list, seen, normalized)

    local prefix = normalized:match("^([%w]+)_")
    if prefix and not seen[prefix] then
        expand_hero_slug(prefix, list, seen)
    end

    local aliases = HERO_PORTRAIT_ALIASES[normalized]
    if aliases then
        for _, alias in ipairs(aliases) do
            if not seen[alias] then
                expand_hero_slug(alias, list, seen)
            end
        end
    end
end

local function build_hero_slug_candidates(hero_slug, display_name)
    local result = {}
    local seen = {}

    expand_hero_slug(hero_slug, result, seen)
    expand_hero_slug(display_name, result, seen)

    return result
end

local function resolve_hero_portrait(hero_slug, display_name)
    local slug_candidates = build_hero_slug_candidates(hero_slug, display_name)
    for _, slug in ipairs(slug_candidates) do
        local cached = portrait_cache[slug]
        if cached ~= nil then
            if cached then
                return cached, slug
            end
        else
            local paths = {}
            for _, template in ipairs(HERO_PORTRAIT_PATHS) do
                table.insert(paths, string.format(template, slug))
            end

            local portrait = load_image(paths)
            portrait_cache[slug] = portrait or false
            if portrait then
                return portrait, slug
            end
        end
    end

    return nil, hero_slug
end

local function format_match_time(seconds)
    if type(seconds) ~= "number" or seconds < 0 then
        return "--:--"
    end

    local total = math.floor(seconds)
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local secs = total % 60

    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    end

    return string.format("%02d:%02d", minutes, secs)
end

local function get_player_count()
    local players = entity_list.by_class_name("C_CitadelPlayerPawn")
    if not players then
        return 0
    end

    return #players
end

local function detect_client_state()
    local has_pawn = false
    local raw_time = nil
    local match_id = nil

    local pawn = entity_list.local_pawn()
    if pawn and pawn:valid() then
        has_pawn = true
    end

    pcall(function()
        raw_time = game_rules.game_time()
    end)
    pcall(function()
        match_id = game_rules.match_id()
    end)

    local player_count = 0
    if has_pawn or (type(raw_time) == "number" and raw_time > 0) or (type(match_id) == "number" and match_id > 0) then
        player_count = get_player_count()
    end

    if has_pawn and type(raw_time) == "number" and raw_time > 0 and player_count >= MIN_PLAYERS_FOR_MATCH then
        return "MATCH", true
    end

    if has_pawn and player_count > 0 and player_count < MIN_PLAYERS_FOR_MATCH then
        return "LOBBY", false
    end

    if has_pawn then
        return "LOBBY", false
    end

    if type(raw_time) == "number" and raw_time > 0 and type(match_id) == "number" and match_id > 0 then
        return "LOADING", false
    end

    if type(raw_time) == "number" and raw_time > 0 then
        return "IN CLIENT", false
    end

    return "MENU", false
end

local function refresh_cached_data(force)
    local now = os.clock()
    if not force and state.last_refresh >= 0 and (now - state.last_refresh) < REFRESH_INTERVAL then
        return
    end

    state.last_refresh = now

    local client_state, in_match = detect_client_state()

    local fps_value = "--"
    local frame_time = nil
    pcall(function()
        frame_time = global_vars.absoluteframetime()
    end)

    if type(frame_time) == "number" and frame_time > 0 then
        fps_value = tostring(clamp(math.floor(1 / frame_time), 0, 999))
    end

    local ping_value = "--"
    if net_channel and net_channel.latency then
        local latency = nil
        pcall(function()
            latency = net_channel.latency()
        end)

        if type(latency) == "number" and latency >= 0 then
            ping_value = tostring(clamp(round_to_int(latency * 1000), 0, 999))
        end
    end

    local match_value = "--:--"
    if in_match then
        local game_time = nil
        pcall(function()
            game_time = game_rules.game_time()
        end)
        match_value = format_match_time(game_time)
    end

    local hero_name, hero_slug = get_local_hero_identity()
    local hero_portrait = nil
    if hero_name ~= "NONE" and hero_slug then
        hero_portrait, hero_slug = resolve_hero_portrait(hero_slug, hero_name)
    end

    state.cached.hero = hero_name
    state.cached.hero_slug = hero_slug
    state.cached.hero_portrait = hero_portrait
    state.cached.fps = fps_value
    state.cached.ping = ping_value
    state.cached.match_time = match_value
    state.cached.client_state = client_state
    state.cached.in_match = in_match
end

local function build_pills(layout_mode)
    local pills = {}
    local allow_portrait = ui_show_portrait:Get() and layout_mode ~= LAYOUT_MINIMAL

    if ui_show_hero:Get() then
        local portrait_handle = allow_portrait and state.cached.hero_portrait or nil
        table.insert(pills, {
            key = "hero",
            label = "HERO",
            value = state.cached.hero,
            icon_kind = portrait_handle and nil or "hero",
            portrait = portrait_handle,
        })
    end
    if ui_show_fps:Get() then
        table.insert(pills, { key = "fps", label = "FPS", value = state.cached.fps, icon_kind = "fps" })
    end
    if ui_show_ping:Get() then
        table.insert(pills, { key = "ping", label = "PING", value = state.cached.ping, icon_kind = "ping" })
    end
    if ui_show_match_time:Get() then
        table.insert(pills, { key = "match", label = "MATCH", value = state.cached.match_time, icon_kind = "clock" })
    end

    return pills
end

local function draw_umbrella_logo(start_pos, size)
    local cx = start_pos.x + size.x / 2
    local cy = start_pos.y + size.y / 2
    local radius = math.min(size.x, size.y) * 0.44
    local inner = math.max(2, radius * 0.10)
    local red = Color(220, 36, 46, 255)
    local white = Color(245, 245, 245, 255)
    local outline = Color(15, 15, 18, 225)

    for i = 0, 5 do
        local a0 = math.rad(-90 + i * 60)
        local a1 = math.rad(-90 + (i + 1) * 60)
        local mid = math.rad(-90 + i * 60 + 30)
        local outer0 = Vec2(cx + math.cos(a0) * radius, cy + math.sin(a0) * radius)
        local outer1 = Vec2(cx + math.cos(a1) * radius, cy + math.sin(a1) * radius)
        local tip = Vec2(cx + math.cos(mid) * (radius * 0.92), cy + math.sin(mid) * (radius * 0.92))
        local color = (i % 2 == 0) and red or white

        Render.FilledTriangle({ Vec2(cx, cy), outer0, outer1 }, outline)
        Render.FilledTriangle({ Vec2(cx, cy), tip, outer1 }, outline)
        Render.FilledTriangle({
            Vec2(cx + math.cos(mid) * inner, cy + math.sin(mid) * inner),
            Vec2(outer0.x * 0.90 + cx * 0.10, outer0.y * 0.90 + cy * 0.10),
            Vec2(outer1.x * 0.90 + cx * 0.10, outer1.y * 0.90 + cy * 0.10),
        }, color)
    end
end

local function draw_pill_icon(kind, pos, size, color)
    local x = pos.x
    local y = pos.y
    local w = size
    local h = size
    local cx = x + w / 2
    local cy = y + h / 2
    local thick = math.max(1, size * 0.12)

    if kind == "hero" then
        Render.FilledCircle(Vec2(cx, y + h * 0.34), size * 0.18, color)
        Render.FilledRect(
            Vec2(x + w * 0.22, y + h * 0.56),
            Vec2(x + w * 0.78, y + h * 0.88),
            color,
            math.max(2, size * 0.18)
        )
        return
    end

    if kind == "fps" then
        local bar_w = math.max(1, size * 0.14)
        Render.FilledRect(Vec2(x + w * 0.18, y + h * 0.58), Vec2(x + w * 0.18 + bar_w, y + h * 0.84), color, 1)
        Render.FilledRect(Vec2(x + w * 0.42, y + h * 0.42), Vec2(x + w * 0.42 + bar_w, y + h * 0.84), color, 1)
        Render.FilledRect(Vec2(x + w * 0.66, y + h * 0.24), Vec2(x + w * 0.66 + bar_w, y + h * 0.84), color, 1)
        return
    end

    if kind == "ping" then
        local base_y = y + h * 0.82
        local bar_w = math.max(1, size * 0.12)
        Render.FilledRect(Vec2(x + w * 0.20, base_y - h * 0.18), Vec2(x + w * 0.20 + bar_w, base_y), color, 1)
        Render.FilledRect(Vec2(x + w * 0.40, base_y - h * 0.34), Vec2(x + w * 0.40 + bar_w, base_y), color, 1)
        Render.FilledRect(Vec2(x + w * 0.60, base_y - h * 0.50), Vec2(x + w * 0.60 + bar_w, base_y), color, 1)
        Render.FilledRect(Vec2(x + w * 0.80, base_y - h * 0.66), Vec2(x + w * 0.80 + bar_w, base_y), color, 1)
        return
    end

    if kind == "clock" then
        Render.Circle(Vec2(cx, cy), size * 0.34, color, thick, 0, 1, false, 24)
        Render.Line(Vec2(cx, cy), Vec2(cx, y + h * 0.30), color, thick)
        Render.Line(Vec2(cx, cy), Vec2(x + w * 0.70, cy), color, thick)
        Render.FilledCircle(Vec2(cx, cy), math.max(1, size * 0.06), color)
        return
    end

    if kind == "menu" then
        local line_h = math.max(1, size * 0.10)
        Render.FilledRect(Vec2(x + w * 0.22, y + h * 0.24), Vec2(x + w * 0.78, y + h * 0.24 + line_h), color, 1)
        Render.FilledRect(Vec2(x + w * 0.22, y + h * 0.45), Vec2(x + w * 0.78, y + h * 0.45 + line_h), color, 1)
        Render.FilledRect(Vec2(x + w * 0.22, y + h * 0.66), Vec2(x + w * 0.78, y + h * 0.66 + line_h), color, 1)
        return
    end

    if kind == "lobby" then
        local radius = math.max(1, size * 0.12)
        Render.FilledCircle(Vec2(x + w * 0.30, y + h * 0.38), radius, color)
        Render.FilledCircle(Vec2(x + w * 0.70, y + h * 0.38), radius, color)
        Render.FilledCircle(Vec2(x + w * 0.50, y + h * 0.26), radius, color)
        Render.FilledRect(Vec2(x + w * 0.20, y + h * 0.58), Vec2(x + w * 0.80, y + h * 0.78), color, math.max(1, size * 0.10))
        return
    end

    if kind == "loading" then
        Render.Circle(Vec2(cx, cy), size * 0.32, color, thick, 0.12, 0.92, false, 20)
        Render.FilledCircle(Vec2(x + w * 0.72, y + h * 0.34), math.max(1, size * 0.07), color)
        return
    end

    if kind == "client" then
        Render.Rect(
            Vec2(x + w * 0.20, y + h * 0.22),
            Vec2(x + w * 0.80, y + h * 0.62),
            color,
            math.max(1, size * 0.10),
            DRAW_NONE,
            thick
        )
        Render.FilledRect(Vec2(x + w * 0.40, y + h * 0.68), Vec2(x + w * 0.60, y + h * 0.75), color, 1)
        Render.FilledRect(Vec2(x + w * 0.30, y + h * 0.78), Vec2(x + w * 0.70, y + h * 0.84), color, 1)
        return
    end

    if kind == "match" then
        Render.Circle(Vec2(cx, cy), size * 0.30, color, thick, 0, 1, false, 18)
        Render.Line(Vec2(cx, y + h * 0.12), Vec2(cx, y + h * 0.28), color, thick)
        Render.Line(Vec2(cx, y + h * 0.72), Vec2(cx, y + h * 0.88), color, thick)
        Render.Line(Vec2(x + w * 0.12, cy), Vec2(x + w * 0.28, cy), color, thick)
        Render.Line(Vec2(x + w * 0.72, cy), Vec2(x + w * 0.88, cy), color, thick)
        Render.FilledCircle(Vec2(cx, cy), math.max(1, size * 0.08), color)
        return
    end

    Render.FilledCircle(Vec2(cx, cy), size * 0.18, color)
end

local function set_hud_position(x, y)
    ui_hud_x:Set(x)
    ui_hud_y:Set(y)
end

local function apply_free_snap(x, y, panel_w, panel_h, screen)
    if not ui_snap_edges:Get() then
        return x, y
    end

    local distance = math.max(4, ui_snap_distance:Get() or 18)
    local right_x = math.max(0, screen.x - panel_w)
    local bottom_y = math.max(0, screen.y - panel_h)

    if math.abs(x) <= distance then
        x = 0
    elseif math.abs(x - right_x) <= distance then
        x = right_x
    end

    if math.abs(y) <= distance then
        y = 0
    elseif math.abs(y - bottom_y) <= distance then
        y = bottom_y
    end

    return x, y
end

local function resolve_panel_position(panel_w, panel_h)
    local screen = Render.ScreenSize()
    local max_x = math.max(0, screen.x - panel_w - 2)
    local max_y = math.max(0, screen.y - panel_h - 2)
    local anchor_mode = ui_anchor_mode:Get()

    if anchor_mode == ANCHOR_TOP_LEFT then
        local x = 24 + (ui_anchor_off_x:Get() or 0)
        local y = ui_anchor_off_y:Get() or 24
        return clamp(round_to_int(x), 0, max_x), clamp(round_to_int(y), 0, max_y), screen
    end

    if anchor_mode == ANCHOR_TOP_CENTER then
        local x = math.floor((screen.x - panel_w) / 2) + (ui_anchor_off_x:Get() or 0)
        local y = ui_anchor_off_y:Get() or 24
        return clamp(round_to_int(x), 0, max_x), clamp(round_to_int(y), 0, max_y), screen
    end

    if anchor_mode == ANCHOR_TOP_RIGHT then
        local x = screen.x - panel_w - 24 + (ui_anchor_off_x:Get() or 0)
        local y = ui_anchor_off_y:Get() or 24
        return clamp(round_to_int(x), 0, max_x), clamp(round_to_int(y), 0, max_y), screen
    end

    local x = ui_hud_x:Get() or 24
    local y = ui_hud_y:Get() or 24
    return clamp(round_to_int(x), 0, max_x), clamp(round_to_int(y), 0, max_y), screen
end

local function should_draw_watermark()
    local visibility_mode = ui_visibility_mode:Get()
    if visibility_mode == VISIBILITY_MATCH_ONLY then
        return state.cached.in_match
    end
    if visibility_mode == VISIBILITY_HIDE_MENU then
        return state.cached.client_state ~= "MENU"
    end
    return true
end

local function resolve_state_badge_spec(palette)
    local text = state.cached.client_state
    local base_color = Color(110, 198, 255, 255)
    local icon_kind = "client"

    if text == "MATCH" then
        base_color = Color(96, 225, 160, 255)
        icon_kind = "match"
    elseif text == "LOBBY" then
        base_color = Color(166, 130, 255, 255)
        icon_kind = "lobby"
    elseif text == "MENU" then
        base_color = Color(126, 188, 255, 255)
        icon_kind = "menu"
    elseif text == "LOADING" then
        base_color = Color(255, 190, 96, 255)
        icon_kind = "loading"
    end

    base_color = mix_colors(base_color, palette.accent, 0.22, 255)
    local fill = color_with_alpha(mix_colors(palette.background, base_color, 0.22, 255), clamp((palette.badge_fill.a or 92) + 4, 44, 132))
    local border = color_with_alpha(
        ensure_contrast(mix_colors(base_color, palette.primary_text, 0.14, 255), fill, palette.primary_text, 2.0),
        clamp((palette.border.a or 105) + 8, 42, 150)
    )
    local text_color = choose_text_color(fill)
    local icon_color = ensure_contrast(base_color, fill, text_color, 2.0)

    return {
        text = text,
        icon_kind = icon_kind,
        fill = fill,
        border = border,
        text_color = text_color,
        icon_color = icon_color,
    }
end

local function resolve_pill_colors(pill, palette)
    local fill_color = palette.pill_background
    local border_color = palette.pill_border
    local label_color = palette.label
    local value_color = palette.primary_text
    local icon_color = palette.label
    local base_color = nil

    if pill.key == "hero" then
        base_color = mix_colors(palette.accent, palette.primary_text, 0.12, 255)
    elseif pill.key == "match" then
        if state.cached.in_match then
            base_color = Color(96, 225, 160, 255)
        else
            base_color = mix_colors(palette.secondary_text, palette.accent, 0.24, 255)
        end
    elseif ui_smart_metric_colors:Get() then
        local numeric_value = tonumber(pill.value)
        if pill.key == "fps" and numeric_value then
            if numeric_value >= 140 then
                base_color = Color(90, 220, 154, 255)
            elseif numeric_value >= 90 then
                base_color = Color(154, 228, 126, 255)
            elseif numeric_value >= 60 then
                base_color = Color(255, 204, 92, 255)
            else
                base_color = Color(255, 120, 120, 255)
            end
        elseif pill.key == "ping" and numeric_value then
            if numeric_value <= 35 then
                base_color = Color(92, 220, 186, 255)
            elseif numeric_value <= 70 then
                base_color = Color(154, 228, 126, 255)
            elseif numeric_value <= 120 then
                base_color = Color(255, 204, 92, 255)
            else
                base_color = Color(255, 120, 120, 255)
            end
        end
    end

    if base_color then
        base_color = ensure_contrast(base_color, fill_color, palette.primary_text, 2.0)
        fill_color = color_with_alpha(mix_colors(fill_color, base_color, 0.08, 255), fill_color.a or 34)
        border_color = color_with_alpha(mix_colors(border_color, base_color, 0.34, 255), clamp((border_color.a or 82) + 10, 30, 150))
        label_color = ensure_contrast(mix_colors(base_color, palette.primary_text, 0.16, 255), fill_color, palette.primary_text, 2.0)
        value_color = ensure_contrast(mix_colors(base_color, palette.primary_text, 0.32, 255), fill_color, palette.primary_text, 2.7)
        icon_color = ensure_contrast(base_color, fill_color, palette.primary_text, 2.1)
    end

    return fill_color, border_color, label_color, value_color, icon_color
end

local function prepare_pills(pills, layout_mode, scale, pill_height, pill_gap, pill_padding_x, pill_label_size, pill_value_size, pill_icon_size)
    local total_width = 0
    local label_gap = round_to_int(8 * scale)
    local media_gap = round_to_int(7 * scale)
    local show_labels = layout_mode ~= LAYOUT_MINIMAL

    for index, pill in ipairs(pills) do
        pill.show_label = show_labels
        pill.label_size = pill.show_label and Render.TextSize(font_body, pill_label_size, pill.label) or Vec2(0, 0)
        pill.value_size = Render.TextSize(font_body, pill_value_size, pill.value)
        if pill.portrait then
            pill.media_size = math.max(round_to_int(pill_height - 8), pill_icon_size + round_to_int(2 * scale))
        elseif pill.icon_kind then
            pill.media_size = pill_icon_size
        else
            pill.media_size = 0
        end

        local width = pill_padding_x * 2 + pill.value_size.x
        if pill.show_label then
            width = width + pill.label_size.x + label_gap
        end
        if pill.media_size > 0 then
            width = width + pill.media_size + media_gap
        end

        pill.width = width
        total_width = total_width + width
        if index < #pills then
            total_width = total_width + pill_gap
        end
    end

    return total_width
end

local function measure_badge(text, font_size, scale)
    local text_size = Render.TextSize(font_body, font_size, text)
    local icon_size = math.max(10, round_to_int(11 * scale))
    local height = math.max(round_to_int(18 * scale), text_size.y + round_to_int(8 * scale))
    local width = text_size.x + round_to_int(18 * scale) + icon_size + round_to_int(6 * scale)
    return width, height
end

local function draw_logo_block(position, box_size, logo_size, fill_color, border_color, scale)
    local rounding = math.max(5, round_to_int(6 * scale))
    local end_pos = Vec2(position.x + box_size, position.y + box_size)
    local image_pos = Vec2(
        position.x + math.floor((box_size - logo_size) / 2),
        position.y + math.floor((box_size - logo_size) / 2)
    )

    Render.FilledRect(position, end_pos, fill_color, rounding)
    Render.Rect(position, end_pos, border_color, rounding, DRAW_NONE, 1)
    if logo_image then
        Render.Image(logo_image, image_pos, Vec2(logo_size, logo_size), Color(255, 255, 255, 245), rounding - 1)
    else
        draw_umbrella_logo(image_pos, Vec2(logo_size, logo_size))
    end
end

local function draw_state_badge(position, size, badge, font_size, scale)
    local rounding = math.max(5, math.floor(size.y / 2))
    local padding_x = round_to_int(9 * scale)
    local gap = round_to_int(6 * scale)
    local text_size = Render.TextSize(font_body, font_size, badge.text)
    local icon_size = math.max(10, round_to_int(11 * scale))

    Render.FilledRect(position, position + size, badge.fill, rounding)
    Render.Rect(position, position + size, badge.border, rounding, DRAW_NONE, 1)

    local cursor_x = position.x + padding_x
    local icon_y = position.y + math.floor((size.y - icon_size) / 2)
    draw_pill_icon(badge.icon_kind, Vec2(cursor_x, icon_y), icon_size, badge.icon_color)
    cursor_x = cursor_x + icon_size + gap

    local text_y = position.y + math.floor((size.y - text_size.y) / 2)
    Render.Text(font_body, font_size, badge.text, Vec2(cursor_x, text_y), badge.text_color)
end

local function draw_pill(pill, position, pill_height, pill_rounding, pill_padding_x, scale, palette, pill_label_size, pill_value_size)
    local label_gap = round_to_int(8 * scale)
    local media_gap = round_to_int(7 * scale)
    local fill_color, border_color, label_color, value_color, icon_color = resolve_pill_colors(pill, palette)
    local pill_start = position
    local pill_end = Vec2(position.x + pill.width, position.y + pill_height)

    Render.FilledRect(pill_start, pill_end, fill_color, pill_rounding)
    Render.Rect(pill_start, pill_end, border_color, pill_rounding, DRAW_NONE, 1)

    local cursor_x = position.x + pill_padding_x
    if pill.portrait then
        local portrait_size = pill.media_size
        local portrait_y = position.y + math.floor((pill_height - portrait_size) / 2)
        local portrait_start = Vec2(cursor_x, portrait_y)
        local portrait_end = Vec2(cursor_x + portrait_size, portrait_y + portrait_size)
        local portrait_rounding = math.max(4, round_to_int(5 * scale))
        local portrait_fill = color_with_alpha(mix_colors(fill_color, palette.primary_text, 0.04, 255), clamp((fill_color.a or 34) + 8, 18, 68))
        local portrait_border = color_with_alpha(mix_colors(border_color, icon_color, 0.24, 255), clamp((border_color.a or 82) + 8, 32, 150))

        Render.FilledRect(portrait_start, portrait_end, portrait_fill, portrait_rounding)
        Render.Rect(portrait_start, portrait_end, portrait_border, portrait_rounding, DRAW_NONE, 1)
        Render.Image(
            pill.portrait,
            Vec2(portrait_start.x + 1, portrait_start.y + 1),
            Vec2(math.max(1, portrait_size - 2), math.max(1, portrait_size - 2)),
            Color(255, 255, 255, 245),
            portrait_rounding - 1
        )
        cursor_x = cursor_x + portrait_size + media_gap
    elseif pill.icon_kind then
        local icon_y = position.y + math.floor((pill_height - pill.media_size) / 2)
        draw_pill_icon(pill.icon_kind, Vec2(cursor_x, icon_y), pill.media_size, icon_color)
        cursor_x = cursor_x + pill.media_size + media_gap
    end

    if pill.show_label then
        local label_y = position.y + math.floor((pill_height - pill.label_size.y) / 2)
        Render.Text(font_body, pill_label_size, pill.label, Vec2(cursor_x, label_y), label_color)
        cursor_x = cursor_x + pill.label_size.x + label_gap
    end

    local value_y = position.y + math.floor((pill_height - pill.value_size.y) / 2)
    Render.Text(font_body, pill_value_size, pill.value, Vec2(cursor_x, value_y), value_color)
end

local function handle_drag(panel_x, panel_y, panel_w, panel_h, header_h)
    if ui_anchor_mode:Get() ~= ANCHOR_FREE or ui_lock_position:Get() then
        state.is_dragging = false
        return panel_x, panel_y
    end

    if not (Menu.Opened and Menu.Opened()) then
        if not input.is_down(KEY_MOUSE1) then
            state.is_dragging = false
        end
        return panel_x, panel_y
    end

    local cursor = input.cursor_pos()
    local screen = Render.ScreenSize()
    local header_start = Vec2(panel_x, panel_y)
    local header_end = Vec2(panel_x + panel_w, panel_y + header_h)

    if not state.is_dragging and input.is_pressed(KEY_MOUSE1) and input.cursor_in_bounds(header_start, header_end) then
        state.is_dragging = true
        state.drag_offset = Vec2(cursor.x - panel_x, cursor.y - panel_y)
    end

    if not state.is_dragging then
        return panel_x, panel_y
    end

    if not input.is_down(KEY_MOUSE1) then
        state.is_dragging = false
        return panel_x, panel_y
    end

    local max_x = math.max(0, screen.x - panel_w - 2)
    local max_y = math.max(0, screen.y - panel_h - 2)
    local new_x = clamp(math.floor(cursor.x - state.drag_offset.x), 0, max_x)
    local new_y = clamp(math.floor(cursor.y - state.drag_offset.y), 0, max_y)
    new_x, new_y = apply_free_snap(new_x, new_y, panel_w, panel_h, screen)

    set_hud_position(new_x, new_y)
    return new_x, new_y
end

local function draw_watermark()
    refresh_cached_data(false)
    if not should_draw_watermark() then
        state.is_dragging = false
        return
    end

    local layout_mode = ui_layout_mode:Get()
    local now = os.clock()
    local fade = clamp((now - (state.fade_started_at or 0.0)) / 0.30, 0, 1)
    local menu_open = Menu.Opened and Menu.Opened() or false
    local opacity_scale = clamp((ui_opacity:Get() or 85) / 100, 0.12, 1.0) * (0.28 + 0.72 * fade)
    local scale = clamp(ui_scale:Get() or 1.0, 0.75, 1.50)
    local pills = build_pills(layout_mode)
    local palette = resolve_theme_palette(opacity_scale)
    local state_badge = ui_show_state:Get() and resolve_state_badge_spec(palette) or nil
    local pulse = 0.5 + 0.5 * math.sin(now * 2.4)
    local glow_boost = state.is_dragging and 0.14 or (menu_open and 0.06 or 0.0)

    local panel_padding_x = round_to_int((layout_mode == LAYOUT_FULL and 12 or 10) * scale)
    local panel_padding_y = round_to_int((layout_mode == LAYOUT_FULL and 10 or 8) * scale)
    local panel_rounding = math.max(6, round_to_int(8 * scale))
    local header_height = layout_mode == LAYOUT_FULL and round_to_int(30 * scale) or round_to_int(28 * scale)
    local accent_height = math.max(2, round_to_int(2 * scale))
    local row_gap = round_to_int((layout_mode == LAYOUT_FULL and 10 or 8) * scale)
    local pill_gap = round_to_int(8 * scale)
    local pill_height = round_to_int((layout_mode == LAYOUT_MINIMAL and 22 or 24) * scale)
    local pill_rounding = math.max(5, round_to_int(7 * scale))
    local pill_padding_x = round_to_int(10 * scale)

    local title_size = math.max(14, round_to_int((layout_mode == LAYOUT_MINIMAL and 15 or 16) * scale))
    local subtitle_size = math.max(10, round_to_int(11 * scale))
    local badge_size = math.max(10, round_to_int(11 * scale))
    local pill_label_size = math.max(9, round_to_int(10 * scale))
    local pill_value_size = math.max(11, round_to_int(12 * scale))
    local pill_icon_size = math.max(10, round_to_int(12 * scale))
    local header_logo_size = round_to_int((layout_mode == LAYOUT_MINIMAL and 16 or 18) * scale)
    local header_logo_box = round_to_int((layout_mode == LAYOUT_MINIMAL and 22 or 24) * scale)
    local header_logo_gap = round_to_int(8 * scale)

    local background_color = palette.background
    local header_color = palette.header
    local border_color = palette.border
    local title_color = color_with_alpha(palette.primary_text, clamp(math.floor(245 * opacity_scale), 60, 255))
    local subtitle_color = color_with_alpha(palette.secondary_text, clamp(math.floor(222 * opacity_scale), 55, 255))
    local shadow_color = palette.shadow
    local pill_background = palette.pill_background
    local pill_border = palette.pill_border
    local divider_color = color_with_alpha(
        mix_colors(palette.divider, palette.accent, 0.18 + pulse * 0.10 + glow_boost, 255),
        clamp(math.floor((196 + pulse * 36) * opacity_scale), 72, 255)
    )
    local accent_glow = color_with_alpha(
        mix_colors(palette.accent, palette.primary_text, 0.18, 255),
        clamp(math.floor((54 + pulse * 28 + glow_boost * 140) * opacity_scale), 16, 120)
    )

    local title_text = "UMBRELLA"
    local subtitle_text = layout_mode == LAYOUT_MINIMAL and "" or "DEADLOCK"
    local show_logo = ui_show_logo:Get()
    local show_subtitle = subtitle_text ~= ""

    local title_size_vec = Render.TextSize(font_title, title_size, title_text)
    local subtitle_size_vec = show_subtitle and Render.TextSize(font_body, subtitle_size, subtitle_text) or Vec2(0, 0)
    local badge_width = 0
    local badge_height = 0
    if state_badge then
        badge_width, badge_height = measure_badge(state_badge.text, badge_size, scale)
    end

    local pills_total_width = prepare_pills(
        pills,
        layout_mode,
        scale,
        pill_height,
        pill_gap,
        pill_padding_x,
        pill_label_size,
        pill_value_size,
        pill_icon_size
    )

    local logo_width = show_logo and (header_logo_box + header_logo_gap) or 0
    local brand_width = logo_width + title_size_vec.x
    if show_subtitle then
        brand_width = brand_width + round_to_int(8 * scale) + subtitle_size_vec.x
    end

    local panel_width = 0
    local panel_height = 0
    local drag_height = 0
    if layout_mode == LAYOUT_FULL then
        local header_width = brand_width
        if state_badge then
            header_width = header_width + badge_width + round_to_int(20 * scale)
        end

        local content_width = math.max(header_width, pills_total_width)
        panel_width = math.max(round_to_int(290 * scale), content_width + panel_padding_x * 2)
        panel_height = header_height + panel_padding_y * 2
        if #pills > 0 then
            panel_height = panel_height + row_gap + pill_height
        end
        drag_height = header_height + panel_padding_y
    else
        local content_width = brand_width
        if #pills > 0 then
            content_width = content_width + round_to_int(14 * scale) + pills_total_width
        end
        if state_badge then
            content_width = content_width + round_to_int(12 * scale) + badge_width
        end

        local content_height = math.max(title_size_vec.y + round_to_int(4 * scale), #pills > 0 and pill_height or 0, badge_height, show_logo and header_logo_box or 0)
        panel_width = math.max(round_to_int((layout_mode == LAYOUT_MINIMAL and 220 or 250) * scale), content_width + panel_padding_x * 2)
        panel_height = content_height + panel_padding_y * 2
        drag_height = panel_height
    end

    local x, y = resolve_panel_position(panel_width, panel_height)
    x, y = handle_drag(x, y, panel_width, panel_height, drag_height)

    local start_pos = Vec2(x, y)
    local end_pos = Vec2(x + panel_width, y + panel_height)
    local header_end = Vec2(x + panel_width, y + (layout_mode == LAYOUT_FULL and (header_height + panel_padding_y) or panel_height))

    local blur_strength = ui_blur_strength:Get() or 0
    if blur_strength > 0 then
        Render.Blur(start_pos, end_pos, blur_strength, background_color.a, panel_rounding)
    end

    Render.Shadow(start_pos, end_pos, shadow_color, round_to_int(18 * scale), panel_rounding)
    Render.FilledRect(start_pos, end_pos, background_color, panel_rounding)
    Render.Rect(start_pos, end_pos, border_color, panel_rounding, DRAW_NONE, 1)
    Render.Gradient(
        start_pos,
        header_end,
        color_with_alpha(header_color, header_color.a),
        color_with_alpha(header_color, clamp(header_color.a - 15, 0, 255)),
        color_with_alpha(background_color, clamp(background_color.a - 35, 0, 255)),
        color_with_alpha(background_color, clamp(background_color.a - 45, 0, 255)),
        panel_rounding,
        DRAW_TOP
    )

    if layout_mode == LAYOUT_FULL then
        local accent_y = y + header_height + panel_padding_y - accent_height
        Render.FilledRect(Vec2(x, accent_y), Vec2(x + panel_width, accent_y + accent_height), divider_color, 0)
        Render.Shadow(
            Vec2(x + panel_padding_x, accent_y),
            Vec2(x + panel_width - panel_padding_x, accent_y + accent_height),
            accent_glow,
            round_to_int(10 * scale),
            0
        )

        local cursor_x = x + panel_padding_x
        if show_logo then
            draw_logo_block(Vec2(cursor_x, y + round_to_int(4 * scale)), header_logo_box, header_logo_size, pill_background, pill_border, scale)
            cursor_x = cursor_x + header_logo_box + header_logo_gap
        end

        local title_y = y + round_to_int(6 * scale)
        Render.Text(font_title, title_size, title_text, Vec2(cursor_x, title_y), title_color)

        if show_subtitle then
            local subtitle_x = cursor_x + title_size_vec.x + round_to_int(8 * scale)
            local subtitle_y = y + round_to_int(10 * scale)
            Render.Text(font_body, subtitle_size, subtitle_text, Vec2(subtitle_x, subtitle_y), subtitle_color)
        end

        if state_badge then
            local badge_x = x + panel_width - panel_padding_x - badge_width
            local badge_y = y + round_to_int((header_height - badge_height) / 2) + 1
            draw_state_badge(Vec2(badge_x, badge_y), Vec2(badge_width, badge_height), state_badge, badge_size, scale)
        end

        if #pills == 0 then
            return
        end

        local pill_y = accent_y + accent_height + row_gap
        local pill_x = x + panel_padding_x
        for _, pill in ipairs(pills) do
            draw_pill(pill, Vec2(pill_x, pill_y), pill_height, pill_rounding, pill_padding_x, scale, palette, pill_label_size, pill_value_size)
            pill_x = pill_x + pill.width + pill_gap
        end
        return
    end

    Render.FilledRect(start_pos, Vec2(x + panel_width, y + accent_height), divider_color, 0)
    Render.Shadow(Vec2(x + panel_padding_x, y), Vec2(x + panel_width - panel_padding_x, y + accent_height), accent_glow, round_to_int(9 * scale), 0)

    local content_y = y + panel_padding_y
    local center_y = y + math.floor(panel_height / 2)
    local cursor_x = x + panel_padding_x
    if show_logo then
        local logo_y = y + math.floor((panel_height - header_logo_box) / 2)
        draw_logo_block(Vec2(cursor_x, logo_y), header_logo_box, header_logo_size, pill_background, pill_border, scale)
        cursor_x = cursor_x + header_logo_box + header_logo_gap
    end

    local title_y = center_y - math.floor(title_size_vec.y / 2) - (show_subtitle and round_to_int(3 * scale) or 0)
    Render.Text(font_title, title_size, title_text, Vec2(cursor_x, title_y), title_color)
    local brand_end_x = cursor_x + title_size_vec.x

    if show_subtitle then
        local subtitle_x = brand_end_x + round_to_int(8 * scale)
        local subtitle_y = center_y - math.floor(subtitle_size_vec.y / 2) + round_to_int(4 * scale)
        Render.Text(font_body, subtitle_size, subtitle_text, Vec2(subtitle_x, subtitle_y), subtitle_color)
        brand_end_x = subtitle_x + subtitle_size_vec.x
    end

    local badge_x = state_badge and (x + panel_width - panel_padding_x - badge_width) or 0
    if state_badge then
        local badge_y = y + math.floor((panel_height - badge_height) / 2)
        draw_state_badge(Vec2(badge_x, badge_y), Vec2(badge_width, badge_height), state_badge, badge_size, scale)
    end

    if #pills == 0 then
        return
    end

    local pill_x = brand_end_x + round_to_int(14 * scale)
    local pill_y = content_y + math.floor((panel_height - panel_padding_y * 2 - pill_height) / 2)
    local pills_max_x = state_badge and (badge_x - round_to_int(12 * scale)) or (x + panel_width - panel_padding_x)
    if pill_x > pills_max_x then
        return
    end

    for _, pill in ipairs(pills) do
        if pill_x + pill.width > pills_max_x then
            break
        end
        draw_pill(pill, Vec2(pill_x, pill_y), pill_height, pill_rounding, pill_padding_x, scale, palette, pill_label_size, pill_value_size)
        pill_x = pill_x + pill.width + pill_gap
    end
end

local function on_scripts_loaded()
    ensure_fonts()
    state.fade_started_at = os.clock()
    refresh_cached_data(true)
    print(string.format("[%s] v%s loaded.", SCRIPT_NAME, SCRIPT_VERSION))
end

local function on_draw()
    if not ui_enable:Get() then
        state.is_dragging = false
        return
    end

    if not ensure_fonts() then
        return
    end

    draw_watermark()
end

callback.on_scripts_loaded:set(on_scripts_loaded)
callback.on_draw:set(on_draw)
