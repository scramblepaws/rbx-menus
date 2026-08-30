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
