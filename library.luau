--[[
	TacticalUI
	A minimalist, dense, monochromatic Luau UI library for Roblox.

	Usage:
		local TacticalUI = require(path.to.TacticalUI)

		local window = TacticalUI.Window.new({
			Title = "my plugin [v1.0]",
			Date = os.date("%A, %d %B %Y"),
			Size = UDim2.new(0, 800, 0, 500),
			Parent = someScreenGuiOrPluginGui,
		})

	See Example.lua for a full usage sample matching this style.
--]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local TacticalUI = {}
TacticalUI.__index = TacticalUI

--==============================================================
-- THEME
--==============================================================

local Theme = {
	Background       = Color3.fromRGB(13, 13, 13),
	PanelBackground  = Color3.fromRGB(17, 17, 17),
	Border           = Color3.fromRGB(44, 44, 44),
	BorderSecondary  = Color3.fromRGB(30, 30, 30),
	TextPrimary      = Color3.fromRGB(240, 240, 240),
	TextSecondary    = Color3.fromRGB(168, 168, 168),
	TextInactive     = Color3.fromRGB(102, 102, 102),
	Accent           = Color3.fromRGB(168, 166, 255),
	Font             = Enum.Font.SourceSans,
	FontMono         = Enum.Font.Code,
	FontSize         = 14,
	FontSizeSmall    = 13,
	Padding          = 12,
	OuterPadding     = 20,
	ControlSpacing   = 8,
	GroupSpacing     = 18,
	BorderThickness  = 1,
	ControlHeight    = 24,
	TopBarHeight     = 34,
	HeaderHeight     = 38,
	CornerRadius     = 0,
}

function TacticalUI.SetTheme(overrides)
	for k, v in pairs(overrides) do
		Theme[k] = v
	end
end

function TacticalUI.GetTheme()
	return Theme
end

--==============================================================
-- INTERNAL HELPERS
--==============================================================

local function new(className, props)
	local inst = Instance.new(className)
	for prop, value in pairs(props or {}) do
		inst[prop] = value
	end
	return inst
end

local function applyBorder(inst, color, thickness)
	local stroke = new("UIStroke", {
		Color = color or Theme.Border,
		Thickness = thickness or Theme.BorderThickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
	if Theme.CornerRadius and Theme.CornerRadius > 0 then
		new("UICorner", { CornerRadius = UDim.new(0, Theme.CornerRadius), Parent = inst })
	end
	return stroke
end

local function label(text, props)
	local base = {
		Text = text or "",
		Font = Theme.Font,
		TextSize = Theme.FontSizeSmall,
		TextColor3 = Theme.TextSecondary,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Theme.ControlHeight),
	}
	if props then
		for k, v in pairs(props) do
			base[k] = v
		end
	end
	return new("TextLabel", base)
end

local function row(height)
	return new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or Theme.ControlHeight),
		AutomaticSize = Enum.AutomaticSize.None,
	})
end

local function verticalList(parent, padding, alignment)
	local layout = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, padding or Theme.ControlSpacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
	return layout
end

--==============================================================
-- BASE CONTROL FACTORIES (used internally by Panel)
--==============================================================

local Controls = {}

function Controls.Checkbox(parentFrame, text, initial, callback)
	local container = row()
	container.Parent = parentFrame

	local box = new("Frame", {
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0, 0, 0.5, -7),
		BackgroundColor3 = initial and Theme.Accent or Theme.PanelBackground,
		BorderSizePixel = 0,
		Parent = container,
	})
	applyBorder(box, Theme.Border)

	local lbl = label(text, {
		Position = UDim2.new(0, 24, 0, 0),
		Size = UDim2.new(1, -24, 1, 0),
		TextColor3 = Theme.TextPrimary,
	})
	lbl.Parent = container

	local checked = initial and true or false

	local clickArea = new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		AutoButtonColor = false,
		Parent = container,
	})

	clickArea.MouseButton1Click:Connect(function()
		checked = not checked
		box.BackgroundColor3 = checked and Theme.Accent or Theme.PanelBackground
		if callback then
			callback(checked)
		end
	end)

	return {
		Instance = container,
		Set = function(_, value)
			checked = value
			box.BackgroundColor3 = checked and Theme.Accent or Theme.PanelBackground
		end,
		Get = function()
			return checked
		end,
	}
end

function Controls.Slider(parentFrame, text, min, max, default, callback)
	local outer = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Theme.ControlHeight + 16),
		Parent = parentFrame,
	})

	local topRow = row()
	topRow.Parent = outer
	topRow.Position = UDim2.new(0, 0, 0, 0)

	local lbl = label(text, {
		Size = UDim2.new(0.6, 0, 1, 0),
		TextColor3 = Theme.TextPrimary,
	})
	lbl.Parent = topRow

	local valueLabel = label(tostring(default), {
		Size = UDim2.new(0.4, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.TextSecondary,
	})
	valueLabel.Parent = topRow

	local track = new("Frame", {
		Position = UDim2.new(0, 0, 0, Theme.ControlHeight + 6),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Theme.BorderSecondary,
		BorderSizePixel = 0,
		Parent = outer,
	})

	local fillRatio = math.clamp((default - min) / (max - min), 0, 1)

	local fill = new("Frame", {
		Size = UDim2.new(fillRatio, 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = track,
	})

	local thumb = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(0, 8, 0, 16),
		Position = UDim2.new(fillRatio, -4, 0.5, -8),
		BackgroundColor3 = Theme.PanelBackground,
		BorderSizePixel = 0,
		Parent = track,
	})
	applyBorder(thumb, Theme.Border)

	local dragging = false
	local currentValue = default

	local function updateFromX(xPos)
		local trackAbsPos = track.AbsolutePosition.X
		local trackAbsSize = track.AbsoluteSize.X
		local ratio = math.clamp((xPos - trackAbsPos) / trackAbsSize, 0, 1)
		currentValue = min + (max - min) * ratio
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		thumb.Position = UDim2.new(ratio, -4, 0.5, -8)
		local rounded = math.floor(currentValue * 10 + 0.5) / 10
		valueLabel.Text = tostring(rounded)
		if callback then
			callback(rounded)
		end
	end

	thumb.MouseButton1Down:Connect(function()
		dragging = true
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	return {
		Instance = outer,
		Set = function(_, value)
			local ratio = math.clamp((value - min) / (max - min), 0, 1)
			currentValue = value
			fill.Size = UDim2.new(ratio, 0, 1, 0)
			thumb.Position = UDim2.new(ratio, -4, 0.5, -8)
			valueLabel.Text = tostring(value)
		end,
		Get = function()
			return currentValue
		end,
	}
end

function Controls.TextInput(parentFrame, placeholder, default, callback)
	local container = row()
	container.Parent = parentFrame

	local box = new("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Theme.PanelBackground,
		BorderSizePixel = 0,
		Parent = container,
	})
	applyBorder(box, Theme.Border)

	new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = box,
	})

	local textBox = new("TextBox", {
		Text = default or "",
		PlaceholderText = placeholder or "",
		Font = Theme.Font,
		TextSize = Theme.FontSizeSmall,
		TextColor3 = Theme.TextPrimary,
		PlaceholderColor3 = Theme.TextInactive,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = box,
	})

	textBox.FocusLost:Connect(function(enterPressed)
		if callback then
			callback(textBox.Text, enterPressed)
		end
	end)

	return {
		Instance = container,
		Set = function(_, value)
			textBox.Text = value
		end,
		Get = function()
			return textBox.Text
		end,
	}
end

function Controls.Dropdown(parentFrame, options, defaultIndex, callback)
	local container = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Theme.ControlHeight),
		ClipsDescendants = false,
		ZIndex = 2,
		Parent = parentFrame,
	})

	local box = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, Theme.ControlHeight),
		BackgroundColor3 = Theme.PanelBackground,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = container,
	})
	applyBorder(box, Theme.Border)

	new("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = box,
	})

	local selected = options[defaultIndex] or options[1] or ""

	local selectedLabel = label(selected, {
		Size = UDim2.new(1, 0, 1, 0),
		TextColor3 = Theme.Accent,
		ZIndex = 2,
	})
	selectedLabel.Parent = box

	local listFrame = new("Frame", {
		Position = UDim2.new(0, 0, 1, 2),
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Theme.PanelBackground,
		BorderSizePixel = 0,
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = container,
	})
	applyBorder(listFrame, Theme.Border)
	verticalList(listFrame, 0)

	local open = false

	local function close()
		open = false
		listFrame.Visible = false
	end

	local function rebuildOptions()
		for _, child in ipairs(listFrame:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for i, optionText in ipairs(options) do
			local optionButton = new("TextButton", {
				Text = "  " .. optionText,
				Font = Theme.Font,
				TextSize = Theme.FontSizeSmall,
				TextColor3 = Theme.TextSecondary,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, Theme.ControlHeight),
				ZIndex = 6,
				LayoutOrder = i,
				Parent = listFrame,
			})
			optionButton.MouseButton1Click:Connect(function()
				selected = optionText
				selectedLabel.Text = selected
				close()
				if callback then
					callback(selected, i)
				end
			end)
		end
		listFrame.Size = UDim2.new(1, 0, 0, #options * Theme.ControlHeight)
	end

	rebuildOptions()

	box.MouseButton1Click:Connect(function()
		open = not open
		listFrame.Visible = open
	end)

	return {
		Instance = container,
		SetOptions = function(_, newOptions)
			options = newOptions
			rebuildOptions()
		end,
		Set = function(_, value)
			selected = value
			selectedLabel.Text = value
		end,
		Get = function()
			return selected
		end,
		Close = close,
	}
end

function Controls.Button(parentFrame, text, callback)
	local btn = new("TextButton", {
		Text = text,
		Font = Theme.Font,
		TextSize = Theme.FontSizeSmall,
		TextColor3 = Theme.TextPrimary,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.PanelBackground,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, Theme.ControlHeight),
		Parent = parentFrame,
	})
	applyBorder(btn, Theme.Border)

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Theme.BorderSecondary
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = Theme.PanelBackground
	end)
	btn.MouseButton1Click:Connect(function()
		if callback then
			callback()
		end
	end)

	return { Instance = btn }
end

function Controls.Separator(parentFrame)
	local sep = new("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.BorderSecondary,
		BorderSizePixel = 0,
		Parent = parentFrame,
	})
	return { Instance = sep }
end

function Controls.Label(parentFrame, text, secondary)
	local lbl = label(text, {
		TextColor3 = secondary and Theme.TextSecondary or Theme.TextPrimary,
	})
	lbl.Parent = parentFrame
	return {
		Instance = lbl,
		SetText = function(_, newText)
			lbl.Text = newText
		end,
	}
end

--==============================================================
-- PANEL
--==============================================================

local Panel = {}
Panel.__index = Panel

function Panel.new(parent, opts)
	opts = opts or {}
	local self = setmetatable({}, Panel)

	local frame = new("Frame", {
		BackgroundColor3 = Theme.PanelBackground,
		BorderSizePixel = 0,
		Size = opts.Size or UDim2.new(1, 0, 1, 0),
		LayoutOrder = opts.LayoutOrder or 0,
		Parent = parent,
	})
	applyBorder(frame, Theme.Border)

	new("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.Padding),
		PaddingRight = UDim.new(0, Theme.Padding),
		PaddingTop = UDim.new(0, Theme.Padding),
		PaddingBottom = UDim.new(0, Theme.Padding),
		Parent = frame,
	})

	local content = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = frame,
	})

	verticalList(content, Theme.ControlSpacing)

	if opts.Title then
		Controls.Label(content, opts.Title, false)
	end

	self._frame = frame
	self._content = content
	self._order = 0

	return self
end

local function nextOrder(self)
	self._order += 1
	return self._order
end

function Panel:AddCheckbox(text, initial, callback)
	local c = Controls.Checkbox(self._content, text, initial, callback)
	c.Instance.LayoutOrder = nextOrder(self)
	return c
end

function Panel:AddSlider(text, min, max, default, callback)
	local c = Controls.Slider(self._content, text, min, max, default, callback)
	c.Instance.LayoutOrder = nextOrder(self)
	return c
end

function Panel:AddTextInput(placeholder, default, callback)
	local c = Controls.TextInput(self._content, placeholder, default, callback)
	c.Instance.LayoutOrder = nextOrder(self)
	return c
end

function Panel:AddDropdown(options, defaultIndex, callback)
	local c = Controls.Dropdown(self._content, options, defaultIndex, callback)
	c.Instance.LayoutOrder = nextOrder(self)
	return c
end

function Panel:AddButton(text, callback)
	local c = Controls.Button(self._content, text, callback)
	c.Instance.LayoutOrder = nextOrder(self)
	return c
end

function Panel:AddLabel(text, secondary)
	local c = Controls.Label(self._content, text, secondary)
	c.Instance.LayoutOrder = nextOrder(self)
	return c
end

function Panel:AddSeparator()
	local c = Controls.Separator(self._content)
	c.Instance.LayoutOrder = nextOrder(self)
	return c
end

function Panel:AddGroupSpacing()
	local spacer = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Theme.GroupSpacing),
		LayoutOrder = nextOrder(self),
		Parent = self._content,
	})
	return { Instance = spacer }
end

--==============================================================
-- TAB
--==============================================================

local Tab = {}
Tab.__index = Tab

function Tab.new(parent)
	local self = setmetatable({}, Tab)

	local frame = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Visible = false,
		Parent = parent,
	})

	local layout = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, Theme.GroupSpacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = frame,
	})

	self._frame = frame
	self._panelCount = 0

	return self
end

function Tab:AddPanel(opts)
	opts = opts or {}
	self._panelCount += 1
	local width = opts.Width or 1
	local size = UDim2.new(width, (width < 1) and -(Theme.GroupSpacing / 2) or 0, 1, 0)
	local panel = Panel.new(self._frame, {
		Title = opts.Title,
		Size = size,
		LayoutOrder = self._panelCount,
	})
	return panel
end

function Tab:SetVisible(visible)
	self._frame.Visible = visible
end

--==============================================================
-- WINDOW
--==============================================================

local Window = {}
Window.__index = Window

function Window.new(opts)
	opts = opts or {}
	local self = setmetatable({}, Window)

	local size = opts.Size or UDim2.new(0, 900, 0, 560)

	local root = new("Frame", {
		Size = size,
		Position = opts.Position or UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = opts.Parent,
	})
	applyBorder(root, Theme.Border)

	-- Header
	local header = new("Frame", {
		Size = UDim2.new(1, 0, 0, Theme.HeaderHeight),
		BackgroundTransparency = 1,
		Parent = root,
	})
	new("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.OuterPadding),
		PaddingRight = UDim.new(0, Theme.OuterPadding),
		Parent = header,
	})

	local titleLabel = new("TextLabel", {
		Text = opts.Title or "window",
		Font = Theme.FontMono,
		TextSize = Theme.FontSize,
		TextColor3 = Theme.TextPrimary,
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.6, 0, 1, 0),
		Parent = header,
	})

	local dateLabel = new("TextLabel", {
		Text = opts.Date or "",
		Font = Theme.FontMono,
		TextSize = Theme.FontSizeSmall,
		TextColor3 = Theme.TextInactive,
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundTransparency = 1,
		Size = UDim2.new(0.4, 0, 1, 0),
		Parent = header,
	})

	local headerLine = new("Frame", {
		Position = UDim2.new(0, 0, 0, Theme.HeaderHeight),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Parent = root,
	})

	-- Top bar: horizontal row of tab labels (populated by Window:AddTab)
	local topBarY = Theme.HeaderHeight + 1
	local topBar = new("Frame", {
		Position = UDim2.new(0, 0, 0, topBarY),
		Size = UDim2.new(1, 0, 0, Theme.TopBarHeight),
		BackgroundTransparency = 1,
		Parent = root,
	})
	new("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.OuterPadding),
		PaddingRight = UDim.new(0, Theme.OuterPadding),
		Parent = topBar,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, Theme.GroupSpacing),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = topBar,
	})

	local topBarLine = new("Frame", {
		Position = UDim2.new(0, 0, 0, topBarY + Theme.TopBarHeight),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Parent = root,
	})

	-- Body: sidebar + content
	local bodyY = topBarY + Theme.TopBarHeight + 1
	local body = new("Frame", {
		Position = UDim2.new(0, 0, 0, bodyY),
		Size = UDim2.new(1, 0, 1, -bodyY),
		BackgroundTransparency = 1,
		Parent = root,
	})

	local sidebarWidth = opts.SidebarWidth or 160

	local sidebar = new("Frame", {
		Size = UDim2.new(0, sidebarWidth, 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})
	new("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.OuterPadding),
		PaddingTop = UDim.new(0, Theme.OuterPadding),
		Parent = sidebar,
	})
	local sidebarList = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sidebar,
	})

	local sidebarDivider = new("Frame", {
		Position = UDim2.new(0, sidebarWidth, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Parent = body,
	})

	local content = new("Frame", {
		Position = UDim2.new(0, sidebarWidth + 1, 0, 0),
		Size = UDim2.new(1, -(sidebarWidth + 1), 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})
	new("UIPadding", {
		PaddingLeft = UDim.new(0, Theme.OuterPadding),
		PaddingRight = UDim.new(0, Theme.OuterPadding),
		PaddingTop = UDim.new(0, Theme.OuterPadding),
		PaddingBottom = UDim.new(0, Theme.OuterPadding),
		Parent = content,
	})

	self._root = root
	self._sidebar = sidebar
	self._content = content
	self._topBar = topBar
	self._navItems = {}
	self._tabs = {}
	self._topTabButtons = {}
	self._activeNav = nil
	self._activeTab = nil

	return self
end

function Window:AddNavItem(text, callback)
	local index = #self._navItems + 1

	local btn = new("TextButton", {
		Text = text,
		Font = Theme.Font,
		TextSize = Theme.FontSizeSmall,
		TextColor3 = Theme.TextInactive,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Theme.ControlHeight),
		LayoutOrder = index,
		Parent = self._sidebar,
	})

	local entry = { Button = btn, Callback = callback, Index = index }
	table.insert(self._navItems, entry)

	btn.MouseButton1Click:Connect(function()
		self:SetActiveNav(index)
		if callback then
			callback()
		end
	end)

	if index == 1 then
		self:SetActiveNav(1)
	end

	return entry
end

function Window:SetActiveNav(index)
	self._activeNav = index
	for i, entry in ipairs(self._navItems) do
		entry.Button.TextColor3 = (i == index) and Theme.TextPrimary or Theme.TextInactive
	end
end

function Window:AddTab(label_)
	local tab = Tab.new(self._content)
	table.insert(self._tabs, tab)
	if #self._tabs == 1 then
		self:SetActiveTab(1)
	end
	return tab
end

function Window:SetActiveTab(index)
	self._activeTab = index
	for i, tab in ipairs(self._tabs) do
		tab:SetVisible(i == index)
	end
end

function Window:Destroy()
	self._root:Destroy()
end

--==============================================================
-- EXPORTS
--==============================================================

TacticalUI.Window = Window
TacticalUI.Tab = Tab
TacticalUI.Panel = Panel
TacticalUI.Controls = Controls
TacticalUI.Theme = Theme

return TacticalUI
