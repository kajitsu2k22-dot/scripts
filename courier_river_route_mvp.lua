local script = {}

-- MVP heuristic router for courier delivery via river hubs.
-- UCZone API has no documented IsRiver/IsWater helper, so we use fixed hubs.
-- Hub coordinates copied from scripts/roshan_position_helper.lua (river pit centers).

local function createMenuGroup()
    local function tryFindBuiltInCourierGroup()
        if not Menu or not Menu.Find then return nil end

        local directCandidates = {
            { "Miscellaneous", "In Game", "Courier", "Courier", "Courier" },
            { "Miscellaneous", "In Game", "Courier", "Main", "Courier" },
            { "Miscellaneous", "In Game", "Courier", "Main", "Main" },
            { "Miscellaneous", "In Game", "Courier", "Курьер", "Курьер" },
            { "Miscellaneous", "In Game", "Courier", "Основное", "Курьер" },
        }
        for i = 1, #directCandidates do
            local p = directCandidates[i]
            local ok, group = pcall(Menu.Find, p[1], p[2], p[3], p[4], p[5])
            if ok and group and group.Switch then
                return group
            end
        end

        local ok, courierTab = pcall(Menu.Find, "Miscellaneous", "In Game", "Courier")
        if not ok or not courierTab then return nil end
        if courierTab.Switch then return courierTab end
        if not courierTab.Find then return nil end

        local thirdCandidates = { "Courier", "Курьер", "Main", "Основное" }
        local groupCandidates = { "Courier", "Курьер", "Main", "Settings", "Настройки" }

        for i = 1, #thirdCandidates do
            local okThird, third = pcall(courierTab.Find, courierTab, thirdCandidates[i])
            if okThird and third then
                if third.Switch then
                    return third
                end
                if third.Find then
                    for j = 1, #groupCandidates do
                        local okGroup, group = pcall(third.Find, third, groupCandidates[j])
                        if okGroup and group and group.Switch then
                            return group
                        end
                    end
                end
            end
        end

        return nil
    end

    local builtInGroup = tryFindBuiltInCourierGroup()
    if builtInGroup then
        return builtInGroup
    end

    -- Fallback for environments where the built-in courier tab path differs.
    local courierNode = nil
    if Menu and Menu.Find then
        local ok, result = pcall(Menu.Find, "Miscellaneous", "In Game", "Courier")
        if ok then courierNode = result end
    end

    if courierNode and courierNode.Create then
        local riverTab = nil
        if courierNode.Find then
            local okFind, found = pcall(courierNode.Find, courierNode, "River Route")
            if okFind then riverTab = found end
        end
        if not riverTab then
            local okCreate, created = pcall(courierNode.Create, courierNode, "River Route")
            if okCreate then riverTab = created end
        end
        if riverTab and riverTab.Create then
            local okGroup, group = pcall(riverTab.Create, riverTab, "Courier River Route")
            if okGroup and group and group.Switch then
                return group
            end
        end
    end

    local root = Menu.Create("Scripts", "User Scripts", "Courier River Route")
    return root:Create("Settings")
end

local MENU_SETTINGS = createMenuGroup()
local ENABLE_SWITCH = MENU_SETTINGS:Switch("River Route", true)
local ADVANCED_GROUP = (ENABLE_SWITCH and ENABLE_SWITCH.Gear and ENABLE_SWITCH:Gear("River Route")) or MENU_SETTINGS
local WORK_FROM_MIN = ADVANCED_GROUP:Slider("Работать с (мин)", 0, 99, 0, "%d")
local WORK_UNTIL_MIN = ADVANCED_GROUP:Slider("Работать до (мин)", 0, 99, 99, "%d")
local DEBUG_LOG_SWITCH = ADVANCED_GROUP:Switch("Debug Log", false)
local VERBOSE_LOG_SWITCH = ADVANCED_GROUP:Switch("Verbose Log", false)
local SHOW_STATUS_SWITCH = ADVANCED_GROUP:Switch("Show Status", false)
local DEBUG_DRAW_SWITCH = ADVANCED_GROUP:Switch("Debug Draw", false)
local PREPARE_ORDERS_ONLY_SWITCH = ADVANCED_GROUP:Switch("PrepareOrders Only", false)
local SAFE_ROUTE_CHECK_SWITCH = ADVANCED_GROUP:Switch("Safe Route Check", true)
local STRICT_TEAM_ROUTE_SWITCH = ADVANCED_GROUP:Switch("Strict Team Route", true)
local SIDE_LANE_ONLY_SWITCH = ADVANCED_GROUP:Switch("SideLane Only", true)
local AGGRESSIVE_PROFILE_SWITCH = ADVANCED_GROUP:Switch("Aggressive Profile", false)
local AUTO_BURST_SWITCH = ADVANCED_GROUP:Switch("Auto Burst", true)
local AUTO_SHIELD_SWITCH = ADVANCED_GROUP:Switch("Auto Shield", true)
local FAIL_DISABLE_SLIDER = ADVANCED_GROUP:Slider("Auto-disable Route Fails", 0, 5, 2, "%d")

local UI = {
    Enable = ENABLE_SWITCH,
    WorkFromMin = WORK_FROM_MIN,
    WorkUntilMin = WORK_UNTIL_MIN,
    DebugLog = DEBUG_LOG_SWITCH,
    VerboseLog = VERBOSE_LOG_SWITCH,
    ShowStatus = SHOW_STATUS_SWITCH,
    DebugDraw = DEBUG_DRAW_SWITCH,
    PrepareOrdersOnly = PREPARE_ORDERS_ONLY_SWITCH,
    SafeRouteCheck = SAFE_ROUTE_CHECK_SWITCH,
    StrictTeamRoute = STRICT_TEAM_ROUTE_SWITCH,
    SideLaneOnly = SIDE_LANE_ONLY_SWITCH,
    AggressiveProfile = AGGRESSIVE_PROFILE_SWITCH,
    AutoBurst = AUTO_BURST_SWITCH,
    AutoShield = AUTO_SHIELD_SWITCH,
    AutoDisableRouteFails = FAIL_DISABLE_SLIDER,
}
if ENABLE_SWITCH and ENABLE_SWITCH.ToolTip then
    pcall(ENABLE_SWITCH.ToolTip, ENABLE_SWITCH, "Courier river-route heuristic for item delivery.")
end
if WORK_UNTIL_MIN and WORK_UNTIL_MIN.ToolTip then
    pcall(WORK_UNTIL_MIN.ToolTip, WORK_UNTIL_MIN, "Auto route works only until this in-game minute (0:00 based).")
end
if WORK_FROM_MIN and WORK_FROM_MIN.ToolTip then
    pcall(WORK_FROM_MIN.ToolTip, WORK_FROM_MIN, "Auto route starts working from this in-game minute (0:00 based).")
end

local RIVER_HUBS = {
    -- Bottom lane river stream ("Wandering Whirl"), from user-provided coordinates.
    bot_stream_start = Vector(-4476.048, -7553.44, 262),
    bot_stream_end = Vector(4725.504, -7793.45, 8.000488),

    -- Top lane river stream (Dire side). Inferred by map symmetry from bot stream.
    top_stream_start = Vector(4476.048, 7553.44, 262),
    top_stream_end = Vector(-4725.504, 7793.45, 8.000488),
}

-- Exact safe routes (user-provided) to avoid neutral camps.
local RIVER_ROUTE_CHAINS = {
    bot_safe = {
        name = "bot_safe",
        team = "radiant",
        points = {
            Vector(-4270.756, -7550.622, 262),
            Vector(-1573.83, -7836.8164, 136.00049),
            Vector(-637.0481, -8264.06, 136.00049),
            Vector(2713.4849, -7671.9453, 8.000488),
            Vector(4598.5317, -7626.057, 8.000488),
        }
    },
    top_safe = {
        name = "top_safe",
        team = "dire",
        points = {
            Vector(3826.729, 7283.053, 262.94336),
            Vector(2115.2205, 7141.1875, 136.00049),
            Vector(214.29291, 7428.9077, 136.00049),
            Vector(-1262.4188, 7963.4795, 134),
            Vector(-3598.7456, 8248.121, 8.000488),
            Vector(-4742.2163, 7557.3184, 8.000488),
        }
    }
}

local DELIVERY_ABILITY_WHITELIST = {
    courier_take_stash_and_transfer_items = true,
    courier_transfer_items = true,
    courier_take_stash_items = true,
    courier_autodeliver = true,
}

local STATE_VALUES = {
    AT_BASE = 1,
    MOVING = 2,
    DELIVERING_ITEMS = 3,
    DEAD = 5,
}

local CAST_ORDER_SET = {}
local ORDER_ISSUER_SCRIPT = nil
local ORDER_ISSUER_PASSED_UNIT_ONLY = nil
local UNIT_ORDER_CAST_TARGET = nil
local UNIT_ORDER_CAST_NO_TARGET = nil
local UNIT_ORDER_MOVE_TO_POSITION = nil
local DEBUG_FONT = nil
local DEBUG_PREFIX = "[CourierRiverMVP] "
local ROUTE_BLACKLIST_SEC = 180
local STUCK_MOVE_EPS = 70
local STUCK_TIMEOUT_SEC = 2.8
local DANGER_HERO_RADIUS = 1150
local DANGER_TOWER_RADIUS = 950
local EARLY_HANDOFF_DIST = 950
local DAMAGE_PANIC_THRESHOLD = 25
local BURST_ROUTE_MIN_DIST = 3200

local state = {
    active = false,
    pendingTriggerUntil = 0,
    pendingTriggerAt = 0,
    manualLockUntil = 0,
    suppressOwnOrdersUntil = 0,
    lastScriptOrderAt = 0,
    routeHubName = nil,
    routeHubPos = nil,
    routePathName = nil,
    routePoints = nil,
    routePointIndex = nil,
    routeStartedAt = nil,
    routeTimeoutAt = nil,
    routePlannedDistance = nil,
    waitingForDeliveryStart = false,
    lastCourierState = nil,
    lastCourierIndex = nil,
    lastReason = nil,
    lastRouteRatio = nil,
    lastTriggerAbility = nil,
    lastTriggerAbilityRef = nil,
    timeLimitBlocked = false,
    lastDangerScanAt = 0,
    lastCourierProgressPos = nil,
    lastCourierProgressAt = 0,
    lastCourierHealth = nil,
    lastBurstAt = 0,
    lastShieldAt = 0,
    routesStarted = 0,
    routesSucceeded = 0,
    routesFailed = 0,
    routeFailCounts = {},
    routeBlacklistedUntil = {},
}

local function nowSec()
    return os.clock()
end

local function safeWidgetGet(widget, fallback)
    if not widget then return fallback end
    if widget.Get then
        local ok, value = pcall(widget.Get, widget)
        if ok and value ~= nil then
            return value
        end
    end
    return fallback
end

local function logDebug(msg)
    if not safeWidgetGet(UI.DebugLog, true) then return end
    if Log and Log.Write then
        Log.Write(DEBUG_PREFIX .. tostring(msg))
    end
end

local function logVerbose(msg)
    if not safeWidgetGet(UI.VerboseLog, false) then return end
    if Log and Log.Write then
        Log.Write(DEBUG_PREFIX .. tostring(msg))
    end
end

local function getObjectMethod(obj, name)
    if not obj or type(name) ~= "string" then return nil end

    -- Some UCZone objects are userdata and may throw on direct indexing.
    local okIndex, fn = pcall(function()
        return obj[name]
    end)
    if okIndex and type(fn) == "function" then
        return fn
    end

    local okMeta, mt = pcall(getmetatable, obj)
    if okMeta and type(mt) == "table" then
        local idx = mt.__index
        if type(idx) == "table" then
            fn = idx[name]
            if type(fn) == "function" then
                return fn
            end
        elseif type(idx) == "function" then
            local okIdxFn, v = pcall(idx, obj, name)
            if okIdxFn and type(v) == "function" then
                return v
            end
        end
    end

    return nil
end

local function tryMethod0(obj, name)
    if not obj or type(name) ~= "string" then return nil end
    local fn = getObjectMethod(obj, name)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, obj)
    if ok then return a end
    return nil
end

local function tryMethod1(obj, name, p1)
    if not obj or type(name) ~= "string" then return nil end
    local fn = getObjectMethod(obj, name)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, obj, p1)
    if ok then return a end
    return nil
end

local function tryMethodN(obj, name, ...)
    if not obj or type(name) ~= "string" then return false end
    local fn = getObjectMethod(obj, name)
    if type(fn) ~= "function" then return false end
    local ok = pcall(fn, obj, ...)
    return ok
end

local function tryStatic(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

local function tryStaticN(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok = pcall(fn, ...)
    return ok
end

local function getMatchElapsedSec()
    local gameTime = 0
    local startTime = 0

    if GameRules and GameRules.GetGameTime then
        gameTime = tryStatic(GameRules.GetGameTime) or 0
    end
    if GameRules and GameRules.GetGameStartTime then
        startTime = tryStatic(GameRules.GetGameStartTime) or 0
    else
        startTime = 0
    end

    local elapsed = (gameTime or 0) - (startTime or 0)
    if not (GameRules and GameRules.GetGameStartTime) then
        elapsed = gameTime or 0
    end
    if type(elapsed) ~= "number" then
        elapsed = 0
    end
    if elapsed < 0 then
        elapsed = 0
    end
    return elapsed
end

local function isWithinWorkTimeLimit()
    local fromMin = safeWidgetGet(UI.WorkFromMin, 0)
    local limitMin = safeWidgetGet(UI.WorkUntilMin, 99)
    if type(fromMin) ~= "number" then
        fromMin = tonumber(fromMin) or 0
    end
    if type(limitMin) ~= "number" then
        limitMin = tonumber(limitMin) or 99
    end
    fromMin = math.max(0, math.min(99, fromMin))
    limitMin = math.max(0, math.min(99, limitMin))
    if fromMin > limitMin then
        fromMin = limitMin
    end

    local elapsedSec = getMatchElapsedSec()
    local fromSec = fromMin * 60
    local limitSec = limitMin * 60
    return elapsedSec >= fromSec and elapsedSec <= limitSec, elapsedSec, limitSec, fromSec
end

local function syncTimeLimitBlockedFlag(isWithin, elapsedSec, limitSec, fromSec)
    if isWithin then
        state.timeLimitBlocked = false
        return false
    end

    if not state.timeLimitBlocked then
        state.timeLimitBlocked = true
        logDebug(string.format(
            "outside work window: %.1f min (window=%d..%d min)",
            (elapsedSec or 0) / 60,
            math.floor(((fromSec or 0) / 60) + 0.5),
            math.floor(((limitSec or 0) / 60) + 0.5)
        ))
    end

    return true
end

local function vec2(x, y)
    if Vec2 then
        return Vec2(x, y)
    end
    return { x = x, y = y }
end

local function cloneVec(v)
    if not v then return nil end
    return Vector(v.x or 0, v.y or 0, v.z or 0)
end

local function groundVec(v)
    local p = cloneVec(v)
    if not p then return nil end
    if World and World.GetGroundZ then
        local z = tryStatic(World.GetGroundZ, p)
        if type(z) == "number" then
            p.z = z
        end
    end
    return p
end

local function dist2d(a, b)
    if not a or not b then return math.huge end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

local function resolveEnumValue(enumTable, names, fallback)
    if enumTable then
        for i = 1, #names do
            local v = enumTable[names[i]]
            if v ~= nil then
                return v
            end
        end
    end
    return fallback
end

local function initEnumCompat()
    local eCourier = Enum and (Enum.ECourierState or Enum.CourierState) or nil
    STATE_VALUES.MOVING = resolveEnumValue(eCourier, {
        "MOVING",
        "COURIER_STATE_MOVING",
        "DOTA_COURIER_STATE_MOVING",
    }, STATE_VALUES.MOVING)
    STATE_VALUES.DELIVERING_ITEMS = resolveEnumValue(eCourier, {
        "DELIVERING_ITEMS",
        "COURIER_STATE_DELIVERING_ITEMS",
        "DOTA_COURIER_STATE_DELIVERING_ITEMS",
    }, STATE_VALUES.DELIVERING_ITEMS)
    STATE_VALUES.DEAD = resolveEnumValue(eCourier, {
        "DEAD",
        "COURIER_STATE_DEAD",
        "DOTA_COURIER_STATE_DEAD",
    }, STATE_VALUES.DEAD)

    local unitOrder = Enum and Enum.UnitOrder or nil
    local castNames = {
        "CAST_NO_TARGET",
        "CAST_TARGET",
        "CAST_POSITION",
        "CAST_TARGET_POSITION",
        "DOTA_UNIT_ORDER_CAST_NO_TARGET",
        "DOTA_UNIT_ORDER_CAST_TARGET",
        "DOTA_UNIT_ORDER_CAST_POSITION",
        "DOTA_UNIT_ORDER_CAST_TARGET_POSITION",
    }
    for i = 1, #castNames do
        local name = castNames[i]
        if unitOrder and unitOrder[name] ~= nil then
            CAST_ORDER_SET[unitOrder[name]] = true
        end
    end

    local issuerEnum = Enum and Enum.PlayerOrderIssuer or nil
    ORDER_ISSUER_SCRIPT = resolveEnumValue(issuerEnum, {
        "PLAYER_ORDER_ISSUER_SCRIPT",
        "DOTA_ORDER_ISSUER_SCRIPT",
    }, ORDER_ISSUER_SCRIPT)
    ORDER_ISSUER_PASSED_UNIT_ONLY = resolveEnumValue(issuerEnum, {
        "PLAYER_ORDER_ISSUER_PASSED_UNIT_ONLY",
        "DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY",
    }, ORDER_ISSUER_PASSED_UNIT_ONLY)

    UNIT_ORDER_CAST_TARGET = resolveEnumValue(unitOrder, {
        "CAST_TARGET",
        "DOTA_UNIT_ORDER_CAST_TARGET",
    }, UNIT_ORDER_CAST_TARGET)
    UNIT_ORDER_CAST_NO_TARGET = resolveEnumValue(unitOrder, {
        "CAST_NO_TARGET",
        "DOTA_UNIT_ORDER_CAST_NO_TARGET",
    }, UNIT_ORDER_CAST_NO_TARGET)
    UNIT_ORDER_MOVE_TO_POSITION = resolveEnumValue(unitOrder, {
        "MOVE_TO_POSITION",
        "DOTA_UNIT_ORDER_MOVE_TO_POSITION",
    }, UNIT_ORDER_MOVE_TO_POSITION)
end

local function ensureDebugFont()
    if DEBUG_FONT then return DEBUG_FONT end
    if not Render then return nil end

    local antialias = Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or nil
    local ok, font

    if Render.LoadFont then
        ok, font = pcall(Render.LoadFont, "Tahoma", 13, antialias or 0)
        if ok and font then
            DEBUG_FONT = font
            return DEBUG_FONT
        end

        ok, font = pcall(Render.LoadFont, "Tahoma", 13, 500)
        if ok and font then
            DEBUG_FONT = font
            return DEBUG_FONT
        end
    end

    if Render.CreateFont then
        ok, font = pcall(Render.CreateFont, "Tahoma", 13, Enum and Enum.FontWeight and Enum.FontWeight.NORMAL or 400)
        if ok and font then
            DEBUG_FONT = font
            return DEBUG_FONT
        end
    end

    return nil
end

local function renderWorldToScreen(pos)
    if not Render or not Render.WorldToScreen or not pos then return nil, false end
    local ok, a, b, c = pcall(Render.WorldToScreen, pos)
    if not ok then return nil, false end

    if type(a) == "table" and a.x ~= nil and a.y ~= nil then
        if type(b) == "boolean" then
            return vec2(a.x, a.y), b
        end
        if a.visible ~= nil then
            return vec2(a.x, a.y), a.visible == true
        end
        return vec2(a.x, a.y), true
    end

    if type(a) == "number" and type(b) == "number" then
        return vec2(a, b), c == true
    end

    return nil, false
end

local function renderLine(p1, p2, color, thickness)
    if not Render or not Render.Line or not p1 or not p2 then return end
    pcall(Render.Line, p1, p2, color, thickness or 1)
end

local function renderText(font, size, text, pos, color)
    if not Render or not Render.Text or not font or not pos then return end
    local ok = pcall(Render.Text, font, size, text, pos, color)
    if ok then return end
    pcall(Render.Text, font, pos, text, color)
end

local function getEntityIndex(ent)
    if not ent then return nil end
    local idx = Entity and Entity.GetIndex and tryStatic(Entity.GetIndex, ent) or nil
    if idx ~= nil then return idx end
    return tryMethod0(ent, "GetIndex")
end

local function sameEntity(a, b)
    if not a or not b then return false end
    local ai = getEntityIndex(a)
    local bi = getEntityIndex(b)
    if ai ~= nil and bi ~= nil then
        return ai == bi
    end
    return a == b
end

local function entityIsAlive(ent)
    if not ent then return false end
    local alive = Entity and Entity.IsAlive and tryStatic(Entity.IsAlive, ent)
    if type(alive) == "boolean" then return alive end
    alive = tryMethod0(ent, "IsAlive")
    return alive == true
end

local function getAbsOrigin(ent)
    if not ent then return nil end
    local pos = Entity and Entity.GetAbsOrigin and tryStatic(Entity.GetAbsOrigin, ent) or nil
    if pos ~= nil then return pos end
    return tryMethod0(ent, "GetAbsOrigin")
end

local function getEntityTeamNum(ent)
    if not ent then return nil end
    local v = Entity and Entity.GetTeamNum and tryStatic(Entity.GetTeamNum, ent) or nil
    if v ~= nil then return v end
    return tryMethod0(ent, "GetTeamNum")
end

local function entityIsDormant(ent)
    if not ent then return false end
    local v = Entity and Entity.IsDormant and tryStatic(Entity.IsDormant, ent) or nil
    if type(v) == "boolean" then return v end
    v = tryMethod0(ent, "IsDormant")
    return v == true
end

local function entityIsHero(ent)
    if not ent then return false end
    local v = Entity and Entity.IsHero and tryStatic(Entity.IsHero, ent) or nil
    if type(v) == "boolean" then return v end
    v = tryMethod0(ent, "IsHero")
    return v == true
end

local function getEntityHealth(ent)
    if not ent then return nil end
    local v = Entity and Entity.GetHealth and tryStatic(Entity.GetHealth, ent) or nil
    if type(v) == "number" then return v end
    v = tryMethod0(ent, "GetHealth")
    if type(v) == "number" then return v end
    return nil
end

local function getEntityMaxHealth(ent)
    if not ent then return nil end
    local v = Entity and Entity.GetMaxHealth and tryStatic(Entity.GetMaxHealth, ent) or nil
    if type(v) == "number" then return v end
    v = tryMethod0(ent, "GetMaxHealth")
    if type(v) == "number" then return v end
    return nil
end

local function getHeroPlayerID(hero)
    if not hero then return nil end
    local id = Hero and Hero.GetPlayerID and tryStatic(Hero.GetPlayerID, hero) or nil
    if id ~= nil then return id end
    return tryMethod0(hero, "GetPlayerID")
end

local function npcIsControllableByPlayer(npc, playerID)
    if not npc or playerID == nil then return false end
    local v = NPC and NPC.IsControllableByPlayer and tryStatic(NPC.IsControllableByPlayer, npc, playerID) or nil
    if type(v) == "boolean" then return v end
    v = tryMethod1(npc, "IsControllableByPlayer", playerID)
    return v == true
end

local function npcIsCourier(npc)
    if not npc then return false end
    local v = NPC and NPC.IsCourier and tryStatic(NPC.IsCourier, npc)
    if type(v) == "boolean" then return v end
    v = tryMethod0(npc, "IsCourier")
    return v == true
end

local function getCourierState(courier)
    if not courier then return nil end
    local v = Courier and Courier.GetState and tryStatic(Courier.GetState, courier) or nil
    if v ~= nil then return v end
    return tryMethod0(courier, "GetState")
end

local function getMoveSpeed(npc)
    if not npc then return nil end
    local v = NPC and NPC.GetMoveSpeed and tryStatic(NPC.GetMoveSpeed, npc) or nil
    if type(v) == "number" then return v end
    v = tryMethod0(npc, "GetMoveSpeed")
    if type(v) == "number" then return v end
    return nil
end

local function npcIsTower(npc)
    if not npc then return false end
    local v = NPC and NPC.IsTower and tryStatic(NPC.IsTower, npc) or nil
    if type(v) == "boolean" then return v end
    v = tryMethod0(npc, "IsTower")
    return v == true
end

local function npcIsBuilding(npc)
    if not npc then return false end
    local v = NPC and NPC.IsBuilding and tryStatic(NPC.IsBuilding, npc) or nil
    if type(v) == "boolean" then return v end
    v = tryMethod0(npc, "IsBuilding")
    return v == true
end

local function npcIsVisible(npc)
    if not npc then return false end
    local v = NPC and NPC.IsVisible and tryStatic(NPC.IsVisible, npc) or nil
    if type(v) == "boolean" then return v end
    v = tryMethod0(npc, "IsVisible")
    return v == true
end

local function getUnitName(npc)
    if not npc then return nil end
    local v = NPC and NPC.GetUnitName and tryStatic(NPC.GetUnitName, npc) or nil
    if type(v) == "string" then return v end
    v = tryMethod0(npc, "GetUnitName")
    if type(v) == "string" then return v end
    return nil
end

local function getAllHeroes()
    if Heroes and Heroes.GetAll then
        local list = tryStatic(Heroes.GetAll)
        if type(list) == "table" then return list end
    end
    return {}
end

local function getAllNPCs()
    if NPCs and NPCs.GetAll then
        local list = tryStatic(NPCs.GetAll)
        if type(list) == "table" then return list end
    end
    return {}
end

local function getAbilityName(ability)
    if not ability then return nil end
    local v = Ability and Ability.GetName and tryStatic(Ability.GetName, ability) or nil
    if type(v) == "string" then return v end
    v = tryMethod0(ability, "GetName")
    if type(v) == "string" then return v end
    return nil
end

local function getAbilityOwner(ability)
    if not ability then return nil end
    local v = Ability and Ability.GetOwner and tryStatic(Ability.GetOwner, ability) or nil
    if v ~= nil then return v end
    return tryMethod0(ability, "GetOwner")
end

local function getAbilityByName(npc, abilityName)
    if not npc or not abilityName then return nil end
    local a = NPC and NPC.GetAbilityByName and tryStatic(NPC.GetAbilityByName, npc, abilityName) or nil
    if a ~= nil then return a end
    return tryMethod1(npc, "GetAbilityByName", abilityName)
end

local function abilityIsReady(ability)
    if not ability then return false end
    local v = Ability and Ability.IsReady and tryStatic(Ability.IsReady, ability) or nil
    if type(v) == "boolean" then return v end
    v = tryMethod0(ability, "IsReady")
    return v == true
end

local function abilityIsActivated(ability)
    if not ability then return true end
    local v = Ability and Ability.IsActivated and tryStatic(Ability.IsActivated, ability) or nil
    if type(v) == "boolean" then return v end
    v = tryMethod0(ability, "IsActivated")
    if type(v) == "boolean" then return v end
    return true
end

local function castAbilityNoTarget(npc, ability)
    if not npc or not ability then return false end
    if tryMethodN(npc, "CastAbility", ability) then
        return true
    end
    if NPC and NPC.CastAbility and tryStaticN(NPC.CastAbility, npc, ability) then
        return true
    end
    return false
end

local function castAbilityTarget(npc, ability, target)
    if not npc or not ability or not target then return false end
    if tryMethodN(npc, "CastAbilityTarget", ability, target) then
        return true
    end
    if NPC and NPC.CastAbilityTarget and tryStaticN(NPC.CastAbilityTarget, npc, ability, target) then
        return true
    end
    return false
end

local function npcMoveTo(npc, pos, queue, showEffects)
    if not npc or not pos then return false end
    if tryMethodN(npc, "MoveTo", pos, queue, showEffects) then
        return true
    end
    if NPC and NPC.MoveTo and tryStaticN(NPC.MoveTo, npc, pos, queue, showEffects) then
        return true
    end
    return false
end

local function isCourierDeadState(stateValue)
    if stateValue == nil then return false end
    return stateValue == STATE_VALUES.DEAD
end

local function isCourierRoutingState(stateValue)
    if stateValue == nil then return false end
    return stateValue == STATE_VALUES.AT_BASE
        or stateValue == STATE_VALUES.MOVING
        or stateValue == STATE_VALUES.DELIVERING_ITEMS
end

local function getAllCouriers()
    if Couriers and Couriers.GetAll then
        local list = tryStatic(Couriers.GetAll)
        if type(list) == "table" then return list end
    end

    local list = {}
    if Couriers and Couriers.Count and Couriers.Get then
        local count = tryStatic(Couriers.Count) or 0
        for i = 1, count do
            local c = tryStatic(Couriers.Get, i)
            if c then
                list[#list + 1] = c
            end
        end
    end
    return list
end

local function getLocalHero()
    if Heroes and Heroes.GetLocal then
        return tryStatic(Heroes.GetLocal)
    end
    return nil
end

local function getLocalPlayer()
    if Players and Players.GetLocal then
        return tryStatic(Players.GetLocal)
    end
    return nil
end

local playerPrepareUnitOrdersPositional
local issueAbilityNoTargetPrepareOrder

local function findLocalCourier(localHero)
    if not localHero then return nil, nil end
    local playerID = getHeroPlayerID(localHero)
    if playerID == nil then return nil, nil end

    local couriers = getAllCouriers()
    for i = 1, #couriers do
        local courier = couriers[i]
        if courier and npcIsControllableByPlayer(courier, playerID) then
            return courier, playerID
        end
    end
    return nil, playerID
end

local function clearRouteOnly(reason)
    state.active = false
    state.routeHubName = nil
    state.routeHubPos = nil
    state.routePathName = nil
    state.routePoints = nil
    state.routePointIndex = nil
    state.routeStartedAt = nil
    state.routeTimeoutAt = nil
    state.routePlannedDistance = nil
    state.lastRouteRatio = nil
    state.lastCourierProgressPos = nil
    state.lastCourierProgressAt = 0
    state.lastCourierHealth = nil
    state.lastReason = reason or state.lastReason
end

local function resetRouteRuntimeTrackers()
    state.lastDangerScanAt = 0
    state.lastCourierProgressPos = nil
    state.lastCourierProgressAt = 0
    state.lastCourierHealth = nil
    state.lastBurstAt = 0
    state.lastShieldAt = 0
end

local function resetRuntimeState(reason)
    state.active = false
    state.pendingTriggerUntil = 0
    state.pendingTriggerAt = 0
    state.manualLockUntil = 0
    state.suppressOwnOrdersUntil = 0
    state.lastScriptOrderAt = 0
    state.routeHubName = nil
    state.routeHubPos = nil
    state.routePathName = nil
    state.routePoints = nil
    state.routePointIndex = nil
    state.routeStartedAt = nil
    state.routeTimeoutAt = nil
    state.routePlannedDistance = nil
    state.waitingForDeliveryStart = false
    state.lastCourierState = nil
    state.lastCourierIndex = nil
    state.lastReason = reason or state.lastReason
    state.lastRouteRatio = nil
    state.lastTriggerAbility = nil
    state.lastTriggerAbilityRef = nil
    state.timeLimitBlocked = false
    state.routesStarted = 0
    state.routesSucceeded = 0
    state.routesFailed = 0
    state.routeFailCounts = {}
    state.routeBlacklistedUntil = {}
    resetRouteRuntimeTrackers()
end

local function canIssueScriptOrder(t)
    local cd = safeWidgetGet(UI.OrderCooldownSec, 0.20)
    return (t - (state.lastScriptOrderAt or 0)) >= cd
end

local function markScriptOrderIssued(t)
    state.suppressOwnOrdersUntil = t + 0.15
    state.lastScriptOrderAt = t
end

local function getTeamKind(teamNum)
    if teamNum == nil then return nil end
    -- Dota defaults: Radiant=2, Dire=3
    if teamNum == 2 then return "radiant" end
    if teamNum == 3 then return "dire" end
    local s = tostring(teamNum):lower()
    if s:find("radiant", 1, true) then return "radiant" end
    if s:find("dire", 1, true) then return "dire" end
    return nil
end

local function isHeroInPreferredSideLaneZone(heroPos, teamKind)
    if not safeWidgetGet(UI.SideLaneOnly, true) then return true end
    if not heroPos or not teamKind then return true end
    if teamKind == "radiant" then
        return (heroPos.y or 0) <= -5200
    end
    if teamKind == "dire" then
        return (heroPos.y or 0) >= 5200
    end
    return true
end

local function isRouteBlacklisted(routeKey, t)
    if not routeKey then return false end
    local untilAt = state.routeBlacklistedUntil and state.routeBlacklistedUntil[routeKey] or nil
    return type(untilAt) == "number" and untilAt > (t or nowSec())
end

local function clearExpiredRouteBlacklists(t)
    if type(state.routeBlacklistedUntil) ~= "table" then
        state.routeBlacklistedUntil = {}
        return
    end
    local now = t or nowSec()
    for routeKey, untilAt in pairs(state.routeBlacklistedUntil) do
        if type(untilAt) ~= "number" or untilAt <= now then
            state.routeBlacklistedUntil[routeKey] = nil
        end
    end
end

local function noteRouteStart(routeName)
    state.routesStarted = (state.routesStarted or 0) + 1
    state.lastCourierProgressAt = nowSec()
    state.lastCourierProgressPos = nil
    if routeName and type(state.routeFailCounts) ~= "table" then
        state.routeFailCounts = {}
    end
end

local function noteRouteSuccess(routeName)
    state.routesSucceeded = (state.routesSucceeded or 0) + 1
    if routeName then
        state.routeFailCounts = state.routeFailCounts or {}
        state.routeBlacklistedUntil = state.routeBlacklistedUntil or {}
        state.routeFailCounts[routeName] = 0
        state.routeBlacklistedUntil[routeName] = nil
    end
end

local function noteRouteFailure(routeName, reason)
    state.routesFailed = (state.routesFailed or 0) + 1
    if not routeName then return end

    local threshold = safeWidgetGet(UI.AutoDisableRouteFails, 2) or 0
    if type(threshold) ~= "number" then
        threshold = tonumber(threshold) or 0
    end
    threshold = math.max(0, math.floor(threshold + 0.0001))
    if threshold <= 0 then return end

    state.routeFailCounts = state.routeFailCounts or {}
    state.routeBlacklistedUntil = state.routeBlacklistedUntil or {}
    local count = (state.routeFailCounts[routeName] or 0) + 1
    state.routeFailCounts[routeName] = count

    if count >= threshold then
        local untilAt = nowSec() + ROUTE_BLACKLIST_SEC
        state.routeBlacklistedUntil[routeName] = untilAt
        state.routeFailCounts[routeName] = 0
        logDebug(string.format(
            "route %s blacklisted for %.0fs after failures (%s)",
            tostring(routeName),
            ROUTE_BLACKLIST_SEC,
            tostring(reason or "unknown")
        ))
    end
end

local function pointIsNearAny(points, pos, radius)
    if type(points) ~= "table" or not pos then return false end
    for i = 1, #points do
        if dist2d(points[i], pos) <= radius then
            return true
        end
    end
    return false
end

local function buildDangerCheckPoints(routePoints, courierPos, currentWp, nextWp, heroPos)
    local pts = {}
    if courierPos then pts[#pts + 1] = courierPos end
    if currentWp then pts[#pts + 1] = currentWp end
    if nextWp then pts[#pts + 1] = nextWp end
    if heroPos then pts[#pts + 1] = heroPos end
    if type(routePoints) == "table" then
        for i = 1, #routePoints do
            pts[#pts + 1] = routePoints[i]
        end
    end
    return pts
end

local function detectRouteDanger(localHero, checkPoints)
    if not safeWidgetGet(UI.SafeRouteCheck, true) then
        return false, nil
    end
    if type(checkPoints) ~= "table" or #checkPoints == 0 or not localHero then
        return false, nil
    end

    local myTeam = getEntityTeamNum(localHero)
    if myTeam == nil then
        return false, nil
    end

    for _, enemy in ipairs(getAllHeroes()) do
        if enemy
            and not sameEntity(enemy, localHero)
            and entityIsAlive(enemy)
            and not entityIsDormant(enemy)
            and getEntityTeamNum(enemy) ~= myTeam
            and not npcIsCourier(enemy)
        then
            local pos = getAbsOrigin(enemy)
            if pos and pointIsNearAny(checkPoints, pos, DANGER_HERO_RADIUS) then
                return true, "enemy_hero"
            end
        end
    end

    for _, npc in ipairs(getAllNPCs()) do
        if npc
            and entityIsAlive(npc)
            and not entityIsDormant(npc)
            and getEntityTeamNum(npc) ~= myTeam
        then
            local isTower = npcIsTower(npc)
            if not isTower and npcIsBuilding(npc) then
                local name = getUnitName(npc) or ""
                isTower = name:find("tower", 1, true) ~= nil
            end
            if isTower then
                local pos = getAbsOrigin(npc)
                if pos and pointIsNearAny(checkPoints, pos, DANGER_TOWER_RADIUS) then
                    return true, "enemy_tower"
                end
            end
        end
    end

    return false, nil
end

local function issueMoveToHub(courier, hubPos)
    local t = nowSec()
    if not canIssueScriptOrder(t) then
        return false, "order_cooldown"
    end
    markScriptOrderIssued(t)
    local ok = false
    if safeWidgetGet(UI.PrepareOrdersOnly, false) and UNIT_ORDER_MOVE_TO_POSITION then
        local player = getLocalPlayer()
        ok = playerPrepareUnitOrdersPositional(
            player,
            UNIT_ORDER_MOVE_TO_POSITION,
            nil,
            hubPos,
            nil,
            ORDER_ISSUER_PASSED_UNIT_ONLY,
            courier,
            false,
            "courier_river_mvp_move"
        )
    end
    if not ok then
        ok = npcMoveTo(courier, hubPos, false, true)
    end
    if not ok then
        return false, "move_failed"
    end
    return true
end

playerPrepareUnitOrdersPositional = function(player, order, target, position, ability, issuer, unit, queue, identifier)
    if not player or not order or not unit then return false end
    local pos = position or Vector(0, 0, 0)
    local ordIssuer = issuer or ORDER_ISSUER_PASSED_UNIT_ONLY or ORDER_ISSUER_SCRIPT
    local q = queue == true

    if Player and Player.PrepareUnitOrders and tryStaticN(
        Player.PrepareUnitOrders,
        player,
        order,
        target,
        pos,
        ability,
        ordIssuer,
        unit,
        q,
        false,
        false,
        false,
        identifier or "courier_river_mvp"
    ) then
        return true
    end

    return false
end

issueAbilityNoTargetPrepareOrder = function(npc, ability, identifier)
    if not npc or not ability then return false end
    if not UNIT_ORDER_CAST_NO_TARGET then return false end
    local player = getLocalPlayer()
    if not player then return false end
    return playerPrepareUnitOrdersPositional(
        player,
        UNIT_ORDER_CAST_NO_TARGET,
        nil,
        Vector(0, 0, 0),
        ability,
        ORDER_ISSUER_PASSED_UNIT_ONLY,
        npc,
        false,
        identifier or "courier_river_mvp_cast_notarget"
    )
end

local function tryUseCourierUtilityAbility(courier, abilityName, reasonTag)
    if not courier or not abilityName then return false, "missing_context" end
    local t = nowSec()
    if not canIssueScriptOrder(t) then
        return false, "order_cooldown"
    end

    local ability = getAbilityByName(courier, abilityName)
    if not ability then
        return false, "ability_missing"
    end
    if not abilityIsActivated(ability) then
        return false, "ability_inactive"
    end
    if not abilityIsReady(ability) then
        return false, "ability_not_ready"
    end

    markScriptOrderIssued(t)
    if castAbilityNoTarget(courier, ability)
        or (safeWidgetGet(UI.PrepareOrdersOnly, false)
            and issueAbilityNoTargetPrepareOrder(courier, ability, "courier_river_mvp_" .. tostring(abilityName)))
    then
        if abilityName == "courier_burst" then
            state.lastBurstAt = t
        elseif abilityName == "courier_shield" then
            state.lastShieldAt = t
        end
        logVerbose("auto " .. tostring(abilityName) .. " (" .. tostring(reasonTag or "-") .. ")")
        return true, "casted"
    end

    return false, "cast_failed"
end

local function tryCourierBurst(courier, reasonTag)
    if not safeWidgetGet(UI.AutoBurst, true) then return false end
    if (nowSec() - (state.lastBurstAt or 0)) < 0.75 then return false end
    local ok = tryUseCourierUtilityAbility(courier, "courier_burst", reasonTag)
    return ok == true
end

local function tryCourierShield(courier, reasonTag)
    if not safeWidgetGet(UI.AutoShield, true) then return false end
    if (nowSec() - (state.lastShieldAt or 0)) < 0.75 then return false end
    local ok = tryUseCourierUtilityAbility(courier, "courier_shield", reasonTag)
    return ok == true
end

local function issueCourierDeliveryPrepareOrder(courier, localHero, ability)
    if not courier or not ability then return false, "prepare_order_missing_context" end

    local player = getLocalPlayer()
    if not player then
        return false, "local_player_missing"
    end

    local abilityName = getAbilityName(ability) or state.lastTriggerAbility
    if abilityName == "courier_take_stash_and_transfer_items" then
        if not localHero then
            return false, "hero_missing"
        end
        if not UNIT_ORDER_CAST_TARGET then
            return false, "order_enum_missing_cast_target"
        end
        local ok = playerPrepareUnitOrdersPositional(
            player,
            UNIT_ORDER_CAST_TARGET,
            localHero,
            Vector(0, 0, 0),
            ability,
            ORDER_ISSUER_PASSED_UNIT_ONLY,
            courier,
            false,
            "courier_river_mvp_handoff_target"
        )
        return ok, ok and "prepare_orders_target" or "prepare_orders_failed_target"
    end

    if not UNIT_ORDER_CAST_NO_TARGET then
        return false, "order_enum_missing_cast_no_target"
    end

    local ok = playerPrepareUnitOrdersPositional(
        player,
        UNIT_ORDER_CAST_NO_TARGET,
        nil,
        Vector(0, 0, 0),
        ability,
        ORDER_ISSUER_PASSED_UNIT_ONLY,
        courier,
        false,
        "courier_river_mvp_handoff_notarget"
    )
    return ok, ok and "prepare_orders_no_target" or "prepare_orders_failed_no_target"
end

local function issueCourierDeliveryRecast(courier, localHero)
    local t = nowSec()
    if not canIssueScriptOrder(t) then
        return false, "order_cooldown"
    end

    local triggerAbility = state.lastTriggerAbilityRef
    local triggerAbilityName = state.lastTriggerAbility
    local prepareFallbackInfo = nil
    if triggerAbility then
        if triggerAbilityName == "courier_take_stash_and_transfer_items" and localHero then
            markScriptOrderIssued(t)
            if castAbilityTarget(courier, triggerAbility, localHero) then
                return true, "stored_trigger_ability"
            end
        elseif triggerAbilityName == "courier_transfer_items"
            or triggerAbilityName == "courier_autodeliver"
            or triggerAbilityName == "courier_take_stash_items"
        then
            markScriptOrderIssued(t)
            if castAbilityNoTarget(courier, triggerAbility) then
                return true, "stored_trigger_ability"
            end
        end

        -- Some builds don't expose courier abilities via GetAbilityByName at handoff time.
        -- Re-issue the original delivery ability through Player.PrepareUnitOrders.
        markScriptOrderIssued(t)
        local okPrepare, prepareInfo = issueCourierDeliveryPrepareOrder(courier, localHero, triggerAbility)
        if okPrepare then
            return true, prepareInfo
        end
        prepareFallbackInfo = prepareInfo
    end

    local hiddenSelfDeliver = getAbilityByName(courier, "courier_take_stash_and_transfer_items")
    if hiddenSelfDeliver and localHero then
        markScriptOrderIssued(t)
        if castAbilityTarget(courier, hiddenSelfDeliver, localHero) then
            return true, "courier_take_stash_and_transfer_items"
        end
        -- Fall through to no-target variants in the same tick.
    end

    local ability = getAbilityByName(courier, "courier_transfer_items")
    local abilityName = "courier_transfer_items"
    if not ability then
        ability = getAbilityByName(courier, "courier_autodeliver")
        abilityName = "courier_autodeliver"
    end
    if not ability then
        if prepareFallbackInfo then
            return false, "ability_missing(" .. tostring(prepareFallbackInfo) .. ")"
        end
        return false, "ability_missing"
    end

    markScriptOrderIssued(t)
    local ok = castAbilityNoTarget(courier, ability)
    if not ok then
        return false, "cast_failed"
    end
    return true, abilityName
end

local function enumOrderLooksLikeCast(order)
    if order == nil then return false end
    if CAST_ORDER_SET[order] then return true end
    if type(order) == "string" then
        return order:find("CAST", 1, true) ~= nil
    end
    return false
end

local function cloneGroundRoutePoints(points)
    if type(points) ~= "table" then return nil end
    local out = {}
    for i = 1, #points do
        out[i] = groundVec(points[i]) or points[i]
    end
    return out
end

local function findNearestRoutePointIndex(points, pos)
    if type(points) ~= "table" or not pos then return nil, math.huge end
    local bestIdx, bestDist = nil, math.huge
    for i = 1, #points do
        local d = dist2d(points[i], pos)
        if d < bestDist then
            bestIdx = i
            bestDist = d
        end
    end
    return bestIdx, bestDist
end

local function routeSegmentDistance(points, fromIdx, toIdx)
    if type(points) ~= "table" or not fromIdx or not toIdx then return 0 end
    if fromIdx == toIdx then return 0 end
    local step = (toIdx > fromIdx) and 1 or -1
    local total = 0
    local i = fromIdx
    while i ~= toIdx do
        local j = i + step
        total = total + dist2d(points[i], points[j])
        i = j
    end
    return total
end

local function buildRouteSlice(points, fromIdx, toIdx)
    if type(points) ~= "table" or not fromIdx or not toIdx then return nil end
    local out = {}
    local step = (toIdx >= fromIdx) and 1 or -1
    local i = fromIdx
    while true do
        out[#out + 1] = points[i]
        if i == toIdx then break end
        i = i + step
    end
    return out
end

local function getRouteCurrentName()
    return state.routePathName or state.routeHubName
end

local function scanActiveRouteDanger(localHero, courierPos, routePoints, routeIdx, heroPos)
    if not safeWidgetGet(UI.SafeRouteCheck, true) then
        return false, nil
    end
    local t = nowSec()
    if (t - (state.lastDangerScanAt or 0)) < 0.20 then
        return false, nil
    end
    state.lastDangerScanAt = t

    local currentWp = routePoints and routePoints[routeIdx] or nil
    local nextWp = routePoints and routePoints[routeIdx and (routeIdx + 1) or 0] or nil
    local points = buildDangerCheckPoints(nil, courierPos, currentWp, nextWp, heroPos)
    return detectRouteDanger(localHero, points)
end

local function shouldEarlyHandoff(localHero, courierPos, routePoints, routeIdx)
    if not localHero or not courierPos then return false end
    local heroPos = getAbsOrigin(localHero)
    if not heroPos then return false end
    if dist2d(courierPos, heroPos) <= EARLY_HANDOFF_DIST then
        return true
    end
    if type(routePoints) == "table" and routeIdx and routeIdx < #routePoints then
        local finalPt = routePoints[#routePoints]
        if finalPt and dist2d(finalPt, heroPos) > safeWidgetGet(UI.HubMaxTargetDistance, 5200) * 1.15 then
            -- Hero moved significantly from planned endpoint; handoff earlier once reasonably close.
            return dist2d(courierPos, heroPos) <= (EARLY_HANDOFF_DIST + 250)
        end
    end
    return false
end

local function pickBestRoutePath(localHero, courierPos, heroPos)
    if not localHero or not courierPos or not heroPos then
        return nil, "missing_positions"
    end

    clearExpiredRouteBlacklists(nowSec())

    local minDirect = safeWidgetGet(UI.MinDirectDistance, 2500)
    local aggressiveProfile = safeWidgetGet(UI.AggressiveProfile, false)
    local maxDetourRatio = safeWidgetGet(UI.MaxDetourRatio, 1.18) + (aggressiveProfile and 0.08 or 0.0)
    local hubMaxTargetDistance = safeWidgetGet(UI.HubMaxTargetDistance, 5200)
    local arrivalRadius = safeWidgetGet(UI.HubArrivalRadius, 280)
    local minRouteTravel = math.max(arrivalRadius * 2, 700)
    local heroTeamKind = getTeamKind(getEntityTeamNum(localHero))

    if not isHeroInPreferredSideLaneZone(heroPos, heroTeamKind) then
        return nil, "hero_not_in_side_lane_zone"
    end

    local direct = dist2d(courierPos, heroPos)
    if direct < minDirect then
        return nil, "direct_too_short"
    end

    local best = nil

    for routeKey, routeDef in pairs(RIVER_ROUTE_CHAINS) do
        local routeAllowed = true
        if isRouteBlacklisted(routeKey) then
            routeAllowed = false
        end
        if routeAllowed and routeDef.team and heroTeamKind and routeDef.team ~= heroTeamKind and safeWidgetGet(UI.StrictTeamRoute, true) then
            routeAllowed = false
        end

        if routeAllowed then
            local points = cloneGroundRoutePoints(routeDef.points)
            if points and #points >= 2 then
            local courierIdx, courierToRoute = findNearestRoutePointIndex(points, courierPos)
            local heroIdx, heroToRoute = findNearestRoutePointIndex(points, heroPos)

            if courierIdx and heroIdx and courierIdx ~= heroIdx and heroToRoute <= hubMaxTargetDistance then
                local along = routeSegmentDistance(points, courierIdx, heroIdx)
                if along >= minRouteTravel then
                    local slice = buildRouteSlice(points, courierIdx, heroIdx)
                    local firstPt = slice and slice[1] or nil
                    local lastPt = slice and slice[#slice] or nil
                    if firstPt and lastPt then
                        local total = dist2d(courierPos, firstPt) + along + dist2d(lastPt, heroPos)
                        local ratio = total / math.max(direct, 1)
                        if routeDef.team and heroTeamKind and routeDef.team ~= heroTeamKind then
                            ratio = ratio + 0.18
                        end
                        if ratio <= maxDetourRatio then
                            local candidate = {
                                key = routeKey,
                                name = routeDef.name or routeKey,
                                points = slice,
                                courierIndex = courierIdx,
                                heroIndex = heroIdx,
                                ratio = ratio,
                                direct = direct,
                                along = along,
                                courierToEntry = dist2d(courierPos, firstPt),
                                exitToHero = dist2d(lastPt, heroPos),
                            }

                            local better = false
                            if not best then
                                better = true
                            elseif candidate.exitToHero < best.exitToHero then
                                better = true
                            elseif candidate.exitToHero == best.exitToHero and candidate.ratio < best.ratio then
                                better = true
                            end

                            if better then
                                best = candidate
                            end
                        end
                    end
                end
            end
        end
        end
    end

    if not best then
        return nil, "no_candidate_route"
    end

    if safeWidgetGet(UI.SafeRouteCheck, true) and not aggressiveProfile then
        local checkPoints = buildDangerCheckPoints(best.points, courierPos, nil, nil, heroPos)
        local danger, dangerReason = detectRouteDanger(localHero, checkPoints)
        if danger then
            return nil, "danger_" .. tostring(dangerReason or "unknown")
        end
    end

    return best
end

local function getDataIssuer(data)
    if not data then return nil end
    if data.orderIssuer ~= nil then return data.orderIssuer end
    if data.issuer ~= nil then return data.issuer end
    return nil
end

local function getDataOrder(data)
    if not data then return nil end
    return data.order
end

local function getDataIdentifier(data)
    if not data then return nil end
    return data.identifier
end

local function resolveOrderCourier(data)
    if not data then return nil end

    if data.npc and npcIsCourier(data.npc) then
        return data.npc
    end

    if data.ability then
        local owner = getAbilityOwner(data.ability)
        if owner and npcIsCourier(owner) then
            return owner
        end
    end

    if data.target and npcIsCourier(data.target) then
        return data.target
    end

    return nil
end

local function getOrderAbilityName(data)
    if not data or not data.ability then return nil end
    return getAbilityName(data.ability)
end

local function isDeliveryTriggerOrder(data)
    if not data then return false end

    local abilityName = getOrderAbilityName(data)
    if abilityName and DELIVERY_ABILITY_WHITELIST[abilityName] then
        state.lastTriggerAbility = abilityName
        state.lastTriggerAbilityRef = data.ability
        return true
    end

    if abilityName then
        return false
    end

    local order = getDataOrder(data)
    if enumOrderLooksLikeCast(order) then
        state.lastTriggerAbility = abilityName
        state.lastTriggerAbilityRef = nil
        return true
    end

    return false
end

local function pickBestHub(courierPos, heroPos)
    if not courierPos or not heroPos then
        return nil, nil, nil, "missing_positions"
    end

    local minDirect = safeWidgetGet(UI.MinDirectDistance, 2500)
    local maxDetourRatio = safeWidgetGet(UI.MaxDetourRatio, 1.18)
    local hubMaxTargetDistance = safeWidgetGet(UI.HubMaxTargetDistance, 5200)
    local arrivalRadius = safeWidgetGet(UI.HubArrivalRadius, 280)
    local minHubTravel = math.max(arrivalRadius * 1.5, 350)

    local direct = dist2d(courierPos, heroPos)
    if direct < minDirect then
        return nil, nil, direct, "direct_too_short"
    end

    local bestHubName, bestHubPos, bestRatio, bestHubToHero

    for hubName, rawHubPos in pairs(RIVER_HUBS) do
        local hubPos = groundVec(rawHubPos)
        local courierToHub = dist2d(courierPos, hubPos)
        if courierToHub >= minHubTravel then
            local hubToHero = dist2d(hubPos, heroPos)
            if hubToHero <= hubMaxTargetDistance then
                local detour = courierToHub + hubToHero
                local ratio = detour / math.max(direct, 1)
                if ratio <= maxDetourRatio then
                    local better = false
                    if bestHubToHero == nil or hubToHero < bestHubToHero then
                        better = true
                    elseif hubToHero == bestHubToHero and (not bestRatio or ratio < bestRatio) then
                        better = true
                    end

                    if better then
                        bestHubName = hubName
                        bestHubPos = hubPos
                        bestRatio = ratio
                        bestHubToHero = hubToHero
                    end
                end
            end
        end
    end

    if not bestHubName then
        return nil, nil, direct, "no_candidate_hub"
    end

    return bestHubName, bestHubPos, direct, bestRatio
end

local function formatRatio(v)
    if type(v) ~= "number" then return "n/a" end
    return string.format("%.3f", v)
end

local function startRouteIfEligible(localHero, courier)
    if not safeWidgetGet(UI.Enable, true) then return end

    local t = nowSec()
    if t < (state.manualLockUntil or 0) then return end
    if not state.waitingForDeliveryStart then return end

    if t > (state.pendingTriggerUntil or 0) then
        state.waitingForDeliveryStart = false
        state.lastReason = "trigger_window_expired"
        return
    end

    if not courier or not entityIsAlive(courier) then
        return
    end

    local courierState = getCourierState(courier)
    if isCourierDeadState(courierState) then
        state.lastReason = "courier_dead"
        state.waitingForDeliveryStart = false
        return
    end

    if courierState ~= nil and not isCourierRoutingState(courierState) then
        return
    end

    local triggerAt = state.pendingTriggerAt or 0
    if triggerAt > 0 and courierState == STATE_VALUES.AT_BASE and (t - triggerAt) < 0.10 then
        return
    end

    local courierPos = getAbsOrigin(courier)
    local heroPos = getAbsOrigin(localHero)
    local routeChoice, routeErr = pickBestRoutePath(localHero, courierPos, heroPos)

    if not routeChoice or not routeChoice.points or #routeChoice.points == 0 then
        state.waitingForDeliveryStart = false
        state.lastRouteRatio = nil
        state.lastReason = "no_profitable_hub"
        logVerbose("skip route: " .. tostring(routeErr))
        return
    end

    local firstPoint = routeChoice.points[1]
    local courierToPathDist = routeChoice.courierToEntry + routeChoice.along
    local routeTimeoutBase = safeWidgetGet(UI.RouteTimeoutSec, 6.0)
    local moveSpeed = getMoveSpeed(courier) or 450
    -- Base->river->lane routes are long; 30s cap was too short and caused timeout
    -- right before final handoff. Keep a generous cap and conservative estimate.
    local estimatedRouteSec = (courierToPathDist / math.max(moveSpeed, 260)) * 3.0 + 3.0
    local routeTimeoutSec = math.max(routeTimeoutBase, math.min(120.0, estimatedRouteSec))

    local ok, err = issueMoveToHub(courier, firstPoint)
    if not ok then
        state.waitingForDeliveryStart = false
        state.lastReason = "route_start_failed:" .. tostring(err)
        logDebug("route start failed: " .. tostring(err))
        return
    end

    state.active = true
    state.routePathName = routeChoice.name
    state.routePoints = routeChoice.points
    state.routePointIndex = 1
    state.routeHubName = string.format("%s[%d/%d]", tostring(routeChoice.name), 1, #routeChoice.points)
    state.routeHubPos = firstPoint
    state.routeStartedAt = t
    state.routeTimeoutAt = t + routeTimeoutSec
    state.routePlannedDistance = courierToPathDist
    state.waitingForDeliveryStart = false
    state.lastRouteRatio = routeChoice.ratio
    state.lastReason = "route_started"
    noteRouteStart(routeChoice.key or routeChoice.name)
    state.lastCourierProgressPos = cloneVec(courierPos)
    state.lastCourierProgressAt = t
    state.lastCourierHealth = getEntityHealth(courier)

    logVerbose(string.format(
        "route start route=%s wp=%d ratio=%s direct=%.0f routeDist=%.0f timeout=%.1f trigger=%s",
        tostring(routeChoice.name),
        #routeChoice.points,
        formatRatio(routeChoice.ratio),
        routeChoice.direct or -1,
        courierToPathDist or -1,
        routeTimeoutSec or -1,
        tostring(state.lastTriggerAbility or "fallback")
    ))

    if courierToPathDist >= BURST_ROUTE_MIN_DIST then
        tryCourierBurst(courier, "route_start")
    end
end

local function updateActiveRoute(localHero, courier)
    if not state.active then return end

    local function clearActiveFailure(reason, logMsg)
        noteRouteFailure(getRouteCurrentName(), reason)
        clearRouteOnly(reason)
        if logMsg then
            logDebug(logMsg)
        end
    end

    local function completeActiveSuccess(reason, successMsg)
        noteRouteSuccess(getRouteCurrentName())
        if successMsg then
            logVerbose(successMsg)
        end
        clearRouteOnly(reason)
    end

    local t = nowSec()
    if t < (state.manualLockUntil or 0) then
        clearRouteOnly("manual_lock_active")
        return
    end

    if not courier or not localHero or not entityIsAlive(courier) then
        clearActiveFailure("route_timeout_or_invalid", "route cancelled: invalid courier/hero")
        return
    end

    local courierState = getCourierState(courier)
    if isCourierDeadState(courierState) then
        clearActiveFailure("route_timeout_or_invalid", "route cancelled: courier dead")
        return
    end

    local routePoints = state.routePoints
    local routeIdx = state.routePointIndex or 1
    local hubPos = (routePoints and routePoints[routeIdx]) or state.routeHubPos
    if not hubPos then
        clearRouteOnly("route_timeout_or_invalid")
        return
    end

    local courierPos = getAbsOrigin(courier)
    if not courierPos then return end
    local heroPos = getAbsOrigin(localHero)

    if (state.routePlannedDistance or 0) >= BURST_ROUTE_MIN_DIST and (t - (state.routeStartedAt or t)) <= 2.5 then
        tryCourierBurst(courier, "route_early")
    end

    local hp = getEntityHealth(courier)
    local prevHp = state.lastCourierHealth
    if type(hp) == "number" then
        if type(prevHp) == "number" and hp < prevHp then
            local delta = prevHp - hp
            if delta >= 1 then
                tryCourierShield(courier, "damage")
            end
            if delta >= DAMAGE_PANIC_THRESHOLD then
                tryCourierBurst(courier, "damage")
            end
        end
        state.lastCourierHealth = hp
    end

    local arrivalRadius = safeWidgetGet(UI.HubArrivalRadius, 280)
    local isFinalRoutePoint = routePoints and routeIdx >= #routePoints
    -- Couriers can stop short of an exact endpoint due to pathing/collision.
    -- Be more tolerant only on the final waypoint so handoff can still fire.
    local effectiveArrivalRadius = isFinalRoutePoint and math.max(arrivalRadius, 650) or arrivalRadius

    local movedEnough = false
    if state.lastCourierProgressPos then
        movedEnough = dist2d(state.lastCourierProgressPos, courierPos) >= STUCK_MOVE_EPS
    end
    if movedEnough or not state.lastCourierProgressPos then
        state.lastCourierProgressPos = cloneVec(courierPos)
        state.lastCourierProgressAt = t
    end

    if heroPos then
        local danger, dangerReason = scanActiveRouteDanger(localHero, courierPos, routePoints, routeIdx, heroPos)
        if danger then
            tryCourierShield(courier, "danger")
            tryCourierBurst(courier, "danger")
            local panicOk, panicInfo = issueCourierDeliveryRecast(courier, localHero)
            local msg = "route danger abort: " .. tostring(dangerReason)
            if panicOk then
                msg = msg .. " -> fallback " .. tostring(panicInfo)
            end
            clearActiveFailure("danger_abort:" .. tostring(dangerReason), msg)
            return
        end
    end

    if shouldEarlyHandoff(localHero, courierPos, routePoints, routeIdx) then
        local okEarly, infoEarly = issueCourierDeliveryRecast(courier, localHero)
        if okEarly then
            completeActiveSuccess("handoff_to_default_delivery", "handoff to default delivery via " .. tostring(infoEarly) .. " (early)")
            return
        elseif infoEarly ~= "order_cooldown" and infoEarly ~= "cast_failed" then
            logDebug("early handoff attempt failed: " .. tostring(infoEarly))
        end
    end

    if dist2d(courierPos, hubPos) > effectiveArrivalRadius then
        if (t - (state.lastCourierProgressAt or t)) > STUCK_TIMEOUT_SEC then
            tryCourierShield(courier, "stuck")
            tryCourierBurst(courier, "stuck")
            local panicOk = issueCourierDeliveryRecast(courier, localHero)
            local msg = "route stuck"
            if panicOk then
                msg = msg .. " -> fallback delivery"
            end
            clearActiveFailure("route_stuck", msg)
            return
        end

        local routeTimeout = safeWidgetGet(UI.RouteTimeoutSec, 6.0)
        local routeTimeoutAt = state.routeTimeoutAt or ((state.routeStartedAt or t) + routeTimeout)
        if t > routeTimeoutAt then
            clearActiveFailure("route_timeout_or_invalid", "route timeout")
        end
        return
    end

    if routePoints and routeIdx < #routePoints then
        local nextIdx = routeIdx + 1
        local nextPos = routePoints[nextIdx]
        local okMove, moveInfo = issueMoveToHub(courier, nextPos)
        if okMove then
            state.routePointIndex = nextIdx
            state.routeHubPos = nextPos
            state.routeHubName = string.format("%s[%d/%d]", tostring(state.routePathName or "route"), nextIdx, #routePoints)
            state.lastCourierProgressAt = t
        elseif moveInfo == "order_cooldown" then
            return
        else
            clearActiveFailure("route_next_failed:" .. tostring(moveInfo), "route next point failed: " .. tostring(moveInfo))
        end
        return
    end

    local ok, info = issueCourierDeliveryRecast(courier, localHero)
    if ok then
        completeActiveSuccess("handoff_to_default_delivery", "handoff to default delivery via " .. tostring(info))
        return
    end

    if info == "order_cooldown" or info == "cast_failed" then
        -- Transient: stay on the route and retry next tick.
        return
    else
        logDebug("handoff attempt failed: " .. tostring(info))
    end

    clearActiveFailure("handoff_failed:" .. tostring(info), nil)
end

local function isLocalCourierOrder(data, localCourier)
    if not data or not localCourier then return false end
    local orderCourier = resolveOrderCourier(data)
    if not orderCourier then return false end
    return sameEntity(orderCourier, localCourier)
end

local function isScriptIssuer(data)
    local issuer = getDataIssuer(data)
    if issuer == nil or ORDER_ISSUER_SCRIPT == nil then return false end
    return issuer == ORDER_ISSUER_SCRIPT
end

local function processCourierOrderCallback(data)
    if not data then return true end

    local t = nowSec()
    if t < (state.suppressOwnOrdersUntil or 0) then
        return true
    end

    local identifier = getDataIdentifier(data)
    if type(identifier) == "string" and identifier:find("^courier_river_mvp") then
        return true
    end

    if isScriptIssuer(data) then
        return true
    end

    local localHero = getLocalHero()
    if not localHero then
        return true
    end

    local localCourier = select(1, findLocalCourier(localHero))
    if not localCourier then
        return true
    end

    if not isLocalCourierOrder(data, localCourier) then
        return true
    end

    if state.active then
        clearRouteOnly("manual_override")
        state.waitingForDeliveryStart = false
        state.manualLockUntil = t + safeWidgetGet(UI.ManualOverrideLockoutSec, 3.0)
        logDebug("manual override detected; lockout applied")
        return true
    end

    if not safeWidgetGet(UI.Enable, true) then
        return true
    end

    if t < (state.manualLockUntil or 0) then
        return true
    end

    if not isDeliveryTriggerOrder(data) then
        return true
    end

    local withinLimit, elapsedSec, limitSec, fromSec = isWithinWorkTimeLimit()
    if syncTimeLimitBlockedFlag(withinLimit, elapsedSec, limitSec, fromSec) then
        return true
    end

    local triggerWindow = safeWidgetGet(UI.TriggerWindowSec, 1.75)
    local isNewPending = (not state.waitingForDeliveryStart) or (t > (state.pendingTriggerUntil or 0))
    local shouldLogTrigger = isNewPending or ((t - (state.pendingTriggerAt or 0)) > 0.35)

    state.waitingForDeliveryStart = true
    if isNewPending then
        state.pendingTriggerAt = t
    end
    state.pendingTriggerUntil = math.max(state.pendingTriggerUntil or 0, t + triggerWindow)
    state.lastReason = "user_delivery_trigger"
    if shouldLogTrigger then
        logVerbose("delivery trigger detected (" .. tostring(state.lastTriggerAbility or "fallback") .. ")")
    end

    return true
end

function script.OnPrepareUnitOrders(data)
    return processCourierOrderCallback(data)
end

function script.OnUpdate()
    local localHero = getLocalHero()
    if not localHero then
        if state.active or state.waitingForDeliveryStart or state.lastCourierIndex ~= nil then
            resetRuntimeState("no_local_hero")
        end
        return
    end

    local courier = findLocalCourier(localHero)
    local localCourier = courier
    state.lastCourierIndex = getEntityIndex(localCourier)
    state.lastCourierState = getCourierState(localCourier)

    if not localCourier then
        if state.active then
            clearRouteOnly("no_local_courier")
            logDebug("route cancelled: no local courier")
        end
        if state.waitingForDeliveryStart and nowSec() > (state.pendingTriggerUntil or 0) then
            state.waitingForDeliveryStart = false
            state.lastReason = "trigger_window_expired"
        end
        return
    end

    if not safeWidgetGet(UI.Enable, true) then
        if state.active or state.waitingForDeliveryStart then
            clearRouteOnly("disabled")
            state.waitingForDeliveryStart = false
        end
        return
    end

    local withinLimit, elapsedSec, limitSec, fromSec = isWithinWorkTimeLimit()
    if syncTimeLimitBlockedFlag(withinLimit, elapsedSec, limitSec, fromSec) then
        if state.active then
            clearRouteOnly("time_window_blocked")
        end
        if state.waitingForDeliveryStart
            or (state.pendingTriggerUntil or 0) ~= 0
            or (state.pendingTriggerAt or 0) ~= 0
        then
            state.waitingForDeliveryStart = false
            state.pendingTriggerUntil = 0
            state.pendingTriggerAt = 0
        end
        state.lastReason = "time_window_blocked"
        return
    end

    if state.waitingForDeliveryStart and nowSec() > (state.pendingTriggerUntil or 0) then
        state.waitingForDeliveryStart = false
        state.lastReason = "trigger_window_expired"
    end

    if state.active then
        updateActiveRoute(localHero, localCourier)
    else
        startRouteIfEligible(localHero, localCourier)
    end
end

function script.OnDraw()
    local showRouteDraw = safeWidgetGet(UI.DebugDraw, false)
    local showStatus = safeWidgetGet(UI.ShowStatus, false)
    if not showRouteDraw and not showStatus then return end

    local font = ensureDebugFont()
    if not font then return end

    local localHero = getLocalHero()
    local courier = localHero and findLocalCourier(localHero) or nil

    if showRouteDraw and localHero and courier and state.active and state.routeHubPos then
        local courierPos = getAbsOrigin(courier)
        local heroPos = getAbsOrigin(localHero)
        local hubPos = state.routeHubPos

        local sCourier, vCourier = renderWorldToScreen(courierPos)
        local sHub, vHub = renderWorldToScreen(hubPos)
        local sHero, vHero = renderWorldToScreen(heroPos)

        if vCourier and vHub then
            renderLine(sCourier, sHub, Color(0, 190, 255, 220), 2)
        end
        if vHub and vHero then
            renderLine(sHub, sHero, Color(80, 255, 120, 220), 2)
        end
        if vHub then
            local text = string.format("hub=%s ratio=%s", tostring(state.routeHubName), formatRatio(state.lastRouteRatio))
            renderText(font, 12, text, vec2(sHub.x + 8, sHub.y - 12), Color(255, 255, 255, 230))
        end
    end

    if not showStatus then
        return
    end

    local blacklistedRoutes = 0
    if type(state.routeBlacklistedUntil) == "table" then
        for _, untilAt in pairs(state.routeBlacklistedUntil) do
            if type(untilAt) == "number" and untilAt > nowSec() then
                blacklistedRoutes = blacklistedRoutes + 1
            end
        end
    end

    local withinWindow, elapsedSec, limitSec, fromSec = isWithinWorkTimeLimit()
    local windowTag = withinWindow and "ok" or "blocked"
    local status = string.format(
        "CourierRiver | active=%s pending=%s reason=%s cstate=%s routes %d/%d/%d blk=%d tw=%s %.1f[%d..%d]",
        tostring(state.active),
        tostring(state.waitingForDeliveryStart),
        tostring(state.lastReason or "-"),
        tostring(state.lastCourierState or "-"),
        state.routesStarted or 0,
        state.routesSucceeded or 0,
        state.routesFailed or 0,
        blacklistedRoutes,
        windowTag,
        (elapsedSec or 0) / 60,
        math.floor(((fromSec or 0) / 60) + 0.5),
        math.floor(((limitSec or 0) / 60) + 0.5)
    )
    renderText(font, 12, status, vec2(20, 220), Color(220, 220, 220, 220))
end

function script.OnGameEnd()
    resetRuntimeState("game_end")
end

initEnumCompat()

return script
