--[[
	Library.lua -- Instance-based Roblox menu library (SeriousHook lineage, modernized)

	Portable: uses only standard Roblox Instances (ScreenGui -> Frame/TextLabel/...).
	Works in Studio, Synapse X, Script-Ware, Solara, and weak executors. A custom
	Drawing-API cursor is optional and never required.

	Public API (designed to be easy to write menus):
		local Library = loadstring(game:HttpGet(".../lib/Library.lua"))()
		local Window  = Library:New({Name="My Hub", Size=..., Accent=...})
		local Page    = Window:Page({Name="Home"})
		local Section = Page:Section({Name="Main", Side="Left"})   -- Side: "Left"|"Right"
		Section:Toggle    ({Name="...", Pointer="x", Default=false,   Callback=fn})
		Section:Slider    ({Name="...", Pointer="s", Minimum=0,Maximum=100,Default=50})
		Section:Button    ({Name="...", Callback=fn})
		Section:Dropdown  ({Name="...", Pointer="d", Options={...}, Default=1,    Callback=fn})
		Section:Multibox  ({Name="...", Pointer="m", Options={...}, Default={...}, Callback=fn})
		Section:Keybind   ({Name="...", Pointer="k", Default=Enum.KeyCode.E, Mode="Hold"})
		Section:Colorpicker({Name="...", Pointer="c", Default=Color3.new(1,0,0), Alpha=1})
		Section:TextBox    ({Name="...", Pointer="t", Default="", Callback=fn})
		Section:Label     ({Name="..."})
		Section:Divider   ()
		Window:Toast(...) / Window:SetWatermark(bool) / Window:Unload() / Window:Initialize()

	Each widget returns an object with GetValue / SetValue / OnChanged.
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
local protectgui    = protectgui or function(g) return g end

Players          = cloneref(Players);        UserInputService = cloneref(UserInputService)
RunService       = cloneref(RunService);     TweenService     = cloneref(TweenService)
TextService      = cloneref(TextService);    HttpService      = cloneref(HttpService)
StatsService     = cloneref(StatsService);    CoreGui          = cloneref(CoreGui)
Lighting         = cloneref(Lighting)

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer and (LocalPlayer:FindFirstChildOfClass("PlayerGui") or CoreGui)

------------------------------ Theme defaults ------------------------------
local function resolveFont(...)
	for _, name in ipairs({...}) do
		local ok, f = pcall(function() return Enum.Font[name] end)
		if ok and f then return f end
	end
	return Enum.Font.SourceSans
end
local DefaultFont = resolveFont("GothamBook", "Gotham", "GothamSemibold", "SourceSans")

local Theme = {
	Font            = DefaultFont,
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

------------------------------- Library -------------------------------
local Library = {
	-- registries
	Options    = {},   -- Pointer -> widget object
	Toggles    = {},   -- Pointer -> toggle widget
	pointers   = {},   -- Pointer -> {Get, Set, Type}  (drives SaveManager)
	Registry   = {},   -- theme entries: {Instance, Properties}
	RegistryMap = {},  -- Instance -> registry entry
	HudRegistry = {},  -- entries that should hide when UI is hidden
	Signals       = {},
	UnloadSignals = {},
	Windows       = {},
	OpenedFrame   = nil,       -- dropdown/multibox/picker currently open

	-- pluggable managers
	SaveManager  = nil,
	ThemeManager = nil,

	-- behaviour flags
	UseBlur       = false,
	NotifyOnError = true,
	ToggleKeybind = "RightControl",
	SaveOnLoad    = false,
	WarnOnError   = true,
	CopyErrorsToClipboard = true,
	MinSize       = Vector2.new(480, 440),
	WindowFade    = 0.18,

	-- theme exports (resolved by registry by string key)
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
Library._UIScales = {}
Library._Effects  = {}
Library._Shadows  = {}

------------------------------- DPI helper -------------------------------
local function getViewportSize()
	local cam = workspace.CurrentCamera
	if cam then
		local ok, vp = pcall(function() return cam.ViewportSize end)
		if ok and vp then return vp end
	end
	local ok, ws = pcall(function() return UserInputService.WindowSize end)
	if ok and ws and ws.X and ws.Y then return ws end
	return Vector2.new(1920, 1080)
end
local function computeScale()
	local vp = getViewportSize()
	return math.clamp(vp.X / 1920, 0.72, 1.12)
end
Library.DPIScale = computeScale()
local function refreshUIScale()
	Library.DPIScale = computeScale()
	for _, ui in ipairs(Library._UIScales) do ui.Scale = Library.DPIScale end
end
pcall(function()
	RunService:GetPropertyChangedSignal("ViewportSize"):Connect(refreshUIScale)
end)
pcall(function()
	UserInputService:GetPropertyChangedSignal("WindowSize"):Connect(refreshUIScale)
end)

------------------------------- Utility layer -------------------------------
function Library:Create(Class, Properties, Parent)
	local InstanceObj
	if type(Class) == "string" then
		InstanceObj = Instance.new(Class)
	elseif typeof(Class) == "Instance" then
		InstanceObj = Class:Clone()
	else
		InstanceObj = Instance.new("Frame")
	end
	if Properties then
		for k, v in pairs(Properties) do
			local ok, err = pcall(function() InstanceObj[k] = v end)
			if not ok then
				warn(("Library:Create: %s.%s = %s failed: %s"):format(
					(typeof(Class) == "Instance" and Class.ClassName or tostring(Class)), k, tostring(v), err))
			end
		end
	end
	if Parent then InstanceObj.Parent = Parent end
	return InstanceObj
end

function Library:CreateLabel(Properties)
	Properties = Properties or {}
	local Label = self:Create("TextLabel", {
		Name                   = Properties.Name or "Label",
		BackgroundTransparency = 1,
		Font                   = self.Font,
		TextColor3             = Properties.TextColor3 or self.TextColor,
		TextSize               = Properties.TextSize or self.FontSize,
		TextStrokeColor3       = self.TextBorderColor,
		TextStrokeTransparency = 0,
		RichText               = true,
		Text                   = Properties.Text or "",
		TextXAlignment         = Properties.TextXAlignment or Enum.TextXAlignment.Left,
		Position               = Properties.Position,
		Size                   = Properties.Size,
		ZIndex                 = Properties.ZIndex or 1,
		Parent                 = Properties.Parent,
	})
	self:AddToRegistry(Label, { TextColor3 = "TextColor", TextStrokeColor3 = "TextBorderColor" })
	return Label
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

local MeasureLabel
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
		self:CaptureError(Err, "widget callback")
		return Err
	end, ...))
	if not Result[1] then return nil, Result[2] end
	return table.unpack(Result, 2, Result.n)
end

local Traceback = (debug and debug.traceback)
	or function(msg, level) return tostring(msg) end

function Library:CaptureError(Err, context)
	local display = (context and (context .. ": ") or "") .. tostring(Err)
	if self.NotifyOnError then self:Toast(display, "error", 10) end
	if self.WarnOnError then warn(display .. "\n" .. Traceback("", 2)) end
	if self.CopyErrorsToClipboard then
		pcall(function()
			if setclipboard then setclipboard(Traceback(display, 2)) end
		end)
	end
	return display
end

function Library:GiveSignal(Signal)
	if Signal then table.insert(self.Signals, Signal) end
	return Signal
end

function Library:MakeDraggable(Instance, Cutoff)
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
	UserInputService.InputChanged:Connect(function(input)
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
	local defaultCache = {}
	for k, v in pairs(Defaults) do defaultCache[k] = Instance[k] end
	HighlightInstance.MouseEnter:Connect(function()
		for k, v in pairs(Props) do Instance[k] = v end
	end)
	local function restore()
		for k, v in pairs(Defaults) do Instance[k] = v end
	end
	HighlightInstance.MouseLeave:Connect(restore)
end

function Library:MouseIsOverOpenedFrame()
	return self.OpenedFrame ~= nil
end

------------------------------- Theme registry -------------------------------
function Library:AddToRegistry(Instance, Properties, IsHud)
	if self.RegistryMap[Instance] then return end
	local Entry = { Instance = Instance, Properties = Properties or {}, Idx = #self.Registry + 1 }
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
		if Entry.Instance and Entry.Instance.Parent then
			for Prop, Key in pairs(Entry.Properties) do
				if type(Key) == "string" then
					local val = self[Key]
					if val ~= nil then Entry.Instance[Prop] = val end
				elseif type(Key) == "function" then
					local val = Key()
					if val ~= nil then Entry.Instance[Prop] = val end
				end
			end
		end
	end
	for _, Entry in ipairs(self.HudRegistry) do
		if Entry.Instance and Entry.Instance.Parent then
			for Prop, Key in pairs(Entry.Properties) do
				if type(Key) == "string" then
					local val = self[Key]
					if val ~= nil then Entry.Instance[Prop] = val end
				end
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
	self._ScreenGui = ScreenGui

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
		PageList   = {},
		CurrentTab = nil,
		CurrentPage= nil,
	}

	local Outer = self:Create("Frame", {
		Name = "Window", BackgroundColor3 = self.BackgroundColor, BorderSizePixel = 0,
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

	local Inner = self:Create("Frame", {
		Name = "Inner", BackgroundColor3 = self.MainColor, BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2), ZIndex = 1,
	}, Outer)
	self:AddToRegistry(Inner, { BackgroundColor3 = "MainColor" })
	self:Create("UICorner", { CornerRadius = UDim.new(0, 8) }, Inner)
	Inner.ClipsDescendants = true

	-- header strip
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
		Parent = Header,
	})
	self:AddToRegistry(Title, { TextColor3 = "TextColor" })
	self.TitleLabel = Title

	local CloseBtn = self:Create("TextButton", {
		Name = "Close", BackgroundTransparency = 1, Text = "×",
		TextColor3 = self.TextColor, TextSize = self.FontSize + 4, Font = self.Font,
		Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -26, 0, 2),
		AutoButtonColor = false, ZIndex = 4,
	}, Inner)
	self:AddToRegistry(CloseBtn, { TextColor3 = "TextColor" })
	CloseBtn.MouseButton1Click:Connect(function() self:Unload(Window) end)

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
	}, Inner)
	local minimized = false
	MinBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		Body.Visible = not minimized
		self:Tween(Outer, self.WindowFade, {Size = (not minimized) and UDim2.new(0, ConfigSize.X, 0, ConfigSize.Y) or UDim2.new(0, ConfigSize.X, 0, 29)})
	end)
	Window._Minimized = false

	-- tab bar
	local TabBar = self:Create("Frame", {
		Name = "TabBar", BackgroundColor3 = self.InlineColor, BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 30), Size = UDim2.new(1, -16, 0, 24), ZIndex = 2,
	}, Inner)
	self:AddToRegistry(TabBar, { BackgroundColor3 = "InlineColor" })
	self:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, TabBar)
	TabBar.ClipsDescendants = true
	self:Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.Name, Padding = UDim.new(0, 4),
	}, TabBar)

	local PagesRoot = self:Create("Frame", {
		Name = "PagesRoot", BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 56), Size = UDim2.new(1, -16, 1, -64),
	}, Inner)

	Window.Outer = Outer; Window.Inner = Inner; Window.Header = Header; Window.Body = Body
	Window.TabBar = TabBar; Window.PagesRoot = PagesRoot
	self.Windows[Outer] = Window

	-- attach Window-level API methods
	self:_attachWindowAPI(Window)
	return Window
end

-- Wire the friendly `Window:Page/Initialize/Toast/...` API onto the Window object.
function Library:_attachWindowAPI(Window)
	function Window:Page(info)        return Library:WindowPage(self, info) end
	function Window:Section(info)
		if not self.CurrentPage then self:Page({Name = "Home"}) end
		return self.CurrentPage:Section(info)
	end
	function Window:Initialize()        return Library:InitializeWindow(self) end
	function Window:ToggleVisibility()  return Library:ToggleWindowVisibility(self) end
	function Window:SetWindowTitle(t)   Library:SetWindowTitle(self, t) end
 	function Window:Toast(m, s, d)      return Library:Toast(m, s, d) end
	function Window:SetWatermark(b)     Library:SetWatermark(self, b) end
	function Window:SetStats(b)         Library:SetStats(self, b) end
	function Window:ToggleKeybindsList() Library:ToggleKeybindsList(self) end
	function Window:SetTheme(t)         Library:SetTheme(t) end
	function Window:GetConfig()         return Library:GetConfig() end
	function Window:LoadConfig(c)       return Library:LoadConfig(c) end
	function Window:Unload()            return Library:Unload(self) end
end

------------------------------- Page ===============================
local PageClass = {}
PageClass.__index = PageClass
function PageClass:Section(info)
	local col = (tostring(info and info.Side or "Left"):lower():match("r") and self.RightCol or self.LeftCol)
	return self.Library:Section(info, col, self.Window)
end

function Library:WindowPage(Window, info)
	info = info or {}
	local Name = info.Name or "Page"
	local Page = setmetatable({
		Window    = Window,
		Library   = self,
		Name      = Name,
		Index     = #Window.Pages,
		Frame     = nil,
	}, PageClass)

	local labelSize = self:GetTextBounds(Name, self.Font, self.FontSize + 1)
	local TabBtn = self:Create("TextButton", {
		Name = "Tab_" .. Name, Text = Name,
		BackgroundColor3 = self.BackgroundColor, BorderSizePixel = 0,
		TextColor3 = self.TextColorSub, TextSize = self.FontSize, Font = self.Font,
		AutoButtonColor = false, ClipsDescendants = true,
		Size = UDim2.new(0, labelSize.X + 20, 1, 0), ZIndex = 3,
	}, Window.TabBar)
	self:Create("UISizeConstraint", { MinSize = Vector2.new(60, 24) }, TabBtn)
	self:AddToRegistry(TabBtn, { BackgroundColor3 = "BackgroundColor", TextColor3 = "TextColorSub" })
	self:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, TabBtn)
	local Indicator = self:Create("Frame", {
		BackgroundColor3 = self.AccentColor, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, 0), Visible = false, ZIndex = 4,
	}, TabBtn)
	self:AddToRegistry(Indicator, { BackgroundColor3 = "AccentColor" })

	local Frame = self:Create("Frame", {
		Name = "PageFrame", BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), Visible = false, ZIndex = 2, ClipsDescendants = true,
	}, Window.PagesRoot)

	local LeftCol = self:Create("ScrollingFrame", {
		Name = "LeftCol", BackgroundTransparency = 1,
		Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(0.5, -12, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 0, BorderSizePixel = 0, ZIndex = 3,
	}, Frame)
	local RightCol = self:Create("ScrollingFrame", {
		Name = "RightCol", BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 6, 0, 0), Size = UDim2.new(0.5, -12, 1, 0),
		CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 0, BorderSizePixel = 0, ZIndex = 3,
	}, Frame)
	local LeftLayout = self:Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.Name, Padding = UDim.new(0, 8),
	}, LeftCol)
	local RightLayout = self:Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.Name, Padding = UDim.new(0, 8),
	}, RightCol)
	-- Auto-size each column's CanvasSize to fit its sections. Some executors
	-- (e.g. Potassium) do not expose `UIListLayout.AbsoluteContentSize` or its
	-- property-changed signal, so we sum child AbsoluteSize.Y and listen to a
	-- universally-valid signal: each child's `Size` (sections resize their
	-- own GroupBox) plus ChildAdded/ChildRemoved on the column.
	local function syncCanvas(col)
		if not col then return end
		local h, n = 0, 0
		local layout = col:FindFirstChildWhichIsA("UIListLayout")
		for _, child in ipairs(col:GetChildren()) do
			if child:IsA("GuiObject") then
				local ay = child.AbsoluteSize.Y
				if ay and ay > 0 then h, n = h + ay, n + 1 end
			end
		end
		local pad = 0
		if layout and layout.Padding then pad = (layout.Padding.Offset or 0) * math.max(n - 1, 0) end
		col.CanvasSize = UDim2.new(0, 0, 0, h + pad + 16)
	end
	local function watchChild(child, col)
		if not (child and child:IsA("GuiObject")) then return end
		local ok, sig = pcall(function() return child:GetPropertyChangedSignal("Size") end)
		if ok and sig then self:GiveSignal(sig:Connect(function() syncCanvas(col) end)) end
	end
	local function connectCanvas(col)
		syncCanvas(col)
		self:GiveSignal(col.ChildAdded:Connect(function(c) watchChild(c, col); syncCanvas(col) end))
		self:GiveSignal(col.ChildRemoved:Connect(function() syncCanvas(col) end))
	end
	connectCanvas(LeftCol)
	connectCanvas(RightCol)

	Page.Frame = Frame
	Page.TabBtn = TabBtn
	Page.Indicator = Indicator
	Page.LeftCol = LeftCol
	Page.RightCol = RightCol

	local function select()
		if Window.CurrentPage and Window.CurrentPage ~= Page then
			Window.CurrentPage.Frame.Visible = false
			Window.CurrentPage.Indicator.Visible = false
		end
		Window.CurrentTab = Page
		Window.CurrentPage = Page
		Frame.Visible = true
		Indicator.Visible = true
	end
	TabBtn.MouseButton1Click:Connect(select)

	table.insert(Window.Pages, Page)
	Page.Select = select

	-- auto-select the first page
	if #Window.Pages == 1 then select() end

	return Page
end

------------------------------- Section ===============================
local Section = {}      -- shared method table for Section instances
Section.__index = Section

function Library:Section(info, colFrame, Window)
	info = info or {}
	local pad = 8
	local BoxOuter = self:Create("Frame", {
		Name = "GroupBox", BackgroundColor3 = self.BackgroundColor, BorderSizePixel = 0, ClipsDescendants = true,
	}, colFrame)
	self:AddToRegistry(BoxOuter, { BackgroundColor3 = "BackgroundColor" })
	self:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, BoxOuter)

	local BoxInner = self:Create("Frame", {
		BackgroundColor3 = self.MainColor, BorderSizePixel = 0,
		Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(1, -2, 1, -2),
	}, BoxOuter)
	self:AddToRegistry(BoxInner, { BackgroundColor3 = "MainColor" })

	local Title = self:CreateLabel({
		BackgroundTransparency = 1, Text = info.Name or "Section",
		TextColor3 = self.TextColor, TextSize = self.FontSizeSmall,
		Position = UDim2.new(0, 8, 0, 2), Size = UDim2.new(1, -16, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
		Parent = BoxInner,
	})
	self:AddToRegistry(Title, { TextColor3 = "TextColor" })
	local LineTop = self:Create("Frame", { BackgroundColor3 = self.InlineColor, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1) }, BoxInner)
	local LineBottom = self:Create("Frame", { BackgroundColor3 = self.InlineColor, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1) }, BoxInner)
	self:AddToRegistry(LineTop, { BackgroundColor3 = "InlineColor" })
	self:AddToRegistry(LineBottom, { BackgroundColor3 = "InlineColor" })

	-- content container (auto-growing rows)
	local Container = self:Create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 20), Size = UDim2.new(1, -16, 0, 0),
	}, BoxInner)
	local List = self:Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.Name, Padding = UDim.new(0, 4),
	}, Container)

	-- Auto-size the GroupBox to fit its rows. Some executors (e.g. Potassium)
	-- do NOT expose `GuiObject.AbsoluteContentSize` (or its layout signal), so we
	-- measure content by summing child rows' AbsoluteSize.Y -- a core GuiObject
	-- property that exists in every Roblox/Luau surface.
	local function resize()
		local h, n = 0, 0
		for _, child in ipairs(Container:GetChildren()) do
			if child:IsA("GuiObject") then
				local ay = child.AbsoluteSize.Y
				if ay and ay > 0 then h, n = h + ay, n + 1 end
			end
		end
		local pad = 0
		if List and List.Padding then pad = (List.Padding.Offset or 0) * math.max(n - 1, 0) end
		BoxOuter.Size = UDim2.new(1, 0, 0, h + pad + 28 + 2)
	end
	-- prefer the layout signal; fall back to child events when the signal is absent
	local okSignal, sig = pcall(function() return List:GetPropertyChangedSignal("AbsoluteContentSize") end)
	if okSignal and sig then
		sig:Connect(resize)
	else
		self.Library:GiveSignal(Container.ChildAdded:Connect(resize))
		self.Library:GiveSignal(Container.ChildRemoved:Connect(resize))
	end
	-- initial sizing (deferred so AbsoluteSizes are computed)
	task.spawn(function()
		if Container:IsDescendantOf(game) then
			resize()
		end
	end)

	local instance = setmetatable({
		Window    = Window,
		Library   = self,
		Name      = info.Name or "Section",
		Side      = info.Side or "Left",
		Frame     = BoxOuter,
		Outer     = BoxOuter,
		Inner     = BoxInner,
		Container = Container,
		Header    = BoxInner,
		List      = List,
		Title     = Title,
		Info      = info,
	}, Section)

	-- row helper
	function instance:NewRow(height)
		return self.Library:Create("Frame", {
			BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or 18),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, self.Container)
	end
	function instance:Blank(size)
		self.Library:Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, size or 4) }, self.Container)
	end
	return instance
end

-- A widget object mixin with shared accessors.
local Widget = {}
function Widget:GetValue()    return self.Value end
function Widget:GetVisible()  return self.Object and self.Object.Visible end
function Widget:SetVisible(v) if self.Object then self.Object.Visible = v end self.Visible = v end
Widget.__index = Widget

function Library:RegisterPointer(WidgetObj, info)
	if not info.Pointer then return end
	self.pointers[info.Pointer] = {
		Get   = function() return WidgetObj.Value end,
		Set   = function(v)
			WidgetObj.Value = v
			if WidgetObj.SyncDisplay then WidgetObj:SyncDisplay() end
			if type(WidgetObj.OnChanged) == "function" then WidgetObj.OnChanged(v) end
		end,
		Type  = WidgetObj.Type,
		Object = WidgetObj,
	}
	if WidgetObj.Type == "Toggle" or WidgetObj.Type == "Keybind" then
		self.Toggles[info.Pointer] = WidgetObj
	end
	self.Options[info.Pointer] = WidgetObj
end

------------------------------- Widgets ===============================
-- ===== Toggle =====
function Section:Toggle(info)
	info = info or {}
	local text     = info.Name or info.Text or "Toggle"
	local pointer  = info.Pointer or info.pointer
	local default  = info.Default or false
	local risky    = info.Risky or false
	local callback = info.Callback or function() end
	local state    = default or false

	local Row = self:NewRow()
	local Box = self.Library:Create("Frame", {
		BackgroundColor3 = state and self.Library.AccentColor or self.Library.BackgroundColor,
		BorderColor3 = self.Library.OutlineColor, BorderSizePixel = 1,
		Size = UDim2.new(0, 14, 0, 14), ZIndex = 5, AutomaticSize = Enum.AutomaticSize.None,
	}, Row)
	self.Library:AddToRegistry(Box, {
		BackgroundColor3 = state and "AccentColor" or "BackgroundColor", BorderColor3 = "OutlineColor",
	})
	self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 3) }, Box)

	local function refresh()
		Box.BackgroundColor3 = state and self.Library.AccentColor or self.Library.BackgroundColor
		self.Library.RegistryMap[Box].Properties.BackgroundColor3 =
			state and "AccentColor" or "BackgroundColor"
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
		Parent = Row,
	})
	if risky then
		Label.TextColor3 = self.Library.RiskColor
		self.Library.RegistryMap[Label].Properties.TextColor3 = "RiskColor"
	end

	local function flip(v)
		state = (v == nil) and (not state) or v
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

	local Widget = setmetatable({
		Type = "Toggle", Value = state, TextLabel = Label, Object = Row,
		Container = self.Container, Library = self.Library, Section = self, Info = info, OnChanged = nil,
		SyncDisplay = refresh,
	}, Widget)
	function Widget:SetValue(v) flip(v == true) end
	function Widget:OnChanged(Func) self.OnChanged = Func end
	self.Library:RegisterPointer(Widget, info)
	return Widget
end

-- ===== Slider =====
function Section:Slider(info)
	info = info or {}
	local text      = info.Name or info.Text or "Slider"
	local minimum   = info.Minimum or 0
	local maximum   = info.Maximum or 100
	local default   = info.Default or minimum
	local decimals  = info.Decimals or 0
	local pointer   = info.Pointer or info.pointer
	local callback  = info.Callback or function() end
	local value     = math.clamp(tonumber(default) or minimum, minimum, maximum)

	local Row = self:NewRow()
	local Label = self.Library:CreateLabel({
		BackgroundTransparency = 1, Text = text, TextColor3 = self.Library.TextColor,
		TextSize = self.Library.FontSize, Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, 120, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5,
		Parent = Row,
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
		Parent = Row,
	})
	self.Library:AddToRegistry(ValueLabel, { TextColor3 = "TextColor" })

	local dragging = false
	local function setValue(v, fire)
		value = math.clamp(tonumber(v) or value, minimum, maximum)
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

-- ===== Button =====
function Section:Button(info)
	info = info or {}
	local text = info.Name or info.Text or "Button"
	local callback = info.Callback or function() end
	local h = info.Size or 24

	local Btn = self.Library:Create("TextButton", {
		Name = "Button", BackgroundColor3 = self.Library.InlineColor, BorderSizePixel = 1,
		BorderColor3 = self.Library.OutlineColor, Size = UDim2.new(1, 0, 0, h), Text = text,
		TextColor3 = self.Library.TextColor, TextSize = self.Library.FontSize, Font = self.Library.Font,
		AutoButtonColor = false, ZIndex = 5,
	}, self:NewRow(0))
	self.Library:AddToRegistry(Btn, { BackgroundColor3 = "InlineColor", BorderColor3 = "OutlineColor", TextColor3 = "TextColor" })
	self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Btn)
	self.Library:OnHighlight(Btn, Btn, {BackgroundColor3 = self.Library.AccentColor}, {BackgroundColor3 = self.Library.InlineColor})

	Btn.MouseButton1Click:Connect(function()
		if self.Library:MouseIsOverOpenedFrame() then return end
		self.Library:SafeCallback(callback)
	end)

	local Widget = setmetatable({
		Type = "Button", Value = false, Object = Btn, TextLabel = Btn,
		Container = self.Container, Library = self.Library, Section = self, Info = info,
	}, Widget)
	function Widget:OnChanged(f) end
	return Widget
end

-- ===== ButtonHolder =====
function Section:ButtonHolder(info)
	info = info or {}
	local buttons = info.Buttons or {}
	local h = info.Height or 24
	local Row = self.Library:Create("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h), AutomaticSize = Enum.AutomaticSize.Y,
	}, self.Container)
	local n = #buttons
	for i, def in ipairs(buttons) do
		local w = 1 / n
		local Btn = self.Library:Create("TextButton", {
			Name = "SubBtn_" .. i, BackgroundColor3 = self.Library.InlineColor, BorderSizePixel = 1,
			BorderColor3 = self.Library.OutlineColor, Size = UDim2.new(w, -8, 1, 0),
			Position = UDim2.new((i - 1) * w, 4, 0, 0), Text = def[1] or "",
			TextColor3 = self.Library.TextColor, TextSize = self.Library.FontSize, Font = self.Library.Font,
			AutoButtonColor = false, ZIndex = 5,
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

-- ===== Label / Divider =====
function Section:Label(info)
	info = info or {}
	local text = info.Name or info.Text or ""
	local Label = self.Library:CreateLabel({
		BackgroundTransparency = 1, Text = text,
		TextColor3 = info.TextColor3 or self.Library.TextColor,
		TextSize = info.TextSize or self.Library.FontSize,
		Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
		Parent = self.Container,
	})
	return { Object = Label, TextLabel = Label, Type = "Label", Library = self.Library, Section = self }
end

function Section:Divider()
	local div = self.Library:Create("Frame", {
		BackgroundColor3 = self.Library.InlineColor, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	}, self.Container)
	self.Library:AddToRegistry(div, { BackgroundColor3 = "InlineColor" })
	return { Object = div, Type = "Divider", Library = self.Library, Section = self }
end

-- ===== Dropdown =====
function Section:Dropdown(info)
	info = info or {}
	local text     = info.Name or info.Text or "Dropdown"
	local options  = info.Options or {}
	local default  = info.Default or 1
	if type(default) ~= "number" then default = 1 end
	if not options[default] then default = 1 end
	local pointer  = info.Pointer or info.pointer
	local callback = info.Callback or function() end
	local current  = default

	local Row = self:NewRow()
	local Label = self.Library:CreateLabel({
		BackgroundTransparency = 1, Text = text, TextColor3 = self.Library.TextColor,
		TextSize = self.Library.FontSize, Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -18, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
		Parent = Row,
	})
	self.Library:AddToRegistry(Label, { TextColor3 = "TextColor" })

	local Box = self.Library:Create("TextButton", {
		BackgroundColor3 = self.Library.InlineColor, BorderColor3 = self.Library.OutlineColor, BorderSizePixel = 1,
		Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 22), Text = tostring(options[current] or ""),
		TextColor3 = self.Library.TextColor, TextSize = self.Library.FontSize, Font = self.Library.Font,
		AutoButtonColor = false, ZIndex = 6, ClipsDescendants = true,
	}, Row)
	self.Library:AddToRegistry(Box, { BackgroundColor3 = "InlineColor", BorderColor3 = "OutlineColor", TextColor3 = "TextColor" })
	self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Box)

	local open = false
	local ListFrame
	local function close()
		open = false
		Library.OpenedFrame = nil
		if ListFrame then ListFrame:Destroy(); ListFrame = nil end
		self.Library._closeOpened = nil
	end
	local function openList()
		if open then return end
		open = true
		Library.OpenedFrame = Box
		self.Library._closeOpened = close
		local count = math.min(#options, 6)
		ListFrame = self.Library:Create("Frame", {
			BackgroundColor3 = self.Library.BackgroundColor, BorderColor3 = self.Library.OutlineColor, BorderSizePixel = 1,
			Size = UDim2.new(1, -4, 0, count * 22 + 4), Position = UDim2.new(0, 2, 0, 22), ZIndex = 7,
		}, Row)
		self.Library:AddToRegistry(ListFrame, { BackgroundColor3 = "BackgroundColor", BorderColor3 = "OutlineColor" })
		self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, ListFrame)
		for i, opt in ipairs(options) do
			local Btn = self.Library:Create("TextButton", {
				BackgroundColor3 = self.Library.BackgroundColor, BorderColor3 = self.Library.OutlineColor, BorderSizePixel = 1,
				Size = UDim2.new(1, -4, 0, 20), Position = UDim2.new(0, 2, 0, 2 + (i-1)*22),
				Text = tostring(opt), TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = (i == current) and self.Library.AccentColor or self.Library.TextColor,
				TextSize = self.Library.FontSize, Font = self.Library.Font,
				AutoButtonColor = false, ZIndex = 8,
			}, ListFrame)
			self.Library:AddToRegistry(Btn, { BackgroundColor3 = "BackgroundColor", BorderColor3 = "OutlineColor",
				TextColor3 = (i == current) and "AccentColor" or "TextColor" })
			self.Library:OnHighlight(Btn, Btn, {BackgroundColor3 = self.Library.AccentColor}, {BackgroundColor3 = self.Library.BackgroundColor})
			Btn.MouseButton1Click:Connect(function()
				current = i
				close()
				self.Library:SafeCallback(callback, opt, i)
				self.Library:SafeCallback(Widget.OnChanged, opt, i)
				if self.Library.SaveManager and self.Library.SaveOnLoad then self.Library.SaveManager:Save() end
			end)
		end
	end
	Box.MouseButton1Click:Connect(function()
		if open then close() else openList() end
	end)

	local Widget = setmetatable({
		Type = "Dropdown", Value = options[current], TextLabel = Label, Object = Row,
		Container = self.Container, Library = self.Library, Section = self, Info = info, OnChanged = nil,
		SetDisplay = function(w) Box.Text = tostring(options[current] or "") end,
	}, Widget)
	function Widget:SetValue(v)
		for i, opt in ipairs(options) do if opt == v then current = i; break end end
		Widget.Value = options[current]
		close()
		self.Library:SafeCallback(callback, options[current], current)
	end
	function Widget:GetValue() return options[current] end
	function Widget:OnChanged(Func) self.OnChanged = Func end
	function Widget:SetOptions(newOpts, newDefault)
		options = newOpts
		if newDefault then current = newDefault end
		if current < 1 or current > #options then current = 1 end
		Widget.Value = options[current]
		if open then Box.Text = tostring(options[current] or "") end
	end
	self.Library:RegisterPointer(Widget, info)
	return Widget
end

-- ===== Multibox =====
function Section:Multibox(info)
	info = info or {}
	local text     = info.Name or info.Text or "Multibox"
	local options  = info.Options or {}
	local default  = info.Default or {}
	local min      = info.Minimum or 1
	local pointer  = info.Pointer or info.pointer
	local callback = info.Callback or function() end
	local selected = {}
	for _, v in ipairs(default) do selected[v] = true end

	local function countSelected() local n=0; for _ in pairs(selected) do n=n+1 end; return n end
	local function toList() local t={}; for k in pairs(selected) do t[#t+1]=k end return t end

	local Row = self:NewRow()
	local Label = self.Library:CreateLabel({
		BackgroundTransparency = 1, Text = text, TextColor3 = self.Library.TextColor,
		TextSize = self.Library.FontSize, Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -18, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
		Parent = Row,
	})
	self.Library:AddToRegistry(Label, { TextColor3 = "TextColor" })

	local Box = self.Library:Create("TextButton", {
		BackgroundColor3 = self.Library.InlineColor, BorderColor3 = self.Library.OutlineColor, BorderSizePixel = 1,
		Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 22), Text = "None",
		TextColor3 = self.Library.TextColor, TextSize = self.Library.FontSize, Font = self.Library.Font,
		AutoButtonColor = false, ZIndex = 6, ClipsDescendants = true,
	}, Row)
	self.Library:AddToRegistry(Box, { BackgroundColor3 = "InlineColor", BorderColor3 = "OutlineColor", TextColor3 = "TextColor" })
	self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Box)

	local open = false
	local ListFrame
	local function updateText()
		local parts = toList()
		Box.Text = #parts > 0 and table.concat(parts, ", ") or "None"
	end
	updateText()
	local function close()
		open = false
		Library.OpenedFrame = nil
		if ListFrame then ListFrame:Destroy(); ListFrame = nil end
		self.Library._closeOpened = nil
	end
	local function openList()
		if open then return end
		open = true
		Library.OpenedFrame = Box
		self.Library._closeOpened = close
		ListFrame = self.Library:Create("Frame", {
			BackgroundColor3 = self.Library.BackgroundColor, BorderColor3 = self.Library.OutlineColor, BorderSizePixel = 1,
			Size = UDim2.new(1, -4, 0, #options * 22 + 4), Position = UDim2.new(0, 2, 0, 22), ZIndex = 7,
		}, Row)
		self.Library:AddToRegistry(ListFrame, { BackgroundColor3 = "BackgroundColor", BorderColor3 = "OutlineColor" })
		self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, ListFrame)
		for i, opt in ipairs(options) do
			local sel = selected[opt] or false
			local Btn = self.Library:Create("TextButton", {
				BackgroundColor3 = sel and self.Library.AccentColor or self.Library.BackgroundColor, BorderColor3 = self.Library.OutlineColor, BorderSizePixel = 1,
				Size = UDim2.new(1, -4, 0, 20), Position = UDim2.new(0, 2, 0, 2 + (i-1)*22),
				Text = tostring(opt), TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = sel and Color3.fromRGB(255,255,255) or self.Library.TextColor,
				TextSize = self.Library.FontSize, Font = self.Library.Font,
				AutoButtonColor = false, ZIndex = 8,
			}, ListFrame)
			self.Library:AddToRegistry(Btn, { BackgroundColor3 = sel and "AccentColor" or "BackgroundColor", BorderColor3 = "OutlineColor",
				TextColor3 = sel and "TextColor" or "TextColor" })
			 Btn.MouseButton1Click:Connect(function()
				local had = selected[opt] or false
				selected[opt] = not had
				if not selected[opt] then selected[opt] = nil end
				-- enforce minimum: never drop below `min` selections
				if had and countSelected() < min then selected[opt] = true end
				Btn.BackgroundColor3 = selected[opt] and self.Library.AccentColor or self.Library.BackgroundColor
				self.Library.RegistryMap[Btn].Properties.BackgroundColor3 = selected[opt] and "AccentColor" or "BackgroundColor"
				Btn.TextColor3 = selected[opt] and Color3.fromRGB(255,255,255) or self.Library.TextColor
				updateText()
				local list = toList()
				Widget.Value = list
				self.Library:SafeCallback(callback, list)
				self.Library:SafeCallback(Widget.OnChanged, list)
				if self.Library.SaveManager and self.Library.SaveOnLoad then self.Library.SaveManager:Save() end
			end)
		end
	end
	Box.MouseButton1Click:Connect(function() if open then close() else openList() end end)

	local Widget = setmetatable({
		Type = "Multibox", Value = toList(), TextLabel = Label, Object = Row,
		Container = self.Container, Library = self.Library, Section = self, Info = info, OnChanged = nil,
	}, Widget)
	function Widget:SetValue(list)
		selected = {}; for _, v in ipairs(list) do selected[v] = true end
		Widget.Value = toList(); updateText()
		self.Library:SafeCallback(callback, toList())
	end
	function Widget:GetValue() return toList() end
	function Widget:OnChanged(Func) self.OnChanged = Func end
	function Widget:SyncDisplay() updateText() end
	function Widget:SetOptions(newOpts, newDefault)
		options = newOpts; selected = {}; if newDefault then for _,v in ipairs(newDefault) do selected[v]=true end end
		Widget.Value = toList(); updateText()
	end
	self.Library:RegisterPointer(Widget, info)
	return Widget
end

-- ===== Keybind =====
-- Some executors lack `Enum.KeyCode.FromString`; `Enum.KeyCode[name]` works via
-- the Enum's string indexer and is universally supported. Fall back to E.
local function resolveKeyCode(name)
	if typeof(name) ~= "string" then return nil end
	local enum = Enum.KeyCode
	if not enum then return nil end
	local ok, item = pcall(function() return enum[name] end)
	if ok and item and typeof(item) == "EnumItem" then return item end
	ok, item = pcall(function() return enum.FromString(name) end)
	if ok and item and typeof(item) == "EnumItem" then return item end
	return nil
end
Library.ResolveKeyCode = resolveKeyCode

function Section:Keybind(info)
	info = info or {}
	local text         = info.Name or info.Text or "Keybind"
	local keybindName  = info.KeybindName or text
	local mode         = info.Mode or "Toggle"   -- Hold | Toggle | Always
	local default      = info.Default or Enum.KeyCode.E
	if typeof(default) == "string" then
		default = resolveKeyCode(default) or Enum.KeyCode.E
	end
	local pointer     = info.Pointer or info.pointer
	local callback     = info.Callback or function() end
	local currentKey  = default
	local pressed     = false

	local Row = self:NewRow()
	local Label = self.Library:CreateLabel({
		BackgroundTransparency = 1, Text = text, TextColor3 = self.Library.TextColor,
		TextSize = self.Library.FontSize, Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -18, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
		Parent = Row,
	})
	self.Library:AddToRegistry(Label, { TextColor3 = "TextColor" })

	local KeyBox = self.Library:Create("TextButton", {
		BackgroundColor3 = self.Library.InlineColor, BorderColor3 = self.Library.OutlineColor, BorderSizePixel = 1,
		Size = UDim2.new(0, 90, 0, 20), Position = UDim2.new(1, -92, 0, 0), Text = tostring(currentKey.Name),
		TextColor3 = self.Library.AccentColor, TextSize = self.Library.FontSize, Font = self.Library.Font,
		AutoButtonColor = false, ZIndex = 6, ClipsDescendants = true,
	}, Row)
	self.Library:AddToRegistry(KeyBox, { BackgroundColor3 = "InlineColor", BorderColor3 = "OutlineColor", TextColor3 = "AccentColor" })
	self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, KeyBox)

	local function updateText()
		KeyBox.Text = tostring(currentKey.Name or currentKey)
	end
	updateText()

	local rebinding = false
	local function fireCb(extra)
		self.Library:SafeCallback(callback, currentKey, pressed, extra)
	end
	local function finishRebind(KeyCode)
		if not rebinding then return end
		currentKey = (KeyCode and KeyCode ~= Enum.KeyCode.Unknown) and KeyCode or currentKey
		updateText()
		rebinding = false
		Library.OpenedFrame = nil
		self.Library._closeOpened = nil
		self.Library:SafeCallback(callback, currentKey, pressed, true)
		if self.Library.pointers[pointer] then self.Library.pointers[pointer].Value = currentKey end
		if self.Library.keybindslist then self.Library.keybindslist:Update() end
		if self.Library.SaveManager and self.Library.SaveOnLoad then self.Library.SaveManager:Save() end
	end

	KeyBox.MouseButton1Click:Connect(function()
		if not rebinding then
			rebinding = true
			KeyBox.Text = "Press a key..."
			Library.OpenedFrame = KeyBox
			self.Library._closeOpened = function() rebinding = false; KeyBox.Text = tostring(currentKey.Name); Library.OpenedFrame = nil end
		end
	end)

	self.Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input, GameProcessed)
		if not rebinding then
			if mode == "Always" and not GameProcessed and Input.KeyCode ~= Enum.KeyCode.Unknown then
			elseif Input.KeyCode == currentKey and not GameProcessed then
				if mode == "Hold" then
					pressed = true
					fireCb()
				elseif mode == "Toggle" then
					pressed = not pressed
					fireCb()
				end
			end
		else
			if Input.KeyCode ~= Enum.KeyCode.Unknown then
				finishRebind(Input.KeyCode)
			end
		end
	end))
	self.Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input, GameProcessed)
		if not rebinding and Input.KeyCode == currentKey and mode == "Hold" then
			pressed = false
			fireCb()
		end
	end))

	if self.Library.keybindslist then
		self.Library.keybindslist:Add(keybindName, tostring(currentKey.Name or currentKey))
	end

	local Widget = setmetatable({
		Type = "Keybind", Value = currentKey, Object = Row, TextLabel = Label,
		Container = self.Container, Library = self.Library, Section = self, Info = info, OnChanged = nil,
		Mode = mode, Pressed = pressed,
	}, Widget)
	function Widget:SetValue(KeyCode)
		if type(KeyCode) == "string" then KeyCode = resolveKeyCode(KeyCode) or KeyCode end
		currentKey = KeyCode
		updateText()
		if self.Library.keybindslist then self.Library.keybindslist:Update() end
	end
	function Widget:GetValue() return currentKey end
	function Widget:GetPressed() return pressed end
	function Widget:OnChanged(Func) self.OnChanged = Func end
	self.Library:RegisterPointer(Widget, info)
	return Widget
end

-- ===== Colorpicker =====
function Section:Colorpicker(info)
	info = info or {}
	local text    = info.Name or info.Text or "Colorpicker"
	local infoTxt = info.Info or ""
	local default = info.Default or Color3.fromRGB(255, 0, 0)
	local alpha   = info.Alpha or 1
	local pointer = info.Pointer or info.pointer
	local callback = info.Callback or function() end
	local color   = default
	local alphaVal = alpha

	local Row = self:NewRow()
	local top = self.Library:Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18) }, Row)
	local Label = self.Library:CreateLabel({
		BackgroundTransparency = 1, Text = text, TextColor3 = self.Library.TextColor,
		TextSize = self.Library.FontSize, Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -82, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
		Parent = top,
	})
	self.Library:AddToRegistry(Label, { TextColor3 = "TextColor" })
	if infoTxt ~= "" then
		local InfoL = self.Library:CreateLabel({
			BackgroundTransparency = 1, Text = infoTxt, TextColor3 = self.Library.TextColorSub,
			TextSize = self.Library.FontSizeSmall, Position = UDim2.new(1, -2, 0, 0),
			Size = UDim2.new(0, 100, 0, 14), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5,
			Parent = top,
		})
		self.Library:AddToRegistry(InfoL, { TextColor3 = "TextColorSub" })
	end

	local Swatch = self.Library:Create("TextButton", {
		BackgroundColor3 = color, BorderSizePixel = 0, Text = "",
		AutoButtonColor = false, Font = self.Library.Font, TextSize = self.Library.FontSize,
		TextColor3 = Color3.fromRGB(255, 255, 255), TextTransparency = 1,
		Size = UDim2.new(0, 80, 0, 80), Position = UDim2.new(1, -82, 0, 0), ZIndex = 6,
	}, Row)
	self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Swatch)

	local open = false
	local picker
	local function updateCb()
		self.Library:SafeCallback(callback, color, alphaVal)
		self.Library:SafeCallback(Widget.OnChanged, color, alphaVal)
	end

	local function close()
		open = false
		Library.OpenedFrame = nil
		if picker then picker:Destroy(); picker = nil end
		self.Library._closeOpened = nil
	end

	local function openPicker()
		if open then return end
		open = true
		Library.OpenedFrame = Swatch
		self.Library._closeOpened = close
		picker = self.Library:Create("Frame", {
			BackgroundColor3 = self.Library.BackgroundColor, BorderColor3 = self.Library.OutlineColor, BorderSizePixel = 1,
			Size = UDim2.new(0, 220, 0, 230), Position = UDim2.new(0, 0, 1, 6), ZIndex = 8,
		}, Row)
		self.Library:AddToRegistry(picker, { BackgroundColor3 = "BackgroundColor", BorderColor3 = "OutlineColor" })
		self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, picker)

		local preview = self.Library:Create("Frame", {
			BackgroundColor3 = color, BorderSizePixel = 0,
			Size = UDim2.new(0, 56, 0, 56), Position = UDim2.new(0, 8, 0, 8), ZIndex = 9,
		}, picker)
		self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, preview)

		local hueTrack = self.Library:Create("Frame", {
			BackgroundColor3 = self.Library.InlineColor, BorderSizePixel = 0,
			Size = UDim2.new(1, -16, 0, 10), Position = UDim2.new(0, 8, 0, 78), ZIndex = 9,
		}, picker)
		self.Library:AddToRegistry(hueTrack, { BackgroundColor3 = "InlineColor" })
		local hueFill = self.Library:Create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 0, 0), BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 1, 0), ZIndex = 10,
		}, hueTrack)
		local hueKnob = self.Library:Create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0,
			Size = UDim2.new(0, 6, 0, 16), ZIndex = 10,
		}, hueTrack)

		local alphaTrack = self.Library:Create("Frame", {
			BackgroundColor3 = self.Library.InlineColor, BorderSizePixel = 0,
			Size = UDim2.new(1, -16, 0, 10), Position = UDim2.new(0, 8, 0, 104), ZIndex = 9,
		}, picker)
		self.Library:AddToRegistry(alphaTrack, { BackgroundColor3 = "InlineColor" })
		local alphaFill = self.Library:Create("Frame", {
			BackgroundColor3 = color, BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0), ZIndex = 10, Transparency = 1 - alphaVal,
		}, alphaTrack)
		local alphaKnob = self.Library:Create("Frame", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0,
			Size = UDim2.new(0, 6, 0, 16), ZIndex = 10,
		}, alphaTrack)

		local h, s, v = color:ToHSV()
		local function setHue(newH)
			h = newH
			color = Color3.fromHSV(h, s, v)
			Swatch.BackgroundColor3 = color
			hueFill.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			hueFill.Size = UDim2.new(math.clamp(h, 0.001, 1), 0, 1, 0)
			hueKnob.Position = UDim2.new(math.clamp(h, 0.02, 0.98), 0, 0, 0)
			alphaFill.BackgroundColor3 = color
			updateCb()
		end
		local function setAlpha(a)
			alphaVal = math.clamp(a, 0, 1)
			alphaFill.Transparency = 1 - alphaVal
			alphaKnob.Position = UDim2.new(math.clamp(alphaVal, 0.02, 0.98), 0, 0, 0)
			updateCb()
		end
		setHue(h)

		local draggingHue, draggingAlpha = false, false
		self.Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input, GameProcessed)
			if GameProcessed then return end
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then
				local mouse = UserInputService:GetMouseLocation()
				local function inside(inst)
					if not inst or not inst.AbsoluteSize then return false end
					return mouse.X >= inst.AbsolutePosition.X and mouse.X <= inst.AbsolutePosition.X + inst.AbsoluteSize.X
						and mouse.Y >= inst.AbsolutePosition.Y and mouse.Y <= inst.AbsolutePosition.Y + inst.AbsoluteSize.Y
				end
				if inside(hueTrack) then draggingHue = true end
				if inside(alphaTrack) then draggingAlpha = true end
			end
		end))
		self.Library:GiveSignal(UserInputService.InputChanged:Connect(function(Input)
			if Input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
			if draggingHue then
				local rel = UserInputService:GetMouseLocation().X - hueTrack.AbsolutePosition.X
				setHue(math.clamp(rel / math.max(hueTrack.AbsoluteSize.X - 2, 1), 0, 1))
			elseif draggingAlpha then
				local rel = UserInputService:GetMouseLocation().X - alphaTrack.AbsolutePosition.X
				setAlpha(rel / math.max(alphaTrack.AbsoluteSize.X - 2, 1))
			end
		end))
		self.Library:GiveSignal(UserInputService.InputEnded:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue, draggingAlpha = false, false end
		end))
	end
	Swatch.MouseButton1Click:Connect(function()
		if open then close() else openPicker() end
	end)

	local Widget = setmetatable({
		Type = "Colorpicker",
		Value = { Color = color, Transparency = alphaVal },
		Object = Row, TextLabel = Label, Swatch = Swatch,
		Container = self.Container, Library = self.Library, Section = self, Info = info, OnChanged = nil,
	}, Widget)
	function Widget:SetValue(c, a)
		color = c
		if a then alphaVal = a end
		Swatch.BackgroundColor3 = color
		updateCb()
	end
	function Widget:GetValue() return { Color = color, Transparency = alphaVal } end
	function Widget:OnChanged(Func) self.OnChanged = Func end
	function Widget:SyncDisplay() Swatch.BackgroundColor3 = color end
	self.Library:RegisterPointer(Widget, info)
	return Widget
end

-- ===== TextBox =====
function Section:TextBox(info)
	info = info or {}
	local text      = info.Name or info.Text or "Textbox"
	local default   = info.Default or ""
	local placeholder = info.Placeholder or ""
	local pointer   = info.Pointer or info.pointer
	local callback  = info.Callback or function() end

	local Row = self:NewRow()
	local Label = self.Library:CreateLabel({
		BackgroundTransparency = 1, Text = text, TextColor3 = self.Library.TextColor,
		TextSize = self.Library.FontSize, Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, -18, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
		Parent = Row,
	})
	self.Library:AddToRegistry(Label, { TextColor3 = "TextColor" })

	local Box = self.Library:Create("TextBox", {
		BackgroundColor3 = self.Library.InlineColor, BorderColor3 = self.Library.OutlineColor, BorderSizePixel = 1,
		Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 20),
		Text = default, PlaceholderText = placeholder, ClearTextOnFocus = false,
		TextColor3 = self.Library.TextColor, TextSize = self.Library.FontSize, Font = self.Library.Font,
		TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
	}, Row)
	self.Library:AddToRegistry(Box, { BackgroundColor3 = "InlineColor", BorderColor3 = "OutlineColor", TextColor3 = "TextColor" })
	self.Library:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, Box)

	Box.FocusLost:Connect(function(enterPressed)
		self.Library:SafeCallback(callback, Box.Text, enterPressed)
		self.Library:SafeCallback(Widget.OnChanged, Box.Text, enterPressed)
		if self.Library.SaveManager and self.Library.SaveOnLoad then self.Library.SaveManager:Save() end
	end)
	Box.Focused:Connect(function()
		Box.BorderColor3 = self.Library.AccentColor
	end)

	local Widget = setmetatable({
		Type = "Input", Value = Box.Text, Object = Row, TextLabel = Label,
		Container = self.Container, Library = self.Library, Section = self, Info = info, OnChanged = nil,
	}, Widget)
	function Widget:SetValue(v) Box.Text = tostring(v); Widget.Value = Box.Text end
	function Widget:GetValue() return Box.Text end
	function Widget:OnChanged(Func) self.OnChanged = Func end
	self.Library:RegisterPointer(Widget, info)
	return Widget
end
Section.TextBox = Section.TextBox  -- alias

------------------------------- Extras ===============================
-- outside-click closes any open dropdown/multibox/picker
Library._closeOpened = nil
Library:GiveSignal(UserInputService.InputBegan:Connect(function(Input, GameProcessed)
	if GameProcessed then return end
	if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
	if Library.OpenedFrame and Library._closeOpened then
		Library._closeOpened()
	end
end))

------------------------------- Window extras ===============================
function Library:Toast(message, style, duration)
	if not self._ScreenGui then return end
	return self.toasts:Add(message, style, duration)
end
function Library:SetWatermark(Window, enabled)
	if not Window._WatermarkFrame then
		local wmFrame = self:Create("Frame", {
			BackgroundColor3 = self.BackgroundColor, BorderColor3 = self.AccentColor, BorderSizePixel = 1,
			Size = UDim2.new(0, 180, 0, 22), Visible = false, ZIndex = 100,
		}); self:Create("UICorner", { CornerRadius = UDim.new(0, 4) }, wmFrame)
		self:AddToRegistry(wmFrame, { BackgroundColor3 = "BackgroundColor", BorderColor3 = "AccentColor" })
		local wmText = self:CreateLabel({
			BackgroundTransparency = 1, Text = "", TextColor3 = self.TextColor,
			TextSize = self.FontSizeSmall, Position = UDim2.new(0, 6, 0, 2),
			Size = UDim2.new(1, -12, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 101,
		}); self:AddToRegistry(wmText, { TextColor3 = "TextColor" })
		wmText.Parent = wmFrame
		wmFrame.Parent = self._ScreenGui
		Window._WatermarkFrame = wmFrame
		Window._WatermarkText  = wmText
		self.watermark.enabled = enabled
		self.watermark:Visibility()
	end
	self.watermark.enabled = enabled
	self.watermark:Visibility()
end
function Library:SetStats(Window, enabled)
	if not Window._StatsFrame then
		local sf = self:Create("Frame", {
			BackgroundColor3 = self.BackgroundColor, BorderColor3 = self.OutlineColor, BorderSizePixel = 1,
			Size = UDim2.new(0, 116, 0, 36), Visible = false, ZIndex = 100,
		}); self:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, sf)
		self:AddToRegistry(sf, { BackgroundColor3 = "BackgroundColor", BorderColor3 = "OutlineColor" })
		local fpsT = self:CreateLabel({ BackgroundTransparency = 1, Text = "FPS: 0", TextColor3 = self.TextColor,
			TextSize = self.FontSizeSmall, Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(1, -12, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 101 })
		self:AddToRegistry(fpsT, { TextColor3 = "TextColor" })
		local pingT = self:CreateLabel({ BackgroundTransparency = 1, Text = "Ping: 0ms", TextColor3 = self.TextColorSub,
			TextSize = self.FontSizeSmall, Position = UDim2.new(0, 6, 0, 18), Size = UDim2.new(1, -12, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 101 })
		self:AddToRegistry(pingT, { TextColor3 = "TextColorSub" })
		fpsT.Parent = sf; pingT.Parent = sf; sf.Parent = self._ScreenGui
		Window._StatsFrame = sf; Window._StatsFPS = fpsT; Window._StatsPing = pingT
	end
	self.stats.enabled = enabled
	self.stats.fpsText = Window._StatsFPS
	self.stats.pingText = Window._StatsPing
	if enabled then
		Window._StatsFrame.Visible = true
		self.stats:UpdatePosition()
	else
		Window._StatsFrame.Visible = false
	end
end

function Library:ToggleKeybindsList(Window)
	self.keybindslist.open = not self.keybindslist.open
	if self.keybindslist.open then
		if not Window._KeybindsFrame then
			local vp = getViewportSize()
			local fr = self:Create("Frame", {
				BackgroundColor3 = self.BackgroundColor, BorderColor3 = self.OutlineColor, BorderSizePixel = 1,
				Size = UDim2.new(0, 170, 0, 30), Position = UDim2.new(0, vp.X - 182, 0, 30), ZIndex = 200,
			}); self:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, fr)
			self:AddToRegistry(fr, { BackgroundColor3 = "BackgroundColor", BorderColor3 = "OutlineColor" })
			fr.Parent = self._ScreenGui
			Window._KeybindsFrame = fr
			self:MakeDraggable(fr, 999)
		end
		self.keybindslist.frame = Window._KeybindsFrame
		self.keybindslist:Update()
		Window._KeybindsFrame.Visible = true
	else
		if Window._KeybindsFrame then Window._KeybindsFrame.Visible = false end
		self.keybindslist:Hide()
	end
end

-- Watermark object
Library.watermark = { enabled = false, frame = nil, text = nil }
function Library.watermark:UpdateSize()
	local vp = getViewportSize()
	self.frame.Size = UDim2.new(0, 182, 0, 24)
	self.frame.Position = UDim2.new(0, vp.X - 192, 0, 8)
	self.text.Size = UDim2.new(0, 168, 0, 20)
	self.text.Position = UDim2.new(0, 4, 0, 2)
end
function Library.watermark:Visibility()
	if not self.frame then return end
	if not self.enabled then self.frame.Visible = false; self.text.Visible = false; return end
	self.frame.Visible = true; self.text.Visible = true
	self:UpdateSize()
end
function Library.watermark:Hide()
	if self.frame then self.frame.Visible = false end
	if self.text then self.text.Visible = false end
	self.enabled = false
end
function Library.watermark:Update()
	if not self.enabled or not self.text then return end
	self.text.Text = string.format("%s  |  FPS: %d  |  Ping: %dms",
		Library._WatermarkPrefix or "SeriousHook", Library.shared.fps or 0, Library.shared.ping or 0)
end

-- Stats object
Library.stats = { enabled = false, fpsText = nil, pingText = nil }
function Library.stats:UpdatePosition()
	local vp = getViewportSize()
	if self.fpsText and self.fpsText.Parent then self.fpsText.Position = UDim2.new(0, 10, 0, vp.Y - 50) end
	if self.pingText and self.pingText.Parent then self.pingText.Position = UDim2.new(0, 10, 0, vp.Y - 32) end
end
function Library.stats:Visibility()
	if not self.enabled then return end
	if self.fpsText then self.fpsText.Visible = true end
	if self.pingText then self.pingText.Visible = true end
	self:UpdatePosition()
end
function Library.stats:Hide()
	if self.fpsText then self.fpsText.Visible = false end
	if self.pingText then self.pingText.Visible = false end
	self.enabled = false
end
function Library.stats:Update()
	if not self.enabled then return end
	if self.fpsText then self.fpsText.Text = "FPS: " .. tostring(Library.shared.fps or 0) end
	if self.pingText then self.pingText.Text = "Ping: " .. tostring(Library.shared.ping or 0) .. "ms" end
end

-- Toast (notification) object
local ToastStyles = {
	info    = Color3.fromRGB(80, 160, 255),
	success = Color3.fromRGB(80, 255, 130),
	warn    = Color3.fromRGB(255, 200, 60),
	error   = Color3.fromRGB(255, 70, 70),
}
Library.toasts = { active = {}, nextId = 1 }
function Library.toasts:Add(message, style, duration)
	style = style or "info"; duration = duration or 3.5
	local color = ToastStyles[style] or ToastStyles.info
	local id = self.nextId; self.nextId = self.nextId + 1
	local screen = Library._ScreenGui
	if not screen then return id end
	local vp = getViewportSize()
	local toastW, toastH = 230, 38
	local baseY = vp.Y - 14 - (#self.active) * (toastH + 6)

	local frame = Library:Create("Frame", {
		BackgroundColor3 = Library.BackgroundColor, BorderColor3 = color, BorderSizePixel = 1,
		Size = UDim2.new(0, toastW, 0, toastH), Position = UDim2.new(vp.X - toastW - 14, 0, 0, baseY),
		ZIndex = 100, ClipsDescendants = true,
	}); Library:Create("UICorner", { CornerRadius = UDim.new(0, 6) }, frame)
	local bar = Library:Create("Frame", {
		BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.new(0, 3, 1, 0), ZIndex = 101,
	}); bar.Parent = frame
	local label = Library:CreateLabel({
		BackgroundTransparency = 1, Text = tostring(message), TextColor3 = Library.TextColor,
		TextSize = Library.FontSizeSmall, Position = UDim2.new(0, 8, 0, 6),
		Size = UDim2.new(1, -12, 1, -12), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 102,
	}); Library:AddToRegistry(frame, { BackgroundColor3 = "BackgroundColor" })
	label.Parent = frame

	local entry = { id = id, frame = frame, bar = bar, label = label,
		style = style, duration = duration, elapsed = 0, removed = false }
	self.active[#self.active + 1] = entry
	frame.BackgroundTransparency = 1
	Library:Tween(frame, 0.2, {BackgroundTransparency = 0})
	return id
end
function Library.toasts:Remove(id)
	for i, e in ipairs(self.active) do
		if e.id == id and not e.removed then
			e.removed = true
			Library:Tween(e.frame, 0.2, {BackgroundTransparency = 1})
			task.delay(0.2, function()
				if e.frame then e.frame:Destroy() end
				if e.bar then e.bar:Destroy() end
				if e.label then e.label:Destroy() end
			end)
			table.remove(self.active, i)
			self:Reposition()
			return
		end
	end
end
function Library.toasts:Reposition()
	local vp = getViewportSize()
	for i, e in ipairs(self.active) do
		if e.frame then
			e.frame.Position = UDim2.new(vp.X - 230 - 14, 0, 0, vp.Y - 14 - (i-1) * (38 + 6))
		end
	end
end
function Library.toasts:Update(delta)
	for i = #self.active, 1, -1 do
		local e = self.active[i]
		if not e.removed then
			e.elapsed = e.elapsed + delta
			if e.elapsed >= e.duration then self:Remove(e.id) end
		end
	end
end
function Library.toasts:Clear()
	for i = #self.active, 1, -1 do self:Remove(self.active[i].id) end
end

-- Keybinds list object
Library.keybindslist = { open = false, entries = {}, frame = nil, _labels = {} }
function Library.keybindslist:Add(name, indicator)
	self.entries[#self.entries + 1] = { name = name, indicator = indicator }
	if self.frame then self:Update() end
end
function Library.keybindslist:Remove(name)
	for i, e in ipairs(self.entries) do
		if e.name == name then table.remove(self.entries, i); break end
	end
	if self.frame then self:Update() end
end
function Library.keybindslist:Hide()
	self.open = false
	if self.frame then self.frame.Visible = false end
	for _, l in ipairs(self._labels) do if l then l.Visible = false end end
end
function Library.keybindslist:Update()
	if not self.open or not self.frame then return end
	for _, l in ipairs(self._labels) do if l then l:Destroy() end end
	self._labels = {}
	local yOff = 24
	for _, e in ipairs(self.entries) do
		local lbl = Library:CreateLabel({
			BackgroundTransparency = 1, Text = e.name .. ": " .. tostring(e.indicator),
			TextColor3 = Library.TextColor, TextSize = Library.FontSizeSmall,
			Position = UDim2.new(0, 8, 0, yOff), Size = UDim2.new(1, -16, 0, 14),
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 980,
		}); lbl.Parent = self.frame
		self._labels[#self._labels + 1] = lbl
		yOff = yOff + 16
	end
	self.frame.Size = UDim2.new(0, 170, 0, math.max(34, yOff))
end

------------------------------- Render loop ===============================
local renderConn
local _fpsAccum, _fpsFrames, _fpsTimer = 0, 0, 0
local function onRender(Delta)
	Library.shared.tick = (Library.shared.tick or 0) + Delta
	-- FPS: count frames over a rolling window (no executor-specific API needed)
	_fpsAccum = _fpsAccum + Delta; _fpsFrames = _fpsFrames + 1; _fpsTimer = _fpsTimer + Delta
	if _fpsTimer >= 0.25 then
		if _fpsAccum > 0 then Library.shared.fps = math.floor(_fpsFrames / _fpsAccum) end
		_fpsAccum, _fpsFrames, _fpsTimer = 0, 0, 0
	end
	-- ping (resilient: StatsService may expose a stats object or a plain number)
	pcall(function()
		local total = StatsService:GetTotalPing()
		if typeof(total) == "number" then Library.shared.ping = math.floor(total) end
		if type(total) == "table" then Library.shared.ping = math.floor(tonumber(total.Average) or 0) end
	end)
	if Library.watermark and Library.watermark.enabled then Library.watermark:Update() end
	if Library.stats and Library.stats.enabled then Library.stats:Update(); Library.stats:UpdatePosition() end
	if Library.toasts then Library.toasts:Update(Delta) end
end
renderConn = RunService.RenderStepped:Connect(onRender)
Library:GiveSignal(renderConn)

------------------------------- Config I/O ===============================
local function colorToHex(c)
	return string.format("%02x%02x%02x", math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
end
local function hexToColor(h)
	h = h:gsub("#", "")
	local r, g, b = tonumber(h:sub(1,2),16), tonumber(h:sub(3,4),16), tonumber(h:sub(5,6),16)
	return Color3.fromRGB(r or 0, g or 0, b or 0)
end

-- Produce a JSON-safe value tree (Roblox Color3/EnumItem can't be JSONEncoded directly).
local function toJSONSafe(value)
	local t = typeof(value)
	if t == "string" or t == "boolean" or t == "number" then
		return value
	elseif t == "Color3" then
		return colorToHex(value)
	elseif t == "EnumItem" then
		return value.Name or tostring(value)
	elseif t == "table" then
		if value.Color and typeof(value.Color) == "Color3" then
			return { Color = colorToHex(value.Color), Transparency = tonumber(value.Transparency) or 1 }
		end
		local out, isArr = {}, (#value > 0)
		if isArr then
			for i, v in ipairs(value) do out[i] = toJSONSafe(v) end
		else
			for k, v in pairs(value) do out[k] = toJSONSafe(v) end
		end
		return out
	end
	return tostring(value)
end

-- Apply a decoded config value to a widget, dispatching on type so the
-- widget's own SetValue (which updates display + fires OnChanged) is used.
local function applyValue(entry, value)
	local obj = entry.Object
	if not obj then entry.Set(value); return end
	local t = entry.Type
	if t == "Colorpicker" then
		local c = (type(value) == "table" and value.Color) or value
		local a = type(value) == "table" and tonumber(value.Transparency) or 1
		if type(c) == "string" then c = hexToColor(c) end
		if obj.SetValue then obj:SetValue(c, a) else entry.Set(value) end
	elseif t == "Keybind" then
		if type(value) == "string" then value = (resolveKeyCode(value) or Enum.KeyCode.E) end
		if obj.SetValue then obj:SetValue(value) else entry.Set(value) end
	elseif t == "Toggle" or t == "Slider" or t == "Dropdown" or t == "Multibox" or t == "Input" then
		if obj.SetValue then obj:SetValue(value) else entry.Set(value) end
	else
		entry.Set(value)
	end
end

function Library:GetConfig()
	local data = {}
	for pointer, entry in pairs(self.pointers) do
		data[pointer] = toJSONSafe(entry.Get())
	end
	return HttpService:JSONEncode(data)
end

function Library:LoadConfig(configStr)
	local ok, data = pcall(function() return HttpService:JSONDecode(configStr) end)
	if not ok then
		self:CaptureError(data, "LoadConfig")
		return false
	end
	for pointer, value in pairs(data) do
		local entry = self.pointers[pointer]
		if entry then
			local t = entry.Type
			if t == "Colorpicker" and type(value) == "table" and type(value.Color) == "string" then
				value = { Color = hexToColor(value.Color), Transparency = tonumber(value.Transparency) or 1 }
			end
			applyValue(entry, value)
		end
	end
	return true
end

function Library:GetConfigTable()
	local data = {}
	for pointer, entry in pairs(self.pointers) do data[pointer] = toJSONSafe(entry.Get()) end
	return data
end

------------------------------- Theming ================================
function Library:SetTheme(theme)
	for k, v in pairs(theme) do
		if k == "Font" and typeof(v) == "EnumItem" then
			self.Font = v; Theme.Font = v
		elseif k == "FontSize" or k == "textsize" then
			self.FontSize = v; Theme.FontSize = v
		elseif self[k] ~= nil then
			self[k] = v
			Theme[k] = v
		end
	end
	self.AccentColorDark = self:GetDarkerColor(self.AccentColor)
	self:UpdateColorsUsingRegistry()
	self.watermark:Update()
	if self.ThemeManager then self.ThemeManager:ThemeUpdate() end
end

------------------------------- Init / Unload ===============================
function Library:InitializeWindow(Window)
	if shared.initialized then return end
	shared.initialized = true
	self.Loaded = true
	if Window.CurrentPage then Window.CurrentPage:Select() end
	Window.Outer.Visible = true
	self:Tween(Window.Outer, self.WindowFade, {BackgroundTransparency = 0})
	self.Toggled = true
	-- toggle-keybind
	self:GiveSignal(UserInputService.InputBegan:Connect(function(Input, GameProcessed)
		if GameProcessed then return end
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			if tostring(Input.KeyCode.Name) == tostring(self.ToggleKeybind) then
				self:ToggleWindowVisibility(Window)
			end
		end
	end))
	return Window
end

function Library:ToggleWindowVisibility(Window)
	if not Window or not Window.Outer then return end
	local visible = not Window.Outer.Visible
	Window.Outer.Visible = visible
	self.Toggled = visible
	if visible then
		self:Tween(Window.Outer, self.WindowFade, {BackgroundTransparency = 0})
	else
		self:Tween(Window.Outer, self.WindowFade, {Size = Window.Outer.Size})
		if Window._KeybindsFrame then Window._KeybindsFrame.Visible = false end
	end
	return visible
end

function Library:SetWindowTitle(Window, Title)
	if Window and Window.TitleLabel and Title then
		Window.TitleLabel.Text = Title
		Window.Title = Title
	end
end

function Library:Unload(Window)
	if self.Unloaded then return end
	self.Unloaded = true
	for _, cb in ipairs(self.UnloadSignals) do self:SafeCallback(cb) end
	for i = #self.Signals, 1, -1 do
		local conn = self.Signals[i]
		if conn and conn.Connected then conn:Disconnect() end
	end
	self.Signals = {}
	for _, eff in ipairs(self._Effects) do pcall(function() eff:Destroy() end) end
	for _, shadow in pairs(self._Shadows) do pcall(function() shadow:Destroy() end) end
	if Window and Window._ScreenGui then Window._ScreenGui:Destroy() end
	if self._ScreenGui then self._ScreenGui:Destroy() end
	self._ScreenGui = nil
	self._UIScales = {}
	self._Shadows = {}
	self.pointers = {}
	self.Options = {}
	self.Toggles = {}
	self.Registry = {}
	self.RegistryMap = {}
	self.OpenedFrame = nil
	self.loaded = false
	if shared then shared.initialized = false end
end

function Library:OnUnload(Callback)
	table.insert(self.UnloadSignals, Callback)
	return Library
end

-- global notification convenience (used by SaveManager/ThemeManager)
function Library:Notify(Text, Time)
	self.toasts:Add(Text, "info", Time)
end

-- expose globally for executors (no-op in vanilla Studio where getgenv is nil)
if typeof(getgenv) == "function" then
	getgenv().Library = Library
end

return Library
