--[[
    Tiny Advanced Toss
    Toss enemies to teammate / tower / fountain with Avalanche, blink/force, and chain double Toss.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local UPDATE_INTERVAL = 0.02
local HERO_NAME = "npc_dota_hero_tiny"
local ABILITY_AVALANCHE = "tiny_avalanche"
local ABILITY_TOSS = "tiny_toss"
local MODIFIER_TOSS = "modifier_tiny_toss"
local GRAB_RADIUS_FALLBACK = 300
local TOSS_DURATION_FALLBACK = 1.25
local AVALANCHE_RANGE_FALLBACK = 600
local TOSS_RANGE_FALLBACK = 800
local BLINK_RANGE = 1200
local FORCE_PUSH = 600
local APPROACH_TIMEOUT = 4.0
local MOVE_THROTTLE = 0.35
local CAST_CONFIRM_TIMEOUT = 0.55
local FOW_ABORT = 1.0
local DEST_SCAN_RADIUS = 4500
local ORDER_ID = "tiny.advtoss"

-- Enum.modifierState is often nil at runtime; integers from Enums.lua
local STATE_INVULNERABLE = 8
local STATE_MAGIC_IMMUNE = 9

local ICON_AVALANCHE = "panorama/images/spellicons/tiny_avalanche_png.vtex_c"
local ICON_TOSS = "panorama/images/spellicons/tiny_toss_png.vtex_c"
local ICON_BLINK = "panorama/images/items/blink_png.vtex_c"
local ICON_TINY = "panorama/images/heroes/icons/npc_dota_hero_tiny_png.vtex_c"

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

local LOC = {
    group = "Advanced Toss",
    enable = "Enable",
    enableTip = "Enable Advanced Toss combo while Toss Key is held.",
    tossKey = "Toss Key",
    tossKeyTip = "Hold to search the enemy near cursor and Toss toward selected destinations.",
    destinations = "Destinations",
    destinationsTip = "Where to Toss the enemy: teammate, tower, or fountain.",
    teammate = "Teammate",
    tower = "Tower",
    fountain = "Fountain",
    settings = "Settings",
    priority = "Priority",
    priorityTip = "Order of destination preference when several options are available.",
    prioAllyTowerFountain = "Ally > Tower > Fountain",
    prioFountainAllyTower = "Fountain > Ally > Tower",
    prioTowerAllyFountain = "Tower > Ally > Fountain",
    useAvalanche = "Use Avalanche",
    useAvalancheTip = "Cast Avalanche before the first Toss when the enemy is in grab range.",
    useBlink = "Use Blink",
    useBlinkTip = "Blink to enemy when 1 Toss reaches ally/tower; after Toss1 for fountain chain Toss2.",
    useForce = "Use Force",
    useForceTip = "Use Force Staff / Hurricane Pike for a short approach into grab range.",
    chainDouble = "Chain Double Toss",
    chainDoubleTip = "Avalanche → Toss → Blink → Toss toward allied fountain only.",
    searchRange = "Enemy Search Range",
    searchRangeTip = "Max distance from you to the cursor enemy used for the combo.",
    fountainNear = "Fountain Near Range",
    fountainNearTip = "If the enemy is within this range of the allied fountain, allow fountain double-Toss chain.",
}

local DEST_MENU = {
    ally = LOC.teammate,
    tower = LOC.tower,
    fountain = LOC.fountain,
}

local PRIORITY_ORDERS = {
    [0] = { "ally", "tower", "fountain" },
    [1] = { "fountain", "ally", "tower" },
    [2] = { "tower", "ally", "fountain" },
}

local PHASE_IDLE = 0
local PHASE_APPROACH = 1
local PHASE_TOSS1 = 2
local PHASE_WAIT_AIR = 3
local PHASE_BLINK_FOLLOW = 4
local PHASE_TOSS2 = 5
--#endregion

--#region State
---@class TinyAdvancedTossUI
---@field enabled CMenuSwitch|nil
---@field tossKey CMenuBind|nil
---@field destinations CMenuMultiComboBox|nil
---@field priority CMenuComboBox|nil
---@field useAvalanche CMenuSwitch|nil
---@field useBlink CMenuSwitch|nil
---@field useForce CMenuSwitch|nil
---@field chainDouble CMenuSwitch|nil
---@field searchRange CMenuSliderInt|nil
---@field fountainNearRange CMenuSliderInt|nil
local UI = {}

---@class TinyAdvancedTossRuntime
---@field lastUpdateAt number
---@field phase integer
---@field phaseStartedAt number
---@field deadline number
---@field enemy userdata|nil
---@field lastSeenAt number
---@field destKind string|nil
---@field destUnit userdata|nil
---@field destPos Vector|nil
---@field destLocked boolean
---@field hopUnit userdata|nil
---@field hopPos Vector|nil
---@field useChain boolean
---@field avalancheIssued boolean
---@field avalancheAt number
---@field toss1Issued boolean
---@field toss1At number
---@field blinkFollowIssued boolean
---@field blinkAt number
---@field blinkItem userdata|nil
---@field lastMoveAt number
local function NewRuntime()
    return {
        lastUpdateAt = -math.huge,
        phase = PHASE_IDLE,
        phaseStartedAt = -math.huge,
        deadline = math.huge,
        enemy = nil,
        lastSeenAt = -math.huge,
        destKind = nil,
        destUnit = nil,
        destPos = nil,
        destLocked = false,
        hopUnit = nil,
        hopPos = nil,
        useChain = false,
        avalancheIssued = false,
        avalancheAt = -math.huge,
        toss1Issued = false,
        toss1At = -math.huge,
        blinkFollowIssued = false,
        blinkAt = -math.huge,
        blinkItem = nil,
        lastMoveAt = -math.huge,
    }
end

local Runtime = NewRuntime()
--#endregion

--#region Helpers
local function ResetRuntime()
    local fresh = NewRuntime()
    for key, value in pairs(fresh) do
        Runtime[key] = value
    end
end

local function OnEnabledChanged(widget)
    if not widget:Get() then
        ResetRuntime()
    end
end

local function Loc(widget, title, tip)
    widget:ForceLocalization(Localizer.Get(title))
    if tip ~= nil then
        widget:ToolTip(Localizer.Get(tip))
    end
end

local function SetPhase(phase, now, deadline)
    Runtime.phase = phase
    Runtime.phaseStartedAt = now
    Runtime.deadline = deadline or math.huge
end

local function UnitAlive(unit)
    return unit ~= nil and Entity.IsAlive(unit) == true
end

local function AbilityCastRange(ability, fallback)
    local range = Ability.GetCastRange(ability)
    if type(range) ~= "number" or range <= 0 then
        return fallback
    end
    return range
end

local function GetTossGrabRadius(toss)
    local radius = Ability.GetLevelSpecialValueFor(toss, "grab_radius")
    if type(radius) ~= "number" or radius <= 0 then
        return GRAB_RADIUS_FALLBACK
    end
    return radius
end

local function GetTossDuration(toss)
    local duration = Ability.GetLevelSpecialValueFor(toss, "duration")
    if type(duration) ~= "number" or duration <= 0 then
        return TOSS_DURATION_FALLBACK
    end
    return duration
end

local function TossHasPointTarget(toss)
    local behavior = Ability.GetBehavior(toss, false)
    return type(behavior) == "number"
        and (behavior & Enum.AbilityBehavior.DOTA_ABILITY_BEHAVIOR_POINT) ~= 0
end

local function AbilityAccepted(ability)
    if ability == nil then
        return false
    end
    if Ability.IsInAbilityPhase(ability) == true then
        return true
    end
    local since = Ability.SecondsSinceLastUse(ability)
    if type(since) == "number" and since >= 0 and since < 1.0 then
        return true
    end
    local cd = Ability.GetCooldown(ability)
    return type(cd) == "number" and cd > 0
end

local function GetReadyItem(me, names)
    for i = 1, #names do
        local item = NPC.GetItem(me, names[i], true)
        if item ~= nil and Ability.IsCastable(item) == true then
            return item
        end
    end
    return nil
end

local function TossChargesReady(toss)
    local charges = Ability.GetCurrentCharges(toss)
    if type(charges) == "number" and charges > 0 then
        return charges
    end
    if Ability.IsCastable(toss) == true then
        return 1
    end
    return 0
end

local function CanGrabEnemy(enemy)
    if NPC.HasState(enemy, STATE_INVULNERABLE) == true then
        return false
    end
    if NPC.HasState(enemy, STATE_MAGIC_IMMUNE) == true then
        return false
    end
    return true
end

local function DestTargetSafe(unit)
    if not UnitAlive(unit) then
        return false
    end
    if NPC.IsLinkensProtected(unit) == true then
        return false
    end
    if NPC.IsMirrorProtected(unit) == true then
        return false
    end
    return true
end

local function IsNearestGrabUnit(me, enemy, grabRadius)
    local mePos = Entity.GetAbsOrigin(me)
    local team = Entity.GetTeamNum(me)
    local units = NPCs.InRadius(mePos, grabRadius, team, Enum.TeamType.TEAM_BOTH, false, true)
    if units == nil or #units == 0 then
        return false
    end

    local best = nil
    local bestDist = math.huge
    for i = 1, #units do
        local unit = units[i]
        if UnitAlive(unit) and unit ~= me and NPC.IsStructure(unit) ~= true then
            local dist = mePos:DistanceSqr2D(Entity.GetAbsOrigin(unit))
            if dist < bestDist then
                bestDist = dist
                best = unit
            end
        end
    end
    return best == enemy
end

local function InGrab(me, enemy, grabRadius)
    return NPC.IsEntityInRange(me, enemy, grabRadius)
        and IsNearestGrabUnit(me, enemy, grabRadius)
end

local function EnemyStillValid(enemy, me, searchRange, now, allowHidden)
    if not UnitAlive(enemy) or NPC.IsIllusion(enemy) == true then
        return false
    end
    if not CanGrabEnemy(enemy) then
        return false
    end

    if NPC.IsVisible(enemy) == true and Entity.IsDormant(enemy) ~= true then
        Runtime.lastSeenAt = now
        if not NPC.IsEntityInRange(me, enemy, searchRange * 1.35) and Runtime.phase <= PHASE_TOSS1 then
            return false
        end
        return true
    end

    if allowHidden then
        return true
    end

    return (now - Runtime.lastSeenAt) <= FOW_ABORT
end

local function FindEnemy(me, searchRange)
    local enemy = Input.GetNearestHeroToCursor(Entity.GetTeamNum(me), Enum.TeamType.TEAM_ENEMY)
    if enemy == nil
        or not UnitAlive(enemy)
        or NPC.IsIllusion(enemy) == true
        or Entity.IsDormant(enemy) == true
        or NPC.IsVisible(enemy) ~= true
        or not NPC.IsEntityInRange(me, enemy, searchRange)
        or not CanGrabEnemy(enemy)
    then
        return nil
    end
    return enemy
end

local function AcquireEnemy(me, searchRange, now)
    local enemy = Runtime.enemy
    local allowHidden = Runtime.phase >= PHASE_WAIT_AIR
    if enemy ~= nil and EnemyStillValid(enemy, me, searchRange, now, allowHidden) then
        return enemy
    end

    if Runtime.phase > PHASE_TOSS1 and Runtime.toss1Issued then
        return nil
    end

    enemy = FindEnemy(me, searchRange)
    Runtime.enemy = enemy
    if enemy ~= nil then
        Runtime.lastSeenAt = now
    end
    return enemy
end

local function DestinationEnabled(kind)
    local key = DEST_MENU[kind]
    return key ~= nil and UI.destinations ~= nil and UI.destinations:Get(key) == true
end

local function FindAlliedFountain(me)
    local team = Entity.GetTeamNum(me)
    local forts = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_FORT)
    if forts == nil then
        return nil
    end
    for i = 1, #forts do
        local fort = forts[i]
        if UnitAlive(fort) and Entity.GetTeamNum(fort) == team then
            return fort
        end
    end
    return nil
end

local function FindBestAlly(me, enemy)
    -- teamType is relative to `me`: TEAM_FRIEND = our allies
    local heroes = Entity.GetHeroesInRadius(me, DEST_SCAN_RADIUS, Enum.TeamType.TEAM_FRIEND, true, true)
    if heroes == nil then
        return nil
    end

    local enemyPos = Entity.GetAbsOrigin(enemy)
    local best, bestDist = nil, math.huge
    for i = 1, #heroes do
        local ally = heroes[i]
        if ally ~= me and UnitAlive(ally) and DestTargetSafe(ally) then
            local dist = enemyPos:DistanceSqr2D(Entity.GetAbsOrigin(ally))
            if dist < bestDist then
                bestDist = dist
                best = ally
            end
        end
    end
    return best
end

local function FindBestTower(me, enemyPos)
    local team = Entity.GetTeamNum(me)
    local towers = Towers.InRadius(enemyPos, DEST_SCAN_RADIUS, team, Enum.TeamType.TEAM_FRIEND)
    if towers == nil then
        return nil
    end

    local best, bestDist = nil, math.huge
    for i = 1, #towers do
        local tower = towers[i]
        if UnitAlive(tower) then
            local dist = enemyPos:DistanceSqr2D(Entity.GetAbsOrigin(tower))
            if dist < bestDist then
                bestDist = dist
                best = tower
            end
        end
    end
    return best
end

local function FindFriendlyUnitNear(me, destPos, castRange, exclude)
    local mePos = Entity.GetAbsOrigin(me)
    local units = NPCs.InRadius(mePos, castRange, Entity.GetTeamNum(me), Enum.TeamType.TEAM_FRIEND, false, true)
    if units == nil then
        return nil
    end

    local best, bestDist = nil, math.huge
    for i = 1, #units do
        local unit = units[i]
        if unit ~= me
            and unit ~= exclude
            and UnitAlive(unit)
            and NPC.IsStructure(unit) ~= true
            and NPC.IsCourier(unit) ~= true
            and DestTargetSafe(unit)
        then
            local dist = destPos:DistanceSqr2D(Entity.GetAbsOrigin(unit))
            if dist < bestDist then
                bestDist = dist
                best = unit
            end
        end
    end
    return best
end

local function ResolveTossTarget(me, toss, destKind, destUnit, destPos, enemy)
    local castRange = AbilityCastRange(toss, TOSS_RANGE_FALLBACK)

    if destKind == "ally" and UnitAlive(destUnit) and DestTargetSafe(destUnit) then
        if NPC.IsEntityInRange(me, destUnit, castRange) then
            return destUnit, nil
        end
    end

    if TossHasPointTarget(toss) and destPos ~= nil then
        local mePos = Entity.GetAbsOrigin(me)
        if mePos:IsInRange2D(destPos, castRange) then
            return nil, destPos
        end
        local hopPos = mePos:Extend2D(destPos, castRange - 25)
        hopPos:SetGroundZ()
        return nil, hopPos
    end

    if destPos ~= nil then
        local near = FindFriendlyUnitNear(me, destPos, castRange, enemy)
        if near ~= nil then
            return near, nil
        end
    end

    return nil, nil
end

local function FindDestination(me, enemy, toss)
    local enemyPos = Entity.GetAbsOrigin(enemy)
    local priority = UI.priority and UI.priority:Get() or 0
    local order = PRIORITY_ORDERS[priority] or PRIORITY_ORDERS[0]

    for i = 1, #order do
        local kind = order[i]
        if DestinationEnabled(kind) then
            local destEntity = nil
            if kind == "ally" then
                destEntity = FindBestAlly(me, enemy)
            elseif kind == "tower" then
                destEntity = FindBestTower(me, enemyPos)
            else
                destEntity = FindAlliedFountain(me)
            end

            if destEntity ~= nil then
                local destPos = Entity.GetAbsOrigin(destEntity)
                local unit, pos = ResolveTossTarget(me, toss, kind, destEntity, destPos, enemy)
                return kind, destEntity, destPos, unit, pos
            end
        end
    end

    return nil, nil, nil, nil, nil
end

local function LockOrRefreshDestination(me, enemy, toss)
    if Runtime.destLocked and Runtime.destPos ~= nil then
        local destUnit = Runtime.destUnit
        if destUnit ~= nil and UnitAlive(destUnit) then
            if Runtime.destKind == "ally" and not DestTargetSafe(destUnit) then
                ResetRuntime()
                return nil, nil, nil, nil, nil
            end
            Runtime.destPos = Entity.GetAbsOrigin(destUnit)
        end
        local unit, pos = ResolveTossTarget(me, toss, Runtime.destKind, Runtime.destUnit, Runtime.destPos, enemy)
        return Runtime.destKind, Runtime.destUnit, Runtime.destPos, unit, pos
    end

    local kind, destEntity, destPos, unit, pos = FindDestination(me, enemy, toss)
    if kind == nil or destPos == nil then
        return nil, nil, nil, nil, nil
    end

    Runtime.destKind = kind
    Runtime.destUnit = destEntity
    Runtime.destPos = destPos
    Runtime.destLocked = true
    return kind, destEntity, destPos, unit, pos
end

-- Double Toss + mid blink only toward allied fountain.
local function ShouldChain(me, enemy, toss, destKind, destPos)
    if destKind ~= "fountain" then
        return false
    end
    if not UI.chainDouble or UI.chainDouble:Get() ~= true or destPos == nil then
        return false
    end
    if TossChargesReady(toss) < 2 then
        return false
    end
    if not UI.useBlink or UI.useBlink:Get() ~= true or GetReadyItem(me, BLINK_ITEMS) == nil then
        return false
    end

    local castRange = AbilityCastRange(toss, TOSS_RANGE_FALLBACK)
    if not NPC.IsPositionInRange(me, destPos, castRange, 0) then
        return true
    end

    local fountainNear = UI.fountainNearRange and UI.fountainNearRange:Get() or 2500
    local fountain = FindAlliedFountain(me)
    if fountain == nil then
        return false
    end

    return Entity.GetAbsOrigin(enemy):IsInRange2D(Entity.GetAbsOrigin(fountain), fountainNear)
        and NPC.IsEntityInRange(me, enemy, GetTossGrabRadius(toss) + 200)
end

local function BuildHopTarget(me, toss, destPos, enemy)
    local castRange = AbilityCastRange(toss, TOSS_RANGE_FALLBACK)
    local mePos = Entity.GetAbsOrigin(me)

    if TossHasPointTarget(toss) then
        local hopPos = mePos:IsInRange2D(destPos, castRange)
            and destPos:Clone()
            or mePos:Extend2D(destPos, castRange - 25)
        hopPos:SetGroundZ()
        return nil, hopPos
    end

    local near = FindFriendlyUnitNear(me, destPos, castRange, enemy)
    if near ~= nil then
        return near, Entity.GetAbsOrigin(near)
    end
    return nil, nil
end

-- One Toss finishes the play to ally/tower (fountain uses chain instead).
local function CanSingleTossFinish(me, toss, destKind, destUnit, destPos, enemy, useChain)
    if useChain or (destKind ~= "ally" and destKind ~= "tower") then
        return false
    end
    local unit, pos = ResolveTossTarget(me, toss, destKind, destUnit, destPos, enemy)
    return unit ~= nil or pos ~= nil
end

-- Spend blink to enter grab when a single Toss to ally/tower finishes the play.
local function TryBlinkApproach(me, enemy, grabRadius)
    if not UI.useBlink or UI.useBlink:Get() ~= true then
        return false
    end
    local blink = GetReadyItem(me, BLINK_ITEMS)
    if blink == nil then
        return false
    end

    local mePos = Entity.GetAbsOrigin(me)
    local enemyPos = Entity.GetAbsOrigin(enemy)
    local dist = mePos:Distance2D(enemyPos)
    if dist <= grabRadius then
        return false
    end
    if dist > BLINK_RANGE + grabRadius * 0.4 then
        return false
    end

    local landDist = math.max(40, math.min(dist - grabRadius * 0.55, BLINK_RANGE))
    local land = mePos:Extend2D(enemyPos, landDist)
    land:SetGroundZ()
    Ability.CastPosition(blink, land, false, true, false, ORDER_ID .. ".blink_approach", false)
    return true
end

local function TryApproach(me, enemy, grabRadius, walkRange, now, allowBlinkApproach)
    local mePos = Entity.GetAbsOrigin(me)
    local enemyPos = Entity.GetAbsOrigin(enemy)
    local dist = mePos:Distance2D(enemyPos)

    if dist <= grabRadius * 0.55 and IsNearestGrabUnit(me, enemy, grabRadius) then
        return false
    end

    if allowBlinkApproach and TryBlinkApproach(me, enemy, grabRadius) then
        return true
    end

    if UI.useForce and UI.useForce:Get() == true then
        local force = GetReadyItem(me, FORCE_ITEMS)
        if force ~= nil and dist > grabRadius and dist < grabRadius + FORCE_PUSH + 150 then
            Ability.CastTarget(force, me, false, true, false, ORDER_ID .. ".force")
            return true
        end
    end

    if dist > walkRange then
        return false
    end
    if now - Runtime.lastMoveAt < MOVE_THROTTLE then
        return true
    end

    local moveDist = dist > grabRadius * 0.45 and (dist - grabRadius * 0.45) or dist
    local movePos = mePos:Extend2D(enemyPos, moveDist)
    movePos:SetGroundZ()
    NPC.MoveTo(me, movePos, false, false, true, false, ORDER_ID .. ".walk", false)
    Runtime.lastMoveAt = now
    return true
end

local function TryAvalanche(me, avalanche, enemy)
    if not UI.useAvalanche or UI.useAvalanche:Get() ~= true then
        return false
    end
    if avalanche == nil or Ability.GetLevel(avalanche) <= 0 or Ability.IsCastable(avalanche) ~= true then
        return false
    end
    if NPC.IsSilenced(me) == true then
        return false
    end

    local castRange = AbilityCastRange(avalanche, AVALANCHE_RANGE_FALLBACK)
    local mePos = Entity.GetAbsOrigin(me)
    local enemyPos = Entity.GetAbsOrigin(enemy)
    local castPos = enemyPos
    if not mePos:IsInRange2D(enemyPos, castRange) then
        castPos = mePos:Extend2D(enemyPos, castRange - 10)
        castPos:SetGroundZ()
    end

    Ability.CastPosition(avalanche, castPos, false, true, true, ORDER_ID .. ".avalanche", false)
    return true
end

local function CastToss(toss, unit, pos, tag)
    if unit ~= nil then
        if not DestTargetSafe(unit) then
            return false
        end
        Ability.CastTarget(toss, unit, false, true, false, ORDER_ID .. "." .. tag)
        return true
    end
    if pos ~= nil then
        Ability.CastPosition(toss, pos, false, true, false, ORDER_ID .. "." .. tag, false)
        return true
    end
    return false
end

local function ResolveLandingPos(enemy)
    local hopPos = Runtime.hopPos
    if hopPos ~= nil then
        return hopPos
    end
    local hopUnit = Runtime.hopUnit
    if hopUnit ~= nil and UnitAlive(hopUnit) then
        return Entity.GetAbsOrigin(hopUnit)
    end
    return Entity.GetAbsOrigin(enemy)
end

local function AvalancheConfirmed(avalanche, now)
    if AbilityAccepted(avalanche) then
        return true
    end
    return (now - Runtime.avalancheAt) >= CAST_CONFIRM_TIMEOUT
end

local function Toss1Confirmed(toss, enemy, now)
    if NPC.HasModifier(enemy, MODIFIER_TOSS) == true then
        return true
    end
    if AbilityAccepted(toss) then
        return true
    end
    return (now - Runtime.toss1At) >= CAST_CONFIRM_TIMEOUT
end

local function BlinkConfirmed(blink, now)
    if AbilityAccepted(blink) then
        return true
    end
    return (now - Runtime.blinkAt) >= CAST_CONFIRM_TIMEOUT
end

local function UpdateCombo(me)
    local toss = NPC.GetAbility(me, ABILITY_TOSS)
    local avalanche = NPC.GetAbility(me, ABILITY_AVALANCHE)
    if toss == nil or Ability.GetLevel(toss) <= 0 then
        return
    end

    local now = GameRules.GetGameTime()
    local searchRange = UI.searchRange and UI.searchRange:Get() or 1200

    local enemy = AcquireEnemy(me, searchRange, now)
    if enemy == nil then
        ResetRuntime()
        return
    end

    if NPC.IsStunned(me) == true then
        return
    end

    local grabRadius = GetTossGrabRadius(toss)
    local kind, destEntity, destPos, tossUnit, tossPos = LockOrRefreshDestination(me, enemy, toss)
    if kind == nil or destPos == nil then
        if Runtime.phase ~= PHASE_IDLE then
            ResetRuntime()
        end
        return
    end

    if Runtime.phase == PHASE_IDLE then
        Runtime.useChain = ShouldChain(me, enemy, toss, kind, destPos)
        if InGrab(me, enemy, grabRadius) then
            SetPhase(PHASE_TOSS1, now, now + 2.0)
        else
            SetPhase(PHASE_APPROACH, now, now + APPROACH_TIMEOUT)
        end
    end

    if Runtime.phase == PHASE_APPROACH then
        if InGrab(me, enemy, grabRadius) then
            SetPhase(PHASE_TOSS1, now, now + 2.0)
        else
            local blinkIn = CanSingleTossFinish(me, toss, kind, destEntity, destPos, enemy, Runtime.useChain)
            TryApproach(me, enemy, grabRadius, searchRange, now, blinkIn)
            if now >= Runtime.deadline then
                ResetRuntime()
            end
            return
        end
    end

    if Runtime.phase == PHASE_TOSS1 then
        if not IsNearestGrabUnit(me, enemy, grabRadius) then
            SetPhase(PHASE_APPROACH, now, now + APPROACH_TIMEOUT)
            return
        end

        if not Runtime.avalancheIssued then
            if TryAvalanche(me, avalanche, enemy) then
                Runtime.avalancheIssued = true
                Runtime.avalancheAt = now
                return
            end
            Runtime.avalancheIssued = true
            Runtime.avalancheAt = -math.huge
        elseif Runtime.avalancheAt > 0 and not AvalancheConfirmed(avalanche, now) then
            return
        end

        if Runtime.toss1Issued then
            if Toss1Confirmed(toss, enemy, now) then
                if Runtime.useChain then
                    SetPhase(PHASE_WAIT_AIR, now, now + GetTossDuration(toss) + 0.5)
                else
                    ResetRuntime()
                end
            elseif now - Runtime.toss1At > CAST_CONFIRM_TIMEOUT + 0.4 then
                ResetRuntime()
            end
            return
        end

        if TossChargesReady(toss) < 1 then
            if now >= Runtime.deadline then
                ResetRuntime()
            end
            return
        end

        if avalanche ~= nil and Ability.IsInAbilityPhase(avalanche) == true then
            return
        end

        local castUnit, castPos = tossUnit, tossPos
        if Runtime.useChain then
            castUnit, castPos = BuildHopTarget(me, toss, destPos, enemy)
            Runtime.hopUnit = castUnit
            Runtime.hopPos = castPos
            if castUnit == nil and castPos == nil then
                Runtime.useChain = false
                castUnit, castPos = tossUnit, tossPos
            end
        end
        if castUnit == nil and castPos == nil then
            castUnit, castPos = BuildHopTarget(me, toss, destPos, enemy)
        end

        if CastToss(toss, castUnit, castPos, "toss1") then
            Runtime.toss1Issued = true
            Runtime.toss1At = now
        elseif now >= Runtime.deadline then
            ResetRuntime()
        end
        return
    end

    if Runtime.phase == PHASE_WAIT_AIR then
        local waited = now - Runtime.phaseStartedAt
        if NPC.HasModifier(enemy, MODIFIER_TOSS) == true or waited > 0.15 then
            SetPhase(PHASE_BLINK_FOLLOW, now, now + 1.2)
        elseif now >= Runtime.deadline then
            ResetRuntime()
        end
        return
    end

    if Runtime.phase == PHASE_BLINK_FOLLOW then
        if not Runtime.toss1Issued then
            ResetRuntime()
            return
        end

        if not Runtime.blinkFollowIssued then
            local blink = UI.useBlink and UI.useBlink:Get() == true and GetReadyItem(me, BLINK_ITEMS) or nil
            if blink == nil then
                ResetRuntime()
                return
            end

            local land = ResolveLandingPos(enemy)
            local mePos = Entity.GetAbsOrigin(me)
            local dist = mePos:Distance2D(land)
            if dist > 50 then
                local blinkPos = mePos:Extend2D(land, math.min(dist, BLINK_RANGE))
                blinkPos:SetGroundZ()
                Ability.CastPosition(blink, blinkPos, false, true, false, ORDER_ID .. ".blink2", false)
            end
            Runtime.blinkFollowIssued = true
            Runtime.blinkAt = now
            Runtime.blinkItem = blink
            return
        end

        if BlinkConfirmed(Runtime.blinkItem, now) then
            SetPhase(PHASE_TOSS2, now, now + 2.0)
        elseif now >= Runtime.deadline then
            ResetRuntime()
        end
        return
    end

    if Runtime.phase == PHASE_TOSS2 then
        if NPC.HasModifier(enemy, MODIFIER_TOSS) == true then
            if now >= Runtime.deadline then
                ResetRuntime()
            end
            return
        end

        if not InGrab(me, enemy, grabRadius) or TossChargesReady(toss) < 1 then
            if now >= Runtime.deadline then
                ResetRuntime()
            end
            return
        end

        local finalUnit, finalPos = ResolveTossTarget(me, toss, Runtime.destKind, Runtime.destUnit, Runtime.destPos, enemy)
        if CastToss(toss, finalUnit, finalPos, "toss2") then
            ResetRuntime()
        elseif now >= Runtime.deadline then
            ResetRuntime()
        end
    end
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    for _, key in pairs(LOC) do
        Localizer.RegToken(key)
    end

    local group = Menu.Create("Heroes", "Hero List", "Tiny", "Main Settings", LOC.group)
    Loc(group, LOC.group)

    UI.enabled = group:Switch(LOC.enable, true)
    UI.enabled:Icon("\u{f00c}")
    Loc(UI.enabled, LOC.enable, LOC.enableTip)
    UI.enabled:SetCallback(OnEnabledChanged, false)

    UI.tossKey = group:Bind(LOC.tossKey, Enum.ButtonCode.KEY_NONE)
    UI.tossKey:Icon("\u{e1c1}")
    Loc(UI.tossKey, LOC.tossKey, LOC.tossKeyTip)

    UI.destinations = group:MultiCombo(LOC.destinations, {
        LOC.teammate,
        LOC.tower,
        LOC.fountain,
    }, {
        LOC.teammate,
        LOC.tower,
        LOC.fountain,
    })
    UI.destinations:Image(ICON_TINY)
    Loc(UI.destinations, LOC.destinations, LOC.destinationsTip)

    local gear = UI.enabled:Gear(LOC.settings)
    Loc(gear, LOC.settings)

    UI.priority = gear:Combo(LOC.priority, {
        LOC.prioAllyTowerFountain,
        LOC.prioFountainAllyTower,
        LOC.prioTowerAllyFountain,
    }, 0)
    UI.priority:Image(ICON_TOSS)
    Loc(UI.priority, LOC.priority, LOC.priorityTip)

    UI.useAvalanche = gear:Switch(LOC.useAvalanche, true, ICON_AVALANCHE)
    Loc(UI.useAvalanche, LOC.useAvalanche, LOC.useAvalancheTip)

    UI.useBlink = gear:Switch(LOC.useBlink, true, ICON_BLINK)
    Loc(UI.useBlink, LOC.useBlink, LOC.useBlinkTip)

    UI.useForce = gear:Switch(LOC.useForce, true, "\u{f07e}")
    Loc(UI.useForce, LOC.useForce, LOC.useForceTip)

    UI.chainDouble = gear:Switch(LOC.chainDouble, true, "\u{f24d}")
    Loc(UI.chainDouble, LOC.chainDouble, LOC.chainDoubleTip)

    UI.searchRange = gear:Slider(LOC.searchRange, 400, 2500, 1200)
    Loc(UI.searchRange, LOC.searchRange, LOC.searchRangeTip)

    UI.fountainNearRange = gear:Slider(LOC.fountainNear, 800, 5000, 2500)
    Loc(UI.fountainNearRange, LOC.fountainNear, LOC.fountainNearTip)
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if not UI.tossKey or UI.tossKey:IsDown() ~= true then
        if Runtime.phase ~= PHASE_IDLE then
            ResetRuntime()
        end
        return
    end
    if Input.IsInputCaptured() or Input.IsPopupOpen() then
        return
    end

    local now = GameRules.GetGameTime()
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true then
        return
    end
    if NPC.GetUnitName(me) ~= HERO_NAME then
        return
    end

    UpdateCombo(me)
end

function Script.OnGameEnd()
    ResetRuntime()
end
--#endregion

return Script
