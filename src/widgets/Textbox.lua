-- widgets/Textbox.lua
-- Section:Textbox{name, default, placeholder, numeric, maxLen, flag, callback}

local function Textbox(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Textbox"
	local def = info.def or info.Def or info.default or info.Default or ""
	local placeholder = info.placeholder or info.Placeholder or nil
	local numeric = info.numeric or info.Numeric or false
	local maxLen = info.maxLen or info.MaxLen or 100
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end

	local tb = {
		text = def or "",
		axis = self.currentAxis,
		flag = flag,
		numeric = numeric,
		maxLen = maxLen,
		placeholder = placeholder,
		focusing = false,
	}

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, tb.axis), self.section_frame, {
		Size      = Vector2.new(1, -8, 0, 15, self.section_frame),
		Position  = Vector2.new(4, tb.axis),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	tb.outline = outline

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
	tb.gradient = gradient

	local nameLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(4, tb.axis + 1), self.section_frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(4, tb.axis + 1),
		Visible      = false,
	}, self.visibleContent)
	tb.nameLabel = nameLabel

	local inputLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(4, tb.axis + (15/2) - 6), frame, {
		Text         = tb.text ~= "" and tb.text or (placeholder or ""),
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = tb.text ~= "" and Theme.textcolor or Theme.textDim,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(4, tb.axis + (15/2) - 6),
		Visible      = false,
	}, self.visibleContent)
	tb.inputLabel = inputLabel

	function tb:Get() return tb.text end

	function tb:Set(t)
		if tb.numeric then
			t = tostring(tonumber(t) or 0)
		end
		if #t > tb.maxLen then t = string.sub(t, 1, tb.maxLen) end
		tb.text = t
		tb.inputLabel.Text = tb.text ~= "" and tb.text or (tb.placeholder or "")
		if #tb.text == 0 then
			tb.inputLabel.Color = Theme.textDim
		else
			tb.inputLabel.Color = Theme.textcolor
		end
		if flag then SeriousHook.Flags[tostring(flag)] = tb end
		callback(tb.text)
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not tb.outline.Visible then return end
		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		if m.X >= sf.Position.X + 4 and m.X <= sf.Position.X + sf.Size.X - 4
			and m.Y >= sf.Position.Y + tb.axis and m.Y <= sf.Position.Y + tb.axis + 15 then
			if self.window:IsOverPopup() then return end
			tb.focusing = true
			tb.inputLabel.Color = Theme.textcolor
		end
	end

	SeriousHook._ended[#SeriousHook._ended + 1] = function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			tb.focusing = false
			if not tb.text then tb.inputLabel.Color = Theme.textDim end
		end
	end

	SeriousHook._changed[#SeriousHook._changed + 1] = function()
		if tb.focusing and tb.window.isVisible then
			-- TextInput is simulated via UserInputService.TextInput on Roblox
			-- Actual text capture delegated to executor's text input; here we just
			-- mark that the field is focused. Real text entry via UserInputService.TextInput
			-- must be hooked separately by the host executor; SeriousHook just exposes
			-- a :Get/Set contract and lets the host feed text via :Set.
			--
			-- For completeness: if this were running in an environment with TextInput,
			-- we would call UserInputService.TextInput:Connect here.
		end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = tb end

	self.currentAxis = self.currentAxis + 15 + 4
	self:Update()
	return tb
end

SectionProto.Textbox = Textbox
return Textbox
