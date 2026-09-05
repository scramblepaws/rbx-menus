--[[ ============================================================
    SeriousHook - Roblox Luau Menu Library
    A single-file Drawing-API menu library with watermark,
    toasts, themes, keybinds list, FPS/ping, and config I/O.

    Returns the Library table when called as: local Lib = (loadstring(...)())()
    ============================================================ ]]

-- // Services
local ws      = game:GetService("Workspace")
local uis     = game:GetService("UserInputService")
local rs      = game:GetService("RunService")
local hs      = game:GetService("HttpService")
local plrs    = game:GetService("Players")
local stats   = game:GetService("Stats")

-- // Library state
local Library = {
    drawings    = {},
    hidden      = {},
    connections = {},
    pointers    = {},
    folders     = {
        main    = "serioushook",
        assets  = "serioushook/assets",
        configs = "serioushook/configs",
    },
    shared = {
        initialized = false,
        fps   = 0,
        ping  = 0,
        tick  = 0,
    },

    -- // subsystem state / method tables (defined on Library so module-scope
    -- // methods like `function Library.watermark:UpdateSize()` resolve)
    watermark = {
        text      = nil,
        frame      = nil,
        enabled    = true,
        updateConn = nil,
    },
    toasts = {
        list       = {},
        active     = {},
        connector    = nil,
        nextId     = 1,
    },
    keybindslist = {
        entries    = {},
        frame      = nil,
        open       = false,
        updateConn = nil,
    },
    stats = {
        enabled   = true,
        fpsText   = nil,
        pingText  = nil,
    },
}

-- // Theme (defaults)
local Theme = {
    accent         = Color3.fromRGB(50, 100, 255),
    light_contrast = Color3.fromRGB(30, 30, 30),
    dark_contrast  = Color3.fromRGB(20, 20, 20),
    outline        = Color3.fromRGB(0, 0, 0),
    inline         = Color3.fromRGB(50, 50, 50),
    textcolor      = Color3.fromRGB(255, 255, 255),
    textborder     = Color3.fromRGB(0, 0, 0),
    font           = 2,
    textsize       = 13,
}

-- // Utility table
local Utility = {}

--[[ ----------------------------------------------------------------
    utility:Size  (scale-based size relative to parent or viewport)
    ---------------------------------------------------------------- ]]
function Utility:Size(xScale, xOffset, yScale, yOffset, instance)
    local vx, vy
    if instance then
        vx, vy = instance.Size.x, instance.Size.y
    else
        vx, vy = ws.CurrentCamera.ViewportSize.x, ws.CurrentCamera.ViewportSize.y
    end
    return Vector2.new(xScale * vx + xOffset, yScale * vy + yOffset)
end

--[[ ----------------------------------------------------------------
    utility:Position  (scale-based position relative to parent or viewport)
    ---------------------------------------------------------------- ]]
function Utility:Position(xScale, xOffset, yScale, yOffset, instance)
    local px, py
    if instance then
        px, py = instance.Position.x, instance.Position.y
    else
        px, py = 0, 0
    end
    local vx, vy
    if instance then
        vx, vy = instance.Size.x, instance.Size.y
    else
        vx, vy = ws.CurrentCamera.ViewportSize.x, ws.CurrentCamera.ViewportSize.y
    end
    return Vector2.new(px + xScale * vx + xOffset, py + yScale * vy + yOffset)
end

--[[ ----------------------------------------------------------------
    utility:Create  (normalised Drawing primitive factory)
    ---------------------------------------------------------------- ]]
function Utility:Create(instanceType, instanceOffset, instanceProperties, instanceParent)
    instanceType     = instanceType     or "Frame"
    instanceOffset   = instanceOffset   or {Vector2.new(0, 0)}
    instanceProperties = instanceProperties or {}
    local instanceHidden = false
    local instance = nil

    local function make()
        if instanceType == "Frame" or instanceType == "frame" then
            local frame = Drawing.new("Square")
            frame.Visible = true
            frame.Filled  = true
            frame.Thickness = 0
            frame.Color   = Color3.fromRGB(255, 255, 255)
            frame.Size    = Vector2.new(100, 100)
            frame.Position = Vector2.new(0, 0)
            frame.ZIndex  = 50
            frame.Transparency = Library.shared.initialized and 1 or 0
            return frame
        elseif instanceType == "TextLabel" or instanceType == "textlabel" then
            local text = Drawing.new("Text")
            text.Font      = Theme.font
            text.Visible   = true
            text.Outline   = true
            text.Center    = false
            text.Color     = Color3.fromRGB(255, 255, 255)
            text.ZIndex    = 50
            text.Transparency = Library.shared.initialized and 1 or 0
            return text
        elseif instanceType == "Triangle" or instanceType == "triangle" then
            local tri = Drawing.new("Triangle")
            tri.Visible   = true
            tri.Filled    = false
            tri.Thickness = 2
            tri.Color     = Color3.fromRGB(255, 255, 255)
            tri.ZIndex    = 50
            tri.Transparency = Library.shared.initialized and 1 or 0
            return tri
        elseif instanceType == "Image" or instanceType == "image" then
            local img = Drawing.new("Image")
            img.Size      = Vector2.new(12, 19)
            img.Position  = Vector2.new(0, 0)
            img.Visible   = true
            img.ZIndex    = 50
            img.Transparency = Library.shared.initialized and 1 or 0
            return img
        elseif instanceType == "Circle" or instanceType == "circle" then
            local cir = Drawing.new("Circle")
            cir.Visible     = false
            cir.Color       = Color3.fromRGB(255, 0, 0)
            cir.Thickness   = 1
            cir.NumSides    = 30
            cir.Filled      = true
            cir.Transparency = 1
            cir.ZIndex      = 50
            cir.Radius      = 50
            return cir
        elseif instanceType == "Quad" or instanceType == "quad" then
            local quad = Drawing.new("Quad")
            quad.Visible     = false
            quad.Color       = Color3.fromRGB(255, 255, 255)
            quad.Thickness   = 1.5
            quad.Transparency = 1
            quad.ZIndex      = 50
            quad.Filled      = false
            return quad
        elseif instanceType == "Line" or instanceType == "line" then
            local line = Drawing.new("Line")
            line.Visible     = false
            line.Color       = Color3.fromRGB(255, 255, 255)
            line.Thickness   = 1.5
            line.Transparency = 1
            line.ZIndex      = 50
            return line
        end
        return nil
    end

    instance = make()
    if not instance then return nil end

    for k, v in pairs(instanceProperties) do
        if k == "Hidden" or k == "hidden" then
            instanceHidden = true
        else
            if Library.shared.initialized then
                instance[k] = v
            else
                if k ~= "Transparency" then
                    instance[k] = v
                end
            end
        end
    end

    if not instanceHidden then
        Library.drawings[#Library.drawings + 1] = {
            instance,
            instanceOffset,
            instanceProperties["Transparency"] or 1,
        }
    else
        Library.hidden[#Library.hidden + 1] = {instance}
    end

    if instanceParent then
        instanceParent[#instanceParent + 1] = instance
    end
    return instance
end

--[[ ----------------------------------------------------------------
    utility:UpdateOffset
    ---------------------------------------------------------------- ]]
function Utility:UpdateOffset(instance, instanceOffset)
    for _, v in pairs(Library.drawings) do
        if v[1] == instance then
            v[2] = instanceOffset
        end
    end
end

--[[ ----------------------------------------------------------------
    utility:UpdateTransparency
    ---------------------------------------------------------------- ]]
function Utility:UpdateTransparency(instance, instanceTransparency)
    for _, v in pairs(Library.drawings) do
        if v[1] == instance then
            v[3] = instanceTransparency
        end
    end
end

--[[ ----------------------------------------------------------------
    utility:Remove  (unregister + :Remove())
    ---------------------------------------------------------------- ]]
function Utility:Remove(instance, hidden)
    local ind = 0
    local tbl = hidden and Library.hidden or Library.drawings
    for i, v in pairs(tbl) do
        if v[1] == instance then
            ind = i
            if hidden then
                v[1] = nil
            else
                v[2] = nil
                v[1] = nil
            end
        end
    end
    table.remove(tbl, ind)
    instance:Remove()
end

--[[ ----------------------------------------------------------------
    utility:GetSubPrefix  ("1st", "2nd", "3rd", "th")
    ---------------------------------------------------------------- ]]
function Utility:GetSubPrefix(str)
    local s = tostring(str):gsub(" ", "")
    if #s == 2 then
        local sec = string.sub(s, #s, #s + 1)
        if sec == "1" then return "st"
        elseif sec == "2" then return "nd"
        elseif sec == "3" then return "rd"
        else return "th" end
    end
    return "th"
end

--[[ ----------------------------------------------------------------
    utility:Connection  (track + return)
    ---------------------------------------------------------------- ]]
function Utility:Connection(connectionType, connectionCallback)
    local connection = connectionType:Connect(connectionCallback)
    Library.connections[#Library.connections + 1] = connection
    return connection
end

--[[ ----------------------------------------------------------------
    utility:Disconnect
    ---------------------------------------------------------------- ]]
function Utility:Disconnect(connection)
    for i, v in pairs(Library.connections) do
        if v == connection then
            Library.connections[i] = nil
            v:Disconnect()
        end
    end
end

--[[ ----------------------------------------------------------------
    utility:MouseLocation
    ---------------------------------------------------------------- ]]
function Utility:MouseLocation()
    return uis:GetMouseLocation()
end

--[[ ----------------------------------------------------------------
    utility:MouseOverDrawing  (rect overlap hit-test)
    ---------------------------------------------------------------- ]]
function Utility:MouseOverDrawing(values, valuesAdd)
    valuesAdd = valuesAdd or {}
    local v = {
        (values[1] or 0) + (valuesAdd[1] or 0),
        (values[2] or 0) + (valuesAdd[2] or 0),
        (values[3] or 0) + (valuesAdd[3] or 0),
        (values[4] or 0) + (valuesAdd[4] or 0),
    }
    local ml = Utility:MouseLocation()
    return (ml.x >= v[1] and ml.x <= (v[1] + (v[3] - v[1]))) and
           (ml.y >= v[2] and ml.y <= (v[2] + (v[4] - v[2])))
end

--[[ ----------------------------------------------------------------
    utility:GetTextBounds  (hidden text label measurement)
    ---------------------------------------------------------------- ]]
function Utility:GetTextBounds(text, textSize, font)
    local textlabel = Utility:Create("TextLabel", {Vector2.new(0, 0)}, {
        Text   = text,
        Size   = textSize,
        Font   = font,
        Hidden = true,
    })
    local tb = textlabel.TextBounds
    Utility:Remove(textlabel, true)
    return tb
end

--[[ ----------------------------------------------------------------
    utility:GetScreenSize
    ---------------------------------------------------------------- ]]
function Utility:GetScreenSize()
    return ws.CurrentCamera.ViewportSize
end

--[[ ----------------------------------------------------------------
    utility:LoadImage  (cache asset to disk, set instance.Data)
    ---------------------------------------------------------------- ]]
function Utility:LoadImage(instance, imageName, imageLink)
    local data
    if isfile(Library.folders.assets .. "/" .. imageName .. ".png") then
        data = readfile(Library.folders.assets .. "/" .. imageName .. ".png")
    else
        if imageLink then
            data = game:HttpGet(imageLink)
            writefile(Library.folders.assets .. "/" .. imageName .. ".png", data)
        else
            return
        end
    end
    if data and instance then
        instance.Data = data
    end
end

--[[ ----------------------------------------------------------------
    utility:Lerp  (animate a table of properties over time)
    ---------------------------------------------------------------- ]]
function Utility:Lerp(instance, instanceTo, instanceTime)
    local currentTime = 0
    local currentIndex = {}
    for i, v in pairs(instanceTo) do
        currentIndex[i] = instance[i]
    end
    local connection
    local function lerp()
        for i, v in pairs(instanceTo) do
            instance[i] = ((v - currentIndex[i]) * currentTime / instanceTime) + currentIndex[i]
        end
    end
    connection = rs.RenderStepped:Connect(function(delta)
        if currentTime < instanceTime then
            currentTime = currentTime + delta
            lerp()
        else
            connection:Disconnect()
        end
    end)
end

--[[ ----------------------------------------------------------------
    utility:Combine  (concat two tables)
    ---------------------------------------------------------------- ]]
function Utility:Combine(table1, table2)
    local t3 = {}
    for i, v in pairs(table1) do t3[i] = v end
    local t = #t3
    for z, x in pairs(table2) do t3[z + t] = x end
    return t3
end

--[[ ============================================================
    Library class definitions
    ============================================================ ]]
Library.__index    = Library
local Pages    = {}
Pages.__index  = Pages
local Sections = {}
Sections.__index = Sections

-- // Folders
if not isfolder(Library.folders.main) then
    makefolder(Library.folders.main)
end
if not isfolder(Library.folders.assets) then
    makefolder(Library.folders.assets)
end
if not isfolder(Library.folders.configs) then
    makefolder(Library.folders.configs)
end

--[[ ----------------------------------------------------------------
    Library:New  → Window object
    ---------------------------------------------------------------- ]]
function Library:New(info)
    local info = info or {}
    local name   = info.name or info.Name or info.title or info.Title or "UI Title"
    local size   = info.size or info.Size or Vector2.new(504, 604)
    local accent = info.accent or info.Accent or info.color or info.Color or Theme.accent

    Theme.accent = accent

    local Window = {
        pages          = {},
        isVisible      = false,
        uibind         = Enum.KeyCode.Z,
        currentPage    = nil,
        fading         = false,
        dragging       = false,
        drag           = Vector2.new(0, 0),
        currentContent = {
            frame      = nil,
            dropdown   = nil,
            multibox   = nil,
            colorpicker = nil,
            keybind    = nil,
        },

        -- watermark / toasts / keybindslist / stats are method tables defined on
        -- Library at module scope; alias them so Window instances inherit them.
        watermark    = Library.watermark,
        toasts       = Library.toasts,
        keybindslist = Library.keybindslist,
        stats        = Library.stats,

        -- internal
        main_frame = nil,
        title      = nil,
        inner_frame_inline = nil,
        back_frame = nil,
        tab_frame  = nil,
        pageTabs   = {},
        pageTabContents = {},
        tabActive  = nil,
        tabTextLabels = {},
        tabInlineFrames = {},
    }

    setmetatable(Window, Library)

    -- [[ Build main frame ]]
    local main_frame = Utility:Create("Frame", {Vector2.new(0, 0)}, {
        Size      = Utility:Size(0, size.X, 0, size.Y),
        Position  = Utility:Position(0.5, -(size.X / 2), 0.5, -(size.Y / 2)),
        Color     = Theme.outline,
    })
    Window.main_frame = main_frame

    local frame_inline = Utility:Create("Frame", {Vector2.new(1, 1), main_frame}, {
        Size      = Utility:Size(1, -2, 1, -2, main_frame),
        Position  = Utility:Position(0, 1, 0, 1, main_frame),
        Color     = Theme.accent,
    })

    local inner_frame = Utility:Create("Frame", {Vector2.new(1, 1), frame_inline}, {
        Size      = Utility:Size(1, -2, 1, -2, frame_inline),
        Position  = Utility:Position(0, 1, 0, 1, frame_inline),
        Color     = Theme.light_contrast,
    })

    local title = Utility:Create("TextLabel", {Vector2.new(4, 2), inner_frame}, {
        Text           = name,
        Size           = Theme.textsize,
        Font           = Theme.font,
        Color          = Theme.textcolor,
        OutlineColor   = Theme.textborder,
        Position       = Utility:Position(0, 4, 0, 2, inner_frame),
    })
    Window.title = title

    local inner_frame_inline = Utility:Create("Frame", {Vector2.new(4, 18), inner_frame}, {
        Size      = Utility:Size(1, -8, 1, -22, inner_frame),
        Position  = Utility:Position(0, 4, 0, 18, inner_frame),
        Color     = Theme.inline,
    })
    Window.inner_frame_inline = inner_frame_inline

    local inner_frame_inline2 = Utility:Create("Frame", {Vector2.new(1, 1), inner_frame_inline}, {
        Size      = Utility:Size(1, -2, 1, -2, inner_frame_inline),
        Position  = Utility:Position(0, 1, 0, 1, inner_frame_inline),
        Color     = Theme.outline,
    })

    local back_frame = Utility:Create("Frame", {Vector2.new(1, 1), inner_frame_inline2}, {
        Size      = Utility:Size(1, -2, 1, -2, inner_frame_inline2),
        Position  = Utility:Position(0, 1, 0, 1, inner_frame_inline2),
        Color     = Theme.dark_contrast,
    })
    Window.back_frame = back_frame

    local tab_frame_inline = Utility:Create("Frame", {Vector2.new(4, 24), back_frame}, {
        Size      = Utility:Size(1, -8, 1, -28, back_frame),
        Position  = Utility:Position(0, 4, 0, 24, back_frame),
        Color     = Theme.outline,
    })

    local tab_frame_inline2 = Utility:Create("Frame", {Vector2.new(1, 1), tab_frame_inline}, {
        Size      = Utility:Size(1, -2, 1, -2, tab_frame_inline),
        Position  = Utility:Position(0, 1, 0, 1, tab_frame_inline),
        Color     = Theme.inline,
    })

    local tab_frame = Utility:Create("Frame", {Vector2.new(1, 1), tab_frame_inline2}, {
        Size      = Utility:Size(1, -2, 1, -2, tab_frame_inline2),
        Position  = Utility:Position(0, 1, 0, 1, tab_frame_inline2),
        Color     = Theme.light_contrast,
    })
    Window.tab_frame = tab_frame

    -- [[ Build watermark ]]
    Window.watermark.frame = Utility:Create("Frame", {Vector2.new(0, 0)}, {
        Size      = Vector2.new(0, 0),
        Position  = Vector2.new(0, 0),
        Color     = Color3.fromRGB(0, 0, 0),
        Transparency = 0.7,
        Filled    = true,
        Hidden    = true,
    })
    Window.watermark.text = Utility:Create("TextLabel", {Vector2.new(0, 0), Window.watermark.frame}, {
        Text         = "",
        Size         = 12,
        Font         = 2,
        Color        = Color3.fromRGB(255, 255, 255),
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Outline      = true,
        Hidden       = true,
    })

    -- [[ Build stat texts (FPS / ping) — shown beside watermark ]]
    Window.stats.fpsText = Utility:Create("TextLabel", {Vector2.new(0, 0)}, {
        Text         = "FPS: 0",
        Size         = 12,
        Font         = 2,
        Color        = Color3.fromRGB(255, 255, 255),
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Outline      = true,
        Hidden       = true,
        Position     = Vector2.new(0, 0),
    })
    Window.stats.pingText = Utility:Create("TextLabel", {Vector2.new(0, 0)}, {
        Text         = "Ping: 0ms",
        Size         = 12,
        Font         = 2,
        Color        = Color3.fromRGB(255, 255, 255),
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Outline      = true,
        Hidden       = true,
        Position     = Vector2.new(0, 0),
    })

    -- [[ global render loop ]]
    Utility:Connection(rs.RenderStepped, function(delta)
        if not Library.shared.initialized then return end
        Library.shared.tick = Library.shared.tick + delta
        if Library.shared.tick >= 0.5 then
            Library.shared.tick = 0
            local st = stats:GetData()
            Library.shared.fps = st.FPS
            Library.shared.ping = st.AveragePing
        end
        Window:UpdateWatermark()
        Window:UpdateStatsPosition()
        Window:UpdateToasts(delta)
    end)

    -- [[ toggle key ]]
    Utility:Connection(uis.InputBegan, function(input, gp)
        if gp then return end
        if input.KeyCode == Window.uibind then
            Window:ToggleVisibility()
        end
    end)

    -- [[ drag handling on title bar area ]]
    local dragStart = nil
    local dragOffset = nil
    Utility:Connection(uis.InputBegan, function(input, gp)
        if gp then return end
        if Window.isVisible and not Window.fading then
            local ml = Utility:MouseLocation()
            if Utility:MouseOverDrawing({
                Window.main_frame.Position.x,
                Window.main_frame.Position.y,
                Window.main_frame.Position.x + Window.main_frame.Size.x,
                Window.main_frame.Position.y + 26,
            }) then
                Window.dragging = true
                dragStart = ml
                dragOffset = Vector2.new(
                    ml.x - Window.main_frame.Position.x,
                    ml.y - Window.main_frame.Position.y
                )
            end
        end
    end)
    Utility:Connection(uis.InputChanged, function(input)
        if Window.dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local ml = Utility:MouseLocation()
            local newPos = Vector2.new(
                ml.x - dragOffset.x,
                ml.y - dragOffset.y
            )
            -- clamp to screen
            local screen = Utility:GetScreenSize()
            newPos = Vector2.new(
                math.max(0, math.min(screen.x - Window.main_frame.Size.x, newPos.x)),
                math.max(0, math.min(screen.y - Window.main_frame.Size.y, newPos.y))
            )
            Window.drag = newPos
            Window:Move(newPos)
        end
    end)
    Utility:Connection(uis.InputEnded, function(input)
        Window.dragging = false
    end)

    -- // initial hidden state (fade in on init)
    for _, v in pairs(Library.drawings) do
        v[1].Transparency = 1
    end

    return Window
end

--[[ ----------------------------------------------------------------
    Window:Initialize
    ---------------------------------------------------------------- ]]
function Library:Initialize()
    Library.shared.initialized = true
    self.isVisible = true
    -- fade in all drawings
    for _, v in pairs(Library.drawings) do
        if v[1] and v[1].Transparency ~= nil then
            Utility:Lerp(v[1], {Transparency = v[3]}, 0.35)
        end
    end
    self.watermark:Visibility()
    self.stats:Visibility()
    if self.keybindslist.updateConn == nil then
        self.keybindslist.updateConn = Utility:Connection(rs.RenderStepped, function()
            self.keybindslist:Update()
        end)
    end
end

--[[ ----------------------------------------------------------------
    Window:ToggleVisibility
    ---------------------------------------------------------------- ]]
function Library:ToggleVisibility()
    self.isVisible = not self.isVisible
    if self.isVisible then
        self:FadeIn()
    else
        self:FadeOut()
    end
end

--[[ ----------------------------------------------------------------
    Window:FadeIn / FadeOut
    ---------------------------------------------------------------- ]]
function Library:FadeIn()
    if self.fading then return end
    self.fading = true
    for _, v in pairs(Library.drawings) do
        if v[1] and v[1].Transparency ~= nil then
            Utility:Lerp(v[1], {Transparency = v[3]}, 0.25)
        end
    end
    task.delay(0.25, function()
        self.fading = false
    end)
    self.watermark:Visibility()
    self.stats:Visibility()
    if self.keybindslist.open then
        self.keybindslist:Visibility()
    end
end

function Library:FadeOut()
    if self.fading then return end
    self.fading = true
    for _, v in pairs(Library.drawings) do
        if v[1] and v[1].Transparency ~= nil then
            Utility:Lerp(v[1], {Transparency = 1}, 0.25)
        end
    end
    task.delay(0.25, function()
        self.fading = false
    end)
    self.watermark:Hide()
    self.stats:Hide()
    self.keybindslist:Hide()
end

--[[ ----------------------------------------------------------------
    Window:Move  (set all drawing positions to new anchor)
    ---------------------------------------------------------------- ]]
function Library:Move(vector)
    for _, v in pairs(Library.drawings) do
        if v[2] and v[2][2] then
            v[1].Position = Utility:Position(0, v[2][1].X, 0, v[2][1].Y, v[2][2])
        else
            v[1].Position = Utility:Position(0, vector.X, 0, vector.Y)
        end
    end
end

--[[ ----------------------------------------------------------------
    Window:CloseContent  (drop closed dropdown/multibox)
    ---------------------------------------------------------------- ]]
function Library:CloseContent()
    if self.currentContent.dropdown and self.currentContent.dropdown.open then
        local dd = self.currentContent.dropdown
        dd.open = not dd.open
        Utility:LoadImage(dd.dropdown_image, "arrow_down", "https://i.imgur.com/tVqy0nL.png")
        for _, v in pairs(dd.holder.drawings) do
            Utility:Remove(v)
        end
        dd.holder.drawings = {}
        dd.holder.buttons = {}
        dd.holder.inline = nil
        self.currentContent.frame = nil
        self.currentContent.dropdown = nil
    elseif self.currentContent.multibox and self.currentContent.multibox.open then
        local mb = self.currentContent.multibox
        mb.open = not mb.open
        Utility:LoadImage(mb.multibox_image, "arrow_down", "https://i.imgur.com/tVqy0nL.png")
        for _, v in pairs(mb.holder.drawings) do
            Utility:Remove(v)
        end
        mb.holder.drawings = {}
        mb.holder.buttons = {}
        mb.holder.inline = nil
        self.currentContent.frame = nil
        self.currentContent.multibox = nil
    elseif self.currentContent.colorpicker and self.currentContent.colorpicker.open then
        local cp = self.currentContent.colorpicker
        cp.open = not cp.open
        Utility:LoadImage(cp.picker_image, "arrow_down", "https://i.imgur.com/tVqy0nL.png")
        for _, v in pairs(cp.holder.drawings) do
            Utility:Remove(v)
        end
        cp.holder.drawings = {}
        cp.holder.buttons = {}
        cp.holder.inline = nil
        self.currentContent.frame = nil
        self.currentContent.colorpicker = nil
    end
end

--[[ ----------------------------------------------------------------
    Window:GetConfig / LoadConfig
    ---------------------------------------------------------------- ]]
function Library:GetConfig()
    local config = {}
    for i, v in pairs(Library.pointers) do
        if typeof(v:Get()) == "table" and v:Get().Transparency then
            local h, s, val = v:Get().Color:ToHSV()
            config[i] = {Color = {h, s, val}, Transparency = v:Get().Transparency}
        else
            config[i] = v:Get()
        end
    end
    return hs:JSONEncode(config)
end

function Library:LoadConfig(configStr)
    local config = hs:JSONDecode(configStr)
    for i, v in pairs(config) do
        if Library.pointers[i] then
            Library.pointers[i]:Set(v)
        end
    end
end

--[[ ----------------------------------------------------------------
    Window:Unload  (full teardown)
    ---------------------------------------------------------------- ]]
function Library:Unload()
    -- disconnect all
    for _, c in pairs(Library.connections) do
        pcall(function() c:Disconnect() end)
    end
    Library.connections = {}

    -- remove all drawings
    for _, v in pairs(Library.drawings) do
        if v[1] then pcall(function() v[1]:Remove() end) end
    end
    for _, v in pairs(Library.hidden) do
        if v[1] then pcall(function() v[1]:Remove() end) end
    end
    Library.drawings = {}
    Library.hidden   = {}
    Library.pointers = {}

    -- reset shared
    Library.shared.initialized = false

    -- clear window children
    for _, p in pairs(self.pages) do
        p._sections = {}
    end
    self.pages = {}
    self.pageTabs = {}
    self.pageTabContents = {}
    self.tabTextLabels = {}
    self.tabInlineFrames = {}
end

--[[ ============================================================
    Page
    ============================================================ ]]
function Pages:Page(info)
    local info = info or {}
    local name = info.name or info.Name or "Page"
    local page = {
        name    = name,
        sections = {},
        side    = info.Side or "Left",
        window  = nil, -- backref
    }
    setmetatable(page, Pages)
    return page
end

--[[ ----------------------------------------------------------------
    Window:Page  (register page + tab)
    ---------------------------------------------------------------- ]]
function Library:Page(info)
    local page = Pages:Page(info)
    page.window = self
    self.pages[#self.pages + 1] = page

    -- build tab
    local tabIndex = #self.pages
    local tabText = Utility:Create("TextLabel", {Vector2.new(0, 0), self.tab_frame}, {
        Text         = page.name,
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 8, 0, 6 + (tabIndex - 1) * 20, self.tab_frame),
    })
    self.tabTextLabels[#self.tabTextLabels + 1] = tabText

    local tabInline = Utility:Create("Frame", {Vector2.new(0, 0), self.tab_frame}, {
        Size      = Vector2.new(0, 0),
        Position  = Utility:Position(0, 4, 0, 4 + (tabIndex - 1) * 20, self.tab_frame),
        Color     = Theme.outline,
        Hidden    = true,
    })
    self.tabInlineFrames[#self.tabInlineFrames + 1] = tabInline

    page._tabIndex     = tabIndex
    page._tabText      = tabText
    page._tabInline    = tabInline
    page._isSelected   = (tabIndex == 1)

    -- click to switch
    Utility:Connection(uis.InputBegan, function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ml = Utility:MouseLocation()
            local txb = tabText.TextBounds
            local tabPos = Utility:Position(0, 4, 0, 4 + (tabIndex - 1) * 20, self.tab_frame)
            if ml.x >= tabPos.x and ml.x <= tabPos.x + txb.X and
               ml.y >= tabPos.y and ml.y <= tabPos.y + txb.Y then
                self:SelectPage(tabIndex)
            end
        end
    end)

    if tabIndex == 1 then
        self:SelectPage(tabIndex)
    end
    return page
end

--[[ ----------------------------------------------------------------
    Window:SelectPage
    ---------------------------------------------------------------- ]]
function Library:SelectPage(index)
    if self.tabActive == index then return end
    self.tabActive = index
    for i, p in pairs(self.pages) do
        p._isSelected = (i == index)
        if p._tabInline then
            p._tabInline.Visible = (i == index)
            p._tabInline.Size = p._isSelected and
                Vector2.new(self.tab_frame.Size.x - 8, 18) or Vector2.new(0, 0)
            p._tabInline.Position = Utility:Position(0, 4, 0, 4 + (i - 1) * 20, self.tab_frame)
        end
        if p._tabText then
            p._tabText.Color = (i == index) and Theme.accent or Theme.textcolor
        end
    end
    self.currentPage = self.pages[index]
    -- hide all page content drawings, show current
    self:RefreshPageContent()
end

--[[ ----------------------------------------------------------------
    Window:RefreshPageContent  (hide all, show current page's)
    NEEDS pages to store their section drawing refs.
    ---------------------------------------------------------------- ]]
function Library:RefreshPageContent()
    -- NOTE: section content drawings are parented to
    -- Window.back_frame via the Section builder.
    -- We toggle visibility by walking Library.drawings
    -- and hiding anything built after back_frame that
    -- belongs to a non-selected page. Simpler approach:
    -- each Section stores its created drawings in a list.
    for _, p in pairs(self.pages) do
        local show = (p._isSelected)
        if p._sectionDrawings then
            for _, sd in pairs(p._sectionDrawings) do
                if sd and sd.Visible ~= nil then
                    sd.Visible = show
                end
            end
        end
    end
end

--[[ ============================================================
    Section
    ============================================================ ]]
function Sections:Section(info)
    local info = info or {}
    local name = info.name or info.Name or "Section"
    local side = info.Side or "Left"
    local section = {
        name  = name,
        side  = side,
        window = nil,
        page  = nil,
        buttons = {},
        labels  = {},
        toggles = {},
        sliders = {},
        drawList = {},
    }
    setmetatable(section, Sections)
    return section
end

--[[ ----------------------------------------------------------------
    Page:Section
    ---------------------------------------------------------------- ]]
function Pages:Section(info)
    local section = Sections:Section(info)
    section.page = self
    section.window = self.window
    self.sections[#self.sections + 1] = section
    if not self.window._pageSectionMap then
        self.window._pageSectionMap = {}
    end
    self.window._pageSectionMap[self] = section
    section._pageSections = self.sections
    return section
end

--[[ ----------------------------------------------------------------
    Page:MultiSection  → returns multiple Section handles
    ---------------------------------------------------------------- ]]
function Pages:MultiSection(info)
    local sections = info.Sections or {}
    local side = info.Side or "Left"
    local size = info.Size or 200
    local out = {}
    for _, sname in pairs(sections) do
        local s = self:Section({Name = sname, Side = side})
        s._multiSize = size
        out[#out + 1] = s
    end
    return out
end

--[[ ----------------------------------------------------------------
    Page:GetSelectedSection  (helper for multi-section UIs)
    ---------------------------------------------------------------- ]]
function Pages:GetSelectedSection()
    if not self.window.currentPage then return nil end
    return self.window.currentPage.sections[1]
end

-- ============================================================
--  Content builders (attach to the active section)
-- ============================================================

local activeSection = nil

local function resolveSection(sec)
    if sec then return sec end
    return activeSection
end

local function sectionDrawing(section, instance, relativeTo)
    table.insert(section.drawList, instance)
    if section.page and section.page._sectionDrawings then
        section.page._sectionDrawings[#section.page._sectionDrawings + 1] = instance
    end
end

-- // helper: build the content frame inside back_frame
local function buildContentFrame(section)
    if section._contentFrame then return section._contentFrame end
    local win = section.window
    local frame = Utility:Create("Frame", {Vector2.new(0, 0), win.back_frame}, {
        Size      = Utility:Size(1, -10, 1, -10, win.back_frame),
        Position  = Utility:Position(0, 5, 0, 30, win.back_frame),
        Color     = Theme.dark_contrast,
    })
    section._contentFrame = frame
    return frame
end

-- // helper: section header
local function sectionHeader(section, contentFrame)
    if section._header then return section._header end
    local win = section.window
    local header = Utility:Create("TextLabel", {Vector2.new(0, 0), contentFrame}, {
        Text         = section.name,
        Size         = Theme.textsize + 1,
        Font         = Theme.font,
        Color        = win and (win.currentPage and win.currentPage._tabText and win.currentPage._tabText.Color or Theme.accent) or Theme.accent,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 8, 0, 6, contentFrame),
    })
    section._header = header
    return header
end

-- // helper: divider line
local function divider(section, contentFrame)
    local line = Utility:Create("Line", {Vector2.new(0, 0), contentFrame}, {
        Color       = Theme.outline,
        Thickness   = 1,
        Position    = Utility:Position(0, 4, 0, 20, contentFrame),
        From        = Vector2.new(0, 0),
        To          = Vector2.new(contentFrame.Size.x, 0),
        Visible     = true,
        Transparency = 0.4,
    })
    return line
end

-- // helper: next Y position
local function nextY(section, contentFrame, startY)
    if not section._nextY then
        section._nextY = startY or 30
    end
    local y = section._nextY
    section._nextY = y + 24
    return y
end

-- // reset Y when switching pages
local function resetSectionY(section)
    section._nextY = 30
end

-- hook page selection to reset Y
originalSelectPage = Library.SelectPage
function Library:SelectPage(index)
    if self.tabActive == index then return end
    self.tabActive = index
    for i, p in pairs(self.pages) do
        p._isSelected = (i == index)
        if p._tabInline then
            p._tabInline.Visible = (i == index)
            p._tabInline.Size = p._isSelected and
                Vector2.new(self.tab_frame.Size.x - 8, 18) or Vector2.new(0, 0)
            p._tabInline.Position = Utility:Position(0, 4, 0, 4 + (i - 1) * 20, self.tab_frame)
        end
        if p._tabText then
            p._tabText.Color = (i == index) and Theme.accent or Theme.textcolor
        end
    end
    self.currentPage = self.pages[index]
    -- reset Y for all sections in current page
    if self.currentPage then
        for _, s in pairs(self.currentPage.sections) do
            resetSectionY(s)
        end
    end
    self:RefreshPageContent()
end

--[[ ----------------------------------------------------------------
    Section:Label
    ---------------------------------------------------------------- ]]
function Sections:Label(info)
    local info = info or {}
    local name = info.name or info.Name or "Label"
    local middle = info.Middle or false
    local pointer = info.pointer or info.Pointer or nil
    local section = resolveSection(self)
    if not section then return nil end

    local contentFrame = buildContentFrame(section)
    local y = nextY(section, contentFrame, 30)

    local lbl = Utility:Create("TextLabel", {Vector2.new(0, 0), contentFrame}, {
        Text         = name,
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 8, 0, y, contentFrame),
        Center       = middle,
        Transparency = 0,
    })
    sectionDrawing(section, lbl, contentFrame)

    if pointer then
        if not Library.pointers[pointer] then
            Library.pointers[pointer] = {
                Get = function() return lbl.Text end,
                Set = function(v) lbl.Text = tostring(v) end,
            }
        end
    end
    section.labels[#section.labels + 1] = lbl
    return lbl
end

--[[ ----------------------------------------------------------------
    Section:Toggle
    ---------------------------------------------------------------- ]]
function Sections:Toggle(info)
    local info = info or {}
    local name      = info.name or info.Name or "Toggle"
    local default   = info.Default or false
    local pointer   = info.pointer or info.Pointer or nil
    local callback  = info.Callback or function() end
    local section   = resolveSection(self)
    if not section then return nil end

    local contentFrame = buildContentFrame(section)
    local y = nextY(section, contentFrame, 30)

    local box = Utility:Create("Square", {Vector2.new(0, 0), contentFrame}, {
        Size        = Vector2.new(12, 12),
        Position    = Utility:Position(0, 8, 0, y, contentFrame),
        Color       = Theme.outline,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })
    local boxInner = Utility:Create("Square", {Vector2.new(1, 1), box}, {
        Size        = Utility:Size(1, -2, 1, -2, box),
        Position    = Utility:Position(0, 1, 0, 1, box),
        Color       = Theme.outline,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })

    local label = Utility:Create("TextLabel", {Vector2.new(0, 0), contentFrame}, {
        Text         = name,
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 24, 0, y, contentFrame),
        Transparency = 0,
    })

    local state = default

    box._toggleState = state
    box._callback    = callback
    box._pointer     = pointer
    box._label       = label
    box._boxInner    = boxInner

    local function updateVisuals()
        boxInner.Color = state and Theme.accent or Theme.outline
        boxInner.Visible = true
        label.Color = state and Theme.accent or Theme.textcolor
    end
    updateVisuals()

    local function toggle()
        state = not state
        box._toggleState = state
        updateVisuals()
        if callback then callback(state) end
    end

    box._toggleFn = toggle

    Utility:Connection(uis.InputBegan, function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ml = Utility:MouseLocation()
            local bb = Utility:MouseOverDrawing({
                box.Position.x,
                box.Position.y,
                box.Position.x + box.Size.x,
                box.Position.y + box.Size.y,
            })
            if bb then
                toggle()
                if pointer then
                    if not Library.pointers[pointer] then
                        Library.pointers[pointer] = {
                            Get = function() return state end,
                            Set = function(v) state = (v == true); updateVisuals() end,
                        }
                    end
                    Library.pointers[pointer]:Set(state)
                end
            end
        end
    end)

    section.toggles[#section.toggles + 1] = box
    sectionDrawing(section, box, contentFrame)
    sectionDrawing(section, boxInner, contentFrame)
    sectionDrawing(section, label, contentFrame)

    return box
end

--[[ ----------------------------------------------------------------
    Section:Slider  (draggable knob on a track)
    ---------------------------------------------------------------- ]]
function Sections:Slider(info)
    local info = info or {}
    local name        = info.name or info.Name or "Slider"
    local min         = info.Minimum or 0
    local max         = info.Maximum or 100
    local default     = info.Default or 50
    local measurement = info.Measurement or ""
    local decimals    = info.Decimals or 0
    local pointer     = info.pointer or info.Pointer or nil
    local callback    = info.Callback or function() end
    local section     = resolveSection(self)
    if not section then return nil end

    local contentFrame = buildContentFrame(section)
    local y = nextY(section, contentFrame, 30)

    local track = Utility:Create("Square", {Vector2.new(0, 0), contentFrame}, {
        Size        = Vector2.new(150, 4),
        Position    = Utility:Position(0, 8, 0, y + 6, contentFrame),
        Color       = Theme.outline,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })

    local fill = Utility:Create("Square", {Vector2.new(1, 1), track}, {
        Size        = Utility:Size(1, 0, 1, 0, track),
        Position    = Utility:Position(0, 1, 0, 1, track),
        Color       = Theme.accent,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })

    local knob = Utility:Create("Circle", {Vector2.new(0, 0), contentFrame}, {
        Color       = Theme.accent,
        Thickness   = 0,
        Filled      = true,
        Radius      = 6,
        Position    = Utility:Position(0, 8 + 75, 0, y + 6, contentFrame),
        Transparency = 0,
    })

    local label = Utility:Create("TextLabel", {Vector2.new(0, 0), contentFrame}, {
        Text         = name,
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 8, 0, y, contentFrame),
        Transparency = 0,
    })

    local valueLabel = Utility:Create("TextLabel", {Vector2.new(0, 0), contentFrame}, {
        Text         = tostring(default) .. measurement,
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.accent,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 8 + 160, 0, y, contentFrame),
        Transparency = 0,
    })

    local value = default
    local dragging = false

    local function updateValue(v)
        value = math.clamp(v, min, max)
        local pct = (value - min) / (max - min)
        fill.Size = Vector2.new(pct * (track.Size.x - 2), 2)
        knob.Position = Vector2.new(track.Position.x + 1 + pct * (track.Size.x - 2), track.Position.y)
        local display = decimals > 0 and string.format("%." .. tostring(decimals) .. "f", value) or tostring(math.floor(value))
        valueLabel.Text = display .. measurement
    end
    updateValue(default)

    local function onChange(v)
        if callback then callback(v) end
    end

    Utility:Connection(uis.InputBegan, function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ml = Utility:MouseLocation()
            local bb = Utility:MouseOverDrawing({
                knob.Position.x - knob.Radius,
                knob.Position.y - knob.Radius,
                knob.Position.x + knob.Radius,
                knob.Position.y + knob.Radius,
            })
            if bb then
                dragging = true
            end
        end
    end)

    Utility:Connection(uis.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local ml = Utility:MouseLocation()
            local rel = ml.x - (track.Position.x + 1)
            local pct = math.clamp(rel / (track.Size.x - 2), 0, 1)
            local v = min + pct * (max - min)
            updateValue(v)
            onChange(v)
            if pointer then
                if not Library.pointers[pointer] then
                    Library.pointers[pointer] = {
                        Get = function() return value end,
                        Set = function(v) updateValue(v); onChange(v) end,
                    }
                end
                Library.pointers[pointer]:Set(value)
            end
        end
        if dragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    Utility:Connection(uis.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    section.sliders[#section.sliders + 1] = {
        track = track, fill = fill, knob = knob,
        label = label, valueLabel = valueLabel,
        value = value, min = min, max = max,
        updateValue = updateValue, onChange = onChange,
    }
    sectionDrawing(section, track, contentFrame)
    sectionDrawing(section, fill, contentFrame)
    sectionDrawing(section, knob, contentFrame)
    sectionDrawing(section, label, contentFrame)
    sectionDrawing(section, valueLabel, contentFrame)

    return {
        Get = function() return value end,
        Set = function(v) updateValue(v); onChange(v) end,
    }
end

--[[ ----------------------------------------------------------------
    Section:Button
    ---------------------------------------------------------------- ]]
function Sections:Button(info)
    local info = info or {}
    local name     = info.name or info.Name or "Button"
    local pointer  = info.pointer or info.Pointer or nil
    local callback = info.Callback or function() end
    local section  = resolveSection(self)
    if not section then return nil end

    local contentFrame = buildContentFrame(section)
    local y = nextY(section, contentFrame, 30)

    local btn = Utility:Create("Square", {Vector2.new(0, 0), contentFrame}, {
        Size        = Vector2.new(100, 20),
        Position    = Utility:Position(0, 8, 0, y, contentFrame),
        Color       = Theme.accent,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })
    local btnText = Utility:Create("TextLabel", {Vector2.new(0, 0), btn}, {
        Text         = name,
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Color3.fromRGB(255, 255, 255),
        OutlineColor = Theme.textborder,
        Outline      = true,
        Center       = true,
        Position     = Utility:Position(0, 0, 0, 0, btn),
        Transparency = 0,
    })

    local hover = false
    local originalColor = Theme.accent

    Utility:Connection(uis.InputBegan, function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ml = Utility:MouseLocation()
            local bb = Utility:MouseOverDrawing({
                btn.Position.x,
                btn.Position.y,
                btn.Position.x + btn.Size.x,
                btn.Position.y + btn.Size.y,
            })
            if bb then
                callback()
                if pointer then
                    if not Library.pointers[pointer] then
                        Library.pointers[pointer] = {
                            Get = function() return true end,
                            Set = function(v) end,
                        }
                    end
                end
            end
        end
    end)

    Utility:Connection(uis.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local ml = Utility:MouseLocation()
            local bb = Utility:MouseOverDrawing({
                btn.Position.x,
                btn.Position.y,
                btn.Position.x + btn.Size.x,
                btn.Position.y + btn.Size.y,
            })
            if bb and not hover then
                hover = true
                btn.Color = Color3.fromRGB(
                    math.min(255, originalColor.R + 30),
                    math.min(255, originalColor.G + 30),
                    math.min(255, originalColor.B + 30)
                )
            elseif not bb and hover then
                hover = false
                btn.Color = originalColor
            end
        end
    end)

    sectionDrawing(section, btn, contentFrame)
    sectionDrawing(section, btnText, contentFrame)

    return {
        Get = function() return true end,
        Set = function(v) end,
    }
end

--[[ ----------------------------------------------------------------
    Section:ButtonHolder
    ---------------------------------------------------------------- ]]
function Sections:ButtonHolder(info)
    local info = info or {}
    local buttons = info.Buttons or {}
    local section = resolveSection(self)
    if not section then return nil end

    local contentFrame = buildContentFrame(section)
    local y = nextY(section, contentFrame, 30)

    for _, btnDef in pairs(buttons) do
        local btnName = btnDef[1] or "Button"
        local btnCb   = btnDef[2] or function() end
        local btn = Utility:Create("Square", {Vector2.new(0, 0), contentFrame}, {
            Size        = Vector2.new(80, 20),
            Position    = Utility:Position(0, 8, 0, y, contentFrame),
            Color       = Theme.accent,
            Filled      = true,
            Thickness   = 0,
            Transparency = 0,
        })
        local btnText = Utility:Create("TextLabel", {Vector2.new(0, 0), btn}, {
            Text         = btnName,
            Size         = Theme.textsize,
            Font         = Theme.font,
            Color        = Color3.fromRGB(255, 255, 255),
            OutlineColor = Theme.textborder,
            Outline      = true,
            Center       = true,
            Position     = Utility:Position(0, 0, 0, 0, btn),
            Transparency = 0,
        })

        Utility:Connection(uis.InputBegan, function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local ml = Utility:MouseLocation()
                local bb = Utility:MouseOverDrawing({
                    btn.Position.x,
                    btn.Position.y,
                    btn.Position.x + btn.Size.x,
                    btn.Position.y + btn.Size.y,
                })
                if bb then btnCb() end
            end
        end)

        sectionDrawing(section, btn, contentFrame)
        sectionDrawing(section, btnText, contentFrame)

        y = y + 24
        section._nextY = y
    end

    return {}
end

--[[ ----------------------------------------------------------------
    Section:Dropdown
    ---------------------------------------------------------------- ]]
function Sections:Dropdown(info)
    local info = info or {}
    local name     = info.name or info.Name or "Dropdown"
    local options  = info.Options or {}
    local default  = info.Default or 1
    local pointer  = info.pointer or info.Pointer or nil
    local callback = info.Callback or function() end
    local section  = resolveSection(self)
    if not section then return nil end

    local contentFrame = buildContentFrame(section)
    local y = nextY(section, contentFrame, 30)

    local ddFrame = Utility:Create("Square", {Vector2.new(0, 0), contentFrame}, {
        Size        = Vector2.new(130, 20),
        Position    = Utility:Position(0, 8, 0, y, contentFrame),
        Color       = Theme.outline,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })

    local ddInner = Utility:Create("Square", {Vector2.new(1, 1), ddFrame}, {
        Size        = Utility:Size(1, -2, 1, -2, ddFrame),
        Position    = Utility:Position(0, 1, 0, 1, ddFrame),
        Color       = Theme.dark_contrast,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })

    local ddText = Utility:Create("TextLabel", {Vector2.new(0, 0), ddInner}, {
        Text         = tostring(options[default] or options[1] or ""),
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 4, 0, 2, ddInner),
        Transparency = 0,
    })

    local ddArrow = Utility:Create("TextLabel", {Vector2.new(0, 0), ddInner}, {
        Text         = "v",
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        Outline      = true,
        Position     = Utility:Position(0, 100, 0, 2, ddInner),
        Transparency = 0,
    })

    local open = false
    local holder = {
        drawings = {},
        buttons  = {},
        inline   = nil,
    }

    local function openDropdown()
        if open then return end
        open = true
        section.window.currentContent.dropdown = {
            open = true,
            holder = holder,
            dropdown_image = ddArrow,
        }
        local hFrame = Utility:Create("Frame", {Vector2.new(0, 0), contentFrame}, {
            Size        = Vector2.new(130, (#options * 22) + 4),
            Position    = Utility:Position(0, 8, 0, y + 20, contentFrame),
            Color       = Theme.dark_contrast,
            Filled      = true,
            Thickness   = 0,
            Transparency = 0,
        })
        holder.inline = hFrame
        sectionDrawing(section, hFrame, contentFrame)

        for i, opt in pairs(options) do
            local btn = Utility:Create("Square", {Vector2.new(0, 0), hFrame}, {
                Size        = Vector2.new(124, 20),
                Position    = Utility:Position(0, 4, 0, 2 + (i - 1) * 22, hFrame),
                Color       = Theme.outline,
                Filled      = true,
                Thickness   = 0,
                Transparency = 0,
            })
            local btnText = Utility:Create("TextLabel", {Vector2.new(0, 0), btn}, {
                Text         = tostring(opt),
                Size         = Theme.textsize,
                Font         = Theme.font,
                Color        = Theme.textcolor,
                OutlineColor = Theme.textborder,
                Outline      = true,
                Position     = Utility:Position(0, 4, 0, 2, btn),
                Transparency = 0,
            })

            local function select(i)
                ddText.Text = tostring(options[i])
                if callback then callback(options[i], i) end
                if pointer then
                    if not Library.pointers[pointer] then
                        Library.pointers[pointer] = {
                            Get = function() return options[i] end,
                            Set = function(v)
                                for idx, o in pairs(options) do
                                    if o == v then
                                        ddText.Text = tostring(o)
                                        if callback then callback(o, idx) end
                                        return
                                    end
                                end
                            end,
                        }
                    end
                    Library.pointers[pointer]:Set(options[i])
                end
                open = false
                section.window.currentContent.dropdown = nil
                for _, v in pairs(holder.drawings) do
                    Utility:Remove(v)
                end
                holder.drawings = {}
                holder.buttons = {}
                holder.inline = nil
                if hFrame then hFrame:Remove() end
            end

            btn._selectFn = select
            Utility:Connection(uis.InputBegan, function(input, gp)
                if gp then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local ml = Utility:MouseLocation()
                    if holder.inline then
                        local bb = Utility:MouseOverDrawing({
                            btn.Position.x,
                            btn.Position.y,
                            btn.Position.x + btn.Size.x,
                            btn.Position.y + btn.Size.y,
                        })
                        if bb then select(i) end
                    end
                end
            end)

            holder.drawings[#holder.drawings + 1] = btn
            holder.drawings[#holder.drawings + 1] = btnText
            holder.buttons[#holder.buttons + 1] = btn
        end
    end

    local function closeDropdown()
        if not open then return end
        open = false
        section.window.currentContent.dropdown = nil
        for _, v in pairs(holder.drawings) do
            Utility:Remove(v)
        end
        holder.drawings = {}
        holder.buttons = {}
        holder.inline = nil
        if ddArrow then
            Utility:LoadImage(ddArrow, "arrow_down", "https://i.imgur.com/tVqy0nL.png")
        end
    end

    Utility:Connection(uis.InputBegan, function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ml = Utility:MouseLocation()
            local bb = Utility:MouseOverDrawing({
                ddFrame.Position.x,
                ddFrame.Position.y,
                ddFrame.Position.x + ddFrame.Size.x,
                ddFrame.Position.y + ddFrame.Size.y,
            })
            if bb then
                if open then
                    closeDropdown()
                else
                    openDropdown()
                end
            end
        end
    end)

    sectionDrawing(section, ddFrame, contentFrame)
    sectionDrawing(section, ddInner, contentFrame)
    sectionDrawing(section, ddText, contentFrame)
    sectionDrawing(section, ddArrow, contentFrame)

    return {
        Get = function() return options[default] end,
        Set = function(v)
            for idx, o in pairs(options) do
                if o == v then
                    ddText.Text = tostring(o)
                    return
                end
            end
        end,
    }
end

--[[ ----------------------------------------------------------------
    Section:Multibox  (multi-select, rendered as tag chips)
    ---------------------------------------------------------------- ]]
function Sections:Multibox(info)
    local info = info or {}
    local name     = info.name or info.Name or "Multibox"
    local options  = info.Options or {}
    local default  = info.Default or {}
    local min      = info.Minimum or 1
    local pointer  = info.pointer or info.Pointer or nil
    local callback = info.Callback or function() end
    local section  = resolveSection(self)
    if not section then return nil end

    local contentFrame = buildContentFrame(section)
    local y = nextY(section, contentFrame, 30)

    local mbFrame = Utility:Create("Square", {Vector2.new(0, 0), contentFrame}, {
        Size        = Vector2.new(130, 20),
        Position    = Utility:Position(0, 8, 0, y, contentFrame),
        Color       = Theme.outline,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })

    local mbInner = Utility:Create("Square", {Vector2.new(1, 1), mbFrame}, {
        Size        = Utility:Size(1, -2, 1, -2, mbFrame),
        Position    = Utility:Position(0, 1, 0, 1, mbFrame),
        Color       = Theme.dark_contrast,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })

    local selected = {}
    for _, v in pairs(default) do
        selected[v] = true
    end

    local mbText = Utility:Create("TextLabel", {Vector2.new(0, 0), mbInner}, {
        Text         = "",
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 4, 0, 2, mbInner),
        Transparency = 0,
    })

    local mbArrow = Utility:Create("TextLabel", {Vector2.new(0, 0), mbInner}, {
        Text         = "v",
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        Outline      = true,
        Position     = Utility:Position(0, 100, 0, 2, mbInner),
        Transparency = 0,
    })

    local open = false
    local holder = {
        drawings = {},
        buttons  = {},
        inline   = nil,
    }

    local function updateText()
        local parts = {}
        for k, _ in pairs(selected) do
            parts[#parts + 1] = tostring(k)
        end
        mbText.Text = (#parts > 0) and table.concat(parts, ", ") or "None"
    end
    updateText()

    local function openMultibox()
        if open then return end
        open = true
        section.window.currentContent.multibox = {
            open = true,
            holder = holder,
            multibox_image = mbArrow,
        }
        local hFrame = Utility:Create("Frame", {Vector2.new(0, 0), contentFrame}, {
            Size        = Vector2.new(130, (#options * 22) + 4),
            Position    = Utility:Position(0, 8, 0, y + 20, contentFrame),
            Color       = Theme.dark_contrast,
            Filled      = true,
            Thickness   = 0,
            Transparency = 0,
        })
        holder.inline = hFrame
        sectionDrawing(section, hFrame, contentFrame)

        for i, opt in pairs(options) do
            local sel = selected[opt] or false
            local btn = Utility:Create("Square", {Vector2.new(0, 0), hFrame}, {
                Size        = Vector2.new(124, 20),
                Position    = Utility:Position(0, 4, 0, 2 + (i - 1) * 22, hFrame),
                Color       = sel and Theme.accent or Theme.outline,
                Filled      = true,
                Thickness   = 0,
                Transparency = 0,
            })
            local btnText = Utility:Create("TextLabel", {Vector2.new(0, 0), btn}, {
                Text         = tostring(opt),
                Size         = Theme.textsize,
                Font         = Theme.font,
                Color        = Color3.fromRGB(255, 255, 255),
                OutlineColor = Theme.textborder,
                Outline      = true,
                Position     = Utility:Position(0, 4, 0, 2, btn),
                Transparency = 0,
            })

            local function toggleSel()
                if selected[opt] then
                    selected[opt] = nil
                    btn.Color = Theme.outline
                else
                    if min and #selected + 1 < min then
                        -- enforce minimum; ignore
                        return
                    end
                    selected[opt] = true
                    btn.Color = Theme.accent
                end
                updateText()
                if callback then callback(selected) end
                if pointer then
                    if not Library.pointers[pointer] then
                        Library.pointers[pointer] = {
                            Get = function() return selected end,
                            Set = function(v)
                                selected = {}
                                for _, item in pairs(v) do
                                    selected[item] = true
                                end
                                updateText()
                                for _, hb in pairs(holder.buttons) do
                                    -- recolor held buttons
                                end
                                if callback then callback(selected) end
                            end,
                        }
                    end
                    Library.pointers[pointer]:Set(selected)
                end
            end

            btn._toggleFn = toggleSel
            Utility:Connection(uis.InputBegan, function(input, gp)
                if gp then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    local ml = Utility:MouseLocation()
                    if holder.inline then
                        local bb = Utility:MouseOverDrawing({
                            btn.Position.x,
                            btn.Position.y,
                            btn.Position.x + btn.Size.x,
                            btn.Position.y + btn.Size.y,
                        })
                        if bb then toggleSel() end
                    end
                end
            end)

            holder.drawings[#holder.drawings + 1] = btn
            holder.drawings[#holder.drawings + 1] = btnText
            holder.buttons[#holder.buttons + 1] = btn
        end
    end

    local function closeMultibox()
        if not open then return end
        open = false
        section.window.currentContent.multibox = nil
        for _, v in pairs(holder.drawings) do
            Utility:Remove(v)
        end
        holder.drawings = {}
        holder.buttons = {}
        holder.inline = nil
        if mbArrow then
            Utility:LoadImage(mbArrow, "arrow_down", "https://i.imgur.com/tVqy0nL.png")
        end
    end

    Utility:Connection(uis.InputBegan, function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ml = Utility:MouseLocation()
            local bb = Utility:MouseOverDrawing({
                mbFrame.Position.x,
                mbFrame.Position.y,
                mbFrame.Position.x + mbFrame.Size.x,
                mbFrame.Position.y + mbFrame.Size.y,
            })
            if bb then
                if open then
                    closeMultibox()
                else
                    openMultibox()
                end
            end
        end
    end)

    sectionDrawing(section, mbFrame, contentFrame)
    sectionDrawing(section, mbInner, contentFrame)
    sectionDrawing(section, mbText, contentFrame)
    sectionDrawing(section, mbArrow, contentFrame)

    return {
        Get = function() return selected end,
        Set = function(v)
            selected = {}
            for _, item in pairs(v) do
                selected[item] = true
            end
            updateText()
        end,
    }
end

--[[ ----------------------------------------------------------------
    Section:Keybind  (click to rebind)
    ---------------------------------------------------------------- ]]
function Sections:Keybind(info)
    local info = info or {}
    local name        = info.name or info.Name or "Keybind"
    local default     = info.Default or Enum.KeyCode.E
    local keybindName = info.KeybindName or name
    local mode        = info.Mode or "Toggle"
    local pointer     = info.pointer or info.Pointer or nil
    local callback    = info.Callback or function() end
    local section     = resolveSection(self)
    if not section then return nil end

    local contentFrame = buildContentFrame(section)
    local y = nextY(section, contentFrame, 30)

    local kbFrame = Utility:Create("Square", {Vector2.new(0, 0), contentFrame}, {
        Size        = Vector2.new(130, 20),
        Position    = Utility:Position(0, 8, 0, y, contentFrame),
        Color       = Theme.outline,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })

    local kbInner = Utility:Create("Square", {Vector2.new(1, 1), kbFrame}, {
        Size        = Utility:Size(1, -2, 1, -2, kbFrame),
        Position    = Utility:Position(0, 1, 0, 1, kbFrame),
        Color       = Theme.dark_contrast,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })

    local kbText = Utility:Create("TextLabel", {Vector2.new(0, 0), kbInner}, {
        Text         = name,
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 4, 0, 2, kbInner),
        Transparency = 0,
    })

    local kbKeyText = Utility:Create("TextLabel", {Vector2.new(0, 0), kbInner}, {
        Text         = tostring(default),
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.accent,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 90, 0, 2, kbInner),
        Transparency = 0,
    })

    local kbArrow = Utility:Create("TextLabel", {Vector2.new(0, 0), kbInner}, {
        Text         = ">",
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        Outline      = true,
        Position     = Utility:Position(0, 110, 0, 2, kbInner),
        Transparency = 0,
    })

    local rebinding = false
    local currentKey = default

    local function updateKeyText()
        kbKeyText.Text = tostring(currentKey)
    end
    updateKeyText()

    local function onKeybindFired()
        if callback then callback(currentKey) end
    end

    Utility:Connection(uis.InputBegan, function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ml = Utility:MouseLocation()
            local bb = Utility:MouseOverDrawing({
                kbFrame.Position.x,
                kbFrame.Position.y,
                kbFrame.Position.x + kbFrame.Size.x,
                kbFrame.Position.y + kbFrame.Size.y,
            })
            if bb then
                if rebinding then
                    rebinding = false
                    kbArrow.Text = ">"
                    section.window.keybindslist:Add(keybindName, tostring(currentKey))
                else
                    rebinding = true
                    kbArrow.Text = "Press a key..."
                end
            end
        end
        if rebinding and input.KeyCode ~= Enum.KeyCode.Unknown then
            currentKey = input.KeyCode
            updateKeyText()
            rebinding = false
            kbArrow.Text = ">"
            section.window.keybindslist:Add(keybindName, tostring(currentKey))
            if pointer then
                if not Library.pointers[pointer] then
                    Library.pointers[pointer] = {
                        Get = function() return currentKey end,
                        Set = function(v) currentKey = v; updateKeyText() end,
                    }
                end
                Library.pointers[pointer]:Set(currentKey)
            end
        end
    end)

    sectionDrawing(section, kbFrame, contentFrame)
    sectionDrawing(section, kbInner, contentFrame)
    sectionDrawing(section, kbText, contentFrame)
    sectionDrawing(section, kbKeyText, contentFrame)
    sectionDrawing(section, kbArrow, contentFrame)

    -- register in keybinds list
    section.window.keybindslist:Add(keybindName, tostring(currentKey))

    return {
        Get = function() return currentKey end,
        Set = function(v) currentKey = v; updateKeyText() end,
    }
end

--[[ ----------------------------------------------------------------
    Section:Colorpicker  (color swatch + full picker popup)
    ---------------------------------------------------------------- ]]
function Sections:Colorpicker(info)
    local info = info or {}
    local name    = info.name or info.Name or "Colorpicker"
    local infoTxt = info.Info or ""
    local default = info.Default or Color3.fromRGB(255, 0, 0)
    local alpha   = info.Alpha or 1
    local pointer = info.pointer or info.Pointer or nil
    local callback = info.Callback or function() end
    local section  = resolveSection(self)
    if not section then return nil end

    local contentFrame = buildContentFrame(section)
    local y = nextY(section, contentFrame, 30)

    local swatch = Utility:Create("Square", {Vector2.new(0, 0), contentFrame}, {
        Size        = Vector2.new(20, 20),
        Position    = Utility:Position(0, 8, 0, y, contentFrame),
        Color       = default,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })

    local swatchBorder = Utility:Create("Square", {Vector2.new(1, 1), swatch}, {
        Size        = Utility:Size(1, -2, 1, -2, swatch),
        Position    = Utility:Position(0, 1, 0, 1, swatch),
        Color       = Theme.outline,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })

    local label = Utility:Create("TextLabel", {Vector2.new(0, 0), contentFrame}, {
        Text         = name,
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 32, 0, y, contentFrame),
        Transparency = 0,
    })

    if infoTxt ~= "" then
        local infoLabel = Utility:Create("TextLabel", {Vector2.new(0, 0), contentFrame}, {
            Text         = infoTxt,
            Size         = 11,
            Font         = Theme.font,
            Color        = Color3.fromRGB(180, 180, 180),
            OutlineColor = Theme.textborder,
            Outline      = false,
            Position     = Utility:Position(0, 32, 0, y + 14, contentFrame),
            Transparency = 0,
        })
        sectionDrawing(section, infoLabel, contentFrame)
    end

    local open = false
    local pickerColor = default
    local pickerAlpha = alpha
    local holder = {
        drawings = {},
        buttons  = {},
        inline   = nil,
    }

    local function openPicker()
        if open then return end
        open = true
        section.window.currentContent.colorpicker = {
            open = true,
            holder = holder,
            picker_image = nil,
        }
        local hSize = Vector2.new(200, 200)
        local hFrame = Utility:Create("Frame", {Vector2.new(0, 0), contentFrame}, {
            Size        = hSize,
            Position    = Utility:Position(0, 8, 0, y, contentFrame),
            Color       = Theme.dark_contrast,
            Filled      = true,
            Thickness   = 0,
            Transparency = 0,
        })
        holder.inline = hFrame
        sectionDrawing(section, hFrame, contentFrame)

        -- color preview box
        local preview = Utility:Create("Square", {Vector2.new(0, 0), hFrame}, {
            Size        = Vector2.new(40, 40),
            Position    = Utility:Position(0, 8, 0, 8, hFrame),
            Color       = pickerColor,
            Filled      = true,
            Thickness   = 0,
            Transparency = 0,
        })
        local previewBorder = Utility:Create("Square", {Vector2.new(1, 1), preview}, {
            Size        = Utility:Size(1, -2, 1, -2, preview),
            Position    = Utility:Position(0, 1, 0, 1, preview),
            Color       = Theme.outline,
            Filled      = true,
            Thickness   = 0,
            Transparency = 0,
        })

        -- hue slider
        local hueTrack = Utility:Create("Square", {Vector2.new(0, 0), hFrame}, {
            Size        = Vector2.new(160, 10),
            Position    = Utility:Position(0, 56, 0, 8, hFrame),
            Color       = Color3.fromRGB(128, 128, 128),
            Filled      = true,
            Thickness   = 0,
            Transparency = 0,
        })
        local hueFill = Utility:Create("Square", {Vector2.new(0, 0), hueTrack}, {
            Size        = Vector2.new(0, 10),
            Position    = Utility:Position(0, 0, 0, 0, hueTrack),
            Color       = Color3.fromRGB(255, 0, 0),
            Filled      = true,
            Thickness   = 0,
            Transparency = 0,
        })

        local hueKnob = Utility:Create("Circle", {Vector2.new(0, 0), hueTrack}, {
            Color       = Color3.fromRGB(255, 255, 255),
            Thickness   = 0,
            Filled      = true,
            Radius      = 5,
            Position    = Utility:Position(0, 0, 0, 0, hueTrack),
            Transparency = 0,
        })

        -- alpha slider
        local alphaTrack = Utility:Create("Square", {Vector2.new(0, 0), hFrame}, {
            Size        = Vector2.new(160, 10),
            Position    = Utility:Position(0, 56, 0, 24, hFrame),
            Color       = Color3.fromRGB(128, 128, 128),
            Filled      = true,
            Thickness   = 0,
            Transparency = 0,
        })
        local alphaFill = Utility:Create("Square", {Vector2.new(0, 0), alphaTrack}, {
            Size        = Vector2.new(160, 10),
            Position    = Utility:Position(0, 0, 0, 0, alphaTrack),
            Color       = pickerColor,
            Filled      = true,
            Thickness   = 0,
            Transparency = 1 - pickerAlpha,
        })

        local alphaKnob = Utility:Create("Circle", {Vector2.new(0, 0), alphaTrack}, {
            Color       = Color3.fromRGB(255, 255, 255),
            Thickness   = 0,
            Filled      = true,
            Radius      = 5,
            Position    = Utility:Position(0, 160, 0, 0, alphaTrack),
            Transparency = 0,
        })

        local hue = pickerColor:ToHSV()
        local huePct = hue
        hueKnob.Position = Vector2.new(2.5 + huePct * (hueTrack.Size.x - 5), 5)
        hueFill.Size = Vector2.new(huePct * (hueTrack.Size.x - 2), 10)

        local alphaPct = pickerAlpha
        alphaKnob.Position = Vector2.new(2.5 + alphaPct * (alphaTrack.Size.x - 5), 5)
        alphaFill.Size = Vector2.new(alphaTrack.Size.x - 2, 10)
        alphaFill.Transparency = 1 - alphaPct

        local draggingHue = false
        local draggingAlpha = false

        local function setHue(h)
            hue = h
            local col = Color3.fromHSV(h, pickerColor:ToHSV()[2], pickerColor:ToHSV()[3])
            pickerColor = col
            swatch.Color = col
            preview.Color = col
            hueFill.Color = Color3.fromHSV(h, 1, 1)
            hueKnob.Position = Vector2.new(2.5 + h * (hueTrack.Size.x - 5), 5)
            hueFill.Size = Vector2.new(h * (hueTrack.Size.x - 2), 10)
            alphaFill.Color = col
            alphaFill.Transparency = 1 - pickerAlpha
            if callback then callback(col, pickerAlpha) end
            if pointer then
                if not Library.pointers[pointer] then
                    Library.pointers[pointer] = {
                        Get = function() return {Color = {pickerColor:ToHSV()[1], pickerColor:ToHSV()[2], pickerColor:ToHSV()[3]}, Transparency = pickerAlpha} end,
                        Set = function(v)
                            if v.Color then
                                local hh, ss, vv = v.Color[1], v.Color[2], v.Color[3]
                                local c = Color3.fromHSV(hh, ss, vv)
                                pickerColor = c
                                swatch.Color = c
                                preview.Color = c
                                hue = hh
                                hueFill.Color = Color3.fromHSV(hh, 1, 1)
                                hueKnob.Position = Vector2.new(2.5 + hh * (hueTrack.Size.x - 5), 5)
                                hueFill.Size = Vector2.new(hh * (hueTrack.Size.x - 2), 10)
                                alphaFill.Color = c
                            end
                            if v.Transparency then
                                pickerAlpha = v.Transparency
                                alphaFill.Transparency = 1 - pickerAlpha
                                alphaKnob.Position = Vector2.new(2.5 + pickerAlpha * (alphaTrack.Size.x - 5), 5)
                            end
                            if callback then callback(pickerColor, pickerAlpha) end
                        end,
                    }
                end
                Library.pointers[pointer]:Set({Color = {pickerColor:ToHSV()[1], pickerColor:ToHSV()[2], pickerColor:ToHSV()[3]}, Transparency = pickerAlpha})
            end
        end

        local function setAlpha(a)
            pickerAlpha = math.clamp(a, 0, 1)
            alphaKnob.Position = Vector2.new(2.5 + pickerAlpha * (alphaTrack.Size.x - 5), 5)
            alphaFill.Size = Vector2.new(alphaTrack.Size.x - 2, 10)
            alphaFill.Transparency = 1 - pickerAlpha
            if callback then callback(pickerColor, pickerAlpha) end
            if pointer then
                if Library.pointers[pointer] then
                    Library.pointers[pointer]:Set({Color = {pickerColor:ToHSV()[1], pickerColor:ToHSV()[2], pickerColor:ToHSV()[3]}, Transparency = pickerAlpha})
                end
            end
        end

        setHue(hue)

        Utility:Connection(uis.InputBegan, function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local ml = Utility:MouseLocation()
                local bbH = Utility:MouseOverDrawing({
                    hueTrack.Position.x,
                    hueTrack.Position.y,
                    hueTrack.Position.x + hueTrack.Size.x,
                    hueTrack.Position.y + hueTrack.Size.y,
                })
                if bbH then draggingHue = true end
                local bbA = Utility:MouseOverDrawing({
                    alphaTrack.Position.x,
                    alphaTrack.Position.y,
                    alphaTrack.Position.x + alphaTrack.Size.x,
                    alphaTrack.Position.y + alphaTrack.Size.y,
                })
                if bbA then draggingAlpha = true end
            end
        end)

        Utility:Connection(uis.InputChanged, function(input)
            if draggingHue and input.UserInputType == Enum.UserInputType.MouseMovement then
                local ml = Utility:MouseLocation()
                local rel = ml.x - (hueTrack.Position.x)
                local h = math.clamp(rel / (hueTrack.Size.x - 2), 0, 1)
                setHue(h)
            end
            if draggingAlpha and input.UserInputType == Enum.UserInputType.MouseMovement then
                local ml = Utility:MouseLocation()
                local rel = ml.x - (alphaTrack.Position.x)
                local a = math.clamp(rel / (alphaTrack.Size.x - 2), 0, 1)
                setAlpha(a)
            end
        end)

        Utility:Connection(uis.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingHue = false
                draggingAlpha = false
            end
        end)

        holder.drawings = {
            hFrame, preview, previewBorder, hueTrack, hueFill, hueKnob,
            alphaTrack, alphaFill, alphaKnob,
        }
    end

    local function closePicker()
        if not open then return end
        open = false
        section.window.currentContent.colorpicker = nil
        for _, v in pairs(holder.drawings) do
            Utility:Remove(v)
        end
        holder.drawings = {}
        holder.buttons = {}
        holder.inline = nil
    end

    Utility:Connection(uis.InputBegan, function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ml = Utility:MouseLocation()
            local bb = Utility:MouseOverDrawing({
                swatch.Position.x - 4,
                swatch.Position.y - 4,
                swatch.Position.x + swatch.Size.x + 4,
                swatch.Position.y + swatch.Size.y + 4,
            })
            if bb then
                if open then
                    closePicker()
                else
                    openPicker()
                end
            end
        end
    end)

    sectionDrawing(section, swatch, contentFrame)
    sectionDrawing(section, swatchBorder, contentFrame)
    sectionDrawing(section, label, contentFrame)

    return {
        Get = function() return pickerColor end,
        Set = function(c) pickerColor = c; swatch.Color = c; setHue(c:ToHSV()[1]) end,
    }
end

--[[ ----------------------------------------------------------------
    Section:ConfigBox  (placeholder for config save/load UI)
    ---------------------------------------------------------------- ]]
function Sections:ConfigBox(info)
    local info = info or {}
    local section = resolveSection(self)
    if not section then return nil end

    local contentFrame = buildContentFrame(section)
    local y = nextY(section, contentFrame, 30)

    local box = Utility:Create("Square", {Vector2.new(0, 0), contentFrame}, {
        Size        = Vector2.new(240, 100),
        Position    = Utility:Position(0, 8, 0, y, contentFrame),
        Color       = Theme.dark_contrast,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
    })
    local boxBorder = Utility:Create("Frame", {Vector2.new(1, 1), box}, {
        Size        = Utility:Size(1, -2, 1, -2, box),
        Position    = Utility:Position(0, 1, 0, 1, box),
        Color       = Theme.outline,
    })

    local boxTitle = Utility:Create("TextLabel", {Vector2.new(0, 0), box}, {
        Text         = "Config Box",
        Size         = Theme.textsize,
        Font         = Theme.font,
        Color        = Theme.textcolor,
        OutlineColor = Theme.textborder,
        Outline      = true,
        Position     = Utility:Position(0, 8, 0, 8, box),
        Transparency = 0,
    })

    local boxStatus = Utility:Create("TextLabel", {Vector2.new(0, 0), box}, {
        Text         = "No config loaded",
        Size         = 11,
        Font         = Theme.font,
        Color        = Color3.fromRGB(180, 180, 180),
        OutlineColor = Theme.textborder,
        Outline      = false,
        Position     = Utility:Position(0, 8, 0, 26, box),
        Transparency = 0,
    })

    sectionDrawing(section, box, contentFrame)
    sectionDrawing(section, boxBorder, contentFrame)
    sectionDrawing(section, boxTitle, contentFrame)
    sectionDrawing(section, boxStatus, contentFrame)

    section._configBox = {
        box = box, boxBorder = boxBorder, boxTitle = boxTitle, boxStatus = boxStatus,
    }

    return section._configBox
end

--[[ ============================================================
    Watermark
    ============================================================ ]]
function Library.watermark:UpdateSize()
    local screen = Utility:GetScreenSize()
    self.frame.Size = Vector2.new(180, 20)
    self.frame.Position = Vector2.new(
        screen.x - self.frame.Size.x - 8,
        screen.y - self.frame.Size.y - 8
    )
    self.text.Size = Vector2.new(self.frame.Size.x - 8, 14)
    self.text.Position = Vector2.new(
        self.frame.Position.x + 4,
        self.frame.Position.y + 3
    )
end

function Library.watermark:Visibility()
    if not self.enabled then
        self.frame.Visible = false
        self.text.Visible = false
        return
    end
    self.frame.Visible = true
    self.text.Visible = true
    self:UpdateSize()
end

function Library.watermark:Hide()
    self.frame.Visible = false
    self.text.Visible = false
end

function Library.watermark:Update()
    if not self.enabled then return end
    local fps = Library.shared.fps
    local ping = Library.shared.ping
    self.text.Text = string.format("SeriousHook  |  FPS: %d  |  Ping: %dms", fps, ping)
end

--[[ ============================================================
    Toasts
    ============================================================ ]]
local ToastStyles = {
    info    = { Color = Color3.fromRGB(50, 100, 255), Border = Color3.fromRGB(0, 0, 0), Icon = "i" },
    success = { Color = Color3.fromRGB(50, 255, 100), Border = Color3.fromRGB(0, 0, 0), Icon = "+" },
    warn    = { Color = Color3.fromRGB(255, 200, 50), Border = Color3.fromRGB(0, 0, 0), Icon = "!" },
    error   = { Color = Color3.fromRGB(255, 50, 50), Border = Color3.fromRGB(0, 0, 0), Icon = "x" },
}

function Library.toasts:Add(message, style, duration)
    style    = style    or "info"
    duration = duration or 3
    local st = ToastStyles[style] or ToastStyles.info
    local id = self.nextId
    self.nextId = self.nextId + 1

    local screen = Utility:GetScreenSize()
    local toastW = 220
    local toastH = 36
    local baseX  = screen.x - toastW - 8
    local baseY  = screen.y - 8 - (#self.active + 1) * (toastH + 4)

    local frame = Utility:Create("Frame", {Vector2.new(0, 0)}, {
        Size        = Vector2.new(toastW, toastH),
        Position    = Vector2.new(baseX, baseY),
        Color       = Color3.fromRGB(20, 20, 20),
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
        ZIndex      = 100,
    })

    local border = Utility:Create("Frame", {Vector2.new(1, 1), frame}, {
        Size        = Utility:Size(1, -2, 1, -2, frame),
        Position    = Utility:Position(0, 1, 0, 1, frame),
        Color       = st.Border,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
        ZIndex      = 100,
    })

    local accentBar = Utility:Create("Frame", {Vector2.new(0, 0), frame}, {
        Size        = Vector2.new(3, toastH - 2),
        Position    = Vector2.new(frame.Position.x + 1, frame.Position.y + 1),
        Color       = st.Color,
        Filled      = true,
        Thickness   = 0,
        Transparency = 0,
        ZIndex      = 100,
    })

    local icon = Utility:Create("TextLabel", {Vector2.new(0, 0), frame}, {
        Text         = st.Icon,
        Size         = 14,
        Font         = 2,
        Color        = st.Color,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Outline      = true,
        Position     = Vector2.new(frame.Position.x + 10, frame.Position.y + 9),
        Transparency = 0,
        ZIndex       = 100,
    })

    local text = Utility:Create("TextLabel", {Vector2.new(0, 0), frame}, {
        Text         = message,
        Size         = 12,
        Font         = 2,
        Color        = Color3.fromRGB(255, 255, 255),
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Outline      = true,
        Position     = Vector2.new(frame.Position.x + 24, frame.Position.y + 9),
        Transparency = 0,
        ZIndex       = 100,
    })

    local entry = {
        id       = id,
        frame    = frame,
        border   = border,
        accentBar = accentBar,
        icon     = icon,
        text     = text,
        style    = style,
        duration = duration,
        elapsed  = 0,
        removed  = false,
        alpha    = 0,
    }

    self.active[#self.active + 1] = entry
    -- fade in
    Utility:Lerp(frame, {Transparency = 0}, 0.2)
    Utility:Lerp(border, {Transparency = 0}, 0.2)
    Utility:Lerp(accentBar, {Transparency = 0}, 0.2)
    Utility:Lerp(icon, {Transparency = 0}, 0.2)
    Utility:Lerp(text, {Transparency = 0}, 0.2)

    return id
end

function Library.toasts:Remove(id)
    for i, e in pairs(self.active) do
        if e.id == id and not e.removed then
            e.removed = true
            Utility:Lerp(e.frame, {Transparency = 1}, 0.2)
            Utility:Lerp(e.border, {Transparency = 1}, 0.2)
            Utility:Lerp(e.accentBar, {Transparency = 1}, 0.2)
            Utility:Lerp(e.icon, {Transparency = 1}, 0.2)
            Utility:Lerp(e.text, {Transparency = 1}, 0.2)
            task.delay(0.2, function()
                if e.frame then e.frame:Remove() end
                if e.border then e.border:Remove() end
                if e.accentBar then e.accentBar:Remove() end
                if e.icon then e.icon:Remove() end
                if e.text then e.text:Remove() end
            end)
            table.remove(self.active, i)
            -- shift positions of remaining toasts
            self:Reposition()
            return
        end
    end
end

function Library.toasts:Reposition()
    local screen = Utility:GetScreenSize()
    local toastW = 220
    local toastH = 36
    local baseX  = screen.x - toastW - 8
    for i, e in pairs(self.active) do
        if e.frame and e.frame.Position then
            e.frame.Position = Vector2.new(baseX, screen.y - 8 - i * (toastH + 4))
            if e.border then
                e.border.Position = Utility:Position(0, 0, 0, 0, e.frame)
                e.border.Size = Utility:Size(1, -2, 1, -2, e.frame)
            end
            if e.accentBar then
                e.accentBar.Position = Vector2.new(e.frame.Position.x + 1, e.frame.Position.y + 1)
            end
            if e.icon then
                e.icon.Position = Vector2.new(e.frame.Position.x + 10, e.frame.Position.y + 9)
            end
            if e.text then
                e.text.Position = Vector2.new(e.frame.Position.x + 24, e.frame.Position.y + 9)
            end
        end
    end
end

function Library.toasts:Update(delta)
    for i = #self.active, 1, -1 do
        local e = self.active[i]
        if e.removed then continue end
        e.elapsed = e.elapsed + delta
        if e.elapsed >= e.duration then
            self:Remove(e.id)
        end
    end
end

function Library.toasts:Clear()
    for i = #self.active, 1, -1 do
        self:Remove(self.active[i].id)
    end
end

--[[ ============================================================
    Keybinds List
    ============================================================ ]]
function Library.keybindslist:Add(keybindName, keybindIndicator)
    self.entries[#self.entries + 1] = {
        name  = keybindName,
        indicator = keybindIndicator,
    }
    self:Update()
end

function Library.keybindslist:Remove(keybindName)
    for i, e in pairs(self.entries) do
        if e.name == keybindName then
            table.remove(self.entries, i)
            break
        end
    end
    self:Update()
end

function Library.keybindslist:Visibility()
    if not self.open then
        if self.frame then self.frame.Visible = false end
        return
    end
    if not self.frame then
        local screen = Utility:GetScreenSize()
        self.frame = Utility:Create("Frame", {Vector2.new(0, 0)}, {
            Size        = Vector2.new(160, 0),
            Position    = Vector2.new(screen.x - 170, 8),
            Color       = Color3.fromRGB(20, 20, 20),
            Filled      = true,
            Thickness   = 0,
            Transparency = 0,
            ZIndex      = 100,
        })
        local title = Utility:Create("TextLabel", {Vector2.new(0, 0), self.frame}, {
            Text         = "Keybinds",
            Size         = Theme.textsize,
            Font         = Theme.font,
            Color        = Theme.accent,
            OutlineColor = Theme.textborder,
            Outline      = true,
            Position     = Vector2.new(self.frame.Position.x + 8, self.frame.Position.y + 6),
            Transparency = 0,
            ZIndex       = 100,
        })
        self._title = title
    end
    self.frame.Visible = true
    self._title.Visible = true
    self:Update()
end

function Library.keybindslist:Hide()
    self.open = false
    if self.frame then self.frame.Visible = false end
    if self._title then self._title.Visible = false end
end

function Library.keybindslist:Update()
    if not self.open or not self.frame then return end
    -- rebuild contents
    for _, v in pairs(self._entryLabels or {}) do
        if v then v:Remove() end
    end
    self._entryLabels = {}

    local yOff = 26
    for _, e in pairs(self.entries) do
        local lbl = Utility:Create("TextLabel", {Vector2.new(0, 0), self.frame}, {
            Text         = e.name .. ": " .. e.indicator,
            Size         = 12,
            Font         = Theme.font,
            Color        = Theme.textcolor,
            OutlineColor = Theme.textborder,
            Outline      = true,
            Position     = Vector2.new(self.frame.Position.x + 8, self.frame.Position.y + yOff),
            Transparency = 0,
            ZIndex       = 100,
        })
        self._entryLabels[#self._entryLabels + 1] = lbl
        yOff = yOff + 16
    end

    self.frame.Size = Vector2.new(160, math.max(30, yOff))
end

--[[ ============================================================
    Stats overlay (FPS / ping)
    ============================================================ ]]
function Library.stats:Visibility()
    if not self.enabled then return end
    self.fpsText.Visible = true
    self.pingText.Visible = true
    self:UpdatePosition()
end

function Library.stats:Hide()
    self.fpsText.Visible = false
    self.pingText.Visible = false
end

function Library.stats:UpdatePosition()
    local screen = Utility:GetScreenSize()
    if self.fpsText.Visible then
        self.fpsText.Position = Vector2.new(screen.x - 120, screen.y - 34)
    end
    if self.pingText.Visible then
        self.pingText.Position = Vector2.new(screen.x - 120, screen.y - 18)
    end
end

function Library.stats:Update()
    if not self.enabled then return end
    self.fpsText.Text = "FPS: " .. Library.shared.fps
    self.pingText.Text = "Ping: " .. Library.shared.ping .. "ms"
end

--[[ ----------------------------------------------------------------
    Window:UpdateWatermark  (called from render loop)
    ---------------------------------------------------------------- ]]
function Library:UpdateWatermark()
    if self.watermark.enabled then
        self.watermark:Update()
    end
end

--[[ ----------------------------------------------------------------
    Window:UpdateStatsPosition  (called from render loop)
    ---------------------------------------------------------------- ]]
function Library:UpdateStatsPosition()
    self.stats:UpdatePosition()
end

--[[ ----------------------------------------------------------------
    Window:UpdateToasts  (called from render loop)
    ---------------------------------------------------------------- ]]
function Library:UpdateToasts(delta)
    self.toasts:Update(delta)
end

-- // make stats update on render loop too
-- (already handled via the global rs.RenderStepped at top)

-- // expose watermark toggle helper
function Library:SetWatermark(enabled)
    self.watermark.enabled = enabled
    if enabled then
        self.watermark:Visibility()
    else
        self.watermark:Hide()
    end
end

-- // expose stats toggle helper
function Library:SetStats(enabled)
    self.stats.enabled = enabled
    if enabled then
        self.stats:Visibility()
    else
        self.stats:Hide()
    end
end

-- // expose keybinds list toggle
function Library:ToggleKeybindsList()
    self.keybindslist.open = not self.keybindslist.open
    if self.keybindslist.open then
        self.keybindslist:Visibility()
    else
        self.keybindslist:Hide()
    end
end

-- // expose toast helpers on Window
function Library:Toast(message, style, duration)
    return self.toasts:Add(message, style, duration)
end

-- // set theme at runtime (re-colors accent-dependent elements)
function Library:SetTheme(newTheme)
    if newTheme.accent then
        Theme.accent = newTheme.accent
    end
    if newTheme.light_contrast then
        Theme.light_contrast = newTheme.light_contrast
    end
    if newTheme.dark_contrast then
        Theme.dark_contrast = newTheme.dark_contrast
    end
    if newTheme.outline then
        Theme.outline = newTheme.outline
    end
    if newTheme.inline then
        Theme.inline = newTheme.inline
    end
    if newTheme.textcolor then
        Theme.textcolor = newTheme.textcolor
    end
    if newTheme.textborder then
        Theme.textborder = newTheme.textborder
    end
    if newTheme.font then
        Theme.font = newTheme.font
    end
    if newTheme.textsize then
        Theme.textsize = newTheme.textsize
    end
    -- recolor title, tabs, etc.
    if self.title then
        self.title.Color = Theme.textcolor
        self.title.OutlineColor = Theme.textborder
    end
    if self.tabActive then
        local p = self.pages[self.tabActive]
        if p and p._tabText then
            p._tabText.Color = Theme.accent
        end
    end
end

-- ============================================================
-- Return the Library table
-- ============================================================
return Library
