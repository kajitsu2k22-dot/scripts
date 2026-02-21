--[[
    Night Stalker — Shard Auto Consume Creep
    UCZone API v2.0

    Автоматически использует Hunter in the Night (3 скилл) с шардом,
    чтобы сожрать ближайшего крипа и восстановить 25% макс. HP и маны,
    когда здоровье героя ниже заданного порога.
    Днём нельзя применять на древних крипов.
]]

local script = {}

-- ═══════════════════════════════════════════════════════════════════════════
--  Проверка героя
-- ═══════════════════════════════════════════════════════════════════════════

local function IsNightStalker()
    local myHero = Heroes.GetLocal()
    return myHero and NPC.GetUnitName(myHero) == "npc_dota_hero_night_stalker"
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Константы
-- ═══════════════════════════════════════════════════════════════════════════

local ABILITY_NAME    = "night_stalker_hunter_in_the_night"
local SHARD_CAST_RANGE = 125  -- базовая дальность каста с шардом

-- Паттерны имён древних крипов (для фильтрации днём)
local ANCIENT_PATTERNS = {
    "black_dragon", "black_drake",
    "granite_golem", "rock_golem",
    "thunderhide",
    "prowler_shaman", "prowler_acolyte",
    "elder_dragon",
    "frostbitten",
}

-- ═══════════════════════════════════════════════════════════════════════════
--  Меню  (Heroes > Hero List > Night Stalker > Main Settings > Hero Settings)
-- ═══════════════════════════════════════════════════════════════════════════

local function InitializeUI()
    -- Прямой путь к Hero Settings
    local heroSettings = Menu.Find("Heroes", "Hero List", "Night Stalker", "Main Settings", "Hero Settings")
    
    if not heroSettings then
        -- Если не найдено, создаём fallback меню
        local tab = Menu.Create("General", "Night Stalker Shard", "ns_shard_consume")
        if tab and tab.Icon then
            tab:Icon("panorama/images/heroes/icons/npc_dota_hero_night_stalker_png.vtex_c")
        end
        heroSettings = tab
    end

    local ui = {}

    -- ─── Основные настройки ───

    ui.Enabled = heroSettings:Switch("Auto Consume Creep", false)
    ui.Enabled:Image("panorama/images/spellicons/night_stalker_hunter_in_the_night_png.vtex_c")
    ui.Enabled:ToolTip("Автоматически сжирать ближайшего крипа способностью Hunter in the Night (требуется Aghanim's Shard).")

    ui.HPThreshold = heroSettings:Slider("HP Threshold %", 10, 90, 50, "%d%%")
    ui.HPThreshold:Icon("\u{f21e}")
    ui.HPThreshold:ToolTip("Сожрать крипа когда HP%% героя ниже этого значения.")

    ui.AlsoCheckMana = heroSettings:Switch("Also Trigger on Low Mana", false)
    ui.AlsoCheckMana:Icon("\u{f043}")
    ui.AlsoCheckMana:ToolTip("Также активировать когда мана ниже порога (использует тот же %%).")

    ui.SearchRadius = heroSettings:Slider("Search Radius", 150, 600, 300, "%d")
    ui.SearchRadius:Icon("\u{f140}")
    ui.SearchRadius:ToolTip("Радиус поиска крипов вокруг героя. Если крип дальше каст рейнджа — герой подойдёт к нему.")

    ui.TargetLaneCreeps = heroSettings:Switch("Target Lane Creeps", true)
    ui.TargetLaneCreeps:Image("panorama/images/heroes/icons/npc_dota_hero_night_stalker_png.vtex_c")
    ui.TargetLaneCreeps:ToolTip("Разрешить поедание лейновых крипов.")

    ui.TargetNeutralCreeps = heroSettings:Switch("Target Neutral Creeps", true)
    ui.TargetNeutralCreeps:Icon("\u{f6ee}")
    ui.TargetNeutralCreeps:ToolTip("Разрешить поедание нейтральных крипов (кроме древних днём).")

    -- ─── Видимость ───

    ui.Enabled:SetCallback(function()
        local on = ui.Enabled:Get()
        ui.HPThreshold:Disabled(not on)
        ui.AlsoCheckMana:Disabled(not on)
        ui.SearchRadius:Disabled(not on)
        ui.TargetLaneCreeps:Disabled(not on)
        ui.TargetNeutralCreeps:Disabled(not on)
    end, true)

    return ui
end

local UI = InitializeUI()

-- ═══════════════════════════════════════════════════════════════════════════
--  Состояние
-- ═══════════════════════════════════════════════════════════════════════════

local State = {
    lastCastTime = 0,
}

-- ═══════════════════════════════════════════════════════════════════════════
--  Утилиты
-- ═══════════════════════════════════════════════════════════════════════════

--- Проверяет, является ли герой дизейбленным (стан, хекс, сайленс и т.д.)
local function IsHeroDisabled(hero)
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_STUNNED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_SILENCED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_COMMAND_RESTRICTED) then return true end
    return false
end

--- Определяет, является ли сейчас ночь (для NS: учитывает ульт и временные эффекты)
local function IsNight()
    -- Временный день (напр. Phoenix Supernova) — приоритет
    if GameRules.IsTemporaryDay() then return false end
    -- Ульт Night Stalker (Dark Ascension) или временная ночь (Luna и т.д.)
    if GameRules.IsNightstalkerNight() then return true end
    if GameRules.IsTemporaryNight() then return true end

    -- Базовый цикл: 0-5мин день, 5-10мин ночь, повтор
    local gameTime = GameRules.GetGameTime() - GameRules.GetGameStartTime()
    if gameTime < 0 then return false end
    local cycleTime = gameTime % 600
    return cycleTime >= 300
end

--- Проверяет, является ли крип древним (ancient) по имени юнита
local function IsAncientCreep(npc)
    if not NPC.IsNeutral(npc) then return false end
    local name = NPC.GetUnitName(npc)
    if not name then return false end
    for _, pattern in ipairs(ANCIENT_PATTERNS) do
        if string.find(name, pattern) then return true end
    end
    return false
end

--- Проверяет, валиден ли крип как цель для поедания
local function IsValidCreepTarget(npc, hero, isNight)
    if not npc or not Entity.IsAlive(npc) then return false end
    if Entity.IsDormant(npc) then return false end
    if not NPC.IsCreep(npc) then return false end
    if Entity.GetTeamNum(npc) == Entity.GetTeamNum(hero) then return false end
    if NPC.IsWaitingToSpawn(npc) then return false end

    local isLane    = NPC.IsLaneCreep(npc)
    local isNeutral = NPC.IsNeutral(npc)

    -- Фильтр по настройкам
    if isLane and not UI.TargetLaneCreeps:Get() then return false end
    if isNeutral and not UI.TargetNeutralCreeps:Get() then return false end
    if not isLane and not isNeutral then return false end

    -- Древних крипов днём нельзя сжирать
    if not isNight and IsAncientCreep(npc) then return false end

    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Поиск лучшего крипа для поедания
-- ═══════════════════════════════════════════════════════════════════════════

local function FindBestCreep(hero, ability)
    local heroPos     = Entity.GetAbsOrigin(hero)
    local searchRange = UI.SearchRadius:Get()
    local isNight     = IsNight()

    local bestCreep = nil
    local bestDist  = math.huge

    local allNPCs = NPCs.GetAll()
    for i = 1, #allNPCs do
        local npc = allNPCs[i]
        if IsValidCreepTarget(npc, hero, isNight) then
            local npcPos = Entity.GetAbsOrigin(npc)
            local dist   = (heroPos - npcPos):Length()
            if dist <= searchRange and dist < bestDist then
                bestDist  = dist
                bestCreep = npc
            end
        end
    end

    return bestCreep
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnUpdate — основная логика
-- ═══════════════════════════════════════════════════════════════════════════

script.OnUpdate = function()
    if not IsNightStalker() or not UI.Enabled:Get() or not Engine.IsInGame() then
        return
    end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then return end

    -- Нужен шард
    if not NPC.HasShard(hero) then return end

    -- Проверка порога HP
    local currentHP = Entity.GetHealth(hero)
    local maxHP     = Entity.GetMaxHealth(hero)
    if maxHP <= 0 then return end
    local hpPct     = (currentHP / maxHP) * 100
    local threshold = UI.HPThreshold:Get()

    local needsConsume = hpPct < threshold

    -- Опционально: также триггерить по мане
    if UI.AlsoCheckMana:Get() and not needsConsume then
        local currentMana = NPC.GetMana(hero)
        local maxMana     = NPC.GetMaxMana(hero)
        if maxMana > 0 then
            local manaPct = (currentMana / maxMana) * 100
            needsConsume = manaPct < threshold
        end
    end

    if not needsConsume then return end

    -- Получаем абилку
    local ability = NPC.GetAbility(hero, ABILITY_NAME)
    if not ability then return end
    if Ability.GetLevel(ability) == 0 then return end
    if not Ability.IsCastable(ability, NPC.GetMana(hero)) then return end
    if Ability.GetCooldown(ability) > 0 then return end

    -- Герой не должен быть дизейблен или занят
    if IsHeroDisabled(hero) then return end
    if NPC.GetChannellingAbility(hero) then return end

    -- Защита от спама: кулдаун между попытками каста
    local now = GameRules.GetGameTime()
    if now - State.lastCastTime < 0.5 then return end

    -- Ищем ближайшего крипа
    local target = FindBestCreep(hero, ability)
    if not target then return end

    -- Кастуем
    Ability.CastTarget(ability, target, false, false, false, "ns_shard_consume")
    State.lastCastTime = now
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnGameEnd — сброс состояния
-- ═══════════════════════════════════════════════════════════════════════════

script.OnGameEnd = function()
    State.lastCastTime = 0
end

return script
