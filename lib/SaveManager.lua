--[[
	SaveManager.lua -- config persistence for lib/Library.lua
	Portable: uses only Roblox Instances + HttpService(JSON). File IO is guarded
	behind `if writefile/makefolder/listfiles/delfile then` so the core library
	still loads on environments without an executor filesystem.

	Usage:
		local Library  = loadstring(game:HttpGet(".../lib/Library.lua"))()
		local Window   = Library:New({Name="Demo"})
		local SaveManager = loadstring(game:HttpGet(".../lib/SaveManager.lua"))()
		SaveManager:Init(Library)
		Library.SaveManager = SaveManager
		-- inside a "Config" section:
		SaveManager:BuildConfigSection(section)
--]]
local HttpService = game:GetService("HttpService")

local function colorToHex(c)
	return string.format("%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end
local function hexToColor(h)
	h = h:gsub("#", "")
	local r, g, b = tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
	return Color3.fromRGB(r or 0, g or 0, b or 0)
end

local function resolveLibrary()
	return _G.Library or (typeof(getgenv) == "function" and getgenv().Library)
end

local SaveManager = {
	-- executor-provided filesystem APIs (nil on vanilla Studio)
	ConfigFile = nil,
	FoldersConfigured = false,
	IgnoreIndentifiers = {},   -- pointers to skip when saving/loading
	Parser = {                 -- per-type (de)serializers, driven by Library.pointers[].Type
		Toggle     = { Parse = function(self, self2) return self.Value end, Sync = function(self, self2, v) self:SetValue(v) end },
		Slider     = { Parse = function(self, self2) return self.Value end, Sync = function(self, self2, v) self:SetValue(v) end },
		Button     = { Parse = function(self, self2) return nil end, Sync = function(self, self2, v) end },
		Dropdown   = { Parse = function(self, self2) return self.Value end, Sync = function(self, self2, v) self:SetValue(v) end },
		Multibox   = { Parse = function(self, self2) return self.Value end, Sync = function(self, self2, v) self:SetValue(v) end },
		Keybind    = { Parse = function(self, self2) return self.Value.Name end, Sync = function(self, self2, v)
				if typeof(v) == "EnumItem" and v.EnumType == Enum.KeyCode then
					-- already an EnumItem
				elseif type(v) == "string" then
					v = (self.Library and self.Library.ResolveKeyCode and self.Library.ResolveKeyCode(v)) or Enum.KeyCode.E
				else
					v = Enum.KeyCode.E
				end
				self:SetValue(v)
			end },
		Colorpicker= { Parse = function(self, self2) local c = self.Value; return {Color = colorToHex(c.Color), Transparency = tonumber(c.Transparency) or 1} end,
		               Sync = function(self, self2, v) if type(v) == "table" then self:SetValue(hexToColor(v.Color), tonumber(v.Transparency) or 1) else self:SetValue(hexToColor(v), 1) end end },
		Input      = { Parse = function(self, self2) return self.Value end, Sync = function(self, self2, v) self:SetValue(v) end },
		Label      = { Parse = function(self, self2) return nil end, Sync = function(self, self2, v) end },
		Divider    = { Parse = function(self, self2) return nil end, Sync = function(self, self2, v) end },
	},
	Registry = {},
	Folder = "rbx-menus_configs",
}
SaveManager.__index = SaveManager

function SaveManager:Init(Library)
	self.Library = Library
	self:ConfigureFolders()
	self.Registry = Library.pointers or {}
	self.ConfigFile = nil
	-- try to autoload the last-saved config
	if Library.SaveOnLoad then
		local autoload = self:GetAutoloadName()
		if autoload then
			local ok, err = pcall(function() self:Load(autoload, true) end)
			if not ok then Library:CaptureError(err, "autoload config") end
		end
	end
	return self
end

function SaveManager:ConfigureFolders()
	if self.FoldersConfigured then return end
	if makefolder and not isfolder(self.Folder) then
		pcall(makefolder, self.Folder)
	end
	self.FoldersConfigured = true
end

function SaveManager:GetConfigFileName(Name)
	return self.Folder .. "/" .. Name .. ".json"
end

-- Build a table of {pointer = value} for all registered widgets, honoring IgnoreIndentifiers.
function SaveManager:BuildSaveTable()
	local data = {}
	for pointer, entry in pairs(self.Registry) do
		if not self.IgnoreIndentifiers[pointer] then
			local parser = self.Parser[entry.Type]
			local value = parser and parser.Parse(entry.Object, entry.Object) or entry.Get()
			data[pointer] = value
		end
	end
	return data
end

function SaveManager:Save(Name)
	if not self.Library then self:Init(resolveLibrary()) end
	self:ConfigureFolders()
	if not Name or Name == "" then Name = self.ConfigFile or "config" end
	local data = self:BuildSaveTable()
	local json
	local ok, enc = pcall(function() return HttpService:JSONEncode(data) end)
	if ok then json = enc end
	if not writefile then
		if self.Library then self.Library:Toast("Save requires an executor with writefile", "error", 2) end
		return false, nil
	end
	local wok, werr = pcall(function() writefile(self:GetConfigFileName(Name), json or "{}") end)
	if not wok then
		if self.Library then self.Library:Toast("Save failed: " .. tostring(werr), "error", 2) end
		return false, nil
	end
	self.ConfigFile = Name
	self:SetAutoloadName(Name)
	return true, Name
end

function SaveManager:Load(Name, suppressNotify)
	if not self.Library then self:Init(resolveLibrary()) end
	if not Name or Name == "" then Name = self.ConfigFile end
	if not Name then
		if not suppressNotify and self.Library then self.Library:Toast("No config selected.", "warn", 2) end
		return false
	end
	if not readfile then
		if not suppressNotify and self.Library then self.Library:Toast("Load requires an executor with readfile", "error", 2) end
		return false
	end
	local path = self:GetConfigFileName(Name)
	local ok, content = pcall(readfile, path)
	if not ok then
		if not suppressNotify and self.Library then self.Library:CaptureError(content, "readfile " .. path) end
		return false
	end
	local decoded = HttpService:JSONDecode(content)
	for pointer, value in pairs(decoded) do
		if not self.IgnoreIndentifiers[pointer] then
			local entry = self.Registry[pointer]
			if entry then
				local parser = self.Parser[entry.Type]
				if parser and parser.Sync then
					local success, err = pcall(parser.Sync, entry.Object, entry.Object, value)
					if not success then
						if not suppressNotify and self.Library then self.Library:CaptureError("Sync failed for " .. tostring(pointer) .. ": " .. tostring(err), "parser") end
					end
				else
					entry.Set(value)
				end
			end
		end
	end
	self.ConfigFile = Name
	self:SetAutoloadName(Name)
	if not suppressNotify then self.Library:Toast("Loaded config: " .. Name, "success", 3) end
	return true
end

function SaveManager:Delete(Name)
	self:ConfigureFolders()
	if not Name or Name == "" then Name = self.ConfigFile end
	if not Name then return false end
	if not delfile then return false end
	local path = self:GetConfigFileName(Name)
	if listfiles then
		local ok, _ = pcall(readfile, path)
		if not ok then return false end
	end
	pcall(delfile, path)
	if self.ConfigFile == Name then self.ConfigFile = nil end
	return true
end

function SaveManager:GetConfigNames()
	self:ConfigureFolders()
	if not listfiles then return {} end
	local files = {}
	local ok, result = pcall(listfiles, self.Folder)
	if ok and result then
		for _, f in ipairs(result) do
			if f:sub(-5) == ".json" then
				local name = f:match("([^/\\]+)%.json$")
				if name then files[#files + 1] = name end
			end
		end
	end
	return files
end

function SaveManager:SetAutoloadName(Name)
	if not writefile then return end
	self:ConfigureFolders()
	if Name then
		writefile(self.Folder .. "/autoload.txt", Name)
	else
		pcall(delfile, self.Folder .. "/autoload.txt")
	end
end

function SaveManager:GetAutoloadName()
	if not readfile then return nil end
	self:ConfigureFolders()
	local ok, content = pcall(readfile, self.Folder .. "/autoload.txt")
	if ok and content and content ~= "" then return content end
	return nil
end

-- Build a "Config" section UI: Dropdown of saved configs + name TextBox + Save/Load/Delete buttons.
-- Requires a Section created via Section:Dropdown / Section:TextBox / Section:Button.
function SaveManager:BuildConfigSection(Section)
	assert(Section, "SaveManager:BuildConfigSection: Section required")

	self.ConfigDropdown = Section:Dropdown({
		Name = "Saved configs",
		Options = self:GetConfigNames(),
		Callback = function(v) if v then self.ConfigFile = v end end,
	})

	self.NameInput = Section:TextBox({
		Name = "Config name",
		Default = "",
		Placeholder = "name",
		Callback = function(v) self.NewName = v end,
	})

	Section:Button({ Name = "Save", Callback = function()
		local name = self.NewName or self.ConfigFile
		if not name or name == "" then
			self.Library:Toast("Type a name and Save, or pick an existing config.", "warn", 3)
			return
		end
		local ok, err = self:Save(name)
		if ok then
			self.ConfigDropdown:SetOptions(self:GetConfigNames())
			self.ConfigDropdown:SetValue(name)
			self.Library:Toast("Saved config: " .. name, "success", 3)
		else
			self.Library:Toast("Save failed: " .. tostring(err), "error", 4)
		end
		self.NewName = nil
	end})

	Section:Button({ Name = "Load", Callback = function()
		local name = self.NameInput and self.NameInput:GetValue() or self.ConfigFile
		if not name or name == "" then name = self.ConfigFile end
		if not name then self.Library:Toast("No config selected.", "warn", 3); return end
		local ok = self:Load(name)
		if ok then self.ConfigDropdown:SetOptions(self:GetConfigNames()) end
	end})

	Section:Button({ Name = "Delete", Callback = function()
		local name = self.ConfigFile or (self.NameInput and self.NameInput:GetValue())
		if not name or name == "" then return end
		self:Delete(name)
		self.ConfigDropdown:SetOptions(self:GetConfigNames())
		self.ConfigFile = nil
	end})

	Section:Toggle({ Name = "Auto load", Pointer = "_autoload", Default = false, Callback = function(v)
		self:SetAutoloadName(v and (self.ConfigFile or "config") or nil)
	end})
end

return SaveManager
