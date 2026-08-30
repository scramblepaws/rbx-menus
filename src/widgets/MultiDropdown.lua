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
