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
