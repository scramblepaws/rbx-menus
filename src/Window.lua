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
