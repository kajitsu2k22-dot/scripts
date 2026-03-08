local script = {}

--------------------------------------------------------------------------------
-- ABILITY LAST HIT v2.0 — авто-добитие крипов способностями
-- Активируется при зажатом бинде Last Hit Helper
-- Сканирует ближайших вражеских крипов и добивает их способностями
-- author: Copilot
-- Created: 2026-03-08
--------------------------------------------------------------------------------

local UI = {}
local menuGroup = nil
local currentHeroName = nil
local currentHeroAbilitySignature = nil
local lastCastTime = 0
local CAST_INTERVAL = 0.25
local lastCastLockDuration = 0
local lastTargetEntity = nil
local lastTargetTime = 0
local lastTargetLockDuration = 0
local TARGET_COOLDOWN_MIN = 0.15
local TARGET_COOLDOWN_MAX = 1.25
local DEBUG_PREFIX = "[AbilityLH] "
local lastDebugTime = 0
local DEBUG_INTERVAL = 1.0
local DEBUG_REPEAT_INTERVAL = 8.0
local lastDebugByKey = {}
local resolvedAbilityInfoCache = {}
local ABILITY_BEHAVIOR_CACHE = {}
local CONDITION_ITEMS = {
    smart = "Не воровать у тычки",
    predict = "Предикт HP",
    aoe = "AoE на пачку",
}
local CREEP_FILTER_ITEMS = {
    melee = "Ближний бой",
    ranged = "Дальний бой",
    neutral = "Нейтралы",
    siege = "Катапульты",
}

--- HP-трекер крипов (предсказание урона союзников)
CONDITION_ITEMS.smart = "smart"
CONDITION_ITEMS.predict = "predict"
CONDITION_ITEMS.aoe = "aoe"
CREEP_FILTER_ITEMS.melee = "melee"
CREEP_FILTER_ITEMS.ranged = "ranged"
CREEP_FILTER_ITEMS.neutral = "neutral"
CREEP_FILTER_ITEMS.siege = "siege"

local MENU_LANG = "ru"
local languageWidget = nil
local I18N = {
    ru = {
        settings = "Настройки",
        enable = "Включить",
        enable_tip = "Автодобив спеллами. Работает, пока держишь хоткей.",
        hotkey = "Хоткей",
        hotkey_tip = "Зажми кнопку, когда хочешь отдать крипа нюком.",
        conditions = "Условия",
        conditions_tip = "Что учитывать при выборе каста.",
        creeps = "Крипы",
        creeps_tip = "Какие типы крипов можно добивать спеллом.",
        search_range = "Радиус",
        search_range_tip = "На каком расстоянии искать крипов под spell CS.",
        min_mana = "Мана %",
        min_mana_tip = "Ниже этого процента скрипт перестанет тратить ману на фарм.",
        buffer = "Запас HP",
        buffer_tip = "Сколько HP можно накинуть сверху, чтобы нюк не мисснул добив.",
        debug = "Лог",
        debug_tip = "Писать в лог расчеты урона, предикт HP и выбранный каст.",
        spells = "Спеллы",
        spells_tip = "Какие нюки можно тратить на добив. Список обновляется под текущего героя.",
        cond_smart = "Не воровать у тычки",
        cond_predict = "Предикт HP",
        cond_aoe = "AoE на пачку",
        creep_melee = "Ближний бой",
        creep_ranged = "Дальний бой",
        creep_neutral = "Нейтралы",
        creep_siege = "Катапульты",
    },
    en = {
        settings = "Settings",
        enable = "Enable",
        enable_tip = "Automatic spell last hit while the hotkey is held.",
        hotkey = "Hotkey",
        hotkey_tip = "Hold the key when you want to secure a creep with a spell.",
        conditions = "Conditions",
        conditions_tip = "What to consider before casting.",
        creeps = "Creeps",
        creeps_tip = "Which creep types can be secured with spells.",
        search_range = "Range",
        search_range_tip = "How far to search for creeps for spell CS.",
        min_mana = "Mana %",
        min_mana_tip = "Stop spending mana for farm below this threshold.",
        buffer = "HP Buffer",
        buffer_tip = "Extra HP margin so the nuke does not miss the last hit.",
        debug = "Log",
        debug_tip = "Write damage checks, HP prediction and chosen casts to the log.",
        spells = "Spells",
        spells_tip = "Which nukes can be used for last hits. Updates for the current hero.",
        cond_smart = "Respect attack",
        cond_predict = "HP prediction",
        cond_aoe = "AOE greed",
        creep_melee = "Melee",
        creep_ranged = "Ranged",
        creep_neutral = "Neutrals",
        creep_siege = "Siege",
    },
    cn = {
        settings = "设置",
        enable = "启用",
        enable_tip = "按住热键时自动用技能补刀。",
        hotkey = "热键",
        hotkey_tip = "想用技能收兵时按住这个键。",
        conditions = "条件",
        conditions_tip = "选择施法前要检查的条件。",
        creeps = "小兵",
        creeps_tip = "选择允许用技能补刀的小兵类型。",
        search_range = "范围",
        search_range_tip = "技能补刀时搜索小兵的距离。",
        min_mana = "法力%",
        min_mana_tip = "低于这个法力百分比后不再用技能刷兵。",
        buffer = "血量余量",
        buffer_tip = "给补刀多留一点血量余量，避免伤害差一点。",
        debug = "日志",
        debug_tip = "在日志里输出伤害判断、血量预测和施法结果。",
        spells = "技能",
        spells_tip = "当前英雄可用于补刀的技能列表。",
        cond_smart = "不抢普攻",
        cond_predict = "血量预测",
        cond_aoe = "优先AOE",
        creep_melee = "近战",
        creep_ranged = "远程",
        creep_neutral = "野怪",
        creep_siege = "攻城车",
    },
}

local creepHPTracker = {}  -- [entityIndex] = { hp=N, time=T, dps=N }
local TRACKER_CLEANUP_INTERVAL = 5.0
local lastTrackerCleanup = 0

local function dbg(msg)
    if UI.Debug and UI.Debug:Get() then
        Log.Write(DEBUG_PREFIX .. tostring(msg))
    end
end

local function dbgThrottle(msg)
    if not (UI.Debug and UI.Debug:Get()) then return end
    local now = GameRules.GetGameTime()
    if now - lastDebugTime < DEBUG_INTERVAL then return end
    lastDebugTime = now
    Log.Write(DEBUG_PREFIX .. tostring(msg))
end

local function dbgThrottleKey(key, msg, interval)
    if not (UI.Debug and UI.Debug:Get()) then return end
    local now = GameRules.GetGameTime()
    local cooldown = interval or DEBUG_INTERVAL
    if key and lastDebugByKey[key] and (now - lastDebugByKey[key]) < cooldown then
        return
    end
    if key then
        lastDebugByKey[key] = now
    else
        lastDebugTime = now
    end
    Log.Write(DEBUG_PREFIX .. tostring(msg))
end

local function t(key)
    local langTable = I18N[MENU_LANG] or I18N.ru or I18N.en or {}
    return langTable[key] or (I18N.en and I18N.en[key]) or (I18N.ru and I18N.ru[key]) or tostring(key)
end

local function getMenuLanguageWidget()
    if languageWidget then
        return languageWidget
    end

    local ok, widget = pcall(Menu.Find, "SettingsHidden", "", "", "", "Main", "Language")
    if ok and widget then
        languageWidget = widget
    end

    return languageWidget
end

local function detectMenuLanguage()
    local widget = getMenuLanguageWidget()
    if not widget then
        return MENU_LANG
    end

    local ok, value = pcall(function() return widget:Get() end)
    if not ok or value == nil then
        return MENU_LANG
    end

    if value == 1 then
        return "ru"
    elseif value == 2 then
        return "cn"
    end

    return "en"
end

local function conditionLabel(itemKey)
    return t("cond_" .. tostring(itemKey))
end

local function creepFilterLabel(itemKey)
    return t("creep_" .. tostring(itemKey))
end

local function getAbilityByName(hero, abilityName)
    if not hero or not abilityName then return nil end

    if NPC.GetAbilityByName then
        local ok, ability = pcall(NPC.GetAbilityByName, hero, abilityName)
        if ok and ability then return ability end
    end

    do
        local ok, ability = pcall(function() return hero:GetAbilityByName(abilityName) end)
        if ok and ability then return ability end
    end

    if NPC.GetAbility then
        local ok, ability = pcall(NPC.GetAbility, hero, abilityName)
        if ok and ability then return ability end
    end

    return nil
end

local function isLaneCreepUnit(npc)
    if NPC.IsLaneCreep then
        local ok, value = pcall(NPC.IsLaneCreep, npc)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return npc:IsLaneCreep() end)
    return ok and value or false
end

local function isRangedUnit(npc)
    if NPC.IsRanged then
        local ok, value = pcall(NPC.IsRanged, npc)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return npc:IsRanged() end)
    return ok and value or false
end

local function isNeutralUnit(npc)
    if NPC.IsNeutral then
        local ok, value = pcall(NPC.IsNeutral, npc)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return npc:IsNeutral() end)
    return ok and value or false
end

local function isCreepUnit(npc)
    if NPC.IsCreep then
        local ok, value = pcall(NPC.IsCreep, npc)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return npc:IsCreep() end)
    return ok and value or false
end

--------------------------------------------------------------------------------
-- HERO-ABILITY DATABASE (70+ heroes)
-- beh:            "target" | "point" | "no_target"
-- radius:         AoE-радиус (для point/no_target)
-- fixedRange:     дистанция приземления (SF razes)
-- dmgKey:         ключ AbilitySpecial
-- dmgTypeOverride: "pure"/"physical"/"magical"
-- fixedDmg:       {lvl1, lvl2, lvl3, lvl4} жёсткий fallback
-- projSpeed:      скорость снаряда (для HP-предсказания), 0 = мгновенно
--------------------------------------------------------------------------------
local HERO_ABILITIES = {
    ------------- UNIT TARGET --------------------------------------------------
    npc_dota_hero_zuus = {
        { name = "zuus_arc_lightning",          beh = "target", dmgKey = "arc_damage", projSpeed = 1100 },
    },
    npc_dota_hero_shadow_shaman = {
        { name = "shadow_shaman_ether_shock",   beh = "target", dmgKey = "damage" },
    },
    npc_dota_hero_tinker = {
        { name = "tinker_laser",                beh = "target", dmgKey = "laser_damage", dmgTypeOverride = "pure" },
    },
    npc_dota_hero_rubick = {
        { name = "rubick_fade_bolt",            beh = "target", dmgKey = "damage", projSpeed = 1200 },
    },
    npc_dota_hero_skywrath_mage = {
        { name = "skywrath_mage_arcane_bolt",   beh = "target", dmgKey = "bolt_damage", projSpeed = 500 },
    },
    npc_dota_hero_ogre_magi = {
        { name = "ogre_magi_fireblast",         beh = "target", dmgKey = "fireblast_damage" },
    },
    npc_dota_hero_hoodwink = {
        { name = "hoodwink_acorn_shot",         beh = "target", dmgKey = "acorn_shot_damage", attackPctKey = "base_damage_pct", dmgTypeOverride = "physical", projSpeed = 2200, noSpellAmp = true },
    },
    npc_dota_hero_muerta = {
        { name = "muerta_dead_shot",            beh = "target", dmgKey = "damage", projSpeed = 2000 },
    },
    npc_dota_hero_witch_doctor = {
        { name = "witch_doctor_paralyzing_cask", beh = "target", dmgKey = "base_damage", projSpeed = 1000 },
    },
    npc_dota_hero_bane = {
        { name = "bane_brain_sap",              beh = "target", dmgKey = "brain_sap_damage", dmgTypeOverride = "pure" },
    },
    npc_dota_hero_lich = {
        { name = "lich_frost_nova",             beh = "target", dmgKey = "blast_damage" },
    },
    npc_dota_hero_clinkz = {
        { name = "clinkz_tar_bomb",             beh = "target", dmgKey = "impact_damage", radius = 325, projSpeed = 2000, dmgTypeOverride = "magical" },
    },
    npc_dota_hero_luna = {
        { name = "luna_lucent_beam",            beh = "target", dmgKey = "beam_damage" },
    },
    npc_dota_hero_sven = {
        { name = "sven_storm_bolt",             beh = "target", radius = 250, projSpeed = 1000, fixedDmg = {80, 160, 240, 320} },
    },
    npc_dota_hero_vengefulspirit = {
        { name = "vengefulspirit_magic_missile", beh = "target", dmgKey = "magic_missile_damage", projSpeed = 1350 },
        { name = "vengefulspirit_wave_of_terror", beh = "point", radius = 325, dmgKey = "damage", dmgTypeOverride = "magical", projSpeed = 2000 },
    },
    npc_dota_hero_chaos_knight = {
        { name = "chaos_knight_chaos_bolt",     beh = "target", dmgKey = "damage_min", projSpeed = 700 },
    },
    npc_dota_hero_skeleton_king = {  -- Wraith King
        { name = "skeleton_king_hellfire_blast", beh = "target", dmgKey = "damage", projSpeed = 1200 },
    },
    npc_dota_hero_phantom_lancer = {
        { name = "phantom_lancer_spirit_lance", beh = "target", dmgKey = "lance_damage", projSpeed = 1000 },
    },
    npc_dota_hero_medusa = {
        { name = "medusa_mystic_snake",         beh = "target", dmgKey = "snake_damage", projSpeed = 800 },
    },
    npc_dota_hero_visage = {
        { name = "visage_soul_assumption",      beh = "target", dmgKey = "soul_base_damage", projSpeed = 1000 },
    },
    npc_dota_hero_winter_wyvern = {
        { name = "winter_wyvern_splinter_blast", beh = "target", radius = 500, dmgKey = "damage", projSpeed = 1200, excludePrimaryTarget = true, allowAoEOnly = true },
    },
    npc_dota_hero_night_stalker = {
        { name = "night_stalker_void",          beh = "target", dmgKey = "damage" },
    },
    npc_dota_hero_centaur = {
        { name = "centaur_double_edge",         beh = "target", dmgKey = "edge_damage" },
    },
    npc_dota_hero_oracle = {
        { name = "oracle_purifying_flames",     beh = "target", dmgKey = "damage" },
    },
    npc_dota_hero_bounty_hunter = {
        { name = "bounty_hunter_shuriken_toss", beh = "target", dmgKey = "bonus_damage", projSpeed = 1000 },
    },
    npc_dota_hero_phantom_assassin = {
        { name = "phantom_assassin_stifling_dagger", beh = "target", attackPctKey = "attack_factor_tooltip", flatDamageKey = "base_damage", dmgTypeOverride = "physical", projSpeed = 1200, noSpellAmp = true },
    },
    npc_dota_hero_abaddon = {
        { name = "abaddon_death_coil",          beh = "target", dmgKey = "target_damage", projSpeed = 1300, selfDamageKeys = {"self_damage_enemy_target", "self_damage"}, selfHpBuffer = 40 },
    },
    npc_dota_hero_leshrac = {
        { name = "leshrac_lightning_storm",     beh = "target", dmgKey = "damage", projSpeed = 1100 },
        { name = "leshrac_split_earth",         beh = "point", radius = 150 },
    },
    npc_dota_hero_morphling = {
        { name = "morphling_adaptive_strike_agi", beh = "target", dmgTypeOverride = "physical", projSpeed = 1150 },
        { name = "morphling_waveform",          beh = "point", radius = 200 },
    },
    npc_dota_hero_dragon_knight = {
        { name = "dragon_knight_breathe_fire",  beh = "point", radius = 200, dmgKey = "damage", projSpeed = 1050 },
    },

    ------------- NO TARGET (AoE вокруг героя) --------------------------------
    npc_dota_hero_queenofpain = {
        { name = "queenofpain_scream_of_pain",  beh = "no_target", radius = 550 },
    },
    npc_dota_hero_bristleback = {
        { name = "bristleback_quill_spray",     beh = "no_target", radius = 700, dmgKey = "quill_base_damage", dmgTypeOverride = "physical" },
    },
    npc_dota_hero_tidehunter = {
        { name = "tidehunter_anchor_smash",     beh = "no_target", radius = 375, dmgTypeOverride = "physical" },
    },
    npc_dota_hero_slardar = {
        { name = "slardar_slithereen_crush",    beh = "no_target", radius = 350, dmgTypeOverride = "physical" },
    },
    npc_dota_hero_mirana = {
        { name = "mirana_starfall",             beh = "no_target", radius = 650 },
    },
    npc_dota_hero_necrolyte = {  -- Necrophos
        { name = "necrolyte_death_pulse",       beh = "no_target", radius = 500 },
    },
    npc_dota_hero_ursa = {
        { name = "ursa_earthshock",             beh = "no_target", radius = 385 },
    },
    npc_dota_hero_dawnbreaker = {
        { name = "dawnbreaker_fire_wreath",     beh = "no_target", radius = 300, dmgTypeOverride = "physical" },
    },
    npc_dota_hero_razor = {
        { name = "razor_plasma_field",          beh = "no_target", radius = 700 },
    },
    npc_dota_hero_mars = {
        { name = "mars_gods_rebuke",            beh = "no_target", radius = 500, critPctKey = "crit_mult", dmgTypeOverride = "physical", noSpellAmp = true },
        { name = "mars_spear",                  beh = "point", radius = 125, dmgKey = "damage", projSpeed = 1400 },
    },

    ------------- POINT (направл. / AoE по точке) -----------------------------
    npc_dota_hero_lina = {
        { name = "lina_dragon_slave",           beh = "point", radius = 275, dmgKey = "dragon_slave_damage" },
    },
    npc_dota_hero_death_prophet = {
        { name = "death_prophet_carrion_swarm", beh = "point", radius = 300, dmgKey = "damage" },
    },
    npc_dota_hero_pugna = {
        { name = "pugna_nether_blast",          beh = "point", radius = 400 },
    },
    npc_dota_hero_crystal_maiden = {
        { name = "crystal_maiden_crystal_nova", beh = "point", radius = 425, dmgKey = "nova_damage" },
    },
    npc_dota_hero_lion = {
        { name = "lion_impale",                 beh = "point", radius = 150 },
    },
    npc_dota_hero_snapfire = {
        { name = "snapfire_scatterblast",       beh = "point", radius = 225 },
    },
    npc_dota_hero_jakiro = {
        { name = "jakiro_dual_breath",          beh = "point", radius = 250 },
    },
    npc_dota_hero_sand_king = {
        { name = "sand_king_burrowstrike",      beh = "point", radius = 150 },
    },
    npc_dota_hero_earthshaker = {
        { name = "earthshaker_fissure",         beh = "point", radius = 150 },
    },
    npc_dota_hero_puck = {
        { name = "puck_illusory_orb",           beh = "point", radius = 225, dmgKey = "damage", projSpeed = 550 },
        { name = "puck_waning_rift",            beh = "point", radius = 400 },
    },
    npc_dota_hero_windrunner = {
        { name = "windrunner_powershot",        beh = "point", radius = 125 },
    },
    npc_dota_hero_venomancer = {
        { name = "venomancer_venomous_gale",    beh = "point", radius = 125 },
    },
    npc_dota_hero_dark_seer = {
        { name = "dark_seer_vacuum",            beh = "point", radius = 400 },
    },
    npc_dota_hero_kunkka = {
        { name = "kunkka_torrent",              beh = "point", radius = 225 },
    },
    npc_dota_hero_shadow_demon = {
        { name = "shadow_demon_shadow_poison",  beh = "point", radius = 200, projSpeed = 1500 },
    },
    npc_dota_hero_legion_commander = {
        { name = "legion_commander_overwhelming_odds", beh = "point", radius = 330 },
    },
    npc_dota_hero_undying = {
        { name = "undying_decay",               beh = "point", radius = 325 },
    },
    npc_dota_hero_ember_spirit = {
        { name = "ember_spirit_sleight_of_fist", beh = "point", radius = 250, dmgTypeOverride = "physical" },
    },
    npc_dota_hero_monkey_king = {
        { name = "monkey_king_boundless_strike", beh = "point", radius = 150, critPctKey = "strike_crit_mult", flatDamageKey = "strike_flat_damage", dmgTypeOverride = "physical", noSpellAmp = true },
    },
    npc_dota_hero_nyx_assassin = {
        { name = "nyx_assassin_impale",         beh = "point", radius = 200 },
    },
    npc_dota_hero_grimstroke = {
        { name = "grimstroke_dark_artistry",    beh = "point", radius = 200 },
    },
    npc_dota_hero_tusk = {
        { name = "tusk_ice_shards",             beh = "point", radius = 200, dmgKey = "shard_damage", projSpeed = 1200 },
    },
    npc_dota_hero_rattletrap = {
        { name = "rattletrap_rocket_flare",     beh = "point", radius = 600, projSpeed = 2250 },
    },
    npc_dota_hero_void_spirit = {
        { name = "void_spirit_resonant_pulse",  beh = "no_target", radius = 500 },
        { name = "void_spirit_aether_remnant",  beh = "point", radius = 300 },
    },
    npc_dota_hero_pangolier = {
        { name = "pangolier_swashbuckle",       beh = "point", radius = 200, dmgTypeOverride = "physical" },
    },
    npc_dota_hero_magnataur = {
        { name = "magnataur_shockwave",         beh = "point", radius = 200, dmgKey = "shock_damage", projSpeed = 1200 },
    },

    ------------- SF (фиксир. дальность razes) ---------------------------------
    npc_dota_hero_nevermore = {
        { name = "nevermore_shadowraze1", beh = "no_target", radius = 250, fixedRange = 200,  dmgKey = "shadowraze_damage", fixedDmg = {90, 160, 230, 300} },
        { name = "nevermore_shadowraze2", beh = "no_target", radius = 250, fixedRange = 450,  dmgKey = "shadowraze_damage", fixedDmg = {90, 160, 230, 300} },
        { name = "nevermore_shadowraze3", beh = "no_target", radius = 250, fixedRange = 700,  dmgKey = "shadowraze_damage", fixedDmg = {90, 160, 230, 300} },
    },

    ------------- INVOKER (инвокированные заклинания) --------------------------
    npc_dota_hero_invoker = {
        { name = "invoker_cold_snap",           beh = "target", dmgKey = "damage" },
        { name = "invoker_tornado",             beh = "point",  radius = 200, dmgKey = "base_damage" },
        { name = "invoker_chaos_meteor",        beh = "point",  radius = 275, dmgKey = "main_damage" },
        { name = "invoker_deafening_blast",     beh = "point",  radius = 175, dmgKey = "damage" },
        { name = "invoker_sun_strike",          beh = "point",  radius = 175, dmgTypeOverride = "pure", dmgKey = "damage" },
    },
}

local ABILITY_PROFILE_OVERRIDES = {
    kunkka_torrent = {
        delayedAoE = true,
        dmgKey = "torrent_damage",
        impactDelayKey = "delay",
        radius = 250,
    },
    leshrac_split_earth = {
        delayedAoE = true,
        impactDelayKey = "delay",
    },
    lina_light_strike_array = {
        delayedAoE = true,
        dmgKey = "light_strike_array_damage",
        impactDelayKey = "light_strike_array_delay_time",
        radiusKey = "light_strike_array_aoe",
    },
    pugna_nether_blast = {
        delayedAoE = true,
        dmgKey = "blast_damage",
        impactDelayKey = "delay",
        radius = 400,
    },
    monkey_king_boundless_strike = {
        attackScaled = true,
        lineProjectile = true,
        lineRadius = 150,
        lineLength = 1100,
    },
    magnataur_shockwave = {
        lineProjectile = true,
        lineRadius = 200,
        projSpeed = 1200,
    },
    mars_spear = {
        lineProjectile = true,
        lineRadius = 125,
        projSpeed = 1400,
    },
    dragon_knight_breathe_fire = {
        lineProjectile = true,
        lineRadius = 200,
        projSpeed = 1050,
    },
    death_prophet_carrion_swarm = {
        lineProjectile = true,
        lineRadius = 300,
    },
    windrunner_powershot = {
        lineProjectile = true,
        lineRadius = 125,
    },
    shadow_demon_shadow_poison = {
        lineProjectile = true,
        lineRadius = 200,
        projSpeed = 1500,
    },
    puck_illusory_orb = {
        lineProjectile = true,
        lineRadius = 225,
        projSpeed = 550,
    },
    tusk_ice_shards = {
        lineProjectile = true,
        lineRadius = 200,
        projSpeed = 1200,
    },
    winter_wyvern_splinter_blast = {
        excludePrimaryTarget = true,
        allowAoEOnly = true,
        radius = 500,
        projSpeed = 1200,
    },
}

--------------------------------------------------------------------------------
-- SAFE SPECIAL VALUE (pattern from Armlet Abuse V2)
--------------------------------------------------------------------------------
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
    do
        local ok, v = pcall(function() return ability:GetSpecialValue(key) end)
        if ok and v ~= nil then return v end
    end
    return nil
end

local function SVAny(ability, keys, default)
    for _, k in ipairs(keys) do
        local v = SV(ability, k)
        if v and v > 0 then return v end
    end
    return default or 0
end

local function appendUnique(list, seen, value)
    if not value or value == "" or seen[value] then return end
    seen[value] = true
    list[#list + 1] = value
end

local function cloneTableShallow(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            local nested = {}
            for nestedKey, nestedValue in pairs(value) do
                nested[nestedKey] = nestedValue
            end
            copy[key] = nested
        else
            copy[key] = value
        end
    end
    return copy
end

local function mergeAbilityInfo(baseInfo, extraInfo)
    local merged = cloneTableShallow(baseInfo or {})
    if type(extraInfo) ~= "table" then
        merged._damageKeys = nil
        return merged
    end

    for key, value in pairs(extraInfo) do
        if key ~= "_damageKeys" then
            if type(value) == "table" then
                local nested = {}
                for nestedKey, nestedValue in pairs(value) do
                    nested[nestedKey] = nestedValue
                end
                merged[key] = nested
            else
                merged[key] = value
            end
        end
    end

    merged._damageKeys = nil
    return merged
end

local function BitAnd(a, b)
    a = math.floor(tonumber(a) or 0)
    b = math.floor(tonumber(b) or 0)

    if bit32 and bit32.band then
        return bit32.band(a, b)
    end

    if bit and bit.band then
        return bit.band(a, b)
    end

    local out = 0
    local bitValue = 1
    while a > 0 and b > 0 do
        local aa = a % 2
        local bb = b % 2
        if aa == 1 and bb == 1 then
            out = out + bitValue
        end

        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bitValue = bitValue * 2
    end

    return out
end

local function GetAbilityBehaviorFlag(name)
    if ABILITY_BEHAVIOR_CACHE[name] ~= nil then
        return ABILITY_BEHAVIOR_CACHE[name]
    end

    local behavior = Enum and Enum.AbilityBehavior
    if not behavior then
        ABILITY_BEHAVIOR_CACHE[name] = false
        return nil
    end

    local value = behavior[name]
        or behavior["DOTA_ABILITY_BEHAVIOR_" .. name]
        or behavior["ABILITY_BEHAVIOR_" .. name]

    ABILITY_BEHAVIOR_CACHE[name] = value or false
    return value
end

local function getAbilityBehaviorMask(ability)
    if not ability then return 0 end

    if Ability.GetBehavior then
        local ok, value = pcall(Ability.GetBehavior, ability)
        if ok and value then return value end
    end

    local ok, value = pcall(function() return ability:GetBehavior() end)
    return (ok and value) or 0
end

local function HasAbilityBehavior(ability, names)
    local behaviorMask = getAbilityBehaviorMask(ability)
    if not behaviorMask or behaviorMask == 0 then
        return false
    end

    for i = 1, #names do
        local flag = GetAbilityBehaviorFlag(names[i])
        if flag and flag ~= 0 and BitAnd(behaviorMask, flag) ~= 0 then
            return true
        end
    end

    return false
end

local function getAbilityNameFromObject(ability)
    if not ability then return nil end

    local ok, value = pcall(function() return ability:GetName() end)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end

    return nil
end

local function getAbilityEntityIndex(ability)
    if not ability then return nil end

    if Entity.GetIndex then
        local ok, value = pcall(Entity.GetIndex, ability)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return ability:GetIndex() end)
    if ok and value ~= nil then return value end

    return nil
end

local function getAbilityByIndex(hero, index)
    if not hero or index == nil then return nil end

    if NPC.GetAbilityByIndex then
        local ok, ability = pcall(NPC.GetAbilityByIndex, hero, index)
        if ok and ability then return ability end
    end

    local ok, ability = pcall(function() return hero:GetAbilityByIndex(index) end)
    if ok and ability then return ability end

    if NPC.GetAbility then
        local okAlt, altAbility = pcall(NPC.GetAbility, hero, index)
        if okAlt and altAbility then return altAbility end
    end

    local okAlt, altAbility = pcall(function() return hero:GetAbility(index) end)
    if okAlt and altAbility then return altAbility end

    return nil
end

local function getHeroAbilityCount(hero)
    if not hero then return 0 end

    if NPC.GetAbilityCount then
        local ok, value = pcall(NPC.GetAbilityCount, hero)
        if ok and value and value > 0 then return value end
    end

    local ok, value = pcall(function() return hero:GetAbilityCount() end)
    if ok and value and value > 0 then return value end

    return 0
end

local function enumerateHeroAbilities(hero)
    local count = getHeroAbilityCount(hero)
    if count <= 0 then
        return {}
    end

    local list = {}
    local seen = {}

    local function pushAbility(ability)
        if not ability then return end
        local identity = getAbilityEntityIndex(ability) or getAbilityNameFromObject(ability)
        if not identity or seen[identity] then return end
        seen[identity] = true
        list[#list + 1] = ability
    end

    for index = 0, count - 1 do
        pushAbility(getAbilityByIndex(hero, index))
    end

    for index = 1, count do
        pushAbility(getAbilityByIndex(hero, index))
    end

    return list
end

--------------------------------------------------------------------------------
-- DAMAGE CALCULATION
--------------------------------------------------------------------------------

local NUKE_DMG_KEYS = {
    "damage", "base_damage", "damage_min", "damage_max",
    "initial_damage", "impact_damage", "damage_impact",
    "blast_damage", "bolt_damage", "wave_damage", "ability_damage",
    "spell_damage", "hit_damage", "bonus_damage", "nova_damage",
    "projectile_damage", "explode_damage", "explosion_damage",
    "contact_damage", "spark_damage", "target_damage",
    "arc_damage", "beam_damage", "snake_damage", "lance_damage",
    "quill_base_damage", "static_remnant_damage",
    "tooltip_damage", "main_damage",
    "shock_damage", "light_strike_array_damage",
    -- hero-specific
    "laser_damage", "fade_bolt_damage", "fireblast_damage",
    "brain_sap_damage", "dragon_slave_damage",
    "scream_damage", "strike_damage", "gale_damage",
    "fissure_damage", "impale_damage", "burrowstrike_damage",
    "powershot_damage", "orb_damage", "waning_rift_damage",
    "nether_blast_damage", "carrion_swarm_damage",
    "acorn_shot_damage", "dead_shot_damage",
    "cask_damage", "tar_bomb_damage",
    "total_damage", "AbilityDamage",
    -- extended
    "shadowraze_damage", "raze_damage",
    "double_edge_damage", "rocket_flare_damage",
    "rebuke_damage", "spear_damage",
    "shuriken_toss_damage", "dagger_damage",
    "death_coil_damage", "decay_damage",
    "purifying_flames_damage", "sticky_bomb_damage",
    "resonant_pulse_damage", "dark_artistry_damage",
    "ice_shards_damage",
    -- batch 2
    "lucent_beam_damage", "storm_bolt_damage",
    "magic_missile_damage", "wave_of_terror_damage",
    "chaos_bolt_damage", "hellfire_blast_damage",
    "spirit_lance_damage", "mystic_snake_damage",
    "thunder_strike_damage", "flux_damage",
    "spark_wraith_damage", "soul_assumption_damage",
    "soul_base_damage", "rock_damage",
    "splinter_blast_damage", "cold_feet_damage",
    "poison_touch_damage", "purification_damage",
    "void_damage", "anchor_smash_damage",
    "slithereen_crush_damage", "starfall_damage",
    "death_pulse_damage", "dark_pact_damage",
    "inner_fire_damage", "earthshock_damage",
    "plasma_field_damage", "breathe_fire_damage",
    "split_earth_damage", "lightning_storm_damage",
    "waveform_damage", "adaptive_strike_damage",
    "torrent_damage", "shrapnel_damage",
    "shadow_poison_damage", "overwhelming_odds_damage",
    "swashbuckle_damage", "rocket_barrage_damage",
    "sticky_napalm_damage", "trample_damage",
    "cold_snap_damage", "tornado_damage",
    "meteor_damage", "deafening_blast_damage",
    "sun_strike_damage",
}

local function getAbilityDamageKeyCandidates(info)
    if not info then
        return NUKE_DMG_KEYS
    end

    if info._damageKeys then
        return info._damageKeys
    end

    local keys = {}
    local seen = {}

    appendUnique(keys, seen, info.dmgKey)
    appendUnique(keys, seen, info.attackPctKey)
    appendUnique(keys, seen, info.critPctKey)
    appendUnique(keys, seen, info.flatDamageKey)
    for _, key in ipairs(NUKE_DMG_KEYS) do
        appendUnique(keys, seen, key)
    end

    if info.name then
        local parts = {}
        for part in string.gmatch(info.name, "[^_]+") do
            parts[#parts + 1] = part
        end

        local count = #parts
        if count >= 1 then
            local tail = parts[count]
            appendUnique(keys, seen, tail .. "_damage")
            appendUnique(keys, seen, "base_" .. tail .. "_damage")
            appendUnique(keys, seen, tail .. "_base_damage")
        end

        if count >= 2 then
            appendUnique(keys, seen, parts[count - 1] .. "_" .. parts[count] .. "_damage")
        end

        if count >= 3 then
            appendUnique(keys, seen, parts[count - 2] .. "_" .. parts[count - 1] .. "_" .. parts[count] .. "_damage")
        end
    end

    info._damageKeys = keys
    return keys
end

--- Полный spell amp героя (проценты → множитель)
local function getSpellAmp(hero)
    if NPC.GetSpellAmplification then
        local ok, v = pcall(NPC.GetSpellAmplification, hero)
        if ok and v and v ~= 0 then
            if v > 1 then v = v / 100 end
            return v
        end
    end
    if NPC.GetBaseSpellAmp then
        local ok, v = pcall(NPC.GetBaseSpellAmp, hero)
        if ok and v and v ~= 0 then
            if v > 1 then v = v / 100 end
            return v
        end
    end
    do
        local ok, v = pcall(function() return hero:GetSpellAmplification() end)
        if ok and v and v ~= 0 then
            if v > 1 then v = v / 100 end
            return v
        end
    end
    return 0
end

--- Базовый урон способности + spell amp
local function getAttackScaledAbilityDamage(hero, ability, info)
    if not info then return 0 end

    local attackDamage = 0
    if NPC.GetTotalDamage then
        local ok, value = pcall(NPC.GetTotalDamage, hero)
        if ok and value and value > 0 then attackDamage = value end
    end
    if attackDamage == 0 then
        local ok, value = pcall(function() return hero:GetTotalDamage() end)
        if ok and value and value > 0 then attackDamage = value end
    end
    if attackDamage == 0 and NPC.GetMinDamage then
        local ok, value = pcall(NPC.GetMinDamage, hero)
        if ok and value and value > 0 then attackDamage = value end
    end
    if attackDamage <= 0 then return 0 end

    local dmg = 0

    if info.attackPctKey then
        local pct = SV(ability, info.attackPctKey) or 0
        if pct ~= 0 then
            dmg = dmg + attackDamage * (pct / 100)
        end
    end

    if info.critPctKey then
        local pct = SV(ability, info.critPctKey) or 0
        if pct ~= 0 then
            dmg = dmg + attackDamage * (pct / 100)
        end
    end

    if info.flatDamageKey then
        dmg = dmg + (SV(ability, info.flatDamageKey) or 0)
    end

    if info.flatDamage then
        dmg = dmg + info.flatDamage
    end

    return math.max(0, dmg)
end

local function getAbilityDamage(hero, ability, info)
    local dmg = 0

    -- 1) GetAbilityDamage (static + OOP)
    if Ability.GetAbilityDamage then
        local ok, v = pcall(Ability.GetAbilityDamage, ability)
        if ok and v and v > 0 then dmg = v end
    end
    if dmg == 0 then
        local ok, v = pcall(function() return ability:GetAbilityDamage() end)
        if ok and v and v > 0 then dmg = v end
    end

    -- 2) Явный dmgKey → SV
    if dmg == 0 and info.dmgKey then
        dmg = SV(ability, info.dmgKey) or 0
    end

    -- 3) Перебор типичных ключей
    if dmg == 0 then
        dmg = SVAny(ability, getAbilityDamageKeyCandidates(info), 0)
    end
    local attackScaledDamage = getAttackScaledAbilityDamage(hero, ability, info)
    if attackScaledDamage > 0 then
        dmg = dmg + attackScaledDamage
    end

    -- 4) Hardcoded fallback (fixedDmg по уровням)
    if dmg == 0 and info.fixedDmg then
        local lvl = 1
        if Ability.GetLevel then
            local okLvl, value = pcall(Ability.GetLevel, ability)
            if okLvl and value and value > 0 then lvl = value end
        end
        dmg = info.fixedDmg[lvl] or info.fixedDmg[#info.fixedDmg] or 0
    end

    if dmg == 0 then return 0 end

    -- Spell amplification
    if not (info and info.noSpellAmp) then
        local spellAmp = getSpellAmp(hero)
        dmg = dmg * (1 + spellAmp)
    end

    return dmg
end

--- Сопротивления цели по типу урона
local function applyResistance(dmg, ability, info, target)
    local damageType = info.dmgTypeOverride

    if not damageType then
        local dt = 0
        if Ability.GetDamageType then
            local ok, v = pcall(Ability.GetDamageType, ability)
            if ok and v then dt = v end
        end
        if dt == 0 then
            local ok, v = pcall(function() return ability:GetDamageType() end)
            if ok and v then dt = v end
        end

        if Enum.DamageTypes then
            if dt == Enum.DamageTypes.PHYSICAL then
                damageType = "physical"
            elseif dt == Enum.DamageTypes.PURE then
                damageType = "pure"
            else
                damageType = "magical"
            end
        elseif Enum.DamageType then
            if dt == Enum.DamageType.PHYSICAL then
                damageType = "physical"
            elseif dt == Enum.DamageType.PURE then
                damageType = "pure"
            else
                damageType = "magical"
            end
        else
            damageType = "magical"
        end
    end

    if damageType == "magical" then
        local mult = (NPC.GetMagicalArmorDamageMultiplier and NPC.GetMagicalArmorDamageMultiplier(target)) or 1
        return dmg * mult
    elseif damageType == "physical" then
        local mult = (NPC.GetArmorDamageMultiplier and NPC.GetArmorDamageMultiplier(target)) or 1
        return dmg * mult
    end

    return dmg  -- pure
end

local function getAbilityCastPoint(ability, info)
    local castPoint = 0

    if Ability.GetCastPoint then
        local ok, value = pcall(Ability.GetCastPoint, ability)
        if ok and value and value > 0 then castPoint = value end
    end

    if castPoint == 0 then
        local ok, value = pcall(function() return ability:GetCastPoint() end)
        if ok and value and value > 0 then castPoint = value end
    end

    if castPoint == 0 and info and info.castPoint and info.castPoint > 0 then
        castPoint = info.castPoint
    end

    if castPoint == 0 then
        castPoint = 0.25
    end

    return castPoint
end

local function getAbilityCooldownLength(ability)
    if Ability.GetCooldownLength then
        local ok, value = pcall(Ability.GetCooldownLength, ability)
        if ok and value and value > 0 then return value end
    end

    local ok, value = pcall(function() return ability:GetCooldownLength() end)
    if ok and value and value > 0 then return value end

    return 0
end

local function isAbilityInPhase(ability)
    if Ability.IsInAbilityPhase then
        local ok, value = pcall(Ability.IsInAbilityPhase, ability)
        if ok and value then return true end
    end

    local ok, value = pcall(function() return ability:IsInAbilityPhase() end)
    return ok and value or false
end

local function getAbilityHealthCost(ability)
    if Ability.GetHealthCost then
        local ok, value = pcall(Ability.GetHealthCost, ability)
        if ok and value and value > 0 then return value end
    end

    local ok, value = pcall(function() return ability:GetHealthCost() end)
    if ok and value and value > 0 then return value end

    return 0
end

local function getAbilitySelfDamage(ability, info)
    local selfDamage = getAbilityHealthCost(ability)

    if info and info.selfDamageKeys then
        for _, key in ipairs(info.selfDamageKeys) do
            local value = SV(ability, key)
            if value and value > selfDamage then
                selfDamage = value
            end
        end
    end

    if info and info.selfDamageFlat and info.selfDamageFlat > selfDamage then
        selfDamage = info.selfDamageFlat
    end

    return selfDamage
end

local function canAffordAbilityCast(hero, ability, info)
    local selfDamage = getAbilitySelfDamage(ability, info)
    if selfDamage <= 0 then
        return true
    end

    local hp = Entity.GetHealth(hero) or 0
    local buffer = (info and info.selfHpBuffer) or 1
    return hp > selfDamage + buffer
end

local COMMON_RADIUS_KEYS = {
    "radius",
    "aoe",
    "area_of_effect",
    "split_radius",
    "light_strike_array_aoe",
    "shock_width",
    "width",
    "start_radius",
    "end_radius",
}

local COMMON_LINE_WIDTH_KEYS = {
    "shock_width",
    "width",
    "start_radius",
    "end_radius",
    "radius",
}

local COMMON_DELAY_KEYS = {
    "delay",
    "impact_delay",
    "explode_delay",
    "blast_delay",
    "light_strike_array_delay_time",
}

local COMMON_PROJECTILE_SPEED_KEYS = {
    "projectile_speed",
    "proj_speed",
    "shock_speed",
    "wave_speed",
    "orb_speed",
    "bolt_speed",
    "arrow_speed",
    "travel_speed",
    "velocity",
}

local getAbilityProjectileSpeedValue

local function getAbilityCastRangeValue(ability)
    if not ability then return 0 end

    if Ability.GetEffectiveCastRange then
        local ok, value = pcall(Ability.GetEffectiveCastRange, ability)
        if ok and value and value > 0 then return value end
    end

    local okEffective, effective = pcall(function() return ability:GetEffectiveCastRange() end)
    if okEffective and effective and effective > 0 then return effective end

    if Ability.GetCastRange then
        local ok, value = pcall(Ability.GetCastRange, ability)
        if ok and value and value > 0 then return value end
    end

    local okRange, castRange = pcall(function() return ability:GetCastRange() end)
    if okRange and castRange and castRange > 0 then return castRange end

    return 0
end

local function getAbilityAOERadiusValue(ability, info)
    local radius = (info and info.radius) or 0
    if radius and radius > 0 then
        return radius
    end

    if ability then
        if Ability.GetAOERadius then
            local ok, value = pcall(Ability.GetAOERadius, ability)
            if ok and value and value > 0 then radius = value end
        end

        if (not radius or radius <= 0) then
            local ok, value = pcall(function() return ability:GetAOERadius() end)
            if ok and value and value > 0 then radius = value end
        end

        if (not radius or radius <= 0) and info and info.radiusKey then
            radius = SV(ability, info.radiusKey) or 0
        end

        if not radius or radius <= 0 then
            radius = SVAny(ability, COMMON_RADIUS_KEYS, 0)
        end
    end

    return radius or 0
end

local function getAbilityLineRadiusValue(ability, info)
    local radius = (info and info.lineRadius) or 0
    if radius and radius > 0 then
        return radius
    end

    if ability then
        radius = SVAny(ability, COMMON_LINE_WIDTH_KEYS, 0)
    end

    if not radius or radius <= 0 then
        radius = getAbilityAOERadiusValue(ability, info)
    end

    if not radius or radius <= 0 then
        radius = 150
    end

    return radius
end

local function getAbilityImpactDelay(ability, info)
    if info and info.impactDelay and info.impactDelay > 0 then
        return info.impactDelay
    end

    if not ability then
        return 0
    end

    if info and info.impactDelayKey then
        local value = SV(ability, info.impactDelayKey)
        if value and value > 0 then
            return value
        end
    end

    if info and info.impactDelayKeys then
        for _, key in ipairs(info.impactDelayKeys) do
            local value = SV(ability, key)
            if value and value > 0 then
                return value
            end
        end
    end

    local autoProbeDelay = info and info.delayedAoE
    if not autoProbeDelay and info and info.beh == "point" then
        autoProbeDelay = getAbilityAOERadiusValue(ability, info) > 0 and getAbilityProjectileSpeedValue(ability, info) <= 0
    end

    if autoProbeDelay then
        return SVAny(ability, COMMON_DELAY_KEYS, 0)
    end

    return 0
end

getAbilityProjectileSpeedValue = function(ability, info)
    local speed = (info and info.projSpeed) or 0
    if speed and speed > 0 then
        return speed
    end

    if not ability then
        return 0
    end

    if info and info.projSpeedKey then
        speed = SV(ability, info.projSpeedKey) or 0
    end

    if not speed or speed <= 0 then
        speed = SVAny(ability, COMMON_PROJECTILE_SPEED_KEYS, 0)
    end

    return speed or 0
end

local function findPositiveSpecialValueKey(ability, keys)
    if not ability or not keys then
        return nil, 0
    end

    for _, key in ipairs(keys) do
        local value = SV(ability, key)
        if value and value > 0 then
            return key, value
        end
    end

    return nil, 0
end

local function isAbilityPassiveState(ability)
    if Ability.IsPassive then
        local ok, value = pcall(Ability.IsPassive, ability)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return ability:IsPassive() end)
    return ok and value or false
end

local function isAbilityHiddenState(ability)
    if Ability.IsHidden then
        local ok, value = pcall(Ability.IsHidden, ability)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return ability:IsHidden() end)
    return ok and value or false
end

local function isAbilityToggleState(ability)
    if Ability.IsToggle then
        local ok, value = pcall(Ability.IsToggle, ability)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return ability:IsToggle() end)
    return ok and value or false
end

local function isAbilityChannelState(ability)
    if Ability.IsChannelling then
        local ok, value = pcall(Ability.IsChannelling, ability)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return ability:IsChannelling() end)
    return ok and value or false
end

local function isAbilityUltimateState(ability)
    if Ability.IsUltimate then
        local ok, value = pcall(Ability.IsUltimate, ability)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return ability:IsUltimate() end)
    return ok and value or false
end

local function getAbilityTargetTeamValue(ability)
    if not ability then return 0 end

    if Ability.GetTargetTeam then
        local ok, value = pcall(Ability.GetTargetTeam, ability)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return ability:GetTargetTeam() end)
    return (ok and value) or 0
end

local function getAbilityTargetTypeValue(ability)
    if not ability then return 0 end

    if Ability.GetTargetType then
        local ok, value = pcall(Ability.GetTargetType, ability)
        if ok and value ~= nil then return value end
    end

    local ok, value = pcall(function() return ability:GetTargetType() end)
    return (ok and value) or 0
end

local function hasTargetType(mask, names)
    if not mask or mask == 0 or not names or not Enum or not Enum.TargetType then
        return mask == 0
    end

    for _, name in ipairs(names) do
        local value = Enum.TargetType[name]
        if value and (mask == value or BitAnd(mask, value) ~= 0) then
            return true
        end
    end

    return false
end

local function isEnemyTargetTeam(team)
    if not Enum or not Enum.TargetTeam or team == nil then
        return true
    end

    return team == 0
        or team == Enum.TargetTeam.ENEMY
        or team == Enum.TargetTeam.BOTH
end

local function resolveAbilityBehaviorKind(ability)
    if HasAbilityBehavior(ability, { "UNIT_TARGET", "OPTIONAL_UNIT_TARGET" }) then
        return "target"
    end

    if HasAbilityBehavior(ability, { "POINT", "OPTIONAL_POINT" }) then
        return "point"
    end

    if HasAbilityBehavior(ability, { "NO_TARGET" }) then
        return "no_target"
    end

    local targetType = getAbilityTargetTypeValue(ability)
    if targetType ~= 0 then
        return "target"
    end

    local castRange = getAbilityCastRangeValue(ability)
    local aoeRadius = getAbilityAOERadiusValue(ability, nil)
    if castRange > 0 or aoeRadius > 0 then
        return "point"
    end

    return nil
end

local function getAbilityChargeState(ability)
    if not ability then
        return { current = 0, max = 0, restore = 0, hasCharges = false }
    end

    local current = 0
    if Ability.GetCurrentCharges then
        local ok, value = pcall(Ability.GetCurrentCharges, ability)
        if ok and value and value > 0 then current = value end
    end
    if current <= 0 then
        local ok, value = pcall(function() return ability:GetCurrentCharges() end)
        if ok and value and value > 0 then current = value end
    end

    local max = 0
    if Ability.GetMaxCharges then
        local ok, value = pcall(Ability.GetMaxCharges, ability)
        if ok and value and value > 0 then max = value end
    end
    if max <= 0 then
        local ok, value = pcall(function() return ability:GetMaxCharges() end)
        if ok and value and value > 0 then max = value end
    end

    local restore = 0
    if Ability.GetChargeRestoreTime then
        local ok, value = pcall(Ability.GetChargeRestoreTime, ability)
        if ok and value and value > 0 then restore = value end
    end
    if restore <= 0 then
        local ok, value = pcall(function() return ability:GetChargeRestoreTime() end)
        if ok and value and value > 0 then restore = value end
    end

    return {
        current = current,
        max = max,
        restore = restore,
        hasCharges = max > 0,
    }
end

local function buildHeroAbilitySignature(hero)
    local heroName = NPC.GetUnitName(hero) or "?"
    local parts = { heroName }

    for _, ability in ipairs(enumerateHeroAbilities(hero)) do
        local name = getAbilityNameFromObject(ability)
        if name and name ~= "" then
            local level = 0
            if Ability.GetLevel then
                local ok, value = pcall(Ability.GetLevel, ability)
                if ok and value and value > 0 then
                    level = value
                end
            end
            parts[#parts + 1] = name .. ":" .. tostring(level or 0)
        end
    end

    return table.concat(parts, "|")
end

local function enrichAbilityInfoFromAbility(ability, info)
    local merged = mergeAbilityInfo(info, ABILITY_PROFILE_OVERRIDES[info and info.name or ""])
    if not ability then
        return merged
    end

    if not merged.beh then
        merged.beh = resolveAbilityBehaviorKind(ability)
    end

    if not merged.radius or merged.radius <= 0 then
        merged.radius = getAbilityAOERadiusValue(ability, merged)
    end

    if merged.lineProjectile and (not merged.lineRadius or merged.lineRadius <= 0) then
        merged.lineRadius = getAbilityLineRadiusValue(ability, merged)
    end

    if not merged.projSpeed or merged.projSpeed <= 0 then
        merged.projSpeed = getAbilityProjectileSpeedValue(ability, merged)
    end

    if not merged.impactDelay or merged.impactDelay <= 0 then
        merged.impactDelay = getAbilityImpactDelay(ability, merged)
    end

    if merged.impactDelay and merged.impactDelay > 0 then
        merged.delayedAoE = true
    end

    if not merged.dmgKey
        and not merged.attackPctKey
        and not merged.critPctKey
        and not merged.flatDamageKey then
        local damageKey = findPositiveSpecialValueKey(ability, getAbilityDamageKeyCandidates(merged))
        if damageKey then
            merged.dmgKey = damageKey
        end
    end

    local chargeState = getAbilityChargeState(ability)
    if chargeState.hasCharges then
        merged.chargeBased = true
    end

    return merged
end

local function inferFallbackAbilityInfo(hero, ability)
    if not hero or not ability then return nil end

    local abilityName = getAbilityNameFromObject(ability)
    if not abilityName or abilityName == "" then return nil end

    if isAbilityPassiveState(ability)
        or isAbilityHiddenState(ability)
        or isAbilityToggleState(ability)
        or isAbilityChannelState(ability)
        or isAbilityUltimateState(ability) then
        return nil
    end

    if HasAbilityBehavior(ability, {
        "PASSIVE",
        "TOGGLE",
        "CHANNELLED",
        "AUTOCAST",
        "ATTACK",
        "VECTOR_TARGETING",
        "DIRECTIONAL",
        "ROOT_DISABLES",
    }) then
        return nil
    end

    local beh = resolveAbilityBehaviorKind(ability)
    if beh ~= "target" and beh ~= "point" then
        return nil
    end

    local targetTeam = getAbilityTargetTeamValue(ability)
    if not isEnemyTargetTeam(targetTeam) then
        return nil
    end

    local targetType = getAbilityTargetTypeValue(ability)
    if beh == "target" and targetType ~= 0 and not hasTargetType(targetType, { "BASIC", "CREEP", "ALL" }) then
        return nil
    end

    local info = enrichAbilityInfoFromAbility(ability, {
        name = abilityName,
        beh = beh,
        autoDetected = true,
    })

    local damage = getAbilityDamage(hero, ability, info)
    if damage <= 0 then
        return nil
    end

    return info
end

local function getResolvedHeroAbilityInfos(hero)
    local heroName = NPC.GetUnitName(hero)
    if not heroName or heroName == "" then
        return {}, nil, false
    end

    local signature = buildHeroAbilitySignature(hero)
    local cached = resolvedAbilityInfoCache[signature]
    if cached then
        return cached.abilities, signature, cached.usedFallback
    end

    local resolved = {}
    local seenNames = {}
    local usedFallback = false
    local manualInfos = HERO_ABILITIES[heroName] or {}

    for _, rawInfo in ipairs(manualInfos) do
        local ability = getAbilityByName(hero, rawInfo.name)
        local info = enrichAbilityInfoFromAbility(ability, rawInfo)
        resolved[#resolved + 1] = info
        seenNames[info.name] = true
    end

    for _, ability in ipairs(enumerateHeroAbilities(hero)) do
        local abilityName = getAbilityNameFromObject(ability)
        if abilityName and not seenNames[abilityName] then
            local info = inferFallbackAbilityInfo(hero, ability)
            if info then
                resolved[#resolved + 1] = info
                seenNames[info.name] = true
                usedFallback = true
            end
        end
    end

    resolvedAbilityInfoCache[signature] = {
        abilities = resolved,
        usedFallback = usedFallback or (#manualInfos == 0 and #resolved > 0),
    }

    return resolved, signature, resolvedAbilityInfoCache[signature].usedFallback
end

--------------------------------------------------------------------------------
-- HP PREDICTION — предсказание HP крипа через DPS-трекер
--------------------------------------------------------------------------------

--- Обновить HP-трекер, вернуть предсказанный HP через deltaTime секунд
local function predictCreepHP(creep, deltaTime)
    local idx = Entity.GetIndex(creep)
    local hp  = Entity.GetHealth(creep) or 0
    local now = GameRules.GetGameTime()

    local entry = creepHPTracker[idx]
    if entry then
        local dt = now - entry.time
        if dt >= 0.1 then
            local currentDPS = (entry.hp - hp) / dt
            if currentDPS < 0 then currentDPS = 0 end
            local smoothDPS = entry.dps * 0.4 + currentDPS * 0.6
            creepHPTracker[idx] = { hp = hp, time = now, dps = smoothDPS }
            return math.max(0, hp - smoothDPS * deltaTime), smoothDPS
        else
            return math.max(0, hp - (entry.dps or 0) * deltaTime), entry.dps or 0
        end
    end

    creepHPTracker[idx] = { hp = hp, time = now, dps = 0 }
    return hp, 0
end

--- Очистка мёртвых крипов
local function cleanupTracker(now)
    if now - lastTrackerCleanup < TRACKER_CLEANUP_INTERVAL then return end
    lastTrackerCleanup = now
    for idx, entry in pairs(creepHPTracker) do
        if now - entry.time > 3.0 then
            creepHPTracker[idx] = nil
        end
    end
end

--- Задержка до попадания (cast point + время полёта)
local function getHitDelay(hero, ability, creep, info)
    local delay = getAbilityCastPoint(ability, info)

    local projSpeed = getAbilityProjectileSpeedValue(ability, info)
    if projSpeed > 0 then
        local heroPos  = Entity.GetAbsOrigin(hero)
        local creepPos = Entity.GetAbsOrigin(creep)
        local dist     = (heroPos - creepPos):Length2D()
        delay = delay + dist / projSpeed
    end

    delay = delay + getAbilityImpactDelay(ability, info)

    return delay
end

local function getTargetLockDuration(hero, ability, creep, info)
    local lockDuration = TARGET_COOLDOWN_MIN
    local hitDelay = getHitDelay(hero, ability, creep, info)

    if hitDelay > 0 then
        lockDuration = math.max(lockDuration, hitDelay + 0.05)
    end

    local cooldownLength = getAbilityCooldownLength(ability)
    if cooldownLength > 0 then
        lockDuration = math.max(lockDuration, math.min(cooldownLength * 0.35, TARGET_COOLDOWN_MAX))
    end

    if info and info.targetCooldown and info.targetCooldown > 0 then
        lockDuration = math.max(lockDuration, info.targetCooldown)
    end

    return math.min(lockDuration, TARGET_COOLDOWN_MAX)
end

--------------------------------------------------------------------------------
-- AoE SCORING — считаем, сколько крипов убьёт AoE
--------------------------------------------------------------------------------

local function getLineCastEndPosition(hero, ability, info, targetCreep)
    local heroPos = Entity.GetAbsOrigin(hero)
    local targetPos = Entity.GetAbsOrigin(targetCreep)
    local direction = targetPos - heroPos
    local directionLength = direction:Length2D()
    if directionLength <= 0 then
        return targetPos
    end

    local lineLength = (info and info.lineLength) or getAbilityCastRangeValue(ability)
    if lineLength <= 0 then
        lineLength = directionLength
    else
        lineLength = math.max(lineLength, directionLength)
    end

    return heroPos + direction * (lineLength / directionLength)
end

local function pointSegmentDistance2D(point, startPos, endPos)
    local segment = endPos - startPos
    local segmentX = segment.x or 0
    local segmentY = segment.y or 0
    local segmentLenSq = segmentX * segmentX + segmentY * segmentY
    if segmentLenSq <= 0 then
        return (point - startPos):Length2D()
    end

    local pointDir = point - startPos
    local pointX = pointDir.x or 0
    local pointY = pointDir.y or 0
    local t = (pointX * segmentX + pointY * segmentY) / segmentLenSq
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end

    local closest = startPos + segment * t
    return (point - closest):Length2D()
end

local function getCreepHpForAoECheck(hero, ability, info, creep, usePrediction)
    local hp = Entity.GetHealth(creep) or 0
    if not usePrediction then
        return hp
    end

    return predictCreepHP(creep, getHitDelay(hero, ability, creep, info))
end

local function scoreLineProjectileKills(hero, ability, info, targetCreep, creeps, baseDmg, buffer, usePrediction)
    local startPos = Entity.GetAbsOrigin(hero)
    local endPos = getLineCastEndPosition(hero, ability, info, targetCreep)
    local lineRadius = getAbilityLineRadiusValue(ability, info)
    local kills = 0

    for _, creep in ipairs(creeps) do
        if Entity.IsAlive(creep) and not NPC.IsHero(creep) then
            if info.excludePrimaryTarget and creep == targetCreep then
                -- skip primary target
            else
                local creepPos = Entity.GetAbsOrigin(creep)
                local hull = (NPC.GetHullRadius and NPC.GetHullRadius(creep)) or 0
                local distanceToLine = pointSegmentDistance2D(creepPos, startPos, endPos)
                if distanceToLine <= lineRadius + hull then
                    local damage = applyResistance(baseDmg, ability, info, creep)
                    local hp = getCreepHpForAoECheck(hero, ability, info, creep, usePrediction)
                    if hp > 0 and hp <= damage + buffer then
                        kills = kills + 1
                    end
                end
            end
        end
    end

    return kills
end

local function scoreAoEKills(hero, ability, info, targetCreep, creeps, baseDmg, buffer, usePrediction)
    if info.beh == "target" and not info.radius and not info.lineProjectile then return 1 end
    if info.lineProjectile then
        return scoreLineProjectileKills(hero, ability, info, targetCreep, creeps, baseDmg, buffer, usePrediction)
    end

    local aoeRadius = info.radius or 350
    local center

    if info.fixedRange then
        local heroPos  = Entity.GetAbsOrigin(hero)
        local creepPos = Entity.GetAbsOrigin(targetCreep)
        local dir      = (creepPos - heroPos)
        local len      = dir:Length2D()
        if len > 0 then dir = dir * (info.fixedRange / len) end
        center = heroPos + dir
    elseif info.beh == "no_target" then
        center = Entity.GetAbsOrigin(hero)
    else
        center = Entity.GetAbsOrigin(targetCreep)
    end

    local kills = 0
    for _, creep in ipairs(creeps) do
        if Entity.IsAlive(creep) and not NPC.IsHero(creep) then
            local pos  = Entity.GetAbsOrigin(creep)
            local dist = (pos - center):Length2D()
            if info.excludePrimaryTarget and creep == targetCreep then
                -- skip primary target
            elseif dist <= aoeRadius then
                local eDmg = applyResistance(baseDmg, ability, info, creep)
                local hp   = getCreepHpForAoECheck(hero, ability, info, creep, usePrediction)
                if hp > 0 and hp <= eDmg + buffer then
                    kills = kills + 1
                end
            end
        end
    end

    return kills
end

local function evaluateCastOpportunity(hero, ability, info, creep, creeps, buffer, usePrediction, useAoE, baseDmg)
    local damage = baseDmg or getAbilityDamage(hero, ability, info)
    if damage <= 0 then
        return nil
    end

    local effectiveDmg = applyResistance(damage, ability, info, creep)
    local hp = Entity.GetHealth(creep) or 0
    local hitDelay = getHitDelay(hero, ability, creep, info)
    local predictedHP = hp

    if usePrediction then
        predictedHP = predictCreepHP(creep, hitDelay)
    end

    local killAtImpact = predictedHP > 0 and predictedHP <= effectiveDmg + buffer
    local allowImmediateKill = hitDelay <= 0.05
    if not usePrediction and hitDelay <= 0.12 and not (info.delayedAoE or getAbilityImpactDelay(ability, info) > 0.05) then
        allowImmediateKill = true
    end
    local killNow = allowImmediateKill and hp > 0 and hp <= effectiveDmg + buffer

    local aoeKills = 0
    if useAoE and (info.radius or info.lineProjectile) then
        aoeKills = scoreAoEKills(hero, ability, info, creep, creeps, damage, buffer, usePrediction)
    end

    local primaryKills = ((killAtImpact or killNow) and not info.excludePrimaryTarget) and 1 or 0
    local extraAoEKills = math.max(0, aoeKills - primaryKills)
    local chargeState = getAbilityChargeState(ability)
    local reserveLastCharge = chargeState.hasCharges
        and chargeState.max > 1
        and chargeState.current > 0
        and chargeState.current <= 1
        and chargeState.restore > 1.0

    return {
        baseDmg = damage,
        effectiveDmg = effectiveDmg,
        hp = hp,
        predictedHP = predictedHP,
        hitDelay = hitDelay,
        killAtImpact = killAtImpact,
        killNow = killNow,
        extraAoEKills = extraAoEKills,
        chargeState = chargeState,
        reserveLastCharge = reserveLastCharge,
        canAoEKill = (info and info.allowAoEOnly and extraAoEKills > 0 and not reserveLastCharge) and true or false,
    }
end

--------------------------------------------------------------------------------
-- ANTI-CONFLICT HELPERS
--------------------------------------------------------------------------------

local function getAttackRange(hero)
    if NPC.GetAttackRange then
        local ok, v = pcall(NPC.GetAttackRange, hero)
        if ok and v then return v end
    end
    do
        local ok, v = pcall(function() return hero:GetAttackRange() end)
        if ok and v then return v end
    end
    return 150
end

local function getAttackDamage(hero)
    if NPC.GetTotalDamage then
        local ok, v = pcall(NPC.GetTotalDamage, hero)
        if ok and v and v > 0 then return v end
    end
    do
        local ok, v = pcall(function() return hero:GetTotalDamage() end)
        if ok and v and v > 0 then return v end
    end
    if NPC.GetMinDamage then
        local ok, v = pcall(NPC.GetMinDamage, hero)
        if ok and v and v > 0 then return v end
    end
    return 50
end

local function isHeroAttacking(hero)
    if NPC.IsAttacking then
        local ok, v = pcall(NPC.IsAttacking, hero)
        if ok and v then return true end
    end
    do
        local ok, v = pcall(function() return hero:IsAttacking() end)
        if ok and v then return true end
    end
    if NPC.GetActivity then
        local ok, act = pcall(NPC.GetActivity, hero)
        if ok and act and Enum.GameActivity then
            if act == Enum.GameActivity.ACT_DOTA_ATTACK
                or act == Enum.GameActivity.ACT_DOTA_ATTACK2 then
                return true
            end
        end
    end
    return false
end

local function canAutoAttackKill(hero, creep, buffer)
    local heroPos   = Entity.GetAbsOrigin(hero)
    local creepPos  = Entity.GetAbsOrigin(creep)
    local dist      = (heroPos - creepPos):Length2D()
    local aaRange   = getAttackRange(hero)
    local heroHull  = (NPC.GetHullRadius and NPC.GetHullRadius(hero)) or 0
    local creepHull = (NPC.GetHullRadius and NPC.GetHullRadius(creep)) or 0

    if dist > aaRange + heroHull + creepHull + 50 then return false end

    local aaDmg = getAttackDamage(hero)
    local armorMult = (NPC.GetArmorDamageMultiplier and NPC.GetArmorDamageMultiplier(creep)) or 1
    aaDmg = aaDmg * armorMult

    local hp = Entity.GetHealth(creep) or 0
    return hp > 0 and hp <= aaDmg + buffer
end

--------------------------------------------------------------------------------
-- TARGETING HELPERS
--------------------------------------------------------------------------------

local function isCreepInRange(hero, ability, creep, info)
    local heroPos  = Entity.GetAbsOrigin(hero)
    local creepPos = Entity.GetAbsOrigin(creep)
    local dist     = (heroPos - creepPos):Length2D()

    -- SF razes: кольцо fixedRange ± radius
    if info.fixedRange then
        local r = info.radius or 250
        return math.abs(dist - info.fixedRange) <= r
    end

    -- NO_TARGET: AoE
    if info.beh == "no_target" then
        local r = getAbilityAOERadiusValue(ability, info)
        if r <= 0 then r = 350 end
        return dist <= r
    end

    -- TARGET / POINT
    local castRange = getAbilityCastRangeValue(ability)
    if castRange <= 0 then castRange = 600 end

    local heroHull  = (NPC.GetHullRadius and NPC.GetHullRadius(hero)) or 0
    local creepHull = (NPC.GetHullRadius and NPC.GetHullRadius(creep)) or 0

    return dist <= castRange + heroHull + creepHull
end

--- Повернуть героя в сторону крипа (MOVE_TO_DIRECTION + cast)
local function faceCreep(hero, creepPos)
    local ok, err = pcall(function()
        local player = Players.GetLocal()
        if not player then return end
        Player.PrepareUnitOrders(
            player,
            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_DIRECTION,
            nil,
            creepPos,
            nil,
            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_HERO_ONLY,
            hero,
            false, false, false, false,
            "ability_lasthit"
        )
    end)
    if not ok then
        dbg("faceCreep error: " .. tostring(err))
    end
end

--- Каст способности
local function castOnCreep(hero, ability, creep, info)
    local creepPos = Entity.GetAbsOrigin(creep)

    if info.beh == "target" then
        Ability.CastTarget(ability, creep, false, false, false, "ability_lasthit")
    elseif info.beh == "point" then
        faceCreep(hero, creepPos)
        Ability.CastPosition(ability, creepPos, false, false, false, "ability_lasthit")
    elseif info.beh == "no_target" then
        faceCreep(hero, creepPos)
        Ability.CastNoTarget(ability, false, false, false, "ability_lasthit")
    end
end

--- Фильтры крипов
local function getMultiComboValue(widget, item)
    if not widget or not item then return nil end
    local ok, value = pcall(function() return widget:Get(item) end)
    if ok then return value end
    return nil
end

local function isConditionEnabled(item, legacyWidget, default)
    local value = getMultiComboValue(UI.Conditions, conditionLabel(item))
    if value ~= nil then return value end
    if legacyWidget and legacyWidget.Get then
        return legacyWidget:Get()
    end
    return default or false
end

local function isCreepFilterEnabled(item, legacyWidget, default)
    local value = getMultiComboValue(UI.CreepTypes, creepFilterLabel(item))
    if value ~= nil then return value end
    if legacyWidget and legacyWidget.Get then
        return legacyWidget:Get()
    end
    return default or false
end

local function isCreepValid(creep)
    if not Entity.IsAlive(creep) then return false end
    if NPC.IsHero(creep) or (NPC.IsConsideredHero and NPC.IsConsideredHero(creep)) then return false end
    if NPC.IsInvulnerable and NPC.IsInvulnerable(creep) then return false end
    if (NPC.IsBuilding and NPC.IsBuilding(creep)) or (NPC.IsTower and NPC.IsTower(creep)) then return false end
    if (NPC.IsWard and NPC.IsWard(creep)) or (NPC.IsCourier and NPC.IsCourier(creep)) then return false end

    local unitName = NPC.GetUnitName(creep) or ""

    if unitName:find("siege") then
        return isCreepFilterEnabled(CREEP_FILTER_ITEMS.siege, UI.Siege, false)
    end

    if isLaneCreepUnit(creep) then
        if isRangedUnit(creep) then
            return isCreepFilterEnabled(CREEP_FILTER_ITEMS.ranged, UI.RangedCreeps, true)
        end
        return isCreepFilterEnabled(CREEP_FILTER_ITEMS.melee, UI.LaneCreeps, true)
    end

    if isNeutralUnit(creep) then
        return isCreepFilterEnabled(CREEP_FILTER_ITEMS.neutral, UI.NeutralCreeps, false)
    end

    if isCreepUnit(creep) then
        return isCreepFilterEnabled(CREEP_FILTER_ITEMS.melee, UI.LaneCreeps, true)
    end

    return false
end

--- Приоритет крипа (ranged > melee, low HP = выше)
local function creepPriority(creep, hp)
    local w = 0
    local unitName = NPC.GetUnitName(creep) or ""

    if isRangedUnit(creep) then
        w = w + 30  -- ranged дают больше золота
    end
    if unitName:find("siege") then
        w = w + 10
    end

    -- Чем меньше HP, тем приоритетнее
    w = w + math.max(0, 100 - hp)

    return w
end

--------------------------------------------------------------------------------
-- SKILL SELECTOR
--------------------------------------------------------------------------------

local function getSpellIcon(abilityName)
    return "panorama/images/spellicons/" .. abilityName .. "_png.vtex_c"
end

local buildSkillsSelector = nil

local function styleMenuWidget(widget, text, tooltip, icon, image)
    if not widget then return widget end

    if text and widget.ForceLocalization then
        widget:ForceLocalization(text)
    end
    if image and widget.Image then
        widget:Image(image)
    end
    if icon and widget.Icon then
        widget:Icon(icon)
    end
    if tooltip and widget.ToolTip then
        widget:ToolTip(tooltip)
    end

    return widget
end

local function addGearSection(gear, text, image)
    if not gear then return nil end

    local label = gear:Label(text)
    if label and image and label.Image then
        label:Image(image)
    end

    return label
end

local function refreshSkillsWidgetState()
    if not UI.Skills then return end

    styleMenuWidget(
        UI.Skills,
        "Нюк-пул героя",
        "Какие спеллы можно тратить на ластхит. Список обновляется под текущего героя.",
        "\u{f0d0}",
        nil
    )

    if UI.Enable then
        UI.Skills:Disabled(not UI.Enable:Get())
    end
end

local function buildSkillsSelectorLegacyV20(heroName)
    if not menuGroup then return end
    local abilities = HERO_ABILITIES[heroName]
    if not abilities then return end

    local previousState = {}
    if UI.Skills then
        for _, info in ipairs(abilities) do
            local ok, val = pcall(function() return UI.Skills:Get(info.name) end)
            if ok then previousState[info.name] = val end
        end
    end

    local items = {}
    for _, info in ipairs(abilities) do
        local enabled = previousState[info.name]
        if enabled == nil then enabled = true end
        items[#items + 1] = {
            info.name,
            getSpellIcon(info.name),
            enabled and true or false,
        }
    end

    if UI.Skills and UI.Skills.Update then
        UI.Skills:Update(items, true)
    else
        UI.Skills = menuGroup:MultiSelect("Способности", items, true)
    end

    refreshSkillsWidgetState()
    currentHeroName = heroName
end

--------------------------------------------------------------------------------
-- MENU
--------------------------------------------------------------------------------

local function legacy_OnScriptsLoaded_v20()
    local group = Menu.Create(
        "Creeps", "Main", "[v2]Last Hit Helper", "Main", "Ability Last Hit"
    )
    menuGroup = group

    UI.Enable = group:Switch("Включить", false)
    UI.Enable:Image("panorama/images/spellicons/zuus_arc_lightning_png.vtex_c")

    UI.Key = group:Bind("Клавиша", Enum.ButtonCode.KEY_V)
    UI.Key:ToolTip("Зажмите для авто-добития способностями")

    local gear = UI.Enable:Gear("Настройки")

    UI.Debug         = gear:Switch("Дебаг-лог", false)
    UI.Buffer        = gear:Slider("Буфер HP",        -20, 60, 5, "%d")
    UI.MinMana       = gear:Slider("Мин. мана %%",      0, 80, 15, "%d%%")
    UI.SearchRange   = gear:Slider("Радиус поиска",   400, 1200, 900, "%d")
    UI.SmartPriority = gear:Switch("Умный приоритет", true)
    UI.SmartPriority:ToolTip("Не кастовать, если крип добивается обычным ударом")
    UI.PredictHP     = gear:Switch("Предсказание HP", true)
    UI.PredictHP:ToolTip("Учитывать урон союзников по крипу при расчёте")
    UI.AoEMode       = gear:Switch("AoE приоритет", true)
    UI.AoEMode:ToolTip("Предпочитать AoE-каст, убивающий больше крипов")
    UI.LaneCreeps    = gear:Switch("Лейн крипы",  true)
    UI.RangedCreeps  = gear:Switch("Дальние крипы", true)
    UI.Siege         = gear:Switch("Осадные крипы", false)
    UI.NeutralCreeps = gear:Switch("Нейтральные крипы", false)

    UI.Enable:SetCallback(function()
        local on = UI.Enable:Get()
        UI.Buffer:Disabled(not on)
        UI.MinMana:Disabled(not on)
        UI.SearchRange:Disabled(not on)
        UI.SmartPriority:Disabled(not on)
        UI.PredictHP:Disabled(not on)
        UI.AoEMode:Disabled(not on)
        UI.LaneCreeps:Disabled(not on)
        UI.RangedCreeps:Disabled(not on)
        UI.Siege:Disabled(not on)
        UI.NeutralCreeps:Disabled(not on)
    end, true)

    Log.Write(DEBUG_PREFIX .. "Menu v2.0 initialized OK")
end

--------------------------------------------------------------------------------
-- ACTIVE MENU OVERRIDES
--------------------------------------------------------------------------------

local function buildSkillsSelectorLegacyV21(heroName)
    if not menuGroup then return end
    local abilities = HERO_ABILITIES[heroName]
    if not abilities then return end

    local previousState = {}
    if UI.Skills then
        for _, info in ipairs(abilities) do
            local ok, val = pcall(function() return UI.Skills:Get(info.name) end)
            if ok then previousState[info.name] = val end
        end
    end

    local items = {}
    for _, info in ipairs(abilities) do
        local enabled = previousState[info.name]
        if enabled == nil then enabled = true end
        items[#items + 1] = {
            info.name,
            getSpellIcon(info.name),
            enabled and true or false,
        }
    end

    if UI.Skills and UI.Skills.Update then
        UI.Skills:Update(items, true)
    else
        UI.Skills = menuGroup:MultiSelect("Нюк-пул героя", items, true)
    end

    refreshSkillsWidgetState()
    currentHeroName = heroName
end

refreshSkillsWidgetState = function()
    if not UI.Skills then return end

    styleMenuWidget(
        UI.Skills,
        t("spells"),
        t("spells_tip"),
        "\u{f0d0}",
        nil
    )

    if UI.Enable then
        UI.Skills:Disabled(not UI.Enable:Get())
    end
end

buildSkillsSelector = function(heroName, abilities, signature)
    if not menuGroup or not abilities or #abilities == 0 then return end
    local previousState = {}
    if UI.Skills then
        for _, info in ipairs(abilities) do
            local ok, val = pcall(function() return UI.Skills:Get(info.name) end)
            if ok then previousState[info.name] = val end
        end
    end

    local items = {}
    local seenNames = {}
    for _, info in ipairs(abilities) do
        if not seenNames[info.name] then
            seenNames[info.name] = true
            local enabled = previousState[info.name]
            if enabled == nil then enabled = true end
            items[#items + 1] = {
                info.name,
                getSpellIcon(info.name),
                enabled and true or false,
            }
        end
    end

    if UI.Skills and UI.Skills.Update then
        UI.Skills:Update(items, true)
    else
        UI.Skills = menuGroup:MultiSelect(t("spells"), items, true)
    end

    refreshSkillsWidgetState()
    currentHeroName = heroName
    currentHeroAbilitySignature = signature
end

local function legacy_OnScriptsLoaded_v21()
    local group = Menu.Create(
        "Creeps", "Main", "[v2]Last Hit Helper", "Main", "Spell CS"
    )
    menuGroup = group

    UI.Enable = group:Switch("Врубить Spell CS", false)
    styleMenuWidget(
        UI.Enable,
        "Врубить Spell CS",
        "Автодобив спеллами. Пока держишь хоткей, скрипт ищет лучший нюк под ластхит.",
        nil,
        getSpellIcon("nevermore_shadowraze2")
    )

    UI.Key = group:Bind("Холд для добива", Enum.ButtonCode.KEY_V, getSpellIcon("zuus_arc_lightning"))
    styleMenuWidget(
        UI.Key,
        "Холд для добива",
        "Зажми кнопку, когда хочешь отдать крипа нюком, а не с руки.",
        nil,
        nil
    )

    local gear = UI.Enable:Gear("Фарм-панель")
    UI.SettingsGear = gear

    addGearSection(gear, "Линия и тайминг", getSpellIcon("lina_dragon_slave"))
    UI.Buffer = gear:Slider("Добивочный запас", -20, 60, 5, "%d")
    UI.MinMana = gear:Slider("Сейв маны", 0, 80, 15, "%d%%")
    UI.SearchRange = gear:Slider("Радиус фарма", 400, 1200, 900, "%d")

    addGearSection(gear, "Поведение на линии", getSpellIcon("shadow_shaman_ether_shock"))
    UI.SmartPriority = gear:Switch("Не воровать у тычки", true)
    UI.PredictHP = gear:Switch("Чекать входящий урон", true)
    UI.AoEMode = gear:Switch("Жадничать на пачку", true)

    addGearSection(gear, "Каких крипов резать", getSpellIcon("leshrac_split_earth"))
    UI.LaneCreeps = gear:Switch("Лейн-милишники", true)
    UI.RangedCreeps = gear:Switch("Лейн-ренджи", true)
    UI.Siege = gear:Switch("Катапульты", false)
    UI.NeutralCreeps = gear:Switch("Нейтралы", false)

    addGearSection(gear, "Тесты и лог", getSpellIcon("tinker_laser"))
    UI.Debug = gear:Switch("Спамить в лог", false)

    styleMenuWidget(UI.Buffer, "Добивочный запас", "Сколько HP можно накинуть сверху, чтобы нюк не мисснул добив.", "\u{f21e}", nil)
    styleMenuWidget(UI.MinMana, "Сейв маны", "Ниже этого процента скрипт перестанет тратить ману на фарм.", "\u{f043}", nil)
    styleMenuWidget(UI.SearchRange, "Радиус фарма", "На каком расстоянии искать крипов под spell CS.", "\u{f140}", nil)
    styleMenuWidget(UI.SmartPriority, "Не воровать у тычки", "Не жать спелл, если крип и так падает от обычной тычки героя.", "\u{f00c}", nil)
    styleMenuWidget(UI.PredictHP, "Чекать входящий урон", "Учитывать тычки крипов и союзников, чтобы точнее ловить тайминг добива.", "\u{f06e}", nil)
    styleMenuWidget(UI.AoEMode, "Жадничать на пачку", "Если можно срезать несколько крипов одним кастом, приоритет уйдёт в AoE.", "\u{f0c0}", nil)
    styleMenuWidget(UI.LaneCreeps, "Лейн-милишники", "Разрешить добивать ближних крипов с линии.", "\u{f00c}", nil)
    styleMenuWidget(UI.RangedCreeps, "Лейн-ренджи", "Разрешить добивать дальников. Обычно это самый жирный приоритет по голде.", "\u{f00c}", nil)
    styleMenuWidget(UI.Siege, "Катапульты", "Разрешить добивать осадных крипов спеллами.", "\u{f00c}", nil)
    styleMenuWidget(UI.NeutralCreeps, "Нейтралы", "Подключить нейтралов к spell CS, если фармишь лес спеллами.", "\u{f6ee}", nil)
    styleMenuWidget(UI.Debug, "Спамить в лог", "Писать в лог расчёты урона, предикт HP и выбранный каст.", "\u{f06e}", nil)

    UI.Enable:SetCallback(function()
        local on = UI.Enable:Get()
        UI.Key:Disabled(not on)
        UI.Buffer:Disabled(not on)
        UI.MinMana:Disabled(not on)
        UI.SearchRange:Disabled(not on)
        UI.SmartPriority:Disabled(not on)
        UI.PredictHP:Disabled(not on)
        UI.AoEMode:Disabled(not on)
        UI.LaneCreeps:Disabled(not on)
        UI.RangedCreeps:Disabled(not on)
        UI.Siege:Disabled(not on)
        UI.NeutralCreeps:Disabled(not on)
        UI.Debug:Disabled(not on)
        if UI.Skills then
            UI.Skills:Disabled(not on)
        end
    end, true)

    refreshSkillsWidgetState()
    Log.Write(DEBUG_PREFIX .. "Menu v2.1 styled UI initialized OK")
end

local function legacy_OnScriptsLoaded_v22()
    local group = Menu.Create(
        "Creeps", "Main", "[v2]Last Hit Helper", "Main", "Spell CS"
    )
    menuGroup = group

    UI.Enable = group:Switch("Включить", false)
    styleMenuWidget(
        UI.Enable,
        "Включить",
        "Автодобив спеллами. Работает, пока держишь хоткей.",
        "\u{f0e7}",
        nil
    )

    UI.Key = group:Bind("Хоткей", Enum.ButtonCode.KEY_V)
    styleMenuWidget(
        UI.Key,
        "Хоткей",
        "Зажми кнопку, когда хочешь отдать крипа нюком.",
        "\u{f11c}",
        nil
    )

    local gear = UI.Enable:Gear("Настройки")
    UI.SettingsGear = gear

    UI.Conditions = gear:MultiCombo("Условия", {
        CONDITION_ITEMS.smart,
        CONDITION_ITEMS.predict,
        CONDITION_ITEMS.aoe,
    }, {
        CONDITION_ITEMS.smart,
        CONDITION_ITEMS.predict,
        CONDITION_ITEMS.aoe,
    })
    UI.CreepTypes = gear:MultiCombo("Крипы", {
        CREEP_FILTER_ITEMS.melee,
        CREEP_FILTER_ITEMS.ranged,
        CREEP_FILTER_ITEMS.neutral,
        CREEP_FILTER_ITEMS.siege,
    }, {
        CREEP_FILTER_ITEMS.melee,
        CREEP_FILTER_ITEMS.ranged,
    })
    UI.SearchRange = gear:Slider("Радиус", 400, 1200, 900, "%d")
    UI.MinMana = gear:Slider("Мана %", 0, 80, 15, "%d%%")
    UI.Buffer = gear:Slider("Запас HP", -20, 60, 5, "%d")
    UI.Debug = gear:Switch("Лог", false)

    styleMenuWidget(UI.Conditions, "Условия", "Что учитывать при выборе каста.", "\u{f070}", nil)
    styleMenuWidget(UI.CreepTypes, "Крипы", "Какие типы крипов можно добивать спеллом.", "\u{f0c0}", nil)
    styleMenuWidget(UI.SearchRange, "Радиус", "На каком расстоянии искать крипов под spell CS.", "\u{f140}", nil)
    styleMenuWidget(UI.MinMana, "Мана %", "Ниже этого процента скрипт перестанет тратить ману на фарм.", "\u{f043}", nil)
    styleMenuWidget(UI.Buffer, "Запас HP", "Сколько HP можно накинуть сверху, чтобы нюк не мисснул добив.", "\u{f21e}", nil)
    styleMenuWidget(UI.Debug, "Лог", "Писать в лог расчеты урона, предикт HP и выбранный каст.", "\u{f188}", nil)

    UI.Enable:SetCallback(function()
        local on = UI.Enable:Get()
        UI.Key:Disabled(not on)
        UI.Conditions:Disabled(not on)
        UI.CreepTypes:Disabled(not on)
        UI.SearchRange:Disabled(not on)
        UI.MinMana:Disabled(not on)
        UI.Buffer:Disabled(not on)
        UI.Debug:Disabled(not on)
        if UI.Skills then
            UI.Skills:Disabled(not on)
        end
    end, true)

    refreshSkillsWidgetState()
    Log.Write(DEBUG_PREFIX .. "Menu v2.2 compact UI initialized OK")
end

script.OnScriptsLoaded = function()
    MENU_LANG = detectMenuLanguage()

    local group = Menu.Create(
        "Creeps", "Main", "[v2]Last Hit Helper", "Main", "Spell CS"
    )
    menuGroup = group

    UI.Enable = group:Switch(t("enable"), false)
    styleMenuWidget(UI.Enable, t("enable"), t("enable_tip"), "\u{f0e7}", nil)

    UI.Key = group:Bind(t("hotkey"), Enum.ButtonCode.KEY_V)
    styleMenuWidget(UI.Key, t("hotkey"), t("hotkey_tip"), "\u{f11c}", nil)

    local gear = UI.Enable:Gear(t("settings"))
    UI.SettingsGear = gear

    UI.Conditions = gear:MultiCombo(t("conditions"), {
        conditionLabel(CONDITION_ITEMS.smart),
        conditionLabel(CONDITION_ITEMS.predict),
        conditionLabel(CONDITION_ITEMS.aoe),
    }, {
        conditionLabel(CONDITION_ITEMS.smart),
        conditionLabel(CONDITION_ITEMS.predict),
        conditionLabel(CONDITION_ITEMS.aoe),
    })

    UI.CreepTypes = gear:MultiCombo(t("creeps"), {
        creepFilterLabel(CREEP_FILTER_ITEMS.melee),
        creepFilterLabel(CREEP_FILTER_ITEMS.ranged),
        creepFilterLabel(CREEP_FILTER_ITEMS.neutral),
        creepFilterLabel(CREEP_FILTER_ITEMS.siege),
    }, {
        creepFilterLabel(CREEP_FILTER_ITEMS.melee),
        creepFilterLabel(CREEP_FILTER_ITEMS.ranged),
    })

    UI.SearchRange = gear:Slider(t("search_range"), 400, 1200, 900, "%d")
    UI.MinMana = gear:Slider(t("min_mana"), 0, 80, 15, "%d%%")
    UI.Buffer = gear:Slider(t("buffer"), -20, 60, 5, "%d")
    UI.Debug = gear:Switch(t("debug"), false)

    styleMenuWidget(UI.Conditions, t("conditions"), t("conditions_tip"), "\u{f070}", nil)
    styleMenuWidget(UI.CreepTypes, t("creeps"), t("creeps_tip"), "\u{f0c0}", nil)
    styleMenuWidget(UI.SearchRange, t("search_range"), t("search_range_tip"), "\u{f140}", nil)
    styleMenuWidget(UI.MinMana, t("min_mana"), t("min_mana_tip"), "\u{f043}", nil)
    styleMenuWidget(UI.Buffer, t("buffer"), t("buffer_tip"), "\u{f21e}", nil)
    styleMenuWidget(UI.Debug, t("debug"), t("debug_tip"), "\u{f188}", nil)

    UI.Enable:SetCallback(function()
        local on = UI.Enable:Get()
        UI.Key:Disabled(not on)
        UI.Conditions:Disabled(not on)
        UI.CreepTypes:Disabled(not on)
        UI.SearchRange:Disabled(not on)
        UI.MinMana:Disabled(not on)
        UI.Buffer:Disabled(not on)
        UI.Debug:Disabled(not on)
        if UI.Skills then
            UI.Skills:Disabled(not on)
        end
    end, true)

    refreshSkillsWidgetState()
    Log.Write(DEBUG_PREFIX .. "Menu v2.4 adaptive UI initialized OK")
end

--------------------------------------------------------------------------------
-- MAIN LOGIC
--------------------------------------------------------------------------------

script.OnUpdate = function()
    if not UI.Enable or not UI.Enable:Get() then return end
    if not UI.Key or not UI.Key:IsDown() then return end

    local myHero = Heroes.GetLocal()
    if not myHero then dbgThrottle("No local hero") return end
    if not Entity.IsAlive(myHero) then return end
    if (NPC.IsSilenced and NPC.IsSilenced(myHero))
        or (NPC.IsStunned and NPC.IsStunned(myHero))
        or (NPC.IsHexed and NPC.IsHexed(myHero)) then return end
    if NPC.IsChannellingAbility and NPC.IsChannellingAbility(myHero) then return end

    if isHeroAttacking(myHero) then
        dbgThrottle("Герой атакует, пропуск")
        return
    end

    local mana    = NPC.GetMana(myHero) or 0
    local maxMana = NPC.GetMaxMana(myHero) or 1
    local manaPercent = (maxMana > 0) and (mana / maxMana * 100) or 0
    if manaPercent < (UI.MinMana and UI.MinMana:Get() or 15) then
        dbgThrottle(string.format("Low mana: %.0f%%", manaPercent))
        return
    end

    local now = GameRules.GetGameTime()
    local castLockDuration = lastCastLockDuration
    if castLockDuration <= 0 then
        castLockDuration = CAST_INTERVAL
    end
    if now - lastCastTime < castLockDuration then return end

    cleanupTracker(now)

    local heroName = NPC.GetUnitName(myHero)
    local heroAbilities, heroAbilitySignature, usedFallback = getResolvedHeroAbilityInfos(myHero)
    if not heroAbilities or #heroAbilities == 0 then
        dbgThrottleKey("hero-no-pool:" .. tostring(heroName), "No supported spell pool: " .. tostring(heroName), 2.0)
        return
    end

    if usedFallback then
        dbgThrottleKey("hero-fallback:" .. tostring(heroName), "Using fallback spell scan: " .. tostring(heroName), 5.0)
    end

    if heroName ~= currentHeroName or heroAbilitySignature ~= currentHeroAbilitySignature then
        buildSkillsSelector(heroName, heroAbilities, heroAbilitySignature)
    end

    local buffer        = UI.Buffer and UI.Buffer:Get() or 5
    local searchRange   = UI.SearchRange and UI.SearchRange:Get() or 900
    local usePrediction = isConditionEnabled(CONDITION_ITEMS.predict, UI.PredictHP, true)
    local useAoE        = isConditionEnabled(CONDITION_ITEMS.aoe, UI.AoEMode, true)
    local smartPriority = isConditionEnabled(CONDITION_ITEMS.smart, UI.SmartPriority, true)

    local creeps = NPCs.InRadius(
        Entity.GetAbsOrigin(myHero), searchRange,
        Entity.GetTeamNum(myHero), Enum.TeamType.TEAM_ENEMY
    )
    if not creeps or #creeps == 0 then
        dbgThrottle("No enemy creeps in " .. searchRange .. " range")
        return
    end

    -- Обновить HP-трекер
    for _, creep in ipairs(creeps) do
        if Entity.IsAlive(creep) and not NPC.IsHero(creep) then
            predictCreepHP(creep, 0)
        end
    end

    -- Поиск лучшего каста (score-based)
    local bestCreep    = nil
    local bestAbility  = nil
    local bestInfo     = nil
    local bestScore    = -1
    local debugChecked = 0
    local debugCastable = 0

    for _, info in ipairs(heroAbilities) do
        if UI.Skills then
            local ok, selected = pcall(function() return UI.Skills:Get(info.name) end)
            if ok and not selected then
                goto continue_ability
            end
        end

        local ability = getAbilityByName(myHero, info.name)
        if not ability then
            -- тихо пропускаем (не инвокирован и т.п.)
        elseif (Ability.GetLevel(ability) or 0) <= 0 then
            -- не выучена
        elseif not Ability.IsCastable(ability, mana) then
            dbgThrottle(info.name .. " not castable (mana=" .. string.format("%.0f", mana) .. ")")
        elseif (Ability.GetCooldown(ability) or 0) > 0 then
            dbgThrottle(info.name .. " on CD: " .. string.format("%.1f", Ability.GetCooldown(ability)))
        elseif isAbilityInPhase(ability) then
            dbgThrottleKey("phase:" .. info.name, info.name .. " in ability phase", 0.25)
        elseif not canAffordAbilityCast(myHero, ability, info) then
            dbgThrottle(info.name .. " blocked by self-damage / health cost")
        elseif isAbilityPassiveState(ability) then
            -- passive
        elseif isAbilityHiddenState(ability) then
            -- hidden
        else
            debugCastable = debugCastable + 1
            local baseDmg = getAbilityDamage(myHero, ability, info)

            if baseDmg <= 0 then
                local found = {}
                local allKeys = getAbilityDamageKeyCandidates(info)
                for _, k in ipairs(allKeys) do
                    local v = SV(ability, k)
                    if v ~= nil then
                        found[#found+1] = k .. "=" .. tostring(v)
                        if #found >= 6 then break end
                    end
                end
                local foundStr = #found > 0 and table.concat(found, ", ") or "ALL_NIL"
                dbgThrottleKey("zero-dmg:" .. info.name, string.format(
                    "%s baseDmg=0 | dmgKey=%s | found: %s",
                    info.name, tostring(info.dmgKey), foundStr
                ), DEBUG_REPEAT_INTERVAL)
            else
                for _, creep in ipairs(creeps) do
                    debugChecked = debugChecked + 1
                    if isCreepValid(creep) and isCreepInRange(myHero, ability, creep, info) then
                        -- Анти-спам
                        if lastTargetEntity and creep == lastTargetEntity
                            and (now - lastTargetTime) < lastTargetLockDuration then
                            -- skip

                        -- Smart priority
                        elseif smartPriority and canAutoAttackKill(myHero, creep, buffer) then
                            -- skip

                        else
                            local eval = evaluateCastOpportunity(
                                myHero, ability, info, creep, creeps, buffer, usePrediction, useAoE, baseDmg
                            )

                            dbgThrottle(string.format(
                                "%s → %s hp=%d pred=%.0f dmg=%.0f buf=%d kill=%s",
                                info.name,
                                NPC.GetUnitName(creep) or "?",
                                eval.hp, eval.predictedHP, eval.effectiveDmg, buffer,
                                tostring(eval.killAtImpact or eval.killNow)
                            ))

                            if eval.killAtImpact or eval.killNow or eval.canAoEKill then
                                local score = 0
                                if eval.killAtImpact or eval.killNow then
                                    score = creepPriority(creep, eval.predictedHP)
                                elseif eval.canAoEKill then
                                    score = 25
                                end

                                -- AoE бонус: +50 за каждого доп. крипа
                                if useAoE and (info.radius or info.lineProjectile) then
                                    score = score + eval.extraAoEKills * 50
                                end

                                if eval.reserveLastCharge then
                                    score = score - 12
                                end

                                if info.autoDetected then
                                    score = score - 2
                                end

                                if score > bestScore then
                                    bestScore   = score
                                    bestCreep   = creep
                                    bestAbility = ability
                                    bestInfo    = info
                                end
                            end
                        end
                    end
                end
            end
        end

        ::continue_ability::
    end

    if not bestCreep then
        dbgThrottle(string.format(
            "No killable creep (checked=%d, castable=%d, creeps=%d)",
            debugChecked, debugCastable, #creeps
        ))
        return
    end

    local finalEval = evaluateCastOpportunity(
        myHero, bestAbility, bestInfo, bestCreep, creeps, buffer, usePrediction, useAoE
    )
    if not finalEval or not (finalEval.killAtImpact or finalEval.killNow or finalEval.canAoEKill) then
        dbgThrottleKey(
            "revalidate:" .. tostring(Entity.GetIndex(bestCreep)) .. ":" .. bestInfo.name,
            string.format(
                "Skip stale cast %s → %s (hp=%d pred=%.0f dmg=%.0f)",
                bestInfo.name,
                NPC.GetUnitName(bestCreep) or "?",
                finalEval and finalEval.hp or (Entity.GetHealth(bestCreep) or 0),
                finalEval and finalEval.predictedHP or 0,
                finalEval and finalEval.effectiveDmg or 0
            ),
            0.2
        )
        return
    end

    local castReason = (finalEval.killAtImpact or finalEval.killNow) and "kill" or "aoe"
    dbg(string.format(
        "CAST %s → %s (hp=%d pred=%.0f dmg=%.0f score=%.0f reason=%s)",
        bestInfo.name,
        NPC.GetUnitName(bestCreep) or "?",
        finalEval.hp,
        finalEval.predictedHP,
        finalEval.effectiveDmg,
        bestScore,
        castReason
    ))
    castOnCreep(myHero, bestAbility, bestCreep, bestInfo)
    lastCastTime = now
    lastCastLockDuration = math.max(CAST_INTERVAL, getAbilityCastPoint(bestAbility, bestInfo) + 0.12)
    lastTargetEntity = bestCreep
    lastTargetTime = now
    lastTargetLockDuration = getTargetLockDuration(myHero, bestAbility, bestCreep, bestInfo)
end

local rawIsHeroAttacking = isHeroAttacking
isHeroAttacking = function(hero)
    if not rawIsHeroAttacking(hero) then
        return false
    end

    local myHero = Heroes.GetLocal()
    if not hero or hero ~= myHero then
        return true
    end

    local smartPriority = isConditionEnabled(CONDITION_ITEMS.smart, UI.SmartPriority, true)
    if not smartPriority then
        return false
    end

    local searchRange = UI.SearchRange and UI.SearchRange:Get() or 900
    local buffer = UI.Buffer and UI.Buffer:Get() or 5
    local creeps = NPCs.InRadius(
        Entity.GetAbsOrigin(hero), searchRange,
        Entity.GetTeamNum(hero), Enum.TeamType.TEAM_ENEMY
    )

    if not creeps or #creeps == 0 then
        return false
    end

    for _, creep in ipairs(creeps) do
        if isCreepValid(creep) and canAutoAttackKill(hero, creep, buffer) then
            return true
        end
    end

    return false
end

--------------------------------------------------------------------------------
-- RESET
--------------------------------------------------------------------------------

script.OnGameEnd = function()
    lastCastTime = 0
    lastCastLockDuration = 0
    lastDebugTime = 0
    lastDebugByKey = {}
    lastTargetEntity = nil
    lastTargetTime = 0
    lastTargetLockDuration = 0
    currentHeroName = nil
    currentHeroAbilitySignature = nil
    resolvedAbilityInfoCache = {}
    creepHPTracker = {}
    lastTrackerCleanup = 0
end

return script
