--[[
        ~ phantom lancer illusions auto-controller - uczone.gitbook.io/api-v2.0/
       ~~ jaydenannemayspecial4wind
      ~~~ special thanks to: qww, shz and other [ветра] members d_b _codex_7
    ~~~~ improvements by: Ephoria 
]]

local PLTools = {}

-- general check
local function IsPhantomLancer()
    local myHero = Heroes.GetLocal()
    return myHero and NPC.GetUnitName(myHero) == "npc_dota_hero_phantom_lancer"
end

local Config = {
    UI = {
        TabName = "General",
        ScriptName = "PL Illusion Controller",
        ScriptID = "pl_illusions",
        Icons = {
            Main = "\u{f6b6}",
            Rush = "\u{f554}",
            Farm = "\u{f72d}",
            Bait = "\u{f06a}",
            Status = "\u{f06e}",
            Bodyblock = "\u{f132}",
            Key = "\u{f084}",
            Manta = "\u{f24d}",
            Follow = "\u{f500}",
            Chase = "\u{f05b}",
            Split = "\u{f126}",
            Bloodthorn = "\u{f0e7}",
            Shard = "\u{f21b}",
            Clock = "\u{f017}"
        }
    },
    Colors = {
        Text = {
            Primary = Color(255, 255, 255),
            Shadow = Color(0, 0, 0)
        }
    },
    Fonts = {
        Main = Render.LoadFont("SF Pro Text", Enum.FontCreate.FONTFLAG_ANTIALIAS)
    },
    Retreat = {
        MinTriggerDist = 310,
        MinRetreat = 120,
        MaxRetreat = 390
    },
    Bait = {
        HPThreshold = 0.5,
        MaxBaiting = 2,
        Interval = 3,
        MinIllusions = 2,
        WRadius = 750,
        WBaitCount = 1,
        WBaitInterval = 0.5
    },
    Follow = {
        Enabled = true,
        Count = 2,
        MinRadius = 200,
        MaxRadius = 400
    },
    Bloodthorn = {
        Enabled = true,
        Range = 900,
        HPThreshold = 70,
        MinEnemies = 1,
        MantaCheckDelay = 0.5,
        CooldownBuffer = 2.0
    },
    Shard = {
        Enabled = true,
        HPThreshold = 30,
        MinEnemies = 1,
        Cooldown = 1.0
    }
    
}

local function CreateUI(tab)
    if not tab or not tab.Create then return nil end
    local mainGroup = tab:Create("Main")
    local illusionGroup = tab:Create("Illusions")
    local settingsGroup = tab:Create("Settings")
    local baitGroup = tab:Create("Auto Bait")
    local followGroup = tab:Create("Auto Follow")
    local chaseGroup = tab:Create("Auto Chase")
    local splitGroup = tab:Create("Auto Split")
    local runAwayGroup = tab:Create("Run Away")
    local bloodthornGroup = tab:Create("Bloodthorn")
    local shardGroup = tab:Create("Auto Shard")
    return {
        AutoRush = {
            Enabled = mainGroup:Switch("Auto Phantom Rush for illusions", true, Config.UI.Icons.Rush),
            DisableRushOnFarm = mainGroup:Switch("Disable Auto Phantom Rush when farming creeps", false, Config.UI.Icons.Farm)
        },
        Visuals = {
            StatusText = illusionGroup:Switch("Show status", true, Config.UI.Icons.Status)
        },
        Settings = {
            MinTriggerDist = settingsGroup:Slider("Distance for Rush trigger", 300, 600, Config.Retreat.MinTriggerDist, "%d"),
            MinRetreat = settingsGroup:Slider("Min. retreat", 50, 300, Config.Retreat.MinRetreat, "%d"),
            MaxRetreat = settingsGroup:Slider("Max. retreat", 300, 900, Config.Retreat.MaxRetreat, "%d"),
            RushSpeedThreshold = settingsGroup:Slider("Movement speed threshold for Rush", 250, 600, 300, "%d"),
            PlayerOverrideSec = settingsGroup:Slider("Control pause after player command (sec)", 0.0, 5.0, 1.5, "%.1f"),
            ControlMantaIllusions = settingsGroup:Switch("Control Manta illusions", false, Config.UI.Icons.Manta),
        },
        RunAway = {
            HoldKey = runAwayGroup:Bind("Bait key", Enum.ButtonCode.KEY_NONE, Config.UI.Icons.Key),
            KeepCount = runAwayGroup:Slider("Number of illusions around real lancer", 0, 6, 2, "%d"),
            Duration = runAwayGroup:Slider("Duration of illusion run (sec)", 0.5, 5.0, 2.0, "%.1f")
        },
        AutoBait = {
            Enabled = baitGroup:Switch("Enable auto-bait", true, Config.UI.Icons.Bait),
            HPThreshold = baitGroup:Slider("Illusion HP threshold (%)", 10, 90, math.floor(Config.Bait.HPThreshold * 100), "%d%%"),
            MaxBaiting = baitGroup:Slider("Max. baiting illusions", 1, 5, Config.Bait.MaxBaiting, "%d"),
            Interval = baitGroup:Slider("Interval between baits (sec)", 1, 10, Config.Bait.Interval, "%d"),
            MinIllusions = baitGroup:Slider("Min. illusions for bait", 2, 6, Config.Bait.MinIllusions, "%d"),
            WRadius = baitGroup:Slider("Enemy radius for W-bait", 400, 1200, Config.Bait.WRadius, "%d"),
            WBaitCount = baitGroup:Slider("Illusions baiting after W", 1, 5, Config.Bait.WBaitCount, "%d"),
            WBaitInterval = baitGroup:Slider("W-bait interval (sec)", 0, 2, Config.Bait.WBaitInterval, "%.1f")
        },
        AutoFollow = {
            Enabled = followGroup:Switch("Enable auto-follow", true, Config.UI.Icons.Follow),
            Count = followGroup:Slider("Number of illusions for follow", 1, 3, Config.Follow.Count, "%d"),
            MinRadius = followGroup:Slider("Min. follow radius", 100, 350, Config.Follow.MinRadius, "%d"),
            MaxRadius = followGroup:Slider("Max. follow radius", 200, 600, Config.Follow.MaxRadius, "%d")
        },
        AutoChase = {
            Enabled = chaseGroup:Switch("Enable auto-chase", true, Config.UI.Icons.Chase),
            Radius = chaseGroup:Slider("Auto-chase radius", 1500, 6000, 1600, "%d")
        },
        AutoBodyblock = {
            Enabled = illusionGroup:Switch("Enable auto-bodyblock", true, Config.UI.Icons.Bodyblock),
            PingThreshold = illusionGroup:Slider("Ping threshold for bodyblock", 50, 300, 150, "%d"),
            ForceBodyblockKey = illusionGroup:Bind("Bodyblock key", Enum.ButtonCode.KEY_NONE, Config.UI.Icons.Key)
        },
        AutoSplit = {
            Enabled = splitGroup:Switch("Enable auto-split attack", true, Config.UI.Icons.Split),
            MaxIllusionsPerTarget = splitGroup:Slider("Max. illusions per target", 3, 12, 8, "%d"),
            SplitCount = splitGroup:Slider("Number of illusions for redirect", 1, 5, 2, "%d"),
            SearchRadius = splitGroup:Slider("Target search radius", 800, 2000, 1200, "%d"),
            MinEnemies = splitGroup:Slider("Min. enemies for activation", 2, 5, 2, "%d")
        },
        Bloodthorn = {
            Enabled = bloodthornGroup:Switch("Enable Auto Bloodthorn", true, Config.UI.Icons.Bloodthorn),
            Range = bloodthornGroup:Slider("Cast range", 500, 1100, Config.Bloodthorn.Range, "%d"),
            HPThreshold = bloodthornGroup:Slider("Target HP threshold (%)", 30, 100, Config.Bloodthorn.HPThreshold, "%d%%"),
            MinEnemies = bloodthornGroup:Slider("Min enemies nearby", 1, 3, Config.Bloodthorn.MinEnemies, "%d"),
            MantaCheck = bloodthornGroup:Switch("Wait for Manta cooldown", true, Config.UI.Icons.Clock),
            MantaDelay = bloodthornGroup:Slider("Manta check delay (sec)", 0.1, 2.0, Config.Bloodthorn.MantaCheckDelay, "%.1f"),
            CooldownBuffer = bloodthornGroup:Slider("Manta CD buffer (sec)", 0.5, 5.0, Config.Bloodthorn.CooldownBuffer, "%.1f")
        },
        Shard = {
            Enabled = shardGroup:Switch("Enable Auto Shard", true, Config.UI.Icons.Shard),
            HPThreshold = shardGroup:Slider("HP threshold (%)", 10, 50, Config.Shard.HPThreshold, "%d%%"),
            MinEnemies = shardGroup:Slider("Min enemies nearby", 1, 5, Config.Shard.MinEnemies, "%d"),
            Cooldown = shardGroup:Slider("Min cooldown between uses (sec)", 0.5, 5.0, Config.Shard.Cooldown, "%.1f")
        },
    }
end

local function InitializeUI()
    -- Menu.Find("Heroes", "Hero List", "Phantom Lancer") + вкладка Helper с группами (API: Menu.Find → :Create)
    local plSection = Menu.Find("Heroes", "Hero List", "Phantom Lancer")
    local helperTab
    if plSection and plSection.Create then
        helperTab = plSection:Create("Helper")
    end
    if helperTab and helperTab.Create then
        return CreateUI(helperTab)
    end
    -- Fallback: если Phantom Lancer нет в Heroes — создаём своё дерево (General > PL Illusion Controller)
    local tab = Menu.Create(Config.UI.TabName, Config.UI.ScriptName, Config.UI.ScriptID)
    if tab and tab.Icon then tab:Icon(Config.UI.Icons.Main) end
    helperTab = tab:Create("Helper")
    return CreateUI(helperTab)
end

local UI = InitializeUI()

local bloodthornState = {
    lastCastTime = 0,
    lastTargetId = nil,
    mantaCheckStart = {},
    illusionCountBefore = {}
}
local shardState = {
    lastCastTime = 0
}

followRole = {}
followLastOrder = followLastOrder or {}

playerOverrideRole = playerOverrideRole or {}
playerOverrideUntil = playerOverrideUntil or {}
playerOverrideDuration = playerOverrideDuration or 1.5

function PlayerOverrideDuration(second)
    if type(second) == "number" and second >= 0 then
        playerOverrideDuration = second
    end
end

runawayRole = runawayRole or {}
runawayLastOrder = runawayLastOrder or {}
runawayActive = runawayActive or false
runawayBaseAngle = runawayBaseAngle or 0
runawayKeepRole = runawayKeepRole or {}
runawayUntil = runawayUntil or {}

local function IsIllusionUnderPlayerOverride(illusion)
    local id = Entity.GetIndex(illusion)
    local untilTime = playerOverrideUntil[id]
    return untilTime and os.clock() < untilTime
end

local function GetControllablePLIllusions()
    local illusions = GetAllPLIllusions()
    local result = {}
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if not IsIllusionUnderPlayerOverride(illusion) and not (runawayRole and runawayRole[id]) then
            table.insert(result, illusion)
        end
    end
    return result
end

local function CleanupPlayerOverride()
    local now = os.clock()
    for id, t in pairs(playerOverrideUntil) do
        if now >= t then
            playerOverrideUntil[id] = nil
            playerOverrideRole[id] = nil
        end
    end
    local alive = {}
    for _, illu in ipairs(GetAllPLIllusions()) do
        alive[Entity.GetIndex(illu)] = true
    end
    for id, _ in pairs(playerOverrideRole) do
        if not alive[id] then
            playerOverrideRole[id] = nil
            playerOverrideUntil[id] = nil
        end
    end
end

function AutoFollowIllusions()
    if not UI.AutoFollow.Enabled:Get() then return end
    local illusions = GetControllablePLIllusions()
    local myHero = Heroes.GetLocal()
    if not myHero or #illusions == 0 then return end
    local now = os.clock()
    local enemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}
    if #enemies > 0 then
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            followRole[id] = nil
        end
        return
    end
    local freeIllusions = {}
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if priorityRole and priorityRole[id] then
            followRole[id] = nil
        elseif not (IsIllusionBaiting and IsIllusionBaiting(id)) and not (IsIllusionWbaiting and IsIllusionWbaiting(id)) and not (farmRole and farmRole[id]) and not (chaseRole and chaseRole[id]) and not (splitRole and splitRole[id]) then
            table.insert(freeIllusions, illusion)
        else
            followRole[id] = nil
        end
    end
    local count = UI.AutoFollow.Count:Get()
    if #freeIllusions < count then count = #freeIllusions end
    local selected = {}
    while #selected < count and #freeIllusions > 0 do
        local idx = math.random(1, #freeIllusions)
        local illusion = freeIllusions[idx]
        local id = Entity.GetIndex(illusion)
        followRole[id] = true
        table.insert(selected, illusion)
        table.remove(freeIllusions, idx)
    end
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        local found = false
        for _, sel in ipairs(selected) do
            if Entity.GetIndex(sel) == id then found = true break end
        end
        if not found then
            followRole[id] = nil
        end
    end
    for _, illusion in ipairs(selected) do
        local id = Entity.GetIndex(illusion)
        if not followLastOrder[id] or (now - followLastOrder[id] > math.random(7,12)/10) then
            local heroPos = Entity.GetAbsOrigin(myHero)
            local minR = UI.AutoFollow.MinRadius:Get()
            local maxR = UI.AutoFollow.MaxRadius:Get()
            local angle = math.rad(math.random(0,359))
            local dist = math.random(minR, maxR)
            local offset = Vector(math.cos(angle), math.sin(angle), 0) * dist
            local targetPos = heroPos + offset
            Player.PrepareUnitOrders(
                Players.GetLocal(),
                Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil,
                targetPos,
                nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                illusion,
                false,
                false,
                false,
                false,
                "pl_illusion_follow"
            )
            followLastOrder[id] = now
        end
    end
end

local function IsPLIllusion(npc)
    return NPC.IsIllusion(npc) and NPC.GetUnitName(npc) == "npc_dota_hero_phantom_lancer"
end

-- Check if illusion is from Manta Style
local function IsMantaIllusion(npc)
    if not npc or not NPC.IsIllusion(npc) then return false end
    -- Manta illusions don't have PL-specific illusion modifiers
    return not NPC.HasModifier(npc, "modifier_phantom_lancer_juxtapose_illusion") and
           not NPC.HasModifier(npc, "modifier_phantom_lancer_doppelwalk_illusion")
end

function GetAllPLIllusions()
    local myHero = Heroes.GetLocal()
    if not myHero then return {} end
    local playerId = Hero.GetPlayerID(myHero)
    local allNPCs = NPCs.GetAll()
    local result = {}
    local controlManta = UI and UI.Settings and UI.Settings.ControlMantaIllusions and UI.Settings.ControlMantaIllusions:Get() or false
    
    for _, npc in ipairs(allNPCs) do
        if IsPLIllusion(npc) and Entity.IsControllableByPlayer(npc, playerId) and Entity.IsAlive(npc) then
            -- If ControlMantaIllusions is disabled, exclude Manta illusions
            if not controlManta and IsMantaIllusion(npc) then
                -- Skip this Manta illusion
            else
                table.insert(result, npc)
            end
        end
    end
    return result
end

-- Get Bloodthorn ability
local function GetBloodthornAbility(hero)
    if not hero then return nil end
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(hero, i)
        if item and Ability.GetName(item) == "item_bloodthorn" then
            return item
        end
    end
    return nil
end

-- Get Orchid ability
local function GetOrchidAbility(hero)
    if not hero then return nil end
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(hero, i)
        if item and Ability.GetName(item) == "item_orchid" then
            return item
        end
    end
    return nil
end

-- Get Manta Style ability from enemy
local function GetMantaAbility(enemy)
    if not enemy then return nil end
    for i = 0, 8 do
        local item = NPC.GetItemByIndex(enemy, i)
        if item and Ability.GetName(item) == "item_manta" then
            return item
        end
    end
    return nil
end

-- Check if enemy has active Manta illusions
local function HasActiveMantaIllusions(enemy)
    if not enemy then return false end
    local enemyPos = Entity.GetAbsOrigin(enemy)
    local allNPCs = NPCs.GetAll()
    local enemyName = NPC.GetUnitName(enemy)
    
    for _, npc in ipairs(allNPCs) do
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

-- Count nearby illusions of an enemy
local function CountNearbyIllusions(enemy, radius)
    if not enemy then return 0 end
    local enemyPos = Entity.GetAbsOrigin(enemy)
    local enemyName = NPC.GetUnitName(enemy)
    local count = 0
    local allNPCs = NPCs.GetAll()
    
    for _, npc in ipairs(allNPCs) do
        if NPC.IsIllusion(npc) and Entity.IsAlive(npc) and
           NPC.GetUnitName(npc) == enemyName and
           Entity.GetTeamNum(npc) == Entity.GetTeamNum(enemy) then
            local illuPos = Entity.GetAbsOrigin(npc)
            local dist = (enemyPos - illuPos):Length()
            if dist < (radius or 800) then
                count = count + 1
            end
        end
    end
    return count
end

-- Check if Manta is on cooldown
local function IsMantaOnCooldown(enemy)
    local manta = GetMantaAbility(enemy)
    if not manta then return true end
    
    -- Try different possible API function names
    local cd = 0
    if Ability.GetCooldown then
        cd = Ability.GetCooldown(manta)
    elseif Ability.GetCooldownLength then
        cd = Ability.GetCooldownLength(manta)
    elseif Ability.IsReady then
        -- If manta is ready, cooldown is 0
        if Ability.IsReady(manta) then
            return false
        else
            return true
        end
    end
    
    local buffer = UI.Bloodthorn.CooldownBuffer:Get()
    return cd > buffer
end

-- Detect if enemy just used Manta
local function DetectMantaUse(enemy)
    if not enemy then return false end
    local enemyId = Entity.GetIndex(enemy)
    local now = os.clock()
    
    local currentCount = CountNearbyIllusions(enemy, 800)
    local previousCount = bloodthornState.illusionCountBefore[enemyId] or 0
    
    bloodthornState.illusionCountBefore[enemyId] = currentCount
    
    if currentCount > previousCount and currentCount >= 2 then
        bloodthornState.mantaCheckStart[enemyId] = now
        Log.Write(string.format("[Bloodthorn] Detected Manta use on enemy %d (illusions: %d -> %d)", 
            enemyId, previousCount, currentCount))
        return true
    end
    
    return false
end

-- Check if we should wait before casting Bloodthorn/Orchid
local function ShouldWaitForManta(enemy)
    if not UI.Bloodthorn.MantaCheck:Get() then 
        return false 
    end
    
    local manta = GetMantaAbility(enemy)
    if not manta then 
        return false 
    end
    
    -- If Manta is on cooldown, it's safe to cast
    if IsMantaOnCooldown(enemy) then
        return false
    end
    
    -- Manta is READY (off cooldown) - this is the danger zone!
    -- If enemy already has illusions, they just used it, wait for them to fade
    if HasActiveMantaIllusions(enemy) then
        Log.Write("[Bloodthorn/Orchid] Enemy has active Manta illusions, waiting for them to fade...")
        return true
    end
    
    -- Manta is ready and no illusions = enemy could pop it any second
    -- We should WAIT unless they're very low HP (desperate situation)
    local enemyHP = Entity.GetHealth(enemy)
    local enemyMaxHP = Entity.GetMaxHealth(enemy)
    local hpPercent = (enemyHP / enemyMaxHP) * 100
    
    -- Only cast if enemy is critically low (below 30% HP) - too risky otherwise
    if hpPercent < 30 then
        Log.Write(string.format("[Bloodthorn/Orchid] Enemy HP very low (%.0f%%), taking the risk!", hpPercent))
        return false
    end
    
    -- Otherwise, wait for them to use Manta first
    Log.Write("[Bloodthorn/Orchid] Enemy has Manta ready, waiting for them to use it first...")
    return true
end

-- Find best Bloodthorn target
local function FindBloodthornTarget(myHero)
    if not myHero then return nil end
    local range = UI.Bloodthorn.Range:Get()
    local hpThreshold = UI.Bloodthorn.HPThreshold:Get() / 100
    local enemies = Entity.GetHeroesInRadius(myHero, range, Enum.TeamType.TEAM_ENEMY, true) or {}
    local validTargets = {}
    for _, enemy in ipairs(enemies) do
        if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) then
            DetectMantaUse(enemy)
            local enemyHP = Entity.GetHealth(enemy)
            local enemyMaxHP = Entity.GetMaxHealth(enemy)
            local hpPercent = enemyHP / enemyMaxHP
            if hpPercent <= hpThreshold then
                if not NPC.HasModifier(enemy, "modifier_item_bloodthorn_debuff") and
                   not NPC.HasModifier(enemy, "modifier_teleporting") and
                   not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) and
                   not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
                    if ShouldWaitForManta(enemy) then
                        goto continue_bloodthorn
                    end
                    local score = 0
                    score = score + (1 - hpPercent) * 100
                    local manta = GetMantaAbility(enemy)
                    if manta and IsMantaOnCooldown(enemy) then
                        score = score + 50
                    end
                    if not HasActiveMantaIllusions(enemy) then
                        score = score + 30
                    end
                    table.insert(validTargets, {enemy = enemy, score = score})
                end
            end
        end
        ::continue_bloodthorn::
    end
    if #validTargets == 0 then return nil end
    table.sort(validTargets, function(a, b) return a.score > b.score end)
    return validTargets[1].enemy
end

-- Auto cast Bloodthorn
function AutoBloodthorn()
    if not UI.Bloodthorn.Enabled:Get() then return end
    local myHero = Heroes.GetLocal()
    if not myHero then return end
    local bloodthorn = GetBloodthornAbility(myHero)
    if not bloodthorn then return end
    if not Ability.IsReady(bloodthorn) or not Ability.IsCastable(bloodthorn, NPC.GetMana(myHero)) then
        return
    end
    local now = os.clock()
    if now - bloodthornState.lastCastTime < 0.5 then return end
    local target = FindBloodthornTarget(myHero)
    if not target then return end
    local myPos = Entity.GetAbsOrigin(myHero)
    local targetPos = Entity.GetAbsOrigin(target)
    local dist = (myPos - targetPos):Length()
    local castRange = Ability.GetCastRange(bloodthorn)
    if dist <= castRange then
        local enemyId = Entity.GetIndex(target)
        local manta = GetMantaAbility(target)
        local mantaStatus = ""
        if manta then
            if IsMantaOnCooldown(target) then
                mantaStatus = " (Manta on CD)"
            else
                mantaStatus = " (Manta ready!)"
            end
        end
        Log.Write(string.format("[Bloodthorn] Casting on enemy %d (HP: %.0f%%)%s",
            enemyId,
            (Entity.GetHealth(target) / Entity.GetMaxHealth(target)) * 100,
            mantaStatus))
        Ability.CastTarget(bloodthorn, target)
        bloodthornState.lastCastTime = now
        bloodthornState.lastTargetId = enemyId
    end
end

-- Auto cast Orchid (uses same settings as Bloodthorn)
function AutoOrchid()
    if not UI.Bloodthorn.Enabled:Get() then return end
    local myHero = Heroes.GetLocal()
    if not myHero then return end
    local orchid = GetOrchidAbility(myHero)
    if not orchid then return end
    if not Ability.IsReady(orchid) or not Ability.IsCastable(orchid, NPC.GetMana(myHero)) then
        return
    end
    local now = os.clock()
    if now - bloodthornState.lastCastTime < 0.5 then return end
    local range = UI.Bloodthorn.Range:Get()
    local hpThreshold = UI.Bloodthorn.HPThreshold:Get() / 100
    local enemies = Entity.GetHeroesInRadius(myHero, range, Enum.TeamType.TEAM_ENEMY, true) or {}
    local validTargets = {}
    for _, enemy in ipairs(enemies) do
        if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) then
            DetectMantaUse(enemy)
            local enemyHP = Entity.GetHealth(enemy)
            local enemyMaxHP = Entity.GetMaxHealth(enemy)
            local hpPercent = enemyHP / enemyMaxHP
            if hpPercent <= hpThreshold then
                if not NPC.HasModifier(enemy, "modifier_item_orchid_malevolence_debuff") and
                   not NPC.HasModifier(enemy, "modifier_item_bloodthorn_debuff") and
                   not NPC.HasModifier(enemy, "modifier_teleporting") and
                   not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_MAGIC_IMMUNE) and
                   not NPC.HasState(enemy, Enum.ModifierState.MODIFIER_STATE_INVULNERABLE) then
                    if ShouldWaitForManta(enemy) then
                        goto continue_orchid
                    end
                    local score = 0
                    score = score + (1 - hpPercent) * 100
                    local manta = GetMantaAbility(enemy)
                    if manta and IsMantaOnCooldown(enemy) then
                        score = score + 50
                    end
                    if not HasActiveMantaIllusions(enemy) then
                        score = score + 30
                    end
                    table.insert(validTargets, {enemy = enemy, score = score})
                end
            end
        end
        ::continue_orchid::
    end
    if #validTargets == 0 then return end
    table.sort(validTargets, function(a, b) return a.score > b.score end)
    local target = validTargets[1].enemy
    if not target then return end
    local myPos = Entity.GetAbsOrigin(myHero)
    local targetPos = Entity.GetAbsOrigin(target)
    local dist = (myPos - targetPos):Length()
    local castRange = Ability.GetCastRange(orchid)
    if dist <= castRange then
        local enemyId = Entity.GetIndex(target)
        local manta = GetMantaAbility(target)
        local mantaStatus = ""
        if manta then
            if IsMantaOnCooldown(target) then
                mantaStatus = " (Manta on CD)"
            else
                mantaStatus = " (Manta ready!)"
            end
        end
        Log.Write(string.format("[Orchid] Casting on enemy %d (HP: %.0f%%)%s",
            enemyId,
            (Entity.GetHealth(target) / Entity.GetMaxHealth(target)) * 100,
            mantaStatus))
        Ability.CastTarget(orchid, target)
        bloodthornState.lastCastTime = now
        bloodthornState.lastTargetId = enemyId
    end
end

-- Get Juxtapose ability (PL's ultimate - Shard adds active component)
local function GetShardAbility(hero)
    if not hero then return nil end
    
    -- Juxtapose is PL's ultimate
    for i = 0, 23 do
        local ability = NPC.GetAbilityByIndex(hero, i)
        if ability and Ability.GetName(ability) == "phantom_lancer_juxtapose" then
            return ability
        end
    end
    return nil
end

-- Auto use Shard (Juxtapose active) for invisibility
function AutoShard()
    if not UI.Shard.Enabled:Get() then return end
    
    local myHero = Heroes.GetLocal()
    if not myHero then return end
    
    -- Check if already invisible from shard active
    if NPC.HasModifier(myHero, "modifier_phantom_lancer_juxtapose_invis") then
        return
    end
    
    local juxtapose = GetShardAbility(myHero)
    if not juxtapose then return end
    
    -- Check if hero has Aghanim's Shard (which enables the active)
    -- The shard modifier is usually "modifier_item_aghanims_shard"
    if not NPC.HasModifier(myHero, "modifier_item_aghanims_shard") then
        return
    end
    
    -- Check if ability is ready and castable
    if not Ability.IsReady(juxtapose) then return end
    
    -- Check mana cost
    local manaCost = Ability.GetManaCost(juxtapose)
    if manaCost and manaCost > 0 then
        if not Ability.IsCastable(juxtapose, NPC.GetMana(myHero)) then
            return
        end
    end
    
    local now = os.clock()
    local cooldown = UI.Shard.Cooldown:Get()
    if now - shardState.lastCastTime < cooldown then return end
    
    -- Check HP threshold
    local hp = Entity.GetHealth(myHero)
    local maxHP = Entity.GetMaxHealth(myHero)
    local hpPercent = (hp / maxHP) * 100
    local threshold = UI.Shard.HPThreshold:Get()
    
    if hpPercent > threshold then return end
    
    -- Check if enemies are nearby
    local minEnemies = UI.Shard.MinEnemies:Get()
    local enemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}
    
    if #enemies < minEnemies then return end
    
    -- Cast Juxtapose (Shard active)
    Log.Write(string.format("[Shard] Using Juxtapose active! HP: %.0f%%, Enemies nearby: %d", hpPercent, #enemies))
    Ability.CastNoTarget(juxtapose)
    shardState.lastCastTime = now
end

local function FindNearestEnemy(npc, radius)
    local enemies = Entity.GetHeroesInRadius(npc, radius or 1200, Enum.TeamType.TEAM_ENEMY, true) or {}
    local minDist, nearest = math.huge, nil
    for _, enemy in ipairs(enemies) do
        if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) then
            local dist = (Entity.GetAbsOrigin(npc) - Entity.GetAbsOrigin(enemy)):Length()
            if dist < minDist then
                minDist = dist
                nearest = enemy
            end
        end
    end
    return nearest
end

local function GetAttackRange(npc)
    return (NPC.GetAttackRange and NPC.GetAttackRange(npc) or 150) + (NPC.GetAttackRangeBonus and NPC.GetAttackRangeBonus(npc) or 0)
end

-- retreat distance aka отход
local function CalcRD(startDist, minTriggerDist, minRetreat, maxRetreat)
    if startDist >= minTriggerDist then
        return minRetreat
    else
        local need = minTriggerDist - startDist + minRetreat
        if need > maxRetreat then
            return maxRetreat
        end
        return need
    end
end

local function FindRD(illusion, enemy, distance)
    local illuPos = Entity.GetAbsOrigin(illusion)
    local enemyPos = Entity.GetAbsOrigin(enemy)
    local dir = (illuPos - enemyPos):Normalized()
    local pos = illuPos + dir * distance
    return pos, (pos - illuPos):Length(), "ok"
end

local illusionOrderTimestamps = {}

local function HasPhantomRushModifier(npc)
    return NPC.HasModifier(npc, "modifier_phantom_lancer_phantom_rush")
end

local illusionStates = {}

local function FindNearestCreep(npc, radius)
    local myHero = Heroes.GetLocal()
    local allNPCs = NPCs.GetAll()
    local illuPos = Entity.GetAbsOrigin(npc)
    local minDist, nearest = math.huge, nil
    for _, creep in ipairs(allNPCs) do
        if Entity.IsAlive(creep) and not Entity.IsDormant(creep) and Entity.GetTeamNum(creep) ~= Entity.GetTeamNum(myHero) then
            local name = NPC.GetUnitName(creep)
            if name and (string.find(name, "creep") or string.find(name, "neutral") or string.find(name, "siege") or string.find(name, "mega") or NPC.IsRoshan(creep)) then
                local dist = (illuPos - Entity.GetAbsOrigin(creep)):Length()
                if dist < minDist and dist < (radius or 1200) then
                    minDist = dist
                    nearest = creep
                end
            end
        end
    end
    return nearest
end

function AutoPhantomRushForIllusions()
    if not UI.AutoRush.Enabled:Get() then return end
    local illusions = GetControllablePLIllusions()
    local player = Players.GetLocal and Players.GetLocal() or nil
    local now = GameRules.GetGameTime()
    local myHero = Heroes.GetLocal()
    if not myHero or NPC.GetCurrentLevel(myHero) < 6 then return end
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if (IsIllusionBaiting and IsIllusionBaiting(id)) or (IsIllusionWbaiting and IsIllusionWbaiting(id)) or (splitRole and splitRole[id]) or (UI.AutoRush.DisableRushOnFarm:Get() and farmRole and farmRole[id]) then
            goto continue
        end
        local state = illusionStates[id] and illusionStates[id].state or nil
        if HasPhantomRushModifier(illusion) then
            illusionStates[id] = {state = "done"}
            goto continue
        end
        if not illusionStates[id] then
        local target = FindNearestEnemy(illusion, 1200)

            if myHero then
                local heroTarget = Entity.GetAttackTarget and Entity.GetAttackTarget(myHero)
                if heroTarget and Entity.IsAlive(heroTarget) and not NPC.IsRunning(heroTarget) then
                    target = heroTarget
                end
            end
            if not target and farmRole and farmRole[id] and not UI.AutoRush.DisableRushOnFarm:Get() then
                target = FindNearestCreep(illusion, 1200)
            end

            local speedThreshold = UI.Settings.RushSpeedThreshold:Get()
            if target and NPC.GetMoveSpeed and NPC.GetMoveSpeed(illusion) < speedThreshold then
                target = nil
            end
            if target then
                if NPC.IsRunning and NPC.IsRunning(target) then
                    Player.PrepareUnitOrders(
                        player,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                        target,
                        Vector(),
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        illusion,
                        false,
                        false,
                        false,
                        false,
                        "pl_illusion_autoattack_moving"
                    )
                    illusionStates[id] = {state = "attacking", time = now, target = target}
                else
                    local illuPos = Entity.GetAbsOrigin(illusion)
                    local enemyPos = Entity.GetAbsOrigin(target)
                    local startDist = (illuPos - enemyPos):Length()
                    local minTriggerDist = UI.Settings.MinTriggerDist:Get()
                    local minRetreat = UI.Settings.MinRetreat:Get()
                    local maxRetreat = UI.Settings.MaxRetreat:Get()
                    local maxFinalDist = 350
                    local retreatDist = CalcRD(startDist, minTriggerDist, minRetreat, maxRetreat)
                    if startDist + retreatDist > maxFinalDist then
                        retreatDist = maxFinalDist - startDist
                        if retreatDist < minRetreat then
                            retreatDist = minRetreat
                        end
                    end
                    local retreatPos, pathLen, status = FindRD(illusion, target, retreatDist)
                    Player.PrepareUnitOrders(
                        player,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                        nil,
                        retreatPos,
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        illusion,
                        false,
                        false,
                        false,
                        false,
                        "pl_illusion_retreat_once"
                    )
                    illusionStates[id] = {
                        state = "retreating",
                        time = now,
                        retreatPos = retreatPos,
                        target = target,
                        pathLen = pathLen,
                        status = status,
                        startDist = startDist,
                        retreatDist = retreatDist,
                        retreatTries = 1
                    }
                end
            end
        elseif state == "retreating" then
            local illuPos = Entity.GetAbsOrigin(illusion)
            local retreatPos = illusionStates[id].retreatPos
            local dist = (illuPos - retreatPos):Length()
            local minTriggerDist = UI.Settings.MinTriggerDist:Get()
            local maxTries = 2
            if dist < 50 or (now - illusionStates[id].time) > 1.2 then
                local target = illusionStates[id].target
                if target and Entity.IsAlive(target) then
                    local enemyPos = Entity.GetAbsOrigin(target)
                    local distToEnemy = (illuPos - enemyPos):Length()
                    if distToEnemy < minTriggerDist and (illusionStates[id].retreatTries or 1) < maxTries then
                        local minRetreat = UI.Settings.MinRetreat:Get()
                        local maxRetreat = UI.Settings.MaxRetreat:Get()
                        local maxFinalDist = 450
                        local retreatDist = CalcRD(distToEnemy, minTriggerDist, minRetreat, maxRetreat)
                        if distToEnemy + retreatDist > maxFinalDist then
                            retreatDist = maxFinalDist - distToEnemy
                            if retreatDist < minRetreat then
                                retreatDist = minRetreat
                            end
                        end
                        local retreatPos2, pathLen2, status2 = FindRD(illusion, target, retreatDist)
                        Player.PrepareUnitOrders(
                            player,
                            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                            nil,
                            retreatPos2,
                            nil,
                            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                            illusion,
                            false,
                            false,
                            false,
                            false,
                            "pl_illusion_retreat_retry"
                        )
                        illusionStates[id].retreatPos = retreatPos2
                        illusionStates[id].pathLen = pathLen2
                        illusionStates[id].status = status2
                        illusionStates[id].time = now
                        illusionStates[id].retreatTries = (illusionStates[id].retreatTries or 1) + 1
                        illusionStates[id].retreatDist = retreatDist
                    else
                        Player.PrepareUnitOrders(
                            player,
                            Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                            target,
                            Vector(),
                            nil,
                            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                            illusion,
                            false,
                            false,
                            false,
                            false,
                            "pl_illusion_attack_once"
                        )
                        illusionStates[id].state = "attacking"
                        illusionStates[id].time = now
                        illusionStates[id].distToEnemy = distToEnemy
                    end
                else
                    illusionStates[id].state = "done"
                end
            end
        elseif state == "attacking" then
            local target = illusionStates[id] and illusionStates[id].target
            if not target or not Entity.IsAlive(target) then

                local newTarget = FindNearestEnemy(illusion, 1200)
                if not newTarget and farmRole and farmRole[id] and not UI.AutoRush.DisableRushOnFarm:Get() then
                    newTarget = FindNearestCreep(illusion, 1200)
                end
                if newTarget then
                    Player.PrepareUnitOrders(
                        Players.GetLocal(),
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                        newTarget,
                        Vector(),
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        illusion,
                        false,
                        false,
                        false,
                        false,
                        "pl_illusion_autoattack_idle"
                    )
                    illusionStates[id] = {state = "attacking", time = now, target = newTarget}
                else
                    illusionStates[id].state = "done"
                    illusionStates[id].target = nil
                end
            elseif now - illusionStates[id].time > 0.5 then
                illusionStates[id].state = "done"
            end
        end
        ::continue::
    end
    for id, _ in pairs(illusionStates) do
        local found = false
        for _, illusion in ipairs(illusions) do
            if Entity.GetIndex(illusion) == id then found = true break end
        end
        if not found then
            illusionStates[id] = nil
        end
    end
end

local baitState = {
    lastBaitTime = 0,
    baitingIllusions = {},
    lastWBaitTime = 0,
}

local wbaitRole = {}
local baitRole = {}

local function IsIllusionWbaiting(id)
    return wbaitRole[id] == true
end
local function IsIllusionBaiting(id)
    return baitRole[id] == true
end

local function HasDoppelgangerFade(hero)
    return NPC.HasModifier(hero, "modifier_phantom_lancer_doppelwalk_fade")
end

local lastDoppelCastTime = 0

-- можно просто проверять на самом деле в функции, я вынес потому что мне так удобнее
local function IsDoppelgangerCasting()
    local myHero = Heroes.GetLocal()
    if not myHero then return false end
    for i = 0, 15 do
        local ability = NPC.GetAbilityByIndex(myHero, i)
        if ability and Ability.GetName(ability) == "phantom_lancer_doppelwalk" then
            return Ability.IsInAbilityPhase(ability)
        end
    end
    return false
end

local function AutoBaitIllusions()
    if not UI.AutoBait.Enabled:Get() then return end
    local illusions = GetControllablePLIllusions()
    local now = os.clock()
    if not baitState._hpBaitLastOrder then baitState._hpBaitLastOrder = {} end
    if not baitState._wbaitLastOrder then baitState._wbaitLastOrder = {} end
    local minIllusions = UI.AutoBait.MinIllusions:Get()
    local hpThreshold = UI.AutoBait.HPThreshold:Get() / 100
    local maxBaiting = UI.AutoBait.MaxBaiting:Get()
    local interval = UI.AutoBait.Interval:Get()
    local myHero = Heroes.GetLocal()
    local heroHP = Entity.GetHealth(myHero)
    local heroMaxHP = Entity.GetMaxHealth(myHero)
    local heroHPFrac = heroHP / heroMaxHP

    local baitHP = heroHP * hpThreshold

    if IsDoppelgangerCasting() then
        lastDoppelCastTime = os.clock()
    end

    local wRadius = UI.AutoBait.WRadius:Get()
    local wBaitCount = UI.AutoBait.WBaitCount:Get()
    local wBaitInterval = UI.AutoBait.WBaitInterval:Get()

    if (os.clock() - lastDoppelCastTime < 0.5) and (now - baitState.lastWBaitTime > wBaitInterval) then
        local enemies = Entity.GetHeroesInRadius(myHero, wRadius, Enum.TeamType.TEAM_ENEMY, true) or {}
        if #enemies > 0 then
            local illuList = {}

            local currentWbait = 0
            for _, illusion in ipairs(illusions) do
                local id = Entity.GetIndex(illusion)
                if IsIllusionWbaiting(id) then
                    currentWbait = currentWbait + 1
                end
            end
            for _, illusion in ipairs(illusions) do
                local id = Entity.GetIndex(illusion)
                if not IsIllusionBaiting(id) and not IsIllusionWbaiting(id) and not (splitRole and splitRole[id]) and not (farmRole and farmRole[id]) then
                    local illuHP = Entity.GetHealth(illusion)
                    local illuMaxHP = Entity.GetMaxHealth(illusion)
                    table.insert(illuList, {npc=illusion, id=id, frac=illuHP/illuMaxHP})
                end
            end
            table.sort(illuList, function(a, b) return a.frac < b.frac end)
            for i = 1, math.min(wBaitCount - currentWbait, #illuList) do
                local illusion = illuList[i].npc
                local id = illuList[i].id
                local enemy = FindNearestEnemy(illusion, 1200)
                local illuPos = Entity.GetAbsOrigin(illusion)
                local baitPos
                if enemy then
                    local baseDir = (illuPos - Entity.GetAbsOrigin(enemy)):Normalized()
                    local angleOffset = math.rad(math.random(-60, 60))
                    local dir = Vector(
                        baseDir.x * math.cos(angleOffset) - baseDir.y * math.sin(angleOffset),
                        baseDir.x * math.sin(angleOffset) + baseDir.y * math.cos(angleOffset),
                        0
                    )
                    local dist = math.random(300, 600)
                    baitPos = illuPos + dir * dist
                else
                    local angle = math.rad(math.random(0, 359))
                    local dist = math.random(300, 600)
                    baitPos = illuPos + Vector(math.cos(angle), math.sin(angle), 0) * dist
                end
                Player.PrepareUnitOrders(
                    Players.GetLocal(),
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil,
                    baitPos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    illusion,
                    false,
                    false,
                    false,
                    false,
                    "pl_illusion_bait_w"
                )
                baitState._wbaitLastOrder[id] = now
                wbaitRole[id] = true
            end
            baitState.lastWBaitTime = now
        end
    end

    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if IsIllusionBaiting(id) and not IsIllusionWbaiting(id) then
            if not baitState._hpBaitLastOrder[id] or (now - baitState._hpBaitLastOrder[id] > math.random(7,12)/10) then
                local enemy = FindNearestEnemy(illusion, 1200)
                local illuPos = Entity.GetAbsOrigin(illusion)
                local baitPos
                if enemy then
                    local baseDir = (illuPos - Entity.GetAbsOrigin(enemy)):Normalized()
                    local angleOffset = math.rad(math.random(-90, 90))
                    local dir = Vector(
                        baseDir.x * math.cos(angleOffset) - baseDir.y * math.sin(angleOffset),
                        baseDir.x * math.sin(angleOffset) + baseDir.y * math.cos(angleOffset),
                        0
                    )
                    local dist = math.random(400, 700)
                    baitPos = illuPos + dir * dist
                else
                    local angle = math.rad(math.random(0, 359))
                    local dist = math.random(400, 700)
                    baitPos = illuPos + Vector(math.cos(angle), math.sin(angle), 0) * dist
                end
                Player.PrepareUnitOrders(
                    Players.GetLocal(),
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil,
                    baitPos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    illusion,
                    false,
                    false,
                    false,
                    false,
                    "pl_illusion_bait_hp"
                )
                baitState._hpBaitLastOrder[id] = now
            end
        end
    end

    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if IsIllusionWbaiting(id) then
            if not baitState._wbaitLastOrder[id] or (now - baitState._wbaitLastOrder[id] > 0.7) then
                local enemy = FindNearestEnemy(illusion, 1200)
                local illuPos = Entity.GetAbsOrigin(illusion)
                local baitPos
                if enemy then
                    local baseDir = (illuPos - Entity.GetAbsOrigin(enemy)):Normalized()
                    local angleOffset = math.rad(math.random(-60, 60))
                    local dir = Vector(
                        baseDir.x * math.cos(angleOffset) - baseDir.y * math.sin(angleOffset),
                        baseDir.x * math.sin(angleOffset) + baseDir.y * math.cos(angleOffset),
                        0
                    )
                    local dist = math.random(300, 600)
                    baitPos = illuPos + dir * dist
                else
                    local angle = math.rad(math.random(0, 359))
                    local dist = math.random(300, 600)
                    baitPos = illuPos + Vector(math.cos(angle), math.sin(angle), 0) * dist
                end
                Player.PrepareUnitOrders(
                    Players.GetLocal(),
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil,
                    baitPos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    illusion,
                    false,
                    false,
                    false,
                    false,
                    "pl_illusion_bait_w"
                )
                baitState._wbaitLastOrder[id] = now
            end
        end
    end

    if heroHP < baitHP then
        local minIllu, minHP, minId = nil, math.huge, nil
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            if not IsIllusionBaiting(id) and not IsIllusionWbaiting(id) and not (splitRole and splitRole[id]) then
                local illuHP = Entity.GetHealth(illusion)
                if illuHP < minHP then
                    minHP = illuHP
                    minIllu = illusion
                    minId = id
                end
            end
        end
        if minIllu and not IsIllusionBaiting(minId) then
            baitRole[minId] = true
        end
    end

    if #illusions < minIllusions then return end
    local baitingCount = 0
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if IsIllusionBaiting(id) then
            baitingCount = baitingCount + 1
        end
    end
    if baitingCount >= maxBaiting then return end
    if now - baitState.lastBaitTime < interval then return end
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if not IsIllusionBaiting(id) and not IsIllusionWbaiting(id) and not (splitRole and splitRole[id]) and not (farmRole and farmRole[id]) then
            local illuHP = Entity.GetHealth(illusion)
            if illuHP < baitHP then
                baitRole[id] = true
                baitState._hpBaitLastOrder[id] = now
                baitState.lastBaitTime = now
                break
            end
        end
    end

    local aliveIds = {}
    for _, illusion in ipairs(illusions) do
        aliveIds[Entity.GetIndex(illusion)] = true
    end
    for id, _ in pairs(wbaitRole) do
        if not aliveIds[id] then
            wbaitRole[id] = nil
        end
    end
    for id, _ in pairs(baitRole) do
        if not aliveIds[id] then
            baitRole[id] = nil
        end
    end

    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if not IsIllusionBaiting(id) and not IsIllusionWbaiting(id) and not (splitRole and splitRole[id]) then
            local state = illusionStates[id] and illusionStates[id].state or nil
            if state == "done" or not state then
                local target = FindNearestEnemy(illusion, 1200)
                if target then
                    Player.PrepareUnitOrders(
                        player,
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                        target,
                        Vector(),
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        illusion,
                        false,
                        false,
                        false,
                        false,
                        "pl_illusion_autoattack_idle"
                    )
                end
            end
        end
    end
end

farmRole = farmRole or {}
farmLastOrder = farmLastOrder or {}



function AutoFarmCreepsForIllusions()
    local illusions = GetControllablePLIllusions()
    local myHero = Heroes.GetLocal()
    if not myHero or #illusions == 0 then return end
    
    local enemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}
    if #enemies > 0 then
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            farmRole[id] = nil
        end
        return
    end
    
    if priorityRole then
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            if priorityRole[id] then
                farmRole[id] = nil
            end
        end
    end
    
    local allNPCs = NPCs.GetAll()

    local availableCreeps = {}
    for _, npc in ipairs(allNPCs) do
        if Entity.IsAlive(npc) and not Entity.IsDormant(npc) and Entity.GetTeamNum(npc) ~= Entity.GetTeamNum(myHero) then
            local name = NPC.GetUnitName(npc)
            if name and (string.find(name, "creep") or string.find(name, "neutral") or string.find(name, "siege") or string.find(name, "mega") or NPC.IsRoshan(npc)) then
                table.insert(availableCreeps, npc)
            end
        end
    end

    
    
    -- ваще пиздец, те кто знают iswaiting
    local i = 1
    while i <= #availableCreeps do
        local creep = availableCreeps[i]
        if NPC.IsWaitingToSpawn(creep) then
            table.remove(availableCreeps, i)
        else
            i = i + 1
        end
    end
    
    if #availableCreeps == 0 then
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            farmRole[id] = nil
        end
        return
    end
    
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        
        if (IsIllusionBaiting and IsIllusionBaiting(id)) or 
           (IsIllusionWbaiting and IsIllusionWbaiting(id)) or 
           (splitRole and splitRole[id]) then
            farmRole[id] = nil
            goto continue
        end
        
        local illuPos = Entity.GetAbsOrigin(illusion)
        local nearestCreep = nil
        local minDist = math.huge
        
        local creepsNearby = 0
        for _, creep in ipairs(availableCreeps) do
            local creepPos = Entity.GetAbsOrigin(creep)
            local dist = (illuPos - creepPos):Length()
            if dist < 1200 then
                creepsNearby = creepsNearby + 1
            end
            if dist < minDist and dist < 1200 then
                minDist = dist
                nearestCreep = creep
            end
        end
        
        
        if nearestCreep then
            local now = os.clock()
            if not farmLastOrder[id] or (now - farmLastOrder[id] > math.random(7,12)/10) then

                -- насчет автоластхита, я не эксперт в таком, поэтому может быть wrong.
                local creepHP = Entity.GetHealth(nearestCreep)
                local creepMaxHP = Entity.GetMaxHealth(nearestCreep)
                local hpPercent = creepHP / creepMaxHP
                
                local illusionDamage = NPC.GetTrueDamage(illusion)
                local armorValue = NPC.GetPhysicalArmorValue(nearestCreep) or 0
                local armorReduction = 1 - (armorValue / (armorValue + 20)) --  редакшн +-
                local actualDamage = illusionDamage * armorReduction
                
                local otherIllusionsDamage = 0
                for _, otherIllusion in ipairs(illusions) do
                    if otherIllusion ~= illusion and Entity.IsAlive(otherIllusion) then
                        local otherPos = Entity.GetAbsOrigin(otherIllusion)
                        local creepPos = Entity.GetAbsOrigin(nearestCreep)
                        local dist = (otherPos - creepPos):Length()
                        if dist <= 150 then 
                            local otherDamage = NPC.GetTrueDamage(otherIllusion)
                            otherIllusionsDamage = otherIllusionsDamage + (otherDamage * armorReduction)
                        end
                    end
                end
                
                local heroDamage = 0
                local heroPos = Entity.GetAbsOrigin(myHero)
                local creepPos = Entity.GetAbsOrigin(nearestCreep)
                local heroDist = (heroPos - creepPos):Length()
                if heroDist <= 150 then 
                    heroDamage = NPC.GetTrueDamage(myHero) * armorReduction
                end
                
                local tid = actualDamage + otherIllusionsDamage + heroDamage
                
                local dmgDiff = tid - creepHP
                local wait4LastHit = dmgDiff > 0 and dmgDiff <= 20
                
                if hpPercent < 0.3 and not wait4LastHit then
                    Log.Write(string.format("[dbg] trying to lasthit | creep hp: %d, il dmg: %d, all dmg: %d, dif: %d", 
                        math.floor(creepHP), math.floor(actualDamage), math.floor(tid), math.floor(dmgDiff)))
                    Player.PrepareUnitOrders(
                        Players.GetLocal(),
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                        nearestCreep,
                        Vector(),
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        illusion,
                        false,
                        false,
                        false,
                        false,
                        "pl_illusion_farm_lasthit"
                    )
                    farmLastOrder[id] = now
                    farmRole[id] = true
                    followRole[id] = nil
                elseif wait4LastHit then
                    Log.Write(string.format("[dbg] waiting best moment4hit | creep hp: %d, alldmg: %d, er: %d", 
                        math.floor(creepHP), math.floor(tid), math.floor(dmgDiff)))
                else
                    Player.PrepareUnitOrders(
                        Players.GetLocal(),
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                        nearestCreep,
                        Vector(),
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        illusion,
                        false,
                        false,
                        false,
                        false,
                        "pl_illusion_farm"
                    )
                    farmLastOrder[id] = now
                    farmRole[id] = true
                    followRole[id] = nil
                end
            end
        else
            farmRole[id] = nil
        end
        
        ::continue::
    end
    
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if farmRole and farmRole[id] then
            local currentTarget = Entity.GetAttackTarget and Entity.GetAttackTarget(illusion)
            local isAttackingCreep = false
            
            if currentTarget and Entity.IsAlive(currentTarget) and not Entity.IsDormant(currentTarget) then
                local targetName = NPC.GetUnitName(currentTarget)
                if targetName and (string.find(targetName, "creep") or string.find(targetName, "neutral") or string.find(targetName, "siege") or string.find(targetName, "mega")) then
                    isAttackingCreep = true
                end
            end
            
            local illuPos = Entity.GetAbsOrigin(illusion)
            local hasCreepsNearby = false
            
            for _, creep in ipairs(availableCreeps) do
                local creepPos = Entity.GetAbsOrigin(creep)
                local dist = (illuPos - creepPos):Length()
                if dist < 1200 then
                    hasCreepsNearby = true
                    break
                end
            end
            
            if not isAttackingCreep and not hasCreepsNearby then
                farmRole[id] = nil
            end
        end
    end
end

chaseRole = chaseRole or {}
chaseLastOrder = chaseLastOrder or {}

-- FIXME: на самом деле очень баганная функция, и ее реализация не совсем корректна
function AutoChaseEnemyForIllusions()
    if not UI.AutoChase.Enabled:Get() then
        for _, illusion in ipairs(GetAllPLIllusions()) do
            local id = Entity.GetIndex(illusion)
            chaseRole[id] = nil
        end
        return
    end
    local illusions = GetControllablePLIllusions()
    local myHero = Heroes.GetLocal()
    if not myHero or #illusions == 0 then return end
    local closeEnemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}
    if #closeEnemies > 0 then
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            chaseRole[id] = nil
        end
        return
    end
    local chaseRadius = UI.AutoChase.Radius:Get()
    local farEnemies = Entity.GetHeroesInRadius(myHero, chaseRadius, Enum.TeamType.TEAM_ENEMY, true) or {}
    if #farEnemies == 0 then
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            chaseRole[id] = nil
        end
        return
    end
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if priorityRole and priorityRole[id] then
            chaseRole[id] = nil
            goto continue
        end
        if not (IsIllusionBaiting and IsIllusionBaiting(id)) and not (IsIllusionWbaiting and IsIllusionWbaiting(id)) and not (farmRole and farmRole[id]) and not (followRole and followRole[id]) and not (splitRole and splitRole[id]) then
            local illuPos = Entity.GetAbsOrigin(illusion)
            local minDist, nearestEnemy = math.huge, nil
            for _, enemy in ipairs(farEnemies) do
                if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) then
                    local dist = (illuPos - Entity.GetAbsOrigin(enemy)):Length()
                    if dist < minDist then
                        minDist = dist
                        nearestEnemy = enemy
                    end
                end
            end
            if nearestEnemy then
                local now = os.clock()
                if not chaseLastOrder[id] or (now - chaseLastOrder[id] > math.random(7,12)/10) then
                    Player.PrepareUnitOrders(
                        Players.GetLocal(),
                        Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                        nearestEnemy,
                        Vector(),
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        illusion,
                        false,
                        false,
                        false,
                        false,
                        "pl_illusion_chase"
                    )
                    chaseLastOrder[id] = now
                    chaseRole[id] = true
                end
            else
                chaseRole[id] = nil
            end
        else
            chaseRole[id] = nil
        end
        ::continue::
    end
end

bodyblockRole = bodyblockRole or {}
bodyblockLastOrder = bodyblockLastOrder or {}
bodyblockActiveId = bodyblockActiveId or nil
bodyblockActiveTime = bodyblockActiveTime or 0

function AutoBodyblockForIllusions()
    local illusions = GetControllablePLIllusions()
    local myHero = Heroes.GetLocal()
    local now = os.clock()
    
    local forceBodyblockKey = UI.AutoBodyblock.ForceBodyblockKey:Get()
    local isForceBodyblockPressed = forceBodyblockKey ~= Enum.ButtonCode.KEY_NONE and Input.IsKeyDown(forceBodyblockKey)
    
    if isForceBodyblockPressed then
        local forceBodyblockIllu = nil
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            if not (IsIllusionBaiting and IsIllusionBaiting(id)) and not (IsIllusionWbaiting and IsIllusionWbaiting(id)) and not (farmRole and farmRole[id]) and not (chaseRole and chaseRole[id]) and not (followRole and followRole[id]) and not (priorityRole and priorityRole[id]) and not (splitRole and splitRole[id]) then
                forceBodyblockIllu = illusion
                break
            end
        end
        
        if forceBodyblockIllu then
            local enemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}
            if #enemies > 0 then
                local bestEnemy, minDist = nil, math.huge
                for _, enemy in ipairs(enemies) do
                    if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) then
                        local dist = (Entity.GetAbsOrigin(myHero) - Entity.GetAbsOrigin(enemy)):Length()
                        if dist < minDist then
                            minDist = dist
                            bestEnemy = enemy
                        end
                    end
                end
                
                if bestEnemy then
                    local id = Entity.GetIndex(forceBodyblockIllu)
                    bodyblockRole[id] = true
                    
                    local enemy = bestEnemy
                    local enemyPos = Entity.GetAbsOrigin(enemy)
                    local enemyDir = Entity.GetRotation(enemy):GetForward()
                    local illuPos = Entity.GetAbsOrigin(forceBodyblockIllu)
                    local toIllu = (illuPos - enemyPos):Normalized()
                    local enemySpeed = NPC.GetMoveSpeed(enemy)

                    local dynamicDistance = (enemySpeed < 250) and 76.5 or 80
                    local predictTime = 0.18
                    local predictPos = enemyPos + enemyDir * enemySpeed * predictTime

                    local angleToIllu = math.atan2(toIllu.y, toIllu.x) - math.atan2(enemyDir.y, enemyDir.x)
                    if angleToIllu > math.pi then angleToIllu = angleToIllu - 2*math.pi end
                    if angleToIllu < -math.pi then angleToIllu = angleToIllu + 2*math.pi end

                    local blockPos
                    if math.abs(angleToIllu) > math.pi/2 then
                        local sideAngle = angleToIllu > 0 and math.pi/2 or -math.pi/2
                        local sideDir = Vector(
                            enemyDir.x * math.cos(sideAngle) - enemyDir.y * math.sin(sideAngle),
                            enemyDir.x * math.sin(sideAngle) + enemyDir.y * math.cos(sideAngle),
                            0
                        )
                        local sideOffset = sideDir * dynamicDistance * 1.5
                        local forwardOffset = enemyDir * dynamicDistance
                        blockPos = enemyPos + sideOffset + forwardOffset
                    else
                        blockPos = predictPos + enemyDir * dynamicDistance
                    end
                    
                    if not bodyblockLastOrder[id] or (now - bodyblockLastOrder[id] > math.random(1,2)/10) then
                        Player.PrepareUnitOrders(
                            Players.GetLocal(),
                            Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                            nil,
                            blockPos,
                            nil,
                            Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                            forceBodyblockIllu,
                            false,
                            false,
                            false,
                            false,
                            "pl_illusion_force_bodyblock"
                        )
                        bodyblockLastOrder[id] = now
                    end
                end
            end
        end
        return
    end
    
    if not UI.AutoBodyblock.Enabled:Get() then
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            bodyblockRole[id] = nil
        end
        bodyblockActiveId = nil
        bodyblockActiveTime = 0
        return
    end
    
    if NetChannel and NetChannel.GetAvgLatency then
        local ping = NetChannel.GetAvgLatency(Enum.Flow.FLOW_OUTGOING) * 1000
        if ping > UI.AutoBodyblock.PingThreshold:Get() then
            for _, illusion in ipairs(illusions) do
                local id = Entity.GetIndex(illusion)
                bodyblockRole[id] = nil
            end
            bodyblockActiveId = nil
            bodyblockActiveTime = 0
            return
        end
    end
    
    if #illusions < 2 then
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            bodyblockRole[id] = nil
        end
        bodyblockActiveId = nil
        bodyblockActiveTime = 0
        return
    end
    
    local enemies = Entity.GetHeroesInRadius(myHero, 1200, Enum.TeamType.TEAM_ENEMY, true) or {}
    if #enemies == 0 then
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            bodyblockRole[id] = nil
        end
        bodyblockActiveId = nil
        bodyblockActiveTime = 0
        return
    end

    local bodyblockIllu = nil
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if not (IsIllusionBaiting and IsIllusionBaiting(id)) and not (IsIllusionWbaiting and IsIllusionWbaiting(id)) and not (farmRole and farmRole[id]) and not (chaseRole and chaseRole[id]) and not (followRole and followRole[id]) and not (priorityRole and priorityRole[id]) and not (splitRole and splitRole[id]) then
            bodyblockIllu = illusion
            break
        end
    end

    local bestEnemy, minDist = nil, math.huge
    for _, enemy in ipairs(enemies) do
        if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) then
            local dist = (Entity.GetAbsOrigin(myHero) - Entity.GetAbsOrigin(enemy)):Length()
            if dist < minDist then
                minDist = dist
                bestEnemy = enemy
            end
        end
    end
    
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if illusion == bodyblockIllu then
            bodyblockRole[id] = true
        else
            bodyblockRole[id] = nil
        end
    end
    
    if bodyblockIllu and bestEnemy then
        local id = Entity.GetIndex(bodyblockIllu)
        local enemy = bestEnemy
        local enemyPos = Entity.GetAbsOrigin(enemy)
        local enemyDir = Entity.GetRotation(enemy):GetForward()
        local illuPos = Entity.GetAbsOrigin(bodyblockIllu)
        local toIllu = (illuPos - enemyPos):Normalized()
        local enemySpeed = NPC.GetMoveSpeed(enemy)

        local dynamicDistance = (enemySpeed < 250) and 76.5 or 80
        local predictTime = 0.18
        local predictPos = enemyPos + enemyDir * enemySpeed * predictTime

        local angleToIllu = math.atan2(toIllu.y, toIllu.x) - math.atan2(enemyDir.y, enemyDir.x)
        if angleToIllu > math.pi then angleToIllu = angleToIllu - 2*math.pi end
        if angleToIllu < -math.pi then angleToIllu = angleToIllu + 2*math.pi end

        local blockPos
        if math.abs(angleToIllu) > math.pi/2 then
            local sideAngle = angleToIllu > 0 and math.pi/2 or -math.pi/2
            local sideDir = Vector(
                enemyDir.x * math.cos(sideAngle) - enemyDir.y * math.sin(sideAngle),
                enemyDir.x * math.sin(sideAngle) + enemyDir.y * math.cos(sideAngle),
                0
            )
            local sideOffset = sideDir * dynamicDistance * 1.5
            local forwardOffset = enemyDir * dynamicDistance
            blockPos = enemyPos + sideOffset + forwardOffset
        else
            blockPos = predictPos + enemyDir * dynamicDistance
        end
        
        if not bodyblockLastOrder[id] or (now - bodyblockLastOrder[id] > math.random(1,2)/10) then
            Player.PrepareUnitOrders(
                Players.GetLocal(),
                Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                nil,
                blockPos,
                nil,
                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                bodyblockIllu,
                false,
                false,
                false,
                false,
                "pl_illusion_bodyblock"
            )
            bodyblockLastOrder[id] = now
        end
    end
end

priorityRole = priorityRole or {}
priorityTarget = priorityTarget or {}
priorityLastOrder = priorityLastOrder or {}

local importantNames = {
    ["npc_dota_healing_ward"] = true,
    ["npc_dota_weaver_swarm"] = true,
    ["npc_dota_shadow_shaman_serpent_ward"] = true,
    ["npc_dota_rattletrap_cog"] = true,
    ["npc_dota_ward_base"] = true,
    ["npc_dota_phoenix_sun"] = true,
    ["npc_dota_tombstone"] = true,
    ["npc_dota_unit_tombstone4"] = true,

}

local function IsImportantName(name)
    if importantNames[name] then return true end
    if string.find(name, "npc_dota_shadow_shaman_ward_") then return true end
    if string.find(name, "npc_dota_unit_tombstone%d*$") then return true end
    return false
end

function AutoPriorityAttackForIllusions()
    local illusions = GetControllablePLIllusions()
    local myHero = Heroes.GetLocal()
    if not myHero or #illusions == 0 then return end
    local allNPCs = NPCs.GetAll()
    local important = {}
    for _, npc in ipairs(allNPCs) do
        local name = tostring(NPC.GetUnitName(npc))
        local id = Entity.GetIndex(npc)
        local alive = tostring(Entity.IsAlive(npc))
        local dormant = tostring(Entity.IsDormant(npc))
        local pos = Entity.GetAbsOrigin(npc)
        local dist = (Entity.GetAbsOrigin(myHero) - pos):Length()
        if IsImportantName(name) and Entity.IsAlive(npc) and not Entity.IsDormant(npc) and dist < 1200 then
            table.insert(important, npc)
        end
        if Entity.IsHero(npc) and NPC.HasModifier(npc, "modifier_healing_salve") and Entity.IsAlive(npc) and not Entity.IsDormant(npc) and dist < 1200 then
            table.insert(important, npc)
        end
    end
    local assigned = {}
    local assignedIllusions = {}
    local maxIllusionsPerTarget = UI.AutoSplit.MaxIllusionsPerTarget:Get()
    for _, npc in ipairs(important) do
        local npcId = Entity.GetIndex(npc)
        assignedIllusions[npcId] = 0
    end
    for _, npc in ipairs(important) do
        local npcId = Entity.GetIndex(npc)
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            if not (IsIllusionBaiting and IsIllusionBaiting(id)) and not (IsIllusionWbaiting and IsIllusionWbaiting(id)) and not (bodyblockRole and bodyblockRole[id]) and not (splitRole and splitRole[id]) and not assigned[id] and assignedIllusions[npcId] < maxIllusionsPerTarget then
                local now = os.clock()
                if not priorityLastOrder[id] or (now - priorityLastOrder[id] > math.random(7,12)/10) then
                Player.PrepareUnitOrders(
                    Players.GetLocal(),
                    Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                    npc,
                    Vector(),
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    illusion,
                    false,
                    false,
                    false,
                    false,
                    "pl_illusion_priority"
                )
                priorityRole[id] = true
                priorityTarget[id] = npc
                assigned[id] = true
                assignedIllusions[npcId] = assignedIllusions[npcId] + 1
                priorityLastOrder[id] = now
                end
            end
        end
    end
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if not assigned[id] then
            priorityRole[id] = nil
            priorityTarget[id] = nil
        end
        if priorityRole[id] then
            splitRole[id] = nil
            chaseRole[id] = nil
            farmRole[id] = nil
            followRole[id] = nil
            bodyblockRole[id] = nil
        end
    end
end

splitRole = splitRole or {}
splitTarget = splitTarget or {}
splitLastOrder = splitLastOrder or {}

-- Писал эту функцию после большого перерыва, и фикса других функций. Мне тут не очень нравиться ее реализация, но она корректная.
-- FIXME: Вообще она должна отвести столько иллюзий сколько указанно в уи элементе, но работает так что если иллюзий больше чем указанно в
-- максимальном количестве, то он будет отводить весь остаток.
function AutoSplitAttackForIllusions()
    if not UI.AutoSplit.Enabled:Get() then
        for _, illusion in ipairs(GetAllPLIllusions()) do
            local id = Entity.GetIndex(illusion)
            splitRole[id] = nil
            splitTarget[id] = nil
        end
        return
    end

    local illusions = GetControllablePLIllusions()
    local myHero = Heroes.GetLocal()
    if not myHero or #illusions == 0 then return end

    local searchRadius = UI.AutoSplit.SearchRadius:Get()
    local minEnemies = UI.AutoSplit.MinEnemies:Get()
    local enemies = Entity.GetHeroesInRadius(myHero, searchRadius, Enum.TeamType.TEAM_ENEMY, true) or {}

    if #enemies < minEnemies then
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            splitRole[id] = nil
            splitTarget[id] = nil
        end
        return
    end

    local now = os.clock()
    local targetCount = {}
    local illusionTarget = {}
    local freeIllusions = {}

    local skippedIllusions = 0
    local attackingIllusions = 0
    local freeIllusionsCount = 0

    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        splitRole[id] = nil
        splitTarget[id] = nil

        if priorityRole and priorityRole[id] then goto continue end
        if IsIllusionBaiting and IsIllusionBaiting(id) then goto continue end
        if IsIllusionWbaiting and IsIllusionWbaiting(id) then goto continue end
        if bodyblockRole and bodyblockRole[id] then goto continue end
        if chaseRole and chaseRole[id] then goto continue end
        if farmRole and farmRole[id] then goto continue end
        if followRole and followRole[id] then goto continue end

        local target = Entity.GetAttackTarget and Entity.GetAttackTarget(illusion)
        local isAttackingHero = false

        if target and Entity.IsHero(target) and Entity.IsAlive(target) and not Entity.IsDormant(target) then
            local tid = Entity.GetIndex(target)
            targetCount[tid] = (targetCount[tid] or 0) + 1
            illusionTarget[id] = tid
            attackingIllusions = attackingIllusions + 1
            isAttackingHero = true
        else

            local illuPos = Entity.GetAbsOrigin(illusion)
            local nearestEnemy = nil
            local nearestDist = math.huge

            for _, enemy in ipairs(enemies) do
                if Entity.IsAlive(enemy) and not Entity.IsDormant(enemy) then
                    local dist = (illuPos - Entity.GetAbsOrigin(enemy)):Length()
                    local attackRange = GetAttackRange(illusion)

                    if dist <= attackRange * 1.5 then
                        if dist < nearestDist then
                            nearestDist = dist
                            nearestEnemy = enemy
                        end
                    end
                end
            end

            if nearestEnemy then
                local tid = Entity.GetIndex(nearestEnemy)
                targetCount[tid] = (targetCount[tid] or 0) + 1
                illusionTarget[id] = tid
                attackingIllusions = attackingIllusions + 1
                isAttackingHero = true
            end
        end

        if not isAttackingHero then

            table.insert(freeIllusions, illusion)
            freeIllusionsCount = freeIllusionsCount + 1
        end
        ::continue::
    end

    local maxIllusionsPerTarget = UI.AutoSplit.MaxIllusionsPerTarget:Get()
    local splitCount = UI.AutoSplit.SplitCount:Get()

    local overloadedTargets = {}
    for enemyId, count in pairs(targetCount) do
        if count > maxIllusionsPerTarget then
            table.insert(overloadedTargets, {
                enemyId = enemyId,
                excess = count - maxIllusionsPerTarget,
                count = count
            })
        end
    end

    table.sort(overloadedTargets, function(a, b) return a.excess > b.excess end)

    for _, overloaded in ipairs(overloadedTargets) do
        local enemyId = overloaded.enemyId
        local excess = overloaded.excess
        local redirectCount = math.min(excess, splitCount)

        local attackingIllusions = {}
        for _, illusion in ipairs(illusions) do
            local id = Entity.GetIndex(illusion)
            if illusionTarget[id] == enemyId then
                table.insert(attackingIllusions, illusion)
            end
        end

        if #attackingIllusions == 0 then
            for _, illusion in ipairs(illusions) do
                local id = Entity.GetIndex(illusion)

                if priorityRole and priorityRole[id] then goto continue_search end
                if IsIllusionBaiting and IsIllusionBaiting(id) then goto continue_search end
                if IsIllusionWbaiting and IsIllusionWbaiting(id) then goto continue_search end
                if bodyblockRole and bodyblockRole[id] then goto continue_search end
                if chaseRole and chaseRole[id] then goto continue_search end
                if farmRole and farmRole[id] then goto continue_search end
                if followRole and followRole[id] then goto continue_search end

                local illuPos = Entity.GetAbsOrigin(illusion)
                local enemyPos = Entity.GetAbsOrigin(enemy)
                local dist = (illuPos - enemyPos):Length()
                local attackRange = GetAttackRange(illusion)

                if dist <= attackRange * 1.5 then
                    table.insert(attackingIllusions, illusion)
                end
                ::continue_search::
            end
        end

        local enemy = nil
        for _, e in ipairs(enemies) do
            if Entity.GetIndex(e) == enemyId then
                enemy = e
                break
            end
        end

        if enemy then
            table.sort(attackingIllusions, function(a, b)
                local distA = (Entity.GetAbsOrigin(a) - Entity.GetAbsOrigin(enemy)):Length()
                local distB = (Entity.GetAbsOrigin(b) - Entity.GetAbsOrigin(enemy)):Length()
                return distA < distB
            end)

            local alternativeTarget = nil
            local bestScore = -1

            for _, potentialTarget in ipairs(enemies) do
                local targetId = Entity.GetIndex(potentialTarget)
                if targetId ~= enemyId and Entity.IsAlive(potentialTarget) and not Entity.IsDormant(potentialTarget) then
                    local currentCount = targetCount[targetId] or 0
                    -- ахахах, ну закос под умную систему =))
                    local distance = (Entity.GetAbsOrigin(enemy) - Entity.GetAbsOrigin(potentialTarget)):Length()

                    local score = 1000 - currentCount * 100 - distance * 0.1

                    if score > bestScore then
                        bestScore = score
                        alternativeTarget = potentialTarget
                    end
                end
            end

            if alternativeTarget then

                for i = 1, redirectCount do
                    if i <= #attackingIllusions then
                        local illusion = attackingIllusions[i]
                        local id = Entity.GetIndex(illusion)

                        if not splitLastOrder[id] or (now - splitLastOrder[id] > math.random(7,12)/10) then
                            Player.PrepareUnitOrders(
                                Players.GetLocal(),
                                Enum.UnitOrder.DOTA_UNIT_ORDER_ATTACK_TARGET,
                                alternativeTarget,
                                Vector(),
                                nil,
                                Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                                illusion,
                                false,
                                false,
                                false,
                                false,
                                "pl_illusion_split"
                            )
                            splitRole[id] = true
                            splitTarget[id] = alternativeTarget
                            splitLastOrder[id] = now

                            targetCount[enemyId] = targetCount[enemyId] - 1
                            targetCount[Entity.GetIndex(alternativeTarget)] = (targetCount[Entity.GetIndex(alternativeTarget)] or 0) + 1
                        end
                    end
                end
            end
        end
    end

    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        if splitRole[id] then
            local target = splitTarget[id]
            if target and Entity.IsAlive(target) then
                local targetId = Entity.GetIndex(target)
                local currentCount = 0
                for _, otherIllusion in ipairs(illusions) do
                    local otherId = Entity.GetIndex(otherIllusion)

                    if Entity.GetAttackTarget and Entity.GetAttackTarget(otherIllusion) == target then
                        currentCount = currentCount + 1
                    end
                end

                local targetPos = Entity.GetAbsOrigin(target)
                for _, otherIllusion in ipairs(illusions) do
                    local otherId = Entity.GetIndex(otherIllusion)
                    local otherPos = Entity.GetAbsOrigin(otherIllusion)
                    local dist = (otherPos - targetPos):Length()
                    local attackRange = GetAttackRange(otherIllusion)

                    if dist <= attackRange * 1.5 then
                        if not (priorityRole and priorityRole[otherId]) and 
                           not (IsIllusionBaiting and IsIllusionBaiting(otherId)) and 
                           not (IsIllusionWbaiting and IsIllusionWbaiting(otherId)) and 
                           not (bodyblockRole and bodyblockRole[otherId]) and 
                           not (chaseRole and chaseRole[otherId]) and 
                           not (farmRole and farmRole[otherId]) and 
                           not (followRole and followRole[otherId]) then
                            currentCount = currentCount + 1
                        end
                    end
                end

                if currentCount <= maxIllusionsPerTarget then
                    splitRole[id] = nil
                    splitTarget[id] = nil
                end
            else
                splitRole[id] = nil
                splitTarget[id] = nil
            end
        end
    end
end

local function DrawIllusionStatus()
    if not UI.Visuals.StatusText:Get() then return end
    local illusions = GetAllPLIllusions()
    for _, illusion in ipairs(illusions) do
        local pos = Entity.GetAbsOrigin(illusion) + Vector(0, 0, NPC.GetHealthBarOffset(illusion))
        local screenPos, isVisible = Render.WorldToScreen(pos)
        if isVisible then
            local id = Entity.GetIndex(illusion)
            local state = illusionStates[id] and illusionStates[id].state or "?"
            local text = ""
            if playerOverrideUntil and playerOverrideUntil[id] and os.clock() < playerOverrideUntil[id] then
                local remain = math.max(0, playerOverrideUntil[id] - os.clock())
                text = string.format("Override: %.1fs", remain)
            elseif IsIllusionWbaiting(id) then
                text = "W-Bait"
            elseif IsIllusionBaiting(id) then
                text = "Bait"
            elseif runawayRole and runawayRole[id] then
                text = "RunAway"
            elseif bodyblockRole and bodyblockRole[id] then
                -- Проверяем, активен ли принудительный бодиблок
                local forceBodyblockKey = UI.AutoBodyblock.ForceBodyblockKey:Get()
                local isForceBodyblockPressed = forceBodyblockKey ~= Enum.ButtonCode.KEY_NONE and Input.IsKeyDown(forceBodyblockKey)
                if isForceBodyblockPressed then
                    text = "Force Bodyblock"
                else
                    text = "Bodyblock"
                end
            elseif priorityRole and priorityRole[id] then
                text = "Priority"
            elseif splitRole and splitRole[id] then
                text = "Split"
            elseif chaseRole and chaseRole[id] then
                text = "Chase"
            elseif farmRole and farmRole[id] then
                text = "Farming creeps"
            elseif state == "retreating" then
                text = string.format(
                    "Illusion: retreating (start: %d, retreat: %d, path: %d, attempts: %d)",
                    math.floor(illusionStates[id].startDist or 0),
                    math.floor(illusionStates[id].retreatDist or 0),
                    math.floor(illusionStates[id].pathLen or 0),
                    illusionStates[id].retreatTries or 1
                )
            elseif state == "attacking" then
                local distToEnemy = illusionStates[id].distToEnemy or 0
                if distToEnemy > 450 then distToEnemy = 450 end
                text = string.format("Illusion: attacking enemy (dist: %d)", math.floor(distToEnemy))
            elseif state == "done" then
                text = "Illusion: ready"
            else
                text = "Illusion: waiting for enemy"
            end

            if illusionStates[id] and illusionStates[id].status then
                text = text .. string.format(" [%s]", illusionStates[id].status)
            end
            local textSize = Render.TextSize(Config.Fonts.Main, 16, text)
            local x = screenPos.x - textSize.x / 2
            local y = screenPos.y - 60
            -- Я знаю про DROPSHADOW флаг, но мне привычнее так. шатаут никсварапи =)
            Render.Text(Config.Fonts.Main, 16, text, Vec2(x + 1, y + 1), Config.Colors.Text.Shadow)
            Render.Text(Config.Fonts.Main, 16, text, Vec2(x, y), Config.Colors.Text.Primary)
        end
    end
end

local PanelDrag = {
    IsDragging = false,
    StartX = 0,
    StartY = 0,
    OffsetX = 0,
    OffsetY = 0
}

local PanelConfig = {
    X = 50,
    Y = 100,
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

local panelPosX = 50
local panelPosY = 100

local function GetConfigPath()
    return "pl_panel.ini"
end

local function LoadPanelPosition()
    local configPath = GetConfigPath()
    local file = io.open(configPath, "r")
    if file then
        for line in file:lines() do
            local x = line:match("pos_x=(%d+)")
            local y = line:match("pos_y=(%d+)")
            if x then panelPosX = tonumber(x) end
            if y then panelPosY = tonumber(y) end
        end
        file:close()
    end

    PanelConfig.X = panelPosX
    PanelConfig.Y = panelPosY
end

local function SavePanelPosition()
    local configPath = GetConfigPath()
    local file = io.open(configPath, "w")
    if file then
        file:write(string.format("pos_x=%d\n", PanelConfig.X))
        file:write(string.format("pos_y=%d\n", PanelConfig.Y))
        file:close()
    end
end

local PanelColors = {
    Background = Color(20, 20, 25, 220),
    BackgroundHover = Color(25, 25, 30, 230),
    Border = Color(60, 60, 70, 180),
    BorderHover = Color(80, 120, 255, 200),
    Header = Color(10, 10, 10, 200),
    HeaderText = Color(255, 255, 255, 255),
    Shadow = Color(0, 0, 0, 100),
    StatusColors = {
        ["W-Bait"] = Color(255, 220, 0, 255),
    ["Bait"] = Color(255, 140, 0, 255),
    ["Bodyblock"] = Color(80, 120, 255, 255),
    ["Force Bodyblock"] = Color(255, 80, 80, 255),
    ["Priority"] = Color(255, 255, 120, 255),
    ["Split"] = Color(120, 255, 255, 255),
    ["Chase"] = Color(255, 120, 255, 255),
    ["Farm"] = Color(120, 200, 255, 255),
    ["Follow"] = Color(120, 255, 120, 255),
    ["Retreating"] = Color(80, 180, 255, 255),
    ["Attacking"] = Color(255, 80, 80, 255),
    ["Done"] = Color(180, 180, 180, 255),
    ["Idle"] = Color(150, 150, 150, 255),
    ["RunAway"] = Color(255, 200, 120, 255)
    }
}

local function GetIllusionStatus(id)
    if IsIllusionWbaiting(id) then
        return "W", "W-Bait"
    elseif IsIllusionBaiting(id) then
        return "B", "Bait"
    elseif bodyblockRole and bodyblockRole[id] then
        -- Проверяем, активен ли принудительный бодиблок
        local forceBodyblockKey = UI.AutoBodyblock.ForceBodyblockKey:Get()
        local isForceBodyblockPressed = forceBodyblockKey ~= Enum.ButtonCode.KEY_NONE and Input.IsKeyDown(forceBodyblockKey)
        if isForceBodyblockPressed then
            return "FB", "Force Bodyblock"
        else
            return "BB", "Bodyblock"
        end
    elseif priorityRole and priorityRole[id] then
        return "P", "Priority"
    elseif splitRole and splitRole[id] then
        return "S", "Split"
    elseif chaseRole and chaseRole[id] then
        return "C", "Chase"
    elseif farmRole and farmRole[id] then
        return "F", "Farm"
    elseif followRole[id] then
        return "FL", "Follow"
    elseif illusionStates[id] then
        if illusionStates[id].state == "retreating" then
            return "R", "Retreating"
        elseif illusionStates[id].state == "attacking" then
            return "A", "Attacking"
        elseif illusionStates[id].state == "done" then
            return "D", "Done"
        end
    elseif runawayRole and runawayRole[id] then
        return "RA", "RunAway"
    end
    -- необязательно, идл все равно не рендерим.
    return "I", "Idle"
end

local function HandlePanelInput()
    local cursorX, cursorY = Input.GetCursorPos()
    local isInHeader = cursorX >= PanelConfig.X and cursorX <= PanelConfig.X + PanelConfig.Width and
                      cursorY >= PanelConfig.Y and cursorY <= PanelConfig.Y + PanelConfig.HeaderHeight

    local isInPanel = cursorX >= PanelConfig.X and cursorX <= PanelConfig.X + PanelConfig.Width and
                     cursorY >= PanelConfig.Y and cursorY <= PanelConfig.Y + PanelConfig.Height

    if isInHeader and Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) and not PanelDrag.IsDragging then
        PanelDrag.IsDragging = true
        PanelDrag.StartX = cursorX
        PanelDrag.StartY = cursorY
        PanelDrag.OffsetX = cursorX - PanelConfig.X
        PanelDrag.OffsetY = cursorY - PanelConfig.Y
    end

    if PanelDrag.IsDragging then
        if Input.IsKeyDown(Enum.ButtonCode.KEY_MOUSE1) then
            PanelConfig.X = cursorX - PanelDrag.OffsetX
            PanelConfig.Y = cursorY - PanelDrag.OffsetY

            local screenSize = Render.ScreenSize()
            PanelConfig.X = math.max(0, math.min(PanelConfig.X, screenSize.x - PanelConfig.Width))
            PanelConfig.Y = math.max(0, math.min(PanelConfig.Y, screenSize.y - PanelConfig.Height))
        else

            SavePanelPosition()
            PanelDrag.IsDragging = false
        end
    end

    return isInPanel
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

-- Закос под панель, как в скрипте на арка но более swag
local function DrawModernPanel()
    local illusions = GetAllPLIllusions()

    local isHovered = HandlePanelInput()

    local bgColor = isHovered and PanelColors.BackgroundHover or PanelColors.Background
    local borderColor = isHovered and PanelColors.BorderHover or PanelColors.Border

    DrawBlurredBackground(PanelConfig.X, PanelConfig.Y, PanelConfig.Width, PanelConfig.HeaderHeight, PanelConfig.BorderRadius, PanelConfig.BlurStrengthHeader, 0.91)

    Render.Shadow(
        Vec2(PanelConfig.X, PanelConfig.Y ),
        Vec2(PanelConfig.X + PanelConfig.Width, PanelConfig.Y + PanelConfig.HeaderHeight),
        Color(0, 0, 0, 255),
        24,
        PanelConfig.BorderRadius,
        Enum.DrawFlags.ShadowCutOutShapeBackground,
        Vec2(1, 1)
    )

    Render.FilledRect(
        Vec2(PanelConfig.X, PanelConfig.Y),
        Vec2(PanelConfig.X + PanelConfig.Width, PanelConfig.Y + PanelConfig.HeaderHeight),
        PanelColors.Header,
        PanelConfig.BorderRadius
    )

    local starsIcon = "⋆｡°✩"
    local starsSize = Render.TextSize(Config.Fonts.Main, 14, starsIcon)
    local starsX = PanelConfig.X + 8
    local starsY = PanelConfig.Y + (PanelConfig.HeaderHeight - starsSize.y) / 2

    Render.Text(Config.Fonts.Main, 14, starsIcon, Vec2(starsX + 1, starsY), Color(0, 0, 0, 80))
    Render.Text(Config.Fonts.Main, 14, starsIcon, Vec2(starsX, starsY - 1), Color(170, 170, 170, 255))

    local separatorX = starsX + starsSize.x + 8
    local separatorY = PanelConfig.Y + 4
    local separatorHeight = PanelConfig.HeaderHeight - 8

    Render.FilledRect(
        Vec2(separatorX, separatorY-4),
        Vec2(separatorX + 2, separatorY + separatorHeight + 4),
        Color(15, 15, 15, 70)
    )

    local maintext = "@illusions"
    local maintextSize = Render.TextSize(Config.Fonts.Main, 12, maintext)
    local maintextX = separatorX + 8
    local maintextY = PanelConfig.Y + (PanelConfig.HeaderHeight - maintextSize.y) / 2

    Render.Text(Config.Fonts.Main, 12, maintext, Vec2(maintextX + 1, maintextY + 1), Color(0, 0, 0, 80))
    Render.Text(Config.Fonts.Main, 12, maintext, Vec2(maintextX, maintextY), Color(170, 170, 170, 255))

    local contentY = PanelConfig.Y + PanelConfig.HeaderHeight + 5

    local activeIllusions = {}
    for _, illusion in ipairs(illusions) do
        local id = Entity.GetIndex(illusion)
        local statusCode, statusName = GetIllusionStatus(id)
        if statusName ~= "Done" and statusName ~= "Idle" then
            table.insert(activeIllusions, illusion)
        end
    end

    local maxCells = 6
    local cellStartX = PanelConfig.X + 8
    local cellY = contentY

    for i = 1, maxCells do
        local cellX = cellStartX + (i - 1) * (PanelConfig.CellSize + PanelConfig.CellSpacing)

        DrawBlurredBackground(cellX, cellY, PanelConfig.CellSize, PanelConfig.CellSize, 6, 8, 0.97)

        Render.Shadow(
            Vec2(cellX, cellY),
            Vec2(cellX + PanelConfig.CellSize, cellY + PanelConfig.CellSize),
            Color(0, 0, 0, 255),
            24,
            6,
            Enum.DrawFlags.ShadowCutOutShapeBackground,
            Vec2(1, 1)
        )

        Render.FilledRect(
            Vec2(cellX, cellY),
            Vec2(cellX + PanelConfig.CellSize, cellY + PanelConfig.CellSize),
            Color(0, 0, 0, 140),
            6
        )

        if i <= #activeIllusions then
            local illusion = activeIllusions[i]
            local id = Entity.GetIndex(illusion)
            local statusCode, statusName = GetIllusionStatus(id)
            local statusColor = PanelColors.StatusColors[statusName] or PanelColors.StatusColors["Idle"]

            local statusText = statusCode
            local statusTextSize = Render.TextSize(Config.Fonts.Main, 12, statusText)
            local textX = cellX + (PanelConfig.CellSize - statusTextSize.x) / 2
            local textY = cellY + (PanelConfig.CellSize - statusTextSize.y) / 2

            Render.Text(Config.Fonts.Main, 12, statusText, Vec2(textX + 1, textY + 1), Color(0, 0, 0, 100))
            Render.Text(Config.Fonts.Main, 12, statusText, Vec2(textX, textY), statusColor)
        end

    end

end

local function AutoRunAwayIllusionsV2()
    if not UI or not UI.RunAway then return end
    local myHero = Heroes.GetLocal()
    if not myHero then return end

    local bind = UI.RunAway.HoldKey
    local isHeld = false
    if bind then
        if bind.IsDown and bind:IsDown() then isHeld = true end
        if bind.IsPressed and bind:IsPressed() then isHeld = true end
        if bind.Buttons then
            local k1, k2 = bind:Buttons()
            if k1 and k1 ~= Enum.ButtonCode.BUTTON_CODE_INVALID and k1 ~= Enum.ButtonCode.KEY_NONE and Input.IsKeyDown(k1) then isHeld = true end
            if k2 and k2 ~= Enum.ButtonCode.BUTTON_CODE_INVALID and k2 ~= Enum.ButtonCode.KEY_NONE and Input.IsKeyDown(k2) then isHeld = true end
        end
        if not isHeld and bind.Get then
            local k = bind:Get()
            if k and k ~= Enum.ButtonCode.BUTTON_CODE_INVALID and k ~= Enum.ButtonCode.KEY_NONE and Input.IsKeyDown(k) then isHeld = true end
        end
    end

    local now = os.clock()

    if isHeld then
        if not runawayActive then
            runawayActive = true
            runawayBaseAngle = math.random(0, 359)
        end

        local illusions = GetAllPLIllusions()
        if #illusions == 0 then return end

        local heroPos = Entity.GetAbsOrigin(myHero)
        local keepCount = UI.RunAway.KeepCount:Get()
        local duration = UI.RunAway.Duration:Get()

        local list = {}
        for _, illusion in ipairs(illusions) do
            table.insert(list, { npc = illusion, id = Entity.GetIndex(illusion), dist = (Entity.GetAbsOrigin(illusion) - heroPos):Length() })
        end
        table.sort(list, function(a, b) return a.dist < b.dist end)

        local keepSet = {}
        for i = 1, math.min(keepCount, #list) do
            local id = list[i].id
            keepSet[id] = true
            runawayRole[id] = true
            runawayKeepRole[id] = true
            runawayUntil[id] = nil

            local minR = (UI.AutoFollow and UI.AutoFollow.MinRadius and UI.AutoFollow.MinRadius:Get()) or 200
            local maxR = (UI.AutoFollow and UI.AutoFollow.MaxRadius and UI.AutoFollow.MaxRadius:Get()) or 400
            local angle = math.rad(math.random(0, 359))
            local dist = math.random(minR, maxR)
            local offset = Vector(math.cos(angle), math.sin(angle), 0) * dist
            local targetPos = heroPos + offset
            if not runawayLastOrder[id] or (now - runawayLastOrder[id] > math.random(7,12)/10) then
                Player.PrepareUnitOrders(
                    Players.GetLocal(),
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil,
                    targetPos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    list[i].npc,
                    false,
                    false,
                    false,
                    false,
                    "pl_illusion_runaway"
                )
                runawayLastOrder[id] = now
            end
        end

        local count = math.max(0, #list - keepCount)
        for idx = keepCount + 1, #list do
            local it = list[idx]
            local illusion = it.npc
            local id = it.id
            runawayRole[id] = true
            runawayKeepRole[id] = nil
            runawayUntil[id] = nil

            local angleDeg = runawayBaseAngle + (idx - keepCount - 1) * (count > 0 and (360 / count) or 0)
            local angle = math.rad(angleDeg)
            local dir = Vector(math.cos(angle), math.sin(angle), 0)
            local speed = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(illusion)) or 350
            local dist = math.max(400, math.floor(speed * duration))
            local targetPos = heroPos + dir * dist
            if not runawayLastOrder[id] or (now - runawayLastOrder[id] > math.random(7,12)/10) then
                Player.PrepareUnitOrders(
                    Players.GetLocal(),
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                    nil,
                    targetPos,
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    illusion,
                    false,
                    false,
                    false,
                    false,
                    "pl_illusion_runaway"
                )
                runawayLastOrder[id] = now
            end

            if priorityRole then priorityRole[id] = nil end
            if splitRole then splitRole[id] = nil end
            if chaseRole then chaseRole[id] = nil end
            if farmRole then farmRole[id] = nil end
            if followRole then followRole[id] = nil end
            if bodyblockRole then bodyblockRole[id] = nil end
            if baitRole then baitRole[id] = nil end
            if wbaitRole then wbaitRole[id] = nil end
        end
        return
    end

    if runawayActive then
        local duration = UI.RunAway.Duration:Get()
        for _, illusion in ipairs(GetAllPLIllusions()) do
            local id = Entity.GetIndex(illusion)
            if runawayRole[id] then
                if runawayKeepRole[id] then
                    runawayRole[id] = nil
                    runawayKeepRole[id] = nil
                    runawayUntil[id] = nil
                else
                    runawayUntil[id] = now + duration
                end
            end
        end
        runawayActive = false
    end

    local heroPos = Entity.GetAbsOrigin(myHero)
    for _, illusion in ipairs(GetAllPLIllusions()) do
        local id = Entity.GetIndex(illusion)
        if runawayUntil[id] then
            if now >= runawayUntil[id] then
                runawayUntil[id] = nil
                runawayRole[id] = nil
            else
                local illuPos = Entity.GetAbsOrigin(illusion)
                local dir = illuPos - heroPos
                if dir:Length() > 0 then dir = dir:Normalized() else dir = Vector(1, 0, 0) end
                local speed = (NPC.GetMoveSpeed and NPC.GetMoveSpeed(illusion)) or 350
                local remain = runawayUntil[id] - now
                local dist = math.max(300, math.floor(speed * math.min(remain, UI.RunAway.Duration:Get())))
                local targetPos = heroPos + dir * dist
                if not runawayLastOrder[id] or (now - runawayLastOrder[id] > math.random(7,12)/10) then
                    Player.PrepareUnitOrders(
                        Players.GetLocal(),
                        Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_POSITION,
                        nil,
                        targetPos,
                        nil,
                        Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                        illusion,
                        false,
                        false,
                        false,
                        false,
                        "pl_illusion_runaway"
                    )
                    runawayLastOrder[id] = now
                end
            end
        end
    end
end

local isInitialized = false

PLTools.OnUpdate = function()

    if not IsPhantomLancer() then return end

    if not isInitialized then
        LoadPanelPosition()
        isInitialized = true
    end

    CleanupPlayerOverride()
    AutoRunAwayIllusionsV2()
    AutoShard()
    AutoBloodthorn()
    AutoOrchid()

    AutoPhantomRushForIllusions()
    AutoBaitIllusions()
    AutoBodyblockForIllusions()
    AutoSplitAttackForIllusions()
    AutoPriorityAttackForIllusions()
    AutoChaseEnemyForIllusions()
    AutoFarmCreepsForIllusions()
    AutoFollowIllusions()
end

PLTools.OnDraw = function()

    if not IsPhantomLancer() then return end

    DrawIllusionStatus()
    DrawModernPanel()
end

PLTools.OnPrepareUnitOrders = function(data)
    if not IsPhantomLancer() then return true end
    if not data then return true end

    local localPlayer = Players.GetLocal and Players.GetLocal() or nil
    local lpId = localPlayer and Player.GetPlayerID(localPlayer) or -1
    local issuerPlayerId = data.player and Player.GetPlayerID(data.player) or -2
    if issuerPlayerId ~= lpId then return true end

    if data.identifier and type(data.identifier) == "string" and data.identifier:find("^pl_") then
        return true
    end

    local function applyOverride(npc)
        if npc and IsPLIllusion(npc) then
            local id = Entity.GetIndex(npc)
            playerOverrideRole[id] = true
            local duration = playerOverrideDuration or 1.5
            if UI and UI.Settings and UI.Settings.PlayerOverrideSec then
                duration = UI.Settings.PlayerOverrideSec:Get()
            end
            playerOverrideUntil[id] = os.clock() + duration

            if priorityRole then priorityRole[id] = nil end
            if splitRole then splitRole[id] = nil end
            if chaseRole then chaseRole[id] = nil end
            if farmRole then farmRole[id] = nil end
            if followRole then followRole[id] = nil end
            if bodyblockRole then bodyblockRole[id] = nil end
            if baitRole then baitRole[id] = nil end
            if wbaitRole then wbaitRole[id] = nil end
        end
    end
    
    if data.orderIssuer == Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_SELECTED_UNITS then
        local selected = Player.GetSelectedUnits and Player.GetSelectedUnits(localPlayer) or {}
        for _, unit in ipairs(selected) do
            applyOverride(unit)
        end
    else
        applyOverride(data.npc)
    end
    return true
end

return PLTools
