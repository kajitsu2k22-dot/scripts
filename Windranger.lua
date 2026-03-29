local WR = {}

local NPC, Ability, Entity, Render, Menu, Players, Player, Engine, GameRules, Input, Particle, Trees, GridNav, Log =
      NPC, Ability, Entity, Render, Menu, Players, Player, Engine, GameRules, Input, Particle, Trees, GridNav, Log

local math_cos = math.cos
local math_floor = math.floor
local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_rad = math.rad
local math_sin = math.sin

local SHACKLE_DISTANCE = 575
local SHACKLE_MIN_DOT = math_cos(math_rad(23))
local SHACKLE_SEARCH_PADDING = 40
local BRANCH_CAST_RANGE = 200
local BRANCH_OFFSET = 96
local BRANCH_REGISTER_DELAY = 0.14
local BRANCH_PENDING_LIFETIME = 0.45
local BLINK_CAST_RANGE = 1200
local GLOBAL_ORDER_THROTTLE = 0.08

local BLINK_RING_DISTANCES = {80, 95, 110, 140}
local BLINK_RING_STEPS = 12

local COLOR_GOOD = Color(105, 255, 175, 240)
local COLOR_BRANCH = Color(255, 205, 95, 240)
local COLOR_BLINK = Color(105, 215, 255, 240)
local COLOR_BAD = Color(255, 115, 120, 240)
local COLOR_TEXT = Color(245, 248, 255, 245)
local COLOR_SUBTEXT = Color(168, 182, 204, 235)
local COLOR_PANEL = Color(13, 18, 24, 188)
local COLOR_PANEL_BORDER = Color(255, 255, 255, 32)
local COLOR_SHADOW = Color(0, 0, 0, 96)

-- Initialize Menu
local root = Menu.Find("Heroes", "Hero List", "Windranger", "Main Settings", "Hero Settings")
if not root then
    root = Menu.Create("Heroes", "Hero List", "Windranger", "Main Settings", "Hero Settings")
end

local function SetMenuIcon(widget, imagePath)
    if widget and widget.Image then
        pcall(widget.Image, widget, imagePath)
    end
end

-- Layout Tabs
local tabCombo = Menu.Find("Heroes", "Hero List", "Windranger", "Main Settings", "Combo Settings")
if not tabCombo then tabCombo = Menu.Create("Heroes", "Hero List", "Windranger", "Main Settings", "Combo Settings") end

local tabDefensive = Menu.Find("Heroes", "Hero List", "Windranger", "Main Settings", "Defensive & Utility")
if not tabDefensive then tabDefensive = Menu.Create("Heroes", "Hero List", "Windranger", "Main Settings", "Defensive & Utility") end

-- Icons
local iconWindrun = "panorama/images/spellicons/windrunner_windrun_png.vtex_c"
local iconFocus = "panorama/images/spellicons/windrunner_focusfire_png.vtex_c"

-- [Main Combo]
WR.ComboKey = tabCombo:Bind("Branch Combo Key", Enum.ButtonCode.BUTTON_CODE_NONE)
local comboGear = WR.ComboKey:Gear("Combo Logic Settings")

WR.UseBranch = comboGear:Switch("Use Iron Branch", true)
SetMenuIcon(WR.UseBranch, "panorama/images/items/branches_png.vtex_c")

WR.UseBlink = comboGear:Switch("Use Blink Dagger", true)
SetMenuIcon(WR.UseBlink, "panorama/images/items/blink_png.vtex_c")

WR.UseUlt = comboGear:Switch("Use Focus Fire", true)
SetMenuIcon(WR.UseUlt, iconFocus)

-- [Defensive]
WR.AutoWindrun = tabDefensive:Switch("Smart Auto-Windrun", true)
SetMenuIcon(WR.AutoWindrun, iconWindrun)
local wrGear = WR.AutoWindrun:Gear("Windrun Settings")

WR.WindrunHP = wrGear:Slider("HP Threshold %", 1, 100, 30)
WR.WindrunOnAttack = wrGear:Switch("Use if Hero is Attacking Me", true)

-- [Visuals]
WR.DrawInfo = tabDefensive:Switch("Enhanced Visual Markers", true)
WR.DebugLogs = tabDefensive:Switch("Enable Detailed Debug Logging", false)

WR.FontTitle = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)
WR.Font = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 560)
WR.FontSmall = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 460)

-- State Control
WR.LastOrderTime = 0
WR.ActionLockUntil = 0
WR.LastCastType = nil
WR.PendingBranchTarget = nil
WR.PendingBranchPos = nil
WR.PendingBranchPlacedAt = 0
WR.PendingBranchUntil = 0
WR.VisualState = nil

-- [[ UTILS ]]

local function WithAlpha(color, alpha)
    return Color(color.r, color.g, color.b, alpha)
end

local function Pulse(now, speed, minValue, maxValue)
    local wave = 0.5 + 0.5 * math_sin(now * speed)
    return minValue + (maxValue - minValue) * wave
end

local function DebugLog(message)
    if WR.DebugLogs:Get() and Log and Log.Write then
        Log.Write(message)
    end
end

local function GetItem(hero, name)
    for i = 0, 5 do
        local item = NPC.GetItemByIndex(hero, i)
        if item and Ability.GetName(item) == name then return item end
    end
    return nil
end

local function GetBlink(hero)
    local blinkNames = {"item_blink", "item_overwhelming_blink", "item_swift_blink", "item_arcane_blink"}
    for _, name in ipairs(blinkNames) do
        local item = GetItem(hero, name)
        if item and Ability.IsReady(item) then return item end
    end
    return nil
end

local function IsValidTarget(target)
    return target
        and Entity.IsAlive(target)
        and not Entity.IsDormant(target)
        and not NPC.IsIllusion(target)
end

local function GetTarget(hero)
    local cursor = Vec2(Input.GetCursorPos())
    local enemies = Entity.GetHeroesInRadius(hero, 2000, Enum.TeamType.TEAM_ENEMY, true, true)
    local best, dist = nil, 500

    for _, enemy in ipairs(enemies) do
        if IsValidTarget(enemy) then
            local screenPos, onScreen = Render.WorldToScreen(Entity.GetAbsOrigin(enemy))
            if onScreen then
                local d = (cursor - screenPos):Length()
                if d < dist then
                    best = enemy
                    dist = d
                end
            end
        end
    end

    return best
end

local function GetVelocity(target)
    local vel = Entity.GetField(target, "m_vecVelocity")
    if vel and vel:Length() > 5 then return vel end
    if NPC.IsRunning(target) then
        local rot = Entity.GetRotation(target)
        if rot then return rot:GetForward():Normalized():Scaled(NPC.GetMoveSpeed(target)) end
    end
    return Vector(0, 0, 0)
end

local function Predict(myPos, target, delay)
    local pos = Entity.GetAbsOrigin(target)
    local vel = GetVelocity(target)
    if vel:Length() < 5 then return pos end

    local out = pos
    for _ = 1, 3 do
        local travelTime = out:Distance(myPos) / 1650
        out = pos + vel:Scaled(delay + travelTime)
    end
    return out
end

local function Distance2D(a, b)
    local delta = a - b
    delta.z = 0
    return delta:Length()
end

local function Direction2D(fromPos, toPos)
    local delta = toPos - fromPos
    delta.z = 0
    local len = delta:Length()
    if len < 1 then return nil, len end
    return delta:Scaled(1 / len), len
end

local function W2S(pos)
    if not pos then return nil, false end
    return Render.WorldToScreen(pos)
end

local function DrawOutlinedText(font, size, text, pos, color, shadowAlpha)
    local shadow = Color(0, 0, 0, shadowAlpha or 160)
    Render.Text(font, size, text, pos + Vec2(1, 1), shadow)
    Render.Text(font, size, text, pos, color)
end

local function DrawScreenDashed(fromPos, toPos, color, thickness, dash, gap)
    local delta = toPos - fromPos
    local len = delta:Length()
    if len <= 0.01 then return end

    local dir = Vec2(delta.x / len, delta.y / len)
    local t = 0
    while t < len do
        local seg = math_min(dash, len - t)
        Render.Line(fromPos + dir * t, fromPos + dir * (t + seg), color, thickness)
        t = t + dash + gap
    end
end

local function DrawWorldLine(fromPos, toPos, color, thickness)
    local s1, v1 = W2S(fromPos)
    local s2, v2 = W2S(toPos)
    if v1 and v2 then
        Render.Line(s1, s2, color, thickness or 1.5)
    end
end

local function DrawWorldDashed(fromPos, toPos, color, thickness, dash, gap)
    local s1, v1 = W2S(fromPos)
    local s2, v2 = W2S(toPos)
    if v1 and v2 then
        DrawScreenDashed(s1, s2, color, thickness or 1.25, dash or 7, gap or 5)
    end
end

local function DrawWorldDot(pos, color, now, radius)
    local screenPos, visible = W2S(pos)
    if not visible then return nil, false end

    local haloAlpha = math_floor(Pulse(now, 5.8, 34, 84))
    local ringAlpha = math_floor(Pulse(now, 6.4, 105, 175))
    radius = radius or 5.5

    if Render.CircleGradient then
        Render.CircleGradient(screenPos, radius * 3.2, Color(0, 0, 0, 0), Color(color.r, color.g, color.b, haloAlpha))
    else
        Render.FilledCircle(screenPos, radius * 1.9, Color(color.r, color.g, color.b, math_floor(haloAlpha * 0.55)))
    end

    Render.FilledCircle(screenPos, radius, color)
    Render.FilledCircle(screenPos, math_max(1.6, radius * 0.38), Color(255, 255, 255, 205))
    Render.Circle(screenPos, radius + 4, Color(color.r, color.g, color.b, ringAlpha), 1.5, 0, 1, false, 28)

    return screenPos, true
end

local function DrawWorldTag(pos, text, accent)
    local screenPos, visible = W2S(pos)
    if not visible then return end

    local textSize = Render.TextSize(WR.FontSmall, 11, text)
    local x = screenPos.x + 12
    local y = screenPos.y - 18
    local start = Vec2(x, y)
    local finish = Vec2(x + textSize.x + 14, y + 18)

    Render.FilledRect(start, finish, Color(10, 14, 20, 188), 6)
    Render.Rect(start, finish, Color(accent.r, accent.g, accent.b, 110), 6, nil, 1.0)
    DrawOutlinedText(WR.FontSmall, 11, text, start + Vec2(7, 3), COLOR_TEXT, 150)
end

local function DrawStatusCard(anchorScreen, title, subtitle, accent)
    local titleSize = Render.TextSize(WR.FontTitle, 15, title)
    local subtitleSize = subtitle and Render.TextSize(WR.FontSmall, 12, subtitle) or Vec2(0, 0)
    local cardWidth = math_max(titleSize.x, subtitleSize.x) + 34
    local cardHeight = subtitle and 42 or 28
    local x = anchorScreen.x + 18
    local y = anchorScreen.y - cardHeight - 16
    local start = Vec2(x, y)
    local finish = Vec2(x + cardWidth, y + cardHeight)

    if Render.Blur then
        Render.Blur(start, finish, 0.9, 0.98, 10)
    end
    if Render.Shadow then
        Render.Shadow(start, finish, COLOR_SHADOW, 14, 10)
    end

    Render.FilledRect(start, finish, COLOR_PANEL, 10)
    Render.Rect(start, finish, Color(accent.r, accent.g, accent.b, 120), 10, nil, 1.0)
    Render.Rect(start, finish, COLOR_PANEL_BORDER, 10, nil, 1.0)
    Render.FilledRect(Vec2(x, y), Vec2(x + cardWidth, y + 3), Color(accent.r, accent.g, accent.b, 175), 10)
    Render.FilledCircle(Vec2(x + 12, y + 15), 4, accent)

    DrawOutlinedText(WR.FontTitle, 15, title, Vec2(x + 22, y + 5), COLOR_TEXT, 165)
    if subtitle then
        DrawOutlinedText(WR.FontSmall, 12, subtitle, Vec2(x + 22, y + 23), COLOR_SUBTEXT, 145)
    end
end

local function AnchorLabel(anchorType)
    if anchorType == "tree" then return "TREE" end
    if anchorType == "unit" then return "UNIT" end
    if anchorType == "pending_branch" then return "BRANCH" end
    return "ANCHOR"
end

local function FindTraversablePointNear(pos)
    if not pos then return nil end
    if not (GridNav and GridNav.IsTraversable) then return pos end
    if GridNav.IsTraversable(pos) then return pos end

    for r = 35, 180, 25 do
        local steps = 8 + math_floor(r / 20)
        for i = 0, steps - 1 do
            local ang = (i / steps) * math_pi * 2
            local probe = Vector(pos.x + math_cos(ang) * r, pos.y + math_sin(ang) * r, pos.z)
            if GridNav.IsTraversable(probe) then
                return probe
            end
        end
    end

    return nil
end

local function GetShackleRange(hero)
    return 800 + NPC.GetCastRangeBonus(hero)
end

local function IsValidAnchor(shotDir, targetPos, anchorPos)
    local anchorDir, dist = Direction2D(targetPos, anchorPos)
    if not anchorDir then return false end
    if dist > (SHACKLE_DISTANCE + SHACKLE_SEARCH_PADDING) then return false end

    local dot = shotDir:Dot(anchorDir)
    if dot < SHACKLE_MIN_DOT then return false end

    return true, dot, dist
end

local function ScoreAnchor(dot, dist, bonus)
    return (dot * 1000) - dist + bonus
end

function WR.ClearPendingBranch()
    WR.PendingBranchTarget = nil
    WR.PendingBranchPos = nil
    WR.PendingBranchPlacedAt = 0
    WR.PendingBranchUntil = 0
end

function WR.ClearVisualState()
    WR.VisualState = nil
end

function WR.GetPendingBranchAnchor(target, shotDir, targetPos, now)
    if not WR.PendingBranchPos or not WR.PendingBranchTarget then return nil end
    if WR.PendingBranchTarget ~= Entity.GetIndex(target) then return nil end
    if now > WR.PendingBranchUntil then
        WR.ClearPendingBranch()
        return nil
    end
    if now < (WR.PendingBranchPlacedAt + BRANCH_REGISTER_DELAY) then return nil end

    local ok, dot, dist = IsValidAnchor(shotDir, targetPos, WR.PendingBranchPos)
    if not ok then return nil end

    return {
        type = "pending_branch",
        pos = WR.PendingBranchPos,
        dot = dot,
        dist = dist,
        score = ScoreAnchor(dot, dist, 50)
    }
end

local function FindNaturalShackleAnchor(myHero, target, shotDir, targetPos)
    local best = nil
    local bestScore = -math_huge

    if Trees and Trees.InRadius then
        local trees = Trees.InRadius(targetPos, SHACKLE_DISTANCE + SHACKLE_SEARCH_PADDING, true) or {}
        for _, tree in ipairs(trees) do
            local treePos = Entity.GetAbsOrigin(tree)
            if treePos then
                local ok, dot, dist = IsValidAnchor(shotDir, targetPos, treePos)
                if ok then
                    local score = ScoreAnchor(dot, dist, 25)
                    if score > bestScore then
                        bestScore = score
                        best = {
                            type = "tree",
                            pos = treePos,
                            dot = dot,
                            dist = dist,
                            score = score
                        }
                    end
                end
            end
        end
    end

    local enemyUnits = Entity.GetUnitsInRadius(myHero, 1800, Enum.TeamType.TEAM_ENEMY, true, true) or {}
    for _, unit in ipairs(enemyUnits) do
        if unit ~= target
            and Entity.IsAlive(unit)
            and not Entity.IsDormant(unit)
            and not NPC.IsCourier(unit)
            and not NPC.IsStructure(unit) then
            local unitPos = Entity.GetAbsOrigin(unit)
            local ok, dot, dist = IsValidAnchor(shotDir, targetPos, unitPos)
            if ok then
                local score = ScoreAnchor(dot, dist, 10)
                if score > bestScore then
                    bestScore = score
                    best = {
                        type = "unit",
                        pos = unitPos,
                        dot = dot,
                        dist = dist,
                        score = score,
                        unit = unit
                    }
                end
            end
        end
    end

    return best
end

local function GetBranchPlantPos(fromPos, targetPos, shotDir)
    local branchPos = targetPos + shotDir:Scaled(BRANCH_OFFSET)
    if Distance2D(fromPos, branchPos) > BRANCH_CAST_RANGE then return nil end
    if GridNav and GridNav.IsTraversable and not GridNav.IsTraversable(branchPos) then return nil end
    return branchPos
end

function WR.EvaluateComboPosition(myHero, target, shackle, fromPos, branchReady, now)
    local castDelay = Ability.GetCastPoint(shackle) + 0.03
    local targetPos = Predict(fromPos, target, castDelay)
    local shotDir, dist = Direction2D(fromPos, targetPos)
    if not shotDir then return nil end

    local bestAnchor = WR.GetPendingBranchAnchor(target, shotDir, targetPos, now)
    local naturalAnchor = FindNaturalShackleAnchor(myHero, target, shotDir, targetPos)

    if naturalAnchor and (not bestAnchor or naturalAnchor.score > bestAnchor.score) then
        bestAnchor = naturalAnchor
    end

    local inRange = dist <= GetShackleRange(myHero)
    local branchPos = nil
    if not bestAnchor and branchReady then
        branchPos = GetBranchPlantPos(fromPos, targetPos, shotDir)
    end

    local score = -dist * 0.1
    if inRange then score = score + 100 end
    if bestAnchor then score = score + 1000 end
    if branchPos then score = score + 650 end

    return {
        fromPos = fromPos,
        targetPos = targetPos,
        shotDir = shotDir,
        dist = dist,
        anchor = bestAnchor,
        branchPos = branchPos,
        canDirectShackle = inRange and bestAnchor ~= nil,
        canBranchShackle = inRange and branchPos ~= nil,
        score = score
    }
end

function WR.FindBlinkSolution(myHero, target, shackle, branchReady, now)
    local myPos = Entity.GetAbsOrigin(myHero)
    local baseSolution = WR.EvaluateComboPosition(myHero, target, shackle, myPos, branchReady, now)
    local center = (baseSolution and baseSolution.targetPos) or Predict(myPos, target, Ability.GetCastPoint(shackle) + 0.03)

    local best = nil
    local seen = {}

    local function consider(pos)
        if not pos then return end
        pos = FindTraversablePointNear(pos)
        if not pos then return end
        if Distance2D(myPos, pos) > BLINK_CAST_RANGE then return end

        local key = tostring(math_floor(pos.x / 20 + 0.5)) .. ":" .. tostring(math_floor(pos.y / 20 + 0.5))
        if seen[key] then return end
        seen[key] = true

        local solution = WR.EvaluateComboPosition(myHero, target, shackle, pos, branchReady, now)
        if not solution then return end
        if not solution.canDirectShackle and not solution.canBranchShackle then return end

        local score = solution.score
        if solution.canDirectShackle then
            score = score + 250
        end
        score = score - (Distance2D(myPos, pos) * 0.03)

        if not best or score > best.score then
            best = {
                pos = pos,
                solution = solution,
                score = score
            }
        end
    end

    local outwardDir = select(1, Direction2D(center, myPos))
    if outwardDir then
        consider(center + outwardDir:Scaled(80))
        consider(center + outwardDir:Scaled(95))
    end

    for _, radius in ipairs(BLINK_RING_DISTANCES) do
        for i = 0, BLINK_RING_STEPS - 1 do
            local ang = (i / BLINK_RING_STEPS) * math_pi * 2
            consider(Vector(center.x + math_cos(ang) * radius, center.y + math_sin(ang) * radius, center.z))
        end
    end

    return best
end

function WR.UpdateVisualState(heroPos, target, shackleRange, solution, blinkPlan)
    if not target then
        WR.ClearVisualState()
        return
    end

    local mode = "none"
    local accent = COLOR_BAD
    local title = "NO SHACKLE"
    local subtitle = "Waiting for a real bind"
    local displaySolution = solution

    if solution and solution.canDirectShackle then
        mode = "direct"
        accent = COLOR_GOOD
        title = "DIRECT SHACKLE"
        subtitle = string.format("%s ANCHOR - %du / %du", AnchorLabel(solution.anchor.type), math_floor(solution.dist), math_floor(shackleRange))
    elseif solution and solution.canBranchShackle then
        mode = "branch"
        accent = COLOR_BRANCH
        title = "BRANCH SETUP"
        subtitle = string.format("PLACE BRANCH - %du / %du", math_floor(solution.dist), math_floor(shackleRange))
    elseif blinkPlan and blinkPlan.solution then
        displaySolution = blinkPlan.solution
        accent = COLOR_BLINK
        if blinkPlan.solution.canDirectShackle then
            mode = "blink_direct"
            title = "BLINK TO SHACKLE"
            subtitle = string.format("%s AFTER BLINK - %du", AnchorLabel(blinkPlan.solution.anchor.type), math_floor(Distance2D(heroPos, blinkPlan.pos)))
        else
            mode = "blink_branch"
            title = "BLINK TO BRANCH"
            subtitle = string.format("SETUP RANGE - %du", math_floor(Distance2D(heroPos, blinkPlan.pos)))
        end
    elseif solution then
        subtitle = string.format("OUT OF WINDOW - %du / %du", math_floor(solution.dist), math_floor(shackleRange))
    end

    local linkPos = nil
    local linkLabel = nil
    if displaySolution then
        if displaySolution.anchor then
            linkPos = displaySolution.anchor.pos
            linkLabel = AnchorLabel(displaySolution.anchor.type)
        elseif displaySolution.branchPos then
            linkPos = displaySolution.branchPos
            linkLabel = "BRANCH"
        end
    end

    WR.VisualState = {
        mode = mode,
        color = accent,
        title = title,
        subtitle = subtitle,
        target = target,
        heroPos = heroPos,
        predPos = displaySolution and displaySolution.targetPos or Entity.GetAbsOrigin(target),
        labelPos = Entity.GetAbsOrigin(target) + Vector(0, 0, 110),
        linkPos = linkPos,
        linkLabel = linkLabel,
        blinkPos = blinkPlan and blinkPlan.pos or nil
    }
end

-- [[ LOGIC ]]

function WR.ManageParticles()
    return
end

function WR.ManageWindrun(myHero)
    if not WR.AutoWindrun:Get() then return end

    local windrun = NPC.GetAbility(myHero, "windrunner_windrun")
    if not windrun or not Ability.IsReady(windrun) or not Ability.IsCastable(windrun, NPC.GetMana(myHero)) then return end
    if NPC.HasModifier(myHero, "modifier_windrunner_windrun") then return end

    local hpPerc = Entity.GetHealth(myHero) / Entity.GetMaxHealth(myHero)
    if hpPerc < (WR.WindrunHP:Get() / 100.0) then
        Ability.CastNoTarget(windrun)
        return
    end

    if WR.WindrunOnAttack:Get() then
        local enemies = Entity.GetHeroesInRadius(myHero, 800, Enum.TeamType.TEAM_ENEMY, true, true)
        if enemies then
            for _, enemy in ipairs(enemies) do
                if NPC.IsAttacking(enemy) and NPC.GetAttackTarget(enemy) == myHero then
                    Ability.CastNoTarget(windrun)
                    return
                end
            end
        end
    end
end

function WR.BreakLinkens(myHero, target)
    if not NPC.IsEntityInRange(myHero, target, 1200) then return false end
    if not NPC.HasModifier(target, "modifier_item_sphere_target") and not NPC.HasModifier(target, "modifier_item_linkens_buff") then return false end

    local items = {"item_sheepstick", "item_abyssal_blade", "item_force_staff", "item_hurricane_pike", "item_orchid", "item_bloodthorn"}
    for _, name in ipairs(items) do
        local item = GetItem(myHero, name)
        if item and Ability.IsReady(item) and Ability.IsCastable(item, NPC.GetMana(myHero)) then
            Ability.CastTarget(item, target)
            DebugLog("[WR-Combo] Breaking Linkens with " .. name)
            return true
        end
    end

    return false
end

local function TryFocusOrAttack(myHero, target, focus, dist, now)
    if WR.UseUlt:Get() and focus and Ability.IsReady(focus) and Ability.IsCastable(focus, NPC.GetMana(myHero)) then
        local focusRange = Ability.GetCastRange(focus) + NPC.GetCastRangeBonus(myHero)
        if dist <= (focusRange + 50) then
            Ability.CastTarget(focus, target)
            WR.LastOrderTime = now
            WR.ActionLockUntil = now + 0.10
            WR.LastCastType = "FOCUS"
            return true
        end
    end

    if not NPC.IsAttacking(myHero) then
        Player.PrepareUnitOrders(
            Players.GetLocal(),
            Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
            target,
            Vector(),
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
            myHero
        )
        WR.LastOrderTime = now
        WR.ActionLockUntil = now + 0.08
        WR.LastCastType = "ATTACK"
        return true
    end

    return false
end

function WR.OnUpdate()
    if not Engine.IsInGame() then return end

    local myHero = Player.GetAssignedHero(Players.GetLocal())
    if not myHero or NPC.GetUnitName(myHero) ~= "npc_dota_hero_windrunner" or not Entity.IsAlive(myHero) then
        WR.ClearPendingBranch()
        WR.ClearVisualState()
        return
    end

    WR.ManageWindrun(myHero)

    local now = GameRules.GetGameTime()
    if WR.PendingBranchUntil > 0 and now > WR.PendingBranchUntil then
        WR.ClearPendingBranch()
    end

    local target = GetTarget(myHero)
    local myPos = Entity.GetAbsOrigin(myHero)
    local shackle = NPC.GetAbility(myHero, "windrunner_shackleshot")
    local focus = NPC.GetAbility(myHero, "windrunner_focusfire")
    local branch = WR.UseBranch:Get() and GetItem(myHero, "item_branches") or nil
    local branchReady = branch and Ability.IsReady(branch)
    local blink = WR.UseBlink:Get() and GetBlink(myHero) or nil

    local solution = nil
    local blinkPlan = nil
    if target and shackle then
        solution = WR.EvaluateComboPosition(myHero, target, shackle, myPos, branchReady, now)
        if blink and (not solution or (not solution.canDirectShackle and not solution.canBranchShackle)) then
            blinkPlan = WR.FindBlinkSolution(myHero, target, shackle, branchReady, now)
        end
        WR.UpdateVisualState(myPos, target, GetShackleRange(myHero), solution, blinkPlan)
    else
        WR.ClearVisualState()
    end

    if not WR.ComboKey:IsDown() then
        WR.LastCastType = nil
        WR.ClearPendingBranch()
        return
    end

    if not target or not IsValidTarget(target) or not shackle then return end
    if now < WR.ActionLockUntil then return end
    if (now - WR.LastOrderTime) < GLOBAL_ORDER_THROTTLE then return end

    local dist = solution and solution.dist or Distance2D(myPos, Entity.GetAbsOrigin(target))

    if NPC.HasModifier(target, "modifier_windrunner_shackle_shot") or NPC.IsStunned(target) then
        WR.ClearPendingBranch()
        if TryFocusOrAttack(myHero, target, focus, dist, now) then return end
        return
    end

    if WR.BreakLinkens(myHero, target) then
        WR.LastOrderTime = now
        WR.ActionLockUntil = now + 0.10
        WR.LastCastType = "BREAK_LINKENS"
        return
    end

    if solution and solution.canDirectShackle and Ability.IsReady(shackle) and Ability.IsCastable(shackle, NPC.GetMana(myHero)) then
        Ability.CastTarget(shackle, target)
        WR.LastOrderTime = now
        WR.ActionLockUntil = now + 0.10
        WR.LastCastType = "SHACKLE"
        WR.ClearPendingBranch()
        DebugLog("[WR-Combo] Casting guaranteed Shackleshot (" .. solution.anchor.type .. ")")
        return
    end

    if blink and blinkPlan then
        Ability.CastPosition(blink, blinkPlan.pos)
        WR.LastOrderTime = now
        WR.ActionLockUntil = now + 0.12
        WR.LastCastType = "BLINK"
        DebugLog("[WR-Combo] Blinking into validated shackle setup")
        return
    end

    if solution and solution.canBranchShackle and branch and Ability.IsReady(branch) then
        Ability.CastPosition(branch, solution.branchPos)
        WR.PendingBranchTarget = Entity.GetIndex(target)
        WR.PendingBranchPos = solution.branchPos
        WR.PendingBranchPlacedAt = now
        WR.PendingBranchUntil = now + BRANCH_PENDING_LIFETIME
        WR.LastOrderTime = now
        WR.ActionLockUntil = now + BRANCH_REGISTER_DELAY
        WR.LastCastType = "BRANCH"
        DebugLog("[WR-Combo] Planting branch only for validated shackle")
        return
    end

    TryFocusOrAttack(myHero, target, focus, dist, now)
end

function WR.OnDraw()
    if not WR.DrawInfo:Get() then return end

    local myHero = Player.GetAssignedHero(Players.GetLocal())
    if not myHero or NPC.GetUnitName(myHero) ~= "npc_dota_hero_windrunner" or not Entity.IsAlive(myHero) then return end

    local state = WR.VisualState
    if not state or not state.target or not IsValidTarget(state.target) then return end

    local now = GameRules.GetGameTime()
    local color = state.color or COLOR_BAD
    local predPos = state.predPos
    local linkPos = state.linkPos
    local heroPos = Entity.GetAbsOrigin(myHero)

    if state.mode == "blink_direct" or state.mode == "blink_branch" then
        if state.blinkPos then
            DrawWorldDashed(heroPos, state.blinkPos, WithAlpha(COLOR_BLINK, 195), 1.7, 7, 5)
            DrawWorldDot(state.blinkPos, COLOR_BLINK, now, 4.8)
            DrawWorldTag(state.blinkPos, "BLINK", COLOR_BLINK)
            if predPos then
                DrawWorldLine(state.blinkPos, predPos, WithAlpha(COLOR_BLINK, 210), 1.7)
            end
        end
        if predPos then
            DrawWorldDot(predPos, color, now, 5.8)
        end
        if predPos and linkPos then
            DrawWorldDashed(predPos, linkPos, WithAlpha(color, 205), 1.6, 7, 5)
        end
    else
        if predPos then
            DrawWorldLine(heroPos, predPos, WithAlpha(color, 215), 1.9)
            DrawWorldDot(predPos, color, now, 5.8)
        end
        if predPos and linkPos then
            DrawWorldDashed(predPos, linkPos, WithAlpha(color, 205), 1.6, 7, 5)
        end
    end

    if linkPos and state.linkLabel then
        DrawWorldDot(linkPos, WithAlpha(color, 225), now, 4.5)
        DrawWorldTag(linkPos, state.linkLabel, color)
    end

    local cardAnchor, visible = W2S(state.labelPos or predPos)
    if visible then
        DrawStatusCard(cardAnchor, state.title or "LOCK", state.subtitle, color)
    end
end

return WR
