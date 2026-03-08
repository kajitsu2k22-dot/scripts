local script = {}

local HERO_NAME = "npc_dota_hero_invoker"
local TORNADO_NAME = "invoker_tornado"
local SPELL_ICON = "panorama/images/spellicons/invoker_tornado_png.vtex_c"
local DEBUG_PREFIX = "[InvokerTornadoStack] "

local BUTTON_SIZE = 28
local BUTTON_VISUAL_Z = 140
local CAST_ORDER_LOCK = 0.60
local STACK_LIFT_SECOND = 59.10
local MIN_STACK_LIFT_SECOND = 58.95
local MAX_STACK_LIFT_SECOND = 59.35

local State = {
    fontSmall = nil,
    icon = nil,
    campBindings = {},
    campBindingsByIndex = {},
    selectedCampIndex = nil,
    lastCampRefresh = 0,
    lastCastTime = -100,
    lastCastMinute = -1,
    menuRootFound = false,
    menuFallbackUsed = false,
}

local function InitializeUI()
    local root = Menu.Find("Heroes", "Hero List", "Invoker", "Auto Usage")
    local group = nil
    State.menuRootFound = root ~= nil

    if root and root.Create then
        group = root:Create("Tornado Stack")
    end

    if not group then
        group = Menu.Create("General", "Invoker", "Tornado Stack", "Settings", "Auto Usage")
        State.menuFallbackUsed = true
    end

    local ui = {}
    ui.Enabled = group:Switch("Auto Tornado Stack", false)
    ui.Enabled:Image(SPELL_ICON)

    local gear = ui.Enabled:Gear("Settings")
    ui.ShowButtons = gear:Switch("Camp Buttons", true)
    ui.ButtonRange = gear:Slider("Button Range", 1800, 12000, 7000, "%d")

    local function UpdateControls()
        local enabled = ui.Enabled:Get()
        ui.ShowButtons:Disabled(not enabled)
        ui.ButtonRange:Disabled(not enabled)
    end

    ui.Enabled:SetCallback(UpdateControls, true)
    return ui
end

local UI = InitializeUI()

local function dbg(message)
    if not Log or not Log.Write then
        return
    end

    Log.Write(DEBUG_PREFIX .. tostring(message))
end

dbg("loaded; menuRootFound=" .. tostring(State.menuRootFound) .. " fallback=" .. tostring(State.menuFallbackUsed))

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function VecX(v)
    return v and (v.x or (v.GetX and v:GetX()) or 0) or 0
end

local function VecY(v)
    return v and (v.y or (v.GetY and v:GetY()) or 0) or 0
end

local function VecZ(v)
    return v and (v.z or (v.GetZ and v:GetZ()) or 0) or 0
end

local function Distance2D(a, b)
    local dx = VecX(a) - VecX(b)
    local dy = VecY(a) - VecY(b)
    return math.sqrt(dx * dx + dy * dy)
end

local function Normalize2D(fromPos, toPos)
    local dx = VecX(toPos) - VecX(fromPos)
    local dy = VecY(toPos) - VecY(fromPos)
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then
        return nil, nil, 0
    end

    return dx / len, dy / len, len
end

local function GetWorldToScreen(worldPos)
    if not worldPos then
        return nil, false
    end

    local function ExtractScreenPoint(a, b, c)
        if type(a) == "table" or type(a) == "userdata" then
            local x = a.x or a[1]
            local y = a.y or a[2]
            local visible = a.visible
            if visible == nil and type(b) == "boolean" then
                visible = b
            end
            if x ~= nil and y ~= nil then
                return Vec2(x, y), visible ~= false
            end
        end

        if type(a) == "number" and type(b) == "number" then
            return Vec2(a, b), c ~= false
        end

        return nil, false
    end

    if Render and Render.WorldToScreen then
        local ok, a, b, c = pcall(Render.WorldToScreen, worldPos)
        if ok then
            local point, visible = ExtractScreenPoint(a, b, c)
            if point then
                return point, visible
            end
        end
    end

    local toScreen = worldPos.ToScreen
    if toScreen then
        local ok, a, b, c = pcall(toScreen, worldPos)
        if ok then
            local point, visible = ExtractScreenPoint(a, b, c)
            if point then
                return point, visible
            end
        end
    end

    return nil, false
end

local function EnsureFonts()
    if State.fontSmall or not Render or not Render.CreateFont then
        return
    end

    State.fontSmall = Render.CreateFont("Tahoma", 12, 500)
end

local function EnsureIcon()
    if State.icon or not Render or not Render.LoadImage then
        return
    end

    State.icon = Render.LoadImage(SPELL_ICON)
end

local function GetTextSize(font, text)
    if not Render or not Render.GetTextSize or not font then
        return 0, 0
    end

    local ok, size = pcall(Render.GetTextSize, font, text)
    if ok and type(size) == "table" then
        return size.x or size[1] or 0, size.y or size[2] or 0
    end

    return 0, 0
end

local function GetLocalHero()
    local hero = Heroes and Heroes.GetLocal and Heroes.GetLocal() or nil
    if not hero then
        return nil
    end

    if NPC.GetUnitName(hero) ~= HERO_NAME then
        return nil
    end

    return hero
end

local function GetAbilityByName(hero, abilityName)
    if not hero or not abilityName then
        return nil
    end

    if NPC and NPC.GetAbilityByName then
        local ok, ability = pcall(NPC.GetAbilityByName, hero, abilityName)
        if ok and ability then
            return ability
        end
    end

    if NPC and NPC.GetAbility then
        local ok, ability = pcall(NPC.GetAbility, hero, abilityName)
        if ok and ability then
            return ability
        end
    end

    local ok, ability = pcall(function()
        return hero:GetAbilityByName(abilityName)
    end)
    if ok then
        return ability
    end

    return nil
end

local function GetAbilityLevel(ability)
    if not ability then
        return 0
    end

    if Ability and Ability.GetLevel then
        local ok, value = pcall(Ability.GetLevel, ability)
        if ok and value then
            return value
        end
    end

    local ok, value = pcall(function()
        return ability:GetLevel()
    end)
    if ok and value then
        return value
    end

    return 0
end

local function GetAbilitySpecialValue(ability, key, fallback)
    if not ability or not key then
        return fallback
    end

    if Ability and Ability.GetSpecialValue then
        local ok, value = pcall(Ability.GetSpecialValue, ability, key)
        if ok and value ~= nil then
            return tonumber(value) or value
        end
    end

    local ok, value = pcall(function()
        return ability:GetSpecialValue(key)
    end)
    if ok and value ~= nil then
        return tonumber(value) or value
    end

    return fallback
end

local function AbilityActivated(ability)
    if not ability then
        return false
    end

    if Ability and Ability.IsActivated then
        local ok, value = pcall(Ability.IsActivated, ability)
        if ok and value ~= nil then
            return value == true
        end
    end

    local ok, value = pcall(function()
        return ability:IsActivated()
    end)
    if ok and value ~= nil then
        return value == true
    end

    return false
end

local function AbilityHidden(ability)
    if not ability then
        return false
    end

    if Ability and Ability.IsHidden then
        local ok, value = pcall(Ability.IsHidden, ability)
        if ok and value ~= nil then
            return value == true
        end
    end

    local ok, value = pcall(function()
        return ability:IsHidden()
    end)
    if ok and value ~= nil then
        return value == true
    end

    return false
end

local function AbilityReady(hero, ability)
    if not hero or not ability then
        return false
    end

    if GetAbilityLevel(ability) <= 0 then
        return false
    end

    if Ability and Ability.IsReady then
        local ok, value = pcall(Ability.IsReady, ability)
        if ok and value == false then
            return false
        end
    end

    if Ability and Ability.IsCastable then
        local mana = NPC.GetMana and NPC.GetMana(hero) or 0
        local ok, value = pcall(Ability.IsCastable, ability, mana)
        if ok and value == false then
            return false
        end
    end

    return true
end

local function CastPosition(hero, ability, pos)
    if not hero or not ability or not pos then
        return false
    end

    if Ability and Ability.CastPosition then
        local ok = pcall(Ability.CastPosition, ability, pos, false, false, false, "invoker_tornado_stack")
        if ok then
            return true
        end
    end

    local ok = pcall(function()
        hero:CastAbilityPosition(ability, pos)
    end)
    return ok
end

local function GetElapsedGameTime()
    local gameTime = GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or 0
    local startTime = GameRules and GameRules.GetGameStartTime and GameRules.GetGameStartTime() or 0
    local elapsed = gameTime - startTime
    if elapsed < 0 and GameRules and GameRules.GetDOTATime then
        elapsed = GameRules.GetDOTATime() or 0
    end
    return elapsed < 0 and 0 or elapsed
end

local function GetMinuteState()
    local elapsed = GetElapsedGameTime()
    local minute = math.floor(elapsed / 60)
    local second = elapsed - (minute * 60)
    return elapsed, minute, second
end

local function GetCampBoxCenter(camp)
    if not camp or not Camp or not Camp.GetCampBox then
        return nil
    end

    local ok, box = pcall(Camp.GetCampBox, camp)
    if not ok or not box or not box.min or not box.max then
        return nil
    end

    return Vector(
        (VecX(box.min) + VecX(box.max)) * 0.5,
        (VecY(box.min) + VecY(box.max)) * 0.5,
        (VecZ(box.min) + VecZ(box.max)) * 0.5
    )
end

local function GetCampAbsOrigin(camp)
    if not camp then
        return nil
    end

    local origin = GetCampBoxCenter(camp)
    if origin then
        return origin
    end

    if Camp and Camp.GetAbsOrigin then
        local ok, value = pcall(Camp.GetAbsOrigin, camp)
        if ok and value then
            return value
        end
    end

    local ok, value = pcall(function()
        return camp:GetAbsOrigin()
    end)
    if ok and value then
        return value
    end

    return nil
end

local function GetCampIndex(camp)
    if not camp then
        return nil
    end

    if Camp and Camp.GetIndex then
        local ok, value = pcall(Camp.GetIndex, camp)
        if ok and value ~= nil then
            return value
        end
    end

    local ok, value = pcall(function()
        return camp:GetIndex()
    end)
    if ok and value ~= nil then
        return value
    end

    return nil
end

local function GetCampType(camp)
    if not camp then
        return nil
    end

    if Camp and Camp.GetType then
        local ok, value = pcall(Camp.GetType, camp)
        if ok and value ~= nil then
            return value
        end
    end

    local ok, value = pcall(function()
        return camp:GetType()
    end)
    if ok and value ~= nil then
        return value
    end

    return nil
end

local function CampTypeShort(camp)
    if not camp then
        return "N"
    end

    local campType = GetCampType(camp)
    local enum = Enum and Enum.ECampType or nil

    if enum then
        if campType == enum.ANCIENT then
            return "A"
        end
        if campType == enum.LARGE then
            return "L"
        end
        if campType == enum.MEDIUM then
            return "M"
        end
        if campType == enum.SMALL then
            return "S"
        end
    end

    return tostring(campType or "N")
end

local function BuildCampBindings()
    local camps = Camps and Camps.GetAll and Camps.GetAll() or {}
    local bindings = {}
    local byIndex = {}

    for listIndex, camp in ipairs(camps) do
        local campPos = GetCampAbsOrigin(camp)
        if campPos then
            local campIndex = GetCampIndex(camp) or listIndex
            local binding = {
                actualIndex = campIndex,
                camp = camp,
                campPos = campPos,
            }
            bindings[#bindings + 1] = binding
            byIndex[campIndex] = binding
        end
    end

    State.campBindings = bindings
    State.campBindingsByIndex = byIndex

    if State.selectedCampIndex and not byIndex[State.selectedCampIndex] then
        State.selectedCampIndex = nil
    end
end

local function RefreshCampBindings(force)
    local now = GameRules and GameRules.GetGameTime and GameRules.GetGameTime() or 0
    if not force and (now - State.lastCampRefresh) < 3.0 then
        return
    end

    State.lastCampRefresh = now
    BuildCampBindings()
end

local function GetSelectedBinding()
    if not State.selectedCampIndex then
        return nil
    end

    return State.campBindingsByIndex[State.selectedCampIndex]
end

local function GetTornadoData(hero)
    local tornado = GetAbilityByName(hero, TORNADO_NAME)
    if not tornado then
        return nil
    end

    return {
        tornado = tornado,
        castRange = (Ability and Ability.GetCastRange and Ability.GetCastRange(tornado)) or 2000,
        castPoint = (Ability and Ability.GetCastPoint and Ability.GetCastPoint(tornado)) or 0.05,
        travelSpeed = GetAbilitySpecialValue(tornado, "travel_speed", 1000),
        radius = GetAbilitySpecialValue(tornado, "area_of_effect", 200),
    }
end

local function IsTornadoReady(hero, data)
    if not hero or not data or not data.tornado then
        return false
    end

    if GetAbilityLevel(data.tornado) <= 0 then
        return false
    end

    if AbilityHidden(data.tornado) then
        return false
    end

    if not AbilityActivated(data.tornado) then
        return false
    end

    return AbilityReady(hero, data.tornado)
end

local function GetTornadoCastPosition(heroPos, binding, data)
    if not heroPos or not binding or not binding.campPos then
        return nil
    end

    local dirX, dirY, dirLen = Normalize2D(heroPos, binding.campPos)
    if not dirX or dirLen <= 1 then
        return binding.campPos
    end

    local extend = math.max(320, (data and data.radius or 200) + 140)
    return Vector(
        VecX(binding.campPos) + (dirX * extend),
        VecY(binding.campPos) + (dirY * extend),
        VecZ(binding.campPos)
    )
end

local function GetCastStatus(hero, binding, data)
    local heroPos = Entity.GetAbsOrigin(hero)
    if not heroPos or not binding or not data then
        return nil
    end

    local castPos = GetTornadoCastPosition(heroPos, binding, data)
    if not castPos then
        return nil
    end

    local centerDistance = Distance2D(heroPos, binding.campPos)
    local contactDistance = math.max(0, centerDistance - math.max(0, data.radius or 0))
    local travelTime = data.travelSpeed > 0 and (contactDistance / data.travelSpeed) or 0
    local desiredLiftSecond = Clamp(STACK_LIFT_SECOND, MIN_STACK_LIFT_SECOND, MAX_STACK_LIFT_SECOND)
    local castSecond = desiredLiftSecond - data.castPoint - travelTime
    local castRangeOk = Distance2D(heroPos, castPos) <= (data.castRange + 10)

    return {
        castPos = castPos,
        castSecond = castSecond,
        castRangeOk = castRangeOk,
    }
end

local function DrawFilledRectCompat(pos, size, color, rounding)
    if not Render or not Render.FilledRect or not pos or not size or not color then
        return false
    end

    local endPos = Vec2(pos.x + size.x, pos.y + size.y)
    local ok = pcall(Render.FilledRect, pos, endPos, color, rounding or 0)
    if ok then
        return true
    end

    return pcall(Render.FilledRect, pos, size, color, rounding or 0)
end

local function DrawOutlineRectCompat(pos, size, color, rounding, thickness)
    if not Render or not pos or not size or not color then
        return false
    end

    local borderThickness = math.max(1, math.floor(thickness or 1))

    if Render.Rect then
        local endPos = Vec2(pos.x + size.x, pos.y + size.y)
        local ok = pcall(Render.Rect, pos, endPos, color, rounding or 0, nil, borderThickness)
        if ok then
            return true
        end

        if Enum and Enum.DrawFlags and Enum.DrawFlags.None ~= nil then
            ok = pcall(Render.Rect, pos, endPos, color, rounding or 0, Enum.DrawFlags.None, borderThickness)
            if ok then
                return true
            end
        end
    end

    if Render.OutlineRect then
        local ok = pcall(Render.OutlineRect, pos, size, color, rounding or 0, borderThickness)
        if ok then
            return true
        end
    end

    if not Render.FilledRect then
        return false
    end

    DrawFilledRectCompat(pos, Vec2(size.x, borderThickness), color, 0)
    DrawFilledRectCompat(Vec2(pos.x, pos.y + size.y - borderThickness), Vec2(size.x, borderThickness), color, 0)
    DrawFilledRectCompat(Vec2(pos.x, pos.y + borderThickness), Vec2(borderThickness, math.max(0, size.y - (borderThickness * 2))), color, 0)
    DrawFilledRectCompat(Vec2(pos.x + size.x - borderThickness, pos.y + borderThickness), Vec2(borderThickness, math.max(0, size.y - (borderThickness * 2))), color, 0)
    return true
end

local function DrawButton(buttonX, buttonY, color, outlineColor, label, selected)
    if not Render then
        return
    end

    local pos = Vec2(buttonX, buttonY)
    local size = Vec2(BUTTON_SIZE, BUTTON_SIZE)

    DrawFilledRectCompat(pos, size, color, 6)
    DrawOutlineRectCompat(pos, size, outlineColor, 6, 1)

    if State.icon then
        local imagePos = Vec2(buttonX + 4, buttonY + 4)
        local imageSize = Vec2(BUTTON_SIZE - 8, BUTTON_SIZE - 8)
        Render.Image(State.icon, imagePos, imageSize, Color(255, 255, 255, selected and 255 or 220), 4)
    end

    if State.fontSmall and label and label ~= "" then
        local tw, th = GetTextSize(State.fontSmall, label)
        local textX = buttonX + math.floor((BUTTON_SIZE - tw) * 0.5)
        local textY = buttonY + BUTTON_SIZE - th - 2
        Render.Text(State.fontSmall, Vec2(textX, textY), label, Color(255, 255, 255, 255))
    end
end

local function HandleCampButtons(hero)
    if not UI.Enabled:Get() or not UI.ShowButtons:Get() or not Input or not Input.IsKeyDownOnce then
        return
    end

    if Input.IsInputCaptured and Input.IsInputCaptured() then
        return
    end

    EnsureFonts()
    EnsureIcon()
    RefreshCampBindings(false)

    local heroPos = Entity.GetAbsOrigin(hero)
    if not heroPos then
        return
    end

    local justClicked = Input.IsKeyDownOnce(Enum.ButtonCode.KEY_MOUSE1)
    local buttonRange = UI.ButtonRange:Get()

    for _, binding in ipairs(State.campBindings) do
        if Distance2D(heroPos, binding.campPos) <= buttonRange then
            local anchor = Vector(VecX(binding.campPos), VecY(binding.campPos), VecZ(binding.campPos) + BUTTON_VISUAL_Z)
            local screenPos, visible = GetWorldToScreen(anchor)
            if visible and screenPos then
                local buttonX = math.floor((screenPos.x or 0) - BUTTON_SIZE * 0.5)
                local buttonY = math.floor((screenPos.y or 0) - BUTTON_SIZE * 0.5)
                local selected = binding.actualIndex == State.selectedCampIndex
                local typeLabel = CampTypeShort(binding.camp)
                local fill = selected and Color(34, 152, 98, 190) or Color(26, 49, 68, 180)
                local outline = selected and Color(129, 255, 185, 255) or Color(89, 166, 219, 235)

                DrawButton(buttonX, buttonY, fill, outline, typeLabel, selected)

                if justClicked and Input.IsCursorInRect(buttonX, buttonY, BUTTON_SIZE, BUTTON_SIZE) then
                    if State.selectedCampIndex == binding.actualIndex then
                        State.selectedCampIndex = nil
                    else
                        State.selectedCampIndex = binding.actualIndex
                    end
                    dbg("Selected camp button: " .. tostring(State.selectedCampIndex))
                    break
                end
            end
        end
    end
end

local function ResetState()
    State.lastCastTime = -100
    State.lastCastMinute = -1
end

function script.OnDraw()
    if not Engine or not Engine.IsInGame or not Engine.IsInGame() then
        return
    end

    local hero = GetLocalHero()
    if not hero or not UI.Enabled:Get() then
        return
    end

    HandleCampButtons(hero)
end

function script.OnUpdate()
    if not Engine or not Engine.IsInGame or not Engine.IsInGame() then
        return
    end

    local hero = GetLocalHero()
    if not hero or not Entity.IsAlive(hero) or not UI.Enabled:Get() then
        return
    end

    RefreshCampBindings(false)

    local binding = GetSelectedBinding()
    if not binding then
        return
    end

    local data = GetTornadoData(hero)
    if not data then
        return
    end

    local status = GetCastStatus(hero, binding, data)
    if not status or not status.castRangeOk then
        return
    end

    local now = GameRules.GetGameTime()
    local _, minute, second = GetMinuteState()
    if State.lastCastMinute == minute then
        return
    end

    if not IsTornadoReady(hero, data) then
        return
    end

    if second >= status.castSecond
        and second <= (status.castSecond + 0.22)
        and (now - State.lastCastTime) > CAST_ORDER_LOCK then
        if CastPosition(hero, data.tornado, status.castPos) then
            dbg("Cast tornado for air-stack timing")
            State.lastCastTime = now
            State.lastCastMinute = minute
        end
    end
end

function script.OnGameEnd()
    ResetState()
    State.campBindings = {}
    State.campBindingsByIndex = {}
    State.selectedCampIndex = nil
    State.lastCampRefresh = 0
end

return script
