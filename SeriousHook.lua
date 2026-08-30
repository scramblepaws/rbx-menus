-- SeriousHook/src/init.lua
-- Public entry. This file is the "root" when concatenating via build.lua.
-- It creates the SeriousHook namespace and attaches core subsystems.
-- Everything else (Theme, Util, Window, Page, Section, widgets, overlays, Toasts, Config)
-- is concatenated AFTER this in dependency order, each file closing over SeriousHook.

local SeriousHook = {}
SeriousHook.__index = SeriousHook

-- Folders (Splix-style isfolder/makefolder guards)
SeriousHook.folders = {
	main    = "serioushook",
	assets  = "serioushook/assets",
	configs = "serioushook/configs",
	toasts  = "serioushook/toasts",
}

if not isfolder(SeriousHook.folders.main) then makefolder(SeriousHook.folders.main) end
if not isfolder(SeriousHook.folders.assets) then makefolder(SeriousHook.folders.assets) end
if not isfolder(SeriousHook.folders.configs) then makefolder(SeriousHook.folders.configs) end

-- Shared state
SeriousHook.Flags    = {}
SeriousHook.Drawings = {}
SeriousHook.Hidden   = {}
SeriousHook.Connections = {}
SeriousHook._began  = {}
SeriousHook._ended  = {}
SeriousHook._changed = {}
SeriousHook.shared  = { initialized = false, fps = 0, ping = 0 }

-- Forward declarations (filled by concatenated modules)
SeriousHook.Theme        = {}
SeriousHook.Util         = {}
SeriousHook.Window       = {}
SeriousHook.Page         = {}
SeriousHook.Section      = {}
SeriousHook.MultiSection = {}
SeriousHook.Toasts       = {}

-- Expose as the return value for loadstring() usage
return SeriousHook
-- SeriousHook/src/Theme.lua
-- Theme table with live-update via Theme:Set + registry for animated transitions.
-- Opts into type colors for Toasts; extended palette beyond Splix.

local TH = {
	accent      = Color3.fromRGB(105, 90, 255),  -- SeriousHook violet
	surface0    = Color3.fromRGB(20, 20, 22),    -- dark_contrast
	surface1    = Color3.fromRGB(28, 28, 30),    -- light_contrast
	surface2    = Color3.fromRGB(36, 36, 38),
	border      = Color3.fromRGB(0, 0, 0),       -- outline
	borderMuted = Color3.fromRGB(50, 50, 52),    -- inline
	text        = Color3.fromRGB(255, 255, 255), -- textcolor
	textDim     = Color3.fromRGB(180, 180, 180),
	textOutline  = Color3.fromRGB(0, 0, 0),      -- textborder
	success     = Color3.fromRGB(70, 200, 120),
	warn        = Color3.fromRGB(255, 180, 0),
	error       = Color3.fromRGB(255, 70, 70),
	cursorOuter = Color3.fromRGB(10, 10, 10),    -- cursoroutline
	font        = 2,     -- Drawing.Font.Monospace
	textsize    = 13,
}

TH._listeners = {}

function TH:Set(key, value)
	if TH[key] == value then return end
	TH[key] = value
	for _, cb in ipairs(TH._listeners) do
		local ok, err = pcall(cb, key, value)
		if not ok then warn("[SeriousHook] Theme listener error: " .. tostring(err)) end
	end
end

function TH:OnChanged(callback)
	table.insert(TH._listeners, callback)
	return #TH._listeners
end

function TH:Unsubscribe(handle)
	TH._listeners[handle] = nil
end

-- Optional theme override surface for ramp/dim/extra; kept for back-compat.
TH.light_contrast = TH.surface1
TH.dark_contrast  = TH.surface0
TH.outline        = TH.border
TH.inline         = TH.borderMuted
TH.textcolor     = TH.text
TH.textborder    = TH.textOutline
TH.cursoroutline = TH.cursorOuter

return TH
-- SeriousHook/src/Util.lua
-- Drawing abstraction matching Splix patterns, plus a single LerpQueue so each
-- Util:Lerp pushes work instead of spawning a RenderStepped connection.

local U = {}

-- Registry for live-position updates (Window:Move iterates these).
U._drawings  = SeriousHook.Drawings
U._hidden    = SeriousHook.Hidden

-- Create a Drawing of kind with optional offset, props, and optional parent list.
-- kind: "Frame" | "TextLabel" | "Triangle" | "Image" | "Circle" | "Quad" | "Line"
-- offset: Vector2 (position offset from parent if parent given, else absolute)
-- props: table of Drawing properties to apply
-- parentList: optional table (e.g. section.visibleContent) to append the instance to
function U:Create(kind, offset, props, parentList)
	kind = kind or "Frame"
	offset = offset or Vector2.new(0, 0)
	props = props or {}

	local instance
	local typeLower = kind:lower()

	if typeLower == "frame" then
		instance = Drawing.new("Square")
		instance.Visible = true
		instance.Filled = true
		instance.Thickness = 0
		instance.Color = Color3.new(1, 1, 1)
		instance.Size = Vector2.new(100, 100)
		instance.Position = Vector2.new(0, 0)
		instance.ZIndex = 50
	elseif typeLower == "textlabel" then
		instance = Drawing.new("Text")
		instance.Font = Theme.font
		instance.Visible = true
		instance.Outline = true
		instance.Center = false
		instance.Color = Theme.textcolor
		instance.ZIndex = 50
	elseif typeLower == "triangle" then
		instance = Drawing.new("Triangle")
		instance.Visible = true
		instance.Filled = false
		instance.Thickness = 2
		instance.Color = Color3.new(1, 1, 1)
		instance.ZIndex = 50
	elseif typeLower == "image" then
		instance = Drawing.new("Image")
		instance.Size = Vector2.new(12, 19)
		instance.Position = Vector2.new(0, 0)
		instance.Visible = true
		instance.ZIndex = 50
	elseif typeLower == "circle" then
		instance = Drawing.new("Circle")
		instance.Visible = false
		instance.Color = Color3.fromRGB(255, 0, 0)
		instance.Thickness = 1
		instance.NumSides = 30
		instance.Filled = true
		instance.ZIndex = 50
		instance.Radius = 50
	elseif typeLower == "quad" then
		instance = Drawing.new("Quad")
		instance.Visible = false
		instance.Color = Color3.new(1, 1, 1)
		instance.Thickness = 1.5
		instance.ZIndex = 50
		instance.Filled = false
	elseif typeLower == "line" then
		instance = Drawing.new("Line")
		instance.Visible = false
		instance.Color = Color3.new(1, 1, 1)
		instance.Thickness = 1.5
		instance.ZIndex = 50
	else
		warn("[SeriousHook] Util:Create - unknown kind: " .. kind)
		return nil
	end

	-- Apply default Transparency (Splix: initialized ? 1 : 0 so it fades-in cleanly)
	if SeriousHook.shared.initialized then
		instance.Transparency = props.Transparency or 1
	else
		instance.Transparency = props.Transparency or 0
	end

	local hidden = false
	for k, v in pairs(props) do
		if k == "Hidden" or k == "hidden" then
			hidden = true
		else
			instance[k] = v
		end
	end

	if instance then
		if not hidden then
			table.insert(U._drawings, { instance, offset, props.Transparency or 1 })
		else
			table.insert(U._hidden, { instance })
		end
		if parentList then
			table.insert(parentList, instance)
		end
		return instance
	end
	return nil
end

-- Update the offset stored alongside a drawing (used by Window:Move).
function U:UpdateOffset(instance, newOffset)
	for _, entry in ipairs(U._drawings) do
		if entry[1] == instance then
			entry[2] = newOffset
			break
		end
	end
end

-- Update stored transparency for a drawing.
function U:UpdateTransparency(instance, newAlpha)
	for _, entry in ipairs(U._drawings) do
		if entry[1] == instance then
			entry[3] = newAlpha
			break
		end
	end
end

-- Remove a drawing from registry and destroy it.
function U:Remove(instance, hidden)
	local target = hidden and U._hidden or U._drawings
	local idx = nil
	for i, entry in ipairs(target) do
		if entry[1] == instance then
			idx = i
			break
		end
	end
	if idx then
		table.remove(target, idx)
	end
	if instance.Remove and instance.__OBJECT_EXISTS then
		instance:Remove()
	end
end

-- Viewport-relative size. If instance given, scales off its Size; else off ViewportSize.
function U:Size(xScale, xOffset, yScale, yOffset, instance)
	if instance then
		return Vector2.new(
			xScale * instance.Size.x + xOffset,
			yScale * instance.Size.y + yOffset
		)
	end
	local vx, vy = workspace.CurrentCamera.ViewportSize.x, workspace.CurrentCamera.ViewportSize.y
	return Vector2.new(
		xScale * vx + xOffset,
		yScale * vy + yOffset
	)
end

-- Viewport-relative position. If instance given, relative to its Position+Size; else absolute.
function U:Position(xScale, xOffset, yScale, yOffset, instance)
	if instance then
		return Vector2.new(
			instance.Position.x + xScale * instance.Size.x + xOffset,
			instance.Position.y + yScale * instance.Size.y + yOffset
		)
	end
	local vx, vy = workspace.CurrentCamera.ViewportSize.x, workspace.CurrentCamera.ViewportSize.y
	return Vector2.new(
		xScale * vx + xOffset,
		yScale * vy + yOffset
	)
end

-- Hit-test a rectangle (x1,y1,x2,y2) against current mouse.
function U:MouseOverDrawing(rect)
	local mx, my = userInputService:GetMouseLocation().X, userInputService:GetMouseLocation().Y
	return mx >= rect[1] and mx <= (rect[3] - rect[1]) and my >= rect[2] and my <= (rect[4] - rect[2])
end

-- Measure text by creating a hidden TextLabel (Splix trick).
function U:GetTextBounds(text, textSize, font)
	local tb = Vector2.new(0, 0)
	local tl = U:Create("TextLabel", Vector2.new(0, 0), {
		Text = text,
		Size = textSize or Theme.textsize,
		Font = font or Theme.font,
		Hidden = true,
	})
	if tl then
		tb = tl.TextBounds
		U:Remove(tl, true)
	end
	return tb
end

-- Screen size helper.
function U:GetScreenSize()
	return workspace.CurrentCamera.ViewportSize
end

-- Load an image asset (cached to serioushook/assets).
function U:LoadImage(instance, imageName, imageLink)
	if instance and instance.Data ~= nil then
		return
	end
	local data
	local path = SeriousHook.folders.assets .. "/" .. imageName .. ".png"
	if isfile(path) then
		data = readfile(path)
	elseif imageLink then
		data = game:HttpGet(imageLink)
		writefile(path, data)
	else
		return
	end
	if data and instance then
		instance.Data = data
	end
end

-- Lerp pushes to the shared queue (single RenderStepped drives it).
function U:Lerp(instance, to, time)
	if not time or time <= 0 then return end
	table.insert(SeriousHook._lerpQueue, {
		instance = instance,
		from = instance[to and "Transparency" or "Position"] and instance["Transparency"] or instance.Position,
		to = to,
		dur = time,
		elapsed = 0,
		prop = to and "Transparency" or nil,
	})
end

-- Combine two arrays (Splix helper).
function U:Combine(t1, t2)
	local out = {}
	for _, v in ipairs(t1) do table.insert(out, v) end
	for _, v in ipairs(t2) do table.insert(out, v) end
	return out
end

-- Lightweight table.find.
function U:Find(t, value)
	for i, v in ipairs(t) do
		if v == value then return i end
	end
	return nil
end

-- Clamp (Roblox math.clamp available, but keep local alias for portability).
local math_clamp = math.clamp or function(x, a, b) return x < a and a or x > b and b or x end
U.clamp = math_clamp

return U
-- SeriousHook/src/Window.lua
-- Main window constructor. Builds layered frames, handles fade/drag/popups,
-- and owns the single RenderStepped loop (cursor + lerp queue + throttles).

local UIS = userInputService
local RS = runService
local WS = workspace

SeriousHook.Window = function(opts)
	opts = opts or {}
	local title = opts.title or opts.Title or opts.name or opts.Name or "SeriousHook"
	local size  = opts.size  or opts.Size  or Vector2.new(540, 620)
	local accent = opts.accent or opts.Accent or Theme.accent
	local fadeKey = opts.fadeKey or opts.FadeKey or Enum.KeyCode.RightShift
	local draggable = opts.draggable ~= false

	Theme:Set("accent", accent)

	local window = {
		pages          = {},
		isVisible      = false,
		fadeKey        = fadeKey,
		draggable      = draggable,
		currentPage    = nil,
		fading         = false,
		dragging       = false,
		dragOffset     = Vector2.new(0, 0),
		currentContent = {},
		overlays       = {},
		_size          = size,
		title          = title,
	}

	local function getScreen()
		return WS.CurrentCamera.ViewportSize
	end

	local function mousePos()
		return UIS:GetMouseLocation()
	end

	local function overRect(x1, y1, x2, y2)
		local m = mousePos()
		return m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2
	end

	-- Build layered frames
	local mainFrame = Util:Create("Frame", Vector2.zero, {
		Size     = size,
		Position = Vector2.new((getScreen().X - size.X) / 2, (getScreen().Y - size.Y) / 2),
		Color    = Theme.border,
		Visible  = false,
	})
	window.mainFrame = mainFrame

	local accentStrip = Util:Create("Frame", Vector2.zero, {
		Size     = Util:Size(1, 0, 0, -2, mainFrame),
		Position = Util:Position(0, 0, 0, 1, mainFrame),
		Color    = Theme.accent,
		Visible  = false,
	})

	local outer = Util:Create("Frame", Vector2.one, mainFrame, {
		Size     = Util:Size(1, -2, 1, -2, mainFrame),
		Position = Util:Position(0, 1, 0, 1, mainFrame),
		Color    = Theme.surface1,
		Visible  = false,
	})

	local innerBorder = Util:Create("Frame", Vector2.one, outer, {
		Size     = Util:Size(1, -2, 1, -2, outer),
		Position = Util:Position(0, 1, 0, 1, outer),
		Color    = Theme.borderMuted,
		Visible  = false,
	})

	local outline2 = Util:Create("Frame", Vector2.one, innerBorder, {
		Size     = Util:Size(1, -2, 1, -2, innerBorder),
		Position = Util:Position(0, 1, 0, 1, innerBorder),
		Color    = Theme.border,
		Visible  = false,
	})

	local tabHost = Util:Create("Frame", Vector2.one, outline2, {
		Size     = Util:Size(1, -2, 1, -2, outline2),
		Position = Util:Position(0, 1, 0, 1, outline2),
		Color    = Theme.surface0,
		Visible  = false,
	})
	window.tabHost = tabHost

	local titleLabel = Util:Create("TextLabel", Vector2.new(4, 2), outline2, {
		Text           = title,
		Size           = Theme.textsize,
		Font           = Theme.font,
		Color          = Theme.textcolor,
		OutlineColor   = Theme.textOutline,
		Position       = Util:Position(0, 4, 0, 2, outline2),
		Visible        = false,
	})
	window.titleLabel = titleLabel
	window.outline2 = outline2
	window.outer = outer
	window.innerBorder = innerBorder
	window.accentStrip = accentStrip

	local mainHeaderH = 20

	-- Move helper: repositions all drawings by stored offset
	function window:Move(vec)
		for _, entry in ipairs(SeriousHook.Drawings) do
			local inst = entry[1]
			local off = entry[2]
			if off and off.Y then
				inst.Position = Vector2.new(vec.X + off.X, vec.Y + off.Y)
			else
				inst.Position = vec
			end
		end
	end

	-- Fade: toggle visibility + lerp transparency
	function window:Fade()
		if window.fading then return end
		window.fading = true
		window.isVisible = not window.isVisible

		local cur = window.overlays.cursor
		if cur and cur.cursor then
			local a = window.isVisible and 0 or 1
			cur.cursor.Transparency      = a
			if cur.cursorInline then cur.cursorInline.Transparency = a end
		end
		UIS.MouseIconEnabled = not window.isVisible

		local target = window.isVisible and 1 or 0
		for _, entry in ipairs(SeriousHook.Drawings) do
			local inst = entry[1]
			if inst and inst.Transparency ~= nil then
				local from = inst.Transparency
				Util:Lerp(inst, {Transparency = target}, 0.25, inst.Transparency, target)
			end
		end

		local wm = window.overlays.watermark
		if wm and wm.vis then wm.vis(window.isVisible) end

		window.fading = false
	end

	-- Close whatever popup is open
	function window:ClosePopups()
		local cc = window.currentContent
		if cc.dropdown and cc.dropdown.open then
			cc.dropdown.open = false
			Util:LoadImage(cc.dropdown.img, "arrow_down", "https://i.imgur.com/tVqy0nL.png")
			for _, v in ipairs(cc.dropdown.holderDrawings) do Util:Remove(v) end
			cc.dropdown.holderDrawings = {}
			cc.dropdown.holderButtons = {}
			cc.dropdown.holderInline = nil
			cc.frame = nil
			cc.dropdown = nil
		elseif cc.multiDropdown and cc.multiDropdown.open then
			cc.multiDropdown.open = false
			Util:LoadImage(cc.multiDropdown.img, "arrow_down", "https://i.imgur.com/tVqy0nL.png")
			for _, v in ipairs(cc.multiDropdown.holderDrawings) do Util:Remove(v) end
			cc.multiDropdown.holderDrawings = {}
			cc.multiDropdown.holderButtons = {}
			cc.multiDropdown.holderInline = nil
			cc.frame = nil
			cc.multiDropdown = nil
		elseif cc.colorpicker and cc.colorpicker.open then
			cc.colorpicker.open = false
			for _, v in ipairs(cc.colorpicker.holderDrawings) do Util:Remove(v) end
			cc.colorpicker.holderDrawings = {}
			cc.colorpicker.holderInline = nil
			cc.frame = nil
			cc.colorpicker = nil
		elseif cc.keybind and cc.keybind.open then
			cc.keybind.open = false
			local mm = cc.keybind.modemenu
			if mm then
				for _, v in ipairs(mm.drawings) do Util:Remove(v) end
				mm.drawings = {}
				mm.buttons = {}
				mm.frame = nil
			end
			cc.frame = nil
			cc.keybind = nil
		end
	end

	function window:IsOverPopup()
		local cc = window.currentContent
		if cc.frame then
			local p = cc.frame.Position
			local s = cc.frame.Size
			return overRect(p.X - 2, p.Y - 2, p.X + s.X + 2, p.Y + s.Y + 2)
		end
		return false
	end

	-- Unload: disconnect + remove all drawings
	function window:Unload()
		for _, conn in ipairs(SeriousHook.Connections) do
			if conn and conn.Disconnect then conn:Disconnect() end
		end
		SeriousHook.Connections = {}

		for i = #SeriousHook.Hidden, 1, -1 do
			local e = SeriousHook.Hidden[i]
			if e and e[1] and e[1].Remove and e[1].__OBJECT_EXISTS then
				e[1]:Remove()
				SeriousHook.Hidden[i] = nil
			end
		end

		for i = #SeriousHook.Drawings, 1, -1 do
			local e = SeriousHook.Drawings[i]
			if e and e[1] and e[1].Remove and e[1].__OBJECT_EXISTS then
				e[1]:Remove()
				SeriousHook.Drawings[i] = nil
			end
		end

		SeriousHook._began   = {}
		SeriousHook._ended   = {}
		SeriousHook._changed = {}
		SeriousHook._lerpQueue = {}
		SeriousHook.shared.initialized = false
		UIS.MouseIconEnabled = true
	end

	-- Initialize: show first page, build overlays, attach input, start render loop
	function window:Initialize()
		if window.pages[1] then window.pages[1]:Show() end
		SeriousHook.shared.initialized = true
		window:Watermark()
		window:Keylist()
		window:Cursor()
		window.isVisible = true
		window:Fade()

		SeriousHook.Connections[#SeriousHook.Connections + 1] = UIS.InputBegan:Connect(function(input)
			for _, fn in ipairs(SeriousHook._began) do
				if not window.dragging then
					local ok, err = pcall(fn, input)
					if not ok then warn("[SH] beGan error:", err) end
				else break end
			end
		end)
		SeriousHook.Connections[#SeriousHook.Connections + 1] = UIS.InputEnded:Connect(function(input)
			for _, fn in ipairs(SeriousHook._ended) do
				local ok, err = pcall(fn, input)
				if not ok then warn("[SH] enDed error:", err) end
			end
		end)
		SeriousHook.Connections[#SeriousHook.Connections + 1] = UIS.InputChanged:Connect(function()
			for _, fn in ipairs(SeriousHook._changed) do
				local ok, err = pcall(fn)
				if not ok then warn("[SH] chan ged error:", err) end
			end
		end)
		SeriousHook.Connections[#SeriousHook.Connections + 1] = WS.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local sz = getScreen()
			window:Move(Vector2.new((sz.X - size.X) / 2, (sz.Y - size.Y) / 2))
		end)

		local lastWM = 0
		local lastToast = 0
		SeriousHook.Connections[#SeriousHook.Connections + 1] = RS.RenderStepped:Connect(function(delta)
			-- Cursor
			local cur = window.overlays.cursor
			if cur and cur.cursor then
				local m = mousePos()
				cur.cursor.PointA = Vector2.new(m.X, m.Y)
				cur.cursor.PointB = Vector2.new(m.X + 16, m.Y + 6)
				cur.cursor.PointC = Vector2.new(m.X + 6, m.Y + 16)
				if cur.cursorInline then
					cur.cursorInline.PointA = Vector2.new(m.X, m.Y)
					cur.cursorInline.PointB = Vector2.new(m.X + 16, m.Y + 6)
					cur.cursorInline.PointC = Vector2.new(m.X + 6, m.Y + 16)
				end
			end

			-- Lerp queue
			for i = #SeriousHook._lerpQueue, 1, -1 do
				local job = SeriousHook._lerpQueue[i]
				job.elapsed = job.elapsed + delta
				local t = job.elapsed / job.dur
				if t >= 1 then
					t = 1
					if job.prop == "Transparency" then
						job.inst.Transparency = job.to
					elseif job.prop == "Position" then
						job.inst.Position = job.to
					end
					table.remove(SeriousHook._lerpQueue, i)
				else
					if job.prop == "Transparency" then
						job.inst.Transparency = job.from + (job.to - job.from) * t
					elseif job.prop == "Position" then
						job.inst.Position = Vector2.new(
							job.from.X + (job.to.X - job.from.X) * t,
							job.from.Y + (job.to.Y - job.from.Y) * t
						)
					end
				end
			end

			-- Watermark throttle 0.25s
			lastWM = lastWM + delta
			if lastWM >= 0.25 then
				lastWM = 0
				SeriousHook.shared.fps = math.round(1 / (delta + 0.0001))
				if window.overlays.watermark and window.overlays.watermark.update then
					window.overlays.watermark.update()
				end
			end

			-- Toast throttle 0.05s
			lastToast = lastToast + delta
			if lastToast >= 0.05 then
				lastToast = 0
				if SeriousHook.Toasts and SeriousHook.Toasts._tick then
					SeriousHook.Toasts._tick(delta)
				end
			end
		end)
	end

	-- Drag handling
	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			and window.isVisible and not window.fading
			and overRect(mainFrame.Position.X, mainFrame.Position.Y,
				mainFrame.Position.X + mainFrame.Size.X,
				mainFrame.Position.Y + mainHeaderH) then
			window.dragging = true
			local m = mousePos()
			window.dragOffset = Vector2.new(m.X - mainFrame.Position.X, m.Y - mainFrame.Position.Y)
		end
	end

	SeriousHook._ended[#SeriousHook._ended + 1] = function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and window.dragging then
			window.dragging = false
			window.dragOffset = Vector2.zero
		end
	end

	SeriousHook._changed[#SeriousHook._changed + 1] = function()
		if window.dragging and window.isVisible then
			local m = mousePos()
			local screen = getScreen()
			local nx = math.clamp(m.X - window.dragOffset.X, 5, screen.X - size.X - 5)
			local ny = math.clamp(m.Y - window.dragOffset.Y, 5, screen.Y - size.Y - 5)
			window:Move(Vector2.new(nx, ny))
		end
	end

	-- Fade key
	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.KeyCode == window.fadeKey then window:Fade() end
	end

	return window
end

-- Ergonomic factory: Win:Page{...} delegates to Page module
do
	local PageMod = SeriousHook.Page
	local origWindow = SeriousHook.Window
	SeriousHook.Window = function(...)
		local win = origWindow(...)
		function win:Page(info)
			local page = PageMod(self, info)
			SeriousHook._began[#SeriousHook._began + 1] = function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					and win.isVisible
					and SeriousHook.Util:MouseOverDrawing({
						page.pageButton.Position.X,
						page.pageButton.Position.Y,
						page.pageButton.Position.X + page.pageButton.Size.X,
						page.pageButton.Position.Y + page.pageButton.Size.Y
					})
					and win.currentPage ~= page then
					page:Show()
				end
			end
			return page
		end
		return win
	end
end
-- SeriousHook/src/Page.lua
-- Pages: pills in Window.tabHost at {4, 24}. Show toggles currentPage + section visibility.

SeriousHook.Page = function(window, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "New Page"

	local page = {
		window    = window,
		name      = name,
		open      = false,
		sections  = {},
		page_button       = nil,
		page_button_inline = nil,
		page_button_color  = nil,
		page_button_title  = nil,
	}

	local tb = SeriousHook.Util:GetTextBounds(name, Theme.textsize, Theme.font)

	-- x position accumulates previous pills
	local x = 4
	for _, prev in ipairs(window.pages) do
		local prevW = prev.page_button and prev.page_button.Size.X or 0
		x = x + prevW + 2
	end

	-- pill: outline > inline > color
	local pill = SeriousHook.Util:Create("Frame", Vector2.new(x, 4), window.tabHost, {
		Size     = Vector2.new(tb.X + 20, 21),
		Position = Vector2.new(x, 4),
		Color    = Theme.border,
		Visible  = false,
	})
	page.page_button = pill

	local pillInline = SeriousHook.Util:Create("Frame", Vector2.new(1, 1), pill, {
		Size     = Vector2.new(1, -2, 1, -1, pill),
		Position = Vector2.new(1, 1),
		Color    = Theme.borderMuted,
		Visible  = false,
	})
	page.page_button_inline = pillInline

	local pillColor = SeriousHook.Util:Create("Frame", Vector2.new(1, 1), pillInline, {
		Size     = Vector2.new(1, -2, 1, -1, pillInline),
		Position = Vector2.new(1, 1),
		Color    = Theme.surface0,  -- closed color
		Visible  = false,
	})
	page.page_button_color = pillColor

	local pillTitle = SeriousHook.Util:Create("TextLabel", Vector2.new(
		SeriousHook.Util:Position(0.5, 0, 0, 2, pillColor).X - tb.X/2,
		2
	), pillColor, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		Center       = true,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(
			SeriousHook.Util:Position(0.5, 0, 0, 2, pillColor).X - tb.X/2,
			2
		),
		Visible      = false,
	})
	page.page_button_title = pillTitle

	window.pages[#window.pages + 1] = page

	function page:Show()
		if window.currentPage and window.currentPage ~= page then
			local prev = window.currentPage
			prev.page_button_color.Size = Vector2.new(
				prev.page_button_inline.Size.X - 2,
				prev.page_button_inline.Size.Y - 1
			)
			prev.page_button_color.Color = Theme.surface0
			prev.open = false
			-- hide prev sections
			for _, sec in ipairs(prev.sections) do
				for _, v in ipairs(sec.visibleContent) do
					v.Visible = false
				end
			end
			window:ClosePopups()
		end

		window.currentPage = page
		page.page_button_color.Size = Vector2.new(
			page.page_button_inline.Size.X - 2,
			page.page_button_inline.Size.Y
		)
		page.page_button_color.Color = Theme.surface1  -- open color
		page.open = true

		for _, sec in ipairs(page.sections) do
			for _, v in ipairs(sec.visibleContent) do
				v.Visible = true
			end
		end

		page:Update()
	end

	function page:Update()
		page.sectionOffset = page.sectionOffset or { left = 0, right = 0 }
		page.sectionOffset.left  = 0
		page.sectionOffset.right = 0
		for _, sec in ipairs(page.sections) do
			local side = sec.side or "left"
			local off = page.sectionOffset[side]
			if sec.section_inline then
				SeriousHook.Util:UpdateOffset(sec.section_inline, Vector2.new(
					side == "right" and (window.tabHost.Size.X/2 + 2) or 5,
					5 + off
				))
			end
			page.sectionOffset[side] = page.sectionOffset[side] + (sec.section_inline and sec.section_inline.Size.Y or 0) + 5
		end
		-- keep window centered (Section layers also reposition via Window:Move in drag, but pages/Sections do it here too)
		window:Move(window.mainFrame.Position)
	end

	page.sectionOffset = { left = 0, right = 0 }

	return setmetatable(page, { __index = page })
end

-- Page factory attached to Window for ergonomics: Win:Page{...}
do
	local origWindow = SeriousHook.Window
	SeriousHook.Window = function(...)
		local win = origWindow(...)
		function win:Page(info)
			local page = SeriousHook.Page(self, info)
			-- connect click on pill
			SeriousHook._began[#SeriousHook._began + 1] = function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					and win.isVisible
					and SeriousHook.Util:MouseOverDrawing({
						page.page_button.Position.X,
						page.page_button.Position.Y,
						page.page_button.Position.X + page.page_button.Size.X,
						page.page_button.Position.Y + page.page_button.Size.Y
					})
					and win.currentPage ~= page
				then
					page:Show()
				end
			end
			return page
		end
		return win
	end
end
-- Helper to wrap any function into a form that can be placed anywhere.
-- SeriousHook exposes a global SeriousHook namespace - each widget adds a
-- method to the Section prototype by closing over SectionProto.
local SectionProto = {}
SectionProto.__index = SectionProto
SeriousHook.SectionProto = SectionProto

-- Section constructor (must be defined before widgets use it)
SeriousHook.Section = function(page, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "New Section"
	local side = (info.side or info.Side or "left"):lower()

	local window = page.window
	local section = {
		window         = window,
		page           = page,
		name           = name,
		side           = side,
		visibleContent = {},
		currentAxis    = 20,
	}
	SeriousHook.Util:Create("Frame", Vector2.new(
		side == "right" and (window.tabHost.Size.X / 2 + 2) or 5,
		5 + (page.sectionOffset[side] or 0)
	), window.tabHost, {
		Size      = SeriousHook.Util:Size(0.5, -7, 0, 22, window.tabHost),
		Position  = Vector2.new(
			side == "right" and (window.tabHost.Size.X / 2 + 2) or 5,
			5 + (page.sectionOffset[side] or 0)
		),
		Color     = Theme.borderMuted,
		Visible   = false,
	}, section.visibleContent)
	section.section_inline = section.visibleContent[#section.visibleContent]

	local outline = SeriousHook.Util:Create("Frame", Vector2.one, section.section_inline, {
		Size      = Vector2.new(1, -2, 1, -2, section.section_inline),
		Position  = Vector2.one,
		Color     = Theme.border,
		Visible   = false,
	}, section.visibleContent)
	section.section_outline = outline

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.surface0,
		Visible   = false,
	}, section.visibleContent)
	section.section_frame = frame

	local accent = SeriousHook.Util:Create("Frame", Vector2.zero, frame, {
		Size      = Vector2.new(1, 0, 0, 2, frame),
		Position  = Vector2.zero,
		Color     = Theme.accent,
		Visible   = false,
	}, section.visibleContent)
	section.section_accent = accent

	local title = SeriousHook.Util:Create("TextLabel", Vector2.new(3, 3), frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(3, 3),
		Visible      = false,
	}, section.visibleContent)
	section.section_title = title

	page.sections = page.sections or {}
	page.sections[#page.sections + 1] = section

	page.sectionOffset = page.sectionOffset or { left = 0, right = 0 }
	page.sectionOffset[side] = (page.sectionOffset[side] or 0) + 100 + 5

	-- Each widget's method will mutate section.currentAxis and call Update.
	function section:Update()
		local h = math.max(22, section.currentAxis + 4)
		self.section_inline.Size = SeriousHook.Util:Size(0.5, -7, 0, h, self.window.tabHost)
		self.section_outline.Size = Vector2.new(1, -2, 1, -2, self.section_inline)
		self.section_frame.Size = Vector2.new(1, -2, 1, -2, self.section_outline)
		self.section_accent.Size = Vector2.new(1, 0, 0, 2, self.section_frame)
		self.section_title.Position = Vector2.new(3, 3)
	end

	return setmetatable(section, SectionProto)
end

-- MultiSection: N tabs sharing one host; returns unpackable sections.
SeriousHook.MultiSection = function(page, info)
	info = info or {}
	local tabs = info.tabs or info.Tabs or {}
	local side = (info.side or info.Side or "left"):lower()
	local height = info.height or info.Height or 150

	local window = page.window
	local ms = {
		window        = window,
		page          = page,
		tabs          = tabs,
		side          = side,
		height        = height,
		current       = nil,
		backup        = {},
		visibleContent = {},
		sections      = {},
		headerHeight  = 17,
	}

	page.sections = page.sections or {}

	local xBase = side == "right" and (window.tabHost.Size.X / 2 + 2) or 5
	local yBase = 5 + (page.sectionOffset[side] or 0)

	local secInline = SeriousHook.Util:Create("Frame", Vector2.new(xBase, yBase), window.tabHost, {
		Size      = SeriousHook.Util:Size(0.5, -7, 0, height, window.tabHost),
		Position  = Vector2.new(xBase, yBase),
		Color     = Theme.borderMuted,
		Visible   = false,
	}, ms.visibleContent)

	local secOutline = SeriousHook.Util:Create("Frame", Vector2.one, secInline, {
		Size      = Vector2.new(1, -2, 1, -2, secInline),
		Position  = Vector2.one,
		Color     = Theme.border,
		Visible   = false,
	}, ms.visibleContent)

	local secFrame = SeriousHook.Util:Create("Frame", Vector2.one, secOutline, {
		Size      = Vector2.new(1, -2, 1, -2, secOutline),
		Position  = Vector2.one,
		Color     = Theme.surface0,
		Visible   = false,
	}, ms.visibleContent)

	local secAccent = SeriousHook.Util:Create("Frame", Vector2.zero, secFrame, {
		Size      = Vector2.new(1, 0, 0, 2, secFrame),
		Position  = Vector2.zero,
		Color     = Theme.accent,
		Visible   = false,
	}, ms.visibleContent)

	local backFrame = SeriousHook.Util:Create("Frame", Vector2.new(0, 2), secFrame, {
		Size      = Vector2.new(1, 0, 0, ms.headerHeight, secFrame),
		Position  = Vector2.new(0, 0, 0, 2),
		Color     = Theme.surface1,
		Visible   = false,
	}, ms.visibleContent)

	local bottomLine = SeriousHook.Util:Create("Frame", Vector2.new(0, ms.headerHeight - 1), secFrame, {
		Size      = Vector2.new(1, 0, 0, 1, secFrame),
		Position  = Vector2.new(0, ms.headerHeight - 1),
		Color     = Theme.border,
		Visible   = false,
	}, ms.visibleContent)

	local xAxis = 0
	for i, tabName in ipairs(tabs) do
		local tb = SeriousHook.Util:GetTextBounds(tabName, Theme.textsize, Theme.font)
		local tabFrame = SeriousHook.Util:Create("Frame", Vector2.new(xAxis, 0), backFrame, {
			Size      = SeriousHook.Util:Size(0, tb.X + 14, 1, -1, backFrame),
			Position  = Vector2.new(xAxis, 0),
			Color     = i == 1 and Theme.surface0 or Theme.surface1,
			Visible   = false,
		}, ms.visibleContent)
		local tabLine = SeriousHook.Util:Create("Frame", Vector2.new(tabFrame.Size.X, 0), tabFrame, {
			Size      = Vector2.new(0, 1, 1, 0, tabFrame),
			Position  = Vector2.new(tabFrame.Size.X, 0),
			Color     = Theme.outline,
			Visible   = false,
		}, ms.visibleContent)
		local tabTitle = SeriousHook.Util:Create("TextLabel", Vector2.new(
			tabFrame.Size.X / 2 - tb.X / 2, 1
		), tabFrame, {
			Text         = tabName,
			Size         = Theme.textsize,
			Font         = Theme.font,
			Color        = Theme.textcolor,
			OutlineColor = Theme.textOutline,
			Center       = true,
			Position     = Vector2.new(tabFrame.Size.X / 2 - tb.X / 2, 1),
			Visible      = false,
		}, ms.visibleContent)
		xAxis = xAxis + tb.X + 15

		-- Create a hidden section that widgets will be inserted into
		local sub = SeriousHook.Section(page, { name = tabName, side = side })
		sub.msection_frame    = tabFrame
		sub.msection_line     = tabLine
		sub.msection_title    = tabTitle
		sub.msection_bottomline = tabLine
		sub._msSection = true
		sub._msParent  = ms
		ms.sections[#ms.sections + 1] = sub

		if i == 1 then ms.current = sub end
	end

	for _, v in ipairs(ms.visibleContent) do
		ms.backup[#ms.backup + 1] = v
	end

	function ms:SetActive(section)
		if self.current == section then return end
		if self.current then
			for _, draw in ipairs(self.current.visibleContent) do
				draw.Visible = false
			end
		end
		self.current = section
		self.visibleContent = {}
		for _, draw in ipairs(self.backup) do
			draw.Visible = true
			self.visibleContent[#self.visibleContent + 1] = draw
		end
		for _, draw in ipairs(section.visibleContent) do
			draw.Visible = true
			self.visibleContent[#self.visibleContent + 1] = draw
		end
	end

	ms:SetActive(ms.current)

	page.sectionOffset = page.sectionOffset or { left = 0, right = 0 }
	page.sectionOffset[side] = (page.sectionOffset[side] or 0) + 100 + 5

	return table.unpack(ms.sections)
end

-- Click handling for MultiSection tabs
do
	local function AddTabClick(ms)
		SeriousHook._began[#SeriousHook._began + 1] = function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if not ms.window.isVisible then return end
			local page = ms.page
			if not (page.open and page.window.currentPage == page) then return end
			for _, sub in ipairs(ms.sections) do
				local m = SeriousHook.Util:MouseLocation()
				local frame = sub.msection_frame
				if frame
					and m.X >= frame.Position.X
					and m.X <= frame.Position.X + frame.Size.X
					and m.Y >= frame.Position.Y
					and m.Y <= frame.Position.Y + frame.Size.Y
				then
					if ms.current ~= sub then
						ms:SetActive(sub)
						return
					end
				end
			end
		end
	end

	function SectionProto:_attachMultiSectionClicks(ms)
		if not ms._clickAttached then
			AddTabClick(ms)
			ms._clickAttached = true
		end
	end
end
-- SeriousHook/src/Config.lua
-- Flags registry and persistence helpers.

local HttpService = game:GetService("HttpService")

-- Register a flag so it can be read/written via GetConfig/LoadConfig.
-- flag: string key (nil => no persistence for this widget)
-- getter: function() -> value
-- setter: function(value) -> ()
-- serializer: optional function(value) -> storable
-- deserializer: optional function(storable) -> value
function SeriousHook.Config:Register(flag, getter, setter, serializer, deserializer)
	if not flag then return end
	if typeof(flag) ~= "string" then
		warn("[SH] Config:Register - flag must be a string, got " .. typeof(flag))
		return
	end
	local entry = {
		get = getter,
		set = setter,
		serialize = serializer,
		deserialize = deserializer,
	}
	SeriousHook.Flags[flag] = entry
end

-- Get full config as a table (serializable JSON).
function SeriousHook.Config:GetConfig()
	local config = {}
	for flag, entry in pairs(SeriousHook.Flags) do
		if entry.serialize then
			config[flag] = entry.serialize(entry.get())
		else
			config[flag] = entry.get()
		end
	end
	return config
end

-- Apply a config table.
function SeriousHook.Config:LoadConfig(config)
	if typeof(config) ~= "table" then
		warn("[SH] Config:LoadConfig - expected table")
		return
	end
	for flag, value in pairs(config) do
		local entry = SeriousHook.Flags[flag]
		if entry then
			local v = value
			if entry.deserialize then
				v = entry.deserialize(value)
			end
			entry.set(v)
		end
	end
end

-- Save config to file as JSON.
function SeriousHook.Config:SaveConfig(name)
	local config = SeriousHook.Config:GetConfig()
	local json = HttpService:JSONEncode(config)
	local path = SeriousHook.folders.configs .. "/" .. name .. ".json"
	writefile(path, json)
	return json
end

-- Load config from file.
function SeriousHook.Config:LoadConfigFile(name)
	local path = SeriousHook.folders.configs .. "/" .. name .. ".json"
	if not isfile(path) then
		warn("[SH] Config:LoadConfigFile - file not found: " .. path)
		return
	end
	local json = readfile(path)
	local config = HttpService:JSONDecode(json)
	SeriousHook.Config:LoadConfig(config)
	return config
end

-- List saved configs.
function SeriousHook.Config:ListConfigs()
	local result = {}
	local folder = SeriousHook.folders.configs
	if not isfolder(folder) then return result end
	for _, file in ipairs(bfs:GetChildren(folder)) do
		if file:IsA("File") and string.sub(file.Name, -5) == ".json" then
			table.insert(result, string.sub(file.Name, 1, -6))
		end
	end
	table.sort(result)
	return result
end

-- Delete a config file.
function SeriousHook.Config:DeleteConfig(name)
	local path = SeriousHook.folders.configs .. "/" .. name .. ".json"
	if isfile(path) then
		deletefile(path)
	end
end

-- Autoload a config by name (call inside Initialize).
function SeriousHook.Config:Autoload(name)
	if name then
		SeriousHook.Config:LoadConfigFile(name)
	end
end

-- Export the Config table as a callable module for registration convenience.
SeriousHook.Config = SeriousHook.Config
return SeriousHook.Config
-- widgets/Label.lua
-- Section:Label{name, centered?}
-- Returns a label with Set(text).

local function Label(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Label"
	local centered = info.centered or info.Centered or false

	local tb = SeriousHook.Util:GetTextBounds(name, Theme.textsize, Theme.font)
	local lbl = SeriousHook.Util:Create("TextLabel", centered and Vector2.new(
		self.section_frame.Size.X / 2 - 0, self.currentAxis
	) or Vector2.new(4, self.currentAxis), self.section_frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Center       = centered,
		Position     = centered
			and Vector2.new(self.section_frame.Size.X / 2, self.currentAxis)
			or  Vector2.new(4, self.currentAxis),
		Visible      = false,
	}, self.visibleContent)

	local label = {
		textLabel = lbl,
		axis = self.currentAxis,
		Set = function(text)
			lbl.Text = text
		end,
	}
	label.Set(name)

	self.currentAxis = self.currentAxis + (tb and tb.Y + 4 or 18)
	self:Update()

	return label
end

SectionProto.Label = Label
return Label
-- widgets/Divider.lua
-- Section:Divider{text?, color?}
-- A thin line with optional centered text.

local function Divider(self, info)
	info = info or {}
	local text  = info.text or info.Text or nil
	local color = info.color or info.Color or Theme.accent

	local div = {}

	local line = SeriousHook.Util:Create("Line", nil, self.section_frame, {
		Size      = Vector2.new(self.section_frame.Size.X - 8, 1),
		Position  = Vector2.new(4, self.currentAxis + 3),
		Color     = color,
		Thickness = 1,
		Visible   = false,
	}, self.visibleContent)
	div.line = line

	if text then
		local tb = SeriousHook.Util:GetTextBounds(text, Theme.textsize - 1, Theme.font)
		local tx = SeriousHook.Util:Create("TextLabel", nil, self.section_frame, {
			Text         = text,
			Size         = Theme.textsize - 1,
			Font         = Theme.font,
			Color        = Theme.textDim,
			OutlineColor = Theme.textOutline,
			Center       = true,
			Position     = Vector2.new(self.section_frame.Size.X / 2 - tb.X / 2, self.currentAxis + 5),
			Visible      = false,
		}, self.visibleContent)
		div.textLabel = tx
		self.currentAxis = self.currentAxis + 13
	else
		self.currentAxis = self.currentAxis + 8
	end

	self:Update()
	return div
end

SectionProto.Divider = Divider
return Divider
-- widgets/Toggle.lua
-- Section:Toggle{name, default, flag, callback}
-- + AddColor{default, alpha, flag, callback}
-- + AddKeybind{default, mode, keyName, flag, callback}

local function Toggle(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Toggle"
	local def = info.def or info.Def or info.default or info.Default or false
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end

	local t = {
		current = def,
		axis = self.currentAxis,
		addedAxis = 0,
		colorpickers = 0,
		keybind = nil,
		flag = flag,
	}

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, t.axis), self.section_frame, {
		Size      = Vector2.new(0, 15, 0, 15),
		Position  = Vector2.new(4, t.axis),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	t.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	}, self.visibleContent)
	t.inline = inline

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = t.current and Theme.accent or Theme.surface1,
		Visible   = false,
	}, self.visibleContent)
	t.frame = frame

	local gradient = SeriousHook.Util:Create("Image", nil, frame, {
		Size      = Vector2.new(1, 0, 1, 0, frame),
		Position  = Vector2.zero,
		Transparency = 0.5,
		Visible   = false,
	}, self.visibleContent)
	table.insert(t._imgs or {}, gradient)
	SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")

	local tb = SeriousHook.Util:GetTextBounds(name, Theme.textsize, Theme.font)
	local label = SeriousHook.Util:Create("TextLabel", Vector2.new(23, t.axis + (15/2) - (tb.Y/2)), self.section_frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(23, t.axis + (15/2) - tb.Y/2),
		Visible      = false,
	}, self.visibleContent)
	t.label = label

	local function onToggle()
		t.current = not t.current
		frame.Color = t.current and Theme.accent or Theme.surface1
		if flag then
			SeriousHook.Flags[tostring(flag)] = t
		end
		callback(t.current)
	end

	function t:Get() return t.current end
	function t:Set(v)
		if v == t.current then return end
		t.current = v
		frame.Color = t.current and Theme.accent or Theme.surface1
		if flag then SeriousHook.Flags[tostring(flag)] = t end
		callback(t.current)
	end

	-- Click handler attached to beGan
	local clickBegan = SeriousHook._began
	clickBegan[#clickBegan + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not t.outline.Visible then return end
		local m = SeriousHook.Util:MouseLocation()
		local x1 = self.section_frame.Position.X
		local y1 = self.section_frame.Position.Y + t.axis
		local x2 = self.section_frame.Position.X + self.section_frame.Size.X - t.addedAxis
		local y2 = self.section_frame.Position.Y + t.axis + 15
		if m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2 then
			if self.window:IsOverPopup() then return end
			onToggle()
		end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = t end

	self.currentAxis = self.currentAxis + 15 + 4
	self:Update()

	-- AddColor
	function t:AddColor(info2)
		info2 = info2 or {}
		local def2 = info2.def or info2.Def or info2.default or info2.Default or Color3.fromRGB(255, 0, 0)
		local transp = info2.transparency or info2.Transparency or info2.transp or info2.Transp or info2.alpha or info2.Alpha or nil
		local flag2 = info2.flag or info2.Flag or info2.pointer or info2.Pointer or nil
		local callback2 = info2.callback or info2.callBack or info2.Callback or function() end
		local cpinfo = info2.info or info2.Info or name

		local hh, ss, vv = def2:ToHSV()
		local cp = {
			toggle = t,
			axis = t.axis,
			index = t.colorpickers,
			current = { hh, ss, vv, transp and transp or 0 },
			holding = { picker = false, huepicker = false, transparency = false },
			holder = {
				inline = nil,
				picker = nil,
				picker_cursor = nil,
				huepicker = nil,
				huepicker_cursor = {},
				transparency = nil,
				transparencybg = nil,
				transparency_cursor = {},
				drawings = {},
			},
		}

		local cpOut = SeriousHook.Util:Create("Frame", Vector2.new(self.section_frame.Size.X - (t.colorpickers == 0 and 34 or 68), t.axis), self.section_frame, {
			Size      = Vector2.new(0, 30, 0, 15),
			Position  = Vector2.new(self.section_frame.Size.X - (t.colorpickers == 0 and 34 or 68), t.axis),
			Color     = Theme.border,
			Visible   = false,
		}, self.visibleContent)
		t._cpOutlines = t._cpOutlines or {}
		t._cpOutlines[#t._cpOutlines + 1] = cpOut

		local cpIn = SeriousHook.Util:Create("Frame", Vector2.one, cpOut, {
			Size      = Vector2.new(1, -2, 1, -2, cpOut),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
			Visible   = false,
		}, self.visibleContent)

		local transpImg
		if transp then
			transpImg = SeriousHook.Util:Create("Image", Vector2.one, cpIn, {
				Size      = Vector2.new(1, -2, 1, -2, cpIn),
				Position  = Vector2.one,
				Visible   = false,
			}, self.visibleContent)
		end

		local cpF = SeriousHook.Util:Create("Frame", Vector2.one, cpIn, {
			Size      = Vector2.new(1, -2, 1, -2, cpIn),
			Position  = Vector2.one,
			Color     = def2,
			Transparency = transp and 1 - transp or 1,
			Visible   = false,
		}, self.visibleContent)
		cp.frame = cpF

		local cpG = SeriousHook.Util:Create("Image", nil, cpF, {
			Size      = Vector2.new(1, 0, 1, 0, cpF),
			Position  = Vector2.zero,
			Transparency = 0.5,
			Visible   = false,
		}, self.visibleContent)
		cp._g = cpG
		SeriousHook.Util:LoadImage(cpG, "gradient", "https://i.imgur.com/5hmlrjX.png")

		if transp then
			SeriousHook.Util:LoadImage(transpImg, "cptransp", "https://i.imgur.com/IIPee2A.png")
		end

		function cp:Set(color, transpVal)
			if typeof(color) == "table" then
				if color.Color and color.Transparency then
					local h, s, v = table.unpack(color.Color)
					cp.current = { h, s, v, color.Transparency }
					cpF.Color = Color3.fromHSV(h, s, v)
					cpF.Transparency = 1 - color.Transparency
					callback2(Color3.fromHSV(h, s, v), color.Transparency)
				else
					cp.current = color
					cpF.Color = Color3.fromHSV(color[1], color[2], color[3])
					cpF.Transparency = 1 - (color[4] or 0)
					callback2(Color3.fromHSV(color[1], color[2], color[3]), color[4] or 0)
				end
			elseif typeof(color) == "Color3" then
				local h, s, v = color:ToHSV()
				cp.current = { h, s, v, transpVal or 0 }
				cpF.Color = Color3.fromHSV(h, s, v)
				cpF.Transparency = 1 - (transpVal or 0)
				callback2(Color3.fromHSV(h, s, v), transpVal or 0)
			end
			if flag2 then
				SeriousHook.Flags[tostring(flag2)] = cp
			end
		end

		function cp:Get()
			return {
				Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3]),
				Transparency = cp.current[4],
			}
		end

		function cp:Refresh()
			if not cp.open then return end
			local m = SeriousHook.Util:MouseLocation()
			if cp.holding.picker and cp.holder.picker then
				cp.current[2] = math.clamp(m.X - cp.holder.picker.Position.X, 0, cp.holder.picker.Size.X) / cp.holder.picker.Size.X
				cp.current[3] = 1 - math.clamp(m.Y - cp.holder.picker.Position.Y, 0, cp.holder.picker.Size.Y) / cp.holder.picker.Size.Y
				cp.holder.picker_cursor.Position = SeriousHook.Util:Position(cp.current[2], -3, 1 - cp.current[3], -3, cp.holder.picker)
				SeriousHook.Util:UpdateOffset(cp.holder.picker_cursor, {Vector2.new((cp.holder.picker.Size.X * cp.current[2]) - 3, (cp.holder.picker.Size.Y * (1 - cp.current[3])) - 3), cp.holder.picker})
				if cp.holder.transparencybg then
					cp.holder.transparencybg.Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3])
				end
			elseif cp.holding.huepicker and cp.holder.huepicker then
				cp.current[1] = math.clamp(m.Y - cp.holder.huepicker.Position.Y, 0, cp.holder.huepicker.Size.Y) / cp.holder.huepicker.Size.Y
				cp.holder.huepicker_cursor[1].Position = SeriousHook.Util:Position(0, -3, cp.current[1], -3, cp.holder.huepicker)
				cp.holder.huepicker_cursor[2].Position = Vector2.new(cp.holder.huepicker_cursor[1].Position.X + 1, cp.holder.huepicker_cursor[1].Position.Y + 1)
				cp.holder.huepicker_cursor[3].Position = Vector2.new(cp.holder.huepicker_cursor[2].Position.X + 1, cp.holder.huepicker_cursor[2].Position.Y + 1)
				cp.holder.huepicker_cursor[3].Color = Color3.fromHSV(cp.current[1], 1, 1)
				SeriousHook.Util:UpdateOffset(cp.holder.huepicker_cursor[1], {Vector2.new(-3, (cp.holder.huepicker.Size.Y * cp.current[1]) - 3), cp.holder.huepicker})
				cp.holder.background.Color = Color3.fromHSV(cp.current[1], 1, 1)
				if cp.holder.transparency_cursor and cp.holder.transparency_cursor[3] then
					cp.holder.transparency_cursor[3].Color = Color3.fromHSV(0, 0, 1 - cp.current[4])
				end
				if cp.holder.transparencybg then
					cp.holder.transparencybg.Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3])
				end
			elseif cp.holding.transparency and cp.holder.transparency then
				cp.current[4] = 1 - math.clamp(m.X - cp.holder.transparency.Position.X, 0, cp.holder.transparency.Size.X) / cp.holder.transparency.Size.X
				cp.holder.transparency_cursor[1].Position = SeriousHook.Util:Position(1 - cp.current[4], -3, 0, -3, cp.holder.transparency)
				cp.holder.transparency_cursor[2].Position = Vector2.new(cp.holder.transparency_cursor[1].Position.X + 1, cp.holder.transparency_cursor[1].Position.Y + 1)
				cp.holder.transparency_cursor[3].Position = Vector2.new(cp.holder.transparency_cursor[2].Position.X + 1, cp.holder.transparency_cursor[2].Position.Y + 1)
				cp.holder.transparency_cursor[3].Color = Color3.fromHSV(0, 0, 1 - cp.current[4])
				cpF.Transparency = 1 - cp.current[4]
				SeriousHook.Util:UpdateTransparency(cpF, 1 - cp.current[4])
				SeriousHook.Util:UpdateOffset(cp.holder.transparency_cursor[1], {Vector2.new((cp.holder.transparency.Size.X * (1 - cp.current[4])) - 3, -3), cp.holder.transparency})
				cp.holder.background.Color = Color3.fromHSV(cp.current[1], 1, 1)
			end
			cp:Set(cp.current)
		end

		SeriousHook._began[#SeriousHook._began + 1] = function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if not self.page.open or not self.window.isVisible then return end
			local m = SeriousHook.Util:MouseLocation()
			local baseX = self.section_frame.Size.X - (cp.index == 0 and 34 + 2 or 68 + 2)
			local baseY = cp.axis
			local hitClose = m.X >= self.section_frame.Position.X + baseX
				and m.X <= self.section_frame.Position.X + self.section_frame.Size.X
				and m.Y >= self.section_frame.Position.Y + baseY
				and m.Y <= self.section_frame.Position.Y + baseY + 15
			if cp.open and cp.holder.inline then
				local ix, iy = cp.holder.inline.Position.X, cp.holder.inline.Position.Y
				if m.X >= ix and m.X <= ix + cp.holder.inline.Size.X and m.Y >= iy and m.Y <= iy + cp.holder.inline.Size.Y then
					if cp.holder.picker and m.X >= cp.holder.picker.Position.X - 2 and m.X <= cp.holder.picker.Position.X + cp.holder.picker.Size.X + 2
						and m.Y >= cp.holder.picker.Position.Y - 2 and m.Y <= cp.holder.picker.Position.Y + cp.holder.picker.Size.Y + 2 then
						cp.holding.picker = true
					elseif cp.holder.huepicker and m.X >= cp.holder.huepicker.Position.X - 2 and m.X <= cp.holder.huepicker.Position.X + cp.holder.huepicker.Size.X + 2
						and m.Y >= cp.holder.huepicker.Position.Y - 2 and m.Y <= cp.holder.huepicker.Position.Y + cp.holder.huepicker.Size.Y + 2 then
						cp.holding.huepicker = true
					elseif cp.holder.transparency and m.X >= cp.holder.transparency.Position.X - 2 and m.X <= cp.holder.transparency.Position.X + cp.holder.transparency.Size.X + 2
						and m.Y >= cp.holder.transparency.Position.Y - 2 and m.Y <= cp.holder.transparency.Position.Y + cp.holder.transparency.Size.Y + 2 then
						cp.holding.transparency = true
					end
				elseif hitClose then
					if cp.open then
						cp.open = false
						for _, v in ipairs(cp.holder.drawings) do SeriousHook.Util:Remove(v) end
						cp.holder.drawings = {}
						cp.holder.inline = nil
						self.window.currentContent.frame = nil
						self.window.currentContent.colorpicker = nil
					end
				end
			elseif hitClose then
				if not cp.open then
					self.window:ClosePopups()
					cp.open = true
					local w = self.section_frame.Size.X - 8
					local panelH = transp and 219 or 200
					local panel = SeriousHook.Util:Create("Frame", Vector2.new(4, cp.axis + 19), self.section_frame, {
						Size      = Vector2.new(1, -8, 0, panelH, self.section_frame),
						Position  = Vector2.new(4, cp.axis + 19),
						Color     = Theme.border,
					}, cp.holder.drawings)
					cp.holder.inline = panel

					local pIn = SeriousHook.Util:Create("Frame", Vector2.one, panel, {
						Size      = Vector2.new(1, -2, 1, -2, panel),
						Position  = Vector2.one,
						Color     = Theme.borderMuted,
					}, cp.holder.drawings)

					local pF = SeriousHook.Util:Create("Frame", Vector2.one, pIn, {
						Size      = Vector2.new(1, -2, 1, -2, pIn),
						Position  = Vector2.one,
						Color     = Theme.surface0,
					}, cp.holder.drawings)

					local pAcc = SeriousHook.Util:Create("Frame", Vector2.zero, pF, {
						Size      = Vector2.new(1, 0, 0, 2, pF),
						Position  = Vector2.zero,
						Color     = Theme.accent,
					}, cp.holder.drawings)

					local pTitle = SeriousHook.Util:Create("TextLabel", Vector2.new(4, 2), pF, {
						Text         = cpinfo,
						Size         = Theme.textsize,
						Font         = Theme.font,
						Color        = Theme.textcolor,
						OutlineColor = Theme.textOutline,
						Position     = Vector2.new(4, 2),
					}, cp.holder.drawings)

					local pickerW = 1 - 27
					local pickerH = transp and -40 or -21
					local pickerOut = SeriousHook.Util:Create("Frame", Vector2.new(4, 17), pF, {
						Size      = Vector2.new(1, pickerW, 1, pickerH, pF),
						Position  = Vector2.new(4, 17),
						Color     = Theme.border,
					}, cp.holder.drawings)

					local pickerIn = SeriousHook.Util:Create("Frame", Vector2.one, pickerOut, {
						Size      = Vector2.new(1, -2, 1, -2, pickerOut),
						Position  = Vector2.one,
						Color     = Theme.borderMuted,
					}, cp.holder.drawings)

					cp.holder.background = SeriousHook.Util:Create("Frame", Vector2.one, pickerIn, {
						Size      = Vector2.new(1, -2, 1, -2, pickerIn),
						Position  = Vector2.one,
						Color     = Color3.fromHSV(cp.current[1], 1, 1),
					}, cp.holder.drawings)

					local pickerImg = SeriousHook.Util:Create("Image", nil, cp.holder.background, {
						Size      = Vector2.new(1, 0, 1, 0, cp.holder.background),
						Position  = Vector2.zero,
					}, cp.holder.drawings)
					cp.holder.picker = pickerImg
					SeriousHook.Util:LoadImage(pickerImg, "valsat", "https://i.imgur.com/wpDRqVH.png")

					local pcW = (pickerImg.Size.X * cp.current[2]) - 3
					local pcH = (pickerImg.Size.Y * (1 - cp.current[3])) - 3
					local pc = SeriousHook.Util:Create("Image", Vector2.new(pcW, pcH), pickerImg, {
						Size      = Vector2.new(0, 6, 0, 6, pickerImg),
						Position  = Vector2.new(cp.current[2], -3, 1 - cp.current[3], -3, pickerImg),
					}, cp.holder.drawings)
					cp.holder.picker_cursor = pc
					SeriousHook.Util:LoadImage(pc, "cursor", "https://raw.githubusercontent.com/mvonwalk/splix-assets/main/Images-cursor.png")

					local hueOut = SeriousHook.Util:Create("Frame", Vector2.new(pF.Size.X - 19, 17), pF, {
						Size      = Vector2.new(0, 15, 1, pickerH, pF),
						Position  = Vector2.new(pF.Size.X - 19, 17),
						Color     = Theme.border,
					}, cp.holder.drawings)

					local hueIn = SeriousHook.Util:Create("Frame", Vector2.one, hueOut, {
						Size      = Vector2.new(1, -2, 1, -2, hueOut),
						Position  = Vector2.one,
						Color     = Theme.borderMuted,
					}, cp.holder.drawings)

					local hueImg = SeriousHook.Util:Create("Image", Vector2.one, hueIn, {
						Size      = Vector2.new(1, -2, 1, -2, hueIn),
						Position  = Vector2.one,
					}, cp.holder.drawings)
					cp.holder.huepicker = hueImg
					SeriousHook.Util:LoadImage(hueImg, "hue", "https://i.imgur.com/iEOsHFv.png")

					local hcX = -3
					local hcY = (hueImg.Size.Y * cp.current[1]) - 3
					cp.holder.huepicker_cursor[1] = SeriousHook.Util:Create("Frame", Vector2.new(hcX, hcY), hueImg, {
						Size      = Vector2.new(0, 6, 0, 6, hueImg),
						Position  = Vector2.new(0, -3, cp.current[1], -3, hueImg),
						Color     = Theme.border,
					}, cp.holder.drawings)

					cp.holder.huepicker_cursor[2] = SeriousHook.Util:Create("Frame", Vector2.one, cp.holder.huepicker_cursor[1], {
						Size      = Vector2.new(1, -2, 1, -2, cp.holder.huepicker_cursor[1]),
						Position  = Vector2.one,
						Color     = Theme.textcolor,
					}, cp.holder.drawings)

					cp.holder.huepicker_cursor[3] = SeriousHook.Util:Create("Frame", Vector2.one, cp.holder.huepicker_cursor[2], {
						Size      = Vector2.new(1, -2, 1, -2, cp.holder.huepicker_cursor[2]),
						Position  = Vector2.one,
						Color     = Color3.fromHSV(cp.current[1], 1, 1),
					}, cp.holder.drawings)

					if transp then
						local trOut = SeriousHook.Util:Create("Frame", Vector2.new(4, pF.Size.X - 19), pF, {
							Size      = Vector2.new(1, -27, 0, 15, pF),
							Position  = Vector2.new(4, pF.Size.X - 19),
							Color     = Theme.border,
						}, cp.holder.drawings)

						local trIn = SeriousHook.Util:Create("Frame", Vector2.one, trOut, {
							Size      = Vector2.new(1, -2, 1, -2, trOut),
							Position  = Vector2.one,
							Color     = Theme.borderMuted,
						}, cp.holder.drawings)

						cp.holder.transparencybg = SeriousHook.Util:Create("Frame", Vector2.one, trIn, {
							Size      = Vector2.new(1, -2, 1, -2, trIn),
							Position  = Vector2.one,
							Color     = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3]),
						}, cp.holder.drawings)

						local trImg = SeriousHook.Util:Create("Image", Vector2.one, trIn, {
							Size      = Vector2.new(1, -2, 1, -2, trIn),
							Position  = Vector2.one,
						}, cp.holder.drawings)
						cp.holder.transparency = trImg
						cp.holder.transparencybg = cp.holder.transparencybg
						SeriousHook.Util:LoadImage(trImg, "transp", "https://i.imgur.com/ncssKbH.png")

						local trcX = (trImg.Size.X * (1 - cp.current[4])) - 3
						local trcY = -3
						cp.holder.transparency_cursor[1] = SeriousHook.Util:Create("Frame", Vector2.new(trcX, trcY), trImg, {
							Size      = Vector2.new(0, 6, 1, 6, trImg),
							Position  = Vector2.new(1 - cp.current[4], -3, 0, -3, trImg),
							Color     = Theme.border,
						}, cp.holder.drawings)

						cp.holder.transparency_cursor[2] = SeriousHook.Util:Create("Frame", Vector2.one, cp.holder.transparency_cursor[1], {
							Size      = Vector2.new(1, -2, 1, -2, cp.holder.transparency_cursor[1]),
							Position  = Vector2.one,
							Color     = Theme.textcolor,
						}, cp.holder.drawings)

						cp.holder.transparency_cursor[3] = SeriousHook.Util:Create("Frame", Vector2.one, cp.holder.transparency_cursor[2], {
							Size      = Vector2.new(1, -2, 1, -2, cp.holder.transparency_cursor[2]),
							Position  = Vector2.one,
							Color     = Color3.fromHSV(0, 0, 1 - cp.current[4]),
						}, cp.holder.drawings)
					end

					self.window.currentContent.frame = pIn
					self.window.currentContent.colorpicker = cp
				else
					cp.open = false
					for _, v in ipairs(cp.holder.drawings) do SeriousHook.Util:Remove(v) end
					cp.holder.drawings = {}
					cp.holder.inline = nil
					self.window.currentContent.frame = nil
					self.window.currentContent.colorpicker = nil
				end
			end
		end

		SeriousHook._ended[#SeriousHook._ended + 1] = function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if cp.holding.picker then cp.holding.picker = false end
				if cp.holding.huepicker then cp.holding.huepicker = false end
				if cp.holding.transparency then cp.holding.transparency = false end
			end
		end

		SeriousHook._changed[#SeriousHook._changed + 1] = function()
			if cp.open and (cp.holding.picker or cp.holding.huepicker or cp.holding.transparency) then
				if cp.holding.picker or cp.holding.huepicker or cp.holding.transparency then
					cp:Refresh()
				end
			end
		end

		if flag2 then SeriousHook.Flags[tostring(flag2)] = cp end

		t.addedAxis = t.addedAxis + (cp.index == 0 and 34 or 68)
		t.colorpickers = t.colorpickers + 1
		self:Update()
		return cp, t
	end

	-- AddKeybind
	function t:AddKeybind(info2)
		info2 = info2 or {}
		local def2 = info2.def or info2.Def or info2.default or info2.Default or nil
		local flag2 = info2.flag or info2.Flag or info2.pointer or info2.Pointer or nil
		local mode = info2.mode or info2.Mode or "Always"
		local keybindName = info2.keybindName or info2.KeybindName or info2.Keybindname or nil
		local callback2 = info2.callback or info2.callBack or info2.Callback or function() end

		local kb = {
			keybindName = keybindName or name,
			axis = t.axis,
			current = {},
			selecting = false,
			mode = mode,
			open = false,
			modemenu = { buttons = {}, drawings = {} },
			active = mode == "Always",
		}
		t.keybind = kb

		local allowedKeys = {
			"Q","W","E","R","T","Y","U","I","O","P",
			"A","S","D","F","G","H","J","K","L",
			"Z","X","C","V","B","N","M",
			"One","Two","Three","Four","Five","Six","Seven","Eight","Nine","0",
			"Insert","Tab","Home","End",
			"LeftAlt","LeftControl","LeftShift","RightAlt","RightControl","RightShift","CapsLock"
		}
		local allowedMouse = { "MouseButton1", "MouseButton2", "MouseButton3" }
		local shortenMap = {
			["MouseButton1"] = "MB1",
			["MouseButton2"] = "MB2",
			["MouseButton3"] = "MB3",
			["Insert"] = "Ins",
			["LeftAlt"] = "LAlt",
			["LeftControl"] = "LC",
			["LeftShift"] = "LS",
			["RightAlt"] = "RAlt",
			["RightControl"] = "RC",
			["RightShift"] = "RS",
			["CapsLock"] = "Caps",
		}

		local kbOut = SeriousHook.Util:Create("Frame", Vector2.new(self.section_frame.Size.X - 44, t.axis), self.section_frame, {
			Size      = Vector2.new(0, 40, 0, 17),
			Position  = Vector2.new(self.section_frame.Size.X - 44, t.axis),
			Color     = Theme.border,
			Visible   = false,
		}, self.visibleContent)
		t._kbOutlines = t._kbOutlines or {}
		t._kbOutlines[#t._kbOutlines + 1] = kbOut

		local kbIn = SeriousHook.Util:Create("Frame", Vector2.one, kbOut, {
			Size      = Vector2.new(1, -2, 1, -2, kbOut),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
			Visible   = false,
		})

		local kbF = SeriousHook.Util:Create("Frame", Vector2.one, kbIn, {
			Size      = Vector2.new(1, -2, 1, -2, kbIn),
			Position  = Vector2.one,
			Color     = Theme.surface1,
			Visible   = false,
		})

		local kbG = SeriousHook.Util:Create("Image", nil, kbF, {
			Size      = Vector2.new(1, 0, 1, 0, kbF),
			Position  = Vector2.zero,
			Transparency = 0.5,
			Visible   = false,
		})
		SeriousHook.Util:LoadImage(kbG, "gradient", "https://i.imgur.com/5hmlrjX.png")

		local kbVal = SeriousHook.Util:Create("TextLabel", Vector2.new(kbOut.Size.X / 2, 1), kbOut, {
			Text         = "...",
			Size         = Theme.textsize,
			Font         = Theme.font,
			Color        = Theme.textcolor,
			OutlineColor = Theme.textOutline,
			Center       = true,
			Position     = Vector2.new(kbOut.Size.X / 2, 1),
			Visible      = false,
		})

		function kb:Shorten(s)
			for k, v in pairs(shortenMap) do s = string.gsub(s, k, v) end
			return s
		end

		function kb:Change(input)
			if not input then return false end
			if input.EnumType then
				if input.EnumType == Enum.KeyCode or input.EnumType == Enum.UserInputType then
					if table.find(allowedKeys, input.Name) or table.find(allowedMouse, input.Name) then
						kb.current = { input.EnumType == Enum.KeyCode and "KeyCode" or "UserInputType", input.Name }
						kbVal.Text = #kb.current > 0 and kb:Shorten(kb.current[2]) or "..."
						return true
					end
				end
			end
			return false
		end

		function kb:Get() return kb.current end
		function kb:Set(tbl)
			kb.current = tbl
			kbVal.Text = #kb.current > 0 and kb:Shorten(kb.current[2]) or "..."
		end
		function kb:Active() return kb.active end
		function kb:Reset()
			for _, btn in ipairs(kb.modemenu.buttons) do
				btn.Color = btn.Text == kb.mode and Theme.accent or Theme.textcolor
			end
			kb.active = mode == "Always"
			if kb.current[1] and kb.current[2] then
				callback2(Enum[kb.current[1]][kb.current[2]], kb.active)
			end
		end

		if def2 then kb:Change(def2) end

		local function onPress(keycode, active)
			if mode == "Hold" then
				kb.active = self:Get()
				if kb.active then
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Add(kb.keybindName, kbVal.Text) end
				else
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
				end
				if active ~= kb.active then callback2(keycode, kb.active) end
			elseif mode == "Toggle" then
				local old = kb.active
				kb.active = not kb.active and self:Get() or false
				if kb.active then
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Add(kb.keybindName, kbVal.Text) end
				else
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
				end
				if kb.active ~= old then callback2(keycode, kb.active) end
			end
		end

		SeriousHook._began[#SeriousHook._began + 1] = function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if not self.page.open or not self.window.isVisible then return end
			local m = SeriousHook.Util:MouseLocation()
			local x1 = self.section_frame.Position.X + (self.section_frame.Size.X - 44 - 2)
			local y1 = kb.axis
			local x2 = self.section_frame.Position.X + self.section_frame.Size.X
			local y2 = kb.axis + 17
			if m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2 then
				if self.window:IsOverPopup() then return end
				if kb.open and kb.modemenu.frame then
					local mf = kb.modemenu.frame
					if m.X >= mf.Position.X and m.X <= mf.Position.X + mf.Size.X
						and m.Y >= mf.Position.Y and m.Y <= mf.Position.Y + mf.Size.Y then
						local changed = false
						for i2, btn in ipairs(kb.modemenu.buttons) do
							if m.Y >= mf.Position.Y + (15 * (i2 - 1))
								and m.Y <= mf.Position.Y + (15 * (i2 - 1)) + 15 then
								kb.mode = btn.Text
								changed = true
								break
							end
						end
						if changed then kb:Reset() end
					else
						kb.open = false
						for _, v in ipairs(kb.modemenu.drawings) do SeriousHook.Util:Remove(v) end
						kb.modemenu.drawings = {}
						kb.modemenu.buttons = {}
						kb.modemenu.frame = nil
						self.window.currentContent.frame = nil
						self.window.currentContent.keybind = nil
					end
				else
					kb.selecting = true
					kbF.Color = Theme.surface0
				end
			end
			-- Keybind trigger
			if kb.current[1] and kb.current[2] then
				local kc = Enum[kb.current[1]][kb.current[2]]
				if input.KeyCode == kc or input.UserInputType == kc then
					onPress(kc, true)
				end
			end
			if kb.selecting then
				if input.KeyCode and input.KeyCode.Name ~= "Unknown" then
					if kb:Change(input.KeyCode) then
						kb.selecting = false
						kb.active = mode == "Always"
						kbF.Color = Theme.surface1
						if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
						callback2(Enum[kb.current[1]][kb.current[2]], kb.active)
					end
				elseif input.UserInputType then
					if kb:Change(input.UserInputType) then
						kb.selecting = false
						kb.active = mode == "Always"
						kbF.Color = Theme.surface1
						if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
						callback2(Enum[kb.current[1]][kb.current[2]], kb.active)
					end
				end
			end
		end

		SeriousHook._ended[#SeriousHook._ended + 1] = function(input)
			if kb.active and mode == "Hold" then
				if kb.current[1] and kb.current[2] then
					local kc = Enum[kb.current[1]][kb.current[2]]
					if input.KeyCode == kc or input.UserInputType == kc then
						kb.active = false
						if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
						callback2(kc, false)
					end
				end
			end
		end

		-- RMB opens mode menu
		SeriousHook._began[#SeriousHook._began + 1] = function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
			if not self.page.open or not self.window.isVisible then return end
			local m = SeriousHook.Util:MouseLocation()
			local x1 = self.section_frame.Position.X + (self.section_frame.Size.X - 44 - 2)
			local y1 = kb.axis
			local x2 = self.section_frame.Position.X + self.section_frame.Size.X
			local y2 = kb.axis + 17
			if m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2 then
				if self.window:IsOverPopup() then return end
				if not kb.selecting then
					self.window:ClosePopups()
					kb.open = true
					local mmF = SeriousHook.Util:Create("Frame", Vector2.new(kbOut.Size.X + 2, 0), kbOut, {
						Size      = Vector2.new(0, 64, 0, 49),
						Position  = Vector2.new(1, 2, 0, 0, kbOut),
						Color     = Theme.border,
					}, kb.modemenu.drawings)
					kb.modemenu.frame = mmF

					local mmIn = SeriousHook.Util:Create("Frame", Vector2.one, mmF, {
						Size      = Vector2.new(1, -2, 1, -2, mmF),
						Position  = Vector2.one,
						Color     = Theme.borderMuted,
					}, kb.modemenu.drawings)

					local mmFrame = SeriousHook.Util:Create("Frame", Vector2.one, mmIn, {
						Size      = Vector2.new(1, -2, 1, -2, mmIn),
						Position  = Vector2.one,
						Color     = Theme.surface1,
					}, kb.modemenu.drawings)

					local mmG = SeriousHook.Util:Create("Image", nil, mmFrame, {
						Size      = Vector2.new(1, 0, 1, 0, mmFrame),
						Position  = Vector2.zero,
						Transparency = 0.5,
					}, kb.modemenu.drawings)
					SeriousHook.Util:LoadImage(mmG, "gradient", "https://i.imgur.com/5hmlrjX.png")

					for i2, modeName in ipairs({ "Always", "Toggle", "Hold" }) do
						local btn = SeriousHook.Util:Create("TextLabel", Vector2.new(mmF.Size.X / 2, 15 * (i2 - 1)), mmF, {
							Text         = modeName,
							Size         = Theme.textsize,
							Font         = Theme.font,
							Color        = modeName == kb.mode and Theme.accent or Theme.textcolor,
							OutlineColor = Theme.textOutline,
							Center       = true,
							Position     = Vector2.new(mmF.Size.X / 2, 15 * (i2 - 1)),
						}, kb.modemenu.drawings)
						kb.modemenu.buttons[#kb.modemenu.buttons + 1] = btn
					end

					self.window.currentContent.frame = mmF
					self.window.currentContent.keybind = kb
				end
			end
		end

		if flag2 then SeriousHook.Flags[tostring(flag2)] = kb end

		self.currentAxis = self.currentAxis + 17 + 4
		self:Update()
		return kb
	end

	return t
end

SectionProto.Toggle = Toggle
return Toggle
-- widgets/Slider.lua
-- Section:Slider{name, min, max, default, suffix, decimals, flag, callback}

local function Slider(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Slider"
	local def = info.def or info.Def or info.default or info.Default or 10
	local min = info.min or info.Min or info.minimum or info.Minimum or 0
	local max = info.max or info.Max or info.maximum or info.Maximum or 100
	local suffix = info.suffix or info.Suffix or info.ending or info.Ending or info.prefix or info.Prefix or info.measurement or info.Measurement or ""
	local decimals = info.decimals or info.Decimals or 1
	decimals = 1 / decimals
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end

	def = math.clamp(def, min, max)

	local s = {
		min = min,
		max = max,
		suffix = suffix,
		decimals = decimals,
		axis = self.currentAxis,
		current = def,
		holding = false,
		flag = flag,
	}

	local title = SeriousHook.Util:GetTextBounds(name, Theme.textsize, Theme.font)
	local label = SeriousHook.Util:Create("TextLabel", Vector2.new(4, s.axis), self.section_frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(4, s.axis),
		Visible      = false,
	}, self.visibleContent)
	s.label = label

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, s.axis + 15), self.section_frame, {
		Size      = Vector2.new(1, -8, 0, 12, self.section_frame),
		Position  = Vector2.new(4, s.axis + 15),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	s.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.surface1,
		Visible   = false,
	})

	local fill = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(0, (frame.Size.X / (s.max - s.min) * (s.current - s.min)), 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.accent,
		Visible   = false,
	})
	s.fill = fill

	local gradient = SeriousHook.Util:Create("Image", nil, frame, {
		Size      = Vector2.new(1, 0, 1, 0, frame),
		Position  = Vector2.zero,
		Transparency = 0.5,
		Visible   = false,
	})
	SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")

	local valTb = SeriousHook.Util:GetTextBounds(name, Theme.textsize, Theme.font)
	local valLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(outline.Size.X / 2, (outline.Size.Y / 2) - (valTb.Y / 2)), outline, {
		Text         = s.current .. suffix .. "/" .. max .. suffix,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Center       = true,
		Position     = Vector2.new(outline.Size.X / 2, (outline.Size.Y / 2) - (valTb.Y / 2)),
		Visible      = false,
	})
	s.valLabel = valLabel

	local function update()
		local pct = 1 - ((s.max - s.current) / (s.max - s.min))
		s.valLabel.Text = s.current .. suffix .. "/" .. max .. suffix
		if s.fill then
			s.fill.Size = Vector2.new(0, pct * (s.fill.Parent and s.fill.Parent.Size.X or frame.Size.X), 1, -2, inline)
		end
		if flag then SeriousHook.Flags[tostring(flag)] = s end
		callback(s.current)
	end
	update()

	function s:Get() return s.current end
	function s:Set(v)
		s.current = math.clamp(math.round(v * s.decimals) / s.decimals, s.min, s.max)
		update()
	end
	function s:Refresh()
		local m = SeriousHook.Util:MouseLocation()
		local pct = math.clamp(m.X - (s.fill and s.fill.Position.X or frame.Position.X), 0, (s.fill and s.fill.Parent and s.fill.Parent.Size.X or frame.Size.X)) / (s.fill and s.fill.Parent and s.fill.Parent.Size.X or frame.Size.X)
		local val = math.floor((s.min + (s.max - s.min) * pct) * s.decimals) / s.decimals
		s:Set(math.clamp(val, s.min, s.max))
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not s.outline.Visible then return end
		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		if m.X >= sf.Position.X and m.X <= sf.Position.X + sf.Size.X
			and m.Y >= sf.Position.Y + s.axis and m.Y <= sf.Position.Y + s.axis + 27 then
			if self.window:IsOverPopup() then return end
			s.holding = true
			s:Refresh()
		end
	end

	SeriousHook._ended[#SeriousHook._ended + 1] = function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and s.holding then
			s.holding = false
		end
	end

	SeriousHook._changed[#SeriousHook._changed + 1] = function()
		if s.holding then s:Refresh() end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = s end

	self.currentAxis = self.currentAxis + 27 + 4
	self:Update()
	return s
end

SectionProto.Slider = Slider
return Slider
-- widgets/Button.lua
-- Section:Button{name, flag, callback}

local function Button(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Button"
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end

	local b = { axis = self.currentAxis, flag = flag }

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, b.axis), self.section_frame, {
		Size      = Vector2.new(1, -8, 0, 20, self.section_frame),
		Position  = Vector2.new(4, b.axis),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	b.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.surface1,
		Visible   = false,
	})

	local gradient = SeriousHook.Util:Create("Image", nil, frame, {
		Size        = Vector2.new(1, 0, 1, 0, frame),
		Position    = Vector2.zero,
		Transparency = 0.5,
		Visible     = false,
	})
	SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")

	local tb = SeriousHook.Util:GetTextBounds(name, Theme.textsize, Theme.font)
	local title = SeriousHook.Util:Create("TextLabel", Vector2.new(frame.Size.X/2, 1), frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Center       = true,
		Position     = Vector2.new(frame.Size.X/2, 1),
		Visible      = false,
	})

	function b:Click()
		if flag then SeriousHook.Flags[tostring(flag)] = b end
		callback()
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.visible then return end
		if not b.outline.Visible then return end
		local m = SeriousHook.Util:MousePosition()
		local sf = self.section_frame
		if m.X >= sf.Position.X and m.X <= sf.Position.X + sf.Size.X
			and m.Y >= sf.Position.Y + b.axis and m.Y <= sf.Position.Y + b.axis + 20 then
			if self.window:IsOverPopup() then return end
			b:Click()
		end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = b end

	self.currentAxis = self.currentAxis + 20 + 4
	self:Update()
	return b
end

SectionProto.Button = Button
return Button
-- widgets/DuoButton.lua
-- Section:DuoButton{buttons = {{name, cb}, {name, cb}}}

local function DuoButton(self, info)
	info = info or {}
	local buttons = info.buttons or info.Buttons or {{"Button 1", function() end}, {"Button 2", function() end}}

	local db = { axis = self.currentAxis }

	for i = 1, 2 do
		local name = buttons[i] and buttons[i][1] or ("Button " .. i)
		local cb = buttons[i] and buttons[i][2] or function() end

		local xOff = i == 2 and ((self.section_frame.Size.X / 2) + 2) or 4
		local xPos = i == 2 and 2 or 4

		local outline = SeriousHook.Util:Create("Frame", Vector2.new(xOff, db.axis), self.section_frame, {
			Size      = Vector2.new(0.5, -6, 0, 20, self.section_frame),
			Position  = Vector2.new(xOff, db.axis),
			Color     = Theme.border,
			Visible   = false,
		}, self.visibleContent)

		local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
			Size      = Vector2.new(1, -2, 1, -2, outline),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
			Visible   = false,
		})

		local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
			Size      = Vector2.new(1, -2, 1, -2, inline),
			Position  = Vector2.one,
			Color     = Theme.surface1,
			Visible   = false,
		})

		local gradient = SeriousHook.Util:Create("Image", nil, frame, {
			Size        = Vector2.new(1, 0, 1, 0, frame),
			Position    = Vector2.zero,
			Transparency = 0.5,
			Visible     = false,
		})
		SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")

		local tb = SeriousHook.Util:GetTextBounds(name, Theme.textsize, Theme.font)
		local title = SeriousHook.Util:Create("TextLabel", Vector2.new(frame.Size.X / 2, 1), frame, {
			Text         = name,
			Size         = Theme.textsize,
			Font         = Theme.font,
			Color        = Theme.textcolor,
			OutlineColor = Theme.textOutline,
			Center       = true,
			Position     = Vector2.new(frame.Size.X / 2, 1),
			Visible      = false,
		})

		SeriousHook._began[#SeriousHook._began + 1] = function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if not self.page.open or not self.window.isVisible then return end
			if not outline.Visible then return end
			local m = SeriousHook.Util:MouseLocation()
			local sf = self.section_frame
			if m.X >= sf.Position.X + (i == 2 and sf.Size.X/2 or 0)
				and m.X <= sf.Position.X + sf.Size.X - (i == 1 and sf.Size.X/2 or 0)
				and m.Y >= sf.Position.Y + db.axis
				and m.Y <= sf.Position.Y + db.axis + 20 then
				if self.window:IsOverPopup() then return end
				cb()
			end
		end
	end

	self.currentAxis = self.currentAxis + 20 + 4
	self:Update()
	return db
end

SectionProto.DuoButton = DuoButton
return DuoButton
-- widgets/Dropdown.lua
-- Section:Dropdown{name, options, default, flag, callback}

local function Dropdown(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Dropdown"
	local options = info.options or info.Options or { "1", "2", "3" }
	local def = info.def or info.Def or info.default or info.Default or options[1]
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end

	local d = {
		open = false,
		current = tostring(def),
		holderDrawings = {},
		holderButtons = {},
		holderInline = nil,
		holderOutline = nil,
		axis = self.currentAxis,
		flag = flag,
		img = nil,
	}

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, d.axis + 15), self.section_frame, {
		Size      = Vector2.new(1, -8, 0, 20, self.section_frame),
		Position  = Vector2.new(4, d.axis + 15),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	d.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.surface1,
		Visible   = false,
	})

	local gradient = SeriousHook.Util:Create("Image", nil, frame, {
		Size        = Vector2.new(1, 0, 1, 0, frame),
		Position    = Vector2.zero,
		Transparency = 0.5,
		Visible     = false,
	})
	d.gradient = gradient
	SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")

	local title = SeriousHook.Util:Create("TextLabel", Vector2.new(4, d.axis), self.section_frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(4, d.axis),
		Visible      = false,
	}, self.visibleContent)

	local valLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(3, frame.Size.Y / 2 - 7), frame, {
		Text         = d.current,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(3, frame.Size.Y / 2 - 7),
		Visible      = false,
	}, self.visibleContent)

	d.img = SeriousHook.Util:Create("Image", Vector2.new(frame.Size.X - 15, frame.Size.Y / 2 - 3), frame, {
		Size      = Vector2.new(0, 9, 0, 6, frame),
		Position  = Vector2.new(1, -15, 0.5, -3, frame),
		Visible   = false,
	}, self.visibleContent)
	SeriousHook.Util:LoadImage(d.img, "arrow_down", "https://i.imgur.com/tVqy0nL.png")

	d.dropdownImage = d.img

	function d:Update()
		if d.open and d.holderInline then
			for _, btn in ipairs(d.holderButtons) do
				btn[1].Color = btn[1].Text == d.current and Theme.accent or Theme.textcolor
				btn[1].Position = Vector2.new(
					btn[1].Text == d.current and 8 or 6,
					2
				)
				SeriousHook.Util:UpdateOffset(btn[1], { Vector2.new(btn[1].Text == d.current and 8 or 6, 2), btn[2] })
			end
		end
	end

	function d:Set(v)
		if type(v) == "string" and table.find(options, v) then
			d.current = v
			valLabel.Text = v
		end
	end

	function d:Get() return d.current end

	local function resetDropdown()
		d.open = false
		SeriousHook.Util:LoadImage(d.img, "arrow_down", "https://i.imgur.com/tVqy0nL.png")
		for _, v in ipairs(d.holderDrawings) do SeriousHook.Util:Remove(v) end
		d.holderDrawings = {}
		d.holderButtons = {}
		d.holderInline = nil
		d.holderOutline = nil
		if d.frame then d.frame = nil end
	end

	local function openDropdown()
		d.open = true
		SeriousHook.Util:LoadImage(d.img, "arrow_up", "https://i.imgur.com/SL9cbQp.png")
		local hostBorder = SeriousHook.Util:Create("Frame", Vector2.new(0, 19), d.outline, {
			Size      = Vector2.new(1, 0, 0, 3 + (#options * 19), d.outline),
			Position  = Vector2.new(0, 0, 0, 19, d.outline),
			Color     = Theme.border,
		}, d.holderDrawings)
		d.holderOutline = hostBorder

		local hostInline = SeriousHook.Util:Create("Frame", Vector2.one, hostBorder, {
			Size      = Vector2.new(1, -2, 1, -2, hostBorder),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
		}, d.holderDrawings)
		d.holderInline = hostInline

		for i, v in ipairs(options) do
			local row = SeriousHook.Util:Create("Frame", Vector2.new(1, 1 + (19 * (i - 1))), hostInline, {
				Size      = Vector2.new(1, -2, 0, 18, hostInline),
				Position  = Vector2.new(0, 1, 0, 1 + (19 * (i - 1)), hostInline),
				Color     = Theme.surface1,
			}, d.holderDrawings)
			local txt = SeriousHook.Util:Create("TextLabel", Vector2.new(v == d.current and 8 or 6, 2), row, {
				Text         = v,
				Size         = Theme.textsize,
				Font         = Theme.font,
				Color        = v == d.current and Theme.accent or Theme.textcolor,
				OutlineColor = Theme.textOutline,
				Position     = Vector2.new(v == d.current and 8 or 6, 2),
			}, d.holderDrawings)
			d.holderButtons[#d.holderButtons + 1] = { txt, row }
		end

		d.frame = hostInline
	end

	local function closeDropdown()
		d.open = false
		SeriousHook.Util:LoadImage(d.img, "arrow_down", "https://i.imgur.com/tVqy0nL.png")
		for _, v in ipairs(d.holderDrawings) do SeriousHook.Util:Remove(v) end
		d.holderDrawings = {}
		d.holderButtons = {}
		d.holderInline = nil
		if d.frame then d.frame = nil end
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not d.outline.Visible then return end
		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		if m.X >= sf.Position.X and m.X <= sf.Position.X + sf.Size.X
			and m.Y >= sf.Position.Y + d.axis and m.Y <= sf.Position.Y + d.axis + 15 + 20 then
			if self.window:IsOverPopup() then return end
			if d.open and d.holderInline then
				for _, btn in ipairs(d.holderButtons) do
					local r = btn[2]
					if m.X >= r.Position.X and m.X <= r.Position.X + r.Size.X
						and m.Y >= r.Position.Y and m.Y <= r.Position.Y + r.Size.Y then
						if btn[1].Text ~= d.current then
							d.current = btn[1].Text
							valLabel.Text = d.current
							d:Update()
							if flag then SeriousHook.Flags[tostring(flag)] = d end
							callback(d.current)
						end
						return
					end
				end
			else
				self.window:ClosePopups()
				if d.open then closeDropdown() else openDropdown() end
			end
		end
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if d.open then
			closeDropdown()
		end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = d end

	self.currentAxis = self.currentAxis + 35 + 4
	self:Update()
	return d
end

SectionProto.Dropdown = Dropdown
return Dropdown
-- widgets/MultiDropdown.lua
-- Section:MultiDropdown{name, options, default, min, flag, callback}

local function MultiDropdown(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "MultiDropdown"
	local options = info.options or info.Options or { "1", "2", "3" }
	local def = info.def or info.Def or info.default or info.Default or { options[1] }
	local min = info.min or info.Min or 0
	local flag = info.flag or info.Flag or nil
	local callback = info.callback or info.callBack or info.Callback or function() end

	local md = {
		open = false,
		current = def,
		holderDrawings = {},
		holderButtons = {},
		holderInline = nil,
		holderOutline = nil,
		axis = self.currentAxis,
		flag = flag,
		img = nil,
	}

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, md.axis + 15), self.section_frame, {
		Size      = Vector2.new(1, -8, 0, 20, self.section_frame),
		Position  = Vector2.new(4, md.axis + 15),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	md.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.surface1,
		Visible   = false,
	})

	local gradient = SeriousHook.Util:Create("Image", nil, frame, {
		Size        = Vector2.new(1, 0, 1, 0, frame),
		Position    = Vector2.zero,
		Transparency = 0.5,
		Visible     = false,
	})
	md.gradient = gradient
	SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")

	local title = SeriousHook.Util:Create("TextLabel", Vector2.new(4, md.axis), self.section_frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(4, md.axis),
		Visible      = false,
	}, self.visibleContent)

	local valLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(3, frame.Size.Y/2 - 7), frame, {
		Text         = md:Resort(),
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(3, frame.Size.Y/2 - 7),
		Visible      = false,
	}, self.visibleContent)
	md.valLabel = valLabel

	md.dropdownImage = SeriousHook.Util:Create("Image", Vector2.new(frame.Size.X - 15, frame.Size.Y/2 - 3), frame, {
		Size      = Vector2.new(0, 9, 0, 6, frame),
		Position  = Vector2.new(1, -15, 0.5, -3, frame),
		Visible   = false,
	}, self.visibleContent)
	SeriousHook.Util:LoadImage(md.dropdownImage, "arrow_down", "https://i.imgur.com/tVqy0nL.png")

	function md:Resort()
		local sorted = {}
		for _, v in ipairs(md.current) do
			local found = false
			for k, o in ipairs(options) do
				if o == v then
					found = true
					break
				end
			end
			if found then
				table.insert(sorted, v)
			end
		end
		table.sort(sorted)
		md.current = sorted
		valLabel.Text = #sorted > 0 and table.concat(sorted, ", ") or ""
		valLabel.Size = Vector2.new(0, Theme.textsize)
		return valLabel.Text
	end

	function md:Get() return md.current end
	function md:Set(tbl)
		md.current = tbl
		md:Resort()
	end

	local function closeMD()
		md.open = false
		SeriousHook.Util:LoadImage(md.dropdownImage, "arrow_down", "https://i.imgur.com/tVqy0nL.png")
		for _, v in ipairs(md.holderDrawings) do SeriousHook.Util:Remove(v) end
		md.holderDrawings = {}
		md.holderButtons = {}
		md.holderInline = nil
		md.holderOutline = nil
		if md.frame then md.frame = nil end
	end

	local function openMD()
		md.open = true
		SeriousHook.Util:LoadImage(md.dropdownImage, "arrow_up", "https://i.imgur.com/SL9cbQp.png")
		local border = SeriousHook.Util:Create("Frame", Vector2.new(0, 19), md.outline, {
			Size      = Vector2.new(1, 0, 0, 3 + (#options * 19), md.outline),
			Position  = Vector2.new(0, 0, 0, 19, md.outline),
			Color     = Theme.border,
		}, md.holderDrawings)
		md.holderOutline = border

		local inline2 = SeriousHook.Util:Create("Frame", Vector2.one, border, {
			Size      = Vector2.new(1, -2, 1, -2, border),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
		}, md.holderDrawings)
		md.holderInline = inline2

		for i, v in ipairs(options) do
			local row = SeriousHook.Util:Create("Frame", Vector2.new(1, 1 + (19 * (i - 1))), inline2, {
				Size      = Vector2.new(1, -2, 0, 18, inline2),
				Position  = Vector2.new(0, 1, 0, 1 + (19 * (i - 1)), inline2),
				Color     = Theme.surface1,
			}, md.holderDrawings)
			local isSelected = table.find(md.current, v)
			local txt = SeriousHook.Util:Create("TextLabel", Vector2.new(isSelected and 8 or 6, 2), row, {
				Text         = v,
				Size         = Theme.textsize,
				Font         = Theme.font,
				Color        = isSelected and Theme.accent or Theme.textcolor,
				OutlineColor = Theme.textOutline,
				Position     = Vector2.new(isSelected and 8 or 6, 2),
			}, md.holderDrawings)
			md.holderButtons[#md.holderButtons + 1] = { txt, row }
		end

		md.frame = inline2
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not md.outline.Visible then return end
		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		if m.X >= sf.Position.X and m.X <= sf.Position.X + sf.Size.X
			and m.Y >= sf.Position.Y + md.axis and m.Y <= sf.Position.Y + md.axis + 15 + 20 then
			if self.window:IsOverPopup() then return end
			if md.open and md.holderInline then
				for _, btn in ipairs(md.holderButtons) do
					local r = btn[2]
					if m.X >= r.Position.X and m.X <= r.Position.X + r.Size.X
						and m.Y >= r.Position.Y and m.Y <= r.Position.Y + r.Size.Y then
						local idx = nil
						for k, s in ipairs(md.current) do
							if s == btn[1].Text then idx = k end
						end
						if idx then
							table.remove(md.current, idx)
						else
							table.insert(md.current, btn[1].Text)
						end
						md:Resort()
						if flag then SeriousHook.Flags[tostring(flag)] = md end
						callback(md.current)
						return
					end
				end
			else
				self.window:ClosePopups()
				if md.open then closeMD() else openMD() end
			end
		end
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if md.open then closeMD() end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = md end

	self.currentAxis = self.currentAxis + 35 + 4
	self:Update()
	return md
end

SectionProto.MultiDropdown = MultiDropdown
return MultiDropdown
-- widgets/Textbox.lua
-- Section:Textbox{name, default, placeholder, numeric, maxLen, flag, callback}

local function Textbox(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Textbox"
	local def = info.def or info.Def or info.default or info.Default or ""
	local placeholder = info.placeholder or info.Placeholder or nil
	local numeric = info.numeric or info.Numeric or false
	local maxLen = info.maxLen or info.MaxLen or 100
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end

	local tb = {
		text = def or "",
		axis = self.currentAxis,
		flag = flag,
		numeric = numeric,
		maxLen = maxLen,
		placeholder = placeholder,
		focusing = false,
	}

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, tb.axis), self.section_frame, {
		Size      = Vector2.new(1, -8, 0, 15, self.section_frame),
		Position  = Vector2.new(4, tb.axis),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	tb.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.surface1,
		Visible   = false,
	})

	local gradient = SeriousHook.Util:Create("Image", nil, frame, {
		Size        = Vector2.new(1, 0, 1, 0, frame),
		Position    = Vector2.zero,
		Transparency = 0.5,
		Visible     = false,
	})
	SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")
	tb.gradient = gradient

	local nameLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(4, tb.axis + 1), self.section_frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(4, tb.axis + 1),
		Visible      = false,
	}, self.visibleContent)
	tb.nameLabel = nameLabel

	local inputLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(4, tb.axis + (15/2) - 6), frame, {
		Text         = tb.text ~= "" and tb.text or (placeholder or ""),
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = tb.text ~= "" and Theme.textcolor or Theme.textDim,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(4, tb.axis + (15/2) - 6),
		Visible      = false,
	}, self.visibleContent)
	tb.inputLabel = inputLabel

	function tb:Get() return tb.text end

	function tb:Set(t)
		if tb.numeric then
			t = tostring(tonumber(t) or 0)
		end
		if #t > tb.maxLen then t = string.sub(t, 1, tb.maxLen) end
		tb.text = t
		tb.inputLabel.Text = tb.text ~= "" and tb.text or (tb.placeholder or "")
		if #tb.text == 0 then
			tb.inputLabel.Color = Theme.textDim
		else
			tb.inputLabel.Color = Theme.textcolor
		end
		if flag then SeriousHook.Flags[tostring(flag)] = tb end
		callback(tb.text)
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not tb.outline.Visible then return end
		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		if m.X >= sf.Position.X + 4 and m.X <= sf.Position.X + sf.Size.X - 4
			and m.Y >= sf.Position.Y + tb.axis and m.Y <= sf.Position.Y + tb.axis + 15 then
			if self.window:IsOverPopup() then return end
			tb.focusing = true
			tb.inputLabel.Color = Theme.textcolor
		end
	end

	SeriousHook._ended[#SeriousHook._ended + 1] = function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			tb.focusing = false
			if not tb.text then tb.inputLabel.Color = Theme.textDim end
		end
	end

	SeriousHook._changed[#SeriousHook._changed + 1] = function()
		if tb.focusing and tb.window.isVisible then
			-- TextInput is simulated via UserInputService.TextInput on Roblox
			-- Actual text capture delegated to executor's text input; here we just
			-- mark that the field is focused. Real text entry via UserInputService.TextInput
			-- must be hooked separately by the host executor; SeriousHook just exposes
			-- a :Get/Set contract and lets the host feed text via :Set.
			--
			-- For completeness: if this were running in an environment with TextInput,
			-- we would call UserInputService.TextInput:Connect here.
		end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = tb end

	self.currentAxis = self.currentAxis + 15 + 4
	self:Update()
	return tb
end

SectionProto.Textbox = Textbox
return Textbox
-- widgets/Keybind.lua
-- Section:Keybind{name, default, mode, keyName, flag, callback}
-- Standalone keybind widget (separate from Toggle:AddKeybind).

local function Keybind(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Keybind"
	local def = info.def or info.Def or info.default or info.Default or nil
	local mode = info.mode or info.Mode or "Always"
	local keybindName = info.keybindName or info.KeybindName or info.Keybindname or nil
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end

	local kb = {
		keybindName = keybindName or name,
		axis = self.currentAxis,
		current = {},
		selecting = false,
		mode = mode,
		open = false,
		modemenu = { buttons = {}, drawings = {} },
		active = mode == "Always",
		flag = flag,
	}

	local allowedKeys = {
		"Q","W","E","R","T","Y","U","I","O","P",
		"A","S","D","F","G","H","J","K","L",
		"Z","X","C","V","B","N","M",
		"One","Two","Three","Four","Five","Six","Seven","Eight","Nine","0",
		"Insert","Tab","Home","End",
		"LeftAlt","LeftControl","LeftShift","RightAlt","RightControl","RightShift","CapsLock"
	}
	local allowedMouse = { "MouseButton1", "MouseButton2", "MouseButton3" }
	local shortenMap = {
		["MouseButton1"] = "MB1",
		["MouseButton2"] = "MB2",
		["MouseButton3"] = "MB3",
		["Insert"] = "Ins",
		["LeftAlt"] = "LAlt",
		["LeftControl"] = "LC",
		["LeftShift"] = "LS",
		["RightAlt"] = "RAlt",
		["RightControl"] = "RC",
		["RightShift"] = "RS",
		["CapsLock"] = "Caps",
	}

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, kb.axis), self.section_frame, {
		Size      = Vector2.new(0, 15, 0, 17, self.section_frame),
		Position  = Vector2.new(4, kb.axis),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	kb.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.surface1,
		Visible   = false,
	})

	local gradient = SeriousHook.Util:Create("Image", nil, frame, {
		Size        = Vector2.new(1, 0, 1, 0, frame),
		Position    = Vector2.zero,
		Transparency = 0.5,
		Visible     = false,
	})
	SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")

	local valLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(outline.Size.X - 4, 1), outline, {
		Text         = "...",
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Center       = false,
		Position     = Vector2.new(outline.Size.X - 4, 1),
		Visible      = false,
	})
	kb.valLabel = valLabel

	local nameLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(4, kb.axis + 1), self.section_frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(4, kb.axis + 1),
		Visible      = false,
	}, self.visibleContent)
	kb.nameLabel = nameLabel

	function kb:Shorten(s)
		for k, v in pairs(shortenMap) do s = string.gsub(s, k, v) end
		return s
	end

	function kb:Change(input)
		if not input then return false end
		if input.EnumType then
			if input.EnumType == Enum.KeyCode or input.EnumType == Enum.UserInputType then
				if table.find(allowedKeys, input.Name) or table.find(allowedMouse, input.Name) then
					kb.current = { input.EnumType == Enum.KeyCode and "KeyCode" or "UserInputType", input.Name }
					kb.valLabel.Text = #kb.current > 0 and kb:Shorten(kb.current[2]) or "..."
					return true
				end
			end
		end
		return false
	end

	function kb:Get() return kb.current end
	function kb:Set(tbl)
		kb.current = tbl
		kb.valLabel.Text = #kb.current > 0 and kb:Shorten(kb.current[2]) or "..."
	end
	function kb:Active() return kb.active end
	function kb:Reset()
		for _, btn in ipairs(kb.modemenu.buttons) do
			btn.Color = btn.Text == kb.mode and Theme.accent or Theme.textcolor
		end
		kb.active = kb.mode == "Always"
		if kb.current[1] and kb.current[2] then
			callback(Enum[kb.current[1]][kb.current[2]], kb.active)
		end
	end

	if def then kb:Change(def) end

	local function onPress(keycode, active)
		if kb.mode == "Hold" then
			kb.active = kb:Get() ~= nil -- simplified: active when keydown
			if kb.active then
				if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Add(kb.keybindName, kb.valLabel.Text) end
			else
				if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
			end
			callback(keycode, kb.active)
		elseif kb.mode == "Toggle" then
			local old = kb.active
			kb.active = not kb.active
			if kb.active then
				if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Add(kb.keybindName, kb.valLabel.Text) end
			else
				if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
			end
			if kb.active ~= old then callback(keycode, kb.active) end
		else
			callback(keycode, true)
		end
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not kb.outline.Visible then return end

		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		local x1 = sf.Position.X + (sf.Size.X - 19 - 2)
		local y1 = kb.axis
		local x2 = sf.Position.X + sf.Size.X
		local y2 = kb.axis + 17

		if m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2 then
			if self.window:IsOverPopup() then return end
			if kb.open and kb.modemenu.frame then
				local mf = kb.modemenu.frame
				if m.X >= mf.Position.X and m.X <= mf.Position.X + mf.Size.X
					and m.Y >= mf.Position.Y and m.Y <= mf.Position.Y + mf.Size.Y then
					local changed = false
					for i2, btn in ipairs(kb.modemenu.buttons) do
						if m.Y >= mf.Position.Y + (15 * (i2 - 1))
							and m.Y <= mf.Position.Y + (15 * (i2 - 1)) + 15 then
							kb.mode = btn.Text
							changed = true
							break
						end
					end
					if changed then kb:Reset() end
				else
					kb.open = false
					for _, v in ipairs(kb.modemenu.drawings) do SeriousHook.Util:Remove(v) end
					kb.modemenu.drawings = {}
					kb.modemenu.buttons = {}
					kb.modemenu.frame = nil
					self.window.currentContent.frame = nil
					self.window.currentContent.keybind = nil
				end
			else
				kb.selecting = true
				kb.frame.Color = Theme.surface0
			end
		end

		if kb.selecting then
			if input.KeyCode and input.KeyCode.Name ~= "Unknown" then
				if kb:Change(input.KeyCode) then
					kb.selecting = false
					kb.active = kb.mode == "Always"
					kb.frame.Color = Theme.surface1
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
					callback(Enum[kb.current[1]][kb.current[2]], kb.active)
				end
			elseif input.UserInputType then
				if kb:Change(input.UserInputType) then
					kb.selecting = false
					kb.active = kb.mode == "Always"
					kb.frame.Color = Theme.surface1
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
					callback(Enum[kb.current[1]][kb.current[2]], kb.active)
				end
			end
		end

		-- Key trigger
		if kb.current[1] and kb.current[2] then
			local kc = Enum[kb.current[1]][kb.current[2]]
			if input.KeyCode == kc or input.UserInputType == kc then
				onPress(kc, true)
			end
		end
	end

	SeriousHook._ended[#SeriousHook._ended + 1] = function(input)
		if kb.active and kb.mode == "Hold" then
			if kb.current[1] and kb.current[2] then
				local kc = Enum[kb.current[1]][kb.current[2]]
				if input.KeyCode == kc or input.UserInputType == kc then
					kb.active = false
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
					callback(kc, false)
				end
			end
		end
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not kb.outline.Visible then return end

		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		local x1 = sf.Position.X + (sf.Size.X - 19 - 2)
		local y1 = kb.axis
		local x2 = sf.Position.X + sf.Size.X
		local y2 = kb.axis + 17

		if m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2 then
			if self.window:IsOverPopup() then return end
			if not kb.selecting then
				self.window:ClosePopups()
				kb.open = true
				local mmF = SeriousHook.Util:Create("Frame", Vector2.new(outline.Size.X + 2, 0), outline, {
					Size      = Vector2.new(0, 64, 0, 49),
					Position  = Vector2.new(1, 2, 0, 0, outline),
					Color     = Theme.border,
				}, kb.modemenu.drawings)
				kb.modemenu.frame = mmF

				local mmIn = SeriousHook.Util:Create("Frame", Vector2.one, mmF, {
					Size      = Vector2.new(1, -2, 1, -2, mmF),
					Position  = Vector2.one,
					Color     = Theme.borderMuted,
				}, kb.modemenu.drawings)

				local mmFrame = SeriousHook.Util:Create("Frame", Vector2.one, mmIn, {
					Size      = Vector2.new(1, -2, 1, -2, mmIn),
					Position  = Vector2.one,
					Color     = Theme.surface1,
				}, kb.modemenu.drawings)

				local mmG = SeriousHook.Util:Create("Image", nil, mmFrame, {
					Size        = Vector2.new(1, 0, 1, 0, mmFrame),
					Position    = Vector2.zero,
					Transparency = 0.5,
				}, kb.modemenu.drawings)
				SeriousHook.Util:LoadImage(mmG, "gradient", "https://i.imgur.com/5hmlrjX.png")

				for i2, modeName in ipairs({ "Always", "Toggle", "Hold" }) do
					local btn = SeriousHook.Util:Create("TextLabel", Vector2.new(mmF.Size.X / 2, 15 * (i2 - 1)), mmF, {
						Text         = modeName,
						Size         = Theme.textsize,
						Font         = Theme.font,
						Color        = modeName == kb.mode and Theme.accent or Theme.textcolor,
						OutlineColor = Theme.textOutline,
						Center       = true,
						Position     = Vector2.new(mmF.Size.X / 2, 15 * (i2 - 1)),
					}, kb.modemenu.drawings)
					kb.modemenu.buttons[#kb.modemenu.buttons + 1] = btn
				end

				self.window.currentContent.frame = mmF
				self.window.currentContent.keybind = kb
			end
		end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = kb end

	self.currentAxis = self.currentAxis + 17 + 4
	self:Update()
	return kb
end

SectionProto.Keybind = Keybind
return Keybind
-- widgets/Colorpicker.lua
-- Section:Colorpicker{name, default, alpha, flag, callback}
-- + AddColor{default, alpha, flag, callback}

local function Colorpicker(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Colorpicker"
	local def = info.def or info.Def or info.default or info.Default or Color3.fromRGB(255, 0, 0)
	local transp = info.transparency or info.Transparency or info.transp or info.Transp or info.alpha or info.Alpha or nil
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback2 = info.callback or info.callBack or info.Callback or function() end
	local cpinfo = info.info or info.Info or name

	local cp = {
		open = false,
		current = { def:ToHSV() },
		holding = { picker = false, huepicker = false, transparency = false },
		holder = { drawings = {}, inline = nil },
		flag = flag,
	}

	if transp then cp.current[4] = transp end

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, cp.axis), self.section_frame, {
		Size      = Vector2.new(0, 25, 0, 15, self.section_frame),
		Position  = Vector2.new(4, cp.axis),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	cp.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = def,
		Transparency = transp and 1 - transp or 1,
		Visible   = false,
	})
	cp.frame = frame

	local gradient = SeriousHook.Util:Create("Image", nil, frame, {
		Size        = Vector2.new(1, 0, 1, 0, frame),
		Position    = Vector2.zero,
		Transparency = 0.5,
		Visible     = false,
	})
	cp.gradient = gradient
	SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")

	local transpImg
	if transp then
		transpImg = SeriousHook.Util:Create("Image", Vector2.one, inline, {
			Size      = Vector2.new(1, -2, 1, -2, inline),
			Position  = Vector2.one,
			Visible   = false,
		}, self.visibleContent)
		SeriousHook.Util:LoadImage(transpImg, "cptransp", "https://i.imgur.com/IIPee2A.png")
		cp.transpImg = transpImg
	end

	local nameLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(28, cp.axis + (15/2) - 6), self.section_frame, {
		Text         = cpinfo,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(28, cp.axis + (15/2) - 6),
		Visible      = false,
	}, self.visibleContent)
	cp.nameLabel = nameLabel

	function cp:Get()
		return {
			Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3]),
			Transparency = cp.current[4] or 0,
		}
	end

	function cp:Set(color, transpVal)
		if typeof(color) == "table" then
			if color.Color and color.Transparency then
				local h, s, v = table.unpack(color.Color)
				cp.current = { h, s, v, color.Transparency }
			else
				cp.current = color
			end
		elseif typeof(color) == "Color3" then
			local h, s, v = color:ToHSV()
			cp.current = { h, s, v, transpVal or 0 }
		end
		cp.frame.Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3])
		cp.frame.Transparency = 1 - (cp.current[4] or 0)
		if flag then SeriousHook.Flags[tostring(flag)] = cp end
		callback2(Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3]), cp.current[4] or 0)
	end

	function cp:Refresh()
		if not cp.open then return end
		local m = SeriousHook.Util:MouseLocation()
		if cp.holding.picker then
			local picker = cp.holder.picker
			if picker then
				cp.current[2] = math.clamp(m.X - picker.Position.X, 0, picker.Size.X) / picker.Size.X
				cp.current[3] = 1 - math.clamp(m.Y - picker.Position.Y, 0, picker.Size.Y) / picker.Size.Y
				if cp.holder.picker_cursor then
					cp.holder.picker_cursor.Position = SeriousHook.Util:Position(cp.current[2], -3, 1 - cp.current[3], -3, picker)
					SeriousHook.Util:UpdateOffset(cp.holder.picker_cursor, {
						Vector2.new((picker.Size.X * cp.current[2]) - 3, (picker.Size.Y * (1 - cp.current[3])) - 3),
						picker,
					})
				end
				if cp.holder.transparencybg then
					cp.holder.transparencybg.Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3])
				end
			end
		elseif cp.holding.huepicker then
			local huepicker = cp.holder.huepicker
			if huepicker then
				cp.current[1] = math.clamp(m.Y - huepicker.Position.Y, 0, huepicker.Size.Y) / huepicker.Size.Y
				if cp.holder.huepicker_cursor then
					cp.holder.huepicker_cursor[1].Position = SeriousHook.Util:Position(0, -3, cp.current[1], -3, huepicker)
					SeriousHook.Util:UpdateOffset(cp.holder.huepicker_cursor[1], {
						Vector2.new(-3, (huepicker.Size.Y * cp.current[1]) - 3),
						huepicker,
					})
					for i = 2, 3 do
						local prev = cp.holder.huepicker_cursor[i - 1]
						if prev then
							cp.holder.huepicker_cursor[i].Position = Vector2.new(prev.Position.X + 1, prev.Position.Y + 1)
						end
					end
				end
				cp.holder.background.Color = Color3.fromHSV(cp.current[1], 1, 1)
				if cp.holder.transparency_cursor and cp.holder.transparency_cursor[3] then
					cp.holder.transparency_cursor[3].Color = Color3.fromHSV(0, 0, 1 - cp.current[4])
				end
				if cp.holder.transparencybg then
					cp.holder.transparencybg.Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3])
				end
			end
		elseif cp.holding.transparency then
			local transpBar = cp.holder.transparency
			if transpBar then
				cp.current[4] = 1 - math.clamp(m.X - transpBar.Position.X, 0, transpBar.Size.X) / transpBar.Size.X
				if cp.holder.transparency_cursor then
					cp.holder.transparency_cursor[1].Position = SeriousHook.Util:Position(1 - cp.current[4], -3, 0, -3, transpBar)
					SeriousHook.Util:UpdateOffset(cp.holder.transparency_cursor[1], {
						Vector2.new((transpBar.Size.X * (1 - cp.current[4])) - 3, -3),
						transpBar,
					})
					for i = 2, 3 do
						local prev = cp.holder.transparency_cursor[i - 1]
						if prev then
							cp.holder.transparency_cursor[i].Position = Vector2.new(prev.Position.X + 1, prev.Position.Y + 1)
						end
					end
				end
				cp.frame.Transparency = 1 - cp.current[4]
				SeriousHook.Util:UpdateTransparency(cp.frame, 1 - cp.current[4])
				cp.holder.background.Color = Color3.fromHSV(cp.current[1], 1, 1)
			end
		end
		cp:Set(cp.current)
	end

	local function closeColorpicker()
		cp.open = false
		for _, v in ipairs(cp.holder.drawings) do SeriousHook.Util:Remove(v) end
		cp.holder.drawings = {}
		cp.holder.inline = nil
		if cp.frame then cp.frame = nil end
	end

	local function openColorpicker()
		cp.open = true
		local W = self.section_frame.Size.X - 8
		local panelH = transp and 219 or 200
		local panel = SeriousHook.Util:Create("Frame", Vector2.new(4, cp.axis + 19), self.section_frame, {
			Size      = Vector2.new(1, -8, 0, panelH, self.section_frame),
			Position  = Vector2.new(4, cp.axis + 19),
			Color     = Theme.border,
		}, cp.holder.drawings)
		cp.holder.inline = panel

		local pIn = SeriousHook.Util:Create("Frame", Vector2.one, panel, {
			Size      = Vector2.new(1, -2, 1, -2, panel),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
		}, cp.holder.drawings)

		local pF = SeriousHook.Util:Create("Frame", Vector2.one, pIn, {
			Size      = Vector2.new(1, -2, 1, -2, pIn),
			Position  = Vector2.one,
			Color     = Theme.surface0,
		}, cp.holder.drawings)
		cp.holder.background = pF

		local pAcc = SeriousHook.Util:Create("Frame", Vector2.zero, pF, {
			Size      = Vector2.new(1, 0, 0, 2, pF),
			Position  = Vector2.zero,
			Color     = Theme.accent,
		}, cp.holder.drawings)

		local pTitle = SeriousHook.Util:Create("TextLabel", Vector2.new(4, 2), pF, {
			Text         = cpinfo,
			Size         = Theme.textsize,
			Font         = Theme.font,
			Color        = Theme.textcolor,
			OutlineColor = Theme.textOutline,
			Position     = Vector2.new(4, 2),
		}, cp.holder.drawings)

		local pickerW = 1 - 27
		local pickerH = transp and -40 or -21
		local pickerOut = SeriousHook.Util:Create("Frame", Vector2.new(4, 17), pF, {
			Size      = Vector2.new(1, pickerW, 1, pickerH, pF),
			Position  = Vector2.new(4, 17),
			Color     = Theme.border,
		}, cp.holder.drawings)

		local pickerIn = SeriousHook.Util:Create("Frame", Vector2.one, pickerOut, {
			Size      = Vector2.new(1, -2, 1, -2, pickerOut),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
		}, cp.holder.drawings)

		local pickerBg = SeriousHook.Util:Create("Frame", Vector2.one, pickerIn, {
			Size      = Vector2.new(1, -2, 1, -2, pickerIn),
			Position  = Vector2.one,
			Color     = Color3.fromHSV(cp.current[1], 1, 1),
		}, cp.holder.drawings)
		cp.holder.background2 = pickerBg

		local pickerImg = SeriousHook.Util:Create("Image", nil, pickerBg, {
			Size      = Vector2.new(1, 0, 1, 0, pickerBg),
			Position  = Vector2.zero,
		}, cp.holder.drawings)
		cp.holder.picker = pickerImg
		SeriousHook.Util:LoadImage(pickerImg, "valsat", "https://i.imgur.com/wpDRqVH.png")

		local pcX = (pickerImg.Size.X * cp.current[2]) - 3
		local pcY = (pickerImg.Size.Y * (1 - cp.current[3])) - 3
		local pc = SeriousHook.Util:Create("Image", Vector2.new(pcX, pcY), pickerImg, {
			Size      = Vector2.new(0, 6, 0, 6, pickerImg),
			Position  = Vector2.new(cp.current[2], -3, 1 - cp.current[3], -3, pickerImg),
		}, cp.holder.drawings)
		cp.holder.picker_cursor = pc
		SeriousHook.Util:LoadImage(pc, "cursor", "https://raw.githubusercontent.com/mvonwalk/splix-assets/main/Images-cursor.png")

		local hueOut = SeriousHook.Util:Create("Frame", Vector2.new(pF.Size.X - 19, 17), pF, {
			Size      = Vector2.new(0, 15, 1, pickerH, pF),
			Position  = Vector2.new(pF.Size.X - 19, 17),
			Color     = Theme.border,
		}, cp.holder.drawings)

		local hueIn = SeriousHook.Util:Create("Frame", Vector2.one, hueOut, {
			Size      = Vector2.new(1, -2, 1, -2, hueOut),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
		}, cp.holder.drawings)

		local hueImg = SeriousHook.Util:Create("Image", Vector2.one, hueIn, {
			Size      = Vector2.new(1, -2, 1, -2, hueIn),
			Position  = Vector2.one,
		}, cp.holder.drawings)
		cp.holder.huepicker = hueImg
		SeriousHook.Util:LoadImage(hueImg, "hue", "https://i.imgur.com/iEOsHFv.png")

		local hcX = -3
		local hcY = (hueImg.Size.Y * cp.current[1]) - 3
		local hcCursor1 = SeriousHook.Util:Create("Frame", Vector2.new(hcX, hcY), hueImg, {
			Size      = Vector2.new(0, 6, 0, 6, hueImg),
			Position  = Vector2.new(0, -3, cp.current[1], -3, hueImg),
			Color     = Theme.border,
		}, cp.holder.drawings)
		cp.holder.huepicker_cursor = { hcCursor1 }

		local hcCursor2 = SeriousHook.Util:Create("Frame", Vector2.one, hcCursor1, {
			Size      = Vector2.new(1, -2, 1, -2, hcCursor1),
			Position  = Vector2.one,
			Color     = Theme.textcolor,
		}, cp.holder.drawings)
		cp.holder.huepicker_cursor[2] = hcCursor2

		local hcCursor3 = SeriousHook.Util:Create("Frame", Vector2.one, hcCursor2, {
			Size      = Vector2.new(1, -2, 1, -2, hcCursor2),
			Position  = Vector2.one,
			Color     = Color3.fromHSV(cp.current[1], 1, 1),
		}, cp.holder.drawings)
		cp.holder.huepicker_cursor[3] = hcCursor3

		if transp then
			local trOut = SeriousHook.Util:Create("Frame", Vector2.new(4, pF.Size.X - 19), pF, {
				Size      = Vector2.new(1, -27, 0, 15, pF),
				Position  = Vector2.new(4, pF.Size.X - 19),
				Color     = Theme.border,
			}, cp.holder.drawings)

			local trIn = SeriousHook.Util:Create("Frame", Vector2.one, trOut, {
				Size      = Vector2.new(1, -2, 1, -2, trOut),
				Position  = Vector2.one,
				Color     = Theme.borderMuted,
			}, cp.holder.drawings)

			local trBg = SeriousHook.Util:Create("Frame", Vector2.one, trIn, {
				Size      = Vector2.new(1, -2, 1, -2, trIn),
				Position  = Vector2.one,
				Color     = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3]),
			}, cp.holder.drawings)
			cp.holder.transparencybg = trBg

			local trImg = SeriousHook.Util:Create("Image", Vector2.one, trIn, {
				Size      = Vector2.new(1, -2, 1, -2, trIn),
				Position  = Vector2.one,
			}, cp.holder.drawings)
			cp.holder.transparency = trImg
			SeriousHook.Util:LoadImage(trImg, "transp", "https://i.imgur.com/ncssKbH.png")

			local trcX = (trImg.Size.X * (1 - cp.current[4])) - 3
			local trcY = -3
			local trCursor1 = SeriousHook.Util:Create("Frame", Vector2.new(trcX, trcY), trImg, {
				Size      = Vector2.new(0, 6, 1, 6, trImg),
				Position  = Vector2.new(1 - cp.current[4], -3, 0, -3, trImg),
				Color     = Theme.border,
			}, cp.holder.drawings)
			cp.holder.transparency_cursor = { trCursor1 }

			local trCursor2 = SeriousHook.Util:Create("Frame", Vector2.one, trCursor1, {
				Size      = Vector2.new(1, -2, 1, -2, trCursor1),
				Position  = Vector2.one,
				Color     = Theme.textcolor,
			}, cp.holder.drawings)
			cp.holder.transparency_cursor[2] = trCursor2

			local trCursor3 = SeriousHook.Util:Create("Frame", Vector2.one, trCursor2, {
				Size      = Vector2.new(1, -2, 1, -2, trCursor2),
				Position  = Vector2.one,
				Color     = Color3.fromHSV(0, 0, 1 - cp.current[4]),
			}, cp.holder.drawings)
			cp.holder.transparency_cursor[3] = trCursor3
		end

		self.window.currentContent.frame = pIn
		self.window.currentContent.colorpicker = cp
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not cp.outline.Visible then return end
		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		local x1 = sf.Position.X + (sf.Size.X - 27 - 2)
		local y1 = cp.axis
		local x2 = sf.Position.X + sf.Size.X
		local y2 = cp.axis + 15
		if m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2 then
			if self.window:IsOverPopup() then return end
			if cp.open and cp.holder.inline then
				local ix, iy = cp.holder.inline.Position.X, cp.holder.inline.Position.Y
				if m.X >= ix and m.X <= ix + cp.holder.inline.Size.X and m.Y >= iy and m.Y <= iy + cp.holder.inline.Size.Y then
					if cp.holding.picker or cp.holding.huepicker or cp.holding.transparency then
						-- still inside popup, check sub-regions
						if cp.holder.picker and m.X >= cp.holder.picker.Position.X - 2 and m.X <= cp.holder.picker.Position.X + cp.holder.picker.Size.X + 2
							and m.Y >= cp.holder.picker.Position.Y - 2 and m.Y <= cp.holder.picker.Position.Y + cp.holder.picker.Size.Y + 2 then
							cp.holding.picker = true
						elseif cp.holder.huepicker and m.X >= cp.holder.huepicker.Position.X - 2 and m.X <= cp.holder.huepicker.Position.X + cp.holder.huepicker.Size.X + 2
							and m.Y >= cp.holder.huepicker.Position.Y - 2 and m.Y <= cp.holder.huepicker.Position.Y + cp.holder.huepicker.Size.Y + 2 then
							cp.holding.huepicker = true
						elseif cp.holder.transparency and m.X >= cp.holder.transparency.Position.X - 2 and m.X <= cp.holder.transparency.Position.X + cp.holder.transparency.Size.X + 2
							and m.Y >= cp.holder.transparency.Position.Y - 2 and m.Y <= cp.holder.transparency.Position.Y + cp.holder.transparency.Size.Y + 2 then
							cp.holding.transparency = true
						end
					end
				else
					closeColorpicker()
				end
			else
				if not cp.open then
					self.window:ClosePopups()
					openColorpicker()
				else
					closeColorpicker()
				end
			end
		end
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if cp.open then closeColorpicker() end
	end

	SeriousHook._ended[#SeriousHook._ended + 1] = function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if cp.holding.picker then cp.holding.picker = false end
			if cp.holding.huepicker then cp.holding.huepicker = false end
			if cp.holding.transparency then cp.holding.transparency = false end
		end
	end

	SeriousHook._changed[#SeriousHook._changed + 1] = function()
		if cp.open and (cp.holding.picker or cp.holding.huepicker or cp.holding.transparency) then
			if cp.holding.picker or cp.holding.huepicker or cp.holding.transparency then
				cp:Refresh()
			end
		end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = cp end

	self.currentAxis = self.currentAxis + 15 + 4
	self:Update()
	return cp
end

-- AddColor attaches a second colorpicker inline to a toggle.
function SectionProto.AddColor(toggle, info)
	info = info or {}
	local def = info.def or info.Def or info.default or info.Default or Color3.fromRGB(255, 0, 0)
	local transp = info.transparency or info.Transparency or info.transp or info.Transp or info.alpha or info.Alpha or nil
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end
	local cpinfo = info.info or info.Info or toggle.name or "Color"

	local cp = Colorpicker(addColorSection, info)
	return cp, toggle
end

SectionProto.Colorpicker = Colorpicker
return Colorpicker
-- widgets/ConfigList.lua
-- Section:ConfigList()
-- 8 rows (18px each) showing configs from Config.ListConfigs().

local function ConfigList(self)
	local cl = { axis = self.currentAxis, flag = "config_list" }

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, cl.axis), self.section_frame, {
		Size      = Vector2.new(1, -8, 0, 148, self.section_frame),
		Position  = Vector2.new(4, cl.axis),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	cl.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.surface1,
		Visible   = false,
	})

	local gradient = SeriousHook.Util:Create("Image", nil, frame, {
		Size        = Vector2.new(1, 0, 1, 0, frame),
		Position    = Vector2.zero,
		Transparency = 0.5,
		Visible     = false,
	})
	SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")

	local rows = {}
	for i = 1, 8 do
		local rowFrame = SeriousHook.Util:Create("Frame", Vector2.new(1, 0, 1, 0), frame, {
			Size      = Vector2.new(1, -2, 0, 18, frame),
			Position  = Vector2.new(0, 1, 0, 1 + ((i - 1) * 18), frame),
			Color     = i == 1 and Theme.surface0 or Theme.borderMuted,
			Visible   = false,
		}, self.visibleContent)
		local rowText = SeriousHook.Util:Create("TextLabel", Vector2.new(4, 1), rowFrame, {
			Text         = "",
			Size         = Theme.textsize,
			Font         = Theme.font,
			Color        = Theme.textcolor,
			OutlineColor = Theme.textOutline,
			Position     = Vector2.new(4, 1),
			Visible      = false,
		}, self.visibleContent)
		rows[#rows + 1] = { frame = rowFrame, label = rowText, index = i }
	end
	cl.rows = rows

	cl.list = {}
	cl.listeners = {}

	function cl:Refresh()
		local saved = SeriousHook.Config:ListConfigs()
		cl.list = saved
		for i = 1, 8 do
			local r = rows[i]
			if i <= #saved then
				r.label.Text = saved[i]
				r.frame.Color = Theme.surface0
				r.frame.Visible = true
				r.label.Visible = true
				r.selected = false
			else
				r.frame.Visible = false
				r.label.Visible = false
				r.selected = false
			end
		end
		-- highlight selected
		for i = 1, #saved do
			if cl.currentSelected and cl.currentSelected == saved[i] then
				rows[i].label.Color = Theme.accent
				rows[i].frame.Color = Theme.borderMuted
				rows[i].selected = true
			else
				rows[i].label.Color = Theme.textcolor
				rows[i].frame.Color = Theme.surface0
				rows[i].selected = false
			end
		end
		if flag then SeriousHook.Flags[tostring(flag)] = cl end
	end
	cl:Refresh()

	function cl:Get()
		return cl.currentSelected or ""
	end

	function cl:Set(name)
		cl.currentSelected = name
		cl:Refresh()
	end

	function cl:Select(idx)
		if idx and idx >= 1 and idx <= #cl.list then
			cl.currentSelected = cl.list[idx]
		else
			cl.currentSelected = nil
		end
		cl:Refresh()
	end

	-- Click handling
	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not cl.outline.Visible then return end
		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		if m.X >= sf.Position.X + 4 and m.X <= sf.Position.X + sf.Size.X - 4
			and m.Y >= sf.Position.Y + cl.axis and m.Y <= sf.Position.Y + cl.axis + 148 then
			if self.window:IsOverPopup() then return end
			for i = 1, 8 do
				local r = rows[i]
				if r.frame.Visible then
					if m.Y >= r.frame.Position.Y and m.Y <= r.frame.Position.Y + r.frame.Size.Y then
						-- left-click selects, right-click loads
						if input.UserInputType == Enum.UserInputType.MouseButton2 then
							-- delete on right click
							if cl.list[i] then
								SeriousHook.Config:DeleteConfig(cl.list[i])
								cl.listeners[#cl.listeners + 1] = function()
									cl:Refresh()
								end
								cl:Refresh()
							end
						else
							cl.currentSelected = cl.list[i]
							cl:Refresh()
						end
					end
				end
			end
		end
	end

	function cl:OnLoad(callback)
		cl.listeners[#cl.listeners + 1] = callback
	end

	if flag then SeriousHook.Flags[tostring(flag)] = cl end

	self.currentAxis = self.currentAxis + 148 + 4
	self:Update()
	return cl
end

SectionProto.ConfigList = ConfigList
return ConfigList
-- overlays/Watermark.lua
-- Window:Watermark{enabled, template}
-- Auto-width text, fps/ping throttle 0.25s (driven by single RenderStepped).

local function Watermark(self, info)
	info = info or {}
	local enabled = info.enabled ~= false
	local template = info.template or "SeriousHook | {fps} FPS | {ping} MS"

	local wm = {
		enabled = enabled,
		visible = false,
	}

	local outline = SeriousHook.Util:Create("Frame", Vector2.zero, {
		Size      = Vector2.new(0, 21, 1, 0),
		Position  = Vector2.new(100, 19, 1, 0),
		Color     = Theme.outline,
		Visible   = false,
	})
	wm.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})
	wm.inline = inline

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.surface0,
		Visible   = false,
	})
	wm.frame = frame

	local accent = SeriousHook.Util:Create("Frame", Vector2.zero, frame, {
		Size      = Vector2.new(1, 0, 0, 2, frame),
		Position  = Vector2.zero,
		Color     = Theme.accent,
		Visible   = false,
	})

	local title = SeriousHook.Util:Create("TextLabel", Vector2.new(12 + 6, 4), outline, {
		Text         = template,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(12 + 6, 4),
		Visible      = false,
	})

	local function updateSize()
		local tb = SeriousHook.Util:GetTextBounds(title.Text, Theme.textsize, Theme.font)
		local w = tb.X + 4 + (6 * 2)
		outline.Size = Vector2.new(w, 21)
		inline.Size = Vector2.new(-2, 0, 0, 0)
		frame.Size = Vector2.new(-2, 0, 0, 0)
		accent.Size = Vector2.new(0, 0, 1, 0)
		-- Re-position title relative to outline
		title.Position = Vector2.new(12 + 6 - outline.Position.X, 4 - outline.Position.Y)
	end

	local function makeVisible(visible)
		wm.visible = visible
		outline.Visible = visible and enabled
		inline.Visible  = visible and enabled
		frame.Visible   = visible and enabled
		accent.Visible  = visible and enabled
		title.Visible   = visible and enabled
		if enabled and visible then
			updateSize()
			SeriousHook.overlays.watermark = wm
		end
	end

	local function updateText()
		if not wm.enabled then return end
		local fpsStr = tostring(SeriousHook.shared.fps or 0)
		local pingStr = tostring(SeriousHook.shared.ping or 0)
		local rendered = template
			:gsub("{fps}", fpsStr)
			:gsub("{ping}", pingStr)
		if title.Text ~= rendered then
			title.Text = rendered
			updateSize()
		end
	end

	wm.vis = makeVisible
	wm.update = updateText

	if enabled then
		makeVisible(true)
	end

	self.overlays.watermark = wm
end

SeriousHook.Window.Watermark = Watermark
return Watermark
-- overlays/Keylist.lua
-- Window:Keylist{enabled, position}

local function Keylist(self, info)
	info = info or {}
	local enabled = info.enabled ~= false
	local pos = info.position or Vector2.new(10, 0.4)

	local kl = {
		enabled = enabled,
		visible = false,
		keys = {},          -- list of {name, keytext, outline, inline, frame, label, value}
		outline = nil,
		inline = nil,
		frame = nil,
		accent = nil,
		title = nil,
	}

	-- Build static container layers
	local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	local x = pos.X
	local yFraction = pos.Y or 0.4
	local baseY = yFraction * (screenSize and screenSize.Y or 1080)

	local outline = Util:Create("Frame", Vector2.zero, self.outline or nil, {
		Size      = Vector2.new(150, 22),
		Position  = Vector2.new(x, baseY),
		Color     = Theme.border,
		Visible   = false,
		ZIndex    = 55,
	})
	kl.outline = outline

	local inline = Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})
	kl.inline = inline

	local frame = Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.surface0,
		Visible   = false,
	})
	kl.frame = frame

	local accent = Util:Create("Frame", Vector2.zero, frame, {
		Size      = Vector2.new(1, 0, 0, 1, frame),
		Position  = Vector2.zero,
		Color     = Theme.accent,
		Visible   = false,
	})
	kl.accent = accent

	local titleLabel = Util:Create("TextLabel", Vector2.zero, outline, {
		Text         = "- Keybinds -",
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Center       = true,
		Position     = Vector2.new(outline.Size.X / 2, 5),
		Visible      = false,
	})
	kl.titleLabel = titleLabel

	-- Internal storage mirror (so Remove works cleanly)
	local keyList = {}

	function kl:Add(keybindname, keybindtext)
		if not keybindname or not keybindtext then return end
		-- Avoid duplicates
		for _, existing in ipairs(keyList) do
			if existing.name == tostring(keybindname) then return end
		end

		local keyObj = {
			name = tostring(keybindname),
			keytext = tostring(keybindtext),
		}

		local idx = #keyList + 1
		local yPos = 1 + ((idx - 1) * 18)

		local keyOut = Util:Create("Frame", Vector2.zero, outline, {
			Size      = Vector2.new(outline.Size.X - 2, 0, 0, 18),
			Position  = Vector2.new(1, 1, 0, yPos),
			Color     = Theme.surface1,
			Visible   = false,
		})
		keyObj.outline = keyOut

		local keyIn = Util:Create("Frame", Vector2.one, keyOut, {
			Size      = Vector2.new(1, -2, 1, -2, keyOut),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
			Visible   = false,
		})
		keyObj.inline = keyIn

		local keyF = Util:Create("Frame", Vector2.one, keyIn, {
			Size      = Vector2.new(1, -2, 1, -2, keyIn),
			Position  = Vector2.one,
			Color     = Theme.surface0,
			Visible   = false,
		})
		keyObj.frame = keyF

		local kbTextBounds = Util:GetTextBounds(keybindname, Theme.textsize, Theme.font)
		local keyLabel = Util:Create("TextLabel", Vector2.zero, keyOut, {
			Text         = keybindname,
			Size         = Theme.textsize,
			Font         = Theme.font,
			Color        = Theme.textcolor,
			OutlineColor = Theme.textOutline,
			Position     = Vector2.new(4, 3),
			Visible      = false,
		})
		keyObj.label = keyLabel

		local valPosX = (keyOut.Size.X - (Util:GetTextBounds(keybindtext, Theme.textsize, Theme.font).X)) - 4
		local keyVal = Util:Create("TextLabel", Vector2.zero, keyOut, {
			Text         = keybindtext,
			Size         = Theme.textsize,
			Font         = Theme.font,
			Color        = Theme.textcolor,
			OutlineColor = Theme.textOutline,
			Position     = Vector2.new(valPosX, 3),
			Visible      = false,
		})
		keyObj.value = keyVal

		table.insert(keyList, keyObj)
		kl.keys = keyList

		-- Resize outline height based on count
		local newH = 22 + ((#keyList - 1) * 18)
		outline.Size = Vector2.new(150, newH)
		inline.Size  = Vector2.new(1, -2, 1, -2, outline)
		frame.Size   = Vector2.new(1, -2, 1, -2, inline)
		accent.Size  = Vector2.new(1, 0, 0, 1, frame)
		titleLabel.Position = Vector2.new(outline.Size.X / 2, 5)

		if enabled and kl.visible then
			keyOut.Visible = true
			keyIn.Visible  = true
			keyF.Visible   = true
			keyLabel.Visible = true
			keyVal.Visible = true
		end
	end

	function kl:Remove(keybindname)
		for i = #keyList, 1, -1 do
			if keyList[i].name == tostring(keybindname) then
				local k = keyList[i]
				if k.outline and k.outline.Remove then k.outline:Remove() end
				if k.inline  and k.inline.Remove  then k.inline.Remove() end
				if k.frame   and k.frame.Remove   then k.frame.Remove() end
				if k.label   and k.label.Remove   then k.label.Remove() end
				if k.value   and k.value.Remove   then k.value.Remove() end
				table.remove(keyList, i)
			end
		end
		kl.keys = keyList

		-- Shrink outline
		local newH = 22 + ((#keyList - 1) * 18)
		outline.Size = Vector2.new(150, math.max(22, newH))
		inline.Size  = Vector2.new(1, -2, 1, -2, outline)
		frame.Size   = Vector2.new(1, -2, 1, -2, inline)
		accent.Size  = Vector2.new(1, 0, 0, 1, frame)
		titleLabel.Position = Vector2.new(outline.Size.X / 2, 5)
	end

	function kl:Resort()
		-- Re-sort and reposition
		for i, k in ipairs(keyList) do
			local yPos = 1 + ((i - 1) * 18)
			if k.outline then k.outline.Position = Vector2.new(1, 1, 0, yPos) end
			if k.inline  then k.inline.Position  = Vector2.new(1, 1, 0, 0, k.outline) end
			if k.frame   then k.frame.Position   = Vector2.new(1, 1, 0, 0, k.inline) end
			if k.label   then k.label.Position   = Vector2.new(4, 3) end
			if k.value   then
				local valX = (k.outline.Size.X - (Util:GetTextBounds(k.keytext, Theme.textsize, Theme.font).X)) - 4
				k.value.Position = Vector2.new(valX, 3)
			end
		end
		local newH = 22 + ((#keyList - 1) * 18)
		outline.Size = Vector2.new(150, math.max(22, newH))
		inline.Size  = Vector2.new(1, -2, 1, -2, outline)
		frame.Size   = Vector2.new(1, -2, 1, -2, inline)
		accent.Size  = Vector2.new(1, 0, 0, 1, frame)
		titleLabel.Position = Vector2.new(outline.Size.X / 2, 5)
	end

	function kl:Visibility(vis)
		kl.visible = vis
		outline.Visible = vis
		inline.Visible  = vis
		frame.Visible   = vis
		accent.Visible  = vis
		titleLabel.Visible = vis
		for _, k in ipairs(keyList) do
			if k.outline then k.outline.Visible = vis end
			if k.inline  then k.inline.Visible  = vis end
			if k.frame   then k.frame.Visible   = vis end
			if k.label   then k.label.Visible   = vis end
			if k.value   then k.value.Visible   = vis end
		end
		if enabled and vis then
			SeriousHook.overlays.keylist = kl
		end
	end

	function kl:Update(updateType, updateValue)
		if updateType == "Visible" then
			kl:Visibility(updateValue)
		end
	end

	-- Attach to window
	self.overlays.keylist = kl

	if enabled then
		kl:Visibility(true)
	end

	return kl
end

SeriousHook.Window.Keylist = Keylist
return Keylist
-- overlays/Cursor.lua
-- Window:Cursor{enabled}

local function Cursor(self, info)
	info = info or {}
	local enabled = info.enabled ~= false

	local cur = {
		enabled = enabled,
		visible = false,
		cursor = nil,
		cursorInline = nil,
	}

	local function makeCursor(outlineColor, filled, thickness)
		local c = Util:Create("Triangle", nil, {
			Color       = outlineColor or Theme.cursorOuter,
			Thickness   = thickness or 2.5,
			Filled      = filled or false,
			Visible     = false,
			ZIndex      = 65,
		})
		return c
	end

	local cursorOutline = makeCursor(Theme.cursorOuter, false, 2.5)
	cur.cursor = cursorOutline

	local cursorInline = makeCursor(Theme.accent, false, 0)
	cur.cursorInline = cursorInline

	-- Hide system cursor
	local mouse = userInputService
	if enabled then
		mouse.MouseIconEnabled = false
	end

	function cur:Update()
		local m = mouse:GetMouseLocation()
		cursorOutline.PointA = Vector2.new(m.X, m.Y)
		cursorOutline.PointB = Vector2.new(m.X + 16, m.Y + 6)
		cursorOutline.PointC = Vector2.new(m.X + 6, m.Y + 16)

		if cursorInline then
			cursorInline.PointA = Vector2.new(m.X, m.Y)
			cursorInline.PointB = Vector2.new(m.X + 16, m.Y + 6)
			cursorInline.PointC = Vector2.new(m.X + 6, m.Y + 16)
		end
	end

	function cur:Visibility(vis)
		cur.visible = vis
		cursorOutline.Visible = vis and enabled
		cursorInline.Visible = vis and enabled
		if enabled then
			mouse.MouseIconEnabled = not vis
		else
			mouse.MouseIconEnabled = true
		end
		if enabled and vis then
			SeriousHook.overlays.cursor = cur
		end
	end

	function cur:Enable()
		enabled = true
		if cur.visible then
			mouse.MouseIconEnabled = false
			cursorOutline.Visible = true
			cursorInline.Visible = true
			SeriousHook.overlays.cursor = cur
		end
	end

	function cur:Disable()
		enabled = false
		mouse.MouseIconEnabled = true
		cursorOutline.Visible = false
		cursorInline.Visible = false
	end

	self.overlays.cursor = cur
	if enabled then
		cur:Visibility(true)
	end

	return cur
end

SeriousHook.Window.Cursor = Cursor
return Cursor
-- src/Toasts.lua
-- Toast system: manager singleton + API functions.
-- Flush-based widget queue (maxVisible=5). Each toast is a composite
-- drawing group (outline > inline > frame + accentLeft + title + message + progressBar).
-- Lifecycle: enter (slide+fade in 0.2s) -> hold (progress bar drains 100%->0% over duration) ->
-- exit (slide+fade out 0.2s) -> Remove.
-- Driven by the single RenderStepped in Window:Initialize via _tick(delta).

SeriousHook.Toasts = {}

local Toasts = SeriousHook.Toasts

local TQ = {}  -- toast queue (FIFO list of toast data)
Toasts._queue = TQ
Toasts._active = {}
Toasts._maxVisible = 5
Toasts._position = "bottomRight"
Toasts._anchor = Vector2.new(0, 0)  -- computed from screen size
Toasts._tickFn = nil
Toasts._counter = 0

local function getScreen()
	return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
end

local function anchorFor(pos)
	local screen = getScreen()
	if pos == "topRight" then
		return Vector2.new(screen.X - (260 + 12), 60 + 0)
	elseif pos == "topCenter" then
		return Vector2.new((screen.X - 260) / 2, 60 + 0)
	elseif pos == "bottomLeft" then
		return Vector2.new(12, screen.Y - (48 + 12))
	else
		-- default bottomRight
		return Vector2.new(screen.X - (260 + 12), screen.Y - (48 + 12))
	end
end

local function refreshAnchor()
	Toasts._anchor = anchorFor(Toasts.position)
end

refreshAnchor()

-- per-toast drawing containers
local function makeToastVisuals(toast)
	local anchor = Toasts._anchor
	local stack = toast._stackIdx

	-- Cap the stack so the mill doesn't have _stackIdx overflow when
	-- too many toasts are pending beyond maxVisible.
	if stack > 3 then stack = 3 end

	local x = anchor.X
	local y = anchor.Y + (stack * 56)

	-- outline
	local outline = SeriousHook.Util:Create("Frame", Vector2.zero, {
		Size      = Vector2.new(260, 48),
		Position  = Vector2.new(x, y),
		Color     = Theme.outline,
		Visible   = false,
		ZIndex    = 70,
	})
	toast.outline = outline

	-- inライン
	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})
	toast.inline = inline

	-- frame (background)
	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.surface0,
		Visible   = false,
	})
	toast.frame = frame

	-- accent left (type-colored vertical strip, 3px)
	local accent = SeriousHook.Util:Create("Frame", Vector2.zero, frame, {
		Size      = Vector2.new(3, 0, 1, 0, frame),
		Position  = Vector2.zero,
		Color     = toast._typeColor,
		Visible   = false,
	})
	toast.accentLeft = accent

	-- title text
	local titleBounds = SeriousHook.Util:GetTextBounds(toast.title, Theme.textsize, Theme.font)
	local title = SeriousHook.Util:Create("TextLabel", Vector2.zero, frame, {
		Text         = toast.title,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(3 + 8, 7),
		Visible      = false,
	})
	title.Position = Vector2.new(11, 7)
	toast.titleLabel = title

	-- message text (dim, below title)
	local msgBounds = SeriousHook.Util:GetTextBounds(toast.message, Theme.textsize - 1, Theme.font)
	local msgLabel = SeriousHook.Util:Create("TextLabel", Vector2.zero, frame, {
		Text         = toast.message,
		Size         = Theme.textsize - 1,
		Font         = Theme.font,
		Color        = Theme.textDim,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(11, 7 + 14),
		Visible      = false,
	})
	msgLabel.Position = Vector2.new(11, 7 + 14)
	toast.messageLabel = msgLabel

	-- progress bar: thin bar at bottom of frame
	local barW = frame.Size.X - 8
	local barH = 2
	local barBg = SeriousHook.Util:Create("Frame", Vector2.zero, frame, {
		Size      = Vector2.new(barW, 0, 0, barH, frame),
		Position  = Vector2.new(4, 0, 0, (21 - barH), frame),
		Color     = Theme.surface2 or Color3.fromRGB(40, 40, 42),
		Visible   = false,
	})
	toast.barBg = barBg

	local barFill = SeriousHook.Util:Create("Frame", Vector2.zero, barBg, {
		Size      = Vector2.new(0, 0, 1, -2, barBg),
		Position  = Vector2.zero,
		Color     = toast._typeColor,
		Visible   = false,
	})
	toast.barFill = barsFill
	-- Note: barFill may overwrite variable; we'll set Width later in _tick.

	-- start position: offset by 18 to the right (out of view), trans=0
	local sx = x + 18
	toast._startPos = Vector2.new(sx, y)
	toast._endPos = Vector2.new(x, y)
	toast._currentAlpha = 0
	toast._state = "enter"  -- enter, hold, exit
	toast._elapsed = 0
	toast._duration = toast.duration or 3

	-- Re-assign frame layers in the correct order
	SeriousHook.Util:Create("Frame", Vector2.zero, frame, {
		Size      = Vector2.new(0, barW, 1, 0, frame),
		Position  = Vector2.new(4, 0, 0, 0, frame),
	}, { frame })  -- no follow, just place it

	SeriousHook.Util:Create("Frame", Vector2.zero, barBg, {
		Size      = Vector2.new(0, 0, 1, -2, barBg),
		Position  = Vector2.zero,
		Color     = toast._typeColor,
		Visible   = false,
	}, { barFill })  -- trash, will reassign

	toast.barFill.Size = Vector2.new(0, 0, 1, -2, barBg)
	toast.barFill.Position = Vector2.zero
	toast.barFill.Color = toast._typeColor
	SeriousHook.Util:Create("Image", nil, barFill, {
		Size      = Vector2.new(1, 0, 1, 0, barFill),
		Position  = Vector2.zero,
		Visible   = false,
	})

	toast._visibleContent = {
		outline, inline, frame, accent, titleLabel, msgLabel, barBg, barFill
	}

	toast._visible = toast

	return toast
end

local function killToast(toast, instant)
	if toast._state == "dead" then return end
	toast._state = "dead"
	if toast.outline and toast.outline.Remove then
		if instant then
			toast.outline.Visible = false
			toast.inline.Visible = false
			toast.frame.Visible = false
			toast.accentLeft.Visible = false
			toast.titleLabel.Visible = false
			toast.messageLabel.Visible = false
			toast.barBg.Visible = false
			toast.barFill.Visible = false
			for _, d in ipairs(toast._visible) do
				if d.Remove then d:Remove() end
			end
		else
			-- fade out and remove via _tick
			toast._state = "exit"
			toast._elapsed = 0
		end
	end
end

-- Central ticker, called every 0.05s from Window render loop
function Toasts._tick(delta)
	local queue = Toasts._queue
	local active = Toasts._active

	-- Phase 1: pop queued toasts up to maxVisible
	while #queue > 0 and #active < Toasts._maxVisible do
		local t = table.remove(queue, 1)
		t._stackIdx = #active
		makeToastVisuals(t)
		t._state = "enter"
		t._elapsed = 0
		t._currentAlpha = 0
		t.outline.Position = t._startPos
		t.outline.Transparency = 1
		t.inline.Transparency = 1
		t.frame.Transparency = 1
		t.accentLeft.Transparency = 1
		t.titleLabel.Transparency = 1
		t.messageLabel.Transparency = 1
		t.barBg.Transparency = 1
		t.barFill.Transparency = 1
		table.insert(active, t)
	end

	-- Phase 2: update states
	for i = #active, 1, -1 do
		local t = active[i]
		t._elapsed = t._elapsed + delta

		if t._state == "enter" then
			local dur = 0.20
			local tt = t._elapsed / dur
			if tt >= 1 then tt = 1 end
			t.outline.Position = Vector2.new(
				t._startPos.X + (t._endPos.X - t._startPos.X) * tt,
				t._startPos.Y + (t._endPos.Y - t._startPos.Y) * tt
			)
			t._currentAlpha = tt
			t.outline.Transparency = 1 - tt
			t.inline.Transparency = 1 - tt
			t.frame.Transparency = 1 - tt
			t.accentLeft.Transparency = 1 - tt
			t.titleLabel.Transparency = 1 - tt
			t.messageLabel.Transparency = 1 - tt
			t.barBg.Transparency = 1 - tt
			t.barFill.Transparency = 1 - tt
			if tt >= 1 then
					t._state = "hold"
					t._elapsed = 0
					t._progress = 1
			end
		elseif t._state == "hold" then
			local dur = t._duration
			if dur == 0 then
					-- sticky: stay in hold forever until cleared
			else
					t._progress = 1 - (t._elapsed / dur)
					if t._progress <= 0 then
							t._progress = 0
							t._state = "exit"
							t._elapsed = 0
					end
					-- update bar
					local barS = t.barFill.Size
					local w = math.max(0, barS.X * t._progress)
					t.barFill.Size = Vector2.new(w, 0, 1, -2, t.barBg)
			end
		elseif t._state == "exit" then
			local dur = 0.20
			local tt = math.min(1, t._elapsed / dur)
			t.outline.Position = Vector2.new(
				t._endPos.X + (t._endPos.X - t._endPos.X) * tt,
				t._endPos.Y
			)
			-- slide right and fade
			local exitX = t._endPos.X + 18 * (1 - tt)
			t.outline.Position = Vector2.new(exitX, t._endPos.Y)
			local exitAlpha = tt
			t.outline.Transparency = exitAlpha
			t.inline.Transparency = exitAlpha
			t.frame.Transparency = exitAlpha
			t.accentLeft.Transparency = exitAlpha
			t.titleLabel.Transparency = exitAlpha
			t.messageLabel.Transparency = exitAlpha
			t.barBg.Transparency = exitAlpha
			t.barFill.Transparency = exitAlpha
			if tt >= 1 then
					-- remove now
					table.remove(active, i)
					for _, d in ipairs(t._visible or {}) do
							if d.Remove then d:Remove() end
					end
					t._visible = nil
					-- shift stack indices for remaining
					for j = i, #active do
							active[j]._stackIdx = j - 1
							active[j]._stackIdx = j - 1
					end
			end
		end
	end

	-- Phase 3: reposition visible toasts when position changes; handled by SetPosition.
end

-- Public API

function Toasts:Toast(info)
	info = info or {}
	local title = info.title or "SeriousHook"
	local message = info.message or ""
	local duration = info.duration or 3
	local position = info.position or Toasts._position

	local typeKey = info.type or "info"
	if typeKey == "info" then typeKey = "info"
	elseif typeKey == "succes" then typeKey = "success"  -- fix typo
	end

	local colors = {
		info    = Theme.accent,
		success = Theme.success,
		warn    = Theme.warn,
		error   = Theme.error,
	}
	local color = colors[typeKey] or Theme.accent

	local toast = {
		title     = title,
		message   = message,
		duration  = duration,
		position  = position,
		_typeColor = color,
	_state    = "queued",
		_elapsed = 0,
		_progress = 0,
		visible  = false,
		_stackIdx = 0,
		outline  = nil,
		inline    = nil,
		frame    = nil,
		accentLeft = nil,
		titleLabel = nil,
		messageLabel = nil,
		barBg    = nil,
		barFill  = nil,
		_startPos = Vector2.zero,
		_endPos = Vector2.zero,
		_ currentAlpha = 0,
		_counter = Toasts._counter,
	}
	Toasts._counter = Toasts._counter + 1
	table.insert(Toasts._queue, toast)

	-- If no window rendered loop yet, we can't tick; but toast will flush when Window:Initialize runs.
	return toast
end

function Toasts:Notify(msg, dur)
	return Toasts:Toast({ title = "SeriousHook", message = msg, duration = dur or 3, type = "info" })
end

function Toasts:Success(msg, dur)
	return Toasts:Toast({ title = "Success", message = msg, duration = dur or 2, type = "success" })
end

function Toasts:Warn(msg, dur)
	return Toasts:Toast({ title = "Warning", message = msg, duration = dur or 3, type = "warn" })
end

function Toasts:Error(msg, dur)
	return Toasts:Toast({ title = "Error", message = msg, duration = dur or 4, type = "error" })
end

function Toasts:Clear()
	-- kill all active toasts with immediate removal
	local active = Toasts._active
	for i = #active, 1, -1 do
		local t = active[i]
		if t._state ~= "dead" then
			killToast(t, true)
		end
		table.remove(active, i)
	end
	-- reset queue: drop queued
	Toasts._queue = {}
end

function Toasts:SetPosition(pos)
	Toasts._position = pos
	refreshAnchor()
	-- reposition active toasts that are in enter/hold state
	local active = Toasts._active
	for _, t in ipairs(active) do
		if t._state == "enter" or t._state == "hold" then
			local stack = t._stackIdx
			local x = Toasts._anchor.X
			local y = Toasts._anchor.Y + (stack * 56)
			t._endPos = Vector2.new(x, y)
		end
	end
end

function Toasts:SetMaxVisible(n)
	Toasts._maxVisible = n
end

Toasts._tick = Toasts._tick
return Toasts
