-- widgets/Keybind.lua
-- Section:Keybind{name, default, mode, keyName, flag, callback}
-- Standalone keybind widget (separate from Toggle:AddKeybind).

local function Keybind(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Keybind"
	local def = info.def or info.Def or info.default or info.Default or nil
	local mode = info.mode or info.Mode or "Always"
	local keybindName = info.keybindName or info.KeybindName or info.Keybindname or nil
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end

	local kb = {
		keybindName = keybindName or name,
		axis = self.currentAxis,
		current = {},
		selecting = false,
		mode = mode,
		open = false,
		modemenu = { buttons = {}, drawings = {} },
		active = mode == "Always",
		flag = flag,
	}

	local allowedKeys = {
		"Q","W","E","R","T","Y","U","I","O","P",
		"A","S","D","F","G","H","J","K","L",
		"Z","X","C","V","B","N","M",
		"One","Two","Three","Four","Five","Six","Seven","Eight","Nine","0",
		"Insert","Tab","Home","End",
		"LeftAlt","LeftControl","LeftShift","RightAlt","RightControl","RightShift","CapsLock"
	}
	local allowedMouse = { "MouseButton1", "MouseButton2", "MouseButton3" }
	local shortenMap = {
		["MouseButton1"] = "MB1",
		["MouseButton2"] = "MB2",
		["MouseButton3"] = "MB3",
		["Insert"] = "Ins",
		["LeftAlt"] = "LAlt",
		["LeftControl"] = "LC",
		["LeftShift"] = "LS",
		["RightAlt"] = "RAlt",
		["RightControl"] = "RC",
		["RightShift"] = "RS",
		["CapsLock"] = "Caps",
	}

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, kb.axis), self.section_frame, {
		Size      = Vector2.new(0, 15, 0, 17, self.section_frame),
		Position  = Vector2.new(4, kb.axis),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	kb.outline = outline

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

	local valLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(outline.Size.X - 4, 1), outline, {
		Text         = "...",
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Center       = false,
		Position     = Vector2.new(outline.Size.X - 4, 1),
		Visible      = false,
	})
	kb.valLabel = valLabel

	local nameLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(4, kb.axis + 1), self.section_frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(4, kb.axis + 1),
		Visible      = false,
	}, self.visibleContent)
	kb.nameLabel = nameLabel

	function kb:Shorten(s)
		for k, v in pairs(shortenMap) do s = string.gsub(s, k, v) end
		return s
	end

	function kb:Change(input)
		if not input then return false end
		if input.EnumType then
			if input.EnumType == Enum.KeyCode or input.EnumType == Enum.UserInputType then
				if table.find(allowedKeys, input.Name) or table.find(allowedMouse, input.Name) then
					kb.current = { input.EnumType == Enum.KeyCode and "KeyCode" or "UserInputType", input.Name }
					kb.valLabel.Text = #kb.current > 0 and kb:Shorten(kb.current[2]) or "..."
					return true
				end
			end
		end
		return false
	end

	function kb:Get() return kb.current end
	function kb:Set(tbl)
		kb.current = tbl
		kb.valLabel.Text = #kb.current > 0 and kb:Shorten(kb.current[2]) or "..."
	end
	function kb:Active() return kb.active end
	function kb:Reset()
		for _, btn in ipairs(kb.modemenu.buttons) do
			btn.Color = btn.Text == kb.mode and Theme.accent or Theme.textcolor
		end
		kb.active = kb.mode == "Always"
		if kb.current[1] and kb.current[2] then
			callback(Enum[kb.current[1]][kb.current[2]], kb.active)
		end
	end

	if def then kb:Change(def) end

	local function onPress(keycode, active)
		if kb.mode == "Hold" then
			kb.active = kb:Get() ~= nil -- simplified: active when keydown
			if kb.active then
				if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Add(kb.keybindName, kb.valLabel.Text) end
			else
				if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
			end
			callback(keycode, kb.active)
		elseif kb.mode == "Toggle" then
			local old = kb.active
			kb.active = not kb.active
			if kb.active then
				if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Add(kb.keybindName, kb.valLabel.Text) end
			else
				if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
			end
			if kb.active ~= old then callback(keycode, kb.active) end
		else
			callback(keycode, true)
		end
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not kb.outline.Visible then return end

		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		local x1 = sf.Position.X + (sf.Size.X - 19 - 2)
		local y1 = kb.axis
		local x2 = sf.Position.X + sf.Size.X
		local y2 = kb.axis + 17

		if m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2 then
			if self.window:IsOverPopup() then return end
			if kb.open and kb.modemenu.frame then
				local mf = kb.modemenu.frame
				if m.X >= mf.Position.X and m.X <= mf.Position.X + mf.Size.X
					and m.Y >= mf.Position.Y and m.Y <= mf.Position.Y + mf.Size.Y then
					local changed = false
					for i2, btn in ipairs(kb.modemenu.buttons) do
						if m.Y >= mf.Position.Y + (15 * (i2 - 1))
							and m.Y <= mf.Position.Y + (15 * (i2 - 1)) + 15 then
							kb.mode = btn.Text
							changed = true
							break
						end
					end
					if changed then kb:Reset() end
				else
					kb.open = false
					for _, v in ipairs(kb.modemenu.drawings) do SeriousHook.Util:Remove(v) end
					kb.modemenu.drawings = {}
					kb.modemenu.buttons = {}
					kb.modemenu.frame = nil
					self.window.currentContent.frame = nil
					self.window.currentContent.keybind = nil
				end
			else
				kb.selecting = true
				kb.frame.Color = Theme.surface0
			end
		end

		if kb.selecting then
			if input.KeyCode and input.KeyCode.Name ~= "Unknown" then
				if kb:Change(input.KeyCode) then
					kb.selecting = false
					kb.active = kb.mode == "Always"
					kb.frame.Color = Theme.surface1
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
					callback(Enum[kb.current[1]][kb.current[2]], kb.active)
				end
			elseif input.UserInputType then
				if kb:Change(input.UserInputType) then
					kb.selecting = false
					kb.active = kb.mode == "Always"
					kb.frame.Color = Theme.surface1
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
					callback(Enum[kb.current[1]][kb.current[2]], kb.active)
				end
			end
		end

		-- Key trigger
		if kb.current[1] and kb.current[2] then
			local kc = Enum[kb.current[1]][kb.current[2]]
			if input.KeyCode == kc or input.UserInputType == kc then
				onPress(kc, true)
			end
		end
	end

	SeriousHook._ended[#SeriousHook._ended + 1] = function(input)
		if kb.active and kb.mode == "Hold" then
			if kb.current[1] and kb.current[2] then
				local kc = Enum[kb.current[1]][kb.current[2]]
				if input.KeyCode == kc or input.UserInputType == kc then
					kb.active = false
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
					callback(kc, false)
				end
			end
		end
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not kb.outline.Visible then return end

		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		local x1 = sf.Position.X + (sf.Size.X - 19 - 2)
		local y1 = kb.axis
		local x2 = sf.Position.X + sf.Size.X
		local y2 = kb.axis + 17

		if m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2 then
			if self.window:IsOverPopup() then return end
			if not kb.selecting then
				self.window:ClosePopups()
				kb.open = true
				local mmF = SeriousHook.Util:Create("Frame", Vector2.new(outline.Size.X + 2, 0), outline, {
					Size      = Vector2.new(0, 64, 0, 49),
					Position  = Vector2.new(1, 2, 0, 0, outline),
					Color     = Theme.border,
				}, kb.modemenu.drawings)
				kb.modemenu.frame = mmF

				local mmIn = SeriousHook.Util:Create("Frame", Vector2.one, mmF, {
					Size      = Vector2.new(1, -2, 1, -2, mmF),
					Position  = Vector2.one,
					Color     = Theme.borderMuted,
				}, kb.modemenu.drawings)

				local mmFrame = SeriousHook.Util:Create("Frame", Vector2.one, mmIn, {
					Size      = Vector2.new(1, -2, 1, -2, mmIn),
					Position  = Vector2.one,
					Color     = Theme.surface1,
				}, kb.modemenu.drawings)

				local mmG = SeriousHook.Util:Create("Image", nil, mmFrame, {
					Size        = Vector2.new(1, 0, 1, 0, mmFrame),
					Position    = Vector2.zero,
					Transparency = 0.5,
				}, kb.modemenu.drawings)
				SeriousHook.Util:LoadImage(mmG, "gradient", "https://i.imgur.com/5hmlrjX.png")

				for i2, modeName in ipairs({ "Always", "Toggle", "Hold" }) do
					local btn = SeriousHook.Util:Create("TextLabel", Vector2.new(mmF.Size.X / 2, 15 * (i2 - 1)), mmF, {
						Text         = modeName,
						Size         = Theme.textsize,
						Font         = Theme.font,
						Color        = modeName == kb.mode and Theme.accent or Theme.textcolor,
						OutlineColor = Theme.textOutline,
						Center       = true,
						Position     = Vector2.new(mmF.Size.X / 2, 15 * (i2 - 1)),
					}, kb.modemenu.drawings)
					kb.modemenu.buttons[#kb.modemenu.buttons + 1] = btn
				end

				self.window.currentContent.frame = mmF
				self.window.currentContent.keybind = kb
			end
		end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = kb end

	self.currentAxis = self.currentAxis + 17 + 4
	self:Update()
	return kb
end

SectionProto.Keybind = Keybind
return Keybind
