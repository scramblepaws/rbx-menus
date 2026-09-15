--[[ ============================================================
  menu.lua | Fatality-style menu library
  Dark + purple | Single file, no dependencies.

  LOAD (no UI appears until you build one):
    local NovaLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/menulib.luau"))()
    -- NovaLib is also exposed as _G.NovaLib for executor workflows.

  API:
    NovaLib:Window({ Logo, Accent, ToggleKey }) -> Win
    Win:Tab(name)              -> top-level header tab
    Tab:Sub(name)              -> left sub-nav entry (3-column page)
    Sub:Group(title)           -> groupbox (auto-fills columns 1-3)
    Group:Toggle({ Name, Default, Flag, Callback(v) })
    Group:Dropdown({ Name, Options, Default, Flag, Callback(opt, idx) })
    Group:Slider({ Name, Min, Max, Default, Suffix, Flag, Callback(v) })
    Group:Button({ Name, Callback() })
    Group:Section(text)
    NovaLib:Watermark(text)    -> top-right logo | fps | ping
    NovaLib:Bind({ Name, Key, Mode="toggle"|"hold", Callback(s) })
    NovaLib:Unbind(nameOrEntry)
    NovaLib:ToggleUI()         -> open/close (default hotkey: L)
    NovaLib:OnAdd(fn)          -> footer "+ Add" hook
    NovaLib:Unload()           -> destroy everything
    NovaLib.Flags              -> live values for every Flagged control
    NovaLib.Version            -> build stamp (also in footer)

  UX notes: right-click any toggle row to bind it to a key
  (toggle/hold) via popup; binds mirror into the bind list.
  See Demo.lua for a complete integration example.
============================================================ --]]

-- all fields predeclared so strict Luau checkers don't flag later assigns
local NovaLib = {
    Flags = {},
    _conns = {},
    _binds = {},
    _bindConn = nil,
    _bindEndConn = nil,
    _popConn = nil,
    _capturing = false,
    _renderBind = nil,
    _gui = nil,
    _tickers = {},
    Version = nil, -- set to Config.Version at the bottom
}

--// Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

--// Config
local Config = {
    Accent  = Color3.fromRGB(168, 85, 247),
    Bg      = Color3.fromRGB(13, 13, 20),
    Panel   = Color3.fromRGB(19, 19, 28),
    Group   = Color3.fromRGB(23, 23, 34),
    Control = Color3.fromRGB(30, 30, 42),
    Stroke  = Color3.fromRGB(44, 44, 60),
    OffTrack= Color3.fromRGB(48, 48, 64),
    Text    = Color3.fromRGB(235, 235, 242),
    Dim     = Color3.fromRGB(140, 140, 155),
    Soft    = Color3.fromRGB(178, 178, 190), -- muted primary labels
    Version = "1.3", -- bump every delivery; shown in footer + NovaLib.Version
    Speed   = 0.16,
    Stagger = 0.07, -- tab cascade step (seconds between tabs)
    Travel  = 0.4,  -- tab slide time (logo <-> slot)
}

--// Helpers
local function Tween(obj, props, t, style, dir)
    if typeof(obj) ~= "Instance" then return nil end
    local ok, tw = pcall(function()
        return TweenService:Create(obj,
            TweenInfo.new(t or Config.Speed,
                style or Enum.EasingStyle.Quad,
                dir or Enum.EasingDirection.Out),
            props)
    end)
    if ok and tw then
        pcall(function() tw:Play() end)
        return tw
    end
    pcall(function()
        for k, v in pairs(props) do obj[k] = v end
    end)
    return nil
end

local function Create(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do
        if k ~= "Parent" then
            pcall(function() o[k] = v end)
        end
    end
    o.Parent = parent or props.Parent
    return o
end

-- shell stays squared (explicit 0), inner controls pick a soft radius
local function Corner(parent, r)
    return Create("UICorner", { CornerRadius = UDim.new(0, r or 0) }, parent)
end

local function Stroke(parent, color, transp, thick)
    return Create("UIStroke", {
        Color = color or Config.Stroke,
        Transparency = transp or 0.2,
        Thickness = thick or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

-- one shared panel border so sub-nav + groupboxes can never drift apart
local function PanelBorder(parent)
    return Stroke(parent, Config.Stroke, 0.15, 1)
end

local function Pad(parent, l, t, r, b)
    return Create("UIPadding", {
        PaddingLeft = UDim.new(0, l or 10),
        PaddingTop = UDim.new(0, t or 8),
        PaddingRight = UDim.new(0, r or 10),
        PaddingBottom = UDim.new(0, b or 8),
    }, parent)
end

-- Ubuntu (ships with Roblox). Nil-safe: Create() pcall keeps default font if missing.
local function UB(weight)
    local ok, f = pcall(function()
        return Font.fromName("Ubuntu", weight or Enum.FontWeight.Regular)
    end)
    if ok and typeof(f) == "Font" then return f end
    return nil
end

-- single shared heartbeat: systems register tick fns instead of opening
-- their own connections (1 connection total per Window lifetime).
local function onTick(fn)
    table.insert(NovaLib._tickers, fn)
end

--// Parent (executor-safe)
local function GetParent()
    local ok, hui = pcall(function()
        if typeof(gethui) == "function" then return gethui() end
        return nil
    end)
    if ok and hui then return hui end
    local ok2, core = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and core then
        local probe = pcall(function()
            local g = Instance.new("ScreenGui")
            g.Parent = core
            g:Destroy()
        end)
        if probe then return core end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

--// THE panel. Groupboxes, the binds list, and the bind popup are all
-- built by this one function: square shell, shared border, group
-- padding, uppercase title. Identical by construction, not by effort.
local function createPanel(parent, title, props)
    props = props or {}
    local box = Create("Frame", {
        Name = props.Name or "Panel",
        AnchorPoint = props.Anchor or Vector2.new(0, 0),
        Position = props.Pos or UDim2.new(0, 0, 0, 0),
        Size = props.Size or UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Config.Group,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = props.Order or 0,
    }, parent)
    Corner(box, 0)
    PanelBorder(box)
    Pad(box, 10, 8, 10, 10)
    Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, box)
    Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = string.upper(tostring(title)),
        FontFace = UB(Enum.FontWeight.Bold),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Text,
        TextTruncate = Enum.TextTruncate.AtEnd,
        LayoutOrder = 0,
    }, box)
    local inner = Create("Frame", {
        Name = "Rows",
        Size = UDim2.new(1, 0, 0, 10),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
    }, box)
    Create("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, inner)
    return box, inner
end

--// Row builders (shared by every groupbox) -----------------------------
local function BuildRows(group, page)
    -- Toggle: label left, square checkbox right
    function group:Toggle(o)
        local state = o.Default or false
        if o.Flag then NovaLib.Flags[o.Flag] = state end

        local row = Create("TextButton", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
        }, page)
        Create("TextLabel", {
            Size = UDim2.new(1, -26, 1, 0),
            BackgroundTransparency = 1,
            Text = o.Name,
            FontFace = UB(Enum.FontWeight.Regular),
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Config.Soft,
        }, row)
        local box = Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            BackgroundColor3 = state and Config.Accent or Config.Control,
            BorderSizePixel = 0,
        }, row)
        Corner(box, 4)
        Stroke(box, state and Config.Accent or Config.Stroke, 0, 1)
        -- bound-key hint (appears when right-click bound)
        local hint = Create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -30, 0.5, 0),
            Size = UDim2.new(0, 40, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            FontFace = UB(Enum.FontWeight.Regular),
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Config.Dim,
            Visible = false,
        }, row)

        local api = { Name = o.Name, bindEntry = nil, Hint = hint }
        local function render()
            box.BackgroundColor3 = state and Config.Accent or Config.Control
            local s = box:FindFirstChildOfClass("UIStroke")
            if s then s.Color = state and Config.Accent or Config.Stroke end
        end
        local function setState(v, fire)
            state = v and true or false
            if o.Flag then NovaLib.Flags[o.Flag] = state end
            render()
            if fire ~= false and o.Callback then pcall(o.Callback, state) end
            if api.bindEntry then
                api.bindEntry.State = state
                if NovaLib._renderBind then NovaLib._renderBind(api.bindEntry) end
            end
        end
        api.Get = function() return state end
        api.Set = function(v) setState(v) end

        row.MouseButton1Click:Connect(function() setState(not state) end)
        row.MouseEnter:Connect(function()
            local s = box:FindFirstChildOfClass("UIStroke")
            if s then s.Color = Config.Accent end
        end)
        row.MouseLeave:Connect(render)
        -- right-click opens the keybind popup for this function
        row.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton2 then
                NovaLib:BindPopup(api)
            end
        end)
        render()
        return row
    end

    -- Dropdown: label left, value box right, expands inline
    function group:Dropdown(o)
        local options = o.Options or { "None" }
        local current = options[o.Default or 1] or options[1]
        local open = false
        if o.Flag then NovaLib.Flags[o.Flag] = current end

        local holder = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
        }, page)
        Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, holder)

        local head = Create("TextButton", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
        }, holder)
        Create("TextLabel", {
            Size = UDim2.new(1, -96, 1, 0),
            BackgroundTransparency = 1,
            Text = o.Name,
            FontFace = UB(Enum.FontWeight.Regular),
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Config.Soft,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, head)
        local valBox = Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 88, 0, 18),
            BackgroundColor3 = Config.Control,
            BorderSizePixel = 0,
        }, head)
        Corner(valBox, 4)
        Stroke(valBox, Config.Stroke, 0.3, 1)
        local valLbl = Create("TextLabel", {
            Position = UDim2.new(0, 6, 0, 0),
            Size = UDim2.new(1, -22, 1, 0),
            BackgroundTransparency = 1,
            Text = tostring(current),
            FontFace = UB(Enum.FontWeight.Regular),
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Config.Dim,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, valBox)
        local arrow = Create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -4, 0.5, 0),
            Size = UDim2.fromOffset(12, 12),
            BackgroundTransparency = 1,
            Text = ">",
            Rotation = 90,
            FontFace = UB(Enum.FontWeight.Bold),
            TextSize = 11,
            TextColor3 = Config.Dim,
        }, valBox)

        local list = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Config.Control,
            BorderSizePixel = 0,
            Visible = false,
            ClipsDescendants = true,
        }, holder)
        Corner(list, 4)
        Stroke(list, Config.Stroke, 0.3, 1)
        Pad(list, 3, 3, 3, 3)
        Create("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, list)

        local function setOpen(v)
            open = v
            Tween(arrow, { Rotation = open and 270 or 90 }, 0.12)
            if open then
                list.Visible = true
                Tween(list, { Size = UDim2.new(1, 0, 0, math.min(#options * 21 + 6, 110)) }, 0.18)
            else
                Tween(list, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                task.delay(0.15, function() if not open then list.Visible = false end end)
            end
        end
        head.MouseButton1Click:Connect(function() setOpen(not open) end)

        for i, opt in ipairs(options) do
            local ob = Create("TextButton", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                Text = tostring(opt),
                FontFace = UB(Enum.FontWeight.Regular),
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Config.Dim,
                AutoButtonColor = false,
            }, list)
            Pad(ob, 6, 0, 0, 0)
            ob.MouseEnter:Connect(function() ob.TextColor3 = Config.Accent end)
            ob.MouseLeave:Connect(function()
                ob.TextColor3 = (tostring(opt) == tostring(current)) and Config.Text or Config.Dim
            end)
            ob.MouseButton1Click:Connect(function()
                current = opt
                valLbl.Text = tostring(opt)
                if o.Flag then NovaLib.Flags[o.Flag] = opt end
                for _, ch in ipairs(list:GetChildren()) do
                    if ch:IsA("TextButton") then
                        ch.TextColor3 = (ch.Text == tostring(opt)) and Config.Text or Config.Dim
                    end
                end
                setOpen(false)
                if o.Callback then pcall(o.Callback, opt, i) end
            end)
            if tostring(opt) == tostring(current) then ob.TextColor3 = Config.Text end
        end
        return holder
    end

    -- Slider: label left + value right, drag row to slide, thin meter below
    function group:Slider(o)
        local min, max = o.Min or 0, o.Max or 100
        local suffix = o.Suffix or ""
        local val = math.clamp(o.Default or min, min, max)
        if o.Flag then NovaLib.Flags[o.Flag] = math.floor(val + 0.5) end

        local row = Create("TextButton", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
        }, page)
        Create("TextLabel", {
            Size = UDim2.new(0.6, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = o.Name,
            FontFace = UB(Enum.FontWeight.Regular),
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Config.Soft,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)
        local valLbl = Create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0.4, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = tostring(math.floor(val + 0.5)) .. suffix,
            FontFace = UB(Enum.FontWeight.Bold),
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextColor3 = Config.Dim,
        }, row)
        local track = Create("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, -5),
            Size = UDim2.new(1, 0, 0, 4),
            BackgroundColor3 = Config.OffTrack,
            BorderSizePixel = 0,
        }, row)
        Corner(track, 2)
        local fill = Create("Frame", {
            Size = UDim2.new((val - min) / math.max(1, (max - min)), 0, 1, 0),
            BackgroundColor3 = Config.Accent,
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
        }, track)
        Corner(fill, 2)
        local knob = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new((val - min) / math.max(1, (max - min)), 0, 0.5, 0),
            Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = Config.Accent,
            BorderSizePixel = 0,
        }, track)
        Corner(knob, 99)

        local dragging = false
        local function apply(pct)
            pct = math.clamp(pct, 0, 1)
            val = min + (max - min) * pct
            local shown = math.floor(val + 0.5)
            valLbl.Text = tostring(shown) .. suffix
            fill.Size = UDim2.new(pct, 0, 1, 0)
            knob.Position = UDim2.new(pct, 0, 0.5, 0)
            Tween(fill, { BackgroundTransparency = dragging and 0 or 0.35 }, 0.12)
            if o.Flag then NovaLib.Flags[o.Flag] = shown end
            if o.Callback then pcall(o.Callback, shown) end
        end
        row.MouseEnter:Connect(function()
            if not dragging then Tween(track, { BackgroundColor3 = Color3.fromRGB(62, 62, 80) }, 0.12) end
        end)
        row.MouseLeave:Connect(function()
            if not dragging then Tween(track, { BackgroundColor3 = Config.OffTrack }, 0.12) end
        end)
        row.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                valLbl.TextColor3 = Config.Accent
                apply((i.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X))
            end
        end)
        table.insert(NovaLib._conns, UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                if dragging then
                    dragging = false
                    valLbl.TextColor3 = Config.Dim
                    Tween(fill, { BackgroundTransparency = 0.35 }, 0.15)
                    Tween(track, { BackgroundColor3 = Config.OffTrack }, 0.15)
                end
            end
        end))
        table.insert(NovaLib._conns, UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                apply((i.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X))
            end
        end))
        return row
    end

    -- Button: full-width dark button
    function group:Button(o)
        local b = Create("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Config.Control,
            Text = o.Name,
            FontFace = UB(Enum.FontWeight.Regular),
            TextSize = 12,
            TextColor3 = Config.Soft,
            AutoButtonColor = false,
            BorderSizePixel = 0,
        }, page)
        Corner(b, 4)
        Stroke(b, Config.Stroke, 0.3, 1)
        b.MouseEnter:Connect(function()
            local s = b:FindFirstChildOfClass("UIStroke")
            if s then s.Color = Config.Accent end
            b.TextColor3 = Config.Accent
        end)
        b.MouseLeave:Connect(function()
            local s = b:FindFirstChildOfClass("UIStroke")
            if s then s.Color = Config.Stroke end
            b.TextColor3 = Config.Soft
        end)
        b.MouseButton1Click:Connect(function()
            if o.Callback then pcall(o.Callback) end
        end)
        return b
    end

    function group:Section(text)
        return Create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = string.upper(tostring(text)),
            FontFace = UB(Enum.FontWeight.Bold),
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Config.Dim,
        }, page)
    end
end

--// Shared overlay helpers (binds panel + popups) -------------------------
local function makeDraggable(frame, handle)
    local dragging, ds, sp = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, ds, sp = true, i.Position, frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    table.insert(NovaLib._conns, UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end))
end

local function renderBind(b)
    pcall(function()
        b.NameLbl.TextColor3 = b.State and Config.Text or Config.Dim
        b.KeyBox.BackgroundColor3 = b.State and Config.Accent or Config.Control
        b.KeyLbl.TextColor3 = b.State and Color3.new(1, 1, 1) or Config.Dim
    end)
end
NovaLib._renderBind = renderBind

local function keyName(key)
    local s = tostring(key)
    return string.gsub(s, "^Enum%.KeyCode%.", "")
end

--// Window ---------------------------------------------------------------
function NovaLib:Window(opts)
    opts = opts or {}
    local logoText = opts.Logo or "menu.lua"
    if opts.Accent then Config.Accent = opts.Accent end
    local toggleKey = opts.ToggleKey or Enum.KeyCode.L

    local HUI = GetParent()
    if HUI:FindFirstChild("NovaMenu") then
        pcall(function() HUI.NovaMenu:Destroy() end)
    end
    for _, c in ipairs(NovaLib._conns) do pcall(function() c:Disconnect() end) end
    table.clear(NovaLib._conns)
    if NovaLib._bindConn then pcall(function() NovaLib._bindConn:Disconnect() end) NovaLib._bindConn = nil end
    if NovaLib._bindEndConn then pcall(function() NovaLib._bindEndConn:Disconnect() end) NovaLib._bindEndConn = nil end
    if NovaLib._popConn then pcall(function() NovaLib._popConn:Disconnect() end) NovaLib._popConn = nil end
    NovaLib._capturing = false
    NovaLib._binds = {}

    local Gui = Create("ScreenGui", {
        Name = "NovaMenu",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, HUI)
    pcall(function()
        if typeof(protectgui) == "function" then protectgui(Gui) end
        if syn and syn.protect_gui then syn.protect_gui(Gui) end
    end)
    NovaLib._gui = Gui
    table.clear(NovaLib._tickers)
    table.insert(NovaLib._conns, RunService.Heartbeat:Connect(function(dt)
        for _, fn in ipairs(NovaLib._tickers) do
            pcall(fn, dt)
        end
    end))

    --// Main shell (CanvasGroup so open/close is one clean whole-menu fade)
    local Main = Create("CanvasGroup", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(740, 480),
        BackgroundColor3 = Config.Bg,
        BorderSizePixel = 0,
        Active = true,
        GroupTransparency = 1,
    }, Gui)
    Corner(Main, 0)
    Stroke(Main, Config.Stroke, 0.1, 1)

    --// Drawn X cursor (no asset needed): two bars, white with accent edge.
    -- Shown while the menu is open so FPS-locked games get a real pointer.
    local Cursor = Create("Frame", {
        Name = "Cursor",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(18, 18),
        BackgroundTransparency = 1,
        Visible = false,
        ZIndex = 500,
    }, Gui)
    for _, rot in ipairs({ 45, -45 }) do
        local bar = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Rotation = rot,
            ZIndex = 500,
        }, Cursor)
        Stroke(bar, Config.Accent, 0, 1)
    end

    --// Header (full-bleed, bottom border)
    local Header = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = Config.Panel,
        BorderSizePixel = 0,
    }, Main)
    Corner(Header, 0)
    Create("Frame", { -- bottom divider
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Config.Stroke,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, Header)

    -- logo + shader
    local Logo = Create("TextLabel", {
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.fromOffset(110, 42),
        BackgroundTransparency = 1,
        Text = logoText,
        FontFace = UB(Enum.FontWeight.ExtraBold),
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Color3.new(1, 1, 1),
    }, Header)
    local Grad = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Config.Accent),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Config.Accent),
        }),
        Rotation = 15,
    }, Logo)
    do
        local t = 0
        onTick(function(dt)
            t += dt
            Grad.Offset = Vector2.new(((t * 0.55) % 1.6) - 0.3, 0)
        end)
    end

    -- top tabs live here
    local TopTabs = Create("Frame", {
        Position = UDim2.fromOffset(130, 0),
        Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
    }, Header)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 2),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, TopTabs)

    -- (right side of header intentionally empty)

    local CloseBtn = Create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.fromOffset(20, 20),
        BackgroundTransparency = 1,
        Text = "×",
        FontFace = UB(Enum.FontWeight.Bold),
        TextSize = 15,
        TextColor3 = Config.Dim,
        AutoButtonColor = false,
    }, Header)
    CloseBtn.MouseEnter:Connect(function() CloseBtn.TextColor3 = Color3.fromRGB(220, 70, 80) end)
    CloseBtn.MouseLeave:Connect(function() CloseBtn.TextColor3 = Config.Dim end)

    --// Body (per-tab containers)
    local Body = Create("Frame", {
        Position = UDim2.new(0, 0, 0, 42),
        Size = UDim2.new(1, 0, 1, -70),
        BackgroundTransparency = 1,
    }, Main)

    --// Footer
    local Footer = Create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Config.Panel,
        BorderSizePixel = 0,
    }, Main)
    Corner(Footer, 0)
    Create("Frame", { -- top divider
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Config.Stroke,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, Footer)
    local AddBtn = Create("TextButton", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(0, 80, 1, 0),
        BackgroundTransparency = 1,
        Text = "+ Add",
        FontFace = UB(Enum.FontWeight.Regular),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Dim,
        AutoButtonColor = false,
    }, Footer)
    AddBtn.MouseEnter:Connect(function() AddBtn.TextColor3 = Config.Accent end)
    AddBtn.MouseLeave:Connect(function() AddBtn.TextColor3 = Config.Dim end)
    -- build marker: proves which version is actually on screen
    Create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 120, 1, 0),
        BackgroundTransparency = 1,
        Text = "v" .. Config.Version,
        FontFace = UB(Enum.FontWeight.Regular),
        TextSize = 10,
        TextColor3 = Config.Dim,
    }, Footer)
    Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        Text = "?",
        FontFace = UB(Enum.FontWeight.Bold),
        TextSize = 12,
        TextColor3 = Config.Dim,
    }, Footer)

    --// Drag via header
    do
        local dragging, dragStart, startPos = false, nil, nil
        Header.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, dragStart, startPos = true, i.Position, Main.Position
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        table.insert(NovaLib._conns, UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - dragStart
                Tween(Main, { Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) }, 0.08, Enum.EasingStyle.Linear)
            end
        end))
    end

    --// Tab system (top bar)
    local Window = { _tabs = {}, _current = nil, _order = 0 }

    local function SwitchTop(tab)
        if Window._current == tab then return end
        Window._current = tab
        for _, t in ipairs(Window._tabs) do
            local active = (t == tab)
            pcall(function()
                t.Body.Visible = active
                t.Label.TextColor3 = active and Config.Accent or Config.Dim
                t.Underline.Visible = active
                t.Underline.BackgroundTransparency = active and 0 or 1
            end)
        end
    end

    -- tab travel: pile every tab at the logo, stream to slots (entrance)
    -- or back (exit). Distances are measured live from the layout so
    -- width/gap changes can't break the cascade. Buttons live in fixed
    -- holders (layout-proof) so Position can tween freely.
    local function measureShift(holder)
        local ok, dx = pcall(function()
            return holder.AbsolutePosition.X - Logo.AbsolutePosition.X
        end)
        if ok and typeof(dx) == "number" and dx > 0 then return dx end
        return 116 -- fallback: slot math (84 + 2 gap) + logo gap (130 - 14)
    end

    local function PlayTabEntrance()
        for i, t in ipairs(Window._tabs) do
            local tab, idx = t, i
            local shift = 116
            pcall(function()
                shift = measureShift(tab.Button.Parent)
                tab.Button.Position = UDim2.new(0, -shift, 0, 0)
                tab.Label.TextTransparency = 1
                tab.Underline.BackgroundTransparency = 1
            end)
            task.delay(Config.Stagger * (idx - 1), function()
                if not Main.Visible then return end
                pcall(function()
                    Tween(tab.Button, { Position = UDim2.new(0, 0, 0, 0) }, Config.Travel, Enum.EasingStyle.Quart)
                    Tween(tab.Label, { TextTransparency = 0 }, 0.25)
                    if Window._current == tab then
                        Tween(tab.Underline, { BackgroundTransparency = 0 }, 0.25)
                    end
                end)
            end)
        end
    end

    -- mirror of the entrance: last tab leaves first, everything streams
    -- back into the logo, then the caller hides the window.
    local function PlayTabExit()
        local n = #Window._tabs
        for i, t in ipairs(Window._tabs) do
            local tab, idx = t, i
            task.delay(Config.Stagger * 0.5 * (n - idx), function()
                pcall(function()
                    local shift = measureShift(tab.Button.Parent)
                    Tween(tab.Button, { Position = UDim2.new(0, -shift, 0, 0) }, Config.Travel * 0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
                    Tween(tab.Label, { TextTransparency = 1 }, 0.2)
                    Tween(tab.Underline, { BackgroundTransparency = 1 }, 0.2)
                end)
            end)
        end
    end

    function Window:Tab(name, icon)
        Window._order += 1
        -- icon param ignored: text-only tabs

        -- holder is layout-managed; the button slides inside it
        local holder = Create("Frame", {
            Size = UDim2.new(0, 84, 1, 0),
            BackgroundTransparency = 1,
            LayoutOrder = Window._order,
        }, TopTabs)
        local btn = Create("TextButton", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
        }, holder)
        local lbl = Create("TextLabel", {
            Size = UDim2.new(1, 0, 1, -3),
            BackgroundTransparency = 1,
            Text = string.upper(tostring(name)),
            FontFace = UB(Enum.FontWeight.Bold),
            TextSize = 11,
            TextColor3 = Config.Dim,
        }, btn)
        local ul = Create("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, 2),
            BackgroundColor3 = Config.Accent,
            BorderSizePixel = 0,
            Visible = false,
        }, btn)
        btn.MouseEnter:Connect(function()
            if Window._current == nil or lbl.TextColor3 ~= Config.Accent then
                lbl.TextColor3 = Config.Text
            end
        end)
        btn.MouseLeave:Connect(function()
            local isActive = false
            pcall(function() isActive = ul.Visible end)
            lbl.TextColor3 = isActive and Config.Accent or Config.Dim
        end)

        -- tab body: sub-nav (left) + page area
        local body = Create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Visible = false,
        }, Body)

        local subNav = Create("Frame", {
            Position = UDim2.fromOffset(10, 10),
            Size = UDim2.new(0, 118, 1, -20),
            BackgroundColor3 = Config.Panel,
            BorderSizePixel = 0,
        }, body)
        Corner(subNav, 0)
        PanelBorder(subNav)
        Pad(subNav, 8, 8, 8, 8)
        Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, subNav)

        local pageArea = Create("Frame", {
            Position = UDim2.new(0, 138, 0, 10),
            Size = UDim2.new(1, -148, 1, -20),
            BackgroundTransparency = 1,
        }, body)

        local tab = {
            Button = btn, Label = lbl, Underline = ul,
            Body = body, SubNav = subNav, PageArea = pageArea,
            _subs = {}, _current = nil, _order = 0,
        }

        local function SwitchSub(sub)
            if tab._current == sub then return end
            tab._current = sub
            for _, s in ipairs(tab._subs) do
                local active = (s == sub)
                pcall(function()
                    s.Page.Visible = active
                    s.Label.TextColor3 = active and Config.Text or Config.Dim
                    s.Bar.Visible = active
                end)
            end
        end

        -- Sub-tab (left entry + 3-column page)
        function tab:Sub(subName)
            tab._order += 1
            local sbtn = Create("TextButton", {
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = tab._order,
            }, subNav)
            local bar = Create("Frame", {
                Size = UDim2.new(0, 2, 1, 0),
                BackgroundColor3 = Config.Accent,
                BorderSizePixel = 0,
                Visible = false,
            }, sbtn)
            local slbl = Create("TextLabel", {
                Position = UDim2.new(0, 10, 0, 0),
                Size = UDim2.new(1, -10, 1, 0),
                BackgroundTransparency = 1,
                Text = tostring(subName),
                FontFace = UB(Enum.FontWeight.Regular),
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextColor3 = Config.Dim,
            }, sbtn)

            local page = Create("Frame", {
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Visible = false,
            }, pageArea)
            Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, page)

            local cols = {}
            for i = 1, 3 do
                local col = Create("ScrollingFrame", {
                    Size = UDim2.new(0.333, -4, 1, 0),
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ScrollBarThickness = 0,
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    LayoutOrder = i,
                }, page)
                Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, col)
                -- 1px gutter: a Border-mode stroke straddles the frame edge,
                -- and the scrolling column would clip its outer half off.
                -- The gutter keeps the full 1px visible like the sub-nav's.
                Pad(col, 1, 1, 1, 1)
                cols[i] = col
            end

            local sub = {
                Button = sbtn, Label = slbl, Bar = bar,
                Page = page, Cols = cols, _groups = 0,
            }
            sbtn.MouseButton1Click:Connect(function() SwitchSub(sub) end)
            sbtn.MouseEnter:Connect(function() slbl.TextColor3 = Config.Text end)
            sbtn.MouseLeave:Connect(function()
                local isActive = false
                pcall(function() isActive = bar.Visible end)
                slbl.TextColor3 = isActive and Config.Text or Config.Dim
            end)
            table.insert(tab._subs, sub)
            if #tab._subs == 1 then SwitchSub(sub) end

            -- Groupbox: round-robin across the 3 columns
            function sub:Group(title)
                sub._groups += 1
                local col = cols[((sub._groups - 1) % 3) + 1]
                local box, inner = createPanel(col, title, { Order = sub._groups })
                local group = {}
                BuildRows(group, inner)
                return group
            end

            return sub
        end

        btn.MouseButton1Click:Connect(function() SwitchTop(tab) end)
        table.insert(Window._tabs, tab)
        if #Window._tabs == 1 then SwitchTop(tab) end
        return tab
    end

    --// Open / close + keybind
    local uiOpen = true
    local savedBehavior, savedIcon = nil, nil
    local function touchOnly()
        return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    end
    local function captureMouse()
        -- remember the game state once, then hold Default + custom cursor
        if savedBehavior == nil then
            pcall(function() savedBehavior = UserInputService.MouseBehavior end)
        end
        if savedIcon == nil then
            pcall(function() savedIcon = UserInputService.MouseIconEnabled end)
        end
        pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
        pcall(function() UserInputService.MouseIconEnabled = false end)
        Cursor.Visible = not touchOnly()
    end
    local function releaseMouse()
        pcall(function()
            if savedBehavior ~= nil then UserInputService.MouseBehavior = savedBehavior end
        end)
        pcall(function()
            UserInputService.MouseIconEnabled = (savedIcon ~= false)
        end)
        Cursor.Visible = false
    end
    function NovaLib:ToggleUI()
        uiOpen = not uiOpen
        if uiOpen then
            Main.Visible = true
            captureMouse()
            Tween(Main, { GroupTransparency = 0 }, 0.22)
            PlayTabEntrance()
        else
            NovaLib._capturing = false
            pcall(function() Gui.BindPopup:Destroy() end)
            releaseMouse()
            PlayTabExit()
            Tween(Main, { GroupTransparency = 1 }, 0.22)
            -- hide only after the exit cascade has landed (abort if reopened)
            task.delay(Config.Stagger * 0.5 * math.max(0, #Window._tabs - 1) + Config.Travel * 0.6, function()
                if not uiOpen then Main.Visible = false end
            end)
        end
    end
    function NovaLib:Unload()
        NovaLib._capturing = false
        if NovaLib._popConn then pcall(function() NovaLib._popConn:Disconnect() end) NovaLib._popConn = nil end
        for _, c in ipairs(NovaLib._conns) do pcall(function() c:Disconnect() end) end
        table.clear(NovaLib._conns)
        pcall(function() Gui:Destroy() end)
        NovaLib._gui = nil
    end
    function NovaLib:OnAdd(fn)
        AddBtn.MouseButton1Click:Connect(function() pcall(fn) end)
    end

    CloseBtn.MouseButton1Click:Connect(function() NovaLib:Unload() end)
    AddBtn.MouseButton1Click:Connect(function() print("[Nova] + Add pressed") end)
    table.insert(NovaLib._conns, UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and not NovaLib._capturing and input.KeyCode == toggleKey then NovaLib:ToggleUI() end
    end))

    -- FPS games re-lock the mouse constantly: hold our capture + cursor
    -- on the shared ticker while the menu is open.
    onTick(function()
        if not uiOpen or touchOnly() then return end
        pcall(function()
            if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end
            if UserInputService.MouseIconEnabled then
                UserInputService.MouseIconEnabled = false
            end
            local m = UserInputService:GetMouseLocation()
            local okIn, inset = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
            if okIn and inset then m = m - inset end
            Cursor.Position = UDim2.new(0, m.X, 0, m.Y)
        end)
    end)

    -- boot open: capture immediately, then fade + entrance for tabs
    -- created right after Window() returns (e.g. the demo)
    captureMouse()
    Tween(Main, { GroupTransparency = 0 }, 0.25)
    task.delay(0.3, function()
        if uiOpen and #Window._tabs > 0 then PlayTabEntrance() end
    end)

    return Window
end

--// Overlays: watermark + bind list (same styling as the menu) ------------

-- compact top-right watermark: logo | fps | ping
function NovaLib:Watermark(text)
    local root = self._gui
    if not root then warn("[Nova] call Window() before Watermark()") return nil end
    text = text or "menu.lua"
    if root:FindFirstChild("Watermark") then root.Watermark:Destroy() end

    local wm = Create("Frame", {
        Name = "Watermark",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.new(0, 0, 0, 26),
        BackgroundColor3 = Config.Panel,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.X,
    }, root)
    Corner(wm, 0)
    -- chunky standalone border (2px)
    Stroke(wm, Config.Stroke, 0, 2)
    Pad(wm, 12, 0, 12, 0)
    Create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }, wm)
    local logo = Create("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        FontFace = UB(Enum.FontWeight.Bold),
        TextSize = 12,
        TextColor3 = Color3.new(1, 1, 1),
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 1,
    }, wm)
    -- same shine sweep as the header logo: white text x accent gradient
    local wgrad = Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Config.Accent),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Config.Accent),
        }),
        Rotation = 15,
    }, logo)
    onTick(function()
        wgrad.Offset = Vector2.new(((tick() * 0.55) % 1.6) - 0.3, 0)
    end)
    Create("Frame", { -- dim divider between logo and stats
        Size = UDim2.new(0, 1, 0, 14),
        BackgroundColor3 = Config.Stroke,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        LayoutOrder = 2,
    }, wm)
    local stats = Create("TextLabel", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "-- fps  |  -- ms",
        FontFace = UB(Enum.FontWeight.Regular),
        TextSize = 11,
        TextColor3 = Config.Dim,
        AutomaticSize = Enum.AutomaticSize.X,
        LayoutOrder = 3,
    }, wm)

    local frames, last = 0, tick()
    onTick(function()
        frames += 1
        local now = tick()
        if now - last >= 0.5 then
            local fps = math.floor(frames / (now - last) + 0.5)
            frames, last = 0, now
            local ok, ping = pcall(function()
                return math.floor(LocalPlayer:GetNetworkPing() * 1000 + 0.5)
            end)
            pcall(function()
                stats.Text = fps .. " fps  |  " .. ((ok and ping) or 0) .. " ms"
            end)
        end
    end)
    return wm
end

-- keybind list entry: { Name, Key = Enum.KeyCode.X, Mode = "toggle"|"hold", Callback }
function NovaLib:Bind(o)
    local root = self._gui
    if not root then warn("[Nova] call Window() before Bind()") return nil end
    o = o or {}
    local entry = {
        Name = o.Name or "Bind",
        Key = o.Key or Enum.KeyCode.X,
        Mode = string.lower(o.Mode or "toggle"),
        State = o.Default or false,
        Callback = o.Callback,
    }
    if entry.Mode ~= "hold" then entry.Mode = "toggle" end

    local panel = root:FindFirstChild("Binds")
    if not panel then
        -- same panel as every groupbox: shared constructor, no custom chrome
        panel = createPanel(root, "BINDS", {
            Name = "Binds",
            Anchor = Vector2.new(0, 0.5),
            Pos = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(0, 180, 0, 30),
        })
        makeDraggable(panel, panel)
    end
    panel.Visible = true
    local list = panel:FindFirstChild("Rows") or panel

    local row = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
    }, list)
    entry.NameLbl = Create("TextLabel", {
        Size = UDim2.new(1, -52, 1, 0),
        BackgroundTransparency = 1,
        Text = entry.Name,
        FontFace = UB(Enum.FontWeight.Regular),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Dim,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    entry.KeyBox = Create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 46, 0, 18),
        BackgroundColor3 = Config.Control,
        BorderSizePixel = 0,
    }, row)
    Corner(entry.KeyBox, 4)
    Stroke(entry.KeyBox, Config.Stroke, 0.3, 1)
    entry.KeyLbl = Create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = keyName(entry.Key),
        FontFace = UB(Enum.FontWeight.Bold),
        TextSize = 10,
        TextColor3 = Config.Dim,
    }, entry.KeyBox)
    entry.Row = row

    if not NovaLib._bindConn then
        NovaLib._bindConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            for _, b in ipairs(NovaLib._binds) do
                if input.KeyCode == b.Key then
                    if b.Mode == "toggle" then
                        b.State = not b.State
                        renderBind(b)
                        if b.Callback then pcall(b.Callback, b.State) end
                    elseif not b.State then
                        b.State = true
                        renderBind(b)
                        if b.Callback then pcall(b.Callback, true) end
                    end
                end
            end
        end)
        NovaLib._bindEndConn = UserInputService.InputEnded:Connect(function(input)
            for _, b in ipairs(NovaLib._binds) do
                if b.Mode == "hold" and input.KeyCode == b.Key and b.State then
                    b.State = false
                    renderBind(b)
                    if b.Callback then pcall(b.Callback, false) end
                end
            end
        end)
    end

    table.insert(NovaLib._binds, entry)
    renderBind(entry)
    if entry.State and entry.Callback then pcall(entry.Callback, true) end
    return entry
end

function NovaLib:Unbind(entryOrName)
    for i, b in ipairs(NovaLib._binds) do
        if b == entryOrName or b.Name == entryOrName then
            pcall(function() b.Row:Destroy() end)
            table.remove(NovaLib._binds, i)
            break
        end
    end
    local root = self._gui
    if root and #NovaLib._binds == 0 then
        local panel = root:FindFirstChild("Binds")
        if panel then panel.Visible = false end
    end
end

-- right-click popup: bind a toggle function to a key (toggle or hold).
-- api = { Name, Get(), Set(v), Hint, bindEntry }
function NovaLib:BindPopup(api)
    local root = self._gui
    if not root or not api then return nil end
    if root:FindFirstChild("BindPopup") then root.BindPopup:Destroy() end
    if NovaLib._popConn then pcall(function() NovaLib._popConn:Disconnect() end) NovaLib._popConn = nil end

    local mode = (api.bindEntry and api.bindEntry.Mode) or "toggle"
    local boundKey = (api.bindEntry and api.bindEntry.Key) or nil
    NovaLib._capturing = (boundKey == nil) -- no key yet: listen immediately

    -- same panel as every groupbox: shared constructor
    local pop, list = createPanel(root, "BIND — " .. tostring(api.Name), {
        Name = "BindPopup",
        Size = UDim2.new(0, 190, 0, 0),
    })
    local popScale = Create("UIScale", { Scale = 0.94 }, pop)
    Tween(popScale, { Scale = 1 }, 0.16, Enum.EasingStyle.Back)
    local xBtn = Create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 8),
        Size = UDim2.fromOffset(16, 16),
        BackgroundTransparency = 1,
        Text = "×",
        FontFace = UB(Enum.FontWeight.Bold),
        TextSize = 14,
        TextColor3 = Config.Dim,
        AutoButtonColor = false,
        ZIndex = 2,
    }, pop)

    -- key row: groupbox-row pattern, dropdown value-box control
    local keyRow = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
    }, list)
    Create("TextLabel", {
        Size = UDim2.new(1, -96, 1, 0),
        BackgroundTransparency = 1,
        Text = "Key",
        FontFace = UB(Enum.FontWeight.Regular),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Text,
    }, keyRow)
    local keyBtn = Create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.new(0, 88, 0, 18),
        BackgroundColor3 = Config.Control,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
    }, keyRow)
    Corner(keyBtn, 4)
    Stroke(keyBtn, Config.Stroke, 0.3, 1)
    local keyLbl = Create("TextLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "—",
        FontFace = UB(Enum.FontWeight.Bold),
        TextSize = 11,
        TextColor3 = Config.Dim,
    }, keyBtn)

    -- mode row: label + two compact buttons sharing the value-box width
    local modeRow = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
    }, list)
    Create("TextLabel", {
        Size = UDim2.new(1, -96, 1, 0),
        BackgroundTransparency = 1,
        Text = "Mode",
        FontFace = UB(Enum.FontWeight.Regular),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Text,
    }, modeRow)
    local function modeBtn(label, xOff)
        local b = Create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, xOff, 0.5, 0),
            Size = UDim2.new(0, 45, 0, 18),
            BackgroundColor3 = Config.Control,
            Text = label,
            FontFace = UB(Enum.FontWeight.Bold),
            TextSize = 10,
            TextColor3 = Config.Dim,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AutoButtonColor = false,
            BorderSizePixel = 0,
        }, modeRow)
        Corner(b, 4)
        Stroke(b, Config.Stroke, 0.3, 1)
        return b
    end
    local holdBtn = modeBtn("hold", 0)
    local togBtn = modeBtn("toggle", -51)

    -- footer divider (window-footer rule) + unbind + hint
    Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Config.Stroke,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, list)
    local foot = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
    }, list)
    local unbindBtn = Create("TextButton", {
        Size = UDim2.new(0, 60, 1, 0),
        BackgroundTransparency = 1,
        Text = "unbind",
        FontFace = UB(Enum.FontWeight.Regular),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextColor3 = Config.Dim,
        AutoButtonColor = false,
    }, foot)
    Create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(1, -66, 1, 0),
        BackgroundTransparency = 1,
        Text = "press ESC to cancel",
        FontFace = UB(Enum.FontWeight.Regular),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextColor3 = Config.Dim,
    }, foot)

    local function paintModes()
        togBtn.BackgroundColor3 = (mode == "toggle") and Config.Accent or Config.Control
        togBtn.TextColor3 = (mode == "toggle") and Color3.new(1, 1, 1) or Config.Dim
        holdBtn.BackgroundColor3 = (mode == "hold") and Config.Accent or Config.Control
        holdBtn.TextColor3 = (mode == "hold") and Color3.new(1, 1, 1) or Config.Dim
    end
    local function refresh()
        keyLbl.Text = NovaLib._capturing and "..." or (boundKey and keyName(boundKey) or "—")
        keyLbl.TextColor3 = NovaLib._capturing and Config.Accent or Config.Dim
        paintModes()
    end
    local function applyBind()
        if api.bindEntry then NovaLib:Unbind(api.bindEntry) api.bindEntry = nil end
        if boundKey then
            api.bindEntry = NovaLib:Bind({
                Name = api.Name, Key = boundKey, Mode = mode,
                Default = false, Callback = function(s) api.Set(s) end,
            })
            -- align entry with the toggle's live state (no refire)
            api.bindEntry.State = api.Get()
            if NovaLib._renderBind then NovaLib._renderBind(api.bindEntry) end
            api.Hint.Text = "[" .. keyName(boundKey) .. "]"
            api.Hint.Visible = true
        else
            api.Hint.Text = ""
            api.Hint.Visible = false
        end
        refresh()
    end
    local function close()
        NovaLib._capturing = false
        if NovaLib._popConn then pcall(function() NovaLib._popConn:Disconnect() end) NovaLib._popConn = nil end
        pcall(function() pop:Destroy() end)
    end

    keyBtn.MouseButton1Click:Connect(function()
        NovaLib._capturing = true
        refresh()
    end)
    togBtn.MouseButton1Click:Connect(function()
        mode = "toggle"
        if api.bindEntry then api.bindEntry.Mode = mode end
        refresh()
    end)
    holdBtn.MouseButton1Click:Connect(function()
        mode = "hold"
        if api.bindEntry then api.bindEntry.Mode = mode end
        refresh()
    end)
    unbindBtn.MouseEnter:Connect(function() unbindBtn.TextColor3 = Color3.fromRGB(220, 70, 80) end)
    unbindBtn.MouseLeave:Connect(function() unbindBtn.TextColor3 = Config.Dim end)
    unbindBtn.MouseButton1Click:Connect(function()
        boundKey = nil
        applyBind()
    end)
    xBtn.MouseButton1Click:Connect(close)

    NovaLib._popConn = UserInputService.InputBegan:Connect(function(input, gpe)
        if input.KeyCode == Enum.KeyCode.Escape then
            if NovaLib._capturing then NovaLib._capturing = false refresh() else close() end
            return
        end
        -- left-click outside the popup dismisses it (uses the inset-corrected
        -- mouse pos, same space as the clamped placement below)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and not NovaLib._capturing then
            local okIn, insetNow = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
            local mp = UserInputService:GetMouseLocation() - (okIn and insetNow or Vector2.new(0, 0))
            local pp, ps = pop.AbsolutePosition, pop.AbsoluteSize
            if mp.X < pp.X or mp.Y < pp.Y or mp.X > pp.X + ps.X or mp.Y > pp.Y + ps.Y then
                close()
            end
            return
        end
        if not NovaLib._capturing then return end
        if input.KeyCode == Enum.KeyCode.Unknown then return end
        boundKey = input.KeyCode
        NovaLib._capturing = false
        applyBind()
    end)

    -- place at cursor, clamped on screen
    local vs = Vector2.new(800, 600)
    pcall(function() vs = workspace.CurrentCamera.ViewportSize end)
    local inset = Vector2.new(0, 0)
    pcall(function() inset = game:GetService("GuiService"):GetGuiInset() end)
    local m = UserInputService:GetMouseLocation() - inset
    pop.Position = UDim2.new(0, math.clamp(m.X + 8, 4, math.max(4, vs.X - 220)),
        0, math.clamp(m.Y + 8, 4, math.max(4, vs.Y - 170)))

    refresh()
    return pop
end

-- public build stamp for host scripts
NovaLib.Version = Config.Version

-- shared for executor workflows (run lib once, consume from any script)
_G.NovaLib = NovaLib
return NovaLib
