--[[
    Magnus — Harpoon + Blink + Reverse Polarity combo
    Hold combo key: approach → harpoon → blink behind cluster → RP
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants

local SCRIPT_NAME = "MagnusHarpoonBlinkRP"
local DEBUG_PREFIX = "[" .. SCRIPT_NAME .. "] "
local HERO_NAME = "npc_dota_hero_magnataur"
local STATE_ROOTED = 0
local STATE_MAGIC_IMMUNE = 9
local HARPOON_NAME = "item_harpoon"
local RP_NAME = "magnataur_reverse_polarity"
local ORDER_ID = "magnus.harpoon_blink_rp"
local FORCE_ICON = "panorama/images/items/force_staff_png.vtex_c"

local function OrderTag(tag, suffix)
    return ORDER_ID .. "." .. tag .. "." .. suffix
end

local DEFAULT_RP_RADIUS = 430
local DEFAULT_HARPOON_RANGE = 700
local MIN_BLINK_DIST_FROM_ME = 150
local BLINK_RANGE_MARGIN = 20
local BLINK_SCAN_STEP = 25
local BLINK_ANGLE_STEP = 5
local BLINK_ANGLE_MAX = 20
local SCAN_RADIUS_BUFFER = 300
local TWO_ENEMY_MAX_SEP = 200

local DEBUG_HOLD_INTERVAL = 0.5
local COMBO_RECOVERY_TIME = 0.45
local LATE_RECOVERY_MAX_TIME = 1.0
local RECOVERY_MIN_DELAY = 0.15
local COMBO_BLINK_SETTLE = 0.22
local COMBO_BLINK_RP_TIMEOUT = 0.55
local COMBO_REPEAT_COOLDOWN = 0.35
local APPROACH_RANGE_BUFFER = 35
local PREDICT_LEAD_HARPOON = 0.35
local PREDICT_LEAD_RECOVERY = 0.20
local MAX_PREDICT_SPEED = 550
local MIN_MOTION_SPEED = 30
local HARPOON_CONFIRM_MIN_MOVE = 60
local HARPOON_PULL_MIN_RATIO = 0.25
local HARPOON_PULL_MAX_RATIO = 0.55
local HARPOON_PULL_DIST_FACTOR = 0.40
local HARPOON_PULL_MAX_DIST = 450
local MAGNUS_PULL_RATIO = 0.10
local CLUSTER_MERGE_RATIO = 0.15
local ANCHOR_FOCUS_BLEND = 0.40
local APPROACH_MOVE_INTERVAL = 0.12
local HARPOON_RETRY_DELAY = 0.12
local HARPOON_CAST_GUARD = 0.28
local LINK_BREAK_VERIFY = 0.35
local LINK_BREAK_CAST_INTERVAL = 0.12
local TARGET_RESOLVE_INTERVAL = 0.05
local PREVIEW_RESOLVE_INTERVAL = 0.12
local FORCE_PUSH_DISTANCE = 600
local FORCE_SETTLE = 0.28
local FORCE_FACE_MAX_TURN_TIME = 0.02
local FORCE_FACE_MAX_ANGLE = 10
local FORCE_FACE_STABLE = 0.10
local FORCE_HARPOON_MARGIN = 40

-- Always-on logic (hidden from menu to avoid breaking the combo)
local CONFIG = {
    targetLock = true,
    skipHarpoonBlock = true,
    predictPull = true,
    blinkBehind = true,
    requireBlinkRange = true,
    soloMode = false,
    repeatWhileHeld = true,
    popLinkens = true,
}

local BLINK_ITEMS = {
    "item_blink",
    "item_overwhelming_blink",
    "item_swift_blink",
    "item_arcane_blink",
}

local FORCE_ITEMS = {
    "item_force_staff",
    "item_hurricane_pike",
}

local BLINK_SETTLE = {
    item_blink = 0.22,
    item_overwhelming_blink = 0.24,
    item_swift_blink = 0.16,
    item_arcane_blink = 0.22,
}

local HARPOON_BLOCK_MODIFIERS = {
    "modifier_item_lotus_orb_channel",
    "modifier_antimage_spell_shield",
}

local MAGIC_IMMUNE_MODIFIERS = {
    "modifier_black_king_bar_immune",
    "modifier_life_stealer_rage",
    "modifier_juggernaut_blade_fury",
}

local POP_ITEMS = {
    "item_cyclone",
    "item_wind_waker",
    "item_dagon",
    "item_orchid",
    "item_bloodthorn",
    "item_ethereal_blade",
    "item_shivas_guard",
    "item_nullifier",
    "item_diffusal_blade",
}

--#endregion

--#region State

---@class MagnusHarpoonUI
---@field Enabled CMenuSwitch|nil
---@field ComboKey CMenuBind|nil
---@field MinSep CMenuSliderInt|CMenuSliderFloat|nil
---@field MinRPHits CMenuSliderInt|CMenuSliderFloat|nil
---@field BehindDistance CMenuSliderInt|CMenuSliderFloat|nil
---@field UseForce CMenuSwitch|nil
---@field Debug CMenuSwitch|nil
---@field DrawOverlay CMenuSwitch|nil
local UI = {
    Enabled = nil,
    ComboKey = nil,
    MinSep = nil,
    MinRPHits = nil,
    BehindDistance = nil,
    UseForce = nil,
    Debug = nil,
    DrawOverlay = nil,
}

local Persistent = {
    ---@type Logger|nil
    logger = nil,
    overlayFont = 0,
    ---@type CMenuGroup|nil
    menuGroup = nil,
    ---@type CMenuGearAttachment|nil
    menuGear = nil,
    languageWidget = nil,
    languageLookupAt = 0,
    lastLanguage = nil,
    languageCallbackSet = false,
}

---@class MagnusHarpoonRuntime
local Runtime = {
    lastDebugHoldLog = -100,
    lastApproachMove = -100,
    comboDone = false,
    harpoonAttempted = false,
    blinkRpSent = false,
    comboAttemptTime = 0,
    comboPauseStarted = nil,
    comboFinishTime = 0,
    harpoonCastPos = nil,
    blinkPending = false,
    blinkPendingTime = 0,
    linkBreakPending = false,
    linkBreakAttemptTime = 0,
    lastLinkBreakCast = -100,
    lastTargetResolve = -100,
    lockedHarpoonTarget = nil,
    lockedTargets = nil,
    overlayTargets = nil,
    overlayReason = "",
    overlayRpRadius = DEFAULT_RP_RADIUS,
    unitMotion = {},
    pendingBlinkName = nil,
    forcePending = false,
    forcePendingTime = 0,
    forceUsed = false,
    forceFaceStarted = false,
    forceFaceOkSince = nil,
}

--#endregion

--#region Localization

local I = {
    enable  = "\u{f00c}", -- check (no background when passed to Switch)
    draw    = "\u{f2d0}", -- window / on-screen overlay
    bind    = "\u{e1c1}", -- keyboard brightness
    sep     = "\u{f337}", -- horizontal separation
    hits    = "\u{f0c0}", -- group hits
    ruler   = "\u{f547}", -- behind distance
    bug     = "\u{f188}", -- debug
    gear    = "\u{f013}", -- settings gear
}

local Locale = {
    group_name = {
        en = "Harpoon Combo",
        ru = "Комбо Harpoon",
        cn = "钩矛连招",
    },
    gear_settings = {
        en = "Settings",
        ru = "Настройки",
        cn = "设置",
    },
    ui_enabled = {
        en = "Enable",
        ru = "Включить",
        cn = "启用",
    },
    ui_combo_key = {
        en = "Combo Key",
        ru = "Бинд комбо",
        cn = "连招按键",
    },
    ui_min_sep = {
        en = "Min target separation",
        ru = "Мин. расстояние целей",
        cn = "最小目标间距",
    },
    ui_min_rp_hits = {
        en = "Min RP hits",
        ru = "Мин. попаданий RP",
        cn = "最小RP命中数",
    },
    ui_behind_dist = {
        en = "Behind distance",
        ru = "Дистанция за толпой",
        cn = "敌后距离",
    },
    ui_use_force = {
        en = "Use Force Staff",
        ru = "Использовать Force Staff",
        cn = "使用原力法杖",
    },
    ui_debug = {
        en = "Debug logs",
        ru = "Debug логи",
        cn = "调试日志",
    },
    ui_draw_overlay = {
        en = "Draw overlay",
        ru = "Оверлей",
        cn = "显示 overlay",
    },
    tip_enabled = {
        en = "Master switch for the Magnus Harpoon + Blink + RP combo script.",
        ru = "Главный переключатель скрипта комбо Harpoon + Blink + RP.",
        cn = "Magnus 钩矛+闪烁+反转极性连招脚本总开关。",
    },
    tip_combo_key = {
        en = "Hold this key to run the combo: approach (optional Force Staff to close Harpoon range), harpoon, blink behind the cluster, then RP.",
        ru = "Удерживай для комбо: подход (опционально Force Staff дотянуть Harpoon), harpoon, блинк за толпу, затем RP.",
        cn = "按住此键执行连招：接近（可选原力法杖进入钩矛射程）、钩矛、闪到敌后、再反转极性。",
    },
    tip_min_sep = {
        en = "Minimum distance between harpoon target and blink anchor enemy.",
        ru = "Минимальная дистанция между целью harpoon и якорем для блинка.",
        cn = "钩矛目标与闪烁锚点敌人之间的最小距离。",
    },
    tip_min_rp_hits = {
        en = "Minimum enemy heroes that must be caught by RP for a valid combo.",
        ru = "Минимум врагов, которых должен зацепить RP для валидного комбо.",
        cn = "连招成立时反转极性至少命中的敌方英雄数量。",
    },
    tip_behind_dist = {
        en = "Minimum distance past the predicted cluster; blink uses full range beyond this point.",
        ru = "Минимальное расстояние за предсказанной толпой; блинк идёт на полный радиус дальше этой точки.",
        cn = "超过预测敌群的最小距离；在此之外会使用闪烁的完整射程。",
    },
    tip_use_force = {
        en = "When enabled, cast Force Staff / Hurricane Pike on self during approach to enter Harpoon cast range. Not used before Blink.",
        ru = "Если включено: на подходе кастует Force Staff / Hurricane Pike на себя, чтобы войти в дальность Harpoon. Перед Blink не используется.",
        cn = "开启后，在接近阶段对自己使用原力法杖/飓风长戟以进入钩矛射程。闪烁前不使用。",
    },
    tip_debug = {
        en = "Write combo decisions and casts to debug.log.",
        ru = "Писать решения комбо и касты в debug.log.",
        cn = "将连招决策和施法写入 debug.log。",
    },
    tip_draw_overlay = {
        en = "Show blink position, RP radius, predicted hits, and combo status while the key is held.",
        ru = "Показывать позицию блинка, радиус RP, число попаданий и статус комбо при удержании клавиши.",
        cn = "按住按键时显示闪烁位置、RP 半径、预测命中数和连招状态。",
    },
}

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
    local lang = GetLanguageCode()
    local entry = Locale[key]
    if not entry then
        return tostring(key)
    end
    return entry[lang] or entry.en or tostring(key)
end

local function MenuTip(widget, key)
    if widget then
        widget:ToolTip(L(key))
    end
end

local function MenuLabel(widget, key)
    if widget then
        widget:ForceLocalization(L(key))
    end
end

local function ApplyLocalization(force)
    local lang = GetLanguageCode()
    if not force and Persistent.lastLanguage == lang then
        return
    end
    Persistent.lastLanguage = lang

    MenuLabel(Persistent.menuGroup, "group_name")
    MenuLabel(Persistent.menuGear, "gear_settings")

    MenuLabel(UI.Enabled, "ui_enabled")
    MenuTip(UI.Enabled, "tip_enabled")

    MenuLabel(UI.ComboKey, "ui_combo_key")
    MenuTip(UI.ComboKey, "tip_combo_key")

    MenuLabel(UI.MinSep, "ui_min_sep")
    MenuTip(UI.MinSep, "tip_min_sep")

    MenuLabel(UI.MinRPHits, "ui_min_rp_hits")
    MenuTip(UI.MinRPHits, "tip_min_rp_hits")

    MenuLabel(UI.BehindDistance, "ui_behind_dist")
    MenuTip(UI.BehindDistance, "tip_behind_dist")

    MenuLabel(UI.UseForce, "ui_use_force")
    MenuTip(UI.UseForce, "tip_use_force")

    MenuLabel(UI.Debug, "ui_debug")
    MenuTip(UI.Debug, "tip_debug")

    MenuLabel(UI.DrawOverlay, "ui_draw_overlay")
    MenuTip(UI.DrawOverlay, "tip_draw_overlay")
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

--#endregion

--#region Helpers

local ResetHoldState

local function LogWrite(message)
    message = tostring(message)
    if Persistent.logger then
        Persistent.logger:debug(message)
        return
    end
    Log.Write(DEBUG_PREFIX .. message)
end

local function Now()
    return GlobalVars.GetCurTime() or 0
end

local function OnEnabledChanged(widget)
    local enabled = widget:Get() == true
    UI.ComboKey:Disabled(not enabled)
    UI.MinSep:Disabled(not enabled)
    UI.MinRPHits:Disabled(not enabled)
    UI.BehindDistance:Disabled(not enabled)
    UI.UseForce:Disabled(not enabled)
    UI.Debug:Disabled(not enabled)
    UI.DrawOverlay:Disabled(not enabled)
    if not enabled then
        ResetHoldState()
    end
end

local function InitializeUI()
    ---@type CMenuGroup|nil
    local group = Menu.Find("Heroes", "Hero List", "Magnus", "Main Settings", "Harpoon Combo")
        or Menu.Find("Scripts", "Combat", "Magnus Harpoon Combo", "Main", "Harpoon Combo")

    if not group then
        local mainSection = Menu.Find("Heroes", "Hero List", "Magnus", "Main Settings")
        if mainSection then
            group = mainSection:Create("Harpoon Combo")
        end
    end

    if not group then
        group = Menu.Create("Scripts", "Combat", "Magnus Harpoon Combo", "Main", "Harpoon Combo")
    end

    if not group then
        error(DEBUG_PREFIX .. "Failed to create menu group")
    end

    Persistent.menuGroup = group

    UI.Enabled = group:Switch("Enable", false, I.enable)
    UI.ComboKey = group:Bind("Combo Key", Enum.ButtonCode.KEY_NONE, I.bind)

    local gear = UI.Enabled:Gear("Settings", I.gear, true)
    Persistent.menuGear = gear

    UI.MinSep = gear:Slider("Min target separation", 200, 1200, 400, "%d")
    UI.MinSep:Icon(I.sep)

    UI.MinRPHits = gear:Slider("Min RP hits", 1, 5, 2, "%d")
    UI.MinRPHits:Icon(I.hits)

    UI.BehindDistance = gear:Slider("Behind distance", 100, 500, 280, "%d")
    UI.BehindDistance:Icon(I.ruler)

    UI.UseForce = gear:Switch("Use Force Staff", false)
    UI.UseForce:Image(FORCE_ICON)

    UI.Debug = gear:Switch("Debug logs", false)
    UI.Debug:Icon(I.bug)

    UI.DrawOverlay = gear:Switch("Draw overlay", true)
    UI.DrawOverlay:Icon(I.draw)

    UI.Enabled:SetCallback(OnEnabledChanged, true)

    ApplyLocalization(true)
    SetupLanguageCallback()
end

local function Dbg(message, ...)
    if not UI.Debug or UI.Debug:Get() ~= true then
        return
    end

    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end

    LogWrite(message)
end

local function GetAbilityName(ability)
    if not ability then
        return "nil"
    end
    return Ability.GetName(ability) or Ability.GetBaseName(ability) or "unknown"
end

local function IsComboDebugAbility(abilityName)
    if abilityName == HARPOON_NAME or abilityName == RP_NAME then
        return true
    end
    if string.find(abilityName, "blink", 1, true) then
        return true
    end
    for _, itemName in ipairs(FORCE_ITEMS) do
        if abilityName == itemName then
            return true
        end
    end
    for _, itemName in ipairs(POP_ITEMS) do
        if abilityName == itemName then
            return true
        end
    end
    return false
end

local function GetCastableDebug(ability, mana, label)
    if not ability then
        return string.format("%s=missing", label)
    end

    return string.format(
        "%s ready=%s castable=%s cd=%.2f",
        label,
        tostring(Ability.IsReady(ability)),
        tostring(Ability.IsCastable(ability, mana)),
        Ability.GetCooldown(ability) or -1
    )
end

local function LogHoldState(reason, me, mana, harpoon, blink, blinkName, rp, targets, comboReady)
    if not UI.Debug or UI.Debug:Get() ~= true then
        return
    end

    local now = Now()
    if now - Runtime.lastDebugHoldLog < DEBUG_HOLD_INTERVAL then
        return
    end

    Runtime.lastDebugHoldLog = now

    local harpBonus = NPC.GetCastRangeBonus(me) or 0
    local harpBase = harpoon and Ability.GetCastRange(harpoon) or 0
    local blinkBase = blink and Ability.GetCastRange(blink) or 0

    LogWrite(string.format(
        "HOLD | %s | ready=%s | harpoon=%.0f blink=%.0f (%s) | %s | %s | %s | %s",
        reason,
        tostring(comboReady),
        harpBase + harpBonus,
        blinkBase + harpBonus,
        blinkName or "none",
        GetCastableDebug(harpoon, mana, "harpoon"),
        GetCastableDebug(blink, mana, "blink"),
        GetCastableDebug(rp, mana, "rp"),
        targets and string.format(
            "hits=%d sep=%.0f pos=(%.0f,%.0f)",
            targets.hitCount,
            targets.sepDist,
            targets.blinkPos.x,
            targets.blinkPos.y
        ) or "none"
    ))
end

local function WorldToScreen(world)
    local screen, visible = Render.WorldToScreen(world)
    return screen, visible
end

local function PauseComboTimer(now)
    if Runtime.harpoonAttempted and not Runtime.comboPauseStarted then
        Runtime.comboPauseStarted = now
    end
end

local function ResumeComboTimer(now)
    if Runtime.comboPauseStarted then
        Runtime.comboAttemptTime = Runtime.comboAttemptTime + (now - Runtime.comboPauseStarted)
        Runtime.comboPauseStarted = nil
    end
end

local function IsBlinkPositionTraversable(from, pos)
    if not from or not pos then
        return true
    end

    return GridNav.IsTraversableFromTo(from, pos, false, nil) == true
end

local function IsValidHero(unit)
    return unit
        and Entity.IsAlive(unit) == true
        and Entity.IsDormant(unit) ~= true
        and NPC.IsIllusion(unit) ~= true
end

local function IsMagicImmuneForRP(unit)
    if not IsValidHero(unit) then
        return true
    end

    if NPC.HasState(unit, STATE_MAGIC_IMMUNE) then
        return true
    end

    for _, modifierName in ipairs(MAGIC_IMMUNE_MODIFIERS) do
        if NPC.HasModifier(unit, modifierName) then
            return true
        end
    end

    return false
end

local function IsEnemyVisibleForCombo(enemy)
    if not IsValidHero(enemy) then
        return false
    end

    if NPC.IsVisible(enemy) == false then
        return false
    end

    local pos = Entity.GetAbsOrigin(enemy)
    if not pos then
        return true
    end

    return FogOfWar.IsPointVisible(pos) ~= false
end

local function GetUnitStatusResistance(unit)
    if not unit then
        return 0
    end

    local base = NPC.GetModifierPropertyHighest(unit, Enum.ModifierFunction.MODIFIER_PROPERTY_STATUS_RESISTANCE) or 0
    local stacking = NPC.GetModifierPropertyHighest(unit, Enum.ModifierFunction.MODIFIER_PROPERTY_STATUS_RESISTANCE_STACKING) or 0

    return math.min(0.85, math.max(0, base + stacking))
end

local function GetEffectiveRPRadius(unit, baseRadius)
    return baseRadius * (1 - GetUnitStatusResistance(unit))
end

local function TargetNeedsLinkBreak(target)
    return target and NPC.IsLinkensProtected(target) == true
end

local function GetPopCastRange(me, item, itemName)
    local range = item and Ability.GetCastRange(item) or 0
    range = range + (NPC.GetCastRangeBonus(me) or 0)
    if range > 0 then
        return range
    end
    if itemName == "item_cyclone" or itemName == "item_wind_waker" then
        return 550
    end
    if itemName == "item_dagon" then
        return 700
    end
    return 600
end

local function FindPopItem(me, target, mana)
    if not target then
        return nil, nil
    end

    local myPos = Entity.GetAbsOrigin(me)
    local targetPos = Entity.GetAbsOrigin(target)
    if not myPos or not targetPos then
        return nil, nil
    end

    local dist = (targetPos - myPos):Length2D()
    local bestItem, bestName, bestRange = nil, nil, -1

    for _, itemName in ipairs(POP_ITEMS) do
        local item = NPC.GetItem(me, itemName, true)
        if item and Ability.IsCastable(item, mana) then
            local range = GetPopCastRange(me, item, itemName)
            if dist <= range and range > bestRange then
                bestItem = item
                bestName = itemName
                bestRange = range
            end
        end
    end

    return bestItem, bestName
end

local function HasHarpoonBlock(unit)
    if not IsValidHero(unit) then
        return false
    end

    if NPC.IsLinkensProtected(unit) == true or NPC.IsMirrorProtected(unit) == true then
        return true
    end

    for _, modifierName in ipairs(HARPOON_BLOCK_MODIFIERS) do
        if NPC.HasModifier(unit, modifierName) then
            return true
        end
    end

    return false
end

local function CanHarpoonTarget(target)
    if not IsValidHero(target) then
        return false
    end

    if CONFIG.skipHarpoonBlock and HasHarpoonBlock(target) then
        if CONFIG.popLinkens and TargetNeedsLinkBreak(target) then
            return true
        end
        return false
    end

    return true
end

local function CanAct(me)
    if not IsValidHero(me) then
        return false
    end

    return NPC.IsStunned(me) ~= true
        and NPC.IsSilenced(me) ~= true
        and NPC.HasState(me, STATE_ROOTED) ~= true
end

local function IsComboKeyHeld()
    return UI.ComboKey ~= nil and UI.ComboKey:IsDown() == true
end

local function GetBlink(me)
    for _, name in ipairs(BLINK_ITEMS) do
        local blink = NPC.GetItem(me, name, true)
        if blink then
            return blink, name
        end
    end
    return nil, nil
end

local function GetBlinkSettleTime(blinkName)
    if blinkName and BLINK_SETTLE[blinkName] then
        return BLINK_SETTLE[blinkName]
    end
    return COMBO_BLINK_SETTLE
end

local function IsUseForceEnabled()
    return UI.UseForce ~= nil and UI.UseForce:Get() == true
end

local function GetForceItem(me, mana)
    for _, name in ipairs(FORCE_ITEMS) do
        local item = NPC.GetItem(me, name, true)
        if item and Ability.IsCastable(item, mana) then
            return item, name
        end
    end
    return nil, nil
end

local function CanPlanWithForce(me)
    if not IsUseForceEnabled() then
        return false
    end

    for _, name in ipairs(FORCE_ITEMS) do
        if NPC.GetItem(me, name, true) then
            return true
        end
    end

    return false
end

local function UpdateUnitMotionCache(units, now)
    if not units then
        return
    end

    now = now or Now()

    for _, unit in ipairs(units) do
        local idx = Entity.GetIndex(unit)
        local pos = Entity.GetAbsOrigin(unit)
        if not idx or not pos then
            goto continue_motion
        end

        local entry = Runtime.unitMotion[idx]
        if entry and entry.time and now > entry.time then
            local dt = now - entry.time
            if dt > 0 and dt <= 0.75 then
                local vx = (pos.x - entry.x) / dt
                local vy = (pos.y - entry.y) / dt
                local speed = math.sqrt(vx * vx + vy * vy)
                if speed > MAX_PREDICT_SPEED then
                    local scale = MAX_PREDICT_SPEED / speed
                    vx = vx * scale
                    vy = vy * scale
                end
                entry.vx = vx
                entry.vy = vy
            else
                entry.vx = nil
                entry.vy = nil
            end
            entry.x = pos.x
            entry.y = pos.y
            entry.z = pos.z
            entry.time = now
        else
            Runtime.unitMotion[idx] = {
                x = pos.x,
                y = pos.y,
                z = pos.z,
                time = now,
            }
        end

        ::continue_motion::
    end
end

local function PredictUnitPos(unit, basePos, leadTime)
    if not unit or not basePos or leadTime <= 0 then
        return basePos
    end

    local idx = Entity.GetIndex(unit)
    local motion = idx and Runtime.unitMotion[idx]
    if not motion or not motion.vx or not motion.vy then
        return basePos
    end

    local speed = math.sqrt(motion.vx * motion.vx + motion.vy * motion.vy)
    if speed < MIN_MOTION_SPEED then
        return basePos
    end

    return Vector(
        basePos.x + motion.vx * leadTime,
        basePos.y + motion.vy * leadTime,
        basePos.z
    )
end

local function GetPredictedEnemyPos(unit, leadTime)
    local pos = Entity.GetAbsOrigin(unit)
    if not pos then
        return nil
    end
    return PredictUnitPos(unit, pos, leadTime)
end

local function GetItemCastRange(me, item, fallback)
    if not item then
        return fallback and (fallback + (NPC.GetCastRangeBonus(me) or 0)) or 0
    end
    return Ability.GetCastRange(item) + (NPC.GetCastRangeBonus(me) or 0)
end

local function GetRPRadius(rp)
    if not rp then
        return DEFAULT_RP_RADIUS
    end

    local radius = Ability.GetLevelSpecialValueFor(rp, "pull_radius")
    return (radius and radius > 0) and radius or DEFAULT_RP_RADIUS
end

local function Lerp3(a, b, t)
    return Vector(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
        a.z + (b.z - a.z) * t
    )
end

local function EffectiveMinSep(enemyCount, minSep)
    if enemyCount <= 2 then
        return math.min(minSep, TWO_ENEMY_MAX_SEP)
    end
    -- 3-man fights: slightly softer sep so cluster blink still finds an anchor.
    if enemyCount == 3 then
        return math.min(minSep, math.max(TWO_ENEMY_MAX_SEP, math.floor(minSep * 0.70)))
    end
    return minSep
end

ResetHoldState = function()
    Runtime.comboDone = false
    Runtime.harpoonAttempted = false
    Runtime.blinkRpSent = false
    Runtime.blinkPending = false
    Runtime.blinkPendingTime = 0
    Runtime.linkBreakPending = false
    Runtime.linkBreakAttemptTime = 0
    Runtime.comboAttemptTime = 0
    Runtime.comboFinishTime = 0
    Runtime.comboPauseStarted = nil
    Runtime.harpoonCastPos = nil
    Runtime.lastApproachMove = -100
    Runtime.lastTargetResolve = -100
    Runtime.lastLinkBreakCast = -100
    Runtime.lockedHarpoonTarget = nil
    Runtime.lockedTargets = nil
    Runtime.overlayTargets = nil
    Runtime.overlayReason = ""
    Runtime.unitMotion = {}
    Runtime.pendingBlinkName = nil
    Runtime.forcePending = false
    Runtime.forcePendingTime = 0
    Runtime.forceUsed = false
    Runtime.forceFaceStarted = false
    Runtime.forceFaceOkSince = nil
end

local function PartialResetForRepeat()
    Runtime.comboDone = false
    Runtime.harpoonAttempted = false
    Runtime.blinkRpSent = false
    Runtime.blinkPending = false
    Runtime.blinkPendingTime = 0
    Runtime.linkBreakPending = false
    Runtime.linkBreakAttemptTime = 0
    Runtime.comboAttemptTime = 0
    Runtime.comboPauseStarted = nil
    Runtime.harpoonCastPos = nil
    Runtime.lastApproachMove = -100
    Runtime.lastTargetResolve = -100
    Runtime.lockedHarpoonTarget = nil
    Runtime.lockedTargets = nil
    Runtime.unitMotion = {}
    Runtime.pendingBlinkName = nil
    Runtime.forcePending = false
    Runtime.forcePendingTime = 0
    Runtime.forceUsed = false
    Runtime.forceFaceStarted = false
    Runtime.forceFaceOkSince = nil
end

local function FinishComboCycle(now)
    Runtime.comboFinishTime = now
    if CONFIG.repeatWhileHeld and IsComboKeyHeld() then
        PartialResetForRepeat()
        Dbg("combo cycle done | repeat while held")
        return
    end
    Runtime.comboDone = true
end

local function ResetRuntime()
    ResetHoldState()
    Runtime.lastDebugHoldLog = -100
    Runtime.overlayRpRadius = DEFAULT_RP_RADIUS
end

--#endregion

--#region Targeting

local function GetHarpoonTargetUnderCursor(me, debugReason)
    local harpoonTarget = Input.GetNearestHeroToCursor(
        Entity.GetTeamNum(me),
        Enum.TeamType.TEAM_ENEMY
    )

    if not harpoonTarget or not CanHarpoonTarget(harpoonTarget) then
        if debugReason then
            debugReason[1] = harpoonTarget and HasHarpoonBlock(harpoonTarget)
                and "harpoon target has block (Linken's/Lotus)"
                or "no valid harpoon target under cursor"
        end
        return nil
    end

    return harpoonTarget
end

local function ResolveHarpoonTarget(me, debugReason)
    if CONFIG.targetLock then
        if not Runtime.lockedHarpoonTarget then
            Runtime.lockedHarpoonTarget = GetHarpoonTargetUnderCursor(me, nil)
        end

        local locked = Runtime.lockedHarpoonTarget
        if not locked or not CanHarpoonTarget(locked) then
            if debugReason then
                debugReason[1] = locked and HasHarpoonBlock(locked)
                    and "locked harpoon target blocked"
                    or "no locked harpoon target"
            end
            return nil
        end

        return locked
    end

    return GetHarpoonTargetUnderCursor(me, debugReason)
end

local function GetHarpoonDist(me, target)
    return (Entity.GetAbsOrigin(target) - Entity.GetAbsOrigin(me)):Length2D()
end

local function GetHarpoonCastRange(me, harpoon)
    return GetItemCastRange(me, harpoon, DEFAULT_HARPOON_RANGE)
end

local function GetHarpoonApproachPosition(me, harpoonTarget, harpoon)
    local myPos = Entity.GetAbsOrigin(me)
    local targetPos = Entity.GetAbsOrigin(harpoonTarget)
    if not myPos or not targetPos then
        return targetPos
    end

    local castRange = GetHarpoonCastRange(me, harpoon)
    local desiredRange = math.max(200, castRange - APPROACH_RANGE_BUFFER)
    local dx = targetPos.x - myPos.x
    local dy = targetPos.y - myPos.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist <= desiredRange then
        return nil
    end

    if dist < 1 then
        return myPos
    end

    local scale = desiredRange / dist
    return Vector(
        myPos.x + dx * scale,
        myPos.y + dy * scale,
        myPos.z
    )
end

local function IsHarpoonInCastRange(me, target, harpoon)
    if not NPC.IsEntityInRange then
        return GetHarpoonDist(me, target) <= GetHarpoonCastRange(me, harpoon)
    end

    return NPC.IsEntityInRange(me, target, GetHarpoonCastRange(me, harpoon))
end

local function CanCastHarpoonNow(me, target, harpoon, mana)
    return Ability.IsCastable(harpoon, mana) and IsHarpoonInCastRange(me, target, harpoon)
end

local function GetHarpoonForceReach(me, harpoon)
    local range = GetHarpoonCastRange(me, harpoon)
    if CanPlanWithForce(me) then
        return range + FORCE_PUSH_DISTANCE - FORCE_HARPOON_MARGIN
    end
    return range
end

local function GetFacingAngleTo(me, pos)
    local angle = NPC.FindRotationAngle(me, pos)
    if angle ~= nil then
        return math.abs(math.deg(angle))
    end
    return 999
end

local function GetForwardDotTo(me, targetPos)
    local myPos = Entity.GetAbsOrigin(me)
    if not myPos or not targetPos then
        return -1, 999
    end

    local toX = targetPos.x - myPos.x
    local toY = targetPos.y - myPos.y
    local toLen = math.sqrt(toX * toX + toY * toY)
    if toLen < 1 then
        return 1, 0
    end
    toX, toY = toX / toLen, toY / toLen

    local forward = Entity.GetForwardPosition(me, 250)
    if not forward then
        return -1, 999
    end

    local fx = forward.x - myPos.x
    local fy = forward.y - myPos.y
    local flen = math.sqrt(fx * fx + fy * fy)
    if flen < 0.001 then
        return -1, 999
    end
    fx, fy = fx / flen, fy / flen

    local dot = fx * toX + fy * toY
    if dot > 1 then
        dot = 1
    elseif dot < -1 then
        dot = -1
    end

    return dot, math.deg(math.acos(dot))
end

--- Facing gate: rotation + forward must both aim at the enemy (GetTimeToFace alone is too loose).
local function GetHarpoonFacingInfo(me, harpoonTarget, targetPos)
    local rotAngle = GetFacingAngleTo(me, targetPos)
    local forwardDot, forwardAngle = GetForwardDotTo(me, targetPos)

    local timeToFace = 999.0
    if harpoonTarget then
        timeToFace = tonumber(NPC.GetTimeToFace(me, harpoonTarget)) or 999.0
    elseif targetPos then
        timeToFace = tonumber(NPC.GetTimeToFacePosition(me, targetPos)) or 999.0
    end

    local facing = rotAngle <= FORCE_FACE_MAX_ANGLE
        and forwardAngle <= FORCE_FACE_MAX_ANGLE
        and timeToFace <= FORCE_FACE_MAX_TURN_TIME

    return facing, rotAngle, forwardAngle, timeToFace
end

local function TryForceForHarpoonGap(me, harpoon, harpoonTarget, mana, now)
    if not harpoonTarget or not CanAct(me) then
        return false
    end

    if Runtime.forcePending then
        if now >= Runtime.forcePendingTime + FORCE_SETTLE then
            Runtime.forcePending = false
            Runtime.forceUsed = true
            Runtime.forceFaceStarted = false
            Runtime.forceFaceOkSince = nil
            Dbg("approach force settle done")
            return false
        end
        return true
    end

    if Runtime.forceUsed or not IsUseForceEnabled() then
        return false
    end

    if CanCastHarpoonNow(me, harpoonTarget, harpoon, mana) then
        return false
    end

    local force, forceName = GetForceItem(me, mana)
    if not force then
        return false
    end

    local dist = GetHarpoonDist(me, harpoonTarget)
    local harpoonRange = GetHarpoonCastRange(me, harpoon)
    local forceReach = harpoonRange + FORCE_PUSH_DISTANCE - FORCE_HARPOON_MARGIN

    -- Too far for one Force push to enter range — keep walking until within forceReach.
    if dist > forceReach then
        Runtime.forceFaceOkSince = nil
        return false
    end

    -- Already close enough that Force is unnecessary / would overshoot badly.
    if dist <= harpoonRange then
        Runtime.forceFaceOkSince = nil
        return false
    end

    local targetPos = Entity.GetAbsOrigin(harpoonTarget)
    if not targetPos then
        return false
    end

    local facing, rotAngle, forwardAngle, timeToFace = GetHarpoonFacingInfo(me, harpoonTarget, targetPos)
    if not facing then
        Runtime.forceFaceOkSince = nil
        if now - Runtime.lastApproachMove >= APPROACH_MOVE_INTERVAL then
            Runtime.lastApproachMove = now
            NPC.MoveTo(me, targetPos, false, false, false, true, ORDER_ID .. ".force_harpoon_face", false)
            Runtime.forceFaceStarted = true
            Dbg(
                "approach force wait face | rot=%.0f fwd=%.0f ttf=%.3f dist=%.0f",
                rotAngle,
                forwardAngle,
                timeToFace,
                dist
            )
        end
        return true
    end

    -- Hold facing briefly so we don't cast mid-turn when angle flickers into range.
    if not Runtime.forceFaceOkSince then
        Runtime.forceFaceOkSince = now
        if now - Runtime.lastApproachMove >= APPROACH_MOVE_INTERVAL then
            Runtime.lastApproachMove = now
            NPC.MoveTo(me, targetPos, false, false, false, true, ORDER_ID .. ".force_harpoon_face", false)
        end
        Dbg(
            "approach force face lock | rot=%.0f fwd=%.0f ttf=%.3f",
            rotAngle,
            forwardAngle,
            timeToFace
        )
        return true
    end

    if now - Runtime.forceFaceOkSince < FORCE_FACE_STABLE then
        return true
    end

    -- Re-check on the cast tick — facing can drift while we waited.
    facing, rotAngle, forwardAngle, timeToFace = GetHarpoonFacingInfo(me, harpoonTarget, targetPos)
    if not facing then
        Runtime.forceFaceOkSince = nil
        Dbg(
            "approach force face lost | rot=%.0f fwd=%.0f ttf=%.3f",
            rotAngle,
            forwardAngle,
            timeToFace
        )
        return true
    end

    Ability.CastTarget(force, me, false, true, true, OrderTag("approach", forceName or "force"))
    Runtime.forcePending = true
    Runtime.forcePendingTime = now
    Runtime.forceFaceStarted = false
    Runtime.forceFaceOkSince = nil
    Runtime.forceUsed = true
    Dbg(
        "CAST approach | %s self | facing ok rot=%.0f fwd=%.0f | dist=%.0f harpoon=%.0f",
        forceName or "force",
        rotAngle,
        forwardAngle,
        dist,
        harpoonRange
    )
    return true
end

local function TryApproachHarpoonTarget(me, harpoon, harpoonTarget, now, mana, force)
    if not CanAct(me) then
        return false
    end

    if Runtime.forcePending then
        return TryForceForHarpoonGap(me, harpoon, harpoonTarget, mana, now)
    end

    if TryForceForHarpoonGap(me, harpoon, harpoonTarget, mana, now) then
        return true
    end

    if not force and CanCastHarpoonNow(me, harpoonTarget, harpoon, mana) then
        return false
    end

    if now - Runtime.lastApproachMove < APPROACH_MOVE_INTERVAL then
        return true
    end

    Runtime.lastApproachMove = now
    local movePos = GetHarpoonApproachPosition(me, harpoonTarget, harpoon)
    if not movePos then
        return true
    end

    NPC.MoveTo(me, movePos, false, false, false, true, ORDER_ID .. ".approach", false)
    Dbg(
        "approach | dist=%.0f range=%.0f stop=%.0f",
        GetHarpoonDist(me, harpoonTarget),
        GetHarpoonCastRange(me, harpoon),
        (movePos - Entity.GetAbsOrigin(me)):Length2D()
    )
    return true
end

local function GetEnemyHeroes(me, scanRadius, now)
    local raw = Entity.GetHeroesInRadius(me, scanRadius, Enum.TeamType.TEAM_ENEMY, true, true) or {}
    local enemies = {}

    for _, enemy in ipairs(raw) do
        if IsValidHero(enemy) and IsEnemyVisibleForCombo(enemy) then
            enemies[#enemies + 1] = enemy
        end
    end

    UpdateUnitMotionCache(enemies, now)
    return enemies
end

local function GetHarpoonPullRatio(myPos, harpoonPos)
    local dist = (harpoonPos - myPos):Length2D()
    if dist <= 0 then
        return HARPOON_PULL_MIN_RATIO
    end

    local pullDist = math.min(dist * HARPOON_PULL_DIST_FACTOR, HARPOON_PULL_MAX_DIST)
    local ratio = pullDist / dist
    return math.max(HARPOON_PULL_MIN_RATIO, math.min(HARPOON_PULL_MAX_RATIO, ratio))
end

local function PredictMagnusPostHarpoon(myPos, harpoonPos)
    return Lerp3(myPos, harpoonPos, MAGNUS_PULL_RATIO)
end

local function PredictPostHarpoonPositions(harpoonTarget, harpoonPos, myPos, enemies, leadTime)
    leadTime = leadTime or PREDICT_LEAD_HARPOON
    local predicted = {}
    local pullRatio = GetHarpoonPullRatio(myPos, harpoonPos)
    local pulledTarget = Lerp3(harpoonPos, myPos, pullRatio)

    for _, enemy in ipairs(enemies) do
        if IsValidHero(enemy) and IsEnemyVisibleForCombo(enemy) then
            local pos = GetPredictedEnemyPos(enemy, leadTime) or Entity.GetAbsOrigin(enemy)
            if enemy == harpoonTarget then
                predicted[#predicted + 1] = { unit = enemy, pos = pulledTarget }
            else
                predicted[#predicted + 1] = {
                    unit = enemy,
                    pos = Lerp3(pos, pulledTarget, CLUSTER_MERGE_RATIO),
                }
            end
        end
    end

    return predicted
end

local function BuildActualPullPredicted(harpoonTarget, enemies, leadTime)
    leadTime = leadTime or PREDICT_LEAD_RECOVERY
    local predicted = {}
    local pulledPos = GetPredictedEnemyPos(harpoonTarget, leadTime) or Entity.GetAbsOrigin(harpoonTarget)
    if not pulledPos then
        return predicted
    end

    for _, enemy in ipairs(enemies) do
        if IsValidHero(enemy) then
            local pos = GetPredictedEnemyPos(enemy, leadTime) or Entity.GetAbsOrigin(enemy)
            if pos then
                if enemy == harpoonTarget then
                    predicted[#predicted + 1] = { unit = enemy, pos = pulledPos }
                else
                    predicted[#predicted + 1] = {
                        unit = enemy,
                        pos = Lerp3(pos, pulledPos, CLUSTER_MERGE_RATIO),
                    }
                end
            end
        end
    end

    return predicted
end

local function GetPredictedPosForUnit(predicted, unit, fallback)
    if predicted then
        for _, entry in ipairs(predicted) do
            if entry.unit == unit then
                return entry.pos
            end
        end
    end
    return fallback
end

local function GetClusterFocusPos(predicted, fallback)
    if not predicted or #predicted == 0 then
        return fallback
    end

    local sumX, sumY, sumZ = 0, 0, fallback.z
    for _, entry in ipairs(predicted) do
        sumX = sumX + entry.pos.x
        sumY = sumY + entry.pos.y
        sumZ = sumZ + entry.pos.z
    end

    local count = #predicted
    return Vector(sumX / count, sumY / count, sumZ / count)
end

local function CountPredictedHits(origin, predicted, radius)
    local count = 0

    for _, entry in ipairs(predicted) do
        if not entry.unit or not IsMagicImmuneForRP(entry.unit) then
            local effectiveRadius = entry.unit and GetEffectiveRPRadius(entry.unit, radius) or radius
            if (entry.pos - origin):Length2D() <= effectiveRadius then
                count = count + 1
            end
        end
    end

    return count
end

local function GetBlinkOrigin(myPos, harpoonPos, usePrediction)
    if usePrediction and CONFIG.predictPull then
        return PredictMagnusPostHarpoon(myPos, harpoonPos)
    end
    return myPos
end

local function RotateDir2D(dx, dy, angleRad)
    local cosA = math.cos(angleRad)
    local sinA = math.sin(angleRad)
    return dx * cosA - dy * sinA, dx * sinA + dy * cosA
end

local function ComputeBlinkPosition(myPos, focusPos, predicted, rpRadius, blinkRange)
    if not focusPos then
        return Vector(myPos.x, myPos.y, myPos.z), predicted
    end

    local dx = focusPos.x - myPos.x
    local dy = focusPos.y - myPos.y
    local baseLen = math.sqrt(dx * dx + dy * dy)

    if baseLen < 1 then
        return Vector(myPos.x, myPos.y, myPos.z), predicted
    end

    dx = dx / baseLen
    dy = dy / baseLen

    local clusterDist = baseLen
    local maxDist = math.max(MIN_BLINK_DIST_FROM_ME, blinkRange - BLINK_RANGE_MARGIN)
    local behindMin = CONFIG.blinkBehind and UI.BehindDistance:Get() or 0
    local minDist = CONFIG.blinkBehind
        and math.max(MIN_BLINK_DIST_FROM_ME, clusterDist + behindMin)
        or math.max(MIN_BLINK_DIST_FROM_ME, math.min(clusterDist, maxDist))

    if minDist > maxDist then
        minDist = maxDist
    end

    local function EvaluateDirection(dirX, dirY)
        local posAtMin = Vector(
            myPos.x + dirX * minDist,
            myPos.y + dirY * minDist,
            myPos.z
        )
        local bestPos = nil
        local bestHits = -1
        local bestDist = minDist

        local function ConsiderPosition(pos, dist)
            if not IsBlinkPositionTraversable(myPos, pos) then
                return
            end

            local hits = CountPredictedHits(pos, predicted, rpRadius)
            if hits > bestHits or (hits == bestHits and (not bestPos or dist > bestDist)) then
                bestHits = hits
                bestPos = pos
                bestDist = dist
            end
        end

        ConsiderPosition(posAtMin, minDist)

        for dist = maxDist, minDist, -BLINK_SCAN_STEP do
            ConsiderPosition(
                Vector(
                    myPos.x + dirX * dist,
                    myPos.y + dirY * dist,
                    myPos.z
                ),
                dist
            )
        end

        if not bestPos then
            bestPos = posAtMin
            bestHits = CountPredictedHits(posAtMin, predicted, rpRadius)
        end

        return bestPos, bestHits, bestDist
    end

    local bestPos, bestHits, bestDist = EvaluateDirection(dx, dy)

    for angle = BLINK_ANGLE_STEP, BLINK_ANGLE_MAX, BLINK_ANGLE_STEP do
        local rad = math.rad(angle)
        for _, sign in ipairs({ -1, 1 }) do
            local dirX, dirY = RotateDir2D(dx, dy, rad * sign)
            local dirLen = math.sqrt(dirX * dirX + dirY * dirY)
            if dirLen > 0.001 then
                dirX = dirX / dirLen
                dirY = dirY / dirLen
                local pos, hits, dist = EvaluateDirection(dirX, dirY)
                if hits > bestHits or (hits == bestHits and dist > bestDist) then
                    bestHits = hits
                    bestPos = pos
                    bestDist = dist
                end
            end
        end
    end

    return bestPos, predicted
end

local function BuildBlinkPlan(blinkOrigin, predicted, focusPos, blinkRange, rpRadius)
    local blinkPos = ComputeBlinkPosition(blinkOrigin, focusPos, predicted, rpRadius, blinkRange)
    local distFromMe = (blinkPos - blinkOrigin):Length2D()
    local rpHits = CountPredictedHits(blinkPos, predicted, rpRadius)

    return {
        blinkPos = blinkPos,
        distFromMe = distFromMe,
        rpHits = rpHits,
        predicted = predicted,
        focusPos = focusPos,
    }
end

local function EvaluateBlinkPlan(me, harpoonTarget, enemies, blinkOrigin, focusUnit, blinkRange, rpRadius, predictedOverride, focusPosOverride)
    local castPos = Entity.GetAbsOrigin(me)
    local harpoonPos = Entity.GetAbsOrigin(harpoonTarget)
    local predicted = predictedOverride
        or PredictPostHarpoonPositions(harpoonTarget, harpoonPos, castPos, enemies)
    local origin = blinkOrigin or castPos

    local focusPos = focusPosOverride
    if not focusPos then
        focusPos = GetPredictedPosForUnit(predicted, focusUnit, harpoonPos)
        if not CONFIG.predictPull and focusUnit then
            focusPos = Entity.GetAbsOrigin(focusUnit) or harpoonPos
        end
    end

    return BuildBlinkPlan(origin, predicted, focusPos, blinkRange, rpRadius)
end

local function IsBlinkPlanValid(plan, blinkRange, minRPHits)
    if not plan then
        return false
    end

    return plan.distFromMe >= MIN_BLINK_DIST_FROM_ME
        and plan.rpHits >= minRPHits
        and (not CONFIG.requireBlinkRange or plan.distFromMe <= blinkRange)
end

local function BuildTargetsFromPlan(harpoonTarget, blinkTarget, plan, harpoonDist, sepDist)
    return {
        harpoonTarget = harpoonTarget,
        blinkTarget = blinkTarget,
        blinkPos = plan.blinkPos,
        hitCount = plan.rpHits,
        harpoonDist = harpoonDist,
        blinkDist = plan.distFromMe or plan.blinkDist or 0,
        sepDist = sepDist or 0,
    }
end

local function FindSoloBlinkPlan(me, harpoonTarget, blinkRange, rpRadius, minRPHits)
    local myPos = Entity.GetAbsOrigin(me)
    local blinkOrigin = GetBlinkOrigin(myPos, Entity.GetAbsOrigin(harpoonTarget), true)
    local plan = EvaluateBlinkPlan(
        me,
        harpoonTarget,
        { harpoonTarget },
        blinkOrigin,
        harpoonTarget,
        blinkRange,
        rpRadius
    )

    if not IsBlinkPlanValid(plan, blinkRange, minRPHits) then
        return nil
    end

    return {
        enemy = nil,
        blinkPos = plan.blinkPos,
        distFromMe = plan.distFromMe,
        sepDist = 0,
        rpHits = plan.rpHits,
    }
end

local function FindBestBlinkTarget(me, harpoonTarget, enemies, blinkRange, rpRadius, minSep, minRPHits)
    local myPos = Entity.GetAbsOrigin(me)
    local harpoonPos = Entity.GetAbsOrigin(harpoonTarget)
    local minSeparation = EffectiveMinSep(#enemies, minSep)
    local blinkOrigin = GetBlinkOrigin(myPos, harpoonPos, true)
    local predicted = PredictPostHarpoonPositions(harpoonTarget, harpoonPos, myPos, enemies)
    local clusterFocus = GetClusterFocusPos(predicted, harpoonPos)
    local pulledHarpoonPos = GetPredictedPosForUnit(predicted, harpoonTarget, harpoonPos)
    local clusterPlan = BuildBlinkPlan(blinkOrigin, predicted, clusterFocus, blinkRange, rpRadius)
    local best = nil

    for _, enemy in ipairs(enemies) do
        if enemy ~= harpoonTarget and IsValidHero(enemy) then
            local anchorPos = GetPredictedPosForUnit(
                predicted,
                enemy,
                GetPredictedEnemyPos(enemy, PREDICT_LEAD_HARPOON) or Entity.GetAbsOrigin(enemy)
            )
            local sepDist = (anchorPos - pulledHarpoonPos):Length2D()

            if sepDist >= minSeparation then
                local blendedFocus = Lerp3(clusterFocus, anchorPos, ANCHOR_FOCUS_BLEND)
                local plan = BuildBlinkPlan(blinkOrigin, predicted, blendedFocus, blinkRange, rpRadius)

                if IsBlinkPlanValid(plan, blinkRange, minRPHits) then
                    local candidate = {
                        enemy = enemy,
                        blinkPos = plan.blinkPos,
                        distFromMe = plan.distFromMe,
                        sepDist = sepDist,
                        rpHits = plan.rpHits,
                    }

                    if not best
                        or candidate.rpHits > best.rpHits
                        or (candidate.rpHits == best.rpHits and candidate.sepDist > best.sepDist) then
                        best = candidate
                    end
                end
            end
        end
    end

    if not best and IsBlinkPlanValid(clusterPlan, blinkRange, minRPHits) then
        local fallbackAnchor, fallbackSep = nil, -1

        for _, enemy in ipairs(enemies) do
            if enemy ~= harpoonTarget and IsValidHero(enemy) then
                local anchorPos = GetPredictedPosForUnit(predicted, enemy, Entity.GetAbsOrigin(enemy))
                local sepDist = (anchorPos - pulledHarpoonPos):Length2D()
                if sepDist >= minSeparation and sepDist > fallbackSep then
                    fallbackSep = sepDist
                    fallbackAnchor = enemy
                end
            end
        end

        if fallbackAnchor then
            best = {
                enemy = fallbackAnchor,
                blinkPos = clusterPlan.blinkPos,
                distFromMe = clusterPlan.distFromMe,
                sepDist = fallbackSep,
                rpHits = clusterPlan.rpHits,
            }
        end
    end

    return best
end

local function RefreshRecoveryTargets(me, locked, harpoon, blink, rp, mana, now)
    if not locked or not locked.harpoonTarget then
        return locked
    end

    local harpoonTarget = locked.harpoonTarget
    if not IsValidHero(harpoonTarget) then
        return nil
    end

    local myPos = Entity.GetAbsOrigin(me)
    local harpoonPos = Entity.GetAbsOrigin(harpoonTarget)
    if not myPos or not harpoonPos then
        return locked
    end

    local blinkRange = GetItemCastRange(me, blink, nil)
    local rpRadius = GetRPRadius(rp)
    local scanRadius = GetHarpoonCastRange(me, harpoon) + blinkRange + rpRadius + SCAN_RADIUS_BUFFER
    local enemies = GetEnemyHeroes(me, scanRadius, now)
    local minRPHits = UI.MinRPHits:Get() or 2
    local blinkOrigin = myPos
    local focusUnit = locked.blinkTarget
    local sepDist = locked.sepDist or 0

    if focusUnit and (not IsValidHero(focusUnit) or not IsEnemyVisibleForCombo(focusUnit)) then
        focusUnit = nil
    end

    if #enemies >= 2 then
        if focusUnit and focusUnit ~= harpoonTarget then
            local plan = EvaluateBlinkPlan(
                me,
                harpoonTarget,
                enemies,
                blinkOrigin,
                focusUnit,
                blinkRange,
                rpRadius
            )
            if IsBlinkPlanValid(plan, blinkRange, minRPHits) then
                local anchorPos = GetPredictedPosForUnit(plan.predicted, focusUnit, Entity.GetAbsOrigin(focusUnit))
                sepDist = anchorPos and (anchorPos - harpoonPos):Length2D() or sepDist
                Dbg(
                    "recovery refresh anchor | hits=%d dist=%.0f pos=(%.0f,%.0f)",
                    plan.rpHits,
                    plan.distFromMe,
                    plan.blinkPos.x,
                    plan.blinkPos.y
                )
                return BuildTargetsFromPlan(
                    harpoonTarget,
                    focusUnit,
                    plan,
                    GetHarpoonDist(me, harpoonTarget),
                    sepDist
                )
            end
        end

        local best = FindBestBlinkTarget(
            me,
            harpoonTarget,
            enemies,
            blinkRange,
            rpRadius,
            UI.MinSep:Get(),
            minRPHits
        )
        if best then
            Dbg(
                "recovery refresh | hits=%d dist=%.0f pos=(%.0f,%.0f)",
                best.rpHits,
                best.distFromMe,
                best.blinkPos.x,
                best.blinkPos.y
            )
            return BuildTargetsFromPlan(
                harpoonTarget,
                best.enemy,
                best,
                GetHarpoonDist(me, harpoonTarget),
                best.sepDist
            )
        end

        Dbg("recovery refresh invalid | no valid anchor plan")
        return locked
    end

    if CONFIG.soloMode then
        local solo = FindSoloBlinkPlan(me, harpoonTarget, blinkRange, rpRadius, minRPHits)
        if solo then
            return BuildTargetsFromPlan(
                harpoonTarget,
                nil,
                solo,
                GetHarpoonDist(me, harpoonTarget),
                0
            )
        end
    end

    Dbg("recovery refresh invalid | enemies=%d", #enemies)
    return locked
end

local function TryRefreshMidComboTargets(me, harpoon, blink, rp, mana, now)
    local locked = Runtime.lockedTargets
    if not locked or not Runtime.harpoonAttempted or Runtime.blinkRpSent then
        return nil
    end

    if now - Runtime.lastTargetResolve < TARGET_RESOLVE_INTERVAL then
        return nil
    end

    Runtime.lastTargetResolve = now

    local harpoonTarget = locked.harpoonTarget
    if not harpoonTarget or not IsValidHero(harpoonTarget) then
        Dbg("mid-combo abort | harpoon target lost")
        return false
    end

    if not IsEnemyVisibleForCombo(harpoonTarget) or not CanHarpoonTarget(harpoonTarget) then
        Dbg("mid-combo abort | harpoon target invalid")
        return false
    end

    local refreshed = RefreshRecoveryTargets(me, locked, harpoon, blink, rp, mana, now)
    if not refreshed then
        Dbg("mid-combo abort | refresh returned nil")
        return false
    end

    if refreshed.blinkPos ~= locked.blinkPos or refreshed.hitCount ~= locked.hitCount then
        Dbg(
            "mid-combo refresh | hits %d->%d | anchor=%s",
            locked.hitCount or 0,
            refreshed.hitCount or 0,
            refreshed.blinkTarget and "yes" or "solo"
        )
    end

    return refreshed
end

local function ResolveComboTargets(me, harpoon, blink, rp, debugReason, now)
    local harpoonRange = GetHarpoonCastRange(me, harpoon)
    local blinkRange = GetItemCastRange(me, blink, nil)
    local rpRadius = GetRPRadius(rp)
    local scanRadius = harpoonRange + blinkRange + rpRadius + SCAN_RADIUS_BUFFER

    local harpoonTarget = ResolveHarpoonTarget(me, debugReason)
    if not harpoonTarget then
        return nil
    end

    local harpoonDist = GetHarpoonDist(me, harpoonTarget)
    local harpoonReach = GetHarpoonForceReach(me, harpoon)
    if harpoonDist > harpoonReach then
        debugReason[1] = string.format(
            "harpoon target too far (%.0f > %.0f%s)",
            harpoonDist,
            harpoonRange,
            harpoonReach > harpoonRange and string.format(" forceReach=%.0f", harpoonReach) or ""
        )
        return nil
    end

    local enemies = GetEnemyHeroes(me, scanRadius, now)
    if #enemies < 2 then
        if CONFIG.soloMode and harpoonTarget then
            local solo = FindSoloBlinkPlan(
                me,
                harpoonTarget,
                blinkRange,
                rpRadius,
                UI.MinRPHits:Get()
            )
            if solo then
                debugReason[1] = "ok (solo)"
                return BuildTargetsFromPlan(harpoonTarget, nil, solo, harpoonDist, 0)
            end
        end
        debugReason[1] = string.format("need 2 enemies, found %d", #enemies)
        return nil
    end

    local best = FindBestBlinkTarget(
        me,
        harpoonTarget,
        enemies,
        blinkRange,
        rpRadius,
        UI.MinSep:Get(),
        UI.MinRPHits:Get()
    )

    if not best then
        debugReason[1] = string.format(
            "no blink target (sep>=%d hits>=%d enemies=%d)",
            EffectiveMinSep(#enemies, UI.MinSep:Get()),
            UI.MinRPHits:Get(),
            #enemies
        )
        return nil
    end

    debugReason[1] = harpoonDist > harpoonRange and "ok (approach force)" or "ok"
    return BuildTargetsFromPlan(
        harpoonTarget,
        best.enemy,
        best,
        harpoonDist,
        best.sepDist
    )
end

local function IsComboReady(me, mana, harpoon, blink, rp, targets)
    return targets
        and CanAct(me)
        and Ability.IsCastable(harpoon, mana) == true
        and Ability.IsCastable(blink, mana) == true
        and Ability.IsCastable(rp, mana) == true
end

local function IsHarpoonConfirmed(harpoonTarget, harpoon, mana)
    if Ability.IsInAbilityPhase(harpoon) then
        return false
    end

    if Ability.IsCastable(harpoon, mana) ~= true then
        return true
    end

    if Runtime.harpoonCastPos and harpoonTarget then
        local pos = Entity.GetAbsOrigin(harpoonTarget)
        if pos and (pos - Runtime.harpoonCastPos):Length2D() >= HARPOON_CONFIRM_MIN_MOVE then
            return true
        end
    end

    return false
end

local function TryPopLinkens(me, target, mana, now)
    if not CONFIG.popLinkens or not TargetNeedsLinkBreak(target) then
        Runtime.linkBreakPending = false
        return false
    end

    if Runtime.linkBreakPending then
        if now - Runtime.linkBreakAttemptTime >= LINK_BREAK_VERIFY then
            if not TargetNeedsLinkBreak(target) then
                Runtime.linkBreakPending = false
                Dbg("linken's popped")
                return false
            end
        end
        return true
    end

    if now - Runtime.lastLinkBreakCast < LINK_BREAK_CAST_INTERVAL then
        return true
    end

    local popItem, popName = FindPopItem(me, target, mana)
    if not popItem then
        return false
    end

    Ability.CastTarget(popItem, target, false, true, true, OrderTag("linkbreak", popName or "pop"))
    Runtime.linkBreakPending = true
    Runtime.linkBreakAttemptTime = now
    Runtime.lastLinkBreakCast = now
    Dbg("CAST link break | %s", popName or "pop")
    return true
end

local function ResolveComboTargetsThrottled(me, harpoon, blink, rp, debugReason, now, force, interval)
    interval = interval or TARGET_RESOLVE_INTERVAL
    if not force and now - Runtime.lastTargetResolve < interval then
        return Runtime.lockedTargets or Runtime.overlayTargets
    end

    Runtime.lastTargetResolve = now
    return ResolveComboTargets(me, harpoon, blink, rp, debugReason, now)
end

--#endregion

--#region Casting

local function CastHarpoonStep(targets, harpoon)
    Runtime.harpoonCastPos = Entity.GetAbsOrigin(targets.harpoonTarget)
    Ability.CastTarget(harpoon, targets.harpoonTarget, false, true, true, OrderTag("harpoon", "cast"))
    Dbg(
        "CAST harpoon | hits=%d dist=%.0f",
        targets.hitCount,
        targets.harpoonDist
    )
end

local function CastBlinkStep(targets, blink, tag, now, blinkName)
    Runtime.pendingBlinkName = blinkName
    Ability.CastPosition(blink, targets.blinkPos, false, true, true, OrderTag(tag, "blink"), true)
    Runtime.blinkPending = true
    Runtime.blinkPendingTime = now
    Dbg("CAST %s | blink setup | hits=%d pos=(%.0f,%.0f)", tag, targets.hitCount, targets.blinkPos.x, targets.blinkPos.y)
end

local function TryChainRPAfterBlink(targets, rp, mana, now, tag)
    if not Runtime.blinkPending then
        return false
    end

    if now < Runtime.blinkPendingTime + GetBlinkSettleTime(Runtime.pendingBlinkName) then
        return true
    end

    if Ability.IsInAbilityPhase(rp) then
        return true
    end

    if Ability.IsCastable(rp, mana) == true then
        Ability.CastNoTarget(rp, false, true, true, OrderTag(tag, "rp"))
        Runtime.blinkPending = false
        Runtime.blinkRpSent = true
        Dbg("CAST %s | rp after blink | hits=%d", tag, targets.hitCount)
        return true
    end

    if now - Runtime.blinkPendingTime > COMBO_BLINK_RP_TIMEOUT then
        Runtime.blinkPending = false
        Dbg("%s | rp after blink timeout", tag)
        return false
    end

    return true
end

local function CanAttemptRecovery(elapsed, allowLate)
    if elapsed < RECOVERY_MIN_DELAY then
        return false
    end
    if allowLate then
        return elapsed <= LATE_RECOVERY_MAX_TIME
    end
    return elapsed <= COMBO_RECOVERY_TIME
end

local function TryFinishCombo(me, activeTargets, harpoon, blink, rp, mana, elapsed, tag, now, blinkName)
    if Runtime.blinkRpSent then
        return false
    end

    if Runtime.blinkPending then
        local targets = Runtime.lockedTargets or activeTargets
        if TryChainRPAfterBlink(targets, rp, mana, now, tag) then
            return true
        end
    end

    local allowLate = tag == "late-recovery"
    if not CanAttemptRecovery(elapsed, allowLate) then
        return false
    end

    if not IsHarpoonConfirmed(activeTargets.harpoonTarget, harpoon, mana) then
        return false
    end

    local blinkReady = Ability.IsCastable(blink, mana) == true
    local rpReady = Ability.IsCastable(rp, mana) == true
    local baseTargets = Runtime.lockedTargets or activeTargets
    local targets = RefreshRecoveryTargets(me, baseTargets, harpoon, blink, rp, mana, now) or baseTargets

    if targets ~= baseTargets then
        Runtime.lockedTargets = targets
    end

    if not blinkReady and not rpReady then
        Dbg("%s skipped | full combo landed", tag)
        Runtime.blinkRpSent = true
        Runtime.blinkPending = false
        return true
    end

    if blinkReady and rpReady and not Runtime.blinkPending then
        CastBlinkStep(targets, blink, tag, now, blinkName)
        return true
    end

    if rpReady and not blinkReady then
        Runtime.blinkRpSent = true
        Ability.CastNoTarget(rp, false, true, true, OrderTag(tag .. "-rp", "rp"))
        Dbg("CAST %s | rp only", tag)
        return true
    end

    if blinkReady and not rpReady and not Runtime.blinkPending then
        Runtime.blinkRpSent = true
        CastBlinkStep(targets, blink, tag .. "-blink", now, blinkName)
        Dbg("CAST %s | blink only", tag)
        return true
    end

    return Runtime.blinkPending
end

--#endregion

--#region Overlay

local OverlayTheme = {
    route = Color(120, 190, 255, 210),
    routeGlow = Color(120, 190, 255, 45),
    blink = Color(255, 196, 72, 220),
    rpRing = Color(255, 92, 92, 170),
    text = Color(235, 240, 255, 235),
    pillBg = Color(18, 22, 32, 188),
    pillBorder = Color(120, 190, 255, 90),
}

local function EnsureOverlayFont()
    if Persistent.overlayFont ~= 0 then
        return
    end

    Persistent.overlayFont = Render.LoadFont("Segoe UI", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500) or 0
    if Persistent.overlayFont == 0 then
        Persistent.overlayFont = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500) or 0
    end
end

local function DrawOverlayLine(from, to, coreColor, glowColor, coreWidth, glowWidth)
    if glowWidth and glowWidth > 0 then
        Render.Line(from, to, glowColor, glowWidth)
    end
    Render.Line(from, to, coreColor, coreWidth or 2)
end

local function DrawWorldRing(worldPos, radius, color, segments)
    segments = segments or 24
    local prevScreen, prevVisible = nil, false

    for i = 0, segments do
        local angle = (i / segments) * math.pi * 2
        local point = Vector(
            worldPos.x + math.cos(angle) * radius,
            worldPos.y + math.sin(angle) * radius,
            worldPos.z
        )
        local screen, visible = WorldToScreen(point)
        if visible and prevVisible then
            DrawOverlayLine(prevScreen, screen, color, Color(color.r, color.g, color.b, 35), 2, 5)
        end
        prevScreen = screen
        prevVisible = visible
    end
end

local function DrawOverlayMarker(screen, color, pulse, radius)
    local ring = radius + math.sin(pulse) * 1.5
    Render.Circle(screen, ring + 6, Color(color.r, color.g, color.b, 40), 2)
    Render.Circle(screen, ring, color, 2)
    Render.FilledCircle(screen, math.max(3, radius * 0.35), Color(color.r, color.g, color.b, 220))
end

local function DrawOverlayPill(screen, text, pulse)
    if Persistent.overlayFont == 0 then
        return
    end

    local textSize = Render.TextSize(Persistent.overlayFont, 13, text) or Vec2(72, 16)
    local padX, padY = 10, 5
    local width = textSize.x + padX * 2
    local height = textSize.y + padY * 2
    local topLeft = Vec2(screen.x + 18, screen.y - height * 0.5 - 8)
    local bottomRight = Vec2(topLeft.x + width, topLeft.y + height)

    Render.FilledRect(topLeft, bottomRight, OverlayTheme.pillBg, 6)
    Render.Rect(topLeft, bottomRight, OverlayTheme.pillBorder, 6, 0, 1)
    Render.FilledRect(topLeft, Vec2(topLeft.x + width, topLeft.y + 2), Color(OverlayTheme.route.r, OverlayTheme.route.g, OverlayTheme.route.b, math.floor(55 + 25 * math.sin(pulse * 1.2))), 6)
    Render.Text(Persistent.overlayFont, 13, text, Vec2(topLeft.x + padX, topLeft.y + padY - 1), OverlayTheme.text)
end

--#endregion

--#region Lifecycle

function Script.OnScriptsLoaded()
    Persistent.logger = Logger(SCRIPT_NAME)
    InitializeUI()
    LogWrite(string.format(
        "loaded | enable=%s debug=%s key=%s",
        tostring(UI.Enabled and UI.Enabled:Get()),
        tostring(UI.Debug and UI.Debug:Get()),
        tostring(UI.ComboKey and UI.ComboKey:Get())
    ))
end

function Script.OnPrepareUnitOrders(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)
    local dataTable = type(data) == "table" and data or nil
    local identifier = dataTable and dataTable.identifier or nil
    local isScriptOrder = type(identifier) == "string" and identifier:find(ORDER_ID, 1, true) == 1

    if UI.Debug and UI.Debug:Get() == true and ability then
        local abilityName = GetAbilityName(ability)
        if IsComboDebugAbility(abilityName) then
            local targetName = target and Entity.GetUnitName(target) or "nil"
            Dbg(
                "order=%s ability=%s queue=%s script=%s combo=%s pending=%s pos=%s target=%s id=%s",
                tostring(order),
                abilityName,
                tostring(queue),
                tostring(isScriptOrder),
                tostring(Runtime.harpoonAttempted),
                tostring(Runtime.blinkPending),
                position and string.format("(%.0f,%.0f)", position.x, position.y) or "nil",
                targetName,
                tostring(identifier)
            )
        end
    end

    return true
end

function Script.OnUpdate()
    if not UI.Enabled or UI.Enabled:Get() ~= true then
        return
    end

    if not Engine.IsInGame() then
        return
    end

    local now = Now()

    if Input.IsInputCaptured() then
        if Runtime.harpoonAttempted then
            PauseComboTimer(now)
        end
        return
    end

    if not IsComboKeyHeld() then
        ResetHoldState()
        return
    end

    local me = Heroes.GetLocal()
    if not me or NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end

    if not CanAct(me) then
        if Runtime.harpoonAttempted then
            PauseComboTimer(now)
        end
        return
    end

    ResumeComboTimer(now)

    local mana = NPC.GetMana(me) or 0
    local harpoon = NPC.GetItem(me, HARPOON_NAME, true)
    local blink, blinkName = GetBlink(me)
    local rp = NPC.GetAbility(me, RP_NAME)

    if not harpoon or not blink or not rp then
        Runtime.overlayTargets = nil
        Runtime.overlayReason = "missing items/ability"
        Dbg("missing items/ability | harpoon=%s blink=%s rp=%s", tostring(harpoon ~= nil), tostring(blink ~= nil), tostring(rp ~= nil))
        return
    end

    local forceResolve = not Runtime.harpoonAttempted and not Runtime.comboDone
    local resolveInterval = (Runtime.comboDone or Ability.IsCastable(harpoon, mana) ~= true)
        and PREVIEW_RESOLVE_INTERVAL
        or TARGET_RESOLVE_INTERVAL

    local debugReason = { "" }
    local targets = ResolveComboTargetsThrottled(
        me, harpoon, blink, rp, debugReason, now, forceResolve, resolveInterval
    )
    local comboReady = IsComboReady(me, mana, harpoon, blink, rp, targets)
    local rpRadius = GetRPRadius(rp)

    Runtime.overlayTargets = Runtime.lockedTargets or targets
    Runtime.overlayReason = debugReason[1]
    Runtime.overlayRpRadius = rpRadius

    LogHoldState(debugReason[1], me, mana, harpoon, blink, blinkName, rp, targets, comboReady)

    if Runtime.comboDone then
        return
    end

    if Runtime.comboFinishTime > 0
        and CONFIG.repeatWhileHeld
        and now - Runtime.comboFinishTime < COMBO_REPEAT_COOLDOWN then
        return
    end

    local activeTargets = Runtime.lockedTargets or targets

    if not activeTargets then
        local harpoonTarget = ResolveHarpoonTarget(me, nil)
        if harpoonTarget then
            TryApproachHarpoonTarget(me, harpoon, harpoonTarget, now, mana)
        end
        return
    end

    if Runtime.harpoonAttempted then
        local elapsed = now - Runtime.comboAttemptTime

        if Ability.IsInAbilityPhase(harpoon) or Ability.IsInAbilityPhase(blink) or Ability.IsInAbilityPhase(rp) then
            return
        end

        if not Runtime.blinkRpSent and not Runtime.blinkPending then
            local refreshed = TryRefreshMidComboTargets(me, harpoon, blink, rp, mana, now)
            if refreshed == false then
                FinishComboCycle(now)
                return
            elseif refreshed then
                Runtime.lockedTargets = refreshed
                activeTargets = refreshed
                Runtime.overlayTargets = refreshed
            end
        end

        if Runtime.blinkPending then
            TryChainRPAfterBlink(activeTargets, rp, mana, now, "recovery")
        end

        if not Runtime.forcePending
            and not Runtime.blinkPending
            and elapsed >= HARPOON_RETRY_DELAY
            and elapsed >= HARPOON_CAST_GUARD
            and Ability.IsCastable(harpoon, mana) == true
            and not IsHarpoonConfirmed(activeTargets.harpoonTarget, harpoon, mana) then
            Dbg(
                "harpoon retry | dist=%.0f inRange=%s",
                GetHarpoonDist(me, activeTargets.harpoonTarget),
                tostring(IsHarpoonInCastRange(me, activeTargets.harpoonTarget, harpoon))
            )
            if CanCastHarpoonNow(me, activeTargets.harpoonTarget, harpoon, mana) then
                Runtime.harpoonAttempted = true
                Runtime.comboAttemptTime = now
                CastHarpoonStep(activeTargets, harpoon)
            else
                TryApproachHarpoonTarget(me, harpoon, activeTargets.harpoonTarget, now, mana, false)
            end
            return
        end

        if not Runtime.blinkRpSent then
            TryFinishCombo(me, activeTargets, harpoon, blink, rp, mana, elapsed, "recovery", now, blinkName)
        end

        if Runtime.blinkRpSent then
            FinishComboCycle(now)
        elseif Ability.IsCastable(blink, mana) ~= true and Ability.IsCastable(rp, mana) ~= true then
            FinishComboCycle(now)
        elseif elapsed > COMBO_RECOVERY_TIME then
            if not Runtime.blinkRpSent then
                TryFinishCombo(me, activeTargets, harpoon, blink, rp, mana, elapsed, "late-recovery", now, blinkName)
            end
            if Runtime.blinkRpSent or not Runtime.blinkPending then
                FinishComboCycle(now)
            end
        end
        return
    end

    if not IsComboReady(me, mana, harpoon, blink, rp, activeTargets) then
        return
    end

    if TryPopLinkens(me, activeTargets.harpoonTarget, mana, now) then
        return
    end

    if CONFIG.popLinkens and TargetNeedsLinkBreak(activeTargets.harpoonTarget) then
        return
    end

    if not CanCastHarpoonNow(me, activeTargets.harpoonTarget, harpoon, mana) then
        TryApproachHarpoonTarget(me, harpoon, activeTargets.harpoonTarget, now, mana)
        return
    end

    if targets then
        Runtime.lockedTargets = targets
        activeTargets = targets
    end

    Runtime.harpoonAttempted = true
    Runtime.comboAttemptTime = now
    CastHarpoonStep(activeTargets, harpoon)
end

function Script.OnDraw()
    if not UI.Enabled or UI.Enabled:Get() ~= true then
        return
    end
    if not UI.DrawOverlay or UI.DrawOverlay:Get() ~= true then
        return
    end
    if Menu.VisualsIsEnabled() ~= true then
        return
    end
    if not Engine.IsInGame() or not IsComboKeyHeld() then
        return
    end

    local me = Heroes.GetLocal()
    if not me or NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end

    local targets = Runtime.overlayTargets
    if not targets or not targets.blinkPos then
        return
    end

    EnsureOverlayFont()

    local pulse = os.clock() * 3.2
    local myPos = Entity.GetAbsOrigin(me)
    local blinkPos = targets.blinkPos
    if not myPos then
        return
    end

    DrawWorldRing(blinkPos, Runtime.overlayRpRadius, OverlayTheme.rpRing, 28)

    local myScreen, myVisible = WorldToScreen(myPos)
    local blinkScreen, blinkVisible = WorldToScreen(blinkPos)

    if myVisible and blinkVisible then
        DrawOverlayLine(myScreen, blinkScreen, OverlayTheme.route, OverlayTheme.routeGlow, 2, 6)
    end

    if blinkVisible then
        DrawOverlayMarker(blinkScreen, OverlayTheme.blink, pulse, 6)
        local label = string.format(
            "RP hits: %d | %s",
            targets.hitCount or 0,
            Runtime.overlayReason or ""
        )
        DrawOverlayPill(blinkScreen, label, pulse)
    end

    if targets.harpoonTarget then
        local harpoonPos = Entity.GetAbsOrigin(targets.harpoonTarget)
        local harpoonScreen, harpoonVisible = WorldToScreen(harpoonPos)
        if harpoonVisible then
            DrawOverlayMarker(harpoonScreen, OverlayTheme.route, pulse + 1.1, 4)
        end
    end
end

function Script.OnGameEnd()
    ResetRuntime()
end

--#endregion

return Script
