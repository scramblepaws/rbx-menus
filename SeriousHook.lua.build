-- SeriousHook.lua — build script
-- Concatenates all src/ modules into a single loadstring-ready file.
-- Run with `lua build.lua` (host Lua) or paste into any Lua environment
-- that has filesystem access. Output: SeriousHook.lua in the project root.

local src_dir = "./src"
local out_path = "./SeriousHook.lua"

local function read(path)
	local f, err = io.open(path, "r")
	if not f then return nil, err end
	local s = f:read("*a")
	f:close()
	return s
end

local function write(path, content)
	local f, err = io.open(path, "w")
	if not f then return false, err end
	f:write(content)
	f:close()
	return true
end

-- Dependency order: base → core → nav → widgets → overlays → toasts
local files = {
	"init.lua",
	"Theme.lua",
	"Util.lua",
	"Window.lua",
	"Page.lua",
	"Section.lua",
	"Config.lua",
	"widgets/Label.lua",
	"widgets/Divider.lua",
	"widgets/Toggle.lua",
	"widgets/Slider.lua",
	"widgets/Button.lua",
	"widgets/DuoButton.lua",
	"widgets/Dropdown.lua",
	"widgets/MultiDropdown.lua",
	"widgets/Textbox.lua",
	"widgets/Keybind.lua",
	"widgets/Colorpicker.lua",
	"widgets/ConfigList.lua",
	"overlays/Watermark.lua",
	"overlays/Keylist.lua",
	"overlays/Cursor.lua",
	"Toasts.lua",
}

local parts = {}
for _, rel in ipairs(files) do
	local path = src_dir .. "/" .. rel
	local s, err = read(path)
	if not s then
		error("missing: " .. path .. " — " .. tostring(err))
	end
	table.insert(parts, s)
end

local joined = table.concat(parts, "\n")
local ok, err = write(out_path, joined)
if not ok then
	error("failed to write " .. out_path .. " — " .. tostring(err))
end

print("Built SeriousHook.lua from " .. #files .. " modules, " .. #parts .. " parts.")
print("Output: " .. out_path .. " (" .. #joined .. " bytes)")
