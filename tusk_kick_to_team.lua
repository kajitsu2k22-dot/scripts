local script = {}
local unpack = table.unpack or unpack

local HERO_NAME = "npc_dota_hero_tusk"
local ABILITY_NAME = "tusk_walrus_kick"
local SPELL_ICON = "panorama/images/spellicons/tusk_walrus_kick_png.vtex_c"

local MODE_AUTO_NEAREST = 0
local MODE_AUTO_CLUSTER = 1

local MODE_ITEMS = {
    "Auto: Nearest Ally",
    "Auto: Ally Cluster",
}

local PUSH_LENGTH = 1200
local VECTOR_HINT_DISTANCE = 350
local CAST_THROTTLE = 0.30
local DEFAULT_MIN_CLOSER_GAIN = 160
local DEFAULT_MAX_LANDING_DISTANCE = 700
local OVERSHOOT_WORSEN_TOLERANCE = 75
local POST_ORDER_MIN_LOCK = 0.85
local POST_ORDER_EXTRA_LOCK = 0.45

local State = {
    lastCastTime = 0,
    bestPlan = nil,
    pendingOrderUntil = 0,
    postOrderLockUntil = 0,
    pendingVectorStep = nil,
}

local function ResolveEnumValue(container, candidates)
    if not container then
        return nil
    end

    for i = 1, #candidates do
        local value = container[candidates[i]]
        if value ~= nil then
            return value
        end
    end

    return nil
end

local ORDER_CAST_TARGET_POSITION_NAMES = { "CAST_TARGET_POSITION", "DOTA_UNIT_ORDER_CAST_TARGET_POSITION" }
local ORDER_CAST_TARGET_NAMES = { "CAST_TARGET", "DOTA_UNIT_ORDER_CAST_TARGET" }
local ORDER_VECTOR_TARGET_POSITION_NAMES = { "VECTOR_TARGET_POSITION", "DOTA_UNIT_ORDER_VECTOR_TARGET_POSITION" }
local ORDER_ISSUER_PASSED_UNIT_ONLY_NAMES =
    { "PLAYER_ORDER_ISSUER_PASSED_UNIT_ONLY", "DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY" }
local ORDER_ISSUER_HERO_ONLY_NAMES = { "PLAYER_ORDER_ISSUER_HERO_ONLY", "DOTA_ORDER_ISSUER_HERO_ONLY" }
local ORDER_ISSUER_SCRIPT_NAMES = { "PLAYER_ORDER_ISSUER_SCRIPT", "DOTA_ORDER_ISSUER_SCRIPT" }

local function ResolveUnitOrder(candidates)
    return ResolveEnumValue(Enum and Enum.UnitOrder or nil, candidates)
end

local function ResolveOrderIssuer(candidates)
    return ResolveEnumValue(Enum and Enum.PlayerOrderIssuer or nil, candidates)
end

local function GetResolvedOrderContext()
    local ctx = {}
    ctx.castTargetPosition = ResolveUnitOrder(ORDER_CAST_TARGET_POSITION_NAMES)
    ctx.castTarget = ResolveUnitOrder(ORDER_CAST_TARGET_NAMES)
    ctx.vectorTargetPosition = ResolveUnitOrder(ORDER_VECTOR_TARGET_POSITION_NAMES)
    ctx.issuerPassedUnitOnly = ResolveOrderIssuer(ORDER_ISSUER_PASSED_UNIT_ONLY_NAMES)
    ctx.issuerHeroOnly = ResolveOrderIssuer(ORDER_ISSUER_HERO_ONLY_NAMES)
    ctx.issuerScript = ResolveOrderIssuer(ORDER_ISSUER_SCRIPT_NAMES)
    ctx.issuer = ctx.issuerPassedUnitOnly or ctx.issuerHeroOnly or ctx.issuerScript
    return ctx
end

local function InitializeUI()
    local mainSettings = Menu.Find("Heroes", "Hero List", "Tusk", "Main Settings")
    local group = nil

    if mainSettings and mainSettings.Create then
        group = mainSettings:Create("Walrus Kick")
    end

    if not group then
        group = Menu.Create("General", "Tusk", "Walrus Kick", "Settings", "Kick To Team")
    end

    local ui = {}

    ui.Enabled = group:Switch("Kick To Team", false)
    ui.Enabled:Image(SPELL_ICON)

    local gear = ui.Enabled:Gear("Settings")
    ui.Mode = gear:Combo("Mode", MODE_ITEMS, MODE_AUTO_NEAREST)
    ui.Mode:Image(SPELL_ICON)

    ui.AssistRadius = gear:Slider("Assist Radius", 600, 2200, 1400, "%d")
    ui.ClusterRadius = gear:Slider("Cluster Radius", 120, 800, 340, "%d")
    ui.MinCloserGain = gear:Slider("Min Closer Gain", 0, 1200, DEFAULT_MIN_CLOSER_GAIN, "%d")
    ui.MaxLandingDistance = gear:Slider("Max Landing Distance To Ally", 150, 1400, DEFAULT_MAX_LANDING_DISTANCE, "%d")

    local function UpdateControls()
        local enabled = ui.Enabled:Get()
        ui.Mode:Disabled(not enabled)
        ui.AssistRadius:Disabled(not enabled)
        ui.ClusterRadius:Disabled(not enabled)
        ui.MinCloserGain:Disabled(not enabled)
        ui.MaxLandingDistance:Disabled(not enabled)
    end

    ui.Enabled:SetCallback(UpdateControls, true)

    return ui
end

local UI = InitializeUI()

local function GetModeName(mode)
    return MODE_ITEMS[(mode or 0) + 1] or "Unknown"
end

local function TryIndex(obj, key)
    if not obj or not key then
        return false, nil
    end

    return pcall(function()
        return obj[key]
    end)
end

local function TryCallMethod(obj, methodName, ...)
    local okIndex, memberOrErr = TryIndex(obj, methodName)
    if not okIndex then
        return false, "index failed: " .. tostring(memberOrErr)
    end

    if type(memberOrErr) ~= "function" then
        return false, "method missing"
    end

    local args = { ... }
    local okCall, resultOrErr = pcall(function()
        return memberOrErr(obj, unpack(args))
    end)

    if okCall then
        return true, resultOrErr
    end

    return false, tostring(resultOrErr)
end

local function GetPlayerForHero(hero)
    local tried = {}

    if Players and Players.GetLocal then
        local player = Players.GetLocal()
        if player then
            return player, "Players.GetLocal"
        end
        tried[#tried + 1] = "Players.GetLocal=nil"
    else
        tried[#tried + 1] = "Players.GetLocal missing"
    end

    if Hero and Hero.GetPlayer then
        local ok, player = pcall(Hero.GetPlayer, hero)
        if ok and player then
            return player, "Hero.GetPlayer"
        end
        tried[#tried + 1] = ok and "Hero.GetPlayer=nil" or ("Hero.GetPlayer error=" .. tostring(player))
    end

    if NPC and NPC.GetPlayerOwner then
        local ok, player = pcall(NPC.GetPlayerOwner, hero)
        if ok and player then
            return player, "NPC.GetPlayerOwner"
        end
        tried[#tried + 1] = ok and "NPC.GetPlayerOwner=nil" or ("NPC.GetPlayerOwner error=" .. tostring(player))
    end

    do
        local ok, playerOrErr = TryCallMethod(hero, "GetPlayer")
        if ok and playerOrErr then
            return playerOrErr, "hero:GetPlayer"
        end
        tried[#tried + 1] = "hero:GetPlayer " .. tostring(playerOrErr)
    end

    do
        local ok, playerOrErr = TryCallMethod(hero, "GetPlayerOwner")
        if ok and playerOrErr then
            return playerOrErr, "hero:GetPlayerOwner"
        end
        tried[#tried + 1] = "hero:GetPlayerOwner " .. tostring(playerOrErr)
    end

    return nil, table.concat(tried, ", ")
end

local function DescribeCompat(ctx, player, playerSource)
    return string.format(
        "player=%s(%s) cast=%s castTarget=%s vector=%s issuer=%s",
        player and "ok" or "nil",
        tostring(playerSource or "?"),
        tostring(ctx and ctx.castTargetPosition or nil),
        tostring(ctx and ctx.castTarget or nil),
        tostring(ctx and ctx.vectorTargetPosition or nil),
        tostring(ctx and ctx.issuer or nil)
    )
end

local function IsTusk(hero)
    return hero and NPC.GetUnitName(hero) == HERO_NAME
end

local function IsValidHeroUnit(unit)
    if not unit then
        return false
    end

    if not Entity.IsAlive(unit) or Entity.IsDormant(unit) then
        return false
    end

    if NPC.IsIllusion(unit) then
        return false
    end

    if NPC.IsInvulnerable and NPC.IsInvulnerable(unit) then
        return false
    end

    return true
end

local function MakeGroundPosition(pos)
    if not pos then
        return nil
    end

    local groundZ = World.GetGroundZ(pos)
    return Vector(pos.x, pos.y, groundZ)
end

local function MakeDirection2D(fromPos, toPos)
    local delta = Vector(toPos.x - fromPos.x, toPos.y - fromPos.y, 0)
    local length = delta:Length2D()
    if length < 0.001 then
        return nil, 0
    end

    return Vector(delta.x / length, delta.y / length, 0), length
end

local function MoveTowards2D(startPos, direction, distance)
    return Vector(
        startPos.x + direction.x * distance,
        startPos.y + direction.y * distance,
        startPos.z
    )
end

local function DistancePointToSegment2D(point, segA, segB)
    local abX = segB.x - segA.x
    local abY = segB.y - segA.y
    local apX = point.x - segA.x
    local apY = point.y - segA.y
    local abLenSq = abX * abX + abY * abY

    if abLenSq <= 0.001 then
        return segA:Distance2D(point)
    end

    local t = (apX * abX + apY * abY) / abLenSq
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end

    local closest = Vector(segA.x + abX * t, segA.y + abY * t, 0)
    local flatPoint = Vector(point.x, point.y, 0)

    return closest:Distance2D(flatPoint)
end

local function CollectUnits(hero, wantAllies)
    local result = {}
    local allHeroes = Heroes.GetAll()

    for i = 1, #allHeroes do
        local other = allHeroes[i]
        if other ~= hero and IsValidHeroUnit(other) then
            local sameTeam = Entity.IsSameTeam(other, hero)
            if sameTeam == wantAllies then
                result[#result + 1] = {
                    hero = other,
                    pos = Entity.GetAbsOrigin(other),
                }
            end
        end
    end

    return result
end

local function GetKickRange(hero, kick)
    return Ability.GetCastRange(kick) or 250
end

local function CountAlliesNearPath(allies, startPos, endPos, width)
    local count = 0

    for i = 1, #allies do
        local allyPos = allies[i].pos
        if DistancePointToSegment2D(allyPos, startPos, endPos) <= width then
            count = count + 1
        end
    end

    return count
end

local function CountAlliesNearPosition(allies, pos, radius)
    local count = 0

    for i = 1, #allies do
        if allies[i].pos:Distance2D(pos) <= radius then
            count = count + 1
        end
    end

    return count
end

local function GetNearestAllyDistance(allies, pos)
    local best = math.huge

    for i = 1, #allies do
        local dist = allies[i].pos:Distance2D(pos)
        if dist < best then
            best = dist
        end
    end

    return best
end

local function BuildPlan(hero, enemyData, allies, desiredPos, meta)
    local enemyPos = enemyData.pos
    local heroPos = Entity.GetAbsOrigin(hero)
    local direction, desiredDist = MakeDirection2D(enemyPos, desiredPos)
    local minCloserGain = UI.MinCloserGain:Get() or DEFAULT_MIN_CLOSER_GAIN
    local maxLandingDistance = UI.MaxLandingDistance:Get() or DEFAULT_MAX_LANDING_DISTANCE

    if not direction then
        return nil
    end

    local endPos = MoveTowards2D(enemyPos, direction, PUSH_LENGTH)
    local vectorPos = MoveTowards2D(enemyPos, direction, VECTOR_HINT_DISTANCE)
    local lineWidth = math.max(140, meta.lineWidth or 200)
    local alliesOnPath = CountAlliesNearPath(allies, enemyPos, endPos, lineWidth)
    local alliesNearStart = CountAlliesNearPosition(allies, enemyPos, maxLandingDistance)
    local alliesNearEnd = CountAlliesNearPosition(allies, endPos, maxLandingDistance)
    local desiredEndDist = endPos:Distance2D(desiredPos)
    local nearestBeforeDist = GetNearestAllyDistance(allies, enemyPos)
    local nearestAfterDist = GetNearestAllyDistance(allies, endPos)
    local desiredGain = desiredDist - desiredEndDist
    local closerGain = nearestBeforeDist - nearestAfterDist
    local heroDist = heroPos:Distance2D(enemyPos)
    local alreadyNearTeam =
        alliesNearStart > 0 or nearestBeforeDist <= maxLandingDistance or desiredDist <= maxLandingDistance
    local worsensDesired = desiredEndDist > desiredDist + OVERSHOOT_WORSEN_TOLERANCE
    local worsensNearest = nearestAfterDist > nearestBeforeDist + OVERSHOOT_WORSEN_TOLERANCE
    local improvesNearbyAllies = alliesNearEnd > alliesNearStart

    if alreadyNearTeam and worsensDesired and worsensNearest and not improvesNearbyAllies then
        return nil
    end

    local smartCloserEnough =
        nearestAfterDist <= maxLandingDistance and (desiredGain >= minCloserGain or closerGain >= minCloserGain)
    local enoughCloser = alliesOnPath > 0 or alliesNearEnd > 0 or smartCloserEnough

    if not enoughCloser then
        return nil
    end

    local score =
        (meta.clusterCount or 0) * 100000 +
        alliesOnPath * 14000 +
        alliesNearEnd * 11000 +
        math.max(0, desiredGain) * 20 +
        math.max(0, closerGain) * 16 -
        nearestAfterDist * 8 -
        desiredEndDist * 4 -
        heroDist * 0.25

    return {
        enemy = enemyData.hero,
        enemyPos = MakeGroundPosition(enemyPos),
        desiredPos = MakeGroundPosition(desiredPos),
        vectorPos = MakeGroundPosition(vectorPos),
        endPos = MakeGroundPosition(endPos),
        score = score,
        alliesOnPath = alliesOnPath,
        alliesNearEnd = alliesNearEnd,
        clusterCount = meta.clusterCount or 0,
        strategy = meta.strategy,
        enemyDistance = heroDist,
        nearestAfterDist = nearestAfterDist,
        desiredEndDist = desiredEndDist,
        desiredGain = desiredGain,
        closerGain = closerGain,
    }
end

local function EvaluateNearestPlan(hero, enemyData, allies, assistRadius, clusterRadius)
    local nearest = nil
    local bestProjectedEndDist = math.huge
    local bestCurrentDist = math.huge
    local endSearchRadius = math.max(assistRadius, UI.MaxLandingDistance:Get() or DEFAULT_MAX_LANDING_DISTANCE)

    for i = 1, #allies do
        local allyData = allies[i]
        local currentDist = enemyData.pos:Distance2D(allyData.pos)
        local projectedEndDist = math.abs(currentDist - PUSH_LENGTH)

        if (currentDist <= assistRadius or projectedEndDist <= endSearchRadius)
            and (projectedEndDist < bestProjectedEndDist
                or (projectedEndDist == bestProjectedEndDist and currentDist < bestCurrentDist))
        then
            nearest = allyData
            bestProjectedEndDist = projectedEndDist
            bestCurrentDist = currentDist
        end
    end

    if not nearest then
        return nil
    end

    return BuildPlan(hero, enemyData, allies, nearest.pos, {
        strategy = "nearest",
        clusterCount = 1,
        lineWidth = math.max(140, clusterRadius),
    })
end

local function EvaluateClusterPlan(hero, enemyData, allies, assistRadius, clusterRadius)
    local candidates = {}
    local endSearchRadius = math.max(assistRadius, UI.MaxLandingDistance:Get() or DEFAULT_MAX_LANDING_DISTANCE)

    for i = 1, #allies do
        local allyData = allies[i]
        local currentDist = enemyData.pos:Distance2D(allyData.pos)
        local projectedEndDist = math.abs(currentDist - PUSH_LENGTH)
        if currentDist <= assistRadius or projectedEndDist <= endSearchRadius then
            candidates[#candidates + 1] = allyData
        end
    end

    if #candidates == 0 then
        return nil
    end

    local bestCenter = nil
    local bestCount = 0
    local bestCenterDist = math.huge
    local bestProjectedEndDist = math.huge

    for i = 1, #candidates do
        local anchor = candidates[i].pos
        local sumX = 0
        local sumY = 0
        local sumZ = 0
        local count = 0

        for j = 1, #candidates do
            local allyPos = candidates[j].pos
            if anchor:Distance2D(allyPos) <= clusterRadius then
                count = count + 1
                sumX = sumX + allyPos.x
                sumY = sumY + allyPos.y
                sumZ = sumZ + allyPos.z
            end
        end

        if count > 0 then
            local center = Vector(sumX / count, sumY / count, sumZ / count)
            local centerDist = enemyData.pos:Distance2D(center)
            local projectedEndDist = math.abs(centerDist - PUSH_LENGTH)

            if count > bestCount
                or (count == bestCount and projectedEndDist < bestProjectedEndDist)
                or (count == bestCount and projectedEndDist == bestProjectedEndDist and centerDist < bestCenterDist)
            then
                bestCount = count
                bestCenter = center
                bestCenterDist = centerDist
                bestProjectedEndDist = projectedEndDist
            end
        end
    end

    if not bestCenter then
        return nil
    end

    return BuildPlan(hero, enemyData, allies, bestCenter, {
        strategy = "cluster",
        clusterCount = bestCount,
        lineWidth = math.max(180, clusterRadius),
    })
end

local function SelectPlanForEnemy(hero, enemyData, allies, assistRadius, clusterRadius, mode)
    if mode == MODE_AUTO_NEAREST then
        return EvaluateNearestPlan(hero, enemyData, allies, assistRadius, clusterRadius)
    end

    return EvaluateClusterPlan(hero, enemyData, allies, assistRadius, clusterRadius)
end

local function FindBestPlan(hero, kick, mode)
    local allies = CollectUnits(hero, true)
    local enemies = CollectUnits(hero, false)

    if #allies == 0 or #enemies == 0 then
        return nil, string.format("insufficient units | allies=%d enemies=%d", #allies, #enemies)
    end

    local castRange = GetKickRange(hero, kick)
    local assistRadius = UI.AssistRadius:Get()
    local clusterRadius = UI.ClusterRadius:Get()
    local bestPlan = nil
    local enemiesInRange = 0

    for i = 1, #enemies do
        local enemyData = enemies[i]
        local heroDist = Entity.GetAbsOrigin(hero):Distance2D(enemyData.pos)

        if heroDist <= castRange + 25 then
            enemiesInRange = enemiesInRange + 1
            local plan = SelectPlanForEnemy(hero, enemyData, allies, assistRadius, clusterRadius, mode)
            if plan and (not bestPlan or plan.score > bestPlan.score) then
                bestPlan = plan
            end
        end
    end

    if not bestPlan then
        if enemiesInRange == 0 then
            return nil, string.format("no enemies in cast range | cast=%.0f", castRange)
        end

        return nil, string.format(
            "no valid plan | mode=%s allies=%d enemiesInRange=%d",
            GetModeName(mode),
            #allies,
            enemiesInRange
        )
    end

    return bestPlan, nil
end

local function CanEvaluateKick(hero, kick)
    if not Entity.IsAlive(hero) or Entity.IsDormant(hero) then
        return false, "hero invalid"
    end

    if not kick or Ability.GetLevel(kick) <= 0 then
        return false, "kick ability missing or level 0"
    end

    if Ability.IsActivated and not Ability.IsActivated(kick) then
        return false, "kick not activated"
    end

    return true, "ok"
end

local function CanAutoCastKick(hero, kick)
    local canEval, evalReason = CanEvaluateKick(hero, kick)
    if not canEval then
        return false, evalReason
    end

    if not Ability.IsReady(kick) then
        return false, "kick cooldown"
    end

    if not Ability.IsCastable(kick, NPC.GetMana(hero)) then
        return false, "not enough mana or cast blocked"
    end

    return true, "ok"
end

local function GetAbilityCastPointValue(ability)
    if not ability then
        return 0
    end

    if Ability and Ability.GetCastPoint then
        local ok, value = pcall(Ability.GetCastPoint, ability)
        if ok and type(value) == "number" then
            return value
        end
    end

    local ok, value = TryCallMethod(ability, "GetCastPoint")
    if ok and type(value) == "number" then
        return value
    end

    return 0
end

local function GetAbilityCooldownValue(ability)
    if not ability then
        return 0
    end

    if Ability and Ability.GetCooldown then
        local ok, value = pcall(Ability.GetCooldown, ability)
        if ok and type(value) == "number" then
            return value
        end
    end

    local ok, value = TryCallMethod(ability, "GetCooldown")
    if ok and type(value) == "number" then
        return value
    end

    return 0
end

local function IsAbilityInPhaseValue(ability)
    if not ability then
        return false
    end

    if Ability and Ability.IsInAbilityPhase then
        local ok, value = pcall(Ability.IsInAbilityPhase, ability)
        if ok and value ~= nil then
            return value == true
        end
    end

    local ok, value = TryCallMethod(ability, "IsInAbilityPhase")
    if ok and value ~= nil then
        return value == true
    end

    return false
end

local function GetPostOrderLockDuration(ability)
    local castPoint = GetAbilityCastPointValue(ability)
    return math.max(POST_ORDER_MIN_LOCK, castPoint + POST_ORDER_EXTRA_LOCK)
end

local function GetPostOrderLockStatus(ability)
    local now = GameRules.GetGameTime()
    if (State.postOrderLockUntil or 0) <= now then
        return false, nil
    end

    if GetAbilityCooldownValue(ability) > 0.05 then
        State.postOrderLockUntil = 0
        return false, nil
    end

    local left = math.max(0, State.postOrderLockUntil - now)
    if IsAbilityInPhaseValue(ability) then
        return true, string.format("kick in ability phase | left=%.2f", left)
    end

    return true, string.format("awaiting order resolve | left=%.2f", left)
end

local function BuildPreparedOrder(order, target, position, kick, issuer, hero, identifier)
    return {
        order = order,
        target = target,
        position = position,
        ability = kick,
        issuer = issuer,
        npc = hero,
        queue = false,
        showEffects = false,
        identifier = identifier,
    }
end

local function TryPrepareUnitOrdersStaticPositional(player, order, target, position, kick, issuer, hero, identifier)
    if not (Player and Player.PrepareUnitOrders) then
        return false, "Player.PrepareUnitOrders missing"
    end

    local pos = position or Vector(0, 0, 0)

    local ok, err = pcall(
        Player.PrepareUnitOrders,
        player,
        order,
        target,
        pos,
        kick,
        issuer,
        hero,
        false,
        false,
        false,
        false,
        identifier
    )

    if ok then
        return true, nil
    end

    return false, tostring(err)
end

local function TryPrepareUnitOrdersStaticTable(player, order, target, position, kick, issuer, hero, identifier)
    if not (Player and Player.PrepareUnitOrders) then
        return false, "Player.PrepareUnitOrders missing"
    end

    local ok, err =
        pcall(Player.PrepareUnitOrders, player, BuildPreparedOrder(order, target, position, kick, issuer, hero, identifier))
    if ok then
        return true, nil
    end

    return false, tostring(err)
end

local function TryPrepareUnitOrdersMethodTable(player, order, target, position, kick, issuer, hero, identifier)
    local ok, err =
        TryCallMethod(player, "PrepareUnitOrders", BuildPreparedOrder(order, target, position, kick, issuer, hero, identifier))
    if ok then
        return true, nil
    end

    return false, tostring(err)
end

local function MarkPendingOrder(methodName, identifier)
    State.pendingOrderUntil = GameRules.GetGameTime() + 0.40
end

local function GetPlayerActiveAbility(player)
    if not player then
        return nil
    end

    if Player and Player.GetActiveAbility then
        local ok, ability = pcall(Player.GetActiveAbility, player)
        if ok then
            return ability
        end
    end

    local ok, ability = TryCallMethod(player, "GetActiveAbility")
    if ok then
        return ability
    end

    return nil
end

local function GetAbilityNameSafe(ability)
    if not ability then
        return nil
    end

    if Ability and Ability.GetName then
        local ok, value = pcall(Ability.GetName, ability)
        if ok and value then
            return value
        end
    end

    local ok, value = TryCallMethod(ability, "GetName")
    if ok and value then
        return value
    end

    return nil
end

local function IsSameAbilityRef(a, b)
    if not a or not b then
        return false
    end

    if a == b then
        return true
    end

    local aName = GetAbilityNameSafe(a)
    local bName = GetAbilityNameSafe(b)
    return aName ~= nil and aName == bName
end

local function QueueVectorFollowup(player, playerSource, hero, kick, plan, ctx)
    State.pendingVectorStep = {
        player = player,
        playerSource = playerSource,
        hero = hero,
        kick = kick,
        enemy = plan.enemy,
        vectorPos = plan.vectorPos,
        order = ctx.vectorTargetPosition,
        issuer = ctx.issuer,
        dueTime = GameRules.GetGameTime() + 0.03,
        expireTime = GameRules.GetGameTime() + 0.25,
        identifier = "tusk_kick_to_team_vector_followup",
    }
end

local function ClearVectorFollowup()
    State.pendingVectorStep = nil
end

local function TryIssuePrepareOrderAny(player, order, target, position, kick, issuer, hero, identifier, label, errors)
    local okStaticPos, errStaticPos =
        TryPrepareUnitOrdersStaticPositional(player, order, target, position, kick, issuer, hero, identifier)
    if okStaticPos then
        MarkPendingOrder("prepare_static_positional:" .. label, identifier)
        return true, "prepare_static_positional:" .. label
    end
    errors[#errors + 1] = label .. " static_positional=" .. tostring(errStaticPos)

    local okStaticTable, errStaticTable =
        TryPrepareUnitOrdersStaticTable(player, order, target, position, kick, issuer, hero, identifier)
    if okStaticTable then
        MarkPendingOrder("prepare_static_table:" .. label, identifier)
        return true, "prepare_static_table:" .. label
    end
    errors[#errors + 1] = label .. " static_table=" .. tostring(errStaticTable)

    local okMethodTable, errMethodTable =
        TryPrepareUnitOrdersMethodTable(player, order, target, position, kick, issuer, hero, identifier)
    if okMethodTable then
        MarkPendingOrder("prepare_method_table:" .. label, identifier)
        return true, "prepare_method_table:" .. label
    end
    errors[#errors + 1] = label .. " method_table=" .. tostring(errMethodTable)

    return false, nil
end

local function TryProcessVectorFollowup()
    local pending = State.pendingVectorStep
    if not pending then
        return false
    end

    local now = GameRules.GetGameTime()
    if now < (pending.dueTime or 0) then
        return true
    end

    if now > (pending.expireTime or 0) then
        ClearVectorFollowup()
        return true
    end

    local activeAbility = GetPlayerActiveAbility(pending.player)

    if activeAbility and not IsSameAbilityRef(activeAbility, pending.kick) then
        ClearVectorFollowup()
        return true
    end

    local errors = {}
    local okTargetNil = TryIssuePrepareOrderAny(
        pending.player,
        pending.order,
        nil,
        pending.vectorPos,
        pending.kick,
        pending.issuer,
        pending.hero,
        pending.identifier .. "_nil_target",
        "vector_followup_nil_target",
        errors
    )
    if okTargetNil then
        State.postOrderLockUntil = GameRules.GetGameTime() + GetPostOrderLockDuration(pending.kick)
        ClearVectorFollowup()
        return true
    end

    local okTargetEnemy = TryIssuePrepareOrderAny(
        pending.player,
        pending.order,
        pending.enemy,
        pending.vectorPos,
        pending.kick,
        pending.issuer,
        pending.hero,
        pending.identifier .. "_enemy_target",
        "vector_followup_enemy_target",
        errors
    )
    if okTargetEnemy then
        State.postOrderLockUntil = GameRules.GetGameTime() + GetPostOrderLockDuration(pending.kick)
        ClearVectorFollowup()
        return true
    end

    ClearVectorFollowup()
    return true
end

local function IssueKickOrder(hero, kick, plan)
    local player, playerSource = GetPlayerForHero(hero)
    local ctx = GetResolvedOrderContext()
    local compatText = DescribeCompat(ctx, player, playerSource)
    local issuer = ctx.issuer
    local orderCandidates = {}
    local errors = {}

    if ctx.castTargetPosition ~= nil then
        orderCandidates[#orderCandidates + 1] = {
            label = "cast_target_position",
            value = ctx.castTargetPosition,
        }
    end

    if ctx.vectorTargetPosition ~= nil and ctx.vectorTargetPosition ~= ctx.castTargetPosition then
        orderCandidates[#orderCandidates + 1] = {
            label = "vector_target_position",
            value = ctx.vectorTargetPosition,
        }
    end

    if not player then
        errors[#errors + 1] = "player unavailable (" .. tostring(playerSource) .. ")"
    end

    if #orderCandidates == 0 then
        errors[#errors + 1] = "no order enum (" .. compatText .. ")"
    end

    if issuer == nil then
        errors[#errors + 1] = "no order issuer (" .. compatText .. ")"
    end

    if player and issuer ~= nil and #orderCandidates > 0 then
        if ctx.castTarget ~= nil and ctx.vectorTargetPosition ~= nil then
            local okTargetStage, targetStageReason = TryIssuePrepareOrderAny(
                player,
                ctx.castTarget,
                plan.enemy,
                Vector(0, 0, 0),
                kick,
                issuer,
                hero,
                "tusk_kick_to_team_cast_target_start",
                "cast_target_start",
                errors
            )
            if okTargetStage then
                QueueVectorFollowup(player, playerSource, hero, kick, plan, ctx)
                return true, "prepare_stage1_cast_target"
            end
        end

        for i = 1, #orderCandidates do
            local candidate = orderCandidates[i]
            local identifier = "tusk_kick_to_team_" .. candidate.label

            local okAny, reasonAny = TryIssuePrepareOrderAny(
                player,
                candidate.value,
                plan.enemy,
                plan.vectorPos,
                kick,
                issuer,
                hero,
                identifier,
                candidate.label,
                errors
            )
            if okAny then
                State.postOrderLockUntil = GameRules.GetGameTime() + GetPostOrderLockDuration(kick)
                return true, tostring(reasonAny)
            end
        end
    end

    do
        local okVectorMethod, errVectorMethod =
            TryCallMethod(hero, "CastAbilityVector", kick, plan.enemyPos, plan.vectorPos)
        if okVectorMethod then
            State.postOrderLockUntil = GameRules.GetGameTime() + GetPostOrderLockDuration(kick)
            return true, "npc_method_vector"
        end
        errors[#errors + 1] = "hero:CastAbilityVector=" .. tostring(errVectorMethod)
    end

    if NPC and NPC.CastAbilityVector then
        local ok, err = pcall(NPC.CastAbilityVector, hero, kick, plan.enemyPos, plan.vectorPos)
        if ok then
            State.postOrderLockUntil = GameRules.GetGameTime() + GetPostOrderLockDuration(kick)
            return true, "npc_static_vector"
        end

        errors[#errors + 1] = "NPC.CastAbilityVector=" .. tostring(err)
    else
        errors[#errors + 1] = "NPC.CastAbilityVector unavailable"
    end

    return false, table.concat(errors, " | ")
end

script.OnUpdate = function()
    State.bestPlan = nil

    if not Engine.IsInGame() then
        ClearVectorFollowup()
        return
    end

    if not UI.Enabled:Get() then
        ClearVectorFollowup()
        return
    end

    local hero = Heroes.GetLocal()
    if not hero then
        ClearVectorFollowup()
        return
    end

    if not IsTusk(hero) then
        ClearVectorFollowup()
        return
    end

    local kick = NPC.GetAbility(hero, ABILITY_NAME)
    local canEval = CanEvaluateKick(hero, kick)
    if not canEval then
        ClearVectorFollowup()
        return
    end

    if TryProcessVectorFollowup() then
        return
    end

    local mode = UI.Mode:Get()
    local plan = FindBestPlan(hero, kick, mode)
    State.bestPlan = plan

    if not plan then
        return
    end

    local lockActive = GetPostOrderLockStatus(kick)
    if lockActive then
        return
    end

    local canCast = CanAutoCastKick(hero, kick)
    if not canCast then
        return
    end

    local now = GameRules.GetGameTime()
    if now - State.lastCastTime < CAST_THROTTLE then
        return
    end

    local issued = IssueKickOrder(hero, kick, plan)
    if issued then
        State.lastCastTime = now
    end
end

script.OnPrepareUnitOrders = function(data)
    if not UI.Enabled:Get() then
        return true
    end

    if not data or State.pendingOrderUntil <= 0 then
        return true
    end

    if GameRules.GetGameTime() > State.pendingOrderUntil then
        State.pendingOrderUntil = 0
        return true
    end

    local hero = Heroes.GetLocal()
    if not hero or not data.npc then
        return true
    end

    if Entity.GetIndex(data.npc) ~= Entity.GetIndex(hero) then
        return true
    end

    State.pendingOrderUntil = 0
    return true
end

script.OnGameEnd = function()
    State.lastCastTime = 0
    State.bestPlan = nil
    State.pendingOrderUntil = 0
    State.postOrderLockUntil = 0
    State.pendingVectorStep = nil
end

return script
