--[[
    Magnus Skewer Combo
    Hold bind: Catches priority (or flank), then Skewer to ally / set position.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "MagnusSkewerCombo"
local HERO_NAME = "npc_dota_hero_magnataur"
local ABILITY_SHOCKWAVE = "magnataur_shockwave"
local ABILITY_SKEWER = "magnataur_skewer"
local ABILITY_HORN_TOSS = "magnataur_horn_toss"
local ITEM_HARPOON = "item_harpoon"
local ORDER_ID = "MagnusSkewerCombo"
local CONFIG_FILE = "magnus_skewer_combo"

local CATCH_HARPOON = "item_harpoon"
local CATCH_HORN = "magnataur_horn_toss"
local CATCH_SHOCK = "magnataur_shockwave"

local UPDATE_INTERVAL = 0.03
local ALLY_SYNC_INTERVAL = 0.50
local ENEMY_SEARCH_RANGE = 3000
local MOVE_INTERVAL = 0.30
local BLINK_RANGE_FALLBACK = 1200
local HARPOON_RANGE_FALLBACK = 700
local HORN_RADIUS_FALLBACK = 325
local SKEWER_RANGE_FALLBACK = 900
local SKEWER_RADIUS_FALLBACK = 145
-- npc_abilities magnataur_shockwave: pull_distance 150, pull_duration 0.2, shock_speed 1200.
local SHOCK_PULL_DURATION_FALLBACK = 0.2
local SHOCK_SPEED_FALLBACK = 1200
local STAGE_TIMEOUT = 1.40
local SHOCK_PULL_WAIT = 0.30
local MARKER_RADIUS = 110
local SKEWER_FLANK_OFFSET = 100
-- Fallback if LIB_HEROES_DATA.particles_path_for_radius.Illuminate is missing.
local PARTICLE_ILLUMINATE_FALLBACK = "materials/ui_mouseed/range_display_illuminate.vpcf"

local MENU_FIRST = "Heroes"
local MENU_SECTION = "Hero List"
local MENU_SECOND = "Magnus"
local MENU_THIRD = "Main Settings"
local MENU_GROUP = "Skewer Combo"

local ICON_ENABLE = "\u{f00c}"
local ICON_PANEL = "\u{f108}"
local ICON_BIND = "\u{e1c1}"
local ICON_CATCHES = "\u{f890}"
local ICON_SET_POS = "\u{f3c5}"
local ICON_PANEL_FA = "\u{e54d}"
local ICON_SKEWER = "panorama/images/spellicons/magnataur_skewer_png.vtex_c"

local ICON_HARPOON = "panorama/images/items/harpoon_png.vtex_c"
local ICON_HORN = "panorama/images/spellicons/magnataur_horn_toss_png.vtex_c"
local ICON_SHOCK = "panorama/images/spellicons/magnataur_shockwave_png.vtex_c"

local BLINK_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

-- MultiSelect: positional { nameId, imagePath, isEnabled }. Left = higher priority (DragAllowed).
local CATCH_ITEMS = {
    { CATCH_HARPOON, ICON_HARPOON, true },
    { CATCH_HORN, ICON_HORN, true },
    { CATCH_SHOCK, ICON_SHOCK, true },
}

-- Enum.modifierState integers — never index Enum.modifierState at runtime.
local STATE_ROOTED = 0

local STAGE_IDLE = 0
local STAGE_APPROACH = 1
local STAGE_BLINK = 2
local STAGE_HARPOON = 3
local STAGE_HORN = 4
local STAGE_SHOCK_WAIT = 5
local STAGE_SKEWER = 6
local STAGE_FLANK = 7

local MODE_HARPOON = 1
local MODE_HORN = 2
local MODE_SHOCK = 3
local MODE_FLANK = 4

local Locale = {
    group_name = {
        en = "Skewer Combo",
        ru = "Skewer Combo",
        cn = "Skewer Combo",
    },
    panel_title = {
        en = "Skewer to Ally",
        ru = "Skewer to Ally",
        cn = "Skewer to Ally",
    },
    ui_enabled = {
        en = "Enable",
        ru = "Включить",
        cn = "启用",
    },
    ui_bind = {
        en = "Combo Bind",
        ru = "Бинд комбо",
        cn = "连招热键",
    },
    ui_catches = {
        en = "Catches",
        ru = "Catches",
        cn = "Catches",
    },
    ui_set_pos = {
        en = "Skewer Set Position",
        ru = "Skewer Set Position",
        cn = "Skewer Set Position",
    },
    ui_set_pos_color = {
        en = "Color",
        ru = "Цвет",
        cn = "颜色",
    },
    ui_show_panel = {
        en = "Show Panel",
        ru = "Показать панель",
        cn = "显示面板",
    },
    tip_enabled = {
        en = "Master switch for Magnus Skewer Combo.",
        ru = "Главный переключатель Skewer Combo для Magnus.",
        cn = "Magnus Skewer Combo 总开关。",
    },
    tip_bind = {
        en = "Hold: blink into catch range, use the first ready catch by Catches order, then Skewer to set position or selected ally.",
        ru = "Зажми: блинк в радиус catch, первый готовый catch по порядку Catches, затем Skewer к точке или выбранному союзнику.",
        cn = "按住：闪现到抓取范围，按 Catches 顺序使用第一个可用抓取，再向定点或所选友军穿刺。",
    },
    tip_catches = {
        en = "Catch icons. Left = higher priority. Drag to reorder, click to enable/disable.",
        ru = "Иконки catch. Левее — выше приоритет. Перетаскивай порядок, клик — вкл/выкл.",
        cn = "抓取图标。靠左优先级更高。拖动排序，点击开关。",
    },
    tip_set_pos = {
        en = "Press to place a Skewer destination at the cursor. Press again to clear. While set, Skewer uses only this point.",
        ru = "Нажми — поставить точку Skewer под курсором. Ещё раз — убрать. Пока точка есть, Skewer только в неё.",
        cn = "按下在光标处设置穿刺终点，再按清除。设置后只向该点穿刺。",
    },
    tip_set_pos_color = {
        en = "Illuminate marker color for the Skewer set position.",
        ru = "Цвет Illuminate-маркера точки Skewer.",
        cn = "穿刺定点 Illuminate 标记颜色。",
    },
    tip_show_panel = {
        en = "Ally HUD. LMB: add/remove Skewer targets (order = priority). RMB: make #1. Used when no set position is active. Drag header to move.",
        ru = "Панель союзников. ЛКМ: добавить/убрать цель Skewer (порядок = приоритет). ПКМ: сделать №1. Если точка не задана. Тяни за заголовок.",
        cn = "友军面板。左键添加/移除穿刺目标（顺序=优先级）。右键设为第1。未设置定点时生效。拖动标题栏可移动。",
    },
}

local PANEL_HEADER_HEIGHT = 30
local PANEL_HEADER_PAD_X = 8
local PANEL_HEADER_TEXT_SIZE = 15
local PANEL_HEADER_ICON_SIZE = 14
local PANEL_HEADER_ICON_GAP = 6
local PANEL_HEADER_RADIUS = 5
local PANEL_BODY_PAD_Y = 6
local PANEL_CELL_W = 44
local PANEL_CELL_H = 26
local PANEL_CELL_SPACING = 6
local PANEL_CELL_RADIUS = 3
local PANEL_CHIP_ENABLED_ALPHA = 255
local PANEL_CHIP_DISABLED_ALPHA = 105
local PANEL_CHIP_MIN_BORDER_LUMA = 70
local PANEL_CHIP_BORDER_THICKNESS = 1.35
local PANEL_MIN_WIDTH = 110
local PANEL_BLUR_BASE_STRENGTH = 2.5
local PANEL_SHADOW_THICKNESS = 14
local PANEL_CHIP_TOGGLE_SPEED = 10
local PANEL_PRIORITY_TEXT_SIZE = 11
local ALLY_PRIORITY_SEP = ","
local ALLY_PRIORITY_MAX = 5

local STYLE_KEYS = {
    "active_widgets_text", "additional_background", "button_active_background",
    "button_background", "combo_frame", "combo_item", "combo_item_active",
    "disabled_switch_background", "disabled_switch_circle", "enabled_switch_background",
    "group_background", "group_outline", "healthbar_ally", "healthbar_enemy",
    "healthbar_roshan", "healthbar_self", "hero_tab_filter_background",
    "hero_tab_filter_separator", "indication_active", "indication_inactive",
    "input_text_bg", "keybind_background", "keybind_background_active",
    "left_tabs_background", "main_background", "manabar", "multiselect_item",
    "multiselect_item_selected", "outline", "popup_background", "popup_border",
    "primary", "primary_first_tab_text", "primary_second_tab_text",
    "primary_widgets_text", "scrollbar_bg", "search_outline", "search_text",
    "section_group_text", "selected_tabs_background", "separator", "shadow",
    "slider_background", "slider_background_active", "slider_grab",
    "slider_grab_active", "text_shadow", "third_tab_text", "widgets_shadow",
}
--#endregion

--#region State
---@class MagnusSkewerComboUI
---@field enabled CMenuSwitch|nil
---@field bind CMenuBind|nil
---@field catches CMenuMultiSelect|nil
---@field setPosBind CMenuBind|nil
---@field setPosColor CMenuColorPickerAttachment|nil
---@field showPanel CMenuSwitch|nil
local UI = {
    enabled = nil,
    bind = nil,
    catches = nil,
    setPosBind = nil,
    setPosColor = nil,
    showPanel = nil,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    ---@type integer|nil
    font = nil,
    ---@type integer|nil
    faFont = nil,
    ---@type table<string, integer>
    heroIcons = {},
    ---@type CMenuSliderInt|CMenuSliderFloat|nil
    blurFactor = nil,
    ---@type CMenuGroup|nil
    menuGroup = nil,
    languageWidget = nil,
    languageLookupAt = 0,
    lastLanguage = nil,
    languageCallbackSet = false,
}

local Style = {}

local Colors = {
    HeaderBg = Color(18, 18, 22, 255),
    TextHeader = Color(245, 247, 250, 255),
    TextShadow = Color(0, 0, 0, 140),
    Primary = Color(180, 180, 190, 255),
    BorderEnabled = Color(180, 180, 190, 255),
    CellBg = Color(12, 12, 16, 255),
    Shadow = Color(0, 0, 0, 160),
}

local PanelConfig = { X = 220, Y = 240 }
local PanelDrag = { IsDragging = false, OffsetX = 0, OffsetY = 0 }

local Runtime = {
    lastUpdateAt = -math.huge,
    lastAllySyncAt = -math.huge,
    lastPanelDrawAt = -math.huge,
    wasMousePressed = false,
    wasMouse2Pressed = false,
    ---@type string[] clean hero names, index 1 = highest Skewer priority
    allyPriority = {},
    ---@type table<string, number>
    chipVisual = {},
    ---@type string[]
    allyNames = {},
    ---@type table<string, string>
    allyUnitNames = {},
    stage = STAGE_IDLE,
    stageAt = -math.huge,
    mode = 0,
    blinkStandDist = 0,
    lastMoveAt = -math.huge,
    shockWait = 0,
    ---@type Vector|nil
    skewerPoint = nil,
    ---@type integer|nil
    markerParticle = nil,
    ---@type integer|nil
    enemyIndex = nil,
    ---@type integer|nil
    allyIndex = nil,
}
--#endregion

--#region Helpers
local function GetLanguageWidget()
    local now = os.clock()
    if Persistent.languageWidget and now < Persistent.languageLookupAt then
        return Persistent.languageWidget
    end

    Persistent.languageLookupAt = now + 1.0
    Persistent.languageWidget = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
    return Persistent.languageWidget
end

local function GetLanguageCode()
    local widget = GetLanguageWidget()
    local value = widget and widget:Get() or "en"

    if type(value) == "number" then
        if value == 1 then
            return "ru"
        end
        if value == 2 then
            return "cn"
        end
        return "en"
    end

    value = tostring(value or "en"):lower()
    if value == "ru" or value:find("рус", 1, true) or value:find("russian", 1, true) then
        return "ru"
    end
    if value == "cn"
        or value == "zh"
        or value:find("chinese", 1, true)
        or value:find("中文", 1, true)
        or value:find("中国", 1, true)
        or value:find("简体", 1, true) then
        return "cn"
    end
    return "en"
end

local function L(key)
    local entry = Locale[key]
    if not entry then
        return tostring(key)
    end
    local lang = GetLanguageCode()
    return entry[lang] or entry.en or tostring(key)
end

local function MenuLabel(widget, key)
    if widget then
        widget:ForceLocalization(L(key))
    end
end

local function MenuTip(widget, key)
    if not widget then
        return
    end
    -- Stub declares ToolTip; some host builds leave the method nil.
    local tip = widget.ToolTip
    if type(tip) ~= "function" then
        return
    end
    tip(widget, L(key))
end

local function ApplyLocalization(force)
    local lang = GetLanguageCode()
    if not force and Persistent.lastLanguage == lang then
        return
    end
    Persistent.lastLanguage = lang

    MenuLabel(Persistent.menuGroup, "group_name")
    MenuLabel(UI.enabled, "ui_enabled")
    MenuTip(UI.enabled, "tip_enabled")
    MenuLabel(UI.bind, "ui_bind")
    MenuTip(UI.bind, "tip_bind")
    MenuLabel(UI.catches, "ui_catches")
    MenuTip(UI.catches, "tip_catches")
    MenuLabel(UI.setPosBind, "ui_set_pos")
    MenuTip(UI.setPosBind, "tip_set_pos")
    MenuLabel(UI.setPosColor, "ui_set_pos_color")
    MenuTip(UI.setPosColor, "tip_set_pos_color")
    MenuLabel(UI.showPanel, "ui_show_panel")
    MenuTip(UI.showPanel, "tip_show_panel")
end

local function SetupLanguageCallback()
    if Persistent.languageCallbackSet then
        return
    end

    local widget = GetLanguageWidget()
    if not widget then
        return
    end

    Persistent.languageCallbackSet = true
    local previous = widget:Get()
    widget:SetCallback(function(ctrl)
        local current = (ctrl or widget):Get()
        if current == previous then
            return
        end
        previous = current
        Persistent.lastLanguage = nil
        ApplyLocalization(true)
    end)
end

local function DestroySkewerMarker()
    if Runtime.markerParticle and Runtime.markerParticle ~= 0 then
        Particle.Destroy(Runtime.markerParticle)
    end
    Runtime.markerParticle = nil
end

local function ClearSkewerPoint()
    DestroySkewerMarker()
    Runtime.skewerPoint = nil
end

local function AbortCombo()
    Runtime.stage = STAGE_IDLE
    Runtime.stageAt = -math.huge
    Runtime.mode = 0
    Runtime.blinkStandDist = 0
    Runtime.lastMoveAt = -math.huge
    Runtime.shockWait = 0
    Runtime.enemyIndex = nil
    Runtime.allyIndex = nil
end

local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastAllySyncAt = -math.huge
    Runtime.lastPanelDrawAt = -math.huge
    Runtime.wasMousePressed = false
    Runtime.wasMouse2Pressed = false
    Runtime.chipVisual = {}
    Runtime.allyNames = {}
    Runtime.allyUnitNames = {}
    ClearSkewerPoint()
    AbortCombo()
    PanelDrag.IsDragging = false
end

local function ChannelByte(value)
    if type(value) ~= "number" then
        return nil
    end
    if value <= 1 then
        return math.floor(value * 255 + 0.5)
    end
    return math.floor(value + 0.5)
end

local function NormalizeThemeColor(value)
    if value == nil then
        return nil
    end
    local r = ChannelByte(value.r)
    local g = ChannelByte(value.g)
    local b = ChannelByte(value.b)
    local a = ChannelByte(value.a)
    if not r or not g or not b then
        return nil
    end
    return Color(r, g, b, a or 255)
end

local function TryGetThemeColor(key, all)
    local normalized = NormalizeThemeColor(Menu.Style(key))
    if normalized then
        return normalized
    end
    if type(all) == "table" then
        return NormalizeThemeColor(all[key])
    end
    return nil
end

local function ColorLuminance(color)
    if not color then
        return 0
    end
    return 0.299 * (color.r or 0) + 0.587 * (color.g or 0) + 0.114 * (color.b or 0)
end

local function SyncColors()
    local all = Menu.Style()
    for i = 1, #STYLE_KEYS do
        local key = STYLE_KEYS[i]
        Style[key] = TryGetThemeColor(key, all)
    end
    if type(all) == "table" then
        for key, _ in pairs(all) do
            if Style[key] == nil then
                Style[key] = TryGetThemeColor(key, all)
            end
        end
    end

    Colors.HeaderBg = Style.additional_background
        or Style.popup_background
        or Style.main_background
        or Style.group_background
        or Colors.HeaderBg
    Colors.TextHeader = Style.primary_widgets_text
        or Style.active_widgets_text
        or Colors.TextHeader

    if Style.primary then
        Colors.Primary = Color(Style.primary.r, Style.primary.g, Style.primary.b, 255)
        Colors.BorderEnabled = Colors.Primary
    end

    local cellBg = Style.group_background
        or Style.button_background
        or Style.combo_frame
        or Style.input_text_bg
    if cellBg then
        Colors.CellBg = Color(cellBg.r, cellBg.g, cellBg.b, 255)
    end

    if Style.shadow and (Style.shadow.a or 0) > 0 then
        Colors.Shadow = Style.shadow
    else
        Colors.Shadow = Color(0, 0, 0, 0)
    end

    if Style.text_shadow and (Style.text_shadow.a or 0) > 0 then
        Colors.TextShadow = Style.text_shadow
    else
        Colors.TextShadow = Color(0, 0, 0, 140)
    end
end

local function GetChipBorderColor()
    local primary = Colors.Primary
    if ColorLuminance(primary) >= PANEL_CHIP_MIN_BORDER_LUMA then
        return Color(primary.r, primary.g, primary.b, 255)
    end
    local text = Colors.TextHeader
    return Color(text.r, text.g, text.b, 255)
end

local function ResolveFont()
    if type(LIB_RENDER) == "table" then
        local libFont = LIB_RENDER.default_font
        if type(libFont) == "number" and libFont ~= 0 then
            local size = Render.TextSize(libFont, PANEL_HEADER_TEXT_SIZE, L("panel_title"))
            if size and (size.x or 0) > 0 and (size.y or 0) > 0 then
                return libFont
            end
        end
    end

    local aa = Enum.FontCreate.FONTFLAG_ANTIALIAS
    local candidates = {
        { "Segoe UI Semibold", aa, Enum.FontWeight.SEMIBOLD },
        { "Segoe UI", aa, Enum.FontWeight.SEMIBOLD },
        { "Bahnschrift", aa, Enum.FontWeight.SEMIBOLD },
        { "Verdana", aa, Enum.FontWeight.BOLD },
        { "Tahoma", aa, Enum.FontWeight.BOLD },
        { "Arial", aa, Enum.FontWeight.BOLD },
    }
    for i = 1, #candidates do
        local c = candidates[i]
        local font = Render.LoadFont(c[1], c[2], c[3])
        if font and font ~= 0 then
            local size = Render.TextSize(font, PANEL_HEADER_TEXT_SIZE, L("panel_title"))
            if size and (size.x or 0) > 0 and (size.y or 0) > 0 then
                return font
            end
        end
    end
    return nil
end

local function MeasureText(font, fontSize, text)
    if not font or font == 0 then
        return Vec2(#text * fontSize * 0.55, fontSize)
    end
    local size = Render.TextSize(font, fontSize, text)
    if size and type(size.x) == "number" and type(size.y) == "number" then
        return size
    end
    return Vec2(#text * fontSize * 0.55, fontSize)
end

local function ResolvePanelFaFont()
    if Persistent.faFont and Persistent.faFont ~= 0 then
        return Persistent.faFont
    end
    if type(LIB_RENDER) ~= "table" then
        return nil
    end
    local font = LIB_RENDER.default_font_awesome
    if type(font) == "number" and font ~= 0 then
        Persistent.faFont = font
        return font
    end
    return nil
end

local function DrawPanelFaIcon(x, y, scale)
    local font = ResolvePanelFaFont()
    if not font then
        return 0, 0
    end
    local fontSize = math.floor(PANEL_HEADER_ICON_SIZE * scale + 0.5)
    local size = Render.TextSize(font, fontSize, ICON_PANEL_FA)
    local w = (size and size.x) or fontSize
    local h = (size and size.y) or fontSize
    local shadow = Colors.TextShadow
    if shadow and (shadow.a or 0) > 0 then
        Render.Text(font, fontSize, ICON_PANEL_FA, Vec2(x + 1, y + 1), shadow)
    end
    Render.Text(font, fontSize, ICON_PANEL_FA, Vec2(x, y), Colors.Primary)
    return w, h
end

local function LoadPanelPosition()
    if type(Config) ~= "table" or type(Config.ReadInt) ~= "function" then
        return
    end
    local x = Config.ReadInt(CONFIG_FILE, "panel_x", 220)
    local y = Config.ReadInt(CONFIG_FILE, "panel_y", 240)
    if type(x) == "number" then
        PanelConfig.X = x
    end
    if type(y) == "number" then
        PanelConfig.Y = y
    end
end

local function SavePanelPosition()
    if type(Config) ~= "table" or type(Config.WriteInt) ~= "function" then
        return
    end
    -- WriteInt creates/flushes configs/<name>.ini when the host supports Config.
    Config.WriteInt(CONFIG_FILE, "panel_saved", 1)
    Config.WriteInt(CONFIG_FILE, "panel_x", math.floor(PanelConfig.X + 0.5))
    Config.WriteInt(CONFIG_FILE, "panel_y", math.floor(PanelConfig.Y + 0.5))
end

local function LoadAllyPriority()
    local list = {}
    if type(Config) == "table" and type(Config.ReadInt) == "function" then
        local count = Config.ReadInt(CONFIG_FILE, "ally_priority_count", 0)
        if type(count) == "number" and count > 0 then
            local getName = Engine and Engine.GetHeroNameByID
            for i = 1, math.min(count, ALLY_PRIORITY_MAX) do
                local heroId = Config.ReadInt(CONFIG_FILE, "ally_p" .. i, 0)
                if type(heroId) == "number" and heroId > 0 and type(getName) == "function" then
                    local unitName = getName(heroId)
                    if type(unitName) == "string" and unitName ~= "" then
                        local clean = unitName:gsub("^npc_dota_hero_", "")
                        if clean ~= "" then
                            list[#list + 1] = clean
                        end
                    end
                end
            end
        end
    end

    if #list == 0 and type(Config) == "table" and type(Config.ReadString) == "function" then
        local raw = Config.ReadString(CONFIG_FILE, "ally_priority", "")
        if type(raw) == "string" and raw ~= "" then
            for name in string.gmatch(raw, "([^" .. ALLY_PRIORITY_SEP .. "]+)") do
                if name ~= "" then
                    list[#list + 1] = name
                end
            end
        end
    end

    Runtime.allyPriority = list
end

local function SaveAllyPriority()
    SavePanelPosition()
    if type(Config) ~= "table" or type(Config.WriteInt) ~= "function" then
        return
    end

    local list = Runtime.allyPriority
    local count = math.min(#list, ALLY_PRIORITY_MAX)
    Config.WriteInt(CONFIG_FILE, "ally_priority_count", count)

    local getId = Engine and Engine.GetHeroIDByName
    for i = 1, ALLY_PRIORITY_MAX do
        local heroId = 0
        if i <= count and type(getId) == "function" then
            local id = getId("npc_dota_hero_" .. list[i])
            if type(id) == "number" and id > 0 then
                heroId = id
            end
        end
        Config.WriteInt(CONFIG_FILE, "ally_p" .. i, heroId)
    end

    if type(Config.WriteString) == "function" then
        Config.WriteString(CONFIG_FILE, "ally_priority", table.concat(list, ALLY_PRIORITY_SEP))
    end
end

local function AllyPriorityIndex(cleanName)
    local list = Runtime.allyPriority
    for i = 1, #list do
        if list[i] == cleanName then
            return i
        end
    end
    return nil
end

local function RemoveAllyPriority(cleanName)
    local list = Runtime.allyPriority
    for i = #list, 1, -1 do
        if list[i] == cleanName then
            table.remove(list, i)
        end
    end
end

local function ToggleAllyPriority(cleanName)
    if AllyPriorityIndex(cleanName) then
        RemoveAllyPriority(cleanName)
    else
        Runtime.allyPriority[#Runtime.allyPriority + 1] = cleanName
    end
    SaveAllyPriority()
end

local function PromoteAllyPriority(cleanName)
    RemoveAllyPriority(cleanName)
    table.insert(Runtime.allyPriority, 1, cleanName)
    SaveAllyPriority()
end

local function GetBlurStrength()
    local widget = Persistent.blurFactor
    if not widget then
        return PANEL_BLUR_BASE_STRENGTH
    end
    local factor = widget:Get()
    if type(factor) ~= "number" or factor <= 0 then
        return nil
    end
    if factor > 1 then
        factor = factor / 100
    end
    return math.max(0.1, factor * PANEL_BLUR_BASE_STRENGTH)
end

local function SyncOptionDisabled()
    local masterOff = UI.enabled == nil or UI.enabled:Get() ~= true
    if UI.bind then UI.bind:Disabled(masterOff) end
    if UI.catches then UI.catches:Disabled(masterOff) end
    if UI.setPosBind then UI.setPosBind:Disabled(masterOff) end
    if UI.setPosColor then UI.setPosColor:Disabled(masterOff) end
    if UI.showPanel then UI.showPanel:Disabled(masterOff) end
end

local function OnEnabledChanged(widget)
    SyncOptionDisabled()
    if not widget:Get() then
        ResetRuntime()
    end
end

local function ResolveIlluminatePath()
    if type(LIB_HEROES_DATA) == "table" then
        local paths = LIB_HEROES_DATA.particles_path_for_radius
        if type(paths) == "table" then
            local path = paths.Illuminate or paths["Illuminate"]
            if type(path) == "string" and path ~= "" then
                return path
            end
        end
    end
    return PARTICLE_ILLUMINATE_FALLBACK
end

local function MarkerColorRgb()
    local color = UI.setPosColor and UI.setPosColor:Get() or nil
    if color and type(color.r) == "number" then
        return color.r or 255, color.g or 200, color.b or 80
    end
    return 120, 200, 255
end

local function ApplyMarkerControlPoints(index, pos)
    if not index or index == 0 or not pos then
        return
    end
    local r, g, b = MarkerColorRgb()
    Particle.SetControlPoint(index, 0, pos)
    Particle.SetControlPoint(index, 1, Vector(r, g, b))
    Particle.SetControlPoint(index, 2, Vector(MARKER_RADIUS, 255, 255))
end

local function CreateSkewerMarker(pos)
    DestroySkewerMarker()
    local path = ResolveIlluminatePath()
    local owner = Heroes.GetLocal() or Players.GetLocal()
    local index = Particle.Create(path, Enum.ParticleAttachment.PATTACH_WORLDORIGIN, owner)
    if not index or index == 0 then
        return
    end
    ApplyMarkerControlPoints(index, pos)
    Runtime.markerParticle = index
    Runtime.skewerPoint = pos:Clone()
end

local function RefreshSkewerMarker()
    local pos = Runtime.skewerPoint
    if not pos then
        return
    end
    if not Runtime.markerParticle or Runtime.markerParticle == 0 then
        CreateSkewerMarker(pos)
        return
    end
    ApplyMarkerControlPoints(Runtime.markerParticle, pos)
end

local function OnSetPosColorChanged()
    RefreshSkewerMarker()
end

local function UpdateSetPositionBind()
    if not UI.setPosBind or UI.setPosBind:IsPressed() ~= true then
        return
    end
    if Input.IsInputCaptured() == true or Input.IsPopupOpen() == true then
        return
    end
    if Runtime.skewerPoint then
        ClearSkewerPoint()
        return
    end
    local world = Input.GetWorldCursorPos()
    if world then
        CreateSkewerMarker(world)
    end
end

local function CleanHeroName(unitName)
    if not unitName or unitName == "" then
        return ""
    end
    return (unitName:gsub("^npc_dota_hero_", ""))
end

---@param unit userdata|nil
---@return boolean
local function IsValidUnit(unit)
    if unit == nil then
        return false
    end
    return Entity.IsAlive(unit) == true
        and Entity.IsDormant(unit) ~= true
        and NPC.IsVisible(unit) == true
        and NPC.IsIllusion(unit) ~= true
end

local function GetHeroIcon(unitName)
    if not unitName or unitName == "" then
        return nil
    end
    local cached = Persistent.heroIcons[unitName]
    if cached then
        return cached
    end
    local handle = Render.LoadImage("panorama/images/heroes/" .. unitName .. "_png.vtex_c")
    if handle and handle ~= 0 then
        Persistent.heroIcons[unitName] = handle
        return handle
    end
    return nil
end

local function UpdateChipVisual(cleanName, selected, dt)
    local target = selected and 1 or 0
    local cur = Runtime.chipVisual[cleanName]
    if cur == nil then
        Runtime.chipVisual[cleanName] = target
        return target
    end
    if dt <= 0 then
        return cur
    end
    local step = dt * PANEL_CHIP_TOGGLE_SPEED
    if cur < target then
        cur = math.min(target, cur + step)
    elseif cur > target then
        cur = math.max(target, cur - step)
    end
    Runtime.chipVisual[cleanName] = cur
    return cur
end

local function EaseChipVisual(t)
    return t * t * (3 - 2 * t)
end

local function FindBlinkItem(me)
    for i = 1, #BLINK_ITEMS do
        local item = NPC.GetItem(me, BLINK_ITEMS[i], true)
        if item then
            return item
        end
    end
    return nil
end

local function AbilityUsable(ability, mana)
    if not ability then
        return false
    end
    if Ability.IsHidden(ability) == true then
        return false
    end
    if (Ability.GetLevel(ability) or 0) <= 0 then
        return false
    end
    if Ability.IsReady(ability) ~= true then
        return false
    end
    if Ability.IsCastable(ability, mana) ~= true then
        return false
    end
    if Ability.IsInAbilityPhase(ability) == true then
        return false
    end
    return true
end

-- Enum.modifierFunction integers — never index Enum.modifierFunction at runtime.
local PROP_CAST_RANGE_BONUS = 110
local PROP_CAST_RANGE_BONUS_PERCENTAGE = 111
local PROP_CAST_RANGE_BONUS_STACKING = 113

local function SpecialValue(ability, name, fallback)
    if not ability then
        return fallback
    end
    local value = Ability.GetLevelSpecialValueFor(ability, name)
    if type(value) == "number" and value > 0 then
        return value
    end
    return fallback
end

local function CastRangeBonusParts(me)
    local apiBonus = NPC.GetCastRangeBonus(me)
    if type(apiBonus) == "number" and apiBonus > 0 then
        return apiBonus, 0
    end

    local flat = (NPC.GetModifierProperty(me, PROP_CAST_RANGE_BONUS) or 0)
        + (NPC.GetModifierProperty(me, PROP_CAST_RANGE_BONUS_STACKING) or 0)
    local pct = NPC.GetModifierProperty(me, PROP_CAST_RANGE_BONUS_PERCENTAGE) or 0
    if type(pct) ~= "number" then
        pct = 0
    end
    if type(apiBonus) == "number" and apiBonus ~= 0 and flat <= 0 then
        return apiBonus, 0
    end
    return flat, pct
end

-- Ability.GetCastRange + cast-range items (Aether Lens, Keen Optic, Ethereal, …).
local function EffectiveCastRange(ability, me, fallback)
    local range = Ability.GetCastRange(ability)
    if type(range) ~= "number" or range <= 0 then
        range = fallback or 0
    end
    local flat, pct = CastRangeBonusParts(me)
    local total = range + flat
    if pct ~= 0 then
        total = total * (1 + pct / 100)
    end
    return total
end

-- Special-value ranges (e.g. Skewer "range") also scale with cast-range bonus.
local function EffectiveSpecialRange(ability, me, name, fallback)
    local range = SpecialValue(ability, name, fallback)
    local flat, pct = CastRangeBonusParts(me)
    local total = range + flat
    if pct ~= 0 then
        total = total * (1 + pct / 100)
    end
    return total
end

local function BlinkLandAtStandDist(mePos, enemyPos, blinkRange, standDistance)
    local dist = mePos:Distance2D(enemyPos)
    if dist < 1 then
        return mePos:Clone()
    end

    -- Prefer landing on the me→enemy line, standDistance before the enemy (not on top).
    local desiredTravel = dist - standDistance
    if desiredTravel >= 80 then
        local travel = math.min(desiredTravel, math.max(0, blinkRange - 8))
        return mePos:Extend2D(enemyPos, travel)
    end

    -- Already inside / past stand distance: step away from the enemy to standDistance.
    local land = enemyPos:Extend2D(mePos, standDistance)
    if mePos:Distance2D(land) > blinkRange then
        land = mePos:Extend2D(land, math.max(0, blinkRange - 8))
    end
    return land
end

local function SkewerEndPos(mePos, allyPos, skewerRange)
    local dist = mePos:Distance2D(allyPos)
    if dist <= skewerRange then
        return allyPos:Clone()
    end
    return mePos:Extend2D(allyPos, skewerRange)
end

local function IsBusy(me)
    if NPC.IsSilenced(me) == true or NPC.IsStunned(me) == true then
        return true
    end
    if NPC.IsChannellingAbility(me) == true then
        return true
    end
    if NPC.HasModifier(me, "modifier_magnataur_skewer_movement") == true then
        return true
    end
    return false
end

local function ResolveEntity(index)
    if not index then
        return nil
    end
    local unit = Entity.Get(index)
    if not IsValidUnit(unit) then
        return nil
    end
    return unit
end

local function FindEnemy(me)
    local myTeam = Entity.GetTeamNum(me)
    local cursor = Input.GetNearestHeroToCursor(myTeam, Enum.TeamType.TEAM_ENEMY)
    if cursor ~= nil then
        if IsValidUnit(cursor) then
            local mePos = Entity.GetAbsOrigin(me)
            local enemyPos = Entity.GetAbsOrigin(cursor)
            if mePos ~= nil and enemyPos ~= nil and mePos:Distance2D(enemyPos) <= ENEMY_SEARCH_RANGE then
                return cursor
            end
        end
    end

    local heroes = Entity.GetHeroesInRadius(me, ENEMY_SEARCH_RANGE, Enum.TeamType.TEAM_ENEMY, true, true)
    if not heroes then
        return nil
    end

    local best, bestDist = nil, math.huge
    local cursorPos = Input.GetWorldCursorPos()
    local mePos = Entity.GetAbsOrigin(me)
    for i = 1, #heroes do
        local hero = heroes[i]
        if hero ~= nil and IsValidUnit(hero) then
            local pos = Entity.GetAbsOrigin(hero)
            if pos ~= nil then
                local dist = math.huge
                if cursorPos ~= nil then
                    dist = cursorPos:Distance2D(pos)
                elseif mePos ~= nil then
                    dist = mePos:Distance2D(pos)
                end
                if dist < bestDist then
                    bestDist = dist
                    best = hero
                end
            end
        end
    end
    return best
end

local function FindAllyByCleanName(me, clean)
    if not clean or clean == "" then
        return nil
    end

    local myTeam = Entity.GetTeamNum(me)
    local all = Heroes.GetAll()
    if not all then
        return nil
    end

    for i = 1, #all do
        local hero = all[i]
        if hero
            and hero ~= me
            and Entity.GetTeamNum(hero) == myTeam
            and IsValidUnit(hero)
            and CleanHeroName(NPC.GetUnitName(hero)) == clean
        then
            return hero
        end
    end
    return nil
end

local function FindSelectedAlly(me)
    local list = Runtime.allyPriority
    for i = 1, #list do
        local hero = FindAllyByCleanName(me, list[i])
        if hero then
            return hero
        end
    end
    return nil
end

local function CatchEnabled(catchId)
    if not UI.catches then
        return true
    end
    return UI.catches:Get(catchId) == true
end

local function CatchPriorityIds()
    if UI.catches then
        local list = UI.catches:List()
        if list and #list > 0 then
            local ordered = {}
            for i = 1, #list do
                local id = list[i]
                if CatchEnabled(id) then
                    ordered[#ordered + 1] = id
                end
            end
            return ordered
        end
    end
    return { CATCH_HARPOON, CATCH_HORN, CATCH_SHOCK }
end

local function HasHornAbility(horn)
    return horn ~= nil
        and Ability.IsHidden(horn) ~= true
        and (Ability.GetLevel(horn) or 0) > 0
end

local function IsMeleeSetupMode(mode)
    return mode == MODE_FLANK or mode == MODE_SHOCK
end

local function StandDistanceForMode(mode, harpoon, horn, skewer, me)
    -- Shockwave pull_distance is only ~150; stand inside skewer_radius before Q→E.
    if IsMeleeSetupMode(mode) then
        local radius = SpecialValue(skewer, "skewer_radius", SKEWER_RADIUS_FALLBACK)
        return math.max(85, radius - 40)
    end
    if mode == MODE_HARPOON then
        local range = EffectiveCastRange(harpoon, me, HARPOON_RANGE_FALLBACK)
        return math.max(300, math.min(range - 220, range * 0.48))
    end
    local radius = SpecialValue(horn, "radius", HORN_RADIUS_FALLBACK)
    return math.max(200, math.min(radius - 40, radius * 0.72))
end

local function PickCatchMode(harpoon, horn, shock, mana, hasHarpoon, hasHorn)
    local order = CatchPriorityIds()
    if #order == 0 then
        return nil
    end

    local harpoonOk = hasHarpoon and CatchEnabled(CATCH_HARPOON) and AbilityUsable(harpoon, mana)
    local hornOk = hasHorn and CatchEnabled(CATCH_HORN) and AbilityUsable(horn, mana)
    local shockOk = CatchEnabled(CATCH_SHOCK) and AbilityUsable(shock, mana)

    for i = 1, #order do
        local id = order[i]
        if id == CATCH_HARPOON and harpoonOk then
            return MODE_HARPOON
        end
        if id == CATCH_HORN and hornOk then
            return MODE_HORN
        end
        if id == CATCH_SHOCK and shockOk then
            return MODE_SHOCK
        end
    end

    return nil
end

local function EnterStage(stage, now)
    Runtime.stage = stage
    Runtime.stageAt = now
end

local function NeedsBlinkForCatch(me, enemy, standDist)
    local mePos = Entity.GetAbsOrigin(me)
    local enemyPos = Entity.GetAbsOrigin(enemy)
    if not mePos or not enemyPos then
        return false
    end
    local dist = mePos:Distance2D(enemyPos)
    return dist > standDist + 60 or dist < standDist * 0.70
end

local function BlinkTravelRange(blink)
    if not blink then
        return 0
    end
    local blinkRange = SpecialValue(blink, "blink_range", BLINK_RANGE_FALLBACK)
    local clamp = SpecialValue(blink, "blink_range_clamp", blinkRange)
    if type(clamp) == "number" and clamp > 0 then
        blinkRange = math.min(blinkRange, clamp)
    end
    return blinkRange
end

local function CatchReachRange(mode, harpoon, horn, skewer, me)
    if mode == MODE_HARPOON then
        return EffectiveCastRange(harpoon, me, HARPOON_RANGE_FALLBACK)
    end
    if mode == MODE_HORN then
        return SpecialValue(horn, "radius", HORN_RADIUS_FALLBACK)
    end
    return SpecialValue(skewer, "skewer_radius", SKEWER_RADIUS_FALLBACK) + 30
end

local function DistanceToEnemy(me, enemy)
    local mePos = Entity.GetAbsOrigin(me)
    local enemyPos = Entity.GetAbsOrigin(enemy)
    if not mePos or not enemyPos then
        return nil
    end
    return mePos:Distance2D(enemyPos), mePos, enemyPos
end

local function SkewerDestinationPos(ally)
    if Runtime.skewerPoint then
        return Runtime.skewerPoint
    end
    if ally then
        return Entity.GetAbsOrigin(ally)
    end
    return nil
end

-- Stand opposite the Skewer destination so the charge line goes through the enemy.
local function FlankStandPos(enemyPos, destPos, offset)
    local delta = enemyPos - destPos
    if delta:Length2D() < 1 then
        return enemyPos:Clone()
    end
    return enemyPos + delta:Normalized():Scaled(offset)
end

local function CanBlinkIntoStand(me, enemy, blink, standDist)
    local dist = DistanceToEnemy(me, enemy)
    if not dist then
        return false
    end
    local blinkRange = BlinkTravelRange(blink)
    if blinkRange <= 0 then
        return false
    end
    if IsMeleeSetupMode(Runtime.mode) then
        return dist <= blinkRange + standDist + 40
    end
    return dist <= blinkRange + standDist - 25
end

local function InCatchRange(me, enemy, mode, harpoon, horn, skewer)
    local dist = DistanceToEnemy(me, enemy)
    if not dist then
        return false
    end
    local reach = CatchReachRange(mode, harpoon, horn, skewer, me)
    return dist <= reach + 20
end

local function CanSkewerGrab(me, enemy, skewer)
    local dist = DistanceToEnemy(me, enemy)
    if not dist then
        return false
    end
    local radius = SpecialValue(skewer, "skewer_radius", SKEWER_RADIUS_FALLBACK) + 30
    return dist <= radius
end

local function ShockPullWait(me, enemy, shock)
    local dist = DistanceToEnemy(me, enemy) or 150
    local speed = SpecialValue(shock, "shock_speed", SHOCK_SPEED_FALLBACK)
    local pullDur = SpecialValue(shock, "pull_duration", SHOCK_PULL_DURATION_FALLBACK)
    local travel = (speed > 1) and (dist / speed) or 0.12
    return travel + pullDur + 0.05
end

local function BeginShockWait(me, enemy, shock, now)
    Runtime.shockWait = ShockPullWait(me, enemy, shock)
    EnterStage(STAGE_SHOCK_WAIT, now)
end

local function ApproachDestination(mePos, enemyPos, standDist)
    local dist = mePos:Distance2D(enemyPos)
    if dist <= standDist + 10 then
        return enemyPos:Extend2D(mePos, standDist)
    end
    return mePos:Extend2D(enemyPos, dist - standDist)
end

local function IssueApproachMove(me, enemy, ally, standDist, now)
    if now - Runtime.lastMoveAt < MOVE_INTERVAL then
        return
    end
    local mePos = Entity.GetAbsOrigin(me)
    local enemyPos = Entity.GetAbsOrigin(enemy)
    if not mePos or not enemyPos then
        return
    end
    Runtime.lastMoveAt = now
    local dest
    if IsMeleeSetupMode(Runtime.mode) then
        local skewerDest = SkewerDestinationPos(ally)
        if skewerDest then
            dest = FlankStandPos(enemyPos, skewerDest, math.max(standDist, SKEWER_FLANK_OFFSET))
        else
            dest = ApproachDestination(mePos, enemyPos, math.max(standDist, 90))
        end
    else
        dest = ApproachDestination(mePos, enemyPos, math.max(standDist, 200))
    end
    NPC.MoveTo(me, dest, false, false, true, false, ORDER_ID, false)
end

local function EnterCatchStage(mode, now)
    if mode == MODE_HARPOON then
        EnterStage(STAGE_HARPOON, now)
    elseif mode == MODE_HORN then
        EnterStage(STAGE_HORN, now)
    else
        EnterStage(STAGE_FLANK, now)
    end
end

local function StartCombo(me, now, enemy, ally, blink, harpoon, horn, shock, skewer, mana)
    local skewerOk = AbilityUsable(skewer, mana)
    if not skewerOk then
        return
    end

    local hasHarpoon = harpoon ~= nil
    local hasHorn = HasHornAbility(horn)
    local mode = PickCatchMode(harpoon, horn, shock, mana, hasHarpoon, hasHorn)
    if not mode then
        mode = MODE_FLANK
    end

    local blinkOk = AbilityUsable(blink, mana) and NPC.HasState(me, STATE_ROOTED) ~= true
    local standDist = StandDistanceForMode(mode, harpoon, horn, skewer, me)

    Runtime.mode = mode
    Runtime.blinkStandDist = standDist
    Runtime.enemyIndex = Entity.GetIndex(enemy)
    Runtime.allyIndex = ally and Entity.GetIndex(ally) or nil

    if IsMeleeSetupMode(mode) then
        if CanSkewerGrab(me, enemy, skewer) then
            EnterCatchStage(mode, now)
            return
        end
        if blinkOk and CanBlinkIntoStand(me, enemy, blink, standDist) then
            EnterStage(STAGE_BLINK, now)
            return
        end
        EnterStage(STAGE_APPROACH, now)
        return
    end

    if blinkOk then
        if not CanBlinkIntoStand(me, enemy, blink, standDist) then
            EnterStage(STAGE_APPROACH, now)
            return
        end
        if NeedsBlinkForCatch(me, enemy, standDist) then
            EnterStage(STAGE_BLINK, now)
            return
        end
        EnterCatchStage(mode, now)
        return
    end

    if InCatchRange(me, enemy, mode, harpoon, horn, skewer) then
        EnterCatchStage(mode, now)
    else
        EnterStage(STAGE_APPROACH, now)
    end
end

local function IssueBlink(me, blink, enemy, ally, mana, standDistance)
    if not AbilityUsable(blink, mana) or NPC.HasState(me, STATE_ROOTED) == true then
        return false
    end
    local mePos = Entity.GetAbsOrigin(me)
    local enemyPos = Entity.GetAbsOrigin(enemy)
    if not mePos or not enemyPos then
        return false
    end
    local blinkRange = BlinkTravelRange(blink)
    local land
    if IsMeleeSetupMode(Runtime.mode) then
        local skewerDest = SkewerDestinationPos(ally)
        if skewerDest then
            land = FlankStandPos(enemyPos, skewerDest, standDistance)
        else
            land = BlinkLandAtStandDist(mePos, enemyPos, blinkRange, standDistance)
        end
        if mePos:Distance2D(land) > blinkRange then
            land = mePos:Extend2D(land, math.max(0, blinkRange - 8))
        end
    else
        land = BlinkLandAtStandDist(mePos, enemyPos, blinkRange, standDistance)
    end
    Ability.CastPosition(blink, land, false, true, false, ORDER_ID, false)
    return true
end

local function IssueHarpoon(harpoon, enemy, mana)
    if not AbilityUsable(harpoon, mana) then
        return false
    end
    Ability.CastTarget(harpoon, enemy, false, true, false, ORDER_ID)
    return true
end

local function IssueHorn(horn, mana)
    if not AbilityUsable(horn, mana) then
        return false
    end
    Ability.CastNoTarget(horn, false, true, false, ORDER_ID)
    return true
end

local function IssueShock(shock, enemy, me, mana)
    if not AbilityUsable(shock, mana) then
        return false
    end
    local range = EffectiveCastRange(shock, me, 1200)
    local mePos = Entity.GetAbsOrigin(me)
    local enemyPos = Entity.GetAbsOrigin(enemy)
    if not mePos or not enemyPos then
        return false
    end
    if mePos:Distance2D(enemyPos) > range then
        return false
    end
    Ability.CastTarget(shock, enemy, false, true, false, ORDER_ID)
    return true
end

local function IssueSkewer(skewer, me, ally, mana)
    if not AbilityUsable(skewer, mana) then
        return false
    end
    local mePos = Entity.GetAbsOrigin(me)
    if not mePos then
        return false
    end
    local destPos = Runtime.skewerPoint
    if not destPos and ally then
        destPos = Entity.GetAbsOrigin(ally)
    end
    if not destPos then
        return false
    end
    local skewerRange = EffectiveSpecialRange(skewer, me, "range", SKEWER_RANGE_FALLBACK)
    local endPos = SkewerEndPos(mePos, destPos, skewerRange)
    Ability.CastPosition(skewer, endPos, false, true, false, ORDER_ID, false)
    return true
end

local function BlinkAccepted(blink, stageAt, now)
    if not blink then
        return true
    end
    if Ability.IsReady(blink) ~= true then
        return true
    end
    local since = Ability.SecondsSinceLastUse(blink)
    if type(since) == "number" and since >= 0 and since < 0.45 then
        return true
    end
    return now - stageAt >= 0.55
end

local function UpdateCombo(me, now)
    if NPC.GetUnitName(me) ~= HERO_NAME then
        AbortCombo()
        return
    end
    if not UI.bind or UI.bind:IsDown() ~= true then
        AbortCombo()
        return
    end
    if Input.IsInputCaptured() == true or Input.IsPopupOpen() == true then
        return
    end
    if IsBusy(me) then
        return
    end

    local mana = NPC.GetMana(me) or 0
    local blink = FindBlinkItem(me)
    local harpoon = NPC.GetItem(me, ITEM_HARPOON, true)
    local horn = NPC.GetAbility(me, ABILITY_HORN_TOSS)
    local shock = NPC.GetAbility(me, ABILITY_SHOCKWAVE)
    local skewer = NPC.GetAbility(me, ABILITY_SKEWER)

    if Runtime.stage == STAGE_IDLE then
        local enemy = FindEnemy(me)
        local ally = FindSelectedAlly(me)
        local hasDest = Runtime.skewerPoint ~= nil or ally ~= nil
        if enemy and skewer and hasDest then
            StartCombo(me, now, enemy, ally, blink, harpoon, horn, shock, skewer, mana)
        end
        return
    end

    if now - Runtime.stageAt > STAGE_TIMEOUT
        and Runtime.stage ~= STAGE_SHOCK_WAIT
        and Runtime.stage ~= STAGE_APPROACH
        and Runtime.stage ~= STAGE_FLANK
    then
        AbortCombo()
        return
    end

    local enemy = ResolveEntity(Runtime.enemyIndex)
    local ally = ResolveEntity(Runtime.allyIndex)
    if not enemy then
        AbortCombo()
        return
    end
    if not Runtime.skewerPoint and not ally then
        AbortCombo()
        return
    end

    local blinkOk = AbilityUsable(blink, mana) and NPC.HasState(me, STATE_ROOTED) ~= true
    local standDist = Runtime.blinkStandDist
    if standDist <= 0 then
        standDist = StandDistanceForMode(Runtime.mode, harpoon, horn, skewer, me)
        Runtime.blinkStandDist = standDist
    end

    if Runtime.stage == STAGE_APPROACH then
        if IsMeleeSetupMode(Runtime.mode) then
            if CanSkewerGrab(me, enemy, skewer) then
                EnterCatchStage(Runtime.mode, now)
                return
            end
            if blinkOk and CanBlinkIntoStand(me, enemy, blink, standDist) then
                EnterStage(STAGE_BLINK, now)
                return
            end
            IssueApproachMove(me, enemy, ally, standDist, now)
            return
        end
        if blinkOk and CanBlinkIntoStand(me, enemy, blink, standDist) then
            if NeedsBlinkForCatch(me, enemy, standDist) then
                EnterStage(STAGE_BLINK, now)
            else
                EnterCatchStage(Runtime.mode, now)
            end
            return
        end
        if not blinkOk and InCatchRange(me, enemy, Runtime.mode, harpoon, horn, skewer) then
            EnterCatchStage(Runtime.mode, now)
            return
        end
        IssueApproachMove(me, enemy, ally, standDist, now)
        return
    end

    if Runtime.stage == STAGE_BLINK then
        if not CanBlinkIntoStand(me, enemy, blink, standDist) then
            EnterStage(STAGE_APPROACH, now)
            return
        end
        if AbilityUsable(blink, mana) and NPC.HasState(me, STATE_ROOTED) ~= true then
            IssueBlink(me, blink, enemy, ally, mana, standDist)
        end
        if BlinkAccepted(blink, Runtime.stageAt, now) then
            if IsMeleeSetupMode(Runtime.mode) and not CanSkewerGrab(me, enemy, skewer) then
                EnterStage(STAGE_APPROACH, now)
            else
                EnterCatchStage(Runtime.mode, now)
            end
        end
        return
    end

    if Runtime.stage == STAGE_FLANK then
        if not CanSkewerGrab(me, enemy, skewer) then
            if blinkOk and CanBlinkIntoStand(me, enemy, blink, standDist) then
                EnterStage(STAGE_BLINK, now)
                return
            end
            IssueApproachMove(me, enemy, ally, standDist, now)
            return
        end

        if AbilityUsable(shock, mana) then
            if IssueShock(shock, enemy, me, mana) then
                BeginShockWait(me, enemy, shock, now)
                return
            end
            if now - Runtime.stageAt < 0.55 then
                return
            end
        end

        if IssueSkewer(skewer, me, ally, mana) then
            AbortCombo()
            return
        end
        if now - Runtime.stageAt > 0.90 then
            AbortCombo()
        end
        return
    end

    if Runtime.stage == STAGE_HARPOON then
        if not InCatchRange(me, enemy, MODE_HARPOON, harpoon, horn, skewer) then
            if blinkOk and CanBlinkIntoStand(me, enemy, blink, standDist) and NeedsBlinkForCatch(me, enemy, standDist) then
                EnterStage(STAGE_BLINK, now)
                return
            end
            IssueApproachMove(me, enemy, ally, standDist, now)
            return
        end
        if IssueHarpoon(harpoon, enemy, mana) then
            EnterStage(STAGE_SKEWER, now)
            return
        end
        if now - Runtime.stageAt > 0.55 then
            EnterStage(STAGE_SKEWER, now)
        end
        return
    end

    if Runtime.stage == STAGE_HORN then
        if not InCatchRange(me, enemy, MODE_HORN, harpoon, horn, skewer) then
            if blinkOk and CanBlinkIntoStand(me, enemy, blink, standDist) then
                EnterStage(STAGE_BLINK, now)
                return
            end
            IssueApproachMove(me, enemy, ally, standDist, now)
            return
        end
        if IssueHorn(horn, mana) then
            EnterStage(STAGE_SKEWER, now)
            return
        end
        if now - Runtime.stageAt > 0.70 then
            EnterStage(STAGE_SKEWER, now)
        end
        return
    end

    if Runtime.stage == STAGE_SHOCK_WAIT then
        if shock and Ability.IsInAbilityPhase(shock) == true then
            return
        end
        local wait = Runtime.shockWait
        if wait <= 0 then
            wait = SHOCK_PULL_WAIT
        end
        if now - Runtime.stageAt < wait then
            return
        end
        if CanSkewerGrab(me, enemy, skewer) then
            EnterStage(STAGE_SKEWER, now)
        else
            EnterStage(STAGE_APPROACH, now)
        end
        return
    end

    if Runtime.stage == STAGE_SKEWER then
        if not CanSkewerGrab(me, enemy, skewer) then
            IssueApproachMove(me, enemy, ally, standDist, now)
            if now - Runtime.stageAt > 1.10 then
                AbortCombo()
            end
            return
        end
        if IsMeleeSetupMode(Runtime.mode) and AbilityUsable(shock, mana) then
            if IssueShock(shock, enemy, me, mana) then
                BeginShockWait(me, enemy, shock, now)
                return
            end
            if now - Runtime.stageAt < 0.40 then
                return
            end
        end
        if IssueSkewer(skewer, me, ally, mana) then
            AbortCombo()
            return
        end
        if now - Runtime.stageAt > 0.80 then
            AbortCombo()
        end
    end
end

local function SyncAllyRoster(me, now)
    if now - Runtime.lastAllySyncAt < ALLY_SYNC_INTERVAL then
        return
    end
    Runtime.lastAllySyncAt = now

    local myTeam = Entity.GetTeamNum(me)
    local names, unitNames = {}, {}
    local all = Heroes.GetAll()
    if all then
        for i = 1, #all do
            local hero = all[i]
            if hero
                and hero ~= me
                and Entity.GetTeamNum(hero) == myTeam
                and NPC.IsIllusion(hero) ~= true
            then
                local unitName = NPC.GetUnitName(hero) or ""
                local cleanName = CleanHeroName(unitName)
                if cleanName ~= "" then
                    names[#names + 1] = cleanName
                    unitNames[cleanName] = unitName
                end
            end
        end
    end
    table.sort(names)
    Runtime.allyNames = names
    Runtime.allyUnitNames = unitNames

    local present = {}
    for i = 1, #names do
        present[names[i]] = true
    end
    local pruned = {}
    local list = Runtime.allyPriority
    for i = 1, #list do
        local name = list[i]
        if present[name] then
            pruned[#pruned + 1] = name
        end
    end
    if #pruned ~= #list then
        Runtime.allyPriority = pruned
        SaveAllyPriority()
    end
end

local function DrawPanelText(font, size, text, pos, color)
    if not font or font == 0 then
        return
    end
    local shadow = Colors.TextShadow
    if shadow and (shadow.a or 0) > 0 then
        Render.Text(font, size, text, Vec2(pos.x + 1, pos.y + 1), shadow)
    end
    Render.Text(font, size, text, pos, color)
end

local function GetPanelLayout(scale, numAllies, screenSize)
    local cellW = PANEL_CELL_W * scale
    local cellH = PANEL_CELL_H * scale
    local cellSpacing = PANEL_CELL_SPACING * scale
    local titleH = PANEL_HEADER_HEIGHT * scale
    local padX = PANEL_HEADER_PAD_X * scale
    local padY = PANEL_BODY_PAD_Y * scale
    local titleFontSize = PANEL_HEADER_TEXT_SIZE * scale
    local titleText = L("panel_title")
    local titleSize = MeasureText(Persistent.font, titleFontSize, titleText)
    local titleIconGap = PANEL_HEADER_ICON_GAP * scale
    local faFont = ResolvePanelFaFont()
    local titleIconW = 0
    local titleIconH = 0
    if faFont then
        local fontSize = math.floor(PANEL_HEADER_ICON_SIZE * scale + 0.5)
        local iconSize = Render.TextSize(faFont, fontSize, ICON_PANEL_FA)
        titleIconW = (iconSize and iconSize.x) or fontSize
        titleIconH = (iconSize and iconSize.y) or fontSize
    end

    local gap = faFont and titleIconGap or 0
    local titleContentW = titleIconW + gap + (titleSize.x or 0)
    local cellsTotalW = numAllies * cellW + math.max(0, numAllies - 1) * cellSpacing
    local width = math.max(padX + titleContentW + padX, padX + cellsTotalW + padX, PANEL_MIN_WIDTH * scale)
    local height = titleH + padY + cellH + padY
    local x = math.max(0, math.min(screenSize.x - width, PanelConfig.X))
    local y = math.max(0, math.min(screenSize.y - height, PanelConfig.Y))

    return {
        cellW = cellW,
        cellH = cellH,
        cellSpacing = cellSpacing,
        titleH = titleH,
        padX = padX,
        titleText = titleText,
        titleIconW = titleIconW,
        titleIconH = titleIconH,
        titleIconGap = gap,
        titleContentW = titleContentW,
        hasFaIcon = faFont ~= nil,
        titleSize = titleSize,
        titleFontSize = titleFontSize,
        width = width,
        height = height,
        x = x,
        y = y,
        rowY = y + titleH + padY,
        cellsStartX = x + math.floor((width - cellsTotalW) * 0.5 + 0.5),
    }
end

local function DrawPanelHeaderShadow(layout, scale)
    local shadow = Colors.Shadow
    if not shadow or (shadow.a or 0) <= 0 then
        return
    end
    local thickness = math.max(6, PANEL_SHADOW_THICKNESS * scale * (0.55 + (shadow.a or 0) / 255))
    Render.Shadow(
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        shadow,
        thickness,
        PANEL_HEADER_RADIUS * scale,
        Enum.DrawFlags.ShadowCutOutShapeBackground)
end

local function DrawPanelBlur(layout, scale)
    local headerA = Colors.HeaderBg.a or 255
    if headerA >= 255 then
        return
    end
    local strength = GetBlurStrength()
    if not strength then
        return
    end
    Render.Blur(
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        strength,
        1.0,
        PANEL_HEADER_RADIUS * scale,
        Enum.DrawFlags.None)
end

local function DrawPanel(me)
    if not UI.showPanel or UI.showPanel:Get() ~= true then
        return
    end
    if Menu.VisualsIsEnabled() ~= true then
        return
    end
    if not Persistent.font then
        Persistent.font = ResolveFont()
    end

    SyncAllyRoster(me, GameRules.GetGameTime())
    local numAllies = #Runtime.allyNames
    if numAllies == 0 then
        return
    end

    local scale = (Menu.Scale() or 100) / 100
    local screenSize = Render.ScreenSize()
    if not screenSize or (screenSize.x or 0) <= 1 or (screenSize.y or 0) <= 1 then
        return
    end

    local layout = GetPanelLayout(scale, numAllies, screenSize)
    local mx, my = Input.GetCursorPos()
    local isDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1, true) == true
    local isDown2 = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE2, true) == true
    local isClicked = isDown and not Runtime.wasMousePressed
    local isClicked2 = isDown2 and not Runtime.wasMouse2Pressed
    local isCursorValid = mx ~= nil and my ~= nil
    local isOverHeader = isCursorValid
        and mx >= layout.x and mx <= layout.x + layout.width
        and my >= layout.y and my <= layout.y + layout.titleH

    if isClicked and isOverHeader then
        PanelDrag.IsDragging = true
        PanelDrag.OffsetX = mx - layout.x
        PanelDrag.OffsetY = my - layout.y
    elseif not isDown then
        if PanelDrag.IsDragging then
            SavePanelPosition()
        end
        PanelDrag.IsDragging = false
    end

    if PanelDrag.IsDragging and mx and my then
        PanelConfig.X = math.max(0, math.min(screenSize.x - layout.width, mx - PanelDrag.OffsetX))
        PanelConfig.Y = math.max(0, math.min(screenSize.y - layout.height, my - PanelDrag.OffsetY))
        layout = GetPanelLayout(scale, numAllies, screenSize)
    end

    local clickTriggered = isClicked and Input.IsInputCaptured() ~= true
    local click2Triggered = isClicked2 and Input.IsInputCaptured() ~= true
    Runtime.wasMousePressed = isDown
    Runtime.wasMouse2Pressed = isDown2

    local titleFontSize = layout.titleFontSize
    local titleSizeY = layout.titleSize.y or titleFontSize
    local titleIconH = layout.titleIconH or 0
    local titleContentH = math.max(titleSizeY, titleIconH)
    local titleContentY = layout.y + math.floor((layout.titleH - titleContentH) * 0.5 + 0.5)
    local titleStartX = layout.x + math.floor((layout.width - (layout.titleContentW or 0)) * 0.5 + 0.5)
    local textX = titleStartX
    local textY = titleContentY + math.floor((titleContentH - titleSizeY) * 0.5 + 0.5)
    local cellRadius = PANEL_CELL_RADIUS * scale
    local priorityFontSize = math.floor(PANEL_PRIORITY_TEXT_SIZE * scale + 0.5)

    DrawPanelBlur(layout, scale)
    DrawPanelHeaderShadow(layout, scale)
    Render.FilledRect(
        Vec2(layout.x, layout.y),
        Vec2(layout.x + layout.width, layout.y + layout.titleH),
        Colors.HeaderBg,
        PANEL_HEADER_RADIUS * scale)

    if layout.hasFaIcon then
        local iconY = titleContentY + math.floor((titleContentH - titleIconH) * 0.5 + 0.5)
        local iconW = DrawPanelFaIcon(textX, iconY, scale)
        if iconW > 0 then
            textX = textX + layout.titleIconW + layout.titleIconGap
        end
    end
    DrawPanelText(Persistent.font, titleFontSize, layout.titleText, Vec2(textX, textY), Colors.TextHeader)

    local borderColor = GetChipBorderColor()
    local nowClock = os.clock()
    local dt = 0
    if Runtime.lastPanelDrawAt > 0 then
        dt = math.max(0, math.min(0.05, nowClock - Runtime.lastPanelDrawAt))
    end
    Runtime.lastPanelDrawAt = nowClock

    for i = 1, numAllies do
        local cleanName = Runtime.allyNames[i]
        local cellX = layout.cellsStartX + (i - 1) * (layout.cellW + layout.cellSpacing)
        local priority = AllyPriorityIndex(cleanName)
        local selected = priority ~= nil
        local visual = EaseChipVisual(UpdateChipVisual(cleanName, selected, dt))
        local imgAlpha = math.floor(
            PANEL_CHIP_DISABLED_ALPHA
                + (PANEL_CHIP_ENABLED_ALPHA - PANEL_CHIP_DISABLED_ALPHA) * visual
                + 0.5)
        local imgHandle = GetHeroIcon(Runtime.allyUnitNames[cleanName] or "")
        local isCellHovered = isCursorValid
            and mx >= cellX and mx <= cellX + layout.cellW
            and my >= layout.rowY and my <= layout.rowY + layout.cellH

        Render.FilledRect(
            Vec2(cellX, layout.rowY),
            Vec2(cellX + layout.cellW, layout.rowY + layout.cellH),
            Colors.CellBg,
            cellRadius)

        if imgHandle then
            Render.Image(
                imgHandle,
                Vec2(cellX, layout.rowY),
                Vec2(layout.cellW, layout.cellH),
                Color(255, 255, 255, imgAlpha),
                cellRadius,
                Enum.DrawFlags.None,
                Vec2(0, 0),
                Vec2(1, 1),
                1.0 - visual)
        end

        if visual > 0.01 then
            Render.Rect(
                Vec2(cellX, layout.rowY),
                Vec2(cellX + layout.cellW, layout.rowY + layout.cellH),
                Color(borderColor.r, borderColor.g, borderColor.b, math.floor(255 * visual + 0.5)),
                cellRadius,
                Enum.DrawFlags.None,
                PANEL_CHIP_BORDER_THICKNESS)
        end

        if priority then
            local label = tostring(priority)
            local labelSize = MeasureText(Persistent.font, priorityFontSize, label)
            local labelX = cellX + layout.cellW - (labelSize.x or 0) - 3 * scale
            local labelY = layout.rowY + 1 * scale
            DrawPanelText(Persistent.font, priorityFontSize, label, Vec2(labelX, labelY), Colors.TextHeader)
        end

        if isCellHovered and not PanelDrag.IsDragging then
            if click2Triggered then
                PromoteAllyPriority(cleanName)
            elseif clickTriggered then
                ToggleAllyPriority(cleanName)
            end
        end
    end
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    Persistent.font = ResolveFont()
    Persistent.blurFactor = Menu.Find("SettingsHidden", "", "", "", "Visual", "Menu Blur Factor")
    LoadPanelPosition()
    LoadAllyPriority()
    SyncColors()

    local group = Menu.Create(MENU_FIRST, MENU_SECTION, MENU_SECOND, MENU_THIRD, MENU_GROUP)
    Persistent.menuGroup = group
    UI.enabled = group:Switch("Enable", true, ICON_ENABLE)
    UI.bind = group:Bind("Combo Bind", Enum.ButtonCode.BUTTON_CODE_INVALID, ICON_BIND)
    UI.catches = group:MultiSelect("Catches", CATCH_ITEMS, true)
    UI.catches:Icon(ICON_CATCHES)
    UI.catches:DragAllowed(true)
    UI.setPosBind = group:Bind("Skewer Set Position", Enum.ButtonCode.BUTTON_CODE_INVALID, ICON_SET_POS)
    UI.setPosBind:Image(ICON_SKEWER)
    UI.setPosBind:Properties(nil, nil, true)
    UI.setPosColor = UI.setPosBind:ColorPicker("Color", Color(120, 200, 255, 255))
    UI.setPosColor:SetCallback(OnSetPosColorChanged, false)
    UI.showPanel = group:Switch("Show Panel", true, ICON_PANEL)

    UI.enabled:SetCallback(OnEnabledChanged, true)

    ApplyLocalization(true)
    SetupLanguageCallback()

    Persistent.logger:info("loaded")
end

function Script.OnThemeUpdate()
    SyncColors()
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end

    UpdateSetPositionBind()
    RefreshSkewerMarker()

    local now = GameRules.GetGameTime()
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true then
        AbortCombo()
        return
    end
    UpdateCombo(me, now)
end

function Script.OnDraw()
    if not Engine.IsInGame() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true then
        return
    end
    if NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end
    DrawPanel(me)
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
