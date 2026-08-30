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
