--[[
	Amnesia - Example Script
	Matching the Figma design
]]

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/library.luau"))()

-- Main Window
local Window = Library:CreateWindow({
	Title = "amnesia [v1.0] | developed by dutu1337",
	Size = Vector2.new(580, 420),
	Position = UDim2.fromOffset(100, 100)
})

-- Sidebar Categories
local Aimbot = Window:CreateSidebarCategory("aimbot")
local Visuals = Window:CreateSidebarCategory("visuals")
local Misc = Window:CreateSidebarCategory("misc")
local Config = Window:CreateSidebarCategory("config")

-- Get active tab and create tabs for aimbot
local activeTab = Window:GetActiveTab()
local Legitbot = activeTab:CreateTab("legitbot")
local Triggerbot = activeTab:CreateTab("triggerbot")
local Other = activeTab:CreateTab("other")

-- ============================================================
-- LEGITBOT TAB
-- ============================================================

-- Left Column - Main settings
local MainGroupbox = Legitbot:CreateGroupbox("main", "Left")

local enabledToggle = MainGroupbox:Toggle("enabled", false, function(value)
	warn("Aimbot enabled:", value)
end)

local recoilToggle = MainGroupbox:Toggle("remove recoil", false, function(value)
	warn("Remove recoil:", value)
end)

local spreadToggle = MainGroupbox:Toggle("remove spread", false, function(value)
	warn("Remove spread:", value)
end)

local fovSlider = MainGroupbox:Slider("field of view", {
	Min = 0,
	Max = 100,
	Default = 34,
	Decimals = 0,
}, function(value)
	warn("FOV:", value)
end)

local hitchanceSlider = MainGroupbox:Slider("hitchance", {
	Min = 0,
	Max = 100,
	Default = 64,
	Decimals = 0,
}, function(value)
	warn("Hitchance:", value)
end)

local targetDropdown = MainGroupbox:Dropdown("target selection", {
	"slot 1",
	"slot 2",
	"slot 3",
	"slot 4",
	"slot 5"
}, "slot 1", function(value)
	warn("Target:", value)
end)

local hitboxesDropdown = MainGroupbox:Dropdown("hitboxes", {
	"head",
	"head, body",
	"head, body, limbs",
	"body",
	"limbs"
}, "head, body", function(value)
	warn("Hitboxes:", value)
end)

local saveBtn = MainGroupbox:Button("save", function()
	warn("Config saved!")
	Library:Notice("Config saved successfully!", 2)
end)

-- Right Column - Accuracy / Config slots
local AccuracyGroupbox = Legitbot:CreateGroupbox("accuracy", "Right")

local configNameInput = AccuracyGroupbox:Textbox("config name", "dutu1337", function(text)
	warn("Config name:", text)
end)

for i = 1, 9 do
	local slotBtn = AccuracyGroupbox:Button("slot " .. i, function()
		warn("Slot " .. i .. " selected")
		configNameInput:SetText("slot_" .. i)
	end)
end

-- ============================================================
-- TRIGGERBOT TAB
-- ============================================================

local TriggerbotLeft = Triggerbot:CreateGroupbox("trigger settings", "Left")
TriggerbotLeft:Toggle("enabled", false)
TriggerbotLeft:Slider("delay", { Min = 0, Max = 500, Default = 50, Suffix = "ms" })
TriggerbotLeft:Slider("hitchance", { Min = 0, Max = 100, Default = 80 })
TriggerbotLeft:Dropdown("target part", { "Head", "HumanoidRootPart", "UpperTorso" }, "Head")

local TriggerbotRight = Triggerbot:CreateGroupbox("conditions", "Right")
TriggerbotRight:Toggle("visible only", true)
TriggerbotRight:Toggle("team check", false)
TriggerbotRight:Toggle("alive check", true)

-- ============================================================
-- OTHER TAB
-- ============================================================

local OtherLeft = Other:CreateGroupbox("misc", "Left")
OtherLeft:Toggle("silent aim", false)
OtherLeft:Slider("silent fov", { Min = 0, Max = 100, Default = 20 })
OtherLeft:Dropdown("hitpart", { "Head", "HumanoidRootPart" }, "Head")

local OtherRight = Other:CreateGroupbox("settings", "Right")
OtherRight:Slider("smoothness", { Min = 1, Max = 20, Default = 5, Decimals = 1 })
OtherRight:Toggle("prediction", true)
OtherRight:Slider("prediction factor", { Min = 0, Max = 1, Default = 0.165, Decimals = 3 })

-- ============================================================
-- VISUALS TAB (placeholder)
-- ============================================================

local VisualsTab = Window:GetActiveTab()
-- Note: The sidebar categories switch tabs, but for this example
-- we create content in the default tab

-- ============================================================
-- FOOTER TEXT
-- ============================================================

-- Add a label at the bottom of the main groupbox
MainGroupbox:Separator("just a text!")

-- ============================================================
-- TOOLTIPS
-- ============================================================

-- Bind tooltips to controls
Library.Tooltip:Bind(enabledToggle, "Toggle aimbot on/off")
Library.Tooltip:Bind(recoilToggle, "Remove weapon recoil")
Library.Tooltip:Bind(spreadToggle, "Remove weapon spread")
Library.Tooltip:Bind(saveBtn, "Save current configuration")

print("=== Amnesia UI Loaded ===")
print("All controls initialized successfully")
