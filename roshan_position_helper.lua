local roshan_helper = {}

-- Константы для Рошана (патч 7.40c) - ИСТИННЫЕ ФАНТОМНЫЕ СПОТЫ
local ROSHAN_PITS = {
    -- Верхнее логово (Night Pit) - в верхней части реки, ближе к Dire
    {
        center = Vector(-156, 1728, 0),
        name = "Night Pit (Top)",
        description = "Upper river pit, closer to Dire jungle",
        positions = {
            -- ПРОВЕРЕННЫЕ ФАНТОМНЫЕ СПОТЫ для верхнего логова
            {pos = Vector(-3128.8865, 1864.0858, 0), name = "Phantom Spot #1", safe = true, priority = 1, 
             description = "True phantom - invisible until close approach"},
            {pos = Vector(-2625.8818, 2234.271, 0), name = "Phantom Spot #2", safe = true, priority = 1,
             description = "Alternative phantom position"},
        }
    },
    -- Нижнее логово (Day Pit) - в нижней части реки, ближе к Radiant  
    {
        center = Vector(128, -1728, 0),
        name = "Day Pit (Bot)",
        description = "Lower river pit, closer to Radiant jungle",
        positions = {
            -- ОБНОВЛЕННЫЙ ПРОВЕРЕННЫЙ ФАНТОМНЫЙ СПОТ для нижнего логова
            {pos = Vector(2321.7434, -2745.3682, 0), name = "Phantom Spot", safe = true, priority = 1,
             description = "True phantom - invisible until close approach"},
        }
    }
}

local ROSHAN_PIT_RADIUS = 800
local current_pit = nil -- Текущее активное логово
local roshan_transition_time = 0 -- Время перехода Рошана между логовами

-- UI элементы
local menuRoot = Menu.Create("Scripts", "User Scripts", "Roshan Position Helper")
menuRoot:Icon("\u{f6b6}")

local mainOptions = menuRoot:Create("Settings")
local mainMenu = mainOptions:Create("Main Settings")
local visualMenu = mainOptions:Create("Visual Settings")

local ui = {}

-- Основные настройки
ui.enabled = mainMenu:Switch("Enable Helper", false, "\u{f00c}")
ui.auto_move = mainMenu:Switch("Auto Move on Click", true, "\u{f0b2}")
ui.blink_to_spot = mainMenu:Switch("Blink to spot on click", false, "\u{f0e7}")
ui.check_enemies = mainMenu:Switch("Check Enemy Vision", true, "\u{f06e}")
ui.show_all_spots = mainMenu:Switch("Show All Phantom Spots", true, "\u{f06e}")

-- Визуальные настройки
ui.position_color = visualMenu:ColorPicker("Safe Spot Color", Color(255, 215, 0, 255), "\u{f111}")
ui.danger_color = visualMenu:ColorPicker("Danger Color", Color(255, 100, 100, 255), "\u{f111}")
ui.circle_size = visualMenu:Slider("Circle Size", 20, 100, 40)

-- Переменные
local font = Render.LoadFont("Arial", 0, 500)
local my_hero = nil
local roshan_entity = nil
local last_click_time = 0
local selected_position = nil
local pending_blink_pos = nil  -- точка, к которой идём; когда войдёт в радиус блинка — кастуем блинк

-- Функция определения времени перехода Рошана (каждые 5 минут с 15:00)
local function GetRoshanTransitionInfo()
    local game_time = GameRules.GetGameTime() - GameRules.GetGameStartTime()
    local minutes = game_time / 60
    
    -- Рошан начинает переходить с 15:00, каждые 5 минут
    if minutes < 15 then
        return {
            next_transition = 15,
            time_until_transition = (15 * 60) - game_time,
            is_transitioning = false
        }
    end
    
    -- Вычисляем следующий переход
    local minutes_since_15 = minutes - 15
    local transition_cycle = math.floor(minutes_since_15 / 5)
    local next_transition_minutes = 15 + (transition_cycle + 1) * 5
    local time_until_transition = (next_transition_minutes * 60) - game_time
    
    -- Рошан переходит в течение ~10 секунд
    local is_transitioning = time_until_transition < 10 and time_until_transition > -10
    
    return {
        next_transition = next_transition_minutes,
        time_until_transition = time_until_transition,
        is_transitioning = is_transitioning,
        current_cycle = transition_cycle
    }
end
-- Функция поиска Рошана и определения активного логова
local function FindRoshanAndPit()
    local roshan = nil
    
    -- Ищем Рошана среди всех NPC
    for _, npc in pairs(NPCs.GetAll()) do
        if npc and Entity.IsAlive(npc) then
            local unit_name = NPC.GetUnitName(npc)
            if unit_name == "npc_dota_roshan" then
                roshan = npc
                break
            end
        end
    end
    
    -- Если Рошан найден, определяем ближайшее логово
    if roshan then
        local roshan_pos = Entity.GetAbsOrigin(roshan)
        local closest_pit = nil
        local min_distance = math.huge
        
        for _, pit in pairs(ROSHAN_PITS) do
            local distance = (roshan_pos - pit.center):Length()
            if distance < min_distance then
                min_distance = distance
                closest_pit = pit
            end
        end
        
        current_pit = closest_pit
        return roshan
    end
    
    -- Если Рошан не найден, определяем логово по времени игры
    local transition_info = GetRoshanTransitionInfo()
    local game_time = GameRules.GetGameTime() - GameRules.GetGameStartTime()
    local minutes = game_time / 60
    
    if minutes >= 15 then
        -- После 15:00 определяем по циклу переходов
        local cycle = math.floor((minutes - 15) / 5)
        current_pit = ROSHAN_PITS[(cycle % 2) + 1] -- Чередуем между логовами
    else
        -- До 15:00 используем верхнее логово по умолчанию
        current_pit = ROSHAN_PITS[1] -- Night Pit
    end
    
    return nil
end

-- Проверка видимости позиции врагами
local function IsPositionSafeFromEnemies(pos)
    if not ui.check_enemies:Get() then
        return true
    end
    
    local my_team = Entity.GetTeamNum(my_hero)
    local enemies = Heroes.GetAll()
    
    for _, enemy in pairs(enemies) do
        if enemy and Entity.IsAlive(enemy) and Entity.GetTeamNum(enemy) ~= my_team then
            if NPC.IsVisible(enemy) then
                local enemy_pos = Entity.GetAbsOrigin(enemy)
                local distance = (pos - enemy_pos):Length()
                local vision_range = NPC.GetDayTimeVisionRange(enemy)
                
                -- Проверяем, видит ли враг эту позицию
                if distance < vision_range then
                    return false
                end
            end
        end
    end
    return true
end

-- Проверка, можно ли видеть яму Рошана с позиции
local function CanSeeRoshanPit(pos)
    if not current_pit then
        return false
    end
    local distance_to_pit = (pos - current_pit.center):Length()
    return distance_to_pit < 1200 -- Дистанция обзора ямы
end

-- Получение лучших позиций для текущего логова
local function GetBestPositions()
    local positions = {}
    
    if ui.show_all_spots:Get() then
        -- Показываем все фантомные споты из всех логовищ
        for _, pit in pairs(ROSHAN_PITS) do
            for _, safe_pos in pairs(pit.positions) do
                local is_safe = IsPositionSafeFromEnemies(safe_pos.pos)
                local can_see = CanSeeRoshanPit(safe_pos.pos)
                
                table.insert(positions, {
                    pos = safe_pos.pos,
                    name = safe_pos.name .. " (" .. pit.name .. ")",
                    safe = is_safe,
                    can_see = can_see,
                    priority = safe_pos.priority or 1,
                    description = safe_pos.description,
                    pit_name = pit.name,
                    score = (is_safe and 1 or 0) + (can_see and 1 or 0) + 2 -- Бонус за фантомный спот
                })
            end
        end
    else
        -- Показываем только позиции для текущего логова
        if not current_pit then
            return {}
        end
        
        for _, safe_pos in pairs(current_pit.positions) do
            local is_safe = IsPositionSafeFromEnemies(safe_pos.pos)
            local can_see = CanSeeRoshanPit(safe_pos.pos)
            
            table.insert(positions, {
                pos = safe_pos.pos,
                name = safe_pos.name,
                safe = is_safe,
                can_see = can_see,
                priority = safe_pos.priority or 1,
                description = safe_pos.description,
                pit_name = current_pit.name,
                score = (is_safe and 1 or 0) + (can_see and 1 or 0) + 2 -- Бонус за фантомный спот
            })
        end
    end
    
    return positions
end

-- Имена предметов-блинков (API: NPC.GetItem по имени)
local BLINK_ITEMS = { "item_overwhelming_blink", "item_arcane_blink", "item_blink" }

-- Найти блинк у героя и вернуть (ability, max_range); max_range может быть clamp для недоброса
local function GetBlinkItemAndRange(hero)
    if not hero or not Entity.IsAlive(hero) then
        return nil, 0
    end
    for _, item_name in ipairs(BLINK_ITEMS) do
        local item = NPC.GetItem(hero, item_name)
        if item then
            local range = Ability.GetLevelSpecialValueFor(item, "blink_range") or 1200
            local clamp = Ability.GetLevelSpecialValueFor(item, "blink_range_clamp") or (range * 0.8)
            return item, range, clamp
        end
    end
    return nil, 0, 0
end

-- Позиция в пределах дистанции от hero_pos (для блинка: не дальше max_range)
local function ClampPositionToRange(hero_pos, target_pos, max_range)
    local delta = target_pos - hero_pos
    delta.z = 0
    local dist = delta:Length()
    if dist <= 0 then
        return target_pos
    end
    if dist <= max_range then
        return target_pos
    end
    return hero_pos + delta:Normalized() * max_range
end

-- Дистанция, ближе которой лучше идти пешком, чем тратить блинк (две точки рядом)
local BLINK_MIN_DISTANCE = 250

-- Попытка блинкнуться в точку спота (по API: Ability.CastPosition, GridNav.IsTraversable)
-- Блинк только если точка в радиусе блинка; если уже рядом — не блинкаем
local function TryBlinkToPosition(hero, pos)
    local blink_item, max_range = GetBlinkItemAndRange(hero)
    if not blink_item then
        return false
    end
    if not Ability.IsCastable(blink_item, NPC.GetMana(hero)) then
        return false
    end
    local hero_pos = Entity.GetAbsOrigin(hero)
    local delta = pos - hero_pos
    delta.z = 0
    local dist_to_spot = delta:Length()
    -- Рядом с точкой — лучше пешком пройтись, чем блинк
    if dist_to_spot < BLINK_MIN_DISTANCE then
        return false
    end
    -- Точка должна попадать в радиус блинка
    if dist_to_spot > max_range then
        return false
    end
    local target_pos = (dist_to_spot > 0) and pos or hero_pos
    local traversable = GridNav.IsTraversable(target_pos)
    if not traversable then
        return false
    end
    Ability.CastPosition(blink_item, target_pos)
    return true
end

-- Обработка клика мыши
local function HandleMouseClick()
    if not ui.enabled:Get() then
        return
    end
    
    local cursor_x, cursor_y = Input.GetCursorPos()
    local positions = GetBestPositions()
    
    for _, pos_data in pairs(positions) do
        local screen_pos, visible = pos_data.pos:ToScreen()
        if visible then
            local distance = math.sqrt((screen_pos.x - cursor_x)^2 + (screen_pos.y - cursor_y)^2)
            
            if distance < ui.circle_size:Get() then
                selected_position = pos_data
                if my_hero then
                    if ui.blink_to_spot:Get() then
                        if TryBlinkToPosition(my_hero, pos_data.pos) then
                            pending_blink_pos = nil  -- блинк применён, цель сброшена
                        else
                            -- далеко: идём к точке, в OnUpdate проверим радиус и сделаем блинк
                            pending_blink_pos = pos_data.pos
                            NPC.MoveTo(my_hero, pos_data.pos, false, true)
                        end
                    elseif ui.auto_move:Get() then
                        pending_blink_pos = nil
                        NPC.MoveTo(my_hero, pos_data.pos, false, true)
                    end
                end
                last_click_time = GameRules.GetGameTime()
                break
            end
        end
    end
end

-- Отрисовка позиций (только фантомные споты)
local function DrawPositions()
    local positions = GetBestPositions()
    local time = GameRules.GetGameTime()
    
    for i, pos_data in pairs(positions) do
        local screen_pos, visible = Render.WorldToScreen(pos_data.pos)
        if visible then
            local base_size = ui.circle_size:Get()
            
            -- Цвета из настроек
            local safe_color = ui.position_color:Get()      -- Цвет безопасных спотов из настроек
            local danger_color = ui.danger_color:Get()      -- Цвет опасных спотов из настроек
            local selected_color = Color(255, 255, 255, 255) -- Белый для выбранных
            
            local main_color = pos_data.safe and safe_color or danger_color
            
            -- Анимация выбранной позиции
            local circle_size = base_size
            if selected_position and selected_position.pos == pos_data.pos then
                local time_since_click = time - last_click_time
                if time_since_click < 3.0 then
                    circle_size = base_size + math.sin(time_since_click * 8) * 8
                    main_color = selected_color
                end
            end
            
            -- Основной круг (заливка)
            if pos_data.safe then
                local fill_alpha = math.floor(180 + 75 * math.sin(time * 2 + i))
                local fill_color = Color(main_color.r, main_color.g, main_color.b, fill_alpha)
                Render.FilledCircle(screen_pos, circle_size * 0.6, fill_color)
            end
            
            -- Внешнее кольцо (основное)
            Render.Circle(screen_pos, circle_size * 0.8, main_color, 3)
            
            -- Пульсирующее внешнее кольцо
            local pulse = math.sin(time * 3 + i * 0.5) * 0.3 + 0.7
            local outer_size = circle_size * (1.2 + pulse * 0.3)
            local outer_alpha = math.floor(100 * pulse)
            local outer_color = Color(main_color.r, main_color.g, main_color.b, outer_alpha)
            Render.Circle(screen_pos, outer_size, outer_color, 2)
            
            -- Внутренняя точка
            local inner_alpha = math.floor(200 + 55 * math.sin(time * 4 + i))
            local inner_color = Color(255, 255, 255, inner_alpha)
            Render.FilledCircle(screen_pos, circle_size * 0.2, inner_color)
            
            -- Дополнительные эффекты для фантомных спотов
            if pos_data.safe then
                -- Вращающиеся частицы вокруг точки
                for j = 1, 4 do
                    local angle = (time * 2 + j * math.pi / 2) % (math.pi * 2)
                    local particle_radius = circle_size * 1.5
                    local particle_x = screen_pos.x + math.cos(angle) * particle_radius
                    local particle_y = screen_pos.y + math.sin(angle) * particle_radius
                    local particle_alpha = math.floor(150 * math.sin(time * 2 + j))
                    if particle_alpha > 0 then
                        local particle_color = Color(safe_color.r, safe_color.g, safe_color.b, particle_alpha)
                        Render.FilledCircle(Vec2(particle_x, particle_y), 3, particle_color)
                    end
                end
                
                -- Волновой эффект
                local wave_size = circle_size * (2 + math.sin(time * 1.5 + i) * 0.5)
                local wave_alpha = math.floor(50 * (1 - math.abs(math.sin(time * 1.5 + i))))
                if wave_alpha > 0 then
                    local wave_color = Color(safe_color.r, safe_color.g, safe_color.b, wave_alpha)
                    Render.Circle(screen_pos, wave_size, wave_color, 1)
                end
            end
            
            -- Индикатор опасности для небезопасных позиций
            if not pos_data.safe then
                local warning_pulse = math.sin(time * 6) * 0.5 + 0.5
                local warning_alpha = math.floor(100 + 155 * warning_pulse)
                local warning_color = Color(danger_color.r, danger_color.g, danger_color.b, warning_alpha)
                Render.Circle(screen_pos, circle_size * 1.4, warning_color, 2)
                
                -- Мигающий крест
                if math.sin(time * 8) > 0 then
                    local cross_size = circle_size * 0.4
                    Render.Line(Vec2(screen_pos.x - cross_size, screen_pos.y), 
                               Vec2(screen_pos.x + cross_size, screen_pos.y), 
                               Color(255, 255, 255, 200), 3)
                    Render.Line(Vec2(screen_pos.x, screen_pos.y - cross_size), 
                               Vec2(screen_pos.x, screen_pos.y + cross_size), 
                               Color(255, 255, 255, 200), 3)
                end
            end
        end
    end
end

-- Отрисовка линий к Рошану
local function DrawRoshanLines()
    if not roshan_entity or not Entity.IsAlive(roshan_entity) then
        return
    end
    
    local roshan_pos = Entity.GetAbsOrigin(roshan_entity)
    local roshan_screen, roshan_visible = Render.WorldToScreen(roshan_pos)
    
    if not roshan_visible then
        return
    end
    
    local time = GameRules.GetGameTime()
    local positions = GetBestPositions()
    local safe_color = ui.position_color:Get()
    
    for i, pos_data in pairs(positions) do
        if pos_data.safe and pos_data.can_see then
            local screen_pos, visible = Render.WorldToScreen(pos_data.pos)
            if visible then
                -- Анимированная линия с пульсацией
                local alpha_pulse = math.sin(time * 3 + i) * 0.3 + 0.7
                local alpha = math.floor(60 * alpha_pulse)
                local line_color = Color(safe_color.r, safe_color.g, safe_color.b, alpha)
                
                -- Основная линия
                Render.Line(screen_pos, roshan_screen, line_color, 2)
                
                -- Дополнительная тонкая линия для эффекта
                local thin_alpha = math.floor(30 * alpha_pulse)
                local thin_color = Color(255, 255, 255, thin_alpha)
                Render.Line(screen_pos, roshan_screen, thin_color, 1)
            end
        end
    end
end

-- Проверка в движении: точка вошла в радиус блинка -> кастуем блинк
local function UpdatePendingBlink()
    if not pending_blink_pos or not my_hero or not Entity.IsAlive(my_hero) then
        return
    end
    if not ui.blink_to_spot:Get() then
        pending_blink_pos = nil
        return
    end
    if TryBlinkToPosition(my_hero, pending_blink_pos) then
        pending_blink_pos = nil
    else
        -- уже на месте (очень близко) — сбрасываем цель
        local hero_pos = Entity.GetAbsOrigin(my_hero)
        local delta = pending_blink_pos - hero_pos
        delta.z = 0
        if delta:Length() < 80 then
            pending_blink_pos = nil
        end
    end
end

-- Callbacks
function roshan_helper.OnUpdate()
    if not ui.enabled:Get() then
        pending_blink_pos = nil
        return
    end
    
    -- Обновляем ссылки на объекты
    if not my_hero then
        my_hero = Heroes.GetLocal()
    end
    
    roshan_entity = FindRoshanAndPit()
    UpdatePendingBlink()
end

function roshan_helper.OnDraw()
    if not ui.enabled:Get() or not Engine.IsInGame() then
        return
    end
    
    DrawPositions()
    DrawRoshanLines()
    
    -- Минимальный индикатор в углу экрана
    local screen_size = Render.ScreenSize()
    local indicator_pos = Vec2(screen_size.x - 100, 50)
    local time = GameRules.GetGameTime()
    local safe_color = ui.position_color:Get()
    
    -- Пульсирующий индикатор активности скрипта
    local pulse = math.sin(time * 2) * 0.3 + 0.7
    local indicator_size = 8 + pulse * 4
    local indicator_alpha = math.floor(150 + 105 * pulse)
    local indicator_color = Color(safe_color.r, safe_color.g, safe_color.b, indicator_alpha)
    
    Render.FilledCircle(indicator_pos, indicator_size, indicator_color)
    Render.Circle(indicator_pos, indicator_size + 3, Color(255, 255, 255, 100), 1)
    
    -- Предупреждение о переходах (только визуальное)
    local transition_info = GetRoshanTransitionInfo()
    if transition_info.is_transitioning then
        -- Мигающий красный индикатор опасности
        if math.sin(time * 8) > 0 then
            local warning_pos = Vec2(screen_size.x / 2, 30)
            local warning_size = 15
            local danger_color = ui.danger_color:Get()
            Render.FilledCircle(warning_pos, warning_size, Color(danger_color.r, danger_color.g, danger_color.b, 200))
            Render.Circle(warning_pos, warning_size + 5, Color(255, 255, 255, 150), 2)
        end
    end
end

function roshan_helper.OnKeyEvent(data)
    if not ui.enabled:Get() then
        return true
    end
    
    -- Обработка клика левой кнопкой мыши
    if data.key == Enum.ButtonCode.KEY_MOUSE1 and data.event == Enum.EKeyEvent.EKeyEvent_KEY_DOWN then
        HandleMouseClick()
    end
    
    return true
end

return roshan_helper