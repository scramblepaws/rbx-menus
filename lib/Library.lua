--[[
	Library.lua -- Instance-based Roblox menu library (SeriousHook lineage, modernized)

	Portable: uses only standard Roblox Instances (ScreenGui -> Frame/TextLabel/...).
	Works in Studio, Synapse X, Script-Ware, Solara, and weak executors. A custom
	Drawing-API cursor is optional and never required.

	Public API (designed to be easy to write menus):
		local Library = loadstring(game:HttpGet(".../lib/Library.lua"))()
		local Window  = Library:New({Name="My Hub", Size=..., Accent=...})
		local Page    = Window:Page({Name="Home"})
		local Section = Page:Section({Name="Main", Side="Left"})   -- Side: "Left"|"Right"|1|2
		Section:Toggle    ({Name="...", Pointer="x", Default=false,   Callback=print})
		Section:Slider    ({Name="...", Pointer="s", Minimum=0,Maximum=100,Default=50})
		Section:Button    ({Name="...", Callback=func})
		Section:Dropdown  ({Name="...", Pointer="d", Options={...}, Default=1,   Callback=print})
		Section:Multibox  ({Name="...", Pointer="m", Options={...}, Default={...}, Callback=print})
		Section:Keybind   ({Name="...", Pointer="k", Default=Enum.KeyCode.E, Mode="Hold"})
		Section:Colorpicker({Name="...", Pointer="c", Default=Color3.new(1,0,0), Alpha=1})
		Section:Label     ({Name="..."})
		Section:Divider   ()
		Window:Toast(...) / Window:SetWatermark(bool) / Window:Unload() / Window:Initialize()

	Each widget returns an object: { GetValue(), SetValue(v), OnChanged(fn), Value }.

	Pair with SaveManager.lua and ThemeManager.lua for persistence + themes.

	GitHub: https://github.com/scramblepaws/rbx-menus
--]]

------------------------------ Services ------------------------------
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local TextService      = game:GetService("TextService")
local HttpService      = game:GetService("HttpService")
local StatsService     = game:GetService("Stats")
local CoreGui          = game:GetService("CoreGui")
local Lighting         = game:GetService("Lighting")

------------------------------ Executor-compat shims ------------------------------
local cloneref      = cloneref or clonereference or function(inst) return inst end
local clonefunction = clonefunction or copyfunction or function(fn) return fn end
local protectgui    = protectgui or function(g) return g end

Players          = cloneref(Players);           UserInputService = cloneref(UserInputService)
RunService       = cloneref(RunService);        TweenService     = cloneref(TweenService)
TextService      = cloneref(TextService);       HttpService      = cloneref(HttpService)
StatsService     = cloneref(StatsService);      CoreGui          = cloneref(CoreGui)
Lighting         = cloneref(Lighting)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer and (LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui)

------------------------------ Theme defaults ------------------------------
local Theme = {
	Font            = Enum.Font.GothamBook,
	FontSize        = 13,
	FontSizeSmall   = 11,
	TextColor       = Color3.fromRGB(235, 235, 235),
	TextColorSub    = Color3.fromRGB(170, 170, 180),
	TextBorderColor = Color3.fromRGB(0, 0, 0),
	BackgroundColor = Color3.fromRGB(20, 20, 22),
	MainColor       = Color3.fromRGB(26, 26, 28),
	AccentColor     = Color3.fromRGB(123, 43, 218),
	AccentColorDark = Color3.fromRGB(80, 25, 140),
	OutlineColor    = Color3.fromRGB(0, 0, 0),
	InlineColor     = Color3.fromRGB(45, 45, 47),
	RiskColor       = Color3.fromRGB(255, 70, 70),
}

------------------------------- Library state -------------------------------
local Library = {
	-- registries (populated by widgets)
	Options    = {},        -- Pointer -> widget object
	Toggles    = {},        -- Pointer -> toggle widget (subset)
	pointers   = {},        -- Pointer -> {Get, Set, Type}  (drives SaveManager)
	Registry   = {},        -- theme entries: {Instance, Properties}
	RegistryMap = {},       -- Instance -> registry entry
	Signals       = {},      -- RBX signals to disconnect on Unload
	UnloadSignals = {},
	Windows       = {},      -- Outer Frame -> Window table
	OpenedFrame   = nil,     -- dropdown/multibox/picker currently open

	-- pluggable managers
	SaveManager  = nil,
	ThemeManager = nil,

	-- behaviour flags
	UseBlur       = false,
	NotifyOnError = false,
	ToggleKeybind = "RightControl",
	SaveOnLoad    = false,     -- auto-save config when a widget changes
	MinSize       = Vector2.new(480, 440),
	WindowFade    = 0.18,

	-- theme aliases exported onto Library for registry resolution
	Font            = Theme.Font,
	FontSize        = Theme.FontSize,
	FontSizeSmall   = Theme.FontSizeSmall,
	TextColor       = Theme.TextColor,
	TextColorSub    = Theme.TextColorSub,
	TextBorderColor = Theme.TextBorderColor,
	BackgroundColor = Theme.BackgroundColor,
	MainColor       = Theme.MainColor,
	AccentColor     = Theme.AccentColor,
	AccentColorDark = Theme.AccentColorDark,
	OutlineColor    = Theme.OutlineColor,
	InlineColor     = Theme.InlineColor,
	RiskColor       = Theme.RiskColor,

	-- runtime state
	IsMobile  = UserInputService.TouchEnabled,
	Unloaded  = false,
	Loaded    = false,
	Toggled   = false,
}

Library.shared = { initialized = false, fps = 0, ping = 0, tick = 0 }
Library.HudRegistry = {}
Library._UIScales = {}
Library._Effects = {}
Library._Shadows = {}

------------------------------ DPI helper ------------------------------
local function computeScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return math.clamp(vp.X / 1920, 0.72, 1.12)
end
Library.DPIScale = computeScale()
RunService:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	Library.DPIScale = computeScale()
	for _, ui in ipairs(Library._UIScales) do ui.Scale = Library.DPIScale end
end)

------------------------------ Utility layer ------------------------------
-- Create a Roblox Instance and apply a property table. Never throws on bad props.
function Library:Create(Class, Properties, Parent)
	local Instance = Instance.new(Class)
	if Properties then
		for k, v in pairs(Properties) do
			local ok, err = pcall(function() Instance[k] = v end)
			if not ok then
				warn(("Library:Create: %s.%s = %s failed: %s")
					:format(Class, k, tostring(v), err))
			end
		end
	end
	if Parent then Instance.Parent = Parent end
	return Instance
end

function Library:CreateLabel(Properties)
	local Label = self:Create("TextLabel", {
		BackgroundTransparency = 1,
		Font              = self.Font,
		TextColor3        = self.TextColor,
		TextSize          = Properties and Properties.TextSize or self.FontSize,
		TextStrokeColor3  = self.TextBorderColor,
		TextStrokeTransparency = 0,
		RichText          = true,
		Text              = Properties and Properties.Text or "",
		AutoButtonColor   = false,
	})
	self:AddToRegistry(Label, { TextColor3 = "TextColor", TextStrokeColor3 = "TextBorderColor" })
	return self:Create(Label, Properties)
end

function Library:Tween(Instance, Time, Props, Style)
	local tween = TweenService:Create(Instance, TweenInfo.new(Time or 0.15, Style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), Props)
	tween:Play()
	return tween
end

function Library:GetDarkerColor(Color)
	return Color3.fromRGB(
		math.clamp(Color.R * 0.85 * 255, 0, 255),
		math.clamp(Color.G * 0.85 * 255, 0, 255),
		math.clamp(Color.B * 0.85 * 255, 0, 255))
end
Library:GetDarkerColor = Library.GetDarkerColor

local MeasureLabel = nil
function Library:GetTextBounds(Text, Font, Size)
	if not MeasureLabel then
		MeasureLabel = Instance.new("TextLabel")
		MeasureLabel.Visible = false
		MeasureLabel.BackgroundTransparency = 1
		MeasureLabel.Size = UDim2.new(0, 9999, 0, 9999)
		MeasureLabel.TextWrapped = false
		MeasureLabel.RichText = true
	end
	MeasureLabel.Text = Text or ""
	MeasureLabel.Font = Font or self.Font
	MeasureLabel.TextSize = Size or self.FontSize
	local b = MeasureLabel.TextBounds
	return Vector2.new(b.X, b.Y)
end

function Library:SafeCallback(Callback, ...)
	if type(Callback) ~= "function" then return end
	local Result = table.pack(xpcall(Callback, function(Err)
		if self.NotifyOnError then self:Toast("Callback error: " .. tostring(Err), "error", 4) end
		return Err
	end, ...))
	if not Result[1] then return nil, Result[2] end
	return table.unpack(Result, 2, Result.n)
end

function Library:GiveSignal(Signal)
	if Signal then table.insert(self.Signals, Signal) end
	return Signal
end

-- drag for any frame. Cutoff (px from top) bounds the draggable region, nil = whole frame.
function Library:MakeDraggable(Instance, Cutoff)
	local Input = UserInputService
	local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
	local function update(input)
		local delta = input.Position - dragStart
		Instance.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
	Instance.Active = true
	Instance.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if not Cutoff or (input.Position.Y - Instance.AbsolutePosition.Y) <= Cutoff then
				dragging, dragStart, dragInput = true, input.Position, input
				startPos = Instance.Position
			end
		end
	end)
	Instance.InputChanged:Connect(function(input)
		if input == dragInput and dragging then update(input) end
	end)
	Input.InputChanged:Connect(function(input)
		if input == dragInput and dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			update(input)
		end
	end)
	Instance.InputEnded:Connect(function(input)
		if input == dragInput then dragging, dragInput = false, nil end
	end)
end

function Library:OnHighlight(HighlightInstance, Instance, Props, Defaults)
	Defaults = Defaults or {}
	HighlightInstance.MouseEnter:Connect(function()
		for k, v in pairs(Props) do Instance[k] = v end
	end)
	HighlightInstance.MouseLeave:Connect(function()
		for k, v in pairs(Defaults) do Instance[k] = v end
	end)
end

function Library:MouseIsOverOpenedFrame()
	return self.OpenedFrame ~= nil
end

------------------------------- Theme registry -------------------------------
function Library:AddToRegistry(Instance, Properties, IsHud)
	if self.RegistryMap[Instance] then return end
	local Entry = { Instance = Instance, Properties = Properties or {} }
	table.insert(self.Registry, Entry)
	self.RegistryMap[Instance] = Entry
	if IsHud and not table.find(self.HudRegistry, Entry) then
		table.insert(self.HudRegistry, Entry)
	end
end

function Library:RemoveFromRegistry(Instance)
	local Entry = self.RegistryMap[Instance]
	if not Entry then return end
	for i = #self.Registry, 1, -1 do
		if self.Registry[i] == Entry then table.remove(self.Registry, i) end
	end
	self.RegistryMap[Instance] = nil
	for i = #self.HudRegistry, 1, -1 do
		if self.HudRegistry[i] == Entry then table.remove(self.HudRegistry, i) end
	end
end

function Library:UpdateColorsUsingRegistry()
	for _, Entry in ipairs(self.Registry) do
		for Prop, Key in pairs(Entry.Properties) do
			if type(Key) == "string" then
				Entry.Instance[Prop] = self[Key]
			elseif type(Key) == "function" then
				Entry.Instance[Prop] = Key()
			end
		end
	end
end

------------------------------- Window ===============================
function Library:New(info)
	return self:CreateWindow(info)
end

function Library:CreateWindow(info)
	info = info or {}
	if self._ScreenGui then self._ScreenGui:Destroy() end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "SeriousHook"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	ScreenGui.DisplayOrder = 9999
	protectgui(ScreenGui)
	ScreenGui.Parent = PlayerGui

	local UIScale = Instance.new("UIScale")
	UIScale.Name = "DPIScale"
	UIScale.Scale = self.DPIScale
	UIScale.Parent = ScreenGui
	table.insert(self._UIScales, UIScale)

	if self.UseBlur then
		local blur = Instance.new("BlurEffect")
		blur.Size = 0
		blur.Parent = Lighting
		table.insert(self._Effects, blur)
		self.BlurEffect = blur
	end

	if type(info.Accent) == "Color3" then
		self.AccentColor     = info.Accent
		self.AccentColorDark = self:GetDarkerColor(info.Accent)
	end

	local ConfigSize = info.Size or Vector2.new(580, 640)
	ConfigSize = Vector2.new(math.max(ConfigSize.X, self.MinSize.X), math.max(ConfigSize.Y, self.MinSize.Y))

	local Window = {
		Library    = self,
		Name       = info.Name or "SeriousHook",
		Title      = info.Name or "SeriousHook",
		Pages      = {},
		PageList   = {},      -- tab buttons
		CurrentTab = nil,
		CurrentPage= nil,
		Outer      = nil,
	}

	-- Outer window root (draggable)
	local Outer = self:Create("Frame", {
		Name = "Window", BackgroundColor3 = self.BackgroundColor,
		BorderColor3 = self.OutlineColor, BorderSizePixel = 0,
		Visible = false, Size = UDim2.new(0, ConfigSize.X, 0, ConfigSize.Y),
		Position = info.Center and UDim2.new(0.5, 0, 0.5, 0) or (info.Position or UDim2.new(0.5, 0, 0.5, 0)),
		AnchorPoint = Vector2.new(0.5, 0.5), ClipsDescendants = true,
	}, ScreenGui)
	self:AddToRegistry(Outer, { BackgroundColor3 = "BackgroundColor" })
	self:Create("UICorner", { CornerRadius = UDim.new(0, 8) }, Outer)
	Library._Shadows[Outer] = self:Create("ImageLabel", {
		BackgroundTransparency = 1, Image = "rbxassetid://6015897843",
		ImageColor3 = Color3.fromRGB(0, 0, 0), ImageTransparency = 0.2,
		ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
		Size = UDim2.new(1, 24, 1, 24), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0), ZIndex = 0,
	}, Outer)

	-- Inner (content + header)
	local Inner = self:Create("Frame", {
		Name = "Inner", BackgroundColor3 = self.MainColor, BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = 1,
	}, Outer)
	self:AddToRegistry(Inner, { BackgroundColor3 = "MainColor" })
	self:Create("UICorner", { CornerRadius = UDim.new(0, 8) }, Inner)
	Inner.ClipsDescendants = true

	-- Header strip (draggable, holds title + buttons)
	local Header = self:Create("Frame", {
		Name = "Header", BackgroundColor3 = self.BackgroundColor, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 28), ZIndex = 2, ClipsDescendants = true,
	}, Inner)
	self:AddToRegistry(Header, { BackgroundColor3 = "BackgroundColor" })
	self:MakeDraggable(Outer, 28)

	local Title = self:CreateLabel({
		Name = "Title", BackgroundTransparency = 1, RichText = true,
		TextColor3 = self.TextColor, TextSize = self.FontSize + 2,
		Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(1, -96, 0, 20),
		Text = self.Title, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
	})
	self:AddToRegistry(Title, { TextColor3 = "TextColor" })
	self.TitleLabel = Title

	-- close (×) / minimize (—)
	local CloseBtn = self:Create("TextButton", {
		Name = "Close", BackgroundTransparency = 1, Text = "×",
		TextColor3 = self.TextColor, TextSize = self.FontSize + 4, Font = self.Font,
		Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -26, 0, 2),
		AutoButtonColor = false, ZIndex = 4,
	}, Inner)
	self:AddToRegistry(CloseBtn, { TextColor3 = "TextColor" })
	CloseBtn.MouseButton1Click:Connect(function() self:Unload() end)

	local MinBtn = self:Create("TextButton", {
		Name = "Minimize", BackgroundTransparency = 1, Text = "—",
		TextColor3 = self.TextColorSub, TextSize = self.FontSize, Font = self.Font,
		Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -54, 0, 2),
		AutoButtonColor = false, ZIndex = 4,
	}, Inner)
	self:AddToRegistry(MinBtn, { TextColor3 = "TextColorSub" })
	local Body = self:Create("Frame", {
		Name = "Body", BackgroundTransparency = 1,
		Position = UDim2.new(0, 1, 0, 29), Size = UDim2.new(1, -2, 1, -30),
	})
	local minimized = false
	MinBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		Body.Visible = not minimized
	end)

	-- Tab bar (horizontal page tabs)
	local TabBar = self:Create("Frame", {
		Name = "TabBar", BackgroundColor3 = self.InlineColor, BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 30), Size = UDimension2(1, -16, 0, 24), ZIndex = 2,
	}, Inner)
	self:AddToRegistry(TabBar, { BackgroundColor3 = "InlineColor" })
	self:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, TabBar)
	TabBar.ClipsDescendants = true
	self:Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.Name, Padding = UDim.new(0, 4),
	}, TabBar)

	-- Pages container + two-column body
	local PagesRoot = self:Create("Frame", {
		Name = "PagesRoot", BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 56), Size = UDim2.new(1, -16, 1, -64),
	}, Inner)

	Window.Outer = Outer
	Window.Inner = Inner
	Window.Header = Header
	Window.Body   = Body
	Window.TabBar = TabBar
	Window.PagesRoot = PagesRoot
	self.Windows[Outer] = Window

	-- ===== methods =====
	function Window:Page(info) return self.Library:WindowPage(self, info) end
	function Window:Section(info)
		if not self.CurrentPage then self:Page({Name="Home"}) end
		return self.CurrentPage:Section(info)
	end
	function Window:Initialize()   return self.Library:InitializeWindow(self) end
	function Window:ToggleVisibility() return self.Library:ToggleWindowVisibility(self) end

	return Window
end

------------------------------- Page ===============================
function Library:WindowPage(Window, info)
	info = info or {}
	local Name = info.Name or "Page"
	local Page = {
		Window   = Window,
		Library  = self,
		Name     = Name,
		Index    = #Window.Pages,
		Frame    = nil,        -- the visible page frame
	}

	-- tab button on the tab bar
	local labelSize = self:GetTextBounds(Name, self.Font, self.FontSize + 1)
	local TabBtn = self:Create("TextButton", {
		Name = "Tab_" .. Name, Text = Name,
		BackgroundColor3 = self.BackgroundColor, BorderSizePixel = 0,
		TextColor3 = self.TextColorSub, TextSize = self.FontSize, Font = self.Font,
		AutoButtonColor = false, ClipsDescendants = true,
		Size = UDim2.new(0, labelSize.X + 20, 1, 0), ZIndex = 3,
		Visible = false, MinSize = UDim2.new(0, 60, 0, 24),
	}, Window.TabBar)
	self:AddToRegistry(TabBtn, { BackgroundColor3 = "BackgroundColor", TextColor3 = "TextColorSub" })
	self:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, TabBtn)
	local Indicator = self:Create("Frame", {
		BackgroundColor3 = self.AccentColor, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, 0), Visible = false, ZIndex = 4,
	}, TabBtn)
	self:AddToRegistry(Indicator, { BackgroundColor3 = "AccentColor" })

	-- page frame (two columns of groupboxes)
	local Frame = self:Create("Frame", {
		Name = "PageFrame", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), Visible = false, ZIndex = 2, ClipsDescendants = true,
	}, Window.PagesRoot)
	-- two columns
	local LeftCol = self:Create("ScrollingFrame", {
		Name = "LeftCol", BackgroundTransparency = 1,
		Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(0.5, -12, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 0,
		BorderSizePixel = 0, ZIndex = 3,
	}, Frame)
	local RightCol = self:Create("ScrollingFrame", {
		Name = "RightCol", BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -12, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 0,
		BorderSizePixel = 0, ZIndex = 3,
	}, Frame)
	self:Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.Name, Padding = UDim.new(0, 8),
	}, LeftCol)
	self:Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.Name, Padding = UDim.new(0, 8),
	}, RightCol)
	local function syncCanvas(col)
		col.CanvasSize = UDim2.new(0, 0, 0, col.AbsoluteContentSize.Y + 8)
	end
	LeftCol:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(syncCanvas)
	RightCol:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(syncCanvas)
	Page.Frame = Frame
	Page.TabBtn = TabBtn
	Page.Indicator = Indicator
	Page.LeftCol = LeftCol
	Page.RightCol = RightCol

	local function select()
		if Window.CurrentPage and Window.CurrentPage ~= Page then
			Window.CurrentPage.Frame.Visible = false
			Window.CurrentPage.Indicator.Visible = false
			Window.CurrentPage.TabBtn.BackgroundColor3 = self.BackgroundColor
			self:RemoveFromRegistry(Window.CurrentPage.TabBtn) -- re-add fresh props below
		end
		Window.CurrentTab = Page
		Window.CurrentPage = Page
		Frame.Visible = true
		TabBtn.Visible = true
		Indicator.Visible = true
		-- active colouring
		TabBtn.BackgroundColor3 = self.BackgroundColor
	end

	TabBtn.MouseButton1Click:Connect(select)

	table.insert(Window.Pages, Page)
	Page.Select = select

	-- auto-select first tab
	if #Window.Pages == 1 then
		self:GiveSignal(RunService.RenderStepped:Connect(function()
			if Frame:IsDescendantOf(game) and Frame.AbsoluteContentSize.Y > 0 then
				select()
			end
		end))  -- fire once
	end

	return Page
end

------------------------------- Section ===============================
local SectionMethods = {}
SectionMethods.__index = SectionMethods

function Library:Section(info, colFrame, Window)
	info = info or {}
	local pad = 8
	local BoxOuter = self:Create("Frame", {
		Name = "GroupBox", BackgroundColor3 = self.BackgroundColor, BorderSizePixel = 0,
		ClipsDescendants = true,
	}, colFrame)
	self:AddToRegistry(BoxOuter, { BackgroundColor3 = "BackgroundColor" })
	self:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, BoxOuter)
	local BoxInner = self:Create("Frame", {
		BackgroundColor3 = self.MainColor, BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2),
	}, BoxOuter)
	self:AddToRegistry(BoxInner, { BackgroundColor3 = "MainColor" })

	-- title header
	local Header = self:Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18) })
	local Title = self:CreateLabel({
		BackgroundTransparency = 1, Text = info.Name or "Section",
		TextColor3 = self.TextColor, TextSize = self.FontSizeSmall,
		Position = UDim2.new(0, 6, 0, 1), Size = UDim2.new(1, -12, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
	})
	self:AddToRegistry(Title, { TextColor3 = "TextColor" })
	local LineTop = self:Create("Frame", {
		BackgroundColor3 = self.InlineColor, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 0),
	}, BoxInner)
	self:AddToRegistry(LineTop, { BackgroundColor3 = "InlineColor" })
	local LineBottom = self:Create("Frame", {
		BackgroundColor3 = self.InlineColor, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
	}, BoxInner)
	self:AddToRegistry(LineBottom, { BackgroundColor3 = "InlineColor" })

	-- content (auto-growing)
	local Container = self:Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 20), Size = UDim2.new(1, -16, 0, 0),
	}, BoxInner)
	local List = self:Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.Name, Padding = UDim.new(0, 4),
	}, Container)
	Container.ListLayout = List

	-- autosize: each child uses AutomaticSize.Y so Container grows via AbsoluteContentSize
	local function resize()
		local h = Container.AbsoluteContentSize.Y
		if h == 0 then return end
		BoxOuter.Size = UDim2.new(1, 0, 0, h + 20 + 2)
	end
	Container:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)
	List:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resize)

	local function blank(size)
		self:Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, size or 4) }, Container)
	end

	local Section = setmetatable({
		Window    = Window,
		Library   = self,
		Name      = info.Name or "Section",
		Side      = info.Side or "Left",
		Frame     = BoxOuter,
		Outer     = BoxOuter,
		Inner     = BoxInner,
		Header    = Header,
		Container = Container,
		Label     = Title,
		List      = List,
		Blank     = blank,
	}, SectionMethods)

	return Section
end

function Page:Section(info)
	local col = (tostring(info and info.Side or "Left"):lower():match("r") and self.RightCol or self.LeftCol)
	return self.Library:Section(info, col, self.Window)
end

-- A row widget: creates a full-width auto-height row and returns it.
function SectionMethods:NewRow(height)
	height = height or 18
	local Row = self.Library:Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height), AutomaticSize = Enum.AutomaticSize.Y,
	}, self.Container)
	return Row
end

-- Register a widget in the pointer/Option/Toggle registries.
function Library:RegisterPointer(Widget, info)
	if not info.Pointer then return end
	self.pointers[info.Pointer] = {
		Get  = function() return Widget.Value end,
		Set  = function(v)
			Widget.Value = v
			if Widget.SyncDisplay then Widget:SyncDisplay() end
			if type(Widget.OnChanged) == "function" then Widget.OnChanged(v) end
		end,
		Type = Widget.Type,
		Object = Widget,
	}
	if Widget.Type == "Toggle" or Widget.Type == "KeyPicker" then
		self.Toggles[info.Pointer] = Widget
	end
	self.Options[info.Pointer] = Widget
end

------------------------------- Widget base ===============================
local Widget = {}
Widget.__index = Widget
function Widget:GetValue()    return self.Value end
function Widget:SetVisible(v) if self.Object and self.Object ~= nil then self.Object.Visible = v end self.Visible = v end
function Widget:GetVisible()  return self.Object and self.Object.Visible end

------------------------------- Widgets ===============================
function SectionMethods:Toggle(info)
	info = info or {}
	local text     = info.Name or info.Text or "Toggle"
	local pointer  = info.Pointer or info.pointer
	local default  = info.Default or false
	local risky    = info.Risky or false
	local callback = info.Callback or function() end
	local state    = default or false

	local Row = self.NewRow and self:NewRow() or self.Library:Create("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,18), AutomaticSize=Enum.AutomaticSize.Y}, self.Container)
	local Box = self.Library:Create("Frame", {
		BackgroundColor3 = state and self.Library.AccentColor or self.Library.BackgroundColor,
		BorderColor3 = self.Library.OutlineColor, BorderSizePixel = 1,
		Size = UDim2.new(0, 14, 0, 14), ZIndex = 5,
	}, Row)
	self.Library:AddToRegistry(Box, {
		BackgroundColor3 = state and "AccentColor" or "BackgroundColor", BorderColor3 = "OutlineColor",
	})
	self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 3) }, Box)

	local function refresh()
		Box.BackgroundColor3 = state and self.Library.AccentColor or self.Library.BackgroundColor
		self.Library.RegistryMap[Box].Properties.BackgroundColor3 = state and "AccentColor" or "BackgroundColor"
	end
	self.Library:OnHighlight(Row, Box,
		{BackgroundColor3 = self.Library.AccentColor, BorderColor3 = self.Library.AccentColorDark},
		state and {BackgroundColor3 = self.Library.AccentColor, BorderColor3 = self.Library.AccentColorDark}
		   or {BackgroundColor3 = self.Library.BackgroundColor, BorderColor3 = self.Library.OutlineColor})

	local Label = self.Library:CreateLabel({
		BackgroundTransparency = 1, Text = text,
		TextColor3 = risky and self.Library.RiskColor or self.Library.TextColor,
		TextSize = self.Library.FontSize, Position = UDim2.new(0, 20, 0, 0),
		Size = UDim2.new(1, -20, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, RichText = true, ZIndex = 5,
	})
	if risky then self.Library:AddToRegistry(Label, { TextColor3 = "RiskColor" }) end

	local function flip(v)
		state = v == nil and (not state) or v
		refresh()
		self.Library:SafeCallback(info.Callback, state)
		self.Library:SafeCallback(Widget.OnChanged, state)
		if self.Library.SaveManager and self.Library.SaveOnLoad then self.Library.SaveManager:Save() end
	end
	Row.InputBegan:Connect(function(Input)
		if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
			and not self.Library:MouseIsOverOpenedFrame() then
			flip()
		end
	end)

	local WidgetObj = setmetatable({
		Type       = "Toggle",
		Value      = state,
		TextLabel  = Label,
		Object     = Row,
		Box        = Box,
		Container  = self.Container,
		Library    = self.Library,
		Section    = self,
		Info       = info,
		OnChanged  = info.OnChanged or nil,
		FlipValue  = flip,
	}, Widget)
	function WidgetObj:SetValue(v)
		flip(v == true)
	end
	function WidgetObj:SyncDisplay() refresh() end
	function WidgetObj:OnChanged(Func) self.OnChanged = Func end
	self.Library:RegisterPointer(WidgetObj, info)
	return WidgetObj
end

function SectionMethods:Slider(info)
	info = info or {}
	local text      = info.Name or info.Text or "Slider"
	local minimum   = info.Minimum or 0
	local maximum   = info.Maximum or 100
	local default   = info.Default or minimum
	local decimals  = info.Decimals or 0
	local pointer   = info.Pointer or info.pointer
	local callback  = info.Callback or function() end
	local value     = math.clamp(default or minimum, minimum, maximum)

	local Row = self:NewRow()
	local Label = self.Library:CreateLabel({
		BackgroundTransparency = 1, Text = text, TextColor3 = self.Library.TextColor,
		TextSize = self.Library.FontSize, Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 120, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
	})
	self.Library:AddToRegistry(Label, { TextColor3 = "TextColor" })
	local TrackX = 126
	local Track = self.Library:Create("Frame", {
		BackgroundColor3 = self.Library.InlineColor, BorderSizePixel = 0,
		Position = UDim2.new(0, TrackX, 0, 4), Size = UDim2.new(1, -TrackX - 50, 0, 6), ZIndex = 5,
	}, Row)
	self.Library:AddToRegistry(Track, { BackgroundColor3 = "InlineColor" })
	local Fill = self.Library:Create("Frame", {
		BackgroundColor3 = self.Library.AccentColor, BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, 0), ZIndex = 6,
	}, Track)
	self.Library:AddToRegistry(Fill, { BackgroundColor3 = "AccentColor" })
	local ValueLabel = self.Library:CreateLabel({
		BackgroundTransparency = 1, Text = "", TextColor3 = self.Library.TextColor,
		TextSize = self.Library.FontSizeSmall, Position = UDim2.new(1, 6, 0, 0),
		Size = UDim2.new(0, 44, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6,
	})
	self.Library:AddToRegistry(ValueLabel, { TextColor3 = "TextColor" })

	local dragging = false
	local function setValue(v, fire)
		value = math.clamp(v, minimum, maximum)
		local pct = (value - minimum) / math.max(maximum - minimum, 1e-9)
		Fill.Size = UDim2.new(pct, 0, 1, 0)
		ValueLabel.Text = string.format("%." .. decimals .. "f", value)
		if fire then
			self.Library:SafeCallback(callback, value)
			self.Library:SafeCallback(Widget.OnChanged, value)
		end
	end
	setValue(value, false)

	Track.InputBegan:Connect(function(Input)
		if (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
			and not self.Library:MouseIsOverOpenedFrame() then
			dragging = true
			setValue((Input.Position.X - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1) * (maximum - minimum) + minimum, true)
		end
	end)
	self.Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
		if dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
			setValue((Input.Position.X - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1) * (maximum - minimum) + minimum, true)
		end
	end))
	self.Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end))

	local Widget = setmetatable({
		Type = "Slider", Value = value, TextLabel = Label, Object = Row,
		Container = self.Container, Library = self.Library, Section = self, Info = info, OnChanged = nil,
	}, Widget)
	function Widget:SetValue(v) setValue(v, true) end
	function Widget:SyncDisplay() setValue(self.Value, false) end
	function Widget:OnChanged(Func) self.OnChanged = Func end
	self.Library:RegisterPointer(Widget, info)
	return Widget
end

function SectionMethods:Button(info)
	info = info or {}
	local text = info.Name or info.Text or "Button"
	local callback = info.Callback or function() end
	local h = info.Size or 24

	local Btn = self.Library:Create("TextButton", {
		Name = "Button", BackgroundColor3 = self.Library.InlineColor, BorderSizePixel = 1,
		BorderColor3 = self.Library.OutlineColor, Size = UDim2.new(1, 0, 0, h), Text = text,
		TextColor3 = self.Library.TextColor, TextSize = self.Library.FontSize, Font = self.Library.Font,
		AutoButtonColor = false, ZIndex = 5,
	}, self:NewRow())
	self.Library:AddToRegistry(Btn, { BackgroundColor3 = "InlineColor", BorderColor3 = "OutlineColor", TextColor3 = "TextColor" })
	self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Btn)
	self.Library:OnHighlight(Btn, Btn,
		{BackgroundColor3 = self.Library.AccentColor},
		{BackgroundColor3 = self.Library.InlineColor})

	Btn.MouseButton1Click:Connect(function()
		if self.Library:MouseIsOverOpenedFrame() then return end
		self.Library:SafeCallback(callback)
	end)

	local Widget = setmetatable({
		Type = "Button", Value = false, Object = Btn, TextLabel = Btn,
		Container = self.Container, Library = self.Libary or self.Library, Section = self, Info = info,
	}, Widget)
	function Widget:OnChanged(f) end
	return Widget
end

-- A row of equally-sized flat buttons.
function SectionMethods:ButtonHolder(info)
	info = info or {}
	local buttons = info.Buttons or {}
	local h = info.Height or 24
	local Row = self.Library:Create("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h),
	}, self.Container)
	local n = #buttons
	for i, def in ipairs(buttons) do
		local w = 1 / n
		local Btn = self.Library:Create("TextButton", {
			Name = "SubBtn_"..i, BackgroundColor3 = self.Library.InlineColor, BorderSizePixel = 1,
			BorderColor3 = self.Library.OutlineColor, Size = UDim2.new(w, -8, 1, 0),
			Position = UDim2.new((i-1) * w, 4, 0, 0), Text = def[1] or "",
			TextColor3 = self.Library.TextColor, TextSize = self.Library.FontSize, Font = self.Library.Font,
			AutoButtonColor = false, ZIndex = 5, ClipsDescendants = true,
		}, Row)
		self.Library:AddToRegistry(Btn, { BackgroundColor3 = "InlineColor", BorderColor3 = "OutlineColor", TextColor3 = "TextColor" })
		self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Btn)
		self.Library:OnHighlight(Btn, Btn, {BackgroundColor3 = self.Library.AccentColor}, {BackgroundColor3 = self.Library.InlineColor})
		Btn.MouseButton1Click:Connect(function()
			if self.Library:MouseIsOverOpenedFrame() then return end
			self.Library:SafeCallback(def[2])
		end)
	end
	return { Object = Row, Type = "ButtonHolder", Library = self.Library, Section = self }
end

function SectionMethods:Label(info)
	info = info or {}
	local text = info.Name or info.Text or ""
	local Label = self.Library:CreateLabel({
		BackgroundTransparency = 1, Text = text,
		TextColor3 = info.TextColor3 or self.Library.TextColor,
		TextSize = self.Library.FontSize, Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
	})
	self.Library:AddToRegistry(Label, { TextColor3 = info.TextColor3 and "TextColor" or "TextColor" })
	return { Object = Label, TextLabel = Label, Type = "Label", Library = self.Library, Section = self }
end

function SectionMethods:Divider()
	local div = self.Library:Create("Frame", {
		BackgroundColor3 = self.InlineColor, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	}, self.Container)
	self.Library:AddToRegistry(div, { BackgroundColor3 = "InlineColor" })
	return { Object = div, Type = "Divider", Library = self.Library, Section = self }
end
