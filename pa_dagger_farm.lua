--[[
    Phantom Assassin — Stifling Dagger Last-Hit Farm
    UCZone API v2.0

    Автоматически добивает крипов Stifling Dagger (1 скилл).
    Рассчитывает: base_damage + attack_factor% * hero_damage, армор, время полёта.
    Учитывает входящий урон в крипа через HP-историю с консервативным фактором.
    Индикатор включения фарма над иконкой скилла (Panorama + fallback).
    
    НОВОЕ: Настройка "Don't Kill Near Hero" - исключает добивание крипов в указанном радиусе,
    когда игрок стоит рядом. Идеально для ласт-хитов рукой рядом с крипом.
]]

local script = {}

-- ═══════════════════════════════════════════════════════════════════════════
--  Проверка героя
-- ═══════════════════════════════════════════════════════════════════════════

local function IsPhantomAssassin()
    local myHero = Heroes.GetLocal()
    return myHero and NPC.GetUnitName(myHero) == "npc_dota_hero_phantom_assassin"
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Константы
-- ═══════════════════════════════════════════════════════════════════════════

local DAGGER_NAME  = "phantom_assassin_stifling_dagger"
local DAGGER_SPEED = 1200

-- ═══════════════════════════════════════════════════════════════════════════
--  Меню  (Heroes > Hero List > Phantom Assassin > Dagger Farm)
-- ═══════════════════════════════════════════════════════════════════════════

local function InitializeUI()
    local paSection = Menu.Find("Heroes", "Hero List", "Phantom Assassin")
    local helperTab
    if paSection and paSection.Create then
        helperTab = paSection:Create("Dagger Farm")
    end
    if not helperTab or not helperTab.Create then
        local tab = Menu.Create("General", "PA Dagger Farm", "pa_dagger_farm")
        if tab and tab.Icon then
            tab:Icon("panorama/images/heroes/icons/npc_dota_hero_phantom_assassin_png.vtex_c")
        end
        helperTab = tab:Create("Dagger Farm")
    end

    local mainGroup    = helperTab:Create("Main Settings")
    local daggerGroup  = helperTab:Create("Stifling Dagger")
    local visualGroup  = helperTab:Create("Visuals")

    local ui = {}

    ui.Enabled = mainGroup:Switch("Enable Script", true)
    ui.Enabled:Image("panorama/images/heroes/icons/npc_dota_hero_phantom_assassin_png.vtex_c")
    ui.Enabled:ToolTip("Enable/Disable Phantom Assassin Dagger Farm script.")

    ui.ToggleKey = mainGroup:Bind("Toggle Farm", Enum.ButtonCode.KEY_NONE,
        "panorama/images/spellicons/phantom_assassin_stifling_dagger_png.vtex_c")
    ui.ToggleKey:ToolTip("Press to toggle dagger last-hit farming ON/OFF.")

    ui.SearchRadius = daggerGroup:Slider("Search Radius", 400, 1200, 800, "%d")
    ui.SearchRadius:Icon("\u{f140}")
    ui.SearchRadius:ToolTip("Radius around hero to search for killable creeps.")

    ui.DmgSafetyMargin = daggerGroup:Slider("Overkill Margin", 0, 40, 5, "%d")
    ui.DmgSafetyMargin:ToolTip("Extra damage buffer over predicted HP. Higher = more reliable kills, lower = tighter timing.")

    ui.HPThreshold = daggerGroup:Slider("Max HP % to consider", 30, 100, 60, "%d%%")
    ui.HPThreshold:ToolTip("Only target creeps below this HP%%. Prevents casting on full-HP creeps with bad prediction.")

    ui.PredictionFactor = daggerGroup:Slider("Prediction Factor %", 30, 100, 60, "%d%%")
    ui.PredictionFactor:ToolTip("How much of the estimated incoming damage to trust. Lower = more conservative (waits longer). 60%% recommended.")

    ui.MinHPAtArrival = daggerGroup:Slider("Min HP at arrival", 1, 50, 8, "%d")
    ui.MinHPAtArrival:ToolTip("Creep must have at least this much predicted HP at dagger arrival. Prevents wasting dagger on already-dying creeps.")

    ui.OnlyLaneCreeps = daggerGroup:Switch("Only Lane Creeps", false)
    ui.OnlyLaneCreeps:ToolTip("If ON, ignores neutral / jungle creeps. If OFF, farms everything.")

    ui.TargetPriority = daggerGroup:Slider("Target Priority (0=Low HP, 1=Close, 2=Bounty)", 0, 2, 0, "%d")
    ui.TargetPriority:ToolTip("0 = Lowest HP first, 1 = Closest first, 2 = Highest bounty (siege) first.")

    ui.DontKillNearRadius = daggerGroup:Slider("Don't Kill Near Hero", 0, 500, 200, "%d")
    ui.DontKillNearRadius:Icon("\u{f057}")
    ui.DontKillNearRadius:ToolTip("Don't kill creeps within this radius when hero is standing nearby. 0 = disable feature.")

    ui.ShowIndicator = visualGroup:Switch("Show Farm Indicator", true)
    ui.ShowIndicator:ToolTip("Show ON/OFF indicator above the ability icon on the HUD.")

    ui.IndicatorYOffset = visualGroup:Slider("Indicator Y Offset", -50, 50, 0, "%d")
    ui.IndicatorYOffset:ToolTip("Manually adjust indicator vertical position. Negative = higher, Positive = lower.")

    ui.ShowKillableMarker = visualGroup:Switch("Mark Killable Creeps", true)
    ui.ShowKillableMarker:ToolTip("Draw a small circle above creeps that can be killed by dagger.")

    ui.ShowExcludeRadius = visualGroup:Switch("Show Exclude Radius", false)
    ui.ShowExcludeRadius:ToolTip("Show visual circle around hero indicating exclude radius.")

    ui.IndicatorColor = visualGroup:ColorPicker("Indicator ON Color", Color(50, 255, 100, 255))
    ui.IndicatorOffColor = visualGroup:ColorPicker("Indicator OFF Color", Color(255, 80, 80, 200))
    ui.KillableColor = visualGroup:ColorPicker("Killable Marker Color", Color(255, 50, 50, 220))
    ui.ExcludeRadiusColor = visualGroup:ColorPicker("Exclude Radius Color", Color(255, 255, 0, 100))

    return ui
end

local UI = InitializeUI()

-- ═══════════════════════════════════════════════════════════════════════════
--  Panorama: попытка найти панель абилок для позиции индикатора
-- ═══════════════════════════════════════════════════════════════════════════

local abilityPanel = nil    -- кеш панели Q-абилки
local panelLookupDone = false

local function TryFindAbilityPanel()
    if panelLookupDone then return end
    panelLookupDone = true

    -- Пробуем несколько известных имен Dota 2 Panorama панелей
    local panelNames = { "abilities", "AbilitiesAndStatBranch" }
    for _, name in ipairs(panelNames) do
        local ok, panel = pcall(Panorama.GetPanelByName, name, false)
        if ok and panel then
            -- Первый ребёнок = Q ability (index 0)
            local ok2, child = pcall(panel.GetChild, panel, 0)
            if ok2 and child then
                abilityPanel = child
                return
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Состояние
-- ═══════════════════════════════════════════════════════════════════════════

local State = {
    farmActive       = false,
    wasKeyPressed    = false,
    lastScanTime     = 0,
    lastCastTime     = 0,
    lastCleanupTime  = 0,
    killableCreeps   = {},
}

-- HP history: { [entityIndex] = { entries = {{time, hp}, ...}, lastDmgTime = number } }
local hpHistory = {}

local font = Render.LoadFont("Arial", Enum.FontCreate.FONTFLAG_ANTIALIAS)

-- ═══════════════════════════════════════════════════════════════════════════
--  Расчёт урона Stifling Dagger
-- ═══════════════════════════════════════════════════════════════════════════

--- Урон даггера = base_damage + hero_attack * (100 + attack_factor)%
--- attack_factor по уровням: -70 / -55 / -40 / -25 → 30% / 45% / 60% / 75% от атаки
local function GetDaggerRawDamage(hero, dagger)
    if not hero or not dagger then return 0 end
    local level = Ability.GetLevel(dagger)
    if level == 0 then return 0 end

    local baseDamage = Ability.GetLevelSpecialValueFor(dagger, "base_damage") or 0
    local attackFactor = Ability.GetLevelSpecialValueFor(dagger, "attack_factor") or 0
    local attackPercent = (100 + attackFactor) / 100

    local heroDamage = NPC.GetTrueDamage(hero) or 0
    return baseDamage + heroDamage * attackPercent
end

--- Armor damage multiplier (Dota 2 formula)
local function GetArmorMultiplier(target)
    if not target then return 1 end
    local armor = NPC.GetPhysicalArmorValue(target) or 0
    if armor >= 0 then
        return 1 - (armor * 0.06 / (1 + armor * 0.06))
    else
        return 2 - (0.94 ^ (-armor))
    end
end

--- Итого урон даггера после армора цели
local function GetDaggerDamage(hero, dagger, target)
    return GetDaggerRawDamage(hero, dagger) * GetArmorMultiplier(target)
end

--- Время полёта: cast_point (из API) + distance / projectile_speed
local function GetTravelTime(hero, dagger, target)
    if not hero or not target then return 0 end
    local castPoint = Ability.GetCastPoint(dagger) or 0.3
    local heroPos = Entity.GetAbsOrigin(hero)
    local targetPos = Entity.GetAbsOrigin(target)
    local dist = (heroPos - targetPos):Length()
    return castPoint + dist / DAGGER_SPEED
end

-- ═══════════════════════════════════════════════════════════════════════════
--  HP Prediction — улучшенная версия
--  Записываем HP каждый тик, вычисляем скорость потери HP
--  Используем консервативный фактор для предотвращения раннего каста
-- ═══════════════════════════════════════════════════════════════════════════

local HP_HISTORY_WINDOW = 1.0  -- секунд истории (короче = отзывчивее)
local MIN_ENTRIES_FOR_RATE = 5 -- минимум записей для расчёта скорости

local function RecordCreepHP(creep)
    local idx = Entity.GetIndex(creep)
    local now = GameRules.GetGameTime()
    local hp  = Entity.GetHealth(creep)

    if not hpHistory[idx] then
        hpHistory[idx] = { entries = {}, lastDmgTime = 0 }
    end

    local data = hpHistory[idx]
    local entries = data.entries

    -- Не дублировать, если прошло <0.02 сек (один тик)
    if #entries > 0 and (now - entries[#entries].time) < 0.02 then
        return
    end

    -- Отслеживаем время последнего урона
    if #entries > 0 and hp < entries[#entries].hp then
        data.lastDmgTime = now
    end

    entries[#entries + 1] = { time = now, hp = hp }

    -- Чистим старое (> HP_HISTORY_WINDOW сек)
    local cutoff = now - HP_HISTORY_WINDOW
    local newEntries = {}
    for j = 1, #entries do
        if entries[j].time >= cutoff then
            newEntries[#newEntries + 1] = entries[j]
        end
    end
    data.entries = newEntries
end

--- Скорость потери HP (HP/sec, >0 = теряет)
--- Использует стабильный расчёт: суммарная потеря / суммарное время
--- Фильтрует пробелы >0.3s (крип вышел из боя/перестали атаковать)
local function GetHPLossRate(creep)
    local idx = Entity.GetIndex(creep)
    local data = hpHistory[idx]
    if not data then return 0 end

    local entries = data.entries
    if #entries < MIN_ENTRIES_FOR_RATE then return 0 end

    local totalLoss = 0
    local totalTime = 0
    local damageEvents = 0

    for j = 2, #entries do
        local dt = entries[j].time - entries[j - 1].time
        local dhp = entries[j - 1].hp - entries[j].hp  -- >0 = потерял HP

        -- Игнорируем слишком большие пробелы (крип не под атакой)
        if dt > 0 and dt < 0.3 then
            totalTime = totalTime + dt

            if dhp > 0 then
                totalLoss = totalLoss + dhp
                damageEvents = damageEvents + 1
            end
            -- dhp <= 0 (regen) тоже учитываем через время, но не урон
        end
    end

    -- Нужно достаточно данных для надёжной оценки
    if damageEvents < 2 or totalTime < 0.15 then return 0 end

    local rate = totalLoss / totalTime
    return rate > 0 and rate or 0
end

--- Проверяет, атакуют ли крипа прямо сейчас (был урон за последние 0.4s)
local function IsCreepUnderAttack(creep)
    local idx = Entity.GetIndex(creep)
    local data = hpHistory[idx]
    if not data then return false end
    local now = GameRules.GetGameTime()
    return (now - data.lastDmgTime) < 0.4
end

--- Предсказанный HP через deltaTime секунд
--- Использует консервативный фактор из настроек
local function PredictCreepHP(creep, deltaTime)
    local currentHP = Entity.GetHealth(creep)
    if deltaTime <= 0 then return currentHP end

    local lossRate = GetHPLossRate(creep)

    -- Если крипа не атакуют прямо сейчас, не предсказываем потерю HP
    if not IsCreepUnderAttack(creep) then
        return currentHP
    end

    -- Консервативный фактор: доверяем только части предсказанного урона
    -- Это КЛЮЧЕВОЙ фикс против раннего каста
    local conservFactor = (UI.PredictionFactor:Get()) / 100  -- 0.3 – 1.0

    local predicted = currentHP - lossRate * deltaTime * conservFactor
    return math.max(0, predicted)
end

--- Умрёт ли крип сам (без нашей помощи) за deltaTime?
--- Использует полный (не консервативный) rate для этой проверки
local function WillDieAlone(creep, deltaTime)
    local currentHP = Entity.GetHealth(creep)
    local lossRate = GetHPLossRate(creep)
    if lossRate <= 0 then return false end

    -- Если крип не под атакой, он не умрёт сам
    if not IsCreepUnderAttack(creep) then return false end

    return (currentHP / lossRate) <= deltaTime
end

local function CleanupHPHistory()
    local now = GameRules.GetGameTime()
    for idx, data in pairs(hpHistory) do
        if not data or not data.entries or #data.entries == 0
            or data.entries[#data.entries].time < now - 3.0 then
            hpHistory[idx] = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Поиск крипов
-- ═══════════════════════════════════════════════════════════════════════════

local function IsValidCreep(creep, hero)
    if not creep or not Entity.IsAlive(creep) or Entity.IsDormant(creep) then return false end
    if Entity.GetTeamNum(creep) == Entity.GetTeamNum(hero) then return false end
    if not NPC.IsCreep(creep) then return false end
    if NPC.IsWaitingToSpawn(creep) then return false end

    if UI.OnlyLaneCreeps:Get() then
        local name = NPC.GetUnitName(creep)
        if name and not (string.find(name, "creep") or string.find(name, "siege") or string.find(name, "mega")) then
            return false
        end
        if name and string.find(name, "neutral") then return false end
    end

    return true
end

local function FindKillableCreeps(hero, dagger)
    local result = {}
    if not hero or not dagger then return result end
    if Ability.GetLevel(dagger) == 0 then return result end

    local radius     = UI.SearchRadius:Get()
    local margin     = UI.DmgSafetyMargin:Get()
    local hpThresh   = UI.HPThreshold:Get() / 100  -- 0.0 – 1.0
    local minHPArr   = UI.MinHPAtArrival:Get()
    local heroPos    = Entity.GetAbsOrigin(hero)
    local castRange  = Ability.GetCastRange(dagger) or 1000
    local maxDist    = math.min(castRange + 50, radius)
    
    -- Новая настройка: радиус исключения крипов рядом с героем
    local dontKillNearRadius = UI.DontKillNearRadius:Get()

    -- Фаза 1: записываем HP для всех крипов в радиусе
    local allNPCs = NPCs.GetAll()
    local candidates = {}
    for i = 1, #allNPCs do
        local npc = allNPCs[i]
        if IsValidCreep(npc, hero) then
            local npcPos = Entity.GetAbsOrigin(npc)
            local dist = (heroPos - npcPos):Length()
            if dist <= maxDist then
                RecordCreepHP(npc)
                candidates[#candidates + 1] = { npc = npc, dist = dist }
            end
        end
    end

    -- Фаза 2: оценка кого можно убить
    for i = 1, #candidates do
        local npc  = candidates[i].npc
        local dist = candidates[i].dist

        local currentHP   = Entity.GetHealth(npc)
        local maxHP       = Entity.GetMaxHealth(npc)
        local daggerDmg   = GetDaggerDamage(hero, dagger, npc)
        local travelTime  = GetTravelTime(hero, dagger, npc)
        local predictedHP = PredictCreepHP(npc, travelTime)

        -- НОВАЯ ПРОВЕРКА: исключаем крипов рядом с героем
        if dontKillNearRadius > 0 and dist <= dontKillNearRadius then
            goto continue_creep
        end

        -- Условие 1: крип должен быть ниже порога HP%
        -- (защита от каста в полнохп крипов из-за шума в prediction)
        local hpPercent = currentHP / maxHP
        if hpPercent > hpThresh then
            goto continue_creep
        end

        -- Условие 2: даггер убьёт крипа по predicted HP (с запасом margin)
        if daggerDmg < (predictedHP + margin) then
            goto continue_creep
        end

        -- Условие 3: крип будет жив к моменту прилёта (минимальный HP)
        if predictedHP < minHPArr then
            goto continue_creep
        end

        -- Условие 4: крип НЕ умрёт сам до прилёта даггера
        if WillDieAlone(npc, travelTime) then
            goto continue_creep
        end

        -- Условие 5: currentHP не слишком высок относительно урона даггера
        -- Дополнительная защита: если текущий HP сильно выше урона даггера,
        -- значит мы слишком сильно полагаемся на предикт. Ограничиваем.
        if currentHP > daggerDmg * 1.6 then
            goto continue_creep
        end

        result[#result + 1] = {
            creep       = npc,
            predictedHP = predictedHP,
            damage      = daggerDmg,
            distance    = dist,
        }

        ::continue_creep::
    end

    return result
end

local function SelectBestTarget(killable)
    if #killable == 0 then return nil end

    local priority = UI.TargetPriority:Get()

    if priority == 1 then
        table.sort(killable, function(a, b) return a.distance < b.distance end)
    elseif priority == 2 then
        table.sort(killable, function(a, b)
            return (Entity.GetMaxHealth(a.creep) or 0) > (Entity.GetMaxHealth(b.creep) or 0)
        end)
    else
        -- Lowest predictedHP first = наиболее "готовый" к ласт-хиту крип
        table.sort(killable, function(a, b) return a.predictedHP < b.predictedHP end)
    end

    return killable[1]
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnUpdate
-- ═══════════════════════════════════════════════════════════════════════════

script.OnUpdate = function()
    if not IsPhantomAssassin() or not UI.Enabled:Get() or not Engine.IsInGame() then
        State.farmActive = false
        return
    end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then return end

    -- Toggle фарма
    local keyPressed = UI.ToggleKey and UI.ToggleKey:IsPressed()
    if keyPressed and not State.wasKeyPressed then
        State.farmActive = not State.farmActive
    end
    State.wasKeyPressed = keyPressed

    if not State.farmActive then
        State.killableCreeps = {}
        return
    end

    local now = GameRules.GetGameTime()
    if now - State.lastScanTime < 0.03 then return end
    State.lastScanTime = now

    local dagger = NPC.GetAbility(hero, DAGGER_NAME)
    if not dagger then
        State.killableCreeps = {}
        return
    end

    -- Сканируем крипов (записываем HP + ищем убиваемых)
    local killable = FindKillableCreeps(hero, dagger)
    State.killableCreeps = killable

    -- Можем ли кастовать?
    if not Ability.IsCastable(dagger, NPC.GetMana(hero)) then return end
    if Ability.GetCooldown(dagger) > 0 then return end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_STUNNED) then return end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED) then return end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_SILENCED) then return end

    -- Кулдаун между кастами (чтобы не спамить при ошибках)
    if now - State.lastCastTime < 0.4 then return end

    local best = SelectBestTarget(killable)
    if not best then return end

    Ability.CastTarget(dagger, best.creep, false, false, false, "pa_dagger_farm")
    State.lastCastTime = now

    -- Периодическая чистка (раз в 2 секунды)
    if now - State.lastCleanupTime > 2.0 then
        CleanupHPHistory()
        State.lastCleanupTime = now
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnDraw — индикатор и маркеры
-- ═══════════════════════════════════════════════════════════════════════════

script.OnDraw = function()
    if not IsPhantomAssassin() or not UI.Enabled:Get() or not Engine.IsInGame() then return end

    local hero = Heroes.GetLocal()
    if not hero then return end

    -- ─── Индикатор ON/OFF ───
    if UI.ShowIndicator:Get() then
        local screenSize = Render.ScreenSize()
        local yOffset = UI.IndicatorYOffset:Get()

        -- Попытка найти панель Q через Panorama (один раз)
        TryFindAbilityPanel()

        local drawX, drawY

        if abilityPanel then
            -- Panorama найдена: позиция прямо над иконкой Q
            local ok, pos = pcall(abilityPanel.GetPositionWithinWindow, abilityPanel)
            if ok and pos then
                local ok2, w = pcall(abilityPanel.GetLayoutWidth, abilityPanel)
                local panelWidth = (ok2 and w) and w or 50
                drawX = pos.x + panelWidth / 2
                drawY = pos.y - 18 + yOffset
            else
                -- Panorama сломалась — fallback
                drawX = screenSize.x * 0.5 - screenSize.x * 0.04
                drawY = screenSize.y * 0.935 + yOffset
            end
        else
            -- Fallback: фиксированная позиция над примерной областью Q-абилки
            -- HUD ability bar в Dota 2 обычно на ~93% высоты экрана
            drawX = screenSize.x * 0.5 - screenSize.x * 0.04
            drawY = screenSize.y * 0.935 + yOffset
        end

        local indicatorSize = 8
        local isActive = State.farmActive
        local time = GameRules.GetGameTime()

        if isActive then
            local onColor = UI.IndicatorColor:Get()
            local pulse = math.sin(time * 4) * 0.2 + 0.8
            local alpha = math.floor(onColor.a * pulse)
            local col = Color(onColor.r, onColor.g, onColor.b, alpha)

            Render.FilledCircle(Vec2(drawX, drawY), indicatorSize, col)
            Render.Circle(Vec2(drawX, drawY), indicatorSize + 2,
                Color(255, 255, 255, math.floor(120 * pulse)), 1)

            local textSize = Render.TextSize(font, 11, "FARM")
            local textX = drawX - textSize.x / 2
            local textY = drawY - indicatorSize - textSize.y - 2
            Render.Text(font, 11, "FARM", Vec2(textX + 1, textY + 1),
                Color(0, 0, 0, math.floor(180 * pulse)))
            Render.Text(font, 11, "FARM", Vec2(textX, textY),
                Color(onColor.r, onColor.g, onColor.b, math.floor(255 * pulse)))
        else
            local offColor = UI.IndicatorOffColor:Get()
            Render.FilledCircle(Vec2(drawX, drawY), indicatorSize * 0.7,
                Color(offColor.r, offColor.g, offColor.b, 120))
        end
    end

    -- ─── Маркеры убиваемых крипов ───
    if UI.ShowKillableMarker:Get() and State.farmActive then
        local killColor = UI.KillableColor:Get()
        local time = GameRules.GetGameTime()

        for i = 1, #State.killableCreeps do
            local data = State.killableCreeps[i]
            local creep = data.creep
            if creep and Entity.IsAlive(creep) and not Entity.IsDormant(creep) then
                local creepPos = Entity.GetAbsOrigin(creep)
                local worldPos = Vector(creepPos.x, creepPos.y, creepPos.z + 120)
                local screenPos, visible = Render.WorldToScreen(worldPos)

                if visible then
                    local pulse = math.sin(time * 6 + i) * 0.3 + 0.7
                    local alpha = math.floor(killColor.a * pulse)
                    local markerColor = Color(killColor.r, killColor.g, killColor.b, alpha)

                    Render.FilledCircle(screenPos, 6, markerColor)
                    Render.Circle(screenPos, 8,
                        Color(255, 255, 255, math.floor(100 * pulse)), 1)

                    local hpText = string.format("%d", math.floor(data.predictedHP))
                    local textSz = Render.TextSize(font, 10, hpText)
                    Render.Text(font, 10, hpText,
                        Vec2(screenPos.x - textSz.x / 2 + 1, screenPos.y + 10 + 1),
                        Color(0, 0, 0, math.floor(160 * pulse)))
                    Render.Text(font, 10, hpText,
                        Vec2(screenPos.x - textSz.x / 2, screenPos.y + 10),
                        Color(255, 255, 255, math.floor(220 * pulse)))
                end
            end
        end
    end

    -- ─── Радиус исключения вокруг героя ───
    if UI.ShowExcludeRadius:Get() and State.farmActive then
        local dontKillNearRadius = UI.DontKillNearRadius:Get()
        if dontKillNearRadius > 0 then
            local heroPos = Entity.GetAbsOrigin(hero)
            local worldPos = Vector(heroPos.x, heroPos.y, heroPos.z + 5)
            local screenPos, visible = Render.WorldToScreen(worldPos)
            
            if visible then
                local excludeColor = UI.ExcludeRadiusColor:Get()
                local time = GameRules.GetGameTime()
                local pulse = math.sin(time * 3) * 0.2 + 0.8
                local alpha = math.floor(excludeColor.a * pulse)
                local radiusColor = Color(excludeColor.r, excludeColor.g, excludeColor.b, alpha)
                
                -- Конвертируем игровой радиус в экранный
                local edgePos = Vector(heroPos.x + dontKillNearRadius, heroPos.y, heroPos.z + 5)
                local edgeScreenPos, _ = Render.WorldToScreen(edgePos)
                local screenRadius = math.abs(edgeScreenPos.x - screenPos.x)
                
                if screenRadius > 0 then
                    Render.Circle(screenPos, screenRadius, radiusColor, 2)
                    
                    -- Добавим текст с радиусом
                    local radiusText = string.format("%d", dontKillNearRadius)
                    local textSz = Render.TextSize(font, 12, radiusText)
                    Render.Text(font, 12, radiusText,
                        Vec2(screenPos.x - textSz.x / 2, screenPos.y - screenRadius - 15),
                        Color(255, 255, 255, math.floor(200 * pulse)))
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Callbacks
-- ═══════════════════════════════════════════════════════════════════════════

script.OnGameEnd = function()
    State.farmActive = false
    State.killableCreeps = {}
    hpHistory = {}
    abilityPanel = nil
    panelLookupDone = false
end

return script
