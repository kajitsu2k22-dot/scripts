--[[
    Sniper — Auto Concussive Grenade
    UCZone API v2.0

    Автоматически кастует Concussive Grenade когда вражеский герой подходит
    слишком близко к Sniper. Откидывает врагов и самого Sniper в разные стороны.
    Требует: Aghanim's Shard
]]

local script = {}

-- ═══════════════════════════════════════════════════════════════════════════
--  Константы
-- ═══════════════════════════════════════════════════════════════════════════

local GRENADE_NAME          = "sniper_concussive_grenade"
local GRENADE_SLOW_MODIFIER = "modifier_sniper_concussive_grenade_slow"
local GRENADE_KB_MODIFIER   = "modifier_knockback"
local GRENADE_RADIUS        = 375
local GRENADE_CAST_ANIM     = 0.1
local GRENADE_PROJ_SPEED    = 2500

-- ═══════════════════════════════════════════════════════════════════════════
--  Меню  (Heroes > Hero List > Sniper > Main Settings > Concussive Grenade)
-- ═══════════════════════════════════════════════════════════════════════════

local function InitializeUI()
    local mainSettings = Menu.Find("Heroes", "Hero List", "Sniper", "Main Settings")
    local group
    if mainSettings and mainSettings.Create then
        group = mainSettings:Create("Concussive Grenade")
    end
    if not group then
        group = Menu.Create("General", "Sniper", "Concussive Grenade", "Settings", "Grenade")
    end

    local ui = {}

    -- ─── 🔘 Main Switch ───
    ui.Enabled = group:Switch("Auto Grenade", false)
    ui.Enabled:Image("panorama/images/spellicons/sniper_concussive_grenade_png.vtex_c")

    -- ⚙ Gear: все настройки внутри шестерёнки
    local gear = ui.Enabled:Gear("⚙ Settings")

    gear:Label("🎯 Targeting")
    ui.TriggerRadius = gear:Slider("📏 Trigger Radius", 200, 800, 500, "%d")
    ui.SmartCast     = gear:Switch("🧠 Smart Cast Position", true)
    ui.SkipSlowed    = gear:Switch("⏭ Skip Already Slowed", true)

    gear:Label("❤ Low HP")
    ui.LowHP           = gear:Switch("🛡 Expand on Low HP", true)
    ui.LowHPThreshold  = gear:Slider("💔 HP Threshold %", 10, 60, 40, "%d%%")
    ui.LowHPExtraRange = gear:Slider("📐 Extra Radius", 50, 400, 200, "%d")

    -- ─── Visibility ───
    ui.Enabled:SetCallback(function()
        local on = ui.Enabled:Get()
        ui.TriggerRadius:Disabled(not on)
        ui.SmartCast:Disabled(not on)
        ui.SkipSlowed:Disabled(not on)
        ui.LowHP:Disabled(not on)
        ui.LowHPThreshold:Disabled(not on)
        ui.LowHPExtraRange:Disabled(not on)
    end, true)

    ui.LowHP:SetCallback(function()
        local on = ui.LowHP:Get() and ui.Enabled:Get()
        ui.LowHPThreshold:Disabled(not on)
        ui.LowHPExtraRange:Disabled(not on)
    end, true)

    return ui
end

local UI = InitializeUI()

-- ═══════════════════════════════════════════════════════════════════════════
--  Состояние
-- ═══════════════════════════════════════════════════════════════════════════

local State = { lastCastTime = 0 }

-- ═══════════════════════════════════════════════════════════════════════════
--  Утилиты
-- ═══════════════════════════════════════════════════════════════════════════

local function IsSniper()
    local me = Heroes.GetLocal()
    return me and NPC.GetUnitName(me) == "npc_dota_hero_sniper"
end

local function IsHeroDisabled(hero)
    if NPC.HasState(hero, Enum.ModifierState.STUNNED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.HEXED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.SILENCED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.ROOTED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.COMMAND_RESTRICTED) then return true end
    return false
end

local function IsValidEnemy(enemy)
    if not Entity.IsAlive(enemy) then return false end
    if Entity.IsDormant(enemy) then return false end
    if NPC.IsIllusion(enemy) then return false end
    if NPC.IsInvulnerable and NPC.IsInvulnerable(enemy) then return false end
    if NPC.IsVisible and not NPC.IsVisible(enemy) then return false end
    return true
end

local function EnemyAlreadyAffected(enemy)
    if NPC.HasModifier(enemy, GRENADE_SLOW_MODIFIER) then return true end
    if NPC.HasModifier(enemy, GRENADE_KB_MODIFIER) then return true end
    return false
end

local function PredictEnemyPos(enemy, t)
    local pos = Entity.GetAbsOrigin(enemy)
    if t <= 0 then return pos end
    if NPC.IsMoving and not NPC.IsMoving(enemy) then return pos end
    if NPC.IsStunned and NPC.IsStunned(enemy) then return pos end
    if NPC.IsRooted and NPC.IsRooted(enemy) then return pos end

    local fwd   = NPC.GetForwardVector and NPC.GetForwardVector(enemy)
    if not fwd then return pos end
    local speed = NPC.GetMoveSpeed(enemy) or 300
    return Vector(
        pos.x + fwd.x * speed * t,
        pos.y + fwd.y * speed * t,
        pos.z
    )
end

--- Оптимальная точка каста: между Sniper и врагом, оба в радиусе 375
local function SmartCastPos(heroPos, enemyPos)
    local dir  = Vector(enemyPos.x - heroPos.x, enemyPos.y - heroPos.y, 0)
    local dist = dir:Length2D()
    if dist < 1 then return heroPos end

    local nx, ny = dir.x / dist, dir.y / dist
    local offset = (dist <= GRENADE_RADIUS * 2) and (dist * 0.5)
                   or (dist - GRENADE_RADIUS + 50)

    return Vector(heroPos.x + nx * offset, heroPos.y + ny * offset, heroPos.z)
end

local function GetTriggerRadius(hero)
    local r = UI.TriggerRadius:Get()
    if UI.LowHP:Get() then
        local hp  = Entity.GetHealth(hero)
        local max = Entity.GetMaxHealth(hero)
        if max > 0 then
            local pct = (hp / max) * 100
            local thr = UI.LowHPThreshold:Get()
            if pct < thr then
                r = r + math.floor(UI.LowHPExtraRange:Get() * (1.0 - pct / thr))
            end
        end
    end
    return r
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Поиск лучшей цели
-- ═══════════════════════════════════════════════════════════════════════════

local function FindBestTarget(hero, radius)
    local heroPos    = Entity.GetAbsOrigin(hero)
    local skipSlowed = UI.SkipSlowed:Get()
    local enemies    = Heroes.InRadius(heroPos, radius,
                            Entity.GetTeamNum(hero), Enum.TeamType.TEAM_ENEMY)

    local best, bestDist = nil, math.huge
    for _, e in ipairs(enemies) do
        if IsValidEnemy(e) then
            if not (skipSlowed and EnemyAlreadyAffected(e)) then
                local d = heroPos:Distance2D(Entity.GetAbsOrigin(e))
                if d < bestDist then
                    bestDist = d
                    best     = e
                end
            end
        end
    end
    return best, bestDist
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnUpdate
-- ═══════════════════════════════════════════════════════════════════════════

script.OnUpdate = function()
    if not Engine.IsInGame() then return end
    if not IsSniper() then return end
    if not UI.Enabled:Get() then return end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then return end
    if not NPC.HasShard(hero) then return end
    if IsHeroDisabled(hero) then return end
    if NPC.IsChannellingAbility and NPC.IsChannellingAbility(hero) then return end

    local ability = NPC.GetAbility(hero, GRENADE_NAME)
    if not ability then return end
    if Ability.GetLevel(ability) == 0 then return end
    if not Ability.IsCastable(ability, NPC.GetMana(hero)) then return end
    if Ability.GetCooldown(ability) > 0 then return end

    local now = GameRules.GetGameTime()
    if now - State.lastCastTime < 0.3 then return end

    local radius = GetTriggerRadius(hero)
    local target, dist = FindBestTarget(hero, radius)
    if not target then return end

    local heroPos = Entity.GetAbsOrigin(hero)
    local castPos

    if UI.SmartCast:Get() then
        local travelTime = dist / GRENADE_PROJ_SPEED
        local predicted  = PredictEnemyPos(target, GRENADE_CAST_ANIM + travelTime)
        castPos = SmartCastPos(heroPos, predicted)
    else
        local enemyPos = Entity.GetAbsOrigin(target)
        castPos = heroPos:Lerp(enemyPos, 0.5)
    end

    -- Clamp к cast range
    local castRange = Ability.GetCastRange(ability) or 600
    local castDist  = heroPos:Distance2D(castPos)
    if castDist > castRange then
        local d   = Vector(castPos.x - heroPos.x, castPos.y - heroPos.y, 0)
        local len = d:Length2D()
        if len > 1 then
            castPos = Vector(
                heroPos.x + (d.x / len) * castRange,
                heroPos.y + (d.y / len) * castRange,
                heroPos.z
            )
        end
    end

    Ability.CastPosition(ability, castPos, false, false, false, "auto_grenade")
    State.lastCastTime = now
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnGameEnd
-- ═══════════════════════════════════════════════════════════════════════════

script.OnGameEnd = function()
    State.lastCastTime = 0
end

return script
