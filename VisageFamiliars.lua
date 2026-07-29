--[[
    Visage Familiars
    Familiars follow Visage; mirror his attack target; Combo Key dives cursor hero.
    Script by 花曇り hanagumori
--]]

local Script = {}

--#region Constants
local UPDATE_INTERVAL = 0.05
local ATTACK_ORDER_GAP = 0.25
local FOLLOW_ORDER_GAP = 0.55
local OVERRIDE_PAUSE = 1.50
local ATTACK_GRACE = 1.20
local MENU_LOOKUP_TTL = 1.0
local DEFAULT_FOLLOW_DISTANCE = 180
local DEFAULT_FOLLOW_DEADZONE = 100
local DEFAULT_SEARCH_RANGE = 1200
local HUD_BAR_ABOVE = 38

local ORDER_ATTACK = "visage.familiars.attack"
local ORDER_FOLLOW = "visage.familiars.follow"

local HERO_NAME = "npc_dota_hero_visage"
local FAMILIAR_NAME_HAS = "visage_familiar"

local STATE_DISARMED = 1 -- MODIFIER_STATE_DISARMED
local STATE_ATTACK_IMMUNE = 2 -- MODIFIER_STATE_ATTACK_IMMUNE
local TEAM_ENEMY = 0 -- Enum.TeamType.TEAM_ENEMY
local TEAM_BOTH = 2 -- Enum.TeamType.TEAM_BOTH
local FONT_ANTIALIAS = 16 -- Enum.FontCreate.FONTFLAG_ANTIALIAS

local ORDER_MOVE_TO_POSITION = 1
local ORDER_MOVE_TO_TARGET = 2
local ORDER_ATTACK_MOVE = 3
local ORDER_ATTACK_TARGET = 4

local ICON_ENABLE = "\u{f00c}"
local ICON_FOLLOW = "\u{f4ba}"
local ICON_DEADZONE = "\u{f192}"
local ICON_HUD = "\u{f201}"

local STYLE_KEYS = {
    "active_widgets_text", "additional_background", "button_active_background",
    "button_background", "combo_frame", "combo_item", "combo_item_active",
    "disabled_switch_background", "disabled_switch_circle", "enabled_switch_background",
    "group_background", "group_outline", "healthbar_ally", "healthbar_enemy",
    "healthbar_roshan", "healthbar_self", "hero_tab_filter_background",
    "hero_tab_filter_separator", "indication_active", "indication_inactive",
    "input_text_bg", "keybind_background", "keybind_background_active",
    "left_tabs_background", "main_background", "manabar", "multiselect_item",
    "multiselect_item_selected", "outline", "popup_background", "popup_border",
    "primary", "primary_first_tab_text", "primary_second_tab_text",
    "primary_widgets_text", "scrollbar_bg", "search_outline", "search_text",
    "section_group_text", "selected_tabs_background", "separator", "shadow",
    "slider_background", "slider_background_active", "slider_grab",
    "slider_grab_active", "text_shadow", "third_tab_text", "widgets_shadow",
}
--#endregion

--#region State
---@class VisageFamiliarsUI
---@field enabled CMenuSwitch|nil
---@field followDistance CMenuSliderInt|nil
---@field followDeadzone CMenuSliderInt|nil
---@field showHud CMenuSwitch|nil
local UI = {
    enabled = nil,
    followDistance = nil,
    followDeadzone = nil,
    showHud = nil,
}

local Persistent = {
    comboKey = nil,
    comboKeyLookupAt = 0,
    searchRange = nil,
    searchRangeLookupAt = 0,
    font = nil,
}

local Style = {}
local Colors = {
    Text = Color(245, 247, 250, 255),
    TextShadow = Color(0, 0, 0, 140),
    Accent = Color(180, 180, 190, 255),
    BarBg = Color(40, 40, 50, 200),
    BarFill = Color(80, 200, 120, 255),
    Shadow = Color(0, 0, 0, 160),
    Warn = Color(220, 120, 80, 255),
}

local Runtime = {
    lastUpdateAt = -math.huge,
    heroTargetIndex = nil,
    lastAttackingAt = -math.huge,
    attackMoveActive = false,
    issuedAt = {},
    lastRole = {},
    lastTargetIndex = {},
    overrideUntil = {},
    hudCount = 0,
    hudHp = 0,
    hudMaxHp = 0,
}
--#endregion

--#region Theme
local function ChannelByte(value)
    if type(value) ~= "number" then
        return 255
    end
    if value <= 1 then
        return math.floor(value * 255 + 0.5)
    end
    return math.floor(value + 0.5)
end

local function NormalizeColor(value, fallback)
    if value == nil then
        return fallback
    end
    if type(value) == "userdata" then
        return Color(
            ChannelByte(value.r),
            ChannelByte(value.g),
            ChannelByte(value.b),
            ChannelByte(value.a ~= nil and value.a or 255)
        )
    end
    if type(value) == "table" then
        return Color(
            ChannelByte(value.r or value[1] or 255),
            ChannelByte(value.g or value[2] or 255),
            ChannelByte(value.b or value[3] or 255),
            ChannelByte(value.a or value[4] or 255)
        )
    end
    return fallback
end

local function TryGetThemeColor(key, all)
    local value = Menu.Style(key)
    if value == nil and type(all) == "table" then
        value = all[key]
    end
    return NormalizeColor(value, nil)
end

local function SyncColors()
    local all = Menu.Style()
    for i = 1, #STYLE_KEYS do
        local key = STYLE_KEYS[i]
        Style[key] = TryGetThemeColor(key, all)
    end
    if type(all) == "table" then
        for key, _ in pairs(all) do
            if Style[key] == nil then
                Style[key] = TryGetThemeColor(key, all)
            end
        end
    end

    Colors.Text = Style.primary_widgets_text
        or Style.active_widgets_text
        or Colors.Text
    Colors.Accent = Style.enabled_switch_background
        or Style.combo_item_active
        or Style.primary
        or Style.indication_active
        or Colors.Accent
    Colors.BarBg = Style.slider_background
        or Style.combo_frame
        or Style.scrollbar_bg
        or Colors.BarBg
    Colors.BarFill = Style.healthbar_self
        or Style.primary
        or Style.slider_grab_active
        or Colors.BarFill
    Colors.Shadow = Style.shadow or Colors.Shadow
    Colors.Warn = Style.indication_active
        or Style.button_active_background
        or Colors.Warn
    if Style.text_shadow and (Style.text_shadow.a or 0) > 0 then
        Colors.TextShadow = Style.text_shadow
    end
end

local function WithAlpha(color, alpha)
    return Color(color.r, color.g, color.b, alpha)
end
--#endregion

--#region Helpers
local function ResetRuntime()
    Runtime.lastUpdateAt = -math.huge
    Runtime.heroTargetIndex = nil
    Runtime.lastAttackingAt = -math.huge
    Runtime.attackMoveActive = false
    Runtime.issuedAt = {}
    Runtime.lastRole = {}
    Runtime.lastTargetIndex = {}
    Runtime.overrideUntil = {}
    Runtime.hudCount = 0
    Runtime.hudHp = 0
    Runtime.hudMaxHp = 0
end

local function OnEnabledChanged(widget)
    if widget:Get() ~= true then
        ResetRuntime()
    end
end

local function GetComboKey()
    local now = os.clock()
    if Persistent.comboKey and now < Persistent.comboKeyLookupAt then
        return Persistent.comboKey
    end
    Persistent.comboKeyLookupAt = now + MENU_LOOKUP_TTL
    Persistent.comboKey = Menu.Find(
        "Heroes", "Hero List", "Visage", "Main Settings", "Hero Settings", "Combo Key"
    )
    return Persistent.comboKey
end

local function GetSearchRangeWidget()
    local now = os.clock()
    if Persistent.searchRange and now < Persistent.searchRangeLookupAt then
        return Persistent.searchRange
    end
    Persistent.searchRangeLookupAt = now + MENU_LOOKUP_TTL
    Persistent.searchRange = Menu.Find(
        "Heroes", "", "Settings", "General", "Target Selection", "Search Range"
    )
    return Persistent.searchRange
end

local function GetSearchRange()
    local widget = GetSearchRangeWidget()
    if widget then
        return widget:Get()
    end
    return DEFAULT_SEARCH_RANGE
end

local function HasPlain(haystack, needle)
    return haystack ~= nil and haystack ~= "" and needle ~= nil
        and string.find(haystack, needle, 1, true) ~= nil
end

local function IsVisage(hero)
    local name = NPC.GetUnitName(hero)
    if not name or name == "" then
        name = Entity.GetUnitName(hero)
    end
    return name == HERO_NAME
end

local function IsFamiliar(npc)
    local name = NPC.GetUnitName(npc)
    if not name or name == "" then
        name = Entity.GetUnitName(npc)
    end
    if HasPlain(name, FAMILIAR_NAME_HAS) then
        return true
    end
    return HasPlain(Entity.GetClassName(npc), FAMILIAR_NAME_HAS)
end

local function IsOwnedFamiliar(npc, playerId, me)
    if npc == me then
        return false
    end
    if IsFamiliar(npc) ~= true then
        return false
    end
    if NPC.IsControllableByPlayer(npc, playerId) ~= true then
        return false
    end
    if Entity.IsAlive(npc) ~= true then
        return false
    end
    if NPC.IsWaitingToSpawn(npc) == true then
        return false
    end
    return true
end

local function IsValidFamiliar(npc, playerId, me)
    return IsOwnedFamiliar(npc, playerId, me)
        and NPC.HasState(npc, STATE_DISARMED) ~= true
end

local function IsAttackableTarget(npc)
    return Entity.IsAlive(npc) == true
        and NPC.IsWaitingToSpawn(npc) ~= true
        and NPC.HasState(npc, STATE_ATTACK_IMMUNE) ~= true
end

local function IsEnemyCombatUnit(npc, myTeam)
    if npc == nil or IsFamiliar(npc) then
        return false
    end
    if NPC.IsCourier(npc) == true then
        return false
    end
    if IsAttackableTarget(npc) ~= true then
        return false
    end
    if NPC.IsNeutral(npc) == true then
        return true
    end
    return Entity.GetTeamNum(npc) ~= myTeam
end

local function IsOwnOrder(data)
    local id = data and data.identifier
    return id == ORDER_ATTACK or id == ORDER_FOLLOW
end

local function ResolveEntity(index)
    if not index then
        return nil
    end
    local entity = Entity.Get(index)
    if not entity or Entity.IsAlive(entity) ~= true then
        return nil
    end
    return entity
end

local function LockHeroTarget(target, now)
    if not target or IsAttackableTarget(target) ~= true then
        return nil
    end
    Runtime.heroTargetIndex = Entity.GetIndex(target)
    Runtime.lastAttackingAt = now
    return target
end

local function ResolveHeroAttackTarget(me, now)
    local meIndex = Entity.GetIndex(me)

    if NPC.IsAttacking(me) == true then
        Runtime.lastAttackingAt = now
    elseif now - Runtime.lastAttackingAt > ATTACK_GRACE then
        Runtime.heroTargetIndex = nil
        Runtime.attackMoveActive = false
    end

    local queue = Humanizer.GetOrderQueue()
    if queue then
        for i = 1, #queue do
            local entry = queue[i]
            if entry.unit
                and Entity.GetIndex(entry.unit) == meIndex
                and entry.orderType == ORDER_ATTACK_TARGET
                and entry.targetIndex
                and entry.targetIndex > 0
            then
                local locked = LockHeroTarget(Entity.Get(entry.targetIndex), now)
                if locked then
                    return locked
                end
            end
        end
    end

    local projectiles = TargetProjectiles.GetAll()
    if projectiles then
        for i = 1, #projectiles do
            local proj = projectiles[i]
            if proj.attack == true
                and proj.source
                and Entity.GetIndex(proj.source) == meIndex
                and proj.target
            then
                local locked = LockHeroTarget(proj.target, now)
                if locked then
                    return locked
                end
            end
        end
    end

    local cached = ResolveEntity(Runtime.heroTargetIndex)
    if cached and IsAttackableTarget(cached) then
        return cached
    end

    Runtime.heroTargetIndex = nil
    return nil
end

local function PickComboTarget(me, searchRange)
    local myTeam = Entity.GetTeamNum(me)
    local hero = Input.GetNearestHeroToCursor(myTeam, TEAM_ENEMY)
    if not hero or IsAttackableTarget(hero) ~= true then
        return nil
    end
    local cursor = Input.GetWorldCursorPos()
    if cursor:DistanceSqr2D(Entity.GetAbsOrigin(hero)) > searchRange * searchRange then
        return nil
    end
    return hero
end

local function ConsiderFocusCandidate(npc, myTeam, origin, attackRangeSqr, best, bestScore)
    if not IsEnemyCombatUnit(npc, myTeam) then
        return best, bestScore
    end
    local distSqr = origin:DistanceSqr2D(Entity.GetAbsOrigin(npc))
    local score = distSqr + Entity.GetHealth(npc) * 25
    if distSqr <= attackRangeSqr then
        score = score - 1e12
    end
    if score < bestScore then
        return npc, score
    end
    return best, bestScore
end

local function PickUnitNearPos(me, pos, searchRange)
    if not pos then
        return nil
    end
    local myTeam = Entity.GetTeamNum(me)
    local units = NPCs.InRadius(pos, searchRange, myTeam, TEAM_BOTH, true, true)
    if not units then
        return nil
    end
    local best, bestDist = nil, math.huge
    for i = 1, #units do
        local npc = units[i]
        if IsEnemyCombatUnit(npc, myTeam) then
            local distSqr = pos:DistanceSqr2D(Entity.GetAbsOrigin(npc))
            if distSqr < bestDist then
                bestDist = distSqr
                best = npc
            end
        end
    end
    return best
end

local function PickHeroFocusTarget(me, searchRange)
    local myTeam = Entity.GetTeamNum(me)
    local origin = Entity.GetAbsOrigin(me)
    local attackRange = NPC.GetAttackRange(me) + NPC.GetAttackRangeBonus(me) + 80
    local attackRangeSqr = attackRange * attackRange
    local best, bestScore = nil, math.huge

    local units = Entity.GetUnitsInRadius(me, searchRange, TEAM_BOTH, true, true)
    for i = 1, #units do
        best, bestScore = ConsiderFocusCandidate(units[i], myTeam, origin, attackRangeSqr, best, bestScore)
    end
    local heroes = Entity.GetHeroesInRadius(me, searchRange, TEAM_ENEMY, true, true)
    for i = 1, #heroes do
        best, bestScore = ConsiderFocusCandidate(heroes[i], myTeam, origin, attackRangeSqr, best, bestScore)
    end
    return best
end

local function HeroWantsCombat(me, now)
    return Runtime.attackMoveActive == true
        or NPC.IsAttacking(me) == true
        or now - Runtime.lastAttackingAt <= ATTACK_GRACE
end

local function FollowPosition(me, followDistance)
    local origin = Entity.GetAbsOrigin(me)
    local forward = Entity.GetRotation(me):GetForward()
    local pos = origin - forward * followDistance
    pos:SetGroundZ()
    return pos
end

local function CollectFamiliars(playerId, me, allowDisarmed)
    local units = NPCs.GetAll()
    local familiars = {}
    for i = 1, #units do
        local npc = units[i]
        local ok = false
        if allowDisarmed == true then
            ok = IsOwnedFamiliar(npc, playerId, me)
        else
            ok = IsValidFamiliar(npc, playerId, me)
        end
        if ok then
            familiars[#familiars + 1] = npc
        end
    end
    return familiars
end

local function RefreshFamiliarHud(playerId, me)
    local familiars = CollectFamiliars(playerId, me, true)
    local hp, maxHp = 0, 0
    for i = 1, #familiars do
        hp = hp + Entity.GetHealth(familiars[i])
        maxHp = maxHp + Entity.GetMaxHealth(familiars[i])
    end
    Runtime.hudCount = #familiars
    Runtime.hudHp = hp
    Runtime.hudMaxHp = maxHp
    return familiars
end

local function CanIssue(index, now, gap)
    local last = Runtime.issuedAt[index]
    return not last or now - last >= gap
end

local function IssueAttack(player, familiar, target, now)
    local index = Entity.GetIndex(familiar)
    local targetIndex = Entity.GetIndex(target)
    if Runtime.lastRole[index] == "attack"
        and Runtime.lastTargetIndex[index] == targetIndex
        and not CanIssue(index, now, ATTACK_ORDER_GAP)
    then
        return
    end
    Player.AttackTarget(player, familiar, target, false, true, true, ORDER_ATTACK, false)
    Runtime.issuedAt[index] = now
    Runtime.lastRole[index] = "attack"
    Runtime.lastTargetIndex[index] = targetIndex
end

local function CommandFamiliarsAttack(me, target, now)
    if not target or IsAttackableTarget(target) ~= true then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    local player = Players.GetLocal()
    if not player then
        return
    end
    local playerId = Player.GetPlayerID(player)
    if playerId < 0 then
        return
    end
    local familiars = CollectFamiliars(playerId, me, false)
    for i = 1, #familiars do
        local familiar = familiars[i]
        local untilAt = Runtime.overrideUntil[Entity.GetIndex(familiar)]
        if not untilAt or now >= untilAt then
            IssueAttack(player, familiar, target, now)
        end
    end
end

local function IssueFollow(familiar, followPos, deadzone, now)
    local index = Entity.GetIndex(familiar)
    local pos = Entity.GetAbsOrigin(familiar)
    if pos:DistanceSqr2D(followPos) <= deadzone * deadzone then
        Runtime.lastRole[index] = "follow"
        Runtime.lastTargetIndex[index] = nil
        return
    end
    if Runtime.lastRole[index] == "follow" and not CanIssue(index, now, FOLLOW_ORDER_GAP) then
        return
    end
    NPC.MoveTo(familiar, followPos, false, false, true, false, ORDER_FOLLOW, false)
    Runtime.issuedAt[index] = now
    Runtime.lastRole[index] = "follow"
    Runtime.lastTargetIndex[index] = nil
end

local function UpdateFeature(me, now, familiars)
    local player = Players.GetLocal()
    if not player or #familiars == 0 then
        return
    end

    local searchRange = GetSearchRange()
    local comboKey = GetComboKey()
    local comboDown = comboKey ~= nil and comboKey:IsDown() == true
    local attackTarget = nil

    if comboDown then
        attackTarget = PickComboTarget(me, searchRange)
    else
        attackTarget = ResolveHeroAttackTarget(me, now)
        if not attackTarget and HeroWantsCombat(me, now) then
            attackTarget = PickHeroFocusTarget(me, searchRange)
            if attackTarget then
                LockHeroTarget(attackTarget, now)
            end
        end
    end

    if attackTarget then
        CommandFamiliarsAttack(me, attackTarget, now)
        return
    end

    local followPos = FollowPosition(me, UI.followDistance:Get())
    local deadzone = UI.followDeadzone:Get()
    for i = 1, #familiars do
        local familiar = familiars[i]
        if NPC.HasState(familiar, STATE_DISARMED) ~= true then
            local untilAt = Runtime.overrideUntil[Entity.GetIndex(familiar)]
            if not untilAt or now >= untilAt then
                IssueFollow(familiar, followPos, deadzone, now)
            end
        end
    end
end
--#endregion

--#region HUD
local function EnsureFont()
    if Persistent.font then
        return Persistent.font
    end
    local names = { "Segoe UI", "Tahoma", "Arial" }
    for i = 1, #names do
        local handle = Render.LoadFont(names[i], FONT_ANTIALIAS, 600)
        if handle and handle ~= 0 then
            local size = Render.TextSize(handle, 12, "Ag")
            if size and size.x > 0 then
                Persistent.font = handle
                return handle
            end
        end
    end
    return nil
end

local function DrawFamiliarHud(me)
    if not UI.showHud or UI.showHud:Get() ~= true then
        return
    end
    if Runtime.hudCount <= 0 then
        return
    end

    local font = EnsureFont()
    if not font then
        return
    end

    local origin = Entity.GetAbsOrigin(me)
    local barOffset = NPC.GetHealthBarOffset(me)
    local world = Vector(origin.x, origin.y, origin.z + barOffset)
    local screen, visible = world:ToScreen()
    if visible ~= true then
        return
    end

    local scale = Menu.Scale() / 100
    if scale <= 0 then
        scale = 1
    end

    local fontSize = 12 * scale
    local barW = 72 * scale
    local barH = 3 * scale
    local gap = HUD_BAR_ABOVE * scale
    local label = string.format("x%d  %d", Runtime.hudCount, Runtime.hudHp)
    local textSize = Render.TextSize(font, fontSize, label)
    local totalW = math.max(barW, textSize.x)
    local x = screen.x - totalW * 0.5
    local y = screen.y - gap - textSize.y - barH - 4 * scale

    local textPos = Vec2(x + (totalW - textSize.x) * 0.5, y)
    if Colors.TextShadow and (Colors.TextShadow.a or 0) > 0 then
        Render.Text(font, fontSize, label, Vec2(textPos.x + 1, textPos.y + 1), Colors.TextShadow)
    end
    Render.Text(font, fontSize, label, textPos, Colors.Text)

    local ratio = 0
    if Runtime.hudMaxHp > 0 then
        ratio = Runtime.hudHp / Runtime.hudMaxHp
        if ratio < 0 then
            ratio = 0
        elseif ratio > 1 then
            ratio = 1
        end
    end

    local barY = y + textSize.y + 2 * scale
    local barStart = Vec2(x + (totalW - barW) * 0.5, barY)
    local barEnd = Vec2(barStart.x + barW, barStart.y + barH)
    local fillEnd = Vec2(barStart.x + barW * ratio, barEnd.y)
    local rounding = 1.5 * scale
    local t = GameRules.GetGameTime()
    local pulse = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * 5.5))

    local fillColor = Colors.BarFill
    if ratio <= 0.35 then
        fillColor = Colors.Warn
    end

    if Colors.Shadow and (Colors.Shadow.a or 0) > 0 then
        local glow = WithAlpha(fillColor, math.floor((Colors.Shadow.a or 160) * pulse))
        Render.Shadow(barStart, fillEnd, glow, 10 * scale, rounding)
    end

    Render.FilledRect(barStart, barEnd, Colors.BarBg, rounding)
    if ratio > 0.001 then
        Render.FilledRect(barStart, fillEnd, WithAlpha(fillColor, math.floor(180 + 75 * pulse)), rounding)
        -- Soft shimmer highlight traveling along the fill.
        local shimmerW = math.max(6 * scale, barW * 0.18)
        local travel = (0.5 + 0.5 * math.sin(t * 3.2))
        local sx = barStart.x + math.max(0, (barW * ratio - shimmerW) * travel)
        local shimmer = WithAlpha(Colors.Accent, math.floor(90 + 110 * pulse))
        Render.FilledRect(Vec2(sx, barStart.y), Vec2(sx + shimmerW, barEnd.y), shimmer, rounding)
    end
end
--#endregion

--#region Lifecycle
function Script.OnScriptsLoaded()
    local group = Menu.Create(
        "Heroes", "Hero List", "Visage", "Main Settings", "Familiars Settings"
    )

    UI.enabled = group:Switch("Enable", true, ICON_ENABLE)
    UI.enabled:SetCallback(OnEnabledChanged, false)
    UI.enabled:ToolTip(
        "Familiars follow Visage and mirror A-click / RMB targets. Combo Key dives the cursor hero within Search Range of the cursor."
    )

    UI.followDistance = group:Slider("Follow Distance", 100, 600, DEFAULT_FOLLOW_DISTANCE)
    UI.followDistance:Icon(ICON_FOLLOW)
    UI.followDistance:ToolTip("How far behind Visage familiars try to stay.")

    UI.followDeadzone = group:Slider("Follow Deadzone", 40, 300, DEFAULT_FOLLOW_DEADZONE)
    UI.followDeadzone:Icon(ICON_DEADZONE)
    UI.followDeadzone:ToolTip("Skip move orders when already this close to the follow point.")

    UI.showHud = group:Switch("Status Overlay", true, ICON_HUD)
    UI.showHud:ToolTip("Show familiar count and HP bar above your hero health bar.")

    SyncColors()
    EnsureFont()
    GetComboKey()
    GetSearchRangeWidget()
end

function Script.OnThemeUpdate()
    SyncColors()
end

function Script.OnUpdate()
    if not Engine.IsInGame() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    if Input.IsInputCaptured() then
        return
    end

    local now = GameRules.GetGameTime()
    if now - Runtime.lastUpdateAt < UPDATE_INTERVAL then
        return
    end
    Runtime.lastUpdateAt = now

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true or not IsVisage(me) then
        Runtime.hudCount = 0
        return
    end

    local player = Players.GetLocal()
    if not player then
        return
    end
    local playerId = Player.GetPlayerID(player)
    if playerId < 0 then
        return
    end

    local familiars = RefreshFamiliarHud(playerId, me)
    UpdateFeature(me, now, familiars)
end

function Script.OnDraw()
    if not Engine.IsInGame() then
        return
    end
    if not Menu.VisualsIsEnabled() then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end

    local me = Heroes.GetLocal()
    if not me or Entity.IsAlive(me) ~= true or not IsVisage(me) then
        return
    end

    DrawFamiliarHud(me)
end

function Script.OnPrepareUnitOrders(data, player, order, target, position, ability, orderIssuer, npc, queue, showEffects)
    if IsOwnOrder(data) then
        return true
    end

    local localPlayer = Players.GetLocal()
    if not localPlayer or player ~= localPlayer then
        return true
    end

    local me = Heroes.GetLocal()
    if not me or not IsVisage(me) then
        return true
    end

    local now = GameRules.GetGameTime()
    local npcIsMe = npc == me or Entity.GetIndex(npc) == Entity.GetIndex(me)

    if order == ORDER_ATTACK_TARGET and target and IsAttackableTarget(target) then
        LockHeroTarget(target, now)
        Runtime.attackMoveActive = false
        CommandFamiliarsAttack(me, target, now)
    elseif order == ORDER_ATTACK_MOVE then
        Runtime.attackMoveActive = true
        Runtime.lastAttackingAt = now
        local early = position and PickUnitNearPos(me, position, GetSearchRange()) or nil
        if not early then
            early = PickHeroFocusTarget(me, GetSearchRange())
        end
        if early then
            LockHeroTarget(early, now)
            CommandFamiliarsAttack(me, early, now)
        end
    elseif npcIsMe
        and (order == ORDER_MOVE_TO_POSITION or order == ORDER_MOVE_TO_TARGET)
    then
        Runtime.heroTargetIndex = nil
        Runtime.attackMoveActive = false
    end

    local playerId = Player.GetPlayerID(localPlayer)
    if playerId >= 0
        and IsValidFamiliar(npc, playerId, me)
        and order ~= ORDER_ATTACK_TARGET
        and order ~= ORDER_ATTACK_MOVE
    then
        Runtime.overrideUntil[Entity.GetIndex(npc)] = now + OVERRIDE_PAUSE
    end

    return true
end

function Script.OnProjectile(
    data, source, target, ability, moveSpeed, sourceAttachment,
    particleSystemHandle, dodgeable, isAttack
)
    if isAttack ~= true or not source or not target then
        return
    end
    if not UI.enabled or UI.enabled:Get() ~= true then
        return
    end
    local me = Heroes.GetLocal()
    if not me or not IsVisage(me) then
        return
    end
    if Entity.GetIndex(source) ~= Entity.GetIndex(me) then
        return
    end
    local now = GameRules.GetGameTime()
    LockHeroTarget(target, now)
    CommandFamiliarsAttack(me, target, now)
end

function Script.OnGameEnd()
    ResetRuntime()
    Persistent.comboKey = nil
    Persistent.comboKeyLookupAt = 0
    Persistent.searchRange = nil
    Persistent.searchRangeLookupAt = 0
end
--#endregion

return Script
