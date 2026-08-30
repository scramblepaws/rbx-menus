-- SeriousHook/src/Config.lua
-- Flags registry and persistence helpers.

local HttpService = game:GetService("HttpService")

-- Register a flag so it can be read/written via GetConfig/LoadConfig.
-- flag: string key (nil => no persistence for this widget)
-- getter: function() -> value
-- setter: function(value) -> ()
-- serializer: optional function(value) -> storable
-- deserializer: optional function(storable) -> value
function SeriousHook.Config:Register(flag, getter, setter, serializer, deserializer)
	if not flag then return end
	if typeof(flag) ~= "string" then
		warn("[SH] Config:Register - flag must be a string, got " .. typeof(flag))
		return
	end
	local entry = {
		get = getter,
		set = setter,
		serialize = serializer,
		deserialize = deserializer,
	}
	SeriousHook.Flags[flag] = entry
end

-- Get full config as a table (serializable JSON).
function SeriousHook.Config:GetConfig()
	local config = {}
	for flag, entry in pairs(SeriousHook.Flags) do
		if entry.serialize then
			config[flag] = entry.serialize(entry.get())
		else
			config[flag] = entry.get()
		end
	end
	return config
end

-- Apply a config table.
function SeriousHook.Config:LoadConfig(config)
	if typeof(config) ~= "table" then
		warn("[SH] Config:LoadConfig - expected table")
		return
	end
	for flag, value in pairs(config) do
		local entry = SeriousHook.Flags[flag]
		if entry then
			local v = value
			if entry.deserialize then
				v = entry.deserialize(value)
			end
			entry.set(v)
		end
	end
end

-- Save config to file as JSON.
function SeriousHook.Config:SaveConfig(name)
	local config = SeriousHook.Config:GetConfig()
	local json = HttpService:JSONEncode(config)
	local path = SeriousHook.folders.configs .. "/" .. name .. ".json"
	writefile(path, json)
	return json
end

-- Load config from file.
function SeriousHook.Config:LoadConfigFile(name)
	local path = SeriousHook.folders.configs .. "/" .. name .. ".json"
	if not isfile(path) then
		warn("[SH] Config:LoadConfigFile - file not found: " .. path)
		return
	end
	local json = readfile(path)
	local config = HttpService:JSONDecode(json)
	SeriousHook.Config:LoadConfig(config)
	return config
end

-- List saved configs.
function SeriousHook.Config:ListConfigs()
	local result = {}
	local folder = SeriousHook.folders.configs
	if not isfolder(folder) then return result end
	for _, file in ipairs(bfs:GetChildren(folder)) do
		if file:IsA("File") and string.sub(file.Name, -5) == ".json" then
			table.insert(result, string.sub(file.Name, 1, -6))
		end
	end
	table.sort(result)
	return result
end

-- Delete a config file.
function SeriousHook.Config:DeleteConfig(name)
	local path = SeriousHook.folders.configs .. "/" .. name .. ".json"
	if isfile(path) then
		deletefile(path)
	end
end

-- Autoload a config by name (call inside Initialize).
function SeriousHook.Config:Autoload(name)
	if name then
		SeriousHook.Config:LoadConfigFile(name)
	end
end

-- Export the Config table as a callable module for registration convenience.
SeriousHook.Config = SeriousHook.Config
return SeriousHook.Config
