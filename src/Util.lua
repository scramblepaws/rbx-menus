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

-- Expose for concatenated builds (return is dead code in single-file mode)
SeriousHook.Util = U

return U
