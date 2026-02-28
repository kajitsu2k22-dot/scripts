local script = {}

-- Smart ally assist alerts (safe heuristics only).
-- Shows HUD + minimap ping only when a usable TP/Travel exists and a valid anchor is near the ally.

local META = {
    NAME = "Help Alert",
    ID = "ally_assist_smart_alerts",
    VERSION = "1.0.0",
}

local MENU_CFG = {
    INFO_FIRST_TAB = "Info Screen",
    INFO_SECTION = "Main",
    SCRIPT_NAME = "Help Alert",
    THIRD_TAB = "Main",
    ROOT_GROUP = "General",
    TAB_ICON = "\u{f0f3}", -- bell
}

local ALERT_TYPES = {
    DIVE = "DIVE_UNDER_TOWER",
    GANK = "GANK",
    TRADE = "LOSING_TRADE",
}

local SEVERITY = {
    LOW = 1,
    MED = 2,
    HIGH = 3,
}

local INTERNAL = {
    TRACK_RETENTION_SEC = 2.5,
    PER_ALLY_PING_COOLDOWN_SEC = 6.0,
    ESCALATION_HP_DROP_PCT = 8.0,
    MAX_ACTIVE_ALERTS = 4,
    MIN_SCAN_INTERVAL_SEC = 0.10,
    TP_CAPABILITY_REFRESH_SEC = 0.30,
    TP_CAPABILITY_REFRESH_MISSING_SEC = 0.75,
}

local DEFAULTS = {
    enabled = true,
    tradeAlerts = true,
    diveAlerts = true,
    gankAlerts = true,
    maxAnchorDistance = 1800,
    scanIntervalMs = 150,
    enemyCombatRadius = 1200,
    tradeRadius = 800,
    towerProtectRadius = 950,
    gankMinEnemies = 2,
    tradeMinHpDropPct = 8,
    gankMinHpDropPct = 12,
    perAllyAlertCooldownSec = 8,
    hudAlerts = true,
    minimapPing = true,
    pingCooldownMs = 1200,
    alertDurationMs = 3500,
    visibleEnemiesOnly = true,
    debugDraw = false,
    debugLog = false,
    painFactorThreshold = 25,
    tradeDeltaMargin = 5,
}

local I18N_PREFIX = META.ID .. "."
local I18N_REGISTERED = false
local LANG = "en"
local _langWidget = nil
local _langLastCheck = -1e9

local I18N = {
    menu_enable = {
        en = "Enable Smart Assist Alerts",
        ru = "Включить умные алерты помощи",
        cn = "启用智能支援提醒",
    },
    menu_group_alert_types = {
        en = "Alert Types",
        ru = "Типы алертов",
        cn = "提醒类型",
    },
    menu_group_detection = {
        en = "Detection",
        ru = "Детект",
        cn = "检测",
    },
    menu_group_teleport = {
        en = "Teleport Gate",
        ru = "Проверка телепорта",
        cn = "传送条件",
    },
    menu_group_notifications = {
        en = "Notifications",
        ru = "Уведомления",
        cn = "通知",
    },
    menu_group_debug = {
        en = "Debug",
        ru = "Отладка",
        cn = "调试",
    },
    menu_trade_alerts = {
        en = "Losing Trade Alerts",
        ru = "Алерты проигранного размена",
        cn = "对拼劣势提醒",
    },
    menu_dive_alerts = {
        en = "Tower Dive Alerts",
        ru = "Алерты дайва под тавер",
        cn = "塔下强杀提醒",
    },
    menu_gank_alerts = {
        en = "Gank Alerts",
        ru = "Алерты ганга",
        cn = "Gank 提醒",
    },
    menu_max_tp_distance = {
        en = "Max TP Arrival Distance",
        ru = "Макс. дистанция точки TP",
        cn = "TP 落点最大距离",
    },
    menu_scan_interval = {
        en = "Scan Interval (ms)",
        ru = "Интервал сканирования (мс)",
        cn = "扫描间隔 (ms)",
    },
    menu_enemy_combat_radius = {
        en = "Enemy Combat Radius",
        ru = "Радиус поиска врагов",
        cn = "敌人战斗半径",
    },
    menu_trade_radius = {
        en = "Trade Radius",
        ru = "Радиус размена",
        cn = "对拼半径",
    },
    menu_tower_protect_radius = {
        en = "Tower Protect Radius",
        ru = "Радиус защиты тавера",
        cn = "防御塔保护半径",
    },
    menu_gank_min_enemies = {
        en = "Gank Min Enemies",
        ru = "Мин. врагов для ганга",
        cn = "Gank 最少敌人数",
    },
    menu_trade_min_hp_drop = {
        en = "Trade Min HP Drop %",
        ru = "Мин. потеря HP для размена %",
        cn = "对拼最小掉血 %",
    },
    menu_gank_min_hp_drop = {
        en = "Gank Min HP Drop %",
        ru = "Мин. потеря HP для ганга %",
        cn = "Gank 最小掉血 %",
    },
    menu_alert_cd = {
        en = "Per Ally Alert Cooldown (s)",
        ru = "КД алерта на союзника (с)",
        cn = "每个队友提醒冷却 (s)",
    },
    menu_hud_alerts = {
        en = "HUD Alerts",
        ru = "HUD-уведомления",
        cn = "HUD 提醒",
    },
    menu_minimap_ping = {
        en = "MiniMap Ping",
        ru = "Пинг на миникарте",
        cn = "小地图 Ping",
    },
    menu_ping_cd = {
        en = "Ping Cooldown (ms)",
        ru = "КД пинга (мс)",
        cn = "Ping 冷却 (ms)",
    },
    menu_alert_duration = {
        en = "Alert Duration (ms)",
        ru = "Длительность алерта (мс)",
        cn = "提醒持续时间 (ms)",
    },
    menu_visible_only = {
        en = "Visible Enemies Only",
        ru = "Только видимые враги",
        cn = "仅可见敌人",
    },
    menu_debug_draw = {
        en = "Debug Draw",
        ru = "Debug-отрисовка",
        cn = "调试绘制",
    },
    menu_debug_log = {
        en = "Debug Log",
        ru = "Debug-лог",
        cn = "调试日志",
    },
    menu_pain_factor = {
        en = "Pain Factor Threshold",
        ru = "Порог Pain Factor",
        cn = "Pain Factor 阈值",
    },
    menu_trade_delta = {
        en = "Trade Delta Margin %",
        ru = "Порог разницы размена %",
        cn = "对拼差值阈值 %",
    },
    tip_enable = {
        en = "Alerts trigger only when a usable TP/Travel exists and a valid teleport anchor is near the ally.",
        ru = "Алерт срабатывает только если есть usable TP/Travel и рядом с союзником есть валидная точка телепорта.",
        cn = "仅当你有可用 TP/飞鞋，且队友附近存在有效传送落点时才会提醒。",
    },
    tip_visible_only = {
        en = "Recommended on. Uses only visible enemies for safe heuristics.",
        ru = "Рекомендуется включить. Безопасные эвристики используют только видимых врагов.",
        cn = "建议开启。安全启发式只使用可见敌人。",
    },
    tip_pain_factor = {
        en = "Heuristic threshold for gank pressure.",
        ru = "Эвристический порог давления для детекта ганга.",
        cn = "用于判断被围攻压力的启发式阈值。",
    },
    alert_dive_fmt = {
        en = "DIVE: %s under tower (%d enemies) [TP]",
        ru = "DIVE: %s под тавером (%d враг.) [TP]",
        cn = "DIVE: %s 塔下被冲 (%d敌) [TP]",
    },
    alert_gank_fmt = {
        en = "GANK: %s (%d enemies) [TP]",
        ru = "GANK: %s (%d враг.) [TP]",
        cn = "GANK: %s (%d敌) [TP]",
    },
    alert_trade_fmt = {
        en = "TRADE: %s is losing trade [TP]",
        ru = "TRADE: %s проигрывает размен [TP]",
        cn = "TRADE: %s 对拼劣势 [TP]",
    },
    label_dive = { en = "DIVE", ru = "DIVE", cn = "DIVE" },
    label_gank = { en = "GANK", ru = "GANK", cn = "GANK" },
    label_trade = { en = "TRADE", ru = "TRADE", cn = "TRADE" },
    hud_tp_none = {
        en = "No TP",
        ru = "Нет TP",
        cn = "无 TP",
    },
    hud_tp_scroll = {
        en = "Scroll",
        ru = "Свиток",
        cn = "卷轴",
    },
    hud_tp_travel1 = {
        en = "BoT1",
        ru = "Тревела1",
        cn = "飞鞋1",
    },
    hud_tp_travel2 = {
        en = "BoT2",
        ru = "Тревела2",
        cn = "飞鞋2",
    },
    hud_anchor_tower = {
        en = "Tower",
        ru = "Тавер",
        cn = "塔",
    },
    hud_anchor_hero = {
        en = "Hero",
        ru = "Герой",
        cn = "英雄",
    },
    hud_anchor_unit = {
        en = "Unit",
        ru = "Юнит",
        cn = "单位",
    },
    hud_anchor_building = {
        en = "Building",
        ru = "Строение",
        cn = "建筑",
    },
    hud_anchor_unknown = {
        en = "Anchor",
        ru = "Точка",
        cn = "落点",
    },
    hud_meta_line_fmt = {
        en = "%s  |  %s -> %s  |  %d enemy",
        ru = "%s  |  %s -> %s  |  %d враг.",
        cn = "%s  |  %s -> %s  |  %d敌",
    },
    hud_meta_line_plural_fmt = {
        en = "%s  |  %s -> %s  |  %d enemies",
        ru = "%s  |  %s -> %s  |  %d враг.",
        cn = "%s  |  %s -> %s  |  %d敌",
    },
    hud_time_left_fmt = {
        en = "%.1fs",
        ru = "%.1fс",
        cn = "%.1f秒",
    },
    dbg_tp_status = {
        en = "TP: kind=%s usable=%s reason=%s",
        ru = "TP: тип=%s доступен=%s причина=%s",
        cn = "TP: 类型=%s 可用=%s 原因=%s",
    },
    dbg_active_alerts = {
        en = "Active alerts: %d",
        ru = "Активных алертов: %d",
        cn = "当前提醒: %d",
    },
    dbg_now = {
        en = "Now: %.2f",
        ru = "Сейчас: %.2f",
        cn = "当前: %.2f",
    },
    dbg_tp_none = {
        en = "TP: none",
        ru = "TP: нет",
        cn = "TP: 无",
    },
}

local UI = nil
local UI_MENU_BUILT = false

local State = {
    heroTracks = {},
    activeAlerts = {},
    lastScanAt = -1e9,
    lastGlobalPingAt = -1e9,
    fonts = {
        main = nil,
        small = nil,
        mode = "unknown",
        loaded = false,
    },
    cachedLocalHeroIndex = nil,
    nextAlertId = 0,
    lastTpCapability = nil,
    lastTpRefreshAt = -1e9,
}

local function ensureI18N()
    if I18N_REGISTERED then return end
    I18N_REGISTERED = true

    if type(Localizer) ~= "table" or type(Localizer.RegToken) ~= "function" then
        return
    end

    for key, values in pairs(I18N) do
        pcall(Localizer.RegToken, I18N_PREFIX .. key, values)
    end
end

local function updateLang()
    local now = os.clock()
    if (now - _langLastCheck) < 0.75 then return end
    _langLastCheck = now

    if not _langWidget and type(Menu) == "table" and type(Menu.Find) == "function" then
        local ok, w = pcall(Menu.Find, "SettingsHidden", "", "", "", "Main", "Language")
        if ok and w then
            _langWidget = w
        end
    end

    if _langWidget and type(_langWidget.Get) == "function" then
        local ok, v = pcall(_langWidget.Get, _langWidget)
        if ok and v ~= nil then
            if v == 1 then
                LANG = "ru"
            elseif v == 2 then
                LANG = "cn"
            else
                LANG = "en"
            end
        end
    end
end

local function t(key, fallback)
    ensureI18N()
    updateLang()
    local token = I18N_PREFIX .. tostring(key)

    local def = I18N[key]
    if type(def) == "table" then
        local byLang = def[LANG]
        if type(byLang) == "string" and byLang ~= "" then
            return byLang
        end
        if type(def.en) == "string" and def.en ~= "" then
            return def.en
        end
    end

    -- Keep Localizer lookup as fallback only.
    if type(Localizer) == "table" and type(Localizer.Get) == "function" then
        local ok, value = pcall(Localizer.Get, token)
        if ok and type(value) == "string" and value ~= "" and value ~= token then
            return value
        end
    end

    if type(def) == "table" and type(def.en) == "string" then
        return def.en
    end
    return fallback or tostring(key)
end

-- -----------------------------------------------------------------------------
-- Generic safe helpers
-- -----------------------------------------------------------------------------

local function V2(x, y)
    if type(Vec2) == "function" then
        return Vec2(x, y)
    end
    return { x = x, y = y }
end

local function Col(r, g, b, a)
    if type(Color) == "function" then
        return Color(r, g, b, a or 255)
    end
    return { r = r, g = g, b = b, a = a or 255 }
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local MCALL_STATIC_CACHE = {}
local MCALL_USERDATA_DIRECT_INDEX_UNSUPPORTED = false
local MCALL_SOURCES = nil

local function mcallIndex(obj, method)
    return obj[method]
end

local function getMcallSources()
    if MCALL_SOURCES then return MCALL_SOURCES end
    MCALL_SOURCES = { Hero, NPC, Entity, Ability, Item, Tower, Modifier, Player }
    return MCALL_SOURCES
end

local function mcall(obj, method, ...)
    if not obj then return nil end

    local objType = type(obj)

    -- Some UCZone userdata objects throw on direct indexing (obj[method]).
    -- Once detected, skip this path for userdata to reduce pcall overhead/spikes.
    if objType ~= "userdata" or not MCALL_USERDATA_DIRECT_INDEX_UNSUPPORTED then
        local okIndex, fn = pcall(mcallIndex, obj, method)
        if okIndex and type(fn) == "function" then
            local okCall, a, b, c, d, e = pcall(fn, obj, ...)
            if okCall then
                return a, b, c, d, e
            end
        elseif objType == "userdata" and not okIndex then
            MCALL_USERDATA_DIRECT_INDEX_UNSUPPORTED = true
        end
    end

    -- Fast path for environments where userdata method indexing is blocked:
    -- use static wrappers (Entity/NPC/Hero/Ability/Item/Tower/Modifier/Player).
    local cachedFn = MCALL_STATIC_CACHE[method]
    if type(cachedFn) == "function" then
        local okCall, a, b, c, d, e = pcall(cachedFn, obj, ...)
        if okCall then
            return a, b, c, d, e
        end
        MCALL_STATIC_CACHE[method] = nil
    end

    local sources = getMcallSources()
    for i = 1, #sources do
        local src = sources[i]
        if type(src) == "table" then
            local srcFn = src[method]
            if type(srcFn) == "function" then
                local okCall, a, b, c, d, e = pcall(srcFn, obj, ...)
                if okCall then
                    MCALL_STATIC_CACHE[method] = srcFn
                    return a, b, c, d, e
                end
            end
        end
    end

    return nil
end

local function scall(tbl, method, ...)
    if type(tbl) ~= "table" then return nil end
    local fn = tbl[method]
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then return nil end
    return a, b, c, d, e
end

local function safeBool(v)
    return v == true
end

local function safeNum(v, fallback)
    if type(v) == "number" then return v end
    return fallback
end

local function safeStr(v, fallback)
    if type(v) == "string" then return v end
    return fallback
end

local function getWidgetValue(widget, fallback)
    if widget and type(widget.Get) == "function" then
        local ok, value = pcall(widget.Get, widget)
        if ok and value ~= nil then
            return value
        end
    end
    return fallback
end

local function dummyWidget(defaultValue)
    return {
        Get = function() return defaultValue end,
        Set = function() end,
        Disabled = function() end,
        ToolTip = function() end,
        Icon = function() end,
        Image = function() end,
        Gear = function() return nil end,
    }
end

local function buildFallbackUI()
    local ui = { _fallback = true }
    return setmetatable(ui, {
        __index = function(t, k)
            local w = dummyWidget(nil)
            rawset(t, k, w)
            return w
        end
    })
end

local function debugEnabled()
    return UI and getWidgetValue(UI.DebugLog, DEFAULTS.debugLog)
end

local function debugLog(msg)
    if not debugEnabled() then return end
    if type(Log) == "table" and type(Log.Write) == "function" then
        pcall(Log.Write, string.format("[%s] %s", META.ID, tostring(msg)))
    end
end

local function safeNowGame()
    local t = scall(GameRules, "GetGameTime")
    if type(t) == "number" then return t end
    t = scall(GlobalVars, "GetCurrentTime")
    if type(t) == "number" then return t end
    return os.clock()
end

local function isInGame()
    local v = scall(Engine, "IsInGame")
    if type(v) == "boolean" then return v end
    return true
end

local function getLocalHero()
    local hero = scall(Heroes, "GetLocal")
    if not hero then return nil end
    local alive = mcall(hero, "IsAlive")
    if alive == false then return nil end
    return hero
end

local function getEntityIndex(ent)
    if not ent then return nil end
    local idx = mcall(ent, "GetIndex")
    if type(idx) == "number" then return idx end
    idx = mcall(ent, "EntIndex")
    if type(idx) == "number" then return idx end
    return nil
end

local function getPos(ent)
    if not ent then return nil end
    local p = mcall(ent, "GetAbsOrigin")
    if p then return p end
    p = mcall(ent, "GetNetOrigin")
    return p
end

local function vecDistance(a, b)
    if not a or not b then return math.huge end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    local dz = (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function getTeamNum(ent)
    return safeNum(mcall(ent, "GetTeamNum"), -1)
end

local function isAlive(ent)
    local v = mcall(ent, "IsAlive")
    return v ~= false and v ~= nil
end

local function isDormant(ent)
    return safeBool(mcall(ent, "IsDormant"))
end

local function isSameTeam(a, b)
    local v = mcall(a, "IsSameTeam", b)
    if type(v) == "boolean" then return v end
    return getTeamNum(a) == getTeamNum(b)
end

local function isHero(ent)
    return safeBool(mcall(ent, "IsHero"))
end

local function isIllusion(ent)
    return safeBool(mcall(ent, "IsIllusion"))
end

local function isClone(ent)
    return safeBool(mcall(ent, "IsClone"))
end

local function isTempestDouble(ent)
    return safeBool(mcall(ent, "IsTempestDouble"))
end

local function isVisible(ent)
    local v = mcall(ent, "IsVisible")
    if type(v) == "boolean" then return v end
    return true
end

local function isWard(ent)
    return safeBool(mcall(ent, "IsWard"))
end

local function isCourier(ent)
    return safeBool(mcall(ent, "IsCourier"))
end

local function isTower(ent)
    return safeBool(mcall(ent, "IsTower"))
end

local function isCreep(ent)
    return safeBool(mcall(ent, "IsCreep"))
end

local function isStructure(ent)
    local v = mcall(ent, "IsStructure")
    if type(v) == "boolean" then return v end
    v = mcall(ent, "IsBuilding")
    return safeBool(v)
end

local function getHealth(ent)
    return safeNum(mcall(ent, "GetHealth"), 0)
end

local function getMaxHealth(ent)
    return safeNum(mcall(ent, "GetMaxHealth"), 0)
end

local function getHealthPct(ent)
    local hpPct = mcall(ent, "GetHealthPercent")
    if type(hpPct) == "number" then return hpPct end
    local hp = getHealth(ent)
    local maxHp = getMaxHealth(ent)
    if maxHp <= 0 then return 0 end
    return (hp / maxHp) * 100.0
end

local function getMana(ent)
    return safeNum(mcall(ent, "GetMana"), 0)
end

local function getHeroNameLocalized(hero)
    local heroName = safeStr(mcall(hero, "GetHeroName"), safeStr(mcall(hero, "GetUnitName"), "Unknown"))
    if type(GameLocalizer) == "table" and type(GameLocalizer.FindNPC) == "function" and heroName then
        local ok, localized = pcall(GameLocalizer.FindNPC, heroName)
        if ok and type(localized) == "string" and localized ~= "" then
            return localized
        end
    end
    if type(heroName) ~= "string" then return "Unknown" end
    local short = heroName:gsub("^npc_dota_hero_", ""):gsub("_", " ")
    if short == "" then return heroName end
    return short
end

local function getAllHeroes()
    local list = scall(Heroes, "GetAll")
    if type(list) == "table" then return list end
    return {}
end

local function getAllTowers()
    local list = scall(Towers, "GetAll")
    if type(list) == "table" then return list end
    return {}
end

local function getAllNPCs()
    local list = scall(NPCs, "GetAll")
    if type(list) == "table" then return list end
    return {}
end

local function heroIsTrackableCombatHero(hero)
    if not hero then return false end
    if not isHero(hero) then return false end
    if not isAlive(hero) then return false end
    if isDormant(hero) then return false end
    if isIllusion(hero) or isClone(hero) or isTempestDouble(hero) then return false end
    return true
end

-- -----------------------------------------------------------------------------
-- Render helpers (supports both Render v1/v2-ish signatures)
-- -----------------------------------------------------------------------------

local function ensureFonts()
    if State.fonts.loaded then return end
    State.fonts.loaded = true

    if type(Render) ~= "table" then return end

    local fontMain, fontSmall

    if type(Render.CreateFont) == "function" then
        local weightNormal = Enum and Enum.FontWeight and (Enum.FontWeight.NORMAL or Enum.FontWeight.REGULAR) or 400
        local ok1, f1 = pcall(Render.CreateFont, "Tahoma", 14, weightNormal)
        if ok1 and f1 then fontMain = f1 end
        local ok2, f2 = pcall(Render.CreateFont, "Tahoma", 12, weightNormal)
        if ok2 and f2 then fontSmall = f2 end
        if fontMain or fontSmall then
            State.fonts.mode = "createfont"
        end
    end

    if (not fontMain or not fontSmall) and type(Render.LoadFont) == "function" then
        local flags = Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or 0
        local ok1, f1 = pcall(Render.LoadFont, "Tahoma", 14, flags)
        if ok1 and f1 and not fontMain then fontMain = f1 end
        local ok2, f2 = pcall(Render.LoadFont, "Tahoma", 12, flags)
        if ok2 and f2 and not fontSmall then fontSmall = f2 end
        if fontMain or fontSmall then
            State.fonts.mode = "loadfont"
        end
    end

    State.fonts.main = fontMain
    State.fonts.small = fontSmall or fontMain
end

local function getScreenSize()
    if type(Render) == "table" then
        local s = scall(Render, "GetScreenSize")
        if s then return s end
        s = scall(Render, "ScreenSize")
        if s then return s end
    end
    return V2(1920, 1080)
end

local function renderText(font, size, text, pos, color)
    if type(Render) ~= "table" or type(Render.Text) ~= "function" or not font then return false end

    local ok = pcall(Render.Text, font, pos, text, color)
    if ok then return true end

    ok = pcall(Render.Text, font, size, text, pos, color)
    return ok
end

local function renderTextShadow(font, size, text, pos, color, shadowColor)
    if type(Render) == "table" and type(Render.TextShadow) == "function" and font then
        local ok = pcall(Render.TextShadow, font, pos, text, color, shadowColor, V2(1, 1))
        if ok then return true end
    end
    if renderText(font, size, text, V2((pos.x or 0) + 1, (pos.y or 0) + 1), shadowColor) then
        return renderText(font, size, text, pos, color)
    end
    return false
end

local function getTextSize(font, size, text)
    if type(Render) == "table" and font then
        if type(Render.GetTextSize) == "function" then
            local ok, v = pcall(Render.GetTextSize, font, text)
            if ok and v then return v end
        end
        if type(Render.TextSize) == "function" then
            local ok, v = pcall(Render.TextSize, font, size, text)
            if ok and v then return v end
        end
    end
    local w = math.floor(#tostring(text) * (size * 0.55))
    return V2(w, size)
end

local function filledRect(x, y, w, h, color, rounding)
    if type(Render) ~= "table" or type(Render.FilledRect) ~= "function" then return false end
    rounding = rounding or 0
    local p0 = V2(x, y)
    local sz = V2(w, h)
    local p1 = V2(x + w, y + h)

    -- Prefer p0->p1 first: many UCZone builds accept two corner points.
    local ok = pcall(Render.FilledRect, p0, p1, color, rounding)
    if ok then return true end

    -- Fallback for builds that expect (pos, size).
    ok = pcall(Render.FilledRect, p0, sz, color, rounding)
    return ok
end

local function outlineRect(x, y, w, h, color, rounding, thickness)
    if type(Render) ~= "table" then return false end
    rounding = rounding or 0
    thickness = thickness or 1
    local p0 = V2(x, y)
    local sz = V2(w, h)
    local p1 = V2(x + w, y + h)

    if type(Render.OutlineRect) == "function" then
        local ok = pcall(Render.OutlineRect, p0, p1, color, rounding, thickness)
        if ok then return true end
        ok = pcall(Render.OutlineRect, p0, sz, color, rounding, thickness)
        if ok then return true end
    end
    if type(Render.Rect) == "function" then
        local ok = pcall(Render.Rect, p0, p1, color, rounding, Enum and Enum.DrawFlags and Enum.DrawFlags.None or nil, thickness)
        if ok then return true end
        ok = pcall(Render.Rect, p0, sz, color, rounding, Enum and Enum.DrawFlags and Enum.DrawFlags.None or nil, thickness)
        if ok then return true end
    end
    return false
end

local function worldToScreen(worldPos)
    if type(Render) ~= "table" or type(Render.WorldToScreen) ~= "function" or not worldPos then
        return nil, false
    end

    local ok, a, b, c = pcall(Render.WorldToScreen, worldPos)
    if not ok then return nil, false end

    if type(a) == "table" and a.x ~= nil and a.y ~= nil then
        local visible = (a.visible ~= nil) and a.visible or (type(b) == "boolean" and b or false)
        return V2(a.x, a.y), visible
    end

    if type(a) == "number" and type(b) == "number" then
        return V2(a, b), c == true
    end

    if type(a) == "userdata" or type(a) == "table" then
        return a, b == true
    end

    return nil, false
end

-- -----------------------------------------------------------------------------
-- Menu
-- -----------------------------------------------------------------------------

local function safeMenuSwitch(group, label, defaultValue)
    local hasSwitch = false
    if group then
        local okHas, fn = pcall(function() return group.Switch end)
        hasSwitch = okHas and type(fn) == "function"
    end
    if hasSwitch then
        local ok, w = pcall(group.Switch, group, label, defaultValue)
        if ok and w then return w end
    end
    return dummyWidget(defaultValue)
end

local function safeMenuSlider(group, label, minv, maxv, defaultValue, fmt)
    local hasSlider = false
    if group then
        local okHas, fn = pcall(function() return group.Slider end)
        hasSlider = okHas and type(fn) == "function"
    end
    if hasSlider then
        local ok, w = pcall(group.Slider, group, label, minv, maxv, defaultValue, fmt)
        if ok and w then return w end
    end
    return dummyWidget(defaultValue)
end

local function safeToolTip(widget, text)
    if widget and type(widget.ToolTip) == "function" then
        pcall(widget.ToolTip, widget, text)
    end
end

local function safeWidgetIcon(widget, icon)
    if not widget or type(widget.Icon) ~= "function" or not icon then
        return false
    end

    local icons = (type(icon) == "table") and icon or { icon }
    for i = 1, #icons do
        local v = icons[i]
        if type(v) == "string" and v ~= "" then
            local ok = pcall(widget.Icon, widget, v)
            if ok then return true end
        end
    end
    return false
end

local function menuMethod(obj, name)
    if not obj then return nil end
    local ok, fn = pcall(function() return obj[name] end)
    if ok and type(fn) == "function" then
        return fn
    end
    return nil
end

local function isMenuGroupLike(obj)
    return menuMethod(obj, "Switch") ~= nil and menuMethod(obj, "Slider") ~= nil
end

local function isMenuContainerLike(obj)
    return menuMethod(obj, "Switch") ~= nil and menuMethod(obj, "Slider") ~= nil
end

local function safeOpenMenu(obj)
    local openFn = menuMethod(obj, "Open")
    if openFn then
        pcall(openFn, obj)
    end
end

local function safeMenuCreateGroup(parent, name)
    if not parent then return nil end

    -- Preferred path for CMenuGroup -> CThirdTab -> Create(groupName)
    local parentFn = menuMethod(parent, "Parent")
    if parentFn then
        local okParent, thirdTab = pcall(parentFn, parent)
        if okParent and thirdTab then
            local findFn = menuMethod(thirdTab, "Find")
            if findFn then
                local okFind, existing = pcall(findFn, thirdTab, name)
                if okFind and isMenuGroupLike(existing) then
                    safeOpenMenu(existing)
                    return existing
                end
            end

            local createOnThird = menuMethod(thirdTab, "Create")
            if createOnThird then
                local okCreate, child = pcall(createOnThird, thirdTab, name)
                if okCreate and isMenuGroupLike(child) then
                    safeOpenMenu(child)
                    return child
                end
            end
        end
    end

    -- Fallback for environments where parent itself supports :Create().
    local createFn = menuMethod(parent, "Create")
    if createFn then
        local ok, child = pcall(createFn, parent, name)
        if ok and child and isMenuGroupLike(child) then
            safeOpenMenu(child)
            return child
        end
    end
    return nil
end

local function tryMenuCreate(...)
    if type(Menu) ~= "table" or type(Menu.Create) ~= "function" then return nil end
    local ok, v = pcall(Menu.Create, ...)
    if ok then return v end
    return nil
end

local function tryMenuFind(...)
    if type(Menu) ~= "table" or type(Menu.Find) ~= "function" then return nil end
    local ok, v = pcall(Menu.Find, ...)
    if ok then return v end
    return nil
end

local function tryFindOrCreateChild(parent, childName)
    if not parent or not childName then return nil end

    local findFn = menuMethod(parent, "Find")
    if findFn then
        local okFind, child = pcall(findFn, parent, childName)
        if okFind and child then
            return child
        end
    end

    local createFn = menuMethod(parent, "Create")
    if createFn then
        local okCreate, child = pcall(createFn, parent, childName)
        if okCreate and child then
            return child
        end
    end

    return nil
end

local function safeSetMenuIcon(obj, icon)
    if not obj or type(icon) ~= "string" or icon == "" then return false end
    local iconFn = menuMethod(obj, "Icon")
    if not iconFn then return false end
    local ok = pcall(iconFn, obj, icon)
    return ok == true
end

local function createInfoScreenMenuGroup()
    -- User-requested host container: Menu.Find("Info Screen", "Main")
    local node = tryMenuFind(MENU_CFG.INFO_FIRST_TAB, MENU_CFG.INFO_SECTION)

    -- Extra fallback: resolve first tab then section manually if this build's Menu.Find
    -- doesn't return partial path objects consistently.
    if not node then
        local first = tryMenuFind(MENU_CFG.INFO_FIRST_TAB)
        node = tryFindOrCreateChild(first, MENU_CFG.INFO_SECTION)
    end
    if not node then
        return nil
    end

    safeOpenMenu(node)

    local secondTab = nil
    local thirdTab = nil
    local helpTabForIcon = nil

    if isMenuGroupLike(node) then
        safeOpenMenu(node)
        return node
    end

    -- If node has :Icon(), it's usually CSecondTab (or CThirdTab in some overloads).
    -- We handle both by trying to create Help Alert beneath it first.
    if menuMethod(node, "Icon") ~= nil then
        local maybeChild = tryFindOrCreateChild(node, MENU_CFG.SCRIPT_NAME)
        if maybeChild and isMenuGroupLike(maybeChild) then
            safeOpenMenu(maybeChild)
            safeSetMenuIcon(node, MENU_CFG.TAB_ICON)
            return maybeChild
        end
        if maybeChild then
            thirdTab = maybeChild
            helpTabForIcon = maybeChild
        else
            -- Node itself may already be the Help Alert tab.
            thirdTab = node
            helpTabForIcon = node
        end
        secondTab = node
    else
        -- Node is likely CTabSection "Main": create/find second tab "Help Alert".
        secondTab = tryFindOrCreateChild(node, MENU_CFG.SCRIPT_NAME)
        helpTabForIcon = secondTab
        if not secondTab then return nil end
    end

    safeOpenMenu(secondTab)
    safeSetMenuIcon(helpTabForIcon, MENU_CFG.TAB_ICON)

    if not thirdTab then
        thirdTab = tryFindOrCreateChild(secondTab, MENU_CFG.THIRD_TAB)
    end
    if not thirdTab then return nil end

    safeOpenMenu(thirdTab)
    if helpTabForIcon ~= thirdTab then
        safeSetMenuIcon(thirdTab, MENU_CFG.TAB_ICON)
    end

    local group = tryFindOrCreateChild(thirdTab, MENU_CFG.ROOT_GROUP)
    if isMenuGroupLike(group) then
        safeOpenMenu(group)
        return group
    end
    return nil
end

local function createMenuGroup()
    if type(Menu) ~= "table" or type(Menu.Create) ~= "function" then
        return nil
    end

    local infoGroup = createInfoScreenMenuGroup()
    if isMenuGroupLike(infoGroup) then
        return infoGroup
    end

    -- Primary documented path: return CMenuGroup directly.
    local directCandidates = {
        { "Scripts", "User Scripts", MENU_CFG.SCRIPT_NAME, "Main", "Settings" },
        { "Scripts", "User Scripts", MENU_CFG.SCRIPT_NAME, "Settings", "Main" },
        { "Scripts", "User Scripts", MENU_CFG.SCRIPT_NAME, "General", "Main" },
    }
    for i = 1, #directCandidates do
        local args = directCandidates[i]
        local group = tryMenuCreate(args[1], args[2], args[3], args[4], args[5])
        if isMenuGroupLike(group) then
            local openFn = menuMethod(group, "Open")
            if openFn then pcall(openFn, group) end
            return group
        end
    end

    -- Fallback chain for environments where Menu.Create returns tabs/sections.
    local root = tryMenuCreate("Scripts", "User Scripts", MENU_CFG.SCRIPT_NAME)
    if isMenuGroupLike(root) then
        local openFn = menuMethod(root, "Open")
        if openFn then pcall(openFn, root) end
        return root
    end

    local createFn = menuMethod(root, "Create")
    if createFn then
        local ok1, settings = pcall(createFn, root, "Settings")
        if ok1 and settings then
            if isMenuGroupLike(settings) then
                local openFn = menuMethod(settings, "Open")
                if openFn then pcall(openFn, settings) end
                return settings
            end
            local createFn2 = menuMethod(settings, "Create")
            if createFn2 then
                local ok2, main = pcall(createFn2, settings, "Main")
                if ok2 and isMenuGroupLike(main) then
                    local openFn = menuMethod(main, "Open")
                    if openFn then pcall(openFn, main) end
                    return main
                end
                local ok3, mainSettings = pcall(createFn2, settings, "Main Settings")
                if ok3 and isMenuGroupLike(mainSettings) then
                    local openFn = menuMethod(mainSettings, "Open")
                    if openFn then pcall(openFn, mainSettings) end
                    return mainSettings
                end
            end
        end
    end

    return nil
end

local function buildUI()
    ensureI18N()
    local group = createMenuGroup()

    local ui = {}
    ui._group = group
    ui._menuReady = group ~= nil

    local function section(nameKey)
        local label = t(nameKey)
        local child = safeMenuCreateGroup(group, label)
        if isMenuContainerLike(child) then
            return child
        end
        return group
    end

    local function decorate(widget, iconCandidates, tipKey)
        if iconCandidates then
            safeWidgetIcon(widget, iconCandidates)
        end
        if tipKey then
            safeToolTip(widget, t(tipKey))
        end
    end

    local Icons = {
        -- UCZone :Icon() expects FontAwesome glyph string (e.g. "\u{f011}"), not icon names.
        power = { "\u{f011}" },   -- power-off
        trade = { "\u{f0ec}" },   -- exchange-arrows / trade-ish
        dive = { "\u{f0e7}" },    -- bolt
        gank = { "\u{f0c0}" },    -- users
        teleport = { "\u{f0b2}" },-- arrows/transfer
        scan = { "\u{f002}" },    -- search
        radius = { "\u{f140}" },  -- bullseye/target
        clock = { "\u{f017}" },   -- clock
        warning = { "\u{f06a}" }, -- warning
        heart = { "\u{f21e}" },   -- heartbeat
        tower = { "\u{f6b6}" },   -- location/tower-ish (used in local scripts)
        bell = { "\u{f0f3}" },    -- bell
        map = { "\u{f0ac}" },     -- globe/map-ish
        eye = { "\u{f06e}" },     -- eye
        bug = { "\u{f188}" },     -- bug
        terminal = { "\u{f03a}" },-- list/terminal-ish
    }

    ui.Enabled = safeMenuSwitch(group, t("menu_enable"), DEFAULTS.enabled)
    decorate(ui.Enabled, Icons.power, "tip_enable")

    local grpAlertTypes = section("menu_group_alert_types")
    local grpDetection = section("menu_group_detection")
    local grpTeleport = section("menu_group_teleport")
    local grpNotifications = section("menu_group_notifications")
    local grpDebug = section("menu_group_debug")

    ui.TradeAlerts = safeMenuSwitch(grpAlertTypes, t("menu_trade_alerts"), DEFAULTS.tradeAlerts)
    ui.DiveAlerts = safeMenuSwitch(grpAlertTypes, t("menu_dive_alerts"), DEFAULTS.diveAlerts)
    ui.GankAlerts = safeMenuSwitch(grpAlertTypes, t("menu_gank_alerts"), DEFAULTS.gankAlerts)
    decorate(ui.TradeAlerts, Icons.trade)
    decorate(ui.DiveAlerts, Icons.dive)
    decorate(ui.GankAlerts, Icons.gank)

    ui.ScanIntervalMs = safeMenuSlider(grpDetection, t("menu_scan_interval"), 50, 1000, DEFAULTS.scanIntervalMs, "%d")
    ui.EnemyCombatRadius = safeMenuSlider(grpDetection, t("menu_enemy_combat_radius"), 600, 2500, DEFAULTS.enemyCombatRadius, "%d")
    ui.TradeRadius = safeMenuSlider(grpDetection, t("menu_trade_radius"), 300, 1500, DEFAULTS.tradeRadius, "%d")
    ui.TowerProtectRadius = safeMenuSlider(grpDetection, t("menu_tower_protect_radius"), 500, 2000, DEFAULTS.towerProtectRadius, "%d")
    ui.GankMinEnemies = safeMenuSlider(grpDetection, t("menu_gank_min_enemies"), 2, 5, DEFAULTS.gankMinEnemies, "%d")
    ui.TradeMinHpDropPct = safeMenuSlider(grpDetection, t("menu_trade_min_hp_drop"), 1, 40, DEFAULTS.tradeMinHpDropPct, "%d%%")
    ui.GankMinHpDropPct = safeMenuSlider(grpDetection, t("menu_gank_min_hp_drop"), 1, 60, DEFAULTS.gankMinHpDropPct, "%d%%")
    ui.PainFactorThreshold = safeMenuSlider(grpDetection, t("menu_pain_factor"), 0, 200, DEFAULTS.painFactorThreshold, "%d")
    ui.TradeDeltaMargin = safeMenuSlider(grpDetection, t("menu_trade_delta"), 0, 30, DEFAULTS.tradeDeltaMargin, "%d%%")
    ui.VisibleEnemiesOnly = safeMenuSwitch(grpDetection, t("menu_visible_only"), DEFAULTS.visibleEnemiesOnly)
    decorate(ui.ScanIntervalMs, Icons.clock)
    decorate(ui.EnemyCombatRadius, Icons.radius)
    decorate(ui.TradeRadius, Icons.trade)
    decorate(ui.TowerProtectRadius, Icons.tower)
    decorate(ui.GankMinEnemies, Icons.gank)
    decorate(ui.TradeMinHpDropPct, Icons.heart)
    decorate(ui.GankMinHpDropPct, Icons.warning)
    decorate(ui.PainFactorThreshold, Icons.warning, "tip_pain_factor")
    decorate(ui.TradeDeltaMargin, Icons.trade)
    decorate(ui.VisibleEnemiesOnly, Icons.eye, "tip_visible_only")

    ui.MaxAnchorDistance = safeMenuSlider(grpTeleport, t("menu_max_tp_distance"), 400, 4000, DEFAULTS.maxAnchorDistance, "%d")
    decorate(ui.MaxAnchorDistance, Icons.teleport)

    ui.PerAllyAlertCooldownSec = safeMenuSlider(grpNotifications, t("menu_alert_cd"), 1, 30, DEFAULTS.perAllyAlertCooldownSec, "%d")
    ui.HudAlerts = safeMenuSwitch(grpNotifications, t("menu_hud_alerts"), DEFAULTS.hudAlerts)
    ui.MiniMapPing = safeMenuSwitch(grpNotifications, t("menu_minimap_ping"), DEFAULTS.minimapPing)
    ui.PingCooldownMs = safeMenuSlider(grpNotifications, t("menu_ping_cd"), 200, 10000, DEFAULTS.pingCooldownMs, "%d")
    ui.AlertDurationMs = safeMenuSlider(grpNotifications, t("menu_alert_duration"), 500, 10000, DEFAULTS.alertDurationMs, "%d")
    decorate(ui.PerAllyAlertCooldownSec, Icons.clock)
    decorate(ui.HudAlerts, Icons.bell)
    decorate(ui.MiniMapPing, Icons.map)
    decorate(ui.PingCooldownMs, Icons.clock)
    decorate(ui.AlertDurationMs, Icons.clock)

    ui.DebugDraw = safeMenuSwitch(grpDebug, t("menu_debug_draw"), DEFAULTS.debugDraw)
    ui.DebugLog = safeMenuSwitch(grpDebug, t("menu_debug_log"), DEFAULTS.debugLog)
    decorate(ui.DebugDraw, Icons.bug)
    decorate(ui.DebugLog, Icons.terminal)

    return ui
end

local function initUI(forceRebuild)
    if UI_MENU_BUILT and not forceRebuild then
        return UI
    end

    local built = buildUI()
    if built and built._group then
        UI = built
        UI._fallback = false
        UI_MENU_BUILT = true
    else
        -- Keep fallback and allow future retries.
        if not UI or not UI._fallback then
            UI = buildFallbackUI()
        end
        UI_MENU_BUILT = false
    end
    return UI
end

UI = buildFallbackUI()

-- -----------------------------------------------------------------------------
-- Hero tracking
-- -----------------------------------------------------------------------------

local function getOrCreateTrack(entIndex)
    if not entIndex then return nil end
    local tr = State.heroTracks[entIndex]
    if tr then return tr end
    tr = {
        samples = {},
        lastAlertAtByType = {},
        lastAlertSeverityByType = {},
        lastAlertHpPctByType = {},
        lastPingAt = -1e9,
        lastSeenAt = -1e9,
    }
    State.heroTracks[entIndex] = tr
    return tr
end

local function pruneTrackSamples(track, now)
    if not track or not track.samples then return end
    local cutoff = now - INTERNAL.TRACK_RETENTION_SEC
    local samples = track.samples
    local firstKeep = 1
    while firstKeep <= #samples do
        local s = samples[firstKeep]
        if s and s.t and s.t >= cutoff then
            break
        end
        firstKeep = firstKeep + 1
    end
    if firstKeep > 1 then
        for i = firstKeep, #samples do
            samples[i - firstKeep + 1] = samples[i]
        end
        for i = #samples - firstKeep + 2, #samples do
            samples[i] = nil
        end
    end
end

local function pushHeroSample(hero, now)
    local entIndex = getEntityIndex(hero)
    if not entIndex then return nil end
    local track = getOrCreateTrack(entIndex)
    if not track then return nil end

    local pos = getPos(hero)
    local hp = getHealth(hero)
    local hpPct = getHealthPct(hero)
    local sample = {
        t = now,
        hp = hp,
        hpPct = hpPct,
        pos = pos,
        recentDamage = safeNum(mcall(hero, "GetRecentDamage"), 0),
        painFactor = safeNum(mcall(hero, "GetPainFactor"), 0),
        lastHurtTime = safeNum(mcall(hero, "GetLastHurtTime"), -1e9),
    }

    track.samples[#track.samples + 1] = sample
    track.lastSeenAt = now
    track.current = sample
    pruneTrackSamples(track, now)
    return track
end

local function sampleAtOrBefore(track, targetTime)
    if not track or not track.samples or #track.samples == 0 then return nil end
    local samples = track.samples
    local fallback = samples[1]
    for i = #samples, 1, -1 do
        local s = samples[i]
        if s and s.t and s.t <= targetTime then
            return s
        end
    end
    return fallback
end

local function getHeroDelta(track, windowSec)
    local zero = {
        hpDropPct = 0,
        hpDrop = 0,
        dt = 0,
        older = nil,
        current = track and track.current or nil,
    }
    if not track or not track.current then return zero end

    local cur = track.current
    local older = sampleAtOrBefore(track, (cur.t or 0) - windowSec)
    if not older then
        zero.current = cur
        return zero
    end

    local hpDrop = math.max(0, safeNum(older.hp, cur.hp) - safeNum(cur.hp, 0))
    local hpDropPct = math.max(0, safeNum(older.hpPct, cur.hpPct) - safeNum(cur.hpPct, 0))
    local dt = math.max(0, (cur.t or 0) - (older.t or 0))

    return {
        hpDropPct = hpDropPct,
        hpDrop = hpDrop,
        dt = dt,
        older = older,
        current = cur,
    }
end

local function pruneStaleTracks(now)
    for entIndex, tr in pairs(State.heroTracks) do
        if not tr or (now - safeNum(tr.lastSeenAt, -1e9)) > 15.0 then
            State.heroTracks[entIndex] = nil
        end
    end
end

-- -----------------------------------------------------------------------------
-- Teleport item detection
-- -----------------------------------------------------------------------------

local function getItemByName(hero, wantedName, allowDeepSlotScan)
    if not hero or not wantedName then return nil end

    -- In this repo/API build, NPC.GetItem(hero, "item_name") is a known working pattern.
    if type(NPC) == "table" and type(NPC.GetItem) == "function" then
        local ok, v = pcall(NPC.GetItem, hero, wantedName)
        if ok and v then return v end
    end

    -- Try instance-style lookups (may fail on userdata builds).
    local item = mcall(hero, "GetItemByName", wantedName)
    if item then return item end

    if type(NPC) == "table" and type(NPC.GetItemByName) == "function" then
        local ok, v = pcall(NPC.GetItemByName, hero, wantedName)
        if ok and v then return v end
    end

    -- Dedicated TP slot may expose the scroll as an ability, not an inventory item.
    if type(NPC) == "table" and type(NPC.GetAbility) == "function" then
        local ok, v = pcall(NPC.GetAbility, hero, wantedName)
        if ok and v then return v end
    end
    if type(NPC) == "table" and type(NPC.GetAbilityByName) == "function" then
        local ok, v = pcall(NPC.GetAbilityByName, hero, wantedName)
        if ok and v then return v end
    end
    do
        local ab = mcall(hero, "GetAbilityByName", wantedName)
        if ab then return ab end
    end

    if allowDeepSlotScan == false then
        return nil
    end

    -- Last-resort slot scan. Include TP slot (commonly 15) and neutral (16).
    for slot = 0, 16 do
        local it = mcall(hero, "GetItem", slot)
        if not it and type(NPC) == "table" and type(NPC.GetItem) == "function" then
            local ok, v = pcall(NPC.GetItem, hero, slot)
            if ok then it = v end
        end
        if it then
            local nm = safeStr(mcall(it, "GetName"), nil)
            if nm == wantedName then
                return it
            end
        end
    end

    -- Last-resort ability scan for dedicated slots / custom representations.
    for slot = 0, 63 do
        local ab = mcall(hero, "GetAbility", slot)
        if not ab and type(NPC) == "table" and type(NPC.GetAbility) == "function" then
            local ok, v = pcall(NPC.GetAbility, hero, slot)
            if ok then ab = v end
        end
        if ab then
            local nm = safeStr(mcall(ab, "GetName"), nil)
            if nm == wantedName then
                return ab
            end
        end
    end

    return nil
end

local function itemName(item)
    return safeStr(mcall(item, "GetName"), nil)
end

local function itemSlot(item)
    return safeNum(mcall(item, "GetItemSlot"), -1)
end

local function itemCharges(item)
    local v = mcall(item, "GetCurrentCharges")
    if type(v) == "number" then return v end
    return nil
end

local function itemCanOutOfInventory(item)
    local v = mcall(item, "CanBeUsedOutOfInventory")
    if type(v) == "boolean" then return v end
    return false
end

local function itemIsActivated(item)
    local v = mcall(item, "IsActivated")
    if type(v) == "boolean" then return v end
    return true
end

local function itemIsReady(item)
    local v = mcall(item, "IsReady")
    if type(v) == "boolean" then return v end
    return nil
end

local function itemIsCastable(item, mana)
    local v = mcall(item, "IsCastable", mana)
    if type(v) == "boolean" then return v end
    return nil
end

local function canUseAbilityCheck(myHero, ability)
    if not myHero or not ability then return true end
    local result = mcall(myHero, "CanUseAbility", ability)
    if result == nil then return true end

    local successEnum = Enum and Enum.AbilityCastResult and Enum.AbilityCastResult.SUCCESS or nil
    if successEnum ~= nil then
        return result == successEnum
    end
    return true
end

local function canUseTeleportItemNow(myHero, item)
    if not myHero or not item then return false, "missing_item" end

    if not itemIsActivated(item) then
        return false, "not_activated"
    end

    local slot = itemSlot(item)
    if slot >= 6 and slot <= 8 and not itemCanOutOfInventory(item) then
        return false, "backpack"
    end

    local name = itemName(item)
    local charges = itemCharges(item)
    if name and name:find("tpscroll", 1, true) and charges ~= nil and charges <= 0 then
        return false, "no_charges"
    end

    local ready = itemIsReady(item)
    if ready == nil then
        ready = itemIsCastable(item, getMana(myHero))
    end
    if ready == false then
        return false, "not_ready"
    end

    if not canUseAbilityCheck(myHero, item) then
        return false, "hero_cannot_use"
    end

    return true, nil
end

local function normalizeTeleportKindByName(name)
    if type(name) ~= "string" then return nil end
    local n = name:lower()
    if n:find("travel_boots_2", 1, true) then return "travel2" end
    if n:find("travel_boots", 1, true) then return "travel1" end
    if n == "item_tpscroll"
        or n:find("tpscroll", 1, true)
        or n:find("teleport_scroll", 1, true)
        or (n:find("teleport", 1, true) and n:find("scroll", 1, true))
    then
        return "scroll"
    end
    return nil
end

local function teleportKindPriority(kind)
    if kind == "travel2" then return 3 end
    if kind == "travel1" then return 2 end
    if kind == "scroll" then return 1 end
    return 0
end

local function getItemByIndexMaybe(hero, index)
    local it = mcall(hero, "GetItemByIndex", index)
    if it then return it end
    if type(NPC) == "table" and type(NPC.GetItemByIndex) == "function" then
        local ok, v = pcall(NPC.GetItemByIndex, hero, index)
        if ok and v then return v end
    end
    return nil
end

local function getAbilityByIndexMaybe(hero, index)
    local ab = mcall(hero, "GetAbilityByIndex", index)
    if ab then return ab end
    if type(NPC) == "table" and type(NPC.GetAbilityByIndex) == "function" then
        local ok, v = pcall(NPC.GetAbilityByIndex, hero, index)
        if ok and v then return v end
    end
    return nil
end

local function enumerateTeleportObjects(hero)
    local seen = {}
    local list = {}

    local function add(obj)
        if not obj then return end
        local name = itemName(obj)
        local kind = normalizeTeleportKindByName(name)
        if not kind then return end

        local key = tostring(mcall(obj, "GetHandle") or getEntityIndex(obj) or obj)
        if seen[key] then return end
        seen[key] = true

        list[#list + 1] = {
            obj = obj,
            kind = kind,
            name = name,
        }
    end

    -- Item-like scans (inventory/backpack/neutral/dedicated slots in custom builds)
    -- 0..20 is enough for common + custom extra slots while keeping CPU cost down.
    for slot = 0, 20 do
        local it = mcall(hero, "GetItem", slot)
        if not it and type(NPC) == "table" and type(NPC.GetItem) == "function" then
            local ok, v = pcall(NPC.GetItem, hero, slot)
            if ok then it = v end
        end
        add(it)
        if not it then
            add(getItemByIndexMaybe(hero, slot))
        end
    end

    -- Ability-like scans (dedicated TP slot often appears here)
    for slot = 0, 63 do
        local ab = mcall(hero, "GetAbility", slot)
        if not ab and type(NPC) == "table" and type(NPC.GetAbility) == "function" then
            local ok, v = pcall(NPC.GetAbility, hero, slot)
            if ok then ab = v end
        end
        add(ab)
        if not ab then
            add(getAbilityByIndexMaybe(hero, slot))
        end
    end

    return list
end

local function buildTpCapability(kind, item, usable, failReason)
    return {
        kind = kind,
        item = item,
        itemName = item and itemName(item) or nil,
        usable = usable == true,
        failReason = failReason,
    }
end

local function findTeleportItem(myHero)
    local candidates = {
        { name = "item_travel_boots_2", kind = "travel2" },
        { name = "item_travel_boots", kind = "travel1" },
        { name = "item_tpscroll", kind = "scroll" },
    }

    local firstUnusable = nil
    for i = 1, #candidates do
        local c = candidates[i]
        local item = getItemByName(myHero, c.name, false)
        if item then
            local usable, reason = canUseTeleportItemNow(myHero, item)
            if usable then
                return buildTpCapability(c.kind, item, true, nil)
            end
            if not firstUnusable then
                firstUnusable = buildTpCapability(c.kind, item, false, reason or "unusable")
            end
        end
    end

    if firstUnusable then
        return firstUnusable
    end

    -- Fuzzy fallback for builds where dedicated TP slot exposes a different object path/name.
    local found = enumerateTeleportObjects(myHero)
    local bestUsable = nil
    local bestUnusable = nil
    for i = 1, #found do
        local row = found[i]
        local usable, reason = canUseTeleportItemNow(myHero, row.obj)
        local cap = buildTpCapability(row.kind, row.obj, usable, reason)
        cap.itemName = row.name or cap.itemName
        if usable then
            if (not bestUsable) or teleportKindPriority(row.kind) > teleportKindPriority(bestUsable.kind) then
                bestUsable = cap
            end
        else
            if (not bestUnusable) or teleportKindPriority(row.kind) > teleportKindPriority(bestUnusable.kind) then
                bestUnusable = cap
            end
        end
    end
    if bestUsable then return bestUsable end
    if bestUnusable then return bestUnusable end

    return buildTpCapability(nil, nil, false, "no_item")
end

local function getTeleportCapabilityCached(myHero, now)
    local prev = State.lastTpCapability
    local refreshSec = INTERNAL.TP_CAPABILITY_REFRESH_MISSING_SEC
    if prev and prev.usable then
        refreshSec = INTERNAL.TP_CAPABILITY_REFRESH_SEC
    end

    if (now - safeNum(State.lastTpRefreshAt, -1e9)) < refreshSec and prev ~= nil then
        return prev
    end

    local cap = findTeleportItem(myHero)
    State.lastTpCapability = cap
    State.lastTpRefreshAt = now
    return cap
end

-- -----------------------------------------------------------------------------
-- Teleport anchor search
-- -----------------------------------------------------------------------------

local function isValidFriendlyTowerAnchor(tower, myHero)
    if not tower or not myHero then return false end
    if not isAlive(tower) then return false end
    if isDormant(tower) then return false end
    if not isSameTeam(tower, myHero) then return false end
    if not isTower(tower) then return false end
    return true
end

local function isValidTravelNonHeroAnchor(npc, myHero)
    if not npc or not myHero then return false end
    if not isAlive(npc) then return false end
    if isDormant(npc) then return false end
    if not isSameTeam(npc, myHero) then return false end
    if isHero(npc) then return false end
    if isTower(npc) then return false end
    if isCourier(npc) then return false end
    if isWard(npc) then return false end
    if isIllusion(npc) then return false end

    if isCreep(npc) or isStructure(npc) then return true end
    if safeBool(mcall(npc, "IsSummoned")) then return true end
    return false
end

local function isValidTravelHeroAnchor(hero, myHero, allowSelfTarget)
    if not hero or not myHero then return false end
    if not isHero(hero) then return false end
    if not isAlive(hero) then return false end
    if isDormant(hero) then return false end
    if not isSameTeam(hero, myHero) then return false end
    if isIllusion(hero) or isClone(hero) or isTempestDouble(hero) then return false end

    if not allowSelfTarget then
        local myIdx = getEntityIndex(myHero)
        local heroIdx = getEntityIndex(hero)
        if myIdx and heroIdx and myIdx == heroIdx then
            return false
        end
    end
    return true
end

local function nearestAnchorFromList(list, myHero, allyPos, maxDist, validator, anchorType)
    local best = nil
    local bestDist = math.huge
    for i = 1, #list do
        local ent = list[i]
        if validator(ent, myHero) then
            local pos = getPos(ent)
            if pos then
                local d = vecDistance(pos, allyPos)
                if d <= maxDist and d < bestDist then
                    bestDist = d
                    best = {
                        entity = ent,
                        pos = pos,
                        type = anchorType,
                        distance = d,
                    }
                end
            end
        end
    end
    return best
end

local function scanCacheGetTowers(scanCache)
    if scanCache and scanCache.towers ~= nil then
        return scanCache.towers
    end
    local towers = getAllTowers()
    if scanCache then
        scanCache.towers = towers
    end
    return towers
end

local function scanCacheGetNPCs(scanCache)
    if scanCache and scanCache.npcs ~= nil then
        return scanCache.npcs
    end
    local npcs = getAllNPCs()
    if scanCache then
        scanCache.npcs = npcs
    end
    return npcs
end

local function findNearestFriendlyTower(allyPos, myHero, maxDist, scanCache)
    local towers = scanCacheGetTowers(scanCache)
    return nearestAnchorFromList(towers, myHero, allyPos, maxDist, isValidFriendlyTowerAnchor, "tower")
end

local function findNearestTravelNonHeroAnchor(allyPos, myHero, maxDist, scanCache)
    local npcs = scanCacheGetNPCs(scanCache)
    return nearestAnchorFromList(npcs, myHero, allyPos, maxDist, isValidTravelNonHeroAnchor, "unit")
end

local function findNearestTravelHeroAnchor(allyPos, myHero, maxDist, preferHero, heroesList)
    local best = nil
    local bestDist = math.huge

    if preferHero and isValidTravelHeroAnchor(preferHero, myHero, false) then
        local pos = getPos(preferHero)
        if pos then
            local d = vecDistance(pos, allyPos)
            if d <= maxDist then
                return {
                    entity = preferHero,
                    pos = pos,
                    type = "hero",
                    distance = d,
                }
            end
        end
    end

    local heroes = heroesList or getAllHeroes()
    local preferIdx = getEntityIndex(preferHero)
    for i = 1, #heroes do
        local hero = heroes[i]
        local hIdx = getEntityIndex(hero)
        if not (preferIdx and hIdx and preferIdx == hIdx) then
            if isValidTravelHeroAnchor(hero, myHero, false) then
                local pos = getPos(hero)
                if pos then
                    local d = vecDistance(pos, allyPos)
                    if d <= maxDist and d < bestDist then
                        bestDist = d
                        best = {
                            entity = hero,
                            pos = pos,
                            type = "hero",
                            distance = d,
                        }
                    end
                end
            end
        end
    end
    return best
end

local function findBestTpAnchorForAlly(myHero, ally, tpCapability, scanCache)
    if not myHero or not ally or not tpCapability or not tpCapability.usable then
        return nil
    end

    local allyPos = getPos(ally)
    if not allyPos then return nil end

    local maxDist = getWidgetValue(UI.MaxAnchorDistance, DEFAULTS.maxAnchorDistance)
    local kind = tpCapability.kind

    if kind == "scroll" then
        return findNearestFriendlyTower(allyPos, myHero, maxDist, scanCache)
    end

    if kind == "travel1" then
        local a1 = findNearestTravelNonHeroAnchor(allyPos, myHero, maxDist, scanCache)
        if a1 then return a1 end
        return findNearestFriendlyTower(allyPos, myHero, maxDist, scanCache)
    end

    if kind == "travel2" then
        local heroList = scanCache and scanCache.allHeroes or nil
        local aHero = findNearestTravelHeroAnchor(allyPos, myHero, maxDist, ally, heroList)
        if aHero then return aHero end
        local aUnit = findNearestTravelNonHeroAnchor(allyPos, myHero, maxDist, scanCache)
        if aUnit then return aUnit end
        return findNearestFriendlyTower(allyPos, myHero, maxDist, scanCache)
    end

    return nil
end

-- -----------------------------------------------------------------------------
-- Threat context
-- -----------------------------------------------------------------------------

local function collectAlliedHeroes(myHero, allHeroes)
    local out = {}
    local myIdx = getEntityIndex(myHero)
    for i = 1, #allHeroes do
        local hero = allHeroes[i]
        if hero and heroIsTrackableCombatHero(hero) and isSameTeam(hero, myHero) then
            local idx = getEntityIndex(hero)
            if not (idx and myIdx and idx == myIdx) then
                out[#out + 1] = hero
            end
        end
    end
    return out
end

local function findNearestFriendlyTowerForPos(myHero, pos, scanCache)
    local maxDist = getWidgetValue(UI.TowerProtectRadius, DEFAULTS.towerProtectRadius)
    return findNearestFriendlyTower(pos, myHero, maxDist, scanCache)
end

local function allyHasCC(hero)
    return safeBool(mcall(hero, "IsStunned"))
        or safeBool(mcall(hero, "IsRooted"))
        or safeBool(mcall(hero, "IsHexed"))
        or safeBool(mcall(hero, "IsSilenced"))
end

local function enemyPassesVisibilityFilter(enemy, visibleOnly)
    if visibleOnly then
        return isVisible(enemy)
    end
    return (not isDormant(enemy)) or isVisible(enemy)
end

local function buildThreatContext(myHero, ally, now, allHeroes, scanCache)
    local allyPos = getPos(ally)
    if not allyPos then return nil end

    local visibleOnly = getWidgetValue(UI.VisibleEnemiesOnly, DEFAULTS.visibleEnemiesOnly)
    local enemyCombatRadius = getWidgetValue(UI.EnemyCombatRadius, DEFAULTS.enemyCombatRadius)
    local tradeRadius = getWidgetValue(UI.TradeRadius, DEFAULTS.tradeRadius)

    local enemyCount = 0
    local allyCount = 0
    local closeEnemyCount = 0
    local primaryEnemy = nil
    local primaryEnemyDist = math.huge

    local allyIdx = getEntityIndex(ally)

    for i = 1, #allHeroes do
        local hero = allHeroes[i]
        if hero and heroIsTrackableCombatHero(hero) then
            local heroPos = getPos(hero)
            if heroPos then
                local d = vecDistance(allyPos, heroPos)
                if d <= enemyCombatRadius then
                    if isSameTeam(hero, myHero) then
                        local hIdx = getEntityIndex(hero)
                        if not (allyIdx and hIdx and allyIdx == hIdx) then
                            allyCount = allyCount + 1
                        end
                    else
                        if enemyPassesVisibilityFilter(hero, visibleOnly) then
                            enemyCount = enemyCount + 1
                            if d <= tradeRadius then
                                closeEnemyCount = closeEnemyCount + 1
                                if d < primaryEnemyDist then
                                    primaryEnemyDist = d
                                    primaryEnemy = hero
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local allyTrack = State.heroTracks[allyIdx]
    local d1 = getHeroDelta(allyTrack, 1.0)
    local d05 = getHeroDelta(allyTrack, 0.5)

    local allyCurrent = allyTrack and allyTrack.current or nil
    local lastHurtTime = allyCurrent and safeNum(allyCurrent.lastHurtTime, -1e9) or safeNum(mcall(ally, "GetLastHurtTime"), -1e9)
    local recentDamage = allyCurrent and safeNum(allyCurrent.recentDamage, 0) or safeNum(mcall(ally, "GetRecentDamage"), 0)
    local painFactor = allyCurrent and safeNum(allyCurrent.painFactor, 0) or safeNum(mcall(ally, "GetPainFactor"), 0)

    local takingDamageNow = ((now - lastHurtTime) <= 1.0) or recentDamage > 0
    local cc = allyHasCC(ally)

    local tower = findNearestFriendlyTowerForPos(myHero, allyPos, scanCache)
    local underFriendlyTower = tower ~= nil

    local primaryEnemyHpDropPct1s = 0
    if primaryEnemy then
        local enemyTrack = State.heroTracks[getEntityIndex(primaryEnemy)]
        primaryEnemyHpDropPct1s = getHeroDelta(enemyTrack, 1.0).hpDropPct or 0
    end

    return {
        ally = ally,
        allyPos = allyPos,
        allyHpPct = getHealthPct(ally),
        enemyCount = enemyCount,
        allyCount = allyCount,
        closeEnemyCount = closeEnemyCount,
        cc = cc,
        hpDropPct1s = d1.hpDropPct or 0,
        hpDropPct05s = d05.hpDropPct or 0,
        takingDamageNow = takingDamageNow,
        underFriendlyTower = underFriendlyTower,
        tower = tower and tower.entity or nil,
        towerPos = tower and tower.pos or nil,
        primaryEnemy = primaryEnemy,
        primaryEnemyHpDropPct1s = primaryEnemyHpDropPct1s,
        recentDamage = recentDamage,
        painFactor = painFactor,
        now = now,
    }
end

-- -----------------------------------------------------------------------------
-- Classification + anti-spam + emit
-- -----------------------------------------------------------------------------

local function classifyThreat(ctx)
    if not ctx or not ctx.ally then return nil end

    local allyName = getHeroNameLocalized(ctx.ally)
    local tradeMinDrop = getWidgetValue(UI.TradeMinHpDropPct, DEFAULTS.tradeMinHpDropPct)
    local gankMinDrop = getWidgetValue(UI.GankMinHpDropPct, DEFAULTS.gankMinHpDropPct)
    local gankMinEnemies = getWidgetValue(UI.GankMinEnemies, DEFAULTS.gankMinEnemies)
    local painThreshold = getWidgetValue(UI.PainFactorThreshold, DEFAULTS.painFactorThreshold)
    local tradeDeltaMargin = getWidgetValue(UI.TradeDeltaMargin, DEFAULTS.tradeDeltaMargin)

    if getWidgetValue(UI.DiveAlerts, DEFAULTS.diveAlerts) then
        local divePressure = ctx.takingDamageNow or ctx.cc or (ctx.hpDropPct1s >= 10)
        if ctx.underFriendlyTower and ctx.enemyCount >= 1 and divePressure then
            local severity = SEVERITY.MED
            if ctx.enemyCount >= 2 or ctx.hpDropPct1s >= 18 then
                severity = SEVERITY.HIGH
            end
            return {
                type = ALERT_TYPES.DIVE,
                severity = severity,
                ally = ctx.ally,
                allyName = allyName,
                enemyCount = ctx.enemyCount,
                reasonText = "tower_dive",
                createdAt = ctx.now,
            }
        end
    end

    if getWidgetValue(UI.GankAlerts, DEFAULTS.gankAlerts) then
        if ctx.enemyCount >= gankMinEnemies and (ctx.takingDamageNow or ctx.cc) then
            local reinforced = false
            if ctx.enemyCount > (ctx.allyCount + 1) then reinforced = true end
            if ctx.hpDropPct1s >= gankMinDrop then reinforced = true end
            if ctx.painFactor >= painThreshold then reinforced = true end

            if reinforced then
                local severity = SEVERITY.MED
                if ctx.enemyCount >= 3 or ctx.hpDropPct1s >= math.max(18, gankMinDrop + 6) then
                    severity = SEVERITY.HIGH
                end
                return {
                    type = ALERT_TYPES.GANK,
                    severity = severity,
                    ally = ctx.ally,
                    allyName = allyName,
                    enemyCount = ctx.enemyCount,
                    reasonText = "gank",
                    createdAt = ctx.now,
                }
            end
        end
    end

    if getWidgetValue(UI.TradeAlerts, DEFAULTS.tradeAlerts) then
        if ctx.closeEnemyCount == 1 and ctx.takingDamageNow and ctx.hpDropPct1s >= tradeMinDrop then
            local enemyDrop = safeNum(ctx.primaryEnemyHpDropPct1s, 0)
            local losing = (ctx.hpDropPct1s >= (enemyDrop + tradeDeltaMargin)) or (enemyDrop < 3)
            if losing then
                local severity = SEVERITY.LOW
                if ctx.hpDropPct1s >= (tradeMinDrop + 8) then
                    severity = SEVERITY.MED
                end
                return {
                    type = ALERT_TYPES.TRADE,
                    severity = severity,
                    ally = ctx.ally,
                    allyName = allyName,
                    enemyCount = ctx.enemyCount,
                    reasonText = "losing_trade",
                    createdAt = ctx.now,
                }
            end
        end
    end

    return nil
end

local function getTrackForHero(hero)
    local idx = getEntityIndex(hero)
    return idx and State.heroTracks[idx] or nil
end

local function shouldEmitAlert(ally, alertType, severity, now)
    local track = getTrackForHero(ally)
    if not track then return true end

    local cooldown = getWidgetValue(UI.PerAllyAlertCooldownSec, DEFAULTS.perAllyAlertCooldownSec)
    local lastAt = safeNum(track.lastAlertAtByType[alertType], -1e9)
    local lastSeverity = safeNum(track.lastAlertSeverityByType[alertType], 0)
    local lastAlertHpPct = track.lastAlertHpPctByType[alertType]
    local curHpPct = track.current and safeNum(track.current.hpPct, getHealthPct(ally)) or getHealthPct(ally)

    if (now - lastAt) >= cooldown then
        return true
    end
    if severity > lastSeverity then
        return true
    end
    if type(lastAlertHpPct) == "number" and (lastAlertHpPct - curHpPct) >= INTERNAL.ESCALATION_HP_DROP_PCT then
        return true
    end
    return false
end

local function severityColors(sev, alphaMul)
    alphaMul = alphaMul or 1.0
    if sev >= SEVERITY.HIGH then
        return Col(245, 90, 90, math.floor(240 * alphaMul)), Col(90, 15, 15, math.floor(180 * alphaMul))
    end
    if sev >= SEVERITY.MED then
        return Col(255, 170, 60, math.floor(235 * alphaMul)), Col(90, 50, 10, math.floor(170 * alphaMul))
    end
    return Col(255, 225, 90, math.floor(230 * alphaMul)), Col(90, 80, 20, math.floor(160 * alphaMul))
end

local function buildAlertText(candidate)
    ensureI18N()
    if candidate.type == ALERT_TYPES.DIVE then
        return string.format(t("alert_dive_fmt"), candidate.allyName or "Ally", candidate.enemyCount or 0)
    end
    if candidate.type == ALERT_TYPES.GANK then
        return string.format(t("alert_gank_fmt"), candidate.allyName or "Ally", candidate.enemyCount or 0)
    end
    return string.format(t("alert_trade_fmt"), candidate.allyName or "Ally")
end

local function pingDangerAt(pos)
    if type(MiniMap) ~= "table" or type(MiniMap.Ping) ~= "function" or not pos then return false end
    local pingType = Enum and Enum.PingType and (Enum.PingType.DANGER or Enum.PingType.DEFAULT) or nil
    local ok = pcall(MiniMap.Ping, pos, pingType)
    if ok then return true end
    ok = pcall(MiniMap.Ping, pos)
    return ok
end

local function pruneExpiredAlerts(now)
    local out = {}
    for i = 1, #State.activeAlerts do
        local a = State.activeAlerts[i]
        if a and safeNum(a.expiresAt, -1) > now then
            out[#out + 1] = a
        end
    end
    State.activeAlerts = out
end

local function emitAlert(candidate, tpCapability, now)
    if not candidate or not candidate.ally then return end

    local allyTrack = getTrackForHero(candidate.ally)
    if allyTrack then
        allyTrack.lastAlertAtByType[candidate.type] = now
        allyTrack.lastAlertSeverityByType[candidate.type] = candidate.severity
        allyTrack.lastAlertHpPctByType[candidate.type] = allyTrack.current and allyTrack.current.hpPct or getHealthPct(candidate.ally)
    end

    local durationSec = getWidgetValue(UI.AlertDurationMs, DEFAULTS.alertDurationMs) / 1000.0
    State.nextAlertId = State.nextAlertId + 1
    local alert = {
        id = State.nextAlertId,
        text = buildAlertText(candidate),
        severity = candidate.severity,
        allyName = candidate.allyName,
        enemyCount = candidate.enemyCount or 0,
        allyIndex = getEntityIndex(candidate.ally),
        worldPos = candidate.anchorPos or candidate.allyPos or getPos(candidate.ally),
        allyPos = candidate.allyPos or getPos(candidate.ally),
        anchorPos = candidate.anchorPos,
        anchorType = candidate.anchorType,
        type = candidate.type,
        expiresAt = now + durationSec,
        createdAt = now,
        pinged = false,
        tpKind = tpCapability and tpCapability.kind or nil,
    }

    table.insert(State.activeAlerts, 1, alert)
    while #State.activeAlerts > INTERNAL.MAX_ACTIVE_ALERTS do
        table.remove(State.activeAlerts)
    end

    if getWidgetValue(UI.MiniMapPing, DEFAULTS.minimapPing) then
        local pingCd = getWidgetValue(UI.PingCooldownMs, DEFAULTS.pingCooldownMs) / 1000.0
        local canGlobal = (now - State.lastGlobalPingAt) >= pingCd
        local canAlly = true
        if allyTrack then
            canAlly = (now - safeNum(allyTrack.lastPingAt, -1e9)) >= INTERNAL.PER_ALLY_PING_COOLDOWN_SEC
        end
        if canGlobal and canAlly then
            local pingPos = candidate.anchorPos or candidate.allyPos or getPos(candidate.ally)
            if pingDangerAt(pingPos) then
                State.lastGlobalPingAt = now
                if allyTrack then allyTrack.lastPingAt = now end
                alert.pinged = true
            end
        end
    end

    if debugEnabled() then
        debugLog(string.format(
            "alert=%s severity=%d ally=%s tp=%s anchor=%s",
            tostring(candidate.type),
            tonumber(candidate.severity or 0) or 0,
            tostring(candidate.allyName or "?"),
            tostring(tpCapability and tpCapability.kind or "?"),
            tostring(candidate.anchorType or "none")
        ))
    end
end

-- -----------------------------------------------------------------------------
-- Draw
-- -----------------------------------------------------------------------------

local function alertTypeLabel(alertType)
    if alertType == ALERT_TYPES.DIVE then return t("label_dive") end
    if alertType == ALERT_TYPES.GANK then return t("label_gank") end
    return t("label_trade")
end

local function tpKindLabel(kind)
    if kind == "scroll" then return t("hud_tp_scroll") end
    if kind == "travel1" then return t("hud_tp_travel1") end
    if kind == "travel2" then return t("hud_tp_travel2") end
    return t("hud_tp_none")
end

local function anchorTypeLabel(anchorType)
    if anchorType == "tower" then return t("hud_anchor_tower") end
    if anchorType == "hero" then return t("hud_anchor_hero") end
    if anchorType == "unit" then return t("hud_anchor_unit") end
    if anchorType == "building" then return t("hud_anchor_building") end
    return t("hud_anchor_unknown")
end

local function buildAlertMetaLine(a)
    local enemyCount = math.max(0, math.floor(safeNum(a and a.enemyCount, 0)))
    if enemyCount <= 0 and a and a.type == ALERT_TYPES.TRADE then
        enemyCount = 1
    end
    local fmt = (enemyCount == 1) and t("hud_meta_line_fmt") or t("hud_meta_line_plural_fmt")
    return string.format(fmt, tpKindLabel(a and a.tpKind), "TP", anchorTypeLabel(a and a.anchorType), enemyCount)
end

local function drawAlerts(now)
    if not getWidgetValue(UI.HudAlerts, DEFAULTS.hudAlerts) then return end
    if #State.activeAlerts == 0 then return end

    ensureFonts()
    local font = State.fonts.main
    local fontSmall = State.fonts.small or font
    if not font then return end

    local screen = getScreenSize()
    local baseX = (screen.x or 1920) - 24
    local baseY = 80
    local rowH = 44
    local gap = 8
    local padX = 10
    local padY = 6
    local durationTotalSec = getWidgetValue(UI.AlertDurationMs, DEFAULTS.alertDurationMs) / 1000.0

    for i = 1, #State.activeAlerts do
        local a = State.activeAlerts[i]
        if a then
            local badge = alertTypeLabel(a.type)
            local title = safeStr(a.allyName, nil)
            if not title or title == "" then
                title = a.text or "Ally"
            end
            local meta = buildAlertMetaLine(a)
            local timeLeft = math.max(0, safeNum(a.expiresAt, now) - now)
            local timeText = string.format(t("hud_time_left_fmt"), timeLeft)

            local badgeSize = getTextSize(fontSmall, 12, badge)
            local titleSize = getTextSize(font, 14, title)
            local metaSize = getTextSize(fontSmall, 12, meta)
            local timeSize = getTextSize(fontSmall, 12, timeText)
            local badgeW = math.max(46, (badgeSize.x or 36) + 12)
            local badgeH = 18
            local line1W = badgeW + 8 + (titleSize.x or 110) + 8 + (timeSize.x or 0)
            local line2W = metaSize.x or 180
            local width = math.max(250, math.max(line1W, line2W) + padX * 2)
            local widthCap = math.floor((screen.x or 1920) * 0.42)
            if widthCap > 280 then
                width = math.min(width, widthCap)
            end
            local x = baseX - width
            local y = baseY + (i - 1) * (rowH + gap)

            local lifeFade = clamp((safeNum(a.expiresAt, now) - now) / 0.35, 0, 1)
            local relLife = clamp((safeNum(a.expiresAt, now) - now) / math.max(0.01, durationTotalSec), 0.0, 1.0)
            local accentColor, borderGlow = severityColors(a.severity or SEVERITY.LOW, clamp(lifeFade + 0.25, 0.25, 1))
            local badgeBg = severityColors(a.severity or SEVERITY.LOW, clamp(0.22 + relLife * 0.45, 0.22, 0.7))
            local bgColor = Col(12, 14, 18, math.floor(185 * (0.35 + relLife * 0.65)))
            local shadowColor = Col(0, 0, 0, math.floor(170 * clamp(lifeFade + 0.2, 0.2, 1)))
            local titleColor = Col(242, 247, 252, math.floor(245 * clamp(lifeFade + 0.35, 0.35, 1)))
            local metaColor = Col(180, 196, 214, math.floor(215 * clamp(lifeFade + 0.35, 0.35, 1)))
            local badgeTextColor = Col(255, 255, 255, math.floor(230 * clamp(lifeFade + 0.3, 0.3, 1)))
            local timeColor = Col(220, 230, 240, math.floor(200 * clamp(lifeFade + 0.3, 0.3, 1)))

            filledRect(x + 2, y + 2, width, rowH, Col(0, 0, 0, math.floor(95 * clamp(lifeFade + 0.3, 0.3, 1))), 7)
            filledRect(x, y, width, rowH, bgColor, 7)
            filledRect(x, y, width, 3, accentColor, 6)
            filledRect(x, y, 3, rowH, accentColor, 6)
            outlineRect(x, y, width, rowH, borderGlow, 7, 1)

            local badgeX = x + padX
            local badgeY = y + padY
            filledRect(badgeX, badgeY, badgeW, badgeH, badgeBg, 5)
            outlineRect(badgeX, badgeY, badgeW, badgeH, Col(255, 255, 255, math.floor(18 + relLife * 30)), 5, 1)
            renderTextShadow(fontSmall, 12, badge, V2(badgeX + 6, badgeY + 2), badgeTextColor, shadowColor)

            local titleX = badgeX + badgeW + 8
            renderTextShadow(font, 14, title, V2(titleX, y + padY - 1), titleColor, shadowColor)
            renderTextShadow(fontSmall, 12, timeText, V2(x + width - padX - (timeSize.x or 0), y + padY + 1), timeColor, shadowColor)
            renderTextShadow(fontSmall, 12, meta, V2(x + padX, y + padY + 20), metaColor, shadowColor)

            local progressW = math.floor((width - 2) * relLife)
            if progressW > 0 then
                filledRect(x + 1, y + rowH - 3, progressW, 2, accentColor, 1)
            end

            local spos, visible = worldToScreen(a.worldPos)
            if visible and spos and fontSmall then
                local wlabel = string.format("%s | TP", badge)
                renderTextShadow(fontSmall, 12, wlabel, V2((spos.x or 0) + 8, (spos.y or 0) - 8), accentColor, shadowColor)
            end
        end
    end
end

local function drawDebug(now)
    if not getWidgetValue(UI.DebugDraw, DEFAULTS.debugDraw) then return end
    ensureFonts()
    local font = State.fonts.small or State.fonts.main
    if not font then return end

    local x, y = 20, 50
    local tp = State.lastTpCapability
    local tpText = t("dbg_tp_none")
    if tp then
        tpText = string.format(t("dbg_tp_status"), tostring(tp.kind), tostring(tp.usable), tostring(tp.failReason))
    end
    renderTextShadow(font, 12, tpText, V2(x, y), Col(180, 220, 255, 240), Col(0, 0, 0, 180))
    y = y + 16
    renderTextShadow(font, 12, string.format(t("dbg_active_alerts"), #State.activeAlerts), V2(x, y), Col(180, 220, 255, 240), Col(0, 0, 0, 180))
    y = y + 16
    renderTextShadow(font, 12, string.format(t("dbg_now"), now), V2(x, y), Col(180, 220, 255, 240), Col(0, 0, 0, 180))

    for i = 1, math.min(#State.activeAlerts, 4) do
        local a = State.activeAlerts[i]
        if a and a.anchorPos then
            local spos, visible = worldToScreen(a.anchorPos)
            if visible and spos then
                renderTextShadow(font, 12, "TP", V2((spos.x or 0) - 8, (spos.y or 0) - 20), Col(120, 255, 120, 240), Col(0, 0, 0, 180))
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- Main loop
-- -----------------------------------------------------------------------------

local function updateTracksForHeroes(allHeroes, now)
    for i = 1, #allHeroes do
        local hero = allHeroes[i]
        if hero and heroIsTrackableCombatHero(hero) then
            pushHeroSample(hero, now)
        end
    end
end

local function shouldRunScan(now)
    local scanIntervalSec = getWidgetValue(UI.ScanIntervalMs, DEFAULTS.scanIntervalMs) / 1000.0
    scanIntervalSec = math.max(INTERNAL.MIN_SCAN_INTERVAL_SEC, scanIntervalSec)
    if (now - State.lastScanAt) < scanIntervalSec then
        return false
    end
    State.lastScanAt = now
    return true
end

function script.OnUpdate()
    if not UI_MENU_BUILT then
        initUI(false)
    end

    local now = safeNowGame()
    pruneExpiredAlerts(now)

    if not getWidgetValue(UI.Enabled, DEFAULTS.enabled) then
        return
    end
    if not isInGame() then
        return
    end

    local myHero = getLocalHero()
    if not myHero then return end

    if not shouldRunScan(now) then
        return
    end

    local allHeroes = getAllHeroes()
    if #allHeroes == 0 then return end

    updateTracksForHeroes(allHeroes, now)
    State.cachedLocalHeroIndex = getEntityIndex(myHero)

    local tpCapability = getTeleportCapabilityCached(myHero, now)
    if not tpCapability or not tpCapability.usable then
        pruneStaleTracks(now)
        return
    end

    local scanCache = {
        allHeroes = allHeroes,
        towers = nil,
        npcs = nil,
    }

    local allies = collectAlliedHeroes(myHero, allHeroes)
    for i = 1, #allies do
        local ally = allies[i]
        local ctx = buildThreatContext(myHero, ally, now, allHeroes, scanCache)
        if ctx then
            local candidate = classifyThreat(ctx)
            if candidate then
                if shouldEmitAlert(ally, candidate.type, candidate.severity, now) then
                    local anchor = findBestTpAnchorForAlly(myHero, ally, tpCapability, scanCache)
                    if anchor then
                        candidate.anchorEntity = anchor.entity
                        candidate.anchorPos = anchor.pos
                        candidate.anchorType = anchor.type
                        candidate.allyPos = ctx.allyPos
                        candidate.tpKind = tpCapability.kind
                        emitAlert(candidate, tpCapability, now)
                    elseif debugEnabled() then
                        debugLog(string.format("no_anchor for ally=%s event=%s", tostring(candidate.allyName), tostring(candidate.type)))
                    end
                end
            end
        end
    end

    pruneStaleTracks(now)
end

function script.OnDraw()
    if not UI_MENU_BUILT then
        initUI(false)
    end

    if not getWidgetValue(UI.Enabled, DEFAULTS.enabled) then return end
    if not isInGame() then return end

    local now = safeNowGame()
    pruneExpiredAlerts(now)
    drawAlerts(now)
    drawDebug(now)
end

function script.OnScriptsLoaded()
    initUI(true)
end

function script.OnScriptLoad()
    -- Compatibility fallback for environments that fire OnScriptLoad earlier than OnScriptsLoaded.
    initUI(false)
end

local function resetState()
    State.heroTracks = {}
    State.activeAlerts = {}
    State.lastScanAt = -1e9
    State.lastGlobalPingAt = -1e9
    State.cachedLocalHeroIndex = nil
    State.nextAlertId = 0
    State.lastTpCapability = nil
    State.lastTpRefreshAt = -1e9
end

function script.OnGameEnd()
    resetState()
end

return script
