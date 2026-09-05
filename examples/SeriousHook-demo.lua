--[[ ============================================================
    SeriousHook Demo
    Loads SeriousHook.lua from GitHub via loadstring and builds
    a full-featured demo UI exercising every library feature.

    HOW TO RUN (executor format):
      1. Push SeriousHook.lua to:
         https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/SeriousHook.lua
      2. Paste THIS file into your Roblox executor (Synapse X, Delta, etc.)
         while Counter Blox (or any game) is open

    The single critical line is the loadstring(game:HttpGet(url))() call —
    that is the "executor format" every Roblox menu script uses.

    GitHub path:  https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/SeriousHook.lua
    ============================================================ ]]

-- // Load the library from GitHub (raw URL inlined, executor format)
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/SeriousHook.lua"))()

-- // Create the main window
local Window = Library:New({
    Name   = "SeriousHook Demo",
    Size   = Vector2.new(560, 620),
    Accent = Color3.fromRGB(50, 100, 255),
})

-- // Build pages
local General     = Window:Page({Name = "General"})
local Editor      = Window:Page({Name = "Editor"})
local Appearance  = Window:Page({Name = "Appearance"})
local Data        = Window:Page({Name = "Data"})
local About       = Window:Page({Name = "About"})

-- ============================================================
-- General page
-- ============================================================
local GenMain = General:Section({Name = "Main Toggles", Side = "Left"})
local GenExtra = General:Section({Name = "Extra Controls", Side = "Right"})

GenMain:Toggle({
    Name     = "Enable Aim",
    Default  = false,
    Pointer  = "enable_aim",
    Callback = function(v)
        Window:Toast("Aim " .. (v and "enabled" or "disabled"), "info")
    end,
})

GenMain:Slider({
    Name        = "Smoothness",
    Minimum     = 1,
    Maximum     = 30,
    Default     = 1.5,
    Decimals    = 1,
    Pointer     = "aim_smoothness",
    Callback   = function(v)
        Window:Toast("Smoothness: " .. tostring(v), "info")
    end,
})

GenMain:Keybind({
    Name        = "Aim Key",
    Default     = Enum.KeyCode.E,
    KeybindName = "Aim Keybind",
    Mode        = "Hold",
    Pointer     = "aim_key",
    Callback    = function(key)
        Window:Toast("Aim key set to: " .. tostring(key), "success")
    end,
})

GenMain:Colorpicker({
    Name    = "Aimbot Color",
    Info    = "Color used for the aim indicator",
    Alpha   = 0.75,
    Default = Color3.fromRGB(255, 0, 0),
    Pointer = "aim_color",
    Callback = function(color, alpha)
        Window:Toast("Aimbot color updated", "success")
    end,
})

GenExtra:Dropdown({
    Name     = "Aimbot Mode",
    Options  = {"Relative", "Absolute", "Camera", "Camera Relative"},
    Default  = "Relative",
    Pointer  = "aim_mode",
    Callback = function(val)
        Window:Toast("Mode: " .. val, "info")
    end,
})

GenExtra:Multibox({
    Name     = "Hit Parts",
    Options  = {"Head", "Torso", "Arms", "Legs"},
    Default  = {"Head", "Torso"},
    Minimum  = 1,
    Pointer  = "aim_hitparts",
    Callback = function(selected)
        Window:Toast("Hit parts: " .. tostring(selected), "info")
    end,
})

GenExtra:Button({
    Name     = "Test Burst",
    Callback = function()
        Window:Toast("Burst fired!", "success")
    end,
})

-- ============================================================
-- Editor page — pure widget showcases
-- ============================================================
local EdMain = Editor:Section({Name = "Widgets", Side = "Left"})
local EdExtra = Editor:Section({Name = "Advanced", Side = "Right"})

EdMain:Label({Name = "Below is every widget type the library supports.", Middle = false})

EdMain:Toggle({
    Name    = "Widget Toggle",
    Default = true,
    Pointer = "widget_toggle",
})

EdMain:Slider({
    Name     = "Widget Slider",
    Minimum  = 0,
    Maximum  = 100,
    Default  = 50,
    Decimals = 0,
    Pointer  = "widget_slider",
})

EdMain:Button({
    Name     = "Press Me",
    Callback = function()
        Window:Toast("Button pressed!", "info")
    end,
})

EdMain:ButtonHolder({
    Buttons = {
        {"Load", function()
            Window:Toast("Load clicked", "info")
        end},
        {"Save", function()
            Window:Toast("Save clicked", "success")
        end},
        {"Reset", function()
            Window:Toast("Reset clicked", "warn")
        end},
    },
})

EdMain:Dropdown({
    Name    = "Dropdown Demo",
    Options = {"Option A", "Option B", "Option C", "Option D"},
    Default = "Option A",
    Pointer = "dropdown_demo",
    Callback = function(val)
        Window:Toast("Selected: " .. val, "info")
    end,
})

EdMain:Multibox({
    Name    = "Multibox Demo",
    Options = {"Red", "Green", "Blue", "Yellow"},
    Default = {"Red", "Blue"},
    Pointer = "multibox_demo",
    Callback = function(selected)
        Window:Toast("Multibox: " .. tostring(selected), "info")
    end,
})

EdMain:Keybind({
    Name        = "Widget Keybind",
    Default     = Enum.KeyCode.F,
    KeybindName = "Widget Keybind",
    Mode        = "Toggle",
    Pointer     = "widget_keybind",
    Callback    = function(key)
        Window:Toast("Keybind: " .. tostring(key), "success")
    end,
})

EdMain:Colorpicker({
    Name    = "Widget Color",
    Info    = "Pick any color",
    Alpha   = 1,
    Default = Color3.fromRGB(100, 100, 255),
    Pointer = "widget_color",
})

EdMain:ConfigBox({})

EdExtra:Toggle({
    Name    = "Extra Toggle",
    Default = false,
    Pointer = "extra_toggle",
})

EdExtra:Slider({
    Name     = "Extra Slider",
    Minimum  = 0,
    Maximum  = 10,
    Default  = 3.3,
    Decimals = 2,
    Pointer  = "extra_slider",
})

EdExtra:Button({
    Name     = "Secondary Action",
    Callback = function()
        Window:Toast("Secondary action", "info")
    end,
})

-- ============================================================
-- Appearance page — watermark, toasts, themes, stats
-- ============================================================
local AppMain = Appearance:Section({Name = "Visual Features", Side = "Left"})

AppMain:Label({Name = "Watermark"})
AppMain:Toggle({
    Name    = "Show Watermark",
    Default = true,
    Pointer = "show_watermark",
    Callback = function(v)
        Window:SetWatermark(v)
        Window:Toast("Watermark " .. (v and "shown" or "hidden"), "info")
    end,
})

AppMain:Label({Name = "Toast Notifications"})
AppMain:Button({
    Name     = "Toast: Info",
    Callback = function()
        Window:Toast("This is an info toast", "info", 2.5)
    end,
})
AppMain:Button({
    Name     = "Toast: Success",
    Callback = function()
        Window:Toast("Operation succeeded!", "success", 2.5)
    end,
})
AppMain:Button({
    Name     = "Toast: Warning",
    Callback = function()
        Window:Toast("Something looks off", "warn", 3)
    end,
})
AppMain:Button({
    Name     = "Toast: Error",
    Callback = function()
        Window:Toast("Something went wrong!", "error", 4)
    end,
})
AppMain:Button({
    Name     = "Toast: Stack Test (5 fast)",
    Callback = function()
        for i = 1, 5 do
            task.delay(i * 0.15, function()
                Window:Toast("Stack toast #" .. i, "info", 2)
            end)
        end
        Window:Toast("Stack test queued", "success", 1.5)
    end,
})
AppMain:Button({
    Name     = "Clear All Toasts",
    Callback = function()
        Window.toasts:Clear()
        Window:Toast("Toasts cleared", "info", 1.5)
    end,
})

AppMain:Label({Name = "Theme System"})
AppMain:ButtonHolder({
    Buttons = {
        {"Ocean Blue", function()
            Window:SetTheme({
                accent         = Color3.fromRGB(50, 100, 255),
                light_contrast = Color3.fromRGB(30, 30, 50),
                dark_contrast  = Color3.fromRGB(20, 20, 30),
                outline        = Color3.fromRGB(0, 0, 0),
                inline         = Color3.fromRGB(50, 50, 70),
                textcolor      = Color3.fromRGB(255, 255, 255),
                textborder     = Color3.fromRGB(0, 0, 0),
            })
            Window:Toast("Theme: Ocean Blue", "success")
        end},
        {"Forest", function()
            Window:SetTheme({
                accent         = Color3.fromRGB(50, 200, 80),
                light_contrast = Color3.fromRGB(30, 40, 30),
                dark_contrast  = Color3.fromRGB(20, 30, 20),
                outline        = Color3.fromRGB(0, 0, 0),
                inline         = Color3.fromRGB(50, 70, 50),
                textcolor      = Color3.fromRGB(255, 255, 255),
                textborder     = Color3.fromRGB(0, 0, 0),
            })
            Window:Toast("Theme: Forest", "success")
        end},
        {"Sunset", function()
            Window:SetTheme({
                accent         = Color3.fromRGB(255, 120, 50),
                light_contrast = Color3.fromRGB(50, 30, 20),
                dark_contrast  = Color3.fromRGB(30, 20, 10),
                outline        = Color3.fromRGB(0, 0, 0),
                inline         = Color3.fromRGB(70, 50, 30),
                textcolor      = Color3.fromRGB(255, 255, 255),
                textborder     = Color3.fromRGB(0, 0, 0),
            })
            Window:Toast("Theme: Sunset", "success")
        end},
        {"Midnight", function()
            Window:SetTheme({
                accent         = Color3.fromRGB(180, 180, 255),
                light_contrast = Color3.fromRGB(25, 25, 35),
                dark_contrast  = Color3.fromRGB(15, 15, 25),
                outline        = Color3.fromRGB(40, 40, 60),
                inline         = Color3.fromRGB(45, 45, 55),
                textcolor      = Color3.fromRGB(220, 220, 255),
                textborder     = Color3.fromRGB(40, 40, 60),
            })
            Window:Toast("Theme: Midnight", "success")
        end},
        {"Reset Default", function()
            Window:SetTheme({
                accent         = Color3.fromRGB(50, 100, 255),
                light_contrast = Color3.fromRGB(30, 30, 30),
                dark_contrast  = Color3.fromRGB(20, 20, 20),
                outline        = Color3.fromRGB(0, 0, 0),
                inline         = Color3.fromRGB(50, 50, 50),
                textcolor      = Color3.fromRGB(255, 255, 255),
                textborder     = Color3.fromRGB(0, 0, 0),
            })
            Window:Toast("Theme reset to default", "info")
        end},
    },
})

AppMain:Label({Name = "Stats Display"})
AppMain:Toggle({
    Name    = "Show FPS / Ping",
    Default = true,
    Pointer = "show_stats",
    Callback = function(v)
        Window:SetStats(v)
        Window:Toast("Stats " .. (v and "visible" or "hidden"), "info")
    end,
})

AppMain:Label({Name = "Keybinds List"})
AppMain:Toggle({
    Name    = "Show Keybinds List",
    Default = false,
    Pointer = "show_keybinds_list",
    Callback = function(v)
        if v then
            Window:ToggleKeybindsList()
            Window:Toast("Keybinds list opened", "info")
        else
            Window.keybindslist:Hide()
            Window:Toast("Keybinds list closed", "info")
        end
    end,
})

-- ============================================================
-- Data page — config save/load, unload
-- ============================================================
local DatMain = Data:Section({Name = "Configuration", Side = "Left"})

DatMain:Label({Name = "Config I/O lets you persist all Pointer values."})
DatMain:Button({
    Name     = "Save Config",
    Callback = function()
        local cfg = Window:GetConfig()
        -- In a real script you'd write cfg to a file, http post, etc.
        Window:Toast("Config saved (" .. tostring(#cfg) .. " chars)", "success")
        -- For demo, print to output
        print("[SeriousHook Demo] Config JSON:", cfg)
    end,
})

DatMain:Button({
    Name     = "Load Config (demo)",
    Callback = function()
        -- Demo: rebuild a config JSON with known pointer values
        local demoCfg = ([=[
        {
            "enable_aim": true,
            "aim_smoothness": 5.0,
            "aim_key": "E",
            "aim_color": {"Color": [0, 1, 0.5], "Transparency": 0.5},
            "aim_mode": "Camera",
            "aim_hitparts": ["Head", "Legs"],
            "widget_toggle": true,
            "widget_slider": 75,
            "dropdown_demo": "Option C",
            "multibox_demo": ["Red", "Yellow"],
            "widget_keybind": "G",
            "widget_color": {"Color": [0.4, 0.4, 1], "Transparency": 1},
            "extra_toggle": true,
            "extra_slider": 6.6,
            "show_watermark": true,
            "show_stats": true,
            "show_keybinds_list": true
        }
        ]=]):gsub("^%s*%n", ""):gsub("%s*%n%s*$", "")
        Window:LoadConfig(demoCfg)
        Window:Toast("Demo config loaded!", "success")
    end,
})

DatMain:Label({Name = "Use Save Config first, then Load Config to restore state."})

DatMain:Button({
    Name     = "Unload Library",
    Callback = function()
        Window:Unload()
        Window:Toast("Library unloaded. Re-run demo to reload.", "warn", 4)
    end,
})

-- ============================================================
-- About page
-- ============================================================
local AbMain = About:Section({Name = "Info", Side = "Left"})

AbMain:Label({Name = "SeriousHook", Middle = false})
AbMain:Label({Name = "A Roblox Luau menu library built on the Drawing API.", Middle = false})
AbMain:Label({Name = "", Middle = false})
AbMain:Label({Name = "Features:", Middle = false})
AbMain:Label({Name = "  - Draggable window with tabbed pages", Middle = false})
AbMain:Label({Name = "  - Watermark with live FPS / ping", Middle = false})
AbMain:Label({Name = "  - Toast notification stack (info/success/warn/error)", Middle = false})
AbMain:Label({Name = "  - Theme system (5 presets + custom)", Middle = false})
AbMain:Label({Name = "  - Keybinds list panel", Middle = false})
AbMain:Label({Name = "  - Config save / load via JSON", Middle = false})
AbMain:Label({Name = "  - All standard widgets: Toggle, Slider, Button,", Middle = false})
AbMain:Label({Name = "    ButtonHolder, Dropdown, Multibox, Keybind,", Middle = false})
AbMain:Label({Name = "    Colorpicker, Label, ConfigBox", Middle = false})
AbMain:Label({Name = "", Middle = false})
AbMain:Label({Name = "Usage:", Middle = false})
AbMain:Label({Name = "  local Lib = loadstring(game:HttpGet(url))()", Middle = false})
AbMain:Label({Name = "  local Win = Lib:New({Name = \"...\", Accent = ...})", Middle = false})
AbMain:Label({Name = "  local Page = Win:Page({Name = \"...\"})", Middle = false})
AbMain:Label({Name = "  local Sec  = Page:Section({Name = \"...\", Side = \"Left\"})", Middle = false})
AbMain:Label({Name = "  Win:Initialize()", Middle = false})

AbMain:Button({
    Name     = "Show Watermark Now",
    Callback = function()
        Window:SetWatermark(true)
        Window:Toast("Watermark toggled on", "info")
    end,
})

AbMain:Button({
    Name     = "Hide Watermark Now",
    Callback = function()
        Window:SetWatermark(false)
        Window:Toast("Watermark toggled off", "info")
    end,
})

AbMain:Button({
    Name     = "Open Keybinds List",
    Callback = function()
        Window:ToggleKeybindsList()
        Window:Toast("Keybinds list toggled", "info")
    end,
})

-- // Expose to the executor environment so other scripts / re-runs can reach it.
-- // getgenv() is preferred over _G for cross-script persistence in executors.
getgenv().SeriousHook = Library
getgenv().SeriousHookWindow = Window

-- ============================================================
-- Initialize
-- ============================================================
Window:Initialize()

-- // Welcome toast
task.delay(0.5, function()
    Window:Toast("SeriousHook Demo loaded — explore every tab!", "success", 4)
end)

-- // Also show a quick stack demo after a moment
task.delay(2, function()
    Window:Toast("Tip: toggle watermark, themes, and toasts in the Appearance tab", "info", 5)
end)
