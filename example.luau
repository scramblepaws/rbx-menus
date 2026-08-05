--[[
	Amnesia UI - Example Script
	Desktop-style engineering UI matching the Figma design
	Includes fallback HTTP methods for executor compatibility
]]

local LIBRARY_URL = "https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/library.luau"

local function fetch(url)
	local content = nil

	-- Try game:HttpGet
	if not content then
		local ok, result = pcall(game.HttpGet, game, url)
		if ok and result and #result > 100 then
			content = result
		end
	end

	-- Try request
	if not content and request then
		local ok, result = pcall(request, { Url = url, Method = "GET" })
		if ok and result and result.Body and #result.Body > 100 then
			content = result.Body
		end
	end

	-- Try http_request
	if not content and http_request then
		local ok, result = pcall(http_request, { Url = url, Method = "GET" })
		if ok and result and result.Body and #result.Body > 100 then
			content = result.Body
		end
	end

	-- Try syn.request
	if not content and syn and syn.request then
		local ok, result = pcall(syn.request, { Url = url, Method = "GET" })
		if ok and result and result.Body and #result.Body > 100 then
			content = result.Body
		end
	end

	return content
end

local librarySource = fetch(LIBRARY_URL)
if not librarySource then
	error("[amnesia] failed to fetch library")
	return
end

local Library = loadstring(librarySource)()
if not Library then
	error("[amnesia] failed to load library")
	return
end

-- ============================================================
-- WINDOW
-- ============================================================

local Window = Library:CreateWindow({
	Title = "amnesia [v1.0] | developed by dutu1337",
	Size = Vector2.new(580, 420),
	Position = UDim2.fromOffset(100, 100),
})

-- ============================================================
-- SIDEBAR
-- ============================================================

local Aimbot = Window:CreateSidebarCategory("aimbot")
local Visuals = Window:CreateSidebarCategory("visuals")
local Misc = Window:CreateSidebarCategory("misc")
local Config = Window:CreateSidebarCategory("config")

-- ============================================================
-- TABS
-- ============================================================

local Legitbot = Window:CreateTab("legitbot")
local Triggerbot = Window:CreateTab("triggerbot")
local Other = Window:CreateTab("other")

-- ============================================================
-- LEGITBOT - LEFT - MAIN
-- ============================================================

local Main = Legitbot:CreateGroupbox("main", "Left")

Main:Toggle("enabled", false, function(v)
	warn("aimbot:", v)
end)

Main:Toggle("remove recoil", false, function(v)
	warn("recoil:", v)
end)

Main:Toggle("remove spread", false, function(v)
	warn("spread:", v)
end)

Main:Slider("field of view", {
	Min = 0,
	Max = 100,
	Default = 34,
}, function(v)
	warn("fov:", v)
end)

Main:Slider("hitchance", {
	Min = 0,
	Max = 100,
	Default = 64,
}, function(v)
	warn("hitchance:", v)
end)

Main:Dropdown("target selection", {
	"slot 1", "slot 2", "slot 3", "slot 4", "slot 5",
}, "slot 1", function(v)
	warn("target:", v)
end)

Main:Dropdown("hitboxes", {
	"head", "head, body", "head, body, limbs", "body", "limbs",
}, "head, body", function(v)
	warn("hitboxes:", v)
end)

Main:Button("save", function()
	warn("saved!")
	Library:Notify("config saved", 2)
end)

Main:Separator("just a text!")

-- ============================================================
-- LEGITBOT - RIGHT - ACCURACY
-- ============================================================

local Accuracy = Legitbot:CreateGroupbox("accuracy", "Right")

local ConfigName = Accuracy:Textbox("config name", "dutu1337", function(v)
	warn("config name:", v)
end)

for i = 1, 9 do
	Accuracy:Button("slot " .. i, function()
		warn("slot", i)
		ConfigName:SetText("slot_" .. i)
	end)
end

-- ============================================================
-- TRIGGERBOT - LEFT
-- ============================================================

local TBMain = Triggerbot:CreateGroupbox("trigger settings", "Left")

TBMain:Toggle("enabled", false, function(v)
	warn("trigger:", v)
end)

TBMain:Slider("delay", {
	Min = 0,
	Max = 500,
	Default = 50,
	Suffix = "ms",
}, function(v)
	warn("delay:", v)
end)

TBMain:Slider("hitchance", {
	Min = 0,
	Max = 100,
	Default = 80,
}, function(v)
	warn("tb hitchance:", v)
end)

TBMain:Dropdown("target part", {
	"Head", "HumanoidRootPart", "UpperTorso",
}, "Head", function(v)
	warn("tb target:", v)
end)

-- ============================================================
-- TRIGGERBOT - RIGHT
-- ============================================================

local TBCond = Triggerbot:CreateGroupbox("conditions", "Right")

TBCond:Toggle("visible only", true)
TBCond:Toggle("team check", false)
TBCond:Toggle("alive check", true)
TBCond:Keybind("trigger key", Enum.KeyCode.X, function(k)
	warn("trigger key:", k)
end)

-- ============================================================
-- OTHER - LEFT
-- ============================================================

local OTMisc = Other:CreateGroupbox("misc", "Left")

OTMisc:Toggle("silent aim", false, function(v)
	warn("silent:", v)
end)

OTMisc:Slider("silent fov", {
	Min = 0,
	Max = 100,
	Default = 20,
}, function(v)
	warn("silent fov:", v)
end)

OTMisc:Dropdown("hitpart", {
	"Head", "HumanoidRootPart",
}, "Head", function(v)
	warn("hitpart:", v)
end)

-- ============================================================
-- OTHER - RIGHT
-- ============================================================

local OTSettings = Other:CreateGroupbox("settings", "Right")

OTSettings:Slider("smoothness", {
	Min = 1,
	Max = 20,
	Default = 5,
	Decimals = 1,
}, function(v)
	warn("smooth:", v)
end)

OTSettings:Toggle("prediction", true)
OTSettings:Slider("prediction factor", {
	Min = 0,
	Max = 1,
	Default = 0.165,
	Decimals = 3,
}, function(v)
	warn("pred factor:", v)
end)

OTSettings:ColorPicker("accent color", Library.Theme.Accent, function(c)
	warn("color:", c)
end)

-- ============================================================
-- DONE
-- ============================================================

Library:Notify("amnesia loaded", 3)
