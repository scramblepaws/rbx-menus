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
