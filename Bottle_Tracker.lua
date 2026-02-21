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
  CIRCLE_SEGMENTS = 32
}

-- Rune type -> main color (whole widget tints to this). Tuned for clarity and preference (e.g. DD = blue).
-- Enum.RuneType: 0=DoubleDamage, 1=Haste, 2=Illusion, 3=Invisibility, 4=Regen, 5=Bounty, 6=Arcane, 7=Water, 8=XP, 9=Shield
local RUNE_COLORS  = {
  [0] = Color(70, 185, 255, 255),   -- Double Damage (cool blue)
  [1] = Color(255, 165, 50, 255),   -- Haste (warm orange)
  [2] = Color(160, 120, 255, 255),  -- Illusion (soft violet)
  [3] = Color(200, 90, 255, 255),   -- Invisibility (purple)
  [4] = Color(50, 230, 100, 255),   -- Regeneration (green)
  [5] = Color(255, 210, 70, 255),   -- Bounty (gold)
  [6] = Color(40, 235, 255, 255),   -- Arcane (bright cyan)
  [7] = Color(100, 215, 255, 255),  -- Water (light blue)
  [8] = Color(80, 255, 200, 255),   -- XP (mint)
  [9] = Color(200, 210, 230, 255)  -- Shield (silver-blue)
}

--- Returns rune-themed colors when auto: bg (tinted), border/text, shadow, progress track. Else nil.
local function getRuneTheme(runeType, timeLeft, warningActive)
  if runeType == nil or not RUNE_COLORS[runeType] then return nil end
  local c = RUNE_COLORS[runeType]
  if warningActive then
    return {
      main = Color(255, 95, 95, 255),
      bg = Color(255, 60, 60, 55),
      shadow = Color(80, 20, 20, 220),
      track = Color(40, 10, 10, 140)
    }
  end
  return {
    main = c,
    bg = Color(c.r, c.g, c.b, 52),
    shadow = Color(math.floor(c.r * 0.22), math.floor(c.g * 0.22), math.floor(c.b * 0.22), 230),
    track = Color(math.floor(c.r * 0.35), math.floor(c.g * 0.35), math.floor(c.b * 0.35), 130)
  }
end
--#endregion

--#region Menu
local menu         = Menu.Create("General", "Main", "Items Manager", "General", "General")
local enableSwitch = menu:Switch("Enable Rune Timer", true)
local gear         = enableSwitch:Gear("Settings")

---@class ScriptSettings
local settings     = {
  enable     = enableSwitch,
  gear       = gear,
  yOffset    = gear:Slider("Vertical Offset (Y)", -30, 30, 0, "%dpx"),
  styleCircle = gear:Switch("Circular style", false),
  autoRuneColor = gear:Switch("Color by rune type", true),
  textColor    = gear:ColorPicker("Timer Color (if not auto)", Color(255, 220, 0, 255)),
  drawBg         = gear:Switch("Background behind text", true),
  bgColor        = gear:ColorPicker("Background Color", Color(0, 0, 0, 200)),
  drawBorder     = gear:Switch("Border (rune color)", true),
  drawProgressBar = gear:Switch("Progress bar", true),
  warningLowTime = gear:Switch("Warning when low", true),
  warningThreshold = gear:Slider("Warning threshold (seconds)", 3, 30, 10, "%ds"),
  shadowColor    = gear:ColorPicker("Text shadow color", Color(0, 0, 0, 220))
}
-- Add icons and tooltips
settings.enable:Image("panorama/images/items/bottle_png.vtex_c")
settings.enable:ToolTip("Shows a 90-second expiration timer above your Bottle when it contains a rune.")

settings.yOffset:Icon("\u{f338}")
settings.yOffset:ToolTip("Vertical offset from the center of the Bottle slot. 0 = centered.")

settings.styleCircle:ToolTip("Off = square background and progress bar. On = circular background and ring progress.")

settings.autoRuneColor:ToolTip("Tint entire widget by rune: text, background, border and progress bar (e.g. Double Damage=blue).")
settings.textColor:Icon("\u{f53f}")
settings.textColor:ToolTip("Timer color when \"Color by rune type\" is off.")

settings.drawBg:ToolTip("Draw a semi-transparent background behind the timer for better visibility.")
settings.bgColor:ToolTip("Color of the background rectangle.")
settings.drawBorder:ToolTip("Draw a thin border around the timer in the rune color.")
settings.drawProgressBar:ToolTip("Show a bar under the timer indicating remaining time.")
settings.warningLowTime:ToolTip("Enable red tint warning when time is low.")
settings.warningThreshold:ToolTip("Seconds remaining when warning activates (red tint).")
settings.shadowColor:ToolTip("Color of the text outline/shadow. Improves readability on any background.")

--#endregion

--#region State Management
---@class ScriptState
local state = {
  pickupTime = nil, ---@type number|nil
  bottleSlot = nil, ---@type number|nil
  runeType = nil ---@type number|nil (Enum.RuneType when bottle has rune)
}

--- Resets the script's state variables to their default values.
local function resetState()
  state.pickupTime = nil
  state.bottleSlot = nil
  state.runeType = nil
end
--#endregion

--#region Core Logic
local font = Render.LoadFont("Arial", CONFIG.FONT_SIZE, CONFIG.FONT_WEIGHT)
local inventoryPanel1 = Panorama.GetPanelByName("inventory_list", false)
local inventoryPanel2 = Panorama.GetPanelByName("inventory_list2", false)

--- Finds the bottle and its rune status, updating the script's state.
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
      end
    else
      state.pickupTime = nil
      state.runeType = nil
    end
  else
    state.pickupTime = nil
    state.runeType = nil
  end
end

--- Handles drawing the timer text on the screen.
script.OnDraw = function()
  if not settings.enable:Get() or not state.pickupTime or not state.bottleSlot then
    return
  end

  local elapsedTime = GameRules.GetGameTime() - state.pickupTime
  local timeLeft = CONFIG.RUNE_DURATION - elapsedTime

  if timeLeft <= 0 then
    state.pickupTime = nil
    return
  end

  -- Determine which inventory panel the bottle is in
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

  -- Theme: full rune tint (bg, border, text, shadow, progress) or manual colors
  local theme = settings.autoRuneColor:Get() and getRuneTheme(state.runeType, timeLeft, warningActive)
  local textColor = theme and theme.main or settings.textColor:Get()
  local borderColor = textColor
  local shadowColor = theme and theme.shadow or settings.shadowColor:Get()
  local bgColor = theme and theme.bg or settings.bgColor:Get()
  local progressTrackColor = theme and theme.track or Color(0, 0, 0, 160)
  local progressFillColor = borderColor

  local centerX = panelPos.x + panelWidth / 2
  local centerY = panelPos.y + panelWidth / 2 + settings.yOffset:Get()
  local drawX = centerX - textSize.x / 2
  local drawY = centerY - textSize.y / 2

  local isCircle = settings.styleCircle:Get()

  if isCircle then
    -- Circular style: circle background, ring progress, circle border
    local radius = math.max(textSize.x, textSize.y) / 2 + pad + CONFIG.CIRCLE_RADIUS_EXTRA
    local center = Vec2(centerX, centerY)
    local percent = math.max(0, timeLeft / CONFIG.RUNE_DURATION)

    if settings.drawBg:Get() then
      Render.FilledCircle(center, radius, bgColor, nil, nil, CONFIG.CIRCLE_SEGMENTS)
    end

    if settings.drawProgressBar:Get() then
      local ringThickness = 2.5
      Render.Circle(center, radius, progressTrackColor, ringThickness, nil, 1, nil, CONFIG.CIRCLE_SEGMENTS)
      Render.Circle(center, radius, progressFillColor, ringThickness, 90, percent, nil, CONFIG.CIRCLE_SEGMENTS)
    end

    if settings.drawBorder:Get() then
      Render.Circle(center, radius, borderColor, CONFIG.BORDER_THICKNESS, nil, 1, nil, CONFIG.CIRCLE_SEGMENTS)
    end
  else
    -- Square style: rectangular background and progress bar, sharp corners
    local rounding = 0
    local bgLeft = drawX - pad
    local bgTop = drawY - pad
    local bgRight = drawX + textSize.x + pad
    local bgBottom = drawY + textSize.y + pad

    if settings.drawBg:Get() then
      Render.FilledRect(Vec2(bgLeft, bgTop), Vec2(bgRight, bgBottom), bgColor, rounding)
    end

    if settings.drawProgressBar:Get() then
      local barY = bgBottom + CONFIG.PROGRESS_BAR_OFFSET
      local barEndY = barY + CONFIG.PROGRESS_BAR_HEIGHT
      local percent = math.max(0, timeLeft / CONFIG.RUNE_DURATION)
      Render.FilledRect(Vec2(bgLeft, barY), Vec2(bgRight, barEndY), progressTrackColor, rounding)
      Render.RoundedProgressRect(Vec2(bgLeft, barY), Vec2(bgRight, barEndY), progressFillColor, percent, rounding)
    end

    if settings.drawBorder:Get() then
      Render.Rect(Vec2(bgLeft, bgTop), Vec2(bgRight, bgBottom), borderColor, rounding, nil, CONFIG.BORDER_THICKNESS)
    end
  end

  Render.Text(font, CONFIG.FONT_SIZE, timerText, Vec2(drawX + so, drawY + so), shadowColor)
  Render.Text(font, CONFIG.FONT_SIZE, timerText, Vec2(drawX, drawY), textColor)
end
--#endregion

--#region Callbacks
script.OnGameEnd = function()
  resetState()
end
--#endregion

return script
