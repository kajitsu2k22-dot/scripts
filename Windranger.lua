local WR = {}

local NPC, Ability, Entity, Render, Menu, Players, Player, Engine, GameRules, Input, Particle = 
      NPC, Ability, Entity, Render, Menu, Players, Player, Engine, GameRules, Input, Particle

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
local iconShackle = "panorama/images/spellicons/windrunner_shackleshot_png.vtex_c"
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

WR.Font = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500)

-- State Control
WR.LastOrderTime = 0
WR.LastTargetIdx = nil
WR.LastCastType = nil -- Track what we just did to prevent loops

-- Particles
local pTarget = "particles/ui_mouseactions/custom_ping_danger.vpcf"
local pBranch = "particles/ui_mouseactions/range_display.vpcf"
WR.ActiveTargetParticle = nil
WR.ActiveBranchParticle = nil

-- [[ UTILS ]]
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

local function GetTarget(hero)
    local cursor = Vec2(Input.GetCursorPos())
    local enemies = Entity.GetHeroesInRadius(hero, 2000, Enum.TeamType.TEAM_ENEMY, true, true)
    local best, dist = nil, 500
    
    for _, enemy in ipairs(enemies) do
        if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and not NPC.IsIllusion(enemy) then
            local screenPos, onScreen = Render.WorldToScreen(Entity.GetAbsOrigin(enemy))
            if onScreen then
                local d = (cursor - screenPos):Length()
                if d < dist then best, dist = enemy, d end
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
    return Vector(0,0,0)
end

local function Predict(myPos, target, delay)
    local pos = Entity.GetAbsOrigin(target)
    local vel = GetVelocity(target)
    if vel:Length() < 5 then return pos end
    local out = pos
    for i = 1, 3 do 
        local travelTime = out:Distance(myPos) / 1650
        out = pos + vel:Scaled(delay + travelTime) 
    end
    return out
end

-- [[ LOGIC ]]

function WR.ManageParticles(myHero, target, predPos, treePos)
    if not WR.DrawInfo:Get() or not target then
        if WR.ActiveTargetParticle then Particle.Destroy(WR.ActiveTargetParticle); WR.ActiveTargetParticle = nil end
        if WR.ActiveBranchParticle then Particle.Destroy(WR.ActiveBranchParticle); WR.ActiveBranchParticle = nil end
        WR.LastTargetIdx = nil
        return
    end

    local tIdx = Entity.GetIndex(target)
    if WR.LastTargetIdx ~= tIdx then
        if WR.ActiveTargetParticle then Particle.Destroy(WR.ActiveTargetParticle) end
        if WR.ActiveBranchParticle then Particle.Destroy(WR.ActiveBranchParticle) end
        WR.ActiveTargetParticle = Particle.Create(pTarget, Enum.ParticleAttachment.PATTACH_WORLDORIGIN, myHero)
        WR.ActiveBranchParticle = Particle.Create(pBranch, Enum.ParticleAttachment.PATTACH_WORLDORIGIN, myHero)
        WR.LastTargetIdx = tIdx
    end

    if WR.ActiveTargetParticle then Particle.SetControlPoint(WR.ActiveTargetParticle, 0, predPos); Particle.SetControlPoint(WR.ActiveTargetParticle, 1, Vector(100, 0, 0)) end
    if WR.ActiveBranchParticle and treePos then Particle.SetControlPoint(WR.ActiveBranchParticle, 0, treePos); Particle.SetControlPoint(WR.ActiveBranchParticle, 1, Vector(150, 0, 0)); Particle.SetControlPoint(WR.ActiveBranchParticle, 15, Vector(0, 255, 255)) end
end

function WR.ManageWindrun(myHero)
    if not WR.AutoWindrun:Get() then return end
    local windrun = NPC.GetAbility(myHero, "windrunner_windrun")
    if not windrun or not Ability.IsReady(windrun) or not Ability.IsCastable(windrun, NPC.GetMana(myHero)) then return end
    if NPC.HasModifier(myHero, "modifier_windrunner_windrun") then return end
    local hpPerc = Entity.GetHealth(myHero) / Entity.GetMaxHealth(myHero)
    if hpPerc < (WR.WindrunHP:Get() / 100.0) then Ability.CastNoTarget(windrun); return end
    if WR.WindrunOnAttack:Get() then
        local enemies = Entity.GetHeroesInRadius(myHero, 800, Enum.TeamType.TEAM_ENEMY, true, true)
        if enemies then
            for _, enemy in ipairs(enemies) do
                if NPC.IsAttacking(enemy) and NPC.GetAttackTarget(enemy) == myHero then Ability.CastNoTarget(windrun); return end
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
        if item and Ability.IsReady(item) then Ability.CastTarget(item, target); return true end
    end
    local shackle = NPC.GetAbility(myHero, "windrunner_shackleshot")
    if shackle and Ability.IsReady(shackle) then Ability.CastTarget(shackle, target); return true end
    return false
end

function WR.OnUpdate()
    if not Engine.IsInGame() then return end
    local myHero = Player.GetAssignedHero(Players.GetLocal())
    if not myHero or NPC.GetUnitName(myHero) ~= "npc_dota_hero_windrunner" or not Entity.IsAlive(myHero) then WR.ManageParticles(nil, nil, nil, nil); return end
    WR.ManageWindrun(myHero)

    local target = GetTarget(myHero)
    local myPos = Entity.GetAbsOrigin(myHero)
    local predPos, treePos = nil, nil
    if target then
        predPos = Predict(myPos, target, 0.3)
        local dir = (predPos - myPos):Normalized()
        local treeDist = myPos:Distance(predPos) + 100
        if treeDist > 195 then treeDist = 195 end
        treePos = myPos + dir:Scaled(treeDist)
    end
    WR.ManageParticles(myHero, target, predPos, treePos)

    if not WR.ComboKey:IsDown() then WR.LastCastType = nil; return end
    if not target then return end

    local now = GameRules.GetGameTime()
    if now - WR.LastOrderTime < 0.1 then return end -- Consistent global throttle

    local shackle = NPC.GetAbility(myHero, "windrunner_shackleshot")
    local focus = NPC.GetAbility(myHero, "windrunner_focusfire")
    if not shackle then return end

    local dist = myPos:Distance(predPos)
    local sRange = 800 + NPC.GetCastRangeBonus(myHero)

    -- IF WE ALREADY STUNNED THEM, JUST FOCUS AND ATTACK
    if NPC.HasModifier(target, "modifier_windrunner_shackle_shot") or NPC.IsStunned(target) then
        if WR.UseUlt:Get() and focus and Ability.IsReady(focus) and Ability.IsCastable(focus, NPC.GetMana(myHero)) then
            if dist <= Ability.GetCastRange(focus) + 150 then
                Ability.CastTarget(focus, target)
                WR.LastOrderTime = now
                return
            end
        end
        if not NPC.IsAttacking(myHero) then
            Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, target, Vector(), nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, myHero)
            WR.LastOrderTime = now
        end
        return
    end

    -- LINKENS BREAK
    if WR.BreakLinkens(myHero, target) then WR.LastOrderTime = now; return end

    -- BLINK
    if WR.UseBlink:Get() and WR.LastCastType ~= "BLINK" then
        local blink = GetBlink(myHero)
        if blink then
            local blinkDist = WR.UseBranch:Get() and 90 or 400
            if dist > (blinkDist + 150) or dist > (sRange + 100) then
                local bPos = predPos - (predPos - myPos):Normalized():Scaled(blinkDist)
                Ability.CastPosition(blink, bPos)
                WR.LastOrderTime = now
                WR.LastCastType = "BLINK"
                if WR.DebugLogs:Get() then Log.Write("[WR-Combo] Blinking") end
                return
            end
        end
    end

    -- BRANCH
    local branch = WR.UseBranch:Get() and GetItem(myHero, "item_branches")
    if branch and Ability.IsReady(branch) and WR.LastCastType ~= "BRANCH" then
        if myPos:Distance(treePos) <= 200 then
            Ability.CastPosition(branch, treePos)
            WR.LastOrderTime = now -- Short delay for tree registration
            WR.LastCastType = "BRANCH"
            if WR.DebugLogs:Get() then Log.Write("[WR-Combo] Planting Branch Tree") end
            return
        end
    end

    -- SHACKLE
    if Ability.IsReady(shackle) and Ability.IsCastable(shackle, NPC.GetMana(myHero)) and dist <= sRange then
        Ability.CastTarget(shackle, target)
        WR.LastOrderTime = now
        WR.LastCastType = "SHACKLE"
        if WR.DebugLogs:Get() then Log.Write("[WR-Combo] Casting Shackleshot") end
        return
    end

    -- LAST RESORT: FOCUS/ATTACK
    if WR.UseUlt:Get() and focus and Ability.IsReady(focus) and dist <= Ability.GetCastRange(focus) then
        Ability.CastTarget(focus, target)
        WR.LastOrderTime = now
    elseif not NPC.IsAttacking(myHero) then
        Player.PrepareUnitOrders(Players.GetLocal(), Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET, target, Vector(), nil, Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY, myHero)
        WR.LastOrderTime = now
    end
end

function WR.OnDraw()
    if not WR.DrawInfo:Get() then return end
    local myHero = Player.GetAssignedHero(Players.GetLocal())
    if not myHero or NPC.GetUnitName(myHero) ~= "npc_dota_hero_windrunner" then return end
    local target = GetTarget(myHero)
    if target then
        local pPos = Predict(Entity.GetAbsOrigin(myHero), target, 0.3)
        local screenTarget, onTarget = Render.WorldToScreen(pPos)
        if onTarget then Render.Text(WR.Font, 16, "LOCK ON", screenTarget + Vec2(0, -50), Color(255, 255, 255, 255)) end
    end
end

return WR
