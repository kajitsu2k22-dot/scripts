---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
--[[
    Ogre Magi — Auto Bloodlust & Fire Shield
    UCZone API v2.0

    Автоматически кастует Bloodlust и Fire Shield на союзных героев.
    In-game HUD панель с иконками героев для быстрого выбора целей.
    Панель синхронизирована с темой меню через Menu.Style().
    Умная логика: порог маны, резерв маны под Q, ребафф по таймеру.
]]

local script = {}

local math_floor, math_max, math_min = math.floor, math.max, math.min

-- ═══════════════════════════════════════════════════════════════════════════
--  Проверка героя
-- ═══════════════════════════════════════════════════════════════════════════

local function IsOgreMagi()
    local myHero = Heroes.GetLocal()
    return myHero and NPC.GetUnitName(myHero) == "npc_dota_hero_ogre_magi"
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Константы
-- ═══════════════════════════════════════════════════════════════════════════

local ABILITY_BLOODLUST     = "ogre_magi_bloodlust"
local ABILITY_FIRE_SHIELD   = "ogre_magi_smash"
local ABILITY_FROST_ARMOR   = "ogre_magi_frost_armor"
local ABILITY_FIREBLAST     = "ogre_magi_fireblast"

local MOD_BLOODLUST         = "modifier_ogre_magi_bloodlust"
local MOD_FIRE_SHIELD       = "modifier_ogre_magi_smash_buff"
local MOD_FROST_ARMOR       = "modifier_ogre_magi_frost_armor"

-- ═══════════════════════════════════════════════════════════════════════════
--  Ресурсы (шрифты, изображения)
-- ═══════════════════════════════════════════════════════════════════════════

local Res = {
    font      = Render.LoadFont("Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, 500),
    fontSmall = Render.LoadFont("Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, 400),
    ogreIcon  = Render.LoadImage("panorama/images/heroes/icons/npc_dota_hero_ogre_magi_png.vtex_c"),
    blIcon    = Render.LoadImage("panorama/images/spellicons/ogre_magi_bloodlust_png.vtex_c"),
    fsIcon    = Render.LoadImage("panorama/images/spellicons/ogre_magi_smash_png.vtex_c"),
    heroImages = {},
}

local function GetHeroIconPath(unitName)
    return "panorama/images/heroes/icons/" .. unitName .. "_png.vtex_c"
end

local function GetHeroImage(unitName)
    if not Res.heroImages[unitName] then
        Res.heroImages[unitName] = Render.LoadImage(GetHeroIconPath(unitName))
    end
    return Res.heroImages[unitName]
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Константы панели
-- ═══════════════════════════════════════════════════════════════════════════

local PL = {
    ICON       = 32,        -- размер иконки героя
    ICON_R     = 4,         -- скругление иконки
    BAR_H      = 4,         -- высота полоски-индикатора под иконкой
    BAR_GAP    = 1,         -- зазор между двумя половинками полоски
    CELL_GAP   = 4,         -- зазор между ячейками героев
    PAD_X      = 10,        -- горизонтальный паддинг панели
    PAD_Y      = 8,         -- вертикальный паддинг панели
    HEADER_H   = 18,        -- высота заголовка
    HDR_ICON   = 14,        -- размер иконки Огра в заголовке
    HDR_GAP    = 6,         -- зазор между иконкой и текстом в заголовке
    SECT_GAP   = 6,         -- зазор между заголовком и иконками
    ICON_BAR   = 2,         -- зазор между иконкой и полоской
    BORDER_R   = 6,         -- скругление панели
    BORDER_W   = 1,         -- толщина рамки
}

-- ═══════════════════════════════════════════════════════════════════════════
--  Меню  (Heroes > Hero List > Ogre Magi > Auto Buff)
-- ═══════════════════════════════════════════════════════════════════════════

local function InitializeUI()
    local ogreSection = Menu.Find("Heroes", "Hero List", "Ogre Magi")
    local helperTab

    if ogreSection and ogreSection.Create then
        helperTab = ogreSection:Create("Auto Buff")
    end

    if not helperTab or not helperTab.Create then
        local tab = Menu.Create("General", "Ogre Magi Auto Buff", "ogre_auto_buff")
        if tab and tab.Icon then
            tab:Icon("panorama/images/heroes/icons/npc_dota_hero_ogre_magi_png.vtex_c")
        end
        helperTab = tab:Create("Auto Buff")
    end

    local mainGroup   = helperTab:Create("Main Settings")
    local bloodGroup  = helperTab:Create("Bloodlust")
    local shieldGroup = helperTab:Create("Fire Shield")
    local panelGroup  = helperTab:Create("In-Game Panel")

    local ui = {}

    -- ─── Main Settings ───

    ui.Enabled = mainGroup:Switch("Enable Script", true)
    ui.Enabled:Image("panorama/images/heroes/icons/npc_dota_hero_ogre_magi_png.vtex_c")
    ui.Enabled:ToolTip("Enable/Disable Ogre Magi Auto Buff script.")

    ui.ManaThreshold = mainGroup:Slider("Min Mana %", 5, 80, 25, "%d%%")
    ui.ManaThreshold:Icon("\u{f043}")
    ui.ManaThreshold:ToolTip("Don't cast buffs when mana %% is below this threshold.")

    ui.ReserveManaForQ = mainGroup:Switch("Reserve Mana for Fireblast", true)
    ui.ReserveManaForQ:Image("panorama/images/spellicons/ogre_magi_fireblast_png.vtex_c")
    ui.ReserveManaForQ:ToolTip("Always keep enough mana to cast Fireblast (Q) at least once.")

    ui.CastDelay = mainGroup:Slider("Cast Delay (ms)", 150, 1500, 300, "%dms")
    ui.CastDelay:Icon("\u{f017}")
    ui.CastDelay:ToolTip("Minimum delay between buff casts to avoid spam. 300ms recommended.")

    -- ─── Bloodlust ───

    ui.BloodlustEnabled = bloodGroup:Switch("Auto Bloodlust", true)
    ui.BloodlustEnabled:Image("panorama/images/spellicons/ogre_magi_bloodlust_png.vtex_c")
    ui.BloodlustEnabled:ToolTip("Automatically cast Bloodlust on selected allies.")

    ui.BloodlustSelf = bloodGroup:Switch("Cast on Self", true)
    ui.BloodlustSelf:Icon("\u{f2bd}")
    ui.BloodlustSelf:ToolTip("Include yourself as a Bloodlust target (highest priority).")

    ui.BloodlustRebuff = bloodGroup:Slider("Rebuff Threshold", 0, 15, 5, "%ds")
    ui.BloodlustRebuff:Icon("\u{f2f1}")
    ui.BloodlustRebuff:ToolTip("Re-cast when remaining duration drops below this value. 0 = only when fully expired.")

    ui.BloodlustTargets = bloodGroup:MultiSelect("Bloodlust Targets", {}, true)
    ui.BloodlustTargets:ToolTip("Select which allied heroes should receive Bloodlust.")
    ui.BloodlustTargets:Icon("\u{f0c0}")

    -- ─── Fire Shield ───

    ui.ShieldEnabled = shieldGroup:Switch("Auto Fire Shield", true)
    ui.ShieldEnabled:Image("panorama/images/spellicons/ogre_magi_smash_png.vtex_c")
    ui.ShieldEnabled:ToolTip("Automatically cast Fire Shield on selected allies. Requires Aghanim's Shard or Facet.")

    ui.ShieldSelf = shieldGroup:Switch("Cast on Self", true)
    ui.ShieldSelf:Icon("\u{f2bd}")
    ui.ShieldSelf:ToolTip("Include yourself as a Fire Shield target (highest priority).")

    ui.ShieldRebuff = shieldGroup:Slider("Rebuff Threshold", 0, 12, 3, "%ds")
    ui.ShieldRebuff:Icon("\u{f2f1}")
    ui.ShieldRebuff:ToolTip("Re-cast when remaining duration drops below this value. 0 = only when fully expired.")

    ui.ShieldTargets = shieldGroup:MultiSelect("Fire Shield Targets", {}, true)
    ui.ShieldTargets:ToolTip("Select which allied heroes should receive Fire Shield.")
    ui.ShieldTargets:Icon("\u{f3ed}")

    -- ─── In-Game Panel ───

    ui.ShowPanel = panelGroup:Switch("Show In-Game Panel", true)
    ui.ShowPanel:Icon("\u{f2d0}")
    ui.ShowPanel:ToolTip("Show a draggable panel in-game to toggle buff targets without opening the menu.")

    -- ─── Visibility callbacks ───

    ui.Enabled:SetCallback(function()
        local on = ui.Enabled:Get()
        ui.ManaThreshold:Disabled(not on)
        ui.ReserveManaForQ:Disabled(not on)
        ui.CastDelay:Disabled(not on)
        ui.BloodlustEnabled:Disabled(not on)
        ui.ShieldEnabled:Disabled(not on)
        ui.ShowPanel:Disabled(not on)
    end, true)

    ui.BloodlustEnabled:SetCallback(function()
        local on = ui.BloodlustEnabled:Get() and ui.Enabled:Get()
        ui.BloodlustSelf:Disabled(not on)
        ui.BloodlustRebuff:Disabled(not on)
    end, true)

    ui.ShieldEnabled:SetCallback(function()
        local on = ui.ShieldEnabled:Get() and ui.Enabled:Get()
        ui.ShieldSelf:Disabled(not on)
        ui.ShieldRebuff:Disabled(not on)
    end, true)

    return ui
end

local UI = InitializeUI()

-- ═══════════════════════════════════════════════════════════════════════════
--  Состояние
-- ═══════════════════════════════════════════════════════════════════════════

local State = {
    lastCastTime     = 0,
    lastAllyCheck    = 0,
    allyHeroNames    = {},
}

-- ═══════════════════════════════════════════════════════════════════════════
--  Состояние панели
-- ═══════════════════════════════════════════════════════════════════════════

local Panel = {
    x = 12,
    y = 350,
    dragging = false,
    dx = 0,
    dy = 0,
    isHovered  = false,   -- курсор над панелью (для блокировки ордеров)
    clickEaten = false,   -- клик обработан панелью в этом фрейме
    -- расчётные размеры (обновляются при отрисовке)
    w = 0,
    h = 0,
}

-- ═══════════════════════════════════════════════════════════════════════════
--  Утилиты
-- ═══════════════════════════════════════════════════════════════════════════

local function GetDistance(ent1, ent2)
    local pos1 = Entity.GetAbsOrigin(ent1)
    local pos2 = Entity.GetAbsOrigin(ent2)
    return (pos1 - pos2):Length()
end

local function Clamp(v, lo, hi) return math_max(lo, math_min(hi, v)) end

local function StyleColor(style, key, alphaOverride)
    local c = style[key]
    if not c then return Color(200, 200, 200, alphaOverride or 255) end
    return Color(c.r or 200, c.g or 200, c.b or 200, alphaOverride or c.a or 255)
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Динамическое обновление панелей союзных героев
-- ═══════════════════════════════════════════════════════════════════════════

local function UpdateAllyMultiSelects(hero)
    local myTeam    = Entity.GetTeamNum(hero)
    local allHeroes = Heroes.GetAll()

    local items = {}
    local names = {}

    for i = 1, #allHeroes do
        local h = allHeroes[i]
        if h and h ~= hero
           and Entity.GetTeamNum(h) == myTeam
           and not NPC.IsIllusion(h) then
            local unitName = NPC.GetUnitName(h)
            if unitName then
                items[#items + 1] = { unitName, GetHeroIconPath(unitName), true }
                names[#names + 1] = unitName
            end
        end
    end

    local changed = #names ~= #State.allyHeroNames
    if not changed then
        for i = 1, #names do
            if names[i] ~= State.allyHeroNames[i] then
                changed = true
                break
            end
        end
    end

    if changed and #items > 0 then
        local bloodSaved, shieldSaved = {}, {}
        for _, name in ipairs(State.allyHeroNames) do
            bloodSaved[name]  = UI.BloodlustTargets:Get(name)
            shieldSaved[name] = UI.ShieldTargets:Get(name)
        end

        local bloodItems, shieldItems = {}, {}
        for _, item in ipairs(items) do
            local name, icon = item[1], item[2]
            local isNew    = (#State.allyHeroNames == 0) or (bloodSaved[name] == nil)
            local bloodOn  = isNew or bloodSaved[name]
            local shieldOn = isNew or shieldSaved[name]
            bloodItems[#bloodItems + 1]   = { name, icon, bloodOn }
            shieldItems[#shieldItems + 1] = { name, icon, shieldOn }
        end

        UI.BloodlustTargets:Update(bloodItems, true)
        UI.ShieldTargets:Update(shieldItems, true)
        State.allyHeroNames = names

        -- предзагрузка изображений героев
        for _, name in ipairs(names) do
            GetHeroImage(name)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Проверки состояний
-- ═══════════════════════════════════════════════════════════════════════════

local function IsHeroDisabled(hero)
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_STUNNED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_HEXED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_SILENCED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_MUTED) then return true end
    if NPC.HasState(hero, Enum.ModifierState.MODIFIER_STATE_COMMAND_RESTRICTED) then return true end
    return false
end

local function NeedsBuff(target, modifierName, rebuffThreshold)
    local mod = NPC.GetModifier(target, modifierName)
    if not mod then return true end
    local duration = Modifier.GetDuration(mod)
    if duration <= 0 then return false end
    local remaining = Modifier.GetDieTime(mod) - GameRules.GetGameTime()
    return remaining <= rebuffThreshold
end

local function GetBuffRemaining(target, modifierName)
    local mod = NPC.GetModifier(target, modifierName)
    if not mod then return 0 end
    return math_max(0, Modifier.GetDieTime(mod) - GameRules.GetGameTime())
end

local function GetAvailableMana(hero)
    local currentMana = NPC.GetMana(hero)
    if UI.ReserveManaForQ:Get() then
        local fireblast = NPC.GetAbility(hero, ABILITY_FIREBLAST)
        if fireblast and Ability.GetLevel(fireblast) > 0 then
            currentMana = currentMana - (Ability.GetManaCost(fireblast) or 0)
        end
    end
    return math_max(0, currentMana)
end

local function CanCastAbility(hero, ability)
    if not ability then return false end
    if Ability.GetLevel(ability) == 0 then return false end
    if Ability.GetCooldown(ability) > 0 then return false end
    if not Ability.IsCastable(ability, NPC.GetMana(hero)) then return false end
    if Ability.IsInAbilityPhase(ability) then return false end
    if GetAvailableMana(hero) < (Ability.GetManaCost(ability) or 0) then return false end
    return true
end

local function IsValidTarget(target)
    if not target then return false end
    if not Entity.IsAlive(target) then return false end
    if Entity.IsDormant(target) then return false end
    if NPC.IsIllusion(target) then return false end
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Поиск лучшей цели для баффа
-- ═══════════════════════════════════════════════════════════════════════════

local function FindBestBuffTarget(hero, modName, rebuff, castOnSelf, multiSelect, castRange)
    if castOnSelf and IsValidTarget(hero) and NeedsBuff(hero, modName, rebuff) then
        return hero
    end

    local myTeam    = Entity.GetTeamNum(hero)
    local allHeroes = Heroes.GetAll()
    local bestTarget, bestRemaining = nil, 999

    for i = 1, #allHeroes do
        local h = allHeroes[i]
        if h and h ~= hero
           and Entity.GetTeamNum(h) == myTeam
           and IsValidTarget(h) then
            local unitName = NPC.GetUnitName(h)
            if unitName and multiSelect:Get(unitName) then
                if GetDistance(hero, h) <= castRange + 100 then
                    if NeedsBuff(h, modName, rebuff) then
                        local rem = GetBuffRemaining(h, modName)
                        if rem < bestRemaining then
                            bestRemaining = rem
                            bestTarget    = h
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Fire Shield: Smash (Shard) или Frost Armor (Facet)
-- ═══════════════════════════════════════════════════════════════════════════

local function GetFireShieldAbility(hero)
    local smash = NPC.GetAbility(hero, ABILITY_FIRE_SHIELD)
    if smash and Ability.GetLevel(smash) > 0 then return smash, MOD_FIRE_SHIELD end
    local frost = NPC.GetAbility(hero, ABILITY_FROST_ARMOR)
    if frost and Ability.GetLevel(frost) > 0 then return frost, MOD_FROST_ARMOR end
    return nil, nil
end

-- ═══════════════════════════════════════════════════════════════════════════
--  In-Game Panel — Отрисовка
-- ═══════════════════════════════════════════════════════════════════════════

local function BuildSlots()
    -- Формируем список слотов: { { name, isSelf }, ... }
    local slots = {}
    slots[1] = { name = "npc_dota_hero_ogre_magi", isSelf = true }
    for _, n in ipairs(State.allyHeroNames) do
        slots[#slots + 1] = { name = n, isSelf = false }
    end
    return slots
end

local function GetSlotBL(slot)
    if slot.isSelf then return UI.BloodlustSelf:Get() end
    return UI.BloodlustTargets:Get(slot.name)
end

local function GetSlotFS(slot)
    if slot.isSelf then return UI.ShieldSelf:Get() end
    return UI.ShieldTargets:Get(slot.name)
end

local function SetSlotBL(slot, val)
    if slot.isSelf then UI.BloodlustSelf:Set(val) else UI.BloodlustTargets:Set(slot.name, val) end
end

local function SetSlotFS(slot, val)
    if slot.isSelf then UI.ShieldSelf:Set(val) else UI.ShieldTargets:Set(slot.name, val) end
end

--- Основная функция отрисовки HUD-панели
local function DrawPanel()
    local style = Menu.Style()
    local slots = BuildSlots()
    local nSlots = #slots

    -- ─── Размеры ───
    local cellW     = PL.ICON
    local cellH     = PL.ICON + PL.ICON_BAR + PL.BAR_H
    local rowW      = nSlots * cellW + math_max(0, nSlots - 1) * PL.CELL_GAP
    local headerW   = PL.HDR_ICON + PL.HDR_GAP + 72  -- ~ширина текста "Auto Buff"
    local contentW  = math_max(rowW, headerW)
    local panelW    = contentW + PL.PAD_X * 2
    local panelH    = PL.PAD_Y + PL.HEADER_H + PL.SECT_GAP + cellH + PL.PAD_Y

    Panel.w = panelW
    Panel.h = panelH

    -- clamp к экрану
    local scr = Render.ScreenSize()
    Panel.x = Clamp(Panel.x, 0, math_max(0, scr.x - panelW))
    Panel.y = Clamp(Panel.y, 0, math_max(0, scr.y - panelH))

    local x0 = math_floor(Panel.x)
    local y0 = math_floor(Panel.y)
    local x1 = x0 + panelW
    local y1 = y0 + panelH

    -- ─── Цвета из темы ───
    local colBg      = StyleColor(style, "additional_background", 240)
    local colBorder   = StyleColor(style, "outline", 255)
    local colText     = StyleColor(style, "primary_first_tab_text", 255)
    local colAccent   = StyleColor(style, "primary", 255)
    local colDim      = StyleColor(style, "slider_background", 180)

    -- Цвет Bloodlust (тёплый оранжевый) и Fire Shield (холодный — accent)
    local colBL = Color(255, 140, 50, 255)
    local colFS = Color(colAccent.r, colAccent.g, colAccent.b, 255)

    -- ─── Фон ───
    local inner0 = Vec2(x0 + PL.BORDER_W, y0 + PL.BORDER_W)
    local inner1 = Vec2(x1 - PL.BORDER_W, y1 - PL.BORDER_W)
    Render.FilledRect(Vec2(x0, y0), Vec2(x1, y1), colBorder, PL.BORDER_R, Enum.DrawFlags.RoundCornersAll)
    Render.Blur(inner0, inner1, 1.0, 1.0, PL.BORDER_R, Enum.DrawFlags.RoundCornersAll)
    Render.FilledRect(inner0, inner1, colBg, PL.BORDER_R, Enum.DrawFlags.RoundCornersAll)

    -- ─── Заголовок ───
    local hdrX = x0 + PL.PAD_X
    local hdrY = y0 + PL.PAD_Y
    local iconY = hdrY + math_floor((PL.HEADER_H - PL.HDR_ICON) / 2)

    Render.Image(Res.ogreIcon, Vec2(hdrX, iconY), Vec2(PL.HDR_ICON, PL.HDR_ICON),
                 Color(255, 255, 255, 255), 3, Enum.DrawFlags.RoundCornersAll)

    local txtX = hdrX + PL.HDR_ICON + PL.HDR_GAP
    local txtSize = Render.TextSize(Res.font, 12, "Auto Buff")
    local txtY = hdrY + math_floor((PL.HEADER_H - (txtSize.y or 12)) / 2)
    Render.Text(Res.font, 12, "Auto Buff", Vec2(txtX, txtY), colText)

    -- маленькие иконки BL и FS справа в заголовке как легенда
    local legendSize = 10
    local legendGap  = 3
    local legendX    = x1 - PL.PAD_X - legendSize
    local legendY    = hdrY + math_floor((PL.HEADER_H - legendSize) / 2)

    -- FS иконка (правее)
    Render.FilledRect(Vec2(legendX, legendY), Vec2(legendX + legendSize, legendY + legendSize), colFS, 2, Enum.DrawFlags.RoundCornersAll)
    Render.Text(Res.fontSmall, 8, "S", Vec2(legendX + 2, legendY), Color(255, 255, 255, 220))

    -- BL иконка (левее)
    legendX = legendX - legendSize - legendGap
    Render.FilledRect(Vec2(legendX, legendY), Vec2(legendX + legendSize, legendY + legendSize), colBL, 2, Enum.DrawFlags.RoundCornersAll)
    Render.Text(Res.fontSmall, 8, "B", Vec2(legendX + 2, legendY), Color(255, 255, 255, 220))

    -- ─── Иконки героев ───
    local rowStartX = x0 + PL.PAD_X + math_floor((contentW - rowW) / 2)
    local rowY      = hdrY + PL.HEADER_H + PL.SECT_GAP

    for i, slot in ipairs(slots) do
        local ix = rowStartX + (i - 1) * (cellW + PL.CELL_GAP)
        local iy = rowY

        local blOn = GetSlotBL(slot)
        local fsOn = GetSlotFS(slot)
        local anyOn = blOn or fsOn

        -- Иконка героя
        local img = GetHeroImage(slot.name)
        if img then
            local imgAlpha = anyOn and 255 or 100
            Render.Image(img, Vec2(ix, iy), Vec2(PL.ICON, PL.ICON),
                         Color(255, 255, 255, imgAlpha), PL.ICON_R, Enum.DrawFlags.RoundCornersAll)
        end

        -- Рамка accent если хотя бы один бафф включён
        if anyOn then
            Render.Rect(Vec2(ix - 1, iy - 1), Vec2(ix + PL.ICON + 1, iy + PL.ICON + 1),
                        colAccent, PL.ICON_R, Enum.DrawFlags.RoundCornersAll, 1)
        end

        -- Метка "Self" для своей иконки
        if slot.isSelf then
            local selfSize = Render.TextSize(Res.fontSmall, 8, "YOU")
            local selfX = ix + math_floor((PL.ICON - (selfSize.x or 18)) / 2)
            local selfY = iy + PL.ICON - (selfSize.y or 8) - 1
            Render.FilledRect(Vec2(ix, selfY - 1), Vec2(ix + PL.ICON, iy + PL.ICON),
                              Color(0, 0, 0, 140), 0, Enum.DrawFlags.RoundCornersBottom)
            Render.Text(Res.fontSmall, 8, "YOU", Vec2(selfX, selfY), Color(255, 255, 255, 200))
        end

        -- Полоска-индикатор под иконкой: [BL | FS]
        local barY = iy + PL.ICON + PL.ICON_BAR
        local halfW = math_floor((PL.ICON - PL.BAR_GAP) / 2)

        -- BL половинка (левая)
        local blC = blOn and colBL or colDim
        Render.FilledRect(Vec2(ix, barY), Vec2(ix + halfW, barY + PL.BAR_H), blC, 1, Enum.DrawFlags.RoundCornersAll)

        -- FS половинка (правая)
        local fsC = fsOn and colFS or colDim
        Render.FilledRect(Vec2(ix + halfW + PL.BAR_GAP, barY),
                          Vec2(ix + PL.ICON, barY + PL.BAR_H), fsC, 1, Enum.DrawFlags.RoundCornersAll)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  In-Game Panel — Ввод (drag + click)
-- ═══════════════════════════════════════════════════════════════════════════

local function HandlePanelInput()
    Panel.clickEaten = false
    Panel.isHovered  = false

    if not UI.ShowPanel:Get() or not UI.Enabled:Get() then return end

    local cx, cy = Input.GetCursorPos()
    local x0, y0 = Panel.x, Panel.y
    local x1, y1 = x0 + Panel.w, y0 + Panel.h

    Panel.isHovered = cx >= x0 and cx <= x1 and cy >= y0 and cy <= y1

    -- ─── Drag (LMB на заголовке) ───
    local hdrBottom = y0 + PL.PAD_Y + PL.HEADER_H
    local onHeader  = cx >= x0 and cx <= x1 and cy >= y0 and cy <= hdrBottom

    if onHeader and Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) and not Panel.dragging then
        Panel.dragging = true
        Panel.dx = cx - x0
        Panel.dy = cy - y0
        Panel.clickEaten = true
    end

    if Panel.dragging then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            Panel.x = cx - Panel.dx
            Panel.y = cy - Panel.dy
        else
            Panel.dragging = false
        end
        Panel.clickEaten = true
        return
    end

    -- ─── Клик по иконкам героев ───
    if not Panel.isHovered then return end
    if not Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1) then return end

    local slots = BuildSlots()
    local nSlots = #slots
    local cellW  = PL.ICON
    local rowW   = nSlots * cellW + math_max(0, nSlots - 1) * PL.CELL_GAP
    local headerW = PL.HDR_ICON + PL.HDR_GAP + 72
    local contentW = math_max(rowW, headerW)
    local rowStartX = x0 + PL.PAD_X + math_floor((contentW - rowW) / 2)
    local rowY      = y0 + PL.PAD_Y + PL.HEADER_H + PL.SECT_GAP

    for i, slot in ipairs(slots) do
        local ix = rowStartX + (i - 1) * (cellW + PL.CELL_GAP)
        local iy = rowY

        -- Проверка клика по иконке (переключаем оба баффа)
        if cx >= ix and cx <= ix + PL.ICON and cy >= iy and cy <= iy + PL.ICON then
            local blOn = GetSlotBL(slot)
            local fsOn = GetSlotFS(slot)
            -- Цикл: оба вкл → только BL → только FS → оба выкл → оба вкл
            if blOn and fsOn then
                SetSlotBL(slot, true)
                SetSlotFS(slot, false)
            elseif blOn and not fsOn then
                SetSlotBL(slot, false)
                SetSlotFS(slot, true)
            elseif not blOn and fsOn then
                SetSlotBL(slot, false)
                SetSlotFS(slot, false)
            else
                SetSlotBL(slot, true)
                SetSlotFS(slot, true)
            end
            Panel.clickEaten = true
            return
        end

        -- Проверка клика по полоскам-индикаторам
        local barY = iy + PL.ICON + PL.ICON_BAR
        local halfW = math_floor((PL.ICON - PL.BAR_GAP) / 2)

        -- BL полоска
        if cx >= ix and cx <= ix + halfW and cy >= barY and cy <= barY + PL.BAR_H + 4 then
            SetSlotBL(slot, not GetSlotBL(slot))
            Panel.clickEaten = true
            return
        end

        -- FS полоска
        if cx >= ix + halfW + PL.BAR_GAP and cx <= ix + PL.ICON and cy >= barY and cy <= barY + PL.BAR_H + 4 then
            SetSlotFS(slot, not GetSlotFS(slot))
            Panel.clickEaten = true
            return
        end
    end

    -- Клик был внутри панели, но не по кнопке — всё равно съедаем
    Panel.clickEaten = true
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnUpdate — Основная логика
-- ═══════════════════════════════════════════════════════════════════════════

script.OnUpdate = function()
    if not IsOgreMagi() or not UI.Enabled:Get() or not Engine.IsInGame() then
        return
    end

    local hero = Heroes.GetLocal()
    if not hero or not Entity.IsAlive(hero) then return end

    local now = GameRules.GetGameTime()

    -- Обновляем список союзников
    if now - State.lastAllyCheck > 2.0 then
        UpdateAllyMultiSelects(hero)
        State.lastAllyCheck = now
    end

    -- Обработка ввода панели
    HandlePanelInput()

    -- Не кастуем, если герой в дизейбле
    if IsHeroDisabled(hero) then return end

    -- Порог маны
    local maxMana = NPC.GetMaxMana(hero)
    if maxMana <= 0 then return end
    if (NPC.GetMana(hero) / maxMana) * 100 < UI.ManaThreshold:Get() then return end

    -- Задержка между кастами
    if now - State.lastCastTime < UI.CastDelay:Get() / 1000.0 then return end

    -- ─── Bloodlust ───
    if UI.BloodlustEnabled:Get() then
        local bloodlust = NPC.GetAbility(hero, ABILITY_BLOODLUST)
        if CanCastAbility(hero, bloodlust) then
            local target = FindBestBuffTarget(
                hero, MOD_BLOODLUST, UI.BloodlustRebuff:Get(),
                UI.BloodlustSelf:Get(), UI.BloodlustTargets,
                Ability.GetCastRange(bloodlust) or 650
            )
            if target then
                Ability.CastTarget(bloodlust, target, false, false, false, "ogre_auto_buff")
                State.lastCastTime = now
                return
            end
        end
    end

    -- ─── Fire Shield / Frost Armor ───
    if UI.ShieldEnabled:Get() then
        local shield, shieldMod = GetFireShieldAbility(hero)
        if CanCastAbility(hero, shield) then
            local target = FindBestBuffTarget(
                hero, shieldMod, UI.ShieldRebuff:Get(),
                UI.ShieldSelf:Get(), UI.ShieldTargets,
                Ability.GetCastRange(shield) or 600
            )
            if target then
                Ability.CastTarget(shield, target, false, false, false, "ogre_auto_buff")
                State.lastCastTime = now
                return
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnDraw — Отрисовка панели
-- ═══════════════════════════════════════════════════════════════════════════

script.OnDraw = function()
    if not IsOgreMagi() or not Engine.IsInGame() then return end
    if not UI.Enabled:Get() or not UI.ShowPanel:Get() then return end

    local hero = Heroes.GetLocal()
    if not hero then return end

    DrawPanel()
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnPrepareUnitOrders — Блокировка ордеров при клике по панели
-- ═══════════════════════════════════════════════════════════════════════════

script.OnPrepareUnitOrders = function(data)
    if Panel.isHovered or Panel.clickEaten then
        return false
    end
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
--  OnGameEnd — Сброс
-- ═══════════════════════════════════════════════════════════════════════════

script.OnGameEnd = function()
    State.lastCastTime  = 0
    State.lastAllyCheck = 0
    State.allyHeroNames = {}
    Res.heroImages      = {}
    Panel.dragging      = false
    Panel.isHovered     = false
    Panel.clickEaten    = false
end

return script
