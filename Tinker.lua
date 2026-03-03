-- Fallback jungle spots data if LIB_HEROES_DATA is not available
local FALLBACK_JUNGLE_SPOTS = {
  -- Radiant jungle camps (patch 7.40, provided by user)
  {pos = Vector(-4014.1, 1052.4, 256.0), team = 2, type = 1, index = 1},
  {pos = Vector(-5102.7, -105.4, 256.0), team = 2, type = 4, index = 2},
  {pos = Vector(-7990.0, -1738.2, 256.0), team = 2, type = 2, index = 3},
  {pos = Vector(-8367.4, -576.9, 256.0), team = 2, type = 2, index = 4},
  {pos = Vector(-812.2, -7538.8, 134.0), team = 2, type = 2, index = 5},
  {pos = Vector(-2341.2, -8374.5, 128.0), team = 2, type = 1, index = 6},
  {pos = Vector(3231.9, -8365.0, 0.0), team = 2, type = 1, index = 7},
  {pos = Vector(4868.5, -8299.8, 0.0), team = 2, type = 4, index = 8},
  {pos = Vector(4084.7, -5187.9, 128.0), team = 2, type = 1, index = 9},
  {pos = Vector(4615.0, -3720.0, 128.0), team = 2, type = 2, index = 10},

  -- Dire jungle camps (patch 7.40, provided by user)
  {pos = Vector(4232.1, 39.8, 256.0), team = 3, type = 4, index = 11},
  {pos = Vector(3327.2, -1333.3, 256.0), team = 3, type = 1, index = 12},
  {pos = Vector(8463.4, 1304.0, 256.0), team = 3, type = 1, index = 13},
  {pos = Vector(7899.2, -114.0, 256.0), team = 3, type = 2, index = 14},
  {pos = Vector(1064.9, 2566.2, 128.0), team = 3, type = 2, index = 15},
  {pos = Vector(1309.2, 4235.9, 128.0), team = 3, type = 2, index = 16},
  {pos = Vector(-4723.6, 8215.5, 0.0), team = 3, type = 4, index = 17},
  {pos = Vector(-3367.3, 7484.8, 0.0), team = 3, type = 1, index = 18},
  {pos = Vector(-4061.7, 4912.9, 128.0), team = 3, type = 1, index = 19},
  {pos = Vector(-4863.8, 4020.4, 128.0), team = 3, type = 2, index = 20},
}

local function GetJungleSpots()
  if LIB_HEROES_DATA and LIB_HEROES_DATA.jungle_spots then
    return LIB_HEROES_DATA.jungle_spots
  end
  return FALLBACK_JUNGLE_SPOTS
end

-- Fallback Camp functions if not available
if not Camp then
  Camp = {}
end
if not Camp.GetGoldBounty then
  function Camp.GetGoldBounty(camp, useBounty)
    local gold = 0
    if camp.type == 1 then -- Small camp
      gold = useBounty and 71 or 43
    elseif camp.type == 2 then -- Medium camp
      gold = useBounty and 94 or 56
    elseif camp.type == 3 then -- Large camp
      gold = useBounty and 119 or 71
    elseif camp.type == 4 then -- Ancient camp
      gold = useBounty and 162 or 97
    end
    return gold
  end
end

local script        = {}
local translation   = {
  en = {
    root = "Autofarm V2",

    menu_general = "General",
    menu_utilities = "Utilities",
    menu_debug = "Visual Debug",
    toggle_key = "Toggle Key",
    farm_targets = "Farming Targets",
    target_ancients = "Ancient Camps",
    target_non_ancients = "Non‑Ancients",
    target_lane = "Lane Creeps",

    items_to_use = "Usable Items",
    item_bottle = "Bottle",
    item_blink = "Blink Dagger",
    item_shiva = "Shiva's Guard",

    auto_defense_matrix = "Auto Defense Matrix",
    gear_matrix_options = "Defense Matrix Settings",
    matrix_precast = "Auto‑cast at Fountain",
    matrix_panic = "Use while Escaping",

    prefer_bounty = "Prioritize High‑Gold Camps",

    blink_options_label = "Blink Settings",
    gear_blink_behavior = "Blink Behavior",
    blink_travel = "Use for Traveling",
    blink_trees_lane = "Blink into Trees (Lane)",

    bottle_options_label = "Bottle Settings",
    gear_bottle_behavior = "Bottle Behavior",
    bottle_use_hp = "Use when Low HP",
    bottle_use_mana = "Use when Low Mana",

    marching_control_label = "March Control",
    gear_controls = "Controls",
    march_use_custom = "Custom March Counts per Camp",
    march_small = "Small Camps",
    march_medium = "Medium Camps",
    march_large = "Large Camps",
    march_ancient = "Ancient Camps",
    march_lane = "Lane Creeps",
    march_count_fmt = "%d Marches",

    lane_min_creeps_label = "Min Creeps to Farm Wave",
    lane_min_creeps_fmt = "%d creeps",

    status_overlay = "Show Status Overlay",
    gear_overlay_options = "Overlay Settings",
    status_lock = "Lock Position (disable dragging)",

    debug_overlay = "Enable Debug Overlay",
    debug_world = "Draw World Guides",
    gear_world_options = "World Settings",
    debug_show_order_throttle = "Show Order Rate",
    debug_show_spot_metrics = "Show Camp Metrics",
    debug_pretty_map = "Use Polished Map Drawing",
    debug_bounty = "Show Gold on Map/Overlay",

    tooltip_autofarm =
    "Autofarm is still in development (enemies may catch you).\nRecommended once March of the Machines is Level 4 and Rearm is Level 1."
  },
  ru = {
    root = "Авто фарм V2",

    menu_general = "Общее",
    menu_utilities = "Утилиты",
    menu_debug = "Визуал",
    toggle_key = "Клавиша включения",
    farm_targets = "Цели фарма",
    target_ancients = "Древние лагеря",
    target_non_ancients = "Обычные лагеря",
    target_lane = "Крипы на линии",

    items_to_use = "Использовать",
    item_bottle = "Боттл",
    item_blink = "Блинк‑даггер",
    item_shiva = "Шива",

    auto_defense_matrix = "Авто Defense Matrix",
    gear_matrix_options = "Настройки Defense Matrix",
    matrix_precast = "Автокаст у фонтана",
    matrix_panic = "Использовать при побеге",

    prefer_bounty = "Предпочитать более выгодные кемпы",

    blink_options_label = "Настройки Блинка",
    gear_blink_behavior = "Поведение Блинка",
    blink_travel = "Использовать для перемещения",
    blink_trees_lane = "Блинк в деревья (линия)",

    bottle_options_label = "Настройки Ботла",
    gear_bottle_behavior = "Поведение Ботла",
    bottle_use_hp = "Использовать для лечения HP",
    bottle_use_mana = "Использовать для восстановления маны",

    marching_control_label = "Настройки March",
    gear_controls = "Контроль",
    march_use_custom = "Своё количество для каждого лагеря",
    march_small = "Маленькие лагеря",
    march_medium = "Средние лагеря",
    march_large = "Большие лагеря",
    march_ancient = "Древние лагеря",
    march_lane = "Крипы на линии",
    march_count_fmt = "%d каста",

    lane_min_creeps_label = "Мин. крипов для фарма волны",
    lane_min_creeps_fmt = "%d крипов",

    status_overlay = "Показывать оверлей статуса",
    gear_overlay_options = "Настройки оверлея",
    status_lock = "Зафиксировать позицию (запрещает двигать)",

    debug_overlay = "Включить оверлей отладки",
    debug_world = "Рисовать информацию в мире",
    gear_world_options = "Настройки мира",
    debug_show_order_throttle = "Показывать частоту команд",
    debug_show_spot_metrics = "Показывать метрики лагерей",
    debug_pretty_map = "Красивое оформление карты",
    debug_bounty = "Показывать золото на карте/оверлее",

    tooltip_autofarm =
    "Скрипт всё ещё в разработке (враги могут поймать).\nРекомендуется включать при March of the Machines 4 уровня и Rearm 1 уровня."
  }
}

local __lang_cached = nil
local function __lang_index()
  if __lang_cached ~= nil then return __lang_cached end
  local d = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
  local v = d and d:Get() or 0
  if v ~= 0 and v ~= 1 then v = 0 end
  __lang_cached = v
  return v
end

local function __lang_code()
  return __lang_index() == 1 and "ru" or "en"
end

function L(key)
  local code = __lang_code()
  return (translation[code] and translation[code][key]) or (translation.en and translation.en[key]) or tostring(key)
end

do
  local d = Menu.Find("SettingsHidden", "", "", "", "Main", "Language")
  if d and d.SetCallback then
    local prev = d:Get()
    d:SetCallback(function(ctrl)
      local cur = (ctrl and ctrl.Get and ctrl:Get()) or d:Get()
      if cur ~= prev then
        prev = cur
        Engine.ReloadScriptSystem()
      end
    end)
  end
end

local autoFarmMenu = Menu.Create("Heroes", "Hero List", "Tinker", L("root"), L("menu_general"))
local utilityMenu  = Menu.Create("Heroes", "Hero List", "Tinker", L("root"), L("menu_utilities"))
local debugMenu    = Menu.Create("Heroes", "Hero List", "Tinker", L("root"), L("menu_debug"))
Config             = {
  AutoFarm = autoFarmMenu:Bind(L("toggle_key"), Enum.ButtonCode.BUTTON_CODE_NONE, "\u{f11c}"),
  ToFarm = autoFarmMenu:MultiCombo(L("farm_targets"), {
    L("target_ancients"), L("target_non_ancients"), L("target_lane")
  }, { L("target_ancients"), L("target_non_ancients") }),
  ItemsToUse = utilityMenu:MultiSelect(L("items_to_use"), {
    { L("item_bottle"), "panorama/images/items/bottle_png.vtex_c", true },
    { L("item_blink"),  "panorama/images/items/blink_png.vtex_c",  true },
    { L("item_shiva"),  "panorama/images/items/shivas_guard_png.vtex_c", true }
  }, true),
  AutoMatrix = utilityMenu:Switch(L("auto_defense_matrix"), true,
    "panorama/images/spellicons/tinker_defense_matrix_png.vtex_c"),
  Matrix = {},
  PreferBounty = autoFarmMenu:Switch(L("prefer_bounty"), true, "\u{f3d1}"),
  BlinkGroup = utilityMenu:Label(L("blink_options_label"), "panorama/images/items/blink_png.vtex_c"),
  Blink = {},
  BottleGroup = utilityMenu:Label(L("bottle_options_label"), "panorama/images/items/bottle_png.vtex_c"),
  Bottle = {},
  MarchControl = {},
  StatusOverlay = autoFarmMenu:Switch(L("status_overlay"), true, "\u{f2d2}"),
  Status = {},
  Debug = {
    Overlay = debugMenu:Switch(L("debug_overlay"), false, "\u{f108}"),
    World   = debugMenu:Switch(L("debug_world"), false, "\u{f279}"),
  }
}

Config.AutoFarm:ToolTip(L("tooltip_autofarm"))

do
  local g                         = Config.AutoMatrix:Gear(L("gear_matrix_options"))
  Config.Matrix.PrecastAtFountain = g:Switch(L("matrix_precast"), true, "\u{f2cd}")
  Config.Matrix.UseDuringPanic    = g:Switch(L("matrix_panic"), true, "\u{f002}")

  local sg                        = Config.StatusOverlay:Gear(L("gear_overlay_options"))
  Config.Status.Lock              = sg:Switch(L("status_lock"), true, "\u{f023}")

  local overlayGear               = Config.Debug.Overlay:Gear(L("gear_overlay_options"))
  Config.Debug.Orders             = overlayGear:Switch(L("debug_show_order_throttle"), false, "\u{f0ae}")
  Config.Debug.Spot               = overlayGear:Switch(L("debug_show_spot_metrics"), true, "\u{f080}")

  local worldGear                 = Config.Debug.World:Gear(L("gear_world_options"))
  Config.Debug.Pretty             = worldGear:Switch(L("debug_pretty_map"), true, "\u{f5a0}")
  Config.Debug.Bounty             = worldGear:Switch(L("debug_bounty"), true, "\u{f51e}")

  local m                         = autoFarmMenu:Label(L("marching_control_label"), "\u{f0c9}"):Gear(L("gear_controls"))
  Config.MarchControl.UseCustom   = m:Switch(L("march_use_custom"), true, "\u{f013}")
  Config.MarchControl.Small       = m:Slider(L("march_small"), 1, 5, 2, L("march_count_fmt"))
  Config.MarchControl.Medium      = m:Slider(L("march_medium"), 1, 5, 3, L("march_count_fmt"))
  Config.MarchControl.Large       = m:Slider(L("march_large"), 1, 5, 3, L("march_count_fmt"))
  Config.MarchControl.Ancient     = m:Slider(L("march_ancient"), 1, 5, 4, L("march_count_fmt"))
  Config.MarchControl.Lane        = m:Slider(L("march_lane"), 1, 5, 2, L("march_count_fmt"))
  Config.MarchControl.LaneMinCreeps = m:Slider(L("lane_min_creeps_label"), 1, 8, 3, L("lane_min_creeps_fmt"))

  local bg                        = Config.BlinkGroup:Gear(L("gear_blink_behavior"))
  Config.Blink.Travel             = bg:Switch(L("blink_travel"), true, "\u{f70c}")
  Config.Blink.TreesLane          = bg:Switch(L("blink_trees_lane"), true, "\u{f1bb}")

  local botg                      = Config.BottleGroup:Gear(L("gear_bottle_behavior"))
  Config.Bottle.UseHP             = botg:Switch(L("bottle_use_hp"), true, "\u{f004}")
  Config.Bottle.UseMana           = botg:Switch(L("bottle_use_mana"), true, "\u{f0d0}")
end

local function SyncMarchSlidersDisabled()
  local useCustom = Config.MarchControl.UseCustom:Get()
  Config.MarchControl.Small:Disabled(not useCustom)
  Config.MarchControl.Medium:Disabled(not useCustom)
  Config.MarchControl.Large:Disabled(not useCustom)
  Config.MarchControl.Ancient:Disabled(not useCustom)
  Config.MarchControl.Lane:Disabled(not useCustom)
  Config.MarchControl.LaneMinCreeps:Disabled(not useCustom)
end

local __blink_menu_cache = {
  travel = nil,
  trees = nil
}

local function ResolveBlinkMenuSwitch(kind)
  local cacheKey = (kind == "travel") and "travel" or "trees"
  if __blink_menu_cache[cacheKey] and __blink_menu_cache[cacheKey].Get then
    return __blink_menu_cache[cacheKey]
  end

  local leaf = (kind == "travel") and L("blink_travel") or L("blink_trees_lane")
  local ctrl = Menu.Find("Heroes", "Hero List", "Tinker", L("root"), L("menu_utilities"), L("blink_options_label"),
    L("gear_blink_behavior"), leaf)
  if not ctrl then
    local ruLeaf = (kind == "travel") and "Использовать для перемещения" or "Блинк в деревья (линия)"
    ctrl = Menu.Find("Heroes", "Hero List", "Tinker", "Авто фарм V2", "Утилиты", "Настройки Блинка",
      "Поведение Блинка", ruLeaf)
  end
  __blink_menu_cache[cacheKey] = ctrl
  return ctrl
end

local function IsBlinkTravelEnabled()
  if Config.Blink and Config.Blink.Travel and Config.Blink.Travel.Get then
    return Config.Blink.Travel:Get()
  end
  local c = ResolveBlinkMenuSwitch("travel")
  return c and c:Get() or false
end

local function IsTreeBlinkLaneEnabled()
  if Config.Blink and Config.Blink.TreesLane and Config.Blink.TreesLane.Get then
    return Config.Blink.TreesLane:Get()
  end
  local c = ResolveBlinkMenuSwitch("trees")
  return c and c:Get() or false
end

Constants = {
  MARCH_CAST_RANGE              = 900,
  MARCH_PAIR_COVERAGE_FRAC      = 1.1,
  TP_MIN_DISTANCE               = 2000,
  BLINK_MAX_RANGE               = 1200,
  POST_TP_LOCK_TIME             = 3.8,
  NO_REARM_AFTER_TP             = 1.6,
  SAME_SPOT_TP_EPS              = 800,
  SAME_SPOT_TP_COOLDOWN         = 7.5,
  BLINK_HOLD_AFTER_REARM        = 0.6,
  BLINK_SAFE_STANDOFF           = 220,
  BLINK_MIN_DISTANCE            = 450,
  FARM_BLINK_MIN_DISTANCE       = 200,    -- минимальная дистанция блинка для позиционирования на споте
  ORDER_COOLDOWN                = 0.02,
  ORDERS_PER_UPDATE             = 1,
  MOVE_RESEND_INTERVAL          = 0.25,
  MOVE_POS_EPS                  = 72,
  ABILITY_DEDUP_INTERVAL        = 0.18,
  CAST_POS_EPS                  = 48,
  BOTTLE_CHECK_COOLDOWN         = 0.1,
  BOTTLE_MISSING_THRESHOLD      = 50,
  FOUNTAIN_MIN_MANA_FRAC        = 0.5,
  -- Updated for patch 7.40 (user-provided Radiant pos).
  -- Team 2 = Radiant, Team 3 = Dire.
  FOUNTAIN_RADIANT              = Vector(-7250.5, -6733.7, 390.6),
  FOUNTAIN_DIRE                 = Vector(6752.5625, 6281.28125, 384.0),
  SPOT_SCAN_INTERVAL            = 0.35,
  CAMP_CLEAR_DELAY              = 0.8,
  CAMP_CLEAR_CONFIRM_DELAY      = 2,
  MARCH_MIN_RECAST_GAP          = 0.6,
  REARM_MIN_GAP_AFTER_MARCH     = 0.35,
  HOLD_ACTIONS_DURING_CONFIRM   = true,
  PANIC_HP_FRAC                 = 0.40,
  PANIC_COOLDOWN                = 1.5,
  PANIC_ARM_TIME                = 0.25,
  PANIC_MATRIX_COOLDOWN         = 1.0,
  SPOT_COMMIT_TIME              = 5.0,
  FARM_TP_MIN_INTERVAL          = 1.5,
  IDLE_DECISION_DELAY           = 0.15,
  BOUNTY_SCORE_FACTOR_HIGH      = 1.0,
  BOUNTY_SCORE_FACTOR_LOW       = 0.3,
  KEEN_LANDING_RADIUS_STRUCTURE = 800,
  KEEN_LANDING_RADIUS_OUTPOST   = 250,
  ENEMY_RISK_RADIUS             = 1400,
  ENEMY_RISK_PATH_STEP          = 550,
  ENEMY_RISK_W_SPOT             = 1.0,
  ENEMY_RISK_W_ANCHOR           = 1.0,
  ENEMY_RISK_W_PATH             = 1.4,
  ENEMY_RISK_WEIGHT             = 80.0,
  ENEMY_RISK_HARD_BLOCK         = 0.45,
  ENEMY_RISK_BLOCK_RADIUS       = 1000,
  PENDING_TP_MAX_AGE            = 2.5,
  MARCH_VERIFY_MAX_AGE          = 1.2,
  MARCH_VERIFY_COOLDOWN_EPS     = 0.01,
  -- Lane farming
  LANE_CLUSTER_RADIUS           = 900,
  LANE_MIN_CREEPS               = 3,
  LANE_GOLD_PER_CREEP           = 45,
  LANE_NO_CREEPS_TIMEOUT        = 2.0,
  LANE_REFARM_COOLDOWN          = 12.0,
  -- Tree blink (lane)
  TREE_BLINK_SEARCH_RADIUS      = 1000,
  TREE_BLINK_MIN_TREES          = 5,
  TREE_BLINK_TREE_CHECK_RADIUS  = 300,
  TREE_BLINK_MAX_WAVE_DIST      = 1000,
  TREE_BLINK_SETTLE_TIME        = 0.22,
  -- Adaptive lane bias
  LANE_BIAS_EARLY               = 5.0,
  LANE_BIAS_MID                 = 0.0,
  LANE_BIAS_LATE                = -8.0,
  LANE_BIAS_EARLY_TIME          = 900,
  LANE_BIAS_LATE_TIME           = 1800,
  -- Расширенный фарм линии: осадные крипы, подходящие волны, безопасность
  LANE_SIEGE_GOLD_BONUS         = 80,
  LANE_INCOMING_WAVE_RADIUS     = 2500,
  LANE_MARCH_LEAD_DISTANCE      = 200,
  LANE_TOWER_SAFETY_RADIUS      = 2500,
  LANE_TOWER_SAFETY_SCORE       = -6.0,
  -- Защита от провала ТП и хождения пешком
  TP_FAIL_DISTANCE              = 1500,   -- если после ТП-лока дальше этого — ТП провалился
  TP_ARRIVAL_GRACE              = 0.5,    -- задержка после ТП-лока перед проверкой
  WALK_TO_SPOT_MAX_TIME         = 12.0,   -- таймаут ходьбы пешком (секунды)
  SPOT_SAFETY_RECHECK           = 1.5,    -- интервал ре-проверки безопасности спота
  FARMING_STALE_TIMEOUT         = 6.0,    -- таймаут бездействия на споте
  SHIVA_FARM_RADIUS             = 900,
  LASER_LANE_RANGE              = 700,
  EXTRA_TOOL_RETRY_INTERVAL     = 0.12,
  EXTRA_TOOL_CAST_INTERVAL      = 0.30,
  HOLD_RESEND_INTERVAL          = 0.22,
}
State = {
  Hero = nil,
  Player = nil,
  HeroTeam = nil,
  IsChanneling = false,
  Rearm = nil,
  March = nil,
  Laser = nil,
  KeenTeleport = nil,
  Blink = nil,
  Shiva = nil,

  FarmState = "IDLE",
  CurrentFarmSpot = nil,

  MatrixCastTime = 0,

  NextOrderTime = 0,
  OrdersThisUpdate = 0,
  NextBottleCheck = 0,

  LastMovePos = nil,
  LastMoveTime = 0,
  LastHoldTime = 0,
  LastAbilityOrders = {},

  DebugFont = nil,
  LastOrderDebug = nil,
  OrderCounterStart = 0,
  OrdersSentThisSecond = 0,
  OrdersPerSec = 0,

  LastTeleportAt = 0,
  TeleportLockUntil = 0,
  MovingAfterTeleport = false,
  LastTeleportCastPos = nil,
  RecalcAfterTP = false,

  PendingTPPos = nil,
  PendingTPSince = 0,
  PendingTPForce = false,

  BlockTPThisSpot = false,
  LastSpotTelePos = nil,

  LastRearmAt = 0,
  RearmChannelDuration = 3.0,
  RearmBlinkHoldPending = false,
  RearmBlinkChannelSeen = false,
  RearmBlinkHoldUntil = 0,
  LastSpotScan = 0,

  CachedBestSpot = nil,
  AfterMarchCheck = nil,

  LastHP = 0,
  LastHPTime = 0,
  PanicCooldownUntil = 0,
  PanicArmingSince = nil,
  LastPanicMatrixAt = 0,
  PanicReason = nil,

  TargetSpotKey = nil,
  SpotCommitUntil = 0,
  LastFarmTPAt = 0,
  JustClearedSpotAt = 0,

  LastMarchCastAt = 0,

  LastTeleportAnchor = nil,
  CurrentSpotMarchCasts = 0,
  CurrentSpotMarchRequired = nil,
  MarchTotalCasts = 0,
  MarchModeWasCustom = false,
  PendingMarchVerify = nil,
  -- Lane farming state
  LaneWaveCreeps = nil,
  LaneNoCreepsSince = nil,
  LaneWaveLaserDone = false,
  LastLaneFarmPos = nil,
  LastLaneFarmAt  = 0,
  LaneTreeBlinkDone = false,
  TreeBlinkStopPending = false,   -- после tree-blink нужен STOP чтобы герой не пошёл
  LastTreeBlinkAt = 0,
  LastTreeBlinkHoldAt = 0,
  NextExtraToolTry = 0,
  -- Защита от хождения пешком
  MovingToSpotSince = 0,
  FarmingSpotSince = 0,
  LastSpotSafetyCheck = 0,
  LastFarmingAction = 0,
  StatusUI = {
    x = Render.ScreenSize().x / 1.35,
    y = Render.ScreenSize().y / 1.1,
    dragging = false,
    dragDX = 0,
    dragDY = 0,
    mousePrevDown = false
  },

  -- Tracks AutoFarm toggle state between updates
  AutoFarmWasOn = false
}

local Utils = {}

local ORDER_NAME = {
  [Enum.UnitOrder.DOTA_UNIT_ORDER_NONE]             = "NONE",
  [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION] = "MOVE",
  [Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION]    = "HOLD",
  [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET]   = "CAST_NO_TARGET",
  [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION]    = "CAST_POSITION",
  [Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET]      = "CAST_TARGET",
}

local function RecordOrder(order, ability, allowed, reason, targetEntity, targetPos)
  State.LastOrderDebug = {
    at      = GameRules.GetGameTime(),
    order   = ORDER_NAME[order] or tostring(order),
    ability = ability and Ability.GetName(ability) or nil,
    allowed = allowed,
    reason  = reason or (allowed and "sent" or "blocked"),
    tpos    = targetPos
  }
end

local function ShouldAllowOrder(order, ability, targetEntity, targetPos)
  local t = GameRules.GetGameTime()

  if (State.OrdersThisUpdate or 0) >= (Constants.ORDERS_PER_UPDATE or 1) then
    return false, "perUpdateCap"
  end

  if t < (State.NextOrderTime or 0) then
    return false, "globalCooldown"
  end

  if order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION and targetPos then
    local lastPos, lastTime = State.LastMovePos, State.LastMoveTime or 0
    if lastPos and (t - lastTime) < Constants.MOVE_RESEND_INTERVAL and targetPos:Distance(lastPos) < Constants.MOVE_POS_EPS then
      return false, "moveDedup"
    end
    return true
  end

  if order == Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION then
    local lastHold = State.LastHoldTime or 0
    if (t - lastHold) < (Constants.HOLD_RESEND_INTERVAL or 0.22) then
      return false, "holdDedup"
    end
    return true
  end

  if ability then
    local aKey = tostring(ability)
    local last = State.LastAbilityOrders[aKey]
    if last and (t - (last.at or 0)) < Constants.ABILITY_DEDUP_INTERVAL then
      if last.order == order then
        if order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET then
          return false, "abilityNoTargetDedup"
        elseif order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET and targetEntity and last.target == targetEntity then
          return false, "abilityTargetDedup"
        elseif order == Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION and targetPos and last.pos
            and targetPos:Distance(last.pos) < Constants.CAST_POS_EPS then
          return false, "abilityPosDedup"
        end
      end
    end
    return true
  end

  return true
end
local function OnMarchIssued() end

function Utils.IssueOrder(order, ability, data)
  local t = GameRules.GetGameTime()

  -- ══ Кешированная проверка канала (обновляется раз в OnUpdate) ══
  if State.IsChanneling then
    RecordOrder(order, ability, false, "channeling", nil, nil)
    return false
  end

  -- ══ СВЕЖАЯ проверка канала прямо сейчас (ловит задержки между кешем и реальностью) ══
  if State.Hero and NPC.IsChannellingAbility(State.Hero) then
    RecordOrder(order, ability, false, "channeling_fresh", nil, nil)
    return false
  end

  -- ══ Блок ордеров: Rearm отправлен, канал ещё не начался (pre-channel gap) ══
  if State.RearmBlinkHoldPending then
    RecordOrder(order, ability, false, "rearm_pending", nil, nil)
    return false
  end

  -- ══ Абсолютная временная защита канала Rearm ══
  -- Если Rearm был скастован недавно и его канал ещё должен идти по времени — блокируем.
  -- Это страхует от ВСЕХ сбоев IsChannellingAbility и pending-системы.
  if State.LastRearmAt and State.LastRearmAt > 0 then
    local rearmElapsed = t - State.LastRearmAt
    local channelGuard = State.RearmChannelDuration or 3.0
    if rearmElapsed < channelGuard then
      -- Проверяем, действительно ли Rearm канализируется (по его собственному состоянию)
      local rearmBusy = false
      if State.Rearm then
        -- Ability:IsChannelling() — проверяет КОНКРЕТНО эту способность
        if Ability.IsChannelling and Ability.IsChannelling(State.Rearm) then
          rearmBusy = true
        elseif Ability.IsInAbilityPhase and Ability.IsInAbilityPhase(State.Rearm) then
          rearmBusy = true
        end
      end
      if rearmBusy then
        RecordOrder(order, ability, false, "rearm_channel_active", nil, nil)
        return false
      end
    end
  end

  local targetEntity  = (data and type(data) == "userdata" and Entity.IsEntity(data)) and data or nil
  local targetPos     = (data and type(data) == "userdata" and not Entity.IsEntity(data)) and data or nil

  local allow, reason = ShouldAllowOrder(order, ability, targetEntity, targetPos)
  if not allow then
    RecordOrder(order, ability, false, reason, targetEntity, targetPos)
    return false
  end

  Player.PrepareUnitOrders(
    State.Player, order, targetEntity, targetPos, ability,
    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, State.Hero,
    false, false, false, true, false, false
  )

  State.NextOrderTime    = t + Constants.ORDER_COOLDOWN
  State.OrdersThisUpdate = (State.OrdersThisUpdate or 0) + 1

  if t - (State.OrderCounterStart or 0) >= 1.0 then
    State.OrdersPerSec         = State.OrdersSentThisSecond or 0
    State.OrdersSentThisSecond = 0
    State.OrderCounterStart    = t
  end
  State.OrdersSentThisSecond = (State.OrdersSentThisSecond or 0) + 1

  if order == Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION and targetPos then
    State.LastMovePos  = targetPos
    State.LastMoveTime = t
  elseif order == Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION then
    State.LastHoldTime = t
  end

  if ability then
    local aKey = tostring(ability)
    State.LastAbilityOrders[aKey] = { order = order, at = t, pos = targetPos, target = targetEntity }
  end

  RecordOrder(order, ability, true, "sent", targetEntity, targetPos)
  if ability and State.March and ability == State.March then
    OnMarchIssued()
  end
  return true
end

function Utils.CastAbility(ability, order, data)
  if ability and Ability.CanBeExecuted(ability) == -1 then
    local ok = Utils.IssueOrder(order, ability, data)
    return ok
  end
  return false
end

function Utils.MoveTo(pos)
  return Utils.IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION, nil, pos)
end

local function FormatGold(n) return tostring(math.floor(n + 0.5)) .. "g" end

--- Вычисляет время канала Rearm по уровню
local function GetRearmChannelTime()
  if not State.Rearm then return 3.0 end
  local lvl = Ability.GetLevel(State.Rearm) or 1
  if lvl >= 3 then return 0.75 end
  if lvl == 2 then return 1.5 end
  return 3.0
end

local MarkRearmIssued = function(now)
  now = now or GameRules.GetGameTime()
  State.LastRearmAt             = now
  State.RearmChannelDuration    = GetRearmChannelTime()
  State.RearmBlinkHoldPending   = true
  State.RearmBlinkChannelSeen   = false
end

local function UpdateRearmBlinkHold()
  if not State.RearmBlinkHoldPending then return end

  local now = GameRules.GetGameTime()

  -- ══ Проверяем конкретно Rearm ability ══
  local rearmChannelling = false
  if State.Rearm then
    if Ability.IsChannelling and Ability.IsChannelling(State.Rearm) then
      rearmChannelling = true
    elseif Ability.IsInAbilityPhase and Ability.IsInAbilityPhase(State.Rearm) then
      rearmChannelling = true
    end
  end

  -- Фолбэк: если конкретную проверку Rearm не удалось — проверяем общий NPC.IsChannelling
  if not rearmChannelling and State.IsChanneling then
    rearmChannelling = true  -- какая-то способность канализируется — считаем что Rearm
  end

  -- Канал обнаружен
  if rearmChannelling then
    State.RearmBlinkChannelSeen = true
    return
  end

  -- Канал был обнаружен и теперь закончился — снимаем pending, ставим holdUntil
  if State.RearmBlinkChannelSeen then
    State.RearmBlinkHoldPending = false
    State.RearmBlinkChannelSeen = false
    State.RearmBlinkHoldUntil   = now + (Constants.BLINK_HOLD_AFTER_REARM or 0.6)
    return
  end

  -- Канал не был обнаружен. Fallback: ждём полное время канала + запас.
  -- Если канал реально шёл но IsChannelling/IsInAbilityPhase не ловили —
  -- эта защита не даст pending сняться раньше времени.
  local channelDur    = State.RearmChannelDuration or 3.0
  local fallbackDelay = channelDur + 0.4  -- полный канал + запас
  local elapsed       = now - (State.LastRearmAt or 0)
  if elapsed >= fallbackDelay then
    State.RearmBlinkHoldPending = false
    State.RearmBlinkChannelSeen = false
    State.RearmBlinkHoldUntil   = now + (Constants.BLINK_HOLD_AFTER_REARM or 0.6)
  end
end

local function IsBlinkLockedNow()
  local now = GameRules.GetGameTime()

  -- TP-лок: блинк заблокирован пока идёт телепорт (всегда активно)
  if now < (State.TeleportLockUntil or 0) then
    return true
  end

  -- Rearm-холд: блинк заблокирован пока канализируется Rearm (всегда активно)
  if State.RearmBlinkHoldPending and (State.IsChanneling or State.RearmBlinkChannelSeen) then
    return true
  end
  if now < (State.RearmBlinkHoldUntil or 0) then
    return true
  end

  return false
end

local Tinker = {}

--- Eureka (врождённая способность Tinker): каждые 3 INT → 1% CDR предметов, макс 60%.
--- Возвращает множитель (0.4 .. 1.0): умножай на номинальный КД чтобы получить реальный.
function Tinker.GetEurekaCDRMultiplier()
  if not State.Hero then return 1.0 end
  local intel = 0
  if Hero and Hero.GetIntellectTotal then
    intel = Hero.GetIntellectTotal(State.Hero) or 0
  elseif Hero and Hero.GetIntelligence then
    intel = Hero.GetIntelligence(State.Hero) or 0
  elseif NPC and NPC.GetUnitAttribute then
    -- Фолбэк: пробуем через NPC
    intel = 0
  end
  local cdrPct = math.floor(intel / 3)  -- 1% за каждые 3 INT
  cdrPct = math.min(cdrPct, 60)          -- макс 60%
  return 1.0 - (cdrPct / 100.0)
end

--- Возвращает реальный КД предмета с учётом Eureka CDR.
--- nominalCD — базовый КД предмета (например, 15 для Blink).
--- Используется для предсказания: «когда предмет будет доступен после использования».
function Tinker.GetItemCooldownWithEureka(nominalCD)
  return nominalCD * Tinker.GetEurekaCDRMultiplier()
end

local function GetAbilityCooldownRemaining(ability)
  if not ability then return 0 end
  if Ability.GetCooldownTimeRemaining then
    local cd = Ability.GetCooldownTimeRemaining(ability) or 0
    if cd < 0 then cd = 0 end
    return cd
  end
  if Ability.GetCooldown then
    local cd = Ability.GetCooldown(ability) or 0
    if cd < 0 then cd = 0 end
    return cd
  end
  return (Ability.CanBeExecuted(ability) == -1) and 0 or 0.1
end

function Tinker.QueueMarchVerify()
  if not State.March then return end
  State.PendingMarchVerify = {
    requestedAt = GameRules.GetGameTime(),
    baseCD      = GetAbilityCooldownRemaining(State.March),
    expireAt    = GameRules.GetGameTime() + Constants.MARCH_VERIFY_MAX_AGE
  }
end

function Tinker.ProcessMarchVerify()
  local v = State.PendingMarchVerify
  if not v or not State.March then return end
  local now = GameRules.GetGameTime()
  if now > (v.expireAt or 0) then
    State.PendingMarchVerify = nil
    return
  end
  local cd  = GetAbilityCooldownRemaining(State.March)
  local eps = Constants.MARCH_VERIFY_COOLDOWN_EPS or 0.01
  if cd > (v.baseCD or 0) + eps then
    State.MarchTotalCasts = (State.MarchTotalCasts or 0) + 1
    if State.FarmState == "FARMING_SPOT" and State.CurrentFarmSpot then
      State.CurrentSpotMarchCasts = (State.CurrentSpotMarchCasts or 0) + 1
    end
    State.LastMarchCastAt    = now
    State.PendingMarchVerify = nil
  end
end

local function GetRequiredMarchesForCampType(campType)
  local mc = Config.MarchControl
  if campType == 1 then
    return mc.Small:Get()
  elseif campType == 2 then
    return mc.Medium:Get()
  elseif campType == 3 then
    return mc.Large:Get()
  elseif campType == 4 then
    return mc.Ancient:Get()
  elseif campType == 5 then
    return mc.Lane:Get()
  end
  return 0
end

local function ComputeRequiredMarchesForSpot(spot)
  if not spot then return 0 end
  local function req(c)
    if not c or not c.type then return 0 end
    return GetRequiredMarchesForCampType(c.type)
  end
  local r1 = req(spot.camp1)
  if spot.single then return r1 end
  local r2 = req(spot.camp2)
  return math.max(r1, r2)
end

local function NextNeutralCampRespawnTime(now)
  local nextMin = (math.floor(now / 60) + 1) * 60
  return nextMin + 0.25
end

local function MarkCampFarmed(camp, now)
  if not camp then return end
  camp.farmed = true
  camp.farmedAt = now
  camp.respawnAt = NextNeutralCampRespawnTime(now)
end

local function UpdateFarmedCampRespawns()
  local now = GameRules.GetGameTime()
  for _, camp in pairs(GetJungleSpots() or {}) do
    if camp and camp.farmed then
      camp.respawnAt = camp.respawnAt or NextNeutralCampRespawnTime(now)
      if camp.respawnAt and now >= camp.respawnAt then
        camp.farmed = false
        camp.farmedAt = nil
        camp.respawnAt = nil
      end
    end
  end
end

local function MarkSpotFarmedAndLeave()
  local now = GameRules.GetGameTime()
  local settle = Constants.TREE_BLINK_SETTLE_TIME or 0.22
  local treeBlinkSettling = ((now - (State.LastTreeBlinkAt or 0)) < settle)
      or ((now - (State.LastTreeBlinkHoldAt or 0)) < settle)

  -- После tree-blink не выходим из FARMING_SPOT мгновенно:
  -- держим HOLD, пока не закончится settle-окно.
  if treeBlinkSettling then
    if not State.IsChanneling and not State.RearmBlinkHoldPending then
      Utils.IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION, nil, nil)
    end
    return
  end

  local wasLane = false
  if State.CurrentFarmSpot then
    if State.CurrentFarmSpot.isLane then
      wasLane = true
      State.LastLaneFarmPos = State.CurrentFarmSpot.pos
      State.LastLaneFarmAt  = now
    else
      if State.CurrentFarmSpot.camp1 then MarkCampFarmed(State.CurrentFarmSpot.camp1, now) end
      if (not State.CurrentFarmSpot.single) and State.CurrentFarmSpot.camp2 then
        MarkCampFarmed(State.CurrentFarmSpot.camp2, now)
      end
    end
  end
  State.AfterMarchCheck          = nil
  State.FarmState                = "IDLE"
  State.JustClearedSpotAt        = now
  State.CurrentFarmSpot          = nil
  State.CurrentSpotMarchCasts    = 0
  State.CurrentSpotMarchRequired = nil
  State.CachedBestSpot           = nil
  State.LastSpotScan             = 0
  State.TreeBlinkStopPending     = false
  State.LaneWaveLaserDone        = false
  State.LastTreeBlinkAt          = 0
  State.LastTreeBlinkHoldAt      = 0
  State.NextExtraToolTry         = 0

  -- Для lane-цикла ещё раз фиксируем hold, чтобы не автоатаковать крипов сразу после выхода.
  if wasLane then
    Utils.IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION, nil, nil)
  end

  -- Сразу кастуем Rearm на споте, чтобы сбросить КД ТП и не терять время
  if State.Rearm and Ability.CanBeExecuted(State.Rearm) == -1
      and State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then
    local rearmCost  = Ability.GetManaCost(State.Rearm) or 0
    local escapeMana = Tinker.GetEscapeManaCost()
    if ((NPC.GetMana(State.Hero) or 0) - rearmCost) >= escapeMana then
      if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
        MarkRearmIssued(now)
      end
    end
  end
end
OnMarchIssued = function()
  State.LastMarchCastAt = GameRules.GetGameTime()
  Tinker.QueueMarchVerify()
end
local function KeenLevel()
  if not State.KeenTeleport then return 0 end
  return Ability.GetLevel(State.KeenTeleport) or 0
end
local function GetLandingRadiusForAnchor(e)
  if not e or not Entity.IsEntity(e) then return 0 end
  if NPC.IsStructure(e) then
    if string.find((Entity.GetUnitName(e) or ""), "npc_dota_watch_tower") then
      return Constants.KEEN_LANDING_RADIUS_OUTPOST
    end
    return Constants.KEEN_LANDING_RADIUS_STRUCTURE
  end
  return NPC.GetPaddedCollisionRadius(e) or 72
end
function Tinker.ResolveKeenTeleport(desiredPos)
  local lvl                           = KeenLevel()
  local allowCreep                    = lvl >= 2
  local allowHero                     = lvl >= 3

  local bestAnchor, bestCat, bestDist = nil, nil, math.huge

  local function consider(e, cat)
    if not e or not Entity.IsAlive(e) then return end
    if Entity.GetTeamNum(e) ~= State.HeroTeam then return end
    if e == State.Hero then return end
    local p = Entity.GetAbsOrigin(e)
    local d = p:Distance(desiredPos)
    if d < bestDist then
      bestDist, bestAnchor, bestCat = d, e, cat
    end
  end

  for _, e in ipairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_STRUCTURE) or {}) do
    consider(e, "structure")
  end
  if allowCreep then
    for _, e in ipairs(NPCs.GetAll(Enum.UnitTypeFlags.TYPE_LANE_CREEP) or {}) do
      if Entity.IsSameTeam(e, State.Hero) and Entity.IsAlive(e) and not Entity.IsDormant(e) and not NPC.IsWaitingToSpawn(e) then
        consider(e, "creep")
      end
    end
  end
  if allowHero then
    for _, e in ipairs(Heroes.GetAll() or {}) do
      consider(e, "hero")
    end
  end

  if bestAnchor then
    local anchorPos = Entity.GetAbsOrigin(bestAnchor)
    local r         = GetLandingRadiusForAnchor(bestAnchor)
    local d         = desiredPos:Distance(anchorPos)
    local finalPos  = (d > r) and (anchorPos + (desiredPos - anchorPos):Normalized() * r) or desiredPos
    return {
      castOrder     = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
      castData      = finalPos,
      anchor        = bestAnchor,
      anchorPos     = anchorPos,
      landingRadius = r,
      finalPos      = finalPos,
      cat           = bestCat
    }
  end

  return {
    castOrder     = Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION,
    castData      = desiredPos,
    anchor        = nil,
    anchorPos     = nil,
    landingRadius = 0,
    finalPos      = desiredPos,
    cat           = "raw"
  }
end

function Tinker.SelectTeleportAnchor(targetPos)
  local res = Tinker.ResolveKeenTeleport(targetPos)
  if res and res.anchor then
    return {
      entity        = res.anchor,
      pos           = res.anchorPos,
      cat           = res.cat,
      landingRadius = res.landingRadius,
      finalPos      = res.finalPos
    }
  end
  return nil
end

function Tinker.IntendedKeenTPPos(rawPos)
  local res = Tinker.ResolveKeenTeleport(rawPos)
  return res and res.finalPos or rawPos
end

function Tinker.GetEnemyLastKnownPositions()
  local out = {}
  if not Heroes or not Heroes.GetAll then return out end
  for _, h in ipairs(Heroes.GetAll() or {}) do
    if h ~= State.Hero
        and Entity.IsEntity(h)
        and Entity.GetTeamNum(h) ~= State.HeroTeam
        and Entity.IsAlive(h)
        and (not NPC.IsIllusion or not NPC.IsIllusion(h)) then
      local p = (not Entity.IsDormant(h)) and Entity.GetAbsOrigin(h)
          or (Hero.GetLastMaphackPos and Hero.GetLastMaphackPos(h))
      if p then table.insert(out, p) end
    end
  end
  return out
end

local function MinDistToEnemies(pt, enemyPts)
  local best = math.huge
  for _, ep in ipairs(enemyPts) do
    local d = pt:Distance(ep)
    if d < best then best = d end
  end
  return best
end

local function RiskAtPoint(pt, enemyPts)
  local R = Constants.ENEMY_RISK_RADIUS
  if #enemyPts == 0 then return 0 end
  local d = MinDistToEnemies(pt, enemyPts)
  if d >= R then return 0 end
  local r = 1 - (d / R)
  return math.max(0, math.min(1, r * r))
end
local function AnyEnemyWithin(pt, enemyPts, radius)
  for _, ep in ipairs(enemyPts or {}) do
    if pt:Distance(ep) <= radius then return true end
  end
  return false
end
local function PathRisk(a, b, enemyPts)
  if #enemyPts == 0 then return 0 end
  local step = Constants.ENEMY_RISK_PATH_STEP
  local ab   = b - a
  local L    = ab:Length()
  if L < 1 then return RiskAtPoint(b, enemyPts) end
  local dir   = ab / L
  local t     = 0
  local worst = 0
  while t <= L do
    local p = a + dir * t
    local r = RiskAtPoint(p, enemyPts)
    if r > worst then worst = r end
    t = t + step
  end
  local rend = RiskAtPoint(b, enemyPts)
  if rend > worst then worst = rend end
  return worst
end

local function FindTraversablePointNear(pos)
  if not pos then return nil end
  if not (GridNav and GridNav.IsTraversable) then return pos end
  if GridNav.IsTraversable(pos) then return pos end

  local offsets = {
    Vector(80, 0, 0), Vector(-80, 0, 0),
    Vector(0, 80, 0), Vector(0, -80, 0),
    Vector(56, 56, 0), Vector(-56, 56, 0),
    Vector(56, -56, 0), Vector(-56, -56, 0),
  }
  for _, off in ipairs(offsets) do
    local p = pos + off
    if GridNav.IsTraversable(p) then return p end
  end
  return nil
end

local function IsPointHardUnsafe(pos)
  local enemyPts = Tinker.GetEnemyLastKnownPositions()
  if #enemyPts == 0 then return false end
  local riskLimit = Constants.ENEMY_RISK_HARD_BLOCK or 0.45
  local blockR    = Constants.ENEMY_RISK_BLOCK_RADIUS or 1000
  if AnyEnemyWithin(pos, enemyPts, blockR) then return true end
  return RiskAtPoint(pos, enemyPts) >= riskLimit
end
function Tinker.IsTeleportSafe(rawTargetPos)
  local enemyPts = Tinker.GetEnemyLastKnownPositions()
  if #enemyPts == 0 then return true end

  local res       = Tinker.ResolveKeenTeleport(rawTargetPos)
  local land      = (res and res.finalPos) or rawTargetPos
  local anchorPos = (res and res.anchorPos) or land

  local riskLimit = Constants.ENEMY_RISK_HARD_BLOCK or 0.45
  local blockR    = Constants.ENEMY_RISK_BLOCK_RADIUS or 1000

  if RiskAtPoint(rawTargetPos, enemyPts) >= riskLimit then return false end
  if RiskAtPoint(land, enemyPts) >= riskLimit then return false end
  if PathRisk(anchorPos, rawTargetPos, enemyPts) >= riskLimit then return false end

  if AnyEnemyWithin(land, enemyPts, blockR) then return false end
  if AnyEnemyWithin(rawTargetPos, enemyPts, blockR) then return false end

  return true
end

local function HasFountainBuff()
  local modifier = NPC.GetModifier(State.Hero, "modifier_fountain_aura_buff")
  if modifier then
    local continous = Modifier.IsCurrentlyInAuraRange(modifier)
    if continous then
      return true
    end
  end
  return false
end
local function CampIndex(camp)
  if not camp then return "nil" end
  return camp.index and tostring(camp.index) or tostring(camp)
end

local function SpotKey(spot)
  if not spot then return "nil" end
  if spot.single then return "S:" .. CampIndex(spot.camp1) end
  local a = CampIndex(spot.camp1)
  local b = CampIndex(spot.camp2)
  if b < a then a, b = b, a end
  return "P:" .. a .. "|" .. b
end

local function RecenterSpot(spot)
  if not spot then return end
  if spot.single then
    if spot.camp1 and spot.camp1.pos then spot.pos = spot.camp1.pos end
  else
    if spot.camp1 and spot.camp1.pos and spot.camp2 and spot.camp2.pos then
      spot.pos = (spot.camp1.pos + spot.camp2.pos) / 2
    end
  end
end

local function IsCampAncient(camp) return camp and camp.type == 4 end
local function ComputeMarchCastInfo(spot)
  if not spot then return nil end
  local castPos = spot.pos
  local maxDist = 0
  if spot.camp1 and spot.camp1.pos then maxDist = math.max(maxDist, castPos:Distance(spot.camp1.pos)) end
  if spot.camp2 and spot.camp2.pos then maxDist = math.max(maxDist, castPos:Distance(spot.camp2.pos)) end
  return { pos = castPos, maxDist = maxDist }
end

-- ────────────────────────────────────────────────────────────
-- Lane wave detection
-- ────────────────────────────────────────────────────────────

-- Gather alive enemy lane creeps visible on the map.
local function GetEnemyLaneCreeps()
  local out = {}
  for _, e in ipairs(NPCs.GetAll() or {}) do
    if e and Entity.IsAlive(e)
        and not Entity.IsDormant(e)
        and Entity.GetTeamNum(e) ~= State.HeroTeam
        and NPC.IsLaneCreep(e)
        and not NPC.IsWaitingToSpawn(e) then
      table.insert(out, e)
    end
  end
  return out
end

--- Проверяет, является ли юнит осадным крипом (катапультой)
local function IsSiegeCreep(unit)
  if not unit then return false end
  local name = Entity.GetUnitName(unit) or ""
  return string.find(name, "siege") ~= nil or string.find(name, "catapult") ~= nil
end

--- Определяет направление движения вражеских крипов по вектору к нашему фонтану
--- (вражеские крипы всегда идут в сторону нашей базы)
function Tinker.GetCreepMovementDirection(creeps)
  if not creeps or #creeps == 0 then return nil end
  -- Вычисляем центр группы крипов
  local cx, cy, cnt = 0, 0, 0
  for _, e in ipairs(creeps) do
    if e and Entity.IsEntity(e) and Entity.IsAlive(e) then
      local pos = Entity.GetAbsOrigin(e)
      if pos then
        cx = cx + pos.x
        cy = cy + pos.y
        cnt = cnt + 1
      end
    end
  end
  if cnt == 0 then return nil end
  cx, cy = cx / cnt, cy / cnt
  -- Определяем команду героя и вычисляем направление к нашему фонтану
  local myTeam = Entity.GetTeamNum(State.Hero)
  local myFountain = (myTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
  local dir = Vector(myFountain.x - cx, myFountain.y - cy, 0)
  local len = dir:Length2D()
  if len < 0.01 then return nil end
  return dir:Normalized()
end

--- Бонус за близость к союзной вышке (отрицательный = лучше, безопаснее фармить)
function Tinker.GetTowerProximityBonus(pos)
  local radius = Constants.LANE_TOWER_SAFETY_RADIUS or 2500
  local bonus  = Constants.LANE_TOWER_SAFETY_SCORE or -6.0
  for i = 1, (Towers.Count() or 0) do
    local t = Towers.Get(i)
    if t and Entity.IsAlive(t) and Entity.GetTeamNum(t) == State.HeroTeam then
      if Entity.GetAbsOrigin(t):Distance(pos) <= radius then
        return bonus
      end
    end
  end
  return 0
end

--- Обнаруживает подходящую волну крипов рядом с текущей позицией фарма
--- Используется для продолжения фарма, если новая волна уже подошла
function Tinker.DetectIncomingWave(currentPos, excludeCreeps)
  local radius    = Constants.LANE_INCOMING_WAVE_RADIUS or 2500
  local clRadius  = Constants.LANE_CLUSTER_RADIUS or 900
  local minCreeps = Constants.LANE_MIN_CREEPS or 3
  if Config.MarchControl and Config.MarchControl.UseCustom:Get()
      and Config.MarchControl.LaneMinCreeps then
    minCreeps = Config.MarchControl.LaneMinCreeps:Get()
  end

  -- Собираем множество уже обработанных крипов для исключения
  local excludeSet = {}
  if excludeCreeps then
    for _, e in ipairs(excludeCreeps) do excludeSet[e] = true end
  end

  -- Ищем новых вражеских крипов в расширенном радиусе
  local newCreeps = {}
  for _, e in ipairs(NPCs.GetAll() or {}) do
    if e and Entity.IsAlive(e)
        and not Entity.IsDormant(e)
        and Entity.GetTeamNum(e) ~= State.HeroTeam
        and NPC.IsLaneCreep(e)
        and not NPC.IsWaitingToSpawn(e)
        and not excludeSet[e]
        and Entity.GetAbsOrigin(e):Distance(currentPos) <= radius then
      table.insert(newCreeps, e)
    end
  end

  if #newCreeps < minCreeps then return nil end

  -- Кластеризируем найденных крипов
  local cx, cy, cz = 0, 0, 0
  local gold = 0
  local inCluster = {}
  local seedPos = Entity.GetAbsOrigin(newCreeps[1])

  for _, e in ipairs(newCreeps) do
    if Entity.GetAbsOrigin(e):Distance(seedPos) <= clRadius then
      table.insert(inCluster, e)
      local p = Entity.GetAbsOrigin(e)
      cx = cx + p.x; cy = cy + p.y; cz = cz + p.z
      local gmin = (NPC.GetGoldBountyMin and NPC.GetGoldBountyMin(e)) or 0
      local gmax = (NPC.GetGoldBountyMax and NPC.GetGoldBountyMax(e)) or 0
      local baseGold = ((gmin + gmax) > 0 and math.floor((gmin + gmax) / 2) or Constants.LANE_GOLD_PER_CREEP)
      if IsSiegeCreep(e) then baseGold = baseGold + (Constants.LANE_SIEGE_GOLD_BONUS or 80) end
      gold = gold + baseGold
    end
  end

  if #inCluster < minCreeps then return nil end

  local n = #inCluster
  local center = Vector(cx / n, cy / n, cz / n)
  return { center = center, creeps = inCluster, gold = gold }
end

-- Find a stable allied lane creep for lane TP anchor.
-- Returns siege (catapult) first, then ranged creep. Never falls back to melee.
local function FindAllyRangedCreepNear(pos, radius)
  local bestSiege, bestSiegeDist   = nil, math.huge
  local bestRanged, bestRangedDist = nil, math.huge
  for _, e in ipairs(NPCs.GetAll() or {}) do
    if e and Entity.IsAlive(e)
        and not Entity.IsDormant(e)
        and Entity.GetTeamNum(e) == State.HeroTeam
        and NPC.IsLaneCreep(e)
        and not NPC.IsWaitingToSpawn(e) then
      local d = Entity.GetAbsOrigin(e):Distance(pos)
      if d <= radius then
        local hp = Entity.GetHealth(e) or 0
        local maxHp = Entity.GetMaxHealth(e) or 1
        local hpFrac = hp / math.max(1, maxHp)
        if hpFrac >= 0.35 then
          if IsSiegeCreep(e) and d < bestSiegeDist then
            bestSiege = e
            bestSiegeDist = d
          elseif NPC.IsRanged(e) and d < bestRangedDist then
            bestRanged = e
            bestRangedDist = d
          end
        elseif NPC.IsRanged(e) and d < bestRangedDist then
          -- fallback: низкое HP, но лучше чем ничего, чем TP в пустоту
          bestRanged = e; bestRangedDist = d
        end
      end
    end
  end
  return bestSiege or bestRanged
end

-- ────────────────────────────────────────────────────────────
-- Tree blink position finder (for lane farming)
-- ────────────────────────────────────────────────────────────
-- Находит позицию В КУЧУ деревьев (кластер) в радиусе блинка от героя.
-- Марши уже прокастованы до блинка, поэтому march-range не учитывается.
-- Возвращает Vector (центроид кластера) или nil.
function Tinker.FindTreeBlinkPos(heroPos, wavePos)
  if not Trees then return nil end
  local searchR   = Constants.TREE_BLINK_SEARCH_RADIUS or 1000
  local clusterR  = Constants.TREE_BLINK_TREE_CHECK_RADIUS or 300
  local minTrees  = Constants.TREE_BLINK_MIN_TREES or 5
  local maxWaveD  = Constants.TREE_BLINK_MAX_WAVE_DIST or 1000
  local blinkMax  = Constants.BLINK_MAX_RANGE or 1200
  local enemyPts  = Tinker.GetEnemyLastKnownPositions()
  local riskLimit = Constants.ENEMY_RISK_HARD_BLOCK or 0.45
  local blockR    = Constants.ENEMY_RISK_BLOCK_RADIUS or 1000

  local function getTreePos(t)
    if Entity and Entity.GetAbsOrigin then return Entity.GetAbsOrigin(t) end
    return nil
  end
  local function treeActive(t)
    local p = getTreePos(t)
    if not p then return false end
    if GridNav and GridNav.IsNearbyTree then
      return GridNav.IsNearbyTree(p, 10)
    end
    return true
  end

  -- Направление к базе — предпочитаем прятаться ближе к нашей стороне
  local fountainPos = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
  local baseDir = (fountainPos - wavePos):Normalized()

  -- Собираем все живые деревья в радиусе поиска
  local allTrees = Trees.InRadius(wavePos, searchR, 0, 0) or {}
  local treePositions = {}
  for _, tree in ipairs(allTrees) do
    local tp = getTreePos(tree)
    if tp and treeActive(tree) then
      treePositions[#treePositions + 1] = tp
    end
  end
  if #treePositions < minTrees then return nil end

  local bestPos   = nil
  local bestScore = -math.huge
  -- Множество уже проверенных центроидов (избегаем дублей)
  local checked = {}

  for _, tp in ipairs(treePositions) do
    local waveD = tp:Distance(wavePos)
    -- Дерево должно быть в допустимом радиусе и доступно блинком
    if waveD >= 200 and waveD <= maxWaveD and tp:Distance(heroPos) <= blinkMax then
      -- Считаем плотность кластера и вычисляем центроид группы
      local clusterCount = 0
      local cx, cy, cz = 0, 0, 0
      for _, otp in ipairs(treePositions) do
        if tp:Distance(otp) <= clusterR then
          clusterCount = clusterCount + 1
          cx = cx + otp.x
          cy = cy + otp.y
          cz = cz + otp.z
        end
      end

      if clusterCount >= minTrees then
        cx = cx / clusterCount
        cy = cy / clusterCount
        cz = cz / clusterCount

        -- Дедупликация: не оцениваем тот же кластер повторно
        local ckey = math.floor(cx / 80) .. "," .. math.floor(cy / 80)
        if not checked[ckey] then
          checked[ckey] = true

          local centroid = Vector(cx, cy, cz)
          local standPos = FindTraversablePointNear(centroid)
          if standPos then
            local standHeroD = standPos:Distance(heroPos)
            local standWaveD = standPos:Distance(wavePos)
            if standHeroD <= blinkMax and standWaveD <= maxWaveD then
              local unsafe = false
              local riskPenalty = 0.0
              if #enemyPts > 0 then
                unsafe = AnyEnemyWithin(standPos, enemyPts, blockR)
                if not unsafe then
                  local r = RiskAtPoint(standPos, enemyPts)
                  if r >= riskLimit then
                    unsafe = true
                  else
                    riskPenalty = r * 8.0
                  end
                end
              end
              if not unsafe then
                -- Скоринг: плотность деревьев — главный фактор
                local treeScore = clusterCount * 5.0
                -- Небольшой штраф за дальность (не доминирующий)
                local distScore = -(standWaveD / 400.0)
                -- Бонус за сторону базы (безопаснее)
                local toStand   = (standPos - wavePos):Normalized()
                local baseDot   = toStand.x * baseDir.x + toStand.y * baseDir.y
                local sideScore = baseDot * 3.0

                local score = treeScore + distScore + sideScore - riskPenalty
                if score > bestScore then
                  bestScore = score
                  bestPos   = standPos
                end
              end
            end
          end
        end
      end
    end
  end

  return bestPos
end

-- ────────────────────────────────────────────────────────────
-- Adaptive lane score bias
-- ────────────────────────────────────────────────────────────
-- Returns a dynamic bias value based on game time.
-- Early game → positive (penalize lane, prefer jungle).
-- Late game  → negative (prefer lane over jungle).
function Tinker.GetAdaptiveLaneBias()
  local dotaTime = 0
  if GameRules and GameRules.GetDOTATime then
    dotaTime = GameRules.GetDOTATime() or 0
  end
  if dotaTime < 0 then dotaTime = 0 end

  local earlyT = Constants.LANE_BIAS_EARLY_TIME or 900   -- 15 min
  local lateT  = Constants.LANE_BIAS_LATE_TIME  or 1800  -- 30 min
  local earlyB = Constants.LANE_BIAS_EARLY      or 5.0
  local midB   = Constants.LANE_BIAS_MID        or 0.0
  local lateB  = Constants.LANE_BIAS_LATE       or -8.0

  if dotaTime <= earlyT then
    -- Lerp from earlyB to midB over [0, earlyT]
    local f = dotaTime / earlyT
    return earlyB + (midB - earlyB) * f
  elseif dotaTime <= lateT then
    -- Lerp from midB to lateB over [earlyT, lateT]
    local f = (dotaTime - earlyT) / (lateT - earlyT)
    return midB + (lateB - midB) * f
  else
    return lateB
  end
end

-- ────────────────────────────────────────────────────────────
-- Compute March cast target, capping distance to MARCH_CAST_RANGE
-- ────────────────────────────────────────────────────────────
-- When the hero blinked into trees, they may be far from spot.pos.
-- March of the Machines travels from hero in cast direction, so we
-- only need to AIM in the right direction within cast range.
function Tinker.GetMarchTarget(spot)
  if not State.Hero or not Entity.GetAbsOrigin then return spot.pos end
  local heroPos = Entity.GetAbsOrigin(State.Hero)
  if not heroPos then return spot.pos end

  local targetPos = spot.pos

  -- Для фарма линии: смещаем цель March в направлении движения крипов (lead)
  if spot.isLane and spot.laneCreeps and #spot.laneCreeps > 0 then
    local moveDir = Tinker.GetCreepMovementDirection(spot.laneCreeps)
    if moveDir then
      local leadDist = Constants.LANE_MARCH_LEAD_DISTANCE or 200
      targetPos = targetPos + moveDir * leadDist
    end
  end

  local dist = heroPos:Distance(targetPos)
  local castRange = Constants.MARCH_CAST_RANGE or 900
  if dist <= castRange then
    return targetPos
  end
  -- Ограничиваем до cast range, чтобы герой не подбегал
  local dir = (targetPos - heroPos):Normalized()
  return heroPos + dir * (castRange - 50)
end

-- Simple greedy clustering of lane creeps.
-- Returns list of { center = Vector, creeps = { entity… }, gold = number }.
function Tinker.FindLaneWaves()
  local creeps   = GetEnemyLaneCreeps()
  if #creeps == 0 then return {} end
  local used     = {}
  local clusters = {}
  local clRadius = Constants.LANE_CLUSTER_RADIUS

  local minCreeps = Constants.LANE_MIN_CREEPS
  if Config.MarchControl and Config.MarchControl.UseCustom:Get()
      and Config.MarchControl.LaneMinCreeps then
    minCreeps = Config.MarchControl.LaneMinCreeps:Get()
  end

  for i, seed in ipairs(creeps) do
    if not used[i] then
      local group    = { seed }
      used[i]        = true
      local seedPos  = Entity.GetAbsOrigin(seed)
      for j = i + 1, #creeps do
        if not used[j] then
          local p = Entity.GetAbsOrigin(creeps[j])
          if seedPos:Distance(p) <= clRadius then
            table.insert(group, creeps[j])
            used[j] = true
          end
        end
      end
      if #group >= minCreeps then
        -- Compute center and gold.
        local cx, cy, cz = 0, 0, 0
        local gold = 0
        local hasSiege = false
        for _, u in ipairs(group) do
          local p = Entity.GetAbsOrigin(u)
          cx = cx + p.x; cy = cy + p.y; cz = cz + p.z
          local gmin = (NPC.GetGoldBountyMin and NPC.GetGoldBountyMin(u)) or 0
          local gmax = (NPC.GetGoldBountyMax and NPC.GetGoldBountyMax(u)) or 0
          local baseGold = ((gmin + gmax) > 0 and math.floor((gmin + gmax) / 2) or Constants.LANE_GOLD_PER_CREEP)
          -- Осадные крипы (катапульты) повышают приоритет волны
          if IsSiegeCreep(u) then
            baseGold = baseGold + (Constants.LANE_SIEGE_GOLD_BONUS or 80)
            hasSiege = true
          end
          gold = gold + baseGold
        end
        local n      = #group
        local center = Vector(cx / n, cy / n, cz / n)
        table.insert(clusters, { center = center, creeps = group, gold = gold, hasSiege = hasSiege })
      end
    end
  end
  return clusters
end

-- Refresh the position of a lane spot to match the live creep positions.
function Tinker.RefreshLaneSpotPos(spot)
  if not spot or not spot.isLane then return end
  local alive = {}
  for _, e in ipairs(spot.laneCreeps or {}) do
    if e and Entity.IsEntity(e) and Entity.IsAlive(e) and not Entity.IsDormant(e) then
      table.insert(alive, e)
    end
  end
  -- Also pick up any new nearby enemy lane creeps.
  local radius = Constants.LANE_CLUSTER_RADIUS
  local center = spot.pos
  for _, e in ipairs(NPCs.GetAll() or {}) do
    if e and Entity.IsAlive(e)
        and not Entity.IsDormant(e)
        and Entity.GetTeamNum(e) ~= State.HeroTeam
        and NPC.IsLaneCreep(e)
        and not NPC.IsWaitingToSpawn(e)
        and Entity.GetAbsOrigin(e):Distance(center) <= radius then
      local found = false
      for _, a in ipairs(alive) do if a == e then found = true; break end end
      if not found then table.insert(alive, e) end
    end
  end
  spot.laneCreeps = alive
  if #alive == 0 then return end
  local cx, cy, cz = 0, 0, 0
  for _, u in ipairs(alive) do
    local p = Entity.GetAbsOrigin(u)
    cx = cx + p.x; cy = cy + p.y; cz = cz + p.z
  end
  local n = #alive
  spot.pos       = Vector(cx / n, cy / n, cz / n)
  spot.camp1.pos = spot.pos
end

-- ────────────────────────────────────────────────────────────

function Tinker.FindBestFarmSpot()
  local myPos                   = Entity.GetAbsOrigin(State.Hero)
  local enabledTargets          = Config.ToFarm:ListEnabled() or {}
  local wantAncient, wantNonAnc, wantLane = false, false, false
  for _, name in ipairs(enabledTargets) do
    if name == L("target_ancients") then wantAncient = true end
    if name == L("target_non_ancients") then wantNonAnc = true end
    if name == L("target_lane") then wantLane = true end
  end
  if not (wantAncient or wantNonAnc or wantLane) then return nil end

  local enemyPts  = Tinker.GetEnemyLastKnownPositions()
  local wSpot     = Constants.ENEMY_RISK_W_SPOT
  local wAnchor   = Constants.ENEMY_RISK_W_ANCHOR
  local wPath     = Constants.ENEMY_RISK_W_PATH
  local riskW     = Constants.ENEMY_RISK_WEIGHT
  local riskLimit = Constants.ENEMY_RISK_HARD_BLOCK
  local blockR    = Constants.ENEMY_RISK_BLOCK_RADIUS
  local bountyK   = Config.PreferBounty:Get() and Constants.BOUNTY_SCORE_FACTOR_HIGH or
      Constants.BOUNTY_SCORE_FACTOR_LOW

  -- ─── Jungle candidates ───
  local bestJungleSpot = nil
  local bestJungleScore = math.huge
  if wantAncient or wantNonAnc then
    local allCamps, selectedSet = {}, {}
    for _, camp in pairs(GetJungleSpots()) do
      if not camp.farmed and camp.team == State.HeroTeam then
        table.insert(allCamps, camp)
        local isAnc = IsCampAncient(camp)
        if (isAnc and wantAncient) or (not isAnc and wantNonAnc) then
          selectedSet[camp] = true
        end
      end
    end

    local coverageMax = Constants.MARCH_CAST_RANGE * Constants.MARCH_PAIR_COVERAGE_FRAC

    -- Pairs
    local bestPairScore, bestPair, bestPairGold = math.huge, nil, 0
    if #allCamps >= 2 then
      for i = 1, #allCamps do
        for j = i + 1, #allCamps do
          local campA, campB = allCamps[i], allCamps[j]
          if selectedSet[campA] or selectedSet[campB] then
            local AB = (campA.pos - campB.pos):Length()
            if (AB * 0.5) <= coverageMax then
              local center        = (campA.pos + campB.pos) / 2
              local distScore     = myPos:Distance(center) / 100.0
              local spreadPenalty = AB / 200.0
              local gold          = (Camp.GetGoldBounty(campA, true) + Camp.GetGoldBounty(campB, true))
              local bountyScore   = (gold / 50.0) * bountyK

              local anchorPos = Tinker.IntendedKeenTPPos(center)
              local rSpot_    = RiskAtPoint(center, enemyPts)
              local rAnchor_  = RiskAtPoint(anchorPos, enemyPts)
              local rPath_    = PathRisk(anchorPos, center, enemyPts)

              local score = math.huge
              if not ((rSpot_ >= riskLimit) or (rAnchor_ >= riskLimit) or (rPath_ >= riskLimit)
                  or AnyEnemyWithin(anchorPos, enemyPts, blockR)) then
                local riskPenalty = (wSpot * rSpot_ + wAnchor * rAnchor_ + wPath * rPath_) * riskW
                score             = distScore + spreadPenalty + riskPenalty - bountyScore
              end
              if score < bestPairScore then
                bestPairScore, bestPair, bestPairGold = score, { campA, campB }, gold
              end
            end
          end
        end
      end
    end

    if bestPair then
      bestJungleSpot  = { pos = (bestPair[1].pos + bestPair[2].pos) / 2, camp1 = bestPair[1], camp2 = bestPair[2], gold = bestPairGold }
      bestJungleScore = bestPairScore
    else
      local bestSingle, bestSingleScore, bestSingleGold = nil, math.huge, 0
      for camp, _ in pairs(selectedSet) do
        local distScore   = myPos:Distance(camp.pos) / 100.0
        local gold        = Camp.GetGoldBounty(camp, true)
        local bountyScore = (gold / 50.0) * bountyK

        local anchorPos = Tinker.IntendedKeenTPPos(camp.pos)
        local rSpot_    = RiskAtPoint(camp.pos, enemyPts)
        local rAnchor_  = RiskAtPoint(anchorPos, enemyPts)
        local rPath_    = PathRisk(anchorPos, camp.pos, enemyPts)

        local score = math.huge
        if not ((rSpot_ >= riskLimit) or (rAnchor_ >= riskLimit) or (rPath_ >= riskLimit)
            or AnyEnemyWithin(anchorPos, enemyPts, blockR)) then
          local riskPenalty = (wSpot * rSpot_ + wAnchor * rAnchor_ + wPath * rPath_) * riskW
          score             = distScore + riskPenalty - bountyScore
        end
        if score < bestSingleScore then
          bestSingleScore, bestSingle, bestSingleGold = score, camp, gold
        end
      end
      if bestSingle then
        bestJungleSpot  = { pos = bestSingle.pos, camp1 = bestSingle, single = true, gold = bestSingleGold }
        bestJungleScore = bestSingleScore
      end
    end
  end

  -- ─── Lane wave candidates ───
  local bestLaneSpot  = nil
  local bestLaneScore = math.huge
  if wantLane then
    local waves = Tinker.FindLaneWaves()
    local laneCooldown = Constants.LANE_REFARM_COOLDOWN or 12.0
    for _, wave in ipairs(waves) do
      -- Skip waves near the position we just finished farming (prevent re-pick loop).
      if State.LastLaneFarmPos and (GameRules.GetGameTime() - (State.LastLaneFarmAt or 0)) < laneCooldown then
        if wave.center:Distance(State.LastLaneFarmPos) < (Constants.LANE_CLUSTER_RADIUS or 900) then
          goto continue_lane
        end
      end
      local pos         = wave.center
      local distScore   = myPos:Distance(pos) / 100.0
      local gold        = wave.gold
      local bountyScore = (gold / 50.0) * bountyK

      local anchorPos = Tinker.IntendedKeenTPPos(pos)
      local rSpot_    = RiskAtPoint(pos, enemyPts)
      local rAnchor_  = RiskAtPoint(anchorPos, enemyPts)
      local rPath_    = PathRisk(anchorPos, pos, enemyPts)

      local score = math.huge
      if not ((rSpot_ >= riskLimit) or (rAnchor_ >= riskLimit) or (rPath_ >= riskLimit)
          or AnyEnemyWithin(anchorPos, enemyPts, blockR)) then
        local riskPenalty = (wSpot * rSpot_ + wAnchor * rAnchor_ + wPath * rPath_) * riskW
        -- Бонус за близость к союзной вышке (безопаснее пушить)
        local towerBonus = Tinker.GetTowerProximityBonus(pos)
        score             = distScore + riskPenalty - bountyScore + Tinker.GetAdaptiveLaneBias() + towerBonus
      end
      if score < bestLaneScore then
        bestLaneScore = score
        bestLaneSpot  = {
          pos        = pos,
          camp1      = { pos = pos, type = 5, index = "lane_" .. tostring(#wave.creeps), farmed = false, isLane = true },
          single     = true,
          isLane     = true,
          gold       = gold,
          laneCreeps = wave.creeps,
        }
      end
      ::continue_lane::
    end
  end

  -- ─── Pick the best among jungle and lane ───
  if bestJungleSpot and bestLaneSpot then
    if bestLaneScore < bestJungleScore then return bestLaneSpot end
    return bestJungleSpot
  end
  if bestJungleSpot then return bestJungleSpot end
  if bestLaneSpot then return bestLaneSpot end
  return nil
end

function Tinker.GetBestFarmSpotCached()
  local t = GameRules.GetGameTime()
  if State.CachedBestSpot and t - (State.LastSpotScan or 0) < Constants.SPOT_SCAN_INTERVAL then
    return State.CachedBestSpot
  end
  local best = Tinker.FindBestFarmSpot()
  if best and not best.camp2 then best.single = true end
  State.CachedBestSpot = best
  State.LastSpotScan   = t
  return best
end

local function ManaCost(ability) return (ability and Ability.GetManaCost(ability)) or 0 end

function Tinker.GetEscapeManaCost()
  local tpCost     = State.KeenTeleport and Ability.GetManaCost(State.KeenTeleport) or 0
  local keenReady  = State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1
  local rearmCost  = State.Rearm and Ability.GetManaCost(State.Rearm) or 0
  local rearmReady = State.Rearm and Ability.CanBeExecuted(State.Rearm) == -1

  if keenReady then return tpCost end
  if rearmReady then return rearmCost + tpCost end
  return rearmCost + tpCost
end

function Tinker.GetCampCycleManaCost()
  local tp       = ManaCost(State.KeenTeleport)
  local march    = ManaCost(State.March)
  local rearm    = ManaCost(State.Rearm)
  local tpReady  = State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1
  local preRearm = tpReady and 0 or rearm
  return preRearm + tp + march + rearm + march + tp
end

--- Минимальная мана ДО каста ТП, чтобы после прибытия хватило на march + rearm + tp_home
function Tinker.GetManaNeededBeforeTP()
  local tpCost    = State.KeenTeleport and (Ability.GetManaCost(State.KeenTeleport) or 0) or 0
  local marchCost = State.March and (Ability.GetManaCost(State.March) or 0) or 0
  local rearmCost = State.Rearm and (Ability.GetManaCost(State.Rearm) or 0) or 0
  -- После ТП (ТП на КД): march + rearm (сброс ТП) + tp домой
  return tpCost + marchCost + rearmCost + tpCost
end

--- Проверяет, хватит ли текущей маны для ТП с гарантией минимального фарм-цикла
function Tinker.HasManaAfterTP()
  if not State.KeenTeleport or not State.March or not State.Rearm then return true end
  local curMana = NPC.GetMana(State.Hero) or 0
  return curMana >= Tinker.GetManaNeededBeforeTP()
end

function Tinker.HasManaForFullCampCycle()
  if not State.KeenTeleport or not State.March or not State.Rearm then return true end
  local curMana  = NPC.GetMana(State.Hero) or 0
  local maxMana  = NPC.GetMaxMana(State.Hero) or 0
  local need     = Tinker.GetCampCycleManaCost()
  local minNeed  = Tinker.GetManaNeededBeforeTP()
  -- Если полный цикл не помещается в пул маны, проверяем хотя бы минимальный (1 march + escape)
  if need > maxMana then return curMana >= math.min(minNeed, maxMana * 0.95) end
  return curMana >= need
end

function Tinker.NeedsToReturnToFountain()
  if not State.KeenTeleport then return false end
  local escapeMana = Tinker.GetEscapeManaCost()
  return (NPC.GetMana(State.Hero) or 0) < escapeMana
end

function Tinker.ShouldRequestTeleport(pos, force)
  if force then return true end
  local now = GameRules.GetGameTime()
  if now < (State.TeleportLockUntil or 0) then return false end

  local atFountain = HasFountainBuff()
  if not atFountain and now - (State.LastFarmTPAt or 0) < Constants.FARM_TP_MIN_INTERVAL then
    return false
  end

  local intended = Tinker.IntendedKeenTPPos(pos)

  if State.FarmState == "MOVING_TO_SPOT" and State.BlockTPThisSpot and State.LastSpotTelePos then
    if State.LastSpotTelePos:Distance(intended) <= Constants.SAME_SPOT_TP_EPS then return false end
  end

  if State.LastTeleportCastPos and State.LastTeleportCastPos:Distance(intended) <= Constants.SAME_SPOT_TP_EPS then
    if (now - (State.LastTeleportAt or 0)) < Constants.SAME_SPOT_TP_COOLDOWN then return false end
  end

  local myPos = Entity.GetAbsOrigin(State.Hero)
  if myPos:Distance(pos) <= intended:Distance(pos) then
    return false
  end
  if not Tinker.IsTeleportSafe(pos) then
    return false
  end

  return true
end

function Tinker.TryTeleportTo(pos, force)
  if not State.KeenTeleport then return false end
  if Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then return false end
  local now = GameRules.GetGameTime()
  if not force and now < (State.TeleportLockUntil or 0) then return false end

  if not force and not Tinker.IsTeleportSafe(pos) then
    return false
  end

  local res      = Tinker.ResolveKeenTeleport(pos)
  local finalPos = res.finalPos
  local myPos    = Entity.GetAbsOrigin(State.Hero)

  if not force and myPos:Distance(finalPos) <= Constants.TP_MIN_DISTANCE then return false end
  if not force and myPos:Distance(pos) <= finalPos:Distance(pos) then return false end

  local issued = Utils.IssueOrder(res.castOrder, State.KeenTeleport, res.castData)
  if not issued then return false end

  State.LastTeleportAt      = now
  State.TeleportLockUntil   = now + Constants.POST_TP_LOCK_TIME
  State.LastTeleportCastPos = finalPos
  State.LastTeleportAnchor  = res.anchor or nil
  State.MovingAfterTeleport = true
  State.RecalcAfterTP       = true
  return true
end

-- Simulate "Alt+Keen Teleport" to home fountain: cast with no target.
function Tinker.TryTeleportHome(force)
  if not State.KeenTeleport then return false end
  if Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then return false end
  local now = GameRules.GetGameTime()
  if not force and now < (State.TeleportLockUntil or 0) then return false end

  local issued = Utils.IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, State.KeenTeleport, nil)
  if not issued then return false end

  State.LastTeleportAt      = now
  State.TeleportLockUntil   = now + Constants.POST_TP_LOCK_TIME
  State.LastTeleportCastPos = Entity.GetAbsOrigin(State.Hero)
  State.LastTeleportAnchor  = nil
  State.MovingAfterTeleport = true
  State.RecalcAfterTP       = true
  return true
end

function Tinker.GetHomeFountainEntity()
  local now = GameRules.GetGameTime()
  if State.HomeFountain and Entity.IsEntity(State.HomeFountain) then
    if Entity.IsAlive(State.HomeFountain) and Entity.GetTeamNum(State.HomeFountain) == State.HeroTeam then
      return State.HomeFountain
    end
  end
  if (State.LastFountainScan or 0) > 0 and (now - (State.LastFountainScan or 0)) < 2.0 then
    return State.HomeFountain
  end
  State.LastFountainScan = now

  local structs = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_STRUCTURE) or {}
  for _, e in ipairs(structs) do
    if e and Entity.IsEntity(e) and Entity.IsAlive(e) and Entity.GetTeamNum(e) == State.HeroTeam then
      local name = Entity.GetUnitName(e) or ""
      if string.find(name, "fountain") then
        State.HomeFountain = e
        return e
      end
    end
  end
  State.HomeFountain = nil
  return nil
end

function Tinker.TryTeleportToFountain(force)
  if not State.KeenTeleport then return false end
  if Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then return false end
  local now = GameRules.GetGameTime()
  if not force and now < (State.TeleportLockUntil or 0) then return false end

  local fountain = Tinker.GetHomeFountainEntity()
  if fountain then
    local issued = Utils.IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, State.KeenTeleport, fountain)
    if issued then
      State.LastTeleportAt      = now
      State.TeleportLockUntil   = now + Constants.POST_TP_LOCK_TIME
      State.LastTeleportCastPos = Entity.GetAbsOrigin(fountain)
      State.LastTeleportAnchor  = fountain
      State.MovingAfterTeleport = true
      State.RecalcAfterTP       = true
      return true
    end
  end

  local fountainPos = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
  return Tinker.TryTeleportTo(fountainPos, force)
end

function Tinker.RequestTeleportToSpot(spot, force)
  if not spot then return false end
  local key        = SpotKey(spot)
  local now        = GameRules.GetGameTime()
  local atFountain = HasFountainBuff()
  local wantForce  = force or atFountain

  if State.TargetSpotKey and key ~= State.TargetSpotKey then
    if not wantForce and now < (State.SpotCommitUntil or 0) then return false end
  end

  -- Для лейна: ТП на союзного крипа (ближе к волне), вышка только как последний вариант
  local tpPos = spot.pos
  if spot.isLane then
    -- Приоритет 1: катапульта/рейндж-крип (маг) рядом с волной.
    -- Не якоримся в мили-крипов: они слишком часто умирают в драке.
    local stableCreep = FindAllyRangedCreepNear(spot.pos, Constants.LANE_CLUSTER_RADIUS or 900)
    if stableCreep and Entity.IsAlive(stableCreep) then
      tpPos = Entity.GetAbsOrigin(stableCreep)
    else
      -- Приоритет 2: такой же стабильный якорь в расширенном радиусе.
      local wideStable = FindAllyRangedCreepNear(spot.pos, (Constants.LANE_CLUSTER_RADIUS or 900) * 1.5)
      if wideStable and Entity.IsAlive(wideStable) then
        tpPos = Entity.GetAbsOrigin(wideStable)
      end
      -- Вышку НЕ используем — она далеко от волны и герой теряет время
    end
  end

  -- Не телепортируемся на спот, если после ТП не хватит маны на march + escape
  if not wantForce and not Tinker.HasManaAfterTP() then return false end

  if not Tinker.ShouldRequestTeleport(tpPos, wantForce) and not wantForce then return false end

  if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1 then
    local started = Tinker.TryTeleportTo(tpPos, wantForce)
    if started then
      State.TargetSpotKey   = key
      State.SpotCommitUntil = now + Constants.SPOT_COMMIT_TIME
      if State.FarmState == "MOVING_TO_SPOT" then
        State.BlockTPThisSpot = true
        State.LastSpotTelePos = Tinker.IntendedKeenTPPos(tpPos)
      end
      State.LastFarmTPAt = now
      return true
    else
      State.PendingTPPos   = tpPos
      State.PendingTPSince = now
      State.PendingTPForce = wantForce
      return true
    end
  end
  if State.Rearm
      and Ability.CanBeExecuted(State.Rearm) == -1
      and State.KeenTeleport
      and Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then
    local needMana = (Ability.GetManaCost(State.Rearm) or 0) + (Ability.GetManaCost(State.KeenTeleport) or 0)
    if (NPC.GetMana(State.Hero) or 0) >= needMana then
      State.PendingTPPos   = tpPos
      State.PendingTPSince = now
      State.PendingTPForce = false
      if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
        MarkRearmIssued(now)
        State.TargetSpotKey   = key
        State.SpotCommitUntil = now + Constants.SPOT_COMMIT_TIME
      end
      return true
    end
  end

  return false
end

function Tinker.HandleAutoBottle()
  if not Config.ItemsToUse:Get(L("item_bottle")) or State.IsChanneling then return end
  if State.RearmBlinkHoldPending then return end  -- не сбиваем Rearm бутылкой
  if not Config.Bottle.UseHP:Get() and not Config.Bottle.UseMana:Get() then return end

  local t = GameRules.GetGameTime()
  if t < (State.NextBottleCheck or 0) then return end
  State.NextBottleCheck = t + Constants.BOTTLE_CHECK_COOLDOWN

  local bottle = NPC.GetItem(State.Hero, "item_bottle", true)
  if not bottle or Ability.CanBeExecuted(bottle) ~= -1 or Item.GetCurrentCharges(bottle) <= 0 then return end
  if NPC.HasModifier(State.Hero, "modifier_bottle_regeneration") then return end

  local hpMissing   = Entity.GetMaxHealth(State.Hero) - Entity.GetHealth(State.Hero)
  local manaMissing = NPC.GetMaxMana(State.Hero) - NPC.GetMana(State.Hero)

  local needHP      = Config.Bottle.UseHP:Get() and (hpMissing >= Constants.BOTTLE_MISSING_THRESHOLD)
  local needMana    = Config.Bottle.UseMana:Get() and (manaMissing >= Constants.BOTTLE_MISSING_THRESHOLD)

  if needHP or needMana then
    Utils.CastAbility(bottle, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil)
  end
end

local function CountCampAliveCreeps(camp)
  if not camp or type(camp.alive_creeps) ~= "table" then return 0 end
  local cnt = 0
  for _, unit in pairs(camp.alive_creeps) do
    if unit and Entity.IsAlive(unit) then
      cnt = cnt + 1
    end
  end
  return cnt
end

local function FindNearestEnemyLaneCreepInRange(origin, range, preferred)
  local best, bestDist = nil, math.huge

  local function consider(e)
    if not e or not Entity.IsEntity(e) then return end
    if not Entity.IsAlive(e) or Entity.IsDormant(e) then return end
    if Entity.GetTeamNum(e) == State.HeroTeam then return end
    if not NPC.IsLaneCreep(e) or NPC.IsWaitingToSpawn(e) then return end
    local d = Entity.GetAbsOrigin(e):Distance(origin)
    if d <= range and d < bestDist then
      best = e
      bestDist = d
    end
  end

  if preferred then
    for _, e in ipairs(preferred) do
      consider(e)
    end
  end
  if best then return best end

  for _, e in ipairs(NPCs.GetAll() or {}) do
    consider(e)
  end
  return best
end

local function HasAliveNeutralNear(pos, radius)
  if not pos then return false end
  for _, e in ipairs(NPCs.GetAll() or {}) do
    if e and Entity.IsAlive(e) and not Entity.IsDormant(e) and not NPC.IsWaitingToSpawn(e) then
      local isNeutral = (NPC.IsNeutral and NPC.IsNeutral(e)) or (Entity.GetTeamNum(e) == 4)
      if isNeutral and Entity.GetAbsOrigin(e):Distance(pos) <= radius then
        return true
      end
    end
  end
  return false
end

local function CampLikelyAlive(camp)
  if not camp or camp.farmed or not camp.pos then return false end
  if CountCampAliveCreeps(camp) > 0 then return true end
  return HasAliveNeutralNear(camp.pos, 430)
end

local function CanShivaHitCamp(heroPos, camp, radius)
  if not camp or not camp.pos then return false end
  return heroPos:Distance(camp.pos) <= (radius * 0.92)
end

function Tinker.TryUseFarmExtraTools(spot, escapeMana)
  if not spot or not State.Hero then return false end
  if State.IsChanneling or State.RearmBlinkHoldPending then return false end

  local now = GameRules.GetGameTime()
  if now < (State.NextExtraToolTry or 0) then return false end

  local mana = NPC.GetMana(State.Hero) or 0
  local heroPos = Entity.GetAbsOrigin(State.Hero)
  local retryIn = Constants.EXTRA_TOOL_RETRY_INTERVAL or 0.12
  local castGap = Constants.EXTRA_TOOL_CAST_INTERVAL or 0.30

  if spot.isLane then
    local req = State.CurrentSpotMarchRequired or 0
    if req > 0 and (State.CurrentSpotMarchCasts or 0) >= req then return false end
    if State.LaneWaveLaserDone then return false end

    local rearmReady = State.Rearm and Ability.CanBeExecuted(State.Rearm) == -1
    local marchReady = State.March and Ability.CanBeExecuted(State.March) == -1
    if rearmReady and not marchReady then
      return false
    end

    if not State.Laser or Ability.CanBeExecuted(State.Laser) ~= -1 then return false end

    local castRange = Constants.LASER_LANE_RANGE or 700
    if Ability.GetCastRange then
      local ar = Ability.GetCastRange(State.Laser) or 0
      if ar > 0 then castRange = ar end
    end

    local target = FindNearestEnemyLaneCreepInRange(heroPos, castRange + 25, spot.laneCreeps)
    if not target then
      State.NextExtraToolTry = now + retryIn
      return false
    end

    local laserCost = Ability.GetManaCost(State.Laser) or 0
    if (mana - laserCost) < escapeMana then return false end

    if Utils.CastAbility(State.Laser, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, target) then
      State.LastFarmingAction = now
      State.LaneWaveLaserDone = true
      State.NextExtraToolTry  = now + castGap
      return true
    end

    State.NextExtraToolTry = now + retryIn
    return false
  end

  if not Config.ItemsToUse:Get(L("item_shiva")) then return false end
  if not State.Shiva or Ability.CanBeExecuted(State.Shiva) ~= -1 then return false end

  local shivaCost = Ability.GetManaCost(State.Shiva) or 0
  if (mana - shivaCost) < escapeMana then return false end

  local r = Constants.SHIVA_FARM_RADIUS or 900
  local c1Alive = CampLikelyAlive(spot.camp1)
  local c2Alive = CampLikelyAlive(spot.camp2)

  if spot.single then
    if not c1Alive then return false end
    if not CanShivaHitCamp(heroPos, spot.camp1, r) then return false end
  else
    local aliveCount = (c1Alive and 1 or 0) + (c2Alive and 1 or 0)
    if aliveCount == 0 then return false end
    if aliveCount == 2 then
      if not (CanShivaHitCamp(heroPos, spot.camp1, r) and CanShivaHitCamp(heroPos, spot.camp2, r)) then
        return false
      end
      if spot.pos and heroPos:Distance(spot.pos) > 220 then
        return false
      end
    else
      local aliveCamp = c1Alive and spot.camp1 or spot.camp2
      if not CanShivaHitCamp(heroPos, aliveCamp, r) then
        return false
      end
    end
  end

  if Utils.CastAbility(State.Shiva, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
    State.LastFarmingAction = now
    State.NextExtraToolTry  = now + castGap
    return true
  end

  State.NextExtraToolTry = now + retryIn
  return false
end

function Tinker.ProcessAfterMarchCheck()
  local am = State.AfterMarchCheck
  if not am then return end

  local t            = GameRules.GetGameTime()
  local minTime      = Constants.CAMP_CLEAR_DELAY
  local confirmWin   = Constants.CAMP_CLEAR_CONFIRM_DELAY
  local begunConfirm = (t - (am.startedAt or 0)) >= minTime

  if am.camp1 then
    local c1 = CountCampAliveCreeps(am.camp1)
    if c1 > 0 then
      am.zeroSince1 = nil
    else
      if begunConfirm then
        am.zeroSince1 = am.zeroSince1 or t
        if (t - am.zeroSince1) >= confirmWin then
          MarkCampFarmed(am.camp1, t)
        end
      end
    end
  end

  if am.camp2 then
    local c2 = CountCampAliveCreeps(am.camp2)
    if c2 > 0 then
      am.zeroSince2 = nil
    else
      if begunConfirm then
        am.zeroSince2 = am.zeroSince2 or t
        if (t - am.zeroSince2) >= confirmWin then
          MarkCampFarmed(am.camp2, t)
        end
      end
    end
  end

  local cleared = (am.camp1 and am.camp1.farmed or false)
      and ((not am.camp2) or (am.camp2 and am.camp2.farmed))

  if cleared then
    State.AfterMarchCheck = nil
    if State.FarmState == "FARMING_SPOT" then
      State.FarmState                = "IDLE"
      State.CurrentFarmSpot          = nil
      State.JustClearedSpotAt        = GameRules.GetGameTime()
      State.CurrentSpotMarchCasts    = 0
      State.CurrentSpotMarchRequired = nil
    end
  end
end

local function TryCastMatrix(mode)
  if not Config.AutoMatrix:Get() then return false end
  local m = NPC.GetAbility(State.Hero, "tinker_defense_matrix")
  if not m or Ability.CanBeExecuted(m) ~= -1 then return false end

  if mode == "precast" then
    if not Config.Matrix.PrecastAtFountain:Get() then return false end
    if not HasFountainBuff() then return false end
    if State.IsChanneling then return false end
    local matrixMod = NPC.GetModifier(State.Hero, "modifier_tinker_defense_matrix")
    if matrixMod and Modifier.GetDuration(matrixMod) > 7 then return false end
    if GameRules.GetGameTime() - (State.MatrixCastTime or 0) < 0.2 then return false end
    local ok = Utils.CastAbility(m, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, State.Hero)
    if ok then State.MatrixCastTime = GameRules.GetGameTime() end
    return ok
  elseif mode == "panic" then
    if not Config.Matrix.UseDuringPanic:Get() then return false end
    if GameRules.GetGameTime() - (State.LastPanicMatrixAt or 0) < Constants.PANIC_MATRIX_COOLDOWN then return false end
    local ok = Utils.CastAbility(m, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, State.Hero)
    if ok then State.LastPanicMatrixAt = GameRules.GetGameTime() end
    return ok
  end
  return false
end

function Tinker.HandlePanic()
  if not State.Hero then return false end

  local now    = GameRules.GetGameTime()
  local hp     = Entity.GetHealth(State.Hero) or 0
  local maxHp  = Entity.GetMaxHealth(State.Hero) or 1
  local hpFrac = hp / math.max(1, maxHp)
  if State.LastHP == nil or State.LastHPTime == nil then
    State.LastHP     = hp
    State.LastHPTime = now
    return false
  end

  local lowHP = hpFrac <= Constants.PANIC_HP_FRAC
  if lowHP then
    State.PanicArmingSince = State.PanicArmingSince or now
  else
    State.PanicArmingSince = nil
    return false
  end

  local armed      = State.PanicArmingSince and (now - State.PanicArmingSince) >= Constants.PANIC_ARM_TIME
  local canTrigger = now >= (State.PanicCooldownUntil or 0)
  if not (armed and canTrigger) then return false end

  State.PanicCooldownUntil = now + Constants.PANIC_COOLDOWN
  State.PanicReason        = lowHP and "lowHP" or "hpDPS"
  State.FarmState          = "RETURNING_TO_FOUNTAIN"
  State.AfterMarchCheck    = nil
  State.TargetSpotKey      = nil
  State.SpotCommitUntil    = 0

  -- Team 2 = Radiant, Team 3 = Dire
  local fountainPos        = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE

  if State.IsChanneling then
    State.PendingTPPos   = fountainPos
    State.PendingTPSince = now
    State.PendingTPForce = true
    return true
  end
  TryCastMatrix("panic")

  if Tinker.TryTeleportTo(fountainPos, true) then
    State.LastFarmTPAt = now
    return true
  end

  -- Never блинкаемся, если уже на фонтане (по баффу).
  if not HasFountainBuff()
      and Config.ItemsToUse:Get(L("item_blink"))
      and State.Blink
      and Ability.CanBeExecuted(State.Blink) == -1 then
    local myPos      = Entity.GetAbsOrigin(State.Hero)
    local toFountain = (fountainPos - myPos)
    local dist       = toFountain:Length()
    local blinkPos   = dist > Constants.BLINK_MAX_RANGE
        and (myPos + toFountain:Normalized() * Constants.BLINK_MAX_RANGE) or fountainPos
    Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, blinkPos)
  end

  Utils.MoveTo(fountainPos)
  return true
end

--- Проверяет, находится ли герой под жёстким контролем (стан, хекс, циклон)
local function IsHeroHardDisabled()
  if not State.Hero then return true end
  if NPC.HasModifier(State.Hero, "modifier_stunned") then return true end
  if NPC.HasModifier(State.Hero, "modifier_cyclone") then return true end
  if NPC.HasModifier(State.Hero, "modifier_sheepstick_debuff") then return true end
  if NPC.HasModifier(State.Hero, "modifier_lion_voodoo") then return true end
  if NPC.HasModifier(State.Hero, "modifier_shadow_shaman_voodoo") then return true end
  if NPC.HasModifier(State.Hero, "modifier_ice_blast") then return true end
  if NPC.HasModifier(State.Hero, "modifier_bashed") then return true end
  if NPC.HasModifier(State.Hero, "modifier_rooted") then return true end
  return false
end

--- Проверяет, провалился ли последний ТП (якорь умер, герой не долетел)
--- Возвращает true если ТП провалился и нужно сбросить состояние
function Tinker.CheckTPFailure(spot)
  if not State.MovingAfterTeleport then return false end
  local now = GameRules.GetGameTime()
  -- Ещё идёт ТП-лок — рано проверять
  local graceEnd = (State.TeleportLockUntil or 0) + (Constants.TP_ARRIVAL_GRACE or 0.5)
  if now < graceEnd then return false end
  -- Ещё каналим ТП
  if State.IsChanneling then return false end

  local myPos = Entity.GetAbsOrigin(State.Hero)
  local intended = Tinker.IntendedKeenTPPos(spot.pos)
  local dist = myPos:Distance(intended)

  -- Проверяем, жив ли якорь (крип, на которого тп'хались)
  local anchorDead = false
  if State.LastTeleportAnchor then
    if not Entity.IsEntity(State.LastTeleportAnchor)
        or not Entity.IsAlive(State.LastTeleportAnchor) then
      anchorDead = true
    end
  end

  -- Мы далеко от цели — ТП точно не сработал
  if dist > (Constants.TP_FAIL_DISTANCE or 1500) then
    return true
  end

  -- Якорь мёртв и мы не в зоне фарма
  if anchorDead and dist > Constants.MARCH_CAST_RANGE then
    return true
  end

  -- ТП успешно приземлил
  State.MovingAfterTeleport = false
  return false
end

--- Полный сброс состояния к IDLE с остановкой героя
local function AbortToIdle(reason)
  -- Останавливаем героя, чтобы не шёл пешком
  if State.Hero and State.Player then
    Player.PrepareUnitOrders(
      State.Player, Enum.UnitOrder.DOTA_UNIT_ORDER_STOP, nil, nil, nil,
      Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY, State.Hero,
      false, false, false, true, false, false
    )
  end
  State.FarmState                = "IDLE"
  State.CurrentFarmSpot          = nil
  State.AfterMarchCheck          = nil
  State.TargetSpotKey            = nil
  State.SpotCommitUntil          = 0
  State.CurrentSpotMarchCasts    = 0
  State.CurrentSpotMarchRequired = nil
  State.MovingAfterTeleport      = false
  State.RecalcAfterTP            = false
  State.LastTeleportAnchor       = nil
  State.BlockTPThisSpot          = false
  State.MovingToSpotSince        = 0
  State.CachedBestSpot           = nil
  State.LastSpotScan             = 0
  State.TreeBlinkStopPending     = false
  State.LaneTreeBlinkDone        = false
  State.LaneWaveLaserDone        = false
  State.LastTreeBlinkAt          = 0
  State.LastTreeBlinkHoldAt      = 0
  State.NextExtraToolTry         = 0
end

--- Проверяет, подошли ли враги к споту пока мы шли/ТП'хались
function Tinker.IsSpotStillSafe(spotPos)
  local enemyPts = Tinker.GetEnemyLastKnownPositions()
  if #enemyPts == 0 then return true end
  local blockR = Constants.ENEMY_RISK_BLOCK_RADIUS or 1000
  if AnyEnemyWithin(spotPos, enemyPts, blockR) then return false end
  local riskLimit = Constants.ENEMY_RISK_HARD_BLOCK or 0.45
  if RiskAtPoint(spotPos, enemyPts) >= riskLimit then return false end
  return true
end

function Tinker.HandleFarming()
  Tinker.ProcessMarchVerify()

  if not Config.MarchControl.UseCustom:Get() then
    Tinker.ProcessAfterMarchCheck()
  else
    State.AfterMarchCheck = nil
  end
  if Tinker.HandlePanic() then return end
  if State.IsChanneling then return end
  -- Герой под жёстким контролем — не можем действовать
  if IsHeroHardDisabled() then return end
  -- Guard: Rearm was just issued but channel hasn't registered yet
  if State.RearmBlinkHoldPending then return end
  if State.PendingTPPos then
    local age = GameRules.GetGameTime() - (State.PendingTPSince or 0)
    if age > (Constants.PENDING_TP_MAX_AGE or 2.5) then
      State.PendingTPPos   = nil
      State.PendingTPForce = false
    else
      if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1 then
        if State.PendingTPForce then
          if Tinker.TryTeleportTo(State.PendingTPPos, true) then
            State.PendingTPPos   = nil
            State.PendingTPForce = false
            return
          end
        else
          if Tinker.ShouldRequestTeleport(State.PendingTPPos, false) then
            if Tinker.TryTeleportTo(State.PendingTPPos, false) then
              State.LastFarmTPAt   = GameRules.GetGameTime()
              State.PendingTPPos   = nil
              State.PendingTPForce = false
              return
            end
          else
            State.PendingTPPos   = nil
            State.PendingTPForce = false
          end
        end
      end
    end
  end
  local usingCustom = Config.MarchControl.UseCustom:Get()
  if State.MarchModeWasCustom ~= usingCustom then
    State.MarchModeWasCustom = usingCustom

    if usingCustom then
      State.AfterMarchCheck = nil
    end

    if State.CurrentFarmSpot and usingCustom then
      State.CurrentSpotMarchCasts = 0
      State.CurrentSpotMarchRequired = ComputeRequiredMarchesForSpot(State.CurrentFarmSpot)
      if (State.CurrentSpotMarchRequired or 0) <= 0 then
        MarkSpotFarmedAndLeave()
        return
      end
    end

    SyncMarchSlidersDisabled()
  end

  if State.FarmState == "FARMING_SPOT" and Tinker.NeedsToReturnToFountain() then
    State.FarmState                = "RETURNING_TO_FOUNTAIN"
    State.CurrentFarmSpot          = nil
    State.AfterMarchCheck          = nil
    State.TargetSpotKey            = nil
    State.SpotCommitUntil          = 0
    State.CurrentSpotMarchCasts    = 0
    State.CurrentSpotMarchRequired = nil
    return
  end

  if State.FarmState == "IDLE" then
    if State.JustClearedSpotAt > 0 and (GameRules.GetGameTime() - State.JustClearedSpotAt) < Constants.IDLE_DECISION_DELAY then
      return
    end

    local bestSpot = Tinker.GetBestFarmSpotCached()
    if bestSpot then
      if not Tinker.HasManaForFullCampCycle() then
        State.FarmState       = "RETURNING_TO_FOUNTAIN"
        State.CurrentFarmSpot = nil
        State.AfterMarchCheck = nil
        State.TargetSpotKey   = nil
        State.SpotCommitUntil = 0
        return
      end

      State.CurrentFarmSpot       = bestSpot
      State.TargetSpotKey         = SpotKey(bestSpot)
      State.SpotCommitUntil       = GameRules.GetGameTime() + Constants.SPOT_COMMIT_TIME

      State.BlockTPThisSpot       = false
      State.LastSpotTelePos       = nil
      State.MovingAfterTeleport   = false
      State.RecalcAfterTP         = false
      State.JustClearedSpotAt     = 0
      State.AfterMarchCheck       = nil
      State.LastMarchCastAt       = 0
      State.CurrentSpotMarchCasts = 0
      State.LaneNoCreepsSince = nil
      State.LaneTreeBlinkDone = false
      State.LaneWaveLaserDone = false
      State.TreeBlinkStopPending = false
      State.LastTreeBlinkAt = 0
      State.LastTreeBlinkHoldAt = 0
      State.NextExtraToolTry = 0
      if bestSpot.isLane then
        -- Lane spots always use custom march count.
        State.CurrentSpotMarchRequired = ComputeRequiredMarchesForSpot(bestSpot)
        if (State.CurrentSpotMarchRequired or 0) <= 0 then
          MarkSpotFarmedAndLeave()
          return
        end
      elseif Config.MarchControl.UseCustom:Get() then
        State.CurrentSpotMarchRequired = ComputeRequiredMarchesForSpot(bestSpot)
        if (State.CurrentSpotMarchRequired or 0) <= 0 then
          MarkSpotFarmedAndLeave()
          return
        end
      else
        State.CurrentSpotMarchRequired = nil
      end

      State.FarmState         = "MOVING_TO_SPOT"
      State.MovingToSpotSince = GameRules.GetGameTime()
      State.LastSpotSafetyCheck = GameRules.GetGameTime()
    end
  elseif State.FarmState == "MOVING_TO_SPOT" then
    local spot = State.CurrentFarmSpot
    if not spot or not spot.camp1 then
      AbortToIdle("no_spot")
      return
    end

    local now = GameRules.GetGameTime()

    -- ═══ Проверка провала ТП: якорь (крип) мог умереть во время канала ═══
    if Tinker.CheckTPFailure(spot) then
      AbortToIdle("tp_failed")
      return
    end

    -- ═══ Таймаут ходьбы пешком: если слишком долго идём — бросаем ═══
    if State.MovingToSpotSince > 0 and not State.MovingAfterTeleport then
      local walkTime = now - State.MovingToSpotSince
      if walkTime > (Constants.WALK_TO_SPOT_MAX_TIME or 12.0) then
        AbortToIdle("walk_timeout")
        return
      end
    end

    -- ═══ Пере-проверка безопасности спота ═══
    if (now - (State.LastSpotSafetyCheck or 0)) >= (Constants.SPOT_SAFETY_RECHECK or 1.5) then
      State.LastSpotSafetyCheck = now
      if not Tinker.IsSpotStillSafe(spot.pos) then
        AbortToIdle("spot_unsafe")
        return
      end
    end

    -- Lane spots: refresh positions, invalidate if creeps gone.
    if spot.isLane then
      Tinker.RefreshLaneSpotPos(spot)
      if not spot.laneCreeps or #spot.laneCreeps == 0 then
        MarkSpotFarmedAndLeave()
        return
      end
    elseif spot.camp1.farmed then
      State.FarmState = "IDLE"
      return
    end

    if State.RecalcAfterTP and (GameRules.GetGameTime() - (State.LastTeleportAt or 0)) > 0.2 then
      if spot.isLane then
        Tinker.RefreshLaneSpotPos(spot)
      else
        RecenterSpot(spot)
      end
      State.RecalcAfterTP = false
    end
    if Config.MarchControl.UseCustom:Get() and (State.CurrentSpotMarchRequired or 0) <= 0 then
      MarkSpotFarmedAndLeave()
      return
    end

    if not Tinker.HasManaForFullCampCycle() then
      State.FarmState                = "RETURNING_TO_FOUNTAIN"
      State.CurrentFarmSpot          = nil
      State.AfterMarchCheck          = nil
      State.TargetSpotKey            = nil
      State.SpotCommitUntil          = 0
      State.CurrentSpotMarchCasts    = 0
      State.CurrentSpotMarchRequired = nil
      return
    end

    local myPos    = Entity.GetAbsOrigin(State.Hero)
    local castInfo = ComputeMarchCastInfo(spot)
    if not castInfo then
      State.FarmState = "IDLE"
      return
    end

    local intended   = Tinker.IntendedKeenTPPos(castInfo.pos)
    local distToLand = myPos:Distance(intended)
    local allowedMax = Constants.MARCH_CAST_RANGE * (spot.single and 1.0 or Constants.MARCH_PAIR_COVERAGE_FRAC)

    if castInfo.maxDist <= allowedMax and myPos:Distance(castInfo.pos) <= Constants.MARCH_CAST_RANGE then
      State.MovingAfterTeleport = false
      State.MovingToSpotSince   = 0
      State.FarmState           = "FARMING_SPOT"
      State.FarmingSpotSince    = GameRules.GetGameTime()
      State.LastFarmingAction   = GameRules.GetGameTime()
      if spot.isLane then
        Tinker.RefreshLaneSpotPos(spot)
      end
      if Config.MarchControl.UseCustom:Get() or spot.isLane then
        if (State.CurrentSpotMarchRequired or 0) <= (State.CurrentSpotMarchCasts or 0) then
          MarkSpotFarmedAndLeave()
          return
        end
      end
      return
    end

    -- Учитываем стоимость самого ТП: после прибытия должно хватить на march + escape
    local requiredMana = Tinker.GetManaNeededBeforeTP()
    local curMana      = NPC.GetMana(State.Hero) or 0
    local atFountain   = HasFountainBuff()

    if distToLand > Constants.TP_MIN_DISTANCE then
      if curMana >= requiredMana then
        if Tinker.RequestTeleportToSpot(spot, atFountain) then return end
      else
        State.FarmState                = "RETURNING_TO_FOUNTAIN"
        State.CurrentFarmSpot          = nil
        State.AfterMarchCheck          = nil
        State.TargetSpotKey            = nil
        State.SpotCommitUntil          = 0
        State.CurrentSpotMarchCasts    = 0
        State.CurrentSpotMarchRequired = nil
        return
      end
    end
    local holdBlink = (State.PendingTPPos ~= nil) or IsBlinkLockedNow()

    if not holdBlink
        and not HasFountainBuff()
        and Config.ItemsToUse:Get(L("item_blink"))
        and IsBlinkTravelEnabled()
        and State.Blink
        and Ability.CanBeExecuted(State.Blink) == -1 then
      local blinkDist = myPos:Distance(castInfo.pos)
      local farmBlinkMin = Constants.FARM_BLINK_MIN_DISTANCE or 200
      if blinkDist > farmBlinkMin then
        local preserveForTreeBlink = spot.isLane and IsTreeBlinkLaneEnabled()
            and blinkDist <= ((Constants.BLINK_MAX_RANGE or 1200) * 1.25)
        if not preserveForTreeBlink then
          local blinkPos = blinkDist <= Constants.BLINK_MAX_RANGE
              and castInfo.pos
              or (myPos + (castInfo.pos - myPos):Normalized() * Constants.BLINK_MAX_RANGE)
          blinkPos = FindTraversablePointNear(blinkPos)
          if blinkPos and not IsPointHardUnsafe(blinkPos) then
            if Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, blinkPos) then return end
          end
        end
      end
    end

    Utils.MoveTo(castInfo.pos)
  elseif State.FarmState == "FARMING_SPOT" then
    local spot = State.CurrentFarmSpot
    -- Jungle: done when camp(s) marked farmed
    if not spot or (not spot.isLane and spot.camp1.farmed and (spot.single or spot.camp2.farmed)) then
      State.FarmState                = "IDLE"
      State.AfterMarchCheck          = nil
      State.CurrentSpotMarchCasts    = 0
      State.CurrentSpotMarchRequired = nil
      return
    end

    local t = GameRules.GetGameTime()

    -- ═══ Проверка безопасности спота во время фарма ═══
    if (t - (State.LastSpotSafetyCheck or 0)) >= (Constants.SPOT_SAFETY_RECHECK or 1.5) then
      State.LastSpotSafetyCheck = t
      if not Tinker.IsSpotStillSafe(spot.pos) then
        -- Враги подошли — экстренно уходим
        State.FarmState                = "RETURNING_TO_FOUNTAIN"
        State.CurrentFarmSpot          = nil
        State.AfterMarchCheck          = nil
        State.TargetSpotKey            = nil
        State.SpotCommitUntil          = 0
        State.CurrentSpotMarchCasts    = 0
        State.CurrentSpotMarchRequired = nil
        return
      end
    end

    -- ═══ Таймаут бездействия: если на споте давно и ничего не кастуем ═══
    if State.FarmingSpotSince > 0 and State.LastFarmingAction > 0 then
      local idleTime = t - State.LastFarmingAction
      if idleTime > (Constants.FARMING_STALE_TIMEOUT or 10.0) then
        AbortToIdle("stale_farming")
        return
      end
    end

    -- ── Lane-specific refresh & timeout ──
    if spot.isLane then
      Tinker.RefreshLaneSpotPos(spot)
      local laneAlive = spot.laneCreeps and #spot.laneCreeps or 0
      if laneAlive == 0 then
        State.LaneNoCreepsSince = State.LaneNoCreepsSince or t
        if (t - State.LaneNoCreepsSince) >= Constants.LANE_NO_CREEPS_TIMEOUT then
          -- Крипов нет — летим на базу
          State.FarmState                = "RETURNING_TO_FOUNTAIN"
          State.CurrentFarmSpot          = nil
          State.AfterMarchCheck          = nil
          State.TargetSpotKey            = nil
          State.SpotCommitUntil          = 0
          State.CurrentSpotMarchCasts    = 0
          State.CurrentSpotMarchRequired = nil
          State.LaneTreeBlinkDone        = false
          State.LaneWaveLaserDone        = false
          State.TreeBlinkStopPending     = false
          State.LastTreeBlinkAt          = 0
          State.LastTreeBlinkHoldAt      = 0
          State.NextExtraToolTry         = 0
          return
        end
      else
        State.LaneNoCreepsSince = nil
      end

    end

    -- Count-based exit (used for UseCustom AND lane spots)
    if Config.MarchControl.UseCustom:Get() or spot.isLane then
      local req = State.CurrentSpotMarchRequired or 0
      if req > 0 and (State.CurrentSpotMarchCasts or 0) >= req then
        -- Для лейна: проверяем, подходит ли новая волна, прежде чем уходить
        if spot.isLane and Tinker.HasManaForFullCampCycle() then
          local nextWave = Tinker.DetectIncomingWave(spot.pos, spot.laneCreeps)
          if nextWave then
            -- Новая волна обнаружена — продолжаем фармить
            spot.laneCreeps = nextWave.creeps
            spot.pos        = nextWave.center
            spot.camp1.pos  = nextWave.center
            spot.gold       = nextWave.gold
            State.CurrentSpotMarchCasts = 0
            State.LaneNoCreepsSince     = nil
            State.LaneTreeBlinkDone     = false  -- сброс для новой волны
            State.LaneWaveLaserDone     = false
            State.LastTreeBlinkAt       = 0
            State.LastTreeBlinkHoldAt   = 0
            State.NextExtraToolTry      = 0
            return
          end
        end

        -- ══ ЗАЩИТА РЕАРМА: не выходим со спота пока Rearm не завершён ══
        -- Это главный guard, покрывающий ВСЁ: блинк в деревья, HOLD и MarkSpotFarmedAndLeave.
        -- Без этого tree-blink или MarkSpot могут сбить канал Rearm.
        if State.IsChanneling then return end  -- Rearm/другой канал ещё идёт
        local rearmSafe = (t - (State.LastRearmAt or 0)) >= (Constants.BLINK_HOLD_AFTER_REARM or 0.6)
        if not rearmSafe then return end        -- Rearm только что кончился, ждём
        if State.RearmBlinkHoldPending then return end  -- Rearm выпущен, канал не начался

        -- ── Tree blink (lane): блинк в КУЧУ деревьев ПОСЛЕ прокаста маршей ──
        if spot.isLane
            and not State.LaneTreeBlinkDone
            and IsTreeBlinkLaneEnabled()
            and Config.ItemsToUse:Get(L("item_blink"))
            and State.Blink then

          if Ability.CanBeExecuted(State.Blink) == -1
              and not IsBlinkLockedNow() then
            -- Блинк готов — блинкаем в кластер деревьев
            local myPos    = Entity.GetAbsOrigin(State.Hero)
            local treePos  = Tinker.FindTreeBlinkPos(myPos, spot.pos)
            if treePos then
              treePos = FindTraversablePointNear(treePos)
              if treePos and not IsPointHardUnsafe(treePos) then
                if Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, treePos) then
                  State.LaneTreeBlinkDone    = true
                  State.TreeBlinkStopPending = true
                  State.LastTreeBlinkAt      = t
                  State.LastTreeBlinkHoldAt  = 0
                  return
                end
                return  -- каст не прошёл (order cooldown), повторим на след. тике
              end
            end
            State.LaneTreeBlinkDone = true  -- деревьев нет/позиция опасна, пропускаем
          else
            -- Блинк заблокирован или на КД — ждём, НЕ уходим со спота
            local blinkCD = GetAbilityCooldownRemaining(State.Blink)
            if blinkCD <= 3.0 and Tinker.IsSpotStillSafe(spot.pos) then
              return  -- скоро будет готов, ждём
            else
              State.LaneTreeBlinkDone = true  -- слишком долго, пропускаем tree-blink
            end
          end
        end

        -- После tree-blink: HOLD чтобы герой не пошёл к крипам
        if State.TreeBlinkStopPending then
          if Utils.IssueOrder(Enum.UnitOrder.DOTA_UNIT_ORDER_HOLD_POSITION, nil, nil) then
            State.TreeBlinkStopPending = false
            State.LastTreeBlinkHoldAt  = t
          end
          return
        end

        -- Даём после blink/hold короткое окно, чтобы Rearm не сбивался следующим ордером.
        if spot.isLane then
          local settle = Constants.TREE_BLINK_SETTLE_TIME or 0.22
          if (t - (State.LastTreeBlinkAt or 0)) < settle or (t - (State.LastTreeBlinkHoldAt or 0)) < settle then
            return
          end
        end

        if State.RearmBlinkHoldPending then
          return
        end

        MarkSpotFarmedAndLeave()
        return
      end
    end

    local escapeMana  = Tinker.GetEscapeManaCost()
    if Tinker.TryUseFarmExtraTools(spot, escapeMana) then
      return
    end
    local am          = (Config.MarchControl.UseCustom:Get() or spot.isLane) and nil or State.AfterMarchCheck
    local minGap      = Constants.MARCH_MIN_RECAST_GAP
    local rearmGap    = Constants.REARM_MIN_GAP_AFTER_MARCH
    local canMarchNow = State.March and Ability.CanBeExecuted(State.March) == -1
    local canRearmNow = State.Rearm and Ability.CanBeExecuted(State.Rearm) == -1
    local justTPedAgo = t - (State.LastTeleportAt or 0)

    local anyAlive
    if spot.isLane then
      anyAlive = spot.laneCreeps and #spot.laneCreeps > 0
    else
      local c1 = spot.camp1 and CountCampAliveCreeps(spot.camp1) or 0
      local c2 = (not spot.single and spot.camp2 and CountCampAliveCreeps(spot.camp2)) or 0
      anyAlive = (c1 > 0) or (c2 > 0)
    end

    if am then
      local begunConfirm = (t - (am.startedAt or 0)) >= Constants.CAMP_CLEAR_DELAY
      local zero1        = (not am.camp1) or CountCampAliveCreeps(am.camp1) == 0
      local zero2        = (not am.camp2) or CountCampAliveCreeps(am.camp2) == 0
      local allZero      = zero1 and zero2

      if (Constants.HOLD_ACTIONS_DURING_CONFIRM and begunConfirm and allZero) then
        return
      end

      if anyAlive and canMarchNow then
        local marchCost = Ability.GetManaCost(State.March) or 0
        if (t - (State.LastMarchCastAt or 0)) >= minGap and ((NPC.GetMana(State.Hero) or 0) - marchCost) >= escapeMana then
          local marchTarget = Tinker.GetMarchTarget(spot)
          if Utils.CastAbility(State.March, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, marchTarget) then
            State.LastFarmingAction = t
          end
        end
        return
      end

      if anyAlive and canRearmNow then
        if justTPedAgo >= Constants.NO_REARM_AFTER_TP and (t - (State.LastMarchCastAt or 0)) >= rearmGap then
          local rearmCost = Ability.GetManaCost(State.Rearm) or 0
          if ((NPC.GetMana(State.Hero) or 0) - rearmCost) >= escapeMana then
            if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
              MarkRearmIssued(t)
              State.LastFarmingAction = t
            end
          else
            State.FarmState                = "RETURNING_TO_FOUNTAIN"
            State.CurrentFarmSpot          = nil
            State.AfterMarchCheck          = nil
            State.TargetSpotKey            = nil
            State.SpotCommitUntil          = 0
            State.CurrentSpotMarchCasts    = 0
            State.CurrentSpotMarchRequired = nil
          end
        end
        return
      end

      return
    end

    if canMarchNow then
      local marchCost = Ability.GetManaCost(State.March) or 0
      if ((NPC.GetMana(State.Hero) or 0) - marchCost) >= escapeMana then
        local marchTarget = Tinker.GetMarchTarget(spot)
        if Utils.CastAbility(State.March, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, marchTarget) then
          State.LastFarmingAction = t
          if not Config.MarchControl.UseCustom:Get() and not spot.isLane then
            State.AfterMarchCheck = {
              startedAt  = t,
              zeroSince1 = nil,
              zeroSince2 = nil,
              camp1      = spot.camp1,
              camp2      = spot.single and nil or spot.camp2
            }
          end
        end
      else
        State.FarmState                = "RETURNING_TO_FOUNTAIN"
        State.CurrentFarmSpot          = nil
        State.AfterMarchCheck          = nil
        State.TargetSpotKey            = nil
        State.SpotCommitUntil          = 0
        State.CurrentSpotMarchCasts    = 0
        State.CurrentSpotMarchRequired = nil
      end
      return
    end

    if canRearmNow then
      if justTPedAgo >= Constants.NO_REARM_AFTER_TP and (t - (State.LastMarchCastAt or 0)) >= rearmGap then
        local rearmCost = Ability.GetManaCost(State.Rearm) or 0
        if ((NPC.GetMana(State.Hero) or 0) - rearmCost) >= escapeMana then
          if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
            MarkRearmIssued(t)
            State.LastFarmingAction = t
          end
        else
          State.FarmState                = "RETURNING_TO_FOUNTAIN"
          State.CurrentFarmSpot          = nil
          State.AfterMarchCheck          = nil
          State.TargetSpotKey            = nil
          State.SpotCommitUntil          = 0
          State.CurrentSpotMarchCasts    = 0
          State.CurrentSpotMarchRequired = nil
        end
      end
      return
    end
  elseif State.FarmState == "RETURNING_TO_FOUNTAIN" then
    State.TargetSpotKey   = nil
    State.SpotCommitUntil = 0

    if HasFountainBuff() then
      local maxMana     = NPC.GetMaxMana(State.Hero) or 0
      local curMana     = NPC.GetMana(State.Hero) or 0
      local cycleCost   = Tinker.GetCampCycleManaCost()
      local minTPNeed   = Tinker.GetManaNeededBeforeTP()
      local minFracNeed = maxMana * Constants.FOUNTAIN_MIN_MANA_FRAC
      -- Не улетаем с фонтана, пока маны не хватит хотя бы на tp + march + rearm + tp_home
      local need        = math.max(minFracNeed, minTPNeed, math.min(cycleCost, maxMana * 0.95))
      -- Также ждём восстановления HP (не улетаем с низким ХП)
      local hp    = Entity.GetHealth(State.Hero) or 0
      local maxHP = Entity.GetMaxHealth(State.Hero) or 1
      local hpOK  = (hp / math.max(1, maxHP)) >= 0.85
      if curMana >= need and hpOK then
        -- Прекастим матрицу перед вылетом
        TryCastMatrix("precast")
        State.FarmState = "IDLE"
      end
      return
    end

    -- Team 2 = Radiant, Team 3 = Dire
    local fountainPos = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE

    -- Если мы уже недалеко от фонтана, не спамим ТП/Реарм/блинк, просто подбегаем.
    local myPos          = Entity.GetAbsOrigin(State.Hero)
    local distToFountain = myPos:Distance(fountainPos)
    if distToFountain <= 900 then
      Utils.MoveTo(fountainPos)
      return
    end

    if State.IsChanneling then
      State.PendingTPPos   = fountainPos
      State.PendingTPSince = GameRules.GetGameTime()
      State.PendingTPForce = true
      return
    end

    if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1 then
      if Tinker.TryTeleportTo(fountainPos, true) then
        State.LastFarmTPAt = GameRules.GetGameTime()
        return
      end
    end

    if State.Rearm
        and Ability.CanBeExecuted(State.Rearm) == -1
        and State.KeenTeleport
        and Ability.CanBeExecuted(State.KeenTeleport) ~= -1 then
      local needMana = (Ability.GetManaCost(State.Rearm) or 0) + (Ability.GetManaCost(State.KeenTeleport) or 0)
      if (NPC.GetMana(State.Hero) or 0) >= needMana then
        State.PendingTPPos   = fountainPos
        State.PendingTPSince = GameRules.GetGameTime()
        State.PendingTPForce = true
        if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
          MarkRearmIssued(GameRules.GetGameTime())
          return
        end
      end
    end

    local holdBlink = (State.PendingTPPos ~= nil) or IsBlinkLockedNow()
    if not HasFountainBuff()
        and not holdBlink
        and Config.ItemsToUse:Get(L("item_blink"))
        and IsBlinkTravelEnabled()
        and State.Blink
        and Ability.CanBeExecuted(State.Blink) == -1 then
      local myPos      = Entity.GetAbsOrigin(State.Hero)
      local toFountain = (fountainPos - myPos)
      local dist       = toFountain:Length()
      local blinkPos   = dist > Constants.BLINK_MAX_RANGE and
          (myPos + toFountain:Normalized() * Constants.BLINK_MAX_RANGE) or fountainPos
      blinkPos = FindTraversablePointNear(blinkPos)
      if blinkPos and Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, blinkPos) then
        return
      end
    end

    Utils.MoveTo(fountainPos)
  end
end

local Theme = {
  bg           = Color(14, 16, 20, 205),
  bg2          = Color(20, 23, 29, 225),
  border       = Color(70, 78, 92, 205),
  shadow       = Color(0, 0, 0, 180),

  text         = Color(230, 235, 245, 255),
  dim          = Color(160, 170, 185, 255),

  good         = Color(120, 255, 180, 255),
  warn         = Color(255, 220, 130, 255),
  bad          = Color(255, 120, 120, 255),

  accent       = Color(120, 220, 255, 255),
  accent2      = Color(120, 255, 180, 255),
  gold         = Color(255, 220, 110, 255),

  ringCast     = Color(120, 255, 120, 165),
  ringPair     = Color(120, 180, 255, 140),
  ringFail     = Color(255, 120, 120, 150),

  campDot      = Color(255, 210, 120, 220),

  tpAnchor     = Color(200, 140, 255, 245),
  tpAnchorRing = Color(200, 140, 255, 155),
  tpAnchorPath = Color(200, 140, 255, 170),
}

local UI = {
  fonts    = { regular = nil, small = nil, bold = nil },
  pad      = 10,
  rowH     = 18,
  rounding = 10,
}

local function EnsureFonts()
  if not UI.fonts.regular then UI.fonts.regular = Render.LoadFont("Tahoma", 0, 500) end
  if not UI.fonts.small then UI.fonts.small = Render.LoadFont("Tahoma", 0, 450) end
  if not UI.fonts.bold then UI.fonts.bold = Render.LoadFont("Tahoma", 0, 700) end
  if not State.DebugFont then State.DebugFont = UI.fonts.regular end
end

local function Lerp(a, b, t) return a + (b - a) * t end
local function Pulse(t, speed, minA, maxA) return Lerp(minA, maxA, 0.5 + 0.5 * math.sin(t * speed)) end
local function W2S(v) return Render.WorldToScreen(v) end

local function Chip(pos, text, colText, colBg)
  EnsureFonts()
  local padX, padY = 6, 3
  local ts         = Render.TextSize(UI.fonts.small, 14, text)
  local s          = Vec2(pos.x, pos.y)
  local e          = Vec2(pos.x + ts.x + padX * 2, pos.y + ts.y + padY * 2)
  Render.FilledRect(s, e, colBg or Theme.bg2, 8)
  Render.Rect(s, e, Theme.border, 8, nil, 1.0)
  Render.Text(UI.fonts.small, 14, text, Vec2(pos.x + padX, pos.y + padY), colText or Theme.text)
end

local function WorldRing(center, radius, color, thickness, segments)
  segments = segments or 56
  local pts = {}
  for i = 0, segments do
    local ang     = (i / segments) * math.pi * 2
    local wp      = Vector(center.x + math.cos(ang) * radius, center.y + math.sin(ang) * radius, center.z)
    local sp, vis = W2S(wp)
    if not vis then return end
    table.insert(pts, sp)
  end
  if #pts > 1 then Render.PolyLine(pts, color, thickness or 1.8) end
end

local function WorldDashed(a, b, color, thickness, dash, gap)
  local sa, va = W2S(a)
  local sb, vb = W2S(b)
  if not (va and vb) then return end
  thickness = thickness or 1.4
  dash      = dash or 8
  gap       = gap or 6
  local d   = sb - sa
  local len = math.sqrt(d.x * d.x + d.y * d.y)
  if len < 1 then return end
  local dir = Vec2(d.x / len, d.y / len)
  local t = 0
  while t < len do
    local seg = math.min(dash, len - t)
    Render.Line(sa + dir * t, sa + dir * (t + seg), color, thickness)
    t = t + dash + gap
  end
end

local function WorldArrow(fromPos, toPos, color, width)
  local s1, v1 = W2S(fromPos)
  local s2, v2 = W2S(toPos)
  if not (v1 and v2) then return end
  width = width or 2.0
  Render.Line(s1, s2, color, width)
  local v = s2 - s1
  local len = math.sqrt(v.x * v.x + v.y * v.y)
  if len <= 0.01 then return end
  local dir  = Vec2(v.x / len, v.y / len)
  local left = Vec2(-dir.y, dir.x)
  local base = s2 - dir * 12
  Render.FilledTriangle({ s2, base + left * 6, base - left * 6 }, color)
end

local function WorldDot(pos, color)
  local sp, vis = W2S(pos)
  if not vis then return end
  Render.FilledCircle(sp, 5.5, color)
  Render.Circle(sp, 8.5, Color(color.r, color.g, color.b, 70), 1.2, 0, 1, false, 28)
end

local function CampTag(pos, txt)
  local s, vis = W2S(pos); if not vis then return end
  Chip(s + Vec2(10, -8), txt, Theme.text, Color(22, 25, 31, 225))
end

local function DrawTPAnchorDebug(targetPos, pathEndPos, tagText)
  local heroPos  = Entity.GetAbsOrigin(State.Hero)
  local res      = Tinker.ResolveKeenTeleport(targetPos)
  local has      = res and res.anchor ~= nil
  local ap       = has and res.anchorPos or targetPos
  local rad      = res and res.landingRadius or 0
  local fp       = res and res.finalPos or targetPos
  local labelCat = has and (res.cat or "anchor") or "raw"
  local dist     = math.floor(heroPos:Distance(fp))
  local label    = (tagText and (tagText .. " • ") or "") .. "TP • " .. labelCat .. " • " .. dist

  if has and rad > 0 then
    WorldRing(ap, rad, Theme.tpAnchorRing, 1.7, 64)
  end

  WorldDot(fp, has and Theme.tpAnchor or Theme.bad)
  WorldArrow(ap, fp, has and Theme.tpAnchor or Theme.bad, 2.0)

  if pathEndPos then
    WorldDashed(ap, pathEndPos, Theme.tpAnchorPath, 1.6, 8, 6)
  end

  WorldDot(ap, Theme.accent2)
  local s, vis = W2S(ap)
  if vis then
    Chip(s + Vec2(12, -22), label, has and Theme.tpAnchor or Theme.bad, Color(20, 22, 28, 230))
  end
end

local function DrawWorldSpotNeo(spot)
  local castPos    = spot.pos
  local heroPos    = Entity.GetAbsOrigin(State.Hero)
  local castInfo   = ComputeMarchCastInfo(spot)
  local allowedMax = Constants.MARCH_CAST_RANGE * (spot.single and 1.0 or Constants.MARCH_PAIR_COVERAGE_FRAC)
  local now        = GameRules.GetGameTime()

  local s, vis     = W2S(castPos)
  if vis then
    local haloA = math.floor(Pulse(now, 3.0, 0.45, 0.8) * 255)
    Render.CircleGradient(s, 22, Color(0, 0, 0, 0), Color(120, 255, 160, haloA))
  end

  local castAlpha = math.floor(Pulse(now, 3.0, 110, 165))
  WorldRing(castPos, Constants.MARCH_CAST_RANGE, Color(Theme.ringCast.r, Theme.ringCast.g, Theme.ringCast.b, castAlpha),
    2.0, 60)
  if not spot.single then
    local fit = castInfo.maxDist <= allowedMax
    local col = fit and Theme.ringPair or Theme.ringFail
    WorldRing(castPos, allowedMax, col, 1.6, 56)
  end

  if spot.camp1 and spot.camp1.pos then
    WorldDot(spot.camp1.pos, Theme.campDot)
    WorldDashed(castPos, spot.camp1.pos, Color(255, 255, 255, 80), 1.2, 7, 5)
    if Config.Debug.Pretty:Get() then CampTag(spot.camp1.pos, "A") end
  end
  if spot.camp2 and spot.camp2.pos then
    WorldDot(spot.camp2.pos, Theme.campDot)
    WorldDashed(castPos, spot.camp2.pos, Color(255, 255, 255, 80), 1.2, 7, 5)
    WorldDashed(spot.camp1.pos, spot.camp2.pos, Color(255, 230, 140, 95), 1.4, 8, 5)
    if Config.Debug.Pretty:Get() then CampTag(spot.camp2.pos, "B") end
  end

  WorldArrow(heroPos, castPos, Theme.accent2, 2.0)

  if Config.Debug.Bounty:Get() and vis then
    local typ = spot.single and "Single" or "Pair"
    local g   = FormatGold(spot.gold or 0)
    Chip(s + Vec2(12, -26), string.format("%s • %s", typ, g), Theme.gold, Color(20, 22, 28, 225))
  end

  DrawTPAnchorDebug(castPos, castPos, nil)
end

local function DrawWorldSpotMinimal(spot)
  local castPos    = spot.pos
  local heroPos    = Entity.GetAbsOrigin(State.Hero)
  local castInfo   = ComputeMarchCastInfo(spot)
  local allowedMax = Constants.MARCH_CAST_RANGE * (spot.single and 1.0 or Constants.MARCH_PAIR_COVERAGE_FRAC)
  WorldRing(castPos, Constants.MARCH_CAST_RANGE, Color(120, 255, 120, 150), 1.6, 48)
  if not spot.single then
    local fit = castInfo.maxDist <= allowedMax
    WorldRing(castPos, allowedMax, fit and Color(120, 180, 255, 140) or Color(255, 120, 120, 140), 1.4, 48)
  end
  if spot.camp1 and spot.camp1.pos then WorldDot(spot.camp1.pos, Theme.campDot) end
  if spot.camp2 and spot.camp2.pos then WorldDot(spot.camp2.pos, Theme.campDot) end
  WorldArrow(heroPos, castPos, Theme.accent2, 1.8)
  DrawTPAnchorDebug(castPos, castPos, nil)
end

local function DrawDockOverlay()
  EnsureFonts()

  local w        = 360
  local screen   = Render.ScreenSize()
  local x        = screen.x - w - 24
  local y        = 110
  local pad      = UI.pad
  local tNow     = GameRules.GetGameTime()
  local lines    = {}

  local stateCol = Theme.text
  if State.FarmState == "FARMING_SPOT" then
    stateCol = Theme.good
  elseif State.FarmState == "RETURNING_TO_FOUNTAIN" then
    stateCol = Theme.warn
  end

  table.insert(lines,
    { "State", string.format("%s  (channeling: %s)", State.FarmState, tostring(State.IsChanneling)), stateCol })

  local tpLockRemain = math.max(0, (State.TeleportLockUntil or 0) - tNow)
  table.insert(lines, { "TP lock",
    string.format("movingAfterTP=%s  remain=%.1fs  pending=%s",
      tostring(State.MovingAfterTeleport),
      tpLockRemain,
      tostring(State.PendingTPPos ~= nil)),
    (tpLockRemain > 0) and Theme.warn or Theme.dim
  })

  if State.CurrentFarmSpot then
    local spot       = State.CurrentFarmSpot
    local castInfo   = ComputeMarchCastInfo(spot)
    local allowedMax = Constants.MARCH_CAST_RANGE * (spot.single and 1.0 or Constants.MARCH_PAIR_COVERAGE_FRAC)
    local fit        = castInfo.maxDist <= allowedMax

    table.insert(lines, { "Spot",
      string.format("key=%s  commitRem=%.1f  lastFarmTP=%.1f",
        tostring(State.TargetSpotKey),
        math.max(0, (State.SpotCommitUntil or 0) - tNow),
        math.max(0, tNow - (State.LastFarmTPAt or 0))),
      Theme.dim })

    if Config.Debug.Bounty:Get() then
      table.insert(lines, { "Bounty", FormatGold(spot.gold or 0), Theme.gold })
    end

    if Config.Debug.Spot:Get() then
      local spotTypeStr
      if spot.isLane then
        local lc = spot.laneCreeps and #spot.laneCreeps or 0
        spotTypeStr = "lane (" .. lc .. " creeps)"
      elseif spot.single then
        spotTypeStr = "single"
      else
        spotTypeStr = "pair (" .. math.floor(Constants.MARCH_PAIR_COVERAGE_FRAC * 100) .. "% cover)"
      end
      table.insert(lines, { "Type", spotTypeStr, spot.isLane and Theme.accent or Theme.dim })
      table.insert(lines,
        { "Max Camp Dist", string.format("%.0f / %.0f", castInfo.maxDist, allowedMax), fit and Theme.good or Theme.bad })
      table.insert(lines,
        { "Hero->Cast", string.format("%.0f / %d", Entity.GetAbsOrigin(State.Hero):Distance(castInfo.pos),
          Constants.MARCH_CAST_RANGE), Theme.dim })
    end
    local isCountMode = Config.MarchControl.UseCustom:Get() or (spot.isLane)
    local mode = spot.isLane and "Lane Count" or (Config.MarchControl.UseCustom:Get() and "Custom Count" or "Until Cleared")
    table.insert(lines, { "March Mode", mode, Theme.accent })
    if isCountMode then
      local req = State.CurrentSpotMarchRequired or 0
      local have = State.CurrentSpotMarchCasts or 0
      table.insert(lines, { "Marches", string.format("%d / %d", have, req), (have >= req and Theme.good or Theme.dim) })
    end
    if spot.isLane then
      local bias = Tinker.GetAdaptiveLaneBias()
      table.insert(lines, { "Lane Bias", string.format("%.1f", bias), bias < 0 and Theme.good or Theme.warn })
      if State.LaneTreeBlinkDone then
        table.insert(lines, { "Tree Blink", "Done", Theme.good })
      elseif IsTreeBlinkLaneEnabled() then
        table.insert(lines, { "Tree Blink", "Pending", Theme.warn })
      end
    end
  end

  if Config.Debug.Orders:Get() then
    local nextReady = math.max(0, (State.NextOrderTime or 0) - tNow)
    table.insert(lines,
      { "Orders", string.format("tick=%d  perSec=%d  next=%.2fs", State.OrdersThisUpdate or 0, State.OrdersPerSec or 0,
        nextReady), Theme.dim })
    if State.LastOrderDebug then
      local lod = State.LastOrderDebug
      local tag = lod.allowed and "sent" or ("blocked:" .. (lod.reason or "?"))
      local pos = lod.tpos and (" to(" .. math.floor(lod.tpos.x) .. "," .. math.floor(lod.tpos.y) .. ")") or ""
      table.insert(lines,
        { "Last Order", string.format("%s%s [%s]%s", lod.order or "?", lod.ability and ("(" .. lod.ability .. ")") or "",
          tag, pos), lod.allowed and Theme.good or Theme.bad })
    end
  end

  local labelW = 0
  for _, r in ipairs(lines) do
    local ts = Render.TextSize(UI.fonts.small, 14, r[1])
    if ts.x > labelW then labelW = ts.x end
  end
  labelW         = labelW + 12
  local contentH = #lines * UI.rowH + pad * 2

  local start    = Vec2(x, y)
  local end_     = Vec2(x + w, y + contentH + 10)
  Render.Shadow(start, end_, Theme.shadow, 14, UI.rounding)
  Render.Blur(start, end_, 0.85, 0.9, UI.rounding)
  Render.FilledRect(start, end_, Theme.bg2, UI.rounding)
  Render.Rect(start, end_, Theme.border, UI.rounding, nil, 1.0)

  Chip(Vec2(x + pad, y - 22), "Auto Push&Farm — Debug", Theme.text, Color(18, 20, 26, 230))

  local ry = y + pad + 6
  for _, r in ipairs(lines) do
    Render.Text(UI.fonts.small, 14, r[1], Vec2(x + pad, ry), Theme.dim)
    Render.Text(UI.fonts.small, 14, r[2], Vec2(x + pad + labelW, ry), r[3])
    ry = ry + UI.rowH
  end
end
local function DrawStatusOverlay()
  if not Config.StatusOverlay:Get() then return end
  EnsureFonts()

  local ui = State.StatusUI
  local pos = Vec2(ui.x, ui.y)

  local isOn = Config.AutoFarm:IsToggled()
  local label = isOn and "AutoFarm: ON" or "AutoFarm: OFF"
  local colBg = isOn and Theme.bg2
  local colBar = isOn and Theme.good or Theme.bad
  local colText = isOn and Theme.good or Theme.bad
  local padX, padY = 10, 7
  local ts = Render.TextSize(UI.fonts.bold, 15, label)
  local w = math.max(140, ts.x + padX * 2 + 6)
  local h = ts.y + padY * 2
  local s = pos
  local e = Vec2(pos.x + w, pos.y + h)
  Render.Shadow(s, e, Theme.shadow, 12, 8)
  Render.Blur(s, e, 0.7, 0.9, 8)
  Render.FilledRect(s, e, Theme.bg2, 8)
  Render.Rect(s, e, Theme.border, 8, nil, 1.0)
  local barW = 5
  Render.FilledRect(s, Vec2(s.x + barW, e.y), colBar, 8)
  Render.Text(UI.fonts.bold, 15, label, Vec2(pos.x + padX + barW + 4, pos.y + padY), colText)
  if not Config.Status.Lock:Get() and Input and Input.GetCursorPos and Input.IsKeyDown then
    local x, y = Input.GetCursorPos()
    local inside = (x >= s.x and x <= e.x and y >= s.y and y <= e.y)
    local down = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)

    if ui.dragging then
      if down then
        ui.x = x - ui.dragDX
        ui.y = y - ui.dragDY
      else
        ui.dragging = false
      end
    else
      if inside and down and not ui.mousePrevDown then
        ui.dragging = true
        ui.dragDX = x - ui.x
        ui.dragDY = y - ui.y
      end
    end
    ui.mousePrevDown = down
  end
end

-- Helper: camp coordinate logger.
-- Press F6/F7/F8/F9 while standing in a camp to log a ready-to-paste entry:
--   {pos = Vector(x, y, z), team = <2/3>, type = <1..4>, index = <n>},
-- Types: 1 small, 2 medium, 3 large, 4 ancient.
local CampLogger = {
  prev = { f6 = false, f7 = false, f8 = false, f9 = false },
  index = 1,
}

local function LogCampHere(campType)
  if not Engine.IsInGame() then return end
  local hero = Heroes.GetLocal()
  if not hero then return end
  local team = Entity.GetTeamNum(hero)
  if team ~= 2 and team ~= 3 then return end

  local p = Entity.GetAbsOrigin(hero)
  Log.Write(string.format(
    "Camp spot: {pos = Vector(%.1f, %.1f, %.1f), team = %d, type = %d, index = %d},",
    p.x, p.y, p.z, team, campType, CampLogger.index
  ))
  CampLogger.index = CampLogger.index + 1
end

local function HandleCampLoggerHotkeys()
  if not Input or not Input.IsKeyDown then return end

  local d6 = Input.IsKeyDown(Enum.ButtonCode.KEY_F6)
  local d7 = Input.IsKeyDown(Enum.ButtonCode.KEY_F7)
  local d8 = Input.IsKeyDown(Enum.ButtonCode.KEY_F8)
  local d9 = Input.IsKeyDown(Enum.ButtonCode.KEY_F9)

  if d6 and not CampLogger.prev.f6 then LogCampHere(1) end -- small
  if d7 and not CampLogger.prev.f7 then LogCampHere(2) end -- medium
  if d8 and not CampLogger.prev.f8 then LogCampHere(3) end -- large
  if d9 and not CampLogger.prev.f9 then LogCampHere(4) end -- ancient

  CampLogger.prev.f6 = d6
  CampLogger.prev.f7 = d7
  CampLogger.prev.f8 = d8
  CampLogger.prev.f9 = d9
end

script.OnDraw = function()
  if not Engine.IsInGame() then return end
  if not State.Hero or not Entity.IsAlive(State.Hero) then return end
  if Entity.GetUnitName(State.Hero) ~= "npc_dota_hero_tinker" then return end
  DrawStatusOverlay()

  if Config.Debug.World:Get() and State.CurrentFarmSpot then
    if Config.Debug.Pretty:Get() then
      DrawWorldSpotNeo(State.CurrentFarmSpot)
    else
      DrawWorldSpotMinimal(State.CurrentFarmSpot)
    end
  end

  if Config.Debug.World:Get() and State.PendingTPPos then
    DrawTPAnchorDebug(State.PendingTPPos, State.PendingTPPos, "Pending")
  end

  if Config.Debug.Overlay:Get() then
    DrawDockOverlay()
  end
end

script.OnUpdate = function()
  if not Engine.IsInGame() then return end

  -- Camp logger hotkeys (F6..F9)
  HandleCampLoggerHotkeys()

  State.OrdersThisUpdate = 0

  State.Hero             = Heroes.GetLocal()
  State.Player           = Players.GetLocal()
  if not State.Hero then
    State.FarmState                = "IDLE"
    State.CurrentFarmSpot          = nil
    State.AfterMarchCheck          = nil
    State.TargetSpotKey            = nil
    State.SpotCommitUntil          = 0
    State.CurrentSpotMarchCasts    = 0
    State.CurrentSpotMarchRequired = nil
    State.PendingMarchVerify       = nil
    State.LastTreeBlinkAt          = 0
    State.LastTreeBlinkHoldAt      = 0
    State.TreeBlinkStopPending     = false
    State.LaneTreeBlinkDone        = false
    State.LaneWaveLaserDone        = false
    State.NextExtraToolTry         = 0
    return
  end
  if Entity.GetUnitName(State.Hero) ~= "npc_dota_hero_tinker" then return end
  if not Entity.IsAlive(State.Hero) then
    State.FarmState                = "IDLE"
    State.CurrentFarmSpot          = nil
    State.AfterMarchCheck          = nil
    State.TargetSpotKey            = nil
    State.SpotCommitUntil          = 0
    State.CurrentSpotMarchCasts    = 0
    State.CurrentSpotMarchRequired = nil
    State.PendingMarchVerify       = nil
    State.LaneWaveLaserDone        = false
    State.NextExtraToolTry         = 0
    return
  end

  State.HeroTeam     = Entity.GetTeamNum(State.Hero)
  State.IsChanneling = NPC.IsChannellingAbility(State.Hero)
  State.Rearm        = NPC.GetAbility(State.Hero, "tinker_rearm")
  UpdateRearmBlinkHold()
  State.March        = NPC.GetAbility(State.Hero, "tinker_march_of_the_machines")
  State.Laser        = NPC.GetAbility(State.Hero, "tinker_laser")
  State.KeenTeleport = NPC.GetAbility(State.Hero, "tinker_keen_teleport")
  State.Blink        = NPC.GetItem(State.Hero, "item_blink", true)
      or NPC.GetItem(State.Hero, "item_overwhelming_blink", true)
      or NPC.GetItem(State.Hero, "item_swift_blink", true)
      or NPC.GetItem(State.Hero, "item_arcane_blink", true)
  State.Shiva        = NPC.GetItem(State.Hero, "item_shivas_guard", true)

  local autoOn = Config.AutoFarm:IsToggled()

  -- If автофарм только что выключили биндом – один раз отправляем героя на фонтан и выходим.
  if not autoOn then
    if State.AutoFarmWasOn then
      local fountainPos = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
      if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1 then
        Tinker.TryTeleportTo(fountainPos, true)
      else
        Utils.MoveTo(fountainPos)
      end
    end
    State.AutoFarmWasOn = false

    -- Полностью сбрасываем внутреннее состояние фарма
    if State.FarmState ~= "IDLE" then
      State.FarmState                = "IDLE"
      State.CurrentFarmSpot          = nil
      State.AfterMarchCheck          = nil
      State.TargetSpotKey            = nil
      State.SpotCommitUntil          = 0
      State.CurrentSpotMarchCasts    = 0
      State.CurrentSpotMarchRequired = nil
      State.PendingMarchVerify       = nil
      State.LastTreeBlinkAt          = 0
      State.LastTreeBlinkHoldAt      = 0
      State.TreeBlinkStopPending     = false
      State.LaneTreeBlinkDone        = false
      State.LaneWaveLaserDone        = false
      State.NextExtraToolTry         = 0
    end
    return
  end
  State.AutoFarmWasOn = true

  if autoOn then
    UpdateFarmedCampRespawns()
    Tinker.HandleAutoBottle()
  end
  TryCastMatrix("precast")

  Tinker.HandleFarming()
end
Config.MarchControl.UseCustom:SetCallback(function()
  SyncMarchSlidersDisabled()
end, true)

return script
