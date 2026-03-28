---@diagnostic disable
local SCRIPT_VERSION = "2.0.0"

-- ==========================================
-- Required Libraries
-- ==========================================
-- Removed custom libraries

if not Menu or not Menu.Find then
    print("[Event Notifier] Error: Required API components not found.")
    return
end

-- ==========================================
-- Constants & Configuration
-- ==========================================
-- IMPORTANT: These values must match the actual in-game event timings.
-- Adjust these if Valve changes the timings in a patch.

local EVENT_INTERVAL_RUNES = 300 -- 5 minutes between spawns
local EVENT_START_RUNES    = 300 -- First spawn at 5:00 game time

local EVENT_INTERVAL_URN   = 300 -- 5 minutes between spawns (after delivery/despawn)
local EVENT_START_URN      = 600 -- First spawn at 10:00 game time

local EVENT_RESPAWN_BOSS   = 420 -- 7 minutes after boss dies
local EVENT_START_BOSS     = 600 -- First spawn at 10:00 game time

-- Maximum number of simultaneous toasts (prevents memory build-up)
local MAX_TOASTS = 5

-- Modifier state IDs for urn carrier detection
local URN_CARRIER_STATES = { 141, 142, 143, 144 }

-- Single panorama icon for popup notifications (only game assets work with Render.LoadImage)
local NOTIF_ICON = nil
do
    local ok, handle = pcall(function() return Render.LoadImage("panorama/images/heroes/bull_sm_psd.vtex_c") end)
    if ok and handle and type(handle) == "number" and handle > 0 then
        NOTIF_ICON = handle
    end
end

local FONT_HUD = Render.LoadFont([[fonts\MuseoSansEx 500.ttf]], Enum.FontCreate.FONTFLAG_ANTIALIAS, 600)
local FONT_ICON = Render.LoadFont([[fonts\FontAwesomeEx Solid.otf]], Enum.FontCreate.FONTFLAG_ANTIALIAS, 700)

-- ==========================================
-- Programmatic Icon Drawing
-- ==========================================

---Draw a diamond shape (for Runes)
---@param cx number Center X
---@param cy number Center Y
---@param size number Icon size in pixels
local function draw_icon_rune(cx, cy, size)
    local s = math.floor(size / 2)
    -- Outer glow
    Render.FilledRect(Vec2(cx - s, cy - s), Vec2(cx + s, cy + s), Color(40, 120, 200, 60), 3)
    -- Diamond body
    Render.FilledRect(Vec2(cx - s + 2, cy - s + 2), Vec2(cx + s - 2, cy + s - 2), Color(60, 160, 255, 220), 4)
    -- Inner highlight
    Render.FilledRect(Vec2(cx - s + 4, cy - s + 4), Vec2(cx + s - 4, cy + s - 4), Color(120, 200, 255, 180), 3)
    -- Symbol
    local ts = Render.TextSize(FONT_ICON, size - 2, "◆")
    Render.Text(FONT_ICON, size - 2, "◆", Vec2(cx - ts.x / 2, cy - ts.y / 2), Color(255, 255, 255, 240))
end

---Draw a circle with glow (for Soul Urn)
---@param cx number Center X
---@param cy number Center Y
---@param size number Icon size in pixels
local function draw_icon_urn(cx, cy, size)
    local s = math.floor(size / 2)
    Render.FilledRect(Vec2(cx - s, cy - s), Vec2(cx + s, cy + s), Color(200, 100, 20, 60), s)
    Render.FilledRect(Vec2(cx - s + 2, cy - s + 2), Vec2(cx + s - 2, cy + s - 2), Color(255, 150, 50, 220), s)
    Render.FilledRect(Vec2(cx - s + 4, cy - s + 4), Vec2(cx + s - 4, cy + s - 4), Color(255, 200, 100, 180), s)
    local ts = Render.TextSize(FONT_ICON, size - 4, "☀")
    Render.Text(FONT_ICON, size - 4, "☀", Vec2(cx - ts.x / 2, cy - ts.y / 2), Color(255, 255, 255, 240))
end

---Draw a skull-like shape (for Mid Boss)
---@param cx number Center X
---@param cy number Center Y
---@param size number Icon size in pixels
local function draw_icon_boss(cx, cy, size)
    local s = math.floor(size / 2)
    Render.FilledRect(Vec2(cx - s, cy - s), Vec2(cx + s, cy + s), Color(200, 30, 30, 60), 3)
    Render.FilledRect(Vec2(cx - s + 2, cy - s + 2), Vec2(cx + s - 2, cy + s - 2), Color(220, 60, 60, 220), 4)
    Render.FilledRect(Vec2(cx - s + 4, cy - s + 4), Vec2(cx + s - 4, cy + s - 4), Color(255, 100, 80, 180), 3)
    local ts = Render.TextSize(FONT_ICON, size - 4, "☠")
    Render.Text(FONT_ICON, size - 4, "☠", Vec2(cx - ts.x / 2, cy - ts.y / 2), Color(255, 255, 255, 240))
end

---Draw a test checkmark (for Test Notification)
---@param cx number Center X
---@param cy number Center Y
---@param size number Icon size in pixels
local function draw_icon_test(cx, cy, size)
    local s = math.floor(size / 2)
    Render.FilledRect(Vec2(cx - s, cy - s), Vec2(cx + s, cy + s), Color(80, 200, 80, 60), s)
    Render.FilledRect(Vec2(cx - s + 2, cy - s + 2), Vec2(cx + s - 2, cy + s - 2), Color(100, 220, 100, 220), s)
    local ts = Render.TextSize(FONT_ICON, size - 4, "✓")
    Render.Text(FONT_ICON, size - 4, "✓", Vec2(cx - ts.x / 2, cy - ts.y / 2), Color(255, 255, 255, 240))
end

print("[Event Notifier] v" .. SCRIPT_VERSION .. " — Programmatic icons enabled.")

-- ==========================================
-- State Management
-- ==========================================

---Create a fresh state table (used at init and on match reset)
---@return table
local function create_initial_state()
    return {
        last_rune_notif  = -1,
        last_urn_notif   = -1,
        last_boss_notif  = -1,

        -- Spawn-event notification dedup (one "SPAWNED" toast per event)
        last_rune_spawn_notif = -1,
        last_urn_spawn_notif  = -1,
        last_boss_spawn_notif = -1,

        -- Chat alert dedup (one chat message per event cycle)
        last_rune_chat = -1,
        last_urn_chat  = -1,
        last_boss_chat = -1,

        -- Rune tracking
        runes_alive      = false,
        rune_pickup_time = -1,

        -- Boss tracking
        boss_alive       = false,
        boss_death_time  = -1,

        -- Urn tracking
        urn_present      = false,
        urn_pickup_time  = -1,

        -- Dragging State
        is_dragging = false,
        is_resizing = false,
        drag_offset = Vec2(0, 0),

        -- Match detection
        last_match_time = -1,
        
        -- In-game detection
        was_in_game = false,
    }
end

local state = create_initial_state()

-- ==========================================
-- Team Chat Helper
-- ==========================================

--- Send a message to team chat using available engine APIs.
--- Tries multiple API patterns since the exact one depends on the framework version.
---@param msg string The message to send
local function send_team_chat(msg)
    -- Sanitize: remove quotes/special chars that could break the command
    local safe_msg = msg:gsub('"', ''):gsub("'", ''):gsub(";", '')
    
    -- Try common Source 2 scripting API patterns
    local sent = false
    
    -- Pattern 1: Engine.ExecuteClientCmd (capital E)
    if not sent then
        local ok = pcall(function()
            Engine.ExecuteClientCmd('say_team "' .. safe_msg .. '"')
        end)
        if ok then sent = true end
    end
    
    -- Pattern 2: engine.execute_client_cmd (lowercase)
    if not sent then
        local ok = pcall(function()
            engine.execute_client_cmd('say_team "' .. safe_msg .. '"')
        end)
        if ok then sent = true end
    end
    
    -- Pattern 3: client.exec (alternative)
    if not sent then
        local ok = pcall(function()
            client.exec('say_team "' .. safe_msg .. '"')
        end)
        if ok then sent = true end
    end
    
    if sent then
        print("[Event Notifier] Chat sent: " .. safe_msg)
    else
        print("[Event Notifier] WARNING: Could not send team chat — no compatible API found.")
    end
end

-- ==========================================
-- In-Game Detection & Match Clock
-- ==========================================

-- Minimum number of players to consider we're in a real match.
-- In lobby/hero-select there can be up to 3 pawns (yours + 2 test bots).
-- In a real 6v6 match there are 12. We use 4 as the threshold.
local MIN_PLAYERS_FOR_MATCH = 4

-- Clock tracking
local clock_method_name = "not detected"
local clock_debug_info  = ""     -- extra debug string for the HUD

--- Attempt to read the match clock from C_CitadelGameRules schema fields.
--- This function tries EVERY known field name in priority order.
--- The match clock is the same value shown on the in-game HUD (0:00 at game start,
--- pauses when game is paused, does NOT count loading/connect time).
---
--- Known Source 2 / Deadlock schema patterns:
---   1. m_flGameStartTime  — engine timestamp of match clock 0:00
---   2. m_flMatchClockStartTime — same idea, alt name
---   3. m_flStateTransitionTime — when game entered current state
---   4. m_flMatchClockTime — direct match clock value
---   5. m_flGameTime / m_fGameTime — direct time values
---
--- We also check m_bGamePaused / m_bIsPaused to detect pauses.
---
---@return number|nil  match_time  Seconds on the match clock (same as HUD)
---@return boolean     is_paused   Whether the game is currently paused
local function get_match_clock()
    local raw_time = game_rules.game_time()
    if not raw_time then return nil, false end

    -- Try to get the game rules raw struct
    local ok_gr, gr = pcall(function() return game_rules.get() end)
    local is_paused = false

    if ok_gr and gr then
        -- ─── Check pause state ───
        local pause_fields = {
            "m_bGamePaused", "m_bIsPaused", "m_bFreezePeriod",
            "m_bMatchClockPaused", "m_bPaused",
        }
        for _, pf in ipairs(pause_fields) do
            local ok_p, pv = pcall(function() return gr[pf] end)
            if ok_p and pv == true then
                is_paused = true
                break
            end
        end

        -- ─── Strategy 1: Direct match clock field ───
        -- If the engine exposes the match clock directly, use it.
        -- This is the most reliable because it already accounts for
        -- pauses, loading time, and everything.
        local direct_fields = {
            "m_flMatchClockTime",
            "m_flGameTime",
            "m_fGameTime",
        }
        for _, fname in ipairs(direct_fields) do
            local ok_f, val = pcall(function() return gr[fname] end)
            if ok_f and val and type(val) == "number" then
                -- Direct clock field found — only use if it looks reasonable
                -- (between 0 and 3 hours = 10800s)
                if val >= 0 and val < 10800 then
                    clock_method_name = fname .. " (direct)"
                    clock_debug_info = string.format("field=%s val=%.1f", fname, val)
                    return val, is_paused
                end
            end
        end

        -- ─── Strategy 2: Compute from start timestamp ───
        -- game_rules.game_time() returns engine time since map load.
        -- m_flGameStartTime (or similar) stores the engine time when
        -- the match clock hit 0:00. Difference = match clock.
        local offset_fields = {
            "m_flGameStartTime",
            "m_flMatchClockStartTime",
            "m_flStateTransitionTime",
        }
        for _, fname in ipairs(offset_fields) do
            local ok_f, val = pcall(function() return gr[fname] end)
            if ok_f and val and type(val) == "number" and val > 0 then
                local clock = raw_time - val
                if clock >= -5 and clock < 10800 then
                    clock_method_name = fname .. " (offset)"
                    clock_debug_info = string.format("field=%s offset=%.1f raw=%.1f clock=%.1f",
                        fname, val, raw_time, clock)
                    -- During pre-game (players connecting) the clock can be negative
                    return math.max(0, clock), is_paused
                end
            end
        end

        -- ─── Strategy 3: Enumerate ALL numeric fields looking for one ───
        -- that matches the pattern of a match clock (increases steadily,
        -- is roughly raw_time - some_offset, and < raw_time)
        -- This is a last-resort discovery mechanism.
        -- We look for any field that gives a small positive number < raw_time.
        -- We'll pick the smallest qualifying value (closest to a real clock).
        local best_clock = nil
        local best_field = nil
        local candidate_fields = {
            "m_flPauseTime", "m_flPausedSince",
            "m_flUnpauseTime", "m_flMatchStartTime",
            "m_flLevelStartTime", "m_flGameStateChangeTime",
            "m_flRoundStartTime", "m_flPreGameStartTime",
        }
        for _, fname in ipairs(candidate_fields) do
            local ok_f, val = pcall(function() return gr[fname] end)
            if ok_f and val and type(val) == "number" and val > 0 and raw_time > val then
                local clock = raw_time - val
                if clock >= 0 and clock < 10800 then
                    if not best_clock or clock < best_clock then
                        best_clock = clock
                        best_field = fname
                    end
                end
            end
        end
        if best_clock and best_field then
            clock_method_name = best_field .. " (candidate)"
            clock_debug_info = string.format("field=%s clock=%.1f", best_field, best_clock)
            return best_clock, is_paused
        end
    end

    -- ─── Fallback: raw game_time() ───
    -- This only works if the map was loaded exactly when the match started
    -- (unlikely but better than nothing). The user will see "raw fallback"
    -- in the debug output and know the clock is unreliable.
    clock_method_name = "raw fallback (UNRELIABLE)"
    clock_debug_info = string.format("raw=%.1f", raw_time)
    return nil, false
end

--- Check if the player is currently inside an active match.
---@return boolean
local function is_in_active_game()
    -- Check local pawn exists
    local pawn = entity_list.local_pawn()
    if not pawn or not pawn:valid() then
        return false
    end
    
    -- Check engine clock is running
    local raw_time = game_rules.game_time()
    if not raw_time or raw_time <= 0 then
        return false
    end
    
    -- Check there are multiple players (lobby only has 1-3)
    local players = entity_list.by_class_name("C_CitadelPlayerPawn")
    if not players or #players < MIN_PLAYERS_FOR_MATCH then
        return false
    end
    
    return true
end

-- ==========================================
-- Custom Toast Notification System (Render-based)
-- ==========================================
local TOAST_WIDTH    = 320
local TOAST_HEIGHT   = 60
local TOAST_MARGIN   = 8
local TOAST_DURATION = 5.0
local TOAST_FADE_IN  = 0.3
local TOAST_FADE_OUT = 0.5
local TOAST_SLIDE_PX = 80

local toast_queue = {} -- { title, text, icon_fn, start_time, duration }

---Show a toast notification
---@param title string  Notification title
---@param text  string  Notification body
---@param icon_fn function|nil  Icon drawing function
---@param duration number|nil  Duration in seconds (default TOAST_DURATION)
local function show_notification(title, text, icon_fn, duration)
    -- Enforce max toast limit to prevent memory build-up
    if #toast_queue >= MAX_TOASTS then
        table.remove(toast_queue, 1) -- drop oldest
    end

    local t = global_vars.curtime() or 0
    table.insert(toast_queue, {
        title      = title,
        text       = text,
        icon_fn    = icon_fn,
        start_time = t,
        duration   = duration or TOAST_DURATION,
    })
    print(string.format("[Event Notifier] %s: %s", title, text))
end

---Draw all active toasts
local function draw_toasts()
    local now = global_vars.curtime() or 0
    local screen_w = Render.ScreenSize().x
    local base_y = 120

    -- Remove expired toasts
    local alive = {}
    for _, toast in ipairs(toast_queue) do
        local elapsed = now - toast.start_time
        if elapsed < toast.duration + TOAST_FADE_OUT then
            table.insert(alive, toast)
        end
    end
    toast_queue = alive

    -- Draw each toast
    for i, toast in ipairs(toast_queue) do
        local elapsed = now - toast.start_time
        local total = toast.duration + TOAST_FADE_OUT

        -- Alpha: fade in -> solid -> fade out
        local alpha = 1.0
        if elapsed < TOAST_FADE_IN then
            alpha = elapsed / TOAST_FADE_IN
        elseif elapsed > toast.duration then
            alpha = 1.0 - ((elapsed - toast.duration) / TOAST_FADE_OUT)
        end
        alpha = math.max(0, math.min(1, alpha))

        -- Slide: from right during fade-in
        local slide_offset = 0
        if elapsed < TOAST_FADE_IN then
            slide_offset = TOAST_SLIDE_PX * (1.0 - (elapsed / TOAST_FADE_IN))
        end

        local tx = screen_w - TOAST_WIDTH - 20 + slide_offset
        local ty = base_y + (i - 1) * (TOAST_HEIGHT + TOAST_MARGIN)
        local a = math.floor(alpha * 255)

        -- Background (glassmorphism)
        local bg_clr = state._cached_bg_color or Color(18, 10, 13, 140)
        local blur_str = state._cached_blur_strength or 5
        local accent_clr = state._cached_accent_color or Color(240, 128, 166, 255)

        if blur_str > 0 then
            Render.Blur(Vec2(tx, ty), Vec2(tx + TOAST_WIDTH, ty + TOAST_HEIGHT), blur_str, math.floor(bg_clr.a * alpha), 8)
        end
        Render.FilledRect(
            Vec2(tx, ty), Vec2(tx + TOAST_WIDTH, ty + TOAST_HEIGHT),
            Color(bg_clr.r, bg_clr.g, bg_clr.b, math.floor(bg_clr.a * alpha)), 8
        )
        -- Border
        Render.Rect(
            Vec2(tx, ty), Vec2(tx + TOAST_WIDTH, ty + TOAST_HEIGHT),
            Color(accent_clr.r, accent_clr.g, accent_clr.b, math.floor(255 * alpha * 0.4)), 8, Enum.DrawFlags.None, 1
        )

        -- Accent bar on left
        local accent_color = Color(100, 200, 255, a)
        if toast.icon_fn == draw_icon_urn then
            accent_color = Color(255, 160, 50, a)
        elseif toast.icon_fn == draw_icon_boss then
            accent_color = Color(255, 70, 70, a)
        end
        Render.FilledRect(
            Vec2(tx, ty + 4), Vec2(tx + 3, ty + TOAST_HEIGHT - 4),
            accent_color, 2
        )

        -- Icon (drawn programmatically)
        local icon_size = 28
        local icon_cx = tx + 22
        local icon_cy = ty + TOAST_HEIGHT / 2
        if toast.icon_fn then
            toast.icon_fn(icon_cx, icon_cy, icon_size)
        end

        -- Title text
        local text_x = tx + 42
        Render.Text(FONT_HUD, 14, toast.title, Vec2(text_x, ty + 8), Color(255, 255, 255, a))

        -- Body text
        Render.Text(FONT_HUD, 12, toast.text, Vec2(text_x, ty + 28), Color(200, 210, 230, math.floor(a * 0.85)))
    end
end


-- ==========================================
-- Event Timing Calculations
-- ==========================================

---Returns the next rune spawn time, or -1 if runes are currently active
---@param cur_time number Current game time in seconds
---@return number
local function get_next_rune_time(cur_time)
    if cur_time < EVENT_START_RUNES then return EVENT_START_RUNES end

    if state.runes_alive then return -1 end

    if state.rune_pickup_time > 0 then
        local elapsed   = state.rune_pickup_time - EVENT_START_RUNES
        local cycle     = math.floor(elapsed / EVENT_INTERVAL_RUNES) + 1
        local next_time = EVENT_START_RUNES + cycle * EVENT_INTERVAL_RUNES
        if next_time <= cur_time then
            next_time = next_time + EVENT_INTERVAL_RUNES
        end
        return next_time
    end

    -- Fallback: pure math based on current time
    local elapsed = cur_time - EVENT_START_RUNES
    local cycle   = math.floor(elapsed / EVENT_INTERVAL_RUNES) + 1
    return EVENT_START_RUNES + cycle * EVENT_INTERVAL_RUNES
end

---Returns the next boss spawn time, or -1 if boss is alive / unknown
---@param cur_time number Current game time in seconds
---@return number
local function get_next_boss_time(cur_time)
    if cur_time < EVENT_START_BOSS then return EVENT_START_BOSS end
    if state.boss_alive then return -1 end

    if state.boss_death_time > 0 then
        local respawn = state.boss_death_time + EVENT_RESPAWN_BOSS
        if respawn > cur_time then return respawn end
        -- Reset stale death time so we don't keep computing a past respawn
        state.boss_death_time = -1
    end
    return -1
end

---Returns the next urn spawn time, or -1 if urn is on the map / unknown
---@param cur_time number Current game time in seconds
---@return number
local function get_next_urn_time(cur_time)
    if cur_time < EVENT_START_URN then return EVENT_START_URN end
    if state.urn_present then return -1 end

    if state.urn_pickup_time > 0 then
        local respawn = state.urn_pickup_time + EVENT_INTERVAL_URN
        if respawn > cur_time then return respawn end
        -- Reset stale pickup time
        state.urn_pickup_time = -1
    end
    return -1
end

-- ==========================================
-- Entity Scanning
-- ==========================================

-- Class names to detect rune entities on the map
local RUNE_CLASS_NAMES = {
    "C_Citadel_PickupRune",
    "C_CitadelPickupRune",
    "C_Citadel_Rune",
    "C_CitadelRune",
    "C_DOTA_Item_Rune",
    "C_Citadel_BuffPickup",
}

-- Class names to detect soul urn entities on the map
local URN_CLASS_NAMES = {
    "C_Citadel_SoulIdol",
    "C_Citadel_IdolPickup",
    "C_SoulIdol",
    "C_Citadel_IdolReturn",
}

---Scan for any alive entity matching any of the given class names
---@param class_names string[]
---@return boolean
local function scan_entities_for_class(class_names)
    for _, name in ipairs(class_names) do
        local ents = entity_list.by_class_name(name)
        if ents then
            for _, ent in ipairs(ents) do
                if ent and ent:valid() and ent:is_alive() then
                    return true
                end
            end
        end
    end
    return false
end

---Check if any rune entity is alive on the map
---@return boolean
local function scan_runes()
    return scan_entities_for_class(RUNE_CLASS_NAMES)
end

---Check if the soul urn is on the ground (not being carried by a player)
---@return boolean
local function scan_urn()
    local players = entity_list.by_class_name("C_CitadelPlayerPawn")

    -- 1. Check urn entities on the ground
    for _, name in ipairs(URN_CLASS_NAMES) do
        local ents = entity_list.by_class_name(name)
        if ents then
            for _, ent in ipairs(ents) do
                if ent and ent:valid() then
                    local ok, alive = pcall(function() return ent:is_alive() end)
                    local ok2, dormant = pcall(function() return ent:is_dormant() end)

                    if alive and not dormant then
                        -- Check proximity to players (carrier detection)
                        local urn_pos      = ent:get_origin()
                        local near_player  = false
                        if players then
                            for _, p in ipairs(players) do
                                if p and p:valid() then
                                    local p_pos = p:get_origin(); local dist = 9999; if p_pos then dist = math.sqrt((p_pos.x - urn_pos.x)^2 + (p_pos.y - urn_pos.y)^2 + (p_pos.z - urn_pos.z)^2) end
                                    if dist < 150 then
                                        near_player = true
                                        break
                                    end
                                end
                            end
                        end

                        if not near_player then
                            return true -- Urn on ground, not near anyone
                        end
                    end
                end
            end
        end
    end

    -- 2. Secondary check via modifier states (carrier holding urn)
    if players then
        for _, p in ipairs(players) do
            if p and p:valid() then
                for _, sid in ipairs(URN_CARRIER_STATES) do
                    local ok, holding = pcall(function() return p:has_modifier_state(sid) end); if ok and holding then
                        return false -- Being carried
                    end
                end
            end
        end
    end

    return false
end

---Check if the mid boss is alive
---@return boolean
local function scan_boss()
    local boss_ents = entity_list.by_class_name("C_Citadel_MidBoss")
    local boss = boss_ents and boss_ents[1]
    return boss and boss:valid() and boss:is_alive()
end

-- ==========================================
-- Match Reset Detection
-- ==========================================

---Detects a new match (game time resets to near-zero) and clears state
---@param cur_time number
local function check_match_reset(cur_time)
    if state.last_match_time > 0 and cur_time < state.last_match_time - 10 then
        -- Game time jumped backwards significantly → new match
        print("[Event Notifier] Match reset detected. Clearing state.")
        local saved_hud = {
            is_dragging = state.is_dragging,
            is_resizing = state.is_resizing,
            drag_offset = state.drag_offset,
        }
        state = create_initial_state()
        state.is_dragging = saved_hud.is_dragging
        state.is_resizing = saved_hud.is_resizing
        state.drag_offset = saved_hud.drag_offset
        toast_queue = {}
        clock_method_name = "not detected"
    end
    state.last_match_time = cur_time
end

-- ==========================================
-- Menu Setup
-- ==========================================
local menu_root     = Menu.Create("Miscellaneous", "Utility", "Visuals", "Event Notifier", "⚙ General")
local ui_enable     = menu_root:Switch("Enable Notifier", true)
local ui_lead_time  = menu_root:Slider("Notification Lead Time (s)", 5, 60, 25)

menu_root:Button("Test Notifier", function()
    show_notification("TEST NOTIFICATION", "The notification system is working!", draw_icon_test)
end)

local menu_hud = Menu.Create("Miscellaneous", "Utility", "Visuals", "Event Notifier", "📺 HUD Settings")
local ui_hud_enable = menu_hud:Switch("Show Timer HUD", true)
local ui_hud_lock   = menu_hud:Switch("Lock HUD Position", false)

-- Theme Settings (Defaulted to New.json style)
local ui_accent_color  = menu_hud:ColorPicker("Accent Color", Color(240, 128, 166, 255))
local ui_header_color  = menu_hud:ColorPicker("Header Color", Color(46, 31, 36, 153))
local ui_bg_color      = menu_hud:ColorPicker("Background Color", Color(18, 10, 13, 140))
local ui_blur_strength = menu_hud:Slider("Blur Strength", 0, 10, 5)

-- HUD Persistence (using sliders to save across sessions)
local ui_hud_x = menu_hud:Slider("HUD X", 0, 3840, 100)
local ui_hud_y = menu_hud:Slider("HUD Y", 0, 2160, 100)
local ui_hud_w = menu_hud:Slider("HUD Width", 100, 500, 200)
local ui_hud_h = menu_hud:Slider("HUD Height", 50, 400, 120)

local menu_runes     = Menu.Create("Miscellaneous", "Utility", "Visuals", "Event Notifier", "💎 Runes")
local ui_runes_enable = menu_runes:Switch("Enable Rune Alerts", true)

local menu_urn       = Menu.Create("Miscellaneous", "Utility", "Visuals", "Event Notifier", "🏺 Soul Urn")
local ui_urn_enable  = menu_urn:Switch("Enable Urn Alerts", true)

local menu_boss      = Menu.Create("Miscellaneous", "Utility", "Visuals", "Event Notifier", "👹 Mid Boss")
local ui_boss_enable = menu_boss:Switch("Enable Mid Boss Alerts", true)

-- ==========================================
-- Chat Alerts Menu
-- ==========================================
local menu_chat       = Menu.Create("Miscellaneous", "Utility", "Visuals", "Event Notifier", "💬 Chat Alerts")
local ui_chat_enable  = menu_chat:Switch("Enable Team Chat Alerts", false)
local ui_chat_lead    = menu_chat:Slider("Chat Alert Lead Time (s)", 5, 60, 25)
local ui_chat_runes   = menu_chat:Switch("Chat Rune Alerts", true)
local ui_chat_urn     = menu_chat:Switch("Chat Soul Urn Alerts", true)
local ui_chat_boss    = menu_chat:Switch("Chat Mid Boss Alerts", true)

menu_chat:Button("Test Chat Alert", function()
    send_team_chat("[Event Notifier] Test message — chat alerts are working!")
end)

-- ==========================================
-- Debug Menu
-- ==========================================
local menu_debug = Menu.Create("Miscellaneous", "Utility", "Visuals", "Event Notifier", "🐛 Debug")
local ui_debug_overlay = menu_debug:Switch("Show Clock Debug Overlay", false)

menu_debug:Button("Test Team Chat", function()
    send_team_chat("[Debug] Team chat test — if you see this, chat works!")
    show_notification("DEBUG", "Team chat test sent. Check game chat.", draw_icon_test)
end)

menu_debug:Button("Dump Schema Fields", function()
    local raw = game_rules.game_time()
    print(string.format("[Event Notifier] ═══ SCHEMA DUMP ═══ (raw_time=%.1f)", raw or -1))
    
    local ok_gr, gr = pcall(function() return game_rules.get() end)
    if not ok_gr or not gr then
        print("[Event Notifier] game_rules.get() not available!")
        show_notification("DEBUG", "game_rules.get() NOT available", draw_icon_test, 6)
        return
    end
    
    -- Dump ALL known and candidate fields
    local fields = {
        -- Time fields
        "m_flGameStartTime", "m_flMatchClockStartTime", "m_flMatchClockTime",
        "m_flGameTime", "m_fGameTime", "m_flStateTransitionTime",
        "m_flPauseTime", "m_flPausedSince", "m_flUnpauseTime",
        "m_flMatchStartTime", "m_flLevelStartTime", "m_flGameStateChangeTime",
        "m_flRoundStartTime", "m_flPreGameStartTime",
        "m_flStartTime", "m_flSpawnTime", "m_flMapLoadTime",
        -- State fields
        "m_nGameState", "m_nMatchState", "m_bGameStarted",
        "m_bGamePaused", "m_bIsPaused", "m_bFreezePeriod",
        "m_bMatchClockPaused", "m_bPaused",
        "m_bWarmupPeriod", "m_bInMatch", "m_bInPreGame",
        -- Other
        "m_nRoundNumber", "m_nPauseCount",
        "m_iPauseTeam", "m_nTotalPausedTicks",
    }
    
    local found_count = 0
    for _, f in ipairs(fields) do
        local ok, val = pcall(function() return gr[f] end)
        if ok and val ~= nil then
            found_count = found_count + 1
            local val_str = tostring(val)
            if type(val) == "number" and val > 1000 then
                -- Likely an engine timestamp — show as offset from raw_time
                val_str = string.format("%.2f (raw-this = %.2f)", val, raw - val)
            elseif type(val) == "number" then
                val_str = string.format("%.4f", val)
            end
            print(string.format("  [%s] = %s (%s)", f, val_str, type(val)))
        end
    end
    
    print(string.format("[Event Notifier] ═══ Found %d fields ═══", found_count))
    show_notification("DEBUG — SCHEMA DUMP",
        string.format("Found %d fields. Check console.", found_count),
        draw_icon_test, 8.0)
end)

menu_debug:Button("Show Match Time", function()
    local raw = game_rules.game_time()
    local match, paused = get_match_clock()
    local players = entity_list.by_class_name("C_CitadelPlayerPawn")
    local player_count = players and #players or 0
    local in_game = is_in_active_game()
    
    local info = string.format(
        "Raw: %.1fs | Match: %s | Method: %s | Paused: %s | Players: %d | InGame: %s",
        raw or -1,
        match and string.format("%.1fs (%d:%02d)", match, math.floor(match/60), math.floor(match%60)) or "nil",
        clock_method_name,
        tostring(paused),
        player_count,
        tostring(in_game)
    )
    
    print("[Event Notifier] DEBUG: " .. info)
    print("[Event Notifier] DEBUG detail: " .. clock_debug_info)
    show_notification("DEBUG — MATCH TIME", info, draw_icon_test, 8.0)
end)

-- ==========================================
-- HUD Implementation
-- ==========================================

local HEADER_HEIGHT   = 24
local TIMER_ROW_H     = 22
local HUD_PADDING_BOT = 8

---Draw the in-game timer HUD panel
---@param cur_time number  Current match clock time
---@param is_paused boolean  Whether the game is paused
local function draw_hud(cur_time, is_paused)
    if not state._cached_hud_enable then return end
    
    local lock_state = state._cached_hud_lock
    local x, y = state._cached_hud_x, state._cached_hud_y
    local w, h = state._cached_hud_w, state._cached_hud_h
    
    local mouse_pos = input.cursor_pos()
    local l_down = input.is_down(Enum.ButtonCode.KEY_MOUSE1)
    
    -- Handle Dragging and Resizing
    if not lock_state then
        local header_h = 24
        local resize_size = 15
        
        local in_header = mouse_pos.x >= x and mouse_pos.x <= x + w and mouse_pos.y >= y and mouse_pos.y <= y + header_h
        local in_resize = mouse_pos.x >= x + w - resize_size and mouse_pos.x <= x + w and mouse_pos.y >= y + h - resize_size and mouse_pos.y <= y + h
        
        if l_down then
            if not state.is_dragging and not state.is_resizing then
                if in_resize then
                    state.is_resizing = true
                elseif in_header then
                    state.is_dragging = true
                    state.drag_offset = Vec2(mouse_pos.x - x, mouse_pos.y - y)
                end
            end
            
            if state.is_dragging then
                local new_x = math.floor(mouse_pos.x - state.drag_offset.x)
                local new_y = math.floor(mouse_pos.y - state.drag_offset.y)
                ui_hud_x:Set(new_x)
                ui_hud_y:Set(new_y)
                -- Apply immediately for snappier dragging
                state._cached_hud_x = new_x
                state._cached_hud_y = new_y
                x, y = new_x, new_y
            elseif state.is_resizing then
                local new_w = math.max(150, math.floor(mouse_pos.x - x))
                local new_h = math.max(80, math.floor(mouse_pos.y - y))
                ui_hud_w:Set(new_w)
                ui_hud_h:Set(new_h)
                state._cached_hud_w = new_w
                state._cached_hud_h = new_h
                w, h = new_w, new_h
            end
        else
            state.is_dragging = false
            state.is_resizing = false
        end
    end
    
    -- Background
    local bg_clr = state._cached_bg_color or Color(18, 10, 13, 140)
    local header_clr = state._cached_header_color or Color(46, 31, 36, 153)
    local accent_clr = state._cached_accent_color or Color(240, 128, 166, 255)
    local blur_str = state._cached_blur_strength or 5
    local border_clr = state.is_dragging and accent_clr or Color(150, 150, 150, 100)
    
    if blur_str > 0 then
        Render.Blur(Vec2(x, y), Vec2(x + w, y + h), blur_str, bg_clr.a, 6)
    end
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + h), bg_clr, 6)
    Render.Rect(Vec2(x, y), Vec2(x + w, y + h), border_clr, 6, Enum.DrawFlags.None, 2)
    
    -- Header
    Render.FilledRect(Vec2(x, y), Vec2(x + w, y + 24), header_clr, 6, Enum.DrawFlags.RoundCornersTop)
    -- Accent line underneath header
    Render.FilledRect(Vec2(x, y + 24), Vec2(x + w, y + 26), accent_clr, 0)
    
    Render.Text(FONT_HUD, 14, "EVENT TIMERS", Vec2(x + 10, y + 4), Color(255, 255, 255, 200))
    
    -- Content
    local draw_y = y + 30
    local icon_size = 16
    local icon_pad = icon_size + 6
    
    local function draw_timer(label, target_time, color, icon_fn)
        local time_left = target_time - cur_time
        local text = ""
        if target_time == -1 then
            text = "ACTIVE"
            color = Color(100, 255, 100, 255)
        elseif time_left <= 0 then
            text = "READY"
            color = Color(255, 200, 0, 255)
        else
            text = string.format("%d:%02d", math.floor(time_left / 60), math.floor(time_left % 60))
        end
        
        -- Draw icon
        if icon_fn then
            icon_fn(x + 6 + icon_size / 2, draw_y + 7, icon_size)
        end
        
        Render.Text(FONT_HUD, 14, label, Vec2(x + icon_pad + 4, draw_y), Color(240, 240, 240, 255))
        local ts = Render.TextSize(FONT_HUD, 14, text)
        Render.Text(FONT_HUD, 14, text, Vec2(x + w - ts.x - 10, draw_y), color)
        draw_y = draw_y + 22
    end
    
    if state._cached_ui_runes then
        draw_timer("Runes:", get_next_rune_time(cur_time), Color(100, 200, 255, 255), draw_icon_rune)
    end
    if state._cached_ui_urn then
        draw_timer("Soul Urn:", get_next_urn_time(cur_time), Color(255, 150, 50, 255), draw_icon_urn)
    end
    if state._cached_ui_boss then
        draw_timer("Mid Boss:", get_next_boss_time(cur_time), Color(255, 80, 80, 255), draw_icon_boss)
    end
    
    -- Resize handle visual
    if not lock_state then
        Render.FilledRect(Vec2(x + w - 10, y + h - 10), Vec2(x + w - 2, y + h - 2), Color(255, 255, 255, 100), 2)
    end
end


-- ==========================================
-- Main Logic Callbacks
-- ==========================================

---Draws a debug text overlay showing clock info
local function draw_debug_overlay()
    if not ui_debug_overlay:Get() then return end
    
    local raw = game_rules.game_time()
    local text = string.format("DEBUG | Method: %s | Raw: %.1f", clock_method_name, raw or -1)
    if clock_debug_info ~= "" then
        text = text .. " | " .. clock_debug_info
    end
    
    Render.Text(FONT_HUD, 14, text, Vec2(10, 350), Color(255, 0, 0, 255))
end

-- Throttle entity scanning (every 0.5s instead of every frame)
local last_scan_time = 0
local SCAN_INTERVAL  = 0.5

-- Throttle clock reads to reduce overhead (every frame is fine for display,
-- but we cache the value per-frame to avoid calling get() multiple times)
local cached_match_time = nil
local cached_is_paused  = false
local cache_frame       = -1

-- Force initialize cache to safe values
state._cached_ui_runes = true
state._cached_ui_urn = true
state._cached_ui_boss = true
state._cached_lead = 25
state._cached_hud_enable = true
state._cached_hud_lock = false
state._cached_hud_x = 100
state._cached_hud_y = 100
state._cached_hud_w = 200
state._cached_hud_h = 120

callback.on_draw:set(function()
    -- Wrap everything in pcall so a single error doesn't kill the script
    local draw_ok, draw_err = pcall(function()
        if not ui_enable:Get() then return end

        -- Debug overlay (always draw if enabled, even outside match)
        draw_debug_overlay()

        -- ============================================================
        -- Only run timers/scanning when INSIDE an active match.
        -- This prevents the HUD from showing/counting in the main menu,
        -- hero select, loading screens, or spectator mode.
        -- ============================================================
        if not is_in_active_game() then
            -- Not in a game: if we WERE in a game before, reset state
            -- so that timers don't carry stale data into the next match.
            if state.was_in_game then
                print("[Event Notifier] Left match — pausing timers.")
                state.was_in_game = false
                clock_method_name = "not detected"
            end
            -- Still draw pending toasts (e.g. "Test" button pressed from menu)
            draw_toasts()
            return
        end

        -- ============================================================
        -- Get the REAL match clock. This MUST be synchronized with the
        -- in-game HUD timer. If we can't get it, don't show timers
        -- (showing wrong timers is worse than showing nothing).
        -- ============================================================
        local cur_frame = global_vars.framecount() or 0
        if cur_frame ~= cache_frame then
            cached_match_time, cached_is_paused = get_match_clock()
            cache_frame = cur_frame
        end

        local cur_time  = cached_match_time
        local is_paused = cached_is_paused

        if not cur_time then
            -- Can't determine match time — show HUD with "SYNCING..." message
            if ui_hud_enable:Get() then
                local x, y = ui_hud_x:Get(), ui_hud_y:Get()
                local w = ui_hud_w:Get()
                Render.FilledRect(Vec2(x, y), Vec2(x + w, y + 50), Color(20, 20, 30, 180), 6)
                Render.Rect(Vec2(x, y), Vec2(x + w, y + 50), Color(255, 200, 50, 150), 6, Enum.DrawFlags.None, 2)
                Render.FilledRect(Vec2(x, y), Vec2(x + w, y + HEADER_HEIGHT), Color(40, 45, 60, 200), 6, Enum.DrawFlags.RoundCornersTop)
                Render.Text(FONT_HUD, 14, "EVENT TIMERS", Vec2(x + 10, y + 4), Color(255, 255, 255, 200))
                Render.Text(FONT_HUD, 12, "⏳ Syncing with match clock...", Vec2(x + 10, y + 28), Color(255, 200, 50, 200))
            end
            draw_toasts()
            return
        end

        -- Mark that we are now in a game
        if not state.was_in_game then
            print(string.format("[Event Notifier] Entered match — clock synced via: %s (%.1fs)",
                clock_method_name, cur_time))
            state.was_in_game = true
        end

        -- If game is paused, still draw the HUD but don't process events
        if is_paused then
            draw_hud(cur_time, true)
            draw_toasts()
            return
        end

        -- Detect match resets (new game)
        check_match_reset(cur_time)

        local lead_time = ui_lead_time:Get()

        -- 1. Scan Entities (throttled)
        -- Use global_vars.curtime() for scan throttling (not match clock)
        -- because match clock can pause but we still want consistent scan rate
        local real_now = global_vars.curtime() or 0
        if real_now - last_scan_time >= SCAN_INTERVAL then
            last_scan_time = real_now

            -- Rune scanning
            local runes_now = scan_runes()
            if not state.runes_alive and runes_now then
                -- Runes just spawned → notify
                if ui_runes_enable:Get() and state.last_rune_spawn_notif ~= cur_time then
                    show_notification("RUNES SPAWNED", "Runes are now on the map!", draw_icon_rune)
                    state.last_rune_spawn_notif = cur_time
                end
            elseif state.runes_alive and not runes_now then
                -- Runes were just picked up
                state.rune_pickup_time = cur_time
            end
            state.runes_alive = runes_now

            -- Boss scanning
            local boss_now = scan_boss()
            if not state.boss_alive and boss_now then
                -- Boss just appeared
                if ui_boss_enable:Get() and state.last_boss_spawn_notif ~= cur_time then
                    show_notification("MID BOSS ALIVE", "The Mid Boss has spawned!", draw_icon_boss)
                    state.last_boss_spawn_notif = cur_time
                end
            elseif state.boss_alive and not boss_now then
                -- Boss just died
                state.boss_death_time = cur_time
            end
            state.boss_alive = boss_now

            -- Urn scanning
            local urn_now = scan_urn()
            if not state.urn_present and urn_now then
                -- Urn just appeared on map
                if ui_urn_enable:Get() and state.last_urn_spawn_notif ~= cur_time then
                    show_notification("SOUL URN AVAILABLE", "The Soul Urn is on the map!", draw_icon_urn)
                    state.last_urn_spawn_notif = cur_time
                end
            elseif state.urn_present and not urn_now then
                -- Urn was just picked up / delivered
                state.urn_pickup_time = cur_time
            end
            state.urn_present = urn_now
            
            -- Cache UI values that we use continuously inside on_draw
            state._cached_ui_runes = ui_runes_enable:Get()
            state._cached_ui_urn = ui_urn_enable:Get()
            state._cached_ui_boss = ui_boss_enable:Get()
            state._cached_lead = ui_lead_time:Get()
            
            -- Maintain HUD color + blur cache
            state._cached_accent_color = ui_accent_color:Get()
            state._cached_header_color = ui_header_color:Get()
            state._cached_bg_color = ui_bg_color:Get()
            state._cached_blur_strength = ui_blur_strength:Get()
            state._cached_hud_enable = ui_hud_enable:Get()
            state._cached_hud_lock = ui_hud_lock:Get()
            if not state.is_dragging then
                state._cached_hud_x = ui_hud_x:Get()
                state._cached_hud_y = ui_hud_y:Get()
            end
            if not state.is_resizing then
                state._cached_hud_w = ui_hud_w:Get()
                state._cached_hud_h = ui_hud_h:Get()
            end
        end

        -- 2. Check Pre-event Notifications (countdown warnings)
        -- Runes
        if ui_runes_enable:Get() then
            local next_rune = get_next_rune_time(cur_time)
            if next_rune ~= -1 then
                local diff = next_rune - cur_time
                if diff <= lead_time and diff > 0 and state.last_rune_notif < next_rune then
                    show_notification("RUNES SPAWNING", string.format("Runes will spawn in %d seconds!", math.floor(diff)), draw_icon_rune)
                    state.last_rune_notif = next_rune
                end
            end
        end

        -- Urn
        if ui_urn_enable:Get() then
            local next_urn = get_next_urn_time(cur_time)
            if next_urn ~= -1 then
                local diff = next_urn - cur_time
                if diff <= lead_time and diff > 0 and state.last_urn_notif < next_urn then
                    show_notification("SOUL URN", string.format("Soul Urn respawning in %d seconds!", math.floor(diff)), draw_icon_urn)
                    state.last_urn_notif = next_urn
                end
            end
        end

        -- Boss
        if ui_boss_enable:Get() then
            local next_boss = get_next_boss_time(cur_time)
            if next_boss ~= -1 then
                local diff = next_boss - cur_time
                if diff <= lead_time and diff > 0 and state.last_boss_notif < next_boss then
                    show_notification("MID BOSS", string.format("Mid Boss appearing in %d seconds!", math.floor(diff)), draw_icon_boss)
                    state.last_boss_notif = next_boss
                end
            end
        end

        -- 3. Chat Alerts (team chat warnings)
        if ui_chat_enable:Get() then
            local chat_lead = ui_chat_lead:Get()
            
            -- Runes chat
            if ui_chat_runes:Get() and ui_runes_enable:Get() then
                local next_rune = get_next_rune_time(cur_time)
                if next_rune ~= -1 then
                    local diff = next_rune - cur_time
                    if diff <= chat_lead and diff > 0 and state.last_rune_chat < next_rune then
                        send_team_chat(string.format("[!] RUNES in %ds — get to bridge!", math.floor(diff)))
                        state.last_rune_chat = next_rune
                    end
                end
            end
            
            -- Urn chat
            if ui_chat_urn:Get() and ui_urn_enable:Get() then
                local next_urn = get_next_urn_time(cur_time)
                if next_urn ~= -1 then
                    local diff = next_urn - cur_time
                    if diff <= chat_lead and diff > 0 and state.last_urn_chat < next_urn then
                        send_team_chat(string.format("[!] SOUL URN in %ds — prepare!", math.floor(diff)))
                        state.last_urn_chat = next_urn
                    end
                end
            end
            
            -- Boss chat
            if ui_chat_boss:Get() and ui_boss_enable:Get() then
                local next_boss = get_next_boss_time(cur_time)
                if next_boss ~= -1 then
                    local diff = next_boss - cur_time
                    if diff <= chat_lead and diff > 0 and state.last_boss_chat < next_boss then
                        send_team_chat(string.format("[!] MID BOSS in %ds — group up!", math.floor(diff)))
                        state.last_boss_chat = next_boss
                    end
                end
            end
        end

        -- 4. Draw HUD & Toasts
        draw_hud(cur_time, is_paused)
        draw_toasts()
    end)

    if not draw_ok and draw_err then
        print("[Event Notifier] Error in on_draw: " .. tostring(draw_err))
    end
end)

print(string.format("[Event Notifier] v%s Loaded Successfully", SCRIPT_VERSION))
