--[[
    Millionware – Pixel‑Perfect Recreation
    Loads ui_utils.luau as shared library.
    All UI components use library functions.
]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ============================================================
-- Load shared UI library
-- ============================================================
local UI
local ok, err = pcall(function()
    UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/yourusername/roblox-scripts/main/ui_utils.luau"))()
end)
if not ok or not UI then
    warn("ui_utils.luau failed to load. Using built-in fallback.")
    -- Minimal fallback (should not be needed if library is deployed)
    UI = {
        COLORS = {
            Outer = Color3.fromRGB(0,0,0), Bg = Color3.fromRGB(18,18,18),
            Panel = Color3.fromRGB(27,27,27), Border = Color3.fromRGB(0,0,0),
            Text = Color3.fromRGB(255,255,255), Muted = Color3.fromRGB(200,200,200),
            Purple = Color3.fromRGB(123,43,218), Hover = Color3.fromRGB(40,40,40),
        },
        FONT = Enum.Font.Arial,
        PAD = {Small = 4, Medium = 8},
        SIZE = {Checkbox = 10, RowHeight = 16},
        createFrame = function(p, props) local f=Instance.new("Frame"); f.Parent=p; for k,v in pairs(props) do f[k]=v end; return f end,
        createTextLabel = function(p, props) local t=Instance.new("TextLabel"); t.Parent=p; for k,v in pairs(props) do t[k]=v end; return t end,
        createTextButton = function(p, props) local b=Instance.new("TextButton"); b.Parent=p; b.AutoButtonColor=false; for k,v in pairs(props) do b[k]=v end; return b end,
        styleButton = function() end,
        addFocusRing = function() end,
        createSidebarButton = function() end,
        createGroupBox = function() end,
        createCheckbox = function() end,
        createDropdown = function() end,
        createActionButton = function() end,
    }
end

-- ============================================================
-- CONSTANTS (local aliases for convenience)
-- ============================================================
local COLORS = UI.COLORS
local FONT = UI.FONT
local PAD = UI.PAD
local UI_SIZE = UI.SIZE

-- ============================================================
-- ROOT
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MillionwareGUI"
ScreenGui.Parent = game.CoreGui
ScreenGui.ResetOnSpawn = false

local OuterFrame = Instance.new("Frame")
OuterFrame.Parent = ScreenGui
OuterFrame.BackgroundColor3 = COLORS.Outer
OuterFrame.BorderSizePixel = 0
OuterFrame.Size = UDim2.new(0, 610, 0, 400)
OuterFrame.Position = UDim2.new(0.5, -305, 0.5, -200)
OuterFrame.Active = true
OuterFrame.ClipsDescendants = true

-- Subtle dark gray layer (#0D0D0D)
local DarkLayer = Instance.new("Frame")
DarkLayer.Parent = OuterFrame
DarkLayer.BackgroundColor3 = Color3.fromRGB(13, 13, 13)
DarkLayer.BorderSizePixel = 0
DarkLayer.Size = UDim2.new(1, 0, 1, 0)

-- === MAIN CONTENT FRAME ===
local MainFrame = Instance.new("Frame")
MainFrame.Parent = OuterFrame
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MainFrame.BorderSizePixel = 1
MainFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.Size = UDim2.new(0, 592, 0, 362)
MainFrame.Position = UDim2.new(0, 9, 0, 29)
MainFrame.ClipsDescendants = true

-- === SIDEBAR (left: width=123) ===
local Sidebar = Instance.new("Frame")
Sidebar.Parent = MainFrame
Sidebar.BackgroundTransparency = 1
Sidebar.Size = UDim2.new(0, 123, 1, 0)
Sidebar.Position = UDim2.new(0, 13, 0, 0)

-- === LOGO: "MW" with "$" ===
local LogoFrame = UI.createFrame(Sidebar, {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 44),
    Position = UDim2.new(0, 12, 0, 20),
})

UI.createTextLabel(LogoFrame, {
    BackgroundTransparency = 1, Size = UDim2.new(0, 30, 1, 0),
    Position = UDim2.new(0, 0, 0, 0), Text = "M",
    TextColor3 = COLORS.Text, TextSize = 44, Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Left,
})

UI.createTextLabel(LogoFrame, {
    BackgroundTransparency = 1, Size = UDim2.new(0, 40, 1, 0),
    Position = UDim2.new(0, 26, 0, 0), Text = "W",
    TextColor3 = COLORS.Text, TextSize = 44, Font = Enum.Font.ArialBold,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local LogoDollar = UI.createTextLabel(LogoFrame, {
    BackgroundTransparency = 1, Size = UDim2.new(0, 16, 0, 20),
    Position = UDim2.new(0, 56, 0, -8), Text = "$",
    TextColor3 = Color3.fromRGB(255, 0, 245), TextSize = 20, Font = Enum.Font.ArialBold,
})

-- ============================================================
-- TAB SYSTEM
-- ============================================================
local tabFrames = {}
local currentTab = nil

local function createTabFrame(name)
    local frame = Instance.new("Frame")
    frame.Parent = MainFrame
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(0, 456, 1, 0)
    frame.Position = UDim2.new(0, 131, 0, 0)
    frame.Visible = false
    tabFrames[name] = frame
    return frame
end

function switchTab(name)
    for k, f in pairs(tabFrames) do
        f.Visible = (k == name)
    end
    currentTab = name
end

-- ============================================================
-- SIDEBAR BUTTONS (loaded via library)
-- ============================================================
local sidebarButtons = {}

local btnExecutor = UI.createSidebarButton(Sidebar, "Executor", 85, sidebarButtons, switchTab)
UI.createSidebarButton(Sidebar, "Aimbot", 119, sidebarButtons, switchTab)
UI.createSidebarButton(Sidebar, "Visuals", 153, sidebarButtons, switchTab)
UI.createSidebarButton(Sidebar, "Misc", 187, sidebarButtons, switchTab)
UI.createSidebarButton(Sidebar, "Skins", 221, sidebarButtons, switchTab)
UI.createSidebarButton(Sidebar, "Settings", 255, sidebarButtons, switchTab)

-- Default active: Executor
local execIndicator = btnExecutor:FindFirstChild("Indicator")
if execIndicator then execIndicator.Visible = true end
switchTab("Executor")

-- ============================================================
-- 1. EXECUTOR TAB
-- ============================================================
local execTab = createTabFrame("Executor")
local ScriptBoxReal = UI.createTextBox(execTab, {
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    BorderSizePixel = 1, BorderColor3 = COLORS.Border,
    TextColor3 = Color3.fromRGB(220, 220, 220),
    TextSize = 10, Font = FONT,
    Size = UDim2.new(0.85, 0, 0.65, 0),
    Position = UDim2.new(0.05, 0, 0.05, 0),
    Text = "-- Paste script", MultiLine = true, ClearTextOnFocus = false,
})
UI.addFocusRing(ScriptBoxReal)

local function createExecButton(text, yPos, callback)
    local btn = UI.createTextButton(execTab, {
        BackgroundColor3 = COLORS.Panel, BorderSizePixel = 1,
        BorderColor3 = COLORS.Border, TextColor3 = COLORS.Text,
        TextSize = 10, Font = FONT,
        Size = UDim2.new(0.25, 0, 0.08, 0),
        Position = UDim2.new(0.05, 0, yPos, 0), Text = text,
    })
    UI.styleButton(btn, COLORS.Panel, COLORS.Hover)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

createExecButton("Execute", 0.75, function()
    local code = ScriptBoxReal.Text
    if code and code ~= "" then
        local success, err = pcall(loadstring(code))
        if not success then warn("Execution error: " .. tostring(err)) end
    end
end)
createExecButton("Clear", 0.85, function()
    ScriptBoxReal.Text = ""
end)

-- ============================================================
-- 2. MISC TAB
-- ============================================================
local miscTab = createTabFrame("Misc")
local movGroup = UI.createGroupBox(miscTab, 5, 5, 219, 340, "Movement")
local otherGroup = UI.createGroupBox(miscTab, 232, 5, 219, 340, "Other")

-- Movement checkboxes
local movY = PAD.Small
UI.createCheckbox(movGroup, "Bunny hop", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "Infinite duck", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "Jump bug", movY, true) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "Jump bug indicator", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "Edge bug", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "Edge bug indicator", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small

-- "Edge bug sound" label + input
local soundLabel = UI.createTextLabel(movGroup, {
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, UI_SIZE.RowHeight),
    Position = UDim2.new(0, PAD.Medium + UI_SIZE.Checkbox, 0, movY),
    Text = "Edge bug sound", TextColor3 = COLORS.Text, TextSize = 10, Font = FONT,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
})
movY = movY + UI_SIZE.RowHeight + PAD.Small

local soundInput = UI.createTextBox(movGroup, {
    BackgroundColor3 = Color3.fromRGB(15, 15, 15), BorderSizePixel = 1,
    BorderColor3 = COLORS.Border, Size = UDim2.new(0, 163, 0, 16),
    Position = UDim2.new(0, PAD.Medium + UI_SIZE.Checkbox, 0, movY),
    Text = "", TextColor3 = COLORS.Muted, TextSize = 10, Font = FONT,
})
UI.addFocusRing(soundInput)
movY = movY + UI_SIZE.RowHeight + PAD.Small + PAD.Small

UI.createCheckbox(movGroup, "Strafe optimizer", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "Edge jump", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "Velocity indicator", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small

-- Gray slider indicator
UI.createFrame(movGroup, {
    BackgroundColor3 = COLORS.Muted, BorderSizePixel = 0,
    Size = UDim2.new(0, 19, 0, 7),
    Position = UDim2.new(0, 219 - 19 - PAD.Small, 0, movY),
})

UI.createCheckbox(movGroup, "Take off", movY, true) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "Velocity graph", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "Blockbot", movY, true) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "Fast walk", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "Long jump", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(movGroup, "LJ on edge", movY, false) movY = movY + UI_SIZE.RowHeight + PAD.Small

-- Other group checkboxes
local otherY = PAD.Small
UI.createCheckbox(otherGroup, "Auto pistol", otherY, false) otherY = otherY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(otherGroup, "Reveal ranks", otherY, true) otherY = otherY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(otherGroup, "Auto accept", otherY, true) otherY = otherY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(otherGroup, "Clan tag", otherY, false) otherY = otherY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(otherGroup, "Watermark", otherY, false) otherY = otherY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(otherGroup, "Name spam", otherY, false) otherY = otherY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(otherGroup, "Team damage log", otherY, true) otherY = otherY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(otherGroup, "View vote", otherY, true) otherY = otherY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(otherGroup, "Kill say", otherY, false) otherY = otherY + UI_SIZE.RowHeight + PAD.Small
UI.createCheckbox(otherGroup, "Inventory unlocker", otherY, true) otherY = otherY + UI_SIZE.RowHeight + PAD.Small

-- Server selector
UI.createTextLabel(otherGroup, {
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, UI_SIZE.RowHeight),
    Position = UDim2.new(0, PAD.Small, 0, otherY),
    Text = "  Server selector", TextColor3 = COLORS.Text, TextSize = 10, Font = FONT,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
})
otherY = otherY + UI_SIZE.RowHeight + PAD.Small
UI.createDropdown(otherGroup, PAD.Medium + UI_SIZE.Checkbox, otherY, 162, 18, {"Don't force", "Force", "Auto"}, 1)
otherY = otherY + UI_SIZE.RowHeight + PAD.Small + PAD.Small

-- Hitsound
UI.createTextLabel(otherGroup, {
    BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, UI_SIZE.RowHeight),
    Position = UDim2.new(0, PAD.Small, 0, otherY),
    Text = "  Hitsound", TextColor3 = COLORS.Text, TextSize = 10, Font = FONT,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
})
otherY = otherY + UI_SIZE.RowHeight + PAD.Small
UI.createDropdown(otherGroup, PAD.Medium + UI_SIZE.Checkbox, otherY, 162, 18, {"Arena switch press", "None", "Default"}, 1)
otherY = otherY + UI_SIZE.RowHeight + PAD.Small + PAD.Small
UI.createActionButton(otherGroup, PAD.Medium + UI_SIZE.Checkbox, otherY, 162, 18, "Unlock hidden convars", function()
    print("Unlocking hidden convars...")
end)

-- ============================================================
-- Placeholder tabs
-- ============================================================
local function createPlaceholderTab(name)
    local tab = createTabFrame(name)
    UI.createTextLabel(tab, {
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        Text = name .. " settings (coming soon)", TextColor3 = COLORS.Muted,
        TextSize = 12, Font = FONT,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
    })
    return tab
end

createPlaceholderTab("Aimbot")
createPlaceholderTab("Visuals")
createPlaceholderTab("Skins")
createPlaceholderTab("Settings")

-- ============================================================
-- DRAGGING (outer frame)
-- ============================================================
local dragStart, dragOffset = false, Vector2.new(0,0)
OuterFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = true
        dragOffset = Vector2.new(input.Position.X - OuterFrame.AbsolutePosition.X, 
                                 input.Position.Y - OuterFrame.AbsolutePosition.Y)
    end
end)
OuterFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = false
    end
end)
OuterFrame.InputChanged:Connect(function(input)
    if dragStart and input.UserInputType == Enum.UserInputType.MouseMovement then
        OuterFrame.Position = UDim2.new(0, input.Position.X - dragOffset.X, 0, input.Position.Y - dragOffset.Y)
    end
end)

print("Millionware UI loaded via ui_utils library.")