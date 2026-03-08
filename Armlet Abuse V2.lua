local script                         = {}

local C = {
  LONG_CP_THRESHOLD = 0.6, ARMLET_HP_SHIFT = 0.6, THRESHOLD_PANIC_DELTA = 60, THRESHOLD_PANIC_DELTA_DOT = 45,
  MAX_DEFERRAL_AFTER_THRESHOLD = 0.25, MAX_DEFERRAL_WHEN_DOT = 0.18, CRITICAL_HP_ABSOLUTE = 220, CRITICAL_HP_BELOW_SLIDER = 55,
  MIN_POST_HIT_SCHEDULE = 0.02, ATTACK_CLUSTER_EPS = 0.03,
  FALLBACK_MIN_PROJ_SPEED = 600, FALLBACK_MAX_PROJ_SPEED = 2000, PREDICT_ATTACK_MAX_PER_SOURCE = 3,
  PREDICT_ATTACK_MIN_INTERVAL = 0.28, PREDICT_ATTACK_MAX_INTERVAL = 2.40, TIMING_MAX_EXTRA_LEAD = 0.065,
  TUNED_SAFETY_BUFFER = 46, TUNED_HERO_AGGRESSION = 0.92, TUNED_HERO_THREAT_WINDOW = 0.96,
  TUNED_PRE_DISABLE_LEAD = 0.12, TUNED_PRE_DISABLE_LEAD_PRO = 0.08, TUNED_FOCUS_EXTRA_BUFFER = 16, TUNED_DISABLE_CHAIN_GAP = 0.56,
  TUNED_UNCERTAINTY_CAP = 34, TUNED_EXECUTION_MARGIN = 26,
  PRO_REACTION_MS = 50,
  PRE_LEAD_FLOOR_PRO = 0.020, SHIFT_FUDGE_MIN_PRO = 0.06, SHIFT_FUDGE_MIN = 0.10,
  LETHAL_WINDOW_NORMAL = 0.08, LETHAL_WINDOW_CRITICAL = 0.12, LETHAL_WINDOW_PRO_NORMAL = 0.04, LETHAL_WINDOW_PRO_CRITICAL = 0.06,
  PANIC_DELTA_PRO = 40, PANIC_DELTA_DOT_PRO = 32, SAFE_BUF_EARLY_MIN_PRO = 8, SAFE_BUF_EARLY_MIN = 12,
  LETHAL_ETA_MARGIN = 0.01, LETHAL_ETA_MARGIN_PRO = 0.005, PLAN_STEP_PRO = 0.01, PLAN_STEP_MIN = 0.012,
  HUSKAR_HP_RESERVE = 120,
}

local function setIconSafe(widget, icon, offset)
  if widget and widget.Icon then
    if offset ~= nil then
      pcall(widget.Icon, widget, icon, offset)
    else
      pcall(widget.Icon, widget, icon)
    end
  end
end
local function setToolTipSafe(widget, text)
  if widget and widget.ToolTip then
    pcall(widget.ToolTip, widget, text)
  end
end

local multiSelectItems               = {
  { "item_magic_stick",     "panorama/images/items/magic_stick_png.vtex_c",     true },
  { "item_magic_wand",      "panorama/images/items/magic_wand_png.vtex_c",      true },
  { "item_faerie_fire",     "panorama/images/items/faerie_fire_png.vtex_c",     true },
  { "item_famango",         "panorama/images/items/famango_png.vtex_c",         true },
  { "item_great_famango",   "panorama/images/items/great_famango_png.vtex_c",   true },
  { "item_greater_famango", "panorama/images/items/greater_famango_png.vtex_c", true }
}

local DEFAULT_REACTION_MS, DEFAULT_TOGGLE_MS = 55, 25
local DEBUG_LOG_ITEMS               = { "Off", "State", "Verbose" }
local DEBUG_LOG_OFF, DEBUG_LOG_STATE, DEBUG_LOG_VERBOSE = 0, 1, 2

local MENU                         = {
  root = nil,
  mainTab = nil,
  coreSettings = nil,
  timingSettings = nil,
  threatSettings = nil,
  consumableSettings = nil,
  overlaySettings = nil,
  debugSettings = nil,
  groupLeft = Enum and Enum.GroupSide and (Enum.GroupSide.LEFT or Enum.GroupSide.Left) or nil,
  groupRight = Enum and Enum.GroupSide and (Enum.GroupSide.RIGHT or Enum.GroupSide.Right) or nil,
  menuInitialized = false
}

local Switch                       = { Get = function() return true end }
local riskyAbuseSwitch             = { Get = function() return false end }
local hpSlider                     = { Get = function() return 340 end }
local Overlay                      = { Get = function() return true end }
local OverlayDetails               = { Get = function() return true end }
local OverlayTimeline              = { Get = function() return true end }
local consumableSwitch             = { Get = function() return true end }
local consumableSelect             = nil
local trackTowers                  = { Get = function() return true end }
local trackCreeps                  = { Get = function() return true end }
local trackNeutrals                = { Get = function() return true end }
local reactionTimeMs               = { Get = function() return DEFAULT_REACTION_MS end }
local toggleCooldownMs             = { Get = function() return DEFAULT_TOGGLE_MS end }
local adaptiveTimingSwitch         = { Get = function() return true end }
local disableGuardSwitch           = { Get = function() return true end }
local heroBurstGuardSwitch         = { Get = function() return true end }
local debugLogLevel                = { Get = function() return DEBUG_LOG_STATE end }

local hero                         = nil
local Armlet                       = nil
local STATE                        = {
  lastToggle = 0,
  armOnSince = 0,
  prevArmState = nil,
  thresholdSince = nil,
  toggledThisFrame = false
}
local THREAT                       = {
  incomingProjectiles = {},
  dotStates = {},
  castWindups = {},
  incomingControls = {},
  latencyState = { ewma = 0.05, jitter = 0.0, initialized = false },
  lastHeroThreat = {
    attackers = 0,
    burst = 0,
    soon = 0,
    dotSoon = 0,
    sustained = 0,
    pressure = 0,
    dotCount = 0,
    firstHitDmg = 0,
    heavyHit = 0,
    ts = 0
  },
  lastControlThreat = { count = 0, firstAt = nil, severity = 0, name = "", chainCount = 0, chainLock = 0, ts = 0 },
  lastFocusState = { active = false, score = 0, ts = 0 },
  lastUncertaintyState = { bonus = 0, fallback = 0, damage = 0, jitter = 0, ts = 0 },
  lastExecutionThreat = { count = 0, soon = 0, lethalSoon = false, firstAt = nil, name = "", ts = 0 },
  lastRiskState = { score = 0, mode = "normal", thresholdBias = 0, ts = 0 },
  lastEventPulse = {
    leadBonus = 0,
    soonHits = 0,
    soonDmg = 0,
    dotTicks = 0,
    attackEvents = 0,
    predicted = 0,
    cadenceSources = 0,
    fastestCadence = nil,
    srcCadence = {},
    ts = 0
  },
  lastHadActiveDot = false,
  counter = { projAttacks = 0, fbAttacks = 0, projAbility = 0, fbAbility = 0, melee = 0 }
}
local PLAN                         = {
  decisionTraceLog = {},
  lastPulseDebugAt = 0,
  lastLogLineAt = {},
  lastPulseLogState = { soonHits = -1, predicted = -1, cadenceBucket = -1 },
  lastReasonByGroup = {},
  config = {
    REPLACE_EARLIER_SEC = 0.025,
    REPLACE_MARGIN_HP = 20,
    CANCEL_COOLDOWN_SEC = 0.20,
    SUPPRESS_AFTER_CANCEL_SEC = 0.30,
    THRESHOLD_EXIT_HP = 35,
    PLAN_CANCEL_HP = 45,
    REALLY_LOW_HP = 25,
    PLAN_MIN_HOLD_SEC = 0.12,
    PLAN_EXPIRE_PAD_SEC = 0.40
  },
  thresholdEpisode = {
    active = false,
    id = 0,
    enteredAt = nil,
    enteredHP = 0,
    allowSafeGapNow = true,
    lastExitAt = nil
  },
  planState = {
    active = false,
    kind = nil,
    reasonGroup = nil,
    reasonRaw = nil,
    priority = 0,
    createdAt = 0,
    executeAt = 0,
    earliestExecuteAt = 0,
    expiresAt = 0,
    hpAtCreate = 0,
    thresholdEpisodeId = 0,
    cancelHP = 0,
    minHoldUntil = 0,
    lastReplanAt = 0,
    safetyMargin = 0
  },
  cancelState = {
    lastCancelAt = -10,
    lastReasonGroup = nil,
    lastReasonRaw = nil,
    lastCancelTs = 0
  },
  suppressUntil = {},
  overlay = {
    ts = 0,
    curHP = 0,
    armOn = false,
    preLead = 0,
    window = 0,
    events = {},
    totalIncoming = 0,
    dynamicSafeBuf = C.TUNED_SAFETY_BUFFER,
    focusMode = false,
    focusScore = 0,
    roshanPressure = false,
    roshanHit = 0,
    thresholdEpisodeId = 0,
    thresholdActive = false,
    activePlan = nil,
    planSuppressed = false,
    lastCancelReason = nil,
    lastCancelAgo = nil,
    riskMode = "normal",
    plannerPrioritySource = "none",
    recentReasons = {}
  },
  recentAnimLog = {},
  lastAnimDedup = {}
}
local DRAW                         = {
  fontSizes = {},
  drawColor = { r = 255, g = 255, b = 255, a = 255 }
}

local function tableContains(tbl, value)
  if not tbl then return false end
  if table.find then return table.find(tbl, value) ~= nil end
  for i = 1, #tbl do
    if tbl[i] == value then return true end
  end
  return false
end

local function drawFlagsNone()
  if not Enum or not Enum.DrawFlags then return nil end
  return Enum.DrawFlags.NONE or Enum.DrawFlags.None
end

local function makeColor(r, g, b, a)
  if Color then return Color(r or 255, g or 255, b or 255, a or 255) end
  return { r = r or 255, g = g or 255, b = b or 255, a = a or 255 }
end

local function loadFontCompat(name, size, weight)
  local ok, f
  if Renderer and Renderer.LoadFont then
    ok, f = pcall(Renderer.LoadFont, name, size, weight)
    if ok and f then return f end
  end
  if Render and Render.LoadFont then
    ok, f = pcall(Render.LoadFont, name, size, weight)
    if ok and f then return f end
    ok, f = pcall(Render.LoadFont, name, Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS or 0,
      weight or 400)
    if ok and f then return f end
  end
  if Render and Render.CreateFont then
    ok, f = pcall(Render.CreateFont, name, size, weight, 0)
    if ok and f then return f end
  end
  if Renderer and Renderer.CreateFont then
    ok, f = pcall(Renderer.CreateFont, name, size, weight, 0)
    if ok and f then return f end
  end
  return nil
end

local function rememberFontSize(font, size)
  if font ~= nil then DRAW.fontSizes[tostring(font)] = size end
end

local function newFont(name, size, weight)
  local f = loadFontCompat(name, size, weight)
  rememberFontSize(f, size)
  return f
end

local function setDrawColorCompat(r, g, b, a)
  DRAW.drawColor = { r = r or 255, g = g or 255, b = b or 255, a = a or 255 }
  if Renderer and Renderer.SetDrawColor then
    Renderer.SetDrawColor(DRAW.drawColor.r, DRAW.drawColor.g, DRAW.drawColor.b, DRAW.drawColor.a)
  end
end

local function drawTextCompat(font, x, y, text)
  if not font or not text then return end
  local s = tostring(text)
  if Renderer and Renderer.DrawText then
    Renderer.DrawText(font, x, y, s)
    return
  end
  if Render and Render.Text then
    local sz = DRAW.fontSizes[tostring(font)] or 14
    local pos = Vec2 and Vec2(x, y) or { x = x, y = y }
    local col = makeColor(DRAW.drawColor.r, DRAW.drawColor.g, DRAW.drawColor.b, DRAW.drawColor.a)
    local ok = pcall(Render.Text, font, sz, s, pos, col)
    if not ok then
      pcall(Render.Text, font, pos, s, col)
    end
  end
end

local function drawFilledRectCompat(x, y, w, h)
  if Renderer and Renderer.DrawFilledRect then
    Renderer.DrawFilledRect(x, y, w, h)
    return
  end
  if Render and Render.FilledRect then
    local pos = Vec2 and Vec2(x, y) or { x = x, y = y }
    local pos2 = Vec2 and Vec2(x + w, y + h) or { x = x + w, y = y + h }
    local sz = Vec2 and Vec2(w, h) or { x = w, y = h }
    local col = makeColor(DRAW.drawColor.r, DRAW.drawColor.g, DRAW.drawColor.b, DRAW.drawColor.a)
    local ok = pcall(Render.FilledRect, pos, pos2, col, 0)
    if not ok then
      pcall(Render.FilledRect, pos, sz, col, 0)
    end
  end
end

local function drawOutlineRectCompat(x, y, w, h)
  if Renderer and Renderer.DrawOutlineRect then
    Renderer.DrawOutlineRect(x, y, w, h)
    return
  end
  local pos = Vec2 and Vec2(x, y) or { x = x, y = y }
  local pos2 = Vec2 and Vec2(x + w, y + h) or { x = x + w, y = y + h }
  local sz = Vec2 and Vec2(w, h) or { x = w, y = h }
  local col = makeColor(DRAW.drawColor.r, DRAW.drawColor.g, DRAW.drawColor.b, DRAW.drawColor.a)
  if Render and Render.Rect then
    local ok = pcall(Render.Rect, pos, pos2, col, 0, drawFlagsNone(), 1)
    if ok then return end
  end
  if Render and Render.OutlineRect then
    local ok = pcall(Render.OutlineRect, pos, sz, col, 0, 1)
    if ok then return end
    pcall(Render.OutlineRect, pos, pos2, col, 0, 1)
  end
end

local function drawLineCompat(x1, y1, x2, y2)
  if Renderer and Renderer.DrawLine then
    Renderer.DrawLine(x1, y1, x2, y2)
    return
  end
  if Render and Render.Line then
    local p1 = Vec2 and Vec2(x1, y1) or { x = x1, y = y1 }
    local p2 = Vec2 and Vec2(x2, y2) or { x = x2, y = y2 }
    local col = makeColor(DRAW.drawColor.r, DRAW.drawColor.g, DRAW.drawColor.b, DRAW.drawColor.a)
    pcall(Render.Line, p1, p2, col, 1)
  end
end

local function screenSizeCompat()
  if Render and Render.ScreenSize then
    local ok, s = pcall(Render.ScreenSize)
    if ok and s and s.x and s.y then return s end
  end
  if Render and Render.GetScreenSize then
    local ok, s = pcall(Render.GetScreenSize)
    if ok and s and s.x and s.y then return s end
  end
  if Engine and Engine.GetScreenSize then
    local ok, s = pcall(Engine.GetScreenSize)
    if ok and s and s.x and s.y then return s end
  end
  return { x = 1920, y = 1080 }
end

local font                         = newFont("Arial", 16, Enum.FontWeight.MEDIUM)
local fontSmall                    = newFont("Arial", 14, Enum.FontWeight.NORMAL)
local fontMono                     = newFont("Consolas", 14, Enum.FontWeight.NORMAL)
local fontTitle                    = newFont("Arial", 18, Enum.FontWeight.HEAVY)

local PROJECTILE_OVERRIDES         = {
  skywrath_mage_arcane_bolt = 500,
  sniper_assassinate        = 2500,
  viper_viper_strike        = 1200
}

local function getWidgetValue(widget, default)
  if not widget then return default end
  local getter = widget.Get or widget.GetValue
  if getter then
    local ok, value = pcall(getter, widget)
    if ok and value ~= nil then
      return value
    end
  end
  return default
end

local function uiBool(widget, default)
  return getWidgetValue(widget, default == true) == true
end

local function uiInt(widget, default)
  local value = tonumber(getWidgetValue(widget, default))
  if not value then return default end
  return math.floor(value + 0.5)
end

local function uiComboIndex(widget, default)
  local value = tonumber(getWidgetValue(widget, default))
  if not value then return default end
  return math.floor(value + 0.5)
end

local nowTime

local function currentDebugLevel()
  local level = uiComboIndex(debugLogLevel, DEBUG_LOG_STATE)
  if level < DEBUG_LOG_OFF then return DEBUG_LOG_OFF end
  if level > DEBUG_LOG_VERBOSE then
    if (level - 1) <= DEBUG_LOG_VERBOSE then
      level = level - 1
    else
      level = DEBUG_LOG_VERBOSE
    end
  end
  return level
end

local function dbg(msg, level, dedupeKey, dedupeWindow)
  local required = level or DEBUG_LOG_VERBOSE
  if currentDebugLevel() < required or not Log or not Log.Write then return end
  local key = dedupeKey or tostring(msg or "")
  local now = nowTime and nowTime() or 0
  local window = dedupeWindow or 0
  if window > 0 then
    local lastAt = PLAN.lastLogLineAt[key]
    if lastAt and (now - lastAt) < window then return end
    PLAN.lastLogLineAt[key] = now
  end
  Log.Write("[ArmletAbuse] " .. tostring(msg))
end

local function logState(msg, key, window)
  dbg(msg, DEBUG_LOG_STATE, key or msg, window or 0.50)
end

local function initMenu()
  if MENU.menuInitialized then return end
  local armletIcon = "panorama/images/items/armlet_png.vtex_c"
  local wandIcon = "panorama/images/items/magic_wand_png.vtex_c"
  local faerieIcon = "panorama/images/items/faerie_fire_png.vtex_c"
  local function setImageSafe(widget, imagePath, offset)
    if widget and widget.Image then
      if offset ~= nil then
        pcall(widget.Image, widget, imagePath, offset)
      else
        pcall(widget.Image, widget, imagePath)
      end
    end
  end

  MENU.root = Menu.Create("Miscellaneous", "In Game", "Armlet Abuse V2")
  setImageSafe(MENU.root, armletIcon, 1)
  MENU.mainTab = MENU.root:Create("Main")
  setImageSafe(MENU.mainTab, armletIcon, 1)

  MENU.coreSettings = MENU.mainTab:Create("Core", MENU.groupLeft)
  MENU.timingSettings = MENU.mainTab:Create("Timing", MENU.groupLeft)
  MENU.threatSettings = MENU.mainTab:Create("Threat Tracking", MENU.groupLeft)
  MENU.consumableSettings = MENU.mainTab:Create("Consumables", MENU.groupRight)
  MENU.overlaySettings = MENU.mainTab:Create("Visuals", MENU.groupRight)
  MENU.debugSettings = MENU.mainTab:Create("Debug", MENU.groupRight)

  MENU.coreSettings:Label("Stability-first armlet planner.", armletIcon)
  MENU.timingSettings:Label("Shift-aware timing and safety guards.")
  MENU.consumableSettings:Label("Healing bridge for risky refresh windows.", wandIcon)
  MENU.overlaySettings:Label("Snapshot overlay and planner visibility.")

  Switch = MENU.coreSettings:Switch("Enable Armlet Abuse", true, armletIcon)
  riskyAbuseSwitch = MENU.coreSettings:Switch("Enable Risky Abuse", false)
  hpSlider = MENU.coreSettings:Slider("Health Threshold", 220, 520, 340)

  adaptiveTimingSwitch = MENU.timingSettings:Switch("Adaptive Timing", true)
  disableGuardSwitch = MENU.timingSettings:Switch("Disable Guard", true)
  heroBurstGuardSwitch = MENU.timingSettings:Switch("Hero Burst Guard", true)
  reactionTimeMs = MENU.timingSettings:Slider("Reaction Time (ms)", 0, 150, DEFAULT_REACTION_MS, "%d")
  toggleCooldownMs = MENU.timingSettings:Slider("Toggle Cooldown (ms)", 0, 120, DEFAULT_TOGGLE_MS, "%d")

  trackTowers = MENU.threatSettings:Switch("Track Towers", true)
  trackCreeps = MENU.threatSettings:Switch("Track Creeps", true)
  trackNeutrals = MENU.threatSettings:Switch("Track Neutrals", true)

  consumableSwitch = MENU.consumableSettings:Switch("Enable Consumable Use", true, wandIcon)
  consumableSelect = MENU.consumableSettings:MultiSelect("Consumables to Use", multiSelectItems, false)

  Overlay = MENU.overlaySettings:Switch("Show Overlay", true)
  local overlayGear = Overlay:Gear("Overlay Details")
  OverlayDetails = overlayGear:Switch("Show Debug Details", true)
  OverlayTimeline = overlayGear:Switch("Show Timeline", true)

  debugLogLevel = MENU.debugSettings:Combo("Debug Log Level", DEBUG_LOG_ITEMS, DEBUG_LOG_STATE)

  setImageSafe(riskyAbuseSwitch, "panorama/images/spellicons/viper_viper_strike_png.vtex_c")
  setImageSafe(hpSlider, armletIcon)
  setIconSafe(adaptiveTimingSwitch, "\u{f201}")
  setIconSafe(disableGuardSwitch, "\u{f05e}")
  setIconSafe(heroBurstGuardSwitch, "\u{f0e7}")
  setIconSafe(reactionTimeMs, "\u{f017}")
  setIconSafe(toggleCooldownMs, "\u{f021}")
  setIconSafe(trackTowers, "\u{f6d9}")
  setIconSafe(trackCreeps, "\u{f188}")
  setIconSafe(trackNeutrals, "\u{f1b0}")
  setImageSafe(consumableSelect, faerieIcon)
  setIconSafe(Overlay, "\u{f06e}")
  setIconSafe(OverlayDetails, "\u{f05a}")
  setIconSafe(OverlayTimeline, "\u{f017}")
  setIconSafe(debugLogLevel, "\u{f188}")

  setToolTipSafe(Switch, "Master switch for the survival-first armlet planner.")
  setToolTipSafe(hpSlider, "HP threshold where armlet pre-toggle logic becomes active.")
  setToolTipSafe(riskyAbuseSwitch,
    "If disabled, the script will not toggle against fast DoTs (<= 0.25s tick rate) unless a usable healing consumable is available.")
  setToolTipSafe(adaptiveTimingSwitch, "Adjust lead time and toggle timing from current pressure instead of fixed delays.")
  setToolTipSafe(consumableSwitch, "Use consumables when armlet toggling against fast DoTs (tick rate <= 0.25s).")
  setToolTipSafe(consumableSelect, "Choose healing consumables used during fast DoT armlet refresh.")
  setToolTipSafe(Overlay, "Show the planner snapshot, active plan, and current pressure state.")
  setToolTipSafe(debugLogLevel, "Off hides logs, State shows transitions only, Verbose keeps detailed pulse diagnostics.")

  MENU.menuInitialized = true
end

function script.OnScriptsLoaded()
  initMenu()
end

nowTime = function() return GameRules.GetGameTime() end
local function isAlive(ent) return ent and Entity.IsAlive(ent) end
local function isEnemy(ent) return ent and hero and not Entity.IsSameTeam(ent, hero) end
local function isHeroUnit(ent)
  if not ent then return false end
  if NPC and NPC.IsHero then
    local ok, v = pcall(NPC.IsHero, ent)
    if ok and v then return true end
  end
  return false
end
local function unitName(ent)
  if not ent then return "" end
  if not NPC or not NPC.GetUnitName then return "" end
  local ok, n = pcall(NPC.GetUnitName, ent)
  return (ok and n) and tostring(n):lower() or ""
end
local function IsTower(unit)
  local n = unitName(unit)
  return n ~= "" and n:find("tower", 1, true) and true or false
end
local function IsCreep(unit)
  local n = unitName(unit)
  return n ~= "" and (n:find("creep", 1, true) or n:find("lane_creep", 1, true) or n:find("_creep", 1, true) or n:find("warlock_golem", 1, true) or n:find("lycan_wolf", 1, true)) and true or false
end
local function IsNeutralOrRoshan(unit)
  local n = unitName(unit)
  return n ~= "" and (n:find("neutral", 1, true) or n:find("roshan", 1, true)) and true or false
end
local function shouldTrackSource(unit)
  if not unit then return false end
  if IsTower(unit) then return uiBool(trackTowers, true) end
  if IsCreep(unit) then return uiBool(trackCreeps, true) end
  if IsNeutralOrRoshan(unit) then return uiBool(trackNeutrals, true) end
  return true
end
local function isEnemyHero(ent)
  return ent and isEnemy(ent) and isHeroUnit(ent)
end
local function isHuskar(unit)
  if not unit then return false end
  local n = unitName(unit)
  return n ~= "" and n:find("huskar", 1, true) and true or false
end

local function pushDecisionLog(text, r, g, b)
  if not text or text == "" then return end
  PLAN.decisionTraceLog[#PLAN.decisionTraceLog + 1] = {
    time = nowTime(),
    text = tostring(text),
    r = r or 180,
    g = g or 220,
    b = b or 255
  }
  if #PLAN.decisionTraceLog > 12 then
    table.remove(PLAN.decisionTraceLog, 1)
  end
end
local function isRoshan(ent)
  local n = unitName(ent)
  return n ~= "" and n:find("roshan", 1, true) ~= nil
end
local function abilityName(ability)
  if not ability then return nil end
  local ok, n = pcall(Ability.GetName, ability)
  if ok then return n end
  return nil
end
local DISABLE_ABILITY_PROFILES = {
  lion_impale = { severity = 0.92, lock = 1.60 },
  lion_voodoo = { severity = 1.00, lock = 2.40 },
  shadow_shaman_voodoo = { severity = 1.00, lock = 2.40 },
  shadow_shaman_shackles = { severity = 1.00, lock = 2.80 },
  bane_fiends_grip = { severity = 1.00, lock = 3.60 },
  bane_nightmare = { severity = 0.85, lock = 1.80 },
  enigma_black_hole = { severity = 1.00, lock = 3.20 },
  faceless_void_chronosphere = { severity = 1.00, lock = 3.40 },
  legion_commander_duel = { severity = 1.00, lock = 4.00 },
  axe_berserkers_call = { severity = 0.90, lock = 2.20 },
  sven_storm_bolt = { severity = 0.88, lock = 1.80 },
  chaos_knight_chaos_bolt = { severity = 0.88, lock = 2.20 },
  dragon_knight_dragon_tail = { severity = 0.90, lock = 2.00 },
  vengefulspirit_magic_missile = { severity = 0.85, lock = 1.70 },
  wraith_king_wraithfire_blast = { severity = 0.85, lock = 1.70 },
  skeleton_king_hellfire_blast = { severity = 0.85, lock = 1.70 },
  sandking_burrowstrike = { severity = 0.86, lock = 1.80 },
  slardar_slithereen_crush = { severity = 0.85, lock = 1.60 },
  tiny_avalanche = { severity = 0.88, lock = 1.80 },
  storm_spirit_electric_vortex = { severity = 0.86, lock = 1.80 },
  puck_waning_rift = { severity = 0.72, lock = 2.00 },
  doom_bringer_doom = { severity = 0.82, lock = 5.00 },
  riki_smoke_screen = { severity = 0.70, lock = 2.00 },
  primal_beast_pulverize = { severity = 0.96, lock = 2.40 },
  muerta_the_calling = { severity = 0.68, lock = 2.00 }
}
local DISABLE_KEYWORDS = {
  chronosphere = { severity = 1.00, lock = 3.20 },
  black_hole = { severity = 1.00, lock = 3.00 },
  fiends_grip = { severity = 1.00, lock = 3.00 },
  duel = { severity = 1.00, lock = 3.50 },
  hex = { severity = 1.00, lock = 2.20 },
  voodoo = { severity = 1.00, lock = 2.20 },
  shackle = { severity = 0.95, lock = 2.30 },
  shackles = { severity = 0.95, lock = 2.30 },
  berserkers_call = { severity = 0.90, lock = 2.10 },
  nightmare = { severity = 0.85, lock = 1.80 },
  stun = { severity = 0.80, lock = 1.70 },
  vortex = { severity = 0.82, lock = 1.60 },
  crush = { severity = 0.80, lock = 1.40 },
  impale = { severity = 0.85, lock = 1.60 },
  silence = { severity = 0.66, lock = 1.80 },
  root = { severity = 0.62, lock = 1.50 },
  leash = { severity = 0.62, lock = 1.50 },
  fear = { severity = 0.70, lock = 1.60 }
}
local function getDisableThreatProfile(aName)
  if not aName then return nil end
  local n = tostring(aName):lower()
  local exact = DISABLE_ABILITY_PROFILES[n]
  if exact then
    return exact.severity, exact.lock
  end
  for key, prof in pairs(DISABLE_KEYWORDS) do
    if n:find(key, 1, true) then
      return prof.severity, prof.lock
    end
  end
  return nil, nil
end
local function addIncomingControl(source, abilityName_, atTime, cp, severity, lockDur)
  if not source or not atTime or atTime <= nowTime() - 0.05 then return end
  local key = tostring(source) .. ":" .. tostring(abilityName_ or "control")
  local expires = atTime + math.max(0.4, (lockDur or 1.5) + 0.8)
  local existing = THREAT.incomingControls[key]
  if existing then
    if atTime < existing.at then
      existing.at = atTime
      existing.cp = cp or existing.cp
      existing.severity = math.max(existing.severity or 0, severity or 0.65)
      existing.lockDur = math.max(existing.lockDur or 0, lockDur or 1.5)
    end
    existing.expires = math.max(existing.expires or expires, expires)
  else
    THREAT.incomingControls[key] = {
      at = atTime,
      cp = cp,
      src = source,
      name = abilityName_ or "control",
      severity = severity or 0.65,
      lockDur = lockDur or 1.5,
      expires = expires
    }
  end
end
local function cleanIncomingControls()
  local t = nowTime()
  for key, info in pairs(THREAT.incomingControls) do
    if (not info.at) or info.at < t - 0.20 or (info.expires and info.expires <= t) then
      THREAT.incomingControls[key] = nil
    end
  end
end
local function vecDist(a, b) return a:Distance(b) end
local function clamp(x, a, b) if x < a then return a elseif x > b then return b else return x end end
local function safeTick(x, fallback)
  x = tonumber(x)
  if not x or x <= 0 or x ~= x then return fallback end
  return math.max(0.05, x)
end

local function updateLatencyState(sample)
  if not sample then return end
  if not THREAT.latencyState.initialized then
    THREAT.latencyState.ewma = sample
    THREAT.latencyState.jitter = 0
    THREAT.latencyState.initialized = true
    return
  end
  local alpha = 0.20
  local delta = math.abs(sample - (THREAT.latencyState.ewma or sample))
  THREAT.latencyState.ewma = (1 - alpha) * (THREAT.latencyState.ewma or sample) + alpha * sample
  THREAT.latencyState.jitter = (1 - alpha) * (THREAT.latencyState.jitter or 0) + alpha * delta
end

local function getLatency()
  if NetChannel and NetChannel.GetLatency then
    local flow = Enum and Enum.Flow and (Enum.Flow.FLOW_OUTGOING or Enum.Flow.OUTGOING or Enum.Flow.OUT)
    local ok, v = pcall(NetChannel.GetLatency, flow)
    if ok and v then
      local sample = math.max(0.01, v)
      updateLatencyState(sample)
      return sample
    end
  end
  updateLatencyState(0.05)
  return 0.05
end

local function getLatencyStats()
  local raw = getLatency()
  local avg = THREAT.latencyState.ewma or raw
  local jitter = THREAT.latencyState.jitter or 0
  return raw, avg, jitter
end

local function autoTiming()
  local _, ping, jitter = getLatencyStats()
  local adaptive = uiBool(adaptiveTimingSwitch, true)
  local jitterLead = adaptive and (jitter * 1.35) or 0
  local pulseLead = adaptive and (THREAT.lastEventPulse.leadBonus or 0) or 0
  -- Lower preLead when ping is very low so we don't toggle too early (less drain waste)
  local preLead
  if ping < 0.020 then
    preLead = math.min(0.28, math.max(0.04, ping + 0.02 + jitterLead + pulseLead))
  else
    preLead = math.min(0.28, math.max(0.05, ping + 0.03 + jitterLead + pulseLead))
  end
  local reactionMs = uiInt(reactionTimeMs, 80)
  local proMode = reactionMs <= C.PRO_REACTION_MS
  local leadFloor = proMode and C.PRE_LEAD_FLOOR_PRO or (reactionMs * 0.001)
  preLead = math.max(preLead, leadFloor)
  local hpDelay = C.ARMLET_HP_SHIFT
  local lookahead = math.max(hpDelay + preLead + 0.90 + (adaptive and jitter * 1.6 or 0) + pulseLead * 1.5, 1.9)
  local cooldown
  if proMode then
    cooldown = hpDelay + math.max(0.03, ping * 0.5 + 0.02 + (adaptive and jitter * 0.5 or 0))
  else
    cooldown = hpDelay + math.max(0.06, ping + 0.04 + (adaptive and jitter * 0.8 or 0))
  end
  return preLead, lookahead, cooldown
end

local function shiftLockFudge()
  local _, ping, jitter = getLatencyStats()
  local reactionMs = uiInt(reactionTimeMs, 80)
  local minFudge = (reactionMs <= C.PRO_REACTION_MS) and C.SHIFT_FUDGE_MIN_PRO or C.SHIFT_FUDGE_MIN
  return math.max(minFudge, ping * 0.4 + 0.03 + jitter * (reactionMs <= C.PRO_REACTION_MS and 0.35 or 0.5))
end

local function isControlDisabled(unit)
  if not unit then return false end
  if NPC.IsStunned and NPC.IsStunned(unit) then return true end
  if NPC.IsHexed and NPC.IsHexed(unit) then return true end
  if NPC.IsMuted and NPC.IsMuted(unit) then return true end
  return false
end

local function castNoTargetCompat(ability)
  if not ability then return false end
  if Ability and Ability.CastNoTarget then
    local ok = pcall(Ability.CastNoTarget, ability, false, false, true)
    if ok then return true end
  end
  if hero and NPC and NPC.CastAbility then
    local ok = pcall(NPC.CastAbility, hero, ability)
    if ok then return true end
  end
  return false
end

local function toggleAbilityCompat(ability)
  if not ability then return false end
  if Ability and Ability.Toggle then
    local ok = pcall(Ability.Toggle, ability, false, false, true)
    if ok then return true end
  end
  if hero and NPC and NPC.CastAbility then
    local ok = pcall(NPC.CastAbility, hero, ability)
    if ok then return true end
  end
  return false
end

local function isShiftLocked()
  if not Armlet then return false end
  if not Ability.GetToggleState then return false end
  if not Ability.GetToggleState(Armlet) then return false end
  return (nowTime() - STATE.armOnSince) < (C.ARMLET_HP_SHIFT + shiftLockFudge())
end
local function nextShiftReadyAt() return STATE.armOnSince + C.ARMLET_HP_SHIFT + shiftLockFudge() end

local MAGIC_RESIST_MODS = {
  { name = "modifier_item_cloak", value = 0.15 }, { name = "modifier_item_hood_of_defiance", value = 0.15 },
  { name = "modifier_item_pipe_aura", value = 0.12 }, { name = "modifier_item_eternal_shroud", value = 0.20 },
  { name = "modifier_antimage_spell_shield", value = 0.35 }, { name = "modifier_rubick_null_field_aura_effect", value = 0.15 },
  { name = "modifier_item_glimmer_cape_fade", value = 0.15 }, { name = "modifier_item_pipe_barrier", value = 0.10 },
}
local MAGIC_VULN_MODS = {
  { name = "modifier_item_veil_of_discord_debuff", value = 0.18 }, { name = "modifier_pugna_decrepify", value = 0.30 },
  { name = "modifier_skywrath_ancient_seal", value = 0.30 }, { name = "modifier_item_ethereal_blade_ethereal", value = 0.40 },
}
local function getMagicResist(unit)
  if not unit then return 0.25 end
  local resist = 0.25
  if NPC.GetMagicalArmorValue then local v = NPC.GetMagicalArmorValue(unit); if v ~= nil then resist = 1 - (v or 0) end end
  if NPC.GetMagicalArmorDamageReduction then local v = NPC.GetMagicalArmorDamageReduction(unit); if v ~= nil then resist = v end end
  if NPC.GetMagicalResist then local v = NPC.GetMagicalResist(unit); if v ~= nil then resist = v end end
  for i = 1, #MAGIC_RESIST_MODS do
    local mod = MAGIC_RESIST_MODS[i]
    local ok, has = pcall(NPC.HasModifier, unit, mod.name)
    if ok and has then resist = 1 - (1 - resist) * (1 - mod.value) end
  end
  do
    local ok, has = pcall(NPC.HasModifier, unit, "modifier_huskar_berserkers_blood")
    if ok and has then
      local mhp = Entity.GetMaxHealth(unit)
      if mhp and mhp > 0 then local hp_pct = (Entity.GetHealth(unit) or 0) / mhp; resist = 1 - (1 - resist) * (1 - 0.50 * (1 - hp_pct)) end
    end
  end
  for i = 1, #MAGIC_VULN_MODS do
    local mod = MAGIC_VULN_MODS[i]
    local ok, has = pcall(NPC.HasModifier, unit, mod.name)
    if ok and has then resist = 1 - (1 - resist) * (1 + mod.value) end
  end
  if resist < 0 then resist = 0 elseif resist > 1 then resist = 1 end
  return resist
end
local function getPhysResist(unit)
  if NPC.GetPhysicalArmorValue then
    local armor = NPC.GetPhysicalArmorValue(unit) or 0
    local red = (0.052 * armor) / (0.9 + 0.048 * math.abs(armor))
    return math.max(0.0, math.min(0.9, red))
  end
  return 0.25
end
local function applyResists(unit, dmg, dtype)
  if not dmg or dmg <= 0 then return 0 end
  if dtype == "pure" then return dmg end
  if dtype == "physical" then return dmg * (1.0 - getPhysResist(unit)) end
  return dmg * (1.0 - getMagicResist(unit))
end
local function isArmletHandle(ref)
  if not ref or not Ability or not Ability.GetName then return false end
  local ok, n = pcall(Ability.GetName, ref)
  return ok and n == "item_armlet"
end

local function ensureArmlet()
  if isArmletHandle(Armlet) then return true end
  Armlet = nil
  if not hero then return false end
  for i = 0, 8 do
    local item = NPC.GetItemByIndex(hero, i)
    if isArmletHandle(item) then
      Armlet = item
      break
    end
  end
  return Armlet ~= nil
end

local function canToggle(cd)
  local t = nowTime()
  if isShiftLocked() then return false end
  if uiBool(disableGuardSwitch, true) then
    if isControlDisabled(hero) then return false end
  end
  local toggleMs = uiInt(toggleCooldownMs, 30)
  local defaultCD = math.max(toggleMs * 0.001, C.ARMLET_HP_SHIFT + math.max(0.06, getLatency() + 0.04))
  local minCD = cd or defaultCD
  return (t - STATE.lastToggle) >= minCD
end
local function nextToggleAllowedAt(cd, now)
  local t = now or nowTime()
  local toggleMs = uiInt(toggleCooldownMs, 30)
  local defaultCD = math.max(toggleMs * 0.001, C.ARMLET_HP_SHIFT + math.max(0.06, getLatency() + 0.04))
  local minCD = cd or defaultCD
  local readyAt = STATE.lastToggle + minCD
  if isShiftLocked() then
    readyAt = math.max(readyAt, nextShiftReadyAt() + 0.005)
  end
  return math.max(readyAt, t + 0.005)
end
local function hasFastDot()
  local t = nowTime()
  for _, st in pairs(THREAT.dotStates) do
    if (not st.endAt or st.endAt > t) and st.dps and st.dps > 0 then
      local tickInt = safeTick(st.tick, 1.0)
      if tickInt <= 0.25 then
        return true
      end
    end
  end
  return false
end

local function getEnabledConsumables()
  if not consumableSelect then return nil end
  if consumableSelect.ListEnabled then
    local ok, list = pcall(consumableSelect.ListEnabled, consumableSelect)
    if ok and type(list) == "table" then return list end
  end
  if not consumableSelect.Get then return nil end
  local list = {}
  for i = 1, #multiSelectItems do
    local itemName = multiSelectItems[i][1]
    local ok, enabled = pcall(consumableSelect.Get, consumableSelect, itemName)
    if ok and enabled then
      list[#list + 1] = itemName
    end
  end
  return list
end

local function getMaxHP(unit)
  if not unit then return 0 end
  if Entity and Entity.GetMaxHealth then
    local ok, hp = pcall(Entity.GetMaxHealth, unit)
    if ok and hp and hp > 0 then return hp end
  end
  if NPC and NPC.GetMaxHealth then
    local ok, hp = pcall(NPC.GetMaxHealth, unit)
    if ok and hp and hp > 0 then return hp end
  end
  return 0
end
local function getMissingHP(unit)
  if not unit then return 0, 0, 0 end
  local hp = Entity.GetHealth(unit) or 0
  local mx = getMaxHP(unit)
  if mx <= 0 then return 0, hp, mx end
  return math.max(0, mx - hp), hp, mx
end
local function estimateConsumableHeal(itemName, item, missingHP)
  if itemName == "item_magic_stick" or itemName == "item_magic_wand" then
    local charges = (Ability.GetCurrentCharges and Ability.GetCurrentCharges(item)) or 0
    if charges <= 0 then return 0, charges end
    return charges * 15, charges
  end
  if itemName == "item_faerie_fire" then
    return 85, 0
  end
  if itemName == "item_greater_famango" then
    return math.min(missingHP or 240, 240), 0
  end
  if itemName == "item_great_famango" then
    return math.min(missingHP or 180, 180), 0
  end
  if itemName == "item_famango" then
    return math.min(missingHP or 120, 120), 0
  end
  return 90, 0
end
local function pickBestConsumable(selected, deficitHP, emergency)
  local itemPriority = {
    "item_magic_wand", "item_magic_stick", "item_faerie_fire", "item_greater_famango",
    "item_great_famango", "item_famango"
  }
  local bestEmergency, bestEmergencyScore = nil, -1e9
  local bestFit, bestFitOver = nil, 1e9
  local bestUnder, bestUnderHeal = nil, -1
  local target = math.max(45, (deficitHP or 0) * 0.55)

  for _, itemName in ipairs(itemPriority) do
    if tableContains(selected, itemName) then
      local item = NPC.GetItem(hero, itemName, false)
      if item and Ability.IsReady(item) then
        local heal, charges = estimateConsumableHeal(itemName, item, deficitHP)
        if heal and heal > 0 then
          local preferWand = (itemName == "item_magic_wand") and 6 or 0
          if emergency then
            local score = heal + (charges or 0) * 4 + preferWand
            if score > bestEmergencyScore then
              bestEmergencyScore = score
              bestEmergency = { item = item, name = itemName, heal = heal, charges = charges or 0 }
            end
          else
            if heal >= target then
              local over = heal - target
              if over < bestFitOver then
                bestFitOver = over
                bestFit = { item = item, name = itemName, heal = heal, charges = charges or 0 }
              end
            else
              if heal > bestUnderHeal then
                bestUnderHeal = heal
                bestUnder = { item = item, name = itemName, heal = heal, charges = charges or 0 }
              end
            end
          end
        end
      end
    end
  end

  if emergency then
    return bestEmergency
  end
  return bestFit or bestUnder
end
local function hasAvailableConsumable(deficitHP, emergency)
  if not hero or not uiBool(consumableSwitch, true) then return false end
  local selected = getEnabledConsumables()
  if not selected then return false end
  local candidate = pickBestConsumable(selected, deficitHP or 120, emergency == true)
  return candidate ~= nil
end
local function findAndUseConsumable(deficitHP, emergency, reason)
  if not hero or not uiBool(consumableSwitch, true) then return false end
  local selected = getEnabledConsumables()
  if not selected then return false end
  local candidate = pickBestConsumable(selected, deficitHP or 120, emergency == true)
  if not candidate then return false end

  if castNoTargetCompat(candidate.item) then
    dbg(string.format("Used %s heal~%.0f charges=%d (%s)", candidate.name, candidate.heal or 0, candidate.charges or 0,
      reason or "consumable"))
    return true
  end
  return false
end

local function getReasonMeta(reason)
  local raw = tostring(reason or "plan")
  local lower = string.lower(raw)
  local group = "threshold"

  if string.find(lower, "lethal", 1, true) or string.find(lower, "burst_ttk", 1, true) or
      string.find(lower, "imminent_multi_attack", 1, true) or string.find(lower, "cluster_prearm_wave", 1, true) or
      string.find(lower, "ultra_risk", 1, true) then
    group = "lethal"
  elseif string.find(lower, "execution", 1, true) then
    group = "execution"
  elseif string.find(lower, "pre_disable", 1, true) or string.find(lower, "disable", 1, true) or
      string.find(lower, "control", 1, true) then
    group = "pre_disable"
  elseif string.find(lower, "panic", 1, true) then
    group = "panic"
  elseif string.find(lower, "roshan", 1, true) then
    group = "roshan"
  elseif string.find(lower, "focus", 1, true) or string.find(lower, "hero_", 1, true) then
    group = "focus_guard"
  elseif string.find(lower, "dot", 1, true) then
    group = "dot_guard"
  elseif string.find(lower, "manual_recovery", 1, true) then
    group = "manual_recovery"
  elseif string.find(lower, "threshold", 1, true) then
    group = "threshold"
  end

  local priority = 40
  if group == "lethal" or group == "execution" or group == "pre_disable" then
    priority = 100
  elseif group == "panic" then
    priority = 80
  elseif group == "dot_guard" or group == "focus_guard" or group == "roshan" then
    priority = 70
  elseif group == "manual_recovery" then
    priority = 20
  end

  return raw, group, priority
end

local function clearPlanState()
  PLAN.planState.active = false
  PLAN.planState.kind = nil
  PLAN.planState.reasonGroup = nil
  PLAN.planState.reasonRaw = nil
  PLAN.planState.priority = 0
  PLAN.planState.createdAt = 0
  PLAN.planState.executeAt = 0
  PLAN.planState.earliestExecuteAt = 0
  PLAN.planState.expiresAt = 0
  PLAN.planState.hpAtCreate = 0
  PLAN.planState.thresholdEpisodeId = 0
  PLAN.planState.cancelHP = 0
  PLAN.planState.minHoldUntil = 0
  PLAN.planState.lastReplanAt = 0
  PLAN.planState.safetyMargin = 0
end

local function hasAnyPlanSuppression(tnow)
  local now = tnow or nowTime()
  for _, untilAt in pairs(PLAN.suppressUntil) do
    if untilAt and untilAt > now then
      return true
    end
  end
  return false
end

local function setPlanSuppression(reasonGroup, untilAt)
  if not reasonGroup or not untilAt then return end
  PLAN.suppressUntil[reasonGroup] = math.max(PLAN.suppressUntil[reasonGroup] or 0, untilAt)
end

local function isPlanSuppressed(reasonGroup, tnow)
  local untilAt = reasonGroup and PLAN.suppressUntil[reasonGroup] or nil
  return untilAt ~= nil and untilAt > (tnow or nowTime())
end

local function clearExpiredPlan(tnow)
  local now = tnow or nowTime()
  if PLAN.planState.active and PLAN.planState.expiresAt > 0 and now > PLAN.planState.expiresAt then
    clearPlanState()
  end
end

local function getActivePlanSummary(tnow)
  local now = tnow or nowTime()
  clearExpiredPlan(now)
  if not PLAN.planState.active then return nil end
  return {
    kind = PLAN.planState.kind,
    reasonGroup = PLAN.planState.reasonGroup,
    reasonRaw = PLAN.planState.reasonRaw,
    priority = PLAN.planState.priority,
    eta = math.max(0, (PLAN.planState.executeAt or now) - now)
  }
end

local function recentReasonsSnapshot(limit)
  local list = {}
  for i = #PLAN.decisionTraceLog, 1, -1 do
    local entry = PLAN.decisionTraceLog[i]
    if entry and entry.text then
      list[#list + 1] = entry.text
      if #list >= (limit or 4) then break end
    end
  end
  return list
end

local function updateThresholdEpisode(curHP, sliderHP, tnow)
  local now = tnow or nowTime()
  if PLAN.thresholdEpisode.active then
    if (curHP or 0) >= (sliderHP + PLAN.config.THRESHOLD_EXIT_HP) then
      PLAN.thresholdEpisode.active = false
      PLAN.thresholdEpisode.enteredAt = nil
      PLAN.thresholdEpisode.enteredHP = 0
      PLAN.thresholdEpisode.allowSafeGapNow = true
      PLAN.thresholdEpisode.lastExitAt = now
      STATE.thresholdSince = nil
      logState(string.format("THRESHOLD_EXIT id=%d hp=%d", PLAN.thresholdEpisode.id or 0, math.floor(curHP or 0)),
        "threshold_exit", 0.25)
      pushDecisionLog(string.format("THRESHOLD_EXIT #%d hp=%d", PLAN.thresholdEpisode.id or 0, math.floor(curHP or 0)), 175,
        220, 175)
    end
  elseif (curHP or 0) <= sliderHP then
    PLAN.thresholdEpisode.active = true
    PLAN.thresholdEpisode.id = (PLAN.thresholdEpisode.id or 0) + 1
    PLAN.thresholdEpisode.enteredAt = now
    PLAN.thresholdEpisode.enteredHP = curHP or 0
    PLAN.thresholdEpisode.allowSafeGapNow = true
    PLAN.thresholdEpisode.lastExitAt = nil
    STATE.thresholdSince = now
    logState(string.format("THRESHOLD_ENTER id=%d hp=%d", PLAN.thresholdEpisode.id, math.floor(curHP or 0)),
      "threshold_enter", 0.25)
    pushDecisionLog(string.format("THRESHOLD_ENTER #%d hp=%d", PLAN.thresholdEpisode.id, math.floor(curHP or 0)), 255, 205,
      135)
  end
  if PLAN.thresholdEpisode.active and PLAN.thresholdEpisode.enteredAt then
    STATE.thresholdSince = PLAN.thresholdEpisode.enteredAt
  end
end

local function shouldReplacePlan(candidate)
  if not PLAN.planState.active then return true end
  if candidate.priority > (PLAN.planState.priority or 0) then return true end
  if candidate.priority < (PLAN.planState.priority or 0) then return false end
  if candidate.executeAt < ((PLAN.planState.executeAt or 0) - PLAN.config.REPLACE_EARLIER_SEC) then
    return true
  end
  if (candidate.safetyMargin or 0) >= ((PLAN.planState.safetyMargin or 0) + PLAN.config.REPLACE_MARGIN_HP) then
    return true
  end
  return false
end

local function registerPlanCancel(reasonRaw, reasonGroup, tag)
  local now = nowTime()
  if (now - (PLAN.cancelState.lastCancelAt or -10)) < PLAN.config.CANCEL_COOLDOWN_SEC then return false end

  local raw = tostring(reasonRaw or PLAN.planState.reasonRaw or "plan")
  local group = reasonGroup or PLAN.planState.reasonGroup or "threshold"
  PLAN.cancelState.lastCancelAt = now
  PLAN.cancelState.lastReasonGroup = group
  PLAN.cancelState.lastReasonRaw = raw
  PLAN.cancelState.lastCancelTs = now
  PLAN.suppressUntil[group] = math.max(PLAN.suppressUntil[group] or 0, now + PLAN.config.SUPPRESS_AFTER_CANCEL_SEC)
  logState(string.format("PLAN_CANCEL %s (%s)", raw, tostring(tag or "cancel")),
    "plan_cancel:" .. group .. ":" .. tostring(tag or "cancel"), 0.50)
  pushDecisionLog(string.format("PLAN_CANCEL %s", tostring(tag or raw)), 170, 220, 170)
  clearPlanState()
  return true
end

local function planToggle(newTime, reason, opts)
  if not newTime then return false end
  local now = nowTime()
  clearExpiredPlan(now)
  local raw, reasonGroup, priority = getReasonMeta(reason)
  if isPlanSuppressed(reasonGroup, now) then return false end

  local options = type(opts) == "table" and opts or {}
  local candidate = {
    kind = options.kind or ((Armlet and Ability.GetToggleState(Armlet)) and "refresh" or "prearm"),
    reasonGroup = reasonGroup,
    reasonRaw = raw,
    priority = options.priority or priority,
    createdAt = now,
    executeAt = math.max(newTime, options.earliestExecuteAt or newTime),
    earliestExecuteAt = options.earliestExecuteAt or newTime,
    expiresAt = math.max(newTime, now) + (options.expirePad or PLAN.config.PLAN_EXPIRE_PAD_SEC),
    hpAtCreate = options.hpAtCreate or (hero and Entity.GetHealth(hero)) or 0,
    thresholdEpisodeId = options.thresholdEpisodeId or (PLAN.thresholdEpisode.active and PLAN.thresholdEpisode.id or 0),
    cancelHP = options.cancelHP or 0,
    minHoldUntil = now + (options.minHold or PLAN.config.PLAN_MIN_HOLD_SEC),
    lastReplanAt = now,
    safetyMargin = options.safetyMargin or 0
  }
  if not shouldReplacePlan(candidate) then return false end

  local action = PLAN.planState.active and "PLAN_REPLACE" or "PLAN_CREATE"
  PLAN.planState.active = true
  PLAN.planState.kind = candidate.kind
  PLAN.planState.reasonGroup = candidate.reasonGroup
  PLAN.planState.reasonRaw = candidate.reasonRaw
  PLAN.planState.priority = candidate.priority
  PLAN.planState.createdAt = candidate.createdAt
  PLAN.planState.executeAt = candidate.executeAt
  PLAN.planState.earliestExecuteAt = candidate.earliestExecuteAt
  PLAN.planState.expiresAt = candidate.expiresAt
  PLAN.planState.hpAtCreate = candidate.hpAtCreate
  PLAN.planState.thresholdEpisodeId = candidate.thresholdEpisodeId
  PLAN.planState.cancelHP = candidate.cancelHP
  PLAN.planState.minHoldUntil = candidate.minHoldUntil
  PLAN.planState.lastReplanAt = candidate.lastReplanAt
  PLAN.planState.safetyMargin = candidate.safetyMargin

  logState(string.format("%s %s in %.2fs p=%d", action, raw, math.max(0, candidate.executeAt - now), candidate.priority),
    "plan_" .. string.lower(action) .. ":" .. candidate.reasonGroup .. ":" .. candidate.kind, 0.15)
  pushDecisionLog(string.format("%s %.2fs (%s)", action, math.max(0, candidate.executeAt - now), raw), 150, 255, 190)
  PLAN.lastReasonByGroup[reasonGroup] = raw
  return true
end

local function AbuseArmlet(reason)
  if not ensureArmlet() then return end
  local reasonRaw, reasonGroup = getReasonMeta(reason)
  if uiBool(disableGuardSwitch, true) and isControlDisabled(hero) then
    dbg("blocked by disable-state guard (" .. (reason or "unknown") .. ")")
    pushDecisionLog("BLOCK disable_guard (" .. tostring(reason or "unknown") .. ")", 255, 165, 130)
    return
  end
  local missingHP, curHP = getMissingHP(hero)
  local sliderVal = uiInt(hpSlider, 340)
  local emergencyConsumable = (missingHP >= 180) or (curHP <= (sliderVal + 40))
  local criticalZone = (curHP or 0) <= C.CRITICAL_HP_ABSOLUTE or (curHP or 0) <= (sliderVal - C.CRITICAL_HP_BELOW_SLIDER)
  if not uiBool(riskyAbuseSwitch, false) then
    if hasFastDot() and not hasAvailableConsumable(math.max(100, missingHP), emergencyConsumable) then
      local criticalHP = (curHP or 0) <= (uiInt(hpSlider, 340) + 60)
      if not criticalHP then
        dbg("Risky abuse disabled: Fast DoT with no consumable. Aborting toggle.")
        return
      end
      dbg("Critical HP under fast DoT: allowing toggle despite no consumable.")
    end
  end

  local t = nowTime()
  local _, _, cd = autoTiming()
  if isShiftLocked() and Ability.GetToggleState(Armlet) then
    dbg("blocked refresh during shift (" .. (reason or "unknown") .. ")")
    pushDecisionLog("BLOCK shift_lock (" .. tostring(reason or "unknown") .. ")", 255, 180, 130)
    return
  end
  if not canToggle(cd) then return end

  local isOn = Ability.GetToggleState(Armlet)
  local toggled = false
  if isOn then
    if reasonGroup == "roshan" then
      local snapshot = PLAN.overlay or {}
      local events = snapshot.events or {}
      local dynamicSafeBuf = snapshot.dynamicSafeBuf or C.TUNED_SAFETY_BUFFER
      local gateWindow = math.max(0.08, math.min(0.22, (snapshot.preLead or 0.03) + getLatency() + 0.07))
      local gateMax = 0
      local gateTotal = 0
      local gateHits = 0
      for i = 1, #events do
        local ev = events[i]
        if ev.time > (t + gateWindow) then break end
        if ev.time > t and ev.src and isRoshan(ev.src) and
            (ev.type == "attack" or ev.type == "melee" or ev.type == "atk_fallback") then
          local dmg = ev.dmg or 0
          gateTotal = gateTotal + dmg
          gateHits = gateHits + 1
          if dmg > gateMax then gateMax = dmg end
        end
      end
      local singleFloor = math.max(18, math.min(42, dynamicSafeBuf - 6))
      local chainFloor = math.max(singleFloor + 6, dynamicSafeBuf - 2)
      if gateHits > 0 and (((curHP - gateMax) <= singleFloor) or ((curHP - gateTotal) <= chainFloor)) then
        local retryAt = math.max(nextToggleAllowedAt(cd, t), t + gateWindow + 0.03)
        dbg("blocked unsafe refresh gate (roshan)")
        pushDecisionLog("BLOCK roshan_refresh_gate", 255, 170, 120)
        planToggle(retryAt, "roshan_refresh_wait", {
          cancelHP = sliderVal + PLAN.config.PLAN_CANCEL_HP,
          safetyMargin = math.max(0, curHP - math.max(gateMax, gateTotal) - dynamicSafeBuf),
          hpAtCreate = curHP,
          thresholdEpisodeId = PLAN.thresholdEpisode.id or 0,
          priority = 85,
          minHold = 0.16,
          expirePad = 0.80
        })
        return
      end
    end
    local tryConsumable = false
    if uiBool(consumableSwitch, true) then
      for key, st in pairs(THREAT.dotStates) do
        if (not st.endAt or st.endAt > t) and st.dps and st.dps > 0 then
          local tickInt = safeTick(st.tick, 1.0)
          if tickInt <= 0.25 then
            tryConsumable = true
            dbg("Fast-ticking DoT detected (" ..
              (st.label or "unknown") .. "), tick=" .. tostring(tickInt) .. ". Trying consumable.")
            break
          end
        end
      end
      if THREAT.lastHadActiveDot and not tryConsumable and (reasonGroup == "panic" or reasonGroup == "dot_guard") and
          curHP <= (sliderVal + 90) then
        tryConsumable = true
        dbg("Sustained DoT pressure: trying consumable during refresh.")
      end
      if criticalZone and not tryConsumable then
        tryConsumable = true
        dbg("Critical zone: trying consumable during refresh.")
      end
    end

    if tryConsumable then
      local usedPre = findAndUseConsumable(math.max(120, missingHP), true, "pre_refresh")
      if toggleAbilityCompat(Armlet) then toggled = true end -- Turn OFF
      local usedMid = false
      if not usedPre then
        usedMid = findAndUseConsumable(math.max(120, missingHP), true, "mid_refresh")
      end
      if toggleAbilityCompat(Armlet) then toggled = true end -- Instantly turn ON

      if usedPre or usedMid then
        dbg("Armlet refresh WITH consumable (" .. (reason or "unknown") .. ")")
      else
        dbg("Armlet refresh (consumable attempted but failed) (" .. (reason or "unknown") .. ")")
      end
    else
      if toggleAbilityCompat(Armlet) then toggled = true end
      if toggleAbilityCompat(Armlet) then toggled = true end
      dbg("Armlet refresh (" .. (reason or "unknown") .. ")")
    end
  else
    toggled = toggleAbilityCompat(Armlet) or toggled
    dbg("Armlet ON (" .. (reason or "unknown") .. ")")
  end

  if toggled then
    STATE.armOnSince = t
    STATE.lastToggle = t
    STATE.toggledThisFrame = true
    local nextToggleAt = nextToggleAllowedAt(cd, t)
    if reason and string.find(string.lower(tostring(reason)), "threshold_safe_gap", 1, true) then
      PLAN.thresholdEpisode.allowSafeGapNow = false
    end
    if PLAN.thresholdEpisode.active and
        (reasonGroup == "panic" or reasonGroup == "dot_guard" or reasonGroup == "roshan" or
          string.find(reasonRaw, "threshold", 1, true)) then
      STATE.thresholdSince = t
      setPlanSuppression("threshold", math.max(t + (THREAT.lastHadActiveDot and 0.18 or 0.12), nextToggleAt + 0.02))
    end
    if reasonGroup == "panic" then
      setPlanSuppression("panic", math.max(t + 0.12, nextToggleAt + 0.02))
    elseif reasonGroup == "roshan" then
      local heavySuppressUntil = math.max(t + 0.18, nextToggleAt + 0.05)
      setPlanSuppression("panic", heavySuppressUntil)
      setPlanSuppression("threshold", heavySuppressUntil)
    elseif reasonRaw == "threshold_deadline" then
      setPlanSuppression("threshold", math.max(t + 0.10, nextToggleAt + 0.02))
    end
    clearPlanState()
    logState(string.format("TOGGLE_EXECUTE %s (%s)", isOn and "refresh" or "prearm", tostring(reason or "toggle")),
      "toggle_execute:" .. tostring(reason or "toggle"), 0.15)
    pushDecisionLog(string.format("TOGGLE %s hp=%d miss=%d", tostring(reason or "toggle"), curHP or 0, missingHP or 0), 150,
      255, 210)
  else
    dbg("toggle command failed (" .. (reason or "unknown") .. ")")
    pushDecisionLog("TOGGLE_FAIL (" .. tostring(reason or "unknown") .. ")", 255, 120, 120)
  end
end

local function SV(ability, key)
  if not ability then return nil end
  if Ability.GetLevelSpecialValueFor then
    local ok, v = pcall(Ability.GetLevelSpecialValueFor, ability, key)
    if ok and v ~= nil then return v end
  end
  if Ability.GetLevelSpecialValue then
    local lvl = 1
    if Ability.GetLevel then
      local okLvl, value = pcall(Ability.GetLevel, ability)
      if okLvl and value and value > 0 then lvl = value end
    end
    local ok, v = pcall(Ability.GetLevelSpecialValue, ability, key, lvl)
    if ok and v ~= nil then return v end
  end
  if Ability.GetSpecialValue then
    local ok, v = pcall(Ability.GetSpecialValue, ability, key)
    if ok and v ~= nil then return v end
  end
  return nil
end
local function SVAny(ability, keys, default)
  for _, k in ipairs(keys) do
    local v = SV(ability, k)
    if v ~= nil then return v end
  end
  return default
end
local function getDamageTypeString(ability)
  if Ability.GetDamageType and Enum then
    local ok, t = pcall(Ability.GetDamageType, ability)
    if ok then
      local dt = Enum.DamageType
      local dts = Enum.DamageTypes
      if dt then
        if t == dt.PHYSICAL then return "physical" end
        if t == dt.PURE then return "pure" end
      end
      if dts then
        if t == dts.PHYSICAL then return "physical" end
        if t == dts.PURE then return "pure" end
        if t == dts.HP_REMOVAL or t == dts.DAMAGE_TYPE_HP_REMOVAL then return "pure" end
      end
    end
  end
  return "magical"
end
local function getAbilityRadius(abil)
  if not abil then return 0 end
  return SVAny(abil, { "radius", "aoe_radius", "blast_radius", "blade_fury_radius", "rot_radius", "shrapnel_radius" }, 0) or
      0
end
local function GetAbilityTick(ability, name)
  local safeKeys = {
    "tick_interval", "tick_rate", "interval", "interval_s",
    "damage_interval", "damage_tick_interval", "damage_tick_rate",
    "blade_fury_damage_interval", "rot_tick", "rot_tick_rate",
    "poison_tick", "burn_interval", "pulse_interval",
    "heal_interval", "effect_interval",
    "second_per_tick", "seconds_per_tick", "immolate_tick",
    "fiend_grip_tick_interval", "twister_tick_rate",
    "invisible_damage_tickrate", "burn_tick_interval",
    "fire_delay", "aura_tick_interval", "spine_tick_rate",
    "whirling_tick", "special_bonus_unique_viper_4"
  }
  for _, key in ipairs(safeKeys) do
    local v = SV(ability, key)
    if v and v > 0 then return v, key end
  end
  local thinkOK = {
    sandking_sand_storm = true,
    pudge_rot = true,
    death_prophet_spirit_siphon = true,
    dark_seer_ion_shell = true,
    venomancer_poison_sting = true,
    venomancer_poison_nova = true,
    leshrac_pulse_nova = true,
  }
  if thinkOK[name] then
    local v = SV(ability, "think_interval")
    if v and v > 0 then return v, "think_interval" end
  end
  if name == "sniper_shrapnel" then
    return SV(ability, "damage_interval"), "damage_interval"
  elseif name == "pudge_rot" then
    return SV(ability, "rot_tick_rate") or SV(ability, "rot_tick"), "rot_tick_rate"
  elseif name == "juggernaut_blade_fury" then
    return SV(ability, "blade_fury_damage_interval"), "blade_fury_damage_interval"
  elseif name == "sandking_sand_storm" then
    return SV(ability, "damage_interval") or SV(ability, "think_interval"), "damage_interval"
  elseif name == "dark_seer_ion_shell" then
    return SV(ability, "damage_tick_interval") or SV(ability, "tick_rate"), "damage_tick_interval"
  elseif name == "venomancer_poison_nova" then
    return SV(ability, "tick_rate") or SV(ability, "poison_tick"), "tick_rate"
  end
  return nil, nil
end

local EXECUTION_ABILITY_PROFILES = {
  axe_culling_blade = {
    kind = "threshold",
    thresholdKeys = { "kill_threshold", "health_threshold", "damage", "culling_blade_damage" },
    defaultThreshold = 300,
    margin = 34,
    severity = 1.00,
    damageType = "pure"
  },
  necrophos_reapers_scythe = {
    kind = "missing_pct",
    pctKeys = { "damage_per_health", "damage_per_health_pct", "damage_per_missing_health" },
    defaultPct = 0.75,
    minDamage = 220,
    severity = 0.96,
    damageType = "magical"
  },
  huskar_life_break = {
    kind = "current_pct",
    pctKeys = { "health_damage", "health_damage_pct", "current_health_damage_pct" },
    defaultPct = 0.34,
    minDamage = 110,
    severity = 0.88,
    damageType = "magical"
  },
  life_stealer_open_wounds = {
    kind = "current_pct",
    pctKeys = { "hp_drain_percent", "health_drain_percent" },
    defaultPct = 0.10,
    minDamage = 55,
    severity = 0.62,
    damageType = "physical"
  },
  item_dagon = { kind = "flat", damageKeys = { "damage" }, defaultDamage = 400, severity = 0.82, damageType = "magical" },
  item_dagon_2 = { kind = "flat", damageKeys = { "damage" }, defaultDamage = 500, severity = 0.84, damageType = "magical" },
  item_dagon_3 = { kind = "flat", damageKeys = { "damage" }, defaultDamage = 600, severity = 0.86, damageType = "magical" },
  item_dagon_4 = { kind = "flat", damageKeys = { "damage" }, defaultDamage = 700, severity = 0.88, damageType = "magical" },
  item_dagon_5 = { kind = "flat", damageKeys = { "damage" }, defaultDamage = 800, severity = 0.90, damageType = "magical" }
}

local EXECUTION_KEYWORDS = {
  culling_blade = { kind = "threshold", defaultThreshold = 300, margin = 34, severity = 1.00, damageType = "pure" },
  reapers_scythe = { kind = "missing_pct", defaultPct = 0.75, minDamage = 220, severity = 0.96, damageType = "magical" },
  life_break = { kind = "current_pct", defaultPct = 0.34, minDamage = 110, severity = 0.88, damageType = "magical" },
  dagon = { kind = "flat", defaultDamage = 500, severity = 0.85, damageType = "magical" }
}

local RISK_MODE_PROFILES = {
  normal = { safeMul = 1.00, extraBuffer = 0, thresholdBias = 0 },
  safe = { safeMul = 1.14, extraBuffer = 8, thresholdBias = 18 },
  ultra = { safeMul = 1.26, extraBuffer = 16, thresholdBias = 34 }
}

local function readPositiveSpecial(ability, keys, default)
  if not ability or type(keys) ~= "table" then return default end
  for i = 1, #keys do
    local v = SV(ability, keys[i])
    if type(v) == "number" and v > 0 and v == v then
      return v
    end
  end
  return default
end

local function resolveExecutionProfile(aName)
  if not aName then return nil end
  local n = tostring(aName):lower()
  local exact = EXECUTION_ABILITY_PROFILES[n]
  if exact then return exact end
  for key, prof in pairs(EXECUTION_KEYWORDS) do
    if n:find(key, 1, true) then
      return prof
    end
  end
  return nil
end

local function estimateExecutionThreat(aName, ability, source, target)
  if not target then return nil end
  local prof = resolveExecutionProfile(aName)
  if not prof then return nil end

  local curHP = Entity.GetHealth(target) or 0
  local maxHP = getMaxHP(target)
  if curHP <= 0 then return nil end

  local kind = prof.kind or "flat"
  local dmg = 0
  local lethalSoon = false
  local thresholdUsed = nil
  if kind == "threshold" then
    thresholdUsed = readPositiveSpecial(ability, prof.thresholdKeys or {}, prof.defaultThreshold or 0) or 0
    local margin = prof.margin or C.TUNED_EXECUTION_MARGIN
    if curHP <= thresholdUsed + margin then
      dmg = curHP + math.max(50, thresholdUsed * 0.20)
      lethalSoon = true
    else
      dmg = math.max(thresholdUsed * 0.60, curHP * 0.22)
    end
  elseif kind == "missing_pct" then
    local pct = readPositiveSpecial(ability, prof.pctKeys or {}, prof.defaultPct or 0.5) or 0.5
    if pct > 1 then pct = pct / 100.0 end
    local missing = math.max(0, maxHP - curHP)
    dmg = math.max(prof.minDamage or 0, missing * pct)
  elseif kind == "current_pct" then
    local pct = readPositiveSpecial(ability, prof.pctKeys or {}, prof.defaultPct or 0.25) or 0.25
    if pct > 1 then pct = pct / 100.0 end
    dmg = math.max(prof.minDamage or 0, curHP * pct)
  elseif kind == "max_pct" then
    local pct = readPositiveSpecial(ability, prof.pctKeys or {}, prof.defaultPct or 0.10) or 0.10
    if pct > 1 then pct = pct / 100.0 end
    dmg = math.max(prof.minDamage or 0, maxHP * pct)
  else
    dmg = readPositiveSpecial(ability, prof.damageKeys or {}, prof.defaultDamage or 0) or 0
  end

  if dmg <= 0 then return nil end
  local dtype = prof.damageType or (ability and getDamageTypeString(ability)) or "magical"
  local resolved = applyResists(target, dmg, dtype)
  if kind == "threshold" and curHP <= (thresholdUsed or prof.defaultThreshold or 300) + C.TUNED_EXECUTION_MARGIN then
    resolved = math.max(resolved, curHP + 1)
  end

  return {
    dmg = math.max(1, resolved),
    label = "EXEC " .. (aName or "ability"),
    severity = prof.severity or 0.85,
    lethalSoon = lethalSoon
  }
end

local function analyzeUncertainty(events, now, horizon)
  local untilT = now + (horizon or 0.9)
  local fallbackCount = 0
  local fallbackDamage = 0
  local dotCount = 0
  local compressed = 0
  local opaque = 0
  local lastAt = nil
  for i = 1, #events do
    local ev = events[i]
    if ev.time > untilT then break end
    if ev.time > now then
      if ev.fb then
        fallbackCount = fallbackCount + 1
        fallbackDamage = fallbackDamage + (ev.dmg or 0)
      end
      if ev.type == "dot" then
        dotCount = dotCount + 1
      end
      if (not ev.src) or type(ev.src) == "string" then
        opaque = opaque + 1
      end
      if lastAt and math.abs(ev.time - lastAt) <= 0.08 then
        compressed = compressed + 1
      end
      lastAt = ev.time
    end
  end
  local _, _, jitter = getLatencyStats()
  local jitterMs = (jitter or 0) * 1000
  local score = fallbackCount * 2.1 +
      fallbackDamage * 0.015 +
      dotCount * 0.35 +
      compressed * 0.85 +
      opaque * 0.9 +
      jitterMs * 0.18
  local bonus = clamp(math.floor(score + 0.5), 0, C.TUNED_UNCERTAINTY_CAP)
  return {
    bonus = bonus,
    fallbackCount = fallbackCount,
    fallbackDamage = fallbackDamage,
    dotCount = dotCount,
    compressed = compressed,
    jitterMs = jitterMs
  }
end

local function analyzeExecutionThreat(events, now, horizon)
  local untilT = now + (horizon or 0.9)
  local count = 0
  local soon = 0
  local firstAt = nil
  local firstName = ""
  local lethalSoon = false
  for i = 1, #events do
    local ev = events[i]
    if ev.time > untilT then break end
    if ev.time > now and ev.type == "execute" then
      count = count + 1
      soon = soon + (ev.dmg or 0)
      if (not firstAt) or ev.time < firstAt then
        firstAt = ev.time
        firstName = ev.label or "execute"
      end
      if ev.execLethal then
        lethalSoon = true
      end
    end
  end
  return {
    count = count,
    soon = soon,
    firstAt = firstAt,
    firstName = firstName,
    lethalSoon = lethalSoon
  }
end

local function computeUnifiedRiskState(curHP, sliderHP, heroThreat, controlThreat, uncertainty, executionThreat, roshanHit, focusMode)
  local hpRef = math.max(1, curHP or 1)
  local score = 0
  score = score + clamp(((heroThreat and heroThreat.soon or 0) / hpRef) * 48, 0, 36)
  score = score + clamp(((heroThreat and heroThreat.dotSoon or 0) / hpRef) * 36, 0, 24)
  score = score + clamp(((heroThreat and heroThreat.sustained or 0) / hpRef) * 18, 0, 14)
  score = score + clamp((heroThreat and heroThreat.attackers or 0) * 3, 0, 12)

  score = score + clamp((controlThreat and controlThreat.severity or 0) * 20, 0, 20)
  score = score + clamp((controlThreat and controlThreat.chainCount or 0) * 4 +
      (controlThreat and controlThreat.chainLock or 0) * 2.2, 0, 20)
  score = score + clamp(((controlThreat and controlThreat.followUp or 0) / hpRef) * 20, 0, 16)

  score = score + clamp(((executionThreat and executionThreat.soon or 0) / hpRef) * 34, 0, 24)
  if executionThreat and executionThreat.lethalSoon then
    score = score + 18
  end
  score = score + clamp((uncertainty and uncertainty.bonus or 0) * 0.75, 0, 16)
  if roshanHit and roshanHit > 0 then
    score = score + clamp((roshanHit / hpRef) * 20, 0, 12)
  end
  if focusMode then
    score = score + 8
  end
  if curHP and sliderHP and curHP <= sliderHP then
    score = score + 6
  end

  local mode = "normal"
  if score >= 80 then
    mode = "ultra"
  elseif score >= 54 then
    mode = "safe"
  end
  local profile = RISK_MODE_PROFILES[mode] or RISK_MODE_PROFILES.normal
  return {
    score = score,
    mode = mode,
    safeMul = profile.safeMul or 1.0,
    extraBuffer = profile.extraBuffer or 0,
    thresholdBias = profile.thresholdBias or 0
  }
end

local function GetAbilityDamageProfile(ability, source, target)
  if not ability then return nil end
  local okLvl, lvl = pcall(Ability.GetLevel, ability)
  if not okLvl or not lvl or lvl <= 0 then return nil end
  local okName, name = pcall(Ability.GetName, ability)
  name = okName and name or "unknown_ability"

  local dtype = getDamageTypeString and getDamageTypeString(ability) or "unknown"
  local function safeSV(k)
    local ok, v = pcall(SV, ability, k)
    if not ok then return nil end
    if type(v) ~= "number" then return nil end
    if v ~= v then return nil end
    return v
  end

  local function addUnique(list, seen, key)
    if key and key ~= "" and not seen[key] then
      seen[key] = true
      list[#list + 1] = key
    end
  end

  local function splitTokens(str)
    local toks = {}
    for t in tostring(str):gmatch("[^_]+") do toks[#toks + 1] = t end
    return toks
  end

  local function buildNameRoots(abilityName)
    local toks = splitTokens(abilityName)
    local roots, seen = {}, {}
    local n = #toks
    local function add(s) addUnique(roots, seen, s) end
    add(abilityName)
    for _, t in ipairs(toks) do add(t) end
    if n >= 1 then add(toks[n]) end
    if n >= 2 then
      add(toks[n - 1] .. "_" .. toks[n])
      add(table.concat(toks, "_", 2, n))
    end
    if n >= 3 then
      add(table.concat(toks, "_", 3, n))
    end

    return roots
  end

  local roots = buildNameRoots(name)
  local staticNukeKeys = {
    "damage", "base_damage", "initial_damage", "impact_damage",
    "explode_damage", "explosion_damage", "blast_damage",
    "spell_damage", "hit_damage", "bonus_damage", "bolt_damage",
    "wave_damage", "max_damage", "min_damage", "nova_damage",
    "projectile_damage", "detonate_damage", "arrow_damage",
    "rocket_damage", "contact_damage", "splash_damage",
    "slash_damage", "shock_damage", "strike_damage",
    "tooltip_damage", "damage_max",
    "spark_damage_base", "target_damage"
  }

  local staticDpsKeys = {
    "damage_per_second", "damage_per_sec", "dps", "damage_pers",
    "burn_dps", "poison_dps", "dot_damage", "damage_over_time", "health_drain",
    "burn_damage", "poison_damage",
    "blade_fury_damage_per_second", "shrapnel_damage", "rot_damage",
    "ignite_damage_per_second", "liquid_fire_damage_per_second",
  }

  local staticPerTickKeys = {
    "damage_per_tick", "tick_damage", "damage_each_tick",
    "damage_tick", "dot_tick_damage", "burn_tick_damage"
  }

  local staticTickIntervalKeys = {
    "tick_interval", "interval", "think_interval",
    "pulse_interval", "dot_interval", "damage_interval",
    "burn_interval", "tick_rate"
  }

  local staticDurationKeys = {
    "duration", "debuff_duration", "burn_duration",
    "poison_duration", "damage_duration", "dot_duration",
  }

  local staticPctKeys = {
    "hp_damage_pct", "health_damage_pct", "damage_pct",
    "max_health_damage_pct", "current_health_pct",
    "current_health_damage_pct", "target_hp_damage_pct",
    "max_hp_damage_pct", "health_as_damage_pct", "hp_as_damage_pct",
  }

  local function buildDynamicKeys()
    local nuke, dps, perTick, tickInt, duration, pct = {}, {}, {}, {}, {}, {}
    local seen = {}

    local function addAllTo(list, arr)
      for _, k in ipairs(arr) do addUnique(list, seen, k) end
    end
    local nukeSuffixes = {
      "", "_base", "_initial", "_impact", "_strike", "_explode",
      "_explosion", "_blast", "_hit", "_bonus", "_bolt", "_wave",
      "_nova", "_spark", "_projectile", "_detonate", "_arrow",
      "_rocket", "_contact", "_splash",
    }

    local dpsSuffixes = {
      "_damage_per_second", "_damage_per_sec", "_dps",
      "_damage_over_time", "_dot_damage", "_burn_dps", "_poison_dps",
    }

    local perTickSuffixes = {
      "_damage_per_tick", "_tick_damage", "_damage_tick", "_each_tick_damage",
    }

    local tickSuffixes = {
      "_tick_interval", "_interval", "_think_interval", "_pulse_interval",
      "_dot_interval", "_damage_interval", "_burn_interval", "_tick",
    }

    local durationSuffixes = {
      "_duration", "_debuff_duration", "_burn_duration",
      "_poison_duration", "_damage_duration", "_dot_duration",
    }

    local pctSuffixes = {
      "_hp_damage_pct", "_health_damage_pct", "_damage_pct",
      "_max_health_damage_pct", "_current_health_pct",
      "_current_health_damage_pct", "_target_hp_damage_pct",
      "_max_hp_damage_pct", "_health_as_damage_pct", "_hp_as_damage_pct",
    }
    for _, r in ipairs(roots) do
      for _, suf in ipairs(nukeSuffixes) do
        addUnique(nuke, seen, r .. suf .. "_damage")
      end
      addUnique(nuke, seen, r .. "_base_damage")
      addUnique(nuke, seen, "damage_" .. r)
      addUnique(nuke, seen, "base_damage_" .. r)
      addUnique(nuke, seen, r .. "_tooltip_damage")
      for _, suf in ipairs(dpsSuffixes) do
        addUnique(dps, seen, r .. suf)
      end
      for _, suf in ipairs(perTickSuffixes) do
        addUnique(perTick, seen, r .. suf)
      end
      for _, suf in ipairs(tickSuffixes) do
        addUnique(tickInt, seen, r .. suf)
      end
      for _, suf in ipairs(durationSuffixes) do
        addUnique(duration, seen, r .. suf)
      end
      for _, suf in ipairs(pctSuffixes) do
        addUnique(pct, seen, r .. suf)
      end
    end

    return nuke, dps, perTick, tickInt, duration, pct
  end

  local dynNukeKeys, dynDpsKeys, dynPerTickKeys, dynTickKeys, dynDurationKeys, dynPctKeys = buildDynamicKeys()
  local allNukeKeys, seenN = {}, {}
  for _, k in ipairs(staticNukeKeys) do addUnique(allNukeKeys, seenN, k) end
  for _, k in ipairs(dynNukeKeys) do addUnique(allNukeKeys, seenN, k) end

  local allDpsKeys, seenD = {}, {}
  for _, k in ipairs(staticDpsKeys) do addUnique(allDpsKeys, seenD, k) end
  for _, k in ipairs(dynDpsKeys) do addUnique(allDpsKeys, seenD, k) end

  local allPerTickKeys, seenPT = {}, {}
  for _, k in ipairs(staticPerTickKeys) do addUnique(allPerTickKeys, seenPT, k) end
  for _, k in ipairs(dynPerTickKeys) do addUnique(allPerTickKeys, seenPT, k) end

  local allTickKeys, seenT = {}, {}
  for _, k in ipairs(staticTickIntervalKeys) do addUnique(allTickKeys, seenT, k) end
  for _, k in ipairs(dynTickKeys) do addUnique(allTickKeys, seenT, k) end

  local allDurationKeys, seenDur = {}, {}
  for _, k in ipairs(staticDurationKeys) do addUnique(allDurationKeys, seenDur, k) end
  for _, k in ipairs(dynDurationKeys) do addUnique(allDurationKeys, seenDur, k) end

  local allPctKeys, seenPct = {}, {}
  for _, k in ipairs(staticPctKeys) do addUnique(allPctKeys, seenPct, k) end
  for _, k in ipairs(dynPctKeys) do addUnique(allPctKeys, seenPct, k) end

  local nuke = 0
  local maxFromKey = nil
  for _, k in ipairs(allNukeKeys) do
    local v = safeSV(k)
    if v and v > nuke then
      nuke = v
      maxFromKey = k
    end
  end
  local dps = 0
  for _, k in ipairs(allDpsKeys) do
    local v = safeSV(k)
    if v and v > dps then dps = v end
  end

  local rawTick = select(1, GetAbilityTick(ability, name))
  local function resolveTick()
    local tick = rawTick
    if rawTick then
      for _, k in ipairs(allTickKeys) do
        local v = safeSV(k)
        if v and v > 0 then
          tick = (tick and math.min(tick, v)) or v
        end
      end
    end
    if tick == nil or tick == 0 then
      local duration = nil
      for _, k in ipairs(allDurationKeys) do
        local v = safeSV(k)
        if v and v > 0 then duration = math.max(duration or 0, v) end
      end
      local ticks = safeSV("ticks") or safeSV("num_ticks") or safeSV("num_pulses")
      if duration and ticks and ticks > 0 then
        tick = duration / ticks
      end
    end
    return tick
  end
  local perTick = nil
  for _, k in ipairs(allPerTickKeys) do
    local v = safeSV(k)
    if v and v > 0 then perTick = (perTick and math.max(perTick, v)) or v end
  end

  local tick = nil
  if perTick and perTick > 0 then
    tick = resolveTick()
    if tick and tick > 0 then
      dps = math.max(dps, perTick / tick)
    end
  else
    local hasDuration = false
    local duration = nil
    for _, k in ipairs(allDurationKeys) do
      local v = safeSV(k)
      if v and v > 0 then
        hasDuration = true; duration = (duration and math.max(duration, v)) or v
      end
    end
    local altTick = resolveTick()
    if (not perTick) and hasDuration and altTick and altTick > 0 and nuke > 0 then
      dps = math.max(dps, nuke / altTick)
      tick = altTick
      nuke = 0
    else
      tick = altTick
    end
  end
  if dps > 0 and not tick then
    tick = 1
  end
  local duration = nil
  for _, k in ipairs(allDurationKeys) do
    local v = safeSV(k)
    if v and v > 0 then duration = (duration and math.max(duration, v)) or v end
  end
  if duration == nil then
    local v = (safeSV("AbilityDuration"))
    if v and v > 0 then duration = (duration and math.max(duration, v)) or v end
  end

  local pct = 0
  for _, k in ipairs(allPctKeys) do
    local v = safeSV(k)
    if v and v > 0 then
      local p = v > 1 and (v / 100.0) or v
      if p > pct then pct = p end
    end
  end

  if nuke and nuke > 0 and duration and duration > 0 then
    dps = nuke
    if tick == nil then
      tick = 1
    end
  end
  if pct > 0 and target and Entity.GetHealth then
    nuke = nuke + (Entity.GetHealth(target) * pct)
  end
  if name == "viper_viper_strike" then
    tick = 1
    dps = math.max(dps, nuke)
    duration = 6
    nuke = 0
  end

  if (nuke <= 0) and (dps <= 0) then return nil end
  return {
    name = name,
    type = dtype,
    nuke = nuke,
    dps = dps,
    tick = tick,
    duration = duration,
    onHitDot = (dps or 0) > 0
  }
end

local function getAbilityProjectileSpeed(ability, name, caster)
  name = name or abilityName(ability) or ""
  if PROJECTILE_OVERRIDES[name] then return PROJECTILE_OVERRIDES[name], true end
  local spd = 0
  if Ability.GetProjectileSpeed then
    local ok, v = pcall(Ability.GetProjectileSpeed, ability)
    if ok and v and v > 0 then spd = v end
  end
  if spd <= 0 then
    for _, k in ipairs({ "projectile_speed", "bolt_speed", "arrow_speed", "missile_speed", "orb_speed", "speed" }) do
      local v = SV(ability, k); if type(v) == "number" and v > 0 then spd = math.max(spd, v) end
    end
  end
  if spd > 0 then return spd, true end
  return 0, false
end

local function estimateAttackDamage(attacker, target)
  if NPC.GetTrueDamage then
    local d = NPC.GetTrueDamage(attacker)
    if d and d > 0 then return d end
  end
  if NPC.GetDamage then
    local d = NPC.GetDamage(attacker)
    if d and d > 0 then return d end
  end
  if NPC.GetTotalDamage then
    local d = NPC.GetTotalDamage(attacker)
    if d and d > 0 then return d end
  end
  if NPC.GetMinDamage and NPC.GetMaxDamage then
    local mn = NPC.GetMinDamage(attacker) or 0
    local mx = NPC.GetMaxDamage(attacker) or mn
    return (mn + mx) * 0.5
  end
  return 50
end

local function getAttackProjectileSpeed(attacker)
  if not attacker then return 0 end
  if NPC.GetProjectileSpeed then
    local ok, v = pcall(NPC.GetProjectileSpeed, attacker)
    if ok and v and v > 0 then return v end
  end
  if NPC.GetAttackProjectileSpeed then
    local ok, v = pcall(NPC.GetAttackProjectileSpeed, attacker)
    if ok and v and v > 0 then return v end
  end
  return 0
end

local function getAttackInterval(unit)
  if not unit then return 1.6 end
  if NPC and NPC.GetSecondsPerAttack then
    local ok, v = pcall(NPC.GetSecondsPerAttack, unit)
    if ok and type(v) == "number" and v > 0 then
      return clamp(v, C.PREDICT_ATTACK_MIN_INTERVAL, C.PREDICT_ATTACK_MAX_INTERVAL)
    end
  end
  if NPC and NPC.GetAttackTime then
    local ok, v = pcall(NPC.GetAttackTime, unit)
    if ok and type(v) == "number" and v > 0 then
      return clamp(v, C.PREDICT_ATTACK_MIN_INTERVAL, C.PREDICT_ATTACK_MAX_INTERVAL)
    end
  end
  if NPC and NPC.GetAttacksPerSecond then
    local ok, aps = pcall(NPC.GetAttacksPerSecond, unit)
    if ok and type(aps) == "number" and aps > 0.01 then
      return clamp(1.0 / aps, C.PREDICT_ATTACK_MIN_INTERVAL, C.PREDICT_ATTACK_MAX_INTERVAL)
    end
  end
  return 1.6
end

local function getCadenceMemoryStore()
  if type(THREAT.lastEventPulse) ~= "table" then return nil end
  if type(THREAT.lastEventPulse.srcCadence) ~= "table" then
    THREAT.lastEventPulse.srcCadence = {}
  end
  return THREAT.lastEventPulse.srcCadence
end

local function pruneCadenceMemory(now)
  local store = getCadenceMemoryStore()
  if not store then return end
  local t = now or nowTime()
  for key, rec in pairs(store) do
    if not rec then
      store[key] = nil
    else
      local lastSeen = rec.ts or rec.last or 0
      if (t - lastSeen) > 8.0 then
        store[key] = nil
      end
    end
  end
end

local function updateAttackCadenceMemory(src, hitAt)
  if not src or not hitAt then return end
  local store = getCadenceMemoryStore()
  if not store then return end
  local key = tostring(src)
  local rec = store[key]
  if not rec then
    store[key] = { last = hitAt, ts = nowTime(), hits = 1, interval = nil, lastUpdate = hitAt }
    return
  end
  if rec.lastUpdate and math.abs((rec.lastUpdate or 0) - hitAt) <= 0.02 then
    rec.ts = nowTime()
    return
  end
  local delta = hitAt - (rec.last or hitAt)
  rec.last = hitAt
  rec.lastUpdate = hitAt
  rec.ts = nowTime()
  rec.hits = (rec.hits or 0) + 1
  if delta > (C.PREDICT_ATTACK_MIN_INTERVAL * 0.45) and delta < (C.PREDICT_ATTACK_MAX_INTERVAL * 1.15) then
    if rec.interval then
      rec.interval = rec.interval * 0.65 + delta * 0.35
    else
      rec.interval = delta
    end
    rec.interval = clamp(rec.interval, C.PREDICT_ATTACK_MIN_INTERVAL, C.PREDICT_ATTACK_MAX_INTERVAL)
  end
end

local function resolveAttackIntervalForSource(src)
  local base = getAttackInterval(src)
  local store = getCadenceMemoryStore()
  if not store then return base end
  local rec = store[tostring(src)]
  if not rec or not rec.interval then return base end
  local hits = rec.hits or 1
  local weight = clamp(hits / 6.0, 0.20, 0.78)
  local blended = base * (1.0 - weight) + rec.interval * weight
  return clamp(blended, C.PREDICT_ATTACK_MIN_INTERVAL, C.PREDICT_ATTACK_MAX_INTERVAL)
end

local function fallbackProjectileTime(source, target)
  local srcPos = Entity.GetAbsOrigin(source)
  local dstPos = Entity.GetAbsOrigin(target)
  local dist = vecDist(dstPos, srcPos)
  local spd = getAttackProjectileSpeed(source)
  if not spd or spd <= 0 then spd = 1100 end
  spd = clamp(spd, C.FALLBACK_MIN_PROJ_SPEED, C.FALLBACK_MAX_PROJ_SPEED)
  return (dist / spd) + 0.03
end

local function addIncoming(dmg, hitTime, src, tag, abilName_, isFallback, cp, meta)
  if not dmg or dmg <= 0 or not hitTime then return end
  table.insert(THREAT.incomingProjectiles,
    {
      expire = hitTime,
      dmg = dmg,
      src = src,
      tag = tag,
      abilName = abilName_,
      isFallback = isFallback,
      cp = cp,
      meta = meta
    })
end
local function upsertMeleeHit(attacker, hitAt, dmg)
  for i = #THREAT.incomingProjectiles, 1, -1 do
    local p = THREAT.incomingProjectiles[i]
    if p.src == attacker and p.tag == "melee" and math.abs((p.expire or 0) - hitAt) <= 0.3 then
      p.expire = hitAt
      p.dmg = dmg
      return
    end
  end
  if not shouldTrackSource(attacker) then return end
  addIncoming(dmg, hitAt, attacker, "melee", nil, false, nil)
  THREAT.counter.melee = THREAT.counter.melee + 1
end
local function removeAbilityFallbacks(source, abilityName)
  for i = #THREAT.incomingProjectiles, 1, -1 do
    local p = THREAT.incomingProjectiles[i]
    if p.src == source and p.isFallback and p.abilName == abilityName then table.remove(THREAT.incomingProjectiles, i) end
  end
  local tnow = nowTime()
  for k, st in pairs(THREAT.dotStates) do
    if st.isFallback and st.label == abilityName and (not st.endAt or st.endAt > tnow) then THREAT.dotStates[k] = nil end
  end
end

local function removeExecutionFallbacks(source, abilityName)
  for i = #THREAT.incomingProjectiles, 1, -1 do
    local p = THREAT.incomingProjectiles[i]
    if p.src == source and p.isFallback and p.tag == "execute" and p.abilName == abilityName then
      table.remove(THREAT.incomingProjectiles, i)
    end
  end
end

function script.OnProjectile(data)
  if not uiBool(Switch, true) then return end
  if not hero or not isAlive(hero) then return end
  if not data or data.target ~= hero then return end
  local source = data.source
  if not source or not isEnemy(source) then return end
  if not shouldTrackSource(source) then return end

  local srcPos    = (data.origin or data.startPos or data.position) or Entity.GetAbsOrigin(source)
  local dstPos    = Entity.GetAbsOrigin(hero)
  local spd       = data.moveSpeed or data.speed or 0
  local dist      = vecDist(dstPos, srcPos)
  local timeToHit = spd > 0 and (dist / spd) or fallbackProjectileTime(source, hero)
  local hitAt     = nowTime() + timeToHit

  local ability   = data.ability
  if not ability and NPC.GetAbilityByActivity and data.activity then
    ability = NPC.GetAbilityByActivity(source, data.activity)
  end
  local aName = abilityName(ability)
  local isAttack = (data.isAttack == true) or (ability == nil)

  if not isAttack and ability then
    removeAbilityFallbacks(source, aName or "ability")
    removeExecutionFallbacks(source, aName or "ability")
    local exec = estimateExecutionThreat(aName, ability, source, hero)
    if exec and exec.dmg and exec.dmg > 0 then
      addIncoming(exec.dmg, hitAt, source, "execute", aName or "execute", false, nil, { execLethal = exec.lethalSoon == true })
    end
    local prof = GetAbilityDamageProfile(ability, source, hero)
    if prof then
      if prof.nuke and prof.nuke > 0 then
        local dmg = applyResists(hero, prof.nuke, prof.type)
        addIncoming(dmg, hitAt, source, "ability", aName, false, nil)
        THREAT.counter.projAbility = THREAT.counter.projAbility + 1
      end
      if prof.dps and prof.dps > 0 then
        local stTick = safeTick(prof.tick, 0.5)
        local key = "auto_dot:" .. (aName or "ability") .. "#" .. tostring(math.floor(hitAt * 1000))
        THREAT.dotStates[key] = {
          dps = prof.dps,
          tick = stTick,
          type = prof.type or "magical",
          label = aName or "DoT",
          active = true,
          createdAt = hitAt,
          nextTickAt = hitAt + stTick,
          endAt = (prof.duration and (hitAt + prof.duration)) or (hitAt + 3.0),
          src = "sched",
          owner = source,
          isFallback = false
        }
      end
    end
  else
    for i = #THREAT.incomingProjectiles, 1, -1 do
      local p = THREAT.incomingProjectiles[i]
      if p.src == source and p.isFallback and p.tag == "atk_fallback" and math.abs((p.expire or 0) - hitAt) <= 0.20 then
        table.remove(THREAT.incomingProjectiles, i)
        break
      end
    end
    local raw = estimateAttackDamage(source, hero)
    local dmg = applyResists(hero, raw, "physical")
    addIncoming(dmg, hitAt, source, "attack", nil, false, nil)
    THREAT.counter.projAttacks = THREAT.counter.projAttacks + 1
  end
end

local function safeCall(fn, ...)
  if not fn then return false, nil end
  local ok, res = pcall(fn, ...)
  if not ok then return false, nil end
  return true, res
end

local KNOWN_DOT_NAME_HINTS = { rot = true, shrapnel = true, poison = true, burn = true, ignite = true, liquid_fire = true, viper = true, venom = true, acid = true, napalm = true, radiance = true, plague = true }
local function buildModKey(mname, abil, caster)
  local n = (mname and mname ~= "" and mname) or "DoT"
  local a = abil and tostring(abil) or "nil"
  local c = caster and tostring(caster) or "nil"
  return "mod_dot:" .. n .. ":" .. c .. ":" .. a
end
local function looksLikeDotMod(name)
  if not name then return false end
  local n = name:lower()
  for key, _ in pairs(KNOWN_DOT_NAME_HINTS) do if n:find(key, 1, true) then return true end end
  return false
end
local BLADE_MAIL_ACTIVE_MODS = {
  modifier_item_blade_mail_reflect = true,
  modifier_item_blade_mail_active = true
}
local STACKING_REFLECT_DOT_HINTS = {
  burning_spear = true,
  spear = true,
  napalm = true
}
local DOT_MODIFIERS = {
  { name = "modifier_venomancer_poison_nova", damage_key = "damage", tick = 1.0, dtype = "magical" },
  { name = "modifier_venomancer_venomous_gale", damage_key = "tick_damage", tick = 3.0, dtype = "magical" },
  { name = "modifier_venomancer_poison_sting_debuff", damage_key = "damage", tick = 1.0, dtype = "magical" },
  { name = "modifier_doom_bringer_doom", damage_key = "damage", tick = 1.0, dtype = "pure" },
  { name = "modifier_queenofpain_shadow_strike", damage_key = "duration_damage", tick = 3.0, dtype = "magical" },
  { name = "modifier_huskar_burning_spear_debuff", flat_damage = 5, tick = 1.0, dtype = "magical", stacks = true },
  { name = "modifier_jakiro_liquid_fire_burn", damage_key = "damage", tick = 1.0, dtype = "magical" },
  { name = "modifier_viper_viper_strike_slow", damage_key = "damage", tick = 1.0, dtype = "magical" },
  { name = "modifier_viper_poison_attack_slow", damage_key = "damage", tick = 1.0, dtype = "magical" },
  { name = "modifier_phoenix_fire_spirit_burn", damage_key = "damage_per_second", tick = 1.0, dtype = "magical" },
  { name = "modifier_ogre_magi_ignite", damage_key = "damage_per_second", tick = 1.0, dtype = "magical" },
  { name = "modifier_batrider_firefly", damage_key = "damage_per_second", tick = 1.0, dtype = "magical" },
  { name = "modifier_pudge_rot", damage_key = "rot_damage", tick = 1.0, dtype = "magical" },
  { name = "modifier_disruptor_thunder_strike", damage_key = "strike_damage", tick = 2.0, dtype = "magical" },
  { name = "modifier_warlock_shadow_word", damage_key = "damage", tick = 1.0, dtype = "magical" },
  { name = "modifier_leshrac_pulse_nova", damage_key = "damage", tick = 1.0, dtype = "magical" },
  { name = "modifier_urn_damage", flat_damage = 25, tick = 1.0, dtype = "pure" },
  { name = "modifier_item_spirit_vessel_damage", flat_damage = 35, tick = 1.0, dtype = "magical" },
  { name = "modifier_radiance_debuff", flat_damage = 60, tick = 1.0, dtype = "magical" },
  { name = "modifier_ember_spirit_flame_guard", damage_key = "dps", tick = 1.0, dtype = "magical" },
  { name = "modifier_silencer_curse_of_the_silent", damage_key = "damage", tick = 1.0, dtype = "magical" },
  { name = "modifier_sandking_caustic_finale", damage_key = "damage", tick = 1.0, dtype = "magical" },
}
local function looksLikeBladeMailActiveMod(name)
  if not name or name == "" then return false end
  local n = tostring(name):lower()
  if BLADE_MAIL_ACTIVE_MODS[n] then return true end
  return n:find("blade_mail", 1, true) ~= nil and (n:find("reflect", 1, true) ~= nil or n:find("active", 1, true) ~= nil)
end
local function hasBladeMailReflect(unit)
  if not unit then return false end
  if NPC and NPC.HasModifier then
    for modName, _ in pairs(BLADE_MAIL_ACTIVE_MODS) do
      local ok, has = pcall(NPC.HasModifier, unit, modName)
      if ok and has then return true end
    end
  end
  local okMods, mods = safeCall(NPC.GetModifiers, unit)
  if okMods and type(mods) == "table" then
    for i = 1, #mods do
      local m = mods[i]
      if m then
        local _, mname = safeCall(Modifier.GetName, m)
        if looksLikeBladeMailActiveMod(mname) then return true end
      end
    end
  end
  return false
end
local function getBladeMailReflectMultiplier(unit)
  local pct = nil
  local item = nil
  if NPC and NPC.GetItem then
    local okItem, found = pcall(NPC.GetItem, unit, "item_blade_mail", false)
    if okItem then item = found end
  end
  if not item and NPC and NPC.GetItemByName then
    local okItem, found = pcall(NPC.GetItemByName, unit, "item_blade_mail")
    if okItem then item = found end
  end
  if item then
    local raw = SVAny(item,
      { "active_damage_reflection_pct", "active_damage_return", "damage_reflection_pct", "reflection_damage_pct",
        "return_damage_pct", "damage_return" }, nil)
    if type(raw) == "number" and raw > 0 then
      pct = raw > 1 and (raw / 100.0) or raw
    end
  end
  return clamp(pct or 0.85, 0.25, 1.50)
end
local function shouldApplyStackMultiplier(modName)
  if not modName then return false end
  local n = tostring(modName):lower()
  for hint, _ in pairs(STACKING_REFLECT_DOT_HINTS) do
    if n:find(hint, 1, true) then return true end
  end
  return false
end
local function buildReflectModKey(enemy, modName, ability)
  return "reflect_dot:" .. tostring(enemy) .. ":" .. tostring(modName or "dot") .. ":" .. tostring(ability or "nil")
end
local function scanBladeMailReflectDots()
  if not hero or not Heroes or not Heroes.GetAll then return end
  for k, st in pairs(THREAT.dotStates) do if st.src == "reflect" then st.active = false end end

  local okAll, all = pcall(Heroes.GetAll)
  if not okAll or type(all) ~= "table" then return end
  local t = nowTime()
  for i = 1, #all do
    local enemy = all[i]
    if enemy and isAlive(enemy) and isEnemy(enemy) and hasBladeMailReflect(enemy) then
      local reflectMul = getBladeMailReflectMultiplier(enemy)
      local okMods, mods = safeCall(NPC.GetModifiers, enemy)
      if okMods and type(mods) == "table" then
        for j = 1, #mods do
          local m = mods[j]
          if m then
            local _, isDeb = safeCall(Modifier.IsDebuff, m); isDeb = isDeb or false
            local _, caster = safeCall(Modifier.GetCaster, m)
            if isDeb and caster == hero then
              local _, modName = safeCall(Modifier.GetName, m); modName = modName or ""
              local _, abil = safeCall(Modifier.GetAbility, m)
              local abilName_ = abilityName(abil)
              local isLikelyDot = looksLikeDotMod(modName) or looksLikeDotMod(abilName_ or "")
              if not isLikelyDot then goto continue_reflect end
              local okProf, prof = pcall(GetAbilityDamageProfile, abil, hero, enemy)
              if okProf and prof and (prof.dps or 0) > 0 then
                local tick = safeTick(prof.tick, 0.5)
                local _, stacks = safeCall(Modifier.GetStackCount, m)
                local stackMul = 1
                if stacks and stacks > 1 and shouldApplyStackMultiplier(modName) then
                  stackMul = math.max(1, math.min(stacks, 12))
                end
                local scaled = (prof.dps or 0) * reflectMul * stackMul
                local nextAt = t + tick
                local endAt = t + (prof.duration or 2.0)
                local okDur, dur = safeCall(Modifier.GetDuration, m)
                local okRem, rem = safeCall(Modifier.GetRemainingTime, m)
                if okDur and okRem and dur and rem then
                  local el = math.max(0, dur - rem)
                  local f = el - math.floor(el / tick) * tick
                  nextAt = t + math.max(0.02, tick - f)
                  endAt = t + rem
                end
                local baseLabel = (abilName_ and abilName_ ~= "") and abilName_ or ((modName ~= "" and modName) or "DOT")
                local label = "BM Reflect " .. baseLabel
                if stackMul > 1 then
                  label = label .. " x" .. tostring(stackMul)
                end
                local key = buildReflectModKey(enemy, modName ~= "" and modName or baseLabel, abil)
                local st = THREAT.dotStates[key]
                if not st then
                  THREAT.dotStates[key] = {
                    dps = scaled,
                    tick = tick,
                    type = prof.type or "magical",
                    label = label,
                    active = true,
                    createdAt = t,
                    nextTickAt = nextAt,
                    endAt = endAt,
                    src = "reflect",
                    owner = enemy,
                    caster = enemy,
                    reflect = true,
                    isFallback = false
                  }
                else
                  st.dps = scaled; st.tick = tick; st.type = prof.type or "magical"; st.label = label; st.active = true; st.endAt =
                      endAt; st.owner = enemy; st.caster = enemy; st.reflect = true
                end
              end
            end
            ::continue_reflect::
          end
        end
      end
    end
  end
  local t2 = nowTime()
  for k, st in pairs(THREAT.dotStates) do
    if st.src == "reflect" and ((not st.active) or (st.endAt and st.endAt <= t2)) then
      THREAT.dotStates[k] = nil
    end
  end
end
local function inferDotOwnerFromKey(key)
  if not key or key == "" or not Heroes or not Heroes.GetAll then return nil end
  local okAll, all = pcall(Heroes.GetAll)
  if not okAll or type(all) ~= "table" then return nil end
  local k = tostring(key)
  for i = 1, #all do
    local h = all[i]
    if h and isEnemyHero(h) then
      local token = tostring(h)
      if token ~= "" and k:find(token, 1, true) then
        return h
      end
    end
  end
  return nil
end
local function resolveDotOwner(st, key)
  if not st then return nil end
  if st.owner and isEnemyHero(st.owner) then return st.owner end
  if st.caster and isEnemyHero(st.caster) then
    st.owner = st.caster
    return st.owner
  end
  if st.src and isEnemyHero(st.src) then
    st.owner = st.src
    return st.owner
  end
  local inferred = inferDotOwnerFromKey(key)
  if inferred then
    st.owner = inferred
    return inferred
  end
  return nil
end

local function scanDebuffDots()
  if not hero or not NPC.GetModifiers then return end
  for k, st in pairs(THREAT.dotStates) do if st.src == "mod" then st.active = false end end
  local okMods, mods = safeCall(NPC.GetModifiers, hero); if not okMods or type(mods) ~= "table" then return end
  local t = nowTime()
  for i = 1, #mods do
    local m = mods[i]
    if m then
      local _, mname = safeCall(Modifier.GetName, m); mname = mname or ""
      local _, abil  = safeCall(Modifier.GetAbility, m)
      local _, isDeb = safeCall(Modifier.IsDebuff, m); isDeb = isDeb or false
      if (abil and isDeb) or looksLikeDotMod(mname) then
        local _, caster = safeCall(Modifier.GetCaster, m)
        if caster == hero then goto continue end
        local okProf, prof = nil, nil
        for j = 1, #DOT_MODIFIERS do
          local info = DOT_MODIFIERS[j]
          if info.name == mname then
            local tickDmg = info.flat_damage or 0
            if info.damage_key and abil then local v = SV(abil, info.damage_key); if v and v > 0 then tickDmg = v end end
            if info.stacks and Modifier and Modifier.GetStackCount then local okSt, n = pcall(Modifier.GetStackCount, m); if okSt and n and n > 0 then tickDmg = tickDmg * n end end
            if tickDmg > 0 then prof = { dps = tickDmg / (info.tick or 1), tick = info.tick or 1, type = info.dtype or "magical" }; okProf = true end
            break
          end
        end
        if not okProf then okProf, prof = pcall(GetAbilityDamageProfile, abil, caster, hero) end
        local mnameLower = (mname or ""):lower()
        if not okProf and (mnameLower:find("burning_spear", 1, true) or mnameLower:find("huskar_burning", 1, true)) then
          local stacks = 1
          if Modifier and Modifier.GetStackCount then local okSt, n = pcall(Modifier.GetStackCount, m); if okSt and n and n > 0 then stacks = n end end
          prof = { dps = 5 * stacks, tick = 1.0, type = "magical" }; okProf = true
        end
        if okProf and prof and (prof.dps or 0) > 0 then
          local tick       = safeTick(prof.tick, 0.5)
          local nextAt     = t + tick
          local endAt      = t + (prof.duration or 3.0)
          local okDur, dur = safeCall(Modifier.GetDuration, m)
          local okRem, rem = safeCall(Modifier.GetRemainingTime, m)
          if okDur and okRem and dur and rem then
            local el = math.max(0, dur - rem)
            local f  = el - math.floor(el / tick) * tick
            nextAt   = t + math.max(0.02, tick - f)
            endAt    = t + rem
          end
          local label = abilityName(abil) or (mname ~= "" and mname) or "DoT"
          local key = buildModKey(mname, abil, caster)
          local st = THREAT.dotStates[key]
          if not st then
            THREAT.dotStates[key] = {
              dps = prof.dps,
              tick = tick,
              type = prof.type or "magical",
              label = label,
              active = true,
              createdAt = t,
              nextTickAt = nextAt,
              endAt = endAt,
              src = "mod",
              owner = caster,
              caster = caster,
              isFallback = false
            }
          else
            st.dps = prof.dps; st.tick = tick; st.type = prof.type or "magical"; st.label = label; st.active = true; st.endAt = endAt; st.nextTickAt = nextAt; st.owner = caster; st.caster = caster
          end
        end
      end
      ::continue::
    end
  end
  local t2 = nowTime()
  for k, st in pairs(THREAT.dotStates) do if st.src == "mod" and ((not st.active) or (st.endAt and st.endAt <= t2)) then THREAT.dotStates[k] = nil end end
end

local function getAttackRange(attacker)
  local r = 0
  if NPC.GetAttackRange then r = (NPC.GetAttackRange(attacker) or 0) end
  if NPC.GetHullRadius then r = r + (NPC.GetHullRadius(attacker) or 0) end
  return r > 0 and r or 150
end
local function isRanged(attacker) return NPC.IsRanged and NPC.IsRanged(attacker) end

local function findFacingEnemy(attacker, range, angle)
  if NPC.FindFacing then
    local enemyTeam = Enum and Enum.TeamType and (Enum.TeamType.TEAM_ENEMY or Enum.TeamType.ENEMY)
    if enemyTeam then
      local ok, target = pcall(NPC.FindFacing, attacker, enemyTeam, range, angle or 90, {})
      if ok and target then return target end
    end
  end
  if NPC.FindFacingNPC then
    local ok, target = pcall(NPC.FindFacingNPC, attacker)
    if ok and target and isEnemy(target) then return target end
  end
  return nil
end

local function findFacingTargetForAbility(caster, abil)
  local castRange = 800
  if Ability.GetCastRange then
    local ok, value = pcall(Ability.GetCastRange, abil)
    if ok and value and value > 0 then castRange = value end
  end
  return findFacingEnemy(caster, castRange, 90)
end
local function findFacingTargetForMelee(attacker)
  return findFacingEnemy(attacker, getAttackRange(attacker) + 100, 90)
end
local function pushAnimLog(text, r, g, b)
  table.insert(PLAN.recentAnimLog, { time = nowTime(), text = text, r = r or 200, g = g or 200, b = b or 200 })
  if #PLAN.recentAnimLog > 8 then table.remove(PLAN.recentAnimLog, 1) end
end
local function getAttackPoint(attacker)
  if NPC.GetAttackAnimationPoint then
    local ap = NPC.GetAttackAnimationPoint(attacker) or 0
    if ap > 0 then return ap end
  end
  if NPC.GetAttackAnimPoint then
    local ap = NPC.GetAttackAnimPoint(attacker) or 0
    if ap > 0 then return ap end
  end
  if NPC.GetAttackPoint then
    local ap = NPC.GetAttackPoint(attacker) or 0
    if ap > 0 then return ap end
  end
  return 0.30
end

local function handleAnimationEvent(unit, sequenceName, castpoint, playbackRate, lagComp, activity)
  if not unit or not isAlive(unit) or not isEnemy(unit) then return end
  local seq = tostring(sequenceName or ""):upper()
  local dedupKey = tostring(unit) .. ":" .. seq
  local tnow = nowTime()
  if PLAN.lastAnimDedup[dedupKey] and (tnow - PLAN.lastAnimDedup[dedupKey]) < 0.05 then return end
  PLAN.lastAnimDedup[dedupKey] = tnow

  local cp = castpoint
  if not cp or cp <= 0 then cp = getAttackPoint(unit) end
  local pr = playbackRate or 1.0
  local lc = lagComp or 0
  local dt = math.max(0.06, (cp / math.max(0.05, pr)) - lc)

  local abil = NPC.GetAbilityByActivity and NPC.GetAbilityByActivity(unit, activity) or nil
  local aName = abilityName(abil)
  if seq:find("ATTACK", 1, true) then
    local target = findFacingTargetForMelee(unit)
    local roshanClose = isRoshan(unit) and
        (vecDist(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(hero)) <= (getAttackRange(unit) + 90))
    if target == hero or roshanClose then
      if shouldTrackSource(unit) then
        if isRanged(unit) then
          local dist = vecDist(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(hero))
          local spd = getAttackProjectileSpeed(unit)
          if not spd or spd <= 0 then spd = 1100 end
          spd         = clamp(spd, C.FALLBACK_MIN_PROJ_SPEED, C.FALLBACK_MAX_PROJ_SPEED)
          local raw   = estimateAttackDamage(unit, hero)
          local dmg   = applyResists(hero, raw, "physical")
          local hitAt = tnow + dt + (dist / math.max(1, spd)) + 0.03
          addIncoming(dmg, hitAt, unit, "atk_fallback", nil, true, cp)
          THREAT.counter.fbAttacks = THREAT.counter.fbAttacks + 1
          pushAnimLog(string.format("ATTACK (ranged-fallback) %.2fs dmg~%.0f", hitAt - tnow, dmg), 200, 180, 120)
        else
          local inRange = vecDist(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(hero)) <= (getAttackRange(unit) + 60)
          if inRange then
            local raw = estimateAttackDamage(unit, hero)
            local dmg = applyResists(hero, raw, "physical")
            local hitAt = tnow + dt
            upsertMeleeHit(unit, hitAt, dmg)
            pushAnimLog(string.format("ATTACK (melee) %.2fs dmg~%.0f", hitAt - tnow, dmg), 255, 140, 90)
          end
        end
      end
    end
    return
  end

  if abil and Ability.GetLevel and Ability.GetLevel(abil) > 0 then
    local target = findFacingTargetForAbility(unit, abil)
    local willHitHero = false
    local radius = getAbilityRadius(abil)
    if target == hero then
      willHitHero = true
    elseif radius > 0 then
      local dist = vecDist(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(hero))
      if dist <= radius + 80 then willHitHero = true end
    end

    if willHitHero then
      if shouldTrackSource(unit) then
        local spd, isProj = getAbilityProjectileSpeed(abil, aName, unit)
        local controlSeverity, controlLock = getDisableThreatProfile(aName)
        if controlSeverity then
          local controlAt = tnow + dt
          if isProj then
            local d = vecDist(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(hero))
            local travel = (spd > 0) and (d / spd) or 0.25
            controlAt = controlAt + travel + 0.03
          end
          addIncomingControl(unit, aName or "control", controlAt, cp, controlSeverity, controlLock)
        end

        local hitAt = tnow + dt
        if isProj then
          local d = vecDist(Entity.GetAbsOrigin(unit), Entity.GetAbsOrigin(hero))
          local travel = (spd > 0) and (d / spd) or 0.25
          hitAt = hitAt + travel + 0.03
        end
        local exec = estimateExecutionThreat(aName, abil, unit, hero)
        if exec and exec.dmg and exec.dmg > 0 then
          addIncoming(exec.dmg, hitAt, unit, "execute", aName or "execute", true, cp, { execLethal = exec.lethalSoon == true })
          pushAnimLog(string.format("%s (execute) %.2fs dmg~%.0f", aName or "EXEC", hitAt - tnow, exec.dmg), 255, 130, 130)
        end

        local prof = GetAbilityDamageProfile(abil, unit, hero)
      if prof then
        if isProj then
          if prof.nuke and prof.nuke > 0 then
            local dmg = applyResists(hero, prof.nuke, prof.type)
            addIncoming(dmg, hitAt, unit, "abil_fallback", aName or "ability", true, cp)
            THREAT.counter.fbAbility = THREAT.counter.fbAbility + 1
            pushAnimLog(string.format("%s (fallback proj) %.2fs dmg~%.0f", aName or "ABILITY", hitAt - tnow, dmg), 240,
              190, 60)
          end
          if prof.dps and prof.dps > 0 then
            local keyDot = "fb_castdot:" ..
                tostring(unit) .. ":" .. (aName or "ability") .. ":" .. string.format("%.3f", hitAt)
            local stTick = safeTick(prof.tick, 0.5)
            THREAT.dotStates[keyDot] = {
              dps = prof.dps,
              tick = stTick,
              type = prof.type or "magical",
              label = aName or "DoT",
              active = true,
              createdAt = hitAt,
              nextTickAt = hitAt + stTick,
              endAt = (prof.duration and (hitAt + prof.duration)) or (hitAt + 3.0),
              src = "sched",
              owner = unit,
              isFallback = true
            }
            pushAnimLog(string.format("%s DoT (fallback) dps=%.0f tick=%.2f", aName or "DoT", prof.dps, stTick), 170, 120,
              255)
          end
        else
          if prof.nuke and prof.nuke > 0 then
            local dmg = applyResists(hero, prof.nuke, prof.type)
            local key = "cast:" .. tostring(unit) .. ":" .. (aName or "ability") .. ":" .. string.format("%.3f", hitAt)
            THREAT.castWindups[key] = { hitAt = hitAt, dmg = dmg, src = unit, ability = abil, label = aName or "cast", cp = cp }
            pushAnimLog(string.format("%s (nuke) %.2fs dmg~%.0f", aName or "ABILITY", hitAt - tnow, dmg), 240, 190, 60)
          end
          if prof.dps and prof.dps > 0 then
            local keyDot = "castdot:" ..
                tostring(unit) .. ":" .. (aName or "ability") .. ":" .. string.format("%.3f", hitAt)
            local stTick = safeTick(prof.tick, 0.5)
            THREAT.dotStates[keyDot] = {
              dps = prof.dps,
              tick = stTick,
              type = prof.type or "magical",
              label = aName or "DoT",
              active = true,
              createdAt = hitAt,
              nextTickAt = hitAt + stTick,
              endAt = (prof.duration and (hitAt + prof.duration)) or (hitAt + 3.0),
              src = "sched",
              owner = unit,
              isFallback = false
            }
            pushAnimLog(string.format("%s DoT start: dps=%.0f tick=%.2f", aName or "DoT", prof.dps, stTick), 170, 120,
              255)
          end
        end
      end
      end
    end
  end
end

local function hasNearbyAttackEvent(events, src, tAt, eps)
  local margin = eps or 0.08
  for i = 1, #events do
    local ev = events[i]
    if ev.src == src and (ev.type == "attack" or ev.type == "atk_fallback" or ev.type == "melee") then
      if math.abs((ev.time or 0) - tAt) <= margin then
        return true
      end
    end
  end
  return false
end

local function injectPredictedAttackCadence(events, tnow, window)
  local firstAttackBySource = {}
  local untilT = tnow + window
  pruneCadenceMemory(tnow)
  for i = 1, #events do
    local ev = events[i]
    if ev.time > untilT then break end
    if ev.src and (ev.type == "attack" or ev.type == "atk_fallback" or ev.type == "melee") then
      local key = tostring(ev.src)
      local prev = firstAttackBySource[key]
      if not prev or ev.time < prev.time then
        firstAttackBySource[key] = { src = ev.src, time = ev.time }
      end
    end
  end

  local predicted = 0
  for _, info in pairs(firstAttackBySource) do
    local src = info.src
    if src and isAlive(src) and (isEnemyHero(src) or isRoshan(src)) then
      if (NPC.IsStunned and NPC.IsStunned(src)) or (NPC.IsDisarmed and NPC.IsDisarmed(src)) then
        goto continue_predict_attack
      end
      local interval = resolveAttackIntervalForSource(src)
      local raw = estimateAttackDamage(src, hero)
      local dmg = applyResists(hero, raw, "physical")
      if dmg > 0 then
        local at = (info.time or tnow) + interval
        local produced = 0
        while at <= untilT and produced < C.PREDICT_ATTACK_MAX_PER_SOURCE do
          if not hasNearbyAttackEvent(events, src, at, 0.08) then
            events[#events + 1] = {
              time = at,
              dmg = dmg,
              type = "atk_fallback",
              label = "atk_chain",
              cp = nil,
              src = src,
              fb = true,
              pred = true
            }
            predicted = predicted + 1
          end
          at = at + interval
          produced = produced + 1
        end
      end
    end
    ::continue_predict_attack::
  end

  return predicted
end

local function collectEvents(window)
  local tnow = nowTime()
  local events = {}

  for i = #THREAT.incomingProjectiles, 1, -1 do
    local p = THREAT.incomingProjectiles[i]
    if p.expire <= tnow + window and p.expire >= tnow - 0.01 then
      local tag = p.tag or "hit"
      local label = (tag == "ability" or tag == "abil_fallback" or tag == "execute") and (p.abilName or tag) or tag
      table.insert(events, {
        time = p.expire,
        dmg = p.dmg,
        type = tag,
        label = label,
        cp = p.cp,
        src = p.src,
        fb = p.isFallback,
        execLethal = p.meta and p.meta.execLethal or false
      })
    elseif p.expire < tnow - 0.01 then
      table.remove(THREAT.incomingProjectiles, i)
    end
  end

  for key, w in pairs(THREAT.castWindups) do
    if w.hitAt <= tnow + window and w.hitAt >= tnow - 0.01 then
      table.insert(events,
        { time = w.hitAt, dmg = w.dmg, type = "cast", label = w.label or "cast", cp = w.cp, src = w.src, fb = false })
    elseif w.hitAt < tnow - 0.01 then
      THREAT.castWindups[key] = nil
    end
  end

  for key, st in pairs(THREAT.dotStates) do
    if not st.endAt or st.endAt > tnow then
      local tickInt = safeTick(st.tick, 0.5)
      local tickTime = st.nextTickAt
      if not tickTime then
        if st.createdAt and st.createdAt < tnow then
          local elapsed = math.max(0, tnow - st.createdAt)
          local frac = elapsed - math.floor(elapsed / tickInt) * tickInt
          tickTime = tnow + math.max(0.01, tickInt - frac)
        else
          tickTime = tnow + tickInt
        end
      end
      local untilTime = (st.endAt and math.min(tnow + window, st.endAt)) or (tnow + window)
      local dotSrc = resolveDotOwner(st, key)
      local maxTicks = math.max(128, math.floor((window / math.max(0.05, tickInt)) + 10))
      local n = 0
      while tickTime <= untilTime and n < maxTicks do
        local tickDmg = applyResists(hero, (st.dps or 0) * tickInt, st.type or "magical")
        table.insert(events,
          {
            time = tickTime,
            dmg = tickDmg,
            type = "dot",
            label = st.label or key,
            cp = nil,
            src = dotSrc or key,
            fb = st.isFallback
          })
        tickTime = tickTime + tickInt
        n = n + 1
      end
    end
  end

  injectPredictedAttackCadence(events, tnow, window)

  table.sort(events, function(a, b) return a.time < b.time end)
  local deduped, lastAttackBySource = {}, {}
  for i = 1, #events do
    local ev = events[i]
    if ev.type == "attack" or ev.type == "atk_fallback" then
      local srcKey = tostring(ev.src)
      local prev = lastAttackBySource[srcKey]
      if prev and math.abs((ev.time or 0) - (prev.time or 0)) <= C.ATTACK_CLUSTER_EPS then
        prev.time = math.min(prev.time or ev.time, ev.time or prev.time)
        prev.dmg = math.max(prev.dmg or 0, ev.dmg or 0)
        prev.cp = prev.cp or ev.cp
        prev.fb = prev.fb and ev.fb or false
        prev.pred = (prev.pred or false) or (ev.pred or false)
        if (prev.label == "atk_chain" or prev.label == "atk_fallback") and ev.label and ev.label ~= "" then
          prev.label = ev.label
        end
      else
        local ref = {
          time = ev.time,
          dmg = ev.dmg,
          type = "attack",
          label = ev.label,
          cp = ev.cp,
          src = ev.src,
          fb = ev.fb,
          pred = ev.pred
        }
        table.insert(deduped, ref)
        lastAttackBySource[srcKey] = ref
      end
    else
      table.insert(deduped, ev)
    end
  end
  local comp, last = {}, nil
  for i = 1, #deduped do
    local ev = deduped[i]
    if ev.type == "attack" then
      if last and last.type == "attack" and last.src == ev.src and math.abs(ev.time - last.time) <= C.ATTACK_CLUSTER_EPS then
        last.dmg = math.max(last.dmg or 0, ev.dmg or 0)
        last.time = math.min(last.time, ev.time)
        last.cp = last.cp or ev.cp
        last.fb = last.fb and ev.fb or false
        last.pred = (last.pred or false) or (ev.pred or false)
      else
        table.insert(comp, ev)
        last = ev
      end
    else
      table.insert(comp, ev)
      last = nil
    end
  end
  deduped = comp

  for i = 1, #deduped do
    local ev = deduped[i]
    if ev and ev.src and ev.time and ev.time >= (tnow - 0.02) and
        (ev.type == "attack" or ev.type == "atk_fallback" or ev.type == "melee") then
      updateAttackCadenceMemory(ev.src, ev.time)
    end
  end

  return deduped
end

local function cleanProjectiles()
  local t = nowTime()
  for i = #THREAT.incomingProjectiles, 1, -1 do
    if THREAT.incomingProjectiles[i].expire < t - 0.15 then
      table.remove(THREAT.incomingProjectiles, i)
    end
  end
end

local function advanceDotSchedules(upToTime)
  for _, st in pairs(THREAT.dotStates) do
    local step = safeTick(st.tick, nil)
    if st.nextTickAt and step and step > 0 then
      local guard = 0
      while st.nextTickAt <= upToTime + 0.001 and guard < 128 do
        st.nextTickAt = st.nextTickAt + step
        guard = guard + 1
      end
    end
  end
end

local function sumDamageBetween(events, t0, t1)
  local s = 0
  for i = 1, #events do
    local ev = events[i]
    if ev.time > t1 then break end
    if ev.time > t0 then s = s + (ev.dmg or 0) end
  end
  return s
end

local function maxEventDamageBetween(events, t0, t1, filterFn)
  local mx = 0
  for i = 1, #events do
    local ev = events[i]
    if ev.time > t1 then break end
    if ev.time > t0 then
      if (not filterFn) or filterFn(ev) then
        local d = ev.dmg or 0
        if d > mx then mx = d end
      end
    end
  end
  return mx
end
local function analyzeIncomingControl(events, now, horizon)
  cleanIncomingControls()
  local untilT = now + (horizon or 0.9)
  local firstAt = nil
  local firstName = ""
  local severity = 0
  local count = 0
  local attackers = {}
  local followUp = 0
  local list = {}

  for _, info in pairs(THREAT.incomingControls) do
    if info and info.at and info.at > now and info.at <= untilT then
      count = count + 1
      local sev = info.severity or 0.65
      if sev > severity then
        severity = sev
      end
      if (not firstAt) or info.at < firstAt then
        firstAt = info.at
        firstName = info.name or "control"
      end
      if info.src then
        attackers[tostring(info.src)] = true
      end
      if events and info.at then
        local dmgWindow = sumDamageBetween(events, now, math.min(untilT, info.at + 0.34))
        if dmgWindow > followUp then followUp = dmgWindow end
      end
      list[#list + 1] = info
    end
  end

  local attackerCount = 0
  for _, _ in pairs(attackers) do
    attackerCount = attackerCount + 1
  end

  table.sort(list, function(a, b) return (a.at or 0) < (b.at or 0) end)
  local chainCount = 0
  local chainSpan = 0
  local chainLock = 0
  local lockUntil = nil
  for i = 1, #list do
    local info = list[i]
    local lock = math.max(0.20, info.lockDur or 1.2)
    chainLock = chainLock + lock
    local thisLockUntil = (info.at or now) + lock
    if (not lockUntil) or thisLockUntil > lockUntil then
      lockUntil = thisLockUntil
    end
    if i > 1 then
      local prev = list[i - 1]
      local gap = (info.at or now) - (prev.at or now)
      if gap <= C.TUNED_DISABLE_CHAIN_GAP then
        chainCount = chainCount + 1
      end
    end
  end
  if #list >= 2 then
    chainSpan = math.max(0, (list[#list].at or now) - (list[1].at or now))
  end
  local chainDensity = 0
  if #list > 1 then
    chainDensity = chainCount / (#list - 1)
  end

  return {
    count = count,
    attackers = attackerCount,
    firstAt = firstAt,
    firstName = firstName,
    severity = severity,
    followUp = followUp,
    chainCount = chainCount,
    chainSpan = chainSpan,
    chainLock = chainLock,
    lockUntil = lockUntil,
    chainDensity = chainDensity
  }
end

local function hasRoshanPressure(events, now, horizon)
  local untilT = now + math.max(horizon or 0.85, 1.10)
  local hit = 0
  local total = 0
  local count = 0
  local firstAt = nil
  for i = 1, #(events or {}) do
    local ev = events[i]
    if ev.time > untilT then break end
    if ev.time > now and ev.src and isRoshan(ev.src) and
        (ev.type == "attack" or ev.type == "melee" or ev.type == "atk_fallback") then
      local dmg = ev.dmg or 0
      if dmg > hit then hit = dmg end
      total = total + dmg
      count = count + 1
      if (not firstAt) or ev.time < firstAt then
        firstAt = ev.time
      end
    end
  end
  return hit > 0, hit, total, firstAt, count
end

local function analyzeHeroThreat(events, now, horizon)
  local untilT = now + (horizon or 0.78)
  local soonT = now + 0.32
  local dotSoonT = now + 0.42
  local sustainedT = now + 0.60
  local attackersMap = {}
  local burst = 0
  local soon = 0
  local dotSoon = 0
  local totalDotSoon = 0
  local dotBurst = 0
  local sustained = 0
  local pressure = 0
  local eventCount = 0
  local dotCount = 0
  local firstHitAt = nil
  local firstHitDmg = 0
  local heavyHit = 0

  for i = 1, #events do
    local ev = events[i]
    if ev.time > untilT then break end
    if ev.time > now and ev.type == "dot" then
      totalDotSoon = totalDotSoon + (ev.dmg or 0)
    end
    if ev.time > now and ev.src and isEnemyHero(ev.src) then
      local dmg = ev.dmg or 0
      burst = burst + dmg
      if ev.time <= soonT then
        soon = soon + dmg
      end
      if ev.time <= sustainedT then
        sustained = sustained + dmg
      end
      if ev.type == "dot" then
        dotCount = dotCount + 1
        dotBurst = dotBurst + dmg
        if ev.time <= dotSoonT then
          dotSoon = dotSoon + dmg
        end
      end
      local key = tostring(ev.src)
      attackersMap[key] = true
      eventCount = eventCount + 1
      if (not firstHitAt) or ev.time < firstHitAt then
        firstHitAt = ev.time
        firstHitDmg = dmg
      end
      if dmg > heavyHit then heavyHit = dmg end
    end
  end
  dotSoon = math.max(dotSoon, totalDotSoon)

  local attackers = 0
  for _, _ in pairs(attackersMap) do
    attackers = attackers + 1
  end
  pressure = burst / math.max(0.05, (horizon or 0.78))

  return {
    attackers = attackers,
    burst = burst,
    soon = soon,
    dotSoon = dotSoon,
    totalDotSoon = totalDotSoon,
    dotBurst = dotBurst,
    sustained = sustained,
    pressure = pressure,
    eventCount = eventCount,
    dotCount = dotCount,
    firstHitAt = firstHitAt,
    firstHitDmg = firstHitDmg,
    heavyHit = heavyHit
  }
end

local function sumDamageUntil(events, tlimit) return sumDamageBetween(events, -1e9, tlimit) end

local function earliestEventTime(events)
  if #events > 0 then return events[1].time end
  return nil
end

local function analyzeEventPulse(events, now, window)
  local untilT = now + (window or 1.8)
  local soonT = now + math.min(0.34, (window or 1.8) * 0.36)
  local soonHits = 0
  local soonDmg = 0
  local dotTicks = 0
  local attackEvents = 0
  local predicted = 0
  local firstAt = nil
  for i = 1, #events do
    local ev = events[i]
    if ev.time > untilT then break end
    if ev.time > now then
      if not firstAt then firstAt = ev.time end
      if ev.time <= soonT then
        soonHits = soonHits + 1
        soonDmg = soonDmg + (ev.dmg or 0)
      end
      if ev.type == "dot" then
        dotTicks = dotTicks + 1
      end
      if ev.type == "attack" or ev.type == "atk_fallback" or ev.type == "melee" then
        attackEvents = attackEvents + 1
      end
      if ev.pred then
        predicted = predicted + 1
      end
    end
  end

  local leadBonus = soonHits * 0.0055 + soonDmg * 0.00018 + dotTicks * 0.0028 + attackEvents * 0.0018 + predicted * 0.0042
  if firstAt and firstAt <= (now + 0.16) then
    leadBonus = leadBonus + 0.010
  end
  leadBonus = clamp(leadBonus, 0, C.TIMING_MAX_EXTRA_LEAD)

  local cadenceSources = 0
  local fastestCadence = nil
  local store = getCadenceMemoryStore()
  if store then
    for _, rec in pairs(store) do
      if rec and rec.interval then
        cadenceSources = cadenceSources + 1
        if (not fastestCadence) or rec.interval < fastestCadence then
          fastestCadence = rec.interval
        end
      end
    end
  end

  return {
    leadBonus = leadBonus,
    soonHits = soonHits,
    soonDmg = soonDmg,
    dotTicks = dotTicks,
    attackEvents = attackEvents,
    predicted = predicted,
    firstAt = firstAt,
    cadenceSources = cadenceSources,
    fastestCadence = fastestCadence
  }
end

local function findEarliestSafeToggleTime(events, now, curHP, gain, hpDelay, preLead, window, enforceNotBefore, safeBufOverride)
  local _, ping = getLatencyStats()
  local postBuf    = math.max(0.22, math.min(0.40, ping + 0.25))
  local safeBuf    = safeBufOverride or C.TUNED_SAFETY_BUFFER
  local preMargin  = math.max(10, safeBuf - 5)
  local postMargin = math.max(8, safeBuf - 10)
  local aggression = C.TUNED_HERO_AGGRESSION
  local reactionMs = uiInt(reactionTimeMs, 80)
  local step = (reactionMs <= C.PRO_REACTION_MS) and C.PLAN_STEP_PRO or clamp(0.03 - aggression * 0.018, C.PLAN_STEP_MIN, 0.03)

  local start      = math.max(now + preLead, enforceNotBefore or -1e9)
  local endT       = now + window - hpDelay - 0.05
  if endT <= start then return nil end

  for t0 = start, endT, step do
    local preDmg = sumDamageBetween(events, now, t0)
    if curHP - preDmg > preMargin then
      local inShift = sumDamageBetween(events, t0, t0 + hpDelay)
      if curHP - inShift > preMargin then
        local post = sumDamageBetween(events, t0 + hpDelay, t0 + hpDelay + postBuf)
        if (curHP - inShift + gain - post) > postMargin then
          return t0
        end
      end
    end
  end
  return nil
end

local function shouldLogPulseState(pulse)
  local cadenceBucket = (pulse and pulse.fastestCadence) and math.floor((pulse.fastestCadence or 0) * 10 + 0.5) or -1
  if (pulse and pulse.soonHits or -1) ~= (PLAN.lastPulseLogState.soonHits or -1) or
      (pulse and pulse.predicted or -1) ~= (PLAN.lastPulseLogState.predicted or -1) or
      cadenceBucket ~= (PLAN.lastPulseLogState.cadenceBucket or -1) then
    PLAN.lastPulseLogState.soonHits = pulse and pulse.soonHits or -1
    PLAN.lastPulseLogState.predicted = pulse and pulse.predicted or -1
    PLAN.lastPulseLogState.cadenceBucket = cadenceBucket
    return true
  end
  return false
end

local function hasHighPriorityThreatSoon(events, now, curHP, dynamicSafeBuf)
  if THREAT.lastExecutionThreat and ((THREAT.lastExecutionThreat.lethalSoon == true) or
      (THREAT.lastExecutionThreat.firstAt and THREAT.lastExecutionThreat.firstAt <= (now + 0.25))) then
    return true
  end
  if THREAT.lastControlThreat and THREAT.lastControlThreat.firstAt and THREAT.lastControlThreat.firstAt <= (now + 0.25) then
    if (THREAT.lastControlThreat.severity or 0) >= 1.0 or (THREAT.lastControlThreat.chainCount or 0) > 0 then
      return true
    end
  end
  local soonDamage = sumDamageBetween(events or {}, now, now + 0.25)
  local damageFloor = math.max(40, math.min((curHP or 0) * 0.38, (dynamicSafeBuf or C.TUNED_SAFETY_BUFFER) + 18))
  if soonDamage >= damageFloor then
    return true
  end
  if THREAT.lastHeroThreat and (THREAT.lastHeroThreat.dotSoon or 0) >= math.max(55, (curHP or 0) * 0.28) then
    return true
  end
  return false
end

local function getDotThreatWindow(events, now, horizon)
  local untilT = (now or nowTime()) + math.max(0.12, horizon or 0.35)
  local activeDots = 0
  local dotTicks = 0
  local dotDamage = 0
  local nextTickSoon = false
  local soonestTickAt = nil

  for _, st in pairs(THREAT.dotStates) do
    if st and (not st.endAt or st.endAt > (now or nowTime())) and (st.dps or 0) > 0 then
      activeDots = activeDots + 1
      if st.nextTickAt and st.nextTickAt >= (now or nowTime()) and st.nextTickAt <= untilT then
        nextTickSoon = true
        if (not soonestTickAt) or st.nextTickAt < soonestTickAt then
          soonestTickAt = st.nextTickAt
        end
      end
    end
  end

  local list = events or {}
  for i = 1, #list do
    local ev = list[i]
    if ev.time > untilT then break end
    if ev.time > (now or nowTime()) and ev.type == "dot" then
      dotTicks = dotTicks + 1
      dotDamage = dotDamage + (ev.dmg or 0)
    end
  end

  return {
    activeDots = activeDots,
    dotTicks = dotTicks,
    dotDamage = dotDamage,
    nextTickSoon = nextTickSoon,
    soonestTickAt = soonestTickAt
  }
end

local function hasDotPlanPressure(events, now, curHP, sliderHP, dynamicSafeBuf, horizon)
  local info = getDotThreatWindow(events, now, horizon)
  if (info.activeDots or 0) <= 0 then return false end

  local safeBuf = dynamicSafeBuf or C.TUNED_SAFETY_BUFFER
  local projectedHP = (curHP or 0) - (info.dotDamage or 0)
  local keepPlanHP = math.max((sliderHP or 0) + 20, safeBuf + 18)

  if (info.dotTicks or 0) >= 2 then return true end
  if info.nextTickSoon and (info.dotDamage or 0) >= math.max(16, safeBuf - 12) then return true end
  if projectedHP <= keepPlanHP then return true end
  return false
end

local function hasRoshanPlanPressure(events, now, curHP, sliderHP, dynamicSafeBuf, horizon)
  local pressure, roshanHit, roshanTotal, firstAt, roshanCount = hasRoshanPressure(events, now, horizon)
  if not pressure then return false end

  local safeBuf = dynamicSafeBuf or C.TUNED_SAFETY_BUFFER
  local singleMargin = math.max(14, safeBuf - 10)
  local chainMargin = math.max(18, safeBuf - 6)
  local projectedSingle = (curHP or 0) - (roshanHit or 0)
  local projectedChain = (curHP or 0) - math.max(roshanHit or 0, roshanTotal or 0)
  local keepPlanHP = math.max((sliderHP or 0) + 16, safeBuf + 10)

  if projectedSingle <= singleMargin then return true end
  if (roshanCount or 0) >= 2 and projectedChain <= chainMargin then return true end
  if firstAt and firstAt <= (now + 0.22) and projectedSingle <= keepPlanHP then return true end
  return false
end

local function shouldCancelRecoveredPlan(events, now, hpNow, sliderHP, dynamicSafeBuf)
  if not PLAN.planState.active then return false end
  local cancelHP = PLAN.planState.cancelHP
  if cancelHP == nil or cancelHP <= 0 then
    cancelHP = sliderHP + PLAN.config.PLAN_CANCEL_HP
  end
  local thresholdEpisodeEnded = (PLAN.planState.thresholdEpisodeId or 0) > 0 and
      ((PLAN.thresholdEpisode.active ~= true) or ((PLAN.thresholdEpisode.id or 0) ~= (PLAN.planState.thresholdEpisodeId or 0)))
  local stronglyRecovered = (hpNow or 0) >= (cancelHP + 20)
  local recoveryOverride = thresholdEpisodeEnded or stronglyRecovered
  if PLAN.planState.reasonGroup == "dot_guard" then
    local dotHorizon = math.max(0.35, math.min(0.80, ((PLAN.planState.executeAt or now) - now) + 0.14))
    if hasDotPlanPressure(events, now, hpNow, sliderHP, dynamicSafeBuf, dotHorizon) then
      return false
    end
  end
  if PLAN.planState.reasonGroup == "roshan" then
    local roshanHorizon = math.max(0.55, math.min(1.20, ((PLAN.planState.executeAt or now) - now) + 0.28))
    if hasRoshanPlanPressure(events, now, hpNow, sliderHP, dynamicSafeBuf, roshanHorizon) then
      return false
    end
  end
  if not recoveryOverride and now < (PLAN.planState.minHoldUntil or 0) then return false end
  if (hpNow or 0) < cancelHP then return false end
  if not recoveryOverride and hasHighPriorityThreatSoon(events, now, hpNow or 0, dynamicSafeBuf) then return false end
  return true
end

local function updateOverlaySnapshot(tnow, curHP, armOn, preLead, window, events, totalIncoming, dynamicSafeBuf, focusMode,
                                     focusScore, roshanPressure, roshanHit)
  local activePlan = getActivePlanSummary(tnow)
  PLAN.overlay = {
    ts = tnow,
    curHP = math.floor(curHP or 0),
    armOn = armOn,
    preLead = preLead,
    window = window,
    events = events,
    totalIncoming = totalIncoming,
    dynamicSafeBuf = dynamicSafeBuf,
    focusMode = focusMode,
    focusScore = focusScore,
    roshanPressure = roshanPressure,
    roshanHit = roshanHit,
    thresholdEpisodeId = PLAN.thresholdEpisode.id or 0,
    thresholdActive = PLAN.thresholdEpisode.active == true,
    activePlan = activePlan,
    planSuppressed = hasAnyPlanSuppression(tnow),
    lastCancelReason = PLAN.cancelState.lastReasonRaw,
    lastCancelAgo = PLAN.cancelState.lastCancelTs > 0 and (tnow - PLAN.cancelState.lastCancelTs) or nil,
    riskMode = tostring((THREAT.lastRiskState and THREAT.lastRiskState.mode) or "normal"),
    plannerPrioritySource = activePlan and
        string.format("%s/%d", tostring(activePlan.reasonGroup or "none"), activePlan.priority or 0) or "none",
    recentReasons = recentReasonsSnapshot(4)
  }
end

local function evaluateAndToggleSmart()
  if STATE.toggledThisFrame then return end
  local curHP = Entity.GetHealth(hero)
  if isHuskar(hero) then curHP = math.max(1, (curHP or 0) - C.HUSKAR_HP_RESERVE) end
  local tnow = nowTime()
  local preLead, window, cd = autoTiming()
  local hpDelay = C.ARMLET_HP_SHIFT
  local armOn = Ability.GetToggleState(Armlet)
  local gain = 500
  local baseSafeBuf = C.TUNED_SAFETY_BUFFER
  local aggression = C.TUNED_HERO_AGGRESSION
  local sliderHP = uiInt(hpSlider, 340)
  local reactionMs = uiInt(reactionTimeMs, 80)
  local proMode = reactionMs <= C.PRO_REACTION_MS

  cleanProjectiles()
  cleanIncomingControls()
  pcall(scanDebuffDots)
  pcall(scanBladeMailReflectDots)
  THREAT.lastHadActiveDot = false
  for _, st in pairs(THREAT.dotStates) do
    if st and (not st.endAt or st.endAt > tnow) and (st.dps or 0) > 0 then THREAT.lastHadActiveDot = true; break end
  end

  local events = collectEvents(window)
  local criticalZone = curHP <= C.CRITICAL_HP_ABSOLUTE or curHP <= (sliderHP - C.CRITICAL_HP_BELOW_SLIDER)
  -- Early lethal: only when HP is actually low; avoid refresh at high HP. In critical zone trigger earlier. Pro mode = tighter windows.
  do
    local lethalExtra = proMode and (criticalZone and C.LETHAL_WINDOW_PRO_CRITICAL or C.LETHAL_WINDOW_PRO_NORMAL) or (criticalZone and C.LETHAL_WINDOW_CRITICAL or C.LETHAL_WINDOW_NORMAL)
    local hpLowForPrearm = curHP <= (sliderHP + 95)
    local hpLowForRefresh = curHP <= (sliderHP + 65)
    local lethalWindow = tnow + hpDelay + preLead + lethalExtra
    local dmgSoon = sumDamageUntil(events, lethalWindow)
    local dotCountInWindow = 0
    for i = 1, math.min(#events, 40) do
      if events[i].time <= lethalWindow and events[i].type == "dot" then dotCountInWindow = dotCountInWindow + 1 end
    end
    local safeBufEarly = baseSafeBuf
    if dotCountInWindow >= 1 then safeBufEarly = baseSafeBuf - 8 end
    if dotCountInWindow >= 2 then safeBufEarly = baseSafeBuf - 14 end
    if dotCountInWindow >= 3 then safeBufEarly = baseSafeBuf - 20 end
    if criticalZone then safeBufEarly = math.max(proMode and C.SAFE_BUF_EARLY_MIN_PRO or C.SAFE_BUF_EARLY_MIN, safeBufEarly - 12) end
    if safeBufEarly < (proMode and C.SAFE_BUF_EARLY_MIN_PRO or C.SAFE_BUF_EARLY_MIN) then safeBufEarly = (proMode and C.SAFE_BUF_EARLY_MIN_PRO or C.SAFE_BUF_EARLY_MIN) end
    if safeBufEarly < 24 and not criticalZone then safeBufEarly = 24 end
    if dmgSoon >= (curHP - safeBufEarly) and not isShiftLocked() and canToggle(cd) then
      if not armOn and (hpLowForPrearm or criticalZone) then
        AbuseArmlet("lethal_early")
        return
      end
      if armOn and (hpLowForRefresh or criticalZone) then
        AbuseArmlet("lethal_early")
        return
      end
    end
  end
  local pulse = analyzeEventPulse(events, tnow, window)
  local adaptive = uiBool(adaptiveTimingSwitch, true)
  if adaptive and (pulse.leadBonus or 0) > 0 then
    preLead = clamp(preLead + (pulse.leadBonus or 0), 0.05, 0.30)
    local boostedWindow = math.max(window, hpDelay + preLead + 0.95 + (pulse.leadBonus or 0) * 2.4)
    if boostedWindow > window + 0.04 then
      local prevWindow = window
      window = boostedWindow
      events = collectEvents(window)
      pulse = analyzeEventPulse(events, tnow, window)
      pushDecisionLog(string.format("PULSE_WINDOW %.2f->%.2f", prevWindow, boostedWindow), 170, 210, 255)
    end
  end
  THREAT.lastEventPulse = {
    leadBonus = pulse.leadBonus or 0,
    soonHits = pulse.soonHits or 0,
    soonDmg = pulse.soonDmg or 0,
    dotTicks = pulse.dotTicks or 0,
    attackEvents = pulse.attackEvents or 0,
    predicted = pulse.predicted or 0,
    cadenceSources = pulse.cadenceSources or 0,
    fastestCadence = pulse.fastestCadence,
    srcCadence = (type(THREAT.lastEventPulse) == "table" and type(THREAT.lastEventPulse.srcCadence) == "table") and THREAT.lastEventPulse.srcCadence or {},
    ts = tnow
  }
  if currentDebugLevel() >= DEBUG_LOG_VERBOSE and (tnow - (PLAN.lastPulseDebugAt or 0)) >= 1.5 then
    local lead = (pulse.leadBonus or 0) * 1000
    local hits = pulse.soonHits or 0
    local dmg = pulse.soonDmg or 0
    local dot = pulse.dotTicks or 0
    local atk = pulse.attackEvents or 0
    local pred = pulse.predicted or 0
    local cad = pulse.cadenceSources or 0
    local fast = pulse.fastestCadence or 0
    local hasThreat = lead > 0 or hits > 0 or dmg > 0 or dot > 0 or atk > 0 or pred > 0
    if hasThreat then
      PLAN.lastPulseDebugAt = tnow
      dbg(string.format("pulse lead=%.0fms hits=%d dmg=%.0f dot=%d atk=%d pred=%d cad=%d fast=%.2f", lead, hits, dmg, dot, atk, pred, cad, fast))
    end
  elseif currentDebugLevel() >= DEBUG_LOG_STATE then
    local hits = pulse.soonHits or 0
    local dmg = pulse.soonDmg or 0
    local pred = pulse.predicted or 0
    local cad = pulse.cadenceSources or 0
    local fast = pulse.fastestCadence or 0
    local hasThreat = hits > 0 or dmg > 0 or pred > 0
    if hasThreat and shouldLogPulseState(pulse) then
      logState(string.format("pulse hits=%d dmg=%.0f pred=%d cad=%d fast=%.2f", hits, dmg, pred, cad, fast),
        "pulse_state", 0.50)
    end
  end

  local heroBurstGuardEnabled = uiBool(heroBurstGuardSwitch, true)
  local heroThreatHorizon = math.max(C.TUNED_HERO_THREAT_WINDOW, hpDelay + preLead + 0.10)
  local heroThreat = analyzeHeroThreat(events, tnow, heroThreatHorizon)
  local controlThreat = analyzeIncomingControl(events, tnow, math.max(1.15, hpDelay + preLead + 0.55))
  THREAT.lastHeroThreat = {
    attackers = heroThreat.attackers,
    burst = heroThreat.burst,
    soon = heroThreat.soon,
    dotSoon = heroThreat.dotSoon,
    sustained = heroThreat.sustained,
    pressure = heroThreat.pressure,
    dotCount = heroThreat.dotCount,
    firstHitDmg = heroThreat.firstHitDmg,
    heavyHit = heroThreat.heavyHit,
    ts = tnow
  }

  local uncertainty = analyzeUncertainty(events, tnow, math.max(1.00, hpDelay + preLead + 0.45))
  local executionThreat = analyzeExecutionThreat(events, tnow, math.max(0.95, hpDelay + preLead + 0.30))

  local dynamicSafeBuf = baseSafeBuf
  if heroBurstGuardEnabled and heroThreat.attackers > 0 then
    local attackersBonus = math.max(0, heroThreat.attackers - 1) * (4 + math.floor(aggression * 3))
    local soonBonus = math.min(26, heroThreat.soon * (0.02 + aggression * 0.03))
    local heavyBonus = math.min(14, heroThreat.heavyHit * 0.035)
    local dotBonus = math.min(20, heroThreat.dotSoon * (0.03 + aggression * 0.035))
    local sustainBonus = math.min(16, heroThreat.sustained * (0.012 + aggression * 0.02))
    local pressureBonus = math.min(12, heroThreat.pressure * (0.04 + aggression * 0.02))
    dynamicSafeBuf = clamp(
      math.floor(baseSafeBuf + attackersBonus + soonBonus + heavyBonus + dotBonus + sustainBonus + pressureBonus + 0.5),
      baseSafeBuf, 100)
  end
  local focusScore = heroThreat.soon + heroThreat.dotSoon + heroThreat.sustained * 0.35
  local focusMode = heroBurstGuardEnabled and heroThreat.attackers >= 2 and
      (focusScore >= math.max(150, curHP * 0.42) or heroThreat.burst >= curHP * 0.90)
  if focusMode then
    dynamicSafeBuf = clamp(dynamicSafeBuf + math.floor(C.TUNED_FOCUS_EXTRA_BUFFER + aggression * 8 + 0.5), baseSafeBuf, 120)
  end

  local chainBonus = math.floor((controlThreat.chainCount or 0) * 3 + (controlThreat.chainLock or 0) * 2.2 + 0.5)
  local executionBonus = math.floor(math.min(24, (executionThreat.soon or 0) * 0.05 + (executionThreat.count or 0) * 4) + 0.5)
  dynamicSafeBuf = clamp(dynamicSafeBuf + (uncertainty.bonus or 0) + chainBonus + executionBonus, baseSafeBuf, 140)

  local roshanPressure, roshanHit, roshanTotal, roshanFirstAt, roshanCount = hasRoshanPressure(events, tnow,
    math.max(hpDelay + preLead + 0.16, 1.10))
  local riskState = computeUnifiedRiskState(curHP, sliderHP, heroThreat, controlThreat, uncertainty, executionThreat,
    roshanHit, focusMode)
  dynamicSafeBuf = clamp(
    math.floor(dynamicSafeBuf * (riskState.safeMul or 1.0) + (riskState.extraBuffer or 0) + 0.5),
    baseSafeBuf, 150)

  local thresholdActive = PLAN.thresholdEpisode.active == true
  local thresholdCancelHP = sliderHP + PLAN.config.PLAN_CANCEL_HP
  local thresholdPlanOpts = {
    cancelHP = thresholdCancelHP,
    safetyMargin = math.max(0, curHP - dynamicSafeBuf),
    hpAtCreate = curHP,
    thresholdEpisodeId = PLAN.thresholdEpisode.id or 0
  }
  local roshanPlanOpts = {
    cancelHP = thresholdCancelHP,
    safetyMargin = math.max(0, curHP - math.max(roshanHit or 0, roshanTotal or 0) - dynamicSafeBuf),
    hpAtCreate = curHP,
    thresholdEpisodeId = PLAN.thresholdEpisode.id or 0,
    priority = 85,
    minHold = 0.16,
    expirePad = 0.80
  }

  THREAT.lastFocusState = { active = focusMode, score = focusScore, ts = tnow }
  THREAT.lastUncertaintyState = {
    bonus = uncertainty.bonus or 0,
    fallback = uncertainty.fallbackCount or 0,
    damage = uncertainty.fallbackDamage or 0,
    jitter = uncertainty.jitterMs or 0,
    ts = tnow
  }
  THREAT.lastExecutionThreat = {
    count = executionThreat.count or 0,
    soon = executionThreat.soon or 0,
    lethalSoon = executionThreat.lethalSoon or false,
    firstAt = executionThreat.firstAt,
    name = executionThreat.firstName or "",
    ts = tnow
  }
  THREAT.lastRiskState = {
    score = riskState.score or 0,
    mode = riskState.mode or "normal",
    thresholdBias = riskState.thresholdBias or 0,
    ts = tnow
  }
  THREAT.lastControlThreat = {
    count = controlThreat.count,
    firstAt = controlThreat.firstAt,
    severity = controlThreat.severity,
    name = controlThreat.firstName or "",
    chainCount = controlThreat.chainCount or 0,
    chainLock = controlThreat.chainLock or 0,
    ts = tnow
  }
  do
    local totalIncoming = 0
    for i = 1, #events do
      totalIncoming = totalIncoming + (events[i].dmg or 0)
    end
    updateOverlaySnapshot(tnow, curHP, armOn, preLead, window, events, totalIncoming, dynamicSafeBuf, focusMode,
      focusScore, roshanPressure, roshanHit)
  end

  if executionThreat.count > 0 and executionThreat.firstAt then
    local execWindowExtra = (reactionMs and reactionMs <= C.PRO_REACTION_MS) and (criticalZone and 0.10 or 0.06) or (criticalZone and 0.16 or 0.12)
    local execWindow = hpDelay + preLead + execWindowExtra
    local execSoon = executionThreat.firstAt <= (tnow + execWindow)
    local execMargin = math.max(12, dynamicSafeBuf - 6 + math.floor((executionThreat.count or 0) * 3))
    if criticalZone then execMargin = math.max(6, execMargin - 10) end
    local execKill = executionThreat.lethalSoon or (executionThreat.soon >= curHP - execMargin)
    if execSoon and execKill then
      if not isShiftLocked() and canToggle(cd) then
        AbuseArmlet("execution_guard@" .. tostring(executionThreat.firstName or "execute"))
        advanceDotSchedules(tnow)
        return
      else
        planToggle(nextToggleAllowedAt(cd, tnow), "execution_wait_shift")
      end
    end
  end

  if controlThreat.count > 0 and controlThreat.firstAt then
    local controlLead = proMode and C.TUNED_PRE_DISABLE_LEAD_PRO or C.TUNED_PRE_DISABLE_LEAD
    local controlWindow = hpDelay + preLead + controlLead + math.min(0.16, (controlThreat.chainCount or 0) * 0.04)
    local controlSoon = controlThreat.firstAt <= (tnow + controlWindow)
    local controlMargin = math.max(10, dynamicSafeBuf - 8 +
        math.floor((controlThreat.severity or 0) * 12) +
        math.floor((controlThreat.chainCount or 0) * 2 + (controlThreat.chainLock or 0) * 1.5))
    local lockPad = 0.34 + math.min(0.28, (controlThreat.chainLock or 0) * 0.08)
    local dmgBeforeLock = sumDamageBetween(events, tnow, math.min(tnow + window, controlThreat.firstAt + lockPad))
    if not armOn and controlSoon and
        (dmgBeforeLock >= curHP - controlMargin or curHP <= sliderHP + math.floor(dynamicSafeBuf * 0.50)) then
      if not isShiftLocked() and canToggle(cd) then
        AbuseArmlet("pre_disable_guard@" .. tostring(controlThreat.firstName or "control"))
        advanceDotSchedules(tnow)
        return
      else
        planToggle(nextToggleAllowedAt(cd, tnow), "pre_disable_wait_shift")
      end
    end
    if armOn and controlSoon then
      local refreshGuardMargin = math.max(10, dynamicSafeBuf - 10)
      if (curHP - dmgBeforeLock) <= refreshGuardMargin then
        if not isShiftLocked() and canToggle(cd) then
          AbuseArmlet("pre_disable_refresh")
          advanceDotSchedules(tnow)
          return
        end
      end
    end
  end

  if riskState.mode == "ultra" and not armOn then
    local ultraWindow = hpDelay + preLead + 0.08
    local ultraIncoming = sumDamageBetween(events, tnow, tnow + ultraWindow)
    if ultraIncoming >= curHP - math.max(12, dynamicSafeBuf - 4) then
      if not isShiftLocked() and canToggle(cd) then
        AbuseArmlet("ultra_risk_prearm")
        advanceDotSchedules(tnow)
        return
      end
    end
  end

  if focusMode then
    if not armOn then
      local focusWindow = hpDelay + preLead + 0.10
      local dmgFocus = sumDamageUntil(events, tnow + focusWindow)
      if dmgFocus >= curHP - math.max(12, dynamicSafeBuf - 4) then
        if not isShiftLocked() and canToggle(cd) then
          AbuseArmlet("focus_prearm_guard")
          advanceDotSchedules(tnow)
          return
        end
      end
    else
      local dmgFocusSoon = sumDamageBetween(events, tnow, tnow + 0.30)
      if (curHP - dmgFocusSoon) <= math.max(10, dynamicSafeBuf - 12) then
        if not isShiftLocked() and canToggle(cd) then
          AbuseArmlet("focus_refresh_guard")
          advanceDotSchedules(tnow)
          return
        end
      end
    end
  end

  -- Next DoT tick: single pass over THREAT.dotStates. Fast DoT (tick <= 0.25): use slightly wider horizon so we react earlier.
  local hpLowForDotPrearm = curHP <= (sliderHP + 110)
  local hpLowForDotRefresh = curHP <= (sliderHP + 75)
  do
    local tickHorizon = criticalZone and (tnow + preLead + 0.18) or (tnow + preLead + 0.12)
    local combinedTickDmg = 0
    local soonestTickAt = nil
    local tickList = {}
    for key, st in pairs(THREAT.dotStates) do
      if (not st.endAt or st.endAt > tnow) and st.dps and st.dps > 0 and st.nextTickAt then
        local tickInt = safeTick(st.tick, 0.5)
        if tickInt and tickInt > 0 then
          local inWindow = st.nextTickAt >= tnow and st.nextTickAt <= tickHorizon
          if not inWindow and tickInt <= 0.25 and st.nextTickAt >= tnow and st.nextTickAt <= tnow + preLead + 0.04 then inWindow = true end
          if inWindow then
            local tickDmg = applyResists(hero, (st.dps or 0) * tickInt, st.type or "magical")
            combinedTickDmg = combinedTickDmg + tickDmg
            if (not soonestTickAt) or st.nextTickAt < soonestTickAt then soonestTickAt = st.nextTickAt end
            tickList[#tickList + 1] = { tickDmg = tickDmg }
          end
        end
      end
    end
    if combinedTickDmg > 0 and soonestTickAt and (not armOn and hpLowForDotPrearm or armOn and hpLowForDotRefresh) then
      local lethalTick = (curHP - combinedTickDmg) <= 0
      local margin = (lethalTick or criticalZone) and 0 or (dynamicSafeBuf + 8)
      if (curHP - combinedTickDmg) <= margin then
        if not isShiftLocked() and canToggle(cd) then
          if armOn then AbuseArmlet("dot_next_tick_refresh") else AbuseArmlet("dot_next_tick_guard") end
          advanceDotSchedules(tnow)
          return
        else
          planToggle(nextToggleAllowedAt(cd, tnow), armOn and "dot_next_tick_refresh_wait" or "dot_next_tick_guard_wait", {
            cancelHP = sliderHP + PLAN.config.PLAN_CANCEL_HP,
            safetyMargin = math.max(0, curHP - combinedTickDmg - dynamicSafeBuf),
            hpAtCreate = curHP,
            thresholdEpisodeId = PLAN.thresholdEpisode.id or 0,
            minHold = 0.08
          })
          advanceDotSchedules(tnow)
          return
        end
      end
      for i = 1, #tickList do
        local tickDmg = tickList[i].tickDmg
        local lethalTick = (curHP - tickDmg) <= 0
        local margin = (lethalTick or criticalZone) and 0 or (dynamicSafeBuf + 8)
        if (curHP - tickDmg) <= margin then
          if not isShiftLocked() and canToggle(cd) then
            if armOn then AbuseArmlet("dot_next_tick_refresh") else AbuseArmlet("dot_next_tick_guard") end
            advanceDotSchedules(tnow)
            return
          else
            planToggle(nextToggleAllowedAt(cd, tnow), armOn and "dot_next_tick_refresh_wait" or "dot_next_tick_guard_wait", {
              cancelHP = sliderHP + PLAN.config.PLAN_CANCEL_HP,
              safetyMargin = math.max(0, curHP - tickDmg - dynamicSafeBuf),
              hpAtCreate = curHP,
              thresholdEpisodeId = PLAN.thresholdEpisode.id or 0,
              minHold = 0.08
            })
            advanceDotSchedules(tnow)
            return
          end
        end
      end
    end
  end
  do
    local dotWindow = hpDelay + preLead + 0.20
    local dotLongDamage = 0
    local dotNearDamage = 0
    local dotTicks = 0
    for i = 1, #events do
      local ev = events[i]
      if ev.time > tnow + dotWindow then break end
      if ev.time > tnow and ev.type == "dot" then
        dotTicks = dotTicks + 1
        dotLongDamage = dotLongDamage + (ev.dmg or 0)
        if ev.time <= tnow + 0.42 then dotNearDamage = dotNearDamage + (ev.dmg or 0) end
      end
    end
    local dotGuardMargin = criticalZone and math.max(6, dynamicSafeBuf - 10) or math.max(10, dynamicSafeBuf - 6)
    local dotRefreshMargin = criticalZone and math.max(6, dynamicSafeBuf - 10) or math.max(8, dynamicSafeBuf - 8)
    if dotTicks >= 1 and curHP <= (sliderHP + 100) then
      if not armOn and dotLongDamage >= curHP - dotGuardMargin then
        if not isShiftLocked() and canToggle(cd) then
          AbuseArmlet("dot_chain_guard")
          advanceDotSchedules(tnow)
          return
        else
          planToggle(nextToggleAllowedAt(cd, tnow), "dot_chain_guard_wait", {
            cancelHP = sliderHP + PLAN.config.PLAN_CANCEL_HP,
            safetyMargin = math.max(0, curHP - dotLongDamage - dynamicSafeBuf),
            hpAtCreate = curHP,
            thresholdEpisodeId = PLAN.thresholdEpisode.id or 0,
            minHold = 0.08
          })
          advanceDotSchedules(tnow)
          return
        end
      end
      if armOn and curHP <= (sliderHP + 80) and dotNearDamage >= curHP - dotRefreshMargin then
        if not isShiftLocked() and canToggle(cd) then
          AbuseArmlet("dot_chain_refresh_guard")
          advanceDotSchedules(tnow)
          return
        else
          planToggle(nextToggleAllowedAt(cd, tnow), "dot_chain_refresh_wait", {
            cancelHP = sliderHP + PLAN.config.PLAN_CANCEL_HP,
            safetyMargin = math.max(0, curHP - dotNearDamage - dynamicSafeBuf),
            hpAtCreate = curHP,
            thresholdEpisodeId = PLAN.thresholdEpisode.id or 0,
            minHold = 0.08
          })
          advanceDotSchedules(tnow)
          return
        end
      end
    end
  end

  if not armOn then
    local imminentWindow = hpDelay + preLead + 0.02
    local dmgImminent = sumDamageUntil(events, tnow + imminentWindow)
    if dmgImminent >= curHP - math.max(10, dynamicSafeBuf - 6) then
      if not isShiftLocked() and canToggle(cd) then
        AbuseArmlet("imminent_multi_attack")
        advanceDotSchedules(tnow)
        return
      else
        planToggle(nextToggleAllowedAt(cd, tnow), "imminent_multi_attack_wait")
      end
    end
  end

  if heroBurstGuardEnabled and heroThreat.attackers > 0 and not armOn then
    local heroSoonMargin = math.max(12, dynamicSafeBuf - 4 + math.floor(aggression * 6))
    local comboKill = (heroThreat.attackers >= 2) and (heroThreat.burst >= curHP - heroSoonMargin)
    local burstSoon = heroThreat.soon >= curHP - heroSoonMargin
    local dotSoon = heroThreat.dotSoon >= curHP - heroSoonMargin
    local sustainKill = heroThreat.sustained >= curHP - math.max(10, heroSoonMargin - 2)
    if comboKill or burstSoon or dotSoon or sustainKill then
      if not isShiftLocked() and canToggle(cd) then
        if comboKill then
          AbuseArmlet("hero_combo_guard")
        elseif dotSoon or sustainKill then
          AbuseArmlet("hero_dot_guard")
        else
          AbuseArmlet("hero_burst_guard")
        end
        advanceDotSchedules(tnow)
        return
      end
    end
  end

  if heroBurstGuardEnabled and heroThreat.attackers > 0 and armOn and curHP <= (sliderHP + 85) then
    local dmgInShift = sumDamageBetween(events, tnow, tnow + hpDelay)
    local refreshMargin = math.max(10, dynamicSafeBuf - 8)
    local dotRefreshMargin = math.max(8, refreshMargin - 2)
    local dotRefreshSoon = (heroThreat.dotSoon or 0) >= curHP - dotRefreshMargin
    if (curHP - dmgInShift) <= refreshMargin or dotRefreshSoon then
      if not isShiftLocked() and canToggle(cd) then
        AbuseArmlet(dotRefreshSoon and "hero_dot_refresh_guard" or "hero_refresh_guard")
        advanceDotSchedules(tnow)
        return
      end
    end
  end

  if roshanPressure and roshanHit > 0 then
    local roshanPreHitMargin = math.max(10, dynamicSafeBuf - 4)
    local roshanChainMargin = math.max(14, dynamicSafeBuf - 2)
    local roshanSoon = roshanFirstAt and roshanFirstAt <= (tnow + hpDelay + preLead + 0.24)
    local roshanDanger = (curHP - roshanHit) <= roshanPreHitMargin
    local roshanChainDanger = ((roshanCount or 0) >= 2) and ((curHP - math.max(roshanHit or 0, roshanTotal or 0)) <= roshanChainMargin)
    if roshanDanger or roshanChainDanger or (roshanSoon and armOn and curHP <= (sliderHP + 70)) then
      if not isShiftLocked() and canToggle(cd) then
        AbuseArmlet(armOn and "roshan_refresh_guard" or "roshan_prehit_guard")
        advanceDotSchedules(tnow)
        return
      else
        planToggle(nextToggleAllowedAt(cd, tnow), armOn and "roshan_refresh_wait" or "roshan_wait_shift", roshanPlanOpts)
        advanceDotSchedules(tnow)
        return
      end
    end
  end

  local panicDelta
  if proMode then
    panicDelta = THREAT.lastHadActiveDot and C.PANIC_DELTA_DOT_PRO or C.PANIC_DELTA_PRO
  else
    panicDelta = THREAT.lastHadActiveDot and C.THRESHOLD_PANIC_DELTA_DOT or C.THRESHOLD_PANIC_DELTA
  end
  local panic = thresholdActive and (curHP <= (sliderHP - panicDelta))
  if panic then
    if roshanPressure and roshanHit > 0 then
      if not isShiftLocked() and canToggle(cd) then
        AbuseArmlet(armOn and "roshan_refresh_guard" or "roshan_prehit_guard")
        advanceDotSchedules(tnow)
        return
      else
        planToggle(nextToggleAllowedAt(cd, tnow), armOn and "roshan_refresh_wait" or "roshan_wait_shift", roshanPlanOpts)
        advanceDotSchedules(tnow)
        return
      end
    end
    if not isShiftLocked() and canToggle(cd) then
      AbuseArmlet("panic_threshold")
      advanceDotSchedules(tnow)
      return
    else
      planToggle(nextToggleAllowedAt(cd, tnow), "panic_wait_shift", thresholdPlanOpts)
    end
  end
  if thresholdActive then
    if #events == 0 then
      if not isShiftLocked() and canToggle(cd) then
        AbuseArmlet("threshold_idle")
        advanceDotSchedules(tnow)
        return
      else
        planToggle(nextToggleAllowedAt(cd, tnow), "threshold_idle_wait_shift", thresholdPlanOpts)
      end
    else
      if not (armOn and isShiftLocked()) then
        local notBefore = armOn and (nextShiftReadyAt() + 0.01) or nil
        local safeT0 = findEarliestSafeToggleTime(events, tnow, curHP, gain, hpDelay, preLead, window, notBefore,
          dynamicSafeBuf)
        if safeT0 then
          planToggle(safeT0, "threshold_safe_gap", thresholdPlanOpts)
          local reallyLow = curHP <= (sliderHP - PLAN.config.REALLY_LOW_HP)
          if reallyLow and PLAN.thresholdEpisode.allowSafeGapNow and PLAN.planState.active and PLAN.planState.reasonRaw == "threshold_safe_gap" and
              tnow + 0.01 >= (PLAN.planState.executeAt or 0) and not isShiftLocked() and canToggle(cd) then
            AbuseArmlet("threshold_safe_gap_now")
            advanceDotSchedules(tnow)
            return
          end
        else
          local tFirst = earliestEventTime(events)
          if tFirst then
            local tAfter = tFirst + C.MIN_POST_HIT_SCHEDULE
            if armOn then tAfter = math.max(tAfter, nextShiftReadyAt() + 0.01) end
            if tAfter <= tnow + window - hpDelay then
              planToggle(tAfter, "threshold_after_hit", thresholdPlanOpts)
            else
              if not isShiftLocked() and canToggle(cd) then
                AbuseArmlet("threshold_immediate_fallback")
                advanceDotSchedules(tnow)
                return
              end
            end
          else
            if not isShiftLocked() and canToggle(cd) then
              AbuseArmlet("threshold_idle_2")
              advanceDotSchedules(tnow)
              return
            end
          end
        end
      end
    end
  end

  if #events == 0 then
    advanceDotSchedules(tnow)
    return
  end

  do
    if not armOn then
      local tShift = tnow + C.ARMLET_HP_SHIFT
      local dmgBeforeShift = sumDamageUntil(events, tShift)
      local dmgToShiftPlus = sumDamageUntil(events, tShift + 0.15)
      if dmgBeforeShift < curHP and (curHP + gain - dmgToShiftPlus) <= dynamicSafeBuf * 0.5 then
        AbuseArmlet("cluster_prearm_wave")
        advanceDotSchedules(tnow)
        return
      end
    end
  end

  do
    local dmgBeforeArrival = 0
    local hasLongCPThreat = false
    for i = 1, #events do
      local ev = events[i]
      if ev.time <= tnow + hpDelay + preLead then
        dmgBeforeArrival = dmgBeforeArrival + (ev.dmg or 0)
        if (ev.type == "cast" or ev.type == "abil_fallback") and (ev.cp or 0) > C.LONG_CP_THRESHOLD then
          hasLongCPThreat = true
        end
      else
        break
      end
    end
    if hasLongCPThreat and dmgBeforeArrival >= curHP and not armOn then
      AbuseArmlet("pre-shift_guard_longCP")
    end
  end

  local tKill = (function()
    local run = 0
    for i = 1, #events do
      local ev = events[i]; run = run + (ev.dmg or 0); if run >= curHP then return ev.time end
    end
    return nil
  end)()
  if tKill then
    local etaKill = tKill - tnow
    if etaKill >= (hpDelay + preLead - 0.02) then
      if not armOn then
        AbuseArmlet("burst_ttk_guard")
      elseif criticalZone and not isShiftLocked() and canToggle(cd) then
        AbuseArmlet("burst_ttk_refresh")
      end
    end
  end

  local running = 0
  for i = 1, #events do
    local ev = events[i]
    running = running + (ev.dmg or 0)
    local eta = ev.time - tnow
    local availableGain = 0
    if not armOn and eta >= hpDelay then availableGain = 500 end
    local lethal = (curHP + availableGain - running - dynamicSafeBuf) <= 0
    if lethal then
      local etaMargin = proMode and C.LETHAL_ETA_MARGIN_PRO or C.LETHAL_ETA_MARGIN
      if eta <= (preLead + hpDelay + etaMargin) then
        if not armOn then
          AbuseArmlet("lethal@" .. (ev.label or "hit"))
        elseif criticalZone and not isShiftLocked() and canToggle(cd) then
          AbuseArmlet("lethal_refresh@" .. (ev.label or "hit"))
        end
      end
      break
    end
  end

  advanceDotSchedules(tnow)
end

function script.OnUnitAnimation(data)
  if not uiBool(Switch, true) then return end
  if not hero or not isAlive(hero) then return end
  if not data then return end
  local unit = data.unit or data.npc
  if not unit or not isEnemy(unit) then return end
  handleAnimationEvent(unit, data.sequenceName or data.sequence, data.castpoint or data.castPoint, data.playbackRate,
    data.lag_compensation_time or data.lagCompensationTime,
    data.activity)
end

function script.OnUpdate()
  STATE.toggledThisFrame = false
  if not uiBool(Switch, true) then return end
  if not hero or not isAlive(hero) then
    hero = Heroes.GetLocal()
    return
  end
  if not ensureArmlet() then return end
  local onNow = Ability.GetToggleState(Armlet)
  if STATE.prevArmState == nil then STATE.prevArmState = onNow end
  if onNow ~= STATE.prevArmState then
    if onNow then STATE.armOnSince = nowTime() end
    STATE.prevArmState = onNow
  end

  local hp = Entity.GetHealth(hero)
  local sliderHP = uiInt(hpSlider, 340)
  local tnow = nowTime()
  clearExpiredPlan(tnow)
  updateThresholdEpisode(hp, sliderHP, tnow)
  evaluateAndToggleSmart()
  tnow = nowTime()
  local maxDeferral = THREAT.lastHadActiveDot and C.MAX_DEFERRAL_WHEN_DOT or C.MAX_DEFERRAL_AFTER_THRESHOLD
  if not STATE.toggledThisFrame and PLAN.thresholdEpisode.active and STATE.thresholdSince and (tnow - STATE.thresholdSince) >= maxDeferral then
    local _, _, cd = autoTiming()
    if not isShiftLocked() and canToggle(cd) then
      AbuseArmlet("threshold_deadline")
    else
      planToggle(nextToggleAllowedAt(cd, tnow), "threshold_deadline_wait_shift", {
        cancelHP = sliderHP + PLAN.config.PLAN_CANCEL_HP,
        safetyMargin = math.max(0, (hp or 0) - (PLAN.overlay.dynamicSafeBuf or C.TUNED_SAFETY_BUFFER)),
        hpAtCreate = hp or 0,
        thresholdEpisodeId = PLAN.thresholdEpisode.id or 0
      })
    end
  end

  local hpNow = Entity.GetHealth(hero)
  local criticalNow = (hpNow or 0) <= C.CRITICAL_HP_ABSOLUTE or (hpNow or 0) <= (sliderHP - C.CRITICAL_HP_BELOW_SLIDER)
  local reactionMsNow = uiInt(reactionTimeMs, 80)
  local proNow = reactionMsNow <= C.PRO_REACTION_MS
  local latencyOffset
  if proNow then
    latencyOffset = getLatency() + 0.015
    if criticalNow then latencyOffset = latencyOffset + 0.02 end
  else
    latencyOffset = getLatency() * 0.5 + 0.02
    if criticalNow then latencyOffset = latencyOffset + 0.025 end
  end
  tnow = nowTime()
  if not STATE.toggledThisFrame and PLAN.planState.active and tnow >= ((PLAN.planState.executeAt or tnow) - latencyOffset) then
    local snapshot = PLAN.overlay or {}
    local events = snapshot.events or {}
    local dynamicSafeBuf = snapshot.dynamicSafeBuf or C.TUNED_SAFETY_BUFFER
    if shouldCancelRecoveredPlan(events, tnow, hpNow, sliderHP, dynamicSafeBuf) then
      registerPlanCancel(PLAN.planState.reasonRaw, PLAN.planState.reasonGroup, "recovered")
    else
      local _, _, cd = autoTiming()
      if not isShiftLocked() and canToggle(cd) then
        AbuseArmlet(PLAN.planState.reasonRaw or "planned")
      end
    end
  end

  local snapshot = PLAN.overlay or {}
  if (snapshot.ts or 0) > 0 then
    updateOverlaySnapshot(nowTime(), hpNow or hp or 0, Ability.GetToggleState(Armlet), snapshot.preLead or 0, snapshot.window or 0,
      snapshot.events or {}, snapshot.totalIncoming or 0, snapshot.dynamicSafeBuf or C.TUNED_SAFETY_BUFFER,
      snapshot.focusMode or false, snapshot.focusScore or 0, snapshot.roshanPressure or false, snapshot.roshanHit or 0)
  end
end

local function drawShadowText(f, x, y, text, r, g, b, a)
  if not text or not f then return end
  setDrawColorCompat(0, 0, 0, a or 255); drawTextCompat(f, x + 1, y + 1, text)
  setDrawColorCompat(r or 255, g or 255, b or 255, a or 255); drawTextCompat(f, x, y, text)
end
local function drawPanel(x, y, w, h, bg, border)
  setDrawColorCompat(bg[1], bg[2], bg[3], bg[4]); drawFilledRectCompat(x, y, w, h)
  setDrawColorCompat(border[1], border[2], border[3], border[4]); drawOutlineRectCompat(x, y, w, h)
end
local function colorForType(t)
  if t == "hit" then
    return 230, 90, 90
  elseif t == "attack" then
    return 255, 120, 80
  elseif t == "melee" then
    return 255, 140, 90
  elseif t == "atk_fallback" then
    return 210, 160, 120
  elseif t == "ability" then
    return 240, 190, 60
  elseif t == "abil_fallback" then
    return 200, 180, 120
  elseif t == "cast" then
    return 240, 190, 60
  elseif t == "execute" then
    return 255, 95, 95
  elseif t == "dot" then
    return 170, 120, 255
  else
    return 220, 220, 220
  end
end

local function buildActiveDotsList(filterSrc)
  local list, totalDPS = {}, 0
  local tnow = nowTime()
  for k, st in pairs(THREAT.dotStates) do
    if (not filterSrc or st.src == filterSrc) and (not st.endAt or st.endAt > tnow) then
      local tick = safeTick(st.tick, 0.5)
      local nextIn = (st.nextTickAt and (st.nextTickAt - tnow)) or tick
      table.insert(list,
        {
          label = st.label or k,
          dps = st.dps or 0,
          tick = tick,
          nextIn = math.max(0, nextIn),
          dtype = st.type or "magical",
          src = st.src or "sched",
          fb = st.isFallback or false
        })
      totalDPS = totalDPS + (st.dps or 0)
    end
  end
  table.sort(list,
    function(a, b)
      if math.abs(a.nextIn - b.nextIn) > 0.02 then return a.nextIn < b.nextIn end
      return a.dps > b.dps
    end)
  return list, totalDPS
end

function script.OnDraw()
  if not uiBool(Overlay, true) then return end
  if not uiBool(Switch, true) then return end
  if not hero or not Armlet then return end

  local ok = pcall(function()
    local screen = screenSizeCompat()
    local baseX, baseY = 1300, screen.y - 520

    local snapshot = PLAN.overlay or {}
    local hasSnapshot = (snapshot.ts or 0) > 0
    local on = uiBool(Switch, true)
    local armOn = snapshot.armOn
    if armOn == nil then armOn = Ability.GetToggleState(Armlet) end
    local preLead = hasSnapshot and (snapshot.preLead or 0) or 0
    local window = (hasSnapshot and snapshot.window and snapshot.window > 0) and snapshot.window or
        math.max(C.ARMLET_HP_SHIFT + 0.90, 1.9)
    local tnow = nowTime()

    local events = hasSnapshot and (snapshot.events or {}) or {}
    local livePulse = THREAT.lastEventPulse or {}
    local heroThreat = THREAT.lastHeroThreat or {}
    local controlThreat = {
      count = THREAT.lastControlThreat.count or 0,
      firstAt = THREAT.lastControlThreat.firstAt,
      severity = THREAT.lastControlThreat.severity or 0,
      chainCount = THREAT.lastControlThreat.chainCount or 0,
      chainLock = THREAT.lastControlThreat.chainLock or 0,
      firstName = THREAT.lastControlThreat.name or ""
    }
    local uncertainty = THREAT.lastUncertaintyState or {}
    local executionThreat = {
      count = THREAT.lastExecutionThreat.count or 0,
      soon = THREAT.lastExecutionThreat.soon or 0,
      lethalSoon = THREAT.lastExecutionThreat.lethalSoon or false,
      firstAt = THREAT.lastExecutionThreat.firstAt,
      firstName = THREAT.lastExecutionThreat.name or ""
    }
    local dynamicSafeBuf = hasSnapshot and (snapshot.dynamicSafeBuf or C.TUNED_SAFETY_BUFFER) or C.TUNED_SAFETY_BUFFER
    local roshanPressure = hasSnapshot and (snapshot.roshanPressure or false) or false
    local roshanHit = hasSnapshot and (snapshot.roshanHit or 0) or 0
    local riskState = THREAT.lastRiskState or { score = 0, mode = "normal", thresholdBias = 0 }
    local totalIncoming = hasSnapshot and (snapshot.totalIncoming or 0) or 0
    local curHP                    = hasSnapshot and (snapshot.curHP or 0) or math.floor(Entity.GetHealth(hero))
    local focusMode = hasSnapshot and (snapshot.focusMode or false) or false
    local focusScore = hasSnapshot and (snapshot.focusScore or 0) or 0
    local thresholdActive = hasSnapshot and (snapshot.thresholdActive == true) or (PLAN.thresholdEpisode.active == true)
    local thresholdEpisodeId = hasSnapshot and (snapshot.thresholdEpisodeId or 0) or (PLAN.thresholdEpisode.id or 0)
    local activePlan = hasSnapshot and snapshot.activePlan or getActivePlanSummary(tnow)
    local planSuppressed = hasSnapshot and (snapshot.planSuppressed == true) or hasAnyPlanSuppression(tnow)
    local plannerPrioritySource = hasSnapshot and (snapshot.plannerPrioritySource or "none") or "none"
    local lastCancelReason = hasSnapshot and snapshot.lastCancelReason or PLAN.cancelState.lastReasonRaw
    local lastCancelAgo = hasSnapshot and snapshot.lastCancelAgo or
        ((PLAN.cancelState.lastCancelTs or 0) > 0 and (tnow - PLAN.cancelState.lastCancelTs) or nil)
    local recentReasons = hasSnapshot and (snapshot.recentReasons or {}) or recentReasonsSnapshot(4)
    local modDots, totalModDotDPS  = buildActiveDotsList("mod")
    local schedDots, totalSchedDPS = buildActiveDotsList("sched")
    local reflectDots, totalReflectDPS = buildActiveDotsList("reflect")

    local panelW, panelH           = 640, 470

    drawPanel(baseX - 10, baseY - 10, panelW, panelH, { 20, 20, 24, 200 }, { 120, 120, 140, 220 })
    local statusText = on and "Armlet Abuse: ENABLED" or "Armlet Abuse: DISABLED"
    local statusColor = on and { 0, 220, 0 } or { 220, 0, 0 }
    drawShadowText(fontTitle, baseX + 4, baseY + 4, statusText, statusColor[1], statusColor[2], statusColor[3], 255)

    local y = baseY + 28
    local pingRaw, pingAvg, pingJitter = getLatencyStats()
    drawShadowText(font, baseX + 6, y, string.format("HP: %d", curHP), 255, 255, 255, 230); y = y + 18
    drawShadowText(fontSmall, baseX + 6, y,
      string.format("Ping: %.0f/%.0f ms  Jitter: %.0f ms  Lead: %.0f ms  ShiftLock: %s  Lookahead: %.2fs",
        pingRaw * 1000, pingAvg * 1000, pingJitter * 1000, preLead * 1000, isShiftLocked() and "YES" or "NO", window), 200,
      200,
      200, 230); y = y + 16

    local countsLine = string.format(
      "Events: %d  |  Mod-DoTs: %d (%.0f)  |  Sched-DoTs: %d (%.0f)  |  BM Reflect: %d (%.0f)  |  Projs: %d",
      #events, #modDots, totalModDotDPS, #schedDots, totalSchedDPS, #reflectDots, totalReflectDPS, #THREAT.incomingProjectiles)
    drawShadowText(fontSmall, baseX + 6, y, countsLine, 200, 200, 200, 230); y = y + 16
    drawShadowText(fontSmall, baseX + 6, y,
      string.format("Pulse: lead+%.0fms  soonHits=%d  soonDmg=%.0f  dotTicks=%d  atk=%d  pred=%d  cad=%d  fast=%.2f",
        (livePulse.leadBonus or 0) * 1000, livePulse.soonHits or 0, livePulse.soonDmg or 0, livePulse.dotTicks or 0,
        livePulse.attackEvents or 0, livePulse.predicted or 0, livePulse.cadenceSources or 0,
        livePulse.fastestCadence or 0), 190, 220, 255, 235)
    y = y + 16
    local riskLabel = string.upper(tostring(riskState.mode or "normal"))
    drawShadowText(fontSmall, baseX + 6, y,
      string.format("Risk: %s (%.0f)  dynSafe=%d  uncertain+%d", riskLabel, riskState.score or 0, dynamicSafeBuf,
        uncertainty.bonus or 0), 255, 165, 145, 235); y = y + 16
    if heroThreat.attackers > 0 then
      drawShadowText(fontSmall, baseX + 6, y,
        string.format("Hero threat: %d  soon=%.0f  dotSoon=%.0f  burst=%.0f", heroThreat.attackers,
          heroThreat.soon, heroThreat.dotSoon, heroThreat.burst), 255, 190, 140, 235); y = y + 16
    end
    if focusMode then
      drawShadowText(fontSmall, baseX + 6, y, string.format("Focus mode: ON  score=%.0f", focusScore), 255, 165, 95, 235)
      y = y + 16
    end
    if executionThreat.count > 0 and executionThreat.firstAt then
      drawShadowText(fontSmall, baseX + 6, y,
        string.format("Execution threat: %d  in %.2fs  dmg=%.0f  lethal=%s", executionThreat.count,
          math.max(0, executionThreat.firstAt - tnow), executionThreat.soon or 0,
          executionThreat.lethalSoon and "YES" or "NO"), 255, 120, 120, 235); y = y + 16
    end
    if controlThreat.count > 0 and controlThreat.firstAt then
      drawShadowText(fontSmall, baseX + 6, y,
        string.format("Incoming control: %d  in %.2fs  sev=%.2f  chain=%d/%.1fs  (%s)", controlThreat.count,
          math.max(0, controlThreat.firstAt - tnow), controlThreat.severity or 0, controlThreat.chainCount or 0,
          controlThreat.chainLock or 0, controlThreat.firstName or "control"),
        255, 150, 120, 235); y = y + 16
    end
    if roshanPressure then
      drawShadowText(fontSmall, baseX + 6, y, string.format("Roshan pressure: YES (max hit %.0f)", roshanHit), 255, 210, 120,
        235); y = y + 16
    end

    drawShadowText(fontSmall, baseX + 6, y,
      string.format("Threshold episode: %s #%d  |  Planner source: %s", thresholdActive and "ACTIVE" or "idle",
        thresholdEpisodeId or 0, plannerPrioritySource), 180, 220, 170, 235)
    y = y + 16
    if activePlan then
      drawShadowText(fontSmall, baseX + 6, y,
        string.format("Active plan: %s in %.2fs  [%s/%d]", tostring(activePlan.reasonRaw or "plan"),
          math.max(0, activePlan.eta or 0), tostring(activePlan.kind or "plan"), activePlan.priority or 0),
        140, 255, 180, 240)
      y = y + 18
    else
      drawShadowText(fontSmall, baseX + 6, y, "Active plan: none", 160, 200, 160, 220); y = y + 16
    end
    drawShadowText(fontSmall, baseX + 6, y,
      string.format("Replans suppressed: %s  |  Last cancel: %s", planSuppressed and "YES" or "NO",
        lastCancelReason and string.format("%s (%.2fs)", tostring(lastCancelReason), math.max(0, lastCancelAgo or 0)) or "none"),
      175, 215, 255, 230)
    y = y + 16

    if #modDots > 0 then
      drawShadowText(font, baseX + 6, y, "Active DoT Modifiers:", 255, 200, 120, 240); y = y + 18
      for i = 1, math.min(5, #modDots) do
        local d = modDots[i]
        local tcol = d.dtype == "physical" and { 255, 120, 80 } or
            (d.dtype == "pure" and { 255, 255, 120 } or { 170, 120, 255 })
        drawShadowText(fontSmall, baseX + 12, y,
          string.format("%s%s  dps=%.0f  tick=%.2fs  next=%.2fs", d.label, d.fb and " (fb)" or "", d.dps, d.tick,
            d.nextIn), tcol[1], tcol[2], tcol[3], 240)
        y = y + 14
      end
    else
      drawShadowText(fontSmall, baseX + 6, y, "Active DoT Modifiers: none", 160, 220, 160, 230); y = y + 16
    end

    if #schedDots > 0 then
      drawShadowText(font, baseX + 6, y, "Scheduled DoTs:", 200, 220, 255, 240); y = y + 18
      for i = 1, math.min(4, #schedDots) do
        local d = schedDots[i]
        local tcol = d.dtype == "physical" and { 255, 120, 80 } or
            (d.dtype == "pure" and { 255, 255, 120 } or { 170, 120, 255 })
        drawShadowText(fontSmall, baseX + 12, y,
          string.format("%s%s  dps=%.0f  tick=%.2fs  next=%.2fs", d.label, d.fb and " (fb)" or "", d.dps, d.tick,
            d.nextIn), tcol[1], tcol[2], tcol[3], 240)
        y = y + 14
      end
    end
    if #reflectDots > 0 then
      drawShadowText(font, baseX + 6, y, "Blade Mail Reflect DoTs:", 255, 170, 120, 240); y = y + 18
      for i = 1, math.min(4, #reflectDots) do
        local d = reflectDots[i]
        local tcol = d.dtype == "physical" and { 255, 120, 80 } or
            (d.dtype == "pure" and { 255, 255, 120 } or { 255, 170, 120 })
        drawShadowText(fontSmall, baseX + 12, y,
          string.format("%s  dps=%.0f  tick=%.2fs  next=%.2fs", d.label, d.dps, d.tick, d.nextIn), tcol[1], tcol[2],
          tcol[3], 240)
        y = y + 14
      end
    end

    local showN = math.min(8, #events)
    if showN > 0 then
      drawShadowText(font, baseX + 6, y, string.format("Next (%.2fs): ~%.0f dmg", window, totalIncoming), 255, 255, 255,
        230); y = y + 18
      for i = 1, showN do
        local ev = events[i]
        local eta = math.max(0, ev.time - tnow)
        local r, g, b = colorForType(ev.type)
        local cpTxt = (ev.cp and ev.cp > 0) and string.format(" cp=%.2f", ev.cp) or ""
        drawShadowText(fontMono, baseX + 10, y,
          string.format("[%s] in %.2fs  dmg=%.0f%s", (ev.label or ev.type), eta, ev.dmg or 0, cpTxt), r, g, b, 240)
        y = y + 16
      end
    else
      drawShadowText(font, baseX + 6, y, "No threats in window", 160, 220, 160, 230); y = y + 18
    end

    if uiBool(OverlayDetails, true) then
      drawShadowText(fontSmall, baseX + 6, y,
        string.format("Under threshold for: %.2fs  (deadline=%.2fs)", STATE.thresholdSince and (tnow - STATE.thresholdSince) or 0,
          C.MAX_DEFERRAL_AFTER_THRESHOLD), 180, 200, 255, 230); y = y + 16
      local sinceToggle = tnow - STATE.lastToggle
      drawShadowText(fontSmall, baseX + 6, y,
        string.format("Armlet: %s  |  Since last toggle: %.2fs  |  Next shift ready in: %.2fs",
          armOn and "ON" or "OFF", sinceToggle, math.max(0, nextShiftReadyAt() - tnow)), 180, 200, 255, 230); y = y + 16
      drawShadowText(fontSmall, baseX + 6, y,
        string.format("Counters: melee=%d atkProj=%d atkFB=%d abilProj=%d abilFB=%d", THREAT.counter.melee, THREAT.counter.projAttacks,
          THREAT.counter.fbAttacks, THREAT.counter.projAbility, THREAT.counter.fbAbility), 200, 200, 200, 230); y = y + 16
      drawShadowText(fontSmall, baseX + 6, y,
        string.format("Hero mem: atk=%d soon=%.0f burst=%.0f heavy=%.0f", THREAT.lastHeroThreat.attackers or 0,
          THREAT.lastHeroThreat.soon or 0, THREAT.lastHeroThreat.burst or 0, THREAT.lastHeroThreat.heavyHit or 0), 220, 185, 145, 230)
      y = y + 16
      if THREAT.lastControlThreat and (THREAT.lastControlThreat.count or 0) > 0 and THREAT.lastControlThreat.firstAt then
        drawShadowText(fontSmall, baseX + 6, y,
          string.format("Control mem: %d  in %.2fs  sev=%.2f  chain=%d/%.1fs  %s", THREAT.lastControlThreat.count or 0,
            math.max(0, (THREAT.lastControlThreat.firstAt or tnow) - tnow), THREAT.lastControlThreat.severity or 0,
            THREAT.lastControlThreat.chainCount or 0, THREAT.lastControlThreat.chainLock or 0,
            THREAT.lastControlThreat.name or "control"), 255, 170, 135, 230)
        y = y + 16
      end
      drawShadowText(fontSmall, baseX + 6, y,
        string.format("Risk mem: %s  score=%.0f  threshold+%d", string.upper(tostring(THREAT.lastRiskState.mode or "normal")),
          THREAT.lastRiskState.score or 0, THREAT.lastRiskState.thresholdBias or 0), 255, 175, 155, 230)
      y = y + 16
      drawShadowText(fontSmall, baseX + 6, y,
        string.format("Uncertainty mem: +%d  fallback=%d  dmg=%.0f  jitter=%.0fms", THREAT.lastUncertaintyState.bonus or 0,
          THREAT.lastUncertaintyState.fallback or 0, THREAT.lastUncertaintyState.damage or 0, THREAT.lastUncertaintyState.jitter or 0),
        190, 210, 255, 230)
      y = y + 16
      if THREAT.lastExecutionThreat and (THREAT.lastExecutionThreat.count or 0) > 0 and THREAT.lastExecutionThreat.firstAt then
        drawShadowText(fontSmall, baseX + 6, y,
          string.format("Execution mem: %d  in %.2fs  dmg=%.0f  lethal=%s", THREAT.lastExecutionThreat.count or 0,
            math.max(0, (THREAT.lastExecutionThreat.firstAt or tnow) - tnow), THREAT.lastExecutionThreat.soon or 0,
            (THREAT.lastExecutionThreat.lethalSoon and "YES" or "NO")), 255, 140, 140, 230)
        y = y + 16
      end
      drawShadowText(fontSmall, baseX + 6, y,
        string.format("Threshold hold: %.2fs  |  Safe-gap once: %s", STATE.thresholdSince and (tnow - STATE.thresholdSince) or 0,
          PLAN.thresholdEpisode.allowSafeGapNow and "READY" or "USED"),
        180, 230, 180, 230)
      y = y + 16
      if THREAT.lastFocusState and THREAT.lastFocusState.active then
        drawShadowText(fontSmall, baseX + 6, y, string.format("Focus mem: ON  score=%.0f", THREAT.lastFocusState.score or 0),
          255, 170, 120, 230)
        y = y + 16
      end

      if #recentReasons > 0 then
        drawShadowText(fontSmall, baseX + 6, y, "Recent reasons:", 200, 220, 255, 230); y = y + 16
        for i = 1, math.min(3, #recentReasons) do
          drawShadowText(fontSmall, baseX + 12, y, tostring(recentReasons[i]), 190, 205, 230, 230)
          y = y + 14
        end
      end

      drawShadowText(fontSmall, baseX + 6, y, "Decision Trace:", 200, 220, 255, 230); y = y + 16
      local dCutoff = tnow - 5.0
      local dShown = 0
      for i = #PLAN.decisionTraceLog, 1, -1 do
        local e = PLAN.decisionTraceLog[i]
        if e.time >= dCutoff then
          drawShadowText(fontSmall, baseX + 12, y, e.text, e.r, e.g, e.b, 230)
          y = y + 14
          dShown = dShown + 1
          if dShown >= 5 then break end
        end
      end
      if dShown == 0 then
        drawShadowText(fontSmall, baseX + 12, y, "(none in last 5.0s)", 140, 140, 160, 230)
        y = y + 14
      end

      drawShadowText(fontSmall, baseX + 6, y, "Recent Animations:", 200, 200, 200, 230); y = y + 16
      local cutoff = tnow - 2.5
      local shown = 0
      for i = #PLAN.recentAnimLog, 1, -1 do
        local e = PLAN.recentAnimLog[i]
        if e.time >= cutoff then
          drawShadowText(fontSmall, baseX + 12, y, e.text, e.r, e.g, e.b, 230); y = y + 14; shown = shown + 1; if shown >= 4 then break end
        end
      end
      if shown == 0 then
        drawShadowText(fontSmall, baseX + 12, y, "(none in last 2.5s)", 140, 140, 160, 230); y = y + 14
      end

      local lx = baseX + 6
      local function legend(label, col, offy)
        setDrawColorCompat(col[1], col[2], col[3], 230); drawFilledRectCompat(lx, offy + 4, 10, 10)
        drawShadowText(fontSmall, lx + 14, offy, label, 200, 200, 200, 230)
      end
      legend("Melee", { 255, 140, 90 }, y); legend("Attack (proj)", { 255, 120, 80 }, y + 16); legend(
        "Attack (fallback)", { 210, 160, 120 }, y + 32)
      legend("Ability (proj precise)", { 240, 190, 60 }, y + 48); legend("Ability (fallback)", { 200, 180, 120 }, y + 64); legend(
        "DoT Tick", { 170, 120, 255 }, y + 80); legend("Execute / HP-removal", { 255, 95, 95 }, y + 96)
      y = y + 116
    end

    if uiBool(OverlayTimeline, true) then
      local tlX, tlY = baseX + 10, y + 6
      local tlW, tlH = panelW - 30, 18
      setDrawColorCompat(50, 50, 60, 220); drawFilledRectCompat(tlX, tlY, tlW, tlH)
      setDrawColorCompat(140, 140, 160, 240); drawOutlineRectCompat(tlX, tlY, tlW, tlH)
      setDrawColorCompat(0, 200, 200, 200)
      drawTextCompat(fontSmall, tlX - 2, tlY - 14, "0s")
      drawTextCompat(fontSmall, tlX + tlW - 30, tlY - 14, string.format("%.2fs", window))
      for i = 1, math.min(12, #events) do
        local ev = events[i]
        local r, g, b = colorForType(ev.type)
        local tRel = clamp((ev.time - tnow) / window, 0, 1)
        local ex = tlX + math.floor(tRel * tlW)
        setDrawColorCompat(r, g, b, 255); drawLineCompat(ex, tlY, ex, tlY + tlH)
      end
      if activePlan then
        local planAt = tnow + math.max(0, activePlan.eta or 0)
        local tRel = clamp((planAt - tnow) / window, 0, 1)
        local ex = tlX + math.floor(tRel * tlW)
        setDrawColorCompat(120, 255, 160, 255); drawLineCompat(ex, tlY, ex, tlY + tlH)
        drawTextCompat(fontSmall, ex - 8, tlY + tlH + 2, "PLAN")
      end
    end
  end)
  if not ok then end
end

function script.OnGameEnd()
  hero                = nil
  Armlet              = nil
  STATE.lastToggle          = 0
  STATE.armOnSince          = 0
  STATE.prevArmState        = nil
  STATE.thresholdSince      = nil
  STATE.toggledThisFrame    = false
  THREAT.lastHadActiveDot    = false
  THREAT.incomingProjectiles = {}
  THREAT.dotStates           = {}
  THREAT.castWindups         = {}
  THREAT.incomingControls    = {}
  PLAN.recentAnimLog       = {}
  PLAN.lastAnimDedup       = {}
  PLAN.decisionTraceLog    = {}
  THREAT.lastEventPulse      = {
    leadBonus = 0,
    soonHits = 0,
    soonDmg = 0,
    dotTicks = 0,
    attackEvents = 0,
    predicted = 0,
    cadenceSources = 0,
    fastestCadence = nil,
    srcCadence = {},
    ts = 0
  }
  PLAN.lastPulseDebugAt    = 0
  PLAN.lastLogLineAt       = {}
  PLAN.lastPulseLogState   = { soonHits = -1, predicted = -1, cadenceBucket = -1 }
  PLAN.lastReasonByGroup   = {}
  PLAN.thresholdEpisode    = {
    active = false,
    id = 0,
    enteredAt = nil,
    enteredHP = 0,
    allowSafeGapNow = true,
    lastExitAt = nil
  }
  clearPlanState()
  PLAN.cancelState  = { lastCancelAt = -10, lastReasonGroup = nil, lastReasonRaw = nil, lastCancelTs = 0 }
  PLAN.suppressUntil   = {}
  PLAN.overlay    = {
    ts = 0,
    curHP = 0,
    armOn = false,
    preLead = 0,
    window = 0,
    events = {},
    totalIncoming = 0,
    dynamicSafeBuf = C.TUNED_SAFETY_BUFFER,
    focusMode = false,
    focusScore = 0,
    roshanPressure = false,
    roshanHit = 0,
    thresholdEpisodeId = 0,
    thresholdActive = false,
    activePlan = nil,
    planSuppressed = false,
    lastCancelReason = nil,
    lastCancelAgo = nil,
    riskMode = "normal",
    plannerPrioritySource = "none",
    recentReasons = {}
  }
  THREAT.lastHeroThreat      = {
    attackers = 0,
    burst = 0,
    soon = 0,
    dotSoon = 0,
    sustained = 0,
    pressure = 0,
    dotCount = 0,
    firstHitDmg = 0,
    heavyHit = 0,
    ts = 0
  }
  THREAT.lastControlThreat   = { count = 0, firstAt = nil, severity = 0, name = "", chainCount = 0, chainLock = 0, ts = 0 }
  THREAT.lastFocusState      = { active = false, score = 0, ts = 0 }
  THREAT.lastUncertaintyState = { bonus = 0, fallback = 0, damage = 0, jitter = 0, ts = 0 }
  THREAT.lastExecutionThreat = { count = 0, soon = 0, lethalSoon = false, firstAt = nil, name = "", ts = 0 }
  THREAT.lastRiskState       = { score = 0, mode = "normal", thresholdBias = 0, ts = 0 }
  THREAT.counter             = { projAttacks = 0, fbAttacks = 0, projAbility = 0, fbAbility = 0, melee = 0 }
end

return script
