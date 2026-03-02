---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
--[[
    Terrorblade — Sunder Auto-Cast Fix
    UCZone API v2.0

    Фикс встроенного авто-Сандера, который отменяет/не пытается кастовать.
    Проблема оригинала: конфликтующие ордера прерывают фазу каста Sunder.
    
    Решение:
      • Блокировка любых конфликтующих ордеров во время ability phase Sunder
      • Корректная проверка ready-состояния перед кастом
      • Собственная логика выбора лучшей цели (враг с наибольшим HP%)
      • Поддержка каста на союзников (опционально)
      • Cooldown между попытками каста — без спама
]]

local script = {}

-- ═══════════════════════════════════════════════════════════════════════════
--  Проверка героя
-- ═══════════════════════════════════════════════════════════════════════════

local function IsTerroblade()
    local myHero = Heroes.GetLocal()
    return myHero and NPC.GetUnitName(myHero) == "npc_dota_hero_terrorblade"
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Константы
-- ═══════════════════════════════════════════════════════════════════════════

local ABILITY_SUNDER = "terrorblade_sunder"

-- Модификаторы, при которых не нужно кастовать Sunder (ТБ защищён)
local SELF_SAFE_MODIFIERS = {
    "modifier_oracle_false_promise",        -- Oracle ult (отложенный урон)
    "modifier_dazzle_shallow_grave",        -- Shallow Grave (нельзя умереть)
    "modifier_abaddon_borrowed_time",       -- Borrowed Time (активирован)
}

-- Модификаторы на враге, при которых Sunder бесполезен
local TARGET_IGNORE_MODIFIERS = {
    "modifier_oracle_false_promise",
    "modifier_dazzle_shallow_grave",
    "modifier_abaddon_borrowed_time",
    "modifier_skeleton_king_reincarnation",
    "modifier_winter_wyvern_winters_curse",
    "modifier_necrolyte_reapers_scythe",
}

-- Модификаторы, которые делают каст невозможным
local CAST_BLOCKING_MODIFIERS = {
    "modifier_spirit_breaker_charge_of_darkness",
}

-- ═══════════════════════════════════════════════════════════════════════════
--  Меню — переключатель прямо в Sunder-секции встроенного меню
-- ═══════════════════════════════════════════════════════════════════════════

local UI = {}

local function InitializeUI()
    -- Находим встроенную группу Sunder
    local sunderGroup = Menu.Find("Heroes", "Hero List", "Terrorblade", "Main Settings", "Sunder")

    if sunderGroup then
        -- Добавляем переключатель прямо в секцию Sunder
        UI.Enabled = sunderGroup:Switch("Sunder Fix", false)
        UI.Enabled:Image("panorama/images/spellicons/terrorblade_sunder_png.vtex_c")
        UI.Enabled:ToolTip("Фикс авто-Sunder: корректный каст без отмены, блокировка конфликтующих ордеров.")

        -- Настройки в Gear-аттачменте
        local gear = UI.Enabled:Gear("Sunder Fix Settings")

        UI.SelfHPThreshold = gear:Slider("Self HP Threshold %", 5, 50, 25, "%d%%")
        UI.SelfHPThreshold:Icon("\u{f21e}")
        UI.SelfHPThreshold:ToolTip("Использовать Sunder когда HP%% Terrorblade ниже этого значения.")

        UI.EnemyHPThreshold = gear:Slider("Enemy Min HP %", 20, 100, 50, "%d%%")
        UI.EnemyHPThreshold:Icon("\u{f06d}")
        UI.EnemyHPThreshold:ToolTip("Кастовать на врага только если его HP%% выше этого значения.")

        UI.AllowAllies = gear:Switch("Allow Sunder on Allies", false)
        UI.AllowAllies:Icon("\u{f0c0}")
        UI.AllowAllies:ToolTip("Разрешить авто-Sunder на союзных героев (когда у них много HP).")

        UI.AllyHPThreshold = gear:Slider("Ally Min HP %", 50, 100, 75, "%d%%")
        UI.AllyHPThreshold:Icon("\u{f004}")
        UI.AllyHPThreshold:ToolTip("Кастовать на союзника если его HP%% выше этого значения.")

        UI.BlockOrders = gear:Switch("Block Conflicting Orders", true)
        UI.BlockOrders:Icon("\u{f05e}")
        UI.BlockOrders:ToolTip("Блокировать ордера которые могут отменить каст Sunder.")
    else
        -- Fallback: создаём своё меню если встроенное не найдено
        local tab = Menu.Create("General", "TB Sunder Fix", "tb_sunder_fix")
        if tab and tab.Icon then
            tab:Icon("panorama/images/heroes/icons/npc_dota_hero_terrorblade_png.vtex_c")
        end
        local mainGroup = tab:Create("Settings")

        UI.Enabled = mainGroup:Switch("Sunder Fix", false)
        UI.Enabled:Image("panorama/images/spellicons/terrorblade_sunder_png.vtex_c")
        UI.Enabled:ToolTip("Фикс авто-Sunder: корректный каст без отмены, блокировка конфликтующих ордеров.")

        UI.SelfHPThreshold = mainGroup:Slider("Self HP Threshold %", 5, 50, 25, "%d%%")
        UI.SelfHPThreshold:Icon("\u{f21e}")

        UI.EnemyHPThreshold = mainGroup:Slider("Enemy Min HP %", 20, 100, 50, "%d%%")
        UI.EnemyHPThreshold:Icon("\u{f06d}")

        UI.AllowAllies = mainGroup:Switch("Allow Sunder on Allies", false)
        UI.AllowAllies:Icon("\u{f0c0}")

        UI.AllyHPThreshold = mainGroup:Slider("Ally Min HP %", 50, 100, 75, "%d%%")
        UI.AllyHPThreshold:Icon("\u{f004}")

        UI.BlockOrders = mainGroup:Switch("Block Conflicting Orders", true)
        UI.BlockOrders:Icon("\u{f05e}")
    end
end

InitializeUI()

-- ═══════════════════════════════════════════════════════════════════════════
--  Состояние
-- ═══════════════════════════════════════════════════════════════════════════

local State = {
    lastCastTime    = 0,     -- время последнего каста
    isCasting       = false, -- в процессе каста Sunder
    castTarget      = nil,   -- текущая цель каста
    castStartTime   = 0,     -- время начала каста
}

-- ═══════════════════════════════════════════════════════════════════════════
--  Утилиты
-- ═══════════════════════════════════════════════════════════════════════════

--- Вычисляет HP% вручную (проверенный паттерн)
local function GetHPPercent(npc)
    local hp  = Entity.GetHealth(npc)
    local max = Entity.GetMaxHealth(npc)
    if max <= 0 then return 100 end
    return (hp / max) * 100
end

--- Герой не может кастовать (дизейбл)
local function IsHeroDisabled(hero)
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_STUNNED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_SILENCED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_COMMAND_RESTRICTED) then return true end
    return false
end

--- Проверяет модификатор из списка
local function HasAnyModifier(npc, list)
    for _, mod in ipairs(list) do
        if NPC.HasModifier(npc, mod) then return true end
    end
    return false
end

--- Проверяет, является ли цель валидной для Sunder
local function IsValidSunderTarget(target, hero, ability)
    if not target then return false end
    if not Entity.IsAlive(target) then return false end
    if Entity.IsDormant(target) then return false end
    if not NPC.IsHero(target) then return false end

    -- Не кастовать на себя
    if Entity.GetIndex(target) == Entity.GetIndex(hero) then return false end

    -- Не кастовать на иллюзии/клонов
    if NPC.IsIllusion and NPC.IsIllusion(target) then return false end

    -- Не кастовать на неуязвимых
    if NPC.HasState(target, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then return false end

    -- Проверка Linken's (Sunder блокируется линкой)
    if NPC.IsLinkensProtected and NPC.IsLinkensProtected(target) then return false end

    -- Модификаторы-исключения на цели
    if HasAnyModifier(target, TARGET_IGNORE_MODIFIERS) then return false end

    -- Проверка дальности каста
    local castRange = Ability.GetCastRange(ability) or 475
    if not NPC.IsEntityInRange(hero, target, castRange) then return false end

    return true
end

--- Находит лучшую вражескую цель для Sunder
local function FindBestEnemyTarget(hero, ability)
    local enemyThreshold = UI.EnemyHPThreshold:Get()
    local bestTarget = nil
    local bestHP = 0
    local myTeam = Entity.GetTeamNum(hero)

    local allHeroes = Heroes.GetAll()
    for i = 1, #allHeroes do
        local h = allHeroes[i]
        if h and Entity.GetTeamNum(h) ~= myTeam then
            if IsValidSunderTarget(h, hero, ability) then
                local hpPct = GetHPPercent(h)
                if hpPct >= enemyThreshold and hpPct > bestHP then
                    bestHP = hpPct
                    bestTarget = h
                end
            end
        end
    end

    return bestTarget
end

--- Находит лучшую союзную цель для Sunder
local function FindBestAllyTarget(hero, ability)
    if not UI.AllowAllies:Get() then return nil end

    local allyThreshold = UI.AllyHPThreshold:Get()
    local bestTarget = nil
    local bestHP = 0
    local myTeam = Entity.GetTeamNum(hero)

    local allHeroes = Heroes.GetAll()
    for i = 1, #allHeroes do
        local h = allHeroes[i]
        if h and Entity.GetTeamNum(h) == myTeam then
            if IsValidSunderTarget(h, hero, ability) then
                local hpPct = GetHPPercent(h)
                if hpPct >= allyThreshold and hpPct > bestHP then
                    bestHP = hpPct
                    bestTarget = h
                end
            end
        end
    end

    return bestTarget
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnUpdate — основная логика
-- ═══════════════════════════════════════════════════════════════════════════

script.OnUpdate = function()
    -- Проверки активности
    if not Engine.IsInGame() then
        State.isCasting = false
        State.castTarget = nil
        return
    end

    if not IsTerroblade() then return end
    if not UI.Enabled:Get() then return end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then
        State.isCasting = false
        State.castTarget = nil
        return
    end

    -- Получаем абилку Sunder
    local sunder = NPC.GetAbility(hero, ABILITY_SUNDER)
    if not sunder then return end
    if Ability.GetLevel(sunder) == 0 then return end

    -- Обновляем состояние каста
    if State.isCasting then
        -- Проверяем, в фазе ли ещё каст
        if Ability.IsInAbilityPhase(sunder) then
            -- Всё хорошо, каст идёт — ничего не делаем, ждём завершения
            return
        else
            -- Фаза каста завершилась (успешно или была отменена)
            State.isCasting = false
            State.castTarget = nil

            -- Если способность на кд — каст прошёл успешно
            if Ability.GetCooldown(sunder) > 0 then
                State.lastCastTime = GameRules.GetGameTime()
                return
            end
        end
    end

    -- Не спамить кастами
    local now = GameRules.GetGameTime()
    if now - State.lastCastTime < 0.5 then return end

    -- Способность должна быть готова
    if Ability.GetCooldown(sunder) > 0 then return end
    if not Ability.IsCastable(sunder, NPC.GetMana(hero)) then return end

    -- Герой не должен быть дизейблен или занят
    if IsHeroDisabled(hero) then return end
    if NPC.GetChannellingAbility(hero) then return end
    if HasAnyModifier(hero, CAST_BLOCKING_MODIFIERS) then return end

    -- Не нужен Sunder если есть «спасающие» модификаторы на TB
    if HasAnyModifier(hero, SELF_SAFE_MODIFIERS) then return end

    -- Проверяем порог HP
    local myHP = GetHPPercent(hero)
    local selfThreshold = UI.SelfHPThreshold:Get()
    if myHP > selfThreshold then return end

    -- Ищем лучшую цель: приоритет — враги, затем союзники
    local target = FindBestEnemyTarget(hero, sunder)
    if not target then
        target = FindBestAllyTarget(hero, sunder)
    end

    if not target then return end

    -- Кастуем Sunder
    State.isCasting = true
    State.castTarget = target
    State.castStartTime = now

    Ability.CastTarget(sunder, target, false, false, false, "tb_sunder_fix")
    State.lastCastTime = now
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnPrepareUnitOrders — блокировка конфликтующих ордеров
-- ═══════════════════════════════════════════════════════════════════════════

script.OnPrepareUnitOrders = function(data)
    if not UI.Enabled:Get() then return end
    if not UI.BlockOrders:Get() then return end
    if not State.isCasting then return end

    local hero = Heroes.GetLocal()
    if not hero then return end

    -- Проверяем, что Sunder всё ещё в фазе каста
    local sunder = NPC.GetAbility(hero, ABILITY_SUNDER)
    if not sunder or not Ability.IsInAbilityPhase(sunder) then
        State.isCasting = false
        State.castTarget = nil
        return
    end

    -- Блокируем только ордера для нашего героя (не для других юнитов)
    if data.npc and Entity.GetIndex(data.npc) ~= Entity.GetIndex(hero) then
        return
    end

    -- Исключение: не блокируем ордер самого Sunder-каста
    if data.ability and Ability.GetName(data.ability) == ABILITY_SUNDER then
        return
    end

    -- Блокируем любые другие ордера, которые могут отменить каст
    local order = data.order
    if order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_STOP
        or order == Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION
    then
        return false -- блокируем ордер
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnGameEnd — сброс состояния
-- ═══════════════════════════════════════════════════════════════════════════

script.OnGameEnd = function()
    State.lastCastTime = 0
    State.isCasting = false
    State.castTarget = nil
    State.castStartTime = 0
end

return script
