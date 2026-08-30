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
