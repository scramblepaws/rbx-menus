--[[
    ui_utils.luau — Shared UI Library
    Provides constants and helper functions for building Roblox GUIs.
    Both scripts load this via loadstring(game:HttpGet(...)).
]]

local UI = {}

-- === COLOR PALETTE ===
UI.COLORS = {
    Outer   = Color3.fromRGB(0, 0, 0),
    Bg      = Color3.fromRGB(18, 18, 18),
    Panel   = Color3.fromRGB(27, 27, 27),
    Border  = Color3.fromRGB(0, 0, 0),
    Text    = Color3.fromRGB(255, 255, 255),
    Muted   = Color3.fromRGB(200, 200, 200),
    Purple  = Color3.fromRGB(123, 43, 218),
    Hover   = Color3.fromRGB(40, 40, 40),
    Disabled= Color3.fromRGB(100, 100, 100),
}

UI.FONT = Enum.Font.Arial

UI.PAD = { Tiny = 2, Small = 4, Medium = 8, Large = 12, XL = 16 }
UI.SIZE = { Checkbox = 10, RowHeight = 16, ButtonMin = 36 }

-- ============================================================
-- INSTANCE HELPERS
-- ============================================================

function UI.createFrame(parent, props)
    local f = Instance.new("Frame")
    f.Parent = parent
    for k, v in pairs(props) do f[k] = v end
    return f
end

function UI.createTextLabel(parent, props)
    local t = Instance.new("TextLabel")
    t.Parent = parent
    for k, v in pairs(props) do t[k] = v end
    return t
end

function UI.createTextButton(parent, props)
    local b = Instance.new("TextButton")
    b.Parent = parent
    b.AutoButtonColor = false
    for k, v in pairs(props) do b[k] = v end
    return b
end

function UI.createTextBox(parent, props)
    local tb = Instance.new("TextBox")
    tb.Parent = parent
    for k, v in pairs(props) do tb[k] = v end
    return tb
end

-- ============================================================
-- VISUAL FEEDBACK
-- ============================================================

function UI.styleButton(btn, defaultColor, hoverColor)
    defaultColor = defaultColor or UI.COLORS.Panel
    hoverColor = hoverColor or UI.COLORS.Hover
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = hoverColor}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = defaultColor}):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        btn.BackgroundColor3 = hoverColor
    end)
    btn.MouseButton1Up:Connect(function()
        btn.BackgroundColor3 = defaultColor
    end)
end

function UI.addFocusRing(tb)
    tb.Focused:Connect(function()
        tb.BorderColor3 = Color3.fromRGB(255, 255, 150)
    end)
    tb.FocusLost:Connect(function()
        tb.BorderColor3 = UI.COLORS.Border
    end)
end

-- ============================================================
-- COMPONENT FACTORIES
-- ============================================================

function UI.createSidebarButton(sidebar, name, yPos, sidebarButtons, switchTab)
    local btn = UI.createTextButton(sidebar, {
        BackgroundColor3 = UI.COLORS.Bg,
        BorderSizePixel = 1,
        BorderColor3 = UI.COLORS.Border,
        Size = UDim2.new(1, 0, 0, 31),
        Position = UDim2.new(0, 0, 0, yPos),
        Text = name,
        TextColor3 = UI.COLORS.Text,
        TextSize = 10,
        Font = UI.FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
    })

    -- Left padding
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.Parent = btn

    -- Magenta indicator — 3px wide, vertically centered on the left edge
    local indicator = Instance.new("Frame")
    indicator.Name = "Indicator"
    indicator.Parent = btn
    indicator.BackgroundColor3 = UI.COLORS.Purple
    indicator.BorderSizePixel = 0
    indicator.Size = UDim2.new(0, 3, 0, 26)
    indicator.Position = UDim2.new(0, 0, 0.5, -13)
    indicator.Visible = false

    UI.styleButton(btn, UI.COLORS.Bg, UI.COLORS.Hover)

    btn.MouseButton1Click:Connect(function()
        for _, b in pairs(sidebarButtons) do
            local ind = b:FindFirstChild("Indicator")
            if ind then ind.Visible = false end
            b.BackgroundColor3 = UI.COLORS.Bg
        end
        local ind = btn:FindFirstChild("Indicator")
        if ind then ind.Visible = true end
        btn.BackgroundColor3 = UI.COLORS.Bg
        switchTab(name)
    end)

    table.insert(sidebarButtons, btn)
    return btn
end

function UI.createGroupBox(parent, x, y, width, height, title)
    local group = UI.createFrame(parent, {
        BackgroundColor3 = UI.COLORS.Bg,
        BorderSizePixel = 1,
        BorderColor3 = UI.COLORS.Border,
        Size = UDim2.new(0, width, 0, height),
        Position = UDim2.new(0, x, 0, y),
        ClipsDescendants = true,
    })

    local titleLabel = UI.createTextLabel(group, {
        BackgroundColor3 = UI.COLORS.Bg,
        BackgroundTransparency = 0,
        Size = UDim2.new(0, 70, 0, 14),
        Position = UDim2.new(0, 8, 0, 4),
        Text = title,
        TextColor3 = UI.COLORS.Text,
        TextSize = 10,
        Font = UI.FONT,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    return group
end

function UI.createCheckbox(parent, text, yPos, defaultState, callback)
    local row = UI.createFrame(parent, {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, UI.SIZE.RowHeight),
        Position = UDim2.new(0, 0, 0, yPos),
    })

    -- The checkbox box itself — filled purple when checked, dark when unchecked
    local checkBox = UI.createFrame(row, {
        BackgroundColor3 = defaultState and UI.COLORS.Purple or UI.COLORS.Bg,
        BorderSizePixel = 1,
        BorderColor3 = UI.COLORS.Border,
        Size = UDim2.new(0, UI.SIZE.Checkbox, 0, UI.SIZE.Checkbox),
        Position = UDim2.new(0, UI.PAD.Small, 0.5, -UI.SIZE.Checkbox/2),
    })

    -- Label next to checkbox
    local label = UI.createTextLabel(row, {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, UI.PAD.Medium + UI.SIZE.Checkbox, 0, 0),
        Text = text,
        TextColor3 = UI.COLORS.Text,
        TextSize = 10,
        Font = UI.FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    -- Hover feedback on checkbox box
    local function onHover()
        TweenService:Create(checkBox, TweenInfo.new(0.1), {BackgroundColor3 = UI.COLORS.Hover}):Play()
    end
    local function onLeave()
        TweenService:Create(checkBox, TweenInfo.new(0.1), {BackgroundColor3 = defaultState and UI.COLORS.Purple or UI.COLORS.Bg}):Play()
    end
    checkBox.MouseEnter:Connect(onHover)
    checkBox.MouseLeave:Connect(onLeave)
    row.MouseEnter:Connect(onHover)
    row.MouseLeave:Connect(onLeave)

    -- Toggle logic — purple fill = checked, dark = unchecked (no ✓ symbol)
    local state = defaultState or false
    checkBox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            state = not state
            checkBox.BackgroundColor3 = state and UI.COLORS.Purple or UI.COLORS.Bg
            if callback then callback(state) end
        end
    end)

    return checkBox
end

function UI.createDropdown(parent, x, y, width, height, options, defaultIndex)
    local dropdown = UI.createTextButton(parent, {
        BackgroundColor3 = UI.COLORS.Panel,
        BorderSizePixel = 1,
        BorderColor3 = UI.COLORS.Border,
        Size = UDim2.new(0, width, 0, height),
        Position = UDim2.new(0, x, 0, y),
        Text = options[defaultIndex or 1] or "Select",
        TextColor3 = UI.COLORS.Text,
        TextSize = 10,
        Font = UI.FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
    })
    UI.styleButton(dropdown, UI.COLORS.Panel, UI.COLORS.Hover)

    -- Left padding for text
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, UI.PAD.Medium + UI.SIZE.Checkbox)
    pad.Parent = dropdown

    -- Arrow indicator
    local arrow = UI.createTextLabel(dropdown, {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, 10, 1, 0),
        Position = UDim2.new(1, -18, 0, 0),
        Text = "▼",
        TextColor3 = UI.COLORS.Muted,
        TextSize = 8,
        Font = UI.FONT,
    })

    local currentIndex = defaultIndex or 1
    dropdown.MouseButton1Click:Connect(function()
        currentIndex = currentIndex % #options + 1
        dropdown.Text = options[currentIndex]
    end)
    return dropdown
end

function UI.createActionButton(parent, x, y, width, height, text, callback)
    local btn = UI.createTextButton(parent, {
        BackgroundColor3 = UI.COLORS.Panel,
        BorderSizePixel = 1,
        BorderColor3 = UI.COLORS.Border,
        Size = UDim2.new(0, width, 0, height),
        Position = UDim2.new(0, x, 0, y),
        Text = text,
        TextColor3 = UI.COLORS.Text,
        TextSize = 10,
        Font = UI.FONT,
    })
    UI.styleButton(btn, UI.COLORS.Panel, UI.COLORS.Hover)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

return UI