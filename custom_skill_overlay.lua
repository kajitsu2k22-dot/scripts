---@diagnostic disable: undefined-global, param-type-mismatch
local script = {}

local MENU = {}
local STATE = {
    fonts = {},
    images = {},
    hoverRadiusWidget = nil,
}

local GROUP_NAME = "Custom Skill Overlay"
local SHOW_ON_ITEMS = { "Enemies", "Allies" }
local ALIGN_ITEMS = { "Left", "Top", "Right", "Bottom", "At Origin" }
local SLOT_ORDER = {
    { key = "Q", index = 0, icon = "panorama/images/spellicons/queenofpain_shadow_strike_png.vtex_c" },
    { key = "W", index = 1, icon = "panorama/images/spellicons/windrunner_windrun_png.vtex_c" },
    { key = "E", index = 2, icon = "panorama/images/spellicons/ember_spirit_searing_chains_png.vtex_c" },
    { key = "R", index = 3, icon = "panorama/images/spellicons/rubick_spell_steal_png.vtex_c" },
    { key = "D", index = 4, icon = "panorama/images/spellicons/doom_bringer_doom_png.vtex_c" },
    { key = "F", index = 5, icon = "panorama/images/spellicons/faceless_void_time_walk_png.vtex_c" },
}

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function tryCall(fn, ...)
    if type(fn) ~= "function" then
        return false
    end

    return pcall(fn, ...)
end

local function safeStatic(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end

    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        return nil
    end

    return a, b, c, d
end

local function safeMethod(obj, methodName, ...)
    if not obj or not methodName then
        return nil
    end

    local okMethod, method = pcall(function()
        return obj[methodName]
    end)
    if not okMethod or type(method) ~= "function" then
        return nil
    end

    local ok, a, b, c, d = pcall(method, obj, ...)
    if not ok then
        return nil
    end

    return a, b, c, d
end

local function widgetGet(widget, item, defaultValue)
    if not widget or type(widget.Get) ~= "function" then
        return defaultValue
    end

    local ok, value = pcall(function()
        if item ~= nil then
            return widget:Get(item)
        end

        return widget:Get()
    end)

    if ok and value ~= nil then
        return value
    end

    return defaultValue
end

local function widgetDisable(widget, value)
    if widget and type(widget.Disabled) == "function" then
        pcall(widget.Disabled, widget, value)
    end
end

local function styleMenuWidget(widget, text, tooltip, icon, image)
    if not widget then
        return widget
    end

    if text and widget.ForceLocalization then
        pcall(widget.ForceLocalization, widget, text)
    end
    if image and widget.Image then
        pcall(widget.Image, widget, image)
    end
    if icon and widget.Icon then
        pcall(widget.Icon, widget, icon)
    end
    if tooltip and widget.ToolTip then
        pcall(widget.ToolTip, widget, tooltip)
    end

    return widget
end

local function addGearSection(gear, text, image)
    if not gear or not gear.Label then
        return nil
    end

    local label = gear:Label(text)
    if label and image and label.Image then
        pcall(label.Image, label, image)
    end

    return label
end

local function colorAlpha(color, alpha)
    if not color then
        return Color(255, 255, 255, clamp(alpha or 255, 0, 255))
    end

    return Color(
        color.r or 255,
        color.g or 255,
        color.b or 255,
        clamp(alpha or color.a or 255, 0, 255)
    )
end

local function getRoundFlags()
    if not Enum or not Enum.DrawFlags then
        return nil
    end

    return Enum.DrawFlags.RoundCornersAll
        or Enum.DrawFlags.ROUND_CORNERS_ALL
        or Enum.DrawFlags.None
        or Enum.DrawFlags.NONE
end

local function getFont(size)
    size = math.max(8, math.floor(size or 12))

    if STATE.fonts[size] ~= nil then
        return STATE.fonts[size] or nil
    end

    local flags = Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or nil
    local weight = Enum and Enum.FontWeight and Enum.FontWeight.NORMAL or 400

    local font = safeStatic(Render and Render.CreateFont, "Inter", size, weight, flags)
    if not font then
        font = safeStatic(Render and Render.LoadFont, "Inter", flags, 500)
    end

    STATE.fonts[size] = font or false
    return font
end

local function getTextSize(font, size, text)
    text = tostring(text or "")
    if text == "" then
        return { x = 0, y = size }
    end

    if not font then
        return { x = size * #text * 0.55, y = size }
    end

    local a, b = safeStatic(Render and Render.TextSize, font, size, text)
    if type(a) == "number" then
        return { x = a, y = b or size }
    end
    if type(a) == "table" or type(a) == "userdata" then
        return { x = a.x or 0, y = a.y or size }
    end

    a, b = safeStatic(Render and Render.GetTextSize, font, text)
    if type(a) == "number" then
        return { x = a, y = b or size }
    end
    if type(a) == "table" or type(a) == "userdata" then
        return { x = a.x or 0, y = a.y or size }
    end

    return { x = size * #text * 0.55, y = size }
end

local function drawText(text, x, y, size, color, centered)
    if not Render or not text or text == "" then
        return
    end

    local font = getFont(size)
    local posX = x
    local posY = y

    if centered then
        local textSize = getTextSize(font, size, text)
        posX = x - textSize.x * 0.5
        posY = y - textSize.y * 0.5
    end

    local shadowColor = Color(0, 0, 0, clamp((color and color.a or 255) * 0.7, 0, 255))

    if Render.TextShadow and tryCall(Render.TextShadow, font, size, text, Vec2(posX, posY), color, shadowColor, Vec2(1, 1)) then
        return
    end

    if Render.Text then
        tryCall(Render.Text, font, size, text, Vec2(posX + 1, posY + 1), shadowColor)
        if not tryCall(Render.Text, font, size, text, Vec2(posX, posY), color) then
            tryCall(Render.Text, font, Vec2(posX + 1, posY + 1), text, shadowColor)
            tryCall(Render.Text, font, Vec2(posX, posY), text, color)
        end
    end
end

local function drawFilledRect(p1, p2, color, rounding)
    if not Render or not Render.FilledRect then
        return
    end

    local flags = getRoundFlags()
    if tryCall(Render.FilledRect, p1, p2, color, rounding, flags) then
        return
    end

    local size = Vec2((p2.x or 0) - (p1.x or 0), (p2.y or 0) - (p1.y or 0))
    tryCall(Render.FilledRect, p1, size, color, rounding, flags)
end

local function drawOutlineRect(p1, p2, color, rounding, thickness)
    if not Render then
        return
    end

    local flags = getRoundFlags()
    if Render.Rect and tryCall(Render.Rect, p1, p2, color, rounding, flags, thickness or 1) then
        return
    end

    if Render.OutlineRect then
        local size = Vec2((p2.x or 0) - (p1.x or 0), (p2.y or 0) - (p1.y or 0))
        tryCall(Render.OutlineRect, p1, size, color, rounding, thickness or 1)
    end
end

local function drawShadow(p1, p2, blur, color, rounding)
    if not Render or not Render.Shadow then
        return
    end

    if tryCall(Render.Shadow, p1, p2, blur or 18, color, rounding or 0) then
        return
    end

    local size = Vec2((p2.x or 0) - (p1.x or 0), (p2.y or 0) - (p1.y or 0))
    tryCall(Render.Shadow, p1, size, blur or 18, color, rounding or 0)
end

local function drawImage(handle, pos, size, color, rounding)
    if not Render or not Render.Image or not handle then
        return false
    end

    local flags = getRoundFlags()
    return tryCall(Render.Image, handle, pos, size, color, rounding or 0, flags)
        or tryCall(Render.Image, handle, pos, size, color, rounding or 0)
end

local function worldToScreen(worldPos)
    local a, b, c = safeStatic(Render and Render.WorldToScreen, worldPos)
    if not a then
        return nil, false
    end

    if type(a) == "table" or type(a) == "userdata" then
        local x = a.x or a[1]
        local y = a.y or a[2]
        local visible = false

        if type(b) == "boolean" then
            visible = b
        elseif a.visible ~= nil then
            visible = a.visible == true
        end

        if x ~= nil and y ~= nil then
            return Vec2(x, y), visible
        end
    end

    if type(a) == "number" and type(b) == "number" then
        return Vec2(a, b), c == true
    end

    return nil, false
end

local function getCursorPos()
    if not Input or not Input.GetCursorPos then
        return nil, nil
    end

    local ok, x, y = pcall(Input.GetCursorPos)
    if not ok then
        return nil, nil
    end

    if type(x) == "table" or type(x) == "userdata" then
        return x.x, x.y
    end

    return x, y
end

local function isCursorNearRect(x, y, w, h, padding)
    padding = math.max(0, padding or 0)

    if Input and Input.IsCursorInRect then
        local inside = safeStatic(Input.IsCursorInRect, x - padding, y - padding, w + padding * 2, h + padding * 2)
        if inside ~= nil then
            return inside == true
        end
    end

    local cx, cy = getCursorPos()
    if not cx or not cy then
        return false
    end

    return cx >= (x - padding)
        and cx <= (x + w + padding)
        and cy >= (y - padding)
        and cy <= (y + h + padding)
end

local function getImage(path)
    if not path or path == "" or not Render or not Render.LoadImage then
        return nil
    end

    if STATE.images[path] ~= nil then
        return STATE.images[path] or nil
    end

    local handle = safeStatic(Render.LoadImage, path)
    STATE.images[path] = handle or false
    return handle
end

local function getAbilityIconPath(abilityName)
    return "panorama/images/spellicons/" .. tostring(abilityName) .. "_png.vtex_c"
end

local function findOrCreateGroup()
    local root = safeStatic(Menu and Menu.Find, "Info Screen", "Main", "Heroes Overlay", "Main")
    if root then
        local existing = safeMethod(root, "Find", GROUP_NAME)
        if existing then
            return existing
        end

        local created = safeMethod(root, "Create", GROUP_NAME)
        if created then
            return created
        end
    end

    return safeStatic(Menu and Menu.Create, "Info Screen", "Main", "Heroes Overlay", "Main", GROUP_NAME)
end

local function refreshMenuState()
    local enabled = widgetGet(MENU.Enable, nil, false)

    widgetDisable(MENU.Minified, not enabled)
    widgetDisable(MENU.VisibleSlots, not enabled)
    widgetDisable(MENU.ShowOn, not enabled)
    widgetDisable(MENU.Align, not enabled)
    widgetDisable(MENU.Size, not enabled)
    widgetDisable(MENU.Opacity, not enabled)
    widgetDisable(MENU.HoverOpacity, not enabled)
    widgetDisable(MENU.OffsetX, not enabled)
    widgetDisable(MENU.OffsetY, not enabled)
    widgetDisable(MENU.ShowPassive, not enabled)
    widgetDisable(MENU.ReadyColor, not enabled)
    widgetDisable(MENU.CooldownColor, not enabled)
    widgetDisable(MENU.NotLearnedColor, not enabled)
    widgetDisable(MENU.BackgroundColor, not enabled)
end

local function initMenu()
    local group = findOrCreateGroup()
    if not group then
        return
    end

    MENU.Enable = group:Switch("Enable", false)
    styleMenuWidget(
        MENU.Enable,
        "Enable",
        "Turns the custom skill overlay on or off.",
        nil,
        "panorama/images/spellicons/rubick_spell_steal_png.vtex_c"
    )

    MENU.Minified = group:Switch("Minified", false)
    styleMenuWidget(
        MENU.Minified,
        "Minified",
        "Compact mode: less text and cleaner status chips on skill icons.",
        "\u{f066}",
        nil
    )

    MENU.ShowOn = group:MultiCombo("Show On", SHOW_ON_ITEMS, { "Enemies" })
    styleMenuWidget(
        MENU.ShowOn,
        "Show On",
        "Choose whether the overlay should be shown on enemy heroes, allied heroes, or both.",
        "\u{f0c0}",
        nil
    )

    MENU.Align = group:Combo("Align", ALIGN_ITEMS, 3)
    styleMenuWidget(
        MENU.Align,
        "Align",
        "Where to anchor the overlay relative to the hero.",
        "\u{f5fd}",
        nil
    )

    local gear = MENU.Enable:Gear("Settings")
    addGearSection(gear, "Visible Slots", "panorama/images/spellicons/invoker_quas_png.vtex_c")
    local slotItems = {}
    for _, slot in ipairs(SLOT_ORDER) do
        slotItems[#slotItems + 1] = { slot.key, slot.icon, true }
    end
    MENU.VisibleSlots = gear:MultiSelect("Visible Slots", slotItems, true)
    styleMenuWidget(
        MENU.VisibleSlots,
        "Visible Slots",
        "Select which ability positions to show. Q/W/E/R/D/F match the hero's skill slots.",
        nil,
        "panorama/images/spellicons/invoker_invoke_png.vtex_c"
    )

    addGearSection(gear, "Behavior", "panorama/images/spellicons/zuus_heavenly_jump_png.vtex_c")
    MENU.ShowPassive = gear:Switch("Show Passive Skills", true)
    styleMenuWidget(
        MENU.ShowPassive,
        "Show Passive Skills",
        "Include passive or innate abilities when they occupy a selected slot.",
        "\u{f06e}",
        nil
    )

    addGearSection(gear, "Layout", "panorama/images/spellicons/kunkka_torrent_png.vtex_c")
    MENU.Size = gear:Slider("Size", 18, 64, 30, "%dpx")
    styleMenuWidget(MENU.Size, "Size", "Size of every skill cell in pixels.", "\u{f03e}", nil)
    MENU.Opacity = gear:Slider("Opacity", 10, 100, 100, "%d%%")
    styleMenuWidget(MENU.Opacity, "Opacity", "Default opacity of the overlay.", "\u{f043}", nil)
    MENU.HoverOpacity = gear:Slider("Hover Opacity", 0, 100, 40, "%d%%")
    styleMenuWidget(MENU.HoverOpacity, "Hover Opacity", "Opacity when the cursor is close to the overlay.", "\u{f245}", nil)
    MENU.OffsetX = gear:Slider("X", -120, 120, 4, "%d")
    styleMenuWidget(MENU.OffsetX, "X", "Horizontal offset relative to the selected align anchor.", "\u{f337}", nil)
    MENU.OffsetY = gear:Slider("Y", -120, 120, -7, "%d")
    styleMenuWidget(MENU.OffsetY, "Y", "Vertical offset relative to the selected align anchor.", "\u{f338}", nil)

    addGearSection(gear, "Colors", "panorama/images/spellicons/oracle_false_promise_png.vtex_c")
    MENU.ReadyColor = gear:ColorPicker("Ready Color", Color(50, 215, 110, 255))
    styleMenuWidget(MENU.ReadyColor, "Ready Color", "Border/status color for skills that are ready to cast.", nil, nil)
    MENU.CooldownColor = gear:ColorPicker("Cooldown Color", Color(255, 185, 70, 255))
    styleMenuWidget(MENU.CooldownColor, "Cooldown Color", "Border/status color for skills on cooldown.", nil, nil)
    MENU.NotLearnedColor = gear:ColorPicker("Not Learned Color", Color(150, 55, 55, 255))
    styleMenuWidget(MENU.NotLearnedColor, "Not Learned Color", "Border/status color for abilities that are still unlearned.", nil, nil)
    MENU.BackgroundColor = gear:ColorPicker("Background", Color(12, 12, 18, 220))
    styleMenuWidget(MENU.BackgroundColor, "Background", "Main background color of the overlay cells.", nil, nil)

    if MENU.Enable and MENU.Enable.SetCallback then
        MENU.Enable:SetCallback(refreshMenuState, true)
    else
        refreshMenuState()
    end
end

local function getHoverRadiusWidget()
    if STATE.hoverRadiusWidget ~= nil then
        return STATE.hoverRadiusWidget or nil
    end

    local widget = safeStatic(
        Menu and Menu.Find,
        "Info Screen", "Main", "Heroes Overlay", "Main", "Extra Settings", "OnHover Radius"
    )
    STATE.hoverRadiusWidget = widget or false
    return widget
end

local function getHoverPadding()
    local widget = getHoverRadiusWidget()
    return math.max(0, tonumber(widgetGet(widget, nil, 0)) or 0)
end

local function isHeroEntity(hero)
    local value = safeStatic(NPC and NPC.IsHero, hero)
    if value ~= nil then
        return value == true
    end

    value = safeMethod(hero, "IsHero")
    return value == true
end

local function isIllusion(hero)
    local value = safeStatic(NPC and NPC.IsIllusion, hero)
    if value ~= nil then
        return value == true
    end

    value = safeMethod(hero, "IsIllusion")
    return value == true
end

local function isTempestDouble(hero)
    local value = safeStatic(NPC and NPC.IsTempestDouble, hero)
    if value ~= nil then
        return value == true
    end

    value = safeMethod(hero, "IsTempestDouble")
    return value == true
end

local function isAlive(entity)
    local value = safeStatic(Entity and Entity.IsAlive, entity)
    if value ~= nil then
        return value == true
    end

    value = safeMethod(entity, "IsAlive")
    return value == true
end

local function isDormant(entity)
    local value = safeStatic(Entity and Entity.IsDormant, entity)
    if value ~= nil then
        return value == true
    end

    return false
end

local function isVisible(entity)
    local value = safeStatic(NPC and NPC.IsVisible, entity)
    if value ~= nil then
        return value == true
    end

    value = safeMethod(entity, "IsVisible")
    if value ~= nil then
        return value == true
    end

    return true
end

local function isSameTeam(entityA, entityB)
    local value = safeStatic(Entity and Entity.IsSameTeam, entityA, entityB)
    if value ~= nil then
        return value == true
    end

    value = safeMethod(entityA, "IsSameTeam", entityB)
    return value == true
end

local function getAbsOrigin(entity)
    return safeStatic(Entity and Entity.GetAbsOrigin, entity)
        or safeMethod(entity, "GetAbsOrigin")
end

local function getHealthBarOffset(entity)
    return safeStatic(NPC and NPC.GetHealthBarOffset, entity)
        or safeMethod(entity, "GetHealthBarOffset")
        or 120
end

local function getAbilityCount(hero)
    return safeStatic(NPC and NPC.GetAbilityCount, hero)
        or safeMethod(hero, "GetAbilityCount")
        or 0
end

local function getAbilityByIndex(hero, index)
    return safeStatic(NPC and NPC.GetAbilityByIndex, hero, index)
        or safeStatic(NPC and NPC.GetAbility, hero, index)
        or safeMethod(hero, "GetAbilityByIndex", index)
        or safeMethod(hero, "GetAbility", index)
end

local function getAbilityName(ability)
    return safeStatic(Ability and Ability.GetName, ability)
        or safeMethod(ability, "GetName")
end

local function getAbilityLevel(ability)
    return safeStatic(Ability and Ability.GetLevel, ability)
        or safeMethod(ability, "GetLevel")
        or 0
end

local function abilityIsHidden(ability)
    local value = safeStatic(Ability and Ability.IsHidden, ability)
    if value ~= nil then
        return value == true
    end

    value = safeMethod(ability, "IsHidden")
    return value == true
end

local function abilityIsPassive(ability)
    local value = safeStatic(Ability and Ability.IsPassive, ability)
    if value ~= nil then
        return value == true
    end

    value = safeMethod(ability, "IsPassive")
    return value == true
end

local function abilityGetCooldown(ability)
    return safeStatic(Ability and Ability.GetCooldown, ability)
        or safeMethod(ability, "GetCooldown")
        or 0
end

local function abilityIsCooldownReady(ability)
    local value = safeStatic(Ability and Ability.IsCooldownReady, ability)
    if value ~= nil then
        return value == true
    end

    value = safeMethod(ability, "IsCooldownReady")
    if value ~= nil then
        return value == true
    end

    return abilityGetCooldown(ability) <= 0
end

local function isValidAbilityName(name)
    if not name or name == "" then
        return false
    end

    if name == "attribute_bonus" then
        return false
    end

    if string.find(name, "special_bonus", 1, true) then
        return false
    end

    if string.find(name, "generic_hidden", 1, true) then
        return false
    end

    return true
end

local function shouldShowHero(localHero, hero)
    if not hero or hero == localHero then
        return false
    end

    if not isHeroEntity(hero) then
        return false
    end

    if not isAlive(hero) or isDormant(hero) or not isVisible(hero) then
        return false
    end

    if isIllusion(hero) or isTempestDouble(hero) then
        return false
    end

    if isSameTeam(localHero, hero) then
        return widgetGet(MENU.ShowOn, "Allies", false)
    end

    return widgetGet(MENU.ShowOn, "Enemies", true)
end

local function isSlotEnabled(slotKey)
    return widgetGet(MENU.VisibleSlots, slotKey, true)
end

local function collectSlotAbilities(hero)
    local result = {}
    local showPassive = widgetGet(MENU.ShowPassive, nil, true)

    for _, slot in ipairs(SLOT_ORDER) do
        if isSlotEnabled(slot.key) then
            local ability = getAbilityByIndex(hero, slot.index)
            if ability then
                local name = getAbilityName(ability)
                if isValidAbilityName(name) and not abilityIsHidden(ability) then
                    if showPassive or not abilityIsPassive(ability) then
                        result[#result + 1] = {
                            slot = slot.key,
                            index = slot.index,
                            ability = ability,
                        }
                    end
                end
            end
        end
    end

    return result
end

local function formatCooldown(value)
    value = math.max(0, tonumber(value) or 0)
    if value >= 10 then
        return string.format("%.0f", value)
    end

    return string.format("%.1f", value)
end

local function buildEntries(hero)
    local entries = {}
    local readyColor = widgetGet(MENU.ReadyColor, nil, Color(50, 215, 110, 255))
    local cooldownColor = widgetGet(MENU.CooldownColor, nil, Color(255, 185, 70, 255))
    local notLearnedColor = widgetGet(MENU.NotLearnedColor, nil, Color(150, 55, 55, 255))
    local minified = widgetGet(MENU.Minified, nil, false)

    for _, slotInfo in ipairs(collectSlotAbilities(hero)) do
        local ability = slotInfo.ability
        local level = tonumber(getAbilityLevel(ability)) or 0
        local learned = level > 0
        local passive = abilityIsPassive(ability)
        local cooldown = learned and math.max(0, tonumber(abilityGetCooldown(ability)) or 0) or 0
        local name = getAbilityName(ability)
        local text = ""
        local color = readyColor
        local state = "ready"

        if not learned then
            state = "not_learned"
            color = notLearnedColor
            text = minified and "" or "LOCK"
        elseif passive then
            state = "passive"
            color = readyColor
            text = minified and "P" or "PASS"
        elseif cooldown > 0.05 then
            state = "cooldown"
            color = cooldownColor
            text = formatCooldown(cooldown)
        elseif abilityIsCooldownReady(ability) then
            state = "ready"
            color = readyColor
            text = minified and "" or "READY"
        else
            state = "cooldown"
            color = cooldownColor
            text = formatCooldown(cooldown)
        end

        entries[#entries + 1] = {
            slot = slotInfo.slot,
            image = getImage(getAbilityIconPath(name)),
            text = text,
            color = color,
            learned = learned,
            state = state,
        }
    end

    return entries
end

local function getPanelPosition(hero, panelWidth, panelHeight)
    local align = tonumber(widgetGet(MENU.Align, nil, 3)) or 3
    local offsetX = tonumber(widgetGet(MENU.OffsetX, nil, 4)) or 0
    local offsetY = tonumber(widgetGet(MENU.OffsetY, nil, -7)) or 0
    local origin = getAbsOrigin(hero)
    if not origin then
        return nil
    end

    local healthBarOffset = tonumber(getHealthBarOffset(hero)) or 120
    local anchorWorld = origin + Vector(0, 0, healthBarOffset + 30)
    local baseScreen, visible = worldToScreen(anchorWorld)
    if not visible or not baseScreen then
        return nil
    end

    local originScreen = nil
    if align == 4 then
        originScreen = select(1, worldToScreen(origin))
    end

    local margin = math.max(8, math.floor(panelHeight * 0.35))
    local x = baseScreen.x - panelWidth * 0.5
    local y = baseScreen.y + margin

    if align == 0 then
        x = baseScreen.x - panelWidth - margin
        y = baseScreen.y - panelHeight * 0.5
    elseif align == 1 then
        x = baseScreen.x - panelWidth * 0.5
        y = baseScreen.y - panelHeight - margin
    elseif align == 2 then
        x = baseScreen.x + margin
        y = baseScreen.y - panelHeight * 0.5
    elseif align == 3 then
        x = baseScreen.x - panelWidth * 0.5
        y = baseScreen.y + margin
    elseif align == 4 and originScreen then
        x = originScreen.x - panelWidth * 0.5
        y = originScreen.y - panelHeight * 0.5
    end

    return Vec2(x + offsetX, y + offsetY)
end

local function drawEntryCell(x, y, size, entry, alpha, minified)
    local rounding = math.max(3, math.floor(size * 0.18))
    local bg = widgetGet(MENU.BackgroundColor, nil, Color(12, 12, 18, 220))
    local boxStart = Vec2(x, y)
    local boxEnd = Vec2(x + size, y + size)

    drawFilledRect(boxStart, boxEnd, colorAlpha(bg, math.floor(alpha * 0.9)), rounding)
    drawOutlineRect(boxStart, boxEnd, colorAlpha(entry.color, alpha), rounding, 1)

    local slotPad = math.max(3, math.floor(size * 0.08))
    local slotSize = math.max(10, math.floor(size * 0.28))
    local slotStart = Vec2(x + slotPad, y + slotPad)
    local slotEnd = Vec2(slotStart.x + slotSize, slotStart.y + slotSize)
    drawFilledRect(slotStart, slotEnd, Color(0, 0, 0, math.floor(alpha * 0.72)), math.max(2, math.floor(rounding * 0.6)))
    drawText(entry.slot, slotStart.x + slotSize * 0.5, slotStart.y + slotSize * 0.45, math.max(8, math.floor(slotSize * 0.72)), Color(255, 255, 255, alpha), true)

    local pad = math.max(2, math.floor(size * 0.08))
    local iconPos = Vec2(x + pad, y + pad)
    local iconSize = Vec2(size - pad * 2, size - pad * 2)
    local iconAlpha = entry.learned and alpha or math.floor(alpha * 0.45)

    if entry.image then
        drawImage(entry.image, iconPos, iconSize, Color(255, 255, 255, iconAlpha), math.max(2, rounding - 2))
    else
        local fallback = entry.learned and entry.slot or "?"
        drawText(fallback, x + size * 0.5, y + size * 0.48, math.max(10, math.floor(size * 0.45)), Color(255, 255, 255, iconAlpha), true)
    end

    if entry.state == "ready" and minified and entry.text == "" then
        local dotRadius = math.max(2, math.floor(size * 0.09))
        local center = Vec2(x + size - dotRadius - 4, y + dotRadius + 4)
        if Render and Render.FilledCircle then
            tryCall(Render.FilledCircle, center, dotRadius, colorAlpha(entry.color, alpha), 16)
        end
        return
    end

    if entry.text ~= "" then
        local badgeHeight = math.max(10, math.floor(size * 0.34))
        local badgeStart = Vec2(x, y + size - badgeHeight)
        drawFilledRect(badgeStart, boxEnd, Color(0, 0, 0, math.floor(alpha * 0.72)), math.max(1, rounding - 2))

        local fontSize = math.max(8, math.floor(size * (minified and 0.28 or 0.26)))
        local textSize = getTextSize(getFont(fontSize), fontSize, entry.text)
        local textX = x + (size - textSize.x) * 0.5
        local textY = y + size - badgeHeight + (badgeHeight - textSize.y) * 0.5 - 1
        drawText(entry.text, textX, textY, fontSize, Color(255, 255, 255, alpha), false)
    end
end

local function drawPanelBackground(panelPos, panelWidth, panelHeight, alpha)
    local pad = math.max(4, math.floor(panelHeight * 0.14))
    local rounding = math.max(6, math.floor(panelHeight * 0.28))
    local bg = widgetGet(MENU.BackgroundColor, nil, Color(12, 12, 18, 220))
    local startPos = Vec2(panelPos.x - pad, panelPos.y - pad)
    local endPos = Vec2(panelPos.x + panelWidth + pad, panelPos.y + panelHeight + pad)
    local panelColor = colorAlpha(bg, math.floor(alpha * 0.62))

    drawShadow(startPos, endPos, math.max(14, math.floor(panelHeight * 0.8)), Color(0, 0, 0, math.floor(alpha * 0.35)), rounding)
    drawFilledRect(startPos, endPos, panelColor, rounding)
    drawOutlineRect(startPos, endPos, Color(255, 255, 255, math.floor(alpha * 0.08)), rounding, 1)
end

function script.OnDraw()
    if not Engine or not Engine.IsInGame or not Engine.IsInGame() then
        return
    end

    if Menu and Menu.VisualsIsEnabled and Menu.VisualsIsEnabled() == false then
        return
    end

    if not widgetGet(MENU.Enable, nil, false) then
        return
    end

    local localHero = Heroes and Heroes.GetLocal and Heroes.GetLocal() or nil
    if not localHero or not isAlive(localHero) then
        return
    end

    local heroes = Heroes and Heroes.GetAll and Heroes.GetAll() or {}
    if not heroes then
        return
    end

    local size = clamp(tonumber(widgetGet(MENU.Size, nil, 30)) or 30, 18, 64)
    local minified = widgetGet(MENU.Minified, nil, false)
    local gap = math.max(3, math.floor(size * 0.12))
    local hoverPadding = getHoverPadding()

    for _, hero in ipairs(heroes) do
        if shouldShowHero(localHero, hero) then
            local entries = buildEntries(hero)
            if #entries > 0 then
                local panelWidth = (#entries * size) + (math.max(0, #entries - 1) * gap)
                local panelHeight = size
                local panelPos = getPanelPosition(hero, panelWidth, panelHeight)

                if panelPos then
                    local hovered = isCursorNearRect(panelPos.x, panelPos.y, panelWidth, panelHeight, hoverPadding)
                    local opacityPercent = hovered
                        and widgetGet(MENU.HoverOpacity, nil, 40)
                        or widgetGet(MENU.Opacity, nil, 100)
                    local alpha = clamp(math.floor((tonumber(opacityPercent) or 100) * 2.55), 0, 255)

                    drawPanelBackground(panelPos, panelWidth, panelHeight, alpha)

                    for index, entry in ipairs(entries) do
                        local cellX = panelPos.x + (index - 1) * (size + gap)
                        drawEntryCell(cellX, panelPos.y, size, entry, alpha, minified)
                    end
                end
            end
        end
    end
end

function script.OnGameEnd()
    STATE.images = {}
end

initMenu()

return script
