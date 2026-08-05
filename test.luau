--[[
	Minimal Test - Stripped down to find the exact failure
]]

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/library.luau"))()

if not Library then
	warn("[TEST] Library is nil!")
	return
end

if not Library.CreateWindow then
	warn("[TEST] Library.CreateWindow is nil!")
	warn("[TEST] Library keys:", table.concat(table.keys(Library), ", "))
	return
end

warn("[TEST] Library loaded, CreateWindow exists")

local success, Window = pcall(function()
	return Library:CreateWindow({
		Title = "test",
		Size = Vector2.new(400, 300),
	})
end)

if not success then
	warn("[TEST] CreateWindow FAILED:", Window)
	return
end

if not Window then
	warn("[TEST] Window is nil!")
	return
end

warn("[TEST] Window created successfully")
warn("[TEST] ScreenGui:", Window.ScreenGui)
warn("[TEST] ScreenGui.Parent:", Window.ScreenGui and Window.ScreenGui.Parent)
warn("[TEST] MainFrame:", Window.MainFrame)
warn("[TEST] MainFrame.Visible:", Window.MainFrame and Window.MainFrame.Visible)
warn("[TEST] MainFrame.Size:", Window.MainFrame and Window.MainFrame.Size)
warn("[TEST] MainFrame.Position:", Window.MainFrame and Window.MainFrame.Position)

-- Try a manual ScreenGui as fallback
warn("[TEST] Creating manual fallback ScreenGui...")
local testGui = Instance.new("ScreenGui")
testGui.Name = "FallbackTest"
testGui.ResetOnSpawn = false

local testFrame = Instance.new("Frame")
testFrame.Size = UDim2.fromOffset(200, 100)
testFrame.Position = UDim2.fromOffset(50, 50)
testFrame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
testFrame.BorderSizePixel = 0
testFrame.Parent = testGui

local testLabel = Instance.new("TextLabel")
testLabel.Size = UDim2.fromScale(1, 1)
testLabel.BackgroundTransparency = 1
testLabel.Text = "IF YOU SEE THIS, COREGUI WORKS"
testLabel.TextColor3 = Color3.new(1, 1, 1)
testLabel.TextSize = 14
testLabel.Parent = testFrame

local ok, err = pcall(function()
	testGui.Parent = game:GetService("CoreGui")
end)
warn("[TEST] CoreGui parent:", ok, err)
if not ok or not testGui.Parent then
	local ok2, err2 = pcall(function()
		testGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
	end)
	warn("[TEST] PlayerGui parent:", ok2, err2)
end

warn("[TEST] Fallback GUI parented to:", testGui.Parent)
