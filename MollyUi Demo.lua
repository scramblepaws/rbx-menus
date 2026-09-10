-- // MollyUi Demo Script
-- // Load the MollyUi library (Potassium-compatible: multiple fallback strategies)
local MollyUi = nil
local loadError = nil

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

-- Attempt 0: loadfile (Lua standard — reads + compiles from file path in one call)
if not MollyUi then
    local ok, chunk = pcall(loadfile, "MollyUi Source.lua")
    if ok and chunk and typeof(chunk) == "function" then
        local runOk, lib = pcall(chunk)
        if runOk and lib and typeof(lib) == "table" then
            MollyUi = lib
        else
            loadError = runOk and "loadfile run returned non-table" or tostring(lib)
        end
    else
        loadError = ok and "loadfile failed" or tostring(chunk)
    end
end

-- Attempt 1: readfile + loadstring
if not MollyUi then
    local ok, result = pcall(readfile, "MollyUi Source.lua")
    if ok and typeof(result) == "string" and result:sub(1, 2) == "--" then
        MollyUi = tryLoadString(result)
        if not MollyUi then
            loadError = "readfile+loadstring failed"
        end
    else
        loadError = ok and "readfile returned non-source" or tostring(result)
    end
end

-- Attempt 2: HttpService:GetAsync + loadstring (canonical Roblox HTTP)
if not MollyUi then
    local ok, result = pcall(function()
        return game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi%20Source.lua")
    end)
    if ok and typeof(result) == "string" and result:sub(1, 2) == "--" then
        MollyUi = tryLoadString(result)
        if not MollyUi then
            loadError = "HTTP+loadstring failed"
        end
    else
        loadError = ok and "HTTP fetch returned non-source" or tostring(result)
    end
end

-- Attempt 3: game:HttpGet + loadstring (executor convenience wrapper, if present)
if not MollyUi and game.HttpGet then
    local ok, result = pcall(function()
        return game:HttpGet("https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi%20Source.lua")
    end)
    if ok and typeof(result) == "string" and result:sub(1, 2) == "--" then
        MollyUi = tryLoadString(result)
        if not MollyUi then
            loadError = "game:HttpGet+loadstring failed"
        end
    else
        loadError = ok and "game:HttpGet returned non-source" or tostring(result)
    end
end

-- Silent abort if library failed to load (anti-cheat: never expose loader failure to console)
if not MollyUi then
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