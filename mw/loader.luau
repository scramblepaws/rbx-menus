--[[
    Counter‑Blox Loader – Compact (610x400)
    Loads ui_utils.luau as shared library.
    Close button, drag anywhere, hover/press feedback, improved contrast.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- Load shared UI library
-- ============================================================
local UI
local ok, err = pcall(function()
    UI = loadstring(game:HttpGet("https://raw.githubusercontent.com/yourusername/roblox-scripts/main/ui_utils.luau"))()
end)
if not ok or not UI then
    warn("ui_utils.luau failed to load. Using fallback.")
    UI = {
        COLORS = {Outer = Color3.fromRGB(0,0,0), Bg = Color3.fromRGB(18,18,18), Panel = Color3.fromRGB(27,27,27), Border = Color3.fromRGB(0,0,0), Text = Color3.fromRGB(255,255,255), Purple = Color3.fromRGB(123,43,218), Hover = Color3.fromRGB(40,40,40)},
        FONT = Enum.Font.Arial,
        createFrame = function(p, props) local f=Instance.new("Frame"); f.Parent=p; for k,v in pairs(props) do f[k]=v end; return f end,
        createTextLabel = function(p, props) local t=Instance.new("TextLabel"); t.Parent=p; for k,v in pairs(props) do t[k]=v end; return t end,
        createTextButton = function(p, props) local b=Instance.new("TextButton"); b.Parent=p; b.AutoButtonColor=false; for k,v in pairs(props) do b[k]=v end; return b end,
        styleButton = function() end,
        addFocusRing = function() end,
    }
end

-- ============================================================
-- CONSTANTS
-- ============================================================
local COLORS = UI.COLORS
local FONT = UI.FONT
local CANVAS_W = 610
local CANVAS_H = 400
local G = {Outer = 6, PanelGap = 4, LeftInset = 4, RightInset = 4}
local LEFT_W = 0.36
local RIGHT_W = 0.64

-- ============================================================
-- ROOT
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CBLoader"
ScreenGui.Parent = game.CoreGui
ScreenGui.ResetOnSpawn = false

local OuterFrame = Instance.new("Frame")
OuterFrame.Parent = ScreenGui
OuterFrame.BackgroundColor3 = COLORS.Outer
OuterFrame.BorderSizePixel = 0
OuterFrame.Size = UDim2.new(0, CANVAS_W, 0, CANVAS_H)
OuterFrame.Position = UDim2.new(0.5, -CANVAS_W/2, 0.5, -CANVAS_H/2)
OuterFrame.Active = true
OuterFrame.ClipsDescendants = true

-- ============================================================
-- MAIN FRAME
-- ============================================================
local MainFrame = Instance.new("Frame")
MainFrame.Parent = OuterFrame
MainFrame.BackgroundColor3 = COLORS.Bg
MainFrame.BorderSizePixel = 1
MainFrame.BorderColor3 = COLORS.Border
MainFrame.Size = UDim2.new(1, -G.Outer*2, 1, -G.Outer*2)
MainFrame.Position = UDim2.new(0, G.Outer, 0, G.Outer)

-- ============================================================
-- TWO‑COLUMN LAYOUT
-- ============================================================
local LeftColumn = UI.createFrame(MainFrame, {BackgroundTransparency = 1, Size = UDim2.new(LEFT_W, 0, 1, 0)})
local RightColumn = UI.createFrame(MainFrame, {BackgroundTransparency = 1, Size = UDim2.new(RIGHT_W, 0, 1, 0), Position = UDim2.new(LEFT_W, 0, 0, 0)})

-- ============================================================
-- HELPERS
-- ============================================================
local function createPanel(parent, x, y, w, h)
    return UI.createFrame(parent, {BackgroundColor3 = COLORS.Panel, BorderSizePixel = 1, BorderColor3 = COLORS.Border, Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, w, 0, h)})
end

local function createText(parent, text, x, y, w, h, size, color, align)
    return UI.createTextLabel(parent, {BackgroundTransparency = 1, Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, w, 0, h), Text = text, TextColor3 = color or COLORS.Text, TextSize = size or 14, Font = FONT, TextXAlignment = align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center})
end

local function createButton(parent, text, x, y, w, h, size, color, func)
    local btn = UI.createTextButton(parent, {BackgroundTransparency = 1, Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, w, 0, h), Text = text, TextColor3 = color or COLORS.Text, TextSize = size or 14, Font = FONT, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center})
    UI.styleButton(btn, COLORS.Panel, COLORS.Hover)
    btn.MouseButton1Click:Connect(func)
    return btn
end

-- ============================================================
-- CLOSE BUTTON
-- ============================================================
UI.createTextButton(OuterFrame, {BackgroundTransparency = 1, Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -24, 0, 8), Text = "×", TextColor3 = COLORS.Text, TextSize = 14, Font = FONT}).MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- ============================================================
-- LEFT COLUMN – ZONE 1: LOGO
-- ============================================================
local logoY = 4
local logoH = 70
local logoPanel = createPanel(LeftColumn, G.LeftInset, logoY, LeftColumn.AbsoluteSize.X - G.LeftInset*2, logoH)

local logo = UI.createTextLabel(logoPanel, {BackgroundTransparency = 1, Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0.5, -30, 0.5, -30), ScaleType = Enum.ScaleType.Fit, Image = "rbxasset://textures/ui/PlaceholderAvatar.png"})

-- ============================================================
-- LEFT COLUMN – ZONE 2: GAME CARDS
-- ============================================================
local gameY = logoY + logoH + G.PanelGap

local function createGameCard(parent, yPos, gameName, status)
    local card = createPanel(parent, G.LeftInset, yPos, parent.AbsoluteSize.X - G.LeftInset*2, 62)
    local thumbSize = 56
    UI.createTextLabel(card, {BackgroundTransparency = 1, Size = UDim2.new(0, thumbSize, 0, thumbSize), Position = UDim2.new(0, 4, 0.5, -thumbSize/2), ScaleType = Enum.ScaleType.Fit, Image = "rbxasset://textures/ui/PlaceholderAvatar.png"})
    createText(card, gameName, thumbSize + 8, 6, 80, 22, 16, COLORS.Purple)
    createText(card, status, thumbSize + 8, 32, 60, 18, 13, COLORS.Purple)
    -- Hover feedback
    UI.styleButton(card, COLORS.Panel, COLORS.Hover)
    return card
end

createGameCard(LeftColumn, gameY, "Counter‑blox", "Beta")
local card2Y = gameY + 62 + G.PanelGap
createGameCard(LeftColumn, card2Y, "Phantom Force's", "Stable")

-- ============================================================
-- LEFT COLUMN – ZONE 3: PROFILE
-- ============================================================
local profileY = card2Y + 62 + G.PanelGap
local profileH = 56
local profilePanel = createPanel(LeftColumn, G.LeftInset, profileY, LeftColumn.AbsoluteSize.X - G.LeftInset*2, profileH)
local avatarSize = 48
local avatar = UI.createTextLabel(profilePanel, {BackgroundTransparency = 1, Size = UDim2.new(0, avatarSize, 0, avatarSize), Position = UDim2.new(0, 4, 0.5, -avatarSize/2), ScaleType = Enum.ScaleType.Fit, Image = "rbxasset://textures/ui/PlaceholderAvatar.png"})
local userId = LocalPlayer.UserId
local thumbSuccess, thumb = pcall(function() return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end)
if thumbSuccess and thumb then avatar.Image = thumb end
createText(profilePanel, LocalPlayer.Name, avatarSize + 10, 0, 80, 24, 16)

-- ============================================================
-- RIGHT COLUMN – ZONE 1: HEADER
-- ============================================================
local headerY = 4
local headerH = 70
local headerPanel = createPanel(RightColumn, G.RightInset, headerY, RightColumn.AbsoluteSize.X - G.RightInset*2, headerH)
UI.createTextLabel(headerPanel, {BackgroundTransparency = 1, Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, 4, 0.5, -30), ScaleType = Enum.ScaleType.Fit, Image = "rbxasset://textures/ui/PlaceholderAvatar.png"})
createText(headerPanel, "Counter‑blox", 72, 0, 150, 32, 20, COLORS.Purple)

-- ============================================================
-- RIGHT COLUMN – ZONE 2: UPDATE LOG
-- ============================================================
local updateY = headerY + headerH + G.PanelGap
local updateH = 150
local updatePanel = createPanel(RightColumn, G.RightInset, updateY, RightColumn.AbsoluteSize.X - G.RightInset*2, updateH)
UI.createTextLabel(updatePanel, {BackgroundTransparency = 1, Size = UDim2.new(0, 150, 0, 18), Position = UDim2.new(0, 12, 0, 6), Text = "9/2/26 Update log", TextColor3 = COLORS.Purple, TextSize = 16, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left})

local entryY = 28
local function addUpdateEntry(text, isAdd)
    UI.createTextLabel(updatePanel, {BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 12, 0, entryY), Text = (isAdd and "[+] " or "[-] ") .. text, TextColor3 = COLORS.Text, TextSize = 13, Font = FONT, TextXAlignment = Enum.TextXAlignment.Left})
end
addUpdateEntry("Updated Skin changer to work with latest update to cb", true)
addUpdateEntry("added spinbot", true)
addUpdateEntry("Removed executor", false)
addUpdateEntry("removed kill all", false)

-- ============================================================
-- RIGHT COLUMN – ZONE 3: LOAD
-- ============================================================
local loadY = updateY + updateH + G.PanelGap
local loadH = 56
local loadPanel = createPanel(RightColumn, G.RightInset, loadY, RightColumn.AbsoluteSize.X - G.RightInset*2, loadH)
UI.styleButton(loadPanel, COLORS.Panel, COLORS.Hover)
UI.createTextLabel(loadPanel, {BackgroundTransparency = 1, Text = "Load", TextColor3 = COLORS.Text, TextSize = 18, Font = FONT, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center})
loadPanel.MouseButton1Click:Connect(function() print("Load clicked") end)

-- ============================================================
-- DRAGGING (entire outer frame)
-- ============================================================
local dragStart, dragOffset = false, Vector2.new(0,0)
OuterFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = true
        dragOffset = Vector2.new(input.Position.X - OuterFrame.AbsolutePosition.X, input.Position.Y - OuterFrame.AbsolutePosition.Y)
    end
end)
OuterFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragStart = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragStart and input.UserInputType == Enum.UserInputType.MouseMovement then
        OuterFrame.Position = UDim2.new(0, input.Position.X - dragOffset.X, 0, input.Position.Y - dragOffset.Y)
    end
end)

print("Counter‑Blox Loader loaded via ui_utils library.")