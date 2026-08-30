-- widgets/Button.lua
-- Section:Button{name, flag, callback}

local function Button(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Button"
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end

	local b = { axis = self.currentAxis, flag = flag }

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, b.axis), self.section_frame, {
		Size      = Vector2.new(1, -8, 0, 20, self.section_frame),
		Position  = Vector2.new(4, b.axis),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	b.outline = outline

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
	local title = SeriousHook.Util:Create("TextLabel", Vector2.new(frame.Size.X/2, 1), frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Center       = true,
		Position     = Vector2.new(frame.Size.X/2, 1),
		Visible      = false,
	})

	function b:Click()
		if flag then SeriousHook.Flags[tostring(flag)] = b end
		callback()
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.visible then return end
		if not b.outline.Visible then return end
		local m = SeriousHook.Util:MousePosition()
		local sf = self.section_frame
		if m.X >= sf.Position.X and m.X <= sf.Position.X + sf.Size.X
			and m.Y >= sf.Position.Y + b.axis and m.Y <= sf.Position.Y + b.axis + 20 then
			if self.window:IsOverPopup() then return end
			b:Click()
		end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = b end

	self.currentAxis = self.currentAxis + 20 + 4
	self:Update()
	return b
end

SectionProto.Button = Button
return Button
