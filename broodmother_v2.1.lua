--[[
  Broodmother Helper — UCZone API v2.0
  Пауки: сбор/развод, авто-следование/чейз/сплит/фарм, Soul Ring, Orchid/Bloodthorn, веб-хелпер.
  Оптимизировано: реже ордера = меньше перехват управления, плавная работа.
]]

local broodmother = {}

-- ═══════════════════════════════════════════════════════════════════════════
--  Константы оптимизации (реже ордера → меньше конфликт с ручным управлением)
-- ═══════════════════════════════════════════════════════════════════════════
local ORDER_INTERVAL_FOLLOW  = 2.8   -- сек между ордерами "следовать за героем"
local ORDER_INTERVAL_CHASE   = 2.4   -- сек между ордерами "атаковать врага"
local ORDER_INTERVAL_FARM   = 2.0   -- сек между ордерами "фармить крипов"
local SPIDER_CACHE_TTL       = 0.12  -- кэш списка пауков (сек), меньше вызовов NPCs.GetAll()
local STACK_TIME_START       = 52.5  -- окно стака: с какой секунды минуты (0-60)
local STACK_TIME_END         = 55.5  -- до какой секунды
local STACK_COOLDOWN         = 58    -- не слать стак в тот же камп чаще чем раз в 58 сек
-- Тайминг первого удара и сдвиг по стакам (из Auto Stacker By GLTM)
local STACK_FIRST_HIT_MELEE  = 53
local STACK_FIRST_HIT_RANGED = 53
local STACK_PER_STACK_SHIFT  = 0.4   -- секунд на стак (40 centi)

-- Точки wait/pull для стака нейтралов (координаты из Auto Stacker By GLTM)
local CAMP_POINTS = {
    [1]  = { wait = Vector(-742, 4325, 134),   pull = Vector(-682, 3881, 236) },
    [2]  = { wait = Vector(2943, -796, 256),   pull = Vector(2817, -53, 256) },
    [3]  = { wait = Vector(4082, -5526, 128),  pull = Vector(4181, -6368, 128) },
    [4]  = { wait = Vector(8255, -734, 256),   pull = Vector(8204, -1369, 256) },
    [5]  = { wait = Vector(-4806, 4534, 128),  pull = Vector(-4884, 5071, 128) },
    [6]  = { wait = Vector(4284, -4110, 128),   pull = Vector(3622, -4505, 128) },
    [7]  = { wait = Vector(-2121, -3921, 128), pull = Vector(-1564, -4531, 128) },
    [8]  = { wait = Vector(262, -4751, 136),   pull = Vector(333, -4101, 254) },
    [9]  = { wait = Vector(-4509, 361, 256),   pull = Vector(-5031, 1121, 128) },
    [10] = { wait = Vector(4072, -421, 256),   pull = Vector(4276, -1359, 128) },
    [11] = { wait = Vector(-1274, -4908, 128), pull = Vector(-812, -5282, 128) },
    [12] = { wait = Vector(1515, 8209, 128),   pull = Vector(792, 8152, 128) },
    [13] = { wait = Vector(455, 3965, 134),    pull = Vector(-78, 3932, 136) },
    [14] = { wait = Vector(-4144, 322, 256),   pull = Vector(-5031, 1121, 128) },
    [15] = { wait = Vector(316, -8138, 134),   pull = Vector(954, -8538, 136) },
    [16] = { wait = Vector(-2529, -7737, 134), pull = Vector(-2690, -7154, 134) },
    [17] = { wait = Vector(-479, 7639, 134),   pull = Vector(-551, 6961, 128) },
    [18] = { wait = Vector(-4743, 7534, 0),    pull = Vector(-4832, 7136, 0) },
    [19] = { wait = Vector(1348, 3263, 128),    pull = Vector(1683, 3710, 128) },
    [20] = { wait = Vector(7969, 1047, 256),   pull = Vector(7681, 695, 256) },
    [21] = { wait = Vector(-7735, -183, 256),  pull = Vector(-7436, 685, 256) },
    [22] = { wait = Vector(-3962, 7564, 0),    pull = Vector(-4521, 7474, 8) },
    [23] = { wait = Vector(-2589, 4502, 256),  pull = Vector(-2651, 5138, 256) },
    [24] = { wait = Vector(3522, -8186, 8),     pull = Vector(4028, -7376, 0) },
    [25] = { wait = Vector(1501, -4208, 256),  pull = Vector(1094, -5103, 136) },
    [26] = { wait = Vector(-4338, 4903, 128),   pull = Vector(-5198, 4877, 128) },
    [27] = { wait = Vector(-7757, -1219, 256), pull = Vector(-7693, -727, 256) },
    [28] = { wait = Vector(4781, -7812, 8),    pull = Vector(4510, -7260, 82) },
}

-- Состояние стака по кнопке (логика GLTM: без выделения, пауки по назначенным кампам)
local stackSessionActive   = false
local stackWasKeyHeld     = false
local stackUnitToCampId   = {}
local stackCampStrikeCenters = {}
local stackCampBoxes      = {}
local stackCampStacks     = {}
local stackCampStacksMinute = {}
local stackLastCampStacks = {}
local stackTimeline       = {}
local STACK_MODIFIERS     = { "modifier_stacked_neutral" }

-- ═══════════════════════════════════════════════════════════════════════════
--  Конфиг и сохранение позиции панели
-- ═══════════════════════════════════════════════════════════════════════════

local function GetConfigPath()
    return "brood_panel.ini"
end

local function LoadPanelPosition()
    local configPath = GetConfigPath()
    local file = io.open(configPath, "r")
    local x, y = 100.0, 100.0
    if file then
        for line in file:lines() do
            local xMatch = line:match("pos_x=(%d+)")
            local yMatch = line:match("pos_y=(%d+)")
            if xMatch then x = tonumber(xMatch) or x end
            if yMatch then y = tonumber(yMatch) or y end
        end
        file:close()
    end
    return x, y
end

local function SavePanelPosition(x, y)
    local configPath = GetConfigPath()
    local file = io.open(configPath, "w")
    if file then
        file:write(string.format("pos_x=%d\n", x))
        file:write(string.format("pos_y=%d\n", y))
        file:close()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Встроенные точки паутины (карта)
-- ═══════════════════════════════════════════════════════════════════════════

local BuiltInWebPoints = {
    radiant = {
        Vector(-201.0,-77.7,116.6), Vector(-1650.3,-1035.8,128.0), Vector(1139.7,926.0,128.0), Vector(-1441.3,-3310.8,128.0),
        Vector(-1073.8,-4963.5,128.0), Vector(937.3,-4405.5,244.2), Vector(3016.3,-5293.7,153.8), Vector(4838.3,-4607.0,128.0),
        Vector(6350.6,-5282.3,128.0), Vector(3007.3,-3204.2,14.0), Vector(4760.9,-6695.1,128.0), Vector(6952.3,-7236.4,256.0),
        Vector(3804.3,-8109.5,8.0), Vector(1358.6,-6705.8,8.0), Vector(-572.4,-7852.3,136.0), Vector(-2781.3,-7820.2,136.0),
        Vector(432.3,-2011.2,128.0), Vector(-3359.8,-2404.2,128.0), Vector(-4038.6,-128.5,256.0), Vector(-6294.8,-81.0,128.0),
        Vector(-7853.7,-720.1,256.0), Vector(-5477.0,1837.9,128.0), Vector(-7644.1,1684.1,256.0), Vector(-7946.9,3872.9,128.0),
        Vector(-7209.8,5891.9,128.0), Vector(-7249.5,7903.7,256.0), Vector(-5578.5,4211.5,128.0), Vector(-5522.4,6315.3,128.0),
        Vector(-3559.2,4280.8,140.4), Vector(-1561.8,4555.9,136.0), Vector(-3146.4,6256.3,128.0), Vector(-4126.5,8058.1,17.9),
        Vector(-1280.8,7674.4,256.0), Vector(782.5,7706.2,134.0), Vector(2627.1,7279.6,134.0), Vector(1627.7,5371.9,128.0),
        Vector(-1262.3,2169.0,256.0), Vector(287.8,3399.1,136.0), Vector(2294.0,2973.3,128.0), Vector(3097.4,1399.3,128.0),
        Vector(4161.7,-441.1,256.0), Vector(1980.0,-1044.2,256.0), Vector(5165.5,1637.2,128.0), Vector(7498.3,1572.4,256.0),
        Vector(7553.4,-640.2,194.5), Vector(5925.3,-1202.9,128.0), Vector(6223.9,-3209.6,128.0), Vector(-333.4,-6524.6,128.0),
        Vector(-2538.9,698.8,0.0), Vector(-3304.7,2564.7,74.9), Vector(-7291.8,2830.6,52.2)
    },
    dire = {
        Vector(577.4,220.4,128.0), Vector(-876.4,-695.2,128.0), Vector(623.2,-1765.3,128.0), Vector(-2676.0,389.6,128.0),
        Vector(-1115.8,1490.1,128.0), Vector(-4499.0,589.8,256.0), Vector(-6297.6,1723.0,128.0), Vector(-4719.2,2781.3,0.0),
        Vector(-1705.4,-2356.7,128.0), Vector(-3187.1,-1237.9,256.0), Vector(-1578.5,-4574.9,128.0), Vector(615.3,-4684.3,136.0),
        Vector(144.2,-3264.8,256.0), Vector(2740.0,-4209.9,256.0), Vector(4773.7,-4620.6,128.0), Vector(3174.1,-6286.9,128.0),
        Vector(5171.5,-6917.3,128.0), Vector(6710.5,-5165.4,128.0), Vector(7340.3,-7211.4,256.0), Vector(3485.5,-8188.2,8.0),
        Vector(1301.2,-7854.0,134.0), Vector(-883.8,-7865.6,136.0), Vector(-2983.0,-7481.6,131.9), Vector(-2115.3,-6160.5,128.0),
        Vector(-3850.4,-4844.2,256.0), Vector(-4180.6,-2536.2,128.0), Vector(-6439.4,-2212.2,128.0), Vector(-7913.8,-946.2,256.0),
        Vector(-7952.4,1369.9,256.0), Vector(-4801.4,-1009.6,256.0), Vector(2687.5,-98.2,240.9), Vector(4333.0,-652.1,256.0),
        Vector(6481.7,-433.7,128.0), Vector(7971.8,757.7,256.0), Vector(7933.0,-2114.0,256.0), Vector(5397.7,-2473.7,128.0),
        Vector(1011.2,2511.2,128.0), Vector(126.7,4245.9,136.0), Vector(-1915.0,4310.5,256.0), Vector(-1035.0,2883.5,256.0),
        Vector(-4098.5,4298.6,128.0), Vector(-6145.8,3511.2,128.0), Vector(-7861.2,4548.8,128.0), Vector(-7044.3,6549.5,256.0),
        Vector(-5528.9,5512.7,128.0), Vector(-5069.2,7786.7,8.0), Vector(-2878.3,7706.6,8.0), Vector(-2966.6,5917.6,128.0),
        Vector(-216.3,5558.3,128.0), Vector(1369.2,7798.8,142.5), Vector(1703.4,5670.7,128.0), Vector(4132.2,1559.8,128.0),
        Vector(6327.4,1596.6,128.0), Vector(2893.6,3347.3,128.0), Vector(2185.7,1661.9,128.0), Vector(2418.7,-3067.0,0.0),
        Vector(4123.6,-2100.7,0.0), Vector(-2959.7,2653.2,0.0)
    },
    neutral = {}
}

local function IsBroodmother()
    local myHero = Heroes.GetLocal()
    return myHero and NPC.GetUnitName(myHero) == "npc_dota_hero_broodmother"
end

local Config = {
    UI = {
        TabName = "General",
        ScriptName = "Broodmother Helper",
        ScriptID = "brood_helper_v3",
        UsePanoramaIcons = true,  -- false = иконки меню через Unicode (если картинки не грузятся)
        Icons = {
            Main   = "panorama/images/heroes/icons/npc_dota_hero_broodmother_png.vtex_c",
            Soul   = "panorama/images/items/soul_ring_png.vtex_c",
            Gather = "panorama/images/items/quelling_blade_png.vtex_c",
            Juggle = "panorama/images/items/branches_png.vtex_c",
            Blood  = "panorama/images/items/bloodthorn_png.vtex_c",
            Web    = "panorama/images/spellicons/broodmother_spin_web_png.vtex_c",
            MainFallback   = "\u{f188}",
            SoulFallback   = "\u{f06e}",
            GatherFallback = "\u{f0c0}",
            JuggleFallback = "\u{f110}",
            BloodFallback  = "\u{f219}",
        }
    },
    Fonts = {
        Main = Render.LoadFont("SF Pro Text", Enum.FontCreate.FONTFLAG_ANTIALIAS)
    }
}

local PanelConfig = {
    Width = 200,
    Height = 50,
    HeaderHeight = 26,
    CellSize = 26,
    CellSpacing = 5,
    BorderRadius = 8,
    ShadowOffset = 2,
    BlurStrength = 15,
    BlurStrengthHeader = 10
}

local PanelColors = {
    Background = Color(20, 20, 25, 220),
    BackgroundHover = Color(25, 25, 30, 230),
    Border = Color(60, 60, 70, 180),
    BorderHover = Color(80, 120, 255, 200),
    Header = Color(10, 10, 10, 200),
    HeaderText = Color(255, 255, 255, 255),
    Shadow = Color(0, 0, 0, 100),
    StatusColors = {
        ["Gather"] = Color(120, 255, 120, 255),
        ["Spread"] = Color(255, 120, 255, 255),
        ["Attack"] = Color(255, 80, 80, 255),
        ["Idle"] = Color(180, 180, 180, 255),
        ["HP"] = Color(120, 200, 255, 255)
    }
}

local function InitializeUI()
    -- Подключение к Heroes > Hero List > Broodmother, вкладка Helper с группами настроек
    local broodSection = Menu.Find("Heroes", "Hero List", "Broodmother")
    local helperTab
    if broodSection and broodSection.Create then
        helperTab = broodSection:Create("Helper")
    end
    if not helperTab or not helperTab.Create then
        -- Fallback: если Broodmother нет в меню — создаём своё дерево (General > Broodmother Helper)
        local tab = Menu.Create(Config.UI.TabName, Config.UI.ScriptName, Config.UI.ScriptID)
        if tab and tab.Icon then tab:Icon(Config.UI.Icons.Main) end
        helperTab = tab:Create("Main"):Create("Main Settings")
        -- Одна группа для всех опций при fallback (минимальное дублирование виджетов)
        local mainGroup = helperTab
        local spiderGroup = tab:Create("Spider Control"):Create("Manual Control")
        local autoGroup = tab:Create("Auto Control"):Create("Automatic Spider Control")
        local stackGroup = tab:Create("Auto Stack")
        local itemsGroup = tab:Create("Items"):Create("Item Usage")
        local webGroup = tab:Create("Web Helper"):Create("Web Helper")
        return {
            Enabled = mainGroup:Switch("Enable Script", true, (Config.UI.UsePanoramaIcons and Config.UI.Icons.Main) or Config.UI.Icons.MainFallback),
            ShowPanel = mainGroup:Switch("Show Panel", true),
            GatherKey = spiderGroup:Bind("Gather Spiders", Enum.ButtonCode.KEY_NONE, (Config.UI.UsePanoramaIcons and Config.UI.Icons.Gather) or Config.UI.Icons.GatherFallback),
            JuggleKey = spiderGroup:Bind("Spread Spiders", Enum.ButtonCode.KEY_NONE, (Config.UI.UsePanoramaIcons and Config.UI.Icons.Juggle) or Config.UI.Icons.JuggleFallback),
            JuggleRadius = spiderGroup:Slider("Spread Radius", 100, 2000, 885, "%d"),
            JuggleCount = spiderGroup:Slider("Number to Spread", 1, 10, 5, "%d"),
            GatherDelay = spiderGroup:Slider("Command Delay (ms)", 30, 300, 50, "%d"),
            AutoFollow = autoGroup:Switch("Auto Follow Hero", true),
            AutoFollowCount = autoGroup:Slider("Spiders Following", 0, 15, 2, "%d"),
            AutoFollowRadius = autoGroup:Slider("Follow Radius", 100, 600, 300, "%d"),
            AutoChase = autoGroup:Switch("Auto Chase Enemies", true),
            AutoChaseRadius = autoGroup:Slider("Chase Radius", 800, 2000, 1200, "%d"),
            AutoSplit = autoGroup:Switch("Auto Split Attack", true),
            AutoSplitMax = autoGroup:Slider("Max Per Target", 3, 20, 6, "%d"),
            PlayerOverride = autoGroup:Slider("Manual Control Duration", 0.5, 5.0, 3.0, "%.1f"),
            AutoFarmCreeps = autoGroup:Switch("Auto Farm Creeps", false),
            AutoFarmRadius = autoGroup:Slider("Farm Radius", 600, 2000, 1200, "%d"),
            AutoFarmCampRange = autoGroup:Slider("Camp Search Radius", 300, 900, 600, "%d"),
            AutoStackCamps = stackGroup:Switch("Enable stack by key", true),
            StackKey = stackGroup:Bind("Stack key (send spiders)", Enum.ButtonCode.KEY_NONE),
            StackRadius = stackGroup:Slider("Max distance to camp", 2000, 6000, 4000, "%d"),
            AutoSoulRing = itemsGroup:Switch("Auto Soul Ring", true, (Config.UI.UsePanoramaIcons and Config.UI.Icons.Soul) or Config.UI.Icons.SoulFallback),
            SmartBloodthorn = itemsGroup:Switch("Smart Orchid/Bloodthorn", true, (Config.UI.UsePanoramaIcons and Config.UI.Icons.Blood) or Config.UI.Icons.BloodFallback),
            BloodthornRange = itemsGroup:Slider("Cast Range", 500, 1100, 900, "%d"),
            BloodthornHPThreshold = itemsGroup:Slider("HP Threshold (%)", 30, 100, 70, "%d"),
            BloodthornDelay = itemsGroup:Slider("Cast Delay (ms)", 0, 500, 100, "%d"),
            WebHelperEnabled = webGroup:Switch("Show Web Points", true),
            ShowWebPointsOnlyAlt = webGroup:Switch("Show Only When ALT Pressed", false),
            WebClickToCast = webGroup:Switch("Click to Cast", true),
        }
    end

    local mainGroup = helperTab:Create("Main Settings")
    local spiderGroup = helperTab:Create("Manual Control")
    local autoGroup = helperTab:Create("Automatic Spider Control")
    local stackGroup = helperTab:Create("Auto Stack")
    local itemsGroup = helperTab:Create("Item Usage")
    local webGroup = helperTab:Create("Web Helper")

    return {
        Enabled = mainGroup:Switch("Enable Script", true, (Config.UI.UsePanoramaIcons and Config.UI.Icons.Main) or Config.UI.Icons.MainFallback),
        ShowPanel = mainGroup:Switch("Show Panel", true),

        GatherKey = spiderGroup:Bind("Gather Spiders", Enum.ButtonCode.KEY_NONE, (Config.UI.UsePanoramaIcons and Config.UI.Icons.Gather) or Config.UI.Icons.GatherFallback),
        JuggleKey = spiderGroup:Bind("Spread Spiders", Enum.ButtonCode.KEY_NONE, (Config.UI.UsePanoramaIcons and Config.UI.Icons.Juggle) or Config.UI.Icons.JuggleFallback),
        JuggleRadius = spiderGroup:Slider("Spread Radius", 100, 2000, 885, "%d"),
        JuggleCount = spiderGroup:Slider("Number to Spread", 1, 10, 5, "%d"),
        GatherDelay = spiderGroup:Slider("Command Delay (ms)", 30, 300, 50, "%d"),

        AutoFollow = autoGroup:Switch("Auto Follow Hero", true),
        AutoFollowCount = autoGroup:Slider("Spiders Following", 0, 15, 2, "%d"),
        AutoFollowRadius = autoGroup:Slider("Follow Radius", 100, 600, 300, "%d"),
        AutoChase = autoGroup:Switch("Auto Chase Enemies", true),
        AutoChaseRadius = autoGroup:Slider("Chase Radius", 800, 2000, 1200, "%d"),
        AutoSplit = autoGroup:Switch("Auto Split Attack", true),
        AutoSplitMax = autoGroup:Slider("Max Per Target", 3, 20, 6, "%d"),
        PlayerOverride = autoGroup:Slider("Manual Control Duration", 0.5, 5.0, 3.0, "%.1f"),
        AutoFarmCreeps = autoGroup:Switch("Auto Farm Creeps", false),
        AutoFarmRadius = autoGroup:Slider("Farm Radius", 600, 2000, 1200, "%d"),
        AutoFarmCampRange = autoGroup:Slider("Camp Search Radius", 300, 900, 600, "%d"),

        AutoStackCamps = stackGroup:Switch("Enable stack by key", true),
        StackKey = stackGroup:Bind("Stack key (send spiders)", Enum.ButtonCode.KEY_NONE),
        StackRadius = stackGroup:Slider("Max distance to camp", 2000, 6000, 4000, "%d"),

        AutoSoulRing = itemsGroup:Switch("Auto Soul Ring", true, (Config.UI.UsePanoramaIcons and Config.UI.Icons.Soul) or Config.UI.Icons.SoulFallback),
        SmartBloodthorn = itemsGroup:Switch("Smart Orchid/Bloodthorn", true, (Config.UI.UsePanoramaIcons and Config.UI.Icons.Blood) or Config.UI.Icons.BloodFallback),
        BloodthornRange = itemsGroup:Slider("Cast Range", 500, 1100, 900, "%d"),
        BloodthornHPThreshold = itemsGroup:Slider("HP Threshold (%)", 30, 100, 70, "%d"),
        BloodthornDelay = itemsGroup:Slider("Cast Delay (ms)", 0, 500, 100, "%d"),

        WebHelperEnabled = webGroup:Switch("Show Web Points", true),
        ShowWebPointsOnlyAlt = webGroup:Switch("Show Only When ALT Pressed", false),
        WebClickToCast = webGroup:Switch("Click to Cast", true),
    }
end

local UI = InitializeUI()
local panelX, panelY = LoadPanelPosition()

followRole = followRole or {}
followLastOrder = followLastOrder or {}
chaseRole = chaseRole or {}
chaseLastOrder = chaseLastOrder or {}
splitRole = splitRole or {}
splitTarget = splitTarget or {}
playerOverrideRole = playerOverrideRole or {}
playerOverrideUntil = playerOverrideUntil or {}
farmRole = farmRole or {}
farmLastOrder = farmLastOrder or {}
lastStackCampTime = lastStackCampTime or {}

local HeroIconCache = {}
local AbilityIconCache = {}
local spiderCache = {}
local lastCacheUpdate = 0

globalManualOverrideUntil = 0

local State = {
    spiders = {},
    lastSoulRingTime = 0,
    juggling = false,
    lastGatherTime = 0,
    lastGatherPos = nil,
    spiderlingCount = 0,
    spideriteCount = 0,
    juggleTime = 0,
    panelPos = {x = panelX, y = panelY},
    isDragging = false,
    dragOffset = {x = 0, y = 0},
    killCandidateName = nil,
    webPoints = BuiltInWebPoints,
    webMouseWasDown = false,
    webAltAlpha = 0,
    webAltLastActive = false,
    panelAnimation = {
        cellsAlpha = 0,
        titleAlpha = 255,
        headerAlpha = 255,
        cellsTargetAlpha = 0,
        titleTargetAlpha = 255,
        headerTargetAlpha = 255,
        lastSpiderCount = 0,
        headerInCellsPosition = true
    },
}

-- ═══════════════════════════════════════════════════════════════════════════
--  Пауки: кэш, контроль, переопределение игроком
-- ═══════════════════════════════════════════════════════════════════════════

local function GetAllSpiders()
    local now = os.clock()
    if now - lastCacheUpdate < SPIDER_CACHE_TTL then
        return spiderCache
    end
    
    local myHero = Heroes.GetLocal()
    if not myHero then 
        spiderCache = {}
        return spiderCache 
    end

    local playerId = Hero.GetPlayerID(myHero)
    local allNPCs = NPCs.GetAll()
    local result = {}
    local spiderlingCount = 0
    local spideriteCount = 0

    for i = 1, #allNPCs do
        local npc = allNPCs[i]
        if Entity.IsAlive(npc) and Entity.IsControllableByPlayer(npc, playerId) then
            local unitName = NPC.GetUnitName(npc)
            if unitName == "npc_dota_broodmother_spiderling" then
                result[#result + 1] = npc
                spiderlingCount = spiderlingCount + 1
            elseif unitName == "npc_dota_broodmother_spiderite" then
                spideriteCount = spideriteCount + 1
            end
        end
    end

    State.spiderlingCount = spiderlingCount
    State.spideriteCount = spideriteCount
    spiderCache = result
    lastCacheUpdate = now

    return result
end

local function IsSpiderUnderPlayerOverride(spider)
    local id = Entity.GetIndex(spider)
    local untilTime = playerOverrideUntil[id]
    return untilTime and os.clock() < untilTime
end

local function GetControllableSpiders()
    local spiders = GetAllSpiders()
    local result = {}
    
    if os.clock() < globalManualOverrideUntil then
        return result
    end
    
    for i = 1, #spiders do
        if not IsSpiderUnderPlayerOverride(spiders[i]) then
            result[#result + 1] = spiders[i]
        end
    end
    return result
end

local function CleanupPlayerOverride()
    local now = os.clock()
    local toRemove = {}
    
    for id, t in pairs(playerOverrideUntil) do
        if now >= t then
            toRemove[#toRemove + 1] = id
        end
    end
    
    for i = 1, #toRemove do
        local id = toRemove[i]
        playerOverrideUntil[id] = nil
        playerOverrideRole[id] = nil
    end
    
    local alive = {}
    local spiders = GetAllSpiders()
    for i = 1, #spiders do
        alive[Entity.GetIndex(spiders[i])] = true
    end
    
    for id, _ in pairs(playerOverrideRole) do
        if not alive[id] then
            playerOverrideRole[id] = nil
            playerOverrideUntil[id] = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Авто-логика: следование, чейз, сплит, фарм
-- ═══════════════════════════════════════════════════════════════════════════

local function AutoFollowSpiders()
    if not UI.AutoFollow:Get() then return end
    local spiders = GetControllableSpiders()
    local myHero = Heroes.GetLocal()
    if not myHero or #spiders == 0 then return end
    
    local now = os.clock()
    local enemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}
    
    if #enemies > 0 then
        for i = 1, #spiders do
            followRole[Entity.GetIndex(spiders[i])] = nil
        end
        return
    end
    
    local freeSpiders = {}
    for i = 1, #spiders do
        local id = Entity.GetIndex(spiders[i])
        if not chaseRole[id] and not splitRole[id] and not farmRole[id] then
            freeSpiders[#freeSpiders + 1] = spiders[i]
        else
            followRole[id] = nil
        end
    end
    
    local count = math.min(UI.AutoFollowCount:Get(), #freeSpiders)
    local selected = {}
    for i = 1, count do
        if freeSpiders[i] then
            local id = Entity.GetIndex(freeSpiders[i])
            followRole[id] = true
            selected[#selected + 1] = freeSpiders[i]
        end
    end
    
    for i = 1, #spiders do
        local id = Entity.GetIndex(spiders[i])
        if not chaseRole[id] and not splitRole[id] and not farmRole[id] then
            local found = false
            for j = 1, #selected do
                if Entity.GetIndex(selected[j]) == id then 
                    found = true 
                    break 
                end
            end
            if not found then 
                followRole[id] = nil 
            end
        elseif followRole[id] then
            followRole[id] = nil
        end
    end
    
    for i = 1, #selected do
        local spider = selected[i]
        local id = Entity.GetIndex(spider)
        if not followLastOrder[id] or (now - followLastOrder[id] > ORDER_INTERVAL_FOLLOW) then
            local heroPos = Entity.GetAbsOrigin(myHero)
            local radius = UI.AutoFollowRadius:Get()
            local angle = math.rad(math.random(0, 359))
            local dist = math.random(100, radius)
            local offset = Vector(math.cos(angle), math.sin(angle), 0) * dist
            local targetPos = heroPos + offset
            
            Player.PrepareUnitOrders(
                Players.GetLocal(),
                Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil,
                targetPos,
                nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                spider,
                false, false, false, false,
                "brood_auto_follow"
            )
            followLastOrder[id] = now
        end
    end
end

local function IsHeroUnderPressure(myHero)
    if not myHero then return false end
    local enemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}
    if #enemies > 0 then return true end
    if NPC.IsAttacking(myHero) then return true end
    return false
end

local function AutoChaseEnemies()
    if not UI.AutoChase:Get() then return end
    local spiders = GetControllableSpiders()
    local myHero = Heroes.GetLocal()
    if not myHero or #spiders == 0 then return end
    
    local now = os.clock()
    local radius = UI.AutoChaseRadius:Get()
    local enemies = Entity.GetHeroesInRadius(myHero, radius, Enum.TeamType.TEAM_ENEMY, true) or {}
    
    if #enemies == 0 then
        for i = 1, #spiders do
            chaseRole[Entity.GetIndex(spiders[i])] = nil
        end
        return
    end
    
    for i = 1, #spiders do
        local spider = spiders[i]
        local id = Entity.GetIndex(spider)
        if not followRole[id] and not splitRole[id] then
            local closestEnemy = nil
            local closestDist = math.huge
            
            local spiderPos = Entity.GetAbsOrigin(spider)
            for j = 1, #enemies do
                local enemy = enemies[j]
                if Entity.IsAlive(enemy) then
                    local enemyPos = Entity.GetAbsOrigin(enemy)
                    local dist = (spiderPos - enemyPos):Length()
                    if dist < closestDist then
                        closestDist = dist
                        closestEnemy = enemy
                    end
                end
            end
            
            if closestEnemy then
                chaseRole[id] = true
                if not chaseLastOrder[id] or (now - chaseLastOrder[id] > ORDER_INTERVAL_CHASE) then
                    Player.PrepareUnitOrders(
                        Players.GetLocal(),
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                        closestEnemy,
                        Vector(0, 0, 0),
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        spider,
                        false, false, false, false,
                        "brood_auto_chase"
                    )
                    chaseLastOrder[id] = now
                end
            end
        else
            chaseRole[id] = nil
        end
    end
end

local function AutoSplitAttack()
    if not UI.AutoSplit:Get() then return end
    local spiders = GetControllableSpiders()
    local myHero = Heroes.GetLocal()
    if not myHero or #spiders == 0 then return end
    
    local enemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}
    
    if #enemies < 2 then
        for i = 1, #spiders do
            local id = Entity.GetIndex(spiders[i])
            splitRole[id] = nil
            splitTarget[id] = nil
        end
        return
    end
    
    local targetCounts = {}
    for i = 1, #spiders do
        local id = Entity.GetIndex(spiders[i])
        local target = splitTarget[id]
        if target and Entity.IsAlive(target) then
            local targetId = Entity.GetIndex(target)
            targetCounts[targetId] = (targetCounts[targetId] or 0) + 1
        end
    end
    
    local maxPerTarget = UI.AutoSplitMax:Get()
    for i = 1, #spiders do
        local spider = spiders[i]
        local id = Entity.GetIndex(spider)
        if not followRole[id] then
            local currentTarget = splitTarget[id]
            local needNewTarget = false
            
            if currentTarget then
                local targetId = Entity.GetIndex(currentTarget)
                if not Entity.IsAlive(currentTarget) or (targetCounts[targetId] or 0) > maxPerTarget then
                    needNewTarget = true
                end
            else
                needNewTarget = true
            end
            
            if needNewTarget then
                local bestTarget = nil
                local lowestCount = math.huge
                for j = 1, #enemies do
                    local enemy = enemies[j]
                    if Entity.IsAlive(enemy) then
                        local enemyId = Entity.GetIndex(enemy)
                        local count = targetCounts[enemyId] or 0
                        if count < lowestCount and count < maxPerTarget then
                            lowestCount = count
                            bestTarget = enemy
                        end
                    end
                end
                
                if bestTarget then
                    splitTarget[id] = bestTarget
                    targetCounts[Entity.GetIndex(bestTarget)] = lowestCount + 1
                    splitRole[id] = true
                    
                    Player.PrepareUnitOrders(
                        Players.GetLocal(),
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                        bestTarget,
                        Vector(0, 0, 0),
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        spider,
                        false, false, false, false,
                        "brood_auto_split"
                    )
                end
            end
        else
            splitRole[id] = nil
            splitTarget[id] = nil
        end
    end
end

local function AutoFarmCreeps()
    if not UI.AutoFarmCreeps:Get() then return end
    
    local myHero = Heroes.GetLocal()
    if not myHero or not Entity.IsAlive(myHero) then return end
    
    local myPlayer = Players.GetLocal()
    if not myPlayer then return end
    
    local now = os.clock()
    
    if IsHeroUnderPressure(myHero) then
        local spiders = GetAllSpiders()
        for i = 1, #spiders do
            farmRole[Entity.GetIndex(spiders[i])] = nil
        end
        return
    end
    
    local spiders = GetControllableSpiders()
    if #spiders == 0 then return end
    
    local heroPos = Entity.GetAbsOrigin(myHero)
    local farmRadius = UI.AutoFarmRadius:Get()
    local allNPCs = NPCs.GetAll()
    local targets = {}
    
    for i = 1, #allNPCs do
        local npc = allNPCs[i]
        if Entity.IsAlive(npc) and NPC.IsCreep(npc) and not NPC.IsAncient(npc) then
            if Entity.GetTeamNum(npc) ~= Entity.GetTeamNum(myHero) then
                local npcPos = Entity.GetAbsOrigin(npc)
                local dist = (heroPos - npcPos):Length()
                if dist <= farmRadius then
                    targets[#targets + 1] = npc
                end
            end
        end
    end
    
    if #targets < 3 then
        local campRange = UI.AutoFarmCampRange:Get()
        for i = 1, #allNPCs do
            local npc = allNPCs[i]
            if Entity.IsAlive(npc) and NPC.IsCreep(npc) and not NPC.IsAncient(npc) then
                if Entity.GetTeamNum(npc) ~= Entity.GetTeamNum(myHero) then
                    local npcPos = Entity.GetAbsOrigin(npc)
                    local dist = (heroPos - npcPos):Length()
                    if dist <= farmRadius + campRange then
                        local alreadyInTargets = false
                        for j = 1, #targets do
                            if targets[j] == npc then
                                alreadyInTargets = true
                                break
                            end
                        end
                        if not alreadyInTargets then
                            targets[#targets + 1] = npc
                        end
                    end
                end
            end
        end
    end
    
    if #targets == 0 then 
        for i = 1, #spiders do
            farmRole[Entity.GetIndex(spiders[i])] = nil
        end
        return 
    end
    
    for i = 1, #spiders do
        local spider = spiders[i]
        local spiderId = Entity.GetIndex(spider)
        
        if chaseRole[spiderId] or splitRole[spiderId] then
            farmRole[spiderId] = nil
            farmLastOrder[spiderId] = nil
        else
            farmRole[spiderId] = true
            followRole[spiderId] = nil
            
            local spiderPos = Entity.GetAbsOrigin(spider)
            local bestTarget = nil
            local bestDist = math.huge
            
            for j = 1, #targets do
                local target = targets[j]
                if Entity.IsAlive(target) then
                    local targetPos = Entity.GetAbsOrigin(target)
                    local dist = (spiderPos - targetPos):Length()
                    if dist < bestDist then
                        bestDist = dist
                        bestTarget = target
                    end
                end
            end
            
            if bestTarget and (not farmLastOrder[spiderId] or (now - farmLastOrder[spiderId] > ORDER_INTERVAL_FARM)) then
                Player.PrepareUnitOrders(
                    myPlayer,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                    bestTarget,
                    Vector(0, 0, 0),
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    spider,
                    false, false, false, false,
                    "brood_auto_farm"
                )
                farmLastOrder[spiderId] = now
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Авто-стак нейтральных кампов паучками (:53–:55), как в Auto Stacker By GLTM
--  Используем ATTACK_MOVE в центр кампа — паук идёт бить, нейтралы выходят.
-- ═══════════════════════════════════════════════════════════════════════════

local function vecX(v)
    if not v then return 0 end
    return type(v.GetX) == "function" and v:GetX() or (v.x or 0)
end
local function vecY(v)
    if not v then return 0 end
    return type(v.GetY) == "function" and v:GetY() or (v.y or 0)
end
local function vecZ(v)
    if not v then return 0 end
    return type(v.GetZ) == "function" and v:GetZ() or (v.z or 0)
end

local function GetCampBoxCenter(camp)
    if not camp then return nil end
    local box = Camp.GetCampBox(camp)
    if not box or not box.min or not box.max then return nil end
    local cx = (vecX(box.min) + vecX(box.max)) * 0.5
    local cy = (vecY(box.min) + vecY(box.max)) * 0.5
    local cz = (vecZ(box.min) + vecZ(box.max)) * 0.5
    return Vector(cx, cy, cz)
end

-- ─── Стак по кнопке (логика GLTM): точки кампа, ближайший лагерь, strike center ───
local function GetStackCampPoints(campId)
    return CAMP_POINTS[campId]
end

local function StackGameTimeSeconds()
    local t = (GameRules.GetGameTime() or 0) - (GameRules.GetGameStartTime and GameRules.GetGameStartTime() or 0)
    return t < 0 and 0 or t
end

local function FindClosestRealCamp(pos)
    local all = (Camps and Camps.GetAll and Camps.GetAll()) or {}
    if not all or #all == 0 then return nil end
    local bestCamp, bestDist = nil, math.huge
    for _, c in ipairs(all) do
        local center = GetCampBoxCenter(c)
        if center then
            local d = (center - pos):Length2D()
            if d < bestDist then
                bestDist = d
                bestCamp = c
            end
        end
    end
    return bestCamp
end

local function EnsureStrikeCenterForCamp(campId)
    if stackCampStrikeCenters[campId] then return end
    local points = GetStackCampPoints(campId)
    if not points then return end
    local realCamp = FindClosestRealCamp(points.wait)
    if not realCamp then return end
    local center = GetCampBoxCenter(realCamp)
    if center then
        stackCampStrikeCenters[campId] = center
        local box = Camp.GetCampBox(realCamp)
        if box and box.min and box.max then
            stackCampBoxes[campId] = { min = box.min, max = box.max }
        end
    end
end

local function AssignSpidersToNearestCamps(units)
    local assignment = {}
    local availableCampIds = {}
    for campId, _ in pairs(CAMP_POINTS) do
        availableCampIds[#availableCampIds + 1] = campId
    end
    -- Храним по индексу сущности, чтобы не получать bad argument (entity может стать числом в ключе)
    if #units <= #availableCampIds then
        for _, u in ipairs(units) do
            local unitPos = Entity.GetAbsOrigin(u)
            if unitPos then
                local bestCamp, bestDist, bestIdx = nil, math.huge, nil
                for idx, campId in ipairs(availableCampIds) do
                    local pts = GetStackCampPoints(campId)
                    if pts then
                        local d = (pts.wait - unitPos):Length2D()
                        if d < bestDist then
                            bestDist = d
                            bestCamp = campId
                            bestIdx = idx
                        end
                    end
                end
                if bestCamp then
                    assignment[Entity.GetIndex(u)] = bestCamp
                    table.remove(availableCampIds, bestIdx)
                end
            end
        end
    else
        for _, u in ipairs(units) do
            local unitPos = Entity.GetAbsOrigin(u)
            if unitPos then
                local bestCamp, bestDist = nil, math.huge
                for campId, _ in pairs(CAMP_POINTS) do
                    local pts = GetStackCampPoints(campId)
                    if pts then
                        local d = (pts.wait - unitPos):Length2D()
                        if d < bestDist then
                            bestDist = d
                            bestCamp = campId
                        end
                    end
                end
                if bestCamp then assignment[Entity.GetIndex(u)] = bestCamp end
            end
        end
    end
    return assignment
end

local function EnsureStackTimelineFor(unitOrIndex, minute)
    local idx = type(unitOrIndex) == "number" and unitOrIndex or Entity.GetIndex(unitOrIndex)
    if not idx then return nil end
    if not stackTimeline[idx] then stackTimeline[idx] = {} end
    if not stackTimeline[idx][minute] then
        stackTimeline[idx][minute] = {
            movedToWait = false,
            attackIssued = false,
            hitConfirmed = false,
            pullIssued = false,
        }
    end
    return stackTimeline[idx][minute]
end

local function PointInsideBox(pos, box, margin)
    if not box or not box.min or not box.max then return false end
    margin = margin or 0
    local x, y = pos:GetX(), pos:GetY()
    return (x >= (vecX(box.min) - margin)) and (x <= (vecX(box.max) + margin))
        and (y >= (vecY(box.min) - margin)) and (y <= (vecY(box.max) + margin))
end

local function EvaluateCampStacks(campId)
    local box = stackCampBoxes[campId]
    if not box then return 0 end
    local all = Entities.GetAll and Entities.GetAll() or {}
    local maxStacks = 0
    for _, e in pairs(all) do
        if Entity.IsAlive(e) and Entity.IsNPC(e) and NPC.IsCreep(e)
            and not (NPC.IsLaneCreep and NPC.IsLaneCreep(e)) and not (NPC.IsHero and NPC.IsHero(e)) then
            local pos = Entity.GetAbsOrigin(e)
            if pos and PointInsideBox(pos, box, 200) then
                local mod = NPC.GetModifier and NPC.GetModifier(e, "modifier_stacked_neutral")
                if mod then
                    local c = Modifier.GetStackCount and Modifier.GetStackCount(mod) or 0
                    if c > maxStacks then maxStacks = c end
                end
            end
        end
    end
    return maxStacks
end

local function StackMoveUnitTo(player, unit, pos)
    if not unit or not Entity.IsAlive(unit) or not pos then return end
    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
        nil,
        pos,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        unit,
        false, false, false, false,
        "brood_stack_move"
    )
end

local function StackAttackMoveUnitTo(player, unit, pos)
    if not unit or not Entity.IsAlive(unit) or not pos then return end
    Player.PrepareUnitOrders(
        player,
        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_MOVE,
        nil,
        pos,
        nil,
        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
        unit,
        false, false, false, false,
        "brood_stack_attack"
    )
end

local function BeginStackSession()
    local spiders = GetControllableSpiders()
    if #spiders == 0 then return false end
    stackUnitToCampId = AssignSpidersToNearestCamps(spiders)
    stackLastCampStacks = {}
    for _, campId in pairs(stackUnitToCampId) do
        EnsureStrikeCenterForCamp(campId)
    end
    stackTimeline = {}
    return true
end

local function AutoStackCampsLogic()
    if not UI.AutoStackCamps or not UI.AutoStackCamps:Get() then return end
    local myPlayer = Players.GetLocal()
    if not myPlayer then return end

    -- Переключение сессии по кнопке (без выделения пауков)
    local keyPressed = UI.StackKey and UI.StackKey:IsPressed()
    if keyPressed and not stackWasKeyHeld then
        stackSessionActive = not stackSessionActive
        if stackSessionActive then
            if not BeginStackSession() then
                stackSessionActive = false
            end
        else
            stackUnitToCampId = {}
            stackTimeline = {}
        end
    end
    stackWasKeyHeld = keyPressed
    if not stackSessionActive then return end

    -- Живые пауки из текущего назначения (по индексу, берём актуальные entity из текущего кадра)
    local alive = {}
    local spiders = GetControllableSpiders()
    for i = 1, #spiders do
        local u = spiders[i]
        local id = Entity.GetIndex(u)
        if id and stackUnitToCampId[id] and Entity.IsAlive(u) then
            alive[#alive + 1] = u
        end
    end
    if #alive == 0 then
        stackSessionActive = false
        return
    end

    local t = StackGameTimeSeconds()
    local minute = math.floor(t / 60)
    local sec = t % 60
    -- Паучки мелевые, baseHit = STACK_FIRST_HIT_MELEE
    local baseHit = STACK_FIRST_HIT_MELEE

    for _, u in ipairs(alive) do
        local campId = stackUnitToCampId[Entity.GetIndex(u)]
        if not campId then goto continue_unit end
        local points = GetStackCampPoints(campId)
        local strike = stackCampStrikeCenters[campId]
        if not strike then
            EnsureStrikeCenterForCamp(campId)
            strike = stackCampStrikeCenters[campId]
            if not strike then goto continue_unit end
        end
        local st = EnsureStackTimelineFor(u, minute)

        -- Обновление стаков по кампу (раз в минуту)
        if sec >= 50 then
            if (stackCampStacksMinute[campId] or -1) ~= minute then
                local stacksNow = EvaluateCampStacks(campId)
                local lastStacks = stackLastCampStacks[campId] or 0
                stackCampStacks[campId] = stacksNow
                stackCampStacksMinute[campId] = minute
                stackLastCampStacks[campId] = stacksNow
            end
        end
        local stacks = stackCampStacks[campId] or 0
        local effFirstHit = math.max(52, math.min(54, baseHit - (stacks * STACK_PER_STACK_SHIFT)))

        if sec < effFirstHit then
            if not st.movedToWait then
                st.movedToWait = true
                StackMoveUnitTo(myPlayer, u, points.wait)
            end
        else
            if (sec >= effFirstHit) and (sec < (effFirstHit + 2)) and not st.attackIssued then
                st.attackIssued = true
                StackAttackMoveUnitTo(myPlayer, u, strike)
            end
            if st.hitConfirmed and not st.pullIssued then
                st.pullIssued = true
                StackMoveUnitTo(myPlayer, u, points.pull)
            elseif (sec >= 57) and (sec < 58) and not st.pullIssued then
                st.pullIssued = true
                StackMoveUnitTo(myPlayer, u, points.pull)
            end
        end
        ::continue_unit::
    end
end

local function GatherSpiders()
    if not UI.GatherKey:IsPressed() then return end

    local currentTime = GameRules.GetGameTime()
    local gatherDelay = UI.GatherDelay:Get() / 1000

    if currentTime - State.lastGatherTime < gatherDelay then return end

    local myHero = Heroes.GetLocal()
    if not myHero then return end

    local cursorPos = Input.GetWorldCursorPos()
    if not cursorPos then
        cursorPos = Entity.GetAbsOrigin(myHero)
    end

    local spiders = GetAllSpiders()
    State.juggling = false
    State.lastGatherTime = currentTime
    State.lastGatherPos = cursorPos

    if #spiders > 0 then
        local myPlayer = Players.GetLocal()
        for i = 1, #spiders do
            if Entity.IsAlive(spiders[i]) then
                Player.PrepareUnitOrders(
                    myPlayer,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil,
                    cursorPos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    spiders[i],
                    false, false, false, false,
                    "brood_gather"
                )
            end
        end
    end
end

local function JuggleSpiders()
    if not UI.JuggleKey:IsPressed() then return end

    local myHero = Heroes.GetLocal()
    if not myHero then return end

    local heroPos = Entity.GetAbsOrigin(myHero)
    local radius = UI.JuggleRadius:Get()
    local spiders = GetAllSpiders()
    local count = math.min(UI.JuggleCount:Get(), #spiders)

    if count > 0 then
        local myPlayer = Players.GetLocal()
        for i = 1, count do
            if spiders[i] and Entity.IsAlive(spiders[i]) then
                local angle = (i - 1) * (2 * math.pi / count)
                local x = heroPos.x + radius * math.cos(angle)
                local y = heroPos.y + radius * math.sin(angle)
                local targetPos = Vector(x, y, heroPos.z)

                Player.PrepareUnitOrders(
                    myPlayer,
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil,
                    targetPos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    spiders[i],
                    false, false, false, false,
                    "brood_juggle"
                )
            end
        end
    end

    State.juggling = true
    State.juggleTime = GameRules.GetGameTime()
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Предметы: Bloodthorn, Orchid, Manta (враг), Soul Ring
-- ═══════════════════════════════════════════════════════════════════════════

local function GetBloodthornItem(hero)
    if not hero then return nil end
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(hero, i)
        if item and Ability.GetName(item) == "item_bloodthorn" then
            return item
        end
    end
    return nil
end

local function GetOrchidItem(hero)
    if not hero then return nil end
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(hero, i)
        if item and Ability.GetName(item) == "item_orchid" then
            return item
        end
    end
    return nil
end

local function GetMantaItem(enemy)
    if not enemy then return nil end
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(enemy, i)
        if item and Ability.GetName(item) == "item_manta" then
            return item
        end
    end
    return nil
end

local function HasActiveMantaIllusions(enemy)
    if not enemy then return false end
    local enemyPos = Entity.GetAbsOrigin(enemy)
    local allNPCs = NPCs.GetAll()
    local enemyName = NPC.GetUnitName(enemy)
    
    for i = 1, #allNPCs do
        local npc = allNPCs[i]
        if NPC.IsIllusion(npc) and Entity.IsAlive(npc) and 
           NPC.GetUnitName(npc) == enemyName and
           Entity.GetTeamNum(npc) == Entity.GetTeamNum(enemy) then
            local illuPos = Entity.GetAbsOrigin(npc)
            local dist = (enemyPos - illuPos):Length()
            if dist < 800 then
                return true
            end
        end
    end
    return false
end

local function IsMantaOnCooldown(enemy)
    local manta = GetMantaItem(enemy)
    if not manta then return true end
    local cd = Ability.GetCooldown(manta)
    local buffer = UI.BloodthornDelay:Get() / 1000
    return cd > buffer
end

local function ShouldWaitForManta(enemy)
    local manta = GetMantaItem(enemy)
    if not manta then return false end
    if IsMantaOnCooldown(enemy) then return false end
    if HasActiveMantaIllusions(enemy) then return true end
    
    local enemyHP = Entity.GetHealth(enemy)
    local enemyMaxHP = Entity.GetMaxHealth(enemy)
    local hpPercent = (enemyHP / enemyMaxHP) * 100
    if hpPercent < 25 then return false end
    return true
end

local function FindBloodthornTarget(myHero)
    if not myHero then return nil end
    
    local range = UI.BloodthornRange:Get()
    local hpThreshold = UI.BloodthornHPThreshold:Get()
    local enemies = Entity.GetHeroesInRadius(myHero, range, Enum.TeamType.TEAM_ENEMY, true) or {}
    
    local validTargets = {}
    for i = 1, #enemies do
        local enemy = enemies[i]
        if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) and NPC.IsVisible(enemy) then
            local enemyHP = Entity.GetHealth(enemy)
            local enemyMaxHP = Entity.GetMaxHealth(enemy)
            local hpPercent = (enemyHP / enemyMaxHP) * 100
            
                if hpPercent <= hpThreshold then
                if not NPC.HasModifier(enemy, "modifier_item_bloodthorn_debuff") and
                   not NPC.HasModifier(enemy, "modifier_item_orchid_malevolence_debuff") and
                   not NPC.HasModifier(enemy, "modifier_teleporting") and
                   not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) and
                   not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) and
                   not NPC.IsLinkensProtected(enemy) then
                    
                    if not ShouldWaitForManta(enemy) then
                        local score = (100 - hpPercent)
                        if IsMantaOnCooldown(enemy) then score = score + 30 end
                        if not HasActiveMantaIllusions(enemy) then score = score + 20 end
                        validTargets[#validTargets + 1] = {enemy = enemy, score = score}
                    end
                end
            end
        end
    end
    
    if #validTargets == 0 then return nil end
    table.sort(validTargets, function(a, b) return a.score > b.score end)
    return validTargets[1].enemy
end

local function AutoBloodthorn()
    if not UI.SmartBloodthorn:Get() then return end
    local myHero = Heroes.GetLocal()
    if not myHero then return end
    
    local bloodthorn = GetBloodthornItem(myHero)
    if not bloodthorn then return end
    
    if not Ability.IsReady(bloodthorn) or not Ability.IsCastable(bloodthorn, NPC.GetMana(myHero)) then return end
    
    local now = GameRules.GetGameTime()
    if now - State.lastSoulRingTime < 0.3 then return end
    
    local target = FindBloodthornTarget(myHero)
    if not target then return end
    
    local myPos = Entity.GetAbsOrigin(myHero)
    local targetPos = Entity.GetAbsOrigin(target)
    local dist = (myPos - targetPos):Length()
    local castRange = Ability.GetCastRange(bloodthorn) or 900
    
    if dist <= castRange then
        Ability.CastTarget(bloodthorn, target)
        State.lastSoulRingTime = now
        State.killCandidateName = NPC.GetUnitName(target)
    end
end

local function AutoOrchid()
    if not UI.SmartBloodthorn:Get() then return end
    local myHero = Heroes.GetLocal()
    if not myHero then return end
    
    local orchid = GetOrchidItem(myHero)
    if not orchid then return end
    
    if not Ability.IsReady(orchid) or not Ability.IsCastable(orchid, NPC.GetMana(myHero)) then return end
    
    local now = GameRules.GetGameTime()
    if now - State.lastSoulRingTime < 0.3 then return end
    
    local target = FindBloodthornTarget(myHero)
    if not target then return end
    
    local myPos = Entity.GetAbsOrigin(myHero)
    local targetPos = Entity.GetAbsOrigin(target)
    local dist = (myPos - targetPos):Length()
    local castRange = Ability.GetCastRange(orchid) or 900
    
    if dist <= castRange then
        Ability.CastTarget(orchid, target)
        State.lastSoulRingTime = now
        State.killCandidateName = NPC.GetUnitName(target)
    end
end

local function AutoSoulRing()
    if not UI.AutoSoulRing:Get() then return end
    local myHero = Heroes.GetLocal()
    if not myHero then return end
    
    local spawnAbility = NPC.GetAbility(myHero, "broodmother_spawn_spiderlings")
    if not spawnAbility then return end
    
    if not Ability.IsInAbilityPhase(spawnAbility) and not Ability.IsChannelling(spawnAbility) then
        return
    end
    
    local soulRing = NPC.GetItem(myHero, "item_soul_ring")
    if soulRing and Ability.IsCastable(soulRing, 0) then
        local soulRingActive = NPC.HasModifier(myHero, "modifier_item_soul_ring_buff")
        if not soulRingActive then
            Ability.CastNoTarget(soulRing)
            State.lastSoulRingTime = GameRules.GetGameTime()
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Отрисовка: панель, ячейки, веб-поинты, иконки
-- ═══════════════════════════════════════════════════════════════════════════

local function GetHeroIconHandle(unitName)
    if not unitName then return nil end
    if HeroIconCache[unitName] then return HeroIconCache[unitName] end
    local path = "panorama/images/heroes/icons/" .. unitName .. "_png.vtex_c"
    local handle = Render.LoadImage(path)
    HeroIconCache[unitName] = handle
    return handle
end

local function GetAbilityIconHandle(abilityName)
    if not abilityName then return nil end
    if AbilityIconCache[abilityName] then return AbilityIconCache[abilityName] end
    local path = "panorama/images/spellicons/" .. abilityName .. "_png.vtex_c"
    local handle = Render.LoadImage(path)
    AbilityIconCache[abilityName] = handle
    return handle
end

local function DrawBlurredBackground(x, y, width, height, radius, blurStrength, alpha)
    Render.Blur(
        Vec2(x, y),
        Vec2(x + width, y + height),
        blurStrength,
        alpha,
        radius,
        Enum.DrawFlags.None
    )
end

local function DrawCell(x, y, alpha, text, fontSize, textColor)
    local size = PanelConfig.CellSize
    DrawBlurredBackground(x, y, size, size, 6, 8, 0.97 * (alpha / 255))
    Render.Shadow(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(alpha)),
        24,
        6,
        Enum.DrawFlags.ShadowCutOutShapeBackground,
        Vec2(1, 1)
    )
    Render.FilledRect(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(140 * alpha / 255)),
        6
    )

    local textSize = Render.TextSize(Config.Fonts.Main, fontSize, text)
    local textX = x + (size - textSize.x) / 2
    local textY = y + (size - textSize.y) / 2

    Render.Text(Config.Fonts.Main, fontSize, text, Vec2(textX + 1, textY + 1), Color(0, 0, 0, math.floor(alpha * 0.4)))
    Render.Text(Config.Fonts.Main, fontSize, text, Vec2(textX, textY), Color(textColor.r, textColor.g, textColor.b, math.floor(alpha)))
end

local function DrawIconCell(x, y, alpha, imageHandle, scale, rounding)
    local size = PanelConfig.CellSize
    DrawBlurredBackground(x, y, size, size, 6, 8, 0.97 * (alpha / 255))
    Render.Shadow(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(alpha)),
        24,
        6,
        Enum.DrawFlags.ShadowCutOutShapeBackground,
        Vec2(1, 1)
    )
    Render.FilledRect(
        Vec2(x, y),
        Vec2(x + size, y + size),
        Color(0, 0, 0, math.floor(140 * alpha / 255)),
        6
    )

    if imageHandle then
        local basePad = 2
        local iconScale = math.max(0.5, math.min(scale or 1.0, 1.0))
        local inner = (size - basePad * 2)
        local iconSize = math.floor(inner * iconScale)
        local offset = math.floor((inner - iconSize) / 2)
        local pos = Vec2(x + basePad + offset + 0.5, y + basePad + 1 + offset)
        local sz = Vec2(iconSize, iconSize)
        local r = rounding or 0
        r = math.max(0, math.min(r, math.floor(iconSize / 2)))
        Render.Image(imageHandle, pos, sz, Color(255, 255, 255, math.floor(alpha)), r)
    end
end

local function AnimateAlpha(current, target, speed)
    if current < target then
        return math.min(current + speed, target)
    elseif current > target then
        return math.max(current - speed, target)
    end
    return current
end

local function GetSpiderStatus(spiders)
    spiders = spiders or GetAllSpiders()
    local totalSpiders = #spiders

    if totalSpiders == 0 then
        return "0", "Idle"
    end

    local status = "Idle"
    if State.juggling and (GameRules.GetGameTime() - State.juggleTime < 3) then
        status = "Spread"
    elseif State.lastGatherPos and (GameRules.GetGameTime() - State.lastGatherTime < 2) then
        status = "Gather"
    else
        local attackingCount = 0
        for i = 1, #spiders do
            if NPC.IsAttacking(spiders[i]) then
                attackingCount = attackingCount + 1
            end
        end
        if attackingCount > totalSpiders * 0.3 then
            status = "Attack"
        end
    end

    return tostring(totalSpiders), status
end

local function GetAverageSpiderHP(spiders)
    spiders = spiders or GetAllSpiders()
    if #spiders == 0 then return 0 end

    local totalHP = 0
    local totalMaxHP = 0

    for i = 1, #spiders do
        totalHP = totalHP + Entity.GetHealth(spiders[i])
        totalMaxHP = totalMaxHP + Entity.GetMaxHealth(spiders[i])
    end

    if totalMaxHP == 0 then return 0 end
    return math.floor((totalHP / totalMaxHP) * 100)
end

local function HandlePanelInput()
    local cursorX, cursorY = Input.GetCursorPos()

    local headerY = State.panelPos.y
    if State.panelAnimation.headerInCellsPosition then
        headerY = State.panelPos.y + PanelConfig.HeaderHeight + 5
    end

    local isInHeader = cursorX >= State.panelPos.x and cursorX <= State.panelPos.x + PanelConfig.Width and
                      cursorY >= headerY and cursorY <= headerY + PanelConfig.HeaderHeight

    if isInHeader and Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) and not State.isDragging then
        State.isDragging = true
        State.dragOffset.x = cursorX - State.panelPos.x
        State.dragOffset.y = cursorY - State.panelPos.y
    end

    if State.isDragging then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            State.panelPos.x = cursorX - State.dragOffset.x
            State.panelPos.y = cursorY - State.dragOffset.y

            local screenSize = Render.ScreenSize()
            State.panelPos.x = math.max(0, math.min(State.panelPos.x, screenSize.x - PanelConfig.Width))
            State.panelPos.y = math.max(0, math.min(State.panelPos.y, screenSize.y - PanelConfig.Height))
        else
            State.isDragging = false
            SavePanelPosition(State.panelPos.x, State.panelPos.y)
        end
    end
end

local function UpdatePanelAnimation()
    local spiders = GetAllSpiders()
    local currentSpiderCount = #spiders

    local nextInCells = (currentSpiderCount == 0)

    if currentSpiderCount ~= State.panelAnimation.lastSpiderCount then
        State.panelAnimation.lastSpiderCount = currentSpiderCount
        State.panelAnimation.cellsTargetAlpha = nextInCells and 0 or 255
    end

    if State.panelAnimation.headerInCellsPosition ~= nextInCells then
        if State.panelAnimation.headerAlpha > 0 then
            State.panelAnimation.headerTargetAlpha = 0
            if not nextInCells then
                State.panelAnimation.cellsTargetAlpha = 0
            end
        else
            State.panelAnimation.headerInCellsPosition = nextInCells
            State.panelAnimation.headerTargetAlpha = 255
            if not nextInCells then
                State.panelAnimation.cellsTargetAlpha = 255
            end
        end
    else
        State.panelAnimation.headerTargetAlpha = 255
    end

    local animationSpeed = 15

    State.panelAnimation.cellsAlpha  = AnimateAlpha(State.panelAnimation.cellsAlpha,  State.panelAnimation.cellsTargetAlpha,  animationSpeed)
    State.panelAnimation.headerAlpha = AnimateAlpha(State.panelAnimation.headerAlpha, State.panelAnimation.headerTargetAlpha, animationSpeed)

    State.panelAnimation.titleTargetAlpha = State.panelAnimation.headerTargetAlpha
    State.panelAnimation.titleAlpha = AnimateAlpha(State.panelAnimation.titleAlpha, State.panelAnimation.titleTargetAlpha, animationSpeed)
end

local function DrawPanel()
    if not UI.ShowPanel:Get() then return end

    UpdatePanelAnimation()
    HandlePanelInput()

    local headerY = State.panelPos.y
    if State.panelAnimation.headerInCellsPosition then
        headerY = State.panelPos.y + PanelConfig.HeaderHeight + 5
    end

    DrawBlurredBackground(State.panelPos.x, headerY, PanelConfig.Width, PanelConfig.HeaderHeight, PanelConfig.BorderRadius, PanelConfig.BlurStrengthHeader, 0.91 * (State.panelAnimation.headerAlpha / 255))

    Render.Shadow(
        Vec2(State.panelPos.x, headerY),
        Vec2(State.panelPos.x + PanelConfig.Width, headerY + PanelConfig.HeaderHeight),
        Color(0, 0, 0, math.floor(State.panelAnimation.headerAlpha)),
        24,
        PanelConfig.BorderRadius,
        Enum.DrawFlags.ShadowCutOutShapeBackground,
        Vec2(1, 1)
    )

    Render.FilledRect(
        Vec2(State.panelPos.x, headerY),
        Vec2(State.panelPos.x + PanelConfig.Width, headerY + PanelConfig.HeaderHeight),
        Color(PanelColors.Header.r, PanelColors.Header.g, PanelColors.Header.b, math.floor(PanelColors.Header.a * State.panelAnimation.headerAlpha / 255)),
        PanelConfig.BorderRadius
    )

    local iconHandle = GetHeroIconHandle("npc_dota_hero_broodmother")
    local iconSizePx = 18
    local iconX = State.panelPos.x + 8
    local iconY = headerY + (PanelConfig.HeaderHeight - iconSizePx) / 2
    if iconHandle then
        Render.Image(iconHandle, Vec2(iconX, iconY), Vec2(iconSizePx, iconSizePx), Color(255, 255, 255, math.floor(State.panelAnimation.headerAlpha)), 0)
    end

    local separatorX = iconX + iconSizePx + 8
    local separatorY = headerY + 4
    local separatorHeight = PanelConfig.HeaderHeight - 8

    Render.FilledRect(
        Vec2(separatorX, separatorY-4),
        Vec2(separatorX + 2, separatorY + separatorHeight + 4),
        Color(15, 15, 15, math.floor(70 * State.panelAnimation.headerAlpha / 255))
    )

    local title = "@spiders"
    local titleSize = Render.TextSize(Config.Fonts.Main, 12, title)
    local titleX = separatorX + 8
    local titleY = headerY + (PanelConfig.HeaderHeight - titleSize.y) / 2

    Render.Text(Config.Fonts.Main, 12, title, Vec2(titleX + 1, titleY + 1), Color(0, 0, 0, math.floor(State.panelAnimation.headerAlpha * 0.3)))
    Render.Text(Config.Fonts.Main, 12, title, Vec2(titleX, titleY), Color(170, 170, 170, math.floor(State.panelAnimation.headerAlpha)))

    local contentY = State.panelPos.y + PanelConfig.HeaderHeight + 5
    local cellStartX = State.panelPos.x + 8
    local cellY = contentY

    local spiders = GetAllSpiders()
    local spiderCount, spiderStatus = GetSpiderStatus(spiders)
    local avgHP = GetAverageSpiderHP(spiders)

    local myHero = Heroes.GetLocal()
    local webText, webColor = "-", Color(120, 200, 255, 255)
    local hungerText, hungerColor = "-", Color(255, 200, 120, 255)

    if myHero then
        local spinWeb = NPC.GetAbility(myHero, "broodmother_spin_web")
        if spinWeb then
            local charges = Ability.GetCurrentCharges(spinWeb)
            if charges and charges >= 0 then
                webText = tostring(charges)
                if charges == 0 then
                    webColor = Color(255, 120, 120, 255)
                end
            end
        end

        local hunger = NPC.GetAbility(myHero, "broodmother_insatiable_hunger")
        if hunger then
            if NPC.HasModifier(myHero, "modifier_broodmother_insatiable_hunger") then
                hungerText = "ON"
                hungerColor = Color(255, 200, 120, 255)
            elseif Ability.IsCastable(hunger, NPC.GetMana(myHero)) then
                hungerText = "RDY"
                hungerColor = Color(120, 255, 120, 255)
            else
                local cd = Ability.GetCooldown(hunger)
                hungerText = tostring(math.ceil(cd))
                hungerColor = Color(255, 120, 120, 255)
            end
        end
    end

    local cells = {
        {text = spiderCount, font = 12, color = Color(255, 255, 255, 255)},
        {
            text = (function()
                if spiderStatus == "Gather" then return "G" end
                if spiderStatus == "Spread" then return "S" end
                if spiderStatus == "Attack" then return "A" end
                return "I"
            end)(),
            font = 12,
            color = PanelColors.StatusColors[spiderStatus] or PanelColors.StatusColors["Idle"]
        },
        {
            text = tostring(avgHP) .. "%",
            font = 9,
            color = (function()
                if avgHP < 25 then return Color(255, 120, 120, 255) end
                if avgHP < 50 then return Color(255, 255, 120, 255) end
                return PanelColors.StatusColors["HP"]
            end)()
        },
        {text = webText, font = 12, color = webColor},
        {text = hungerText, font = 11, color = hungerColor}
    }

    local cellX = cellStartX
    for i = 1, #cells do
        local c = cells[i]
        DrawCell(cellX, cellY, State.panelAnimation.cellsAlpha, c.text, c.font, c.color)
        cellX = cellX + PanelConfig.CellSize + PanelConfig.CellSpacing
    end
end

local function DrawWebPoints()
    if not UI.WebHelperEnabled:Get() then return end

    local altHeld = Input.IsKeyDown(Enum.ButtonCode.KEY_LALT) or Input.IsKeyDown(Enum.ButtonCode.KEY_RALT)
    local altActive = (not UI.ShowWebPointsOnlyAlt:Get()) or altHeld
    local targetAlpha = altActive and 255 or 0
    State.webAltAlpha = AnimateAlpha(State.webAltAlpha, targetAlpha, 25)
    if State.webAltAlpha <= 0 then return end

    local webIcon = GetAbilityIconHandle("broodmother_spin_web")
    local rounding = 6
    local myHero = Heroes.GetLocal()
    local team = myHero and Entity.GetTeamNum(myHero) or nil
    local cursorX, cursorY = Input.GetCursorPos()
    local mouseDown = Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1)
    local justClicked = mouseDown and (not State.webMouseWasDown)
    local didCast = false
    local alphaScale = State.webAltAlpha / 255

    local function drawList(list)
        for i = 1, #(list or {}) do
            local wp = list[i]
            local screenPos, visible = Render.WorldToScreen(wp)
            if visible then
                local size = PanelConfig.CellSize
                local x = screenPos.x - size / 2
                local y = screenPos.y - size / 2

                local isHovered = cursorX >= x and cursorX <= (x + size) and cursorY >= y and cursorY <= (y + size)
                local baseAlpha = isHovered and math.floor(230 * 0.6) or 230
                local alpha = math.floor(baseAlpha * alphaScale)

                if webIcon then
                    DrawIconCell(x, y, alpha, webIcon, 0.88, rounding)

                    local basePad = 2
                    local iconScale = 0.88
                    local inner = (size - basePad * 2)
                    local iconSize = math.floor(inner * iconScale)
                    local offset = math.floor((inner - iconSize) / 2)
                    local pos = Vec2(x + basePad + offset + 0.5, y + basePad + 1 + offset)
                    local endPos = Vec2(pos.x + iconSize, pos.y + iconSize)
                    local baseBorder = isHovered and 180 or 220
                    local borderAlpha = math.floor(baseBorder * alphaScale)
                    Render.Rect(pos, endPos, Color(170, 170, 170, borderAlpha), rounding, Enum.DrawFlags.None, 0.5)
                else
                    DrawCell(x, y, alpha, "", 14, Color(120, 200, 255, 255))
                end

                if (not didCast) and UI.WebClickToCast:Get() and justClicked and isHovered and myHero then
                    local spinWeb = NPC.GetAbility(myHero, "broodmother_spin_web")
                    if spinWeb and Ability.IsCastable(spinWeb, NPC.GetMana(myHero)) then
                        -- Ability.CastPosition(ability, pos, [queue], [push], [execute_fast], [identifier], [force_minimap])
                        Ability.CastPosition(spinWeb, wp, false, false, false, "web_click")
                        didCast = true
                    end
                end
            end
        end
    end

    if team == Enum.TeamNum.TEAM_RADIANT then
        drawList(State.webPoints.radiant)
    elseif team == Enum.TeamNum.TEAM_DIRE then
        drawList(State.webPoints.dire)
    else
        drawList(State.webPoints.neutral)
    end

    State.webMouseWasDown = mouseDown
end

-- ═══════════════════════════════════════════════════════════════════════════
--  Callbacks: OnUpdate, OnDraw, OnGameEnd, OnPrepareUnitOrders
-- ═══════════════════════════════════════════════════════════════════════════

broodmother.OnUpdate = function()
    if not IsBroodmother() or not UI.Enabled:Get() then return end

    CleanupPlayerOverride()
    
    local spiderCount = #GetAllSpiders()
    
    if not State.updateFrame then
        State.updateFrame = 0
    end
    State.updateFrame = (State.updateFrame + 1)
    
    -- Реже обновляем авто-логику при большом числе пауков → меньше перехват, плавнее
    local throttleRate = 2
    if spiderCount > 20 then
        throttleRate = 6
    elseif spiderCount > 15 then
        throttleRate = 5
    elseif spiderCount > 10 then
        throttleRate = 4
    elseif spiderCount > 5 then
        throttleRate = 3
    end
    
    GatherSpiders()
    JuggleSpiders()
    AutoBloodthorn()
    AutoOrchid()
    AutoSoulRing()
    AutoStackCampsLogic()

    if State.updateFrame % throttleRate == 0 then
        if spiderCount <= 20 then
            AutoChaseEnemies()
            AutoSplitAttack()
            AutoFarmCreeps()
            AutoFollowSpiders()
        else
            AutoFarmCreeps()
        end
    end
end

broodmother.OnDraw = function()
    if not IsBroodmother() or not UI.Enabled:Get() then return end

    DrawPanel()
    DrawWebPoints()

    if State.lastGatherPos and (GameRules.GetGameTime() - State.lastGatherTime < 2) then
        local screenPos, isVisible = Render.WorldToScreen(State.lastGatherPos)
        if isVisible then
            local alpha = math.max(0, 255 - (GameRules.GetGameTime() - State.lastGatherTime) * 127)
            Render.Line(Vec2(screenPos.x - 5, screenPos.y), Vec2(screenPos.x + 5, screenPos.y), Color(100, 255, 100, alpha), 2)
            Render.Line(Vec2(screenPos.x, screenPos.y - 5), Vec2(screenPos.x, screenPos.y + 5), Color(100, 255, 100, alpha), 2)
        end
    end

    if State.juggling and (GameRules.GetGameTime() - State.juggleTime < 3) then
        local myHero = Heroes.GetLocal()
        if myHero then
            local heroPos = Entity.GetAbsOrigin(myHero)
            local radius = UI.JuggleRadius:Get()
            local alpha = math.max(0, 255 - (GameRules.GetGameTime() - State.juggleTime) * 85)

            local points = 32
            for i = 0, points do
                local angle = (i / points) * 2 * math.pi
                local x = heroPos.x + radius * math.cos(angle)
                local y = heroPos.y + radius * math.sin(angle)
                local worldPos = Vector(x, y, heroPos.z)
                local screenPos, isVisible = Render.WorldToScreen(worldPos)

                if isVisible and i > 0 then
                    local prevAngle = ((i - 1) / points) * 2 * math.pi
                    local prevX = heroPos.x + radius * math.cos(prevAngle)
                    local prevY = heroPos.y + radius * math.sin(prevAngle)
                    local prevWorldPos = Vector(prevX, prevY, heroPos.z)
                    local prevScreenPos, prevVisible = Render.WorldToScreen(prevWorldPos)

                    if prevVisible then
                        Render.Line(prevScreenPos, screenPos, Color(255, 120, 0, alpha), 2)
                    end
                end
            end

            local spiders = GetAllSpiders()
            local count = math.min(UI.JuggleCount:Get(), #spiders)

            for i = 1, count do
                local angle = (i - 1) * (2 * math.pi / count)
                local x = heroPos.x + radius * math.cos(angle)
                local y = heroPos.y + radius * math.sin(angle)
                local worldPos = Vector(x, y, heroPos.z)
                local screenPos, isVisible = Render.WorldToScreen(worldPos)

                if isVisible then
                    Render.FilledCircle(screenPos, 6, Color(255, 120, 0, alpha))
                    Render.Text(Config.Fonts.Main, 12, tostring(i), Vec2(screenPos.x - 4, screenPos.y - 6), Color(255, 255, 255, alpha))
                end
            end
        end
    else
        State.juggling = false
    end
end

broodmother.OnGameEnd = function()
    State.juggling = false
end

broodmother.OnPrepareUnitOrders = function(data)
    if not IsBroodmother() or not UI.Enabled:Get() then return true end
    if not data then return true end

    local localPlayer = Players.GetLocal()
    local lpId = localPlayer and Player.GetPlayerID(localPlayer) or -1
    local issuerPlayerId = data.player and Player.GetPlayerID(data.player) or -2
    if issuerPlayerId ~= lpId then return true end

    if data.identifier and type(data.identifier) == "string" and data.identifier:find("^brood_") then
        return true
    end

    local function IsSpiderling(npc)
        if not npc or not Entity.IsNPC(npc) then return false end
        return NPC.GetUnitName(npc) == "npc_dota_broodmother_spiderling"
    end

    local function applyOverride(npc)
        if npc and IsSpiderling(npc) then
            local id = Entity.GetIndex(npc)
            playerOverrideRole[id] = true
            playerOverrideUntil[id] = os.clock() + UI.PlayerOverride:Get()
            
            followRole[id] = nil
            chaseRole[id] = nil
            splitRole[id] = nil
            splitTarget[id] = nil
            farmRole[id] = nil
            farmLastOrder[id] = nil
        end
    end
    
    if data.orderIssuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
        local selected = Player.GetSelectedUnits and Player.GetSelectedUnits(localPlayer) or {}
        for i = 1, #selected do
            applyOverride(selected[i])
        end
    else
        applyOverride(data.npc)
    end

    return true
end

-- Стак по кнопке: при ударе паука по нейтралу — сразу пулл (как в GLTM)
broodmother.OnEntityHurt = function(data)
    if not stackSessionActive or not data or not data.source then return end
    local src = data.source
    if not Entity.IsAlive(src) then return end
    local srcId = Entity.GetIndex(src)
    if not srcId or not stackUnitToCampId[srcId] then return end
    local campId = stackUnitToCampId[srcId]
    local t = StackGameTimeSeconds()
    local minute = math.floor(t / 60)
    local st = EnsureStackTimelineFor(src, minute)
    if not (st.attackIssued and not st.hitConfirmed) then return end
    st.hitConfirmed = true
    local points = GetStackCampPoints(campId)
    if points and not st.pullIssued then
        st.pullIssued = true
        local myPlayer = Players.GetLocal()
        if myPlayer then
            StackMoveUnitTo(myPlayer, src, points.pull)
        end
    end
end

return broodmother