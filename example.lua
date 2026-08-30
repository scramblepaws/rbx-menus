-- example.lua — SeriousHook usage example
-- This file demonstrates all widgets, overlays, toasts, and config persistence.
-- Drop into an executor alongside SeriousHook.lua: dofile("SeriousHook.lua") then dofile("example.lua")

local SH = SeriousHook

-- ── Window ──────────────────────────────────────────────────────────────
local Win = SH:Window{
	title   = "SeriousHook Example",
	size    = Vector2.new(540, 620),
	accent  = Color3.fromRGB(105, 90, 255),
	fadeKey = Enum.KeyCode.RightShift,
}

-- ── Pages ───────────────────────────────────────────────────────────────
local AimPage  = Win:Page{name = "Aimbot"}
local VisPage  = Win:Page{name = "Visuals"}
local MiscPage = Win:Page{name = "Misc"}

-- ── Aimbot: MultiSection (Main + Settings) on the left ────────────────
local Main, SettingsTab = AimPage:MultiSection{
	tabs   = {"Main", "Settings"},
	side   = "left",
	height = 200,
}

-- ── Main tab widgets ──────────────────────────────────────────────────
local EnabledToggle = Main:Toggle{
	name     = "Enabled",
	default  = true,
	flag     = "aim_enabled",
	callback = function(v)
		print("[Aim] Enabled:", v)
	end,
}

EnabledToggle:AddColor{
	default  = Color3.fromRGB(255, 0, 0),
	alpha    = 0.2,
	flag     = "aim_color",
	callback = function(c, a)
		print("[Aim] Color:", c, a)
	end,
}

EnabledToggle:AddKeybind{
	default  = Enum.KeyCode.E,
	mode     = "Toggle",
	flag     = "aim_keybind",
	callback = function(k, active)
		print("[Aim] Keybind triggered:", k, "active:", active)
	end,
}

Main:Slider{
	name     = "FOV",
	min      = 0,
	max      = 360,
	default  = 90,
	suffix   = "°",
	decimals = 1,
	flag     = "aim_fov",
	callback = function(v)
		print("[Aim] FOV:", v)
	end,
}

Main:Dropdown{
	name     = "Target Bone",
	options  = {"Head", "Torso", "Legs", "Chest"},
	default  = "Head",
	flag     = "aim_bone",
	callback = function(v)
		print("[Aim] Bone:", v)
	end,
}

Main:MultiDropdown{
	name     = "Checks",
	options  = {"Visible", "Alive", "Team", "Closer"},
	default  = {"Visible", "Alive"},
	min      = 1,
	flag     = "aim_checks",
	callback = function(tbl)
		print("[Aim] Checks:", table.concat(tbl, ", "))
	end,
}

Main:Textbox{
	name        = "Custom Config Value",
	default     = "default",
	placeholder = "type here...",
	flag        = "aim_custom",
	callback = function(text)
		print("[Aim] Custom:", text)
	end,
}

-- ── Settings tab ──────────────────────────────────────────────────────
SettingsTab:Button{
	name = "Reset All",
	callback = function()
		print("[Aim] Reset clicked")
		SH:Notify("Settings reset", 2)
	end,
}

SettingsTab:DuoButton{
	buttons = {
		{"Save Config", function()
			Win:SaveConfig("aimbot_settings")
			SH:Success("Config saved!", 2)
		end},
		{"Load Config", function()
			Win:LoadConfig("aimbot_settings")
			SH:Success("Config loaded!", 2)
		end},
	},
}

-- ── Visuals page ──────────────────────────────────────────────────────
local ESP_Section = VisPage:Section{name = "ESP", side = "left"}
local ESP_Enabled = ESP_Section:Toggle{
	name     = "ESP Enabled",
	default  = true,
	flag     = "esp_enabled",
	callback = function(v)
		print("[Vis] ESP:", v)
	end,
}

ESP_Enabled:AddColor{
	default  = Color3.fromRGB(0, 255, 0),
	flag     = "esp_color",
	callback = function(c)
		print("[Vis] ESP Color:", c)
	end,
}

local WorldSection = VisPage:Section{name = "World", side = "right"}
WorldSection:Slider{
	name     = "World Brightness",
	min      = 0,
	max      = 3,
	default  = 1,
	decimals = 2,
	flag     = "world_brightness",
	callback = function(v)
		print("[Vis] Brightness:", v)
	end,
}

-- ── Misc page ─────────────────────────────────────────────────────────
local ConfigSection = MiscPage:Section{name = "Configs", side = "left"}
ConfigSection:ConfigList()

MiscPage:Section{name = "Actions", side = "right"}:Button{
	name = "Save Default",
	flag = "save_default",
	callback = function()
		Win:SaveConfig("default")
		SH:Success("Default config saved!", 2)
	end,
}

MiscPage:Section{name = "Actions", side = "right"}:Button{
	name = "Load Default",
	flag = "load_default",
	callback = function()
		Win:LoadConfig("default")
		SH:Success("Default config loaded!", 2)
	end,
}

-- ── Overlays ──────────────────────────────────────────────────────────
Win:Watermark{enabled = true}
Win:Keylist{enabled = true, position = Vector2.new(10, 0.4)}
Win:Cursor{enabled = true}

-- ── Toasts ────────────────────────────────────────────────────────────
SH:SetToastPosition("bottomRight")
SH:Toast{
	title    = "SeriousHook",
	message  = "Example loaded — press RightShift to toggle menu",
	type     = "success",
	duration = 4,
}

SH:Success("Example script initialized!", 3)

-- ── Boot ──────────────────────────────────────────────────────────────
Win:Initialize()
