---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
--[[
  Templar Assassin — Psionic Trap Helper — UCZone API v2.0
  Помощник по Psionic Trap: лучшие позиции трапов для вижена, рун, Рошана, ганков.
  Клик по точке — каст трапа. Трекер активных трапов с визуализацией вижен-радиуса.
]]

local ta = {}

-- ═══════════════════════════════════════════════════════════════════════════
--  Константы
-- ═══════════════════════════════════════════════════════════════════════════
local HERO_NAME           = "npc_dota_hero_templar_assassin"
local TRAP_ABILITY_NAME   = "templar_assassin_psionic_trap"
local TRAP_DETONATE_NAME  = "templar_assassin_trap"
local TRAP_UNIT_NAME      = "npc_dota_templar_assassin_psionic_trap"
local TRAP_RADIUS         = 400
local TRAP_CACHE_TTL      = 0.2
local POINT_COVERED_DIST  = 500

-- ═══════════════════════════════════════════════════════════════════════════
--  Конфиг и сохранение позиции панели
-- ═══════════════════════════════════════════════════════════════════════════
local function GetConfigPath()
    return "ta_trap_panel.ini"
end

local function LoadPanelPosition()
    local file = io.open(GetConfigPath(), "r")
    local x, y = 100.0, 150.0
    if file then
        for line in file:lines() do
            local xMatch = line:match("pos_x=(%d+)")
            local yMatch = line:match("pos_y=(%d+)")
            if xMatch then x = tonumber(xMatch) or x end
            if yMatch then y = tonumber(yMatch) or y end
        end
        file:close()
    end
    return x, y
end

local function SavePanelPosition(x, y)
    local file = io.open(GetConfigPath(), "w")
    if file then
        file:write(string.format("pos_x=%d\n", x))
        file:write(string.format("pos_y=%d\n", y))
        file:close()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Стратегические позиции Psionic Trap (карта)
-- ═══════════════════════════════════════════════════════════════════════════
--  Позиции подобраны для максимального вижена/контроля:
--  • Руны (Power, Bounty, Wisdom)
--  • Рошан
--  • Mid Lane (оба хайграунда)
--  • Входы в джангл
--  • Ключевые чокпоинты

local BuiltInTrapPoints = {
    -- ═══ Radiant perspective: агрессивный вижен на сторону Dire ═══
    radiant = {
        -- ─── Руны ───
        Vector(-2260, 230, 128),       -- Top Power Rune
        Vector(2800, -2380, 128),      -- Bottom Power Rune
        Vector(-4200, -1580, 128),     -- Radiant Top Bounty
        Vector(4020, -790, 128),       -- Dire Bottom Bounty

        -- ─── Рошан ───
        Vector(3050, -2080, 128),      -- Rosh Pit вход
        Vector(2600, -1600, 128),      -- Rosh Pit внешний подход (река)
        Vector(3700, -2700, 128),      -- За Rosh Pit (Dire сторона)

        -- ─── Mid Lane ───
        Vector(-680, 480, 256),        -- Dire HG mid (верх)
        Vector(280, -550, 256),        -- Radiant HG mid (низ)
        Vector(-200, -100, 128),       -- Mid river центр
        Vector(650, 600, 128),         -- Dire mid T1 подход
        Vector(-750, -950, 128),       -- Radiant mid T1 подход

        -- ─── Top Lane ───
        Vector(-6250, 1850, 128),      -- Top переход через реку
        Vector(-4800, 2200, 128),      -- Dire offlane shrine зона
        Vector(-3500, 4400, 128),      -- Top T2 зона
        Vector(-6100, 4500, 128),      -- За Dire T1 top
        Vector(-1600, 4550, 136),      -- Radiant triangle вход (top)

        -- ─── Bottom Lane ───
        Vector(4700, -4650, 128),      -- Bot переход через реку
        Vector(3050, -5350, 128),      -- Radiant safe lane зона
        Vector(6400, -5250, 128),      -- За Dire T1 bot
        Vector(5700, -3100, 128),      -- Dire triangle вход (bot)

        -- ─── Dire Jungle (offensive vision) ───
        Vector(3200, 400, 256),        -- Dire jungle mid вход
        Vector(4300, -350, 256),       -- Dire jungle main тропа
        Vector(5200, 1700, 128),       -- Dire jungle deep
        Vector(7500, 1400, 256),       -- Dire ancient camp зона
        Vector(2500, 2900, 128),       -- Dire jungle top вход
        Vector(4300, 1600, 128),       -- Dire medium camp

        -- ─── Radiant Jungle (defensive vision) ───
        Vector(-2200, -3900, 128),     -- Radiant jungle bot вход
        Vector(-800, -4800, 128),      -- Radiant jungle deep
        Vector(-4500, -100, 256),      -- Radiant jungle top вход

        -- ─── Ключевые чокпоинты ───
        Vector(1600, -1400, 128),      -- River choke mid-bot
        Vector(-1400, 1500, 128),      -- River choke mid-top
        Vector(0, 3500, 128),          -- Top river HG
    },

    -- ═══ Dire perspective: агрессивный вижен на сторону Radiant ═══
    dire = {
        -- ─── Руны ───
        Vector(-2260, 230, 128),       -- Top Power Rune
        Vector(2800, -2380, 128),      -- Bottom Power Rune
        Vector(-4200, -1580, 128),     -- Radiant Top Bounty
        Vector(4020, -790, 128),       -- Dire Bottom Bounty

        -- ─── Рошан ───
        Vector(3050, -2080, 128),      -- Rosh Pit вход
        Vector(2600, -1600, 128),      -- Rosh Pit внешний подход
        Vector(3700, -2700, 128),      -- За Rosh Pit

        -- ─── Mid Lane ───
        Vector(-680, 480, 256),        -- Dire HG mid
        Vector(280, -550, 256),        -- Radiant HG mid
        Vector(-200, -100, 128),       -- Mid river центр
        Vector(-900, -750, 128),       -- Radiant mid подход
        Vector(700, 250, 128),         -- Dire mid подход

        -- ─── Top Lane ───
        Vector(-6250, 1850, 128),      -- Top переход через реку
        Vector(-7650, 750, 256),       -- Radiant offlane зона
        Vector(-5600, 4350, 128),      -- За Radiant T1 top
        Vector(-3600, 6400, 128),      -- Radiant T2 top зона

        -- ─── Bottom Lane ───
        Vector(4700, -4650, 128),      -- Bot переход через реку
        Vector(6300, -5350, 128),      -- Dire safe lane зона
        Vector(3100, -3100, 128),      -- Bot river подход
        Vector(1400, -4350, 128),      -- Radiant triangle вход

        -- ─── Radiant Jungle (offensive vision) ───
        Vector(-3300, -2350, 128),     -- Radiant jungle mid вход
        Vector(-4200, -50, 256),       -- Radiant jungle main тропа
        Vector(-1400, -4700, 128),     -- Radiant jungle deep
        Vector(-7800, -650, 256),      -- Radiant ancient camp зона
        Vector(-2700, -3100, 128),     -- Radiant medium camp
        Vector(-5500, 1900, 128),      -- Radiant jungle top

        -- ─── Dire Jungle (defensive vision) ───
        Vector(2500, 3100, 128),       -- Dire jungle top вход
        Vector(4300, 1700, 128),       -- Dire jungle mid
        Vector(7800, 950, 256),        -- Dire jungle deep

        -- ─── Ключевые чокпоинты ───
        Vector(1600, -1400, 128),      -- River choke mid-bot
        Vector(-1400, 1500, 128),      -- River choke mid-top
        Vector(-400, -6600, 128),      -- Radiant base подход
        Vector(800, 6400, 128),        -- Dire base подход
    },

    neutral = {}
}

-- ═══════════════════════════════════════════════════════════════════════════
--  Конфигурация UI
-- ═══════════════════════════════════════════════════════════════════════════
local Config = {
    Fonts = {
        Main = Render.LoadFont("SF Pro Text", Enum.FontCreate.FONTFLAG_ANTIALIAS)
    },
    Icons = {
        Hero     = "panorama/images/heroes/icons/npc_dota_hero_templar_assassin_png.vtex_c",
        Trap     = "panorama/images/spellicons/templar_assassin_psionic_trap_png.vtex_c",
        Detonate = "panorama/images/spellicons/templar_assassin_trap_png.vtex_c",
    }
}

local PanelConfig = {
    Width           = 180,
    HeaderHeight    = 26,
    CellSize        = 26,
    CellSpacing     = 5,
    BorderRadius    = 8,
    BlurStrengthHdr = 10,
}

local PanelColors = {
    Header     = Color(10, 10, 10, 200),
    HeaderText = Color(255, 255, 255, 255),
}

-- Vision circle color (constant; change here if you want a different tint)
local VISION_CIRCLE_COLOR = Color(150, 100, 255, 60)

-- ═══════════════════════════════════════════════════════════════════════════
--  Инициализация меню
-- ═══════════════════════════════════════════════════════════════════════════
local function InitializeUI()
    local taSection = Menu.Find("Heroes", "Hero List", "Templar Assassin")
    local helperTab

    if taSection and taSection.Create then
        helperTab = taSection:Create("Trap Helper")
    end

    if not helperTab or not helperTab.Create then
        -- Fallback: если TA нет в меню — своё дерево
        local tab = Menu.Create("General", "TA Trap Helper", "ta_trap_helper")
        if tab and tab.Icon then tab:Icon(Config.Icons.Hero) end
        helperTab = tab
    end

    local mainGroup     = helperTab:Create("Main Settings")
    local trapGroup     = helperTab:Create("Trap Helper")
    local trackerGroup  = helperTab:Create("Trap Tracker")
    local detonateGroup = helperTab:Create("Quick Detonate")

    return {
        -- ── Main ──
        Enabled   = mainGroup:Switch("Enable Script", true, Config.Icons.Hero),
        ShowPanel = mainGroup:Switch("Show Status Panel", true),

        -- ── Trap Helper ──
        TrapHelperEnabled = trapGroup:Switch("Show Trap Points", true, Config.Icons.Trap),
        ShowOnlyAlt       = trapGroup:Switch("Show Only When ALT Pressed", false),
        ClickToCast       = trapGroup:Switch("Click to Cast", true),
        ShowOnlyInRange   = trapGroup:Switch("Show Only In Cast Range", false),
        HideCoveredPoints = trapGroup:Switch("Hide Covered Points", false),
        PointSize         = trapGroup:Slider("Point Size", 18, 40, 28, "%d"),

        -- ── Tracker ──
        ShowActiveTraps  = trackerGroup:Switch("Show Active Traps", true),
        ShowVisionRadius = trackerGroup:Switch("Show Vision Radius", true),

        -- ── Detonate ──
        DetonateNearest = detonateGroup:Switch("Quick Detonate (Key)", true, Config.Icons.Detonate),
        DetonateKey     = detonateGroup:Bind("Detonate Key", Enum.ButtonCode.KEY_NONE),
    }
end

local UI = InitializeUI()
local panelX, panelY = LoadPanelPosition()

-- ═══════════════════════════════════════════════════════════════════════════
--  Состояние
-- ═══════════════════════════════════════════════════════════════════════════
local State = {
    trapPoints    = BuiltInTrapPoints,
    activeTraps   = {},
    trapCacheTime = 0,
    mouseWasDown  = false,
    altAlpha      = 0,
    panelPos      = { x = panelX, y = panelY },
    isDragging    = false,
    dragOffset    = { x = 0, y = 0 },
}

local HeroIconCache    = {}
local AbilityIconCache = {}

-- ═══════════════════════════════════════════════════════════════════════════
--  Утилиты
-- ═══════════════════════════════════════════════════════════════════════════
local function IsTA()
    local myHero = Heroes.GetLocal()
    return myHero and NPC.GetUnitName(myHero) == HERO_NAME
end

local function AnimateAlpha(current, target, speed)
    if current < target then
        return math.min(current + speed, target)
    elseif current > target then
        return math.max(current - speed, target)
    end
    return current
end

local function GetHeroIconHandle(unitName)
    if not unitName then return nil end
    if HeroIconCache[unitName] then return HeroIconCache[unitName] end
    local path = "panorama/images/heroes/icons/" .. unitName .. "_png.vtex_c"
    local handle = Render.LoadImage(path)
    HeroIconCache[unitName] = handle
    return handle
end

local function GetAbilityIconHandle(abilityName)
    if not abilityName then return nil end
    if AbilityIconCache[abilityName] then return AbilityIconCache[abilityName] end
    local path = "panorama/images/spellicons/" .. abilityName .. "_png.vtex_c"
    local handle = Render.LoadImage(path)
    AbilityIconCache[abilityName] = handle
    return handle
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Кэш активных трапов
-- ═══════════════════════════════════════════════════════════════════════════
local function GetActiveTraps()
    local now = os.clock()
    if now - State.trapCacheTime < TRAP_CACHE_TTL then
        return State.activeTraps
    end

    local myHero = Heroes.GetLocal()
    if not myHero then
        State.activeTraps = {}
        return State.activeTraps
    end

    local playerId = Hero.GetPlayerID(myHero)
    local allNPCs  = NPCs.GetAll()
    local traps    = {}

    for i = 1, #allNPCs do
        local npc = allNPCs[i]
        if Entity.IsAlive(npc) and Entity.IsControllableByPlayer(npc, playerId) then
            local unitName = NPC.GetUnitName(npc)
            if unitName == TRAP_UNIT_NAME then
                traps[#traps + 1] = npc
            end
        end
    end

    State.activeTraps   = traps
    State.trapCacheTime = now
    return traps
end

local function IsPointCoveredByTrap(worldPos, traps)
    for i = 1, #traps do
        local trapPos = Entity.GetAbsOrigin(traps[i])
        if trapPos then
            local dist = (worldPos - trapPos):Length2D()
            if dist < POINT_COVERED_DIST then
                return true
            end
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Отрисовка: вспомогательные
-- ═══════════════════════════════════════════════════════════════════════════
local function DrawBlurredBackground(x, y, w, h, radius, blur, alpha)
    Render.Blur(
        Vec2(x, y),
        Vec2(x + w, y + h),
        blur,
        alpha,
        radius,
        Enum.DrawFlags.None
    )
end

local function DrawIconCell(x, y, alpha, imageHandle, size, rounding)
    DrawBlurredBackground(x, y, size, size, 6, 8, 0.97 * (alpha / 255))
    Render.Shadow(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(alpha)),
        24, 6,
        Enum.DrawFlags.ShadowCutOutShapeBackground,
        Vec2(1, 1)
    )
    Render.FilledRect(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(140 * alpha / 255)),
        6
    )

    if imageHandle then
        local pad      = 2
        local iconSize = size - pad * 2
        local r        = rounding or 0
        r = math.max(0, math.min(r, math.floor(iconSize / 2)))
        Render.Image(
            imageHandle,
            Vec2(x + pad, y + pad),
            Vec2(iconSize, iconSize),
            Color(255, 255, 255, math.floor(alpha)),
            r
        )
    end
end

local function DrawTextCell(x, y, alpha, text, fontSize, textColor, size)
    size = size or PanelConfig.CellSize
    DrawBlurredBackground(x, y, size, size, 6, 8, 0.97 * (alpha / 255))
    Render.Shadow(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(alpha)),
        24, 6,
        Enum.DrawFlags.ShadowCutOutShapeBackground,
        Vec2(1, 1)
    )
    Render.FilledRect(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(140 * alpha / 255)),
        6
    )

    local textSize = Render.TextSize(Config.Fonts.Main, fontSize, text)
    local textX = x + (size - textSize.x) / 2
    local textY = y + (size - textSize.y) / 2
    Render.Text(Config.Fonts.Main, fontSize, text,
        Vec2(textX + 1, textY + 1),
        Color(0, 0, 0, math.floor(alpha * 0.4)))
    Render.Text(Config.Fonts.Main, fontSize, text,
        Vec2(textX, textY),
        Color(textColor.r, textColor.g, textColor.b, math.floor(alpha)))
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Отрисовка: Trap Points (click-to-cast helper)
-- ═══════════════════════════════════════════════════════════════════════════
local function DrawTrapPoints()
    if not UI.TrapHelperEnabled:Get() then return end

    local myHero = Heroes.GetLocal()
    if not myHero or not Entity.IsAlive(myHero) then return end

    -- ALT toggle animation
    local altHeld   = Input.IsKeyDown(Enum.ButtonCode.KEY_LALT) or Input.IsKeyDown(Enum.ButtonCode.KEY_RALT)
    local altActive = (not UI.ShowOnlyAlt:Get()) or altHeld
    local targetAlpha = altActive and 255 or 0
    State.altAlpha = AnimateAlpha(State.altAlpha, targetAlpha, 25)
    if State.altAlpha <= 0 then return end

    local trapIcon   = GetAbilityIconHandle("templar_assassin_psionic_trap")
    local rounding   = 6
    local team       = Entity.GetTeamNum(myHero)
    local heroPos    = Entity.GetAbsOrigin(myHero)
    local cursorX, cursorY = Input.GetCursorPos()
    local mouseDown  = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
    local justClicked = mouseDown and (not State.mouseWasDown)
    local didCast    = false
    local alphaScale = State.altAlpha / 255
    local pointSize  = UI.PointSize:Get()

    local showOnlyInRange = UI.ShowOnlyInRange:Get()
    local hideCovered     = UI.HideCoveredPoints:Get()
    local activeTraps     = GetActiveTraps()

    local trapAbility = NPC.GetAbility(myHero, TRAP_ABILITY_NAME)
    local castRange   = 1800
    if trapAbility then
        castRange = Ability.GetCastRange(trapAbility) or 1800
    end

    local function drawList(list)
        for i = 1, #(list or {}) do
            local wp = list[i]

            -- Distance check
            local dist    = heroPos and (heroPos - wp):Length2D() or 99999
            local inRange = dist <= castRange

            if showOnlyInRange and not inRange then
                goto continue_point
            end

            -- Coverage check
            local covered = IsPointCoveredByTrap(wp, activeTraps)
            if hideCovered and covered then
                goto continue_point
            end

            local screenPos, visible = Render.WorldToScreen(wp)
            if visible then
                local halfSize = pointSize / 2
                local x = screenPos.x - halfSize
                local y = screenPos.y - halfSize

                local isHovered = cursorX >= x and cursorX <= (x + pointSize)
                               and cursorY >= y and cursorY <= (y + pointSize)

                -- Alpha по статусу точки
                local baseAlpha
                if covered then
                    baseAlpha = math.floor(100 * alphaScale)
                elseif inRange then
                    baseAlpha = isHovered and math.floor(255 * alphaScale) or math.floor(210 * alphaScale)
                else
                    baseAlpha = math.floor(130 * alphaScale)
                end

                -- Иконка трапа
                if trapIcon then
                    DrawIconCell(x, y, baseAlpha, trapIcon, pointSize, rounding)

                    -- Рамка
                    local borderColor
                    if covered then
                        borderColor = Color(100, 100, 100, math.floor(80 * alphaScale))
                    elseif isHovered and inRange then
                        borderColor = Color(180, 130, 255, math.floor(220 * alphaScale))
                    elseif inRange then
                        borderColor = Color(150, 100, 255, math.floor(150 * alphaScale))
                    else
                        borderColor = Color(120, 120, 120, math.floor(100 * alphaScale))
                    end

                    Render.Rect(
                        Vec2(x + 2, y + 2),
                        Vec2(x + pointSize - 2, y + pointSize - 2),
                        borderColor, rounding, Enum.DrawFlags.None, 0.5
                    )

                    -- Галочка если уже покрыто трапом
                    if covered then
                        local chkSize = Render.TextSize(Config.Fonts.Main, 10, "OK")
                        Render.Text(Config.Fonts.Main, 10, "OK",
                            Vec2(x + pointSize - chkSize.x - 2, y + 1),
                            Color(100, 255, 100, math.floor(baseAlpha)))
                    end
                end

                -- Click-to-cast
                if (not didCast) and UI.ClickToCast:Get() and justClicked and isHovered
                   and inRange and (not covered) then
                    if trapAbility and Ability.IsCastable(trapAbility, NPC.GetMana(myHero)) then
                        Ability.CastPosition(trapAbility, wp, false, false, false, "ta_trap_click")
                        didCast = true
                    end
                end
            end

            ::continue_point::
        end
    end

    if team == Enum.TeamNum.TEAM_RADIANT then
        drawList(State.trapPoints.radiant)
    elseif team == Enum.TeamNum.TEAM_DIRE then
        drawList(State.trapPoints.dire)
    else
        drawList(State.trapPoints.neutral)
    end

    State.mouseWasDown = mouseDown
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Отрисовка: активные трапы (маркеры + вижен-радиус)
-- ═══════════════════════════════════════════════════════════════════════════
local function DrawActiveTraps()
    if not UI.ShowActiveTraps:Get() then return end

    local traps      = GetActiveTraps()
    local showVision = UI.ShowVisionRadius:Get()

    for i = 1, #traps do
        local trap    = traps[i]
        local trapPos = Entity.GetAbsOrigin(trap)
        if not trapPos then goto continue_trap end

        local screenPos, visible = Render.WorldToScreen(trapPos)
        if not visible then goto continue_trap end

        -- Маркер трапа
        Render.FilledCircle(screenPos, 5, Color(180, 120, 255, 200))
        Render.Circle(screenPos, 6, Color(220, 180, 255, 180), 1.5)

        -- Номер трапа
        Render.Text(Config.Fonts.Main, 10, tostring(i),
            Vec2(screenPos.x + 8, screenPos.y - 5),
            Color(220, 200, 255, 180))

        -- Вижен-радиус (мировой круг через сегменты)
        if showVision then
            local numSegments  = 24
            local prevScreenPt = nil
            local prevVis      = false

            for s = 0, numSegments do
                local angle   = (s / numSegments) * 2 * math.pi
                local worldPt = Vector(
                    trapPos.x + TRAP_RADIUS * math.cos(angle),
                    trapPos.y + TRAP_RADIUS * math.sin(angle),
                    trapPos.z
                )
                local scrPt, vis = Render.WorldToScreen(worldPt)

                if vis and prevVis and prevScreenPt then
                    Render.Line(
                        prevScreenPt, scrPt,
                        VISION_CIRCLE_COLOR,
                        1
                    )
                end

                prevScreenPt = scrPt
                prevVis      = vis
            end
        end

        ::continue_trap::
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Отрисовка: панель статуса
-- ═══════════════════════════════════════════════════════════════════════════
local function HandlePanelInput()
    local cursorX, cursorY = Input.GetCursorPos()
    local px, py = State.panelPos.x, State.panelPos.y
    local isInHeader = cursorX >= px and cursorX <= px + PanelConfig.Width
                   and cursorY >= py and cursorY <= py + PanelConfig.HeaderHeight

    if isInHeader and Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) and not State.isDragging then
        State.isDragging     = true
        State.dragOffset.x   = cursorX - px
        State.dragOffset.y   = cursorY - py
    end

    if State.isDragging then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            State.panelPos.x = cursorX - State.dragOffset.x
            State.panelPos.y = cursorY - State.dragOffset.y
            local screenSize = Render.ScreenSize()
            State.panelPos.x = math.max(0, math.min(State.panelPos.x, screenSize.x - PanelConfig.Width))
            State.panelPos.y = math.max(0, math.min(State.panelPos.y, screenSize.y - 60))
        else
            State.isDragging = false
            SavePanelPosition(State.panelPos.x, State.panelPos.y)
        end
    end
end

local function DrawPanel()
    if not UI.ShowPanel:Get() then return end

    HandlePanelInput()

    local px, py = State.panelPos.x, State.panelPos.y
    local alpha  = 255

    -- ── Хедер ──
    DrawBlurredBackground(px, py, PanelConfig.Width, PanelConfig.HeaderHeight,
        PanelConfig.BorderRadius, PanelConfig.BlurStrengthHdr, 0.91)

    Render.Shadow(
        Vec2(px, py),
        Vec2(px + PanelConfig.Width, py + PanelConfig.HeaderHeight),
        Color(0, 0, 0, alpha),
        24, PanelConfig.BorderRadius,
        Enum.DrawFlags.ShadowCutOutShapeBackground,
        Vec2(1, 1)
    )
    Render.FilledRect(
        Vec2(px, py),
        Vec2(px + PanelConfig.Width, py + PanelConfig.HeaderHeight),
        PanelColors.Header,
        PanelConfig.BorderRadius
    )

    -- Иконка героя
    local iconHandle = GetHeroIconHandle(HERO_NAME)
    local iconSz     = 18
    local iconX       = px + 8
    local iconY       = py + (PanelConfig.HeaderHeight - iconSz) / 2
    if iconHandle then
        Render.Image(iconHandle, Vec2(iconX, iconY), Vec2(iconSz, iconSz),
            Color(255, 255, 255, alpha), 0)
    end

    -- Разделитель
    local sepX = iconX + iconSz + 8
    Render.FilledRect(
        Vec2(sepX, py),
        Vec2(sepX + 2, py + PanelConfig.HeaderHeight),
        Color(15, 15, 15, 70)
    )

    -- Заголовок
    local title     = "@traps"
    local titleSize = Render.TextSize(Config.Fonts.Main, 12, title)
    local titleX    = sepX + 8
    local titleY    = py + (PanelConfig.HeaderHeight - titleSize.y) / 2
    Render.Text(Config.Fonts.Main, 12, title,
        Vec2(titleX + 1, titleY + 1), Color(0, 0, 0, math.floor(alpha * 0.3)))
    Render.Text(Config.Fonts.Main, 12, title,
        Vec2(titleX, titleY), Color(170, 170, 170, alpha))

    -- ── Ячейки (ряд под хедером) ──
    local cellY  = py + PanelConfig.HeaderHeight + 5
    local cellX  = px + 8
    local cellSz = PanelConfig.CellSize

    local myHero     = Heroes.GetLocal()
    local traps      = GetActiveTraps()
    local trapCount  = #traps

    -- Определяем макс. количество трапов по уровню способности
    local trapAbility = myHero and NPC.GetAbility(myHero, TRAP_ABILITY_NAME) or nil
    local maxTraps    = "?"
    if trapAbility then
        local ok, lvl = pcall(Ability.GetLevel, trapAbility)
        if ok and lvl then
            if     lvl == 1 then maxTraps = "5"
            elseif lvl == 2 then maxTraps = "8"
            elseif lvl == 3 then maxTraps = "11"
            end
        end
    end

    -- Cell 1: Trap count (wider cell)
    local countW    = cellSz + 10
    local countText = tostring(trapCount) .. "/" .. maxTraps
    local countClr  = trapCount == 0
                      and Color(180, 180, 180, 255)
                      or  Color(180, 130, 255, 255)
    DrawTextCell(cellX, cellY, alpha, countText, 10, countClr, countW)
    cellX = cellX + countW + PanelConfig.CellSpacing

    -- Cell 2: Ability status (CD / RDY)
    local cdW     = cellSz + 6
    local cdText  = "-"
    local cdColor = Color(180, 180, 180, 255)
    if trapAbility then
        if Ability.IsCastable(trapAbility, NPC.GetMana(myHero)) then
            cdText  = "RDY"
            cdColor = Color(120, 255, 120, 255)
        else
            local cd = Ability.GetCooldown(trapAbility)
            if cd > 0 then
                cdText  = string.format("%.1f", cd)
                cdColor = Color(255, 120, 120, 255)
            else
                cdText  = "NO"
                cdColor = Color(255, 180, 80, 255)
            end
        end
    end
    DrawTextCell(cellX, cellY, alpha, cdText, 10, cdColor, cdW)
    cellX = cellX + cdW + PanelConfig.CellSpacing

    -- Cell 3: Detonate sub-ability status
    local detW       = cellSz + 6
    local detAbility = myHero and NPC.GetAbility(myHero, TRAP_DETONATE_NAME) or nil
    local detText    = "-"
    local detColor   = Color(180, 180, 180, 255)
    if detAbility and trapCount > 0 then
        if Ability.IsCastable(detAbility, NPC.GetMana(myHero)) then
            detText  = "DET"
            detColor = Color(255, 200, 80, 255)
        else
            local cd = Ability.GetCooldown(detAbility)
            detText  = string.format("%.1f", cd)
            detColor = Color(255, 120, 120, 255)
        end
    end
    DrawTextCell(cellX, cellY, alpha, detText, 10, detColor, detW)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Логика: Quick Detonate
-- ═══════════════════════════════════════════════════════════════════════════
local function QuickDetonate()
    if not UI.DetonateNearest:Get() then return end
    if not UI.DetonateKey or not UI.DetonateKey:IsPressed() then return end

    local myHero = Heroes.GetLocal()
    if not myHero then return end

    local detAbility = NPC.GetAbility(myHero, TRAP_DETONATE_NAME)
    if not detAbility then return end
    if not Ability.IsCastable(detAbility, NPC.GetMana(myHero)) then return end

    -- Каст sub-ability (detonates nearest trap to hero)
    Ability.CastNoTarget(detAbility)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Callbacks
-- ═══════════════════════════════════════════════════════════════════════════
ta.OnUpdate = function()
    if not IsTA() or not UI.Enabled:Get() then return end

    GetActiveTraps()   -- refresh cache
    QuickDetonate()
end

ta.OnDraw = function()
    if not IsTA() or not UI.Enabled:Get() then return end

    DrawPanel()
    DrawTrapPoints()
    DrawActiveTraps()
end

ta.OnGameEnd = function()
    State.activeTraps   = {}
    State.trapCacheTime = 0
end

return ta
