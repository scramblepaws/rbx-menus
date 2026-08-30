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
