--[[
	ThemeManager.lua -- theme selection/persistence for lib/Library.lua
	Portable: file I/O guarded behind executor FS APIs (nil on vanilla Studio).

	Usage:
		local ThemeManager = loadstring(game:HttpGet(".../lib/ThemeManager.lua"))()
		ThemeManager:Init(Library)
		Library.ThemeManager = ThemeManager
		-- inside a "Themes" section:
		ThemeManager:CreateThemeManager(section)
--]]
local HttpService = game:GetService("HttpService")

local ThemeManager = {}
ThemeManager.__index = ThemeManager

-- theme color keys the library exposes (mirrors Library.* exports)
ThemeManager.ThemeKeys = {
	Font = "Font", TextColor = "TextColor", TextColorSub = "TextColorSub",
	TextBorderColor = "TextBorderColor", BackgroundColor = "BackgroundColor",
	MainColor = "MainColor", AccentColor = "AccentColor", AccentColorDark = "AccentColorDark",
	OutlineColor = "OutlineColor", InlineColor = "InlineColor", RiskColor = "RiskColor",
}

ThemeManager._DefaultFont = (function(...)
	for _, name in ipairs({...}) do
		local ok, f = pcall(function() return Enum.Font[name] end)
		if ok and f then return f end
	end
	return Enum.Font.SourceSans
end)("Gotham", "GothamBook", "GothamSemibold", "SourceSans")

ThemeManager.BuiltInThemes = {
	Dark = {
		Font = ThemeManager._DefaultFont, FontSize = 13, FontSizeSmall = 11,
		TextColor = Color3.fromRGB(235, 235, 235), TextColorSub = Color3.fromRGB(170, 170, 180),
		TextBorderColor = Color3.fromRGB(0, 0, 0), BackgroundColor = Color3.fromRGB(20, 20, 22),
		MainColor = Color3.fromRGB(26, 26, 28), AccentColor = Color3.fromRGB(123, 43, 218),
		AccentColorDark = Color3.fromRGB(80, 25, 140), OutlineColor = Color3.fromRGB(0, 0, 0),
		InlineColor = Color3.fromRGB(45, 45, 47), RiskColor = Color3.fromRGB(255, 70, 70),
	},
	Light = {
		Font = ThemeManager._DefaultFont, FontSize = 13, FontSizeSmall = 11,
		TextColor = Color3.fromRGB(30, 30, 30), TextColorSub = Color3.fromRGB(80, 80, 90),
		TextBorderColor = Color3.fromRGB(0, 0, 0), BackgroundColor = Color3.fromRGB(240, 240, 242),
		MainColor = Color3.fromRGB(232, 232, 234), AccentColor = Color3.fromRGB(90, 90, 200),
		AccentColorDark = Color3.fromRGB(60, 60, 160), OutlineColor = Color3.fromRGB(200, 200, 204),
		InlineColor = Color3.fromRGB(215, 215, 219), RiskColor = Color3.fromRGB(220, 60, 60),
	},
	Violet = {
		Font = ThemeManager._DefaultFont, FontSize = 13, FontSizeSmall = 11,
		TextColor = Color3.fromRGB(240, 240, 250), TextColorSub = Color3.fromRGB(190, 190, 210),
		TextBorderColor = Color3.fromRGB(0, 0, 0), BackgroundColor = Color3.fromRGB(18, 14, 24),
		MainColor = Color3.fromRGB(26, 22, 32), AccentColor = Color3.fromRGB(160, 70, 230),
		AccentColorDark = Color3.fromRGB(110, 45, 170), OutlineColor = Color3.fromRGB(60, 50, 70),
		InlineColor = Color3.fromRGB(40, 36, 48), RiskColor = Color3.fromRGB(255, 80, 80),
	},
	Terminal = {
		Font = Enum.Font.Code, FontSize = 13, FontSizeSmall = 11,
		TextColor = Color3.fromRGB(0, 255, 0), TextColorSub = Color3.fromRGB(0, 200, 0),
		TextBorderColor = Color3.fromRGB(0, 0, 0), BackgroundColor = Color3.fromRGB(0, 0, 0),
		MainColor = Color3.fromRGB(0, 0, 0), AccentColor = Color3.fromRGB(0, 200, 0),
		AccentColorDark = Color3.fromRGB(0, 140, 0), OutlineColor = Color3.fromRGB(0, 200, 0),
		InlineColor = Color3.fromRGB(20, 20, 20), RiskColor = Color3.fromRGB(255, 80, 80),
	},
}

function ThemeManager:Init(Library)
	self.Library = Library
	self.Folder = "rbx-menus_themes"
	if makefolder and not pcall(isfolder, self.Folder) then
		pcall(makefolder, self.Folder)
	end
	return self
end

function ThemeManager:GetThemeNames()
	local names = {}
	for name in pairs(self.BuiltInThemes) do names[#names + 1] = name end
	table.sort(names)
	return names
end

function ThemeManager:ApplyTheme(name)
	local theme = self.BuiltInThemes[name]
	if not theme then return false end
	self.Library:SetTheme(theme)
	return true
end

function ThemeManager:GetCurrentTheme()
	local t = {}
	for _, key in next, self.ThemeKeys do
		local v = self.Library[key]
		if typeof(v) == "Color3" then
			t[key] = v
		elseif typeof(v) == "EnumItem" or type(v) == "number" or type(v) == "string" then
			t[key] = v
		end
	end
	return t
end

function ThemeManager:_colorToHex(c)
	if typeof(c) ~= "Color3" then return nil end
	return string.format("%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

function ThemeManager:SaveTheme(Name)
	if not Name or not writefile then return false end
	local serializable = {}
	for key, _ in pairs(self.ThemeKeys) do
		local v = self.Library[key]
		if typeof(v) == "Color3" then
			serializable[key] = self:_colorToHex(v)
		elseif typeof(v) == "EnumItem" then
			serializable[key] = v.Name
		elseif type(v) == "number" or type(v) == "string" then
			serializable[key] = v
		end
	end
	local json = HttpService:JSONEncode(serializable)
	if makefolder and not pcall(isfolder, self.Folder) then pcall(makefolder, self.Folder) end
	writefile(self.Folder .. "/" .. Name .. ".json", json)
	return true
end

function ThemeManager:LoadTheme(Name)
	if not Name or not readfile then return false end
	local ok, content = pcall(readfile, self.Folder .. "/" .. Name .. ".json")
	if not ok then return false end
	local theme = HttpService:JSONDecode(content)
	for k, v in pairs(theme) do
		if typeof(self.Library[k]) == "Color3" and type(v) == "string" then
			theme[k] = self:_hexToColor(v)
		elseif typeof(self.Library[k]) == "EnumItem" and type(v) == "string" then
			local ok2, resolved = pcall(function() return Enum.Font.FromString(v) end)  -- generic; only Font uses EnumItem
			theme[k] = (ok2 and resolved) or v
		end
	end
	self.Library:SetTheme(theme)
	return true
end

function ThemeManager:_hexToColor(hex)
	hex = hex:gsub("#", "")
	local r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
	return Color3.fromRGB(r or 0, g or 0, b or 0)
end

-- Build a section of theme controls: a Dropdown to switch built-ins + one Colorpicker
-- per color key that live-updates the library theme as you pick.
function ThemeManager:CreateThemeManager(Section)
	assert(Section, "ThemeManager:CreateThemeManager: Section required")
	assert(self.Library, "ThemeManager:Init(Library) must be called first")

	self.ThemeDropdown = Section:Dropdown({
		Name = "Preset",
		Options = self:GetThemeNames(),
		Callback = function(name)
			if self.BuiltInThemes[name] then
				self:ApplyTheme(name)
				self.Library:Toast("Theme: " .. name, "info", 2)
			end
		end,
	})

	self._ColorPickers = {}
	for _, key in ipairs(self.ThemeKeys) do
		local current = self.Library[key]
		if typeof(current) == "Color3" then
			local cp = Section:Colorpicker({
				Name = key,
				Default = current,
				Callback = function(color)
					self.Library[key] = color
					self.Library:SetTheme({ [key] = color })
				end,
			})
			self._ColorPickers[key] = cp
		end
	end

	Section:Button({ Name = "Save Theme", Callback = function()
		if self.ThemeDropdown and self.ThemeDropdown:GetValue() then
			local name = self.ThemeDropdown:GetValue()
			if self:SaveTheme(name) then
				self.Library:Toast("Theme saved: " .. name, "success", 3)
			else
				self.Library:Toast("Cannot save theme (no writefile).", "error", 3)
			end
		end
	end})

	return self._ColorPickers
end

return ThemeManager
