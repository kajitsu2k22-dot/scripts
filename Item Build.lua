
local script = {}

local itemData = {}
local lastHeroID = nil
local lastUpdateTime = 0
local updateInterval = 300
local isLoading = false
local dataHeroID = nil
local queuedHeroID = nil
local heroIdCache = nil

local menu = {}
local fontMain = nil
local fontMainMode = nil
local itemNameCache = nil
local itemKeyCache = nil
local itemCostCache = nil
local itemDisplayByKeyCache = nil
local itemCostByKeyCache = nil
local itemRecipeByResultCache = nil
local itemIconCache = {}
local heroIconCache = {}
local heroMetaCache = nil
local textWidthCache = {}
local truncatedTextCache = {}
local ResetTextLayoutCaches = nil
local MeasureTextWidth = nil
local TruncateTextToWidth = nil
local PushClipRect = nil
local PopClipRect = nil
local NormalizeItemKey = nil

local enemyCtxCache = {
    hero = nil,
    nextAt = 0,
    stamp = 0,
    value = {
        total = 0,
        melee = 0,
        ranged = 0,
        invisThreat = 0,
    },
}

local inventoryCache = {
    hero = nil,
    nextAt = 0,
    stamp = 0,
    signature = "",
    counts = {},
    slots = {},
}

local panelScroll = {
    offset = 0,
    target = 0,
    maxOffset = 0,
}

local panelAnim = {
    alpha = 0,
    visible = false,
}

local panelViewModel = {
    heroID = nil,
    heroName = "unknown",
    heroLabel = "Unknown",
    sections = {},
    dataRef = nil,
    dataHeroID = nil,
    flagsKey = "",
    timeBucket = -1,
    enemyStamp = -1,
    heroCtxKey = "",
    inventoryStamp = -1,
    inventory = nil,
    scrollSignature = "",
    nextBuy = nil,
}

local PANEL_STYLE = {
    width = 390,
    header_height = 34,
    padding = 12,
    row_height = 20,
    section_gap = 10,
    footer_height = 24,
    rounding = 8,
}

local ITEMS_FILE = "/assets/data/items.json"
local HEROES_FILE = "/assets/data/npc_heroes.json"
local NEUTRAL_ITEMS_FILE = "/assets/data/neutral_items.json"
local PIXEL_FONT_FILE = "/fonts/04b03.ttf"
local CACHE_FILE_NAME = "item_helper_beta_opendota"
local CACHE_META_SECTION = "__meta"
local CACHE_SCHEMA_VERSION = 2

local cheatDirCache = nil
local neutralTiersCache = nil
local cacheSchemaReady = false

local httpFailureCount = 0
local httpNextRetryAt = 0
local httpLastStatus = 0
local httpLastError = ""
local dataSource = "none" -- live | cache | none

local panelDrag = {
    active = false,
    offsetX = 0,
    offsetY = 0,
}
local runtimePanelPos = {
    x = nil,
    y = nil,
}

local SHOP_PANEL_ID = "shop"
local SHOP_HUD_ROOT_ID = "Hud"
local shopCache = false
local shopCacheT = 0
local shopPanel = nil
local shopPanelSearchDone = false
local shopPanelNextSearchAt = 0

local function IsMenuReady()
    return menu.enabled ~= nil and type(menu.enabled.Get) == "function"
end

local function DebugLog(msg)
    if not (menu.debugLogs and type(menu.debugLogs.Get) == "function" and menu.debugLogs:Get()) then
        return
    end
    Log.Write("Item Build[debug]: " .. tostring(msg))
end

local function GetUnixTime()
    if type(os) == "table" and type(os.time) == "function" then
        local ok, t = pcall(os.time)
        if ok and type(t) == "number" then
            return math.floor(t)
        end
    end
    return 0
end

local function ReadConfigInt(fileName, section, key, defaultValue)
    if type(Config) ~= "table" or type(Config.ReadInt) ~= "function" then
        return defaultValue
    end
    local ok, value = pcall(Config.ReadInt, fileName, section, key, defaultValue)
    if ok and type(value) == "number" then
        return math.floor(value)
    end
    return defaultValue
end

local function ReadConfigString(fileName, section, key, defaultValue)
    if type(Config) ~= "table" or type(Config.ReadString) ~= "function" then
        return defaultValue
    end
    local ok, value = pcall(Config.ReadString, fileName, section, key, defaultValue)
    if ok and type(value) == "string" then
        return value
    end
    return defaultValue
end

local function WriteConfigInt(fileName, section, key, value)
    if type(Config) ~= "table" or type(Config.WriteInt) ~= "function" then
        return false
    end
    local ok = pcall(Config.WriteInt, fileName, section, key, math.floor(value))
    return ok
end

local function WriteConfigString(fileName, section, key, value)
    if type(Config) ~= "table" or type(Config.WriteString) ~= "function" then
        return false
    end
    local ok = pcall(Config.WriteString, fileName, section, key, tostring(value))
    return ok
end

local function GetScreenSize2D()
    if type(Engine) == "table" and type(Engine.GetScreenSize) == "function" then
        local ok, s = pcall(Engine.GetScreenSize)
        if ok and s then
            if type(s) == "table" or type(s) == "userdata" then
                return tonumber(s.x) or 1920, tonumber(s.y) or 1080
            end
        end
    end

    if type(Render) == "table" and type(Render.ScreenSize) == "function" then
        local ok, s = pcall(Render.ScreenSize)
        if ok and s then
            if type(s) == "table" or type(s) == "userdata" then
                return tonumber(s.x) or 1920, tonumber(s.y) or 1080
            end
        end
    end

    return 1920, 1080
end

local function GetCursorPos2D()
    if type(Input) == "table" and type(Input.GetCursorPos) == "function" then
        local ok, a, b = pcall(Input.GetCursorPos)
        if ok then
            if (type(a) == "table" or type(a) == "userdata") and a.x and a.y then
                return tonumber(a.x) or 0, tonumber(a.y) or 0
            end
            if type(a) == "number" and type(b) == "number" then
                return a, b
            end
        end
    end

    if type(Engine) == "table" and type(Engine.GetCursorPos) == "function" then
        local ok, pos = pcall(Engine.GetCursorPos)
        if ok and pos and (type(pos) == "table" or type(pos) == "userdata") then
            return tonumber(pos.x) or 0, tonumber(pos.y) or 0
        end
    end

    return 0, 0
end

local function GetFrameDeltaTime()
    if type(GlobalVars) == "table" and type(GlobalVars.GetFrameTime) == "function" then
        local ok, dt = pcall(GlobalVars.GetFrameTime)
        if ok and type(dt) == "number" and dt > 0 then
            return math.min(0.2, dt)
        end
    end
    if type(GlobalVars) == "table" and type(GlobalVars.GetAbsFrameTime) == "function" then
        local ok, dt = pcall(GlobalVars.GetAbsFrameTime)
        if ok and type(dt) == "number" and dt > 0 then
            return math.min(0.2, dt)
        end
    end
    return 1 / 60
end

local function SmoothApproach(current, target, speed, dt)
    current = tonumber(current) or 0
    target = tonumber(target) or 0
    speed = math.max(0.01, tonumber(speed) or 12)
    dt = math.max(0, tonumber(dt) or (1 / 60))
    local t = 1 - math.exp(-speed * dt)
    return current + ((target - current) * t)
end

local function GetScaleFactor()
    local scale = (menu.panelScale and menu.panelScale:Get() or 100) / 100
    if menu.autoMenuScale and menu.autoMenuScale:Get() and type(Menu) == "table" and type(Menu.Scale) == "function" then
        local ok, menuScale = pcall(Menu.Scale)
        if ok and type(menuScale) == "number" and menuScale > 0 then
            scale = scale * (menuScale / 100)
        end
    end

    if scale < 0.5 then scale = 0.5 end
    if scale > 2.2 then scale = 2.2 end
    return scale
end

local function GetUIPresetIndex()
    if menu.uiPreset and type(menu.uiPreset.Get) == "function" then
        local v = tonumber(menu.uiPreset:Get()) or 0
        if v < 0 then v = 0 end
        if v > 2 then v = 2 end
        return math.floor(v)
    end
    return 0
end

local function GetUIPresetValues()
    local preset = GetUIPresetIndex()
    if preset == 1 then
        return {
            width = 350,
            header_height = 30,
            padding = 8,
            row_height = 18,
            section_gap = 7,
            footer_height = 20,
            rounding = 6,
            icon_size = 12,
            title_font = 14,
            text_font = 12,
        }
    elseif preset == 2 then
        return {
            width = 430,
            header_height = 38,
            padding = 14,
            row_height = 22,
            section_gap = 11,
            footer_height = 24,
            rounding = 9,
            icon_size = 16,
            title_font = 17,
            text_font = 14,
        }
    end
    return nil
end

local function GetResolvedFontSizes(uiScale)
    local preset = GetUIPresetValues()
    local titleBase = (menu.titleFontSize and menu.titleFontSize:Get()) or 16
    local textBase = (menu.textFontSize and menu.textFontSize:Get()) or 14
    if preset then
        titleBase = preset.title_font or titleBase
        textBase = preset.text_font or textBase
    end
    uiScale = uiScale or 1.0
    return {
        title = math.max(10, math.floor((titleBase * uiScale) + 0.5)),
        text = math.max(9, math.floor((textBase * uiScale) + 0.5)),
    }
end

local function GetPanelStyle()
    local scale = GetScaleFactor()
    local preset = GetUIPresetValues()
    local function s(v, minValue)
        local scaled = math.floor((v or 0) * scale + 0.5)
        if minValue and scaled < minValue then
            return minValue
        end
        return scaled
    end

    return {
        width = s(preset and preset.width or ((menu.panelWidth and menu.panelWidth:Get()) or PANEL_STYLE.width), 220),
        header_height = s(preset and preset.header_height or ((menu.headerHeight and menu.headerHeight:Get()) or PANEL_STYLE.header_height), 18),
        padding = s(preset and preset.padding or ((menu.panelPadding and menu.panelPadding:Get()) or PANEL_STYLE.padding), 2),
        row_height = s(preset and preset.row_height or ((menu.rowHeight and menu.rowHeight:Get()) or PANEL_STYLE.row_height), 12),
        section_gap = s(preset and preset.section_gap or ((menu.sectionGap and menu.sectionGap:Get()) or PANEL_STYLE.section_gap), 2),
        footer_height = s(preset and preset.footer_height or ((menu.footerHeight and menu.footerHeight:Get()) or PANEL_STYLE.footer_height), 10),
        rounding = s(preset and preset.rounding or ((menu.panelRounding and menu.panelRounding:Get()) or PANEL_STYLE.rounding), 0),
        icon_size = s(preset and preset.icon_size or ((menu.itemIconSize and menu.itemIconSize:Get()) or 14), 8),
        ui_scale = scale,
    }
end

local function ResolveCheatDir()
    if cheatDirCache then
        return cheatDirCache
    end

    if type(Engine) == "table" then
        if type(Engine.GetCheatDir) == "function" then
            local ok, path = pcall(Engine.GetCheatDir)
            if ok and type(path) == "string" and path ~= "" then
                cheatDirCache = path
                return cheatDirCache
            end
        end

        if type(Engine.GetCheatDirectory) == "function" then
            local ok, path = pcall(Engine.GetCheatDirectory)
            if ok and type(path) == "string" and path ~= "" then
                cheatDirCache = path
                return cheatDirCache
            end
        end
    end

    if type(debug) == "table" and type(debug.getinfo) == "function" then
        local info = debug.getinfo(1, "S")
        local source = info and info.source
        if type(source) == "string" and source:sub(1, 1) == "@" then
            source = source:sub(2):gsub("\\", "/")
            local root = source:match("^(.*)/scripts/[^/]+%.lua$")
            if root and root ~= "" then
                cheatDirCache = root
                return cheatDirCache
            end
        end
    end

    cheatDirCache = "."
    return cheatDirCache
end

local function DecodeJson(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local ok, jsonLib = pcall(require, "assets.JSON")
    if not ok or type(jsonLib) ~= "table" then
        ok, jsonLib = pcall(function()
            local loader = loadfile(ResolveCheatDir() .. "/assets/JSON.lua")
            if not loader then
                return nil
            end
            return loader()
        end)
    end

    if not ok or type(jsonLib) ~= "table" or type(jsonLib.decode) ~= "function" then
        return nil
    end

    local okDecode, decoded = pcall(function()
        return jsonLib:decode(text)
    end)
    if okDecode then
        return decoded
    end

    okDecode, decoded = pcall(function()
        return jsonLib.decode(text)
    end)
    if okDecode then
        return decoded
    end

    return nil
end

local function ReadJsonFile(relativePath)
    local file = io.open(ResolveCheatDir() .. relativePath, "r")
    if not file then
        return nil
    end

    local content = file:read("*all")
    file:close()
    return DecodeJson(content)
end

local function EnsureFont()
    local preferPixel = false
    if menu.usePixelFont and type(menu.usePixelFont.Get) == "function" then
        preferPixel = menu.usePixelFont:Get()
    end

    local desiredMode = preferPixel and "pixel" or "default"
    if fontMain and fontMainMode == desiredMode then
        return
    end

    fontMain = nil
    fontMainMode = desiredMode
    ResetTextLayoutCaches()

    if preferPixel and type(Engine) == "table" and type(Engine.CreateFontFromFile) == "function" then
        local flags = Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or 0
        local weight = Enum.FontWeight and Enum.FontWeight.NORMAL or 400
        local fontPath = ResolveCheatDir() .. PIXEL_FONT_FILE
        local winPath = fontPath:gsub("/", "\\")

        local ok, font = pcall(Engine.CreateFontFromFile, fontPath, 14, weight, flags)
        if not (ok and font and font ~= 0) then
            ok, font = pcall(Engine.CreateFontFromFile, winPath, 14, weight, flags)
        end
        if ok and font and font ~= 0 then
            fontMain = font
        end
    end

    if preferPixel and not fontMain and Render.LoadFont then
        local ok, loaded = pcall(Render.LoadFont, "04b03", 14, Enum.FontCreate.FONTFLAG_ANTIALIAS)
        if ok and loaded and loaded ~= 0 then
            fontMain = loaded
        end
    end

    if not fontMain and Render.LoadFont then
        fontMain = Render.LoadFont("Segoe UI", 14, Enum.FontCreate.FONTFLAG_ANTIALIAS)
    end
    if not fontMain and Render.LoadFont then
        fontMain = Render.LoadFont("Tahoma", 14, Enum.FontCreate.FONTFLAG_ANTIALIAS)
    end
end

local function PrettyItemName(rawName)
    if not rawName then return "unknown" end
    local text = tostring(rawName):gsub("^item_", ""):gsub("_", " ")
    return text:gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest
    end)
end

local function Alpha(color, a)
    return Color(color.r, color.g, color.b, math.max(0, math.min(255, a)))
end

local function ScaleColorAlpha(color, mul)
    if not color then
        return color
    end
    mul = math.max(0, math.min(1, tonumber(mul) or 1))
    local a = tonumber(color.a) or 255
    return Color(color.r or 0, color.g or 0, color.b or 0, math.floor(a * mul + 0.5))
end

local function ApplyPaletteAlpha(palette, mul)
    if type(palette) ~= "table" then
        return palette
    end
    for k, v in pairs(palette) do
        if type(v) == "table" or type(v) == "userdata" then
            palette[k] = ScaleColorAlpha(v, mul)
        end
    end
    return palette
end

local function MakeColorOrFallback(raw, fallback, alphaOverride)
    local f = fallback or Color(200, 200, 200, 255)
    local t = type(raw)
    if t ~= "table" and t ~= "userdata" then
        return Color(f.r, f.g, f.b, alphaOverride or f.a)
    end

    local function safeField(obj, field)
        local ok, value = pcall(function()
            return obj[field]
        end)
        if ok and type(value) == "number" then
            return value
        end
        return nil
    end

    local r = safeField(raw, "r")
    local g = safeField(raw, "g")
    local b = safeField(raw, "b")
    local a = safeField(raw, "a")

    if (r == nil or g == nil or b == nil) and type(raw.Unpack) == "function" then
        local ok, ur, ug, ub, ua = pcall(raw.Unpack, raw)
        if ok then
            r = r or (type(ur) == "number" and ur or nil)
            g = g or (type(ug) == "number" and ug or nil)
            b = b or (type(ub) == "number" and ub or nil)
            a = a or (type(ua) == "number" and ua or nil)
        end
    end

    return Color(r or f.r, g or f.g, b or f.b, alphaOverride or a or f.a)
end

local function GetThemeColor(styleTable, keys, fallback, alphaOverride)
    if type(keys) ~= "table" then
        keys = { tostring(keys) }
    end

    if type(styleTable) == "table" then
        for i = 1, #keys do
            local key = keys[i]
            local c = styleTable[key]
            if c ~= nil then
                return MakeColorOrFallback(c, fallback, alphaOverride)
            end
        end
    end

    if type(Menu) == "table" and type(Menu.Style) == "function" then
        for i = 1, #keys do
            local key = keys[i]
            local ok, c = pcall(Menu.Style, key)
            if ok and c ~= nil then
                return MakeColorOrFallback(c, fallback, alphaOverride)
            end
        end
    end

    return MakeColorOrFallback(nil, fallback, alphaOverride)
end

local function ResolvePalette(opacity)
    local bgBase = menu.backgroundColor and menu.backgroundColor:Get() or Color(20, 20, 30, 200)
    local textBase = menu.textColor and menu.textColor:Get() or Color(255, 255, 255, 255)
    local titleBase = menu.titleColor and menu.titleColor:Get() or Color(100, 200, 255, 255)
    local borderBase = menu.borderColor and menu.borderColor:Get() or Color(140, 170, 220, 56)
    local mutedBase = menu.mutedColor and menu.mutedColor:Get() or Color(175, 195, 225, 230)
    local rowABase = menu.rowColorA and menu.rowColorA:Get() or Color(90, 120, 170, 18)
    local rowBBase = menu.rowColorB and menu.rowColorB:Get() or Color(90, 120, 170, 34)
    local accentBase = menu.accentColor and menu.accentColor:Get() or titleBase

    local palette = {
        bg = Alpha(bgBase, math.floor(bgBase.a * opacity)),
        bgHeader = Color(math.min(bgBase.r + 24, 255), math.min(bgBase.g + 24, 255), math.min(bgBase.b + 30, 255), math.min(255, math.floor((bgBase.a + 30) * opacity))),
        border = Alpha(borderBase, math.floor(borderBase.a * opacity)),
        title = titleBase,
        text = textBase,
        muted = Alpha(mutedBase, math.floor(mutedBase.a * opacity)),
        rowA = Alpha(rowABase, math.floor(rowABase.a * opacity)),
        rowB = Alpha(rowBBase, math.floor(rowBBase.a * opacity)),
        accent = Alpha(accentBase, math.floor(accentBase.a * opacity)),
    }

    if menu.syncTheme and menu.syncTheme:Get() and Menu.Style then
        local ok, style = pcall(Menu.Style)
        if not ok or type(style) ~= "table" then
            style = nil
        end

        -- Support both Menu.Style() -> table and Menu.Style("key") -> Color variants.
        palette.bg = GetThemeColor(style, { "additional_background", "background", "window_background" }, palette.bg, math.floor(214 * opacity))
        palette.bgHeader = GetThemeColor(style, { "primary", "accent", "tab_active" }, palette.bgHeader, math.floor(62 * opacity))
        palette.border = GetThemeColor(style, { "outline", "border" }, palette.border, math.floor(64 * opacity))
        palette.title = GetThemeColor(style, { "primary", "accent" }, palette.title, 255)
        palette.text = GetThemeColor(style, { "primary_first_tab_text", "text", "main_text" }, palette.text, 245)
        palette.muted = GetThemeColor(style, { "slider_background", "secondary_text", "dim_text" }, palette.muted, 220)
        palette.rowA = GetThemeColor(style, { "slider_background", "secondary_background" }, palette.rowA, math.floor(22 * opacity))
        palette.rowB = GetThemeColor(style, { "slider_background", "secondary_background" }, palette.rowB, math.floor(38 * opacity))
        palette.accent = GetThemeColor(style, { "primary", "accent" }, palette.accent, 255)
    end

    return palette
end

local function TryRender(fn, ...)
    if not fn then return false end
    local ok = pcall(fn, ...)
    return ok
end

ResetTextLayoutCaches = function()
    textWidthCache = {}
    truncatedTextCache = {}
end

MeasureTextWidth = function(text)
    local s = tostring(text or "")
    local cached = textWidthCache[s]
    if cached ~= nil then
        return cached
    end

    local width = #s * 7
    if type(Render) == "table" and type(Render.GetTextSize) == "function" and fontMain then
        local ok, size = pcall(Render.GetTextSize, fontMain, s)
        if ok and size and size.x then
            width = tonumber(size.x) or width
        end
    end

    textWidthCache[s] = width
    return width
end

TruncateTextToWidth = function(text, maxWidth)
    local s = tostring(text or "")
    if maxWidth == nil or maxWidth <= 0 then
        return ""
    end

    local cacheKey = tostring(math.floor(maxWidth + 0.5)) .. "|" .. s
    local cached = truncatedTextCache[cacheKey]
    if cached ~= nil then
        return cached
    end

    if MeasureTextWidth(s) <= maxWidth then
        truncatedTextCache[cacheKey] = s
        return s
    end

    local ellipsis = "..."
    local ellipsisW = MeasureTextWidth(ellipsis)
    if ellipsisW >= maxWidth then
        truncatedTextCache[cacheKey] = ""
        return ""
    end

    local lo, hi = 1, #s
    local best = ""
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local candidate = s:sub(1, mid) .. ellipsis
        if MeasureTextWidth(candidate) <= maxWidth then
            best = candidate
            lo = mid + 1
        else
            hi = mid - 1
        end
    end

    truncatedTextCache[cacheKey] = best
    return best
end

PushClipRect = function(x, y, w, h)
    if type(Render) ~= "table" or type(Render.PushClip) ~= "function" then
        return false
    end

    local function tryPosSize()
        local ok = pcall(Render.PushClip, Vec2(x, y), Vec2(w, h))
        return ok == true
    end

    local function tryMinMax()
        local ok = pcall(Render.PushClip, Vec2(x, y), Vec2(x + w, y + h))
        return ok == true
    end

    -- In this environment PushClip often behaves like min/max even though docs say
    -- pos+size. Try min/max first to avoid "shrunk clip" artifacts (empty space at
    -- panel bottom), then fallback to pos+size for compatibility.
    if tryMinMax() then return true end
    return tryPosSize()
end

PopClipRect = function()
    if type(Render) ~= "table" or type(Render.PopClip) ~= "function" then
        return false
    end
    return pcall(Render.PopClip)
end

local function TruncateText(text, maxLen)
    if not text then return "" end
    local s = tostring(text)
    if #s <= maxLen then return s end
    return s:sub(1, maxLen - 3) .. "..."
end

local function FormatCost(cost)
    if type(cost) ~= "number" then return "--" end
    return tostring(math.floor(cost))
end
local function ParseClockToSeconds(value)
    if type(value) == "number" then return math.floor(value) end
    if type(value) ~= "string" then return nil end

    local mm, ss = value:match("^(%d+):(%d+)$")
    if mm and ss then
        return tonumber(mm) * 60 + tonumber(ss)
    end

    local hh, mm2, ss2 = value:match("^(%d+):(%d+):(%d+)$")
    if hh and mm2 and ss2 then
        return tonumber(hh) * 3600 + tonumber(mm2) * 60 + tonumber(ss2)
    end

    return tonumber(value)
end

local function GetNeutralTiers()
    if neutralTiersCache ~= nil then
        return neutralTiersCache or nil
    end

    local data = ReadJsonFile(NEUTRAL_ITEMS_FILE)
    local tiers = data and data.neutral_items and data.neutral_items.neutral_tiers
    if type(tiers) ~= "table" then
        neutralTiersCache = false
        Log.Write("Item Build: failed to read neutral data from " .. NEUTRAL_ITEMS_FILE)
        return nil
    end

    neutralTiersCache = tiers
    return tiers
end

local function GetNeutralTierByGameTime(gameTime)
    local tiers = GetNeutralTiers()
    if type(tiers) ~= "table" then
        return 0, nil
    end

    local currentTier = 0
    for tierKey, tierData in pairs(tiers) do
        local tier = tonumber(tierKey)
        if tier and type(tierData) == "table" then
            local startTime = ParseClockToSeconds(tierData.start_time) or 0
            if gameTime >= startTime and tier > currentTier then
                currentTier = tier
            end
        end
    end

    if currentTier <= 0 then
        return 0, nil
    end

    return currentTier, tiers[tostring(currentTier)] or tiers[currentTier]
end

local function BuildHeroMetaCache()
    if heroMetaCache then
        return heroMetaCache
    end

    heroMetaCache = {}
    local heroesData = ReadJsonFile(HEROES_FILE)
    local source = heroesData and (heroesData.DOTAHeroes or heroesData)
    if type(source) == "table" then
        for key, hero in pairs(source) do
            if type(key) == "string" and type(hero) == "table" and key:find("^npc_dota_hero_") then
                local attrRaw = tostring(hero.AttributePrimary or ""):lower()
                local attr = "all"
                if attrRaw:find("strength", 1, true) then
                    attr = "str"
                elseif attrRaw:find("agility", 1, true) then
                    attr = "agi"
                elseif attrRaw:find("intelligence", 1, true) then
                    attr = "int"
                end

                local attackCaps = tostring(hero.AttackCapabilities or ""):upper()
                local ranged = attackCaps:find("RANGED", 1, true) ~= nil
                heroMetaCache[key:lower()] = {
                    attr = attr,
                    ranged = ranged,
                }
            end
        end
    end

    return heroMetaCache
end

local function TryCallMethod(obj, methodName, ...)
    local args = { ... }
    local ok, result = pcall(function()
        if obj == nil then
            return nil
        end
        local fn = obj[methodName]
        if type(fn) ~= "function" then
            return nil
        end
        return fn(obj, table.unpack(args))
    end)
    if ok then
        return result
    end
    return nil
end

local function ResolveHeroAttrByRuntime(myHero, fallback)
    local attr = fallback
    local pa = TryCallMethod(myHero, "GetPrimaryAttribute")
    if pa ~= nil then
        if type(pa) == "string" then
            local low = pa:lower()
            if low:find("strength", 1, true) then attr = "str" end
            if low:find("agility", 1, true) then attr = "agi" end
            if low:find("intelligence", 1, true) then attr = "int" end
            if low:find("all", 1, true) then attr = "all" end
        elseif type(pa) == "number" and Enum and Enum.Attributes then
            if pa == Enum.Attributes.STRENGTH then attr = "str" end
            if pa == Enum.Attributes.AGILITY then attr = "agi" end
            if pa == Enum.Attributes.INTELLIGENCE then attr = "int" end
            if pa == Enum.Attributes.ALL then attr = "all" end
        end
    end
    return attr or "all"
end

local function GetHeroContext(myHero, heroName)
    local meta = BuildHeroMetaCache()[(heroName and heroName:lower()) or ""] or {}
    local ranged = meta.ranged
    local isRanged = nil
    if myHero and NPC and type(NPC.IsRanged) == "function" then
        local ok, value = pcall(NPC.IsRanged, myHero)
        if ok then
            isRanged = value
        end
    end
    if isRanged == nil then
        isRanged = TryCallMethod(myHero, "IsRanged")
    end
    if type(isRanged) == "boolean" then
        ranged = isRanged
    end

    return {
        attr = ResolveHeroAttrByRuntime(myHero, meta.attr or "all"),
        ranged = ranged == true,
    }
end

local function GetEnemyContext(myHero)
    local result = {
        total = 0,
        melee = 0,
        ranged = 0,
        invisThreat = 0,
    }

    if not myHero or type(Heroes) ~= "table" or type(Heroes.GetAll) ~= "function" then
        return result
    end

    local myTeam = (Entity and Entity.GetTeamNum and Entity.GetTeamNum(myHero)) or nil
    if myTeam == nil then
        myTeam = TryCallMethod(myHero, "GetTeamNum")
    end
    local heroes = Heroes.GetAll()
    if type(heroes) ~= "table" then
        return result
    end

    for i = 1, #heroes do
        local hero = heroes[i]
        if hero and hero ~= myHero then
            local sameTeam = false
            if myTeam ~= nil then
                if Entity and Entity.GetTeamNum then
                    sameTeam = (Entity.GetTeamNum(hero) == myTeam)
                else
                    local team = TryCallMethod(hero, "GetTeamNum")
                    sameTeam = team == myTeam
                end
            end

            if not sameTeam then
                local alive = (Entity and Entity.IsAlive and Entity.IsAlive(hero)) or false
                local isIllusion = false
                if NPC and type(NPC.IsIllusion) == "function" then
                    local okIllusion, value = pcall(NPC.IsIllusion, hero)
                    if okIllusion and type(value) == "boolean" then
                        isIllusion = value
                    end
                else
                    isIllusion = TryCallMethod(hero, "IsIllusion") == true
                end
                if alive and not isIllusion then
                    result.total = result.total + 1
                    local isRanged = false
                    if NPC and type(NPC.IsRanged) == "function" then
                        local okRanged, value = pcall(NPC.IsRanged, hero)
                        if okRanged and type(value) == "boolean" then
                            isRanged = value
                        end
                    else
                        isRanged = TryCallMethod(hero, "IsRanged") == true
                    end
                    if isRanged then
                        result.ranged = result.ranged + 1
                    else
                        result.melee = result.melee + 1
                    end

                    local invisNow = TryCallMethod(hero, "IsInvisible") == true
                    local invisMod = TryCallMethod(hero, "HasModifier", "modifier_invisible") == true
                    if invisNow or invisMod then
                        result.invisThreat = result.invisThreat + 1
                    end
                end
            end
        end
    end

    return result
end

local function ScoreNeutralItem(key, heroCtx, enemyCtx, gameTime)
    local score = 10
    local k = tostring(key or ""):lower()
    local attr = heroCtx and heroCtx.attr or "all"
    local ranged = heroCtx and heroCtx.ranged == true

    if attr == "str" then
        if k:find("shield", 1, true) or k:find("vest", 1, true) or k:find("shell", 1, true) or k:find("maul", 1, true) or k:find("mandible", 1, true) then score = score + 5 end
        if k:find("gloves", 1, true) or k:find("crossbow", 1, true) then score = score - 2 end
    elseif attr == "agi" then
        if k:find("gloves", 1, true) or k:find("crossbow", 1, true) or k:find("shiv", 1, true) or k:find("gauntlets", 1, true) then score = score + 5 end
        if k:find("shield", 1, true) or k:find("vest", 1, true) then score = score - 1 end
    elseif attr == "int" then
        if k:find("bracelet", 1, true) or k:find("ring", 1, true) or k:find("draught", 1, true) or k:find("prism", 1, true) or k:find("headband", 1, true) then score = score + 5 end
        if k:find("maul", 1, true) then score = score - 2 end
    end

    if ranged then
        if k:find("crossbow", 1, true) or k:find("headband", 1, true) or k:find("eye", 1, true) then score = score + 3 end
    else
        if k:find("shield", 1, true) or k:find("maul", 1, true) or k:find("mandible", 1, true) then score = score + 3 end
    end

    if enemyCtx then
        if enemyCtx.melee > enemyCtx.ranged then
            if k:find("headband", 1, true) or k:find("pogo", 1, true) or k:find("spider_legs", 1, true) then score = score + 3 end
        elseif enemyCtx.ranged > enemyCtx.melee then
            if k:find("shield", 1, true) or k:find("vest", 1, true) or k:find("shell", 1, true) then score = score + 3 end
        end
        if enemyCtx.invisThreat > 0 and k:find("eye", 1, true) then
            score = score + 4
        end
    end

    if gameTime then
        if gameTime < 1500 and (k:find("weighted_dice", 1, true) or k:find("dormant_curio", 1, true)) then
            score = score + 2
        end
        if gameTime >= 3000 and (k:find("fallen_sky", 1, true) or k:find("divine_regalia", 1, true) or k:find("minotaur_horn", 1, true)) then
            score = score + 2
        end
    end

    return score
end

local function ScoreCharm(key, heroCtx, enemyCtx, gameTime)
    local score = 10
    local k = tostring(key or ""):lower()
    local attr = heroCtx and heroCtx.attr or "all"
    local ranged = heroCtx and heroCtx.ranged == true

    if attr == "str" then
        if k:find("brawny", 1, true) or k:find("tough", 1, true) or k:find("titanic", 1, true) then score = score + 5 end
    elseif attr == "agi" then
        if k:find("alert", 1, true) or k:find("feverish", 1, true) or k:find("vampiric", 1, true) then score = score + 5 end
    elseif attr == "int" then
        if k:find("mystical", 1, true) or k:find("wise", 1, true) or k:find("timeless", 1, true) then score = score + 5 end
    else
        if k:find("quickened", 1, true) or k:find("evolved", 1, true) or k:find("boundless", 1, true) then score = score + 4 end
    end

    if ranged and (k:find("keen_eyed", 1, true) or k:find("alert", 1, true) or k:find("fleetfooted", 1, true)) then
        score = score + 3
    end
    if (not ranged) and (k:find("brawny", 1, true) or k:find("audacious", 1, true) or k:find("tough", 1, true)) then
        score = score + 3
    end

    if enemyCtx then
        if enemyCtx.invisThreat > 0 and (k:find("keen_eyed", 1, true) or k:find("alert", 1, true)) then
            score = score + 3
        end
        if enemyCtx.ranged > enemyCtx.melee and (k:find("tough", 1, true) or k:find("brawny", 1, true)) then
            score = score + 2
        end
    end

    if gameTime then
        if gameTime < 1200 and k:find("greedy", 1, true) then
            score = score + 3
        end
        if gameTime > 2400 and k:find("greedy", 1, true) then
            score = score - 2
        end
    end

    return score
end

local function RankNeutralEntries(list, scoreFn, heroCtx, enemyCtx, gameTime)
    for i = 1, #list do
        local item = list[i]
        item.score = scoreFn(item.key, heroCtx, enemyCtx, gameTime)
    end

    table.sort(list, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        return a.name < b.name
    end)

    if menu.neutralTopOnly and menu.neutralTopOnly:Get() then
        local topN = math.max(1, (menu.neutralTopCount and menu.neutralTopCount:Get()) or 3)
        while #list > topN do
            table.remove(list)
        end
    end

    return list
end

local function CacheSectionForHero(heroID)
    return "hero_" .. tostring(heroID)
end

local function EnsureCacheSchema()
    if cacheSchemaReady then
        return
    end
    cacheSchemaReady = true

    local storedVersion = ReadConfigInt(CACHE_FILE_NAME, CACHE_META_SECTION, "schema_version", 0)
    if storedVersion == CACHE_SCHEMA_VERSION then
        return
    end

    WriteConfigInt(CACHE_FILE_NAME, CACHE_META_SECTION, "schema_version", CACHE_SCHEMA_VERSION)
    WriteConfigInt(CACHE_FILE_NAME, CACHE_META_SECTION, "updated_at", GetUnixTime())
    if storedVersion > 0 then
        DebugLog("cache schema migrated from=" .. tostring(storedVersion) .. " to=" .. tostring(CACHE_SCHEMA_VERSION))
    end
end

local function ResetHeroCacheSection(heroID)
    local section = CacheSectionForHero(heroID)
    WriteConfigString(CACHE_FILE_NAME, section, "json", "")
    WriteConfigInt(CACHE_FILE_NAME, section, "saved_at", 0)
    WriteConfigInt(CACHE_FILE_NAME, section, "schema", CACHE_SCHEMA_VERSION)
end

local function SaveHeroCache(heroID, rawJson)
    if not (menu.useDiskCache and menu.useDiskCache:Get()) then
        return
    end
    if type(rawJson) ~= "string" or rawJson == "" then
        return
    end

    EnsureCacheSchema()
    local section = CacheSectionForHero(heroID)
    local nowUnix = GetUnixTime()
    WriteConfigString(CACHE_FILE_NAME, section, "json", rawJson)
    WriteConfigInt(CACHE_FILE_NAME, section, "saved_at", nowUnix)
    WriteConfigInt(CACHE_FILE_NAME, section, "schema", CACHE_SCHEMA_VERSION)
    DebugLog("cache saved hero=" .. tostring(heroID) .. " size=" .. tostring(#rawJson))
end

local function LoadHeroCache(heroID, allowStale)
    if not (menu.useDiskCache and menu.useDiskCache:Get()) then
        return nil, "cache_disabled"
    end

    EnsureCacheSchema()
    local section = CacheSectionForHero(heroID)
    local entryVersion = ReadConfigInt(CACHE_FILE_NAME, section, "schema", 0)
    if entryVersion ~= CACHE_SCHEMA_VERSION then
        -- Drop old format immediately so it doesn't keep spamming decode errors.
        ResetHeroCacheSection(heroID)
        return nil, "cache_migrated"
    end

    local rawJson = ReadConfigString(CACHE_FILE_NAME, section, "json", "")
    if rawJson == "" then
        return nil, "cache_miss"
    end

    local savedAt = ReadConfigInt(CACHE_FILE_NAME, section, "saved_at", 0)
    if not allowStale then
        local ttlMin = (menu.cacheTTLMinutes and menu.cacheTTLMinutes:Get()) or 10
        local nowUnix = GetUnixTime()
        if nowUnix > 0 and savedAt > 0 and (nowUnix - savedAt) > (ttlMin * 60) then
            return nil, "cache_stale"
        end
    end

    local data = DecodeJson(rawJson)
    if type(data) ~= "table" then
        ResetHeroCacheSection(heroID)
        return nil, "cache_corrupted_reset"
    end
    return data, "cache_hit"
end

local function TryApplyCachedHeroData(heroID, allowStale)
    local data, reason = LoadHeroCache(heroID, allowStale)
    if not data then
        DebugLog("cache load failed hero=" .. tostring(heroID) .. " reason=" .. tostring(reason))
        return false
    end

    itemData = data
    dataHeroID = heroID
    lastUpdateTime = 0
    dataSource = "cache"
    DebugLog("cache applied hero=" .. tostring(heroID))
    return true
end

local function ResetNetworkBackoff()
    httpFailureCount = 0
    httpNextRetryAt = 0
    httpLastStatus = 0
    httpLastError = ""
end

local function RegisterNetworkFailure(statusCode, errorText)
    httpLastStatus = tonumber(statusCode) or 0
    httpLastError = tostring(errorText or "")
    local now = (GameRules.GetGameTime and GameRules.GetGameTime()) or 0
    if not (menu.retryWithBackoff and menu.retryWithBackoff:Get()) then
        httpNextRetryAt = now + 5
        return
    end

    httpFailureCount = math.min(10, httpFailureCount + 1)
    local maxBackoff = (menu.maxBackoffSeconds and menu.maxBackoffSeconds:Get()) or 120
    local delay = math.min(maxBackoff, 3 * (2 ^ (httpFailureCount - 1)))
    if httpLastStatus == 429 then
        delay = math.max(delay, 20)
    end

    httpNextRetryAt = now + delay
    DebugLog("network fail status=" .. tostring(httpLastStatus) .. " next_retry_in=" .. tostring(delay))
end

local function IsUIPanelValid(panel)
    if panel == nil then
        return false
    end
    if type(panel.IsValid) == "function" then
        local ok, isValid = pcall(panel.IsValid, panel)
        if ok then
            return isValid == true
        end
    end
    return true
end

local function FindShopPanel()
    if shopPanel and IsUIPanelValid(shopPanel) then
        return shopPanel
    end
    shopPanel = nil

    local now = (GameRules.GetGameTime and GameRules.GetGameTime()) or 0
    if shopPanelSearchDone and now < shopPanelNextSearchAt then
        return nil
    end

    shopPanelSearchDone = true
    shopPanelNextSearchAt = now + 1.0
    if type(Panorama) ~= "table" or type(Panorama.GetPanelByName) ~= "function" then
        return nil
    end

    local ok, panel = pcall(Panorama.GetPanelByName, SHOP_PANEL_ID, false)
    if ok and panel then
        shopPanel = panel
        shopPanelNextSearchAt = 0
        return shopPanel
    end

    local okHud, hud = pcall(Panorama.GetPanelByName, SHOP_HUD_ROOT_ID, false)
    if okHud and hud and type(hud.FindChildTraverse) == "function" then
        local okFind, nested = pcall(hud.FindChildTraverse, hud, SHOP_PANEL_ID)
        if okFind and nested then
            shopPanel = nested
            shopPanelNextSearchAt = 0
            return shopPanel
        end
    end

    return nil
end

local function IsShopOpen()
    local now = (GameRules.GetGameTime and GameRules.GetGameTime()) or 0
    if now - shopCacheT < 0.15 then
        return shopCache
    end
    shopCacheT = now

    local panel = FindShopPanel()
    if panel and type(panel.HasClass) == "function" then
        local ok, has = pcall(panel.HasClass, panel, "ShopOpen")
        if ok then
            shopCache = (has == true)
            return shopCache
        end
    end

    shopCache = false
    return false
end

local function IsCheatMenuOpen()
    if type(Menu) ~= "table" or type(Menu.Opened) ~= "function" then
        return false
    end
    local ok, opened = pcall(Menu.Opened)
    return ok and opened == true
end

local function ShouldDrawPanel()
    if not menu.visibilityMode or type(menu.visibilityMode.Get) ~= "function" then
        return true
    end

    if type(menu.visibilityMode.GetItem) == "function" then
        local okItem, item = pcall(menu.visibilityMode.GetItem, menu.visibilityMode)
        if okItem and type(item) == "string" then
            local lower = item:lower()
            if lower:find("always", 1, true) then
                return true
            end
            if lower:find("menu", 1, true) and lower:find("shop", 1, true) then
                return IsCheatMenuOpen() or IsShopOpen()
            end
            if lower:find("shop", 1, true) then
                return IsShopOpen()
            end
        end
    end

    local mode = menu.visibilityMode:Get() or 0
    if mode <= 0 then
        return true
    end

    local shopOpen = IsShopOpen()
    if mode == 1 then
        return IsCheatMenuOpen() or shopOpen
    end
    if mode >= 2 then
        return shopOpen
    end

    return true
end

local function SetPanelPosition(x, y)
    x = math.floor(x + 0.5)
    y = math.floor(y + 0.5)

    local updated = false
    if menu.positionX and type(menu.positionX.Set) == "function" then
        local ok = pcall(menu.positionX.Set, menu.positionX, x)
        updated = updated or ok
    end
    if menu.positionY and type(menu.positionY.Set) == "function" then
        local ok = pcall(menu.positionY.Set, menu.positionY, y)
        updated = updated or ok
    end

    if not updated then
        runtimePanelPos.x = x
        runtimePanelPos.y = y
    end
end

local function ResolvePanelPosition()
    local x = (menu.positionX and menu.positionX:Get()) or 50
    local y = (menu.positionY and menu.positionY:Get()) or 200
    if runtimePanelPos.x ~= nil then
        x = runtimePanelPos.x
    end
    if runtimePanelPos.y ~= nil then
        y = runtimePanelPos.y
    end
    return x, y
end

local function HandlePanelDragging(panelX, panelY, panelW, panelH, headerH)
    if not (menu.enableDrag and menu.enableDrag:Get()) then
        panelDrag.active = false
        return panelX, panelY
    end

    if menu.dragOnlyInMenu and menu.dragOnlyInMenu:Get() and not IsCheatMenuOpen() then
        panelDrag.active = false
        return panelX, panelY
    end

    local mouseKey = Enum and Enum.ButtonCode and (Enum.ButtonCode.KEY_MOUSE1 or Enum.ButtonCode.MOUSE_LEFT) or nil
    if not mouseKey or type(Input) ~= "table" or type(Input.IsKeyDown) ~= "function" then
        return panelX, panelY
    end

    local cursorX, cursorY = GetCursorPos2D()
    local isMouseDown = Input.IsKeyDown(mouseKey)

    local inHeader = false
    if type(Input.IsCursorInRect) == "function" then
        local ok, inRect = pcall(Input.IsCursorInRect, panelX, panelY, panelW, headerH)
        inHeader = ok and inRect == true
    else
        inHeader = cursorX >= panelX and cursorX <= (panelX + panelW) and cursorY >= panelY and cursorY <= (panelY + headerH)
    end

    if isMouseDown and inHeader and not panelDrag.active then
        panelDrag.active = true
        panelDrag.offsetX = cursorX - panelX
        panelDrag.offsetY = cursorY - panelY
        DebugLog("drag start x=" .. tostring(panelX) .. " y=" .. tostring(panelY))
    end

    if panelDrag.active then
        if isMouseDown then
            panelX = cursorX - panelDrag.offsetX
            panelY = cursorY - panelDrag.offsetY

            local screenW, screenH = GetScreenSize2D()
            panelX = math.max(0, math.min(panelX, screenW - panelW))
            panelY = math.max(0, math.min(panelY, screenH - panelH))

            if menu.snapToEdges and menu.snapToEdges:Get() then
                local snapDist = (menu.snapDistance and menu.snapDistance:Get()) or 14
                if math.abs(panelX) <= snapDist then panelX = 0 end
                if math.abs((panelX + panelW) - screenW) <= snapDist then panelX = screenW - panelW end
                if math.abs(panelY) <= snapDist then panelY = 0 end
                if math.abs((panelY + panelH) - screenH) <= snapDist then panelY = screenH - panelH end
            end

            runtimePanelPos.x = panelX
            runtimePanelPos.y = panelY
        else
            SetPanelPosition(panelX, panelY)
            panelDrag.active = false
            DebugLog("drag stop x=" .. tostring(panelX) .. " y=" .. tostring(panelY))
        end
    end

    return panelX, panelY
end

local function TrySetMenuIcon(widget, icon, offset)
    if not widget or type(widget.Icon) ~= "function" or type(icon) ~= "string" or icon == "" then
        return false
    end
    local ok = pcall(widget.Icon, widget, icon, offset)
    return ok == true
end

local function TrySetMenuGroupIcon(group, icon, offset)
    if not group or type(group.Parent) ~= "function" then
        return false
    end
    local okParent, parent = pcall(group.Parent, group)
    if not okParent or not parent or type(parent.Icon) ~= "function" then
        return false
    end
    local ok = pcall(parent.Icon, parent, icon, offset)
    return ok == true
end

local function TrySetMenuScriptTabIcon(group, icon, offset)
    if not group or type(group.Parent) ~= "function" then
        return false
    end
    local okThird, thirdTab = pcall(group.Parent, group)
    if not okThird or not thirdTab or type(thirdTab.Parent) ~= "function" then
        return false
    end
    local okSecond, secondTab = pcall(thirdTab.Parent, thirdTab)
    if not okSecond or not secondTab or type(secondTab.Icon) ~= "function" then
        return false
    end
    local ok = pcall(secondTab.Icon, secondTab, icon, offset)
    return ok == true
end

local function CreateMenuGroup(groupName)
    local candidates = {
        { "General", "Main", "Item Build", "Settings", groupName },
        { "General", "Main", "Item Build", "Main", groupName },
        { "General", "Main", "Item Helper", "Settings", groupName },
        { "General", "Main", "Item Helper", "Main", groupName },
        { "ItemHelper", "Main", "Settings", "General", groupName },
        { "ItemBuild", "Main", "Settings", "General", groupName },
        { "ItemHelper", "Main", "Settings", "General", "Options" },
        { "ItemBuild", "Main", "Settings", "General", "Options" },
    }

    for i = 1, #candidates do
        local a = candidates[i]
        local ok, group = pcall(Menu.Create, a[1], a[2], a[3], a[4], a[5])
        if ok and group and type(group.Switch) == "function" then
            return group
        end
    end

    return nil
end

function script.OnScriptsLoaded()
    local generalGroup = CreateMenuGroup("General")
    if not generalGroup then
        Log.Write("Item Build: failed to create menu group")
        return
    end

    local displayGroup = CreateMenuGroup("Display") or generalGroup
    local windowGroup = CreateMenuGroup("Window") or generalGroup
    local styleGroup = CreateMenuGroup("Style") or generalGroup
    local colorsGroup = CreateMenuGroup("Colors") or generalGroup
    local networkGroup = CreateMenuGroup("Network") or generalGroup

    TrySetMenuGroupIcon(generalGroup, "\u{f0ad}")
    TrySetMenuGroupIcon(displayGroup, "\u{f06e}")
    TrySetMenuGroupIcon(windowGroup, "\u{f2d2}")
    TrySetMenuGroupIcon(styleGroup, "\u{f1fc}")
    TrySetMenuGroupIcon(colorsGroup, "\u{f53f}")
    TrySetMenuGroupIcon(networkGroup, "\u{f0c2}")
    TrySetMenuScriptTabIcon(generalGroup, "\u{f07a}")

    menu.enabled = generalGroup:Switch("Enabled", true)
    menu.refreshKey = generalGroup:Bind("Refresh Key", Enum.ButtonCode.KEY_F5)
    menu.maxItemsShown = generalGroup:Slider("Max Items per Phase", 1, 10, 5, "%d")
    menu.showStartItems = generalGroup:Switch("Show Start Items", true)
    menu.showEarlyItems = generalGroup:Switch("Show Early Items", true)
    menu.showMidItems = generalGroup:Switch("Show Mid Items", true)
    menu.showLateItems = generalGroup:Switch("Show Late Items", true)
    menu.showNeutralItems = generalGroup:Switch("Show Neutral Items", true)
    menu.showCharms = generalGroup:Switch("Show Charms", true)
    menu.neutralRecommendations = generalGroup:Switch("Recommend Neutral/Charms", true)
    menu.neutralTopOnly = generalGroup:Switch("Top Suggestions Only", true)
    menu.neutralTopCount = generalGroup:Slider("Top Suggestions Count", 1, 6, 3, "%d")
    menu.focusMode = generalGroup:Combo("Phase Focus", { "All Phases", "Current + Next", "Current Only" }, 0)
    menu.showNextBuy = generalGroup:Switch("Show Next Buy Block", true)
    menu.nextBuyCount = generalGroup:Slider("Next Buy Count", 1, 5, 2, "%d")
    menu.debugLogs = generalGroup:Switch("Debug Logs", false)
    if menu.debugLogs and type(menu.debugLogs.Set) == "function" then
        pcall(menu.debugLogs.Set, menu.debugLogs, false)
    end

    menu.visibilityMode = displayGroup:Combo("Panel Visibility", { "Always", "Menu or Shop", "Only Shop" }, 0)
    menu.showItemCost = displayGroup:Switch("Show Item Cost", true)
    menu.showGames = displayGroup:Switch("Show Popularity", true)
    menu.showHeroIcon = displayGroup:Switch("Show Hero Icon", true)
    menu.showSampleConfidence = displayGroup:Switch("Show Sample Confidence", true)
    menu.showOwnedItems = displayGroup:Switch("Highlight Owned Items", true)
    menu.showComponentProgress = displayGroup:Switch("Show Component Progress", true)
    menu.showSourcePhaseInNextBuy = displayGroup:Switch("Show Next Buy Source", true)

    menu.positionX = windowGroup:Slider("Position X", 0, 2000, 50, "%d")
    menu.positionY = windowGroup:Slider("Position Y", 0, 2000, 200, "%d")
    menu.panelScale = windowGroup:Slider("Panel Scale %", 60, 160, 100, "%d")
    menu.autoMenuScale = windowGroup:Switch("Auto Scale From Menu", true)
    menu.panelWidth = windowGroup:Slider("Panel Width", 300, 700, PANEL_STYLE.width, "%d")
    menu.headerHeight = windowGroup:Slider("Header Height", 24, 56, PANEL_STYLE.header_height, "%d")
    menu.footerHeight = windowGroup:Slider("Footer Height", 14, 36, PANEL_STYLE.footer_height, "%d")
    menu.panelPadding = windowGroup:Slider("Panel Padding", 6, 24, PANEL_STYLE.padding, "%d")
    menu.rowHeight = windowGroup:Slider("Row Height", 16, 32, PANEL_STYLE.row_height, "%d")
    menu.sectionGap = windowGroup:Slider("Section Gap", 4, 20, PANEL_STYLE.section_gap, "%d")
    menu.panelRounding = windowGroup:Slider("Panel Rounding", 0, 24, PANEL_STYLE.rounding, "%d")
    menu.itemIconSize = windowGroup:Slider("Item Icon Size", 10, 24, 14, "%d")
    menu.enableDrag = windowGroup:Switch("Drag Panel", true)
    menu.dragOnlyInMenu = windowGroup:Switch("Drag Only In Menu", true)
    menu.snapToEdges = windowGroup:Switch("Snap To Screen Edges", true)
    menu.snapDistance = windowGroup:Slider("Snap Distance", 0, 80, 14, "%d")
    menu.limitPanelHeight = windowGroup:Switch("Limit Panel Height", true)
    menu.maxPanelHeightPct = windowGroup:Slider("Max Height % of Screen", 30, 95, 70, "%d")
    menu.scrollStepRows = windowGroup:Slider("Scroll Step (rows)", 1, 8, 3, "%d")
    menu.scrollUpKey = windowGroup:Bind("Scroll Up Bind", Enum.ButtonCode.KEY_UP)
    menu.scrollDownKey = windowGroup:Bind("Scroll Down Bind", Enum.ButtonCode.KEY_DOWN)
    menu.smoothScroll = windowGroup:Switch("Smooth Scroll", true)
    menu.scrollSmoothness = windowGroup:Slider("Scroll Smoothness", 4, 36, 16, "%d")
    menu.autoDockToShop = windowGroup:Switch("Auto Dock To Shop", true)
    menu.dockSide = windowGroup:Combo("Dock Side", { "Left of Shop", "Right of Shop" }, 0)
    menu.dockGap = windowGroup:Slider("Dock Gap", 0, 48, 10, "%d")

    menu.uiPreset = styleGroup:Combo("UI Preset", { "Custom", "Compact", "Comfortable" }, 0)
    menu.animatePanel = styleGroup:Switch("Animate Panel", true)
    menu.panelAnimSpeed = styleGroup:Slider("Appear Speed", 4, 36, 16, "%d")
    menu.panelAnimSlide = styleGroup:Slider("Appear Slide Px", 0, 32, 10, "%d")
    menu.syncTheme = styleGroup:Switch("Sync With Cheat Theme", true)
    menu.useBlur = styleGroup:Switch("Blur Background", true)
    menu.useShadow = styleGroup:Switch("Shadow", true)
    menu.usePixelFont = styleGroup:Switch("Use 04b03 Font", false)
    menu.titleFontSize = styleGroup:Slider("Title Font Size", 12, 24, 16, "%d")
    menu.textFontSize = styleGroup:Slider("Text Font Size", 10, 18, 14, "%d")
    menu.opacity = styleGroup:Slider("Opacity %", 35, 100, 88, "%d")

    menu.backgroundColor = colorsGroup:ColorPicker("Background Color", Color(20, 20, 30, 200))
    menu.textColor = colorsGroup:ColorPicker("Text Color", Color(255, 255, 255, 255))
    menu.titleColor = colorsGroup:ColorPicker("Title Color", Color(100, 200, 255, 255))
    menu.mutedColor = colorsGroup:ColorPicker("Muted Text Color", Color(175, 195, 225, 230))
    menu.borderColor = colorsGroup:ColorPicker("Border Color", Color(140, 170, 220, 56))
    menu.accentColor = colorsGroup:ColorPicker("Accent Color", Color(100, 200, 255, 255))
    menu.rowColorA = colorsGroup:ColorPicker("Row Color A", Color(90, 120, 170, 18))
    menu.rowColorB = colorsGroup:ColorPicker("Row Color B", Color(90, 120, 170, 34))

    menu.useDiskCache = networkGroup:Switch("Use Disk Cache", true)
    menu.cacheTTLMinutes = networkGroup:Slider("Cache TTL (min)", 1, 60, 10, "%d")
    menu.useStaleCacheOnFail = networkGroup:Switch("Use Stale Cache On Error", true)
    menu.retryWithBackoff = networkGroup:Switch("Retry With Backoff", true)
    menu.maxBackoffSeconds = networkGroup:Slider("Max Backoff (sec)", 10, 300, 120, "%d")
    menu.preloadVisibleIcons = networkGroup:Switch("Preload Visible Icons", true)
    menu.showNetDebug = networkGroup:Switch("Show Net Debug In Footer", false)

    TrySetMenuIcon(menu.enabled, "\u{f00c}")
    TrySetMenuIcon(menu.refreshKey, "\u{f021}")
    TrySetMenuIcon(menu.maxItemsShown, "\u{f03a}")
    TrySetMenuIcon(menu.focusMode, "\u{f0ae}")
    TrySetMenuIcon(menu.showNextBuy, "\u{f061}")
    TrySetMenuIcon(menu.nextBuyCount, "\u{f162}")

    TrySetMenuIcon(menu.visibilityMode, "\u{f06e}")
    TrySetMenuIcon(menu.showItemCost, "\u{f155}")
    TrySetMenuIcon(menu.showGames, "\u{f201}")
    TrySetMenuIcon(menu.showHeroIcon, "\u{f007}")
    TrySetMenuIcon(menu.showSampleConfidence, "\u{f059}")
    TrySetMenuIcon(menu.showOwnedItems, "\u{f00c}")
    TrySetMenuIcon(menu.showComponentProgress, "\u{f0ae}")

    TrySetMenuIcon(menu.positionX, "\u{f061}")
    TrySetMenuIcon(menu.positionY, "\u{f063}")
    TrySetMenuIcon(menu.panelScale, "\u{f065}")
    TrySetMenuIcon(menu.limitPanelHeight, "\u{f2d0}")
    TrySetMenuIcon(menu.scrollUpKey, "\u{f062}")
    TrySetMenuIcon(menu.scrollDownKey, "\u{f063}")
    TrySetMenuIcon(menu.smoothScroll, "\u{f0dc}")
    TrySetMenuIcon(menu.scrollSmoothness, "\u{f0b2}")
    TrySetMenuIcon(menu.autoDockToShop, "\u{f0c1}")
    TrySetMenuIcon(menu.dockSide, "\u{f07e}")

    TrySetMenuIcon(menu.uiPreset, "\u{f1fc}")
    TrySetMenuIcon(menu.animatePanel, "\u{f0d8}")
    TrySetMenuIcon(menu.panelAnimSpeed, "\u{f017}")
    TrySetMenuIcon(menu.panelAnimSlide, "\u{f101}")
    TrySetMenuIcon(menu.syncTheme, "\u{f53f}")
    TrySetMenuIcon(menu.useBlur, "\u{f0eb}")
    TrySetMenuIcon(menu.useShadow, "\u{f2dc}")
    TrySetMenuIcon(menu.usePixelFont, "\u{f031}")
    TrySetMenuIcon(menu.opacity, "\u{f043}")

    TrySetMenuIcon(menu.useDiskCache, "\u{f0a0}")
    TrySetMenuIcon(menu.cacheTTLMinutes, "\u{f017}")
    TrySetMenuIcon(menu.useStaleCacheOnFail, "\u{f0e2}")
    TrySetMenuIcon(menu.retryWithBackoff, "\u{f1da}")
    TrySetMenuIcon(menu.maxBackoffSeconds, "\u{f252}")
    TrySetMenuIcon(menu.preloadVisibleIcons, "\u{f03e}")
    TrySetMenuIcon(menu.showNetDebug, "\u{f188}")

    fontMain = nil
    fontMainMode = nil
    ResetTextLayoutCaches()
    runtimePanelPos.x = nil
    runtimePanelPos.y = nil
    panelDrag.active = false
    panelViewModel.sections = {}
    panelViewModel.dataRef = nil
    panelViewModel.dataHeroID = nil
    panelViewModel.flagsKey = ""
    panelViewModel.timeBucket = -1
    panelViewModel.enemyStamp = -1
    panelViewModel.heroCtxKey = ""
    panelViewModel.inventoryStamp = -1
    panelViewModel.inventory = nil
    panelViewModel.nextBuy = nil
    panelViewModel.scrollSignature = ""
    inventoryCache.hero = nil
    inventoryCache.nextAt = 0
    inventoryCache.stamp = 0
    inventoryCache.signature = ""
    inventoryCache.counts = {}
    inventoryCache.slots = {}
    panelScroll.offset = 0
    panelScroll.target = 0
    panelScroll.maxOffset = 0
    panelAnim.alpha = 0
    panelAnim.visible = false
    EnsureCacheSchema()
    EnsureFont()
end
local function BuildHeroIdCache()
    if heroIdCache then
        return heroIdCache
    end

    heroIdCache = {}
    local heroesData = ReadJsonFile(HEROES_FILE)
    local source = heroesData and (heroesData.DOTAHeroes or heroesData)
    if type(source) == "table" then
        for key, hero in pairs(source) do
            if type(hero) == "table" and type(key) == "string" then
                local id = tonumber(hero.HeroID or hero.id or hero.ID)
                if id and key:find("^npc_dota_hero_") then
                    heroIdCache[key:lower()] = id
                end
            end
        end
    end

    return heroIdCache
end

local function GetHeroIDByName(heroName)
    if not heroName then return nil end
    return BuildHeroIdCache()[tostring(heroName):lower()]
end

local function ParseRecipeRequirements(requirements)
    if type(requirements) ~= "table" then
        return nil
    end

    local counts = {}
    local total = 0
    for _, rawLine in pairs(requirements) do
        if type(rawLine) == "string" and rawLine ~= "" then
            for token in rawLine:gmatch("[^;]+") do
                local key = token:gsub("%*", "")
                key = NormalizeItemKey and NormalizeItemKey(key) or key
                if key and key:find("^item_") then
                    counts[key] = (counts[key] or 0) + 1
                    total = total + 1
                end
            end
        end
    end

    if total <= 0 then
        return nil
    end

    return {
        counts = counts,
        total = total,
    }
end

local function GetItemNameByID(itemID)
    if not itemNameCache then
        itemNameCache = {}
        itemKeyCache = {}
        itemCostCache = {}
        itemDisplayByKeyCache = {}
        itemCostByKeyCache = {}
        itemRecipeByResultCache = {}

        local result = ReadJsonFile(ITEMS_FILE)
        if type(result) == "table" then
            local source = result.DOTAAbilities or result
            for key, item in pairs(source) do
                if type(item) == "table" then
                    local internal = item.name or item.AbilityName or key
                    if type(internal) ~= "string" then
                        internal = tostring(key)
                    end
                    if not internal:find("^item_") then
                        internal = "item_" .. internal
                    end

                    local localized = item.localized_name or item.localizedName
                    local displayName = localized or PrettyItemName(internal)
                    local cost = tonumber(item.ItemCost or item.item_cost or item.cost)

                    itemDisplayByKeyCache[internal] = displayName
                    itemCostByKeyCache[internal] = cost

                    local isRecipe = tostring(item.ItemRecipe or "") == "1"
                    local itemResult = item.ItemResult or item.result
                    if isRecipe and type(itemResult) == "string" then
                        local resultKey = NormalizeItemKey(itemResult)
                        local req = ParseRecipeRequirements(item.ItemRequirements or item.item_requirements)
                        if resultKey and req then
                            itemRecipeByResultCache[resultKey] = req
                        end
                    elseif type(item.ItemRequirements) == "table" then
                        local req = ParseRecipeRequirements(item.ItemRequirements)
                        if req then
                            itemRecipeByResultCache[internal] = req
                        end
                    end

                    local id = tonumber(item.id or item.ID or item.ItemID)
                    if id then
                        itemNameCache[id] = displayName
                        itemKeyCache[id] = internal
                        itemCostCache[id] = cost
                    end
                end
            end
        else
            Log.Write("Item Build: failed to read items catalog from " .. ITEMS_FILE)
        end
    end

    return itemNameCache[itemID] or ("item " .. tostring(itemID))
end

local function EnsureItemCatalogLoaded()
    if not itemNameCache then
        GetItemNameByID(1)
    end
end

local function GetItemCostByID(itemID)
    EnsureItemCatalogLoaded()
    return itemCostCache and itemCostCache[itemID] or nil
end

NormalizeItemKey = function(itemKey)
    if not itemKey then return nil end
    local key = tostring(itemKey)
    if not key:find("^item_") then
        key = "item_" .. key
    end
    return key
end

local function GetItemNameByKey(itemKey)
    EnsureItemCatalogLoaded()
    local key = NormalizeItemKey(itemKey)
    if not key then return "Unknown" end
    return (itemDisplayByKeyCache and itemDisplayByKeyCache[key]) or PrettyItemName(key)
end

local function GetItemCostByKey(itemKey)
    EnsureItemCatalogLoaded()
    local key = NormalizeItemKey(itemKey)
    if not key then return nil end
    return itemCostByKeyCache and itemCostByKeyCache[key] or nil
end

local function GetRecipeInfoByKey(itemKey)
    EnsureItemCatalogLoaded()
    local key = NormalizeItemKey(itemKey)
    if not key then return nil end
    return itemRecipeByResultCache and itemRecipeByResultCache[key] or nil
end

local function GetItemRuntimeName(itemObj)
    if itemObj == nil then
        return nil
    end
    local n = TryCallMethod(itemObj, "GetName")
    if type(n) == "string" and n ~= "" then
        return NormalizeItemKey(n)
    end
    if type(Ability) == "table" and type(Ability.GetName) == "function" then
        local ok, name = pcall(Ability.GetName, itemObj)
        if ok and type(name) == "string" and name ~= "" then
            return NormalizeItemKey(name)
        end
    end
    return nil
end

local function BuildInventorySnapshot(myHero)
    local counts = {}
    local slots = {}
    if not myHero then
        return { counts = counts, slots = slots }
    end

    for slot = 0, 16 do
        local itemObj = nil
        if type(NPC) == "table" and type(NPC.GetItem) == "function" then
            local ok, v = pcall(NPC.GetItem, myHero, slot)
            if ok then
                itemObj = v
            end
        end
        if itemObj == nil then
            itemObj = TryCallMethod(myHero, "GetItem", slot) or TryCallMethod(myHero, "GetItemByIndex", slot)
        end
        if itemObj then
            local key = GetItemRuntimeName(itemObj)
            if key then
                counts[key] = (counts[key] or 0) + 1
                slots[slot] = key
            end
        end
    end

    return {
        counts = counts,
        slots = slots,
    }
end

local function BuildInventorySignature(snap)
    local counts = snap and snap.counts or {}
    local parts = {}
    for key, count in pairs(counts) do
        parts[#parts + 1] = tostring(key) .. "=" .. tostring(count)
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

local function GetInventorySnapshotThrottled(myHero, gameTime)
    if inventoryCache.hero ~= myHero then
        inventoryCache.hero = myHero
        inventoryCache.nextAt = 0
        inventoryCache.stamp = (inventoryCache.stamp or 0) + 1
    end

    local now = gameTime or 0
    if now >= (inventoryCache.nextAt or 0) or type(inventoryCache.counts) ~= "table" then
        local snap = BuildInventorySnapshot(myHero)
        local signature = BuildInventorySignature(snap)
        inventoryCache.counts = snap.counts or {}
        inventoryCache.slots = snap.slots or {}
        inventoryCache.nextAt = now + 0.20
        if inventoryCache.signature ~= signature then
            inventoryCache.signature = signature
            inventoryCache.stamp = (inventoryCache.stamp or 0) + 1
        end
    end

    return inventoryCache
end

local function GetItemOwnershipInfo(itemKey, inventory)
    local key = NormalizeItemKey(itemKey)
    local counts = inventory and inventory.counts or nil
    local exactOwned = (key and counts and (counts[key] or 0) > 0) or false

    local componentOwned = 0
    local componentTotal = 0
    local recipeInfo = key and GetRecipeInfoByKey(key) or nil
    if recipeInfo and type(recipeInfo.counts) == "table" then
        componentTotal = tonumber(recipeInfo.total) or 0
        if counts then
            for compKey, need in pairs(recipeInfo.counts) do
                local owned = counts[compKey] or 0
                componentOwned = componentOwned + math.min(tonumber(need) or 0, owned)
            end
        end
    end

    return {
        owned = exactOwned,
        component_owned = componentOwned,
        component_total = componentTotal,
    }
end

local function GetSampleConfidence(count)
    local c = tonumber(count) or 0
    if c >= 40 then return "high" end
    if c >= 15 then return "mid" end
    return "low"
end

local function BuildStaticItemList(sourceTable, hideStats)
    local list = {}
    if type(sourceTable) ~= "table" then
        return list
    end

    for itemKey, weight in pairs(sourceTable) do
        local key = NormalizeItemKey(itemKey)
        if key then
            table.insert(list, {
                key = key,
                name = GetItemNameByKey(key),
                count = tonumber(weight) or 0,
                cost = GetItemCostByKey(key),
                iconKey = key,
                hideStats = hideStats == true,
                confidence = GetSampleConfidence(weight),
            })
        end
    end

    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    return list
end

local function BuildNeutralSections(gameTime, heroCtx, enemyCtx)
    local sections = {}
    local tier, tierData = GetNeutralTierByGameTime(gameTime or 0)
    if tier <= 0 or type(tierData) ~= "table" then
        return sections
    end

    local recommend = not menu.neutralRecommendations or menu.neutralRecommendations:Get()

    if menu.showNeutralItems and menu.showNeutralItems:Get() then
        local neutrals = BuildStaticItemList(tierData.items, true)
        if #neutrals > 0 then
            if recommend then
                neutrals = RankNeutralEntries(neutrals, ScoreNeutralItem, heroCtx, enemyCtx, gameTime)
            end
            local neutralTitle = recommend and string.format("Neutral Picks (T%d)", tier) or string.format("Neutral Items (T%d)", tier)
            table.insert(sections, { title = neutralTitle, items = neutrals })
        end
    end

    if menu.showCharms and menu.showCharms:Get() then
        local charms = BuildStaticItemList(tierData.enhancements, true)
        if #charms > 0 then
            if recommend then
                charms = RankNeutralEntries(charms, ScoreCharm, heroCtx, enemyCtx, gameTime)
            end
            local charmTitle = recommend and string.format("Charm Picks (T%d)", tier) or string.format("Charms (T%d)", tier)
            table.insert(sections, { title = charmTitle, items = charms })
        end
    end

    return sections
end

local function GetItemIconHandle(itemKey)
    local key = NormalizeItemKey(itemKey)
    if not key then return nil end

    local cached = itemIconCache[key]
    if cached ~= nil then
        return cached or nil
    end

    local iconName = key:gsub("^item_", ""):lower()
    if iconName:match("^%d+$") then
        itemIconCache[key] = false
        return nil
    end

    local candidates = {
        "panorama/images/items/" .. iconName .. "_png.vtex_c",
        "panorama/images/items/" .. key:lower() .. "_png.vtex_c",
        "panorama/images/items/" .. iconName .. ".vtex_c",
    }

    for i = 1, #candidates do
        local ok, loaded = pcall(Render.LoadImage, candidates[i])
        if ok and loaded and loaded ~= 0 then
            itemIconCache[key] = loaded
            return loaded
        end
    end

    itemIconCache[key] = false
    return nil
end

local function GetHeroIconHandle(heroName)
    if not heroName then return nil end
    local key = tostring(heroName)

    local cached = heroIconCache[key]
    if cached ~= nil then
        return cached or nil
    end

    local path = "panorama/images/heroes/icons/" .. key .. "_png.vtex_c"
    local ok, loaded = pcall(Render.LoadImage, path)
    if ok and loaded and loaded ~= 0 then
        heroIconCache[key] = loaded
        return loaded
    end

    heroIconCache[key] = false
    return nil
end
local function LoadItemData(heroID)
    if not heroID or heroID == 0 then return end

    local nowTime = (GameRules.GetGameTime and GameRules.GetGameTime()) or 0
    if httpNextRetryAt > nowTime then
        DebugLog("network cooldown active, skip request")
        return
    end

    if isLoading then
        queuedHeroID = heroID
        return
    end

    isLoading = true
    queuedHeroID = heroID

    local url = string.format("https://api.opendota.com/api/heroes/%d/itemPopularity", heroID)
    local function finalizeRequest()
        isLoading = false
        if queuedHeroID and queuedHeroID ~= heroID then
            local nextHeroID = queuedHeroID
            queuedHeroID = nil
            LoadItemData(nextHeroID)
        end
    end

    local function handleResult(rawResult)
        local response = nil
        local errorMsg = nil
        local statusCode = nil

        if type(rawResult) == "string" then
            response = rawResult
        elseif type(rawResult) == "table" then
            response = rawResult.response or rawResult.body
            errorMsg = rawResult.error or rawResult.errorMsg
            statusCode = tonumber(rawResult.status or rawResult.code)
        end

        if errorMsg and errorMsg ~= "" then
            Log.Write("Item Build: HTTP error: " .. tostring(errorMsg))
            RegisterNetworkFailure(statusCode, errorMsg)
            if menu.useStaleCacheOnFail and menu.useStaleCacheOnFail:Get() then
                TryApplyCachedHeroData(heroID, true)
            end
            finalizeRequest()
            return
        end

        if statusCode and (statusCode < 200 or statusCode >= 300) then
            Log.Write("Item Build: OpenDota HTTP status " .. tostring(statusCode))
            RegisterNetworkFailure(statusCode, "bad_status")
            if menu.useStaleCacheOnFail and menu.useStaleCacheOnFail:Get() then
                TryApplyCachedHeroData(heroID, true)
            end
            finalizeRequest()
            return
        end

        if type(response) == "string" and response ~= "" then
            local data = DecodeJson(response)
            if type(data) == "table" then
                itemData = data
                dataHeroID = heroID
                lastUpdateTime = (GameRules.GetGameTime and GameRules.GetGameTime()) or 0
                dataSource = "live"
                SaveHeroCache(heroID, response)
                ResetNetworkBackoff()
                Log.Write("Item data loaded for hero ID: " .. tostring(heroID))
            else
                Log.Write("Item Build: failed to parse OpenDota response")
                RegisterNetworkFailure(statusCode, "parse_error")
                if menu.useStaleCacheOnFail and menu.useStaleCacheOnFail:Get() then
                    TryApplyCachedHeroData(heroID, true)
                end
            end
        else
            Log.Write("Item Build: empty OpenDota response")
            RegisterNetworkFailure(statusCode, "empty_response")
            if menu.useStaleCacheOnFail and menu.useStaleCacheOnFail:Get() then
                TryApplyCachedHeroData(heroID, true)
            end
        end

        finalizeRequest()
    end

    -- Primary runtime signature in your build:
    -- HTTP.Request(method, url, options, callback)
    local ok4, err4 = pcall(function()
        HTTP.Request("GET", url, { timeout = 10000 }, handleResult)
    end)
    if ok4 then
        return
    end

    -- Fallback signature from docs:
    -- HTTP.Request(method, url, { success=..., error=... })
    local ok3, err3 = pcall(function()
        HTTP.Request("GET", url, {
            timeout = 10000,
            success = function(status, body, headers)
                handleResult({ status = status, body = body, headers = headers })
            end,
            error = function(errorMsg)
                handleResult({ error = errorMsg })
            end
        })
    end)

    if not ok3 then
        Log.Write("Item Build: HTTP request call failed: " .. tostring(err4 or err3))
        RegisterNetworkFailure(0, tostring(err4 or err3))
        if menu.useStaleCacheOnFail and menu.useStaleCacheOnFail:Get() then
            TryApplyCachedHeroData(heroID, true)
        end
        isLoading = false
    end
end

local function SortItemsByPopularity(items)
    local sortedItems = {}
    if type(items) ~= "table" then
        return sortedItems
    end

    for itemName, count in pairs(items) do
        local itemId = tonumber(itemName)
        local displayName = nil
        local itemCost = nil
        local iconKey = nil

        if itemId then
            displayName = GetItemNameByID(itemId)
            itemCost = GetItemCostByID(itemId)
            if itemKeyCache then
                iconKey = itemKeyCache[itemId]
            end
        else
            local key = NormalizeItemKey(itemName)
            displayName = GetItemNameByKey(key)
            itemCost = GetItemCostByKey(key)
            iconKey = key
        end

        if not iconKey then
            iconKey = NormalizeItemKey(itemName)
        end

        if iconKey and tostring(iconKey):find("^item_recipe_", 1, true) then
            goto continue
        end

        table.insert(sortedItems, {
            key = itemName,
            name = displayName or PrettyItemName(itemName),
            count = tonumber(count) or 0,
            cost = itemCost,
            iconKey = iconKey,
            confidence = GetSampleConfidence(count),
        })
        ::continue::
    end

    table.sort(sortedItems, function(a, b)
        if a.count ~= b.count then
            return a.count > b.count
        end
        return tostring(a.name or "") < tostring(b.name or "")
    end)

    return sortedItems
end

local function BlendColor(a, b, t, alphaOverride)
    if not a then return b end
    if not b then return a end
    t = math.max(0, math.min(1, t or 0))
    local r = math.floor((a.r or 0) + (((b.r or 0) - (a.r or 0)) * t) + 0.5)
    local g = math.floor((a.g or 0) + (((b.g or 0) - (a.g or 0)) * t) + 0.5)
    local bb = math.floor((a.b or 0) + (((b.b or 0) - (a.b or 0)) * t) + 0.5)
    local aa = alphaOverride or a.a or 255
    return Color(r, g, bb, aa)
end

local function GetSectionAccentColor(title, palette)
    local base = palette and palette.accent or Color(100, 200, 255, 255)
    local t = tostring(title or ""):lower()
    local target = nil
    if t:find("start", 1, true) then
        target = Color(129, 214, 106, base.a)
    elseif t:find("early", 1, true) then
        target = Color(235, 191, 95, base.a)
    elseif t:find("mid", 1, true) then
        target = Color(108, 177, 255, base.a)
    elseif t:find("late", 1, true) then
        target = Color(236, 112, 112, base.a)
    elseif t:find("neutral", 1, true) then
        target = Color(96, 214, 205, base.a)
    elseif t:find("charm", 1, true) then
        target = Color(219, 208, 121, base.a)
    elseif t:find("next buy", 1, true) then
        target = Color(157, 222, 116, base.a)
    end
    if target then
        return BlendColor(base, target, 0.55, base.a)
    end
    return base
end

local function BuildItemStatsText(item)
    local rightParts = {}
    if menu.showComponentProgress and menu.showComponentProgress:Get() and (item.component_total or 0) > 0 and not item.owned_exact then
        table.insert(rightParts, string.format("%d/%d parts", item.component_owned or 0, item.component_total or 0))
    end
    if menu.showItemCost and menu.showItemCost:Get() then
        if type(item.cost) == "number" then
            table.insert(rightParts, FormatCost(item.cost) .. "g")
        else
            table.insert(rightParts, "n/a")
        end
    end
    if menu.showGames and menu.showGames:Get() then
        table.insert(rightParts, tostring(item.count) .. " games")
    end
    if #rightParts == 0 then
        table.insert(rightParts, tostring(item.count) .. " games")
    end
    if item.next_source_phase and menu.showSourcePhaseInNextBuy and menu.showSourcePhaseInNextBuy:Get() then
        table.insert(rightParts, tostring(item.next_source_phase))
    end
    return table.concat(rightParts, " | ")
end

local function GetPanelSectionsFlagsKey()
    local parts = {
        (menu.showStartItems and menu.showStartItems:Get()) and "1" or "0",
        (menu.showEarlyItems and menu.showEarlyItems:Get()) and "1" or "0",
        (menu.showMidItems and menu.showMidItems:Get()) and "1" or "0",
        (menu.showLateItems and menu.showLateItems:Get()) and "1" or "0",
        (menu.showNeutralItems and menu.showNeutralItems:Get()) and "1" or "0",
        (menu.showCharms and menu.showCharms:Get()) and "1" or "0",
        (menu.neutralRecommendations and menu.neutralRecommendations:Get()) and "1" or "0",
        (menu.neutralTopOnly and menu.neutralTopOnly:Get()) and "1" or "0",
        tostring((menu.neutralTopCount and menu.neutralTopCount:Get()) or 3),
        tostring((menu.focusMode and menu.focusMode:Get()) or 0),
        (menu.showNextBuy and menu.showNextBuy:Get()) and "1" or "0",
        tostring((menu.nextBuyCount and menu.nextBuyCount:Get()) or 2),
        (menu.showOwnedItems and menu.showOwnedItems:Get()) and "1" or "0",
        (menu.showComponentProgress and menu.showComponentProgress:Get()) and "1" or "0",
    }
    return table.concat(parts, ":")
end

local function GetPhaseIndexByGameTime(gameTime)
    local t = tonumber(gameTime) or 0
    if t < 600 then return 1 end   -- start
    if t < 1500 then return 2 end  -- early
    if t < 3000 then return 3 end  -- mid
    return 4                       -- late
end

local function GetPhaseTitleByIndex(index)
    if index == 1 then return "Start Game" end
    if index == 2 then return "Early Game" end
    if index == 3 then return "Mid Game" end
    return "Late Game"
end

local function GetSectionKind(title)
    local t = tostring(title or ""):lower()
    if t:find("start", 1, true) then return "start", 1 end
    if t:find("early", 1, true) then return "early", 2 end
    if t:find("mid", 1, true) then return "mid", 3 end
    if t:find("late", 1, true) then return "late", 4 end
    if t:find("neutral", 1, true) then return "neutral", nil end
    if t:find("charm", 1, true) then return "charm", nil end
    if t:find("next buy", 1, true) then return "next_buy", nil end
    return "other", nil
end

local function ApplyPhaseFocus(phaseSections, gameTime)
    local mode = (menu.focusMode and menu.focusMode:Get()) or 0
    if mode <= 0 then
        return phaseSections
    end

    local currentIndex = GetPhaseIndexByGameTime(gameTime)
    local keep = {}
    keep[currentIndex] = true
    if mode == 1 and currentIndex < 4 then
        keep[currentIndex + 1] = true
    end

    local out = {}
    for i = 1, #phaseSections do
        local section = phaseSections[i]
        local _, idx = GetSectionKind(section.title)
        if idx and keep[idx] then
            out[#out + 1] = section
        end
    end
    return out
end

local function BuildNextBuySection(phaseSections, inventory, gameTime)
    if not (menu.showNextBuy and menu.showNextBuy:Get()) then
        return nil
    end

    local maxCount = math.max(1, (menu.nextBuyCount and menu.nextBuyCount:Get()) or 2)
    local phaseMap = {}
    for i = 1, #phaseSections do
        local section = phaseSections[i]
        local _, idx = GetSectionKind(section.title)
        if idx then
            phaseMap[idx] = section
        end
    end

    local current = GetPhaseIndexByGameTime(gameTime)
    local order = { current }
    if current < 4 then order[#order + 1] = current + 1 end
    for i = 1, 4 do
        local seen = false
        for j = 1, #order do
            if order[j] == i then
                seen = true
                break
            end
        end
        if not seen then
            order[#order + 1] = i
        end
    end

    local seenKeys = {}
    local picks = {}
    local invCounts = inventory and inventory.counts or {}
    for _, phaseIdx in ipairs(order) do
        local section = phaseMap[phaseIdx]
        if section and type(section.items) == "table" then
            for i = 1, #section.items do
                local item = section.items[i]
                local iconKey = NormalizeItemKey(item.iconKey or item.key)
                if iconKey and not seenKeys[iconKey] and (invCounts[iconKey] or 0) <= 0 then
                    seenKeys[iconKey] = true
                    picks[#picks + 1] = {
                        key = item.key,
                        name = item.name,
                        count = item.count,
                        cost = item.cost,
                        iconKey = item.iconKey,
                        confidence = item.confidence or GetSampleConfidence(item.count),
                        next_source_phase = GetPhaseTitleByIndex(phaseIdx),
                    }
                    if #picks >= maxCount then
                        return {
                            title = "Next Buy",
                            items = picks,
                            kind = "next_buy",
                        }
                    end
                end
            end
        end
    end

    if #picks == 0 then
        return nil
    end

    return {
        title = "Next Buy",
        items = picks,
        kind = "next_buy",
    }
end

local function AnnotateSectionItemsWithInventory(section, inventory)
    if type(section) ~= "table" or type(section.items) ~= "table" then
        return
    end
    for i = 1, #section.items do
        local item = section.items[i]
        local own = GetItemOwnershipInfo(item.iconKey or item.key, inventory)
        item.owned_exact = own.owned == true
        item.component_owned = own.component_owned or 0
        item.component_total = own.component_total or 0
        item.confidence = item.confidence or GetSampleConfidence(item.count)
    end
end

local function PreloadVisibleIconsForSections(sections, maxItems)
    if not (menu.preloadVisibleIcons and menu.preloadVisibleIcons:Get()) then
        return
    end
    if type(Render) ~= "table" or type(Render.LoadImage) ~= "function" then
        return
    end
    if type(sections) ~= "table" then
        return
    end

    local limit = math.max(1, tonumber(maxItems) or 5)
    for _, section in ipairs(sections) do
        if section and type(section.items) == "table" then
            local n = math.min(#section.items, limit)
            for i = 1, n do
                local item = section.items[i]
                if item and item.iconKey then
                    GetItemIconHandle(item.iconKey)
                end
            end
        end
    end
end

local function ClampPanelScroll()
    if panelScroll.target == nil then
        panelScroll.target = panelScroll.offset or 0
    end
    if panelScroll.target < 0 then
        panelScroll.target = 0
    end
    if panelScroll.target > (panelScroll.maxOffset or 0) then
        panelScroll.target = panelScroll.maxOffset or 0
    end
    if panelScroll.offset < 0 then
        panelScroll.offset = 0
    end
    if panelScroll.offset > (panelScroll.maxOffset or 0) then
        panelScroll.offset = panelScroll.maxOffset or 0
    end
end

local function UpdateSmoothPanelScroll(panelStyle)
    ClampPanelScroll()
    local target = panelScroll.target or 0
    if not (menu.smoothScroll and menu.smoothScroll:Get()) then
        panelScroll.offset = target
        return
    end

    local smoothness = (menu.scrollSmoothness and menu.scrollSmoothness:Get()) or 14
    local dt = GetFrameDeltaTime()
    panelScroll.offset = SmoothApproach(panelScroll.offset or 0, target, smoothness, dt)
    if math.abs((panelScroll.offset or 0) - target) < 0.2 then
        panelScroll.offset = target
    end
    ClampPanelScroll()
end

local function UpdatePanelAppearAnimation(visibleWanted)
    if panelAnim.visible ~= visibleWanted then
        panelAnim.visible = visibleWanted
        if visibleWanted then
            panelAnim.alpha = math.min(panelAnim.alpha or 0, 0.02)
        end
    end

    local target = visibleWanted and 1 or 0
    if not (menu.animatePanel and menu.animatePanel:Get()) then
        panelAnim.alpha = target
        return panelAnim.alpha
    end

    local speed = (menu.panelAnimSpeed and menu.panelAnimSpeed:Get()) or 14
    local dt = GetFrameDeltaTime()
    panelAnim.alpha = SmoothApproach(panelAnim.alpha or 0, target, speed, dt)
    if math.abs((panelAnim.alpha or 0) - target) < 0.01 then
        panelAnim.alpha = target
    end
    return panelAnim.alpha
end

local function HandlePanelScrollInput(panelStyle)
    if not (menu.limitPanelHeight and menu.limitPanelHeight:Get()) then
        panelScroll.offset = 0
        panelScroll.target = 0
        return
    end
    if (panelScroll.maxOffset or 0) <= 0 then
        panelScroll.offset = 0
        panelScroll.target = 0
        return
    end
    if type(Input) ~= "table" then
        return
    end

    local stepRows = (menu.scrollStepRows and menu.scrollStepRows:Get()) or 3
    local stepPx = math.max(8, ((panelStyle and panelStyle.row_height) or 20) * stepRows)

    local function bindPressed(bindWidget)
        if bindWidget and type(bindWidget.IsPressed) == "function" then
            local ok, pressed = pcall(bindWidget.IsPressed, bindWidget)
            if ok and pressed then
                return true
            end
        end
        return false
    end

    local up = bindPressed(menu.scrollUpKey)
    local down = bindPressed(menu.scrollDownKey)

    if up then
        panelScroll.target = (panelScroll.target or panelScroll.offset or 0) - stepPx
    end
    if down then
        panelScroll.target = (panelScroll.target or panelScroll.offset or 0) + stepPx
    end
    ClampPanelScroll()
end

local function GetShopPanelBounds()
    local panel = FindShopPanel()
    if panel and type(panel.GetBounds) == "function" then
        local ok, b = pcall(panel.GetBounds, panel)
        if ok and type(b) == "table" and b.x and b.y and b.w and b.h then
            return tonumber(b.x), tonumber(b.y), tonumber(b.w), tonumber(b.h)
        end
    end
    if type(Panorama) == "table" and type(Panorama.GetPanelInfo) == "function" then
        local ok, info = pcall(Panorama.GetPanelInfo, { SHOP_HUD_ROOT_ID, SHOP_PANEL_ID }, false)
        if ok and type(info) == "table" and info.x and info.y and info.w and info.h then
            return tonumber(info.x), tonumber(info.y), tonumber(info.w), tonumber(info.h)
        end
    end
    return nil
end

local function ResolveAutoDockPosition(panelW, panelH)
    if not (menu.autoDockToShop and menu.autoDockToShop:Get()) then
        return nil, nil
    end
    if not IsShopOpen() then
        return nil, nil
    end
    if panelDrag.active then
        return nil, nil
    end

    local sx, sy, sw, sh = GetShopPanelBounds()
    if not (sx and sy and sw and sh) then
        return nil, nil
    end

    local side = (menu.dockSide and menu.dockSide:Get()) or 0
    local gap = (menu.dockGap and menu.dockGap:Get()) or 10
    local x
    if side <= 0 then
        x = sx - panelW - gap
    else
        x = sx + sw + gap
    end
    local y = sy
    return x, y
end

local function GetEnemyContextThrottled(myHero, gameTime)
    if not myHero then
        return enemyCtxCache.value
    end

    if enemyCtxCache.hero ~= myHero then
        enemyCtxCache.hero = myHero
        enemyCtxCache.nextAt = 0
    end

    local now = gameTime or 0
    if now >= (enemyCtxCache.nextAt or 0) or type(enemyCtxCache.value) ~= "table" then
        enemyCtxCache.value = GetEnemyContext(myHero)
        enemyCtxCache.nextAt = now + 0.35
        enemyCtxCache.stamp = (enemyCtxCache.stamp or 0) + 1
    end

    return enemyCtxCache.value
end

local function RefreshPanelViewModel(myHero, heroName, heroID, gameTime)
    local safeHeroName = heroName or "unknown"
    local heroCtx = GetHeroContext(myHero, safeHeroName)
    local enemyCtx = GetEnemyContextThrottled(myHero, gameTime)
    local inventorySnap = GetInventorySnapshotThrottled(myHero, gameTime)
    local heroCtxKey = tostring(heroCtx.attr or "all") .. ":" .. ((heroCtx.ranged and "1") or "0")
    local timeBucket = math.floor((gameTime or 0) / 5)
    local flagsKey = GetPanelSectionsFlagsKey()

    local dataRef = itemData
    local needRebuild = panelViewModel.dataRef ~= dataRef
        or panelViewModel.dataHeroID ~= dataHeroID
        or panelViewModel.heroID ~= heroID
        or panelViewModel.flagsKey ~= flagsKey
        or panelViewModel.timeBucket ~= timeBucket
        or panelViewModel.enemyStamp ~= enemyCtxCache.stamp
        or panelViewModel.heroCtxKey ~= heroCtxKey
        or panelViewModel.inventoryStamp ~= inventoryCache.stamp

    if not needRebuild then
        panelViewModel.heroName = safeHeroName
        panelViewModel.heroLabel = PrettyItemName(safeHeroName:gsub("^npc_dota_hero_", ""))
        panelViewModel.inventory = inventorySnap
        return panelViewModel
    end

    local data = dataRef or {}
    local phaseSections = {}
    if menu.showStartItems:Get() then
        table.insert(phaseSections, { title = "Start Game", items = SortItemsByPopularity(data.start_game_items or {}) })
    end
    if menu.showEarlyItems:Get() then
        table.insert(phaseSections, { title = "Early Game", items = SortItemsByPopularity(data.early_game_items or {}) })
    end
    if menu.showMidItems:Get() then
        table.insert(phaseSections, { title = "Mid Game", items = SortItemsByPopularity(data.mid_game_items or {}) })
    end
    if menu.showLateItems:Get() then
        table.insert(phaseSections, { title = "Late Game", items = SortItemsByPopularity(data.late_game_items or {}) })
    end

    local sections = {}
    local nextBuySection = BuildNextBuySection(phaseSections, inventorySnap, gameTime)
    if nextBuySection then
        table.insert(sections, nextBuySection)
    end

    local focusedPhases = ApplyPhaseFocus(phaseSections, gameTime)
    for _, section in ipairs(focusedPhases) do
        table.insert(sections, section)
    end
    for _, section in ipairs(BuildNeutralSections(gameTime, heroCtx, enemyCtx)) do
        table.insert(sections, section)
    end

    for _, section in ipairs(sections) do
        AnnotateSectionItemsWithInventory(section, inventorySnap)
    end

    panelViewModel.sections = sections
    panelViewModel.heroID = heroID
    panelViewModel.heroName = safeHeroName
    panelViewModel.heroLabel = PrettyItemName(safeHeroName:gsub("^npc_dota_hero_", ""))
    panelViewModel.dataRef = dataRef
    panelViewModel.dataHeroID = dataHeroID
    panelViewModel.flagsKey = flagsKey
    panelViewModel.timeBucket = timeBucket
    panelViewModel.enemyStamp = enemyCtxCache.stamp
    panelViewModel.heroCtxKey = heroCtxKey
    panelViewModel.inventoryStamp = inventoryCache.stamp
    panelViewModel.inventory = inventorySnap
    panelViewModel.nextBuy = nextBuySection

    return panelViewModel
end

local function DrawItemList(title, items, y, maxItems, panelX, panelW, palette, panelStyle)
    if not items or #items == 0 then return y end
    if not fontMain then return y end

    panelStyle = panelStyle or GetPanelStyle()
    local rowHeight = panelStyle.row_height
    local iconSize = math.max(10, panelStyle.icon_size)
    local uiScale = panelStyle.ui_scale or 1.0
    local fonts = GetResolvedFontSizes(uiScale)
    local titleSize = math.max(10, fonts.title - 1)
    local textSize = fonts.text
    local subTextSize = math.max(10, textSize - 2)
    local sectionHeaderHeight = math.max(20, textSize + 10)
    local sectionAccent = GetSectionAccentColor(title, palette)
    local sideInset = math.max(8, panelStyle.padding - 1)
    local rowInset = math.max(6, math.floor(sideInset * 0.75))
    local rowRadius = math.max(3, math.min(panelStyle.rounding, math.floor(rowHeight * 0.45)))
    local rowLeft = panelX + sideInset
    local rowRight = panelX + panelW - sideInset

    local headerTop = y + 1
    local headerBottom = y + sectionHeaderHeight - 4
    local headerBgAlpha = math.max(14, math.floor((palette.bg.a or 80) * 0.22))
    Render.FilledRect(
        Vec2(rowLeft, headerTop),
        Vec2(rowRight, headerBottom),
        Alpha(sectionAccent, headerBgAlpha),
        rowRadius
    )
    Render.FilledRect(
        Vec2(rowLeft, headerTop),
        Vec2(rowLeft + math.max(3, math.floor(uiScale * 3)), headerBottom),
        Alpha(sectionAccent, math.floor(150 + (panelStyle.row_height * 2))),
        rowRadius
    )

    Render.Text(fontMain, titleSize, title, Vec2(rowLeft + rowInset + 4, y), sectionAccent)

    local displayCount = math.min(#items, maxItems)
    local countText = string.format("%d/%d", displayCount, #items)
    local countW = MeasureTextWidth(countText)
    Render.Text(fontMain, subTextSize, countText, Vec2(math.max(rowLeft + 10, rowRight - rowInset - countW), y + 1), palette.muted)
    y = y + sectionHeaderHeight

    for i = 1, displayCount do
        local item = items[i]
        local hideStats = item.hideStats == true
        local rightText = hideStats and "" or BuildItemStatsText(item)

        local rowTop = y - 1
        local rowBottom = y + rowHeight - 3
        local rowColor = (i % 2 == 0) and palette.rowB or palette.rowA
        if menu.showOwnedItems and menu.showOwnedItems:Get() then
            if item.owned_exact then
                rowColor = BlendColor(rowColor, Color(92, 188, 122, rowColor.a), 0.36, rowColor.a)
            elseif (item.component_total or 0) > 0 and (item.component_owned or 0) > 0 then
                local ratio = math.min(1, (item.component_owned or 0) / math.max(1, item.component_total or 1))
                rowColor = BlendColor(rowColor, Color(232, 187, 84, rowColor.a), 0.12 + (0.20 * ratio), rowColor.a)
            end
        end
        if i <= 3 then
            rowColor = BlendColor(rowColor, sectionAccent, 0.18, rowColor.a)
        end
        Render.FilledRect(Vec2(rowLeft, rowTop), Vec2(rowRight, rowBottom), rowColor, rowRadius)

        local stripeW = (i <= 3) and math.max(2, math.floor(uiScale * 2)) or 1
        Render.FilledRect(
            Vec2(rowLeft, rowTop),
            Vec2(rowLeft + stripeW, rowBottom),
            Alpha(sectionAccent, (i <= 3) and 190 or 70),
            rowRadius
        )

        local rankText = tostring(i) .. "."
        local rankColor = (i <= 3) and Alpha(sectionAccent, 230) or palette.muted
        local rankX = rowLeft + rowInset + 2
        local rankW = MeasureTextWidth(rankText)
        Render.Text(fontMain, subTextSize, rankText, Vec2(rankX, y + 1), rankColor)

        local icon = GetItemIconHandle(item.iconKey)
        local textX = rankX + rankW + 8
        if icon then
            local iconY = y + math.floor((rowHeight - iconSize) / 2) - 1
            local iconAlpha = (item.owned_exact and menu.showOwnedItems and menu.showOwnedItems:Get()) and 205 or 235
            Render.Image(icon, Vec2(textX, iconY), Vec2(iconSize, iconSize), Color(255, 255, 255, iconAlpha), 3)
            textX = textX + iconSize + 6
        end

        local rightX = rowRight - rowInset
        local confColor = nil
        local confReserve = 0
        local confDotR = 0
        local confCx = nil
        local confCy = nil
        if menu.showSampleConfidence and menu.showSampleConfidence:Get() and not hideStats then
            local conf = item.confidence or GetSampleConfidence(item.count)
            if conf == "high" then
                confColor = Color(108, 207, 120, 220)
            elseif conf == "mid" then
                confColor = Color(233, 186, 77, 220)
            else
                confColor = Color(237, 116, 116, 220)
            end
            confDotR = math.max(2, math.floor(uiScale * 2))
            confReserve = confDotR * 2 + 6
            confCx = rowRight - rowInset - confDotR
            confCy = y + math.floor(rowHeight * 0.5) - 1
        end
        if rightText ~= "" then
            local rightW = MeasureTextWidth(rightText)
            rightX = math.max(textX + 20, rowRight - rowInset - confReserve - rightW)
            Render.Text(fontMain, subTextSize, rightText, Vec2(rightX, y + 1), palette.muted)
        end
        if confColor and confCx and confCy then
            if Render.FilledCircle then
                TryRender(Render.FilledCircle, Vec2(confCx, confCy), confDotR, confColor, 12)
            else
                Render.FilledRect(Vec2(confCx - confDotR, confCy - confDotR), Vec2(confCx + confDotR, confCy + confDotR), confColor, confDotR)
            end
        end

        local maxTextWidth = math.max(20, (rightText ~= "" and (rightX - 10) or (rowRight - rowInset)) - textX)
        local itemText = TruncateTextToWidth(item.name, maxTextWidth)
        local itemTextColor = palette.text
        if menu.showOwnedItems and menu.showOwnedItems:Get() and item.owned_exact then
            itemTextColor = BlendColor(palette.text, Color(158, 232, 172, palette.text.a), 0.45, palette.text.a)
        end
        Render.Text(fontMain, textSize, itemText, Vec2(textX, y), itemTextColor)
        y = y + rowHeight
    end

    return y + panelStyle.section_gap
end

local function BuildUpdateStatusInfo(gameTime)
    local updateText = "Updated: pending"
    if lastUpdateTime > 0 then
        local timeDiff = math.max(0, math.floor(((gameTime or 0) - lastUpdateTime) / 60))
        local sourceLabel = (dataSource == "cache") and "cache" or "live"
        updateText = string.format("Updated: %d min ago (%s)", timeDiff, sourceLabel)
    elseif dataSource == "cache" then
        updateText = "Updated: cache"
    end

    local chipText = "Pending"
    local chipState = "idle"
    if isLoading then
        chipText = "Loading"
        chipState = "loading"
    elseif httpNextRetryAt > (gameTime or 0) then
        local waitSec = math.max(0, math.floor(httpNextRetryAt - (gameTime or 0)))
        chipText = string.format("Retry %ds", waitSec)
        chipState = "retry"
        updateText = updateText .. string.format(" | retry in %ds", waitSec)
    elseif dataSource == "live" then
        chipText = "Live"
        chipState = "live"
    elseif dataSource == "cache" then
        chipText = "Cache"
        chipState = "cache"
    end

    if menu.showNetDebug and menu.showNetDebug:Get() then
        updateText = updateText .. string.format(" | http:%s fail:%d", tostring(httpLastStatus or 0), tonumber(httpFailureCount) or 0)
        if httpLastError and httpLastError ~= "" and chipState ~= "loading" then
            chipText = chipText .. "*"
        end
    end

    return updateText, chipText, chipState
end

function script.OnUpdate()
    if not IsMenuReady() then return end
    if not menu.enabled:Get() then return end

    local myHero = Heroes.GetLocal()
    if not myHero or not Entity.IsAlive(myHero) then return end

    local heroName = NPC.GetUnitName(myHero)
    if not heroName then return end

    local currentHeroID = GetHeroIDByName(heroName)
    if not currentHeroID then return end

    local currentTime = (GameRules.GetGameTime and GameRules.GetGameTime()) or 0
    local forceRefresh = menu.refreshKey and menu.refreshKey.IsPressed and menu.refreshKey:IsPressed()
    if forceRefresh then
        httpNextRetryAt = 0
    end

    if currentHeroID ~= lastHeroID then
        itemData = {}
        dataHeroID = nil
        lastUpdateTime = 0
        dataSource = "none"
        panelScroll.offset = 0
        panelScroll.target = 0
        panelScroll.maxOffset = 0
        if menu.useDiskCache and menu.useDiskCache:Get() then
            TryApplyCachedHeroData(currentHeroID, false)
        end
    end

    local needUpdate = currentHeroID ~= lastHeroID
        or dataHeroID ~= currentHeroID
        or (currentTime - lastUpdateTime > updateInterval)
        or dataSource == "cache"
        or forceRefresh

    if needUpdate then
        lastHeroID = currentHeroID
        if currentTime >= httpNextRetryAt then
            LoadItemData(currentHeroID)
        else
            DebugLog("skip network update, cooldown remains " .. tostring(math.max(0, math.floor(httpNextRetryAt - currentTime))) .. "s")
            if menu.useDiskCache and menu.useDiskCache:Get() and dataHeroID ~= currentHeroID then
                TryApplyCachedHeroData(currentHeroID, true)
            end
        end
    end

    local model = RefreshPanelViewModel(myHero, heroName, currentHeroID, currentTime)
    HandlePanelScrollInput(GetPanelStyle())
    PreloadVisibleIconsForSections(model and model.sections or nil, math.max((menu.maxItemsShown and menu.maxItemsShown:Get()) or 5, (menu.nextBuyCount and menu.nextBuyCount:Get()) or 2))
end

function script.OnDraw()
    if not IsMenuReady() then return end
    if not menu.enabled:Get() then return end
    local wantsVisible = ShouldDrawPanel()
    local animAlpha = UpdatePanelAppearAnimation(wantsVisible)
    if not wantsVisible and animAlpha <= 0.01 then return end
    if not wantsVisible then return end

    local myHero = Heroes.GetLocal()
    if not myHero or not Entity.IsAlive(myHero) then return end

    EnsureFont()
    if not fontMain then return end

    local heroName = NPC.GetUnitName(myHero) or "unknown"
    local currentHeroID = GetHeroIDByName(heroName)
    if not currentHeroID then return end

    local gameTime = (GameRules.GetGameTime and GameRules.GetGameTime()) or 0
    local model = RefreshPanelViewModel(myHero, heroName, currentHeroID, gameTime)
    local sections = model.sections or {}
    local heroLabel = model.heroLabel or PrettyItemName(heroName:gsub("^npc_dota_hero_", ""))

    local panelStyle = GetPanelStyle()
    local panelX, panelY = ResolvePanelPosition()
    local panelW = panelStyle.width
    local maxItems = menu.maxItemsShown:Get()
    local baseOpacity = (menu.opacity and menu.opacity:Get() or 88) / 100
    local drawOpacity = baseOpacity * animAlpha
    local palette = ApplyPaletteAlpha(ResolvePalette(baseOpacity), animAlpha)
    local uiScale = panelStyle.ui_scale or 1.0
    local fonts = GetResolvedFontSizes(uiScale)
    local titleFontSize = fonts.title
    local textFontSize = fonts.text
    local footerFontSize = math.max(10, textFontSize - 2)
    local sectionHeaderHeight = math.max(20, textFontSize + 10)
    local headerPadX = math.max(10, panelStyle.padding)

    local visibleSections = 0
    local contentHeight = 0
    for _, section in ipairs(sections) do
        if #section.items > 0 then
            visibleSections = visibleSections + 1
            contentHeight = contentHeight + sectionHeaderHeight + math.min(#section.items, maxItems) * panelStyle.row_height + panelStyle.section_gap
        end
    end

    if isLoading then
        contentHeight = contentHeight + math.max(panelStyle.row_height, textFontSize + 8)
    end
    if visibleSections == 0 and not isLoading then
        contentHeight = math.max(panelStyle.row_height * 2, 42)
    end

    local screenW, screenH = GetScreenSize2D()
    local contentViewportH = contentHeight
    if menu.limitPanelHeight and menu.limitPanelHeight:Get() then
        local maxPct = (menu.maxPanelHeightPct and menu.maxPanelHeightPct:Get()) or 70
        local maxPanelH = math.max(160, math.floor(screenH * (maxPct / 100)))
        local fixedH = panelStyle.header_height + panelStyle.padding * 2 + panelStyle.footer_height
        local maxContentH = math.max(panelStyle.row_height * 2, maxPanelH - fixedH)
        contentViewportH = math.min(contentHeight, maxContentH)
    end
    panelScroll.maxOffset = math.max(0, contentHeight - contentViewportH)
    ClampPanelScroll()
    UpdateSmoothPanelScroll(panelStyle)

    local panelH = panelStyle.header_height + panelStyle.padding * 2 + contentViewportH + panelStyle.footer_height

    local dockX, dockY = ResolveAutoDockPosition(panelW, panelH)
    if dockX ~= nil and dockY ~= nil then
        panelX = dockX
        panelY = dockY
    end
    panelX = math.max(0, math.min(panelX, screenW - panelW))
    panelY = math.max(0, math.min(panelY, screenH - panelH))
    if dockX == nil then
        panelX, panelY = HandlePanelDragging(panelX, panelY, panelW, panelH, panelStyle.header_height)
    end

    if animAlpha < 0.999 then
        local slidePx = (menu.panelAnimSlide and menu.panelAnimSlide:Get()) or 10
        if slidePx > 0 then
            panelY = panelY + math.floor((1 - animAlpha) * slidePx + 0.5)
        end
    end

    if menu.useBlur and menu.useBlur:Get() and Render.Blur then
        TryRender(Render.Blur, Vec2(panelX, panelY), Vec2(panelX + panelW, panelY + panelH), 1.0)
    end

    if menu.useShadow and menu.useShadow:Get() and Render.Shadow then
        TryRender(Render.Shadow, Vec2(panelX, panelY), Vec2(panelX + panelW, panelY + panelH), 14, Color(0, 0, 0, math.floor(120 * drawOpacity)), panelStyle.rounding)
    end

    Render.FilledRect(Vec2(panelX, panelY), Vec2(panelX + panelW, panelY + panelH), palette.bg, panelStyle.rounding)
    Render.FilledRect(Vec2(panelX, panelY), Vec2(panelX + panelW, panelY + panelStyle.header_height), palette.bgHeader, panelStyle.rounding)

    if Render.Rect then
        local drawFlags = Enum and Enum.DrawFlags and Enum.DrawFlags.RoundCornersAll or nil
        local okRect = false
        if drawFlags ~= nil then
            okRect = TryRender(Render.Rect, Vec2(panelX, panelY), Vec2(panelX + panelW, panelY + panelH), palette.border, panelStyle.rounding, drawFlags, 1)
        end
        if not okRect and Render.OutlineRect then
            TryRender(Render.OutlineRect, Vec2(panelX, panelY), Vec2(panelX + panelW, panelY + panelH), palette.border, panelStyle.rounding, 1)
        end
    elseif Render.OutlineRect then
        Render.OutlineRect(Vec2(panelX, panelY), Vec2(panelX + panelW, panelY + panelH), palette.border, panelStyle.rounding, 1)
    end

    local updateText, chipText, chipState = BuildUpdateStatusInfo(gameTime)
    local chipTarget = Color(145, 175, 220, 255)
    if chipState == "live" then
        chipTarget = Color(126, 214, 129, 255)
    elseif chipState == "cache" then
        chipTarget = Color(104, 176, 255, 255)
    elseif chipState == "loading" then
        chipTarget = Color(236, 194, 96, 255)
    elseif chipState == "retry" then
        chipTarget = Color(239, 123, 123, 255)
    end
    local chipColor = BlendColor(palette.accent, chipTarget, 0.55, palette.accent.a)

    Render.Line(
        Vec2(panelX + headerPadX, panelY + panelStyle.header_height),
        Vec2(panelX + panelW - headerPadX, panelY + panelStyle.header_height),
        Alpha(palette.accent, math.floor(90 * drawOpacity)),
        1
    )

    local titleText = "Item Build"
    local titleW = MeasureTextWidth(titleText)
    local titleX = panelX + headerPadX
    local titleY = panelY + math.max(6, math.floor((panelStyle.header_height - titleFontSize) * 0.5) - 1)
    Render.Text(fontMain, titleFontSize, titleText, Vec2(titleX, titleY), palette.title)

    local heroIcon = (menu.showHeroIcon and menu.showHeroIcon:Get()) and GetHeroIconHandle(heroName) or nil
    local rightCursor = panelX + panelW - headerPadX
    if heroIcon then
        local heroIconSize = math.max(14, panelStyle.icon_size + 4)
        local iconY = panelY + math.max(4, math.floor((panelStyle.header_height - heroIconSize) * 0.5))
        local iconX = rightCursor - heroIconSize
        Render.Image(heroIcon, Vec2(iconX, iconY), Vec2(heroIconSize, heroIconSize), Color(255, 255, 255, 240), 4)
        rightCursor = iconX - 6
    end

    local heroMinLeft = panelX + math.floor(panelW * 0.50)
    local heroTextMaxW = math.max(44, rightCursor - heroMinLeft)
    local heroText = TruncateTextToWidth(heroLabel, heroTextMaxW)
    local heroTextW = MeasureTextWidth(heroText)
    if heroText ~= "" and heroTextW > 0 then
        local heroTextX = rightCursor - heroTextW
        local heroTextY = panelY + math.max(6, math.floor((panelStyle.header_height - footerFontSize) * 0.5) - 1)
        Render.Text(fontMain, footerFontSize, heroText, Vec2(heroTextX, heroTextY), palette.muted)
        rightCursor = heroTextX - 8
    end

    local chipTextW = MeasureTextWidth(chipText)
    local chipPadX = math.max(6, math.floor(6 * uiScale))
    local chipH = math.max(14, math.min(panelStyle.header_height - 10, math.floor(18 * uiScale)))
    local chipW = chipTextW + chipPadX * 2
    local chipRight = rightCursor
    local chipLeftLimit = titleX + titleW + 12
    local chipX = chipRight - chipW
    if chipText ~= "" and chipX >= chipLeftLimit then
        local chipY = panelY + math.max(4, math.floor((panelStyle.header_height - chipH) * 0.5))
        Render.FilledRect(
            Vec2(chipX, chipY),
            Vec2(chipX + chipW, chipY + chipH),
            Alpha(chipColor, math.max(16, math.floor(60 * drawOpacity))),
            math.max(4, math.floor(chipH * 0.45))
        )
        if Render.Rect then
            local chipRound = math.max(4, math.floor(chipH * 0.45))
            local chipBorder = Alpha(chipColor, math.max(36, math.floor(155 * drawOpacity)))
            local drawFlags = Enum and Enum.DrawFlags and Enum.DrawFlags.RoundCornersAll or nil
            local okChipRect = false
            if drawFlags ~= nil then
                okChipRect = TryRender(
                    Render.Rect,
                    Vec2(chipX, chipY),
                    Vec2(chipX + chipW, chipY + chipH),
                    chipBorder,
                    chipRound,
                    drawFlags,
                    1
                )
            end
            if not okChipRect and Render.OutlineRect then
                TryRender(
                    Render.OutlineRect,
                    Vec2(chipX, chipY),
                    Vec2(chipX + chipW, chipY + chipH),
                    chipBorder,
                    chipRound,
                    1
                )
            end
        elseif Render.OutlineRect then
            TryRender(
                Render.OutlineRect,
                Vec2(chipX, chipY),
                Vec2(chipX + chipW, chipY + chipH),
                Alpha(chipColor, math.max(36, math.floor(155 * drawOpacity))),
                math.max(4, math.floor(chipH * 0.45)),
                1
            )
        end
        Render.Text(fontMain, footerFontSize, chipText, Vec2(chipX + chipPadX, chipY + 1), chipColor)
    end

    local contentClipX = panelX + math.max(4, panelStyle.padding - 4)
    local contentClipY = panelY + panelStyle.header_height + panelStyle.padding
    local contentClipW = panelW - (math.max(4, panelStyle.padding - 4) * 2)
    local contentClipH = contentViewportH
    local y = contentClipY - (panelScroll.offset or 0)
    local drewAny = false
    local pushedClip = PushClipRect(contentClipX, contentClipY, contentClipW, contentClipH)

    if isLoading then
        local msgInset = math.max(8, panelStyle.padding - 1)
        local rowTop = y - 1
        local rowBottom = y + panelStyle.row_height - 3
        Render.FilledRect(
            Vec2(panelX + msgInset, rowTop),
            Vec2(panelX + panelW - msgInset, rowBottom),
            Alpha(chipColor, math.max(8, math.floor(22 * drawOpacity))),
            math.max(3, math.floor(panelStyle.rounding * 0.4))
        )
        Render.Text(fontMain, textFontSize, "Loading OpenDota data...", Vec2(panelX + msgInset + 8, y), palette.text)
        y = y + panelStyle.row_height
    end

    for _, section in ipairs(sections) do
        if #section.items > 0 then
            drewAny = true
            y = DrawItemList(section.title .. ":", section.items, y, maxItems, panelX, panelW, palette, panelStyle)
        end
    end

    if not drewAny and not isLoading then
        local msgInset = math.max(8, panelStyle.padding - 1)
        if menu.showNeutralItems and menu.showNeutralItems:Get() and gameTime < 300 then
            Render.Text(fontMain, textFontSize, "Neutral items unlock at 5:00.", Vec2(panelX + msgInset, y), palette.text)
        else
            Render.Text(fontMain, textFontSize, "No item stats for this hero.", Vec2(panelX + msgInset, y), palette.text)
        end
    end

    if pushedClip then
        PopClipRect()
    end

    if (panelScroll.maxOffset or 0) > 0 then
        local trackW = math.max(4, math.floor(uiScale * 4))
        local trackX = panelX + panelW - math.max(5, math.floor(panelStyle.padding * 0.55)) - trackW
        local trackY = contentClipY + 2
        local trackH = math.max(12, contentClipH - 4)
        local thumbH = math.max(14, math.floor(trackH * (contentClipH / math.max(contentClipH, contentHeight))))
        local thumbTravel = math.max(0, trackH - thumbH)
        local ratio = (panelScroll.maxOffset > 0) and ((panelScroll.offset or 0) / panelScroll.maxOffset) or 0
        local thumbY = trackY + math.floor(thumbTravel * ratio + 0.5)
        Render.FilledRect(
            Vec2(trackX, trackY),
            Vec2(trackX + trackW, trackY + trackH),
            Alpha(palette.border, math.max(10, math.floor(42 * drawOpacity))),
            trackW
        )
        Render.FilledRect(
            Vec2(trackX, thumbY),
            Vec2(trackX + trackW, thumbY + thumbH),
            Alpha(chipColor, math.max(36, math.floor(180 * drawOpacity))),
            trackW
        )
    end

    local footerTop = panelY + panelH - panelStyle.footer_height
    Render.Line(
        Vec2(panelX + headerPadX, footerTop),
        Vec2(panelX + panelW - headerPadX, footerTop),
        Alpha(palette.border, math.max(10, math.floor(80 * drawOpacity))),
        1
    )
    local dotSize = math.max(3, math.floor(4 * uiScale))
    local dotY = footerTop + math.max(6, math.floor((panelStyle.footer_height - dotSize) * 0.5))
    Render.FilledRect(
        Vec2(panelX + headerPadX, dotY),
        Vec2(panelX + headerPadX + dotSize, dotY + dotSize),
        Alpha(chipColor, 210),
        dotSize
    )
    local footerText = updateText
    if (panelScroll.maxOffset or 0) > 0 then
        local pct = math.floor((((panelScroll.offset or 0) / math.max(1, panelScroll.maxOffset)) * 100) + 0.5)
        footerText = footerText .. string.format(" | scroll %d%%", pct)
    end
    local footerTextX = panelX + headerPadX + dotSize + 6
    local footerTextMaxW = math.max(20, (panelX + panelW - headerPadX) - footerTextX)
    footerText = TruncateTextToWidth(footerText, footerTextMaxW)
    Render.Text(fontMain, footerFontSize, footerText, Vec2(footerTextX, panelY + panelH - 18), palette.muted)
end

function script.OnGameEnd()
    itemData = {}
    lastHeroID = nil
    lastUpdateTime = 0
    isLoading = false
    dataHeroID = nil
    queuedHeroID = nil
    shopCache = false
    shopCacheT = 0
    shopPanel = nil
    shopPanelSearchDone = false
    shopPanelNextSearchAt = 0
    neutralTiersCache = nil
    heroMetaCache = nil
    itemRecipeByResultCache = nil
    runtimePanelPos.x = nil
    runtimePanelPos.y = nil
    panelDrag.active = false
    dataSource = "none"
    ResetTextLayoutCaches()
    enemyCtxCache.hero = nil
    enemyCtxCache.nextAt = 0
    enemyCtxCache.stamp = 0
    enemyCtxCache.value = {
        total = 0,
        melee = 0,
        ranged = 0,
        invisThreat = 0,
    }
    inventoryCache.hero = nil
    inventoryCache.nextAt = 0
    inventoryCache.stamp = 0
    inventoryCache.signature = ""
    inventoryCache.counts = {}
    inventoryCache.slots = {}
    panelScroll.offset = 0
    panelScroll.target = 0
    panelScroll.maxOffset = 0
    panelAnim.alpha = 0
    panelAnim.visible = false
    panelViewModel.heroID = nil
    panelViewModel.heroName = "unknown"
    panelViewModel.heroLabel = "Unknown"
    panelViewModel.sections = {}
    panelViewModel.dataRef = nil
    panelViewModel.dataHeroID = nil
    panelViewModel.flagsKey = ""
    panelViewModel.timeBucket = -1
    panelViewModel.enemyStamp = -1
    panelViewModel.heroCtxKey = ""
    panelViewModel.inventoryStamp = -1
    panelViewModel.inventory = nil
    panelViewModel.nextBuy = nil
    panelViewModel.scrollSignature = ""
    ResetNetworkBackoff()
end

return script
