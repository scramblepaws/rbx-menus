--[[
	demo.lua -- exercises every widget + SaveManager + ThemeManager against lib/Library.lua
	Portable Instance-based UI (works in Studio / Synapse / Script-Ware / Solara).

	Drop lib/ into a ModuleScript or load via loadstring(game:HttpGet(...));
	this demo assumes the three modules are served at a BASE url.
--]]
local BASE = "https://raw.githubusercontent.com/scramblepaws/rbx-menus/main"

-- Load a library module. Prefers a local readfile (offline/dev), falls back
-- to HttpGet so the same script works in an executor with network access.
local function loadModule(rel)
	local content
	if readfile then
		local ok, r = pcall(readfile, rel)
		if ok and r then content = r end
	end
	if not content and game.HttpGet then
		content = game:HttpGet(BASE .. "/" .. rel)
	end
	assert(content, "loadModule: could not load " .. rel .. " (try readfile or set BASE)")
	return loadstring(content)()
end

local Library       = loadModule("lib/Library.lua")
local SaveManager   = loadModule("lib/SaveManager.lua")
local ThemeManager  = loadModule("lib/ThemeManager.lua")

-- ---- Window ---------------------------------------------------------------
local Window = Library:New({
	Name      = "rbx-menus",
	Size      = Vector2.new(640, 700),
	Accent    = Color3.fromRGB(123, 43, 218),
	Center    = true,
})

-- ---- Pages ----------------------------------------------------------------
local Home   = Window:Page({Name = "Home"})
local Visual = Window:Page({Name = "Visual"})
local Config = Window:Page({Name = "Config"})
local Themes = Window:Page({Name = "Themes"})

-- ---- Home section (Left): toggles / sliders / buttons ---------------------
local Left = Home:Section({Name = "Player", Side = "Left"})

Left:Toggle({Name = "Auto Farm", Pointer = "autoFarm", Default = false,
	Callback = function(v) Library:Toast("Auto Farm: " .. tostring(v), "info", 2) end})

Left:Toggle({Name = "No-Clip (risky)", Pointer = "noclip", Default = false, Risky = true,
	Callback = function(v) Library:Toast("No-clip: " .. tostring(v), "warn", 2) end})

Left:Slider({Name = "Walk Speed", Pointer = "walkSpeed",
	Minimum = 0, Maximum = 100, Default = 16, Decimals = 0,
	Callback = function(v) Library:Toast("WalkSpeed -> " .. v, "info", 1.5) end})

Left:Slider({Name = "FOV", Pointer = "fov",
	Minimum = 0, Maximum = 120, Default = 70, Decimals = 1,
	Callback = function(v) Library:Toast("FOV -> " .. v, "info", 1.5) end})

Left:Button({Name = "Print Stats", Callback = function()
	Library:Toast(("FPS=%d PING=%dms"):format(Library.shared.fps, Library.shared.ping), "info", 3)
end})

Left:ButtonHolder({Name = "Quick actions", Buttons = {
	{"Rejoin", function() Library:Toast("Rejoin requested", "info", 2) end},
	{"Respawn", function() Library:Toast("Respawn requested", "info", 2) end},
}})

-- ---- Home section (Right): dropdowns / keybinds / color -------------------
local Right = Home:Section({Name = "Combat", Side = "Right"})

Right:Dropdown({Name = "Aim Mode", Pointer = "aimMode",
	Options = {"Silent","Smooth","None"}, Default = 1,
	Callback = function(v) Library:Toast("Aim: " .. v, "info", 2) end})

Right:Multibox({Name = "Wallbang Targets", Pointer = "targets",
	Options = {"Head","Body","Limbs"}, Default = {"Head"}, Minimum = 1,
	Callback = function(list) Library:Toast("Targets: " .. table.concat(list, ","), "info", 2) end})

Right:Keybind({Name = "Aim Toggle", Pointer = "aimKey",
	Default = Enum.KeyCode.E, Mode = "Toggle",
	Callback = function(key, pressed) Library:Toast(("Key %s: %s"):format(key.Name, tostring(pressed)), "info", 2) end})

Right:Colorpicker({Name = "Crosshair color", Pointer = "crosshairColor",
	Default = Color3.fromRGB(0, 255, 0), Info = "in-game crosshair tint",
	Callback = function(c) Library:Toast("Crosshair -> #"..c:ToHex(), "info", 2) end})

-- ---- Visual section -------------------------------------------------------
local VisLeft = Visual:Section({Name = "Rendering", Side = "Left"})

VisLeft:Toggle({Name = "ESP Enabled", Pointer = "esp", Default = true,
	Callback = function(v) Library:Toast("ESP: " .. tostring(v), "info", 2) end})

VisLeft:Label({Name = "Esp settings below", TextColor3 = Color3.fromRGB(200, 200, 220)})
VisLeft:TextBox({Name = "Player name filter", Pointer = "nameFilter", Default = "John",
	Callback = function(v) Library:Toast("Filter: " .. v, "info", 2) end})
VisLeft:Divider()
VisLeft:Label({Name = "misc"})
VisLeft:Colorpicker({Name = "Team color", Pointer = "teamColor", Default = Color3.fromRGB(80, 160, 255),
	Callback = function(c) Library:Toast("Team color -> #"..c:ToHex(), "info", 2) end})

local VisRight = Visual:Section({Name = "World", Side = "Right"})
VisRight:Toggle({Name = "Show dropped weapons", Pointer = "weapons", Default = false})
VisRight:Slider({Name = "Brightness", Pointer = "brightness", Minimum = 0, Maximum = 5, Default = 2, Decimals = 2})
VisRight:Dropdown({Name = "Skybox", Pointer = "skybox", Options = {"Default","Night","City"}, Default = 1})

-- ---- wiring managers ------------------------------------------------------
Library.SaveOnLoad = true
SaveManager:Init(Library)
Library.SaveManager = SaveManager
ThemeManager:Init(Library)
Library.ThemeManager = ThemeManager

SaveManager:BuildConfigSection(Config:Section({Name = "Configuration", Side = "Left"}))
ThemeManager:CreateThemeManager(Themes:Section({Name = "Themes", Side = "Left"}))

-- ---- extras ---------------------------------------------------------------
Window:SetWatermark(true)
Window:SetStats(true)

-- toggle the whole UI with RightControl (Library.ToggleKeybind)
Window:Initialize()

Library:OnUnload(function()
	Library:Toast("Unloaded.", "info", 2)
end)
