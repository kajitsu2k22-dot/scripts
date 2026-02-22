local DEFAULT_PRIMARY_COLOR = Color(100, 200, 255, 200)
local DEFAULT_SECONDARY_COLOR = Color(255, 100, 200, 200)

local script = {}

local time = 0
local bgParticles = {}  -- Фоновые частицы
local stars = {}  -- Мерцающие звезды
local nebulaClouds = {}  -- Туманности
local shootingStars = {}  -- Падающие звезды
local wormholes = {}  -- Червоточины

local function ensureCount(list, targetCount, factory)
    while #list < targetCount do
        list[#list + 1] = factory()
    end
    while #list > targetCount do
        list[#list] = nil
    end
end

local function getFallbackColor(widget, defaultColor)
    if widget and widget.Get then
        return widget:Get()
    end
    return defaultColor
end

local function getPrimaryColor()
    return getFallbackColor(script.shieldColor, DEFAULT_PRIMARY_COLOR)
end

local function getSecondaryColor()
    return getFallbackColor(script.shieldColor2, DEFAULT_SECONDARY_COLOR)
end

local function createBgParticle()
    return {
        x = math.random(0, 1920),
        y = math.random(0, 1080),
        size = math.random(1, 4),
        speed = math.random(20, 100) / 100,
        angle = math.random() * math.pi * 2,
        brightness = math.random(30, 100) / 100,
        colorIdx = math.random(1, 2)
    }
end

local function createStar()
    return {
        x = math.random(0, 1920),
        y = math.random(0, 1080),
        size = math.random(1, 3),
        twinkleSpeed = math.random(1, 5),
        twinklePhase = math.random() * math.pi * 2,
        brightness = math.random(50, 100) / 100
    }
end

local function createCloud()
    return {
        x = math.random(-200, 1920),
        y = math.random(-200, 1080),
        size = math.random(200, 500),
        rotation = math.random() * math.pi * 2,
        rotationSpeed = (math.random() - 0.5) * 0.1,
        color = {
            r = math.random(50, 150),
            g = math.random(50, 150),
            b = math.random(100, 200)
        },
        alpha = math.random(10, 30)
    }
end

local function createWormhole()
    return {
        x = math.random(200, 1720),
        y = math.random(200, 880),
        size = math.random(50, 100),
        rotation = 0,
        rotationSpeed = (math.random() - 0.5) * 2,
        pulse = 0
    }
end

-- Шрифт будет создан позже при необходимости

-- Создание меню
script.OnScriptsLoaded = function()
    -- Создаём группы
    local mainGroup = Menu.Create("General", "Main", "CosmicMenu", "Settings", "Main")
    local particleGroup = Menu.Create("General", "Main", "CosmicMenu", "Settings", "Particles")
    local effectsGroup = Menu.Create("General", "Main", "CosmicMenu", "Settings", "Effects")
    local advancedEffects = Menu.Create("General", "Main", "CosmicMenu", "Settings", "Advanced")
    local colorGroup = Menu.Create("General", "Main", "CosmicMenu", "Settings", "Colors")

    -- Получаем доступ к CSecondTab "CosmicMenu" через Parent для добавления иконки
    -- mainGroup это CMenuGroup, его Parent это CThirdTab "Settings"
    -- Parent CThirdTab это CSecondTab "CosmicMenu"
    local ok, cosmicMenuTab = pcall(function()
        local settingsTab = mainGroup:Parent()  -- CThirdTab "Settings"
        return settingsTab:Parent()  -- CSecondTab "CosmicMenu"
    end)
    
    -- Добавляем иконку на вкладку CosmicMenu
    if ok and cosmicMenuTab and cosmicMenuTab.Icon then
        cosmicMenuTab:Icon("\u{f0ac}")  -- globe
    end

    -- Main settings
    script.enabled = mainGroup:Switch("Enabled", true)
    script.enabled:Icon("\u{f011}")  -- power-off
    script.backgroundEffects = {Get = function() return true end}
    script.backgroundOpacity = mainGroup:Slider("Background Darkness", 0, 100, 30, "%d")
    script.backgroundOpacity:Icon("\u{f042}")  -- adjust

    -- Particles
    script.bgParticleCount = particleGroup:Slider("Particle Count", 50, 200, 100, "%d")
    script.bgParticleCount:Icon("\u{f0e8}")  -- sitemap
    script.particleGlow = particleGroup:Switch("Particle Glow", true)
    script.particleGlow:Icon("\u{f0eb}")  -- lightbulb
    script.shieldRadius = particleGroup:Slider("Particle Size", 1, 5, 2, "%d")
    script.shieldRadius:Icon("\u{f0b2}")  -- expand

    -- Effects
    script.backgroundBlur = effectsGroup:Switch("Background Blur", false)
    script.backgroundBlur:Icon("\u{f0c9}")  -- bars
    script.blurIntensity = effectsGroup:Slider("Blur Intensity", 0, 20, 10, "%d")
    script.blurIntensity:Icon("\u{f010}")  -- eye-slash
    script.nebulaClouds = effectsGroup:Switch("Nebula Clouds", true)
    script.nebulaClouds:Icon("\u{f0c2}")  -- cloud
    script.cloudCount = effectsGroup:Slider("Cloud Count", 3, 10, 5, "%d")
    script.cloudCount:Icon("\u{f0ae}")  -- clone
    script.stars = effectsGroup:Switch("Twinkling Stars", true)
    script.stars:Icon("\u{f005}")  -- star
    script.starCount = effectsGroup:Slider("Star Count", 100, 500, 200, "%d")
    script.starCount:Icon("\u{f0d0}")  -- certificate

    -- Advanced Effects
    script.shootingStars = advancedEffects:Switch("Shooting Stars", true)
    script.shootingStars:Icon("\u{f135}")  -- rocket
    script.shootingStarFreq = advancedEffects:Slider("Shooting Star Frequency", 1, 10, 5, "%d")
    script.shootingStarFreq:Icon("\u{f017}")  -- clock-o
    script.auroraBorealis = advancedEffects:Switch("Aurora Borealis", true)
    script.auroraBorealis:Icon("\u{f0d0}")  -- certificate
    script.auroraIntensity = advancedEffects:Slider("Aurora Intensity", 0, 100, 50, "%d")
    script.auroraIntensity:Icon("\u{f06d}")  -- fire
    script.galaxySpiral = advancedEffects:Switch("Galaxy Spiral", false)
    script.galaxySpiral:Icon("\u{f0e2}")  -- refresh
    script.spiralArms = advancedEffects:Slider("Spiral Arms", 2, 6, 4, "%d")
    script.spiralArms:Icon("\u{f0ce}")  -- table
    script.wormholes = advancedEffects:Switch("Wormholes", false)
    script.wormholes:Icon("\u{f0ac}")  -- globe
    script.wormholeCount = advancedEffects:Slider("Wormhole Count", 1, 3, 2, "%d")
    script.wormholeCount:Icon("\u{f0ae}")  -- clone

    -- Colors
    script.shieldColor = colorGroup:ColorPicker("Primary Color", DEFAULT_PRIMARY_COLOR)
    script.shieldColor2 = colorGroup:ColorPicker("Secondary Color", DEFAULT_SECONDARY_COLOR)
end

-- Основная логика и отрисовка
script.OnFrame = function()
    if not script.enabled or not script.enabled.Get then return end
    if not script.enabled:Get() then return end

    -- Получаем dt с fallback
    local dt = 0.016
    if GlobalVars and GlobalVars.GetFrameTime then
        local ok, ft = pcall(GlobalVars.GetFrameTime)
        if ok and ft and ft > 0 then
            dt = math.min(ft, 0.033)  -- Максимум ~30 FPS для стабильности
        end
    end
    time = time + dt

    -- Обновляем количество частиц при необходимости
    ensureCount(bgParticles, script.bgParticleCount:Get(), createBgParticle)

    -- Обновляем количество звезд при необходимости
    ensureCount(stars, script.starCount:Get(), createStar)

    -- Обновляем количество туманностей при необходимости
    ensureCount(nebulaClouds, script.cloudCount:Get(), createCloud)

    -- Обновляем количество червоточин при необходимости
    ensureCount(wormholes, script.wormholeCount:Get(), createWormhole)

    -- Обновление фоновых частиц
    for i, particle in ipairs(bgParticles) do
        -- Движение частицы
        particle.x = particle.x + math.cos(particle.angle) * particle.speed * 20 * dt
        particle.y = particle.y + math.sin(particle.angle) * particle.speed * 20 * dt
        particle.brightness = 0.5 + math.sin(time * 2 + i) * 0.3
        
        -- Оборачивание по экрану
        if particle.x < -50 then particle.x = 1970 end
        if particle.x > 1970 then particle.x = -50 end
        if particle.y < -50 then particle.y = 1130 end
        if particle.y > 1130 then particle.y = -50 end
    end
    
    -- Обновление звезд
    for i, star in ipairs(stars) do
        star.brightness = 0.5 + math.sin(time * star.twinkleSpeed + star.twinklePhase) * 0.5
    end
    
    -- Обновление туманностей
    for i, cloud in ipairs(nebulaClouds) do
        cloud.rotation = cloud.rotation + cloud.rotationSpeed * dt * 0.5  -- Замедлили в 2 раза
    end
    
    -- Обновление падающих звезд
    if script.shootingStars:Get() then
        -- Создаем новые падающие звезды
        if math.random() < script.shootingStarFreq:Get() * dt * 0.01 then  -- Уменьшили частоту
            shootingStars[#shootingStars + 1] = {
                startX = math.random(0, 1920),
                startY = math.random(-100, 0),
                endX = math.random(0, 1920),
                endY = math.random(1080, 1280),
                progress = 0,
                speed = math.random(5, 20) / 10,
                size = math.random(2, 4),
                tail = {}
            }
        end
        
        -- Обновляем существующие падающие звезды
        for i = #shootingStars, 1, -1 do
            local star = shootingStars[i]
            star.progress = star.progress + star.speed * dt * 0.5  -- Замедлили в 2 раза
            
            if star.progress >= 1 then
                table.remove(shootingStars, i)
            else
                local x = star.startX + (star.endX - star.startX) * star.progress
                local y = star.startY + (star.endY - star.startY) * star.progress
                
                -- Добавляем точку в хвост
                star.tail[#star.tail + 1] = {x = x, y = y}
                if #star.tail > 20 then
                    table.remove(star.tail, 1)
                end
            end
        end
    end
    
    -- Обновление червоточин
    for i, wormhole in ipairs(wormholes) do
        wormhole.rotation = wormhole.rotation + wormhole.rotationSpeed * dt * 0.5  -- Замедлили в 2 раза
        wormhole.pulse = 0.5 + math.sin(time * 3 + i) * 0.5
    end
    
    -- Отрисовка фоновых эффектов только при открытом меню
    if script.backgroundEffects:Get() and IsMenuOpen() then
        DrawBackgroundEffects()
    end
end

-- Проверка, открыто ли меню чита
function IsMenuOpen()
    if Menu and Menu.Opened then
        local ok, v = pcall(Menu.Opened)
        return ok and v == true
    end
    return false
end

-- Отрисовка фоновых эффектов
function DrawBackgroundEffects()
    -- Проверяем существование необходимых переменных
    if not script.backgroundOpacity then
        return
    end
    
    local opacity = script.backgroundOpacity:Get()
    local primaryColor = getPrimaryColor()
    local secondaryColor = getSecondaryColor()
    
    -- Затемнение фона
    local screenSize = Vec2(1920, 1080)  -- Стандартное разрешение
    Render.FilledRect(Vec2(0, 0), screenSize, Color(0, 0, 0, math.floor(opacity * 2.55)), 0)
    
    -- Эффект размытия (если включен) - используем настоящий Render.Blur
    if script.backgroundBlur and script.backgroundBlur:Get() and script.blurIntensity then
        local blurIntensity = script.blurIntensity:Get()
        
        -- Render.Blur(pos, size, strength) - плавная шкала размытия
        -- Используем квадратный корень для более плавного нарастания
        -- 0 -> 0, 1 -> 1, 5 -> 2.2, 10 -> 3.2, 20 -> 4.5
        local strength = math.sqrt(blurIntensity) * 1.5
        if strength > 0 then
            Render.Blur(Vec2(0, 0), screenSize, strength)
        end
    end
    
    -- Отрисовка туманностей
    if script.nebulaClouds and script.nebulaClouds:Get() and nebulaClouds then
        for i, cloud in ipairs(nebulaClouds) do
            -- Рисуем туманность как несколько перекрывающихся кругов
            for j = 1, 5 do
                local offsetX = math.cos(cloud.rotation + j) * cloud.size * 0.3
                local offsetY = math.sin(cloud.rotation + j) * cloud.size * 0.3
                local size = cloud.size * (0.5 + j * 0.1)
                
                Render.FilledCircle(
                    Vec2(cloud.x + offsetX, cloud.y + offsetY),
                    size,
                    Color(cloud.color.r, cloud.color.g, cloud.color.b, math.floor(cloud.alpha * 0.3)),
                    32
                )
            end
        end
    end
    
    -- Отрисовка мерцающих звезд
    if script.stars and script.stars:Get() and stars then
        for i, star in ipairs(stars) do
            local alpha = math.floor(star.brightness * 255)
            
            -- Свечение звезды
            Render.FilledCircle(Vec2(star.x, star.y), star.size * 2, Color(255, 255, 255, math.floor(alpha * 0.3)), 16)
            
            -- Основная звезда
            Render.FilledCircle(Vec2(star.x, star.y), star.size, Color(255, 255, 255, alpha), 8)
            
            -- Лучи звезды
            if star.brightness > 0.8 then
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
        for _, star in ipairs(shootingStars) do
            local x = star.startX + (star.endX - star.startX) * star.progress
            local y = star.startY + (star.endY - star.startY) * star.progress
            
            -- Рисуем хвост
            for i = 1, #star.tail - 1 do
                local alpha = math.floor((i / #star.tail) * 200)
                local size = star.size * (i / #star.tail)
                Render.FilledCircle(Vec2(star.tail[i].x, star.tail[i].y), size, Color(255, 255, 200, alpha), 8)
            end
            
            -- Рисуем саму звезду
            Render.FilledCircle(Vec2(x, y), star.size, Color(255, 255, 255, 255), 8)
            -- Свечение
            Render.FilledCircle(Vec2(x, y), star.size * 3, Color(255, 255, 200, 100), 16)
        end
    end
    
    -- Отрисовка северного сияния
    if script.auroraBorealis and script.auroraBorealis:Get() then
        local intensity = script.auroraIntensity:Get() / 100
        local waveHeight = 200
        local waveCount = 5
        
        for wave = 1, waveCount do
            local points = {}
            for x = 0, 1920, 20 do
                local y = 100 + math.sin((x / 1920) * math.pi * 2 + time * 2 + wave) * waveHeight
                y = y + math.sin((x / 1920) * math.pi * 4 + time * 3) * waveHeight * 0.5
                points[#points + 1] = Vec2(x, y)
            end
            
            -- Рисуем волну
            for i = 1, #points - 1 do
                local alpha = math.floor(intensity * 50 * (1 - wave / waveCount))
                local color = wave % 2 == 1 and Color(100, 255, 150, alpha) or Color(150, 100, 255, alpha)
                Render.Line(points[i], points[i + 1], color, 3)
            end
        end
    end
    
    -- Отрисовка спиральной галактики
    if script.galaxySpiral and script.galaxySpiral:Get() then
        local centerX = 960
        local centerY = 540
        local arms = script.spiralArms:Get()
        
        for arm = 1, arms do
            local armOffset = (arm - 1) * (2 * math.pi / arms)
            for i = 0, 100 do
                local angle = armOffset + (i / 20) + time * 0.5
                local radius = i * 5
                local x = centerX + math.cos(angle) * radius
                local y = centerY + math.sin(angle) * radius
                
                if x > 0 and x < 1920 and y > 0 and y < 1080 then
                    local brightness = 1 - (i / 100)
                    local size = (1 - i / 100) * 3 + 1
                    local alpha = math.floor(brightness * 100)
                    
                    Render.FilledCircle(Vec2(x, y), size, Color(200, 200, 255, alpha), 8)
                end
            end
        end
    end
    
    -- Отрисовка червоточин
    if script.wormholes and script.wormholes:Get() and wormholes then
        for i, wormhole in ipairs(wormholes) do
            local x = wormhole.x
            local y = wormhole.y
            local size = wormhole.size
            
            -- Внешний кольцо
            for j = 1, 3 do
                local ringSize = size * (1 + j * 0.3)
                local alpha = math.floor(100 * wormhole.pulse / j)
                Render.Circle(Vec2(x, y), ringSize, Color(150, 50, 255, alpha), 32, 2)
            end
            
            -- Внутренняя спираль
            for angle = 0, math.pi * 4, 0.1 do
                local r = angle * size / (math.pi * 4)
                local px = x + math.cos(angle + wormhole.rotation) * r
                local py = y + math.sin(angle + wormhole.rotation) * r
                
                if r < size then
                    local alpha = math.floor(150 * (1 - r / size) * wormhole.pulse)
                    Render.FilledCircle(Vec2(px, py), 2, Color(200, 100, 255, alpha), 8)
                end
            end
            
            -- Центральная черная дыра
            Render.FilledCircle(Vec2(x, y), size * 0.3, Color(0, 0, 0, 255), 16)
        end
    end
    
    -- Отрисовка фоновых частиц
    local c1 = primaryColor
    local c2 = secondaryColor
    local particleSize = script.shieldRadius and script.shieldRadius:Get() or 2
    
    if bgParticles then
        for i, particle in ipairs(bgParticles) do
            local pColor = particle.colorIdx == 1 and c1 or c2
            local alpha = math.floor(particle.brightness * 150)
            
            -- Свечение
            if script.particleGlow and script.particleGlow:Get() then
                local glowSize = particle.size * particleSize * 3
                Render.FilledCircle(Vec2(particle.x, particle.y), glowSize, Color(pColor.r, pColor.g, pColor.b, math.floor(alpha * 0.3)), 16)
            end
            
            -- Основная частица
            Render.FilledCircle(Vec2(particle.x, particle.y), particle.size * particleSize, Color(pColor.r, pColor.g, pColor.b, alpha), 8)
        end
        
        -- Соединительные линии между близкими частицами
        for i = 1, #bgParticles do
            for j = i + 1, #bgParticles do
                local p1 = bgParticles[i]
                local p2 = bgParticles[j]
                local dist = math.sqrt((p1.x - p2.x) ^ 2 + (p1.y - p2.y) ^ 2)
                
                if dist < 150 then
                    local alpha = math.floor((150 - dist) / 150 * 50)
                    Render.Line(Vec2(p1.x, p1.y), Vec2(p2.x, p2.y), Color(255, 255, 255, alpha), 1)
                end
            end
        end
    end
end

-- Очистка при конце игры
script.OnGameEnd = function()
    particles = {}
    mouseTrail = {}
    bgParticles = {}
    stars = {}
    nebulaClouds = {}
    shootingStars = {}
    wormholes = {}
    constellations = {}
    time = 0
    lastTime = 0
end

return script
