---@diagnostic disable: undefined-global, param-type-mismatch, inject-field
local script = {}

-- Visage Auto-Follow Script by Euphoria
-- Version: 1.1.0
-- Compatible with UC.zone API v2.0
--
-- NEW: Automatic language detection and localization!
-- The script now detects system language and adapts interface accordingly:
-- - Russian client: Russian interface
-- - English/other: English interface
-- Language detection updates automatically every 5 seconds

-- Language detection and localization
local function getLanguage()
    -- Try to detect system language from multiple sources
    -- Default to English if detection fails
    local lang = "en"
    
    -- Method 1: Check system environment variables (works in cheat menu)
    local os_locale = os.getenv("LANG") or os.getenv("LC_ALL") or os.getenv("LANGUAGE")
    if os_locale then
        if string.find(os_locale, "ru") or string.find(os_locale, "RU") or
           string.find(os_locale, "russian") or string.find(os_locale, "Russian") then
            lang = "ru"
        end
    end
    
    -- Method 2: Simple heuristic based on keyboard layout (works in cheat menu)
    if lang == "en" then
        -- Check if system is likely Russian based on common indicators
        -- This is a fallback method that doesn't require external commands
        local user_profile = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
        local computer_name = os.getenv("COMPUTERNAME") or os.getenv("HOSTNAME") or ""
        
        if (string.find(user_profile, "[\208\144-\209\143]") or string.find(computer_name, "[\208\144-\209\143]") or
            string.find(user_profile, "User") or string.find(computer_name, "PC")) then
            -- Additional checks for Russian systems
            local system_drive = os.getenv("SystemDrive") or "C:"
            local windows_dir = system_drive .. "\\Windows"
            
            -- Check if Russian language files exist (simple heuristic)
            local ru_indicators = {
                windows_dir .. "\\Help\\mui\\ru-RU",
                windows_dir .. "\\System32\\ru-RU",
                windows_dir .. "\\Resources\\Themes\\ru-RU"
            }
            
            for _, path in ipairs(ru_indicators) do
                local file = io.open(path, "r")
                if file then
                    file:close()
                    lang = "ru"
                    break
                end
            end
        end
    end
    
    -- Method 3: Try PowerShell with safety checks (may not work in cheat menu)
    if lang == "en" then
        local success, handle = pcall(io.popen, "powershell -Command \"Get-WinSystemLocale | Select-Object -ExpandProperty Name\" 2>nul")
        if success and handle then
            local result = handle:read("*a")
            handle:close()
            if result and (string.find(result, "ru") or string.find(result, "RU") or
                          string.find(result, "russian") or string.find(result, "Russian")) then
                lang = "ru"
            end
        end
    end
    
    -- Method 4: Try locale command with safety checks (may not work in cheat menu)
    if lang == "en" then
        local success, handle = pcall(io.popen, "locale 2>nul")
        if success and handle then
            local result = handle:read("*a")
            handle:close()
            if result and (string.find(result, "ru") or string.find(result, "RU") or
                          string.find(result, "russian") or string.find(result, "Russian")) then
                lang = "ru"
            end
        end
    end
    
    return lang
end

-- Update language detection periodically
local function updateLanguage()
    local new_lang = getLanguage()
    if new_lang ~= current_lang then
        current_lang = new_lang
        -- Language has changed, could trigger menu update here
    end
end

local current_lang = getLanguage()

-- Localization table
local localization = {
    ru = {
        enable = "Включить",
        follow_key = "Клавиша следования",
        familiars_following = "Фамилиары следуют (%d)",
        script_name = "Авто-Следование"
    },
    en = {
        enable = "Enable",
        follow_key = "Follow Key",
        familiars_following = "Familiars Following (%d)",
        script_name = "Auto-Follow"
    }
}

-- Get localized text
local function t(key)
    return localization[current_lang][key] or localization.en[key] or key
end

-- Add font loading at the top
local font = Render.LoadFont("Tahoma", 14, Enum.FontCreate.FONTFLAG_ANTIALIAS)

-- Menu setup with localized names
local menu = Menu.Create("Heroes", "Hero List", "Visage", "Main Settings", t("script_name"))
local ui = {}
ui.enable = menu:Switch(t("enable"), false, "\u{f1e3}")
ui.follow_key = menu:Bind(t("follow_key"), Enum.ButtonCode.KEY_NONE, "\u{f0b1}")

-- State variables
local my_hero = nil
local familiars = {}
local last_command_time = 0
local command_delay = 0.5 -- 500ms между командами
local last_key_press_time = 0
local status_alpha = 0
local last_lang_update = 0 -- For periodic language detection

-- Helper function to check if unit is a Visage familiar
local function isVisageFamiliar(npc)
    if not npc or not Entity.IsAlive(npc) then
        return false
    end
    
    local unit_name = NPC.GetUnitName(npc)
    return unit_name == "npc_dota_visage_familiar1" or 
           unit_name == "npc_dota_visage_familiar2" or 
           unit_name == "npc_dota_visage_familiar3"
end

-- Helper function to get all Visage familiars
local function getFamiliars()
    local found_familiars = {}
    local all_npcs = NPCs.GetAll()
    
    for _, npc in ipairs(all_npcs) do
        if isVisageFamiliar(npc) and Entity.IsControllableByPlayer(npc, Player.GetPlayerID(Players.GetLocal())) then
            table.insert(found_familiars, npc)
        end
    end
    
    return found_familiars
end

-- Helper function to check if hero is Visage
local function isVisageHero(hero)
    if not hero or not Entity.IsAlive(hero) then
        return false
    end
    
    local hero_name = NPC.GetUnitName(hero)
    return hero_name == "npc_dota_hero_visage"
end

-- Main auto-follow function
local function autoFollow()
    -- Check delay
    local current_time = os.clock()
    if current_time - last_command_time < command_delay then
        return
    end
    
    -- Double-check we are playing as Visage (safety check)
    if not my_hero or not isVisageHero(my_hero) then
        return
    end
    
    -- Get familiars
    familiars = getFamiliars()
    
    -- Issue move command to follow hero only if we have familiars
    if #familiars > 0 then
        for _, familiar in ipairs(familiars) do
            if Entity.IsAlive(familiar) and not NPC.IsWaitingToSpawn(familiar) then
                -- Use Player.PrepareUnitOrders for Move to Target command
                Player.PrepareUnitOrders(
                    Players.GetLocal(),
                    Enum.UnitOrder.DOTA_UNIT_ORDER_MOVE_TO_TARGET,
                    my_hero,
                    Vector(0, 0, 0),
                    nil,
                    Enum.PlayerOrderIssuer.DOTA_ORDER_ISSUER_PASSED_UNIT_ONLY,
                    familiar,
                    false, false, false, false,
                    "visage_auto_follow"
                )
            end
        end
        last_command_time = current_time
    end
end

-- Toggle auto-follow
local function toggleAutoFollow()
    auto_follow_enabled = not auto_follow_enabled
end

-- Callbacks
function script.OnUpdate()
    -- Update language detection periodically (every 5 seconds)
    local current_time = os.clock()
    if not last_lang_update or current_time - last_lang_update > 5.0 then
        updateLanguage()
        last_lang_update = current_time
    end
    
    -- Check if menu settings exist and are valid
    if not ui.enable or not ui.follow_key then
        return
    end
    
    -- Only work when script is enabled via switch
    if not ui.enable:Get() then
        return
    end
    
    -- Check if we are playing as Visage
    my_hero = Heroes.GetLocal()
    if not my_hero or not isVisageHero(my_hero) then
        return
    end
    
    -- Check for key press to make familiars follow
    if ui.follow_key:IsPressed() then
        autoFollow()
        last_key_press_time = os.clock()
        status_alpha = 255 -- Full opacity when key is pressed
    end
    
    -- Fade out effect
    if status_alpha > 0 then
        local fade_time = 2.0 -- 2 seconds to fade out
        local time_since_press = os.clock() - last_key_press_time
        if time_since_press < fade_time then
            status_alpha = math.floor(255 * (1 - time_since_press / fade_time))
        else
            status_alpha = 0
        end
    end
end

function script.OnDraw()
    -- Draw status indicator when script is enabled, we are Visage, and key was pressed recently
    if ui.enable:Get() and my_hero and Entity.IsAlive(my_hero) and isVisageHero(my_hero) and status_alpha > 0 then
        local pos = Entity.GetAbsOrigin(my_hero)
        if pos then
            -- Convert 3D position to 2D screen coordinates
            local screen_pos, on_screen = Render.WorldToScreen(pos + Vector(0, 0, 100)) -- Offset above hero
            
            if on_screen then
                -- Draw status text with localization
                local status_text = string.format(t("familiars_following"), #getFamiliars())
                local text_color = Color(120, 255, 120, status_alpha) -- Green with alpha
                
                -- Draw text using correct format (like in Axe script)
                Render.Text(font, 14, status_text, screen_pos + Vector(-60, -20), text_color)
                
                -- Draw small circles around familiars
                familiars = getFamiliars()
                for i, familiar in ipairs(familiars) do
                    if Entity.IsAlive(familiar) then
                        local fam_pos = Entity.GetAbsOrigin(familiar)
                        local fam_screen, fam_on_screen = Render.WorldToScreen(fam_pos)
                        
                        if fam_on_screen then
                            -- Draw small circle around familiar
                            Render.Circle(fam_screen, 15, Color(255, 200, 100, status_alpha), 2)
                        end
                    end
                end
            end
        end
    end
end

-- Initialize
function script.OnScriptLoad()
    -- Update language detection when script loads
    current_lang = getLanguage()
    
    -- Update menu names if needed (optional enhancement)
    -- This would require recreating menu items, which is complex
    -- For now, we'll use the detected language for text display
end

-- Initialize
function script.OnScriptsLoaded()
    -- Alternative place to update language
    current_lang = getLanguage()
end

return script
