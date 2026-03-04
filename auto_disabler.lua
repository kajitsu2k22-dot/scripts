---@diagnostic disable: undefined-global, param-type-mismatch, inject-field

local script = {}

local SCRIPT_ID = "auto_disabler"
local MODE_LEGIT = 0
local MODE_RAGE = 1
local CONFIG_FILE = "auto_disabler"
local CONFIG_SECTION_PANEL = "priority_panel"
local CONFIG_SECTION_OWN_CONTROLS = "own_controls"
local CONFIG_SECTION_ENEMY_ABILITIES = "enemy_abilities"
local CONFIG_SECTION_ENEMY_HEROES = "enemy_heroes"

local MENU = {
    initialized = false,
}

local STATE = {
    lastHeroName = "",
    ownAbilitySnapshot = {},
    ownItemSnapshot = {},
    enemyDangerSnapshot = {},
    enemyOtherSnapshot = {},
    enemyItemSnapshot = {},
    ownAbilityNames = {},
    ownItemNames = {},
    enemyDangerNames = {},
    enemyOtherNames = {},
    enemyItemNames = {},
    enemyHeroSnapshot = {},
    enemyHeroNames = {},
    priorityOrder = {},
    selectedPriorityId = nil,
    lastRefreshTime = 0,
    lastPanelSaveTime = 0,
    lastCastTime = 0,
    lastOrderAttemptTime = 0,
    targetControlUsage = {},
    instantEnemyCasts = {},
    linkensFollowupTargets = {},
    enemyRevealThreatCache = {},
    ownControlPanelDisabled = {},
    ownControlStateLoaded = {},
    enemyAbilityEnabled = {},
    enemyAbilityLoaded = {},
    enemyHeroEnabled = {},
    enemyHeroLoaded = {},
    persistLoaded = false,
    persistOwnEnabled = {},
    persistEnemyAbilityEnabled = {},
    persistEnemyHeroEnabled = {},
    language = "ru",
    panel = {
        x = 420,
        y = 340,
        w = 0,
        h = 0,
        collapsed = false,
        dock = 0,
        iconSize = 36,
        dragging = false,
        resizing = false,
        resizeCorner = "",
        resizeStartX = 0,
        resizeStartY = 0,
        resizeStartSize = 36,
        dx = 0,
        dy = 0,
        hovered = false,
        clickEaten = false,
    },
    iconCache = {},
    fontMain = nil,
    fontSmall = nil,
    panelTheme = {
        lastSync = 0,
        colors = nil,
    },
}

local PANEL_LAYOUT = {
    padding = 10,
    header = 24,
    sectionTitle = 14,
    sectionGap = 6,
    footer = 28,
    icon = 36,
    iconGap = 6,
    enemyIcon = 30,
    enemyIconGap = 5,
    edgeTab = 28,
    corner = 8,
}

local DANGEROUS_ABILITY_LIST = {
    "enigma_black_hole",
    "faceless_void_chronosphere",
    "magnataur_reverse_polarity",
    "bane_fiends_grip",
    "crystal_maiden_freezing_field",
    "witch_doctor_death_ward",
    "pudge_dismember",
    "shadow_shaman_shackles",
    "lion_mana_drain",
    "warlock_rain_of_chaos",
    "winter_wyvern_winters_curse",
    "treant_overgrowth",
    "disruptor_static_storm",
    "phoenix_supernova",
    "primal_beast_pulverize",
    "muerta_pierce_the_veil",
    "void_spirit_aether_remnant",
    "mars_arena_of_blood",
    "necrolyte_reapers_scythe",
    "oracle_false_promise",
    "terrorblade_sunder",
    "naga_siren_song_of_the_siren",
    "pugna_life_drain",
    "leshrac_pulse_nova",
    "jakiro_macropyre",
    "death_prophet_exorcism",
    "dawnbreaker_solar_guardian",
    "invoker_cataclysm",
    "queenofpain_sonic_wave",
    "skywrath_mage_mystic_flare",
}

local DANGEROUS_ITEM_LIST = {
    "item_black_king_bar",
    "item_lotus_orb",
    "item_blade_mail",
    "item_aeon_disk",
    "item_hurricane_pike",
    "item_ghost",
    "item_cyclone",
    "item_wind_waker",
    "item_force_staff",
    "item_glimmer_cape",
    "item_manta",
    "item_sphere",
    "item_disperser",
    "item_orchid",
    "item_bloodthorn",
}

local DANGEROUS_ITEM_MODIFIERS = {
    item_black_king_bar = "modifier_black_king_bar_immune",
    item_lotus_orb = "modifier_item_lotus_orb_active",
    item_blade_mail = "modifier_item_blade_mail_reflect",
    item_ghost = "modifier_ghost_state",
    item_glimmer_cape = "modifier_item_glimmer_cape_fade",
}

local EXCLUDED_OWN_ITEM_SET = {
    item_tpscroll = true,
    item_town_portal_scroll = true,
    item_travel_boots = true,
    item_travel_boots_2 = true,
    item_boots_of_travel = true,
    item_boots_of_travel_2 = true,
}

local NULLIFIER_PRIORITY_MODIFIERS = {
    "modifier_ghost_state",
    "modifier_item_glimmer_cape_fade",
    "modifier_item_euls_cyclone",
    "modifier_wind_waker",
    "modifier_item_aeon_disk_buff",
    "modifier_item_fluffy_hat",
}

local ITEM_SMART_ROLE = {
    item_blink = "blink",
    item_overwhelming_blink = "blink",
    item_swift_blink = "blink",
    item_arcane_blink = "blink",
    item_force_staff = "force",
    item_hurricane_pike = "force",
    item_sheepstick = "hex",
    item_orchid = "silence",
    item_bloodthorn = "silence",
    item_rod_of_atos = "root",
    item_gungir = "root",
    item_cyclone = "cyclone",
    item_wind_waker = "cyclone",
    item_nullifier = "nullifier",
    item_abyssal_blade = "stun",
}

local ABILITY_SMART_ROLE = {
    antimage_blink = "blink",
    queenofpain_blink = "blink",
    faceless_void_time_walk = "blink",
    riki_blink_strike = "target_gapclose",
    ember_spirit_fire_remnant = "blink",
    void_spirit_astral_step = "blink",
    magnataur_skewer = "escape_line",
    earth_spirit_rolling_boulder = "escape_line",
    morphling_waveform = "escape_line",
    puck_phase_shift = "self_defense",
}

local LINKENS_BREAK_ITEM_PRIORITY = {
    item_orchid = 10,
    item_bloodthorn = 12,
    item_diffusal_blade = 14,
    item_disperser = 16,
    item_rod_of_atos = 18,
    item_gungir = 20,
    item_nullifier = 22,
    item_ethereal_blade = 24,
    item_harpoon = 28,
    item_sheepstick = 80,
    item_abyssal_blade = 90,
    item_cyclone = 140,
    item_wind_waker = 145,
}

local LINKENS_BREAK_ABILITY_PRIORITY = {
    lion_voodoo = 75,
    shadow_shaman_voodoo = 75,
    doom_bringer_doom = 88,
}

local THREAT_WEIGHTS = {
    severity = 1300,
    instantBonus = 650,
    triggerChannel = 700,
    triggerReveal = 280,
    triggerLinkensFollowup = 2600,
    dangerousAbility = 800,
    dangerousItem = 280,
    channeling = 1000,
    distanceScale = 0.75,
    close500 = 340,
    close800 = 200,
    close1100 = 90,
    facing = 150,
    lowHpPerSeverity = 95,
    lowHpClose = 240,
    usedPenalty = 180,
}

local CONTROL_ROLE_WEIGHTS = {
    hex = 520,
    stun = 500,
    cyclone = 360,
    silence = 300,
    root = 270,
    nullifier = 255,
    force = 120,
    blink = 95,
    self_defense = 105,
    escape_line = 110,
    target_gapclose = 90,
}

local ABILITY_ROLE_TOKENS = {
    { token = "hex", role = "hex" },
    { token = "voodoo", role = "hex" },
    { token = "stun", role = "stun" },
    { token = "impale", role = "stun" },
    { token = "bash", role = "stun" },
    { token = "shackle", role = "stun" },
    { token = "lasso", role = "stun" },
    { token = "ravage", role = "stun" },
    { token = "black_hole", role = "stun" },
    { token = "chronosphere", role = "stun" },
    { token = "silence", role = "silence" },
    { token = "last_word", role = "silence" },
    { token = "root", role = "root" },
    { token = "ensnare", role = "root" },
    { token = "sprout", role = "root" },
    { token = "cyclone", role = "cyclone" },
}

local L10N = {
    en = {
        menu_enable = "Enable",
        menu_settings = "Settings",
        menu_language = "Language / Язык",
        menu_mode = "Mode",
        menu_mode_legit = "Legit",
        menu_mode_rage = "Rage",
        menu_show_panel = "Show priority panel",
        menu_auto_refresh = "Auto refresh lists",
        menu_interrupt_channel = "Interrupt any channel",
        menu_track_other = "Track optional abilities",
        menu_react_mods = "React to active item buffs",
        menu_ignore_disabled = "Ignore already disabled targets",
        menu_cast_linkens = "Cast into Linkens",
        menu_search_radius = "Search radius",
        menu_cast_delay = "Delay between casts (ms)",
        menu_retry_delay = "Retry on failed cast (ms)",
        menu_max_controls = "Max controls per target",
        menu_target_window = "Per-target window (ms)",
        menu_reserve_nearby = "Reserve control if enemy nearby",
        menu_panel_cols = "Panel columns",
        menu_auto_speed_priority = "Auto priority by cast speed",
        menu_resize_handles = "Resize handles near cursor",
        menu_own_controls = "Own controls",
        menu_own_abilities = "Own abilities",
        menu_own_items = "Own items",
        menu_enemy_triggers = "Enemy triggers",
        menu_enemy_heroes = "Enemy heroes",
        menu_enemy_danger_abilities = "Hero abilities",
        menu_enemy_danger_items = "Dangerous items",
        menu_enemy_other_abilities = "Other abilities",
        tip_own_abilities = "Select your abilities for auto disable.",
        tip_own_items = "Select your items for auto disable.",
        tip_enemy_heroes = "Disable heroes you do not want to react to.",
        tip_enemy_danger = "High-priority enemy spells to react to.",
        tip_enemy_other = "Optional enemy spells to react to.",
        tip_enemy_items = "Enemy items to react to while casting.",
        panel_title = "\u{1F608} Euphoria Disabler",
        panel_mode = "Mode",
        panel_hint = "LMB own: priority | RMB own: on/off | LMB hero/skill: on/off | Corners: resize",
        panel_own = "Your Controls",
        panel_enemy = "Enemy Abilities",
        panel_empty_own = "No active abilities/items found.",
    },
    ru = {
        menu_enable = "Включить",
        menu_settings = "Настройки",
        menu_language = "Язык / Language",
        menu_mode = "Режим",
        menu_mode_legit = "Legit",
        menu_mode_rage = "Rage",
        menu_show_panel = "Панель приоритетов",
        menu_auto_refresh = "Авто-обновление списков",
        menu_interrupt_channel = "Сбивать любой канал",
        menu_track_other = "Отслеживать доп. способности",
        menu_react_mods = "Реакция на бафы предметов",
        menu_ignore_disabled = "Игнорировать уже законтроленных",
        menu_cast_linkens = "Кастовать в Linken's",
        menu_search_radius = "Радиус поиска",
        menu_cast_delay = "Задержка между кастами (мс)",
        menu_retry_delay = "Повтор при неудаче (мс)",
        menu_max_controls = "Макс. контролей на цель",
        menu_target_window = "Окно учета по цели (мс)",
        menu_reserve_nearby = "Оставлять контроль при 2+ врагах",
        menu_panel_cols = "Колонки панели",
        menu_resize_handles = "Ручки размера рядом с курсором",
        menu_own_controls = "Свои контроли",
        menu_own_abilities = "Свои способности",
        menu_own_items = "Свои предметы",
        menu_enemy_triggers = "Триггеры врагов",
        menu_enemy_heroes = "Герои врагов",
        menu_enemy_danger_abilities = "Способности героев",
        menu_enemy_danger_items = "Опасные предметы",
        menu_enemy_other_abilities = "Прочие способности",
        tip_own_abilities = "Выбери свои способности для авто-дизейбла.",
        tip_own_items = "Выбери свои предметы для авто-дизейбла.",
        tip_enemy_heroes = "Отключи героев, на которых не реагировать.",
        tip_enemy_danger = "Главные вражеские спеллы для реакции.",
        tip_enemy_other = "Дополнительные спеллы для реакции.",
        tip_enemy_items = "Предметы врагов для реакции во время каста.",
        panel_title = "\u{1F608} Euphoria Disabler",
        panel_mode = "Режим",
        panel_hint = "ЛКМ: свои выбрать / враг toggle | ПКМ свои: выкл/вкл",
        panel_own = "Твои Контроли",
        panel_enemy = "Вражеские Способности",
        panel_empty_own = "Выбери способности/предметы в меню",
    },
}

local function BuildSet(list)
    local out = {}
    for i = 1, #list do
        out[list[i]] = true
    end
    return out
end

local DANGEROUS_ABILITY_SET = BuildSet(DANGEROUS_ABILITY_LIST)
local DANGEROUS_ITEM_SET = BuildSet(DANGEROUS_ITEM_LIST)

local function BuildBlockedStates()
    local out = {}
    local ms = Enum and Enum.ModifierState
    if not ms then
        return out
    end

    local values = {
        ms.MODIFIER_STATE_STUNNED or ms.STUNNED,
        ms.MODIFIER_STATE_HEXED or ms.HEXED,
        ms.MODIFIER_STATE_SILENCED or ms.SILENCED,
        ms.MODIFIER_STATE_MUTED or ms.MUTED,
        ms.MODIFIER_STATE_COMMAND_RESTRICTED or ms.COMMAND_RESTRICTED,
    }

    for i = 1, #values do
        if values[i] ~= nil then
            out[#out + 1] = values[i]
        end
    end

    return out
end

local BLOCKED_STATES = BuildBlockedStates()

local function BuildAlreadyDisabledStates()
    local out = {}
    local ms = Enum and Enum.ModifierState
    if not ms then
        return out
    end

    local values = {
        ms.MODIFIER_STATE_STUNNED or ms.STUNNED,
        ms.MODIFIER_STATE_HEXED or ms.HEXED,
        ms.MODIFIER_STATE_ROOTED or ms.ROOTED,
        ms.MODIFIER_STATE_SILENCED or ms.SILENCED,
        ms.MODIFIER_STATE_DISARMED or ms.DISARMED,
        ms.MODIFIER_STATE_COMMAND_RESTRICTED or ms.COMMAND_RESTRICTED,
        ms.MODIFIER_STATE_NIGHTMARED or ms.NIGHTMARED,
    }

    for i = 1, #values do
        if values[i] ~= nil then
            out[#out + 1] = values[i]
        end
    end

    return out
end

local ALREADY_DISABLED_STATES = BuildAlreadyDisabledStates()
local ABILITY_BEHAVIOR_CACHE = {}
local FILE_PERSIST_PATH = "auto_disabler_state.ini"
local FILE_PERSIST = {
    loaded = false,
    data = {},
}

local function TrimText(value)
    if type(value) ~= "string" then
        return ""
    end

    local out = string.gsub(value, "^%s+", "")
    out = string.gsub(out, "%s+$", "")
    return out
end

local function OpenPersistFile(mode)
    if not io or not io.open then
        return nil
    end

    local ok, file = pcall(io.open, FILE_PERSIST_PATH, mode)
    if not ok then
        return nil
    end
    return file
end

local function EnsureFilePersistLoaded()
    if FILE_PERSIST.loaded then
        return
    end

    FILE_PERSIST.loaded = true
    FILE_PERSIST.data = {}

    local file = OpenPersistFile("r")
    if not file then
        return
    end

    local section = ""
    for line in file:lines() do
        local raw = tostring(line or "")
        local foundSection = string.match(raw, "^%s*%[([^%]]+)%]%s*$")
        if foundSection and foundSection ~= "" then
            section = TrimText(foundSection)
            if section ~= "" and not FILE_PERSIST.data[section] then
                FILE_PERSIST.data[section] = {}
            end
        else
            local rawKey, rawValue = string.match(raw, "^%s*([^=]+)%s*=%s*(.-)%s*$")
            local key = TrimText(rawKey)
            if section ~= "" and key ~= "" then
                FILE_PERSIST.data[section] = FILE_PERSIST.data[section] or {}
                FILE_PERSIST.data[section][key] = rawValue or ""
            end
        end
    end

    file:close()
end

local function SaveFilePersist()
    local file = OpenPersistFile("w")
    if not file then
        return
    end

    local sections = {}
    for section, _ in pairs(FILE_PERSIST.data) do
        sections[#sections + 1] = section
    end
    table.sort(sections)

    for i = 1, #sections do
        local section = sections[i]
        file:write("[" .. section .. "]\n")

        local values = FILE_PERSIST.data[section] or {}
        local keys = {}
        for key, _ in pairs(values) do
            keys[#keys + 1] = key
        end
        table.sort(keys)

        for j = 1, #keys do
            local key = keys[j]
            local value = tostring(values[key] or "")
            file:write(key .. "=" .. value .. "\n")
        end

        if i < #sections then
            file:write("\n")
        end
    end

    file:close()
end

local function ReadFilePersist(section, key)
    EnsureFilePersistLoaded()
    local sec = FILE_PERSIST.data[tostring(section or "")]
    if not sec then
        return nil
    end
    return sec[tostring(key or "")]
end

local function WriteFilePersist(section, key, value)
    EnsureFilePersistLoaded()

    local sectionKey = tostring(section or "")
    local valueKey = tostring(key or "")
    if sectionKey == "" or valueKey == "" then
        return
    end

    FILE_PERSIST.data[sectionKey] = FILE_PERSIST.data[sectionKey] or {}
    local text = tostring(value or "")
    if FILE_PERSIST.data[sectionKey][valueKey] == text then
        return
    end
    FILE_PERSIST.data[sectionKey][valueKey] = text
    SaveFilePersist()
end

local function SafeCall(fn, ...)
    if not fn then
        return nil
    end

    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        return nil
    end

    return a, b, c, d
end

local function ReadConfigString(section, key, defaultValue)
    if Config and Config.ReadString then
        local value = SafeCall(Config.ReadString, CONFIG_FILE, section, key, defaultValue)
        if type(value) == "string" and value ~= "" then
            return value
        end
    end

    local fileValue = ReadFilePersist(section, key)
    if type(fileValue) == "string" and fileValue ~= "" then
        return fileValue
    end

    return defaultValue
end

local function WriteConfigString(section, key, value)
    local text = tostring(value or "")

    if Config and Config.WriteString then
        SafeCall(Config.WriteString, CONFIG_FILE, section, key, text)
    end

    WriteFilePersist(section, key, text)
end

local function NormalizeLanguageCode(value)
    if type(value) ~= "string" then
        return "ru"
    end
    local low = string.lower(value)
    if low == "en" then
        return "en"
    end
    return "ru"
end

local FIXED_SETTINGS = {
    language = "ru",
    rageMode = true,
    interruptAnyChannel = true,
    reactToItemModifiers = true,
    ignoreDisabledTargets = true,
    castIntoLinkens = false,
    searchRadius = 1100,
    castDelayMs = 80,
    retryDelayMs = 80,
    maxControlsPerTarget = 2,
    targetMemoryMs = 1800,
    reserveForNearby = true,
    panelColumns = 6,
}

local function GetLanguageCode()
    return NormalizeLanguageCode(FIXED_SETTINGS.language or STATE.language)
end

local function L(key)
    local lang = GetLanguageCode()
    local byLang = L10N[lang] or L10N.ru
    if byLang and byLang[key] then
        return byLang[key]
    end
    local fallback = L10N.en
    return (fallback and fallback[key]) or key
end

local function GetTime()
    return (GameRules and GameRules.GetGameTime and GameRules.GetGameTime()) or 0
end

local function Dist(a, b)
    return (a - b):Length()
end

local function GetModeIndex()
    if FIXED_SETTINGS.rageMode then
        return MODE_RAGE
    end

    return MODE_LEGIT
end

local function IsRageMode()
    return GetModeIndex() == MODE_RAGE
end

local function GetEffectiveCastDelay()
    local base = FIXED_SETTINGS.castDelayMs or 80
    if IsRageMode() then
        return math.min(base, 120)
    end
    return base
end

local function GetEffectiveRetryDelay()
    local base = FIXED_SETTINGS.retryDelayMs or 80
    if IsRageMode() then
        return math.min(base, 120)
    end
    return base
end

local function IsInterruptAnyChannelEnabled()
    return FIXED_SETTINGS.interruptAnyChannel and true or false
end

local function IsReactToItemModifiersEnabled()
    return FIXED_SETTINGS.reactToItemModifiers and true or false
end

local function IsIgnoreDisabledTargetsEnabled()
    return FIXED_SETTINGS.ignoreDisabledTargets and true or false
end

local function IsCastIntoLinkensEnabled()
    return FIXED_SETTINGS.castIntoLinkens and true or false
end

local function GetSearchRadius()
    return FIXED_SETTINGS.searchRadius or 1100
end

local function GetTargetMemoryMs()
    return FIXED_SETTINGS.targetMemoryMs or 1800
end

local function GetMaxControlsPerTarget()
    return FIXED_SETTINGS.maxControlsPerTarget or 2
end

local function IsReserveForNearbyEnabled()
    return FIXED_SETTINGS.reserveForNearby and true or false
end

local function GetPanelColumns()
    return FIXED_SETTINGS.panelColumns or 6
end

local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function MakeVec3(x, y, z)
    if Vector then
        local v = SafeCall(Vector, x, y, z)
        if v then return v end
    end
    return { x = x, y = y, z = z or 0 }
end

local function Normalize2D(vec)
    if not vec then
        return nil
    end

    local x = vec.x or 0
    local y = vec.y or 0
    local len = math.sqrt(x * x + y * y)
    if len <= 0.0001 then
        return nil
    end

    return MakeVec3(x / len, y / len, 0)
end

local function Dir2D(from, to)
    if not from or not to then
        return nil
    end

    return Normalize2D(MakeVec3((to.x or 0) - (from.x or 0), (to.y or 0) - (from.y or 0), 0))
end

local function GetFountainPosByTeam(teamNum)
    if teamNum == 2 then
        return MakeVec3(-7176, -6623, 384)
    end

    if teamNum == 3 then
        return MakeVec3(7015, 6423, 392)
    end

    return nil
end

local function ReadConfigInt(section, key, defaultValue)
    if Config and Config.ReadString then
        local text = SafeCall(Config.ReadString, CONFIG_FILE, section, key, "")
        if type(text) == "string" and text ~= "" then
            local parsed = tonumber(text)
            if type(parsed) == "number" then
                return parsed
            end
        end
    end

    if Config and Config.ReadInt then
        local value = SafeCall(Config.ReadInt, CONFIG_FILE, section, key, defaultValue)
        if type(value) == "number" then
            return value
        end
    end

    local fileValue = ReadFilePersist(section, key)
    if type(fileValue) == "string" and fileValue ~= "" then
        local parsed = tonumber(fileValue)
        if type(parsed) == "number" then
            return parsed
        end
    end

    return defaultValue
end

local function WriteConfigInt(section, key, value)
    local iv = math.floor(value)
    if Config and Config.WriteInt then
        SafeCall(Config.WriteInt, CONFIG_FILE, section, key, iv)
    end

    if Config and Config.WriteString then
        SafeCall(Config.WriteString, CONFIG_FILE, section, key, tostring(iv))
    end

    WriteFilePersist(section, key, tostring(iv))
end

local function NormalizeConfigKey(value)
    local raw = tostring(value or "")
    local normalized = string.gsub(raw, "[^%w_]+", "_")
    if normalized == "" then
        return "_"
    end
    return normalized
end

local function EncodeBoolMap(map)
    local keys = {}
    for key, _ in pairs(map or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)

    local parts = {}
    for i = 1, #keys do
        local key = keys[i]
        parts[#parts + 1] = key .. "=" .. ((map[key] and true) and "1" or "0")
    end
    return table.concat(parts, ";")
end

local function DecodeBoolMap(text)
    local out = {}
    if type(text) ~= "string" or text == "" then
        return out
    end

    for chunk in string.gmatch(text, "([^;]+)") do
        local eq = string.find(chunk, "=", 1, true)
        if eq and eq > 1 then
            local key = string.sub(chunk, 1, eq - 1)
            local value = string.sub(chunk, eq + 1)
            if key ~= "" then
                out[key] = (value == "1")
            end
        end
    end

    return out
end

local function LoadPersistMaps()
    if STATE.persistLoaded then
        return
    end
    STATE.persistLoaded = true

    STATE.persistOwnEnabled = DecodeBoolMap(ReadConfigString(CONFIG_SECTION_OWN_CONTROLS, "state", ""))
    STATE.persistEnemyAbilityEnabled = DecodeBoolMap(ReadConfigString(CONFIG_SECTION_ENEMY_ABILITIES, "state", ""))
    STATE.persistEnemyHeroEnabled = DecodeBoolMap(ReadConfigString(CONFIG_SECTION_ENEMY_HEROES, "state", ""))
end

local function SavePersistMap(section, map)
    WriteConfigString(section, "state", EncodeBoolMap(map or {}))
end

local function DecodePanelState(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    local sx, sy, sdock, scollapsed, ssize = string.match(text, "^%s*(-?%d+),(-?%d+),(-?%d+),(-?%d+),(-?%d+)%s*$")
    if not sx then
        return nil
    end

    return {
        x = tonumber(sx) or STATE.panel.x,
        y = tonumber(sy) or STATE.panel.y,
        dock = tonumber(sdock) or 0,
        collapsed = tonumber(scollapsed) or 0,
        size = tonumber(ssize) or STATE.panel.iconSize or 36,
    }
end

local function LoadPanelPosition()
    local packed = DecodePanelState(ReadConfigString(CONFIG_SECTION_PANEL, "state", ""))
    if packed then
        STATE.panel.x = packed.x
        STATE.panel.y = packed.y
        STATE.panel.collapsed = packed.collapsed ~= 0
        STATE.panel.iconSize = Clamp(math.floor(packed.size or 36), 24, 64)
        if packed.dock == -1 or packed.dock == 1 then
            STATE.panel.dock = packed.dock
        else
            STATE.panel.dock = 0
        end
        return
    end

    local x = ReadConfigInt(CONFIG_SECTION_PANEL, "x", STATE.panel.x)
    local y = ReadConfigInt(CONFIG_SECTION_PANEL, "y", STATE.panel.y)
    local collapsed = ReadConfigInt(CONFIG_SECTION_PANEL, "collapsed", STATE.panel.collapsed and 1 or 0)
    local dock = ReadConfigInt(CONFIG_SECTION_PANEL, "dock", STATE.panel.dock or 0)
    local iconSize = ReadConfigInt(CONFIG_SECTION_PANEL, "icon_size", STATE.panel.iconSize or 36)
    if type(x) == "number" then STATE.panel.x = x end
    if type(y) == "number" then STATE.panel.y = y end
    STATE.panel.collapsed = collapsed ~= 0
    STATE.panel.iconSize = Clamp(math.floor(iconSize or 36), 24, 64)
    if dock == -1 or dock == 1 then
        STATE.panel.dock = dock
    else
        STATE.panel.dock = 0
    end
end

local function SavePanelPosition()
    local packed = string.format(
        "%d,%d,%d,%d,%d",
        math.floor(STATE.panel.x or 0),
        math.floor(STATE.panel.y or 0),
        math.floor(STATE.panel.dock or 0),
        STATE.panel.collapsed and 1 or 0,
        math.floor(STATE.panel.iconSize or 36)
    )
    WriteConfigString(CONFIG_SECTION_PANEL, "state", packed)

    WriteConfigInt(CONFIG_SECTION_PANEL, "x", STATE.panel.x)
    WriteConfigInt(CONFIG_SECTION_PANEL, "y", STATE.panel.y)
    WriteConfigInt(CONFIG_SECTION_PANEL, "collapsed", STATE.panel.collapsed and 1 or 0)
    WriteConfigInt(CONFIG_SECTION_PANEL, "dock", STATE.panel.dock or 0)
    WriteConfigInt(CONFIG_SECTION_PANEL, "icon_size", STATE.panel.iconSize or 36)
end

local function MakeOwnControlConfigKey(id)
    return NormalizeConfigKey(tostring(id or ""))
end

local function EnsureOwnControlPanelState(id)
    if not id then
        return
    end

    LoadPersistMaps()

    local key = MakeOwnControlConfigKey(id)
    if STATE.ownControlStateLoaded[key] then
        return
    end

    STATE.ownControlStateLoaded[key] = true
    local fromPacked = STATE.persistOwnEnabled[key]
    local enabled
    if fromPacked ~= nil then
        enabled = fromPacked and true or false
    else
        enabled = ReadConfigInt(CONFIG_SECTION_OWN_CONTROLS, key, 1) ~= 0
    end
    if enabled then
        STATE.ownControlPanelDisabled[id] = nil
    else
        STATE.ownControlPanelDisabled[id] = true
    end
end

local function ReadEnemyAbilityEnabled(name)
    if not name then
        return false
    end

    LoadPersistMaps()

    if STATE.enemyAbilityLoaded[name] then
        return STATE.enemyAbilityEnabled[name] and true or false
    end

    local defaultValue = DANGEROUS_ABILITY_SET[name] and 1 or 0
    local key = NormalizeConfigKey(name)
    local fromPacked = STATE.persistEnemyAbilityEnabled[key]
    local enabled
    if fromPacked ~= nil then
        enabled = fromPacked and true or false
    else
        enabled = ReadConfigInt(CONFIG_SECTION_ENEMY_ABILITIES, key, defaultValue) ~= 0
    end
    STATE.enemyAbilityLoaded[name] = true
    STATE.enemyAbilityEnabled[name] = enabled and true or false
    return enabled and true or false
end

local function WriteEnemyAbilityEnabled(name, enabled)
    if not name then
        return
    end

    LoadPersistMaps()

    local key = NormalizeConfigKey(name)
    STATE.enemyAbilityLoaded[name] = true
    STATE.enemyAbilityEnabled[name] = enabled and true or false
    STATE.persistEnemyAbilityEnabled[key] = enabled and true or false
    SavePersistMap(CONFIG_SECTION_ENEMY_ABILITIES, STATE.persistEnemyAbilityEnabled)
    WriteConfigInt(CONFIG_SECTION_ENEMY_ABILITIES, key, enabled and 1 or 0)
end

local function ReadEnemyHeroEnabled(name)
    if not name then
        return false
    end

    LoadPersistMaps()

    if STATE.enemyHeroLoaded[name] then
        return STATE.enemyHeroEnabled[name] and true or false
    end

    local key = NormalizeConfigKey(name)
    local fromPacked = STATE.persistEnemyHeroEnabled[key]
    local enabled
    if fromPacked ~= nil then
        enabled = fromPacked and true or false
    else
        enabled = ReadConfigInt(CONFIG_SECTION_ENEMY_HEROES, key, 1) ~= 0
    end
    STATE.enemyHeroLoaded[name] = true
    STATE.enemyHeroEnabled[name] = enabled and true or false
    return enabled and true or false
end

local function WriteEnemyHeroEnabled(name, enabled)
    if not name then
        return
    end

    LoadPersistMaps()

    local key = NormalizeConfigKey(name)
    STATE.enemyHeroLoaded[name] = true
    STATE.enemyHeroEnabled[name] = enabled and true or false
    STATE.persistEnemyHeroEnabled[key] = enabled and true or false
    SavePersistMap(CONFIG_SECTION_ENEMY_HEROES, STATE.persistEnemyHeroEnabled)
    WriteConfigInt(CONFIG_SECTION_ENEMY_HEROES, key, enabled and 1 or 0)
end

local function CopyArray(src)
    local out = {}
    for i = 1, #src do
        out[i] = src[i]
    end
    return out
end

local function ArraysEqual(a, b)
    if #a ~= #b then
        return false
    end

    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end

    return true
end

local function IsValidAbilityName(name)
    if not name or name == "" then return false end
    if name == "generic_hidden" then return false end
    if name == "attribute_bonus" then return false end
    if string.find(name, "special_bonus_", 1, true) then return false end
    if string.find(name, "generic_", 1, true) then return false end
    return true
end

local function IsValidItemName(name)
    if not name or name == "" then return false end
    if not string.find(name, "item_", 1, true) then return false end
    if string.find(name, "item_recipe", 1, true) then return false end
    return true
end

local function IsSelectableOwnItemName(name)
    if not IsValidItemName(name) then
        return false
    end
    return not EXCLUDED_OWN_ITEM_SET[name]
end

local function GetSpellIconPath(name)
    return "panorama/images/spellicons/" .. name .. "_png.vtex_c"
end

local function GetItemIconPath(name)
    local icon = string.gsub(name, "^item_", "")
    return "panorama/images/items/" .. icon .. "_png.vtex_c"
end

local function GetHeroIconPath(unitName)
    return "panorama/images/heroes/icons/" .. unitName .. "_png.vtex_c"
end

local function IsSelectableAbility(ability)
    if not ability then return false end
    if SafeCall(Ability.IsPassive, ability) then return false end
    if SafeCall(Ability.IsHidden, ability) then return false end
    if SafeCall(Ability.IsToggle, ability) then return false end
    return true
end

local function IsTrackableEnemyAbility(ability)
    if not IsSelectableAbility(ability) then return false end

    local level = SafeCall(Ability.GetLevel, ability) or 0
    if level <= 0 then return false end

    return true
end

local function CollectHeroAbilities(hero)
    local out = {}
    local used = {}

    local function addAbility(ability)
        if not ability then return end
        local name = SafeCall(Ability.GetName, ability)
        if not IsValidAbilityName(name) then return end
        if used[name] then return end
        used[name] = true
        out[#out + 1] = ability
    end

    local count = SafeCall(NPC.GetAbilityCount, hero)
    if count and count > 0 then
        for i = 0, count - 1 do
            addAbility(SafeCall(NPC.GetAbilityByIndex, hero, i))
            addAbility(SafeCall(NPC.GetAbility, hero, i))
        end
    end

    if #out == 0 then
        for i = 0, 35 do
            addAbility(SafeCall(NPC.GetAbilityByIndex, hero, i))
            addAbility(SafeCall(NPC.GetAbility, hero, i))
        end
    end

    return out
end

local function CollectHeroItems(hero)
    local out = {}
    local used = {}

    for i = 0, 16 do
        local item = SafeCall(NPC.GetItemByIndex, hero, i)
        if item then
            local name = SafeCall(Ability.GetName, item)
            if IsValidItemName(name) and not used[name] then
                used[name] = true
                out[#out + 1] = item
            end
        end
    end

    return out
end

local function IsEnemyHero(localHero, hero)
    if not hero or hero == localHero then return false end
    if not SafeCall(NPC.IsHero, hero) then return false end

    local myTeam = SafeCall(Entity.GetTeamNum, localHero)
    local enemyTeam = SafeCall(Entity.GetTeamNum, hero)
    if myTeam == nil or enemyTeam == nil or myTeam == enemyTeam then
        return false
    end

    if SafeCall(NPC.IsIllusion, hero) then return false end
    if SafeCall(NPC.IsTempestDouble, hero) then return false end

    return true
end

local function GetEnemyHeroesAround(localHero, radius)
    local out = {}

    local teamType = Enum and Enum.TeamType and (Enum.TeamType.TEAM_ENEMY or Enum.TeamType.ENEMY)
    if Entity and Entity.GetHeroesInRadius and teamType then
        local around = SafeCall(Entity.GetHeroesInRadius, localHero, radius, teamType)
        if around and #around > 0 then
            return around
        end
    end

    local all = Heroes and Heroes.GetAll and (Heroes.GetAll() or {}) or {}
    local myPos = SafeCall(Entity.GetAbsOrigin, localHero)

    for i = 1, #all do
        local hero = all[i]
        if IsEnemyHero(localHero, hero) then
            if not myPos then
                out[#out + 1] = hero
            else
                local pos = SafeCall(Entity.GetAbsOrigin, hero)
                if pos then
                    local d = Dist(myPos, pos)
                    if d <= radius then
                        out[#out + 1] = hero
                    end
                end
            end
        end
    end

    return out
end

local function IsWidgetSelected(widget, name)
    local v = SafeCall(widget and widget.Get, widget, name)
    return v and true or false
end

local function BuildItemsForMulti(names, previousByName, iconFn, defaultFn)
    local items = {}

    for i = 1, #names do
        local name = names[i]
        local enabled = previousByName[name]
        if enabled == nil then
            enabled = defaultFn and defaultFn(name) or false
        end

        items[#items + 1] = {
            name,
            iconFn(name),
            enabled and true or false,
        }
    end

    return items
end

local function UpdateMultiSelect(fieldName, label, names, snapshot, iconFn, defaultFn)
    local widget = MENU[fieldName]
    if not widget then return end

    local previousByName = {}
    for i = 1, #snapshot do
        local old = snapshot[i]
        previousByName[old] = IsWidgetSelected(widget, old)
    end

    local items = BuildItemsForMulti(names, previousByName, iconFn, defaultFn)

    if widget.Update then
        widget:Update(items, true)
    elseif MENU.Root and MENU.Root.MultiSelect then
        local newWidget = MENU.Root:MultiSelect(label, items, true)
        if newWidget then
            if widget.Visible then SafeCall(widget.Visible, widget, false) end
            MENU[fieldName] = newWidget
            widget = newWidget
        end
    end

    if widget and widget.ToolTip then
        if fieldName == "EnemyDangerItems" then
            widget:ToolTip(L("tip_enemy_items"))
        end
    end
end

local function InitMenu()
    if MENU.initialized then
        return true
    end

    local function HasMethod(obj, methodName)
        return obj and type(obj[methodName]) == "function"
    end

    local function CreateChild(parent, name)
        if not HasMethod(parent, "Create") then
            return nil
        end
        return SafeCall(parent.Create, parent, name)
    end

    local MENU_TAB_NAME = "\u{1F608} Euphoria Disabler"
    local MENU_MAIN_GROUP_NAME = "Main Settings"

    local base = Menu.Find and Menu.Find("General", "Main")
    if not base and Menu.Create then
        local created = Menu.Create("General", "Main", MENU_TAB_NAME)
        if created and HasMethod(created, "Create") then
            base = Menu.Find and Menu.Find("General", "Main")
        else
            base = created
        end
    end
    if not base then
        return false
    end

    local tab = Menu.Find and Menu.Find("General", "Main", MENU_TAB_NAME)
    if not tab then
        tab = CreateChild(base, MENU_TAB_NAME)
    end
    if not tab then
        return false
    end

    local legacyTab = Menu.Find and Menu.Find("General", "Main", "Euphoria Disabler")
    if legacyTab and legacyTab ~= tab and legacyTab.Visible then
        SafeCall(legacyTab.Visible, legacyTab, false)
    end

    local gMain = Menu.Find and Menu.Find("General", "Main", MENU_TAB_NAME, MENU_MAIN_GROUP_NAME)
    if not gMain then
        gMain = CreateChild(tab, MENU_MAIN_GROUP_NAME)
    end
    if not gMain then
        gMain = tab
    end
    if not HasMethod(gMain, "Switch") then
        local fallback = CreateChild(gMain, MENU_MAIN_GROUP_NAME)
        if fallback and HasMethod(fallback, "Switch") then
            gMain = fallback
        end
    end
    if not HasMethod(gMain, "Switch") then
        return false
    end

    MENU.Root = gMain

    MENU.Enabled = gMain:Switch(L("menu_enable"), true)
    MENU.Enabled:Icon("\u{f00c}")
    MENU.Enabled:ToolTip("Auto-casts your disables on tracked enemy casts. Configure toggles in panel.")

    MENU.PanelEnabled = gMain:Switch(L("menu_show_panel"), true)
    if MENU.PanelEnabled and MENU.PanelEnabled.Icon then
        MENU.PanelEnabled:Icon("\u{f06e}")
    end

    MENU.AutoSpeedPriority = gMain:Switch(L("menu_auto_speed_priority"), true)
    if MENU.AutoSpeedPriority and MENU.AutoSpeedPriority.Icon then
        MENU.AutoSpeedPriority:Icon("\u{f0e7}")
    end

    MENU.ResizeHandlesNear = gMain:Switch(L("menu_resize_handles"), true)
    if MENU.ResizeHandlesNear and MENU.ResizeHandlesNear.Icon then
        MENU.ResizeHandlesNear:Icon("\u{f065}")
    end

    MENU.EnemyDangerItems = gMain:MultiSelect(L("menu_enemy_danger_items"), {}, true)
    if MENU.EnemyDangerItems and MENU.EnemyDangerItems.Icon then
        MENU.EnemyDangerItems:Icon("\u{f714}")
    end

    LoadPanelPosition()
    LoadPersistMaps()

    MENU.initialized = true
    return true
end

local function UpdateOwnControlMenus(hero, force)
    local abilityNames = {}
    local itemNames = {}

    local abilities = CollectHeroAbilities(hero)
    for i = 1, #abilities do
        local ability = abilities[i]
        local name = SafeCall(Ability.GetName, ability)
        if IsValidAbilityName(name) and IsSelectableAbility(ability) then
            abilityNames[#abilityNames + 1] = name
        end
    end

    local items = CollectHeroItems(hero)
    for i = 1, #items do
        local item = items[i]
        local name = SafeCall(Ability.GetName, item)
        if IsSelectableOwnItemName(name) then
            itemNames[#itemNames + 1] = name
        end
    end

    if force or not ArraysEqual(abilityNames, STATE.ownAbilitySnapshot) then
        STATE.ownAbilitySnapshot = CopyArray(abilityNames)
        STATE.ownAbilityNames = CopyArray(abilityNames)
    end

    if force or not ArraysEqual(itemNames, STATE.ownItemSnapshot) then
        STATE.ownItemSnapshot = CopyArray(itemNames)
        STATE.ownItemNames = CopyArray(itemNames)
    end
end

local function CollectEnemyAbilityNames(localHero)
    local danger = {}
    local other = {}
    local seenDanger = {}
    local seenOther = {}

    local enemies = Heroes and Heroes.GetAll and (Heroes.GetAll() or {}) or {}
    for i = 1, #enemies do
        local enemy = enemies[i]
        if IsEnemyHero(localHero, enemy) then
            local abilities = CollectHeroAbilities(enemy)
            for j = 1, #abilities do
                local ability = abilities[j]
                if IsTrackableEnemyAbility(ability) then
                    local name = SafeCall(Ability.GetName, ability)
                    if IsValidAbilityName(name) then
                        if DANGEROUS_ABILITY_SET[name] then
                            if not seenDanger[name] then
                                seenDanger[name] = true
                                danger[#danger + 1] = name
                            end
                        else
                            if not seenOther[name] then
                                seenOther[name] = true
                                other[#other + 1] = name
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(danger)
    table.sort(other)
    return danger, other
end

local function CollectDangerItemNames()
    local items = CopyArray(DANGEROUS_ITEM_LIST)
    table.sort(items)
    return items
end

local function CollectEnemyHeroNames(localHero)
    local names = {}
    local seen = {}
    local enemies = Heroes and Heroes.GetAll and (Heroes.GetAll() or {}) or {}
    for i = 1, #enemies do
        local enemy = enemies[i]
        if IsEnemyHero(localHero, enemy) then
            local name = SafeCall(NPC.GetUnitName, enemy)
            if name and not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end
        end
    end
    table.sort(names)
    return names
end

local function IsEnemyNameEnabled(name)
    if not name then
        return false
    end
    return ReadEnemyHeroEnabled(name)
end

local function SetEnemyNameEnabled(name, enabled)
    WriteEnemyHeroEnabled(name, enabled and true or false)
end

local function ToggleEnemyName(name)
    SetEnemyNameEnabled(name, not IsEnemyNameEnabled(name))
end

local function IsEnemyEntityEnabled(enemy)
    local name = SafeCall(NPC.GetUnitName, enemy)
    if not name then
        return true
    end
    return IsEnemyNameEnabled(name)
end

local function UpdateEnemyHeroSnapshot(localHero, force)
    local names = CollectEnemyHeroNames(localHero)
    if force or not ArraysEqual(names, STATE.enemyHeroSnapshot) then
        STATE.enemyHeroSnapshot = CopyArray(names)
        STATE.enemyHeroNames = CopyArray(names)
    end
end

local function UpdateEnemyTriggerMenus(localHero, force)
    UpdateEnemyHeroSnapshot(localHero, force)

    local dangerNames, otherNames = CollectEnemyAbilityNames(localHero)
    local itemNames = CollectDangerItemNames()

    if force or not ArraysEqual(dangerNames, STATE.enemyDangerSnapshot) then
        STATE.enemyDangerSnapshot = CopyArray(dangerNames)
        STATE.enemyDangerNames = CopyArray(dangerNames)
    end

    if force or not ArraysEqual(otherNames, STATE.enemyOtherSnapshot) then
        STATE.enemyOtherSnapshot = CopyArray(otherNames)
        STATE.enemyOtherNames = CopyArray(otherNames)
    end

    if force or not ArraysEqual(itemNames, STATE.enemyItemSnapshot) then
        UpdateMultiSelect(
            "EnemyDangerItems",
            L("menu_enemy_danger_items"),
            itemNames,
            STATE.enemyItemSnapshot,
            GetItemIconPath,
            function() return true end
        )
        STATE.enemyItemSnapshot = CopyArray(itemNames)
        STATE.enemyItemNames = CopyArray(itemNames)
    end
end

local function GetControlCastPoint(control)
    if not control or not control.handle then
        return 9.99
    end

    local castPoint = SafeCall(Ability.GetCastPoint, control.handle)
    if type(castPoint) ~= "number" then
        return 9.99
    end

    return math.max(0, castPoint)
end

local function SortControlIdsByCastSpeed(ids, byId)
    table.sort(ids, function(a, b)
        local ca = byId and byId[a] or nil
        local cb = byId and byId[b] or nil
        if not ca or not cb then
            return tostring(a or "") < tostring(b or "")
        end

        local pa = GetControlCastPoint(ca)
        local pb = GetControlCastPoint(cb)
        if math.abs(pa - pb) > 0.0001 then
            return pa < pb
        end

        local ra = SafeCall(Ability.GetCastRange, ca.handle) or 0
        local rb = SafeCall(Ability.GetCastRange, cb.handle) or 0
        if ra ~= rb then
            return ra > rb
        end

        if ca.kind ~= cb.kind then
            return ca.kind == "ability"
        end

        return tostring(ca.name or "") < tostring(cb.name or "")
    end)
end

local function SyncPriorityOrder(currentIds)
    local exists = {}
    for i = 1, #currentIds do
        exists[currentIds[i]] = true
    end

    local newOrder = {}
    local added = {}

    for i = 1, #STATE.priorityOrder do
        local id = STATE.priorityOrder[i]
        if exists[id] then
            newOrder[#newOrder + 1] = id
            added[id] = true
        end
    end

    for i = 1, #currentIds do
        local id = currentIds[i]
        if not added[id] then
            newOrder[#newOrder + 1] = id
            added[id] = true
        end
    end

    STATE.priorityOrder = newOrder

    if STATE.selectedPriorityId and not exists[STATE.selectedPriorityId] then
        STATE.selectedPriorityId = nil
    end

    if not STATE.selectedPriorityId and #newOrder > 0 then
        STATE.selectedPriorityId = newOrder[1]
    end
end

local function IsOwnControlPanelEnabled(id)
    return not STATE.ownControlPanelDisabled[id]
end

local function SetOwnControlPanelEnabled(id, enabled)
    if not id then
        return
    end

    LoadPersistMaps()

    if enabled then
        STATE.ownControlPanelDisabled[id] = nil
    else
        STATE.ownControlPanelDisabled[id] = true
    end

    local key = MakeOwnControlConfigKey(id)
    STATE.ownControlStateLoaded[key] = true
    STATE.persistOwnEnabled[key] = enabled and true or false
    SavePersistMap(CONFIG_SECTION_OWN_CONTROLS, STATE.persistOwnEnabled)
    WriteConfigInt(CONFIG_SECTION_OWN_CONTROLS, key, enabled and 1 or 0)
end

local function ToggleOwnControlPanelEnabled(id)
    SetOwnControlPanelEnabled(id, not IsOwnControlPanelEnabled(id))
end

local function BuildSelectedOwnControls(hero)
    local abilitiesByName = {}
    local itemsByName = {}

    local abilities = CollectHeroAbilities(hero)
    for i = 1, #abilities do
        local ability = abilities[i]
        local name = SafeCall(Ability.GetName, ability)
        if IsValidAbilityName(name) then
            abilitiesByName[name] = ability
        end
    end

    local items = CollectHeroItems(hero)
    for i = 1, #items do
        local item = items[i]
        local name = SafeCall(Ability.GetName, item)
        if IsSelectableOwnItemName(name) then
            itemsByName[name] = item
        end
    end

    local byId = {}
    local currentIds = {}

    for i = 1, #STATE.ownAbilityNames do
        local name = STATE.ownAbilityNames[i]
        local handle = abilitiesByName[name]
        if handle then
            local id = "ability:" .. name
            EnsureOwnControlPanelState(id)
            byId[id] = {
                id = id,
                kind = "ability",
                name = name,
                handle = handle,
                iconPath = GetSpellIconPath(name),
                panelEnabled = IsOwnControlPanelEnabled(id),
            }
            currentIds[#currentIds + 1] = id
        end
    end

    for i = 1, #STATE.ownItemNames do
        local name = STATE.ownItemNames[i]
        local handle = itemsByName[name]
        if handle then
            local id = "item:" .. name
            EnsureOwnControlPanelState(id)
            byId[id] = {
                id = id,
                kind = "item",
                name = name,
                handle = handle,
                iconPath = GetItemIconPath(name),
                panelEnabled = IsOwnControlPanelEnabled(id),
            }
            currentIds[#currentIds + 1] = id
        end
    end

    local autoSortBySpeed = MENU.AutoSpeedPriority and MENU.AutoSpeedPriority.Get and MENU.AutoSpeedPriority:Get()
    if autoSortBySpeed then
        SortControlIdsByCastSpeed(currentIds, byId)
        STATE.priorityOrder = CopyArray(currentIds)

        local exists = {}
        for i = 1, #currentIds do
            exists[currentIds[i]] = true
        end

        if STATE.selectedPriorityId and not exists[STATE.selectedPriorityId] then
            STATE.selectedPriorityId = nil
        end
        if not STATE.selectedPriorityId and #currentIds > 0 then
            STATE.selectedPriorityId = currentIds[1]
        end
    else
        SyncPriorityOrder(currentIds)
    end

    local ordered = {}
    for i = 1, #STATE.priorityOrder do
        local id = STATE.priorityOrder[i]
        local control = byId[id]
        if control then
            ordered[#ordered + 1] = control
        end
    end

    return ordered
end

local function IsHeroDisabled(hero)
    for i = 1, #BLOCKED_STATES do
        if SafeCall(NPC.HasState, hero, BLOCKED_STATES[i]) then
            return true
        end
    end

    return false
end

local function IsTargetAlreadyDisabled(target)
    for i = 1, #ALREADY_DISABLED_STATES do
        if SafeCall(NPC.HasState, target, ALREADY_DISABLED_STATES[i]) then
            return true
        end
    end

    return false
end

local function GetTargetUsageWindow()
    local baseMs = GetTargetMemoryMs()
    if IsRageMode() then
        baseMs = math.max(baseMs, 2500)
    end
    return baseMs / 1000
end

local function CleanupTargetUsage(now)
    local window = GetTargetUsageWindow()
    for targetIndex, usage in pairs(STATE.targetControlUsage) do
        if not usage or (now - (usage.lastTime or 0)) > window then
            STATE.targetControlUsage[targetIndex] = nil
        end
    end
end

local function GetTargetUsageCount(target, now)
    local targetIndex = SafeCall(Entity.GetIndex, target)
    if not targetIndex then
        return 0
    end

    local usage = STATE.targetControlUsage[targetIndex]
    if not usage then
        return 0
    end

    if (now - (usage.lastTime or 0)) > GetTargetUsageWindow() then
        STATE.targetControlUsage[targetIndex] = nil
        return 0
    end

    return usage.count or 0
end

local function RegisterTargetUsage(target, now)
    local targetIndex = SafeCall(Entity.GetIndex, target)
    if not targetIndex then
        return
    end

    local usage = STATE.targetControlUsage[targetIndex]
    if not usage or (now - (usage.lastTime or 0)) > GetTargetUsageWindow() then
        usage = { count = 0, lastTime = now }
    end

    usage.count = (usage.count or 0) + 1
    usage.lastTime = now
    STATE.targetControlUsage[targetIndex] = usage
end

local function GetEffectiveMaxControlsPerTarget(localHero)
    local maxControls = GetMaxControlsPerTarget()
    if maxControls < 1 then maxControls = 1 end

    if IsRageMode() then
        maxControls = math.max(maxControls, 3)
    elseif IsReserveForNearbyEnabled() then
        local enemies = GetEnemyHeroesAround(localHero, GetSearchRadius())
        local nearbyAlive = 0
        for i = 1, #enemies do
            if SafeCall(Entity.IsAlive, enemies[i]) and not SafeCall(Entity.IsDormant, enemies[i]) then
                nearbyAlive = nearbyAlive + 1
            end
        end

        if nearbyAlive >= 2 then
            maxControls = math.max(1, maxControls - 1)
        end
    end

    return maxControls
end

local function CanSpendControlOnTarget(localHero, target, now)
    local maxControls = GetEffectiveMaxControlsPerTarget(localHero)
    local usedControls = GetTargetUsageCount(target, now)
    return usedControls < maxControls
end

local function CanUseControl(hero, ability)
    if not ability then return false end

    if SafeCall(Ability.IsPassive, ability) then return false end
    if SafeCall(Ability.IsHidden, ability) then return false end
    if SafeCall(Ability.IsInAbilityPhase, ability) then return false end

    local cooldown = SafeCall(Ability.GetCooldown, ability) or 0
    if cooldown > 0 then return false end

    local mana = SafeCall(NPC.GetMana, hero) or 0
    if not SafeCall(Ability.IsCastable, ability, mana) then return false end

    local maxCharges = SafeCall(Ability.GetMaxCharges, ability)
    if maxCharges and maxCharges > 0 then
        local charges = SafeCall(Ability.GetCurrentCharges, ability) or 0
        if charges <= 0 then
            return false
        end
    end

    return true
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

local function HasAbilityBehavior(ability, names)
    local behaviorMask = SafeCall(Ability.GetBehavior, ability)
    if not behaviorMask or behaviorMask == 0 then
        return false
    end

    for i = 1, #names do
        local flag = GetAbilityBehaviorFlag(names[i])
        if flag and flag ~= 0 then
            if BitAnd(behaviorMask, flag) ~= 0 then
                return true
            end
        end
    end

    return false
end

local function ResolveControlCastMode(ability)
    if HasAbilityBehavior(ability, { "UNIT_TARGET", "OPTIONAL_UNIT_TARGET" }) then
        return "target"
    end

    if HasAbilityBehavior(ability, { "POINT", "OPTIONAL_POINT", "VECTOR_TARGETING", "DIRECTIONAL" }) then
        return "position"
    end

    if HasAbilityBehavior(ability, { "NO_TARGET" }) then
        return "notarget"
    end

    local targetType = SafeCall(Ability.GetTargetType, ability) or 0
    if targetType ~= 0 then
        return "target"
    end

    local castRange = SafeCall(Ability.GetCastRange, ability) or 0
    local aoeRadius = SafeCall(Ability.GetAOERadius, ability) or 0
    if castRange > 0 or aoeRadius > 0 then
        return "position"
    end

    return "notarget"
end

local function CastCallSucceeded(ok, result)
    if not ok then return false end
    if result == false then return false end
    return true
end

local function ConfirmCast(ability, cooldownBefore, phaseBefore, callResult)
    local phaseAfter = SafeCall(Ability.IsInAbilityPhase, ability) and true or false
    if phaseAfter and not phaseBefore then
        return true
    end

    local cooldownAfter = SafeCall(Ability.GetCooldown, ability) or 0
    if cooldownAfter > cooldownBefore + 0.01 then
        return true
    end

    if callResult == true then
        return true
    end

    return false
end

local function TryCastTarget(ability, target)
    local cdBefore = SafeCall(Ability.GetCooldown, ability) or 0
    local phaseBefore = SafeCall(Ability.IsInAbilityPhase, ability) and true or false

    local ok, result = pcall(Ability.CastTarget, ability, target, false, false, false, SCRIPT_ID)
    if CastCallSucceeded(ok, result) and ConfirmCast(ability, cdBefore, phaseBefore, result) then
        return true
    end

    cdBefore = SafeCall(Ability.GetCooldown, ability) or 0
    phaseBefore = SafeCall(Ability.IsInAbilityPhase, ability) and true or false
    ok, result = pcall(Ability.CastTarget, ability, target)
    if CastCallSucceeded(ok, result) and ConfirmCast(ability, cdBefore, phaseBefore, result) then
        return true
    end

    return false
end

local function TryCastPosition(ability, pos)
    local cdBefore = SafeCall(Ability.GetCooldown, ability) or 0
    local phaseBefore = SafeCall(Ability.IsInAbilityPhase, ability) and true or false

    local ok, result = pcall(Ability.CastPosition, ability, pos, false, false, false, SCRIPT_ID)
    if CastCallSucceeded(ok, result) and ConfirmCast(ability, cdBefore, phaseBefore, result) then
        return true
    end

    cdBefore = SafeCall(Ability.GetCooldown, ability) or 0
    phaseBefore = SafeCall(Ability.IsInAbilityPhase, ability) and true or false
    ok, result = pcall(Ability.CastPosition, ability, pos)
    if CastCallSucceeded(ok, result) and ConfirmCast(ability, cdBefore, phaseBefore, result) then
        return true
    end

    return false
end

local function TryCastNoTarget(ability)
    local cdBefore = SafeCall(Ability.GetCooldown, ability) or 0
    local phaseBefore = SafeCall(Ability.IsInAbilityPhase, ability) and true or false

    local ok, result = pcall(Ability.CastNoTarget, ability, false, false, false, SCRIPT_ID)
    if CastCallSucceeded(ok, result) and ConfirmCast(ability, cdBefore, phaseBefore, result) then
        return true
    end

    cdBefore = SafeCall(Ability.GetCooldown, ability) or 0
    phaseBefore = SafeCall(Ability.IsInAbilityPhase, ability) and true or false
    ok, result = pcall(Ability.CastNoTarget, ability)
    if CastCallSucceeded(ok, result) and ConfirmCast(ability, cdBefore, phaseBefore, result) then
        return true
    end

    return false
end

local function HasTargetState(target, stateNameA, stateNameB)
    local ms = Enum and Enum.ModifierState
    if not ms then
        return false
    end

    local state = ms[stateNameA] or ms[stateNameB]
    if not state then
        return false
    end

    return SafeCall(NPC.HasState, target, state) and true or false
end

local function HasAnyModifier(target, list)
    for i = 1, #list do
        if SafeCall(NPC.HasModifier, target, list[i]) then
            return true
        end
    end
    return false
end

local ResolveControlSmartRole

local function IsControlUsefulOnTarget(control, target)
    if not control or not target then
        return false
    end

    local role = ResolveControlSmartRole and ResolveControlSmartRole(control) or nil
    local magicImmune = HasTargetState(target, "MODIFIER_STATE_MAGIC_IMMUNE", "MAGIC_IMMUNE")

    if role == "silence" then
        if magicImmune then
            return false
        end
        return not HasTargetState(target, "MODIFIER_STATE_SILENCED", "SILENCED")
    end
    if role == "hex" then
        if magicImmune and control.name ~= "item_abyssal_blade" then
            return false
        end
        return not HasTargetState(target, "MODIFIER_STATE_HEXED", "HEXED")
    end
    if role == "root" then
        if magicImmune then
            return false
        end
        return not HasTargetState(target, "MODIFIER_STATE_ROOTED", "ROOTED")
    end
    if role == "cyclone" then
        if magicImmune then
            return false
        end
        if SafeCall(NPC.HasModifier, target, "modifier_eul_cyclone") then return false end
        if SafeCall(NPC.HasModifier, target, "modifier_item_wind_waker") then return false end
        return true
    end
    if role == "nullifier" then
        return HasAnyModifier(target, NULLIFIER_PRIORITY_MODIFIERS)
    end

    if control.kind ~= "item" and magicImmune then
        return control.name == "faceless_void_chronosphere" or control.name == "beastmaster_primal_roar"
    end

    if IsIgnoreDisabledTargetsEnabled() and (not IsRageMode()) and IsTargetAlreadyDisabled(target) then
        return false
    end

    return true
end

local function GetPredictedTargetPos(target, delay)
    local targetPos = SafeCall(Entity.GetAbsOrigin, target)
    if not targetPos then
        return nil
    end

    if delay <= 0 then
        return targetPos
    end

    local moving = SafeCall(NPC.IsMoving, target)
    if not moving then
        return targetPos
    end

    local dir = SafeCall(NPC.GetForwardVector, target)
    dir = Normalize2D(dir)
    if not dir then
        return targetPos
    end

    local speed = SafeCall(NPC.GetMoveSpeed, target)
        or SafeCall(NPC.GetBaseMoveSpeed, target)
        or 300
    local travel = (speed or 300) * delay

    return MakeVec3(
        (targetPos.x or 0) + (dir.x or 0) * travel,
        (targetPos.y or 0) + (dir.y or 0) * travel,
        targetPos.z or 0
    )
end

local function FindBestAllyBlinkTarget(hero, enemy, castRange)
    local allies = Heroes and Heroes.GetAll and (Heroes.GetAll() or {}) or {}
    local heroPos = SafeCall(Entity.GetAbsOrigin, hero)
    local enemyPos = SafeCall(Entity.GetAbsOrigin, enemy)
    if not heroPos or not enemyPos then
        return nil
    end

    local team = SafeCall(Entity.GetTeamNum, hero)
    local best = nil
    local bestScore = -100000

    for i = 1, #allies do
        local ally = allies[i]
        if ally and ally ~= hero then
            if SafeCall(NPC.IsHero, ally)
                and SafeCall(Entity.IsAlive, ally)
                and not SafeCall(Entity.IsDormant, ally)
                and SafeCall(Entity.GetTeamNum, ally) == team then
                local allyPos = SafeCall(Entity.GetAbsOrigin, ally)
                if allyPos then
                    local distFromHero = Dist(heroPos, allyPos)
                    if distFromHero <= castRange + 75 then
                        local allyEnemyDist = Dist(allyPos, enemyPos)
                        local heroEnemyDist = Dist(heroPos, enemyPos)
                        local score = allyEnemyDist - (distFromHero * 0.25)
                        if allyEnemyDist > heroEnemyDist + 200 and score > bestScore then
                            bestScore = score
                            best = allyPos
                        end
                    end
                end
            end
        end
    end

    return best
end

local function GetSmartBlinkPos(hero, target, castRange)
    local heroPos = SafeCall(Entity.GetAbsOrigin, hero)
    local targetPos = SafeCall(Entity.GetAbsOrigin, target)
    if not heroPos or not targetPos then
        return nil
    end

    local effectiveRange = castRange
    if effectiveRange <= 0 then
        effectiveRange = 1200
    end
    effectiveRange = math.min(effectiveRange, 1200)

    local allyPos = FindBestAllyBlinkTarget(hero, target, effectiveRange)
    if allyPos then
        return allyPos
    end

    local fountainPos = GetFountainPosByTeam(SafeCall(Entity.GetTeamNum, hero))
    if fountainPos then
        local dirToFountain = Dir2D(heroPos, fountainPos)
        if dirToFountain then
            local dist = math.min(effectiveRange * 0.95, Dist(heroPos, fountainPos))
            return MakeVec3(
                (heroPos.x or 0) + (dirToFountain.x or 0) * dist,
                (heroPos.y or 0) + (dirToFountain.y or 0) * dist,
                heroPos.z or 0
            )
        end
    end

    local away = Dir2D(targetPos, heroPos)
    if away then
        return MakeVec3(
            (heroPos.x or 0) + (away.x or 0) * (effectiveRange * 0.9),
            (heroPos.y or 0) + (away.y or 0) * (effectiveRange * 0.9),
            heroPos.z or 0
        )
    end

    return nil
end

ResolveControlSmartRole = function(control)
    if not control or not control.name then
        return nil
    end

    if control.kind == "item" then
        return ITEM_SMART_ROLE[control.name]
    end

    local direct = ABILITY_SMART_ROLE[control.name]
    if direct then
        return direct
    end

    if string.find(control.name, "blink", 1, true) then
        return "blink"
    end

    local low = string.lower(control.name)
    for i = 1, #ABILITY_ROLE_TOKENS do
        local hint = ABILITY_ROLE_TOKENS[i]
        if string.find(low, hint.token, 1, true) then
            return hint.role
        end
    end

    return nil
end

local function TrySmartControlCast(hero, control, target, distance, castRange)
    local role = ResolveControlSmartRole(control)
    if not role then
        return nil
    end

    if role == "blink" then
        if distance <= 180 then
            return false, false
        end

        local blinkPos = GetSmartBlinkPos(hero, target, castRange)
        if not blinkPos then
            return false, false
        end
        return TryCastPosition(control.handle, blinkPos), true
    end

    if role == "force" then
        if distance > castRange + 75 then
            return false, false
        end

        local targetDormant = SafeCall(Entity.IsDormant, target) and true or false
        if not targetDormant and IsRageMode() and distance > 520 then
            return TryCastTarget(control.handle, target), true
        end
        return TryCastTarget(control.handle, hero), true
    end

    if role == "self_defense" then
        return TryCastNoTarget(control.handle), true
    end

    if role == "escape_line" then
        local castPos = GetSmartBlinkPos(hero, target, castRange)
        if castPos then
            return TryCastPosition(control.handle, castPos), true
        end
        return false, false
    end

    return nil
end

local function IsUsableTargetControlForLinkens(hero, control, target)
    if not hero or not control or not control.handle or not target then
        return false
    end

    if not CanUseControl(hero, control.handle) then
        return false
    end

    local mode = ResolveControlCastMode(control.handle)
    if mode ~= "target" then
        return false
    end

    local role = ResolveControlSmartRole(control)
    if role == "blink" or role == "force" or role == "self_defense" or role == "escape_line" then
        return false
    end

    if SafeCall(Entity.IsDormant, target) then
        return false
    end

    local heroPos = SafeCall(Entity.GetAbsOrigin, hero)
    local targetPos = SafeCall(Entity.GetAbsOrigin, target)
    if not heroPos or not targetPos then
        return false
    end

    local castRange = (SafeCall(Ability.GetCastRange, control.handle) or 0) + (SafeCall(NPC.GetCastRangeBonus, hero) or 0)
    if castRange <= 0 then
        castRange = 600
    end

    return Dist(heroPos, targetPos) <= castRange + 75
end

local function GetLinkensBreakerCost(control)
    if not control or not control.name then
        return 999
    end

    local role = ResolveControlSmartRole(control)
    local base
    if control.kind == "item" then
        base = LINKENS_BREAK_ITEM_PRIORITY[control.name] or 60
    else
        base = LINKENS_BREAK_ABILITY_PRIORITY[control.name] or 95
    end

    if role == "silence" then
        base = base + 4
    elseif role == "root" then
        base = base + 8
    elseif role == "stun" then
        base = base + 16
    elseif role == "hex" then
        base = base + 24
    elseif role == "cyclone" then
        base = base + 90
    end

    local castPoint = SafeCall(Ability.GetCastPoint, control.handle) or 0
    base = base + math.max(0, castPoint) * 45

    return base
end

local function FindBestLinkensBreaker(hero, controls, target)
    local bestControl = nil
    local bestCost = 100000

    for i = 1, #controls do
        local control = controls[i]
        if control and control.panelEnabled ~= false and IsUsableTargetControlForLinkens(hero, control, target) then
            local cost = GetLinkensBreakerCost(control)
            if cost < bestCost then
                bestCost = cost
                bestControl = control
            end
        end
    end

    return bestControl
end

local function Dot2D(a, b)
    if not a or not b then
        return 0
    end
    return (a.x or 0) * (b.x or 0) + (a.y or 0) * (b.y or 0)
end

local function ComputeEnemyThreatScore(localHero, enemy, severity, isInstant, triggerName, now)
    local score = (severity or 0) * THREAT_WEIGHTS.severity
    if isInstant then
        score = score + THREAT_WEIGHTS.instantBonus
    end

    if triggerName then
        if triggerName == "channel" then
            score = score + THREAT_WEIGHTS.triggerChannel
        elseif triggerName == "reveal" then
            score = score + THREAT_WEIGHTS.triggerReveal
        elseif triggerName == "linkens_followup" then
            score = score + THREAT_WEIGHTS.triggerLinkensFollowup
        elseif DANGEROUS_ABILITY_SET[triggerName] then
            score = score + THREAT_WEIGHTS.dangerousAbility
        elseif DANGEROUS_ITEM_SET[triggerName] then
            score = score + THREAT_WEIGHTS.dangerousItem
        end
    end

    if SafeCall(NPC.IsChannelling, enemy) then
        score = score + THREAT_WEIGHTS.channeling
    end

    local myPos = SafeCall(Entity.GetAbsOrigin, localHero)
    local enemyPos = SafeCall(Entity.GetAbsOrigin, enemy)
    if myPos and enemyPos then
        local dist = Dist(myPos, enemyPos)
        score = score + math.max(0, (1200 - dist) * THREAT_WEIGHTS.distanceScale)
        if dist <= 500 then
            score = score + THREAT_WEIGHTS.close500
        elseif dist <= 800 then
            score = score + THREAT_WEIGHTS.close800
        elseif dist <= 1100 then
            score = score + THREAT_WEIGHTS.close1100
        end

        local enemyForward = Normalize2D(SafeCall(NPC.GetForwardVector, enemy))
        local toMe = Dir2D(enemyPos, myPos)
        if enemyForward and toMe and Dot2D(enemyForward, toMe) > 0.80 then
            score = score + THREAT_WEIGHTS.facing
        end
    end

    local myHp = SafeCall(Entity.GetHealth, localHero) or 0
    local myMaxHp = SafeCall(Entity.GetMaxHealth, localHero) or 0
    if myMaxHp > 0 then
        local hpPct = myHp / myMaxHp
        if hpPct < 0.45 then
            score = score + severity * THREAT_WEIGHTS.lowHpPerSeverity
            if myPos and enemyPos and Dist(myPos, enemyPos) <= 700 then
                score = score + THREAT_WEIGHTS.lowHpClose
            end
        end
    end

    local used = GetTargetUsageCount(enemy, now)
    score = score - (used * THREAT_WEIGHTS.usedPenalty)

    return score
end

local function TryCastControl(hero, control, target, allowCastIntoLinkens)
    if not control or not control.handle or not target then
        return false, false
    end

    local heroPos = SafeCall(Entity.GetAbsOrigin, hero)
    local targetPos = SafeCall(Entity.GetAbsOrigin, target)
    if not heroPos or not targetPos then
        return false, false
    end

    local distance = Dist(heroPos, targetPos)
    local castRange = (SafeCall(Ability.GetCastRange, control.handle) or 0) + (SafeCall(NPC.GetCastRangeBonus, hero) or 0)
    local aoeRadius = SafeCall(Ability.GetAOERadius, control.handle) or 0
    local rangeForPosition = castRange
    if aoeRadius > rangeForPosition then
        rangeForPosition = aoeRadius
    end
    if rangeForPosition <= 0 then
        rangeForPosition = 550
    end

    local skipTarget = false
    if (not allowCastIntoLinkens) and (not IsCastIntoLinkensEnabled()) and SafeCall(NPC.IsLinkensProtected, target) then
        skipTarget = true
    end

    local forceLinkensBreaker = allowCastIntoLinkens and SafeCall(NPC.IsLinkensProtected, target)
    if (not forceLinkensBreaker) and (not IsControlUsefulOnTarget(control, target)) then
        return false, false
    end

    local smartResultCast, smartResultAttempt = TrySmartControlCast(hero, control, target, distance, castRange)
    if smartResultCast ~= nil then
        return smartResultCast, smartResultAttempt
    end

    local mode = ResolveControlCastMode(control.handle)
    local targetDormant = SafeCall(Entity.IsDormant, target) and true or false

    if mode == "target" then
        if targetDormant then
            return false, false
        end

        if skipTarget then
            return false, false
        end

        if distance > castRange + 75 then
            return false, false
        end

        return TryCastTarget(control.handle, target), true
    end

    if mode == "position" then
        if distance > rangeForPosition + 75 then
            return false, false
        end

        local castPoint = SafeCall(Ability.GetCastPoint, control.handle) or 0
        local predictedPos = GetPredictedTargetPos(target, castPoint + 0.12) or targetPos
        return TryCastPosition(control.handle, predictedPos), true
    end

    if distance > rangeForPosition + 75 then
        return false, false
    end

    return TryCastNoTarget(control.handle), true
end

local function ScoreControlForTarget(hero, target, control, orderIndex, controlCount, triggerName, isInstant, now)
    if not control or not control.handle then
        return -100000
    end

    local heroPos = SafeCall(Entity.GetAbsOrigin, hero)
    local targetPos = SafeCall(Entity.GetAbsOrigin, target)
    if not heroPos or not targetPos then
        return -100000
    end

    local distance = Dist(heroPos, targetPos)
    local mode = ResolveControlCastMode(control.handle)
    local role = ResolveControlSmartRole(control)
    local roleWeight = CONTROL_ROLE_WEIGHTS[role] or 185
    local castPoint = math.max(0, GetControlCastPoint(control))
    local score = roleWeight

    local priorityWeight = math.max(0, (controlCount - (orderIndex or 1))) * 72
    score = score + priorityWeight

    score = score - (castPoint * 250)
    if isInstant then
        score = score - (castPoint * 220)
    end

    if triggerName == "channel" then
        if role == "stun" or role == "hex" or role == "silence" or role == "cyclone" then
            score = score + 320
        else
            score = score - 120
        end
    elseif triggerName == "reveal" then
        if role == "stun" or role == "hex" or role == "cyclone" then
            score = score + 150
        end
    elseif triggerName == "linkens_followup" then
        if role == "hex" or role == "stun" then
            score = score + 260
        elseif role == "silence" or role == "root" then
            score = score + 170
        end
    end

    local castRange = (SafeCall(Ability.GetCastRange, control.handle) or 0) + (SafeCall(NPC.GetCastRangeBonus, hero) or 0)
    local aoeRadius = SafeCall(Ability.GetAOERadius, control.handle) or 0
    local rangeForPosition = castRange
    if aoeRadius > rangeForPosition then
        rangeForPosition = aoeRadius
    end
    if rangeForPosition <= 0 then
        rangeForPosition = 550
    end

    if mode == "target" then
        if SafeCall(Entity.IsDormant, target) then
            score = score - 1400
        end

        local maxRange = castRange
        if maxRange <= 0 then
            maxRange = 600
        end
        if distance > maxRange + 75 then
            score = score - 900
        else
            score = score + math.max(0, 180 - (distance * 0.11))
        end
    elseif mode == "position" then
        if distance > rangeForPosition + 75 then
            score = score - 650
        else
            score = score + math.max(0, 120 - (distance * 0.06))
        end
    else
        if distance > rangeForPosition + 75 then
            score = score - 250
        else
            score = score + 35
        end
    end

    if role == "nullifier" and not HasAnyModifier(target, NULLIFIER_PRIORITY_MODIFIERS) then
        score = score - 260
    end

    if role == "blink" or role == "force" or role == "self_defense" or role == "escape_line" then
        local myHp = SafeCall(Entity.GetHealth, hero) or 0
        local myMaxHp = SafeCall(Entity.GetMaxHealth, hero) or 0
        local hpPct = (myMaxHp > 0) and (myHp / myMaxHp) or 1
        if hpPct < 0.55 then
            score = score + 220
        else
            score = score - 90
        end

        if distance <= 550 then
            score = score + 160
        else
            score = score - 45
        end
    end

    local magicImmune = HasTargetState(target, "MODIFIER_STATE_MAGIC_IMMUNE", "MAGIC_IMMUNE")
    if magicImmune then
        if role == "silence" or role == "root" or role == "hex" or role == "cyclone" then
            score = score - 1300
        elseif control.kind == "ability" and role == nil then
            score = score - 320
        end
    end

    if IsTargetAlreadyDisabled(target) and triggerName ~= "linkens_followup" then
        if role == "hex" or role == "stun" then
            score = score - 140
        else
            score = score - 220
        end

        if (not isInstant) and (now - (STATE.lastCastTime or 0)) < 0.30 then
            score = score - 300
        end
    end

    return score
end

local function BuildSmartControlSequence(hero, target, controls, triggerName, isInstant, now)
    local pool = {}
    local count = #controls
    for i = 1, count do
        local control = controls[i]
        if control
            and control.panelEnabled ~= false
            and CanUseControl(hero, control.handle)
            and IsControlUsefulOnTarget(control, target) then
            local score = ScoreControlForTarget(hero, target, control, i, count, triggerName, isInstant, now)
            pool[#pool + 1] = {
                control = control,
                score = score,
                order = i,
            }
        end
    end

    table.sort(pool, function(a, b)
        if math.abs((a.score or 0) - (b.score or 0)) > 0.01 then
            return (a.score or 0) > (b.score or 0)
        end
        return (a.order or 0) < (b.order or 0)
    end)

    local sequence = {}
    for i = 1, #pool do
        sequence[#sequence + 1] = pool[i].control
    end
    return sequence
end

local function IsEnemyAbilitySelected(name)
    local enabled = ReadEnemyAbilityEnabled(name)
    if not enabled then
        return false, 0
    end
    return true, DANGEROUS_ABILITY_SET[name] and 3 or 1
end

local function SetEnemyAbilitySelected(name, enabled)
    if not name then
        return
    end
    WriteEnemyAbilityEnabled(name, enabled and true or false)
end

local function ToggleEnemyAbilitySelected(name)
    local enabled = ReadEnemyAbilityEnabled(name)
    SetEnemyAbilitySelected(name, not enabled)
end

local function IsEnemyItemSelected(name)
    if not MENU.EnemyDangerItems then
        return true
    end
    return IsWidgetSelected(MENU.EnemyDangerItems, name)
end

local function IsEnemyValidTarget(localHero, enemy, allowDormant, allowDisabledIgnore)
    if not IsEnemyHero(localHero, enemy) then return false end
    if not IsEnemyEntityEnabled(enemy) then return false end
    if not SafeCall(Entity.IsAlive, enemy) then return false end
    if SafeCall(Entity.IsDormant, enemy) and not allowDormant then return false end

    local ms = Enum and Enum.ModifierState
    if ms then
        if SafeCall(NPC.HasState, enemy, ms.MODIFIER_STATE_INVULNERABLE or ms.INVULNERABLE) then return false end
        if SafeCall(NPC.HasState, enemy, ms.MODIFIER_STATE_OUT_OF_GAME or ms.OUT_OF_GAME) then return false end
    end

    if not IsRageMode() and (not allowDisabledIgnore) and IsIgnoreDisabledTargetsEnabled() and IsTargetAlreadyDisabled(enemy) then
        return false
    end

    return true
end

local RegisterInstantEnemyCast

local function IsAggressiveReveal(localHero, enemy, cache, myPos, enemyPos, now)
    if not cache or not myPos or not enemyPos then
        return false, 0
    end

    local distToMe = Dist(myPos, enemyPos)
    if distToMe > 900 then
        return false, 0
    end

    local hiddenSince = cache.hiddenSince or cache.lastVisibleTime or now
    local hiddenFor = math.max(0, now - (hiddenSince or now))
    if hiddenFor < 0.24 then
        return false, 0
    end

    local enemyForward = Normalize2D(SafeCall(NPC.GetForwardVector, enemy))
    local toMe = Dir2D(enemyPos, myPos)
    local facingMe = false
    if enemyForward and toMe then
        local dot = (enemyForward.x or 0) * (toMe.x or 0) + (enemyForward.y or 0) * (toMe.y or 0)
        facingMe = dot > 0.76
    end

    local movingToMe = (SafeCall(NPC.IsMoving, enemy) and true or false) and facingMe

    local blinkLikeDive = false
    if cache.lastVisiblePos and cache.lastVisibleTime and cache.lastVisibleTime > 0 then
        local shiftDist = Dist(cache.lastVisiblePos, enemyPos)
        local hiddenTimeFromLastSeen = math.max(0.05, now - cache.lastVisibleTime)
        local maxWalkDist = hiddenTimeFromLastSeen * 500
        local excessShift = shiftDist - maxWalkDist
        blinkLikeDive = (excessShift > 220) and (distToMe <= 900)
    end

    local chargeReveal = movingToMe and distToMe <= 500 and hiddenFor <= 1.25
    if not blinkLikeDive and not chargeReveal then
        return false, 0
    end

    if blinkLikeDive then
        return true, 5
    end

    return true, 4
end

local function UpdateEnemyRevealThreats(localHero, now)
    local myPos = SafeCall(Entity.GetAbsOrigin, localHero)
    if not myPos then
        return
    end

    local enemies = Heroes and Heroes.GetAll and (Heroes.GetAll() or {}) or {}
    local aliveIndexes = {}

    for i = 1, #enemies do
        local enemy = enemies[i]
        if IsEnemyHero(localHero, enemy) and IsEnemyEntityEnabled(enemy) then
            local idx = SafeCall(Entity.GetIndex, enemy)
            if idx then
                aliveIndexes[idx] = true
                local cache = STATE.enemyRevealThreatCache[idx] or {
                    visible = false,
                    lastTrigger = 0,
                    initialized = false,
                    lastVisiblePos = nil,
                    lastVisibleTime = 0,
                    hiddenSince = 0,
                }

                local visible = SafeCall(Entity.IsAlive, enemy) and (not SafeCall(Entity.IsDormant, enemy))
                if cache.initialized and cache.visible and (not visible) then
                    cache.hiddenSince = now
                end

                if cache.initialized and visible and not cache.visible then
                    local enemyPos = SafeCall(Entity.GetAbsOrigin, enemy)
                    if enemyPos then
                        local isThreat, revealSeverity = IsAggressiveReveal(localHero, enemy, cache, myPos, enemyPos, now)
                        if isThreat and (now - (cache.lastTrigger or 0)) > 1.2 then
                            RegisterInstantEnemyCast(enemy, "reveal", revealSeverity, now)
                            cache.lastTrigger = now
                        end
                    end
                end

                if visible then
                    local pos = SafeCall(Entity.GetAbsOrigin, enemy)
                    if pos then
                        cache.lastVisiblePos = MakeVec3(pos.x or 0, pos.y or 0, pos.z or 0)
                        cache.lastVisibleTime = now
                    end
                end

                cache.visible = visible and true or false
                cache.initialized = true
                STATE.enemyRevealThreatCache[idx] = cache
            end
        end
    end

    for idx, _ in pairs(STATE.enemyRevealThreatCache) do
        if not aliveIndexes[idx] then
            STATE.enemyRevealThreatCache[idx] = nil
        end
    end
end

RegisterInstantEnemyCast = function(enemy, triggerName, severity, now)
    local idx = SafeCall(Entity.GetIndex, enemy)
    if not idx then
        return
    end

    STATE.instantEnemyCasts[idx] = {
        untilTime = now + 0.45,
        triggerName = triggerName or "cast",
        severity = severity or 5,
    }
end

local function RegisterLinkensFollowupTarget(enemy, now, triggerName)
    local idx = SafeCall(Entity.GetIndex, enemy)
    if not idx then
        return
    end

    STATE.linkensFollowupTargets[idx] = {
        untilTime = now + 1.15,
        triggerName = triggerName or "linkens_followup",
        severity = 7,
        castsLeft = 1,
    }
end

local function CleanupLinkensFollowupTargets(now)
    for idx, data in pairs(STATE.linkensFollowupTargets) do
        if not data or now > (data.untilTime or 0) or (data.castsLeft or 0) <= 0 then
            STATE.linkensFollowupTargets[idx] = nil
        end
    end
end

local function GetLinkensFollowupTarget(enemy, now)
    local idx = SafeCall(Entity.GetIndex, enemy)
    if not idx then
        return 0, nil
    end

    local data = STATE.linkensFollowupTargets[idx]
    if not data then
        return 0, nil
    end

    if now > (data.untilTime or 0) or (data.castsLeft or 0) <= 0 then
        STATE.linkensFollowupTargets[idx] = nil
        return 0, nil
    end

    return data.severity or 0, data.triggerName
end

local function ConsumeLinkensFollowupTarget(enemy)
    local idx = SafeCall(Entity.GetIndex, enemy)
    if not idx then
        return
    end

    local data = STATE.linkensFollowupTargets[idx]
    if not data then
        return
    end

    data.castsLeft = math.max(0, (data.castsLeft or 1) - 1)
    if (data.castsLeft or 0) <= 0 then
        STATE.linkensFollowupTargets[idx] = nil
    else
        STATE.linkensFollowupTargets[idx] = data
    end
end

local function CleanupInstantEnemyCasts(now)
    for idx, data in pairs(STATE.instantEnemyCasts) do
        if not data or now > (data.untilTime or 0) then
            STATE.instantEnemyCasts[idx] = nil
        end
    end
end

local function GetInstantEnemyCast(enemy, now)
    local idx = SafeCall(Entity.GetIndex, enemy)
    if not idx then
        return 0, nil
    end

    local data = STATE.instantEnemyCasts[idx]
    if not data then
        return 0, nil
    end

    if now > (data.untilTime or 0) then
        STATE.instantEnemyCasts[idx] = nil
        return 0, nil
    end

    return data.severity or 0, data.triggerName
end

local function ScanEnemyTrigger(enemy)
    local bestSeverity = 0
    local bestName = nil

    if IsInterruptAnyChannelEnabled() and SafeCall(NPC.IsChannelling, enemy) then
        local channelAbility = SafeCall(NPC.GetChannellingAbility, enemy)
        local channelName = channelAbility and SafeCall(Ability.GetName, channelAbility) or "channel"
        bestSeverity = 4
        bestName = channelName or "channel"
    end

    local abilities = CollectHeroAbilities(enemy)
    for i = 1, #abilities do
        local ability = abilities[i]
        if IsTrackableEnemyAbility(ability) then
            if SafeCall(Ability.IsInAbilityPhase, ability) or SafeCall(Ability.IsChannelling, ability) then
                local name = SafeCall(Ability.GetName, ability)
                if IsValidAbilityName(name) then
                    local enabled, severity = IsEnemyAbilitySelected(name)
                    if enabled and severity > bestSeverity then
                        bestSeverity = severity
                        bestName = name
                    end
                end
            end
        end
    end

    local items = CollectHeroItems(enemy)
    for i = 1, #items do
        local item = items[i]
        local itemName = SafeCall(Ability.GetName, item)
        if DANGEROUS_ITEM_SET[itemName] and IsEnemyItemSelected(itemName) then
            local activeCast = SafeCall(Ability.IsInAbilityPhase, item) or SafeCall(Ability.IsChannelling, item)
            local activeBuff = false
            if IsReactToItemModifiersEnabled() then
                local modifierName = DANGEROUS_ITEM_MODIFIERS[itemName]
                if modifierName then
                    activeBuff = SafeCall(NPC.HasModifier, enemy, modifierName) and true or false
                end
            end

            if activeCast or activeBuff then
                if 2 > bestSeverity then
                    bestSeverity = 2
                    bestName = itemName
                end
            end
        end
    end

    return bestSeverity, bestName
end

local function FindTriggeredEnemy(localHero, now)
    local radius = GetSearchRadius()
    local enemies = GetEnemyHeroesAround(localHero, radius)

    local bestTarget = nil
    local bestScore = -100000
    local bestTrigger = nil
    local bestInstant = false

    for i = 1, #enemies do
        local enemy = enemies[i]
        local instantSeverity, instantTrigger = GetInstantEnemyCast(enemy, now)
        local followupSeverity, followupTrigger = GetLinkensFollowupTarget(enemy, now)
        local allowDormant = instantSeverity > 0
        local allowDisabledIgnore = followupSeverity > 0
        if IsEnemyValidTarget(localHero, enemy, allowDormant, allowDisabledIgnore) then
            local severity, trigger = ScanEnemyTrigger(enemy)
            local isInstant = false
            if instantSeverity > severity then
                severity = instantSeverity
                trigger = instantTrigger
                isInstant = true
            end
            if followupSeverity > severity then
                severity = followupSeverity
                trigger = followupTrigger
                isInstant = true
            end
            if severity > 0 then
                local canSpend = (followupSeverity > 0) or CanSpendControlOnTarget(localHero, enemy, now)
                if canSpend then
                    local score = ComputeEnemyThreatScore(localHero, enemy, severity, isInstant, trigger, now)

                    if score > bestScore then
                        bestScore = score
                        bestTarget = enemy
                        bestTrigger = trigger
                        bestInstant = isInstant
                    end
                end
            end
        end
    end

    return bestTarget, bestTrigger, bestInstant
end

local function V2(x, y)
    return Vec2(math.floor(x + 0.5), math.floor(y + 0.5))
end

local function GetDrawFlagsRoundAll()
    if not Enum or not Enum.DrawFlags then
        return 0
    end

    return Enum.DrawFlags.RoundCornersAll
        or Enum.DrawFlags.ROUND_CORNERS_ALL
        or Enum.DrawFlags.None
        or Enum.DrawFlags.NONE
        or 0
end

local function GetStyleColor(style, key, fallback)
    local c = style and style[key]
    if c then
        return Color(c.r or fallback.r, c.g or fallback.g, c.b or fallback.b, c.a or fallback.a)
    end
    return Color(fallback.r, fallback.g, fallback.b, fallback.a)
end

local function WithAlpha(col, alpha)
    if not col then
        return Color(255, 255, 255, alpha or 255)
    end
    return Color(col.r or 255, col.g or 255, col.b or 255, alpha or (col.a or 255))
end

local function LerpColor(a, b, t, alpha)
    local tt = Clamp(tonumber(t) or 0, 0, 1)
    local ar, ag, ab, aa = (a and a.r) or 0, (a and a.g) or 0, (a and a.b) or 0, (a and a.a) or 255
    local br, bg, bb, ba = (b and b.r) or 0, (b and b.g) or 0, (b and b.b) or 0, (b and b.a) or 255
    local rr = math.floor(ar + (br - ar) * tt + 0.5)
    local rg = math.floor(ag + (bg - ag) * tt + 0.5)
    local rb = math.floor(ab + (bb - ab) * tt + 0.5)
    local ra = alpha or math.floor(aa + (ba - aa) * tt + 0.5)
    return Color(rr, rg, rb, ra)
end

local function SyncPanelThemeColors()
    local now = GetTime()
    local cache = STATE.panelTheme
    if cache and cache.colors and (now - (cache.lastSync or 0)) < 0.35 then
        return cache.colors
    end

    local style = nil
    if Menu and Menu.Style then
        local ok, data = pcall(Menu.Style)
        if ok and data then
            style = data
        end
    end

    local bgBase = GetStyleColor(style, "additional_background", Color(19, 20, 27, 230))
    local outlineBase = GetStyleColor(style, "outline", Color(88, 98, 122, 180))
    local textBase = GetStyleColor(style, "primary_first_tab_text", Color(236, 238, 244, 245))
    local accentBase = GetStyleColor(style, "primary", Color(132, 149, 201, 230))
    local mutedBase = GetStyleColor(style, "slider_background", Color(176, 183, 203, 215))

    local bg = WithAlpha(bgBase, 232)
    local header = LerpColor(bgBase, Color(0, 0, 0, 255), 0.12, 238)
    local section = LerpColor(bgBase, accentBase, 0.07, 214)
    local accentSoft = LerpColor(accentBase, Color(255, 255, 255, 255), 0.18, 220)
    local danger = LerpColor(Color(220, 90, 90, 255), accentBase, 0.10, 195)

    local colors = {
        bg = bg,
        header = header,
        outline = WithAlpha(outlineBase, 190),
        text = WithAlpha(textBase, 252),
        accent = accentSoft,
        muted = WithAlpha(LerpColor(textBase, mutedBase, 0.40, 255), 234),
        sectionBg = section,
        divider = WithAlpha(outlineBase, 170),
        buttonBg = LerpColor(bgBase, accentBase, 0.14, 222),
        buttonBorder = WithAlpha(accentBase, 230),
        panelShadow = Color(0, 0, 0, 126),
        offText = WithAlpha(danger, 230),
        corner = WithAlpha(accentBase, 120),
        okBorder = WithAlpha(accentBase, 205),
        coolBorder = WithAlpha(LerpColor(accentBase, mutedBase, 0.35, 255), 180),
        offBorder = WithAlpha(danger, 182),
        heroOffBorder = WithAlpha(danger, 195),
        heroOnBorder = WithAlpha(accentBase, 208),
        sectionBorder = WithAlpha(outlineBase, 150),
        dangerousBorder = WithAlpha(LerpColor(Color(168, 110, 210, 255), accentBase, 0.20, 255), 215),
        secondaryBorder = WithAlpha(accentBase, 195),
    }

    STATE.panelTheme.colors = colors
    STATE.panelTheme.lastSync = now
    return colors
end

local function EnsureFonts()
    if not STATE.fontMain then
        if Render.LoadFont then
            STATE.fontMain = SafeCall(Render.LoadFont, "Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, 550)
        elseif Render.CreateFont then
            STATE.fontMain = SafeCall(Render.CreateFont, "Inter", 14, 550, Enum.FontCreate.FONTFLAG_ANTIALIAS)
        end
    end

    if not STATE.fontSmall then
        if Render.LoadFont then
            STATE.fontSmall = SafeCall(Render.LoadFont, "Inter", Enum.FontCreate.FONTFLAG_ANTIALIAS, 450)
        elseif Render.CreateFont then
            STATE.fontSmall = SafeCall(Render.CreateFont, "Inter", 12, 450, Enum.FontCreate.FONTFLAG_ANTIALIAS)
        end
    end
end

local function DrawText(font, size, text, x, y, color)
    if not Render then return end

    if Render.Text then
        SafeCall(Render.Text, font, size, text, V2(x, y), color)
    end
end

local function DrawTextSoft(font, size, text, x, y, color, shadowAlpha)
    local sa = shadowAlpha
    if sa == nil then
        sa = math.min(170, math.floor((color and color.a or 255) * 0.55))
    end
    DrawText(font, size, text, x + 1, y + 1, Color(0, 0, 0, sa))
    DrawText(font, size, text, x, y, color)
end

local function DrawRect(x0, y0, x1, y1, color, rounding, thickness)
    if Render and Render.Rect then
        SafeCall(Render.Rect, V2(x0, y0), V2(x1, y1), color, rounding or 0, GetDrawFlagsRoundAll(), thickness or 1)
        return
    end

    if Render and Render.OutlineRect then
        SafeCall(Render.OutlineRect, V2(x0, y0), Vec2(x1 - x0, y1 - y0), color, rounding or 0, thickness or 1)
    end
end

local function GetTextSize(font, size, text)
    if Render and Render.TextSize then
        local vec = SafeCall(Render.TextSize, font, size, text)
        if vec then return vec end
    end

    if Render and Render.GetTextSize then
        local vec = SafeCall(Render.GetTextSize, font, text)
        if vec then return vec end
    end

    return Vec2(0, 0)
end

local function FitTextToWidth(font, size, text, maxWidth)
    local source = tostring(text or "")
    local limit = math.floor(tonumber(maxWidth) or 0)
    if limit <= 0 then
        return source
    end

    local measure = GetTextSize(font, size, source)
    if (measure.x or 0) <= limit then
        return source
    end

    local utf8mod = _G and _G.utf8 or nil
    local function utf8len(s)
        if utf8mod and utf8mod.len then
            local ok, len = pcall(utf8mod.len, s)
            if ok and len then
                return len
            end
        end
        return #s
    end
    local function utf8sub(s, charCount)
        if charCount <= 0 then
            return ""
        end
        if utf8mod and utf8mod.offset then
            local ok, idx = pcall(utf8mod.offset, s, charCount + 1)
            if ok and idx then
                return string.sub(s, 1, idx - 1)
            end
            if ok and not idx then
                return s
            end
        end
        return string.sub(s, 1, charCount)
    end

    local count = utf8len(source)
    while count > 0 do
        count = count - 1
        local out = utf8sub(source, count)
        local candidate = out .. "..."
        local sizeVec = GetTextSize(font, size, candidate)
        if (sizeVec.x or 0) <= limit then
            return candidate
        end
    end

    return "..."
end

local function LoadImage(path)
    if not path then return nil end

    local cached = STATE.iconCache[path]
    if cached ~= nil then
        return cached
    end

    local image = nil
    if Render and Render.LoadImage then
        image = SafeCall(Render.LoadImage, path)
    end

    STATE.iconCache[path] = image
    return image
end

local function DrawImage(path, x, y, size, alpha)
    local image = LoadImage(path)
    if not image then return false end

    SafeCall(
        Render.Image,
        image,
        V2(x, y),
        Vec2(size, size),
        Color(255, 255, 255, alpha or 255),
        4,
        GetDrawFlagsRoundAll()
    )

    return true
end

local function RoundInt(v)
    return math.floor((tonumber(v) or 0) + 0.5)
end

local function ComputePanelGeometry(controls, enemyGroups)
    local cols = GetPanelColumns()
    cols = Clamp(cols, 3, 8)

    local icon = Clamp(math.floor(STATE.panel.iconSize or PANEL_LAYOUT.icon), 24, 64)
    local iconGap = Clamp(RoundInt(icon * 0.16), 4, 14)
    local enemyIcon = Clamp(RoundInt(icon * 0.82), 20, 52)
    local enemyIconGap = Clamp(RoundInt(enemyIcon * 0.16), 3, 10)
    local padding = Clamp(RoundInt(icon * 0.30), 10, 20)
    local header = Clamp(RoundInt(icon * 0.82), 28, 50)
    local sectionTitle = Clamp(RoundInt(icon * 0.38), 12, 24)
    local sectionGap = Clamp(RoundInt(icon * 0.18), 5, 12)
    local footer = Clamp(RoundInt(icon * 0.72), 24, 44)
    local edgeTab = Clamp(RoundInt(icon * 0.76), 20, 40)
    local corner = Clamp(RoundInt(icon * 0.22), 6, 12)
    local resizeHandle = Clamp(RoundInt(icon * 0.30), 10, 18)

    local controlCount = #controls
    local ownRows = (controlCount > 0) and math.ceil(controlCount / cols) or 1
    local ownContentW = cols * icon + (cols - 1) * iconGap
    local ownContentH = ownRows * icon + (ownRows - 1) * iconGap

    local enemyMaxCols = 1
    for i = 1, #enemyGroups do
        local columnsForHero = 1 + #(enemyGroups[i].abilities or {})
        if columnsForHero > enemyMaxCols then
            enemyMaxCols = columnsForHero
        end
    end

    local enemyRows = (#enemyGroups > 0) and #enemyGroups or 1
    local enemyContentW = enemyMaxCols * enemyIcon + (enemyMaxCols - 1) * enemyIconGap
    local enemyContentH = enemyRows * enemyIcon + (enemyRows - 1) * enemyIconGap

    local contentW = math.max(ownContentW, enemyContentW)
    local minExpandedWidth = Clamp(RoundInt(icon * 8.6), 300, 460)
    local expandedWidth = math.max(padding * 2 + contentW, minExpandedWidth)
    local collapsed = STATE.panel.collapsed and true or false
    local dock = STATE.panel.dock or 0
    local width = expandedWidth
    local height
    if collapsed then
        if dock == -1 or dock == 1 then
            width = expandedWidth
        else
            width = Clamp(expandedWidth, 220, 300)
        end
        height = padding + header + 8
    else
        height =
            padding + header +
            sectionGap + sectionTitle + 2 + ownContentH +
            sectionGap + sectionTitle + 2 + enemyContentH +
            footer
    end

    return {
        cols = cols,
        ownRows = ownRows,
        enemyRows = enemyRows,
        ownContentW = ownContentW,
        ownContentH = ownContentH,
        enemyContentW = enemyContentW,
        enemyContentH = enemyContentH,
        contentW = contentW,
        expandedW = expandedWidth,
        dock = dock,
        collapsed = collapsed,
        icon = icon,
        iconGap = iconGap,
        enemyIcon = enemyIcon,
        enemyIconGap = enemyIconGap,
        padding = padding,
        header = header,
        sectionTitle = sectionTitle,
        sectionGap = sectionGap,
        footer = footer,
        edgeTab = edgeTab,
        corner = corner,
        resizeHandle = resizeHandle,
        w = width,
        h = height,
    }
end

local function BuildPanelRects(controls, enemyGroups)
    local geom = ComputePanelGeometry(controls, enemyGroups)
    local panel = STATE.panel

    local screen = (Render and (SafeCall(Render.ScreenSize) or SafeCall(Render.GetScreenSize))) or Vec2(1920, 1080)
    local screenW = screen.x or 1920
    local screenH = screen.y or 1080
    local tabW = geom.edgeTab

    if not panel.dragging and not panel.resizing then
        if panel.dock == -1 then
            if geom.collapsed then
                panel.x = -(geom.w - tabW)
            else
                panel.x = 0
            end
        elseif panel.dock == 1 then
            if geom.collapsed then
                panel.x = math.max(0, screenW - tabW)
            else
                panel.x = math.max(0, screenW - geom.w)
            end
        else
            panel.x = Clamp(panel.x, 0, math.max(0, screenW - geom.w))
        end
    end

    panel.y = Clamp(panel.y, 0, math.max(0, screenH - geom.h))

    panel.w = geom.w
    panel.h = geom.h

    local rects = {
        panel = { x = panel.x, y = panel.y, w = geom.w, h = geom.h },
        header = { x = panel.x, y = panel.y, w = geom.w, h = geom.header + geom.padding },
        ownTitle = nil,
        enemyTitle = nil,
        toggleBtn = nil,
        collapsed = geom.collapsed,
        leftBtn = nil,
        rightBtn = nil,
        ownIcons = {},
        enemyRows = {},
        resize = {
            tl = { x = panel.x, y = panel.y, w = geom.resizeHandle, h = geom.resizeHandle },
            tr = { x = panel.x + geom.w - geom.resizeHandle, y = panel.y, w = geom.resizeHandle, h = geom.resizeHandle },
            bl = { x = panel.x, y = panel.y + geom.h - geom.resizeHandle, w = geom.resizeHandle, h = geom.resizeHandle },
            br = { x = panel.x + geom.w - geom.resizeHandle, y = panel.y + geom.h - geom.resizeHandle, w = geom.resizeHandle, h = geom.resizeHandle },
        },
        geom = geom,
    }

    local toggleW = Clamp(RoundInt(geom.icon * 0.72), 20, 34)
    local toggleH = Clamp(RoundInt(geom.icon * 0.46), 16, 22)
    local toggleX = panel.x + geom.w - geom.padding - toggleW
    if geom.collapsed and panel.dock == -1 then
        toggleX = 2
    elseif geom.collapsed and panel.dock == 1 then
        toggleX = panel.x + 2
    end
    rects.toggleBtn = {
        x = toggleX,
        y = panel.y + math.floor((geom.header + geom.padding - toggleH) * 0.5),
        w = toggleW,
        h = toggleH,
    }

    if geom.collapsed then
        return rects
    end

    local gridX = panel.x + geom.padding
    local y = panel.y + geom.padding + geom.header + math.max(2, geom.sectionGap - 1)
    rects.ownTitle = { x = gridX, y = y, w = geom.contentW, h = geom.sectionTitle }
    y = y + geom.sectionTitle + 4

    local ownGridY = y
    for i = 1, #controls do
        local col = (i - 1) % geom.cols
        local row = math.floor((i - 1) / geom.cols)
        local x = gridX + col * (geom.icon + geom.iconGap)
        local iconY = ownGridY + row * (geom.icon + geom.iconGap)

        rects.ownIcons[i] = {
            x = x,
            y = iconY,
            w = geom.icon,
            h = geom.icon,
            index = i,
        }
    end

    y = ownGridY + geom.ownContentH + geom.sectionGap
    rects.enemyTitle = { x = gridX, y = y, w = geom.contentW, h = geom.sectionTitle }
    y = y + geom.sectionTitle + 4

    local enemyGridY = y
    for i = 1, #enemyGroups do
        local rowY = enemyGridY + (i - 1) * (geom.enemyIcon + geom.enemyIconGap)
        local rowRect = {
            index = i,
            hero = {
                x = gridX,
                y = rowY,
                w = geom.enemyIcon,
                h = geom.enemyIcon,
            },
            abilities = {},
        }

        local abilities = enemyGroups[i].abilities or {}
        for j = 1, #abilities do
            local x = gridX + j * (geom.enemyIcon + geom.enemyIconGap)
            rowRect.abilities[j] = {
                x = x,
                y = rowY,
                w = geom.enemyIcon,
                h = geom.enemyIcon,
                index = j,
            }
        end
        rects.enemyRows[i] = rowRect
    end

    local btnY = panel.y + geom.h - geom.footer + 4
    local btnW = 34
    local btnH = 20
    local midX = panel.x + math.floor(geom.w * 0.5)
    rects.leftBtn = { x = midX - btnW - 6, y = btnY, w = btnW, h = btnH }
    rects.rightBtn = { x = midX + 6, y = btnY, w = btnW, h = btnH }

    return rects
end

local function IsPointInRect(x, y, rect)
    if not rect then return false end
    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function MoveSelectedPriority(delta)
    local selected = STATE.selectedPriorityId
    if not selected then return end

    local idx = nil
    for i = 1, #STATE.priorityOrder do
        if STATE.priorityOrder[i] == selected then
            idx = i
            break
        end
    end

    if not idx then return end

    local nextIdx = idx + delta
    if nextIdx < 1 or nextIdx > #STATE.priorityOrder then
        return
    end

    STATE.priorityOrder[idx], STATE.priorityOrder[nextIdx] = STATE.priorityOrder[nextIdx], STATE.priorityOrder[idx]
end

local function ToggleOwnControlState(control)
    if not control then return end
    ToggleOwnControlPanelEnabled(control.id)
end

local function GetMouseKeyLeft()
    local bc = Enum and Enum.ButtonCode
    if not bc then return nil end
    return bc.KEY_MOUSE1 or bc.MOUSE_LEFT
end

local function GetMouseKeyRight()
    local bc = Enum and Enum.ButtonCode
    if not bc then return nil end
    return bc.KEY_MOUSE2 or bc.MOUSE_RIGHT
end

local function CollectEnemyPanelHeroes(localHero)
    local list = {}
    local seenByName = {}
    local enemies = Heroes and Heroes.GetAll and (Heroes.GetAll() or {}) or {}
    for i = 1, #enemies do
        local enemy = enemies[i]
        if IsEnemyHero(localHero, enemy) then
            local name = SafeCall(NPC.GetUnitName, enemy)
            if name and not seenByName[name] then
                seenByName[name] = true
                list[#list + 1] = enemy
            end
        end
    end

    table.sort(list, function(a, b)
        local aName = SafeCall(NPC.GetUnitName, a) or ""
        local bName = SafeCall(NPC.GetUnitName, b) or ""
        return aName < bName
    end)
    return list
end

local function BuildEnemyPanelEntries(localHero)
    if not localHero then
        return {}
    end

    local out = {}
    local enemies = CollectEnemyPanelHeroes(localHero)

    for i = 1, #enemies do
        local enemy = enemies[i]
        local heroName = SafeCall(NPC.GetUnitName, enemy)
        if heroName then
            local abilitiesOut = {}
            local seen = {}
            local abilities = CollectHeroAbilities(enemy)
            for j = 1, #abilities do
                local ability = abilities[j]
                if IsTrackableEnemyAbility(ability) then
                    local name = SafeCall(Ability.GetName, ability)
                    if IsValidAbilityName(name) and not seen[name] then
                        seen[name] = true
                        local enabled, severity = IsEnemyAbilitySelected(name)
                        abilitiesOut[#abilitiesOut + 1] = {
                            name = name,
                            iconPath = GetSpellIconPath(name),
                            enabled = enabled and true or false,
                            severity = severity or 0,
                        }
                    end
                end
            end

            out[#out + 1] = {
                heroName = heroName,
                heroIconPath = GetHeroIconPath(heroName),
                enabled = IsEnemyNameEnabled(heroName),
                abilities = abilitiesOut,
            }
        end
    end

    return out
end

local function HandlePriorityPanelInput(controls, enemyGroups)
    local panel = STATE.panel
    panel.clickEaten = false
    panel.hovered = false

    if not MENU.Enabled:Get() then return end
    if not MENU.PanelEnabled:Get() then return end

    local rects = BuildPanelRects(controls, enemyGroups)

    local cx, cy = SafeCall(Input.GetCursorPos)
    if not cx or not cy then return end

    panel.hovered = IsPointInRect(cx, cy, rects.panel)

    local leftKey = GetMouseKeyLeft()
    local rightKey = GetMouseKeyRight()

    local leftOnce = leftKey and SafeCall(Input.IsKeyDownOnce, leftKey)
    local leftHold = leftKey and SafeCall(Input.IsKeyDown, leftKey)
    local rightOnce = rightKey and SafeCall(Input.IsKeyDownOnce, rightKey)
    local screen = (Render and (SafeCall(Render.ScreenSize) or SafeCall(Render.GetScreenSize))) or Vec2(1920, 1080)
    local screenW = screen.x or 1920
    local edgeSnap = 26
    local function getResizeCorner()
        if rects.resize then
            if IsPointInRect(cx, cy, rects.resize.tl) then return "tl" end
            if IsPointInRect(cx, cy, rects.resize.tr) then return "tr" end
            if IsPointInRect(cx, cy, rects.resize.bl) then return "bl" end
            if IsPointInRect(cx, cy, rects.resize.br) then return "br" end
        end
        return nil
    end

    if leftOnce and IsPointInRect(cx, cy, rects.toggleBtn) then
        panel.collapsed = not panel.collapsed
        if panel.collapsed and panel.dock == 0 then
            if panel.x <= edgeSnap then
                panel.dock = -1
            elseif panel.x + panel.w >= screenW - edgeSnap then
                panel.dock = 1
            end
        elseif (not panel.collapsed) and panel.dock ~= 0 then
            panel.x = (panel.dock == -1) and 0 or math.max(0, screenW - panel.w)
        end
        SavePanelPosition()
        panel.clickEaten = true
        return
    end

    if leftOnce and not rects.collapsed then
        local corner = getResizeCorner()
        if corner then
            panel.resizing = true
            panel.resizeCorner = corner
            panel.resizeStartX = cx
            panel.resizeStartY = cy
            panel.resizeStartSize = panel.iconSize or PANEL_LAYOUT.icon
            panel.clickEaten = true
            return
        end
    end

    if panel.resizing then
        if leftHold then
            local dx = cx - panel.resizeStartX
            local dy = cy - panel.resizeStartY
            local corner = panel.resizeCorner or "br"
            if corner == "tl" then
                dx = -dx
                dy = -dy
            elseif corner == "tr" then
                dy = -dy
            elseif corner == "bl" then
                dx = -dx
            end

            local delta = math.max(dx, dy)
            local nextSize = Clamp(math.floor((panel.resizeStartSize or PANEL_LAYOUT.icon) + delta * 0.22), 24, 64)
            panel.iconSize = nextSize
        else
            panel.resizing = false
            panel.resizeCorner = ""
            SavePanelPosition()
        end
        panel.clickEaten = true
        return
    end

    if IsPointInRect(cx, cy, rects.header) and leftOnce and not panel.dragging and not IsPointInRect(cx, cy, rects.toggleBtn) then
        if panel.dock ~= 0 and panel.collapsed then
            panel.collapsed = false
            panel.x = (panel.dock == -1) and 0 or math.max(0, screenW - panel.w)
        end
        panel.dock = 0
        panel.dragging = true
        panel.dx = cx - panel.x
        panel.dy = cy - panel.y
        panel.clickEaten = true
    end

    if panel.dragging then
        if leftHold then
            panel.x = cx - panel.dx
            panel.y = cy - panel.dy
        else
            panel.dragging = false
            if panel.x <= edgeSnap then
                panel.dock = -1
                panel.x = 0
            elseif panel.x + panel.w >= screenW - edgeSnap then
                panel.dock = 1
                panel.x = math.max(0, screenW - panel.w)
            else
                panel.dock = 0
            end
            SavePanelPosition()
        end
        panel.clickEaten = true
        return
    end

    if not panel.hovered then
        return
    end

    if rects.collapsed then
        return
    end

    if leftOnce then
        for i = 1, #rects.ownIcons do
            if IsPointInRect(cx, cy, rects.ownIcons[i]) then
                local control = controls[i]
                if control then
                    STATE.selectedPriorityId = control.id
                end
                panel.clickEaten = true
                return
            end
        end

        for i = 1, #rects.enemyRows do
            local rowRect = rects.enemyRows[i]
            local group = enemyGroups[i]
            if rowRect and group then
                if IsPointInRect(cx, cy, rowRect.hero) then
                    ToggleEnemyName(group.heroName)
                    panel.clickEaten = true
                    return
                end

                for j = 1, #rowRect.abilities do
                    if IsPointInRect(cx, cy, rowRect.abilities[j]) then
                        local ability = group.abilities and group.abilities[j]
                        if ability then
                            ToggleEnemyAbilitySelected(ability.name)
                        end
                        panel.clickEaten = true
                        return
                    end
                end
            end
        end

        if IsPointInRect(cx, cy, rects.leftBtn) then
            MoveSelectedPriority(-1)
            panel.clickEaten = true
            return
        end

        if IsPointInRect(cx, cy, rects.rightBtn) then
            MoveSelectedPriority(1)
            panel.clickEaten = true
            return
        end
    end

    if rightOnce then
        for i = 1, #rects.ownIcons do
            if IsPointInRect(cx, cy, rects.ownIcons[i]) then
                local control = controls[i]
                if control then
                    ToggleOwnControlState(control)
                end
                panel.clickEaten = true
                return
            end
        end

        for i = 1, #rects.enemyRows do
            local rowRect = rects.enemyRows[i]
            local group = enemyGroups[i]
            if rowRect and group then
                if IsPointInRect(cx, cy, rowRect.hero) then
                    ToggleEnemyName(group.heroName)
                    panel.clickEaten = true
                    return
                end
                for j = 1, #rowRect.abilities do
                    if IsPointInRect(cx, cy, rowRect.abilities[j]) then
                        local ability = group.abilities and group.abilities[j]
                        if ability then
                            ToggleEnemyAbilitySelected(ability.name)
                        end
                        panel.clickEaten = true
                        return
                    end
                end
            end
        end
    end
end

local function DrawPriorityPanel(hero, controls, enemyGroups)
    if not MENU.Enabled:Get() then return end
    if not MENU.PanelEnabled:Get() then return end

    EnsureFonts()

    local rects = BuildPanelRects(controls, enemyGroups)
    local geom = rects.geom

    local tc = SyncPanelThemeColors()
    local colBg = tc.bg
    local colHeader = tc.header
    local colOutline = tc.outline
    local colText = tc.text
    local colAccent = tc.accent
    local colMuted = tc.muted
    local colSectionBg = tc.sectionBg

    if Render and Render.Blur then
        local blurFlags = (Enum and Enum.DrawFlags and (Enum.DrawFlags.None or Enum.DrawFlags.NONE)) or 0
        SafeCall(
            Render.Blur,
            V2(rects.panel.x, rects.panel.y),
            V2(rects.panel.x + rects.panel.w, rects.panel.y + rects.panel.h),
            1.0,
            1.0,
            0,
            blurFlags
        )
    end

    SafeCall(
        Render.FilledRect,
        V2(rects.panel.x + 2, rects.panel.y + 3),
        V2(rects.panel.x + rects.panel.w + 2, rects.panel.y + rects.panel.h + 3),
        tc.panelShadow,
        geom.corner + 1,
        GetDrawFlagsRoundAll()
    )

    SafeCall(
        Render.FilledRect,
        V2(rects.panel.x, rects.panel.y),
        V2(rects.panel.x + rects.panel.w, rects.panel.y + rects.panel.h),
        colOutline,
        geom.corner,
        GetDrawFlagsRoundAll()
    )

    SafeCall(
        Render.FilledRect,
        V2(rects.panel.x + 1, rects.panel.y + 1),
        V2(rects.panel.x + rects.panel.w - 1, rects.panel.y + rects.panel.h - 1),
        colBg,
        geom.corner,
        GetDrawFlagsRoundAll()
    )

    SafeCall(
        Render.FilledRect,
        V2(rects.header.x + 1, rects.header.y + 1),
        V2(rects.header.x + rects.header.w - 1, rects.header.y + rects.header.h - 1),
        colHeader,
        geom.corner,
        GetDrawFlagsRoundAll()
    )

    local titleX = rects.panel.x + geom.padding
    local titleY = rects.panel.y + 6
    local titleRightLimit = rects.panel.x + rects.panel.w - geom.padding
    if rects.toggleBtn and rects.toggleBtn.x > rects.panel.x and rects.toggleBtn.x < (rects.panel.x + rects.panel.w) then
        titleRightLimit = rects.toggleBtn.x - 6
    end
    if titleRightLimit < titleX + 60 then
        titleRightLimit = rects.panel.x + rects.panel.w - geom.padding
    end
    local titleMaxW = math.max(60, titleRightLimit - titleX)
    local titleText = FitTextToWidth(STATE.fontMain, 13, L("panel_title"), titleMaxW)
    DrawTextSoft(STATE.fontMain, 13, titleText, titleX, titleY, colText, 140)
    DrawRect(
        rects.panel.x + 1,
        rects.header.y + rects.header.h,
        rects.panel.x + rects.panel.w - 1,
        rects.header.y + rects.header.h + 1,
        tc.divider,
        0,
        1
    )
    local accentH = math.max(1, math.floor((geom.corner - 2) * 0.4) + 1)
    SafeCall(
        Render.FilledRect,
        V2(rects.panel.x + 1, rects.header.y + 1),
        V2(rects.panel.x + rects.panel.w - 1, rects.header.y + accentH + 1),
        WithAlpha(colAccent, 192),
        math.max(1, geom.corner - 2),
        GetDrawFlagsRoundAll()
    )

    local function drawBtn(rect, text)
        SafeCall(
            Render.FilledRect,
            V2(rect.x, rect.y),
            V2(rect.x + rect.w, rect.y + rect.h),
            tc.buttonBg,
            4,
            GetDrawFlagsRoundAll()
        )
        DrawRect(rect.x, rect.y, rect.x + rect.w, rect.y + rect.h, tc.buttonBorder, 4, 1)
        SafeCall(
            Render.FilledRect,
            V2(rect.x + 1, rect.y + 1),
            V2(rect.x + rect.w - 1, rect.y + 2),
            WithAlpha(colAccent, 180),
            2,
            GetDrawFlagsRoundAll()
        )
        local sz = GetTextSize(STATE.fontMain, 12, text)
        local tx = rect.x + math.floor((rect.w - (sz.x or 0)) * 0.5)
        local ty = rect.y + math.floor((rect.h - (sz.y or 0)) * 0.5) - 1
        DrawTextSoft(STATE.fontMain, 12, text, tx, ty, colText, 120)
    end

    local toggleText
    if rects.collapsed then
        toggleText = (STATE.panel.dock == 1) and "<" or ">"
    else
        toggleText = (STATE.panel.dock == 1) and ">" or "<"
    end
    drawBtn(rects.toggleBtn, toggleText)

    local hintX = rects.panel.x + geom.padding
    local hintRightLimit = rects.panel.x + rects.panel.w - geom.padding
    if rects.toggleBtn and rects.toggleBtn.x > rects.panel.x and rects.toggleBtn.x < (rects.panel.x + rects.panel.w) then
        hintRightLimit = rects.toggleBtn.x - 6
    end
    if hintRightLimit < hintX + 60 then
        hintRightLimit = rects.panel.x + rects.panel.w - geom.padding
    end
    local hintMaxW = math.max(60, hintRightLimit - hintX)
    local hintY = titleY + 16
    local hintText = FitTextToWidth(STATE.fontSmall, 10, L("panel_hint"), hintMaxW)
    if rects.collapsed then
        DrawTextSoft(STATE.fontSmall, 10, hintText, hintX, hintY, colMuted, 110)
        return
    end

    DrawTextSoft(STATE.fontSmall, 10, hintText, hintX, hintY, colMuted, 110)

    local function drawSectionTitle(rect, text)
        if not rect then
            return
        end
        local tt = FitTextToWidth(STATE.fontMain, 11, text, math.max(80, rect.w))
        DrawTextSoft(STATE.fontMain, 11, tt, rect.x, rect.y + 1, colText, 125)
        local ts = GetTextSize(STATE.fontMain, 11, tt)
        local lineX0 = rect.x + (ts.x or 0) + 8
        local lineY = rect.y + math.floor(rect.h * 0.55)
        local lineX1 = rects.panel.x + rects.panel.w - geom.padding
        if lineX1 > lineX0 + 8 then
            DrawRect(lineX0, lineY, lineX1, lineY + 1, WithAlpha(colMuted, 85), 0, 1)
        end
    end

    local function drawSectionBox(x0, y0, x1, y1, alphaMul)
        SafeCall(
            Render.FilledRect,
            V2(x0, y0),
            V2(x1, y1),
            WithAlpha(colSectionBg, alphaMul or 212),
            math.max(2, geom.corner - 3),
            GetDrawFlagsRoundAll()
        )
        DrawRect(x0, y0, x1, y1, tc.sectionBorder, math.max(2, geom.corner - 3), 1)
    end

    local function drawOffBadge(x, y, w, h, small)
        local bw = small and 16 or 20
        local bh = small and 9 or 10
        local bx = x + w - bw - 2
        local by = y + h - bh - 2
        SafeCall(
            Render.FilledRect,
            V2(bx, by),
            V2(bx + bw, by + bh),
            WithAlpha(LerpColor(colBg, Color(90, 26, 26, 255), 0.45, 255), 212),
            3,
            GetDrawFlagsRoundAll()
        )
        DrawRect(bx, by, bx + bw, by + bh, tc.offBorder, 3, 1)
        DrawTextSoft(STATE.fontSmall, small and 7 or 8, "OFF", bx + 2, by + 1, tc.offText, 125)
    end

    local boxX0 = rects.panel.x + geom.padding - 4
    local boxX1 = rects.panel.x + rects.panel.w - geom.padding + 4

    local ownY0 = rects.ownTitle.y + rects.ownTitle.h + 3
    local ownY1 = ownY0 + geom.icon + 8
    if #rects.ownIcons > 0 then
        ownY0 = rects.ownIcons[1].y - 4
        ownY1 = rects.ownIcons[#rects.ownIcons].y + rects.ownIcons[#rects.ownIcons].h + 4
    end

    local enemyY0 = rects.enemyTitle.y + rects.enemyTitle.h + 3
    local enemyY1 = enemyY0 + geom.enemyIcon + 8
    if #rects.enemyRows > 0 then
        enemyY0 = rects.enemyRows[1].hero.y - 4
        local last = rects.enemyRows[#rects.enemyRows]
        local rowBottom = last.hero.y + last.hero.h
        if #last.abilities > 0 then
            local a = last.abilities[#last.abilities]
            rowBottom = math.max(rowBottom, a.y + a.h)
        end
        enemyY1 = rowBottom + 4
    end

    drawSectionTitle(rects.ownTitle, L("panel_own"))
    drawSectionTitle(rects.enemyTitle, L("panel_enemy"))
    drawSectionBox(boxX0, ownY0, boxX1, ownY1, 208)
    drawSectionBox(boxX0, enemyY0, boxX1, enemyY1, 200)

    if #controls == 0 then
        DrawTextSoft(
            STATE.fontSmall,
            11,
            L("panel_empty_own"),
            rects.panel.x + geom.padding,
            rects.ownTitle.y + 18,
            colMuted,
            115
        )
    end

    for i = 1, #controls do
        local control = controls[i]
        local r = rects.ownIcons[i]

        local ready = CanUseControl(hero, control.handle)
        local enabled = control.panelEnabled ~= false
        local alpha = (ready and enabled) and 255 or 88

        local bg = (ready and enabled)
            and LerpColor(colSectionBg, colAccent, 0.11, 236)
            or LerpColor(colSectionBg, Color(0, 0, 0, 255), 0.10, 224)
        SafeCall(
            Render.FilledRect,
            V2(r.x, r.y),
            V2(r.x + r.w, r.y + r.h),
            bg,
            5,
            GetDrawFlagsRoundAll()
        )

        local hasIcon = DrawImage(control.iconPath, r.x + 1, r.y + 1, r.w - 2, alpha)
        if not hasIcon then
            DrawTextSoft(STATE.fontSmall, 10, control.kind == "ability" and "A" or "I", r.x + 13, r.y + 10, colText, 100)
        end

        local border = tc.coolBorder
        if STATE.selectedPriorityId == control.id then
            border = colAccent
        elseif enabled then
            border = ready and tc.okBorder or tc.coolBorder
        else
            border = tc.offBorder
        end

        DrawRect(r.x, r.y, r.x + r.w, r.y + r.h, border, 5, 1)
        local idxTxt = tostring(i)
        local idxSz = GetTextSize(STATE.fontSmall, 9, idxTxt)
        local idxW = (idxSz.x or 0) + 6
        SafeCall(
            Render.FilledRect,
            V2(r.x + 2, r.y + 2),
            V2(r.x + 2 + idxW, r.y + 12),
            WithAlpha(colBg, 190),
            3,
            GetDrawFlagsRoundAll()
        )
        DrawTextSoft(STATE.fontSmall, 9, idxTxt, r.x + 4, r.y + 2, Color(255, 255, 255, 232), 120)
        if not enabled then
            drawOffBadge(r.x, r.y, r.w, r.h, false)
        end
    end

    if #enemyGroups == 0 then
        DrawTextSoft(
            STATE.fontSmall,
            10,
            L("menu_enemy_heroes"),
            rects.panel.x + geom.padding,
            rects.enemyTitle.y + 18,
            colMuted,
            115
        )
    end

    for i = 1, #rects.enemyRows do
        local rowRect = rects.enemyRows[i]
        local group = enemyGroups[i]
        if rowRect and group then
            local rowY0 = rowRect.hero.y - 2
            local rowY1 = rowRect.hero.y + rowRect.hero.h + 2
            SafeCall(
                Render.FilledRect,
                V2(boxX0 + 2, rowY0),
                V2(boxX1 - 2, rowY1),
                WithAlpha(LerpColor(colSectionBg, Color(0, 0, 0, 255), 0.06, 255), 148),
                4,
                GetDrawFlagsRoundAll()
            )
            local heroEnabled = group.enabled and true or false
            local heroBg = heroEnabled
                and LerpColor(colSectionBg, colAccent, 0.10, 236)
                or LerpColor(colSectionBg, Color(0, 0, 0, 255), 0.09, 222)
            SafeCall(
                Render.FilledRect,
                V2(rowRect.hero.x, rowRect.hero.y),
                V2(rowRect.hero.x + rowRect.hero.w, rowRect.hero.y + rowRect.hero.h),
                heroBg,
                5,
                GetDrawFlagsRoundAll()
            )
            DrawImage(group.heroIconPath, rowRect.hero.x + 1, rowRect.hero.y + 1, rowRect.hero.w - 2, heroEnabled and 255 or 95)
            DrawRect(
                rowRect.hero.x,
                rowRect.hero.y,
                rowRect.hero.x + rowRect.hero.w,
                rowRect.hero.y + rowRect.hero.h,
                heroEnabled and tc.heroOnBorder or tc.heroOffBorder,
                5,
                1
            )
            if not heroEnabled then
                drawOffBadge(rowRect.hero.x, rowRect.hero.y, rowRect.hero.w, rowRect.hero.h, true)
            end

            for j = 1, #rowRect.abilities do
                local r = rowRect.abilities[j]
                local ability = group.abilities and group.abilities[j]
                if r and ability then
                    local abilityEnabled = ability.enabled and true or false
                    local active = heroEnabled and abilityEnabled
                    local bg = active
                        and LerpColor(colSectionBg, colAccent, 0.09, 230)
                        or LerpColor(colSectionBg, Color(0, 0, 0, 255), 0.08, 220)
                    SafeCall(
                        Render.FilledRect,
                        V2(r.x, r.y),
                        V2(r.x + r.w, r.y + r.h),
                        bg,
                        5,
                        GetDrawFlagsRoundAll()
                    )

                    local alpha = active and 255 or 90
                    DrawImage(ability.iconPath, r.x + 1, r.y + 1, r.w - 2, alpha)

                    local border = abilityEnabled and ((ability.severity or 0) >= 3 and tc.dangerousBorder or tc.secondaryBorder)
                        or tc.offBorder
                    DrawRect(r.x, r.y, r.x + r.w, r.y + r.h, border, 5, 1)

                    if not abilityEnabled then
                        drawOffBadge(r.x, r.y, r.w, r.h, true)
                    end
                end
            end
        end
    end

    drawBtn(rects.leftBtn, "<")
    drawBtn(rects.rightBtn, ">")

    local showHandles = true
    if MENU.ResizeHandlesNear and MENU.ResizeHandlesNear.Get and MENU.ResizeHandlesNear:Get() then
        local cx, cy = SafeCall(Input.GetCursorPos)
        local nearRect = {
            x = rects.panel.x - 24,
            y = rects.panel.y - 24,
            w = rects.panel.w + 48,
            h = rects.panel.h + 48,
        }
        showHandles = (cx and cy and IsPointInRect(cx, cy, nearRect)) and true or false
    end

    if showHandles then
        local function drawCornerHandle(rect)
            SafeCall(
                Render.FilledRect,
                V2(rect.x + 1, rect.y + 1),
                V2(rect.x + rect.w - 1, rect.y + rect.h - 1),
                tc.corner,
                3,
                GetDrawFlagsRoundAll()
            )
        end

        drawCornerHandle(rects.resize.tl)
        drawCornerHandle(rects.resize.tr)
        drawCornerHandle(rects.resize.bl)
        drawCornerHandle(rects.resize.br)
    end
end
local function RefreshMenus(localHero, force)
    UpdateOwnControlMenus(localHero, force)
    UpdateEnemyTriggerMenus(localHero, force)
end

local function ResolveAnimationAbility(enemy, data)
    if not data then
        return nil
    end

    if data.ability then
        local testName = SafeCall(Ability.GetName, data.ability)
        if IsValidAbilityName(testName) then
            return data.ability
        end
    end

    if data.activity ~= nil then
        local byActivity = SafeCall(NPC.GetAbilityByActivity, enemy, data.activity)
        if byActivity then
            local name = SafeCall(Ability.GetName, byActivity)
            if IsValidAbilityName(name) then
                return byActivity
            end
        end
    end

    return nil
end

script.OnScriptsLoaded = function()
    STATE.language = NormalizeLanguageCode(FIXED_SETTINGS.language)
    InitMenu()
end

script.OnUnitAnimation = function(data)
    if not data then return end
    if not MENU.initialized or not MENU.Enabled or not MENU.Enabled:Get() then return end
    if not Engine.IsInGame() then return end

    local localHero = Heroes.GetLocal()
    local enemy = data.npc
    if not localHero or not enemy then return end
    if not IsEnemyHero(localHero, enemy) then return end
    if not IsEnemyEntityEnabled(enemy) then return end

    local ability = ResolveAnimationAbility(enemy, data)
    if not ability then
        if IsInterruptAnyChannelEnabled() and SafeCall(NPC.IsChannelling, enemy) then
            RegisterInstantEnemyCast(enemy, "channel", 5, GetTime())
        end
        return
    end

    local abilityName = SafeCall(Ability.GetName, ability)
    if not IsValidAbilityName(abilityName) then return end

    local enabled, severity = IsEnemyAbilitySelected(abilityName)
    if not enabled then return end

    RegisterInstantEnemyCast(enemy, abilityName, math.max(5, severity + 2), GetTime())
end

script.OnUpdate = function()
    if not Engine.IsInGame() then return end
    if not InitMenu() then return end

    local hero = Heroes.GetLocal()
    if not hero then return end

    local heroName = SafeCall(NPC.GetUnitName, hero) or ""
    if heroName ~= STATE.lastHeroName then
        STATE.lastHeroName = heroName
        STATE.ownAbilitySnapshot = {}
        STATE.ownItemSnapshot = {}
        STATE.enemyDangerSnapshot = {}
        STATE.enemyOtherSnapshot = {}
        STATE.enemyItemSnapshot = {}
        STATE.enemyHeroSnapshot = {}
        STATE.enemyHeroNames = {}
        STATE.priorityOrder = {}
        STATE.selectedPriorityId = nil
        STATE.lastRefreshTime = 0
        STATE.lastPanelSaveTime = 0
        STATE.lastOrderAttemptTime = 0
        STATE.targetControlUsage = {}
        STATE.instantEnemyCasts = {}
        STATE.linkensFollowupTargets = {}
        STATE.enemyRevealThreatCache = {}
        STATE.ownControlPanelDisabled = {}
        STATE.ownControlStateLoaded = {}
    end

    local now = GetTime()
    if now - STATE.lastRefreshTime > 0.50 then
        RefreshMenus(hero, false)
        STATE.lastRefreshTime = now
    end

    if now - (STATE.lastPanelSaveTime or 0) > 1.0 then
        SavePanelPosition()
        STATE.lastPanelSaveTime = now
    end

    CleanupTargetUsage(now)
    CleanupInstantEnemyCasts(now)
    CleanupLinkensFollowupTargets(now)
    UpdateEnemyRevealThreats(hero, now)

    local controls = BuildSelectedOwnControls(hero)
    local panelEnemies = BuildEnemyPanelEntries(hero)

    HandlePriorityPanelInput(controls, panelEnemies)

    if not MENU.Enabled:Get() then return end
    if not SafeCall(Entity.IsAlive, hero) then return end
    if IsHeroDisabled(hero) then return end
    if SafeCall(NPC.GetChannellingAbility, hero) then return end

    if #controls == 0 then return end

    local target, triggerName, isInstant = FindTriggeredEnemy(hero, now)
    if not target then
        return
    end

    local castDelay = GetEffectiveCastDelay() / 1000
    local retryDelay = GetEffectiveRetryDelay() / 1000
    if isInstant then
        castDelay = math.min(castDelay, 0.05)
        retryDelay = math.min(retryDelay, 0.05)
    end

    if now - STATE.lastCastTime < castDelay then
        return
    end

    if now - STATE.lastOrderAttemptTime < retryDelay then
        return
    end

    local linkensProtected = SafeCall(NPC.IsLinkensProtected, target) and true or false
    if linkensProtected and not IsCastIntoLinkensEnabled() then
        local breaker = FindBestLinkensBreaker(hero, controls, target)
        if breaker then
            local casted, attempted = TryCastControl(hero, breaker, target, true)
            if attempted then
                STATE.lastOrderAttemptTime = now
            end
            if casted then
                STATE.lastCastTime = now
                RegisterTargetUsage(target, now)
                RegisterLinkensFollowupTarget(target, now, "linkens_followup")
                return
            end
            if attempted then
                return
            end
        end
    end

    local castSequence = BuildSmartControlSequence(hero, target, controls, triggerName, isInstant, now)
    for i = 1, #castSequence do
        local control = castSequence[i]
        local casted, attempted = TryCastControl(hero, control, target, false)
        if attempted then
            STATE.lastOrderAttemptTime = now
        end

        if casted then
            STATE.lastCastTime = now
            RegisterTargetUsage(target, now)
            ConsumeLinkensFollowupTarget(target)
            return
        end

        if attempted then
            return
        end
    end
end

script.OnDraw = function()
    if not Engine.IsInGame() then return end
    if not InitMenu() then return end

    if not MENU.Enabled:Get() then return end
    if not MENU.PanelEnabled:Get() then return end

    local hero = Heroes.GetLocal()
    if not hero then return end

    local controls = BuildSelectedOwnControls(hero)
    local panelEnemies = BuildEnemyPanelEntries(hero)
    DrawPriorityPanel(hero, controls, panelEnemies)
end

script.OnPrepareUnitOrders = function()
    if STATE.panel.hovered or STATE.panel.clickEaten then
        return false
    end
    return true
end

script.OnGameEnd = function()
    SavePanelPosition()
    STATE.lastHeroName = ""
    STATE.ownAbilitySnapshot = {}
    STATE.ownItemSnapshot = {}
    STATE.enemyDangerSnapshot = {}
    STATE.enemyOtherSnapshot = {}
    STATE.enemyItemSnapshot = {}
    STATE.enemyHeroSnapshot = {}
    STATE.ownAbilityNames = {}
    STATE.ownItemNames = {}
    STATE.enemyDangerNames = {}
    STATE.enemyOtherNames = {}
    STATE.enemyItemNames = {}
    STATE.enemyHeroNames = {}
    STATE.priorityOrder = {}
    STATE.selectedPriorityId = nil
    STATE.lastRefreshTime = 0
    STATE.lastPanelSaveTime = 0
    STATE.lastCastTime = 0
    STATE.lastOrderAttemptTime = 0
    STATE.targetControlUsage = {}
    STATE.instantEnemyCasts = {}
    STATE.linkensFollowupTargets = {}
    STATE.enemyRevealThreatCache = {}
    STATE.ownControlPanelDisabled = {}
    STATE.ownControlStateLoaded = {}
    STATE.enemyAbilityEnabled = {}
    STATE.enemyAbilityLoaded = {}
    STATE.enemyHeroEnabled = {}
    STATE.enemyHeroLoaded = {}
    STATE.persistLoaded = false
    STATE.persistOwnEnabled = {}
    STATE.persistEnemyAbilityEnabled = {}
    STATE.persistEnemyHeroEnabled = {}
    STATE.panel.dragging = false
    STATE.panel.resizing = false
    STATE.panel.resizeCorner = ""
    STATE.panel.resizeStartX = 0
    STATE.panel.resizeStartY = 0
    STATE.panel.hovered = false
    STATE.panel.clickEaten = false
    STATE.iconCache = {}
end

return script
