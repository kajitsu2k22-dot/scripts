local CONSTANTS = {
    SCREEN_DEFAULT_WIDTH = 1920,
    SCREEN_DEFAULT_HEIGHT = 1080,
    DT_DEFAULT = 0.016,
    DT_MAX = 0.033,
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
    SCREEN_UPDATE_INTERVAL = 2.0, -- Обновлять размер экрана каждые 2 секунды
}

local DEFAULT_PRIMARY_COLOR = Color(100, 200, 255, 200)
local DEFAULT_SECONDARY_COLOR = Color(255, 100, 200, 200)

local script = {}

local time = 0
local fadeInTime = 0
local menuWasOpen = false

local screenSize = Vec2(CONSTANTS.SCREEN_DEFAULT_WIDTH, CONSTANTS.SCREEN_DEFAULT_HEIGHT)
local lastScreenUpdateTime = 0

-- Пулы объектов для повторного использования
local bgParticlePool = {}
local bgParticleActive = {}
local starPool = {}
local starActive = {}
local cloudPool = {}
local cloudActive = {}
local wormholePool = {}
local wormholeActive = {}
local shootingStarPool = {}
local shootingStarActive = {}

-- Функция получения размера экрана
local function GetScreenSize()
    if Render and Render.GetScreenSize then
        local ok, size = pcall(function() return Render:GetScreenSize() end)
        if ok and size then
            return size
        end
    end
    return Vec2(CONSTANTS.SCREEN_DEFAULT_WIDTH, CONSTANTS.SCREEN_DEFAULT_HEIGHT)
end

-- Обновление размера экрана (только периодически)
local function UpdateScreenSize(currentTime)
    if currentTime - lastScreenUpdateTime > CONSTANTS.SCREEN_UPDATE_INTERVAL then
        screenSize = GetScreenSize()
        lastScreenUpdateTime = currentTime
    end
end

-- Фабрики частиц
local function createBgParticle()
    return {
        x = math.random(0, math.floor(screenSize.x)),
        y = math.random(0, math.floor(screenSize.y)),
        size = math.random(1, 4),
        speed = math.random(20, 100) / 100,
        angle = math.random() * math.pi * 2,
        brightness = math.random(30, 100) / 100,
        colorIdx = math.random(1, 2),
        active = true
    }
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

-- Управление пулами объектов
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

local function deactivateAll(list)
    for i, obj in ipairs(list) do
        obj.active = false
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

-- Оптимизированное получение цвета с fallback
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

-- Создание меню
script.OnScriptsLoaded = function()
    -- Инициализация пулов
    initPool(bgParticlePool, createBgParticle, 100)
    initPool(starPool, createStar, 200)
    initPool(cloudPool, createCloud, 5)
    initPool(wormholePool, createWormhole, 2)
    initPool(shootingStarPool, createShootingStar, 10)

    -- Обновление размера экрана при инициализации
    UpdateScreenSize(0)

    -- Создаём группы
    local mainGroup = Menu.Create("General", "Main", "CosmicMenu", "Settings", "Main")
    local particleGroup = Menu.Create("General", "Main", "CosmicMenu", "Settings", "Particles")
    local effectsGroup = Menu.Create("General", "Main", "CosmicMenu", "Settings", "Effects")
    local advancedEffects = Menu.Create("General", "Main", "CosmicMenu", "Settings", "Advanced")
    local colorGroup = Menu.Create("General", "Main", "CosmicMenu", "Settings", "Colors")

    -- Получаем доступ к CSecondTab "CosmicMenu" через Parent для добавления иконки
    local ok, cosmicMenuTab = pcall(function()
        local settingsTab = mainGroup:Parent()
        return settingsTab:Parent()
    end)

    -- Добавляем иконку на вкладку CosmicMenu
    if ok and cosmicMenuTab and cosmicMenuTab.Icon then
        cosmicMenuTab:Icon("\u{f0ac}")
    end

    -- Main settings
    script.enabled = mainGroup:Switch("Enabled", true)
    script.enabled:Icon("\u{f011}")
    script.backgroundEffects = {Get = function() return true end}
    script.backgroundOpacity = mainGroup:Slider("Background Darkness", 0, 100, 30, "%d")
    script.backgroundOpacity:Icon("\u{f042}")

    -- Particles
    script.bgParticleCount = particleGroup:Slider("Particle Count", 50, 200, 100, "%d")
    script.bgParticleCount:Icon("\u{f0e8}")
    script.particleGlow = particleGroup:Switch("Particle Glow", true)
    script.particleGlow:Icon("\u{f0eb}")
    script.shieldRadius = particleGroup:Slider("Particle Size", 1, 5, 2, "%d")
    script.shieldRadius:Icon("\u{f0b2}")

    -- Effects
    script.backgroundBlur = effectsGroup:Switch("Background Blur", false)
    script.backgroundBlur:Icon("\u{f0c9}")
    script.blurIntensity = effectsGroup:Slider("Blur Intensity", 0, 20, 10, "%d")
    script.blurIntensity:Icon("\u{f010}")
    script.nebulaClouds = effectsGroup:Switch("Nebula Clouds", true)
    script.nebulaClouds:Icon("\u{f0c2}")
    script.cloudCount = effectsGroup:Slider("Cloud Count", 3, 10, 5, "%d")
    script.cloudCount:Icon("\u{f0ae}")
    script.stars = effectsGroup:Switch("Twinkling Stars", true)
    script.stars:Icon("\u{f005}")
    script.starCount = effectsGroup:Slider("Star Count", 100, 500, 200, "%d")
    script.starCount:Icon("\u{f0d0}")

    -- Advanced Effects
    script.shootingStars = advancedEffects:Switch("Shooting Stars", true)
    script.shootingStars:Icon("\u{f135}")
    script.shootingStarFreq = advancedEffects:Slider("Shooting Star Frequency", 1, 10, 5, "%d")
    script.shootingStarFreq:Icon("\u{f017}")
    script.auroraBorealis = advancedEffects:Switch("Aurora Borealis", true)
    script.auroraBorealis:Icon("\u{f0d0}")
    script.auroraIntensity = advancedEffects:Slider("Aurora Intensity", 0, 100, 50, "%d")
    script.auroraIntensity:Icon("\u{f06d}")
    script.galaxySpiral = advancedEffects:Switch("Galaxy Spiral", false)
    script.galaxySpiral:Icon("\u{f0e2}")
    script.spiralArms = advancedEffects:Slider("Spiral Arms", 2, 6, 4, "%d")
    script.spiralArms:Icon("\u{f0ce}")
    script.wormholes = advancedEffects:Switch("Wormholes", false)
    script.wormholes:Icon("\u{f0ac}")
    script.wormholeCount = advancedEffects:Slider("Wormhole Count", 1, 3, 2, "%d")
    script.wormholeCount:Icon("\u{f0ae}")

    -- Colors
    script.shieldColor = colorGroup:ColorPicker("Primary Color", DEFAULT_PRIMARY_COLOR)
    script.shieldColor2 = colorGroup:ColorPicker("Secondary Color", DEFAULT_SECONDARY_COLOR)

    -- Visual improvements
    script.fadeInEffect = mainGroup:Switch("Fade In Effect", true)
    script.fadeInEffect:Icon("\u{f04d}")
end

-- Основная логика и отрисовка
script.OnFrame = function()
    if not script.enabled or not script.enabled.Get then return end
    if not script.enabled:Get() then return end

    -- Получаем dt с fallback
    local dt = CONSTANTS.DT_DEFAULT
    if GlobalVars and GlobalVars.GetFrameTime then
        local ft = GlobalVars:GetFrameTime()
        if ft and ft > 0 then
            dt = math.min(ft, CONSTANTS.DT_MAX)
        end
    end
    time = time + dt

    -- Обновление размера экрана (периодически)
    UpdateScreenSize(time)

    -- Обновление времени fade-in
    local menuOpen = IsMenuOpen()
    if menuOpen and not menuWasOpen then
        fadeInTime = 0
    end
    if menuOpen then
        fadeInTime = math.min(fadeInTime + dt, CONSTANTS.FADE_IN_DURATION)
    end
    menuWasOpen = menuOpen

    -- Вычисление alpha для fade-in
    local fadeInAlpha = 1
    if script.fadeInEffect and script.fadeInEffect:Get() and fadeInTime < CONSTANTS.FADE_IN_DURATION then
        fadeInAlpha = fadeInTime / CONSTANTS.FADE_IN_DURATION
    end
    -- Обновление количества фоновых частиц через пул
    local targetParticleCount = script.bgParticleCount:Get()
    local activeParticles = getActiveCount(bgParticlePool)
    if activeParticles < targetParticleCount then
        for i = 1, targetParticleCount - activeParticles do
            getFromPool(bgParticlePool, createBgParticle)
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

    -- Обновление количества звезд через пул
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

    -- Обновление количества туманностей через пул
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

    -- Обновление количества червоточин через пул
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

    -- Сбор активных частиц в отдельные таблицы для обновления
    deactivateAll(bgParticleActive)
    deactivateAll(starActive)
    deactivateAll(cloudActive)
    deactivateAll(wormholeActive)
    deactivateAll(shootingStarActive)

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

    -- Обновление фоновых частиц
    local w, h = screenSize.x, screenSize.y
    for i, particle in ipairs(bgParticleActive) do
        particle.x = particle.x + math.cos(particle.angle) * particle.speed * 20 * dt
        particle.y = particle.y + math.sin(particle.angle) * particle.speed * 20 * dt
        particle.brightness = 0.5 + math.sin(time * 2 + i) * 0.3

        -- Оборачивание по экрану
        if particle.x < -50 then particle.x = w + 50 end
        if particle.x > w + 50 then particle.x = -50 end
        if particle.y < -50 then particle.y = h + 50 end
        if particle.y > h + 50 then particle.y = -50 end
    end

    -- Обновление звезд
    for i, star in ipairs(starActive) do
        star.brightness = 0.5 + math.sin(time * star.twinkleSpeed + star.twinklePhase) * 0.5
    end

    -- Обновление туманностей
    for i, cloud in ipairs(cloudActive) do
        cloud.rotation = cloud.rotation + cloud.rotationSpeed * dt * CONSTANTS.CLOUD_ROTATION_SPEED_MOD
    end

    -- Обновление падающих звезд
    if script.shootingStars and script.shootingStars:Get() then
        -- Создаем новые падающие звезды
        if math.random() < script.shootingStarFreq:Get() * dt * 0.01 then
            local star = getFromPool(shootingStarPool, createShootingStar)
            star.progress = 0
            star.lifetime = 0
            star.tail = {}
        end

        -- Обновляем существующие падающие звезды
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

                    -- Добавляем точку в хвост с ограничением длины
                    star.tail[#star.tail + 1] = {x = x, y = y}
                    if #star.tail > CONSTANTS.SHOOTING_STAR_TAIL_LENGTH then
                        table.remove(star.tail, 1)
                    end
                end
            end
        end
    end

    -- Обновление червоточин
    for i, wormhole in ipairs(wormholeActive) do
        wormhole.rotation = wormhole.rotation + wormhole.rotationSpeed * dt * CONSTANTS.WORMHOLE_ROTATION_SPEED_MOD
        wormhole.pulse = 0.5 + math.sin(time * 3 + i) * 0.5
    end

    -- Отрисовка фоновых эффектов только при открытом меню
    if script.backgroundEffects:Get() and menuOpen then
        DrawBackgroundEffects(fadeInAlpha)
    end
end

-- Проверка, открыто ли меню чита
function IsMenuOpen()
    if Menu and Menu.Opened then
        return Menu.Opened() == true
    end
    return false
end

-- Отрисовка фоновых эффектов
function DrawBackgroundEffects(fadeInAlpha)
    if not script.backgroundOpacity then
        return
    end

    fadeInAlpha = fadeInAlpha or 1

    local opacity = script.backgroundOpacity:Get()
    local primaryColor = getPrimaryColor()
    local secondaryColor = getSecondaryColor()

    -- Затемнение фона с учетом fade-in
    local fadeOpacity = math.floor(opacity * 2.55 * fadeInAlpha)
    Render.FilledRect(Vec2(0, 0), screenSize, Color(0, 0, 0, fadeOpacity), 0)

    -- Эффект размытия
    if script.backgroundBlur and script.backgroundBlur:Get() and script.blurIntensity then
        local blurIntensity = script.blurIntensity:Get()
        local strength = math.sqrt(blurIntensity) * 1.5
        if strength > 0 then
            Render.Blur(Vec2(0, 0), screenSize, strength)
        end
    end

    -- Отрисовка туманностей
    if script.nebulaClouds and script.nebulaClouds:Get() then
        for i, cloud in ipairs(cloudActive) do
            for j = 1, 5 do
                local offsetX = math.cos(cloud.rotation + j) * cloud.size * 0.3
                local offsetY = math.sin(cloud.rotation + j) * cloud.size * 0.3
                local size = cloud.size * (0.5 + j * 0.1)
                local alpha = math.floor(cloud.alpha * 0.3 * fadeInAlpha)

                Render.FilledCircle(
                    Vec2(cloud.x + offsetX, cloud.y + offsetY),
                    size,
                    Color(cloud.color.r, cloud.color.g, cloud.color.b, alpha),
                    32
                )
            end
        end
    end

    -- Отрисовка мерцающих звезд
    if script.stars and script.stars:Get() then
        for i, star in ipairs(starActive) do
            local alpha = math.floor(star.brightness * 255 * fadeInAlpha)

            -- Свечение звезды
            Render.FilledCircle(Vec2(star.x, star.y), star.size * 2, Color(255, 255, 255, math.floor(alpha * 0.3)), 16)

            -- Основная звезда
            Render.FilledCircle(Vec2(star.x, star.y), star.size, Color(255, 255, 255, alpha), 8)

            -- Лучи звезды
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

    -- Отрисовка падающих звезд
    if script.shootingStars and script.shootingStars:Get() then
        for _, star in ipairs(shootingStarPool) do
            if star.active then
                local x = star.startX + (star.endX - star.startX) * star.progress
                local y = star.startY + (star.endY - star.startY) * star.progress

                -- Рисуем хвост
                for i = 1, #star.tail - 1 do
                    local tailAlpha = math.floor((i / #star.tail) * 200 * fadeInAlpha)
                    local size = star.size * (i / #star.tail)
                    Render.FilledCircle(Vec2(star.tail[i].x, star.tail[i].y), size, Color(255, 255, 200, tailAlpha), 8)
                end

                -- Рисуем саму звезду
                Render.FilledCircle(Vec2(x, y), star.size, Color(255, 255, 255, 255 * fadeInAlpha), 8)
                Render.FilledCircle(Vec2(x, y), star.size * 3, Color(255, 255, 200, math.floor(100 * fadeInAlpha)), 16)
            end
        end
    end

    -- Отрисовка северного сияния с градиентами
    if script.auroraBorealis and script.auroraBorealis:Get() then
        local intensity = script.auroraIntensity:Get() / 100
        local waveHeight = 200

        for wave = 1, CONSTANTS.AURORA_WAVE_COUNT do
            local points = {}
            for x = 0, math.floor(screenSize.x), CONSTANTS.AURORA_SEGMENT_STEP do
                local y = 100 + math.sin((x / screenSize.x) * math.pi * 2 + time * 2 + wave) * waveHeight
                y = y + math.sin((x / screenSize.x) * math.pi * 4 + time * 3) * waveHeight * 0.5
                points[#points + 1] = Vec2(x, y)
            end

            -- Градиентные цвета для волны
            local baseColor1 = wave % 2 == 1 and Color(100, 255, 150, 0) or Color(150, 100, 255, 0)
            local baseColor2 = wave % 2 == 1 and Color(50, 200, 255, 0) or Color(100, 50, 200, 0)

            -- Рисуем сегменты с градиентом
            for i = 1, #points - 1 do
                local t = i / #points
                local r = baseColor1.r + (baseColor2.r - baseColor1.r) * t
                local g = baseColor1.g + (baseColor2.g - baseColor1.g) * t
                local b = baseColor1.b + (baseColor2.b - baseColor1.b) * t
                local alpha = math.floor(intensity * 50 * (1 - wave / CONSTANTS.AURORA_WAVE_COUNT) * fadeInAlpha)

                local color = Color(r, g, b, alpha)
                Render.Line(points[i], points[i + 1], color, 3)
            end
        end
    end

    -- Отрисовка спиральной галактики
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

    -- Отрисовка червоточин
    if script.wormholes and script.wormholes:Get() then
        for i, wormhole in ipairs(wormholeActive) do
            local x = wormhole.x
            local y = wormhole.y
            local size = wormhole.size

            -- Внешние кольца
            for j = 1, 3 do
                local ringSize = size * (1 + j * 0.3)
                local alpha = math.floor(100 * wormhole.pulse / j * fadeInAlpha)
                Render.Circle(Vec2(x, y), ringSize, Color(150, 50, 255, alpha), 32, 2)
            end

            -- Внутренняя спираль
            for angle = 0, math.pi * 4, 0.1 do
                local r = angle * size / (math.pi * 4)
                local px = x + math.cos(angle + wormhole.rotation) * r
                local py = y + math.sin(angle + wormhole.rotation) * r

                if r < size then
                    local alpha = math.floor(150 * (1 - r / size) * wormhole.pulse * fadeInAlpha)
                    Render.FilledCircle(Vec2(px, py), 2, Color(200, 100, 255, alpha), 8)
                end
            end

            -- Центральная черная дыра
            Render.FilledCircle(Vec2(x, y), size * 0.3, Color(0, 0, 0, 255 * fadeInAlpha), 16)
        end
    end

    -- Отрисовка фоновых частиц с оптимизированными соединениями
    local c1 = primaryColor
    local c2 = secondaryColor
    local particleSize = script.shieldRadius and script.shieldRadius:Get() or 2

    -- Собираем активные частицы для отрисовки
    local activeForRender = {}
    for i, particle in ipairs(bgParticleActive) do
        activeForRender[#activeForRender + 1] = particle
    end

    -- Отрисовка частиц
    for i, particle in ipairs(activeForRender) do
        local pColor = particle.colorIdx == 1 and c1 or c2
        local alpha = math.floor(particle.brightness * 150 * fadeInAlpha)

        -- Свечение
        if script.particleGlow and script.particleGlow:Get() then
            local glowSize = particle.size * particleSize * 3
            Render.FilledCircle(Vec2(particle.x, particle.y), glowSize, Color(pColor.r, pColor.g, pColor.b, math.floor(alpha * 0.3)), 16)
        end

        -- Основная частица
        Render.FilledCircle(Vec2(particle.x, particle.y), particle.size * particleSize, Color(pColor.r, pColor.g, pColor.b, alpha), 8)
    end

    -- Оптимизированная отрисовка соединений (только с ближайшими соседями, без сортировки)
    local connectionDist = CONSTANTS.PARTICLE_CONNECTION_DIST
    local connectionDistSq = connectionDist * connectionDist
    local maxConnections = CONSTANTS.PARTICLE_MAX_CONNECTIONS

    for i = 1, #activeForRender do
        local p1 = activeForRender[i]
        local connections = 0

        for j = i + 1, #activeForRender do
            if connections >= maxConnections then break end

            local p2 = activeForRender[j]
            local dx = p1.x - p2.x
            local dy = p1.y - p2.y
            local distSq = dx * dx + dy * dy

            if distSq < connectionDistSq then
                local dist = math.sqrt(distSq)
                local alpha = math.floor((connectionDist - dist) / connectionDist * 50 * fadeInAlpha)
                Render.Line(Vec2(p1.x, p1.y), Vec2(p2.x, p2.y), Color(255, 255, 255, alpha), 1)
                connections = connections + 1
            end
        end
    end
end

-- Очистка при конце игры
script.OnGameEnd = function()
    -- Деактивируем все частицы в пулах
    deactivateAll(bgParticlePool)
    deactivateAll(starPool)
    deactivateAll(cloudPool)
    deactivateAll(wormholePool)
    deactivateAll(shootingStarPool)

    -- Очищаем вспомогательные таблицы
    deactivateAll(bgParticleActive)
    deactivateAll(starActive)
    deactivateAll(cloudActive)
    deactivateAll(wormholeActive)
    deactivateAll(shootingStarActive)

    time = 0
    fadeInTime = 0
end

return script
