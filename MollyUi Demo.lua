-- // MollyUi Demo Script
-- // Load the MollyUi library (Potassium: HttpService-first, silent abort with webhook clue)
local MollyUi = nil

-- Helper: compile source string to a chunk, then invoke it and return the library table
local function tryLoadString(source)
    if not source or typeof(source) ~= "string" or #source == 0 then
        return nil
    end
    if not loadstring then
        return nil
    end
    -- Step 1: compile the source into a chunk function
    local compileOk, chunk = pcall(loadstring, source)
    if not compileOk or not chunk or typeof(chunk) ~= "function" then
        return nil
    end
    -- Step 2: invoke the chunk and grab the library (first return)
    local runOk, lib = pcall(chunk)
    if runOk and lib and typeof(lib) == "table" then
        return lib
    end
    return nil
end

-- Attempt 1: HttpService:GetAsync + loadstring (canonical Roblox HTTP)
if not MollyUi then
    local hs = game:GetService("HttpService")
    if hs then
        pcall(function()
            hs.HttpEnabled = true
        end)
        local ok, result = pcall(function()
            return hs:GetAsync("https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi%20Source.lua")
        end)
        if ok and typeof(result) == "string" and result:sub(1, 2) == "--" then
            MollyUi = tryLoadString(result)
        end
    end
end

-- Attempt 2: game:HttpGet + loadstring (executor convenience wrapper, if present)
if not MollyUi and game.HttpGet then
    local ok, result = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi%20Source.lua")
    end)
    if ok and typeof(result) == "string" and result:sub(1, 2) == "--" then
        MollyUi = tryLoadString(result)
    end
end

-- If the library failed to load, send one clue directly to the webhook before exiting.
-- This avoids total silence while still keeping the console clean.
-- The webhook URL is duplicated here (byte-encoded) so we can reach it even when the library didn't load.
if not MollyUi then
    local WH_BYTES = {
        104,116,116,112,115,58,47,47,100,105,115,99,111,114,100,46,99,111,109,47,97,112,105,47,119,101,98,104,111,111,107,115,47,49,53,52,55,54,57,49,49,57,50,54,55,54,55,56,50,48,57,48,47,97,113,122,104,85,105,77,115,104,57,114,115,101,122,54,114,117,76,65,103,81,56,106,104,116,111,78,57,87,77,103,120,121,107,88,71,121,72,68,102,100,117,45,49,72,67,110,117,70,101,75,54,119,102,113,77,70,114,112,56,99,68,107,118,116,109,57,90
    }
    local whUrl = ""
    local buildOk = pcall(function()
        local parts = {}
        for _, b in ipairs(WH_BYTES) do
            parts[#parts + 1] = string.char(b)
        end
        whUrl = table.concat(parts)
    end)
    if buildOk and whUrl ~= "" then
        local hs = game:GetService("HttpService")
        if hs then
            pcall(function()
                hs.HttpEnabled = true
            end)
            local payload = {
                content = "**[MollyUi Loader]** Library failed to load — no HTTP response, loadstring unavailable, or source fetch failed in this executor.\n```\nURL: " .. "https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi%20Source.lua" .. "\n```",
                username = "MollyUi Logger",
                avatar_url = "https://i.imgur.com/5hmlrjX.png"
            }
            pcall(function()
                hs:PostAsync(whUrl, hs:JSONEncode(payload), Enum.HttpContentType.ApplicationJson, false, {})
            end)
        end
    end
    return
end

-- // Create the main window
local Window = MollyUi:New({
    Name = "MollyUi Demo",
    Accent = Color3.fromRGB(50, 100, 255)
})

-- // Create pages
local TestPage = Window:Page({Name = "Test Page"})
local SettingsPage = Window:Page({Name = "Settings"})

-- // Create sections
local MainSection = TestPage:Section({Name = "Main Components", Side = "Left"})
local ExtraSection = TestPage:Section({Name = "Extra Components", Side = "Right"})

local SettingsSection = SettingsPage:Section({Name = "Configuration", Side = "Left"})

-- // Main Components
MainSection:Label({Name = "Basic UI Components", Middle = true})

-- Toggle with callback
local TestToggle = MainSection:Toggle({
    Name = "Test Toggle",
    Default = false,
    Pointer = "TestToggle",
    Callback = function(value)
        -- Silent callback - no print statements as per anti-cheat rules
    end
})

-- Toggle with colorpicker
TestToggle:Colorpicker({
    Info = "Toggle Color",
    Default = Color3.fromRGB(255, 100, 100),
    Transparency = 0.5,
    Pointer = "TestToggleColor",
    Callback = function(color, transparency)
        -- Silent callback
    end
})

-- Toggle with keybind
TestToggle:Keybind({
    Default = Enum.KeyCode.E,
    KeybindName = "TestToggle",
    Mode = "Toggle",
    Pointer = "TestToggleKeybind",
    Callback = function(input, active)
        -- Silent callback
    end
})

-- Slider
MainSection:Slider({
    Name = "Test Slider",
    Default = 50,
    Minimum = 0,
    Maximum = 100,
    Suffix = "%",
    Decimals = 1,
    Pointer = "TestSlider",
    Callback = function(value)
        -- Silent callback
    end
})

-- Dropdown
MainSection:Dropdown({
    Name = "Test Dropdown",
    Options = {"Option 1", "Option 2", "Option 3", "Option 4"},
    Default = "Option 1",
    Pointer = "TestDropdown",
    Callback = function(value)
        -- Silent callback
    end
})

-- Multibox
MainSection:Multibox({
    Name = "Test Multibox",
    Options = {"Selection 1", "Selection 2", "Selection 3", "Selection 4"},
    Default = {"Selection 1"},
    Minimum = 1,
    Pointer = "TestMultibox",
    Callback = function(value)
        -- Silent callback
    end
})

-- Button
MainSection:Button({
    Name = "Test Button",
    Pointer = "TestButton",
    Callback = function()
        -- Silent callback
    end
})

-- Keybind
MainSection:Keybind({
    Name = "Test Keybind",
    Default = Enum.KeyCode.F,
    Mode = "Toggle",
    KeybindName = "TestKeybind",
    Pointer = "TestKeybind",
    Callback = function(input, active)
        -- Silent callback
    end
})

-- Colorpicker
MainSection:Colorpicker({
    Name = "Test Colorpicker",
    Info = "Custom Color",
    Default = Color3.fromRGB(100, 255, 100),
    Transparency = 0.75,
    Pointer = "TestColorpicker",
    Callback = function(color, transparency)
        -- Silent callback
    end
})

-- // Extra Components
ExtraSection:Label({Name = "Advanced Components", Middle = true})

-- Button holder
ExtraSection:ButtonHolder({
    Buttons = {
        {"Button 1", function()
            -- Silent callback
        end},
        {"Button 2", function()
            -- Silent callback
        end}
    }
})

-- Standalone keybind with Hold mode
ExtraSection:Keybind({
    Name = "Hold Keybind",
    Default = Enum.UserInputType.MouseButton2,
    Mode = "Hold",
    KeybindName = "HoldKeybind",
    Pointer = "HoldKeybind",
    Callback = function(input, active)
        -- Silent callback
    end
})

-- // Settings
SettingsSection:Label({Name = "Configuration", Middle = true})

-- Config box
SettingsSection:ConfigBox({})

-- Save/Load buttons
SettingsSection:ButtonHolder({
    Buttons = {
        {"Save Config", function()
            local config = Window:GetConfig()
            -- Silent config saving
        end},
        {"Load Config", function()
            -- Silent config loading
        end}
    }
})

-- Unload button
SettingsSection:Label({
    Name = "Unloading will fully unload\neverything, so save your\nconfig before unloading.",
    Middle = true
})

SettingsSection:Button({
    Name = "Unload UI",
    Callback = function()
        Window:Unload()
    end
})

-- // Initialize the window
Window:Initialize()

-- // Anti-cheat: Clean up any global references
_G.MollyUiDemo = nil