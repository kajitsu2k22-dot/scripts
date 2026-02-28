local CONSTANTS = {
    SCREEN_DEFAULT_WIDTH = 1920,
    SCREEN_DEFAULT_HEIGHT = 1080,
    DT_DEFAULT = 0.016,
    DT_MAX = 0.033,
    ANIMATION_DT_MIN = 0.001,
    ANIMATION_DT_MAX = 0.05,
    PARTICLE_CONNECTION_DIST = 150,
    PARTICLE_MAX_CONNECTIONS = 3,
    SHOOTING_STAR_TAIL_LENGTH = 20,
    SHOOTING_STAR_MAX_LIFETIME = 5,
    STAR_RAY_BRIGHTNESS_THRESHOLD = 0.8,
    CLOUD_ROTATION_SPEED_MOD = 0.25,
    WORMHOLE_ROTATION_SPEED_MOD = 0.25,
    SHOOTING_STAR_SPEED_MOD = 0.5,
    AURORA_WAVE_COUNT = 5,
    AURORA_SEGMENT_STEP = 20,
    GALAXY_ARM_POINTS = 100,
    GALAXY_POINT_SPACING = 5,
    FADE_IN_DURATION = 1.5,
    SCREEN_UPDATE_INTERVAL = 2.0,
}

local DEFAULT_PRIMARY_COLOR = Color(100, 200, 255, 200)
local DEFAULT_SECONDARY_COLOR = Color(255, 100, 200, 200)

local script = {}

local time = 0
local fadeInTime = 0
local menuWasOpen = false
local lastRealTime = nil
local lastCursorX = nil
local lastCursorY = nil
local lastCursorModeApplied = nil
local lastCursorInteractionApplied = nil

local screenSize = Vec2(CONSTANTS.SCREEN_DEFAULT_WIDTH, CONSTANTS.SCREEN_DEFAULT_HEIGHT)
local lastScreenUpdateTime = 0

local bgParticlePool = {}
local bgParticleActive = {}
local starPool = {}
local starActive = {}
local cloudPool = {}
local cloudActive = {}
local wormholePool = {}
local wormholeActive = {}
local shootingStarPool = {}

local function normalizeCursorPos(v1, v2)
    if type(v1) == "number" and type(v2) == "number" then
        return Vec2(v1, v2)
    end

    if v1 and type(v1) == "table" then
        local x = v1.x or v1.X
        local y = v1.y or v1.Y
        if type(x) == "number" and type(y) == "number" then
            return Vec2(x, y)
        end
    end

    return nil
end

local function GetScreenSize()
    if Render and Render.GetScreenSize then
        local ok, size = pcall(function() return Render:GetScreenSize() end)
        if ok and size then
            return size
        end
    end
    return Vec2(CONSTANTS.SCREEN_DEFAULT_WIDTH, CONSTANTS.SCREEN_DEFAULT_HEIGHT)
end

local function UpdateScreenSize(currentTime)
    if currentTime - lastScreenUpdateTime > CONSTANTS.SCREEN_UPDATE_INTERVAL then
        screenSize = GetScreenSize()
        lastScreenUpdateTime = currentTime
    end
end

local function clearList(list)
    for i = #list, 1, -1 do
        list[i] = nil
    end
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function getGlobalVarNumber(methodName)
    if not GlobalVars or not GlobalVars[methodName] then
        return nil
    end

    local ok, value = pcall(GlobalVars[methodName], GlobalVars)
    if ok and type(value) == "number" then
        return value
    end

    return nil
end

local function GetAnimationDt()
    local realTime = getGlobalVarNumber("GetRealTime")
    if realTime then
        if lastRealTime then
            local rawDt = realTime - lastRealTime
            lastRealTime = realTime

            if rawDt and rawDt > 0 then
                return clamp(rawDt, CONSTANTS.ANIMATION_DT_MIN, CONSTANTS.ANIMATION_DT_MAX)
            end
        else
            lastRealTime = realTime
        end
    else
        lastRealTime = nil
    end

    local fallbackDt = getGlobalVarNumber("GetAbsFrameTime") or getGlobalVarNumber("GetFrameTime") or CONSTANTS.DT_DEFAULT
    if fallbackDt <= 0 then
        fallbackDt = CONSTANTS.DT_DEFAULT
    end

    return clamp(fallbackDt, CONSTANTS.ANIMATION_DT_MIN, CONSTANTS.ANIMATION_DT_MAX)
end

local function createBgParticle()
    return {
        x = math.random(0, math.floor(screenSize.x)),
        y = math.random(0, math.floor(screenSize.y)),
        size = math.random(1, 4),
        speed = math.random(20, 100) / 100,
        angle = math.random() * math.pi * 2,
        baseBrightness = math.random(35, 90) / 100,
        brightness = math.random(35, 90) / 100,
        twinkleSpeed = math.random(60, 180) / 100,
        twinklePhase = math.random() * math.pi * 2,
        driftPhase = math.random() * math.pi * 2,
        driftSpeed = math.random(40, 140) / 100,
        driftStrength = math.random(20, 120) / 100,
        angularVelocity = (math.random() - 0.5) * 0.8,
        depth = math.random(70, 150) / 100,
        impulseX = 0,
        impulseY = 0,
        colorIdx = math.random(1, 2),
        active = true
    }
end

local function roundToInt(value)
    if type(value) ~= "number" then
        return 0
    end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function GetCursorPos()
    if Input and Input.GetCursorPos then
        local ok, x, y = pcall(Input.GetCursorPos)
        if ok then
            local pos = normalizeCursorPos(x, y)
            if pos then
                return pos
            end
        end

        ok, x, y = pcall(function() return Input:GetCursorPos() end)
        if ok then
            local pos = normalizeCursorPos(x, y)
            if pos then
                return pos
            end
        end
    end

    if not Engine or not Engine.GetCursorPos then
        return nil
    end

    local ok, a, b = pcall(Engine.GetCursorPos)
    if ok then
        local pos = normalizeCursorPos(a, b)
        if pos then
            return pos
        end
    end

    ok, a, b = pcall(Engine.GetCursorPos, Engine)
    if ok then
        local pos = normalizeCursorPos(a, b)
        if pos then
            return pos
        end
    end

    ok, a, b = pcall(function() return Engine:GetCursorPos() end)
    if ok then
        local pos = normalizeCursorPos(a, b)
        if pos then
            return pos
        end
    end

    return nil
end

local function createStar()
    return {
        x = math.random(0, math.floor(screenSize.x)),
        y = math.random(0, math.floor(screenSize.y)),
        size = math.random(1, 3),
        twinkleSpeed = math.random(1, 5),
        twinklePhase = math.random() * math.pi * 2,
        brightness = math.random(50, 100) / 100,
        active = true
    }
end

local function createCloud()
    return {
        x = math.random(-200, math.floor(screenSize.x + 200)),
        y = math.random(-200, math.floor(screenSize.y + 200)),
        size = math.random(200, 500),
        rotation = math.random() * math.pi * 2,
        rotationSpeed = (math.random() - 0.5) * 0.1,
        color = {
            r = math.random(50, 150),
            g = math.random(50, 150),
            b = math.random(100, 200)
        },
        alpha = math.random(10, 30),
        active = true
    }
end

local function createWormhole()
    return {
        x = math.random(200, math.floor(screenSize.x - 200)),
        y = math.random(200, math.floor(screenSize.y - 200)),
        size = math.random(50, 100),
        rotation = 0,
        rotationSpeed = (math.random() - 0.5) * 2,
        pulse = 0,
        active = true
    }
end

local function createShootingStar()
    return {
        startX = math.random(0, math.floor(screenSize.x)),
        startY = math.random(-100, 0),
        endX = math.random(0, math.floor(screenSize.x)),
        endY = math.random(math.floor(screenSize.y), math.floor(screenSize.y + 200)),
        progress = 0,
        speed = math.random(5, 20) / 10,
        size = math.random(2, 4),
        tail = {},
        lifetime = 0,
        active = false
    }
end

local function resetShootingStar(star)
    star.startX = math.random(0, math.floor(screenSize.x))
    star.startY = math.random(-100, 0)
    star.endX = math.random(0, math.floor(screenSize.x))
    star.endY = math.random(math.floor(screenSize.y), math.floor(screenSize.y + 200))
    star.progress = 0
    star.speed = math.random(5, 20) / 10
    star.size = math.random(2, 4)
    star.lifetime = 0
    star.active = true
    star.tail = star.tail or {}
    clearList(star.tail)
end

local function initPool(pool, factory, initialSize)
    for i = 1, initialSize do
        pool[i] = factory()
    end
end

local function getFromPool(pool, factory)
    for i, obj in ipairs(pool) do
        if not obj.active then
            obj.active = true
            return obj
        end
    end
    local newObj = factory()
    newObj.active = true
    pool[#pool + 1] = newObj
    return newObj
end

local function deactivatePoolObjects(list)
    for i, obj in ipairs(list) do
        obj.active = false
    end
end

local function resetParticleImpulses()
    for i, particle in ipairs(bgParticlePool) do
        particle.impulseX = 0
        particle.impulseY = 0
    end
end

local function getActiveCount(list)
    local count = 0
    for i, obj in ipairs(list) do
        if obj.active then
            count = count + 1
        end
    end
    return count
end

local function getFallbackColor(widget, defaultColor)
    if widget and widget.Get then
        local ok, color = pcall(widget.Get, widget)
        if ok and color then
            return color
        end
    end
    return defaultColor
end

local function getPrimaryColor()
    return getFallbackColor(script.shieldColor, DEFAULT_PRIMARY_COLOR)
end

local function getSecondaryColor()
    return getFallbackColor(script.shieldColor2, DEFAULT_SECONDARY_COLOR)
end

local function gradientRectCompat(pos, size, color1, color2, isHorizontal)
    if Render and Render.GradientRect then
        local ok = pcall(Render.GradientRect, pos, size, color1, color2, isHorizontal)
        if ok then
            return true
        end

        ok = pcall(Render.GradientRect, Render, pos, size, color1, color2, isHorizontal)
        if ok then
            return true
        end
    end

    if Render and Render.FilledRect then
        Render.FilledRect(pos, size, color1, 0)
    end
    return false
end

script.OnScriptsLoaded = function()
    initPool(bgParticlePool, createBgParticle, 100)
    initPool(starPool, createStar, 200)
    initPool(cloudPool, createCloud, 5)
    initPool(wormholePool, createWormhole, 2)
    initPool(shootingStarPool, createShootingStar, 10)

    UpdateScreenSize(0)

    local tab = Menu.Create("General", "Main", "CosmicMenu")
    local main = tab:Create("Settings")

    local ok, cosmicMenuTab = pcall(function()
        return tab:Parent()
    end)

    if ok and cosmicMenuTab and cosmicMenuTab.Icon then
        cosmicMenuTab:Icon("\u{f0ac}")
    end

    -- ═══════════════════════════════════════════════════════════════
    --  General
    -- ═══════════════════════════════════════════════════════════════
    local g_general = main:Create("General")

    script.enabled = g_general:Switch("Enable CosmicMenu", true, "\u{f011}")
    script.enabled:ToolTip("Master switch — enables or disables the entire cosmic background")

    script.backgroundEffects = {Get = function() return true end}

    script.backgroundOpacity = g_general:Slider("Background Darkness", 0, 100, 30, "%d")
    script.backgroundOpacity:ToolTip("How dark the overlay behind the menu is (0 = transparent, 100 = fully black)")

    script.fadeInEffect = g_general:Switch("Fade In Effect", true, "\u{f04d}")
    script.fadeInEffect:ToolTip("Smooth fade-in animation when the menu is opened")

    -- ═══════════════════════════════════════════════════════════════
    --  Colors
    -- ═══════════════════════════════════════════════════════════════
    local g_colors = main:Create("Colors")

    script.shieldColor = g_colors:ColorPicker("Primary Color", DEFAULT_PRIMARY_COLOR)
    script.shieldColor:ToolTip("Main accent color used for particles, glow, and color wash")

    script.shieldColor2 = g_colors:ColorPicker("Secondary Color", DEFAULT_SECONDARY_COLOR)
    script.shieldColor2:ToolTip("Second accent color — particles alternate between primary and secondary")

    -- ═══════════════════════════════════════════════════════════════
    --  Particles
    -- ═══════════════════════════════════════════════════════════════
    local g_particles = main:Create("Particles")

    script.bgParticleCount = g_particles:Slider("Particle Count", 20, 500, 100, "%d")
    script.bgParticleCount:ToolTip("Total number of floating particles on screen. Higher values look denser but cost more FPS")

    script.shieldRadius = g_particles:Slider("Particle Size", 1, 8, 2, "%d")
    script.shieldRadius:ToolTip("Base radius of each particle dot (pixels)")

    script.particleBaseAlpha = g_particles:Slider("Particle Opacity", 10, 255, 150, "%d")
    script.particleBaseAlpha:ToolTip("Base opacity of particles (10 = barely visible, 255 = fully opaque)")

    script.particleSoftCore = g_particles:Switch("Soft Core", true, "\u{f111}")
    script.particleSoftCore:ToolTip("Adds a soft halo ring around each particle core for a smoother look")

    -- Glow sub-settings
    script.particleGlow = g_particles:Switch("Particle Glow", true, "\u{f0eb}")
    script.particleGlow:ToolTip("Enable a large colored glow aura behind every particle")

    local glow_gear = script.particleGlow:Gear("Glow Settings")

    script.particleGlowScale = glow_gear:Slider("Glow Size", 1, 8, 3, "%d")
    script.particleGlowScale:ToolTip("Multiplier for the glow radius relative to particle size")

    script.particleGlowAlpha = glow_gear:Slider("Glow Opacity", 0, 100, 30, "%d%%")
    script.particleGlowAlpha:ToolTip("How visible the glow aura is (0%% = invisible, 100%% = very bright)")

    -- ═══════════════════════════════════════════════════════════════
    --  Particle Motion
    -- ═══════════════════════════════════════════════════════════════
    local g_motion = main:Create("Particle Motion")

    script.particleSpeedScale = g_motion:Slider("Particle Speed", 10, 400, 100, "%d%%")
    script.particleSpeedScale:ToolTip("How fast particles move across the screen (100%% = default speed)")

    script.particleDrift = g_motion:Slider("Particle Drift", 0, 200, 35, "%d%%")
    script.particleDrift:ToolTip("How much particles sway and wobble during movement")

    script.particleTwinkleSpeedScale = g_motion:Slider("Twinkle Speed", 0, 300, 100, "%d%%")
    script.particleTwinkleSpeedScale:ToolTip("Speed of the brightness pulsation (twinkle) effect")

    script.particleTwinkleAmount = g_motion:Slider("Twinkle Amount", 0, 100, 30, "%d%%")
    script.particleTwinkleAmount:ToolTip("Intensity of brightness variation — higher = more noticeable twinkle")

    -- ═══════════════════════════════════════════════════════════════
    --  Particle Links
    -- ═══════════════════════════════════════════════════════════════
    local g_links = main:Create("Particle Links")

    script.particleConnections = g_links:Switch("Enable Links", true, "\u{f0c1}")
    script.particleConnections:ToolTip("Draw thin lines between nearby particles creating a constellation web")

    local links_gear = script.particleConnections:Gear("Link Settings")

    script.particleConnectionDist = links_gear:Slider("Link Distance", 40, 400, 150, "%d")
    script.particleConnectionDist:ToolTip("Maximum distance (px) at which two particles are connected by a line")

    script.particleConnectionAlpha = links_gear:Slider("Link Opacity", 0, 150, 50, "%d")
    script.particleConnectionAlpha:ToolTip("Base opacity of connection lines (fades with distance)")

    script.particleConnectionWidth = links_gear:Slider("Link Width", 1, 3, 1, "%d")
    script.particleConnectionWidth:ToolTip("Thickness of connection lines in pixels")

    script.particleMaxConnections = links_gear:Slider("Links per Particle", 0, 8, 3, "%d")
    script.particleMaxConnections:ToolTip("Max number of connections a single particle can have")

    script.particleColoredLinks = links_gear:Switch("Colored Links", true, "\u{f1fc}")
    script.particleColoredLinks:ToolTip("Tint connection lines with the particle colors instead of plain white")

    -- ═══════════════════════════════════════════════════════════════
    --  Cursor Interaction
    -- ═══════════════════════════════════════════════════════════════
    local g_cursor = main:Create("Cursor Interaction")

    script.particleCursorInteraction = g_cursor:Switch("Enable Cursor Interaction", true, "\u{f245}")
    script.particleCursorInteraction:ToolTip("Particles react to your mouse cursor movement")

    local cursor_gear = script.particleCursorInteraction:Gear("Cursor Settings")

    script.particleCursorMode = cursor_gear:Slider("Cursor Mode", 1, 3, 1, function(value)
        local mode = roundToInt(value)
        if mode == 1 then return "Repel" end
        if mode == 2 then return "Swipe" end
        if mode == 3 then return "Vortex" end
        return tostring(mode)
    end)
    script.particleCursorMode:ToolTip("Repel — pushes particles away, Swipe — drags in cursor direction, Vortex — swirls around cursor")

    script.particleCursorRadius = cursor_gear:Slider("Cursor Radius", 40, 600, 180, "%d")
    script.particleCursorRadius:ToolTip("Area of effect around the cursor (pixels)")

    script.particleCursorForce = cursor_gear:Slider("Cursor Force", 100, 12000, 3200, "%d")
    script.particleCursorForce:ToolTip("Strength of the push/pull force applied to particles")

    script.particleCursorFalloff = cursor_gear:Slider("Cursor Falloff", 25, 300, 120, "%d%%")
    script.particleCursorFalloff:ToolTip("How quickly the force weakens with distance from cursor (higher = sharper edge)")

    script.particleCursorMotionBoost = cursor_gear:Slider("Cursor Motion Boost", 0, 300, 120, "%d%%")
    script.particleCursorMotionBoost:ToolTip("Extra force multiplier when the cursor is moving fast")

    script.particleCursorMoveThreshold = cursor_gear:Slider("Cursor Move Threshold", 0, 40, 1, "%d")
    script.particleCursorMoveThreshold:ToolTip("Minimum cursor movement (px/frame) to trigger interaction")

    script.particleCursorOnlyMoving = cursor_gear:Switch("Only While Moving", true, "\u{f04b}")
    script.particleCursorOnlyMoving:ToolTip("Particles only react when the cursor is actively moving")

    script.particleCursorImpulseDamping = cursor_gear:Slider("Cursor Damping", 0, 300, 90, "%d%%")
    script.particleCursorImpulseDamping:ToolTip("How fast the cursor impulse fades — higher = particles slow down quicker")

    script.particleCursorSwirl = cursor_gear:Slider("Cursor Swirl", -100, 100, 60, "%d%%")
    script.particleCursorSwirl:ToolTip("Tangential swirl strength for Vortex mode (negative = reverse direction)")

    -- ═══════════════════════════════════════════════════════════════
    --  Visual Effects
    -- ═══════════════════════════════════════════════════════════════
    local g_effects = main:Create("Visual Effects")

    script.backgroundBlur = g_effects:Switch("Background Blur", false, "\u{f0c9}")
    script.backgroundBlur:ToolTip("Apply a gaussian-like blur to the game behind the menu overlay")

    local blur_gear = script.backgroundBlur:Gear("Blur Settings")

    script.blurIntensity = blur_gear:Slider("Blur Intensity", 0, 20, 5, "%d")
    script.blurIntensity:ToolTip("Blur strength — uses multiple soft passes to avoid blocky artifacts")

    script.colorWash = g_effects:Switch("Color Wash", true, "\u{f043}")
    script.colorWash:ToolTip("Subtle colored gradient overlay using your primary and secondary colors")

    script.cloudCount = {Get = function() return 0 end}

    script.stars = g_effects:Switch("Twinkling Stars", true, "\u{f005}")
    script.stars:ToolTip("Show small twinkling stars in the background")

    local stars_gear = script.stars:Gear("Star Settings")

    script.starCount = stars_gear:Slider("Star Count", 100, 500, 200, "%d")
    script.starCount:ToolTip("Number of background stars (separate from particles)")

    -- ═══════════════════════════════════════════════════════════════
    --  Advanced Effects
    -- ═══════════════════════════════════════════════════════════════
    local g_advanced = main:Create("Advanced Effects")

    script.shootingStars = g_advanced:Switch("Shooting Stars", true, "\u{f135}")
    script.shootingStars:ToolTip("Occasional shooting stars streak across the screen")

    local shooting_gear = script.shootingStars:Gear("Shooting Star Settings")

    script.shootingStarFreq = shooting_gear:Slider("Frequency", 1, 10, 5, "%d")
    script.shootingStarFreq:ToolTip("How often shooting stars appear (1 = rare, 10 = frequent)")

    script.auroraBorealis = {Get = function() return false end}
    script.auroraIntensity = {Get = function() return 0 end}
    script.galaxySpiral = {Get = function() return false end}
    script.spiralArms = {Get = function() return 0 end}
    script.wormholes = {Get = function() return false end}
    script.wormholeCount = {Get = function() return 0 end}
end

script.OnFrame = function()
    if not script.enabled or not script.enabled.Get then return end
    if not script.enabled:Get() then return end

    local dt = GetAnimationDt()


    local menuOpen = IsMenuOpen()
    if menuOpen and not menuWasOpen then
        fadeInTime = 0
        screenSize = GetScreenSize()
        lastScreenUpdateTime = time
    end
    if menuOpen then
        fadeInTime = math.min(fadeInTime + dt, CONSTANTS.FADE_IN_DURATION)
    end
    menuWasOpen = menuOpen

    if not menuOpen then
        lastCursorX = nil
        lastCursorY = nil
        lastCursorModeApplied = nil
        lastCursorInteractionApplied = nil
        resetParticleImpulses()
        return
    end

    time = time + dt
    UpdateScreenSize(time)

    local fadeInAlpha = 1
    if script.fadeInEffect and script.fadeInEffect:Get() and fadeInTime < CONSTANTS.FADE_IN_DURATION then
        fadeInAlpha = fadeInTime / CONSTANTS.FADE_IN_DURATION
    end
    local targetParticleCount = script.bgParticleCount:Get()
    local activeParticles = getActiveCount(bgParticlePool)
    if activeParticles < targetParticleCount then
        for i = 1, targetParticleCount - activeParticles do
            local particle = getFromPool(bgParticlePool, createBgParticle)
            if particle then
                particle.impulseX = 0
                particle.impulseY = 0
            end
        end
    elseif activeParticles > targetParticleCount then
        local toDeactivate = activeParticles - targetParticleCount
        for i = #bgParticlePool, 1, -1 do
            if toDeactivate <= 0 then break end
            if bgParticlePool[i].active then
                bgParticlePool[i].active = false
                toDeactivate = toDeactivate - 1
            end
        end
    end

    local targetStarCount = script.starCount:Get()
    local activeStars = getActiveCount(starPool)
    if activeStars < targetStarCount then
        for i = 1, targetStarCount - activeStars do
            getFromPool(starPool, createStar)
        end
    elseif activeStars > targetStarCount then
        local toDeactivate = activeStars - targetStarCount
        for i = #starPool, 1, -1 do
            if toDeactivate <= 0 then break end
            if starPool[i].active then
                starPool[i].active = false
                toDeactivate = toDeactivate - 1
            end
        end
    end

    local targetCloudCount = script.cloudCount:Get()
    local activeClouds = getActiveCount(cloudPool)
    if activeClouds < targetCloudCount then
        for i = 1, targetCloudCount - activeClouds do
            getFromPool(cloudPool, createCloud)
        end
    elseif activeClouds > targetCloudCount then
        local toDeactivate = activeClouds - targetCloudCount
        for i = #cloudPool, 1, -1 do
            if toDeactivate <= 0 then break end
            if cloudPool[i].active then
                cloudPool[i].active = false
                toDeactivate = toDeactivate - 1
            end
        end
    end

    local targetWormholeCount = script.wormholeCount:Get()
    local activeWormholes = getActiveCount(wormholePool)
    if activeWormholes < targetWormholeCount then
        for i = 1, targetWormholeCount - activeWormholes do
            getFromPool(wormholePool, createWormhole)
        end
    elseif activeWormholes > targetWormholeCount then
        local toDeactivate = activeWormholes - targetWormholeCount
        for i = #wormholePool, 1, -1 do
            if toDeactivate <= 0 then break end
            if wormholePool[i].active then
                wormholePool[i].active = false
                toDeactivate = toDeactivate - 1
            end
        end
    end

    clearList(bgParticleActive)
    clearList(starActive)
    clearList(cloudActive)
    clearList(wormholeActive)

    for i, particle in ipairs(bgParticlePool) do
        if particle.active then
            bgParticleActive[#bgParticleActive + 1] = particle
        end
    end

    for i, star in ipairs(starPool) do
        if star.active then
            starActive[#starActive + 1] = star
        end
    end

    for i, cloud in ipairs(cloudPool) do
        if cloud.active then
            cloudActive[#cloudActive + 1] = cloud
        end
    end

    for i, wormhole in ipairs(wormholePool) do
        if wormhole.active then
            wormholeActive[#wormholeActive + 1] = wormhole
        end
    end

    local w, h = screenSize.x, screenSize.y
    local particleSpeedScale = (script.particleSpeedScale and script.particleSpeedScale:Get() or 100) * 0.01
    local particleDrift = (script.particleDrift and script.particleDrift:Get() or 35) * 0.01
    local particleTwinkleSpeedScale = (script.particleTwinkleSpeedScale and script.particleTwinkleSpeedScale:Get() or 100) * 0.01
    local particleTwinkleAmount = (script.particleTwinkleAmount and script.particleTwinkleAmount:Get() or 30) * 0.01
    local wrapMargin = 50
    local cursorInteractionEnabled = script.particleCursorInteraction and script.particleCursorInteraction:Get()
    local cursorPos = nil
    local frameCursorDeltaX = 0
    local frameCursorDeltaY = 0
    local frameCursorDeltaLen = 0
    local rawCursorMode = script.particleCursorMode and script.particleCursorMode:Get() or 1
    local cursorMode = clamp(roundToInt(rawCursorMode), 1, 3)
    local cursorRadius = script.particleCursorRadius and script.particleCursorRadius:Get() or 180
    local cursorRadiusSq = cursorRadius * cursorRadius
    local cursorForce = script.particleCursorForce and script.particleCursorForce:Get() or 3200
    local cursorFalloffExp = (script.particleCursorFalloff and script.particleCursorFalloff:Get() or 120) * 0.01
    local cursorMotionBoost = (script.particleCursorMotionBoost and script.particleCursorMotionBoost:Get() or 120) * 0.01
    local cursorMoveThreshold = script.particleCursorMoveThreshold and script.particleCursorMoveThreshold:Get() or 1
    local cursorOnlyMoving = script.particleCursorOnlyMoving and script.particleCursorOnlyMoving:Get()
    local cursorImpulseDecay = clamp(1 - ((script.particleCursorImpulseDamping and script.particleCursorImpulseDamping:Get() or 90) * 0.01) * 4 * dt, 0, 1)
    local cursorSwirl = (script.particleCursorSwirl and script.particleCursorSwirl:Get() or 0) * 0.01

    if lastCursorModeApplied ~= cursorMode or lastCursorInteractionApplied ~= cursorInteractionEnabled then
        resetParticleImpulses()
        lastCursorModeApplied = cursorMode
        lastCursorInteractionApplied = cursorInteractionEnabled
    end

    if cursorInteractionEnabled then
        cursorPos = GetCursorPos()
        if cursorPos then
            if lastCursorX ~= nil and lastCursorY ~= nil then
                frameCursorDeltaX = cursorPos.x - lastCursorX
                frameCursorDeltaY = cursorPos.y - lastCursorY
                frameCursorDeltaLen = math.sqrt(frameCursorDeltaX * frameCursorDeltaX + frameCursorDeltaY * frameCursorDeltaY)
            end

            lastCursorX = cursorPos.x
            lastCursorY = cursorPos.y
        else
            lastCursorX = nil
            lastCursorY = nil
        end
    else
        lastCursorX = nil
        lastCursorY = nil
    end

    for i, particle in ipairs(bgParticleActive) do
        particle.angle = particle.angle + (particle.angularVelocity or 0) * particleDrift * dt

        local driftWave = math.sin(time * (particle.driftSpeed or 1) * math.max(0, particleTwinkleSpeedScale) + (particle.driftPhase or i))
        local moveAngle = particle.angle + driftWave * 0.35 * particleDrift * (particle.driftStrength or 1)
        local moveSpeed = particle.speed * 20 * dt * particleSpeedScale * (particle.depth or 1)
        particle.x = particle.x + math.cos(moveAngle) * moveSpeed
        particle.y = particle.y + math.sin(moveAngle) * moveSpeed

        local impulseX = (particle.impulseX or 0) * cursorImpulseDecay
        local impulseY = (particle.impulseY or 0) * cursorImpulseDecay

        if cursorInteractionEnabled and cursorPos then
            local dx = particle.x - cursorPos.x
            local dy = particle.y - cursorPos.y
            local distSq = dx * dx + dy * dy

            if distSq < cursorRadiusSq and cursorRadius > 0 then
                local allowInteraction = (not cursorOnlyMoving) or (frameCursorDeltaLen > cursorMoveThreshold)
                if allowInteraction then
                    local dist = math.sqrt(distSq)
                    if dist < 0.001 then
                        dist = 0.001
                        dx = math.cos((particle.driftPhase or 0) + i)
                        dy = math.sin((particle.driftPhase or 0) + i)
                    end

                    local nx = dx / dist
                    local ny = dy / dist
                    local t = clamp(1 - (dist / cursorRadius), 0, 1)
                    local falloff = t ^ math.max(0.05, cursorFalloffExp)
                    local moveNorm = clamp((frameCursorDeltaLen - cursorMoveThreshold) / 24, 0, 1)
                    local boost = 1 + moveNorm * cursorMotionBoost
                    local radialForce = cursorForce * falloff * boost
                    local forceX = 0
                    local forceY = 0

                    if cursorMode == 1 then
                        -- Repel: pure radial push away from cursor.
                        forceX = nx * radialForce
                        forceY = ny * radialForce
                    elseif cursorMode == 2 then
                        -- Swipe: directional push by cursor movement, almost no radial component.
                        if frameCursorDeltaLen > 0.001 then
                            local svx = frameCursorDeltaX / frameCursorDeltaLen
                            local svy = frameCursorDeltaY / frameCursorDeltaLen
                            local swipeForce = radialForce * (0.85 + cursorMotionBoost * 0.5)
                            forceX = svx * swipeForce
                            forceY = svy * swipeForce
                        else
                            -- No movement in swipe mode -> no force (keeps mode behavior distinct).
                            forceX = 0
                            forceY = 0
                        end
                    elseif cursorMode == 3 then
                        -- Vortex: pure tangential swirl around cursor.
                        local tangentX = -ny
                        local tangentY = nx
                        local swirlStrength = cursorSwirl

                        if swirlStrength == 0 then
                            swirlStrength = 0.6
                        end

                        if frameCursorDeltaLen > 0.001 then
                            local cross = frameCursorDeltaX * ny - frameCursorDeltaY * nx
                            if cross < 0 then
                                tangentX = -tangentX
                                tangentY = -tangentY
                            end
                        elseif swirlStrength < 0 then
                            tangentX = -tangentX
                            tangentY = -tangentY
                        end

                        swirlStrength = math.abs(swirlStrength)
                        local vortexForce = radialForce * (0.6 + swirlStrength)
                        forceX = tangentX * vortexForce
                        forceY = tangentY * vortexForce
                    else
                        -- Safe fallback: behave like Repel.
                        forceX = nx * radialForce
                        forceY = ny * radialForce
                    end

                    impulseX = impulseX + forceX * dt
                    impulseY = impulseY + forceY * dt
                end
            end
        end

        particle.impulseX = impulseX
        particle.impulseY = impulseY
        particle.x = particle.x + impulseX * dt
        particle.y = particle.y + impulseY * dt

        local twinkle = math.sin(time * 2 * (particle.twinkleSpeed or 1) * math.max(0, particleTwinkleSpeedScale) + (particle.twinklePhase or i))
        particle.brightness = clamp((particle.baseBrightness or 0.6) + twinkle * particleTwinkleAmount, 0.05, 1)

        if particle.x < -wrapMargin then particle.x = w + wrapMargin end
        if particle.x > w + wrapMargin then particle.x = -wrapMargin end
        if particle.y < -wrapMargin then particle.y = h + wrapMargin end
        if particle.y > h + wrapMargin then particle.y = -wrapMargin end
    end

    for i, star in ipairs(starActive) do
        star.brightness = 0.5 + math.sin(time * star.twinkleSpeed + star.twinklePhase) * 0.5
    end

    for i, cloud in ipairs(cloudActive) do
        cloud.rotation = cloud.rotation + cloud.rotationSpeed * dt * CONSTANTS.CLOUD_ROTATION_SPEED_MOD
    end

    if script.shootingStars and script.shootingStars:Get() then
        if math.random() < script.shootingStarFreq:Get() * dt * 0.01 then
            local star = getFromPool(shootingStarPool, createShootingStar)
            resetShootingStar(star)
        end

        for i = #shootingStarPool, 1, -1 do
            local star = shootingStarPool[i]
            if star.active then
                star.progress = star.progress + star.speed * dt * CONSTANTS.SHOOTING_STAR_SPEED_MOD
                star.lifetime = star.lifetime + dt

                if star.progress >= 1 or star.lifetime > CONSTANTS.SHOOTING_STAR_MAX_LIFETIME then
                    star.active = false
                else
                    local x = star.startX + (star.endX - star.startX) * star.progress
                    local y = star.startY + (star.endY - star.startY) * star.progress

                    star.tail[#star.tail + 1] = {x = x, y = y}
                    if #star.tail > CONSTANTS.SHOOTING_STAR_TAIL_LENGTH then
                        table.remove(star.tail, 1)
                    end
                end
            end
        end
    end

    for i, wormhole in ipairs(wormholeActive) do
        wormhole.rotation = wormhole.rotation + wormhole.rotationSpeed * dt * CONSTANTS.WORMHOLE_ROTATION_SPEED_MOD
        wormhole.pulse = 0.5 + math.sin(time * 3 + i) * 0.5
    end

    if script.backgroundEffects:Get() then
        DrawBackgroundEffects(fadeInAlpha)
    end
end

function IsMenuOpen()
    if Menu and Menu.Opened then
        return Menu.Opened() == true
    end
    return false
end

function DrawBackgroundEffects(fadeInAlpha)
    if not script.backgroundOpacity then
        return
    end

    fadeInAlpha = fadeInAlpha or 1

    local opacity = script.backgroundOpacity:Get()
    local primaryColor = getPrimaryColor()
    local secondaryColor = getSecondaryColor()

    local fadeOpacity = math.floor(opacity * 2.55 * fadeInAlpha)
    Render.FilledRect(Vec2(0, 0), screenSize, Color(0, 0, 0, fadeOpacity), 0)

    if script.backgroundBlur and script.backgroundBlur:Get() and script.blurIntensity then
        local blurIntensity = script.blurIntensity:Get()
        if blurIntensity > 0 then
            local maxPassStrength = 1.2
            local totalStrength = blurIntensity * 0.15
            local passCount = math.max(1, math.ceil(totalStrength / maxPassStrength))
            local perPass = totalStrength / passCount
            for _blurPass = 1, passCount do
                Render.Blur(Vec2(0, 0), screenSize, perPass)
            end
        end
    end

    if script.colorWash and script.colorWash:Get() then
        local washAlpha = math.floor((12 + opacity * 0.18) * fadeInAlpha)
        local washAlphaSoft = math.floor(washAlpha * 0.6)

        gradientRectCompat(
            Vec2(0, 0),
            screenSize,
            Color(primaryColor.r, primaryColor.g, primaryColor.b, washAlpha),
            Color(secondaryColor.r, secondaryColor.g, secondaryColor.b, washAlpha),
            true
        )

        gradientRectCompat(
            Vec2(0, 0),
            screenSize,
            Color(10, 18, 32, washAlphaSoft),
            Color(0, 0, 0, 0),
            false
        )
    end
    if script.stars and script.stars:Get() then
        for i, star in ipairs(starActive) do
            local alpha = math.floor(star.brightness * 255 * fadeInAlpha)

            Render.FilledCircle(Vec2(star.x, star.y), star.size * 2, Color(255, 255, 255, math.floor(alpha * 0.3)), 16)

            Render.FilledCircle(Vec2(star.x, star.y), star.size, Color(255, 255, 255, alpha), 8)

            if star.brightness > CONSTANTS.STAR_RAY_BRIGHTNESS_THRESHOLD then
                local rayLength = star.size * 4
                for angle = 0, math.pi * 2, math.pi / 2 do
                    local x1 = star.x + math.cos(angle) * star.size
                    local y1 = star.y + math.sin(angle) * star.size
                    local x2 = star.x + math.cos(angle) * rayLength
                    local y2 = star.y + math.sin(angle) * rayLength

                    Render.Line(Vec2(x1, y1), Vec2(x2, y2), Color(255, 255, 255, math.floor(alpha * 0.5)), 1)
                end
            end
        end
    end

    if script.shootingStars and script.shootingStars:Get() then
        for _, star in ipairs(shootingStarPool) do
            if star.active then
                local x = star.startX + (star.endX - star.startX) * star.progress
                local y = star.startY + (star.endY - star.startY) * star.progress

                for i = 1, #star.tail - 1 do
                    local tailAlpha = math.floor((i / #star.tail) * 200 * fadeInAlpha)
                    local size = star.size * (i / #star.tail)
                    Render.FilledCircle(Vec2(star.tail[i].x, star.tail[i].y), size, Color(255, 255, 200, tailAlpha), 8)
                end

                Render.FilledCircle(Vec2(x, y), star.size, Color(255, 255, 255, 255 * fadeInAlpha), 8)
                Render.FilledCircle(Vec2(x, y), star.size * 3, Color(255, 255, 200, math.floor(100 * fadeInAlpha)), 16)
            end
        end
    end

    if script.auroraBorealis and script.auroraBorealis:Get() then
        local intensity = script.auroraIntensity:Get() / 100
        local waveHeight = 200
        local maxX = math.floor(screenSize.x)
        local totalSegments = math.max(1, math.floor(maxX / CONSTANTS.AURORA_SEGMENT_STEP))

        for wave = 1, CONSTANTS.AURORA_WAVE_COUNT do
            local baseColor1 = wave % 2 == 1 and Color(100, 255, 150, 0) or Color(150, 100, 255, 0)
            local baseColor2 = wave % 2 == 1 and Color(50, 200, 255, 0) or Color(100, 50, 200, 0)
            local prevX, prevY
            local segmentIndex = 0

            for x = 0, maxX, CONSTANTS.AURORA_SEGMENT_STEP do
                local y = 100 + math.sin((x / screenSize.x) * math.pi * 2 + time * 2 + wave) * waveHeight
                y = y + math.sin((x / screenSize.x) * math.pi * 4 + time * 3) * waveHeight * 0.5

                if prevX then
                    segmentIndex = segmentIndex + 1
                    local t = segmentIndex / totalSegments
                    local r = baseColor1.r + (baseColor2.r - baseColor1.r) * t
                    local g = baseColor1.g + (baseColor2.g - baseColor1.g) * t
                    local b = baseColor1.b + (baseColor2.b - baseColor1.b) * t
                    local alpha = math.floor(intensity * 50 * (1 - wave / CONSTANTS.AURORA_WAVE_COUNT) * fadeInAlpha)

                    local color = Color(r, g, b, alpha)
                    Render.Line(Vec2(prevX, prevY), Vec2(x, y), color, 3)
                end

                prevX = x
                prevY = y
            end
        end
    end
    if script.galaxySpiral and script.galaxySpiral:Get() then
        local centerX = screenSize.x / 2
        local centerY = screenSize.y / 2
        local arms = script.spiralArms:Get()

        for arm = 1, arms do
            local armOffset = (arm - 1) * (2 * math.pi / arms)
            for i = 0, CONSTANTS.GALAXY_ARM_POINTS do
                local angle = armOffset + (i / 20) + time * 0.5
                local radius = i * CONSTANTS.GALAXY_POINT_SPACING
                local x = centerX + math.cos(angle) * radius
                local y = centerY + math.sin(angle) * radius

                if x > 0 and x < screenSize.x and y > 0 and y < screenSize.y then
                    local brightness = 1 - (i / CONSTANTS.GALAXY_ARM_POINTS)
                    local size = (1 - i / CONSTANTS.GALAXY_ARM_POINTS) * 3 + 1
                    local alpha = math.floor(brightness * 100 * fadeInAlpha)

                    Render.FilledCircle(Vec2(x, y), size, Color(200, 200, 255, alpha), 8)
                end
            end
        end
    end

    if script.wormholes and script.wormholes:Get() then
        for i, wormhole in ipairs(wormholeActive) do
            local x = wormhole.x
            local y = wormhole.y
            local size = wormhole.size

            for j = 1, 3 do
                local ringSize = size * (1 + j * 0.3)
                local alpha = math.floor(100 * wormhole.pulse / j * fadeInAlpha)
                Render.Circle(Vec2(x, y), ringSize, Color(150, 50, 255, alpha), 32, 2)
            end

            for angle = 0, math.pi * 4, 0.1 do
                local r = angle * size / (math.pi * 4)
                local px = x + math.cos(angle + wormhole.rotation) * r
                local py = y + math.sin(angle + wormhole.rotation) * r

                if r < size then
                    local alpha = math.floor(150 * (1 - r / size) * wormhole.pulse * fadeInAlpha)
                    Render.FilledCircle(Vec2(px, py), 2, Color(200, 100, 255, alpha), 8)
                end
            end

            Render.FilledCircle(Vec2(x, y), size * 0.3, Color(0, 0, 0, 255 * fadeInAlpha), 16)
        end
    end

    local c1 = primaryColor
    local c2 = secondaryColor
    local particleSize = script.shieldRadius and script.shieldRadius:Get() or 2
    local particleBaseAlpha = script.particleBaseAlpha and script.particleBaseAlpha:Get() or 150
    local particleGlowScale = script.particleGlowScale and script.particleGlowScale:Get() or 3
    local particleGlowAlphaScale = (script.particleGlowAlpha and script.particleGlowAlpha:Get() or 30) * 0.01
    local particleGlowEnabled = script.particleGlow and script.particleGlow:Get()
    local particleSoftCore = script.particleSoftCore and script.particleSoftCore:Get()
    local particleLinksEnabled = script.particleConnections and script.particleConnections:Get()
    local connectionDist = script.particleConnectionDist and script.particleConnectionDist:Get() or CONSTANTS.PARTICLE_CONNECTION_DIST
    local connectionDistSq = connectionDist * connectionDist
    local maxConnections = script.particleMaxConnections and script.particleMaxConnections:Get() or CONSTANTS.PARTICLE_MAX_CONNECTIONS
    local linkBaseAlpha = script.particleConnectionAlpha and script.particleConnectionAlpha:Get() or 50
    local linkWidth = script.particleConnectionWidth and script.particleConnectionWidth:Get() or 1
    local coloredLinks = script.particleColoredLinks and script.particleColoredLinks:Get()

    for i, particle in ipairs(bgParticleActive) do
        local pColor = particle.colorIdx == 1 and c1 or c2
        local alpha = math.floor(particle.brightness * particleBaseAlpha * fadeInAlpha)
        local radius = particle.size * particleSize * (particle.depth or 1) * 0.85

        if particleGlowEnabled then
            local glowSize = radius * particleGlowScale
            local glowAlpha = math.floor(alpha * particleGlowAlphaScale)
            if glowAlpha > 0 then
                Render.FilledCircle(Vec2(particle.x, particle.y), glowSize, Color(pColor.r, pColor.g, pColor.b, glowAlpha), 16)
            end
        end

        if particleSoftCore then
            Render.FilledCircle(Vec2(particle.x, particle.y), radius * 1.8, Color(pColor.r, pColor.g, pColor.b, math.floor(alpha * 0.25)), 12)
        end

        Render.FilledCircle(Vec2(particle.x, particle.y), radius, Color(pColor.r, pColor.g, pColor.b, alpha), 8)
        Render.FilledCircle(Vec2(particle.x, particle.y), math.max(0.6, radius * 0.45), Color(255, 255, 255, math.floor(alpha * 0.5)), 8)
    end

    if particleLinksEnabled and maxConnections > 0 and connectionDist > 0 then
        for i = 1, #bgParticleActive do
            local p1 = bgParticleActive[i]
            local connections = 0

            for j = i + 1, #bgParticleActive do
                if connections >= maxConnections then break end

                local p2 = bgParticleActive[j]
                local dx = p1.x - p2.x
                local dy = p1.y - p2.y
                local distSq = dx * dx + dy * dy

                if distSq < connectionDistSq then
                    local dist = math.sqrt(distSq)
                    local alpha = math.floor((connectionDist - dist) / connectionDist * linkBaseAlpha * fadeInAlpha)
                    if alpha > 0 then
                        if coloredLinks then
                            local p1Color = p1.colorIdx == 1 and c1 or c2
                            local p2Color = p2.colorIdx == 1 and c1 or c2
                            local lineColor = Color(
                                math.floor((p1Color.r + p2Color.r) * 0.5),
                                math.floor((p1Color.g + p2Color.g) * 0.5),
                                math.floor((p1Color.b + p2Color.b) * 0.5),
                                alpha
                            )
                            Render.Line(Vec2(p1.x, p1.y), Vec2(p2.x, p2.y), lineColor, linkWidth)
                        else
                            Render.Line(Vec2(p1.x, p1.y), Vec2(p2.x, p2.y), Color(255, 255, 255, alpha), linkWidth)
                        end
                    end
                    connections = connections + 1
                end
            end
        end
    end
end

script.OnGameEnd = function()
    deactivatePoolObjects(bgParticlePool)
    deactivatePoolObjects(starPool)
    deactivatePoolObjects(cloudPool)
    deactivatePoolObjects(wormholePool)
    deactivatePoolObjects(shootingStarPool)

    for i, star in ipairs(shootingStarPool) do
        if star.tail then
            clearList(star.tail)
        end
    end

    clearList(bgParticleActive)
    clearList(starActive)
    clearList(cloudActive)
    clearList(wormholeActive)

    time = 0
    fadeInTime = 0
    menuWasOpen = false
    lastRealTime = nil
    lastCursorX = nil
    lastCursorY = nil
    lastCursorModeApplied = nil
    lastCursorInteractionApplied = nil
    resetParticleImpulses()
end

return script
