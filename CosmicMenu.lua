--[[
    CosmicMenu - Космическое меню для UCZone API v2.0
    
    Создает потрясающий космический фон при открытии меню чита с множеством визуальных эффектов.
    
    🌌 Основные возможности:
    • Фоновые частицы с реакцией на курсор
    • Мерцающие звезды и падающие звезды
    • Туманности с вращением
    • Северное сияние
    • Спиральная галактика
    • Червоточины с пульсацией
    • Настраиваемое размытие фона
    • Плавные анимации
    
    ⚙️ Настройки:
    • Main Settings - основные параметры фона
    • Particles - настройка частиц и их размера
    • Cursor - управление притяжением к курсору
    • Effects - включение/выключение визуальных эффектов
    • Colors - настройка цветовой схемы
    
    🎨 Эффекты работают везде: в игре, в главном меню, в лобби
    • Автоматически появляются при открытии меню чита
    • Оптимизированы для плавной работы
    • Настраиваемая интенсивность каждого эффекта
    
    Автор: Euphoria
    Версия: 1.0
]]

local script = {}

local time = 0
local lastTime = 0
local particles = {}
local shieldPulse = 0
local mouseTrail = {}
local constellations = {}
local bgParticles = {}  -- Фоновые частицы
local stars = {}  -- Мерцающие звезды
local nebulaClouds = {}  -- Туманности
local shootingStars = {}  -- Падающие звезды
local wormholes = {}  -- Червоточины

-- Шрифт будет создан позже при необходимости

-- Создание меню
script.OnScriptsLoaded = function()
    -- Пробуем создать меню в General
    local tab = Menu.Create("General", "Main", "CosmicMenu")
    if tab and tab.Icon then tab:Icon("✨") end
    
    -- Создаем группы для настроек
    local mainGroup = tab:Create("Main"):Create("Main Settings")
    local particleGroup = tab:Create("Particles"):Create("Particle Settings")
    local cursorGroup = tab:Create("Cursor"):Create("Cursor Settings")
    local effectsGroup = tab:Create("Effects"):Create("Visual Effects")
    local colorGroup = tab:Create("Colors"):Create("Color Settings")
    
    script.enabled = mainGroup:Switch("Enabled", true)
    
    -- Переменные для совместимости, но не отображаются в меню
    script.shieldEnabled = {Get = function() return false end}
    script.particlesEnabled = {Get = function() return false end}
    script.mouseTrailEnabled = {Get = function() return false end}
    script.constellationsEnabled = {Get = function() return false end}
    
    -- Основные настройки (Background Effects всегда включен)
    script.backgroundEffects = {Get = function() return true end}
    script.backgroundOpacity = mainGroup:Slider("Background Darkness", 0, 100, 30, "%d")
    
    -- Настройки частиц
    script.bgParticleCount = particleGroup:Slider("Particle Count", 50, 200, 100, "%d")
    script.particleGlow = particleGroup:Switch("Particle Glow", true)
    script.shieldRadius = particleGroup:Slider("Particle Size", 1, 5, 2, "%d")
    
    -- Настройки взаимодействия с курсором
    script.cursorAttraction = cursorGroup:Switch("Cursor Attraction", true)
    script.attractionRadius = cursorGroup:Slider("Attraction Radius", 50, 300, 150, "%d")
    script.attractionForce = cursorGroup:Slider("Attraction Force", 0.1, 5.0, 2.0, "%.1f")
    script.smoothness = cursorGroup:Slider("Animation Smoothness", 1, 10, 5, "%d")
    
    -- Визуальные эффекты
    script.backgroundBlur = effectsGroup:Switch("Background Blur", false)
    script.blurIntensity = effectsGroup:Slider("Blur Intensity", 0, 20, 10, "%d")
    script.nebulaClouds = effectsGroup:Switch("Nebula Clouds", true)
    script.cloudCount = effectsGroup:Slider("Cloud Count", 3, 10, 5, "%d")
    script.stars = effectsGroup:Switch("Twinkling Stars", true)
    script.starCount = effectsGroup:Slider("Star Count", 100, 500, 200, "%d")
    
    -- Новые космические эффекты
    script.shootingStars = effectsGroup:Switch("Shooting Stars", true)
    script.shootingStarFreq = effectsGroup:Slider("Shooting Star Frequency", 1, 10, 5, "%d")
    script.auroraBorealis = effectsGroup:Switch("Aurora Borealis", true)
    script.auroraIntensity = effectsGroup:Slider("Aurora Intensity", 0, 100, 50, "%d")
    script.galaxySpiral = effectsGroup:Switch("Galaxy Spiral", false)
    script.spiralArms = effectsGroup:Slider("Spiral Arms", 2, 6, 4, "%d")
    script.wormholes = effectsGroup:Switch("Wormholes", false)
    script.wormholeCount = effectsGroup:Slider("Wormhole Count", 1, 3, 2, "%d")
    
    -- Цветовые настройки
    script.shieldColor = colorGroup:ColorPicker("Primary Color", Color(100, 200, 255, 200))
    script.shieldColor2 = colorGroup:ColorPicker("Secondary Color", Color(255, 100, 200, 200))
end

-- Основная логика и отрисовка
script.OnFrame = function()
    if not script.enabled:Get() then return end

    local dt = 0.016  -- ~60 FPS
    time = time + dt * 0.1  -- Замедляем время в 10 раз
    
    -- Обновляем количество частиц при необходимости
    local targetParticleCount = script.bgParticleCount:Get()
    while #bgParticles < targetParticleCount do
        bgParticles[#bgParticles + 1] = {
            x = math.random(0, 1920),
            y = math.random(0, 1080),
            size = math.random(1, 4),
            speed = math.random(20, 100) / 100,
            angle = math.random() * math.pi * 2,
            brightness = math.random(30, 100) / 100,
            colorIdx = math.random(1, 2)
        }
    end
    while #bgParticles > targetParticleCount do
        table.remove(bgParticles)
    end
    
    -- Обновляем количество звезд при необходимости
    local targetStarCount = script.starCount:Get()
    while #stars < targetStarCount do
        stars[#stars + 1] = {
            x = math.random(0, 1920),
            y = math.random(0, 1080),
            size = math.random(1, 3),
            twinkleSpeed = math.random(1, 5),
            twinklePhase = math.random() * math.pi * 2,
            brightness = math.random(50, 100) / 100
        }
    end
    while #stars > targetStarCount do
        table.remove(stars)
    end
    
    -- Обновляем количество туманностей при необходимости
    local targetCloudCount = script.cloudCount:Get()
    while #nebulaClouds < targetCloudCount do
        nebulaClouds[#nebulaClouds + 1] = {
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
    while #nebulaClouds > targetCloudCount do
        table.remove(nebulaClouds)
    end
    
    -- Обновляем количество червоточин при необходимости
    local targetWormholeCount = script.wormholeCount:Get()
    while #wormholes < targetWormholeCount do
        wormholes[#wormholes + 1] = {
            x = math.random(200, 1720),
            y = math.random(200, 880),
            size = math.random(50, 100),
            rotation = 0,
            rotationSpeed = (math.random() - 0.5) * 2,
            pulse = 0
        }
    end
    while #wormholes > targetWormholeCount do
        table.remove(wormholes)
    end
    
    -- Получаем позицию курсора
    local cursorPos = nil
    local mousePos = Input.GetWorldCursorPos()
    if mousePos then
        -- Конвертируем мировые координаты в экранные
        cursorPos = Render.WorldToScreen(mousePos)
    end
    
    -- Обновление фоновых частиц с реакцией на курсор
    for i, particle in ipairs(bgParticles) do
        -- Реакция на курсор
        if script.cursorAttraction:Get() and cursorPos then
            local dx = cursorPos.x - particle.x
            local dy = cursorPos.y - particle.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist < script.attractionRadius:Get() and dist > 0 then
                local force = script.attractionForce:Get() * (1 - dist / script.attractionRadius:Get())
                local targetAngle = math.atan(dy, dx)
                
                -- Плавный поворот угла
                local angleDiff = targetAngle - particle.angle
                -- Нормализуем разницу углов
                while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
                while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
                
                -- Плавное изменение угла с ограничением
                local smoothFactor = math.min(script.smoothness:Get() * dt, 0.5)
                particle.angle = particle.angle + angleDiff * smoothFactor
                
                -- Плавное изменение скорости
                local targetSpeed = math.min(particle.speed + force * dt * 100, 5.0)
                local speedDiff = targetSpeed - particle.speed
                particle.speed = particle.speed + speedDiff * smoothFactor
                
                -- Плавное изменение яркости
                local targetBrightness = math.min(1.0, 0.5 + force)
                local brightnessDiff = targetBrightness - particle.brightness
                particle.brightness = particle.brightness + brightnessDiff * smoothFactor
            else
                -- Плавное возвращение к нормальной яркости
                local targetBrightness = 0.5 + math.sin(time * 2 + i) * 0.5
                local brightnessDiff = targetBrightness - particle.brightness
                particle.brightness = particle.brightness + brightnessDiff * math.min(dt * 2, 0.5)
            end
        end
        
        -- Обновляем позицию с ограничением скорости
        local moveSpeed = math.min(particle.speed, 5.0)
        particle.x = particle.x + math.cos(particle.angle) * moveSpeed * dt * 10  -- Замедлили в 5 раз
        particle.y = particle.y + math.sin(particle.angle) * moveSpeed * dt * 10
        
        -- Оборачивание по экрану
        if particle.x < -50 then particle.x = 1970 end
        if particle.x > 1970 then particle.x = -50 end
        if particle.y < -50 then particle.y = 1130 end
        if particle.y > 1130 then particle.y = -50 end
        
        -- Плавное затухание скорости
        if not (script.cursorAttraction:Get() and cursorPos) then
            local dx = cursorPos and cursorPos.x - particle.x or 0
            local dy = cursorPos and cursorPos.y - particle.y or 0
            local dist = cursorPos and math.sqrt(dx * dx + dy * dy) or 999
            
            if dist >= script.attractionRadius:Get() then
                local smoothFactor = script.smoothness:Get() * 0.4 * dt
                particle.speed = particle.speed + (0.5 - particle.speed) * smoothFactor
            end
        end
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
    
    -- Отрисовка фоновых эффектов только при открытом меню (работает везде)
    if script.backgroundEffects:Get() and IsMenuOpen() then
        DrawBackgroundEffects()
    end
end

-- Проверка, открыто ли меню чита
function IsMenuOpen()
    local ok, v = pcall(Menu.Opened)
    return ok and v == true
end

-- Отрисовка космического щита
function DrawCosmicShield(screenPos)
    local radius = script.shieldRadius:Get()
    local segments = script.shieldSegments:Get()
    local thickness = script.shieldThickness:Get()
    local color1 = script.shieldColor:Get()
    local color2 = script.shieldColor2:Get()

    -- Основной щит с пульсацией
    for i = 0, segments do
        local angle1 = (math.pi * 2 / segments) * i
        local angle2 = (math.pi * 2 / segments) * (i + 1)

        local pulseRadius = radius
    if script.shieldPulse and script.shieldPulse:Get() then
        pulseRadius = radius + shieldPulse * 20
    end
    
    local x1 = screenPos.x + math.cos(angle1 + time) * pulseRadius
        local y1 = screenPos.y + math.sin(angle1 + time) * pulseRadius
        local x2 = screenPos.x + math.cos(angle2 + time) * pulseRadius
        local y2 = screenPos.y + math.sin(angle2 + time) * pulseRadius

        -- Градиентный цвет
        local t = i / segments
        local r = math.floor(color1.r * (1 - t) + color2.r * t)
        local g = math.floor(color1.g * (1 - t) + color2.g * t)
        local b = math.floor(color1.b * (1 - t) + color2.b * t)
        local a = math.floor(color1.a * (0.5 + shieldPulse * 0.5))

        Render.Line(Vec2(x1, y1), Vec2(x2, y2), Color(r, g, b, a), thickness)

        -- Внутренние кольца
        if i % 2 == 0 then
            local innerRadius = radius * 0.7 + math.sin(time * 3 + i) * 10
            local ix1 = screenPos.x + math.cos(angle1 * 2 - time * 2) * innerRadius
            local iy1 = screenPos.y + math.sin(angle1 * 2 - time * 2) * innerRadius
            local ix2 = screenPos.x + math.cos(angle2 * 2 - time * 2) * innerRadius
            local iy2 = screenPos.y + math.sin(angle2 * 2 - time * 2) * innerRadius

            Render.Line(Vec2(ix1, iy1), Vec2(ix2, iy2), Color(r, g, b, math.floor(a * 0.5)), 1)
        end
    end

    -- Энергетические кольца
    if script.energyRings and script.energyRings:Get() then
        for r = 1, script.ringCount:Get() do
            local ringRadius = radius + r * 15 + math.sin(time * 2 + r) * 5
            local ringAlpha = math.floor(100 * (1 - r / script.ringCount:Get()) * (0.5 + shieldPulse * 0.5))
            
            for i = 0, 360, 30 do
                local angle = math.rad(i)
                local x = screenPos.x + math.cos(angle) * ringRadius
                local y = screenPos.y + math.sin(angle) * ringRadius
                
                local size = 2 + math.sin(time * 4 + i + r) * 1
                -- Используем смешанный цвет из color1 и color2
                local mixedColor = Color(
                    math.floor((color1.r + color2.r) / 2),
                    math.floor((color1.g + color2.g) / 2),
                    math.floor((color1.b + color2.b) / 2),
                    ringAlpha
                )
                Render.FilledCircle(Vec2(x, y), size, mixedColor, 4)
            end
        end
    end
    -- Энергетические спицы с пульсацией
    for i = 0, segments - 1 do
        if i % 2 == 0 then
            local angle = (math.pi * 2 / segments) * i + time * 0.5
            local innerRadius = radius * 0.3
            local outerRadius = radius
            
            if script.shieldPulse and script.shieldPulse:Get() then
                outerRadius = radius + shieldPulse * 30
            end
            
            local x1 = screenPos.x + math.cos(angle) * innerRadius
            local y1 = screenPos.y + math.sin(angle) * innerRadius
            local x2 = screenPos.x + math.cos(angle) * outerRadius
            local y2 = screenPos.y + math.sin(angle) * outerRadius

            Render.Line(Vec2(x1, y1), Vec2(x2, y2), Color(255, 255, 255, 100), 1)
        end
    end
end

-- Отрисовка поля частиц
function DrawParticleField(screenPos)
    local pSize = script.particleSize:Get()
    local c1 = script.shieldColor:Get()
    local c2 = script.shieldColor2:Get()

    for i, particle in ipairs(particles) do
        local pColor = particle.colorIdx == 1 and c1 or c2
        local x = screenPos.x + math.cos(particle.angle) * particle.distance + particle.offsetX
        local y = screenPos.y + math.sin(particle.angle) * particle.distance + particle.offsetY

        -- Свечение частицы
        local glowIntensity = script.glowIntensity and script.glowIntensity:Get() or 50
        if script.particleGlow and script.particleGlow:Get() then
            local glowSize = particle.size * pSize * (2 + glowIntensity / 50)
            local glowAlpha = math.floor(30 * (glowIntensity / 100))
            Render.FilledCircle(Vec2(x, y), glowSize, Color(pColor.r, pColor.g, pColor.b, glowAlpha), 16)
        end

        -- Основная частица
        Render.FilledCircle(Vec2(x, y), particle.size * pSize, pColor, 8)

        -- Соединительные линии между близкими частицами
        for j = i + 1, #particles do
            local other = particles[j]
            local oColor = other.colorIdx == 1 and c1 or c2
            local ox = screenPos.x + math.cos(other.angle) * other.distance + other.offsetX
            local oy = screenPos.y + math.sin(other.angle) * other.distance + other.offsetY

            local dist = math.sqrt((x - ox) ^ 2 + (y - oy) ^ 2)
            if dist < 100 then
                local alpha = math.floor((100 - dist) / 100 * 50)
                Render.Line(Vec2(x, y), Vec2(ox, oy), Color(255, 255, 255, alpha), 1)
            end
        end
    end
end

-- Отрисовка следа мыши
function DrawMouseTrail()
    for i = 1, #mouseTrail - 1 do
        local trail = mouseTrail[i]
        local nextTrail = mouseTrail[i + 1]

        if trail.alpha > 0 and nextTrail.alpha > 0 then
            local pos1 = Render.WorldToScreen(trail.pos)
            local pos2 = Render.WorldToScreen(nextTrail.pos)

            if pos1 and pos2 then
                local width = (i / #mouseTrail) * 3
                local alpha = math.floor(trail.alpha * 0.7)

                Render.Line(pos1, pos2, Color(100, 200, 255, alpha), width)

                -- Свечение в точках
                if i % 3 == 0 then
                    Render.FilledCircle(pos1, width * 2, Color(255, 255, 255, math.floor(trail.alpha * 0.3)), 8)
                end
            end
        end
    end
end

-- Отрисовка созвездий (отключена из-за отсутствия GetScreenSize в API)
function DrawConstellations()
    -- local screenSize = Engine.GetScreenSize()
    -- Метод не существует в данной версии API
end

-- Кастомная полоса здоровья
function DrawCustomHealthBar(screenPos, hero)
    local health = Entity.GetHealth(hero)
    local maxHealth = Entity.GetMaxHealth(hero)
    if maxHealth <= 0 then return end
    local healthPercent = health / maxHealth

    local barWidth = 100
    local barHeight = 8
    local x = screenPos.x - barWidth / 2
    local y = screenPos.y - 60

    -- Фон
    Render.FilledRect(Vec2(x - 2, y - 2), Vec2(x + barWidth + 2, y + barHeight + 2), Color(20, 20, 30, 180), 3)

    -- Градиентная полоса здоровья
    local rC = math.min(255, math.floor(255 * (1 - healthPercent) + 100))
    local gC = math.min(255, math.floor(255 * healthPercent))
    local healthColor = Color(rC, gC, 50, 220)

    local fillWidth = barWidth * healthPercent
    if fillWidth > 0 then
        Render.FilledRect(Vec2(x, y), Vec2(x + fillWidth, y + barHeight), healthColor, 2)
    end

    -- Текст здоровья (отключен из-за проблем с шрифтами)
    -- local healthText = string.format("%d / %d", health, maxHealth)
    -- local font = Render.CreateFont("Default", 14, Enum.FontWeight.NORMAL)
    -- local textSize = Render.GetTextSize(font, healthText)

    -- Тень
    -- Render.TextShadow(font, Vec2(screenPos.x - textSize.x / 2, y - 18), healthText,
    --     Color(255, 255, 255, 255), Color(0, 0, 0, 150))
    -- Основной текст
    -- Render.Text(font, Vec2(screenPos.x - textSize.x / 2, y - 18), healthText,
    --     Color(255, 255, 255, 255))
end

-- Отрисовка имени героя с эффектом (отключена из-за проблем с шрифтами)
function DrawHeroName(screenPos, hero)
    -- local heroName = hero:GetUnitName()
    -- if not heroName then return end
    -- local name = heroName:gsub("npc_dota_hero_", ""):gsub("_", " ")
    -- name = name:gsub("(%a)([%w_']*)", function(first, rest) return first:upper() .. rest:lower() end)

    -- local font = Render.CreateFont("Default", 14, Enum.FontWeight.NORMAL)
    -- local textSize = Render.GetTextSize(font, name)
    -- local tx = screenPos.x - textSize.x / 2
    -- local ty = screenPos.y + 40

    -- -- Эффект свечения
    -- for i = 1, 3 do
    --     local glowAlpha = math.floor(50 / i)
    --     Render.Text(font, Vec2(tx + i, ty + i), name,
    --         Color(100, 200, 255, glowAlpha))
    -- end

    -- -- Тень
    -- Render.TextShadow(font, Vec2(tx, ty), name,
    --     Color(255, 255, 255, 255), Color(0, 0, 0, 200))
    -- -- Основной текст
    -- Render.Text(font, Vec2(tx, ty), name,
    --     Color(255, 255, 255, 255))
end

-- Отрисовка фоновых эффектов
function DrawBackgroundEffects()
    -- Проверяем существование необходимых переменных
    if not script.backgroundOpacity or not script.shieldColor or not script.shieldColor2 then
        return
    end
    
    local opacity = script.backgroundOpacity:Get()
    
    -- Затемнение фона с размытием
    local screenSize = Vec2(1920, 1080)  -- Стандартное разрешение
    Render.FilledRect(Vec2(0, 0), screenSize, Color(0, 0, 0, math.floor(opacity * 2.55)), 0)
    
    -- Эффект размытия (если включен)
    if script.backgroundBlur and script.backgroundBlur:Get() and script.blurIntensity then
        local blurIntensity = script.blurIntensity:Get()
        
        -- Создаем слои размытия с уменьшающейся интенсивностью
        for i = 1, math.min(blurIntensity, 15) do
            local alpha = math.floor(40 / (i * 0.8))
            local offset = i * 1.5
            
            -- Основное размытие - крестовый паттерн
            Render.FilledRect(Vec2(-offset, 0), Vec2(1920 + offset, 1080), Color(0, 0, 0, alpha), 0)
            Render.FilledRect(Vec2(0, -offset), Vec2(1920, 1080 + offset), Color(0, 0, 0, alpha), 0)
            
            -- Диагональное размытие с меньшей интенсивностью
            if i <= 8 then
                local diagAlpha = math.floor(alpha * 0.3)
                Render.FilledRect(Vec2(-offset * 0.7, -offset * 0.7), Vec2(1920 + offset * 0.7, 1080 + offset * 0.7), Color(0, 0, 0, diagAlpha), 0)
                Render.FilledRect(Vec2(offset * 0.7, -offset * 0.7), Vec2(1920 - offset * 0.7, 1080 + offset * 0.7), Color(0, 0, 0, diagAlpha), 0)
            end
        end
        
        -- Добавляем мягкий виньет для красоты
        local vignetteAlpha = math.floor(blurIntensity * 2)
        for i = 1, 5 do
            local size = 200 + i * 100
            local alpha = math.floor(vignetteAlpha / (i + 1))
            Render.FilledRect(Vec2(-size, -size), Vec2(1920 + size, 1080 + size), Color(0, 0, 0, alpha), 0)
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
    local c1 = script.shieldColor:Get()
    local c2 = script.shieldColor2:Get()
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
