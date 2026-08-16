--[[
    Batrider Auto Lasso Combo
    Hold bind: blink in, Flaming Lasso, drag to fountain/allies; break Linken and use speed items.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local NAME = "BatriderAutoLasso"
local CONFIG_FILE = "batrider_auto_lasso"
local HERO_NAME = "npc_dota_hero_batrider"
local LASSO_NAME = "batrider_flaming_lasso"
local NAPALM_NAME = "batrider_sticky_napalm"

local UPDATE_INTERVAL = 0.03
local MOVE_INTERVAL = 0.25
local SPEED_ITEM_INTERVAL = 0.35
local ALLY_SYNC_INTERVAL = 0.25
local ORDER_GAP = 0.08
local BLINK_ORDER_GAP = 0.35
local BIND_RELEASE_GRACE = 0.18
local SEARCH_RANGE_FALLBACK = 1200
local LASSO_RANGE_SLACK = 50
local ALLY_ANIM_SPEED = 10

local MENU_FIRST = "Heroes"
local MENU_SECTION = "Hero List"
local MENU_SECOND = "Batrider"
local MENU_THIRD = "Main Settings"
local MENU_GROUP = "Auto Lasso"

local PHASE_LINKEN = "linken"
local PHASE_BLINK = "blink"
local PHASE_LASSO = "lasso"
local PHASE_DRAG = "drag"

local PULL_FOUNTAIN = "Fountain"
local PULL_ALLIES = "Allies"

local PANEL_TITLE = "Auto Lasso"
local PANEL_HEADER_HEIGHT = 28
local PANEL_HEADER_PAD_X = 8
local PANEL_HEADER_TEXT_SIZE = 14
local PANEL_HEADER_ICON_SIZE = 14
local PANEL_HEADER_RADIUS = 5
local PANEL_BODY_PAD_Y = 6
local PANEL_MIN_WIDTH = 120
local PANEL_CELL_W = 44
local PANEL_CELL_H = 26
local PANEL_CELL_SPACING = 6
local PANEL_CELL_RADIUS = 3
local PANEL_CHIP_ENABLED_ALPHA = 255
local PANEL_CHIP_DISABLED_ALPHA = 105
local PANEL_CHIP_MIN_BORDER_LUMA = 90
local PANEL_BLUR_BASE = 2.5
local PANEL_HEADER_FA = "\u{e1c9}"
local ITEMS_USAGE_FA = "\u{e1d0}"

local PANEL_HEADER_FONT_CANDIDATES <const> = { "Segoe UI", "Tahoma", "Arial" }
local PANEL_HEADER_FONT_WEIGHTS <const> = { 600, 500, 400 }

local STYLE_KEYS <const> = {
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

local function ItemRow(name, enabled)
    return { name, "panorama/images/items/" .. name:gsub("^item_", "") .. "_png.vtex_c", enabled ~= false }
end

local DAGON_MENU_ID = "item_dagon_5"

local DAGON_ITEM_NAMES <const> = {
    "item_dagon_5",
    "item_dagon_4",
    "item_dagon_3",
    "item_dagon_2",
    "item_dagon",
}

-- Positional MultiSelect: { nameId, imagePath, isEnabled }
-- Only unit-targeted actives that trigger Spell Block (Linken's).
-- One Dagon 5 tile toggles all dagon levels at runtime.
local LINK_BREAKER_ITEMS <const> = {
    ItemRow("item_force_staff"),
    ItemRow("item_hurricane_pike"),
    ItemRow("item_orchid"),
    ItemRow("item_bloodthorn"),
    ItemRow("item_sheepstick"),
    ItemRow("item_cyclone"),
    ItemRow("item_wind_waker"),
    ItemRow("item_nullifier"),
    ItemRow("item_ethereal_blade"),
    ItemRow(DAGON_MENU_ID),
    ItemRow("item_abyssal_blade"),
    ItemRow("item_heavens_halberd"),
    ItemRow("item_diffusal_blade"),
    ItemRow("item_disperser"),
    ItemRow("item_rod_of_atos"),
    ItemRow("item_gungir"),
    ItemRow("item_book_of_shadows"),
    { NAPALM_NAME, "panorama/images/spellicons/batrider_sticky_napalm_png.vtex_c", true },
}

local BLINK_MENU_ID = "item_blink"

local BLINK_ITEM_NAMES <const> = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

-- One Blink tile toggles all blink dagger variants at runtime.
local ITEMS_USAGE <const> = {
    ItemRow(BLINK_MENU_ID),
    ItemRow("item_phase_boots"),
    ItemRow("item_force_staff"),
    ItemRow("item_hurricane_pike"),
    ItemRow("item_ancient_janggo"),
    ItemRow("item_boots_of_bearing"),
}

local LASSO_MODS <const> = {
    modifier_batrider_flaming_lasso = true,
    modifier_batrider_flaming_lasso_self = true,
}
--#endregion

--#region State
---@class BatriderLassoUI
---@field enabled CMenuSwitch|nil
---@field comboKey CMenuBind|nil
---@field pullTo CMenuMultiComboBox|nil
---@field linkBreakerItems CMenuMultiSelect|nil
---@field itemsUsage CMenuMultiSelect|nil
---@field searchRange any
local UI = {
    enabled = nil,
    comboKey = nil,
    pullTo = nil,
    linkBreakerItems = nil,
    itemsUsage = nil,
    searchRange = nil,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    searchRangeWarned = false,
    ---@type integer|nil
    font = nil,
    ---@type integer|nil
    faFont = nil,
    faFontResolved = false,
    ---@type table<string, integer>
    heroImages = {},
    ---@type any
    blurFactor = nil,
}

local Style = {}
local Colors = {
    HeaderBg = Color(18, 18, 22, 255),
    TextHeader = Color(245, 247, 250, 255),
    Accent = Color(180, 180, 190, 255),
    CellBg = Color(12, 12, 16, 255),
    Primary = Color(180, 180, 190, 255),
    Shadow = Color(0, 0, 0, 160),
    WidgetsShadow = Color(0, 0, 0, 0),
    TextShadow = Color(0, 0, 0, 140),
}

local PanelConfig = { X = 200, Y = 200 }
local PanelDrag = { IsDragging = false, OffsetX = 0, OffsetY = 0 }

local Runtime = {
    lastUpdateAt = -math.huge,
    lastMoveAt = -math.huge,
    lastSpeedItemAt = -math.huge,
    lastAllySyncAt = -math.huge,
    lastDrawAt = -math.huge,
    bindUpAt = -math.huge,
    bindHeld = false,
    wasMouseDown = false,
    ---@type userdata|nil
    stickyTarget = nil,
    ---@type Vector|nil
    fountainPos = nil,
    ---@type table<string, boolean>
    allySelected = {},
    ---@type table<string, number>
    allyAnim = {},
    ---@type string[]
    allyNames = {},
    ---@type table<string, userdata>
    allyEntities = {},
    combo = {
        phase = nil,
        lastOrderAt = -math.huge,
        busyUntil = -math.huge,
    },
}
--#endregion

--#region Theme
local function NormalizeThemeColor(value)
    if value == nil then
        return nil
    end
    if type(value) == "userdata" then
        return value
    end
    if type(value) ~= "table" then
        return nil
    end
    local r = value.r or value[1] or 0
    local g = value.g or value[2] or 0
    local b = value.b or value[3] or 0
    local a = value.a or value[4] or 255
    if r <= 1 and g <= 1 and b <= 1 then
        r = r * 255
        g = g * 255
        b = b * 255
        if a <= 1 then
            a = a * 255
        end
    end
    return Color(r, g, b, a)
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
    Colors.Accent = Style.enabled_switch_background
        or Style.combo_item_active
        or Style.primary
        or Style.indication_active
        or Style.multiselect_item_selected
        or Colors.Accent
    local cell = Style.group_background or Style.button_background or Style.combo_frame or Colors.CellBg
    Colors.CellBg = Color(cell.r, cell.g, cell.b, 255)
    Colors.Primary = Style.primary or Colors.Accent
    if Colors.Primary then
        Colors.Primary = Color(Colors.Primary.r, Colors.Primary.g, Colors.Primary.b, 255)
    end
    Colors.Shadow = Style.shadow or Colors.Shadow
    Colors.WidgetsShadow = Style.widgets_shadow or Colors.WidgetsShadow
    if Style.text_shadow and (Style.text_shadow.a or 0) > 0 then
        Colors.TextShadow = Style.text_shadow
    end
end

local function ColorLuminance(color)
    if not color then
        return 0
    end
    return 0.299 * (color.r or 0) + 0.587 * (color.g or 0) + 0.114 * (color.b or 0)
end

local function GetChipBorderColor()
    local accent = Colors.Accent
    if ColorLuminance(accent) >= PANEL_CHIP_MIN_BORDER_LUMA then
        return Color(accent.r, accent.g, accent.b, 255)
    end
    local text = Colors.TextHeader
    return Color(text.r, text.g, text.b, 255)
end
--#endregion

--#region Panel fonts / images
local function IsValidFontHandle(handle)
    if type(handle) == "number" then
        return handle ~= 0
    end
    return type(handle) == "userdata"
end

local function CanMeasureWithFont(handle, sampleText, fontSize)
    if not IsValidFontHandle(handle) then
        return false
    end
    local size = Render.TextSize(handle, fontSize or PANEL_HEADER_TEXT_SIZE, sampleText or PANEL_TITLE)
    return size ~= nil and type(size.x) == "number" and type(size.y) == "number" and size.x > 0
end

local function EnsureFont()
    if Persistent.font and CanMeasureWithFont(Persistent.font, PANEL_TITLE, PANEL_HEADER_TEXT_SIZE) then
        return Persistent.font
    end
    for i = 1, #PANEL_HEADER_FONT_CANDIDATES do
        for w = 1, #PANEL_HEADER_FONT_WEIGHTS do
            local handle = Render.LoadFont(
                PANEL_HEADER_FONT_CANDIDATES[i],
                Enum.FontCreate.FONTFLAG_ANTIALIAS,
                PANEL_HEADER_FONT_WEIGHTS[w])
            if CanMeasureWithFont(handle, PANEL_TITLE, PANEL_HEADER_TEXT_SIZE) then
                Persistent.font = handle
                return handle
            end
        end
    end
    return nil
end

local function ResolveFaFont()
    if Persistent.faFontResolved then
        return Persistent.faFont
    end
    Persistent.faFontResolved = true
    if type(LIB_RENDER) == "table" and IsValidFontHandle(LIB_RENDER.default_font_awesome) then
        Persistent.faFont = LIB_RENDER.default_font_awesome
        return Persistent.faFont
    end
    Persistent.faFont = nil
    return nil
end

local function LoadPanelPosition()
    PanelConfig.X = Config.ReadInt(CONFIG_FILE, "panel_x", 200)
    PanelConfig.Y = Config.ReadInt(CONFIG_FILE, "panel_y", 200)
end

local function SavePanelPosition()
    Config.WriteInt(CONFIG_FILE, "panel_x", math.floor(PanelConfig.X + 0.5))
    Config.WriteInt(CONFIG_FILE, "panel_y", math.floor(PanelConfig.Y + 0.5))
end

local function GetBlurFactorWidget()
    if Persistent.blurFactor ~= nil then
        return Persistent.blurFactor
    end
    Persistent.blurFactor = Menu.Find("SettingsHidden", "", "", "", "Visual", "Menu Blur Factor") or false
    return Persistent.blurFactor
end

local function GetMenuBlurStrength()
    local widget = GetBlurFactorWidget()
    if not widget or widget == false or not widget.Get then
        return nil
    end
    local factor = widget:Get()
    if type(factor) ~= "number" or factor <= 0 then
        return nil
    end
    if factor > 1 then
        factor = factor / 100
    end
    return PANEL_BLUR_BASE * factor
end

local function GetHeroImage(unitName)
    if not unitName or unitName == "" then
        return nil
    end
    local cached = Persistent.heroImages[unitName]
    if cached then
        return cached
    end
    local handle = Render.LoadImage("panorama/images/heroes/" .. unitName .. "_png.vtex_c")
    if handle then
        Persistent.heroImages[unitName] = handle
    end
    return handle
end
--#endregion

--#region Helpers
local function ResetCombo()
    Runtime.combo.phase = nil
    Runtime.combo.lastOrderAt = -math.huge
    Runtime.combo.busyUntil = -math.huge
end

local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.lastMoveAt = -math.huge
    Runtime.lastSpeedItemAt = -math.huge
    Runtime.lastAllySyncAt = -math.huge
    Runtime.lastDrawAt = -math.huge
    Runtime.bindUpAt = -math.huge
    Runtime.bindHeld = false
    Runtime.wasMouseDown = false
    Runtime.stickyTarget = nil
    Runtime.fountainPos = nil
    Runtime.allySelected = {}
    Runtime.allyAnim = {}
    Runtime.allyNames = {}
    Runtime.allyEntities = {}
    PanelDrag.IsDragging = false
    ResetCombo()
end

local function SyncDisabled()
    local off = not UI.enabled or UI.enabled:Get() ~= true
    if UI.comboKey then
        UI.comboKey:Disabled(off)
    end
    if UI.pullTo then
        UI.pullTo:Disabled(off)
    end
    if UI.linkBreakerItems then
        UI.linkBreakerItems:Disabled(off)
    end
    if UI.itemsUsage then
        UI.itemsUsage:Disabled(off)
    end
end

local function OnEnabledChanged()
    SyncDisabled()
    if not UI.enabled or UI.enabled:Get() ~= true then
        ResetRuntime()
    end
end

local function MultiEnabled(widget, nameId)
    if not widget then
        return false
    end
    return widget:Get(nameId) == true
end

local function PullWants(nameId)
    return MultiEnabled(UI.pullTo, nameId)
end

local function GetSearchRange()
    if UI.searchRange then
        local value = UI.searchRange:Get()
        if type(value) == "number" and value > 0 then
            return value
        end
    end
    return SEARCH_RANGE_FALLBACK
end

local function GetLassoRange(me, lasso)
    return Ability.GetCastRange(lasso) + NPC.GetCastRangeBonus(me)
end

local function IsLassoActive(me, target)
    if NPC.HasAnyModifier(me, LASSO_MODS) == true then
        return true
    end
    if target and NPC.HasModifier(target, "modifier_batrider_flaming_lasso") == true then
        return true
    end
    return false
end

local function IsValidEnemyHero(unit, me)
    if not unit then
        return false
    end
    if Entity.IsAlive(unit) ~= true then
        return false
    end
    if Entity.IsDormant(unit) == true then
        return false
    end
    if NPC.IsVisible(unit) ~= true then
        return false
    end
    if NPC.IsIllusion(unit) == true then
        return false
    end
    if Entity.IsSameTeam(me, unit) == true then
        return false
    end
    return true
end

local function IsValidAllyHero(unit, me)
    if not unit or unit == me then
        return false
    end
    if Entity.IsAlive(unit) ~= true then
        return false
    end
    if Entity.IsDormant(unit) == true then
        return false
    end
    if NPC.IsIllusion(unit) == true then
        return false
    end
    if NPC.IsMeepoClone(unit) == true then
        return false
    end
    if Entity.IsSameTeam(me, unit) ~= true then
        return false
    end
    return true
end

local function IsStickyEnemyOk(unit, me)
    if not unit then
        return false
    end
    if Entity.IsAlive(unit) ~= true then
        return false
    end
    if NPC.IsIllusion(unit) == true then
        return false
    end
    if Entity.IsSameTeam(me, unit) == true then
        return false
    end
    return true
end

local function ResolveStickyTarget(me)
    local sticky = Runtime.stickyTarget
    if sticky and IsStickyEnemyOk(sticky, me) then
        return sticky
    end

    Runtime.stickyTarget = nil

    local searchRange = GetSearchRange()
    local nearest = Input.GetNearestHeroToCursor(Entity.GetTeamNum(me), Enum.TeamType.TEAM_ENEMY)
    if nearest == nil or not IsValidEnemyHero(nearest, me) then
        return nil
    end

    local cursorPos = Input.GetWorldCursorPos()
    local nearestPos = Entity.GetAbsOrigin(nearest)
    if cursorPos:IsInRange2D(nearestPos, searchRange) ~= true then
        return nil
    end

    Runtime.stickyTarget = nearest
    return nearest
end

local function ResolveFountainPos(me)
    if Runtime.fountainPos then
        return Runtime.fountainPos
    end

    local forts = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_FORT)
    for i = 1, #forts do
        local fort = forts[i]
        if fort and Entity.IsSameTeam(me, fort) == true and NPC.IsFort(fort) == true then
            Runtime.fountainPos = Entity.GetAbsOrigin(fort)
            return Runtime.fountainPos
        end
    end
    return nil
end

local function SyncAllyTargets(me, now)
    if now - Runtime.lastAllySyncAt < ALLY_SYNC_INTERVAL then
        return
    end
    Runtime.lastAllySyncAt = now

    local names = {}
    local entities = {}
    local heroes = Heroes.GetAll()
    for i = 1, #heroes do
        local ally = heroes[i]
        if IsValidAllyHero(ally, me) then
            local name = NPC.GetUnitName(ally)
            if name and name ~= "" then
                names[#names + 1] = name
                entities[name] = ally
            end
        end
    end
    table.sort(names)

    local selected = {}
    local anim = {}
    for i = 1, #names do
        local name = names[i]
        local prev = Runtime.allySelected[name]
        selected[name] = prev ~= false
        anim[name] = Runtime.allyAnim[name]
        if anim[name] == nil then
            anim[name] = selected[name] and 1 or 0
        end
    end

    Runtime.allyNames = names
    Runtime.allyEntities = entities
    Runtime.allySelected = selected
    Runtime.allyAnim = anim
end

local function ResolveAllyPullPos(me)
    local sx, sy, sz = 0, 0, 0
    local count = 0
    for i = 1, #Runtime.allyNames do
        local name = Runtime.allyNames[i]
        if Runtime.allySelected[name] == true then
            local unit = Runtime.allyEntities[name]
            if IsValidAllyHero(unit, me) then
                local x, y, z = Entity.GetAbsOriginXYZ(unit)
                sx = sx + x
                sy = sy + y
                sz = sz + z
                count = count + 1
            end
        end
    end
    if count <= 0 then
        return nil
    end
    return Vector(sx / count, sy / count, sz / count)
end

local function ResolveDragPos(me)
    if PullWants(PULL_ALLIES) then
        local allyPos = ResolveAllyPullPos(me)
        if allyPos then
            return allyPos
        end
    end
    if PullWants(PULL_FOUNTAIN) then
        return ResolveFountainPos(me)
    end
    return nil
end

local function SetPhase(phase)
    Runtime.combo.phase = phase
end

local function IsBusy(now)
    return now < Runtime.combo.busyUntil
end

local function MarkBusy(now, duration)
    local untilAt = now + (duration or ORDER_GAP)
    if untilAt > Runtime.combo.busyUntil then
        Runtime.combo.busyUntil = untilAt
    end
    Runtime.combo.lastOrderAt = now
end

local function CanIssueOrder(now, gap)
    if IsBusy(now) then
        return false
    end
    return now - Runtime.combo.lastOrderAt >= (gap or ORDER_GAP)
end

local function FindReadyLinkBreaker(me)
    local mana = NPC.GetMana(me)
    for i = 1, #LINK_BREAKER_ITEMS do
        local nameId = LINK_BREAKER_ITEMS[i][1]
        if MultiEnabled(UI.linkBreakerItems, nameId) then
            if nameId == NAPALM_NAME then
                local napalm = NPC.GetAbility(me, NAPALM_NAME)
                if napalm
                    and Ability.IsCastable(napalm, mana) == true
                    and NPC.IsSilenced(me) ~= true
                then
                    return napalm
                end
            elseif nameId == DAGON_MENU_ID then
                for d = 1, #DAGON_ITEM_NAMES do
                    local item = NPC.GetItem(me, DAGON_ITEM_NAMES[d], true)
                    if item and Ability.IsCastable(item, mana) == true then
                        return item
                    end
                end
            else
                local item = NPC.GetItem(me, nameId, true)
                if item and Ability.IsCastable(item, mana) == true then
                    return item
                end
            end
        end
    end
    return nil
end

local function HasAnyLinkBreakerEnabled()
    for i = 1, #LINK_BREAKER_ITEMS do
        if MultiEnabled(UI.linkBreakerItems, LINK_BREAKER_ITEMS[i][1]) then
            return true
        end
    end
    return false
end

local function FindReadyBlink(me)
    if MultiEnabled(UI.itemsUsage, BLINK_MENU_ID) ~= true then
        return nil
    end
    local mana = NPC.GetMana(me)
    for i = 1, #BLINK_ITEM_NAMES do
        local item = NPC.GetItem(me, BLINK_ITEM_NAMES[i], true)
        if item and Ability.IsCastable(item, mana) == true then
            return item
        end
    end
    return nil
end

local function ApproachTarget(me, target, now)
    if not CanIssueOrder(now, MOVE_INTERVAL) then
        return
    end
    if now - Runtime.lastMoveAt < MOVE_INTERVAL then
        return
    end
    NPC.MoveTo(me, Entity.GetAbsOrigin(target), false, false, false, false, "bat.approach", false)
    Runtime.lastMoveAt = now
    MarkBusy(now, MOVE_INTERVAL)
end

-- Blink preferred; walk if blink missing/CD.
local function CloseGapToTarget(me, target, range, now)
    local needRange = range - LASSO_RANGE_SLACK
    if needRange < 50 then
        needRange = range
    end
    if NPC.IsEntityInRange(me, target, needRange) == true then
        return false
    end

    if IsBusy(now) then
        return true
    end

    local blink = FindReadyBlink(me)
    if blink then
        if Ability.IsInAbilityPhase(blink) == true then
            return true
        end
        if not CanIssueOrder(now, BLINK_ORDER_GAP) then
            return true
        end

        SetPhase(PHASE_BLINK)

        local myPos = Entity.GetAbsOrigin(me)
        local targetPos = Entity.GetAbsOrigin(target)
        local dist = math.sqrt(myPos:DistanceSqr2D(targetPos))
        local blinkRange = Ability.GetCastRange(blink)
        if blinkRange <= 0 then
            blinkRange = 1200
        end
        local desired = dist - needRange
        if desired < 0 then
            desired = 0
        end
        if desired > blinkRange then
            desired = blinkRange
        end
        if desired < 50 then
            ApproachTarget(me, target, now)
            return true
        end

        local castPoint = Ability.GetCastPoint(blink) or 0
        Ability.CastPosition(blink, myPos:Extend2D(targetPos, desired), false, false, false, "bat.blink", false)
        MarkBusy(now, math.max(BLINK_ORDER_GAP, castPoint + 0.05))
        return true
    end

    ApproachTarget(me, target, now)
    return true
end

local function TryBreakLinken(me, target, now, lassoRange)
    if NPC.IsLinkensProtected(target) ~= true then
        return false
    end
    if not HasAnyLinkBreakerEnabled() then
        return false
    end

    SetPhase(PHASE_LINKEN)

    if IsBusy(now) then
        return true
    end

    local breaker = FindReadyLinkBreaker(me)
    if breaker then
        if Ability.IsInAbilityPhase(breaker) == true then
            return true
        end

        local range = Ability.GetCastRange(breaker) + NPC.GetCastRangeBonus(me)
        if range <= 0 then
            range = 600
        end

        if NPC.IsEntityInRange(me, target, range) == true then
            if not CanIssueOrder(now, ORDER_GAP) then
                return true
            end
            local castPoint = Ability.GetCastPoint(breaker) or 0
            Ability.CastTarget(breaker, target, false, false, false, "bat.linken.item")
            MarkBusy(now, math.max(ORDER_GAP, castPoint + 0.05))
            return true
        end
    end

    CloseGapToTarget(me, target, lassoRange, now)
    return true
end

local function TryCastLasso(me, target, lasso, now)
    if IsLassoActive(me, target) then
        return true
    end

    SetPhase(PHASE_LASSO)

    if IsBusy(now) then
        return false
    end
    if Ability.IsInAbilityPhase(lasso) == true then
        return false
    end
    if NPC.IsSilenced(me) == true then
        return false
    end
    if NPC.IsStunned(me) == true then
        return false
    end

    local mana = NPC.GetMana(me)
    if Ability.IsCastable(lasso, mana) ~= true then
        return false
    end
    if NPC.IsEntityInRange(me, target, GetLassoRange(me, lasso)) ~= true then
        return false
    end
    if not CanIssueOrder(now, ORDER_GAP) then
        return false
    end

    local castPoint = Ability.GetCastPoint(lasso) or 0
    Ability.CastTarget(lasso, target, false, false, false, "bat.lasso")
    MarkBusy(now, math.max(ORDER_GAP, castPoint + 0.05))
    return true
end

local function TrySpeedItems(me, destPos, now)
    if now - Runtime.lastSpeedItemAt < SPEED_ITEM_INTERVAL then
        return
    end

    local mana = NPC.GetMana(me)
    local noTarget = { "item_phase_boots", "item_ancient_janggo", "item_boots_of_bearing" }
    for i = 1, #noTarget do
        local nameId = noTarget[i]
        if MultiEnabled(UI.itemsUsage, nameId) then
            local item = NPC.GetItem(me, nameId, true)
            if item and Ability.IsCastable(item, mana) == true then
                Ability.CastNoTarget(item, false, false, false, "bat.speed.nt")
                Runtime.lastSpeedItemAt = now
                return
            end
        end
    end

    local selfTarget = { "item_force_staff", "item_hurricane_pike" }
    for i = 1, #selfTarget do
        local nameId = selfTarget[i]
        if MultiEnabled(UI.itemsUsage, nameId) then
            local item = NPC.GetItem(me, nameId, true)
            if item and Ability.IsCastable(item, mana) == true then
                local myPos = Entity.GetAbsOrigin(me)
                if myPos:IsInRange2D(destPos, 400) ~= true then
                    Ability.CastTarget(item, me, false, false, false, "bat.speed.force")
                    Runtime.lastSpeedItemAt = now
                end
                return
            end
        end
    end
end

local function DragToDestination(me, now)
    SetPhase(PHASE_DRAG)

    local destPos = ResolveDragPos(me)
    if not destPos then
        return
    end

    TrySpeedItems(me, destPos, now)
    if now - Runtime.lastMoveAt < MOVE_INTERVAL then
        return
    end

    NPC.MoveTo(me, destPos, false, false, false, false, "bat.move", false)
    Runtime.lastMoveAt = now
end

local function UpdateCombo(me)
    local now = GameRules.GetGameTime()
    local target = ResolveStickyTarget(me)
    if not target then
        ResetCombo()
        Runtime.stickyTarget = nil
        return
    end

    local lasso = NPC.GetAbility(me, LASSO_NAME)
    if not lasso then
        ResetCombo()
        return
    end

    if IsLassoActive(me, target) then
        DragToDestination(me, now)
        return
    end

    local lassoRange = GetLassoRange(me, lasso)

    if TryBreakLinken(me, target, now, lassoRange) then
        return
    end

    if CloseGapToTarget(me, target, lassoRange, now) then
        return
    end

    TryCastLasso(me, target, lasso, now)
end
--#endregion

--#region Panel draw
local function MeasurePanelTextSize(font, fontSize, text)
    local size = Render.TextSize(font, fontSize, text)
    if size and type(size.x) == "number" then
        return size
    end
    return Vec2(#text * fontSize * 0.55, fontSize)
end

local function DrawPanelText(font, size, text, pos, color)
    if Colors.TextShadow and (Colors.TextShadow.a or 0) > 0 then
        Render.Text(font, size, text, Vec2(pos.x + 1, pos.y + 1), Colors.TextShadow)
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
    local font = EnsureFont()
    local titleSize = font and MeasurePanelTextSize(font, titleFontSize, PANEL_TITLE)
        or Vec2(#PANEL_TITLE * titleFontSize * 0.55, titleFontSize)
    local faFont = ResolveFaFont()
    local titleW = (titleSize and titleSize.x) or 0
    local iconW = faFont and (PANEL_HEADER_ICON_SIZE * scale) or 0
    local cellsTotalW = numAllies * cellW + math.max(0, numAllies - 1) * cellSpacing
    local headerW = padX + iconW + titleW + padX
    local heroesW = padX + cellsTotalW + padX
    local width = math.max(headerW, heroesW, PANEL_MIN_WIDTH * scale)
    local height = titleH + padY + cellH + padY
    local x = math.max(0, math.min(screenSize.x - width, PanelConfig.X))
    local y = math.max(0, math.min(screenSize.y - height, PanelConfig.Y))

    return {
        cellW = cellW,
        cellH = cellH,
        cellSpacing = cellSpacing,
        titleH = titleH,
        padX = padX,
        titleFontSize = titleFontSize,
        hasTitleIcon = faFont ~= nil,
        width = width,
        height = height,
        x = x,
        y = y,
        rowY = y + titleH + padY,
        cellsStartX = x + math.floor((width - cellsTotalW) * 0.5 + 0.5),
        font = font,
        faFont = faFont,
    }
end

local function Smooth01(t)
    if t <= 0 then
        return 0
    end
    if t >= 1 then
        return 1
    end
    return t * t * (3 - 2 * t)
end

local function StepAllyVisual(name, selected, dt)
    local target = selected and 1 or 0
    local cur = Runtime.allyAnim[name]
    if cur == nil then
        cur = target
    end
    if cur < target then
        cur = math.min(1, cur + dt * ALLY_ANIM_SPEED)
    elseif cur > target then
        cur = math.max(0, cur - dt * ALLY_ANIM_SPEED)
    end
    Runtime.allyAnim[name] = cur
    return Smooth01(cur)
end

local function DrawAllyPanel()
    if not PullWants(PULL_ALLIES) then
        return
    end
    if Menu.VisualsIsEnabled() ~= true then
        return
    end

    local numAllies = #Runtime.allyNames
    if numAllies <= 0 then
        return
    end

    local scale = Menu.Scale() / 100
    if scale <= 0 then
        scale = 1
    end
    local screenSize = Render.ScreenSize()
    if not screenSize or (screenSize.x or 0) <= 1 or (screenSize.y or 0) <= 1 then
        return
    end

    local layout = GetPanelLayout(scale, numAllies, screenSize)
    if not layout.font then
        return
    end

    local mx, my = Input.GetCursorPos()
    local isDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) == true
    local isClicked = isDown and not Runtime.wasMouseDown
    local captured = Input.IsInputCaptured() == true
    local isOverHeader = mx >= layout.x and mx <= layout.x + layout.width
        and my >= layout.y and my <= layout.y + layout.titleH

    if isClicked and isOverHeader and not captured then
        PanelDrag.IsDragging = true
        PanelDrag.OffsetX = mx - layout.x
        PanelDrag.OffsetY = my - layout.y
    elseif not isDown then
        if PanelDrag.IsDragging then
            SavePanelPosition()
        end
        PanelDrag.IsDragging = false
    end

    if PanelDrag.IsDragging then
        PanelConfig.X = math.max(0, math.min(screenSize.x - layout.width, mx - PanelDrag.OffsetX))
        PanelConfig.Y = math.max(0, math.min(screenSize.y - layout.height, my - PanelDrag.OffsetY))
        layout = GetPanelLayout(scale, numAllies, screenSize)
    end

    local clickTriggered = isClicked and not captured
    Runtime.wasMouseDown = isDown

    local now = GameRules.GetGameTime()
    local dt = 0.016
    if Runtime.lastDrawAt > 0 then
        dt = now - Runtime.lastDrawAt
        if dt < 0 then
            dt = 0.016
        elseif dt > 0.05 then
            dt = 0.05
        end
    end
    Runtime.lastDrawAt = now

    local titleFontSize = layout.titleFontSize
    local titleSize = MeasurePanelTextSize(layout.font, titleFontSize, PANEL_TITLE)
    local titleW = titleSize.x or 0
    local titleH = titleSize.y or titleFontSize

    local iconSize = PANEL_HEADER_ICON_SIZE * scale
    local iconW = 0
    if layout.hasTitleIcon and layout.faFont then
        local iconMeasure = Render.TextSize(layout.faFont, iconSize, PANEL_HEADER_FA)
        if iconMeasure and type(iconMeasure.x) == "number" then
            iconW = iconMeasure.x
        else
            iconW = iconSize
        end
    end

    local textX = layout.x + math.floor((layout.width - titleW) * 0.5 + 0.5)
    local textY = layout.y + math.floor((layout.titleH - titleH) * 0.5 + 0.5)
    local iconX = layout.x + layout.padX
    local cellRadius = PANEL_CELL_RADIUS * scale
    local headerRadius = PANEL_HEADER_RADIUS * scale
    local headerStart = Vec2(layout.x, layout.y)
    local headerEnd = Vec2(layout.x + layout.width, layout.y + layout.titleH)

    local headerAlpha = Colors.HeaderBg.a or 255
    if headerAlpha < 255 then
        local blurStrength = GetMenuBlurStrength()
        if blurStrength then
            Render.Blur(headerStart, headerEnd, blurStrength, 1.0, headerRadius, Enum.DrawFlags.None)
        end
    end

    if Colors.Shadow and (Colors.Shadow.a or 0) > 0 then
        Render.Shadow(
            headerStart,
            headerEnd,
            Colors.Shadow,
            18 * scale,
            headerRadius,
            Enum.DrawFlags.ShadowCutOutShapeBackground)
    end

    Render.FilledRect(headerStart, headerEnd, Colors.HeaderBg, headerRadius)

    if layout.hasTitleIcon and layout.faFont and iconW > 0 then
        local iconY = layout.y + math.floor((layout.titleH - iconSize) * 0.5 + 0.5)
        local iconColor = Colors.Primary or Colors.TextHeader
        Render.Text(layout.faFont, iconSize, PANEL_HEADER_FA, Vec2(iconX, iconY), iconColor)
    end

    DrawPanelText(layout.font, titleFontSize, PANEL_TITLE, Vec2(textX, textY), Colors.TextHeader)

    local borderColor = GetChipBorderColor()
    for i = 1, numAllies do
        local name = Runtime.allyNames[i]
        local cellX = layout.cellsStartX + (i - 1) * (layout.cellW + layout.cellSpacing)
        local enabled = Runtime.allySelected[name] == true
        local visual = StepAllyVisual(name, enabled, dt)
        local imgAlpha = math.floor(
            PANEL_CHIP_DISABLED_ALPHA + (PANEL_CHIP_ENABLED_ALPHA - PANEL_CHIP_DISABLED_ALPHA) * visual + 0.5)
        local grayscale = 1.0 - visual
        local borderAlpha = math.floor(255 * visual + 0.5)
        local cellStart = Vec2(cellX, layout.rowY)
        local cellEnd = Vec2(cellX + layout.cellW, layout.rowY + layout.cellH)

        if Colors.WidgetsShadow and (Colors.WidgetsShadow.a or 0) > 0 then
            Render.Shadow(cellStart, cellEnd, Colors.WidgetsShadow, 10 * scale, cellRadius)
        end

        Render.FilledRect(cellStart, cellEnd, Colors.CellBg, cellRadius)

        local image = GetHeroImage(name)
        if image then
            Render.Image(
                image,
                cellStart,
                Vec2(layout.cellW, layout.cellH),
                Color(255, 255, 255, imgAlpha),
                cellRadius,
                Enum.DrawFlags.None,
                Vec2(0, 0),
                Vec2(1, 1),
                grayscale)
        end

        if borderAlpha > 0 then
            Render.Rect(
                cellStart,
                cellEnd,
                Color(borderColor.r, borderColor.g, borderColor.b, borderAlpha),
                cellRadius,
                Enum.DrawFlags.None,
                1.3)
        end

        local hovered = mx >= cellX and mx <= cellX + layout.cellW
            and my >= layout.rowY and my <= layout.rowY + layout.cellH
        if hovered and clickTriggered and not PanelDrag.IsDragging then
            Runtime.allySelected[name] = not enabled
        end
    end
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    Persistent.logger = Logger(NAME)
    LoadPanelPosition()
    SyncColors()
    EnsureFont()
    ResolveFaFont()
    Persistent.blurFactor = Menu.Find("SettingsHidden", "", "", "", "Visual", "Menu Blur Factor")

    local group = Menu.Create(MENU_FIRST, MENU_SECTION, MENU_SECOND, MENU_THIRD, MENU_GROUP)
    UI.enabled = group:Switch("Enable", true, "\u{f00c}")
    UI.comboKey = group:Bind("Combo Key", Enum.ButtonCode.KEY_NONE, "\u{f11c}")
    UI.pullTo = group:MultiCombo("Pull To", { PULL_FOUNTAIN, PULL_ALLIES }, { PULL_FOUNTAIN, PULL_ALLIES })
    UI.pullTo:Icon("\u{f0c0}")

    UI.linkBreakerItems = group:MultiSelect("LinkBreaker Items", LINK_BREAKER_ITEMS, false)
    UI.linkBreakerItems:Image("panorama/images/items/sphere_png.vtex_c")

    UI.itemsUsage = group:MultiSelect("Items Usage", ITEMS_USAGE, false)
    UI.itemsUsage:Icon(ITEMS_USAGE_FA)

    UI.searchRange = Menu.Find("Heroes", "", "Settings", "General", "Target Selection", "Search Range")
    if not UI.searchRange and Persistent.logger and not Persistent.searchRangeWarned then
        Persistent.logger:warning("Search Range menu not found; using fallback", SEARCH_RANGE_FALLBACK)
        Persistent.searchRangeWarned = true
    end

    UI.enabled:SetCallback(OnEnabledChanged, true)
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

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true then
        ResetRuntime()
        return
    end
    if NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end

    local now = GameRules.GetGameTime()
    if PullWants(PULL_ALLIES) then
        SyncAllyTargets(me, now)
    end

    local bindDown = UI.comboKey ~= nil and UI.comboKey:IsDown() == true
    if not bindDown then
        if Runtime.bindHeld then
            Runtime.bindUpAt = now
            Runtime.bindHeld = false
        end
        if now - Runtime.bindUpAt >= BIND_RELEASE_GRACE then
            if Runtime.combo.phase ~= nil or Runtime.stickyTarget ~= nil then
                ResetCombo()
                Runtime.stickyTarget = nil
            end
        end
        return
    end
    Runtime.bindHeld = true

    if Input.IsInputCaptured() then
        return
    end

    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    UpdateCombo(me)
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

    DrawAllyPanel()
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
