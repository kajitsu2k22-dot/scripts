---@diagnostic disable: undefined-global

local SCRIPT_NAME = "Watermark"
local SCRIPT_VERSION = "2.0.0"
local DEBUG_PREFIX = "[Watermark]"

-- ═══════════════════════════════════════════════════════════════
--  Инициализация UI через NEW_UI_LIB
-- ═══════════════════════════════════════════════════════════════
local visuals_tab = Menu.Find("Visuals", "", "Visuals")
local tab
if visuals_tab then
    tab = NEW_UI_LIB.create_tab(false, visuals_tab, "Watermark")
else
    tab = NEW_UI_LIB.create_tab(false, "Visuals", "", "Visuals", "Watermark")
end
local g_general = tab:create("General")
local g_elements = tab:create("Elements")
local g_colors = tab:create("Colors")

local script = {}

-- Глобальные переменные рендеринга и состояния
local fonts = {
    pixel = nil,
    museo = nil,
    consolas = nil,
    arial = nil
}

local state = {
    is_dragging = false,
    drag_offset = Vec2(0, 0),
    pos_x_val = 20,
    pos_y_val = 20,
    pending_save = false,
    fps = 0,
    fps_refresh = 0,
}

script.enabled = g_general:switch("Enable Watermark", true, "\u{f011}", "Toggles the watermark rendering")
script.locked = g_general:switch("Lock Position", false, "\u{f023}", "Lock the position to prevent dragging")
script.font_style = g_general:combo("Font Style", {"Pixel (04b03)", "Museo Sans", "Consolas", "Arial"}, 1, "\u{f031}", "Choose the font style")
script.font_size = g_general:slider("Font Size", 8, 16, 11, "%d", "\u{f034}", "Size of the text font")
script.accent_thick = g_general:slider("Accent Thickness", 1, 4, 2, "%d", "\u{f5fd}", "Thickness of the top accent line")

-- Слайдеры координат (обновляются при перетаскивании)
script.pos_x = g_general:slider("Position X", 0, 3840, 20, "%d", "\u{f07e}", "X position on screen")
script.pos_y = g_general:slider("Position Y", 0, 2160, 20, "%d", "\u{f07d}", "Y position on screen")

-- Колбэки на изменение слайдеров вручную из меню
script.pos_x:set_callback(function()
    if not state.is_dragging then
        state.pos_x_val = script.pos_x()
    end
end)

script.pos_y:set_callback(function()
    if not state.is_dragging then
        state.pos_y_val = script.pos_y()
    end
end)

-- Инициализируем стартовые значения
state.pos_x_val = script.pos_x()
state.pos_y_val = script.pos_y()

-- Переключатели элементов текста
script.show_brand = g_elements:switch("Show Brand", true, "\u{f54c}", "Show cheat/brand name")
script.brand_name = g_elements:input("Brand Name", "umbrella", "\u{f304}", "Custom brand text")

script.show_user = g_elements:switch("Show Username", true, "\u{f007}", "Show username")
script.user_name = g_elements:input("Username", "", "\u{f4ff}", "Custom username (leave blank to use Steam Name)")

script.show_custom = g_elements:switch("Show Custom Tag", true, "\u{f02c}", "Show custom middle text tag")
script.custom_tag = g_elements:input("Custom Tag", "zont", "\u{f303}", "Custom middle text tag")

script.show_tickrate = g_elements:switch("Show Tickrate", true, "\u{f0e7}", "Show server tickrate")
script.show_fps = g_elements:switch("Show FPS", true, "\u{f2db}", "Show frames per second")
script.show_ping = g_elements:switch("Show Ping", true, "\u{f1eb}", "Show connection ping")
script.show_time = g_elements:switch("Show Time", true, "\u{f017}", "Show local time")

-- Настройка цветов
script.rainbow_accent = g_colors:switch("Rainbow Accent Line", true, "\u{f5c1}", "Use shifting rainbow cycle for accent line")
script.accent_c1 = g_colors:colorpicker("Accent Gradient Color 1", Color(255, 50, 50, 255), "\u{f53f}", "Start color of custom gradient")
script.accent_c2 = g_colors:colorpicker("Accent Gradient Color 2", Color(50, 50, 255, 255), "\u{f53f}", "End color of custom gradient")
script.gradient_speed = g_colors:slider("Gradient Speed", 0, 10, 2, "%d", "\u{f3fd}", "Speed of the gradient color shifting (0 to disable)")
script.bg_color = g_colors:colorpicker("Background Color", Color(14, 18, 26, 230), "\u{f571}", "Color of the background box")
script.text_color = g_colors:colorpicker("Text Color", Color(255, 255, 255, 240), "\u{f031}", "Color of the watermark text")

-- ═══════════════════════════════════════════════════════════════
--  Вспомогательные методы
-- ═══════════════════════════════════════════════════════════════
local function is_menu_open()
    return Menu.Opened and Menu.Opened() or false
end

local function hsl_to_rgb(h, s, l)
    local r, g, b
    if s == 0 then
        r, g, b = l, l, l
    else
        local function hue_to_rgb(p, q, t)
            if t < 0 then t = t + 1 end
            if t > 1 then t = t - 1 end
            if t < 1/6 then return p + (q - p) * 6 * t end
            if t < 1/2 then return q end
            if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
            return p
        end

        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        r = hue_to_rgb(p, q, h + 1/3)
        g = hue_to_rgb(p, q, h)
        b = hue_to_rgb(p, q, h - 1/3)
    end
    return Color(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), 255)
end

local function lerp_color(c1, c2, t)
    local r = math.floor(c1.r + (c2.r - c1.r) * t)
    local g = math.floor(c1.g + (c2.g - c1.g) * t)
    local b = math.floor(c1.b + (c2.b - c1.b) * t)
    local a = math.floor(c1.a + (c2.a - c1.a) * t)
    return Color(r, g, b, a)
end

local function get_accent_colors()
    local speed = script.gradient_speed()
    local t = speed > 0 and (os.clock() * speed) or 0
    
    if script.rainbow_accent() then
        local hue_left = (os.clock() * (speed * 0.05)) % 1.0
        local hue_right = (hue_left + 0.2) % 1.0
        local left_color = hsl_to_rgb(hue_left, 1.0, 0.6)
        local right_color = hsl_to_rgb(hue_right, 1.0, 0.6)
        return left_color, right_color
    else
        local c1 = script.accent_c1()
        local c2 = script.accent_c2()
        
        local left_val = (math.sin(t) + 1.0) / 2.0
        local right_val = (math.sin(t + 1.5) + 1.0) / 2.0
        
        local left_color = lerp_color(c1, c2, left_val)
        local right_color = lerp_color(c1, c2, right_val)
        return left_color, right_color
    end
end

local function handle_dragging(width, height)
    if script.locked() then
        state.is_dragging = false
        state.pending_save = false
        return
    end

    local menu_open = is_menu_open()
    if not menu_open then
        if state.is_dragging then
            state.is_dragging = false
            state.pending_save = true
        end
        return
    end

    local KEY_MOUSE1 = (Enum and Enum.ButtonCode and Enum.ButtonCode.KEY_MOUSE1) or 314
    local mouse_down = input.is_down(KEY_MOUSE1)
    local cursor = input.cursor_pos()
    
    if not state.is_dragging then
        if input.is_pressed(KEY_MOUSE1) then
            if cursor.x >= state.pos_x_val and cursor.x <= state.pos_x_val + width and
               cursor.y >= state.pos_y_val and cursor.y <= state.pos_y_val + height then
                state.is_dragging = true
                state.drag_offset = Vec2(cursor.x - state.pos_x_val, cursor.y - state.pos_y_val)
            end
        end
    else
        if mouse_down then
            local new_x = math.floor(cursor.x - state.drag_offset.x)
            local new_y = math.floor(cursor.y - state.drag_offset.y)
            
            -- Ограничение позиционирования границами экрана
            local screen = Render.ScreenSize()
            state.pos_x_val = math.max(0, math.min(new_x, screen.x - width))
            state.pos_y_val = math.max(0, math.min(new_y, screen.y - height))
        else
            state.is_dragging = false
            state.pending_save = true
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
--  Рендеринг и Отрисовка
-- ═══════════════════════════════════════════════════════════════
local function on_draw()
    if not script.enabled() then
        state.is_dragging = false
        return
    end

    local selected_style = script.font_style()
    local active_font = fonts.pixel or fonts.museo or fonts.consolas
    if selected_style == 1 then
        active_font = fonts.pixel or fonts.museo or fonts.consolas
    elseif selected_style == 2 then
        active_font = fonts.museo or fonts.pixel or fonts.consolas
    elseif selected_style == 3 then
        active_font = fonts.consolas or fonts.pixel
    elseif selected_style == 4 then
        active_font = fonts.arial or fonts.pixel
    end

    if not active_font then
        return
    end

    local parts = {}
    
    -- 1. Название чита/бренда (с авто-заполнением, если пусто)
    if script.show_brand() then
        local brand = script.brand_name()
        if not brand or brand == "" then
            brand = "umbrella"
        end
        table.insert(parts, brand)
    end
    
    -- 2. Имя пользователя (с авто-заполнением Steam Name, если пусто)
    if script.show_user() then
        local user = script.user_name()
        if not user or user == "" then
            local controller = entity_list.local_controller()
            if controller and controller:valid() then
                user = controller:get_name()
            end
        end
        if not user or user == "" then
            user = "user"
        end
        table.insert(parts, user)
    end
    
    -- 3. Кастомный тег (с авто-заполнением, если пусто)
    if script.show_custom() then
        local tag = script.custom_tag()
        if not tag or tag == "" then
            tag = "zont"
        end
        table.insert(parts, tag)
    end
    
    -- 4. Серверный тикрейт
    if script.show_tickrate() then
        local interval = global_vars.interval_per_tick()
        local tickrate = interval > 0 and math.floor(1 / interval + 0.5) or 64
        table.insert(parts, tostring(tickrate) .. " tick")
    end
    
    -- 5. Показатель FPS
    if script.show_fps() then
        local now = os.clock()
        if now - state.fps_refresh > 0.25 then
            local frame_time = global_vars.absoluteframetime()
            state.fps = frame_time > 0 and math.floor(1 / frame_time) or 0
            state.fps_refresh = now
        end
        table.insert(parts, tostring(state.fps) .. " fps")
    end
    
    -- 6. Пинг/Задержка сети
    if script.show_ping() then
        local ping = 0
        if net_channel and net_channel.latency then
            local latency = net_channel.latency()
            if type(latency) == "number" and latency >= 0 then
                ping = math.floor(latency * 1000 + 0.5)
            end
        end
        table.insert(parts, tostring(ping) .. "ms")
    end
    
    -- 7. Локальное время
    if script.show_time() then
        table.insert(parts, os.date("%I:%M %p"))
    end

    if #parts == 0 then
        return
    end

    local text = table.concat(parts, " | ")
    local font_size = script.font_size()
    local accent_thickness = script.accent_thick()
    
    local text_size = Render.TextSize(active_font, font_size, text)
    local padding_x = 10
    local padding_y = 6
    
    local width = text_size.x + padding_x * 2
    local height = text_size.y + padding_y * 2 + accent_thickness
    
    -- Перетаскивание и фиксация границ экрана
    handle_dragging(width, height)
    
    local pos = Vec2(state.pos_x_val, state.pos_y_val)
    
    local box_start = pos
    local box_end = Vec2(pos.x + width, pos.y + height)
    
    -- Цвета
    local bg_color = script.bg_color() or Color(14, 18, 26, 230)
    local text_color = script.text_color() or Color(255, 255, 255, 240)
    local left_color, right_color = get_accent_colors()
    
    -- 1. Рисуем фон
    Render.FilledRect(box_start, box_end, bg_color)
    
    -- 2. Рисуем верхнюю полосу акцента (градиентную)
    local accent_start = pos
    local accent_end = Vec2(pos.x + width, pos.y + accent_thickness)
    Render.Gradient(accent_start, accent_end, left_color, right_color, left_color, right_color)
    
    -- 3. Двойная рамка
    -- Внешняя (черный контур)
    Render.Rect(box_start, box_end, Color(0, 0, 0, 255), 0, 0, 1.0)
    
    -- Внутренняя (темно-серый контур для 3D глубины)
    local inner_start = Vec2(box_start.x + 1, box_start.y + 1)
    local inner_end = Vec2(box_end.x - 1, box_end.y - 1)
    Render.Rect(inner_start, inner_end, Color(45, 45, 45, 220), 0, 0, 1.0)
    
    -- 4. Вывод строки с кастомной раскраской rella
    local current_x = pos.x + padding_x
    local text_y = pos.y + accent_thickness + padding_y
    
    for i, part in ipairs(parts) do
        -- Отрисовка разделителя
        if i > 1 then
            local sep = " | "
            Render.Text(active_font, font_size, sep, Vec2(current_x, text_y), text_color)
            current_x = current_x + Render.TextSize(active_font, font_size, sep).x
        end
        
        -- Отрисовка части текста
        if i == 1 and script.show_brand() then
            -- Проверяем наличие rella в названии бренда
            local brand_text = part
            local rella_start, rella_end = brand_text:find("rella")
            if rella_start then
                local first_part = brand_text:sub(1, rella_start - 1)
                local second_part = brand_text:sub(rella_start, rella_end)
                local third_part = brand_text:sub(rella_end + 1)
                
                if #first_part > 0 then
                    Render.Text(active_font, font_size, first_part, Vec2(current_x, text_y), text_color)
                    current_x = current_x + Render.TextSize(active_font, font_size, first_part).x
                end
                
                -- Подсвечиваем rella красным цветом
                local red_color = Color(255, 50, 50, text_color.a)
                Render.Text(active_font, font_size, second_part, Vec2(current_x, text_y), red_color)
                current_x = current_x + Render.TextSize(active_font, font_size, second_part).x
                
                if #third_part > 0 then
                    Render.Text(active_font, font_size, third_part, Vec2(current_x, text_y), text_color)
                    current_x = current_x + Render.TextSize(active_font, font_size, third_part).x
                end
            else
                Render.Text(active_font, font_size, brand_text, Vec2(current_x, text_y), text_color)
                current_x = current_x + Render.TextSize(active_font, font_size, brand_text).x
            end
        else
            Render.Text(active_font, font_size, part, Vec2(current_x, text_y), text_color)
            current_x = current_x + Render.TextSize(active_font, font_size, part).x
        end
    end
end

local function OnScriptsLoaded()
    local antialias = (Enum and Enum.FontCreate and Enum.FontCreate.FONTFLAG_ANTIALIAS) or 16
    
    -- Определяем базовую директорию скрипта
    local base_dir = ""
    local status, info = pcall(debug.getinfo, 1, "S")
    if status and info and info.source and info.source:sub(1, 1) == "@" then
        local filepath = info.source:sub(2):gsub("\\", "/")
        base_dir = filepath:match("(.-)deadlock_scripts/") or filepath:match("(.-)[^/]+$") or ""
    end

    -- 1. Загружаем Pixel Font (04b03) с отключенным сглаживанием для четкости пикселей
    local pixel_paths = {
        "C:\\Umbrella\\fonts\\04b03.ttf",
        "D:\\Umbrella\\fonts\\04b03.ttf",
        "E:\\Umbrella\\fonts\\04b03.ttf",
        "fonts\\04b03.ttf",
    }
    if base_dir ~= "" then
        table.insert(pixel_paths, 1, (base_dir .. "fonts/04b03.ttf"):gsub("/", "\\"))
    end
    for _, path in ipairs(pixel_paths) do
        fonts.pixel = Render.LoadFont(path, 0, 500)
        if fonts.pixel then break end
    end

    -- 2. Загружаем Museo Sans
    local museo_paths = {
        "C:\\Umbrella\\fonts\\MuseoSansEx 500.ttf",
        "D:\\Umbrella\\fonts\\MuseoSansEx 500.ttf",
        "E:\\Umbrella\\fonts\\MuseoSansEx 500.ttf",
        "fonts\\MuseoSansEx 500.ttf",
    }
    if base_dir ~= "" then
        table.insert(museo_paths, 1, (base_dir .. "fonts/MuseoSansEx 500.ttf"):gsub("/", "\\"))
    end
    for _, path in ipairs(museo_paths) do
        fonts.museo = Render.LoadFont(path, antialias, 500)
        if fonts.museo then break end
    end

    -- 3. Загружаем стандартные системные шрифты
    fonts.consolas = Render.LoadFont("Consolas", antialias, 700)
    fonts.arial = Render.LoadFont("Arial", antialias, 400)

    -- Принудительно синхронизируем координаты из меню при загрузке
    state.pos_x_val = script.pos_x()
    state.pos_y_val = script.pos_y()
    
    print(string.format("%s v%s loaded. Custom fonts loaded: Pixel=%s, Museo=%s", 
        DEBUG_PREFIX, SCRIPT_VERSION, tostring(fonts.pixel ~= nil), tostring(fonts.museo ~= nil)))
end

local function on_frame()
    if not script.enabled() then
        return
    end

    if state.pending_save then
        pcall(function()
            script.pos_x:set(state.pos_x_val)
        end)
        pcall(function()
            script.pos_y:set(state.pos_y_val)
        end)
        state.pending_save = false
    end
end

callback.on_scripts_loaded:set(OnScriptsLoaded)
callback.on_frame:set(on_frame)
callback.on_draw:set(on_draw)

return script
