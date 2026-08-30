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
