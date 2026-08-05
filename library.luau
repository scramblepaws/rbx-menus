--[[
	Desktop-Style Roblox Luau UI Library
	Single-file, self-contained, professional-grade
]]

-- ============================================================
-- THEME SYSTEM
-- ============================================================

local Theme = {
	Background = Color3.fromRGB(12, 12, 12),
	Window = Color3.fromRGB(18, 18, 18),
	Panel = Color3.fromRGB(22, 22, 22),
	Border = Color3.fromRGB(42, 42, 42),
	BorderDark = Color3.fromRGB(28, 28, 28),

	Text = Color3.fromRGB(235, 235, 235),
	SubText = Color3.fromRGB(145, 145, 145),

	Accent = Color3.fromRGB(166, 164, 255),
	Disabled = Color3.fromRGB(80, 80, 80),

	-- Typography
	Font = Enum.Font.Code,
	HeaderSize = 13,
	NormalSize = 12,
	SmallSize = 11,

	-- Layout constants
	HeaderHeight = 20,
	SidebarWidth = 110,
	BorderThickness = 1,
	GroupboxPadding = 8,
	ControlSpacing = 6,
	ControlHeight = 22,
	ToggleSize = 10,
	SliderTrackHeight = 4,
	SliderThumbSize = 12,
}

-- Theme change listeners
local ThemeListeners = {}

function Theme:RegisterListener(callback: (Theme) -> ())
	table.insert(ThemeListeners, callback)
end

function Theme:NotifyListeners()
	for _, callback in ThemeListeners do
		callback(self)
	end
end

function Theme:SetColor(key: string, color: Color3)
	if self[key] ~= nil then
		self[key] = color
		self:NotifyListeners()
	end
end

-- ============================================================
-- UTILITIES
-- ============================================================

local Util = {}

function Util.Create(className: string, properties: { [string]: any }, children: { Instance }?): Instance
	local instance = Instance.new(className)
	for prop, value in properties do
		instance[prop] = value
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	return instance
end

function Util.Tween(instance: Instance, properties: { [string]: any }, tweenInfo: TweenInfo?): Tween
	tweenInfo = tweenInfo or TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = game:GetService("TweenService"):Create(instance, tweenInfo, properties)
	tween:Play()
	return tween
end

function Util.Round(num: number, decimals: number?): number
	local mult = 10 ^ (decimals or 0)
	return math.floor(num * mult + 0.5) / mult
end

function Util.Clamp(num: number, min: number, max: number): number
	return math.max(min, math.min(max, num))
end

function Util.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.InverseLerp(a: number, b: number, v: number): number
	return (v - a) / (b - a)
end

function Util.Map(v: number, a1: number, b1: number, a2: number, b2: number): number
	return Util.Lerp(a2, b2, Util.InverseLerp(a1, b1, v))
end

function Util.RGBToHex(color: Color3): string
	return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end

function Util.HexToRGB(hex: string): Color3
	hex = hex:gsub("#", "")
	local r = tonumber(hex:sub(1, 2), 16) / 255
	local g = tonumber(hex:sub(3, 4), 16) / 255
	local b = tonumber(hex:sub(5, 6), 16) / 255
	return Color3.new(r, g, b)
end

function Util.HSVToRGB(h: number, s: number, v: number): Color3
	local c = v * s
	local x = c * (1 - math.abs((h * 6) % 2 - 1))
	local m = v - c
	local r, g, b
	if h < 1/6 then r, g, b = c, x, 0
	elseif h < 2/6 then r, g, b = x, c, 0
	elseif h < 3/6 then r, g, b = 0, c, x
	elseif h < 4/6 then r, g, b = 0, x, c
	elseif h < 5/6 then r, g, b = x, 0, c
	else r, g, b = c, 0, x end
	return Color3.new(r + m, g + m, b + m)
end

function Util.RGBToHSV(color: Color3): (number, number, number)
	local r, g, b = color.R, color.G, color.B
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local delta = max - min
	local h, s, v = 0, 0, max
	if delta > 0 then
		s = delta / max
		if max == r then h = ((g - b) / delta) % 6
		elseif max == g then h = (b - r) / delta + 2
		else h = (r - g) / delta + 4 end
		h = h / 6
	end
	return h, s, v
end

function Util.GetTextSize(text: string, font: Enum.Font, size: number, maxWidth: number?): Vector2
	local label = Instance.new("TextLabel")
	label.Font = font
	label.TextSize = size
	label.Text = text
	if maxWidth then
		label.TextWrapped = true
		label.Size = UDim2.fromOffset(maxWidth, 1000)
	end
	local size = label.TextBounds
	label:Destroy()
	return size
end

function Util.Signal(): { Connect: (self: any, callback: (...any) -> ()) -> { Disconnect: (self: any) -> () }, Fire: (self: any, ...any) -> () }
	local connections = {}
	local signal = {}
	function signal:Connect(callback)
		local conn = { Connected = true, Callback = callback }
		table.insert(connections, conn)
		return {
			Disconnect = function()
				conn.Connected = false
				for i, c in connections do
					if c == conn then
						table.remove(connections, i)
						break
					end
				end
			end
		}
	end
	function signal:Fire(...)
		for _, conn in connections do
			if conn.Connected then
				task.spawn(conn.Callback, ...)
			end
		end
	end
	return signal
end

function Util.Computed(initialValue: any): { Get: (self: any) -> any, Set: (self: any, value: any) -> (), OnChanged: (self: any, callback: (any) -> ()) -> () }
	local value = initialValue
	local changed = Util.Signal()
	return {
		Get = function() return value end,
		Set = function(self, newValue)
			if newValue ~= value then
				value = newValue
				changed:Fire(value)
			end
		end,
		OnChanged = function(self, callback)
			return changed:Connect(callback)
		end
	}
end

-- ============================================================
-- RENDERER
-- ============================================================

local Renderer = {}

function Renderer.CreateFrame(properties: { [string]: any }?): Frame
	local props = {
		BackgroundColor3 = Theme.Panel,
		BorderColor3 = Theme.Border,
		BorderSizePixel = Theme.BorderThickness,
		BackgroundTransparency = 0,
	}
	if properties then
		for k, v in properties do props[k] = v end
	end
	return Util.Create("Frame", props)
end

function Renderer.CreateBorder(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return Util.Create("UIStroke", {
		Color = color or Theme.Border,
		Thickness = thickness or Theme.BorderThickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, { parent })
end

function Renderer.CreateLabel(text: string, size: number?, color: Color3?, alignment: Enum.TextXAlignment?): TextLabel
	return Util.Create("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = Theme.Font,
		TextSize = size or Theme.NormalSize,
		TextColor3 = color or Theme.Text,
		TextXAlignment = alignment or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
end

function Renderer.CreateButton(text: string, size: UDim2?): TextButton
	local btn = Util.Create("TextButton", {
		BackgroundColor3 = Theme.Panel,
		BorderColor3 = Theme.Border,
		BorderSizePixel = Theme.BorderThickness,
		Text = text,
		Font = Theme.Font,
		TextSize = Theme.NormalSize,
		TextColor3 = Theme.Text,
		AutoButtonColor = false,
		Size = size or UDim2.fromOffset(80, Theme.ControlHeight),
	})
	return btn
end

function Renderer.CreateInput(placeholder: string, size: UDim2?): TextBox
	return Util.Create("TextBox", {
		BackgroundColor3 = Theme.Background,
		BorderColor3 = Theme.Border,
		BorderSizePixel = Theme.BorderThickness,
		PlaceholderText = placeholder,
		PlaceholderColor3 = Theme.SubText,
		Text = "",
		Font = Theme.Font,
		TextSize = Theme.NormalSize,
		TextColor3 = Theme.Text,
		ClearTextOnFocus = false,
		Size = size or UDim2.fromOffset(200, Theme.ControlHeight),
	})
end

function Renderer.CreateScrollFrame(size: UDim2?): ScrollingFrame
	return Util.Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Border,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = size or UDim2.fromScale(1, 1),
	}, {
		Util.Create("UIListLayout", {
			Padding = UDim.new(0, Theme.ControlSpacing),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	})
end

function Renderer.CreateListLayout(padding: number?): UIListLayout
	return Util.Create("UIListLayout", {
		Padding = UDim.new(0, padding or Theme.ControlSpacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Renderer.CreatePadding(padding: number): UIPadding
	return Util.Create("UIPadding", {
		PaddingTop = UDim.new(0, padding),
		PaddingBottom = UDim.new(0, padding),
		PaddingLeft = UDim.new(0, padding),
		PaddingRight = UDim.new(0, padding),
	})
end

function Renderer.CreateSeparator(): Frame
	return Util.Create("Frame", {
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
	})
end

function Renderer.CreateAccentIndicator(): Frame
	return Util.Create("Frame", {
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 2, 1, 0),
		Visible = false,
	})
end

function Renderer.UpdateTheme()
	-- This will be called by Theme:NotifyListeners
	-- Individual components will register their own update logic
end

-- ============================================================
-- BASE CLASSES / METATABLES
-- ============================================================

local BaseObject = {}
BaseObject.__index = BaseObject

function BaseObject:new()
	local obj = setmetatable({}, self)
	obj._connections = {}
	obj._maid = {}
	return obj
end

function BaseObject:AddConnection(connection: RBXScriptConnection)
	table.insert(self._connections, connection)
	return connection
end

function BaseObject:AddToMaid(item: any)
	table.insert(self._maid, item)
	return item
end

function BaseObject:Destroy()
	for _, conn in self._connections do
		if conn.Connected then conn:Disconnect() end
	end
	for _, item in self._maid do
		if typeof(item) == "Instance" then item:Destroy()
		elseif type(item) == "table" and item.Destroy then item:Destroy()
		elseif type(item) == "function" then item() end
	end
	table.clear(self._connections)
	table.clear(self._maid)
end

-- Signal wrapper for controls
local ControlSignal = {}
ControlSignal.__index = ControlSignal

function ControlSignal:new()
	return setmetatable({ _signal = Util.Signal() }, self)
end

function ControlSignal:Connect(callback: (...any) -> ())
	return self._signal:Connect(callback)
end

function ControlSignal:Fire(...)
	self._signal:Fire(...)
end

-- ============================================================
-- WINDOW
-- ============================================================

local Window = {}
Window.__index = Window
setmetatable(Window, BaseObject)

function Window:new(options: { Title: string, Size: Vector2?, Position: UDim2? })
	local self = BaseObject:new()
	setmetatable(self, Window)

	self.Title = options.Title or "Window"
	self.Size = options.Size or Vector2.new(580, 420)
	self.Position = options.Position or UDim2.fromOffset(100, 100)

	self._tabs = {}
	self._activeTab = nil
	self._sidebarCategories = {}
	self._activeCategory = nil
	self._dragging = false
	self._dragStart = nil
	self._startPos = nil

	self:_build()
	self:_setupDragging()
	self:_registerThemeListener()

	return self
end

function Window:_build()
	-- ScreenGui
	self.ScreenGui = Util.Create("ScreenGui", {
		Name = "DesktopUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
	})

	-- Main window frame
	self.MainFrame = Util.Create("Frame", {
		BackgroundColor3 = Theme.Window,
		BorderColor3 = Theme.Border,
		BorderSizePixel = Theme.BorderThickness,
		Size = UDim2.fromOffset(self.Size.X, self.Size.Y),
		Position = self.Position,
		ClipsDescendants = true,
	}, { self.ScreenGui })

	-- Header
	self.Header = Util.Create("Frame", {
		Name = "Header",
		BackgroundColor3 = Theme.Panel,
		BorderColor3 = Theme.BorderDark,
		BorderSizePixel = Theme.BorderThickness,
		Size = UDim2.new(1, 0, 0, Theme.HeaderHeight),
		ZIndex = 2,
	}, { self.MainFrame })

	self.HeaderLabel = Renderer.CreateLabel(self.Title, Theme.HeaderSize, Theme.Text)
	self.HeaderLabel.Size = UDim2.new(1, -20, 1, 0)
	self.HeaderLabel.Position = UDim2.fromOffset(10, 0)
	self.HeaderLabel.Parent = self.Header

	-- Close button
	self.CloseBtn = Util.Create("TextButton", {
		BackgroundTransparency = 1,
		Text = "×",
		Font = Theme.Font,
		TextSize = Theme.HeaderSize + 2,
		TextColor3 = Theme.SubText,
		Size = UDim2.fromOffset(Theme.HeaderHeight, Theme.HeaderHeight),
		Position = UDim2.new(1, -Theme.HeaderHeight, 0, 0),
		ZIndex = 3,
	}, { self.Header })

	self:AddConnection(self.CloseBtn.MouseEnter:Connect(function()
		Util.Tween(self.CloseBtn, { TextColor3 = Theme.Accent })
	end))
	self:AddConnection(self.CloseBtn.MouseLeave:Connect(function()
		Util.Tween(self.CloseBtn, { TextColor3 = Theme.SubText })
	end))
	self:AddConnection(self.CloseBtn.MouseButton1Click:Connect(function()
		self:Destroy()
	end))

	-- Content area (below header)
	self.ContentArea = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -Theme.HeaderHeight),
		Position = UDim2.fromOffset(0, Theme.HeaderHeight),
	}, { self.MainFrame })

	-- Sidebar
	self.Sidebar = Util.Create("Frame", {
		Name = "Sidebar",
		BackgroundColor3 = Theme.Panel,
		BorderColor3 = Theme.BorderDark,
		BorderSizePixel = Theme.BorderThickness,
		Size = UDim2.new(0, Theme.SidebarWidth, 1, 0),
	}, { self.ContentArea })

	self.SidebarList = Util.Create("UIListLayout", {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, { self.Sidebar })

	-- Tab container (right of sidebar)
	self.TabContainer = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -Theme.SidebarWidth, 1, 0),
		Position = UDim2.fromOffset(Theme.SidebarWidth, 0),
		ClipsDescendants = true,
	}, { self.ContentArea })

	-- Tab buttons bar (top of tab container)
	self.TabBar = Util.Create("Frame", {
		BackgroundColor3 = Theme.Panel,
		BorderColor3 = Theme.BorderDark,
		BorderSizePixel = Theme.BorderThickness,
		Size = UDim2.new(1, 0, 0, 24),
	}, { self.TabContainer })

	self.TabList = Util.Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, { self.TabBar })

	-- Tab content area
	self.TabContent = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -24),
		Position = UDim2.fromOffset(0, 24),
	}, { self.TabContainer })
end

function Window:_setupDragging()
	self:AddConnection(self.Header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._dragging = true
			self._dragStart = input.Position
			self._startPos = self.MainFrame.Position
		end
	end))

	self:AddConnection(game:GetService("UserInputService").InputChanged:Connect(function(input)
		if self._dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - self._dragStart
			self.MainFrame.Position = UDim2.fromOffset(
				self._startPos.X.Offset + delta.X,
				self._startPos.Y.Offset + delta.Y
			)
		end
	end))

	self:AddConnection(game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._dragging = false
		end
	end))
end

function Window:_registerThemeListener()
	Theme:RegisterListener(function()
		self.MainFrame.BackgroundColor3 = Theme.Window
		self.MainFrame.BorderColor3 = Theme.Border
		self.Header.BackgroundColor3 = Theme.Panel
		self.Header.BorderColor3 = Theme.BorderDark
		self.HeaderLabel.TextColor3 = Theme.Text
		self.CloseBtn.TextColor3 = Theme.SubText
		self.Sidebar.BackgroundColor3 = Theme.Panel
		self.Sidebar.BorderColor3 = Theme.BorderDark
		self.TabBar.BackgroundColor3 = Theme.Panel
		self.TabBar.BorderColor3 = Theme.BorderDark
		for _, tab in self._tabs do
			tab:UpdateTheme()
		end
	end)
end

function Window:CreateTab(name: string): any
	local tab = Tab:new(self, name)
	table.insert(self._tabs, tab)

	if not self._activeTab then
		tab:Select()
	end

	return tab
end

function Window:CreateSidebarCategory(name: string): any
	local category = SidebarCategory:new(self, name)
	table.insert(self._sidebarCategories, category)

	if not self._activeCategory then
		category:Select()
	end

	return category
end

function Window:GetActiveTab()
	return self._activeTab
end

function Window:SetActiveTab(tab)
	if self._activeTab then
		self._activeTab:Deselect()
	end
	self._activeTab = tab
	if tab then
		tab:Select()
	end
end

-- ============================================================
-- SIDEBAR CATEGORY
-- ============================================================

local SidebarCategory = {}
SidebarCategory.__index = SidebarCategory
setmetatable(SidebarCategory, BaseObject)

function SidebarCategory:new(window: any, name: string)
	local self = BaseObject:new()
	setmetatable(self, SidebarCategory)

	self.Window = window
	self.Name = name
	self._selected = false

	self:_build()
	return self
end

function SidebarCategory:_build()
	self.Button = Util.Create("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = #self.Window._sidebarCategories,
	}, { self.Window.Sidebar })

	self.Indicator = Renderer.CreateAccentIndicator()
	self.Indicator.Position = UDim2.fromOffset(0, 0)
	self.Indicator.Parent = self.Button

	self.Label = Renderer.CreateLabel(self.Name, Theme.NormalSize, Theme.SubText)
	self.Label.Size = UDim2.new(1, -12, 1, 0)
	self.Label.Position = UDim2.fromOffset(12, 0)
	self.Label.Parent = self.Button

	self:AddConnection(self.Button.MouseEnter:Connect(function()
		if not self._selected then
			Util.Tween(self.Label, { TextColor3 = Theme.Text })
		end
	end))

	self:AddConnection(self.Button.MouseLeave:Connect(function()
		if not self._selected then
			Util.Tween(self.Label, { TextColor3 = Theme.SubText })
		end
	end))

	self:AddConnection(self.Button.MouseButton1Click:Connect(function()
		self:Select()
	end))
end

function SidebarCategory:Select()
	if self.Window._activeCategory then
		self.Window._activeCategory:Deselect()
	end
	self._selected = true
	self.Indicator.Visible = true
	self.Label.TextColor3 = Theme.Text
	self.Label.Font = Enum.Font.Code -- Already default
	self.Window._activeCategory = self
end

function SidebarCategory:Deselect()
	self._selected = false
	self.Indicator.Visible = false
	self.Label.TextColor3 = Theme.SubText
end

function SidebarCategory:UpdateTheme()
	self.Label.TextColor3 = self._selected and Theme.Text or Theme.SubText
	self.Indicator.BackgroundColor3 = Theme.Accent
end

-- ============================================================
-- TAB
-- ============================================================

local Tab = {}
Tab.__index = Tab
setmetatable(Tab, BaseObject)

function Tab:new(window: any, name: string)
	local self = BaseObject:new()
	setmetatable(self, Tab)

	self.Window = window
	self.Name = name
	self._selected = false
	self._groupboxes = { Left = {}, Right = {} }
	self._columnHeights = { Left = 0, Right = 0 }

	self:_build()
	return self
end

function Tab:_build()
	-- Tab button
	self.Button = Util.Create("TextButton", {
		BackgroundTransparency = 1,
		Text = self.Name,
		Font = Theme.Font,
		TextSize = Theme.NormalSize,
		TextColor3 = Theme.SubText,
		Size = UDim2.fromOffset(80, 24),
		LayoutOrder = #self.Window._tabs,
	}, { self.Window.TabBar })

	self.Underline = Util.Create("Frame", {
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromOffset(0, 23),
		Visible = false,
	}, { self.Button })

	-- Content frame (two columns)
	self.Content = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, { self.Window.TabContent })

	self.LeftColumn = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.5, -Theme.GroupboxPadding, 1, 0),
		Position = UDim2.fromOffset(Theme.GroupboxPadding, 0),
	}, { self.Content })

	self.RightColumn = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.5, -Theme.GroupboxPadding, 1, 0),
		Position = UDim2.new(0.5, Theme.GroupboxPadding / 2, 0, 0),
	}, { self.Content })

	self.LeftList = Util.Create("UIListLayout", {
		Padding = UDim.new(0, Theme.GroupboxPadding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, { self.LeftColumn })

	self.RightList = Util.Create("UIListLayout", {
		Padding = UDim.new(0, Theme.GroupboxPadding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
	}, { self.RightColumn })

	self:AddConnection(self.Button.MouseEnter:Connect(function()
		if not self._selected then
			Util.Tween(self.Button, { TextColor3 = Theme.Text })
		end
	end))

	self:AddConnection(self.Button.MouseLeave:Connect(function()
		if not self._selected then
			Util.Tween(self.Button, { TextColor3 = Theme.SubText })
		end
	end))

	self:AddConnection(self.Button.MouseButton1Click:Connect(function()
		self:Select()
	end))
end

function Tab:Select()
	if self.Window._activeTab then
		self.Window._activeTab:Deselect()
	end
	self._selected = true
	self.Button.TextColor3 = Theme.Accent
	self.Underline.Visible = true
	self.Content.Visible = true
	self.Window._activeTab = self
end

function Tab:Deselect()
	self._selected = false
	self.Button.TextColor3 = Theme.SubText
	self.Underline.Visible = false
	self.Content.Visible = false
end

function Tab:UpdateTheme()
	self.Button.TextColor3 = self._selected and Theme.Accent or Theme.SubText
	self.Underline.BackgroundColor3 = Theme.Accent
	for side, groupboxes in self._groupboxes do
		for _, gb in groupboxes do
			gb:UpdateTheme()
		end
	end
end

function Tab:CreateGroupbox(title: string, side: string?): any
	side = side or "Left"
	local groupbox = Groupbox:new(self, title, side)
	table.insert(self._groupboxes[side], groupbox)
	return groupbox
end

function Tab:GetColumnHeight(side: string): number
	return self._columnHeights[side] or 0
end

function Tab:AddColumnHeight(side: string, height: number)
	self._columnHeights[side] = (self._columnHeights[side] or 0) + height
end

-- ============================================================
-- GROUPBOX & LAYOUT ENGINE
-- ============================================================

local Groupbox = {}
Groupbox.__index = Groupbox
setmetatable(Groupbox, BaseObject)

function Groupbox:new(tab: any, title: string, side: string)
	local self = BaseObject:new()
	setmetatable(self, Groupbox)

	self.Tab = tab
	self.Title = title
	self.Side = side
	self._controls = {}
	self._cursorY = 0
	self._contentHeight = 0

	self:_build()
	return self
end

function Groupbox:_build()
	local column = self.Side == "Left" and self.Tab.LeftColumn or self.Tab.RightColumn

	self.Frame = Renderer.CreateFrame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #self.Tab._groupboxes[self.Side],
	}, { column })

	self.Border = Renderer.CreateBorder(self.Frame)

	self.Padding = Renderer.CreatePadding(Theme.GroupboxPadding)
	self.Padding.Parent = self.Frame

	self.Layout = Util.Create("UIListLayout", {
		Padding = UDim.new(0, Theme.ControlSpacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, { self.Frame })

	-- Title
	self.TitleLabel = Renderer.CreateLabel(self.Title, Theme.NormalSize, Theme.Accent)
	self.TitleLabel.Size = UDim2.new(1, 0, 0, Theme.NormalSize + 2)
	self.TitleLabel.LayoutOrder = 0
	self.TitleLabel.Parent = self.Frame

	-- Separator under title
	self.TitleSeparator = Renderer.CreateSeparator()
	self.TitleSeparator.LayoutOrder = 1
	self.TitleSeparator.Parent = self.Frame

	-- Content starts at layout order 2
	self._cursorY = Theme.NormalSize + 2 + Theme.ControlSpacing
end

function Groupbox:GetNextPosition(): number
	local pos = self._cursorY
	return pos
end

function Groupbox:AdvanceCursor(height: number)
	self._cursorY += height + Theme.ControlSpacing
end

function Groupbox:AddControl(control: any)
	table.insert(self._controls, control)
	control.Groupbox = self
	control.LayoutOrder = #self._controls + 1
	control.Frame.Parent = self.Frame
	self:AdvanceCursor(control:GetHeight())
	return control
end

function Groupbox:GetContentHeight(): number
	return self._cursorY
end

function Groupbox:UpdateTheme()
	self.Frame.BackgroundColor3 = Theme.Panel
	self.Border.Color = Theme.Border
	self.TitleLabel.TextColor3 = Theme.Accent
	for _, control in self._controls do
		control:UpdateTheme()
	end
end

-- Label
function Groupbox:Label(text: string)
	return self:AddControl(Label:new(text))
end

-- Separator
function Groupbox:Separator(text: string)
	return self:AddControl(Separator:new(text))
end

-- Button
function Groupbox:Button(text: string, callback: () -> ())
	return self:AddControl(Button:new(text, callback))
end

-- Toggle
function Groupbox:Toggle(text: string, default: boolean?, callback: (boolean) -> ())
	return self:AddControl(Toggle:new(text, default, callback))
end

-- Slider
function Groupbox:Slider(text: string, options: { Min: number, Max: number, Default: number, Decimals: number?, Suffix: string? }, callback: (number) -> ())
	return self:AddControl(Slider:new(text, options, callback))
end

-- Textbox
function Groupbox:Textbox(placeholder: string, default: string?, callback: (string) -> ())
	return self:AddControl(Textbox:new(placeholder, default, callback))
end

-- Dropdown
function Groupbox:Dropdown(text: string, options: { string }, default: string?, callback: (string) -> (), multi: boolean?)
	return self:AddControl(Dropdown:new(text, options, default, callback, multi))
end

-- Keybind
function Groupbox:Keybind(text: string, default: Enum.KeyCode?, callback: (Enum.KeyCode?) -> (), mode: string?)
	return self:AddControl(Keybind:new(text, default, callback, mode))
end

-- ColorPicker
function Groupbox:ColorPicker(text: string, default: Color3?, callback: (Color3) -> ())
	return self:AddControl(ColorPicker:new(text, default, callback))
end

-- ============================================================
-- BASE CONTROL
-- ============================================================

local Control = {}
Control.__index = Control
setmetatable(Control, BaseObject)

function Control:new(height: number)
	local self = BaseObject:new()
	setmetatable(self, Control)

	self.Height = height
	self.LayoutOrder = 0
	self.Groupbox = nil
	self.Frame = nil
	self._changed = ControlSignal:new()

	return self
end

function Control:GetHeight(): number
	return self.Height
end

function Control:OnChanged(callback: (any) -> ())
	return self._changed:Connect(callback)
end

function Control:FireChanged(value: any)
	self._changed:Fire(value)
end

function Control:UpdateTheme()
	-- Override in subclasses
end

function Control:Destroy()
	for _, conn in self._connections do
		if conn.Connected then conn:Disconnect() end
	end
	if self.Frame then self.Frame:Destroy() end
end

-- ============================================================
-- CONTROLS: LABEL
-- ============================================================

local Label = {}
Label.__index = Label
setmetatable(Label, Control)

function Label:new(text: string)
	local height = Theme.NormalSize
	local self = Control:new(height)
	setmetatable(self, Label)

	self.Frame = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
	})

	self.TextLabel = Renderer.CreateLabel(text, Theme.NormalSize, Theme.Text)
	self.TextLabel.Size = UDim2.fromScale(1, 1)
	self.TextLabel.Parent = self.Frame

	return self
end

function Label:SetText(text: string)
	self.TextLabel.Text = text
end

function Label:UpdateTheme()
	self.TextLabel.TextColor3 = Theme.Text
end

-- ============================================================
-- CONTROLS: SEPARATOR
-- ============================================================

local Separator = {}
Separator.__index = Separator
setmetatable(Separator, Control)

function Separator:new(text: string)
	local height = Theme.NormalSize + 4 + 1 -- text + gap + line
	local self = Control:new(height)
	setmetatable(self, Separator)

	self.Frame = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
	})

	self.TextLabel = Renderer.CreateLabel(text, Theme.NormalSize, Theme.SubText)
	self.TextLabel.Size = UDim2.new(1, 0, 0, Theme.NormalSize)
	self.TextLabel.Parent = self.Frame

	self.Line = Renderer.CreateSeparator()
	self.Line.Position = UDim2.fromOffset(0, Theme.NormalSize + 4)
	self.Line.Parent = self.Frame

	return self
end

function Separator:UpdateTheme()
	self.TextLabel.TextColor3 = Theme.SubText
	self.Line.BackgroundColor3 = Theme.Border
end

-- ============================================================
-- CONTROLS: BUTTON
-- ============================================================

local Button = {}
Button.__index = Button
setmetatable(Button, Control)

function Button:new(text: string, callback: () -> ())
	local height = Theme.ControlHeight
	local self = Control:new(height)
	setmetatable(self, Button)

	self.Callback = callback
	self._hovered = false
	self._pressed = false

	self.Frame = Renderer.CreateButton(text, UDim2.new(1, 0, 0, height))

	self:AddConnection(self.Frame.MouseEnter:Connect(function()
		self._hovered = true
		self:_updateVisuals()
	end))

	self:AddConnection(self.Frame.MouseLeave:Connect(function()
		self._hovered = false
		self._pressed = false
		self:_updateVisuals()
	end))

	self:AddConnection(self.Frame.MouseButton1Down:Connect(function()
		self._pressed = true
		self:_updateVisuals()
	end))

	self:AddConnection(self.Frame.MouseButton1Up:Connect(function()
		self._pressed = false
		self:_updateVisuals()
	end))

	self:AddConnection(self.Frame.MouseButton1Click:Connect(function()
		if self.Callback then
			task.spawn(self.Callback)
		end
		self:FireChanged(true)
	end))

	return self
end

function Button:_updateVisuals()
	if self._pressed then
		Util.Tween(self.Frame, { BackgroundColor3 = Theme.Background })
		self.Frame.BorderColor3 = Theme.Accent
	elseif self._hovered then
		Util.Tween(self.Frame, { BackgroundColor3 = Theme.Panel })
		self.Frame.BorderColor3 = Theme.Accent
	else
		Util.Tween(self.Frame, { BackgroundColor3 = Theme.Panel })
		self.Frame.BorderColor3 = Theme.Border
	end
end

function Button:UpdateTheme()
	self.Frame.TextColor3 = Theme.Text
	self:_updateVisuals()
end

-- ============================================================
-- CONTROLS: TOGGLE
-- ============================================================

local Toggle = {}
Toggle.__index = Toggle
setmetatable(Toggle, Control)

function Toggle:new(text: string, default: boolean?, callback: (boolean) -> ())
	local height = Theme.ControlHeight
	local self = Control:new(height)
	setmetatable(self, Toggle)

	self.Value = default or false
	self.Callback = callback
	self._hovered = false

	self.Frame = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
	})

	-- Checkbox square
	self.Box = Util.Create("Frame", {
		BackgroundColor3 = Theme.Background,
		BorderColor3 = Theme.Border,
		BorderSizePixel = Theme.BorderThickness,
		Size = UDim2.fromOffset(Theme.ToggleSize, Theme.ToggleSize),
		Position = UDim2.fromOffset(0, (height - Theme.ToggleSize) / 2),
	}, { self.Frame })

	self.Fill = Util.Create("Frame", {
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = self.Value,
	}, { self.Box })

	-- Label
	self.Label = Renderer.CreateLabel(text, Theme.NormalSize, Theme.Text)
	self.Label.Size = UDim2.new(1, -Theme.ToggleSize - 8, 1, 0)
	self.Label.Position = UDim2.fromOffset(Theme.ToggleSize + 8, 0)
	self.Label.Parent = self.Frame

	-- Hit area
	self.HitArea = Util.Create("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
	}, { self.Frame })

	self:AddConnection(self.HitArea.MouseEnter:Connect(function()
		self._hovered = true
		self:_updateVisuals()
	end))

	self:AddConnection(self.HitArea.MouseLeave:Connect(function()
		self._hovered = false
		self:_updateVisuals()
	end))

	self:AddConnection(self.HitArea.MouseButton1Click:Connect(function()
		self:Set(not self.Value)
	end))

	return self
end

function Toggle:_updateVisuals()
	self.Fill.Visible = self.Value
	if self.Value then
		self.Box.BackgroundColor3 = Theme.Accent
		self.Box.BorderColor3 = Theme.Accent
	elseif self._hovered then
		self.Box.BackgroundColor3 = Theme.Background
		self.Box.BorderColor3 = Theme.Accent
	else
		self.Box.BackgroundColor3 = Theme.Background
		self.Box.BorderColor3 = Theme.Border
	end
end

function Toggle:Set(value: boolean)
	self.Value = value
	self:_updateVisuals()
	if self.Callback then
		task.spawn(self.Callback, value)
	end
	self:FireChanged(value)
end

function Toggle:Get(): boolean
	return self.Value
end

function Toggle:UpdateTheme()
	self.Label.TextColor3 = Theme.Text
	self:_updateVisuals()
end

-- ============================================================
-- CONTROLS: SLIDER
-- ============================================================

local Slider = {}
Slider.__index = Slider
setmetatable(Slider, Control)

function Slider:new(text: string, options: { Min: number, Max: number, Default: number, Decimals: number?, Suffix: string? }, callback: (number) -> ())
	local height = Theme.NormalSize + 4 + Theme.SliderTrackHeight + 4
	local self = Control:new(height)
	setmetatable(self, Slider)

	self.Min = options.Min or 0
	self.Max = options.Max or 100
	self.Decimals = options.Decimals or 0
	self.Suffix = options.Suffix or ""
	self.Callback = callback
	self.Value = options.Default or self.Min
	self._dragging = false
	self._hovered = false

	self.Frame = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
	})

	-- Label + value
	self.Label = Renderer.CreateLabel("", Theme.NormalSize, Theme.Text)
	self.Label.Size = UDim2.new(1, 0, 0, Theme.NormalSize)
	self.Label.Parent = self.Frame

	-- Track
	self.Track = Util.Create("Frame", {
		BackgroundColor3 = Theme.Background,
		BorderColor3 = Theme.Border,
		BorderSizePixel = Theme.BorderThickness,
		Size = UDim2.new(1, 0, 0, Theme.SliderTrackHeight),
		Position = UDim2.fromOffset(0, Theme.NormalSize + 4),
	}, { self.Frame })

	self.Fill = Util.Create("Frame", {
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, { self.Track })

	self.Thumb = Util.Create("Frame", {
		BackgroundColor3 = Theme.Text,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(Theme.SliderThumbSize, Theme.SliderThumbSize),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		ZIndex = 2,
	}, { self.Track })

	-- Hit area
	self.HitArea = Util.Create("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
	}, { self.Track })

	self:AddConnection(self.HitArea.MouseEnter:Connect(function()
		self._hovered = true
		self:_updateVisuals()
	end))

	self:AddConnection(self.HitArea.MouseLeave:Connect(function()
		self._hovered = false
		self._dragging = false
		self:_updateVisuals()
	end))

	self:AddConnection(self.HitArea.MouseButton1Down:Connect(function()
		self._dragging = true
		self:_updateFromMouse()
	end))

	self:AddConnection(game:GetService("UserInputService").InputChanged:Connect(function(input)
		if self._dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_updateFromMouse()
		end
	end))

	self:AddConnection(game:GetService("UserInputService").InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self._dragging = false
			self:_updateVisuals()
		end
	end))

	self:_updateLabel()
	self:_updateFill()

	return self
end

function Slider:_updateFromMouse()
	local mouse = game:GetService("Players").LocalPlayer:GetMouse()
	local trackAbsPos = self.Track.AbsolutePosition
	local trackAbsSize = self.Track.AbsoluteSize
	local relativeX = Util.Clamp(mouse.X - trackAbsPos.X, 0, trackAbsSize.X)
	local alpha = relativeX / trackAbsSize.X
	local value = Util.Lerp(self.Min, self.Max, alpha)
	self:Set(Util.Round(value, self.Decimals))
end

function Slider:_updateLabel()
	local displayValue = self.Suffix ~= "" and (tostring(self.Value) .. " " .. self.Suffix) or tostring(self.Value)
	self.Label.Text = string.format("%s  [%s]", self.Text or "Slider", displayValue)
end

function Slider:_updateFill()
	local alpha = (self.Value - self.Min) / (self.Max - self.Min)
	self.Fill.Size = UDim2.fromScale(alpha, 1)
	self.Thumb.Position = UDim2.fromScale(alpha, 0.5)
end

function Slider:_updateVisuals()
	if self._hovered or self._dragging then
		self.Track.BorderColor3 = Theme.Accent
	else
		self.Track.BorderColor3 = Theme.Border
	end
end

function Slider:Set(value: number)
	self.Value = Util.Clamp(value, self.Min, self.Max)
	self:_updateLabel()
	self:_updateFill()
	if self.Callback then
		task.spawn(self.Callback, self.Value)
	end
	self:FireChanged(self.Value)
end

function Slider:Get(): number
	return self.Value
end

function Slider:SetText(text: string)
	self.Text = text
	self:_updateLabel()
end

function Slider:UpdateTheme()
	self.Label.TextColor3 = Theme.Text
	self.Track.BackgroundColor3 = Theme.Background
	self.Track.BorderColor3 = self._hovered and Theme.Accent or Theme.Border
	self.Fill.BackgroundColor3 = Theme.Accent
	self.Thumb.BackgroundColor3 = Theme.Text
	self:_updateVisuals()
end

-- ============================================================
-- CONTROLS: TEXTBOX
-- ============================================================

local Textbox = {}
Textbox.__index = Textbox
setmetatable(Textbox, Control)

function Textbox:new(placeholder: string, default: string?, callback: (string) -> ())
	local height = Theme.ControlHeight
	local self = Control:new(height)
	setmetatable(self, Textbox)

	self.Callback = callback
	self:_build()
	self:SetText(default or "")
	return self
end

function Textbox:_build()
	self.Frame = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, self.Height),
	})

	self.Input = Renderer.CreateInput("", UDim2.new(1, 0, 1, 0))
	self.Input.Position = UDim2.fromOffset(0, 0)
	self.Input.Parent = self.Frame

	self:AddConnection(self.Input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			if self.Callback then
				task.spawn(self.Callback, self.Input.Text)
			end
			self:FireChanged(self.Input.Text)
		end
	end))
end

function Textbox:SetText(text: string)
	self.Input.Text = text
end

function Textbox:GetText(): string
	return self.Input.Text
end

function Textbox:UpdateTheme()
	self.Input.PlaceholderColor3 = Theme.SubText
	self.Input.TextColor3 = Theme.Text
	self.Input.BackgroundColor3 = Theme.Background
	self.Input.BorderColor3 = Theme.Border
end

-- ============================================================
-- CONTROLS: DROPDOWN
-- ============================================================

local Dropdown = {}
Dropdown.__index = Dropdown
setmetatable(Dropdown, Control)

function Dropdown:new(text: string, options: { string }, default: string?, callback: (string) -> (), multi: boolean?)
	local height = Theme.ControlHeight
	local self = Control:new(height)
	setmetatable(self, Dropdown)

	self.Text = text
	self.Options = options or {}
	self.MultiSelect = multi or false
	self.Callback = callback
	self.Value = default or ""

	self:_build()
	return self
end

function Dropdown:_build()
	self.Frame = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, self.Height),
	})

	self.Button = Util.Create("TextButton", {
		BackgroundColor3 = Theme.Background,
		BorderColor3 = Theme.Border,
		BorderSizePixel = Theme.BorderThickness,
		Text = "",
		Font = Theme.Font,
		TextSize = Theme.NormalSize,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 1, 0),
	}, { self.Frame })

	self.ValueLabel = Util.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = Theme.NormalSize,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -30, 1, 0),
		Position = UDim2.fromOffset(8, 0),
	}, { self.Button })

	self.Arrow = Util.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		Text = "▼",
		TextSize = Theme.SmallSize,
		TextColor3 = Theme.SubText,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.fromOffset(30, 0),
		Position = UDim2.new(1, -30, 0, 0),
		AnchorPoint = Vector2.new(0, 0.5),
	}, { self.Button })

	self:AddConnection(self.Button.MouseButton1Click:Connect(function()
		self:_toggleList()
	end))

	self:AddConnection(self.Button.MouseEnter:Connect(function()
		self:_updateVisuals()
	end))

	self:AddConnection(self.Button.MouseLeave:Connect(function()
		self:_updateVisuals()
	end))

	if #self.Options > 0 then
		self:_updateValueLabel()
	end
end

function Dropdown:_toggleList()
	if self.ListOpen then
		self:CloseList()
	else
		self:OpenList()
	end
end

function Dropdown:OpenList()
	local screenGui = Util.Create("ScreenGui", {
		Name = "DropdownList",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Global,
	}, { game:GetService("CoreGui") })

	self.ListGui = screenGui

	self.List = Util.Create("ScrollingFrame", {
		BackgroundColor3 = Theme.Window,
		BorderColor3 = Theme.Border,
		BorderSizePixel = Theme.BorderThickness,
		Size = UDim2.fromOffset(200, 200),
		Position = UDim2.fromOffset(self.Button.AbsolutePosition.X, self.Button.AbsolutePosition.Y + self.Button.AbsoluteSize.Y),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Border,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { screenGui })

	local layout = Util.Create("UIListLayout", {
		Padding = UDim.new(0, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, { self.List })

	self.SearchBox = Util.Create("TextBox", {
		BackgroundColor3 = Theme.Background,
		BorderColor3 = Theme.Border,
		BorderSizePixel = Theme.BorderThickness,
		PlaceholderText = "Search...",
		PlaceholderColor3 = Theme.SubText,
		Font = Theme.Font,
		TextSize = Theme.NormalSize,
		TextColor3 = Theme.Text,
		ClearTextOnFocus = false,
		Size = UDim2.new(1, 0, 0, 20),
	}, { self.List })

	local searchPadding = Util.Create("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	}, { self.SearchBox })

	self:AddConnection(self.SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
			self:_filterList()
		end))

	local searchBoxCreated = false
	local function createSearchBox()
		if not searchBoxCreated then
			searchBoxCreated = true
			local searchBox = self.SearchBox
			searchBox.Parent = self.List
			self:_filterList()
		end
	end

	self:AddConnection(self.Button:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			createSearchBox()
			self.List.Position = UDim2.fromOffset(
				self.Button.AbsolutePosition.X,
				self.Button.AbsolutePosition.Y + self.Button.AbsoluteSize.Y
			)
		end))

	for _, option in self.Options do
			local optionBtn = Util.Create("TextButton", {
				BackgroundTransparency = 1,
				Text = option,
				Font = Theme.Font,
				TextSize = Theme.NormalSize,
				TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.new(1, 0, 0, 24),
			}, { self.List })

			local optionLabel = Util.Create("TextLabel", {
				BackgroundTransparency = 1,
				Font = Theme.Font,
				TextSize = Theme.NormalSize,
				TextColor3 = Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.fromOffset(180, 0),
				Position = UDim2.fromOffset(8, 0),
			}, { optionBtn })

			optionLabel.Text = option

			local selectedIndicator = Util.Create("Frame", {
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(0, 0),
				Visible = (self.MultiSelect and table.find(self.Value, option)) or (not self.MultiSelect and self.Value == option),
			}, { optionBtn })

			local indicatorPadding = Util.Create("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, 2),
			}, { selectedIndicator })

			local function updateSelectionColor()
				local isSelected = (self.MultiSelect and table.find(self.Value, option)) or (not self.MultiSelect and self.Value == option)
				selectedIndicator.Size = isSelected and UDim2.new(3, 0, 0, 1) or UDim2.new(0, 0, 0, 1)
				selectedIndicator.Visible = isSelected
			end

			optionBtn.MouseButton1Click:Connect(function()
				if self.MultiSelect then
					local index = table.find(self.Value, option)
					if index then
						table.remove(self.Value, index)
					else
						if #self.Value == 0 or not table.find(self.Value, option) then
							table.insert(self.Value, option)
						end
					end
				else
					self.Value = option
				end
				self:_updateValueLabel()
				updateSelectionColor()
				if self.Callback then
					task.spawn(self.Callback, self.Value)
				end
				self:FireChanged(self.Value)
			end)

			optionBtn.MouseEnter:Connect(function()
				optionLabel.TextColor3 = Theme.Accent
			end)

			optionBtn.MouseLeave:Connect(function()
				optionLabel.TextColor3 = Theme.Text
			end)
		end

		self.ListOpen = true
	self:_updateVisuals()
	self:AddConnection(self.List:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			for _, child in self.List:GetChildren() do
				if child:IsA("TextButton") then
					child.Size = UDim2.new(1, 0, 0, 24)
				end
			end
		end))

	self:AddConnection(self.List:GetPropertyChangedSignal("CanvasSize"):Connect(function()
			local maxHeight = math.min(200, self.List.CanvasSize.Y.Offset)
			if maxHeight == 0 then maxHeight = 200 end
			self.List.Size = UDim2.fromOffset(200, maxHeight)
		end))

	self:AddConnection(game:GetService("UserInputService").InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local hit = false
			for _, child in self.List:GetChildren() do
				if child:IsA("TextButton") then
					local absPos = child.AbsolutePosition
					local absSize = child.AbsoluteSize
					if input.Position.X >= absPos.X and input.Position.X <= absPos.X + absSize.X and
					   input.Position.Y >= absPos.Y and input.Position.Y <= absPos.Y + absSize.Y then
						hit = true
						break
					end
				end
			end
			if not hit and self.ListOpen then
				self:CloseList()
			end
		end
	end))
end

function Dropdown:CloseList()
	if self.ListGui then
		self.ListGui:Destroy()
		self.ListGui = nil
		self.ListOpen = false
		self:_updateVisuals()
	end
end

function Dropdown:_filterList()
	if not self.ListOpen or not self.SearchBox then return end

	for _, child in self.List:GetChildren() do
			if child.Name == "SearchBox" then continue end
			local visible = string.lower(child.Label.Text):find(string.lower(self.SearchBox.Text), 1, true)
			child.Visible = visible
			child.Label.Visible = visible
			child.SelectedIndicator.Visible = (self.MultiSelect and table.find(self.Value, child.Label.Text)) or (not self.MultiSelect and self.Value == child.Label.Text)
			if child.SelectedIndicator.Visible then
				child.Label.TextColor3 = Theme.Accent
			else
				child.Label.TextColor3 = visible and Theme.Text or Theme.SubText
			end
		end
end

function Dropdown:_updateValueLabel()
	local displayValue
	if self.MultiSelect then
		if #self.Value == 0 then
			displayValue = ""
		else
			displayValue = table.concat(self.Value, ", ")
		end
	else
		displayValue = self.Value
	end
	self.ValueLabel.Text = displayValue
end

function Dropdown:_updateVisuals()
	if self._hovered or self.ListOpen then
		self.Button.BorderColor3 = Theme.Accent
		self.Arrow.TextColor3 = Theme.Accent
	else
		self.Button.BorderColor3 = Theme.Border
		self.Arrow.TextColor3 = Theme.SubText
	end
end

function Dropdown:UpdateTheme()
	self.Button.BackgroundColor3 = Theme.Background
	self.Button.BorderColor3 = self._hovered or self.ListOpen and Theme.Accent or Theme.Border
	self.Arrow.TextColor3 = Theme.SubText
	self:_updateVisuals()
	for _, child in self.List:GetChildren() do
			if child:IsA("TextButton") then
				child.Label.TextColor3 = Theme.Text
			end
		end
end

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================

local Notifications = {}
Notifications.__index = Notifications
Notifications._queue = {}
Notifications._container = nil

function Notifications:_ensureContainer()
	if self._container then return end
	local screenGui = Util.Create("ScreenGui", {
		Name = "Notifications",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
	})
	self._container = Util.Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 240, 1, 0),
		Position = UDim2.new(1, -250, 0, 10),
	}, { screenGui })
end

function Notifications:Show(text: string, duration: number?)
	duration = duration or 3
	self:_ensureContainer()

	local notif = Util.Create("Frame", {
		BackgroundColor3 = Theme.Window,
		BorderColor3 = Theme.Border,
		BorderSizePixel = Theme.BorderThickness,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = #self._queue,
	}, { self._container })

	Renderer.CreateBorder(notif)

	local label = Renderer.CreateLabel(text, Theme.NormalSize, Theme.Text)
	label.Size = UDim2.new(1, -16, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Position = UDim2.fromOffset(8, 6)
	label.Parent = notif

	table.insert(self._queue, notif)
	notif.Size = UDim2.fromOffset(240, 0)
	notif.AutomaticSize = Enum.AutomaticSize.Y

	task.delay(duration, function()
		Util.Tween(notif, { BackgroundTransparency = 1 })
		task.wait(0.12)
		local idx = table.find(self._queue, notif)
		if idx then table.remove(self._queue, idx) end
		notif:Destroy()
	end)
end

-- ============================================================
-- TOOLTIP SYSTEM
-- ============================================================

local Tooltip = {}
Tooltip._gui = nil
Tooltip._label = nil
Tooltip._frame = nil
Tooltip._delay = 0.4
Tooltip._hovered = false

function Tooltip:_ensureGui()
	if self._gui then return end
	local screenGui = Util.Create("ScreenGui", {
		Name = "Tooltip",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
	})
	self._gui = screenGui
	self._frame = Util.Create("Frame", {
		BackgroundColor3 = Theme.Background,
		BorderColor3 = Theme.Border,
		BorderSizePixel = Theme.BorderThickness,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 100,
	}, { screenGui })
	Renderer.CreateBorder(self._frame)
	self._label = Util.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextSize = Theme.SmallSize,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -12, 0, 0),
		Position = UDim2.fromOffset(6, 4),
	}, { self._frame })
end

function Tooltip:Show(text: string, position: Vector2)
	self:_ensureGui()
	self._label.Text = text
	local textSize = Util.GetTextSize(text, Theme.Font, Theme.SmallSize, 200)
	self._frame.Size = UDim2.fromOffset(textSize.X + 16, textSize.Y + 12)
	self._frame.Position = UDim2.fromOffset(position.X + 10, position.Y + 10)
	self._frame.Visible = true
end

function Tooltip:Hide()
	if self._frame then
		self._frame.Visible = false
	end
end

function Tooltip:Bind(control, text: string)
	control.HitArea = control.HitArea or control.Button
	local target = control.HitArea or control.Frame
	if not target then return end

	target.MouseEnter:Connect(function()
		Tooltip._hovered = true
		task.delay(self._delay, function()
			if Tooltip._hovered then
				local mouse = game:GetService("UserInputService"):GetMouseLocation()
				Tooltip:Show(text, Vector2.new(mouse.X, mouse.Y))
			end
		end)
	end)
	target.MouseLeave:Connect(function()
		Tooltip._hovered = false
		Tooltip:Hide()
	end)
end

-- ============================================================
-- CONFIG SYSTEM
-- ============================================================

local Config = {}
Config.__index = Config

function Config.new(name: string)
	local self = setmetatable({}, Config)
	self.Name = name or "default"
	self._callbacks = {}
	return self
end

function Config:Save(data: { [string]: any })
	local success, encoded = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), data)
	if not success then return false end
	writefile("configs/" .. self.Name .. ".json", encoded)
	for _, cb in self._callbacks do task.spawn(cb, data) end
	return true
end

function Config:Load(): { [string]: any }?
	local path = "configs/" .. self.Name .. ".json"
	if not isfile(path) then return nil end
	local content = readfile(path)
	local success, data = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), content)
	if not success then return nil end
	return data
end

function Config:Delete()
	local path = "configs/" .. self.Name .. ".json"
	if isfile(path) then delfile(path) end
end

function Config:Refresh(): { string }?
	local files = listfiles("configs") or {}
	local configs = {}
	for _, file in files do
		if file:match("%.json$") then
			table.insert(configs, file:match("(.+)%.json$"))
		end
	end
	return configs
end

function Config:OnSave(callback: (data) -> ())
	table.insert(self._callbacks, callback)
end

-- ============================================================
-- LIBRARY WRAPPER
-- ============================================================

local Library = {
	Theme = Theme,
	Util = Util,
	Renderer = Renderer,
	Notifications = Notifications,
	Tooltip = Tooltip,
	Config = Config,
	Window = Window,
	Tab = Tab,
	Groupbox = Groupbox,
	Controls = {
		Label = Label,
		Separator = Separator,
		Button = Button,
		Toggle = Toggle,
		Slider = Slider,
		Textbox = Textbox,
		Dropdown = Dropdown,
		Keybind = Keybind,
		ColorPicker = ColorPicker,
	},
}

function Library:CreateWindow(options: { Title: string, Size: Vector2?, Position: UDim2? }): any
	return Window:new(options)
end

function Library:Notify(text: string, duration: number?)
	Notifications:Show(text, duration)
end

return Library