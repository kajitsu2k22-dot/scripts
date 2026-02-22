local script       = {}

--#region Configuration
---@class ScriptConfig
local CONFIG       = {
  RUNE_DURATION = 90.0,
  FONT_SIZE = 18,
  FONT_WEIGHT = Enum.FontWeight.BOLD,
  RUNE_INVALID_ID = 4294967295,
  RUNE_EMPTY_ALT_ID = -1,
  SHADOW_OFFSET = 1,
  BG_PADDING = 4,
  BG_ROUNDING = 3,
  PROGRESS_BAR_HEIGHT = 3,
  PROGRESS_BAR_OFFSET = 2,
  BORDER_THICKNESS = 1,
  WARNING_SECONDS = 10,
  CIRCLE_RADIUS_EXTRA = 3,
  CIRCLE_SEGMENTS = 32,
  -- Glow effect settings
  GLOW_LAYERS = 3,
  GLOW_SPREAD = 2,
  -- Pulsing animation
  PULSE_SPEED = 8.0,
  PULSE_MIN_SCALE = 0.95,
  PULSE_MAX_SCALE = 1.05,
  -- Widget shadow
  SHADOW_SOFTNESS = 4
}

-- Rune type -> main color (whole widget tints to this).
local RUNE_COLORS  = {
  [0] = Color(70, 185, 255, 255),   -- Double Damage
  [1] = Color(255, 165, 50, 255),   -- Haste
  [2] = Color(160, 120, 255, 255),  -- Illusion
  [3] = Color(200, 90, 255, 255),   -- Invisibility
  [4] = Color(50, 230, 100, 255),   -- Regeneration
  [5] = Color(255, 210, 70, 255),   -- Bounty
  [6] = Color(40, 235, 255, 255),   -- Arcane
  [7] = Color(100, 215, 255, 255),  -- Water
  [8] = Color(80, 255, 200, 255),   -- XP
  [9] = Color(200, 210, 230, 255)   -- Shield
}

--- Returns rune-themed colors when auto: bg (tinted), border/text, shadow, progress track.
local function getRuneTheme(runeType, timeLeft, warningActive)
  if runeType == nil or not RUNE_COLORS[runeType] then return nil end
  local c = RUNE_COLORS[runeType]
  if warningActive then
    return {
      main = Color(255, 95, 95, 255),
      bg = Color(255, 60, 60, 55),
      shadow = Color(80, 20, 20, 220),
      track = Color(40, 10, 10, 140),
      glow = Color(255, 50, 50, 180)
    }
  end
  return {
    main = c,
    bg = Color(c.r, c.g, c.b, 52),
    shadow = Color(math.floor(c.r * 0.22), math.floor(c.g * 0.22), math.floor(c.b * 0.22), 230),
    track = Color(math.floor(c.r * 0.35), math.floor(c.g * 0.35), math.floor(c.b * 0.35), 130),
    glow = Color(c.r, c.g, c.b, 150)
  }
end

--- Calculate pulse scale based on time left
local function getPulseScale(timeLeft, pulseEnabled)
  if not pulseEnabled or timeLeft > 10 then return 1.0 end
  local pulsePhase = math.sin(GameRules.GetGameTime() * CONFIG.PULSE_SPEED)
  local t = math.max(0, math.min(1, (10 - timeLeft) / 10))
  local pulseAmount = (CONFIG.PULSE_MAX_SCALE - CONFIG.PULSE_MIN_SCALE) / 2
  return 1.0 + pulsePhase * pulseAmount * t
end

--- Draw gradient rectangle
local function drawGradientRect(topLeft, bottomRight, colorTop, colorBottom, rounding)
  local width = bottomRight.x - topLeft.x
  local height = bottomRight.y - topLeft.y
  local steps = 8
  local stepHeight = height / steps
  
  for i = 0, steps - 1 do
    local t1 = i / steps
    local t2 = (i + 1) / steps
    local r1 = colorTop.r + (colorBottom.r - colorTop.r) * t1
    local g1 = colorTop.g + (colorBottom.g - colorTop.g) * t1
    local b1 = colorTop.b + (colorBottom.b - colorTop.b) * t1
    local a1 = colorTop.a + (colorBottom.a - colorTop.a) * t1
    
    local y1 = topLeft.y + i * stepHeight
    local y2 = y1 + stepHeight
    
    Render.FilledRect(
      Vec2(topLeft.x, y1),
      Vec2(bottomRight.x, y2),
      Color(r1, g1, b1, a1),
      rounding
    )
  end
end

--- Draw glow effect around a center point
local function drawGlow(center, radius, color, segments)
  for i = 1, CONFIG.GLOW_LAYERS do
    local glowRadius = radius + i * CONFIG.GLOW_SPREAD
    local glowAlpha = color.a * (1 - i / (CONFIG.GLOW_LAYERS + 1))
    local glowColor = Color(color.r, color.g, color.b, glowAlpha)
    Render.Circle(center, glowRadius, glowColor, CONFIG.BORDER_THICKNESS * 2, nil, 1, nil, segments)
  end
end

--- Draw widget shadow
local function drawWidgetShadow(topLeft, bottomRight, color, rounding, isCircle, center, radius)
  if isCircle and center then
    for i = 1, CONFIG.SHADOW_SOFTNESS do
      local offset = i
      local shadowAlpha = color.a * (1 - i / (CONFIG.SHADOW_SOFTNESS + 1))
      local shadowColor = Color(color.r, color.g, color.b, shadowAlpha)
      Render.FilledCircle(
        Vec2(center.x + offset, center.y + offset),
        radius,
        shadowColor,
        nil,
        nil,
        CONFIG.CIRCLE_SEGMENTS
      )
    end
  else
    for i = 1, CONFIG.SHADOW_SOFTNESS do
      local offset = i
      local shadowAlpha = color.a * (1 - i / (CONFIG.SHADOW_SOFTNESS + 1))
      local shadowColor = Color(color.r, color.g, color.b, shadowAlpha)
      Render.FilledRect(
        Vec2(topLeft.x + offset, topLeft.y + offset),
        Vec2(bottomRight.x + offset, bottomRight.y + offset),
        shadowColor,
        rounding
      )
    end
  end
end

--- Draw improved ring progress with rounded ends and gap
local function drawRingProgress(center, radius, color, thickness, startAngle, percent, segments, gapAngle)
  gapAngle = gapAngle or 5
  
  if percent <= 0 then return end
  
  local totalAngle = 360 - gapAngle * 2
  local sweepAngle = totalAngle * percent
  
  if sweepAngle <= 0 then return end
  
  -- Draw main arc
  Render.Circle(center, radius, color, thickness, startAngle, sweepAngle / 360, nil, segments)
  
  -- Draw rounded end cap if needed
  if percent < 1 then
    local endAngleRad = math.rad(startAngle + sweepAngle)
    local endX = center.x + radius * math.cos(endAngleRad)
    local endY = center.y + radius * math.sin(endAngleRad)
    Render.FilledCircle(Vec2(endX, endY), thickness / 2, color, nil, nil, 8)
  end
end
--#endregion

--#region Menu
local menu         = Menu.Create("General", "Main", "Items Manager", "General", "General")
local enableSwitch = menu:Switch("Enable Rune Timer", true)
local gear         = enableSwitch:Gear("Settings")

---@class ScriptSettings
local settings     = {
  enable          = enableSwitch,
  gear            = gear,
  yOffset         = gear:Slider("Vertical Offset (Y)", -30, 30, 0, "%dpx"),
  xOffset         = gear:Slider("Horizontal Offset (X)", -30, 30, 0, "%dpx"),
  styleCircle     = gear:Switch("Circular style", false),
  styleMinimal    = gear:Switch("Minimalist style", false),
  autoRuneColor   = gear:Switch("Color by rune type", true),
  textColor       = gear:ColorPicker("Timer Color (if not auto)", Color(255, 220, 0, 255)),
  drawBg          = gear:Switch("Background behind text", true),
  gradientBg      = gear:Switch("Gradient background", true),
  bgColor         = gear:ColorPicker("Background Color Top", Color(0, 0, 0, 200)),
  bgColorBottom   = gear:ColorPicker("Background Color Bottom", Color(30, 30, 30, 220)),
  drawBorder      = gear:Switch("Border (rune color)", true),
  drawGlow        = gear:Switch("Glow effect", true),
  drawWidgetShadow = gear:Switch("Widget shadow", true),
  drawProgressBar = gear:Switch("Progress bar", true),
  progressGap     = gear:Slider("Progress ring gap", 0, 45, 10, "%d°"),
  warningLowTime  = gear:Switch("Warning when low", true),
  warningThreshold = gear:Slider("Warning threshold (seconds)", 3, 30, 10, "%ds"),
  pulseWarning    = gear:Switch("Pulse animation on warning", true),
  shadowColor     = gear:ColorPicker("Text shadow color", Color(0, 0, 0, 220)),
  widgetShadowColor = gear:ColorPicker("Widget shadow color", Color(0, 0, 0, 180))
}

-- Add icons and tooltips
settings.enable:Image("panorama/images/items/bottle_png.vtex_c")
settings.enable:ToolTip("Shows a 90-second expiration timer above your Bottle when it contains a rune.")

settings.yOffset:Icon("\u{f338}")
settings.yOffset:ToolTip("Vertical offset from the center of the Bottle slot.")

settings.xOffset:Icon("\u{f339}")
settings.xOffset:ToolTip("Horizontal offset from the center of the Bottle slot.")

settings.styleCircle:ToolTip("Off = square background and progress bar. On = circular background and ring progress.")

settings.styleMinimal:ToolTip("Minimalist style: only text with shadow, no background or borders.")

settings.autoRuneColor:ToolTip("Tint entire widget by rune type.")
settings.textColor:Icon("\u{f53f}")
settings.textColor:ToolTip("Timer color when \"Color by rune type\" is off.")

settings.drawBg:ToolTip("Draw a semi-transparent background behind the timer.")
settings.gradientBg:ToolTip("Use gradient instead of solid color for background.")
settings.bgColor:ToolTip("Top color of the background.")
settings.bgColorBottom:ToolTip("Bottom color of the background (for gradient).")

settings.drawBorder:ToolTip("Draw a thin border around the timer in the rune color.")
settings.drawGlow:ToolTip("Add external glow effect around the widget.")
settings.drawWidgetShadow:ToolTip("Add soft shadow under the entire widget.")

settings.drawProgressBar:ToolTip("Show a bar under the timer indicating remaining time.")
settings.progressGap:ToolTip("Gap angle for circular progress ring (0 = full circle).")

settings.warningLowTime:ToolTip("Enable red tint warning when time is low.")
settings.warningThreshold:ToolTip("Seconds remaining when warning activates.")
settings.pulseWarning:ToolTip("Animate pulsing effect when warning is active.")

settings.shadowColor:ToolTip("Color of the text outline/shadow.")
settings.widgetShadowColor:ToolTip("Color of the widget drop shadow.")
--#endregion

--#region State Management
---@class ScriptState
local state = {
  pickupTime = nil,
  bottleSlot = nil,
  runeType = nil,
  lastPanelPos = nil,
  fadeAlpha = 255
}

local function resetState()
  state.pickupTime = nil
  state.bottleSlot = nil
  state.runeType = nil
  state.lastPanelPos = nil
  state.fadeAlpha = 255
end
--#endregion

--#region Core Logic
local font = Render.LoadFont("Arial", CONFIG.FONT_SIZE, CONFIG.FONT_WEIGHT)
local inventoryPanel1 = Panorama.GetPanelByName("inventory_list", false)
local inventoryPanel2 = Panorama.GetPanelByName("inventory_list2", false)

script.OnUpdate = function()
  if not settings.enable:Get() or not Engine.IsInGame() then
    resetState()
    return
  end

  local hero = Heroes.GetLocal()
  if not hero then
    resetState()
    return
  end

  local bottle, slot = nil, nil
  for i = 0, 5 do
    local item = NPC.GetItemByIndex(hero, i)
    if item and Entity.GetUnitName(item) == "item_bottle" then
      bottle, slot = item, i
      break
    end
  end

  state.bottleSlot = slot

  if bottle then
    local runeType = Bottle.GetRuneType(bottle)
    if runeType ~= CONFIG.RUNE_INVALID_ID and runeType ~= CONFIG.RUNE_EMPTY_ALT_ID then
      state.runeType = runeType
      if not state.pickupTime then
        state.pickupTime = GameRules.GetGameTime()
        state.fadeAlpha = 0
      end
    else
      state.pickupTime = nil
      state.runeType = nil
    end
  else
    state.pickupTime = nil
    state.runeType = nil
  end
  
  -- Fade animation
  if state.pickupTime and state.fadeAlpha < 255 then
    state.fadeAlpha = math.min(255, state.fadeAlpha + 25)
  elseif not state.pickupTime and state.fadeAlpha > 0 then
    state.fadeAlpha = math.max(0, state.fadeAlpha - 25)
  end
end

script.OnDraw = function()
  if not settings.enable:Get() or not state.pickupTime or not state.bottleSlot then
    return
  end
  
  if state.fadeAlpha <= 0 then return end

  local elapsedTime = GameRules.GetGameTime() - state.pickupTime
  local timeLeft = CONFIG.RUNE_DURATION - elapsedTime

  if timeLeft <= 0 then
    state.pickupTime = nil
    return
  end

  local panel
  if state.bottleSlot <= 2 then
    panel = inventoryPanel1 and inventoryPanel1:GetChild(state.bottleSlot)
  else
    panel = inventoryPanel2 and inventoryPanel2:GetChild(state.bottleSlot - 3)
  end

  if not panel then return end

  local timerText = string.format("%.1f", timeLeft)
  local panelPos = panel:GetPositionWithinWindow()
  local panelWidth = panel:GetLayoutWidth()
  local textSize = Render.TextSize(font, CONFIG.FONT_SIZE, timerText)

  local pad = CONFIG.BG_PADDING
  local so = CONFIG.SHADOW_OFFSET
  local warningThreshold = settings.warningThreshold:Get()
  local warningActive = settings.warningLowTime:Get() and timeLeft <= warningThreshold and timeLeft > 0
  local pulseScale = getPulseScale(timeLeft, settings.pulseWarning:Get() and warningActive)

  -- Theme colors
  local theme = settings.autoRuneColor:Get() and getRuneTheme(state.runeType, timeLeft, warningActive)
  local textColor = theme and theme.main or settings.textColor:Get()
  local borderColor = textColor
  local shadowColor = theme and theme.shadow or settings.shadowColor:Get()
  local bgColorTop = theme and theme.bg or settings.bgColor:Get()
  local bgColorBottom = theme and theme.bg or settings.bgColorBottom:Get()
  local progressTrackColor = theme and theme.track or Color(0, 0, 0, 160)
  local progressFillColor = borderColor
  local glowColor = theme and theme.glow or Color(textColor.r, textColor.g, textColor.b, 150)
  local widgetShadowColor = settings.widgetShadowColor:Get()

  -- Apply fade animation
  textColor = Color(textColor.r, textColor.g, textColor.b, state.fadeAlpha)
  bgColorTop = Color(bgColorTop.r, bgColorTop.g, bgColorTop.b, bgColorTop.a * state.fadeAlpha / 255)
  bgColorBottom = Color(bgColorBottom.r, bgColorBottom.g, bgColorBottom.b, bgColorBottom.a * state.fadeAlpha / 255)
  glowColor = Color(glowColor.r, glowColor.g, glowColor.b, glowColor.a * state.fadeAlpha / 255)
  widgetShadowColor = Color(widgetShadowColor.r, widgetShadowColor.g, widgetShadowColor.b, widgetShadowColor.a * state.fadeAlpha / 255)

  -- Calculate position with offsets
  local baseCenterX = panelPos.x + panelWidth / 2 + settings.xOffset:Get()
  local baseCenterY = panelPos.y + panelWidth / 2 + settings.yOffset:Get()
  local centerX = baseCenterX
  local centerY = baseCenterY

  -- Apply pulse scale
  local scaledTextSizeX = textSize.x * pulseScale
  local scaledTextSizeY = textSize.y * pulseScale

  local isCircle = settings.styleCircle:Get()
  local isMinimal = settings.styleMinimal:Get()

  -- Drawing position for text
  local drawX = centerX - scaledTextSizeX / 2
  local drawY = centerY - scaledTextSizeY / 2

  -- Calculate bounding box for background/shadow
  local bgLeft, bgTop, bgRight, bgBottom
  if isCircle then
    local radius = math.max(scaledTextSizeX, scaledTextSizeY) / 2 + pad
    bgLeft = centerX - radius
    bgTop = centerY - radius
    bgRight = centerX + radius
    bgBottom = centerY + radius
  else
    if isMinimal then
      bgLeft, bgTop = drawX - pad, drawY - pad
      bgRight, bgBottom = drawX + scaledTextSizeX + pad, drawY + scaledTextSizeY + pad
    else
      bgLeft, bgTop = drawX - pad, drawY - pad
      bgRight, bgBottom = drawX + scaledTextSizeX + pad, drawY + scaledTextSizeY + pad
    end
  end

  local rounding = isMinimal and 0 or CONFIG.BG_ROUNDING

  -- Draw widget shadow
  if settings.drawWidgetShadow:Get() and not isMinimal then
    local shadowCenter = isCircle and Vec2(centerX, centerY) or nil
    drawWidgetShadow(
      Vec2(bgLeft, bgTop),
      Vec2(bgRight, bgBottom),
      widgetShadowColor,
      rounding,
      isCircle,
      shadowCenter,
      math.max(scaledTextSizeX, scaledTextSizeY) / 2 + pad
    )
  end

  -- Draw glow effect
  if settings.drawGlow:Get() and not isMinimal then
    local glowRadius = isCircle and (math.max(scaledTextSizeX, scaledTextSizeY) / 2 + pad) or
                       (math.max(bgRight - bgLeft, bgBottom - bgTop) / 2)
    local glowCenter = isCircle and Vec2(centerX, centerY) or Vec2((bgLeft + bgRight) / 2, (bgTop + bgBottom) / 2)
    drawGlow(glowCenter, glowRadius, glowColor, CONFIG.CIRCLE_SEGMENTS)
  end

  -- Draw background
  if settings.drawBg:Get() and not isMinimal then
    if settings.gradientBg:Get() and not isCircle then
      drawGradientRect(Vec2(bgLeft, bgTop), Vec2(bgRight, bgBottom), bgColorTop, bgColorBottom, rounding)
    else
      local bgColor = isCircle and bgColorTop or bgColorTop
      if isCircle then
        Render.FilledCircle(
          Vec2(centerX, centerY),
          math.max(scaledTextSizeX, scaledTextSizeY) / 2 + pad,
          bgColor,
          nil,
          nil,
          CONFIG.CIRCLE_SEGMENTS
        )
      else
        Render.FilledRect(Vec2(bgLeft, bgTop), Vec2(bgRight, bgBottom), bgColor, rounding)
      end
    end
  end

  -- Draw border
  if settings.drawBorder:Get() and not isMinimal then
    if isCircle then
      Render.Circle(
        Vec2(centerX, centerY),
        math.max(scaledTextSizeX, scaledTextSizeY) / 2 + pad,
        borderColor,
        CONFIG.BORDER_THICKNESS,
        nil,
        1,
        nil,
        CONFIG.CIRCLE_SEGMENTS
      )
    else
      Render.Rect(
        Vec2(bgLeft, bgTop),
        Vec2(bgRight, bgBottom),
        borderColor,
        rounding,
        nil,
        CONFIG.BORDER_THICKNESS
      )
    end
  end

  -- Draw progress bar/ring
  if settings.drawProgressBar:Get() and not isMinimal then
    local percent = math.max(0, timeLeft / CONFIG.RUNE_DURATION)

    if isCircle then
      local ringRadius = math.max(scaledTextSizeX, scaledTextSizeY) / 2 + pad + CONFIG.PROGRESS_BAR_OFFSET
      local ringThickness = 3
      local gapAngle = settings.progressGap:Get()

      -- Track
      Render.Circle(
        Vec2(centerX, centerY),
        ringRadius,
        progressTrackColor,
        ringThickness,
        nil,
        1,
        nil,
        CONFIG.CIRCLE_SEGMENTS
      )

      -- Fill with gap and rounded ends
      drawRingProgress(
        Vec2(centerX, centerY),
        ringRadius,
        progressFillColor,
        ringThickness,
        90,
        percent,
        CONFIG.CIRCLE_SEGMENTS,
        gapAngle
      )
    else
      local barY = bgBottom + CONFIG.PROGRESS_BAR_OFFSET
      local barEndY = barY + CONFIG.PROGRESS_BAR_HEIGHT
      local percent = math.max(0, timeLeft / CONFIG.RUNE_DURATION)
      
      -- Track
      Render.FilledRect(Vec2(bgLeft, barY), Vec2(bgRight, barEndY), progressTrackColor, rounding)
      -- Fill
      Render.RoundedProgressRect(Vec2(bgLeft, barY), Vec2(bgRight, barEndY), progressFillColor, percent, rounding)
    end
  end

  -- Draw text shadow
  Render.Text(font, CONFIG.FONT_SIZE, timerText, Vec2(drawX + so, drawY + so),
    Color(shadowColor.r, shadowColor.g, shadowColor.b, shadowColor.a * state.fadeAlpha / 255))
  -- Draw text
  Render.Text(font, CONFIG.FONT_SIZE, timerText, Vec2(drawX, drawY), textColor)
end
--#endregion

--#region Callbacks
script.OnGameEnd = function()
  resetState()
end
--#endregion

return script
