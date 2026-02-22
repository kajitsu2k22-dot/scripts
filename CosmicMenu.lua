local L_STRINGS = {
    en = {
        tabs = {
            main = "Main",
            particles = "Particles",
            cursor = "Cursor",
            effects = "Effects",
            colors = "Colors",
            advanced = "Advanced Effects"
        },
        main_enabled = "Enabled",
        main_enabled_tip = "Enable or disable cosmic background effects",
        main_darkness = "Background Darkness",
        main_darkness_tip = "Adjusts dark overlay intensity",
        particles_count = "Particle Count",
        particles_count_tip = "Background particle amount",
        particles_glow = "Particle Glow",
        particles_glow_tip = "Adds bloom around particles",
        particles_size = "Particle Size",
        particles_size_tip = "Size of base particles",
        cursor_attraction = "Cursor Attraction",
        cursor_attraction_tip = "Particles react to cursor position",
        cursor_radius = "Attraction Radius",
        cursor_radius_tip = "Area around cursor affecting particles",
        cursor_force = "Attraction Force",
        cursor_force_tip = "Strength of particle pull",
        cursor_smoothness = "Animation Smoothness",
        cursor_smoothness_tip = "Interpolation factor for particle movement",
        blur_switch = "Background Blur",
        blur_switch_tip = "Applies layered blur to menu background",
        blur_intensity = "Blur Intensity",
        blur_intensity_tip = "Controls blur strength",
        nebula_switch = "Nebula Clouds",
        nebula_switch_tip = "Enable rotating nebula layers",
        nebula_count = "Cloud Count",
        nebula_count_tip = "Number of nebula clusters",
        stars_switch = "Twinkling Stars",
        stars_switch_tip = "Enable animated star field",
        stars_count = "Star Count",
        stars_count_tip = "Number of background stars",
        shooting_switch = "Shooting Stars",
        shooting_tip = "Enable shooting stars with tails",
        shooting_freq = "Shooting Star Frequency",
        shooting_freq_tip = "Spawn rate of shooting stars",
        aurora_switch = "Aurora Borealis",
        aurora_switch_tip = "Draws aurora waves at top",
        aurora_intensity = "Aurora Intensity",
        aurora_intensity_tip = "Brightness of aurora",
        galaxy_switch = "Galaxy Spiral",
        galaxy_switch_tip = "Paint spiral galaxy center",
        galaxy_arms = "Spiral Arms",
        galaxy_arms_tip = "Number of galaxy arms",
        wormholes_switch = "Wormholes",
        wormholes_switch_tip = "Spinning wormhole portals",
        wormholes_count = "Wormhole Count",
        wormholes_count_tip = "How many wormholes to draw",
        primary_color = "Primary Color",
        secondary_color = "Secondary Color"
    },
    cn = {
        tabs = {
            main = "主设置",
            particles = "粒子",
            cursor = "鼠标",
            effects = "效果",
            colors = "颜色",
            advanced = "高级效果"
        },
        main_enabled = "启用",
        main_enabled_tip = "开启或关闭宇宙背景",
        main_darkness = "背景暗度",
        main_darkness_tip = "控制暗色遮罩强度",
        particles_count = "粒子数量",
        particles_count_tip = "背景粒子数量",
        particles_glow = "粒子光晕",
        particles_glow_tip = "为粒子添加柔和光晕",
        particles_size = "粒子大小",
        particles_size_tip = "基础粒子尺寸",
        cursor_attraction = "鼠标吸附",
        cursor_attraction_tip = "粒子跟随鼠标",
        cursor_radius = "吸附半径",
        cursor_radius_tip = "鼠标影响范围",
        cursor_force = "吸附强度",
        cursor_force_tip = "粒子被吸引的力度",
        cursor_smoothness = "动画平滑",
        cursor_smoothness_tip = "粒子运动的平滑程度",
        blur_switch = "背景模糊",
        blur_switch_tip = "为背景添加模糊层",
        blur_intensity = "模糊强度",
        blur_intensity_tip = "模糊的强弱",
        nebula_switch = "星云",
        nebula_switch_tip = "启用旋转星云",
        nebula_count = "星云数量",
        nebula_count_tip = "绘制的星云数量",
        stars_switch = "闪烁星星",
        stars_switch_tip = "启用闪烁星空",
        stars_count = "星星数量",
        stars_count_tip = "背景星星数量",
        shooting_switch = "流星",
        shooting_tip = "启用带尾巴的流星",
        shooting_freq = "流星频率",
        shooting_freq_tip = "流星出现频率",
        aurora_switch = "极光",
        aurora_switch_tip = "绘制天空极光",
        aurora_intensity = "极光亮度",
        aurora_intensity_tip = "极光强度",
        galaxy_switch = "螺旋星系",
        galaxy_switch_tip = "绘制中心星系",
        galaxy_arms = "星系臂",
        galaxy_arms_tip = "星系臂数量",
        wormholes_switch = "虫洞",
        wormholes_switch_tip = "显示旋转虫洞",
        wormholes_count = "虫洞数量",
        wormholes_count_tip = "绘制的虫洞数量",
        primary_color = "主色",
        secondary_color = "次色"
    }
}

local LANG = "en"
local _langWidget = nil
local _langLastCheck = 0
local LANG_UPDATE_INTERVAL = 2.0

local DEFAULT_PRIMARY_COLOR = Color(100, 200, 255, 200)
local DEFAULT_SECONDARY_COLOR = Color(255, 100, 200, 200)

local function currentStrings()
    return L_STRINGS[LANG] or L_STRINGS.en
end

local function TabsLabel(key)
    local dict = currentStrings()
    local tabs = dict.tabs or L_STRINGS.en.tabs
    return (tabs and tabs[key]) or L_STRINGS.en.tabs[key] or key
end

local function L(key)
    local dict = currentStrings()
    return dict[key] or L_STRINGS.en[key] or key
end

local function UpdateLanguage(force)
    local now = (GlobalVars and GlobalVars.GetRealTime and GlobalVars.GetRealTime()) or os.clock()
    if not force and now - _langLastCheck < LANG_UPDATE_INTERVAL then return end
    _langLastCheck = now

    if not _langWidget then
        local ok, widget = pcall(Menu.Find, "SettingsHidden", "", "", "", "Main", "Language")
        if ok and widget then _langWidget = widget end
    end

    if _langWidget and _langWidget.Get then
        local ok, value = pcall(function()
            return _langWidget:Get()
        end)
        if ok and value ~= nil then
            if value == 2 or value == "cn" then
                LANG = "cn"
            else
                LANG = "en"
            end
        end
    end
end

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

local function createSwitch(group, label, defaultValue, tooltip)
    local widget = group:Switch(label, defaultValue)
    if tooltip then widget:ToolTip(tooltip) end
    return widget
end

local function createSliderInt(group, label, minValue, maxValue, defaultValue, fmt, tooltip)
    local widget = group:Slider(label, minValue, maxValue, defaultValue, fmt)
    if tooltip then widget:ToolTip(tooltip) end
    return widget
end

local function createSliderFloat(group, label, minValue, maxValue, defaultValue, fmt, tooltip)
    local widget = group:Slider(label, minValue, maxValue, defaultValue, fmt)
    if tooltip then widget:ToolTip(tooltip) end
    return widget
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

local function getCursorScreenPos()
    if Input and Input.GetCursorPos then
        local x, y = Input.GetCursorPos()
        if x and y then
            return Vec2(x, y)
        end
    end
    if Engine and Engine.GetCursorPos then
        local pos = Engine.GetCursorPos()
        if pos then return pos end
    end
    if Input and Input.GetWorldCursorPos then
        local world = Input.GetWorldCursorPos()
        if world then
            local screen = Render.WorldToScreen(world)
            if screen and screen.x and screen.y then
                return Vec2(screen.x, screen.y)
            end
        end
    end
    return nil
end

-- Шрифт будет создан позже при необходимости

-- Создание меню
script.OnScriptsLoaded = function()
    UpdateLanguage(true)

    local tab = Menu.Create("General", "Main", "CosmicMenu")
    if tab and tab.Icon then tab:Icon("✨") end

    local mainTab = tab:Create(TabsLabel("main"))
    local particleTab = tab:Create(TabsLabel("particles"))
    local cursorTab = tab:Create(TabsLabel("cursor"))
    local effectsTab = tab:Create(TabsLabel("effects"))
    local colorTab = tab:Create(TabsLabel("colors"))

    local mainGroup = mainTab:Create(TabsLabel("main"))
    local particleGroup = particleTab:Create(TabsLabel("particles"))
    local cursorGroup = cursorTab:Create(TabsLabel("cursor"))
    local effectsGroup = effectsTab:Create(TabsLabel("effects"))
    local advancedEffects = effectsTab:Create(TabsLabel("advanced"))
    local colorGroup = colorTab:Create(TabsLabel("colors"))

    script.enabled = createSwitch(mainGroup, L("main_enabled"), true, L("main_enabled_tip"))
    script.backgroundEffects = {Get = function() return true end}
    script.backgroundOpacity = createSliderInt(mainGroup, L("main_darkness"), 0, 100, 30, "%d", L("main_darkness_tip"))

    script.bgParticleCount = createSliderInt(particleGroup, L("particles_count"), 50, 200, 100, "%d", L("particles_count_tip"))
    script.particleGlow = createSwitch(particleGroup, L("particles_glow"), true, L("particles_glow_tip"))
    script.shieldRadius = createSliderInt(particleGroup, L("particles_size"), 1, 5, 2, "%d", L("particles_size_tip"))

    script.cursorAttraction = createSwitch(cursorGroup, L("cursor_attraction"), true, L("cursor_attraction_tip"))
    script.attractionRadius = createSliderInt(cursorGroup, L("cursor_radius"), 50, 300, 150, "%d", L("cursor_radius_tip"))
    script.attractionForce = createSliderFloat(cursorGroup, L("cursor_force"), 0.1, 5.0, 2.0, "%.1f", L("cursor_force_tip"))
    script.smoothness = createSliderInt(cursorGroup, L("cursor_smoothness"), 1, 10, 5, "%d", L("cursor_smoothness_tip"))

    script.backgroundBlur = createSwitch(effectsGroup, L("blur_switch"), false, L("blur_switch_tip"))
    script.blurIntensity = createSliderInt(effectsGroup, L("blur_intensity"), 0, 20, 10, "%d", L("blur_intensity_tip"))
    script.nebulaClouds = createSwitch(effectsGroup, L("nebula_switch"), true, L("nebula_switch_tip"))
    script.cloudCount = createSliderInt(effectsGroup, L("nebula_count"), 3, 10, 5, "%d", L("nebula_count_tip"))
    script.stars = createSwitch(effectsGroup, L("stars_switch"), true, L("stars_switch_tip"))
    script.starCount = createSliderInt(effectsGroup, L("stars_count"), 100, 500, 200, "%d", L("stars_count_tip"))

    script.shootingStars = createSwitch(advancedEffects, L("shooting_switch"), true, L("shooting_tip"))
    script.shootingStarFreq = createSliderInt(advancedEffects, L("shooting_freq"), 1, 10, 5, "%d", L("shooting_freq_tip"))
    script.auroraBorealis = createSwitch(advancedEffects, L("aurora_switch"), true, L("aurora_switch_tip"))
    script.auroraIntensity = createSliderInt(advancedEffects, L("aurora_intensity"), 0, 100, 50, "%d", L("aurora_intensity_tip"))
    script.galaxySpiral = createSwitch(advancedEffects, L("galaxy_switch"), false, L("galaxy_switch_tip"))
    script.spiralArms = createSliderInt(advancedEffects, L("galaxy_arms"), 2, 6, 4, "%d", L("galaxy_arms_tip"))
    script.wormholes = createSwitch(advancedEffects, L("wormholes_switch"), false, L("wormholes_switch_tip"))
    script.wormholeCount = createSliderInt(advancedEffects, L("wormholes_count"), 1, 3, 2, "%d", L("wormholes_count_tip"))

    script.shieldColor = colorGroup:ColorPicker(L("primary_color"), DEFAULT_PRIMARY_COLOR)
    script.shieldColor2 = colorGroup:ColorPicker(L("secondary_color"), DEFAULT_SECONDARY_COLOR)
end

-- Основная логика и отрисовка
script.OnFrame = function()
    if not script.enabled or not script.enabled.Get then return end
    if not script.enabled:Get() then return end

    local frameTime = GlobalVars and GlobalVars.GetFrameTime and GlobalVars.GetFrameTime() or 0.016
    local dt = math.min(frameTime, 0.05)
    time = time + dt * 0.1  -- Замедляем время в 10 раз
    UpdateLanguage(false)

    -- Обновляем количество частиц при необходимости
    ensureCount(bgParticles, script.bgParticleCount:Get(), createBgParticle)

    -- Обновляем количество звезд при необходимости
    ensureCount(stars, script.starCount:Get(), createStar)

    -- Обновляем количество туманностей при необходимости
    ensureCount(nebulaClouds, script.cloudCount:Get(), createCloud)

    -- Обновляем количество червоточин при необходимости
    ensureCount(wormholes, script.wormholeCount:Get(), createWormhole)

    -- Получаем позицию курсора
    local cursorPos = getCursorScreenPos()

    -- Обновление фоновых частиц с реакцией на курсор
    for i, particle in ipairs(bgParticles) do
        -- Реакция на курсор
        if script.cursorAttraction:Get() and cursorPos and cursorPos.x and cursorPos.y then
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

-- Отрисовка фоновых эффектов
function DrawBackgroundEffects()
    -- Проверяем существование необходимых переменных
    if not script.backgroundOpacity then
        return
    end
    
    local opacity = script.backgroundOpacity:Get()
    local primaryColor = getPrimaryColor()
    local secondaryColor = getSecondaryColor()
    
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
