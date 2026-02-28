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
    item_shivas_guard = "Shiva's Guard",
    item_dagon = "Dagon",

    auto_defense_matrix = "Auto Defense Matrix",
    gear_matrix_options = "Defense Matrix Settings",
    matrix_precast = "Auto‑cast at Fountain",
    matrix_panic = "Use while Escaping",

    prefer_bounty = "Prioritize High‑Gold Camps",

    blink_options_label = "Blink Settings",
    gear_blink_behavior = "Blink Behavior",
    blink_travel = "Use for Traveling",
    blink_escape = "Use for Escaping",
    blink_hold_after_rearm = "Delay after Rearm",
    blink_hold_tp_lock = "Hold during TP Lock",

    lane_logic_label = "Lane Logic",
    gear_lane_logic = "Lane Logic Settings",
    lane_advanced_logic = "Advanced Lane Logic",
    lane_tree_blink_approach = "Tree Blink (Approach)",
    lane_tree_blink_retreat = "Tree Blink (Retreat)",
    lane_use_laser = "Use Laser on Lane Creeps",
    lane_rotate_after_clear = "Rotate After Clear",
    lane_dynamic_mix_priority = "Dynamic Jungle/Lane Priority",
    lane_marches_per_wave = "Lane Marches",

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
    march_count_fmt = "%d Marches",

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

    auto_defense_matrix = "Авто Defense Matrix",
    gear_matrix_options = "Настройки Defense Matrix",
    matrix_precast = "Автокаст у фонтана",
    matrix_panic = "Использовать при побеге",

    prefer_bounty = "Предпочитать более выгодные кемпы",

    blink_options_label = "Настройки Блинка",
    gear_blink_behavior = "Поведение Блинка",
    blink_travel = "Использовать для перемещения",
    blink_escape = "Использовать при побеге",
    blink_hold_after_rearm = "Задержка после Rearm",
    blink_hold_tp_lock = "Блокировать при ТП‑локе",

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
    march_count_fmt = "%d каста",

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
    { L("item_shivas_guard"), "panorama/images/items/shivas_guard_png.vtex_c", true },
    { L("item_dagon"), "panorama/images/items/dagon_png.vtex_c", false }
  }, true),
  AutoMatrix = utilityMenu:Switch(L("auto_defense_matrix"), true,
    "panorama/images/spellicons/tinker_defense_matrix_png.vtex_c"),
  Matrix = {},
  PreferBounty = autoFarmMenu:Switch(L("prefer_bounty"), true, "\u{f3d1}"),
  BlinkGroup = utilityMenu:Label(L("blink_options_label"), "panorama/images/items/blink_png.vtex_c"),
  Blink = {},
  BottleGroup = utilityMenu:Label(L("bottle_options_label"), "panorama/images/items/bottle_png.vtex_c"),
  Bottle = {},
  LaneGroup = autoFarmMenu:Label(L("lane_logic_label"), "panorama/images/spellicons/tinker_laser_png.vtex_c"),
  Lane = {},
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

  local bg                        = Config.BlinkGroup:Gear(L("gear_blink_behavior"))
  Config.Blink.Travel             = bg:Switch(L("blink_travel"), true, "\u{f70c}")
  Config.Blink.Escape             = bg:Switch(L("blink_escape"), true, "\u{f2f5}")
  Config.Blink.HoldAfterRearm     = bg:Switch(L("blink_hold_after_rearm"), true, "\u{f017}")
  Config.Blink.HoldTPLock         = bg:Switch(L("blink_hold_tp_lock"), true, "\u{f023}")

  local botg                      = Config.BottleGroup:Gear(L("gear_bottle_behavior"))
  Config.Bottle.UseHP             = botg:Switch(L("bottle_use_hp"), true, "\u{f004}")
  Config.Bottle.UseMana           = botg:Switch(L("bottle_use_mana"), true, "\u{f0d0}")

  local lg                        = Config.LaneGroup:Gear(L("gear_lane_logic"))
  Config.Lane.Advanced            = lg:Switch(L("lane_advanced_logic"), true, "\u{f0e8}")
  Config.Lane.TreeBlinkApproach   = lg:Switch(L("lane_tree_blink_approach"), true, "\u{f6ff}")
  Config.Lane.TreeBlinkRetreat    = lg:Switch(L("lane_tree_blink_retreat"), true, "\u{f6ff}")
  Config.Lane.UseLaser            = lg:Switch(L("lane_use_laser"), true, "\u{f0e7}")
  Config.Lane.RotateAfterClear    = lg:Switch(L("lane_rotate_after_clear"), true, "\u{f5aa}")
  Config.Lane.DynamicMixPriority  = lg:Switch(L("lane_dynamic_mix_priority"), true, "\u{f201}")
  Config.Lane.MarchesPerWave      = lg:Slider(L("lane_marches_per_wave"), 1, 5, 1, L("march_count_fmt"))
end

local function SyncMarchSlidersDisabled()
  local useCustom = Config.MarchControl.UseCustom:Get()
  Config.MarchControl.Small:Disabled(not useCustom)
  Config.MarchControl.Medium:Disabled(not useCustom)
  Config.MarchControl.Large:Disabled(not useCustom)
  Config.MarchControl.Ancient:Disabled(not useCustom)
end
Constants = {
  MARCH_CAST_RANGE              = 900,
  MARCH_PAIR_COVERAGE_FRAC      = 1.1,
  TP_MIN_DISTANCE               = 2000,
  BLINK_CAST_RANGE              = 1190,
  BLINK_MAX_RANGE               = 1200,
  POST_TP_LOCK_TIME             = 3.8,
  NO_REARM_AFTER_TP             = 1.6,
  SAME_SPOT_TP_EPS              = 800,
  SAME_SPOT_TP_COOLDOWN         = 7.5,
  BLINK_HOLD_AFTER_REARM        = 0.6,
  BLINK_HOLD_BEFORE_TP          = 0.6,
  REARM_HOLD_ARM_FALLBACK       = 0.15,
  BLINK_SAFE_STANDOFF           = 220,
  BLINK_MIN_DISTANCE            = 450,
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
  CAMP_ALIVE_SCAN_RADIUS        = 900,
  CAMP_ALIVE_SCAN_RADIUS_ANCIENT = 1200,
  CAMP_ALIVE_SCAN_CACHE_TTL     = 0.10,
  NEUTRAL_SNAPSHOT_CACHE_TTL    = 0.10,
  LANE_CREEP_SNAPSHOT_CACHE_TTL = 0.10,
  LANE_CLUSTER_SEED_RADIUS      = 900,
  LANE_TRACK_RADIUS             = 1000,
  LANE_REACQUIRE_RADIUS         = 1800,
  LANE_MIN_CREEPS               = 2,
  LANE_SCORE_PER_CREEP          = 2.0,
  LANE_SCORE_PER_SIEGE          = 1.0,
  LANE_POS_BUCKET               = 320,
  LANE_TREE_NEARBY_RADIUS       = 140,
  LANE_TREE_MIN_WAVE_DIST       = 420,
  LANE_TREE_MAX_WAVE_DIST       = 900,
  LANE_TREE_CANDIDATE_RINGS     = { 460, 600, 760, 880 },
  LANE_TREE_CANDIDATE_ANGLE_STEP = 20,
  LANE_TREE_CACHE_TTL           = 0.20,
  LANE_RETREAT_TREE_SEARCH_RADIUS = 1100,
  LANE_BURST_GAP                = 0.10,
  LANE_ROTATE_MIN_CREEPS_LEFT   = 1,
  LANE_ROTATE_BYPASS_IDLE_DELAY = true,
  LANE_DYNAMIC_SCORE_BIAS       = 1.5,
  LANE_LASER_MIN_VALUE_CREEPS   = 3,
  LANE_DAGON_USE_MAX_CREEPS     = 2,
  LANE_DAGON_MIN_ROTATE_MANA_BUFFER = 35,
  LANE_SPOT_RESELECT_COOLDOWN   = 2.0,
  MARCH_MIN_RECAST_GAP          = 0.6,
  REARM_MIN_GAP_AFTER_MARCH     = 0.35,
  HOLD_ACTIONS_DURING_CONFIRM   = true,
  PANIC_HP_FRAC                 = 0.40,
  PANIC_COOLDOWN                = 1.5,
  PANIC_ARM_TIME                = 0.25,
  PANIC_MATRIX_COOLDOWN         = 1.0,
  SPOT_COMMIT_TIME              = 5.0,
  FARM_TP_MIN_INTERVAL          = 5.0,
  IDLE_DECISION_DELAY           = 0.6,
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
}
State = {
  Hero = nil,
  Player = nil,
  HeroTeam = nil,
  IsChanneling = false,
  Rearm = nil,
  March = nil,
  KeenTeleport = nil,
  Blink = nil,
  Laser = nil,
  Shiva = nil,
  Dagon = nil,

  FarmState = "IDLE",
  CurrentFarmSpot = nil,

  MatrixCastTime = 0,

  NextOrderTime = 0,
  OrdersThisUpdate = 0,
  NextBottleCheck = 0,

  LastMovePos = nil,
  LastMoveTime = 0,
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
  RearmBlinkHoldPending = false,
  RearmBlinkChannelSeen = false,
  RearmBlinkHoldUntil = 0,
  LastSpotScan = 0,

  CachedBestSpot = nil,
  AfterMarchCheck = nil,
  CampAliveScanCache = {},
  NeutralSnapshot = { at = 0, list = {} },
  LaneCreepSnapshot = { at = 0, list = {} },
  SessionSig = nil,
  LastObservedGameTime = 0,
  LastNeutralRespawnMinute = nil,

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
  LastLaneBurstAt = 0,
  LastLaneRetreatBlinkAt = 0,
  PendingLaneRotate = false,
  LastLaneSpotKey = nil,
  LaneTreeBlinkCache = {},
  LastLaneTreeSearchAt = 0,
  LaneBurstTargets = {},
  LastLaneSkipKey = nil,
  LastLaneSkipUntil = 0,

  LastMarchCastAt = 0,

  LastTeleportAnchor = nil,
  CurrentSpotMarchCasts = 0,
  CurrentSpotMarchRequired = nil,
  MarchTotalCasts = 0,
  MarchModeWasCustom = false,
  PendingMarchVerify = nil,
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
local Tinker = {}
local RefreshLaneCamp
local GetLaneMarchLimit

local ORDER_NAME = {
  [Enum.UnitOrder.DOTA_UNIT_ORDER_NONE]             = "NONE",
  [Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION] = "MOVE",
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

  -- Prevent accidental order spam from cancelling Rearm during cast point / early channel frames.
  if State.RearmBlinkHoldPending and ability ~= State.Rearm then
    return false, "rearmPendingLock"
  end

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

  if State.IsChanneling then
    RecordOrder(order, ability, false, "channeling", nil, nil)
    return false
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

local function CanExecuteAbility(ability)
  if not ability then return false end
  if Ability and Ability.CanBeExecuted then
    return Ability.CanBeExecuted(ability) == -1
  end
  if Ability and Ability.IsReady then
    return Ability.IsReady(ability)
  end
  if ability.IsReady then
    return ability:IsReady()
  end
  return false
end

function Tinker.GetDagonItem()
  if not State.Hero then return nil end
  return NPC.GetItem(State.Hero, "item_dagon_5", true)
      or NPC.GetItem(State.Hero, "item_dagon_4", true)
      or NPC.GetItem(State.Hero, "item_dagon_3", true)
      or NPC.GetItem(State.Hero, "item_dagon_2", true)
      or NPC.GetItem(State.Hero, "item_dagon", true)
end

function Tinker.IsOverwhelmingBlink()
  return State.Blink and Ability.GetName(State.Blink) == "item_overwhelming_blink"
end

local function FormatGold(n) return tostring(math.floor(n + 0.5)) .. "g" end

local MarkRearmIssued = function(now)
  now = now or GameRules.GetGameTime()
  State.LastRearmAt           = now
  State.RearmBlinkHoldPending = true
  State.RearmBlinkChannelSeen = false
end

local function UpdateRearmBlinkHold()
  if not State.RearmBlinkHoldPending then return end

  local now = GameRules.GetGameTime()
  if State.IsChanneling then
    State.RearmBlinkChannelSeen = true
    return
  end

  local fallbackDelay = Constants.REARM_HOLD_ARM_FALLBACK or 0.15
  if State.RearmBlinkChannelSeen or (now - (State.LastRearmAt or 0)) >= fallbackDelay then
    State.RearmBlinkHoldPending = false
    State.RearmBlinkChannelSeen = false
    State.RearmBlinkHoldUntil   = now + (Constants.BLINK_HOLD_AFTER_REARM or 0)
  end
end

local function IsBlinkLockedNow()
  local now = GameRules.GetGameTime()

  if Config.Blink and Config.Blink.HoldTPLock and Config.Blink.HoldTPLock:Get() then
    if now < (State.TeleportLockUntil or 0) then
      return true
    end
  end

  if Config.Blink and Config.Blink.HoldAfterRearm and Config.Blink.HoldAfterRearm:Get() then
    if State.RearmBlinkHoldPending and (State.IsChanneling or State.RearmBlinkChannelSeen) then
      return true
    end
    if now < (State.RearmBlinkHoldUntil or 0) then
      return true
    end
  end

  return false
end

Tinker = Tinker or {}
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
  end
  return 0
end

local function ComputeRequiredMarchesForSpot(spot)
  if not spot then return 0 end
  if spot.kind == "lane" then return GetLaneMarchLimit() end
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
  if camp.kind == "lane_wave" then
    camp.farmed = true
    camp.farmedAt = now
    camp.respawnAt = nil
    return
  end
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
  local curSpot = State.CurrentFarmSpot
  local now = GameRules.GetGameTime()
  if curSpot then
    if curSpot.camp1 then MarkCampFarmed(curSpot.camp1, now) end
    if (not curSpot.single) and curSpot.camp2 then
      MarkCampFarmed(curSpot.camp2, now)
    end
  end
  State.AfterMarchCheck          = nil
  State.CurrentFarmSpot          = curSpot
  if curSpot and curSpot.kind == "lane" and Tinker.TryRotateAfterLaneClear and Tinker.TryRotateAfterLaneClear(curSpot) then
    return
  end
  State.FarmState                = "IDLE"
  State.JustClearedSpotAt        = GameRules.GetGameTime()
  State.CurrentFarmSpot          = nil
  State.CurrentSpotMarchCasts    = 0
  State.CurrentSpotMarchRequired = nil
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
  if spot.kind == "lane" and spot.camp1 then
    RefreshLaneCamp(spot.camp1)
    if spot.camp1.pos then spot.pos = spot.camp1.pos end
    return
  end
  if spot.single then
    if spot.camp1 and spot.camp1.pos then spot.pos = spot.camp1.pos end
  else
    if spot.camp1 and spot.camp1.pos and spot.camp2 and spot.camp2.pos then
      spot.pos = (spot.camp1.pos + spot.camp2.pos) / 2
    end
  end
end

local function ClearCampScanCaches()
  State.CampAliveScanCache = {}
  State.NeutralSnapshot    = { at = 0, list = {} }
  State.LaneCreepSnapshot  = { at = 0, list = {} }
end

local function ResetFarmedCampFlags(reason)
  for _, camp in pairs(GetJungleSpots() or {}) do
    if type(camp) == "table" then
      camp.farmed    = false
      camp.farmedAt  = nil
      camp.respawnAt = nil
    end
  end
  State.CachedBestSpot = nil
  State.LastSpotScan   = 0
  ClearCampScanCaches()
  State.LastCampResetReason = reason or "manual"
end

local function MaybeResetCampStateForSession()
  local matchId = (GameRules.GetMatchID and GameRules.GetMatchID()) or 0
  local startAt = (GameRules.GetGameStartTime and GameRules.GetGameStartTime()) or 0
  local sig     = tostring(matchId) .. "|" .. tostring(startAt)

  if State.SessionSig ~= sig then
    State.SessionSig = sig
    ResetFarmedCampFlags("sessionChange")
  end

  local now = GameRules.GetGameTime() or 0
  if (State.LastObservedGameTime or 0) > (now + 1.0) then
    ResetFarmedCampFlags("timeRewind")
  end
  State.LastObservedGameTime = now

  local dotaTime = (GameRules.GetDOTATime and GameRules.GetDOTATime()) or now
  local minute   = math.floor(math.max(0, dotaTime) / 60)
  if State.LastNeutralRespawnMinute == nil then
    State.LastNeutralRespawnMinute = minute
  elseif minute > State.LastNeutralRespawnMinute then
    State.LastNeutralRespawnMinute = minute
    State.CachedBestSpot = nil
    State.LastSpotScan   = 0
    ClearCampScanCaches()
  elseif minute < State.LastNeutralRespawnMinute then
    State.LastNeutralRespawnMinute = minute
  end
end

local function GetNeutralSnapshot()
  local ttl  = Constants.NEUTRAL_SNAPSHOT_CACHE_TTL or 0.10
  local now  = GameRules.GetGameTime() or 0
  local snap = State.NeutralSnapshot
  if snap and (now - (snap.at or 0)) <= ttl and type(snap.list) == "table" then
    return snap.list
  end

  local out = {}
  for _, unit in ipairs(NPCs.GetAll() or {}) do
    if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
        and NPC.IsCreep(unit)
        and (NPC.IsNeutral and NPC.IsNeutral(unit))
        and (not NPC.IsWaitingToSpawn or not NPC.IsWaitingToSpawn(unit)) then
      table.insert(out, unit)
    end
  end

  State.NeutralSnapshot = { at = now, list = out }
  return out
end

local function CountCampAliveCreepsByScan(camp)
  if not camp or not camp.pos then return 0 end

  local key   = CampIndex(camp)
  local now   = GameRules.GetGameTime() or 0
  local cache = State.CampAliveScanCache and State.CampAliveScanCache[key] or nil
  local ttl   = Constants.CAMP_ALIVE_SCAN_CACHE_TTL or 0.10
  if cache and (now - (cache.at or 0)) <= ttl then
    return cache.cnt or 0
  end

  local radius = (camp.type == 4) and (Constants.CAMP_ALIVE_SCAN_RADIUS_ANCIENT or 1200)
      or (Constants.CAMP_ALIVE_SCAN_RADIUS or 900)
  local cnt = 0
  for _, unit in ipairs(GetNeutralSnapshot()) do
    if unit and Entity.IsEntity(unit) then
      local upos = Entity.GetAbsOrigin(unit)
      if upos and upos:Distance(camp.pos) <= radius then
        cnt = cnt + 1
      end
    end
  end

  State.CampAliveScanCache = State.CampAliveScanCache or {}
  State.CampAliveScanCache[key] = { at = now, cnt = cnt }
  return cnt
end

local function MaybeUnmarkFarmedCamp(camp)
  if not camp or not camp.farmed then return end
  if not (GameRules.IsCheatsEnabled and GameRules.IsCheatsEnabled()) then return end
  if CountCampAliveCreepsByScan(camp) > 0 then
    camp.farmed    = false
    camp.farmedAt  = nil
    camp.respawnAt = nil
  end
end

local function GetCampTeam(camp)
  if not camp then return nil end
  if camp.team ~= nil then return camp.team end
  if not camp.pos then return nil end
  local dR = camp.pos:Distance(Constants.FOUNTAIN_RADIANT)
  local dD = camp.pos:Distance(Constants.FOUNTAIN_DIRE)
  return (dR <= dD) and 2 or 3
end

local function GetEnemyLaneCreepsSnapshot()
  local ttl  = Constants.LANE_CREEP_SNAPSHOT_CACHE_TTL or 0.10
  local now  = GameRules.GetGameTime() or 0
  local snap = State.LaneCreepSnapshot
  if snap and (now - (snap.at or 0)) <= ttl and type(snap.list) == "table" then
    return snap.list
  end

  local raw = nil
  if NPCs and NPCs.GetAll then
    raw = NPCs.GetAll(Enum.UnitTypeFlags.TYPE_LANE_CREEP)
    if type(raw) ~= "table" or #raw == 0 then
      raw = NPCs.GetAll()
    end
  end
  raw = raw or {}

  local out = {}
  for _, unit in ipairs(raw) do
    if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit)
        and NPC.IsCreep(unit)
        and (NPC.IsLaneCreep and NPC.IsLaneCreep(unit))
        and Entity.GetTeamNum(unit) ~= State.HeroTeam
        and (not Entity.IsDormant or not Entity.IsDormant(unit))
        and (not NPC.IsWaitingToSpawn or not NPC.IsWaitingToSpawn(unit)) then
      table.insert(out, unit)
    end
  end

  State.LaneCreepSnapshot = { at = now, list = out }
  return out
end

local function IsSiegeLikeLaneCreep(unit)
  local name = (unit and Entity.GetUnitName(unit)) or ""
  return string.find(name, "siege", 1, true) ~= nil or string.find(name, "catapult", 1, true) ~= nil
end

local function CollectLaneCreepsAround(center, creeps, radius)
  if not center then return {}, nil, 0, 0 end
  local picked = {}
  local sx, sy, sz = 0, 0, 0
  local siegeCnt = 0

  for _, unit in ipairs(creeps or {}) do
    if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) then
      local p = Entity.GetAbsOrigin(unit)
      if p and p:Distance(center) <= radius then
        table.insert(picked, unit)
        sx, sy, sz = sx + (p.x or 0), sy + (p.y or 0), sz + (p.z or 0)
        if IsSiegeLikeLaneCreep(unit) then siegeCnt = siegeCnt + 1 end
      end
    end
  end

  local n = #picked
  if n == 0 then return picked, nil, 0, 0 end

  local avg = Vector(sx / n, sy / n, sz / n)
  local maxDist = 0
  for _, unit in ipairs(picked) do
    local p = Entity.GetAbsOrigin(unit)
    if p then
      local d = p:Distance(avg)
      if d > maxDist then maxDist = d end
    end
  end

  return picked, avg, maxDist, siegeCnt
end

local function MakeLaneBucketIndex(pos)
  local b = Constants.LANE_POS_BUCKET or 320
  return string.format("lane:%d:%d", math.floor((pos.x or 0) / b), math.floor((pos.y or 0) / b))
end

RefreshLaneCamp = function(camp)
  if not camp or camp.kind ~= "lane_wave" then return nil end
  if not camp.pos then
    camp.alive_creeps = {}
    camp.farmed = true
    return 0
  end

  local creeps = GetEnemyLaneCreepsSnapshot()
  local trackR = camp.track_radius or Constants.LANE_TRACK_RADIUS or 1000
  local reacqR = camp.reacquire_radius or Constants.LANE_REACQUIRE_RADIUS or 1800

  local picked, avg, _, siegeCnt = CollectLaneCreepsAround(camp.pos, creeps, trackR)
  if #picked == 0 then
    local nearestPos, nearestDist = nil, math.huge
    for _, unit in ipairs(creeps) do
      local p = Entity.GetAbsOrigin(unit)
      if p then
        local d = p:Distance(camp.pos)
        if d < nearestDist and d <= reacqR then
          nearestDist, nearestPos = d, p
        end
      end
    end
    if nearestPos then
      picked, avg, _, siegeCnt = CollectLaneCreepsAround(nearestPos, creeps, trackR)
    end
  end

  camp.alive_creeps = picked or {}
  if avg then
    camp.pos = avg
    camp.index = MakeLaneBucketIndex(avg)
    camp.farmed = false
    camp.creepCount = #camp.alive_creeps
    camp.siegeCount = siegeCnt or 0
  else
    camp.farmed = true
    camp.creepCount = 0
    camp.siegeCount = 0
  end

  return #camp.alive_creeps
end

GetLaneMarchLimit = function()
  if Config and Config.Lane and Config.Lane.MarchesPerWave and Config.Lane.MarchesPerWave.Get then
    return math.max(1, Config.Lane.MarchesPerWave:Get() or 1)
  end
  return 1
end

local function IsLaneSpotTemporarilySkipped(spotKey)
  if not spotKey then return false end
  return State.LastLaneSkipKey == spotKey and (GameRules.GetGameTime() or 0) < (State.LastLaneSkipUntil or 0)
end

function Tinker.FindBestLaneCreepSpot(excludeSpotKey)
  local creeps = GetEnemyLaneCreepsSnapshot()
  if #creeps < (Constants.LANE_MIN_CREEPS or 2) then return nil end

  local myPos    = Entity.GetAbsOrigin(State.Hero)
  local enemyPts = Tinker.GetEnemyLastKnownPositions()
  local bestSpot, bestScore = nil, math.huge

  for _, seed in ipairs(creeps) do
    local seedPos = Entity.GetAbsOrigin(seed)
    if seedPos then
      local _, center = CollectLaneCreepsAround(seedPos, creeps, Constants.LANE_CLUSTER_SEED_RADIUS or 900)
      if center then
        local cluster2, center2, maxDist, siegeCnt = CollectLaneCreepsAround(center, creeps,
          Constants.MARCH_CAST_RANGE or 900)
        local count = #cluster2
        if count >= (Constants.LANE_MIN_CREEPS or 2) and center2 and maxDist <= (Constants.MARCH_CAST_RANGE or 900) then
          local anchorPos = Tinker.IntendedKeenTPPos(center2)
          local rSpot     = RiskAtPoint(center2, enemyPts)
          local rAnchor   = RiskAtPoint(anchorPos, enemyPts)
          local rPath     = PathRisk(anchorPos, center2, enemyPts)

          local riskLimit = Constants.ENEMY_RISK_HARD_BLOCK
          local blockR    = Constants.ENEMY_RISK_BLOCK_RADIUS
          if not ((rSpot >= riskLimit) or (rAnchor >= riskLimit) or (rPath >= riskLimit)
              or AnyEnemyWithin(anchorPos, enemyPts, blockR)) then
            local distScore   = myPos:Distance(center2) / 100.0
            local riskPenalty = (Constants.ENEMY_RISK_W_SPOT * rSpot
                + Constants.ENEMY_RISK_W_ANCHOR * rAnchor
                + Constants.ENEMY_RISK_W_PATH * rPath) * Constants.ENEMY_RISK_WEIGHT
            local waveValue   = count * (Constants.LANE_SCORE_PER_CREEP or 2.0)
                + siegeCnt * (Constants.LANE_SCORE_PER_SIEGE or 1.0)
            local score       = distScore + riskPenalty - waveValue

            if score < bestScore then
              local camp = {
                pos              = center2,
                type             = 2,
                index            = MakeLaneBucketIndex(center2),
                alive_creeps     = cluster2,
                farmed           = false,
                kind             = "lane_wave",
                creepCount       = count,
                siegeCount       = siegeCnt or 0,
                laneScoreRaw     = score,
                track_radius     = Constants.LANE_TRACK_RADIUS or 1000,
                reacquire_radius = Constants.LANE_REACQUIRE_RADIUS or 1800
              }
              local candidate = {
                pos    = center2,
                camp1  = camp,
                single = true,
                gold   = 0,
                kind   = "lane",
                creepCount = count,
                siegeCount = siegeCnt or 0,
                score = score
              }
              local cKey = SpotKey(candidate)
              if (not excludeSpotKey or cKey ~= excludeSpotKey) and (not IsLaneSpotTemporarilySkipped(cKey)) then
                bestScore = score
                bestSpot = candidate
              end
            end
          end
        end
      end
    end
  end

  return bestSpot
end

local function IsCampAncient(camp) return camp and camp.type == 4 end
local function ComputeMarchCastInfo(spot)
  if not spot then return nil end
  if spot.kind == "lane" and spot.camp1 then
    local cnt = RefreshLaneCamp(spot.camp1) or 0
    if cnt <= 0 then return nil end

    local castPos = spot.camp1.pos or spot.pos
    if not castPos then return nil end

    local alive = {}
    local sx, sy, sz = 0, 0, 0
    for _, unit in ipairs(spot.camp1.alive_creeps or {}) do
      if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) then
        local p = Entity.GetAbsOrigin(unit)
        if p then
          table.insert(alive, unit)
          sx, sy, sz = sx + (p.x or 0), sy + (p.y or 0), sz + (p.z or 0)
        end
      end
    end
    if #alive == 0 then
      spot.camp1.alive_creeps = {}
      spot.camp1.farmed = true
      return nil
    end

    castPos = Vector(sx / #alive, sy / #alive, sz / #alive)
    spot.camp1.alive_creeps = alive
    spot.camp1.pos = castPos
    spot.camp1.creepCount = #alive
    spot.pos = castPos
    spot.creepCount = #alive

    local maxDist = 0
    local siegeCnt = 0
    for _, unit in ipairs(alive) do
      local p = Entity.GetAbsOrigin(unit)
      if p then
        local d = castPos:Distance(p)
        if d > maxDist then maxDist = d end
      end
      if IsSiegeLikeLaneCreep(unit) then siegeCnt = siegeCnt + 1 end
    end
    spot.camp1.siegeCount = siegeCnt
    spot.siegeCount = siegeCnt
    return { pos = castPos, maxDist = maxDist, count = #alive, siegeCount = siegeCnt }
  end
  local castPos = spot.pos
  local maxDist = 0
  if spot.camp1 and spot.camp1.pos then maxDist = math.max(maxDist, castPos:Distance(spot.camp1.pos)) end
  if spot.camp2 and spot.camp2.pos then maxDist = math.max(maxDist, castPos:Distance(spot.camp2.pos)) end
  return { pos = castPos, maxDist = maxDist }
end
function Tinker.FindBestJungleSpot(wantAncient, wantNonAnc)
  local myPos = Entity.GetAbsOrigin(State.Hero)
  if not (wantAncient or wantNonAnc) then return nil end
  local allCamps, selectedSet = {}, {}
  for _, camp in pairs(GetJungleSpots()) do
    MaybeUnmarkFarmedCamp(camp)
    if not camp.farmed and GetCampTeam(camp) == State.HeroTeam then
      table.insert(allCamps, camp)
      local isAnc = IsCampAncient(camp)
      if (isAnc and wantAncient) or (not isAnc and wantNonAnc) then
        selectedSet[camp] = true
      end
    end
  end
  if #allCamps == 0 then return nil end

  local coverageMax                           = Constants.MARCH_CAST_RANGE * Constants.MARCH_PAIR_COVERAGE_FRAC
  local bountyK                               = Config.PreferBounty:Get() and Constants.BOUNTY_SCORE_FACTOR_HIGH or
      Constants.BOUNTY_SCORE_FACTOR_LOW

  local enemyPts                              = Tinker.GetEnemyLastKnownPositions()
  local wSpot                                 = Constants.ENEMY_RISK_W_SPOT
  local wAnchor                               = Constants.ENEMY_RISK_W_ANCHOR
  local wPath                                 = Constants.ENEMY_RISK_W_PATH
  local riskW                                 = Constants.ENEMY_RISK_WEIGHT
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

            local anchorPos     = Tinker.IntendedKeenTPPos(center)
            local rSpot         = RiskAtPoint(center, enemyPts)
            local rAnchor       = RiskAtPoint(anchorPos, enemyPts)
            local rPath         = PathRisk(anchorPos, center, enemyPts)

            local score         = math.huge
            local riskLimit     = Constants.ENEMY_RISK_HARD_BLOCK
            local blockR        = Constants.ENEMY_RISK_BLOCK_RADIUS
            if (rSpot >= riskLimit) or (rAnchor >= riskLimit) or (rPath >= riskLimit)
                or AnyEnemyWithin(anchorPos, enemyPts, blockR) then
            else
              local riskPenalty = (wSpot * rSpot + wAnchor * rAnchor + wPath * rPath) * riskW
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
    return {
      pos = (bestPair[1].pos + bestPair[2].pos) / 2,
      camp1 = bestPair[1],
      camp2 = bestPair[2],
      gold = bestPairGold,
      score = bestPairScore,
      kind = "jungle"
    }
  end
  local bestSingle, bestSingleScore, bestSingleGold = nil, math.huge, 0
  for camp, _ in pairs(selectedSet) do
    local distScore   = myPos:Distance(camp.pos) / 100.0
    local gold        = Camp.GetGoldBounty(camp, true)
    local bountyScore = (gold / 50.0) * bountyK

    local anchorPos   = Tinker.IntendedKeenTPPos(camp.pos)
    local rSpot       = RiskAtPoint(camp.pos, enemyPts)
    local rAnchor     = RiskAtPoint(anchorPos, enemyPts)
    local rPath       = PathRisk(anchorPos, camp.pos, enemyPts)

    local riskLimit   = Constants.ENEMY_RISK_HARD_BLOCK
    local blockR      = Constants.ENEMY_RISK_BLOCK_RADIUS
    local score       = math.huge
    if (rSpot >= riskLimit) or (rAnchor >= riskLimit) or (rPath >= riskLimit)
        or AnyEnemyWithin(anchorPos, enemyPts, blockR) then
    else
      local riskPenalty = (wSpot * rSpot + wAnchor * rAnchor + wPath * rPath) * riskW
      score             = distScore + riskPenalty - bountyScore
    end
    if score < bestSingleScore then
      bestSingleScore, bestSingle, bestSingleGold = score, camp, gold
    end
  end
  if bestSingle then
    return {
      pos = bestSingle.pos,
      camp1 = bestSingle,
      single = true,
      gold = bestSingleGold,
      score = bestSingleScore,
      kind = "jungle"
    }
  end
  return nil
end

local function GetLaneDynamicSpotScore(spot)
  if not spot then return math.huge end
  local score = spot.score or 0
  local creepCount = spot.creepCount or (spot.camp1 and spot.camp1.creepCount) or 0
  local siegeCount = spot.siegeCount or (spot.camp1 and spot.camp1.siegeCount) or 0

  score = score - (Constants.LANE_DYNAMIC_SCORE_BIAS or 0)
  if State.PendingLaneRotate then
    score = score - 2.0
  end
  if creepCount <= 2 and siegeCount <= 0 then
    score = score + 2.5
  end
  return score
end

function Tinker.FindBestFarmSpot(excludeSpotKey)
  local enabledTargets = Config.ToFarm:ListEnabled() or {}
  local wantAncient, wantNonAnc, wantLane = false, false, false
  for _, name in ipairs(enabledTargets) do
    if name == L("target_ancients") then wantAncient = true end
    if name == L("target_non_ancients") then wantNonAnc = true end
    if name == L("target_lane") then wantLane = true end
  end
  if not (wantAncient or wantNonAnc or wantLane) then return nil end

  local laneSpot = wantLane and Tinker.FindBestLaneCreepSpot(excludeSpotKey) or nil
  if not (wantAncient or wantNonAnc) then
    return laneSpot
  end

  local jungleSpot = Tinker.FindBestJungleSpot(wantAncient, wantNonAnc)
  if jungleSpot and excludeSpotKey and SpotKey(jungleSpot) == excludeSpotKey then
    jungleSpot = nil
  end

  if not wantLane then return jungleSpot end
  if not jungleSpot then return laneSpot end
  if not laneSpot then return jungleSpot end

  local useDynamic = Config.Lane and Config.Lane.DynamicMixPriority and Config.Lane.DynamicMixPriority:Get()
  if not useDynamic then
    return jungleSpot or laneSpot
  end

  local laneScore = GetLaneDynamicSpotScore(laneSpot)
  local jungleScore = jungleSpot.score or math.huge
  laneSpot.score = laneScore

  if laneScore < jungleScore then
    return laneSpot
  end
  return jungleSpot
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

function Tinker.HasManaForFullCampCycle()
  if not State.KeenTeleport or not State.March or not State.Rearm then return true end
  local curMana = NPC.GetMana(State.Hero) or 0
  local maxMana = NPC.GetMaxMana(State.Hero) or 0
  local need    = Tinker.GetCampCycleManaCost()
  if need > maxMana then return curMana >= (maxMana * 0.9) end
  return curMana >= need
end

local function GetLaneRotateManaCost()
  if not (Config.Lane and Config.Lane.RotateAfterClear and Config.Lane.RotateAfterClear:Get()) then
    return 0
  end
  local tpCost = State.KeenTeleport and (Ability.GetManaCost(State.KeenTeleport) or 0) or 0
  if State.KeenTeleport and CanExecuteAbility(State.KeenTeleport) then
    return tpCost
  end
  if State.Rearm and CanExecuteAbility(State.Rearm) then
    return (Ability.GetManaCost(State.Rearm) or 0) + tpCost
  end
  return tpCost
end

function Tinker.HasManaForSpot(spot)
  if not spot or spot.kind ~= "lane" then
    return Tinker.HasManaForFullCampCycle()
  end
  if not State.March then return true end

  local curMana     = NPC.GetMana(State.Hero) or 0
  local marchCost   = Ability.GetManaCost(State.March) or 0
  local laserCost   = (Config.Lane and Config.Lane.UseLaser and Config.Lane.UseLaser:Get() and State.Laser and
      (Ability.GetManaCost(State.Laser) or 0)) or 0
  local escapeMana  = Tinker.GetEscapeManaCost()
  local rotateCost  = GetLaneRotateManaCost()
  local needStart   = marchCost + escapeMana
  local needPrefer  = needStart + math.min(laserCost, 80) + math.min(rotateCost, 120)
  local maxMana     = NPC.GetMaxMana(State.Hero) or 0

  if curMana >= needStart then return true end
  if needStart > maxMana and curMana >= math.min(needPrefer, maxMana * 0.9) then return true end
  return false
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

  if not Tinker.ShouldRequestTeleport(spot.pos, wantForce) and not wantForce then return false end

  if State.KeenTeleport and Ability.CanBeExecuted(State.KeenTeleport) == -1 then
    local started = Tinker.TryTeleportTo(spot.pos, wantForce)
    if started then
      State.TargetSpotKey   = key
      State.SpotCommitUntil = now + Constants.SPOT_COMMIT_TIME
      if State.FarmState == "MOVING_TO_SPOT" then
        State.BlockTPThisSpot = true
        State.LastSpotTelePos = Tinker.IntendedKeenTPPos(spot.pos)
      end
      State.LastFarmTPAt = now
      return true
    else
      State.PendingTPPos   = spot.pos
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
      State.PendingTPPos   = spot.pos
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

local function RequiredManaBeforeCommit()
  local marchCost  = State.March and (Ability.GetManaCost(State.March) or 0) or 0
  local escapeMana = Tinker.GetEscapeManaCost()
  return marchCost + escapeMana
end
function Tinker.HandleAutoBottle()
  if not Config.ItemsToUse:Get(L("item_bottle")) or State.IsChanneling then return end
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
  if not camp then return 0 end
  if camp.kind == "lane_wave" then
    return RefreshLaneCamp(camp) or 0
  end

  if type(camp.alive_creeps) == "table" then
    local cnt = 0
    for _, unit in pairs(camp.alive_creeps) do
      if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) then
        cnt = cnt + 1
      end
    end

    if cnt > 0 then
      return cnt
    end

    if not (GameRules.IsCheatsEnabled and GameRules.IsCheatsEnabled()) then
      return 0
    end
  end

  return CountCampAliveCreepsByScan(camp)
end

local function GetBlinkCastRangeLimit()
  return Constants.BLINK_CAST_RANGE or Constants.BLINK_MAX_RANGE or 1200
end

local function GetLaneHeroPos()
  return State.Hero and Entity.GetAbsOrigin(State.Hero) or nil
end

local function GetLaneValueUnits(spot)
  if not spot or spot.kind ~= "lane" or not spot.camp1 then
    return {}, { count = 0, siege = 0, ranged = 0, hasSiege = false, hasRanged = false, best = nil }
  end

  RefreshLaneCamp(spot.camp1)

  local rows = {}
  local stats = { count = 0, siege = 0, ranged = 0, hasSiege = false, hasRanged = false, best = nil }
  for _, unit in ipairs(spot.camp1.alive_creeps or {}) do
    if unit and Entity.IsEntity(unit) and Entity.IsAlive(unit) then
      local p = Entity.GetAbsOrigin(unit)
      if p then
        local isSiege = IsSiegeLikeLaneCreep(unit)
        local isRanged = (NPC.IsRanged and NPC.IsRanged(unit)) or false
        local hp = Entity.GetHealth(unit) or 0
        local row = { unit = unit, pos = p, hp = hp, isSiege = isSiege, isRanged = isRanged }
        table.insert(rows, row)
        stats.count = stats.count + 1
        if isSiege then
          stats.siege = stats.siege + 1
          stats.hasSiege = true
        end
        if isRanged then
          stats.ranged = stats.ranged + 1
          stats.hasRanged = true
        end
      end
    end
  end

  local function rank(row)
    if row.isSiege then return 3000 + row.hp end
    if row.isRanged then return 2000 + row.hp end
    return 1000 + row.hp
  end

  for _, row in ipairs(rows) do
    if (not stats.best) or rank(row) > rank(stats.best) then
      stats.best = row
    end
  end

  spot.creepCount = stats.count
  spot.siegeCount = stats.siege
  if spot.camp1 then
    spot.camp1.creepCount = stats.count
    spot.camp1.siegeCount = stats.siege
  end

  return rows, stats
end

local function AbilityTargetRange(ability)
  local base = (ability and Ability.GetCastRange and Ability.GetCastRange(ability)) or 0
  local bonus = (State.Hero and NPC.GetCastRangeBonus and NPC.GetCastRangeBonus(State.Hero)) or 0
  return (base or 0) + (bonus or 0)
end

local function LaneRotateReserveMana()
  local reserve = GetLaneRotateManaCost()
  if reserve <= 0 then return 0 end
  return reserve
end

local function FindNearestEnemyPoint(pt, enemyPts)
  local bestPos, bestDist = nil, math.huge
  for _, ep in ipairs(enemyPts or {}) do
    local d = pt:Distance(ep)
    if d < bestDist then
      bestDist = d
      bestPos = ep
    end
  end
  return bestPos, bestDist
end

local function GetLaneBlinkPreferredDir(castPos, mode, enemyPts)
  local heroPos = GetLaneHeroPos()
  local ref = nil
  local nearestEnemy = FindNearestEnemyPoint(castPos, enemyPts)

  if mode == "retreat" then
    if nearestEnemy then
      ref = castPos - nearestEnemy
    else
      local fountainPos = (State.HeroTeam == 2) and Constants.FOUNTAIN_RADIANT or Constants.FOUNTAIN_DIRE
      ref = fountainPos - castPos
    end
  else
    if nearestEnemy then
      ref = castPos - nearestEnemy
    elseif heroPos then
      ref = heroPos - castPos
    end
  end

  if not ref then return nil end
  local len = ref:Length()
  if len < 1 then return nil end
  return ref:Normalized()
end

local function IsLaneTreeCandidateValid(candidate, castPos, mode, enemyPts)
  if not candidate or not castPos or not State.Hero then return false end
  if not (GridNav and GridNav.IsTraversable and GridNav.IsBlocked and GridNav.IsNearbyTree) then return false end
  if not GridNav.IsTraversable(candidate) then return false end
  if GridNav.IsBlocked(candidate) then return false end
  if not GridNav.IsNearbyTree(candidate, Constants.LANE_TREE_NEARBY_RADIUS or 140) then return false end

  local myPos = Entity.GetAbsOrigin(State.Hero)
  if myPos:Distance(candidate) > (GetBlinkCastRangeLimit() + 24) then return false end

  local dWave = candidate:Distance(castPos)
  local minWave = Constants.LANE_TREE_MIN_WAVE_DIST or 420
  local maxWave = (mode == "retreat") and (Constants.LANE_RETREAT_TREE_SEARCH_RADIUS or 1100) or
      (Constants.LANE_TREE_MAX_WAVE_DIST or 900)
  if dWave < minWave or dWave > maxWave then return false end

  if mode == "approach" and dWave > (Constants.MARCH_CAST_RANGE or 900) then return false end

  local riskLimit = Constants.ENEMY_RISK_HARD_BLOCK or 0.45
  local blockR = Constants.ENEMY_RISK_BLOCK_RADIUS or 1000
  if RiskAtPoint(candidate, enemyPts or {}) >= riskLimit then return false end
  if AnyEnemyWithin(candidate, enemyPts or {}, blockR) then return false end

  return true
end

local function FindLaneTreeBlinkPos(castPos, mode)
  if not castPos or not State.Hero or not State.Blink then return nil end
  if not (GridNav and GridNav.IsTraversable and GridNav.IsBlocked and GridNav.IsNearbyTree) then return nil end

  local now = GameRules.GetGameTime()
  local myPos = Entity.GetAbsOrigin(State.Hero)
  local enemyPts = Tinker.GetEnemyLastKnownPositions()
  local cacheKey = string.format("%s:%s", tostring(mode or "approach"), MakeLaneBucketIndex(castPos))
  State.LaneTreeBlinkCache = State.LaneTreeBlinkCache or {}
  local cached = State.LaneTreeBlinkCache[cacheKey]
  if cached and (now - (cached.at or 0)) <= (Constants.LANE_TREE_CACHE_TTL or 0.20) then
    if cached.pos and IsLaneTreeCandidateValid(cached.pos, castPos, mode, enemyPts) then
      return cached.pos
    end
  end

  local prefDir = GetLaneBlinkPreferredDir(castPos, mode, enemyPts)
  local desiredWaveDist = (mode == "retreat") and 760 or 620
  local blinkRange = GetBlinkCastRangeLimit()
  local rings = Constants.LANE_TREE_CANDIDATE_RINGS or { 460, 600, 760, 880 }
  local stepDeg = Constants.LANE_TREE_CANDIDATE_ANGLE_STEP or 20
  local bestPos, bestScore = nil, math.huge

  for _, r in ipairs(rings) do
    local deg = 0
    while deg < 360 do
      local rad = math.rad(deg)
      local candidate = Vector((castPos.x or 0) + math.cos(rad) * r, (castPos.y or 0) + math.sin(rad) * r, castPos.z or 0)
      if myPos:Distance(candidate) <= (blinkRange + 24)
          and IsLaneTreeCandidateValid(candidate, castPos, mode, enemyPts) then
        local v = candidate - castPos
        local vLen = v:Length()
        local dirPenalty = 0
        if prefDir and vLen > 0 then
          local vd = v / vLen
          local dot = (vd.x or 0) * (prefDir.x or 0) + (vd.y or 0) * (prefDir.y or 0)
          dirPenalty = (1 - dot) * 60
        end
        local risk = RiskAtPoint(candidate, enemyPts)
        local waveDist = candidate:Distance(castPos)
        local score = risk * 1000
            + math.abs(waveDist - desiredWaveDist) * 0.25
            + dirPenalty
            + myPos:Distance(candidate) * (mode == "approach" and -0.03 or 0.02)
        if score < bestScore then
          bestScore = score
          bestPos = candidate
        end
      end
      deg = deg + stepDeg
    end
  end

  State.LastLaneTreeSearchAt = now
  State.LaneTreeBlinkCache[cacheKey] = { at = now, pos = bestPos }
  return bestPos
end

local function TryLaneRetreatBlink(spot, castInfo)
  if not (spot and spot.kind == "lane" and castInfo and castInfo.pos) then return false end
  if not (Config.Lane and Config.Lane.Advanced and Config.Lane.Advanced:Get()) then return false end
  if not (Config.Lane.TreeBlinkRetreat and Config.Lane.TreeBlinkRetreat:Get()) then return false end
  if State.PendingTPPos ~= nil then return false end
  if HasFountainBuff() then return false end

  local holdBlink = IsBlinkLockedNow()
  if holdBlink then return false end
  if not (Config.ItemsToUse:Get(L("item_blink")) and Config.Blink and Config.Blink.Travel and Config.Blink.Travel:Get()) then
    return false
  end
  if not (State.Blink and CanExecuteAbility(State.Blink)) then return false end

  local _, stats = GetLaneValueUnits(spot)
  local nearClear = stats.count <= math.max(2, (Constants.LANE_ROTATE_MIN_CREEPS_LEFT or 1) + 1)
      or (stats.count <= 3 and not stats.hasSiege and not stats.hasRanged)
  if not nearClear then return false end

  local now = GameRules.GetGameTime()
  if (now - (State.LastLaneRetreatBlinkAt or 0)) < 0.45 then return false end

  local pos = FindLaneTreeBlinkPos(castInfo.pos, "retreat")
  if not pos then return false end

  if Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, pos) then
    State.LastLaneRetreatBlinkAt = now
    return true
  end
  return false
end

local function TryLaneBurstAction(spot, castInfo)
  if not (spot and spot.kind == "lane" and castInfo and castInfo.pos) then return false end
  if not (Config.Lane and Config.Lane.Advanced and Config.Lane.Advanced:Get()) then return false end
  if State.IsChanneling then return false end

  local now = GameRules.GetGameTime()
  if (now - (State.LastLaneBurstAt or 0)) < (Constants.LANE_BURST_GAP or 0.10) then return false end

  local rows, stats = GetLaneValueUnits(spot)
  if stats.count <= 0 then return false end

  local myPos = Entity.GetAbsOrigin(State.Hero)
  local curMana = NPC.GetMana(State.Hero) or 0
  local escapeReserve = Tinker.GetEscapeManaCost()
  local rotateReserve = LaneRotateReserveMana()
  local canMarchNow = State.March and CanExecuteAbility(State.March)

  local wantShiva = Config.ItemsToUse:Get(L("item_shivas_guard"))
  if wantShiva and State.Shiva and CanExecuteAbility(State.Shiva) then
    local shivaRad = (Ability.GetAOERadius and Ability.GetAOERadius(State.Shiva)) or 900
    local shivaCost = Ability.GetManaCost(State.Shiva) or 0
    local canAfford = (curMana - shivaCost) >= escapeReserve
    local waveValuable = stats.count >= 3 or stats.hasSiege
    if canAfford and waveValuable and myPos:Distance(castInfo.pos) <= math.max(700, shivaRad - 60) then
      if Utils.CastAbility(State.Shiva, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
        State.LastLaneBurstAt = now
        return true
      end
    end
  end

  local target = stats.best and stats.best.unit or nil
  local targetPos = target and Entity.GetAbsOrigin(target) or nil

  if Config.Lane.UseLaser and Config.Lane.UseLaser:Get()
      and State.Laser and target and targetPos
      and CanExecuteAbility(State.Laser) then
    local laserCost = Ability.GetManaCost(State.Laser) or 0
    local laserRange = math.max(600, AbilityTargetRange(State.Laser))
    local targetDist = myPos:Distance(targetPos)
    local holdForMarch = canMarchNow and stats.count >= (Constants.LANE_LASER_MIN_VALUE_CREEPS or 3) and not stats.hasSiege
    if not holdForMarch and targetDist <= (laserRange + 32) and (curMana - laserCost) >= escapeReserve then
      if Utils.CastAbility(State.Laser, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, target) then
        State.LastLaneBurstAt = now
        return true
      end
    end
  end

  if Config.ItemsToUse:Get(L("item_dagon"))
      and State.Dagon and target and targetPos
      and CanExecuteAbility(State.Dagon) then
    local dagonCost = Ability.GetManaCost(State.Dagon) or 0
    local dagonRange = math.max(600, AbilityTargetRange(State.Dagon))
    local targetDist = myPos:Distance(targetPos)
    local maxCreeps = Constants.LANE_DAGON_USE_MAX_CREEPS or 2
    local needReserve = escapeReserve + (Config.Lane.RotateAfterClear:Get() and
        (rotateReserve + (Constants.LANE_DAGON_MIN_ROTATE_MANA_BUFFER or 35)) or 0)
    if stats.count <= maxCreeps and targetDist <= (dagonRange + 32) and (curMana - dagonCost) >= needReserve then
      if Utils.CastAbility(State.Dagon, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_TARGET, target) then
        State.LastLaneBurstAt = now
        return true
      end
    end
  end

  return false
end

local function LaneSpotShouldRotate(spot)
  if not (spot and spot.kind == "lane" and spot.camp1) then return false end
  local alive = CountCampAliveCreeps(spot.camp1)
  if alive <= (Constants.LANE_ROTATE_MIN_CREEPS_LEFT or 1) then
    return true
  end

  local _, stats = GetLaneValueUnits(spot)
  if stats.count <= 0 then return true end
  if stats.count <= 2 and (not stats.hasSiege) and (not stats.hasRanged) then return true end
  return false
end

function Tinker.TryRotateAfterLaneClear(spot)
  if not (Config.Lane and Config.Lane.Advanced and Config.Lane.Advanced:Get()) then return false end
  if not (Config.Lane.RotateAfterClear and Config.Lane.RotateAfterClear:Get()) then return false end

  local curSpot = spot or State.CurrentFarmSpot
  if not (curSpot and curSpot.kind == "lane") then return false end
  if not LaneSpotShouldRotate(curSpot) then return false end

  local now = GameRules.GetGameTime()
  local curKey = SpotKey(curSpot)
  State.PendingLaneRotate = true
  State.LastLaneSpotKey = curKey
  State.CachedBestSpot = nil
  State.LastSpotScan = 0

  local nextSpot = Tinker.FindBestFarmSpot(curKey)
  State.PendingLaneRotate = false

  if not nextSpot then
    return false
  end

  if not Tinker.HasManaForSpot(nextSpot) then
    State.FarmState                = "RETURNING_TO_FOUNTAIN"
    State.CurrentFarmSpot          = nil
    State.AfterMarchCheck          = nil
    State.TargetSpotKey            = nil
    State.SpotCommitUntil          = 0
    State.CurrentSpotMarchCasts    = 0
    State.CurrentSpotMarchRequired = nil
    return true
  end

  State.CurrentFarmSpot       = nextSpot
  State.TargetSpotKey         = SpotKey(nextSpot)
  State.SpotCommitUntil       = now + Constants.SPOT_COMMIT_TIME
  State.BlockTPThisSpot       = false
  State.LastSpotTelePos       = nil
  State.MovingAfterTeleport   = false
  State.RecalcAfterTP         = false
  State.AfterMarchCheck       = nil
  State.LastMarchCastAt       = 0
  State.CurrentSpotMarchCasts = 0
  if Config.MarchControl.UseCustom:Get() then
    State.CurrentSpotMarchRequired = ComputeRequiredMarchesForSpot(nextSpot)
    if (State.CurrentSpotMarchRequired or 0) <= 0 then
      State.CurrentSpotMarchRequired = nil
      return false
    end
  else
    State.CurrentSpotMarchRequired = nil
  end
  if Constants.LANE_ROTATE_BYPASS_IDLE_DELAY then
    State.JustClearedSpotAt = 0
  else
    State.JustClearedSpotAt = now
  end
  State.FarmState = "MOVING_TO_SPOT"
  return true
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
    local clearedSpot = State.CurrentFarmSpot
    State.AfterMarchCheck = nil
    if State.FarmState == "FARMING_SPOT" then
      if clearedSpot and clearedSpot.kind == "lane" and Tinker.TryRotateAfterLaneClear(clearedSpot) then
        return
      end
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
    if Modifier.GetDuration(NPC.GetModifier(State.Hero, "modifier_tinker_defense_matrix")) > 7 then return false end
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
      and Config.Blink.Escape:Get()
      and State.Blink
      and Ability.CanBeExecuted(State.Blink) == -1 then
    local myPos      = Entity.GetAbsOrigin(State.Hero)
    local toFountain = (fountainPos - myPos)
    local dist       = toFountain:Length()
    local blinkRange = GetBlinkCastRangeLimit()
    local blinkPos   = dist > blinkRange
        and (myPos + toFountain:Normalized() * blinkRange) or fountainPos
    Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, blinkPos)
  end

  Utils.MoveTo(fountainPos)
  return true
end

local function ComputeSafeBlinkPos(targetPos)
  if not State.Hero then return nil end
  local myPos = Entity.GetAbsOrigin(State.Hero)
  local dir   = (targetPos - myPos)
  local dist  = dir:Length()
  if dist <= Constants.BLINK_MIN_DISTANCE then return nil end
  local ndir     = dir:Normalized()
  local standOff = Constants.BLINK_SAFE_STANDOFF
  local maxStep  = GetBlinkCastRangeLimit()
  local desired  = math.max(dist - standOff, 0)
  local step     = math.min(maxStep, desired > 0 and desired or dist)
  return myPos + ndir * step
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
    if State.PendingTPPos then
      -- Do not wander / issue extra orders while we are waiting to finish Rearm->TP or retry TP.
      return
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
      if not Tinker.HasManaForSpot(bestSpot) then
        State.FarmState       = "RETURNING_TO_FOUNTAIN"
        State.CurrentFarmSpot = nil
        State.AfterMarchCheck = nil
        State.TargetSpotKey   = nil
        State.SpotCommitUntil = 0
        return
      end

      State.CurrentFarmSpot       = bestSpot
      State.TargetSpotKey         = SpotKey(bestSpot)
      State.LastLaneSpotKey       = (bestSpot.kind == "lane") and State.TargetSpotKey or State.LastLaneSpotKey
      State.SpotCommitUntil       = GameRules.GetGameTime() + Constants.SPOT_COMMIT_TIME

      State.BlockTPThisSpot       = false
      State.LastSpotTelePos       = nil
      State.MovingAfterTeleport   = false
      State.RecalcAfterTP         = false
      State.JustClearedSpotAt     = 0
      State.AfterMarchCheck       = nil
      State.LastMarchCastAt       = 0
      State.CurrentSpotMarchCasts = 0
      State.PendingLaneRotate     = false
      if Config.MarchControl.UseCustom:Get() then
        State.CurrentSpotMarchRequired = ComputeRequiredMarchesForSpot(bestSpot)
        if (State.CurrentSpotMarchRequired or 0) <= 0 then
          MarkSpotFarmedAndLeave()
          return
        end
      else
        State.CurrentSpotMarchRequired = nil
      end

      State.FarmState = "MOVING_TO_SPOT"
    end
  elseif State.FarmState == "MOVING_TO_SPOT" then
    local spot = State.CurrentFarmSpot
    if not spot or not spot.camp1 or spot.camp1.farmed then
      State.FarmState = "IDLE"
      return
    end

    if State.RecalcAfterTP and (GameRules.GetGameTime() - (State.LastTeleportAt or 0)) > 0.2 then
      RecenterSpot(spot)
      State.RecalcAfterTP = false
    end
    if Config.MarchControl.UseCustom:Get() and (State.CurrentSpotMarchRequired or 0) <= 0 then
      MarkSpotFarmedAndLeave()
      return
    end

    if not Tinker.HasManaForSpot(spot) then
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
      if spot and spot.kind == "lane" and Tinker.TryRotateAfterLaneClear(spot) then
        return
      end
      State.FarmState = "IDLE"
      return
    end

    local intended   = Tinker.IntendedKeenTPPos(castInfo.pos)
    local distToLand = myPos:Distance(intended)
    local allowedMax = Constants.MARCH_CAST_RANGE * (spot.single and 1.0 or Constants.MARCH_PAIR_COVERAGE_FRAC)

    if castInfo.maxDist <= allowedMax and myPos:Distance(castInfo.pos) <= Constants.MARCH_CAST_RANGE then
      State.MovingAfterTeleport = false
      State.FarmState           = "FARMING_SPOT"
      if Config.MarchControl.UseCustom:Get() then
        if (State.CurrentSpotMarchRequired or 0) <= (State.CurrentSpotMarchCasts or 0) then
          MarkSpotFarmedAndLeave()
          return
        end
      end
      return
    end

    local requiredMana = RequiredManaBeforeCommit()
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
        and Config.Blink.Travel:Get()
        and State.Blink
        and Ability.CanBeExecuted(State.Blink) == -1 then
      local blinkPos = nil
      if spot.kind == "lane"
          and Config.Lane and Config.Lane.Advanced and Config.Lane.Advanced:Get()
          and Config.Lane.TreeBlinkApproach and Config.Lane.TreeBlinkApproach:Get() then
        blinkPos = FindLaneTreeBlinkPos(castInfo.pos, "approach")
      end
      if not blinkPos then
        blinkPos = ComputeSafeBlinkPos(castInfo.pos)
      end
      if blinkPos and Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, blinkPos) then return end
    end

    Utils.MoveTo(castInfo.pos)
  elseif State.FarmState == "FARMING_SPOT" then
    local spot = State.CurrentFarmSpot
    if not spot or (spot.camp1.farmed and (spot.single or spot.camp2.farmed)) then
      if spot and spot.kind == "lane" and Tinker.TryRotateAfterLaneClear(spot) then
        return
      end
      State.FarmState                = "IDLE"
      State.AfterMarchCheck          = nil
      State.CurrentSpotMarchCasts    = 0
      State.CurrentSpotMarchRequired = nil
      return
    end
    if Config.MarchControl.UseCustom:Get() then
      local req = State.CurrentSpotMarchRequired or 0
      if req > 0 and (State.CurrentSpotMarchCasts or 0) >= req then
        MarkSpotFarmedAndLeave()
        return
      end
    end

    local escapeMana  = Tinker.GetEscapeManaCost()
    local t           = GameRules.GetGameTime()
    local am          = Config.MarchControl.UseCustom:Get() and nil or State.AfterMarchCheck
    local minGap      = Constants.MARCH_MIN_RECAST_GAP
    local rearmGap    = Constants.REARM_MIN_GAP_AFTER_MARCH
    local canMarchNow = State.March and Ability.CanBeExecuted(State.March) == -1
    local canRearmNow = State.Rearm and Ability.CanBeExecuted(State.Rearm) == -1
    local justTPedAgo = t - (State.LastTeleportAt or 0)

    local c1          = spot.camp1 and CountCampAliveCreeps(spot.camp1) or 0
    local c2          = (not spot.single and spot.camp2 and CountCampAliveCreeps(spot.camp2)) or 0
    local anyAlive    = (c1 > 0) or (c2 > 0)

    if spot.kind == "lane" and Config.Lane and Config.Lane.Advanced and Config.Lane.Advanced:Get() then
      local laneCastInfo = ComputeMarchCastInfo(spot)
      if not laneCastInfo then
        if Tinker.TryRotateAfterLaneClear(spot) then return end
        State.FarmState                = "IDLE"
        State.CurrentFarmSpot          = nil
        State.AfterMarchCheck          = nil
        State.TargetSpotKey            = nil
        State.SpotCommitUntil          = 0
        State.CurrentSpotMarchCasts    = 0
        State.CurrentSpotMarchRequired = nil
        return
      else
        if TryLaneRetreatBlink(spot, laneCastInfo) then return end
        if TryLaneBurstAction(spot, laneCastInfo) then return end
        if Tinker.TryRotateAfterLaneClear(spot) then return end
      end
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
          Utils.CastAbility(State.March, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, spot.pos)
        end
        return
      end

      if anyAlive and canRearmNow then
        if justTPedAgo >= Constants.NO_REARM_AFTER_TP and (t - (State.LastMarchCastAt or 0)) >= rearmGap then
          local rearmCost = Ability.GetManaCost(State.Rearm) or 0
          if ((NPC.GetMana(State.Hero) or 0) - rearmCost) >= escapeMana then
            if Utils.CastAbility(State.Rearm, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_NO_TARGET, nil) then
              MarkRearmIssued(t)
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
        if Utils.CastAbility(State.March, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, spot.pos) then
          if not Config.MarchControl.UseCustom:Get() then
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
      local minFracNeed = maxMana * Constants.FOUNTAIN_MIN_MANA_FRAC
      local need        = math.max(minFracNeed, math.min(cycleCost, maxMana * 0.95))
      if curMana >= need then
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
        and Config.Blink.Travel:Get()
        and State.Blink
        and Ability.CanBeExecuted(State.Blink) == -1 then
      local myPos      = Entity.GetAbsOrigin(State.Hero)
      local toFountain = (fountainPos - myPos)
      local dist       = toFountain:Length()
      local blinkRange = GetBlinkCastRangeLimit()
      local blinkPos   = dist > blinkRange and
          (myPos + toFountain:Normalized() * blinkRange) or fountainPos
      if Utils.CastAbility(State.Blink, Enum.UnitOrder.DOTA_UNIT_ORDER_CAST_POSITION, blinkPos) then return end
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
  if castInfo and castInfo.pos then castPos = castInfo.pos end
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
  if (not spot.single) and castInfo then
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
  if castInfo and castInfo.pos then castPos = castInfo.pos end
  local allowedMax = Constants.MARCH_CAST_RANGE * (spot.single and 1.0 or Constants.MARCH_PAIR_COVERAGE_FRAC)
  WorldRing(castPos, Constants.MARCH_CAST_RANGE, Color(120, 255, 120, 150), 1.6, 48)
  if (not spot.single) and castInfo then
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
    local fit        = castInfo and (castInfo.maxDist <= allowedMax) or false

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
      table.insert(lines, { "Type",
        spot.single and "single" or ("pair (" .. math.floor(Constants.MARCH_PAIR_COVERAGE_FRAC * 100) .. "% cover)"),
        Theme.dim })
      if castInfo then
        table.insert(lines,
          { "Max Camp Dist", string.format("%.0f / %.0f", castInfo.maxDist, allowedMax), fit and Theme.good or Theme.bad })
        table.insert(lines,
          { "Hero->Cast", string.format("%.0f / %d", Entity.GetAbsOrigin(State.Hero):Distance(castInfo.pos),
            Constants.MARCH_CAST_RANGE), Theme.dim })
      else
        table.insert(lines, { "Spot Metrics", "N/A (target moved/despawned)", Theme.warn })
      end
    end
    local mode = Config.MarchControl.UseCustom:Get() and "Custom Count" or "Until Cleared"
    table.insert(lines, { "March Mode", mode, Theme.accent })
    if Config.MarchControl.UseCustom:Get() then
      local req = State.CurrentSpotMarchRequired or 0
      local have = State.CurrentSpotMarchCasts or 0
      table.insert(lines, { "Marches", string.format("%d / %d", have, req), (have >= req and Theme.good or Theme.dim) })
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
  if not State.Hero or not Entity.IsEntity(State.Hero) then return end
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
    State.CampAliveScanCache       = {}
    State.NeutralSnapshot          = { at = 0, list = {} }
    State.LaneCreepSnapshot        = { at = 0, list = {} }
    State.PendingLaneRotate        = false
    State.LaneTreeBlinkCache       = {}
    State.LaneBurstTargets         = {}
    return
  end

  State.HeroTeam     = Entity.GetTeamNum(State.Hero)
  State.IsChanneling = NPC.IsChannellingAbility(State.Hero)
  State.Rearm        = NPC.GetAbility(State.Hero, "tinker_rearm")
  State.March        = NPC.GetAbility(State.Hero, "tinker_march_of_the_machines")
  State.Laser        = NPC.GetAbility(State.Hero, "tinker_laser")
  State.KeenTeleport = NPC.GetAbility(State.Hero, "tinker_keen_teleport")
  State.Blink        = NPC.GetItem(State.Hero, "item_blink", true)
      or NPC.GetItem(State.Hero, "item_overwhelming_blink", true)
      or NPC.GetItem(State.Hero, "item_swift_blink", true)
      or NPC.GetItem(State.Hero, "item_arcane_blink", true)
  State.Shiva        = NPC.GetItem(State.Hero, "item_shivas_guard", true)
  State.Dagon        = Tinker.GetDagonItem()
  MaybeResetCampStateForSession()
  UpdateRearmBlinkHold()

  local autoOn   = Config.AutoFarm:IsToggled()
  local autoWasOn = State.AutoFarmWasOn

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
    State.PendingLaneRotate = false

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
      State.PendingLaneRotate        = false
      State.CachedBestSpot           = nil
      State.LaneTreeBlinkCache       = {}
    end
    return
  end
  if not autoWasOn then
    ResetFarmedCampFlags("autofarmToggleOn")
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
