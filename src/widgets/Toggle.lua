-- widgets/Toggle.lua
-- Section:Toggle{name, default, flag, callback}
-- + AddColor{default, alpha, flag, callback}
-- + AddKeybind{default, mode, keyName, flag, callback}

local function Toggle(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Toggle"
	local def = info.def or info.Def or info.default or info.Default or false
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end

	local t = {
		current = def,
		axis = self.currentAxis,
		addedAxis = 0,
		colorpickers = 0,
		keybind = nil,
		flag = flag,
	}

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, t.axis), self.section_frame, {
		Size      = Vector2.new(0, 15, 0, 15),
		Position  = Vector2.new(4, t.axis),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	t.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	}, self.visibleContent)
	t.inline = inline

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = t.current and Theme.accent or Theme.surface1,
		Visible   = false,
	}, self.visibleContent)
	t.frame = frame

	local gradient = SeriousHook.Util:Create("Image", nil, frame, {
		Size      = Vector2.new(1, 0, 1, 0, frame),
		Position  = Vector2.zero,
		Transparency = 0.5,
		Visible   = false,
	}, self.visibleContent)
	table.insert(t._imgs or {}, gradient)
	SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")

	local tb = SeriousHook.Util:GetTextBounds(name, Theme.textsize, Theme.font)
	local label = SeriousHook.Util:Create("TextLabel", Vector2.new(23, t.axis + (15/2) - (tb.Y/2)), self.section_frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(23, t.axis + (15/2) - tb.Y/2),
		Visible      = false,
	}, self.visibleContent)
	t.label = label

	local function onToggle()
		t.current = not t.current
		frame.Color = t.current and Theme.accent or Theme.surface1
		if flag then
			SeriousHook.Flags[tostring(flag)] = t
		end
		callback(t.current)
	end

	function t:Get() return t.current end
	function t:Set(v)
		if v == t.current then return end
		t.current = v
		frame.Color = t.current and Theme.accent or Theme.surface1
		if flag then SeriousHook.Flags[tostring(flag)] = t end
		callback(t.current)
	end

	-- Click handler attached to beGan
	local clickBegan = SeriousHook._began
	clickBegan[#clickBegan + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not t.outline.Visible then return end
		local m = SeriousHook.Util:MouseLocation()
		local x1 = self.section_frame.Position.X
		local y1 = self.section_frame.Position.Y + t.axis
		local x2 = self.section_frame.Position.X + self.section_frame.Size.X - t.addedAxis
		local y2 = self.section_frame.Position.Y + t.axis + 15
		if m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2 then
			if self.window:IsOverPopup() then return end
			onToggle()
		end
	end

	if flag then SeriousHook.Flags[tostring(flag)] = t end

	self.currentAxis = self.currentAxis + 15 + 4
	self:Update()

	-- AddColor
	function t:AddColor(info2)
		info2 = info2 or {}
		local def2 = info2.def or info2.Def or info2.default or info2.Default or Color3.fromRGB(255, 0, 0)
		local transp = info2.transparency or info2.Transparency or info2.transp or info2.Transp or info2.alpha or info2.Alpha or nil
		local flag2 = info2.flag or info2.Flag or info2.pointer or info2.Pointer or nil
		local callback2 = info2.callback or info2.callBack or info2.Callback or function() end
		local cpinfo = info2.info or info2.Info or name

		local hh, ss, vv = def2:ToHSV()
		local cp = {
			toggle = t,
			axis = t.axis,
			index = t.colorpickers,
			current = { hh, ss, vv, transp and transp or 0 },
			holding = { picker = false, huepicker = false, transparency = false },
			holder = {
				inline = nil,
				picker = nil,
				picker_cursor = nil,
				huepicker = nil,
				huepicker_cursor = {},
				transparency = nil,
				transparencybg = nil,
				transparency_cursor = {},
				drawings = {},
			},
		}

		local cpOut = SeriousHook.Util:Create("Frame", Vector2.new(self.section_frame.Size.X - (t.colorpickers == 0 and 34 or 68), t.axis), self.section_frame, {
			Size      = Vector2.new(0, 30, 0, 15),
			Position  = Vector2.new(self.section_frame.Size.X - (t.colorpickers == 0 and 34 or 68), t.axis),
			Color     = Theme.border,
			Visible   = false,
		}, self.visibleContent)
		t._cpOutlines = t._cpOutlines or {}
		t._cpOutlines[#t._cpOutlines + 1] = cpOut

		local cpIn = SeriousHook.Util:Create("Frame", Vector2.one, cpOut, {
			Size      = Vector2.new(1, -2, 1, -2, cpOut),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
			Visible   = false,
		}, self.visibleContent)

		local transpImg
		if transp then
			transpImg = SeriousHook.Util:Create("Image", Vector2.one, cpIn, {
				Size      = Vector2.new(1, -2, 1, -2, cpIn),
				Position  = Vector2.one,
				Visible   = false,
			}, self.visibleContent)
		end

		local cpF = SeriousHook.Util:Create("Frame", Vector2.one, cpIn, {
			Size      = Vector2.new(1, -2, 1, -2, cpIn),
			Position  = Vector2.one,
			Color     = def2,
			Transparency = transp and 1 - transp or 1,
			Visible   = false,
		}, self.visibleContent)
		cp.frame = cpF

		local cpG = SeriousHook.Util:Create("Image", nil, cpF, {
			Size      = Vector2.new(1, 0, 1, 0, cpF),
			Position  = Vector2.zero,
			Transparency = 0.5,
			Visible   = false,
		}, self.visibleContent)
		cp._g = cpG
		SeriousHook.Util:LoadImage(cpG, "gradient", "https://i.imgur.com/5hmlrjX.png")

		if transp then
			SeriousHook.Util:LoadImage(transpImg, "cptransp", "https://i.imgur.com/IIPee2A.png")
		end

		function cp:Set(color, transpVal)
			if typeof(color) == "table" then
				if color.Color and color.Transparency then
					local h, s, v = table.unpack(color.Color)
					cp.current = { h, s, v, color.Transparency }
					cpF.Color = Color3.fromHSV(h, s, v)
					cpF.Transparency = 1 - color.Transparency
					callback2(Color3.fromHSV(h, s, v), color.Transparency)
				else
					cp.current = color
					cpF.Color = Color3.fromHSV(color[1], color[2], color[3])
					cpF.Transparency = 1 - (color[4] or 0)
					callback2(Color3.fromHSV(color[1], color[2], color[3]), color[4] or 0)
				end
			elseif typeof(color) == "Color3" then
				local h, s, v = color:ToHSV()
				cp.current = { h, s, v, transpVal or 0 }
				cpF.Color = Color3.fromHSV(h, s, v)
				cpF.Transparency = 1 - (transpVal or 0)
				callback2(Color3.fromHSV(h, s, v), transpVal or 0)
			end
			if flag2 then
				SeriousHook.Flags[tostring(flag2)] = cp
			end
		end

		function cp:Get()
			return {
				Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3]),
				Transparency = cp.current[4],
			}
		end

		function cp:Refresh()
			if not cp.open then return end
			local m = SeriousHook.Util:MouseLocation()
			if cp.holding.picker and cp.holder.picker then
				cp.current[2] = math.clamp(m.X - cp.holder.picker.Position.X, 0, cp.holder.picker.Size.X) / cp.holder.picker.Size.X
				cp.current[3] = 1 - math.clamp(m.Y - cp.holder.picker.Position.Y, 0, cp.holder.picker.Size.Y) / cp.holder.picker.Size.Y
				cp.holder.picker_cursor.Position = SeriousHook.Util:Position(cp.current[2], -3, 1 - cp.current[3], -3, cp.holder.picker)
				SeriousHook.Util:UpdateOffset(cp.holder.picker_cursor, {Vector2.new((cp.holder.picker.Size.X * cp.current[2]) - 3, (cp.holder.picker.Size.Y * (1 - cp.current[3])) - 3), cp.holder.picker})
				if cp.holder.transparencybg then
					cp.holder.transparencybg.Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3])
				end
			elseif cp.holding.huepicker and cp.holder.huepicker then
				cp.current[1] = math.clamp(m.Y - cp.holder.huepicker.Position.Y, 0, cp.holder.huepicker.Size.Y) / cp.holder.huepicker.Size.Y
				cp.holder.huepicker_cursor[1].Position = SeriousHook.Util:Position(0, -3, cp.current[1], -3, cp.holder.huepicker)
				cp.holder.huepicker_cursor[2].Position = Vector2.new(cp.holder.huepicker_cursor[1].Position.X + 1, cp.holder.huepicker_cursor[1].Position.Y + 1)
				cp.holder.huepicker_cursor[3].Position = Vector2.new(cp.holder.huepicker_cursor[2].Position.X + 1, cp.holder.huepicker_cursor[2].Position.Y + 1)
				cp.holder.huepicker_cursor[3].Color = Color3.fromHSV(cp.current[1], 1, 1)
				SeriousHook.Util:UpdateOffset(cp.holder.huepicker_cursor[1], {Vector2.new(-3, (cp.holder.huepicker.Size.Y * cp.current[1]) - 3), cp.holder.huepicker})
				cp.holder.background.Color = Color3.fromHSV(cp.current[1], 1, 1)
				if cp.holder.transparency_cursor and cp.holder.transparency_cursor[3] then
					cp.holder.transparency_cursor[3].Color = Color3.fromHSV(0, 0, 1 - cp.current[4])
				end
				if cp.holder.transparencybg then
					cp.holder.transparencybg.Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3])
				end
			elseif cp.holding.transparency and cp.holder.transparency then
				cp.current[4] = 1 - math.clamp(m.X - cp.holder.transparency.Position.X, 0, cp.holder.transparency.Size.X) / cp.holder.transparency.Size.X
				cp.holder.transparency_cursor[1].Position = SeriousHook.Util:Position(1 - cp.current[4], -3, 0, -3, cp.holder.transparency)
				cp.holder.transparency_cursor[2].Position = Vector2.new(cp.holder.transparency_cursor[1].Position.X + 1, cp.holder.transparency_cursor[1].Position.Y + 1)
				cp.holder.transparency_cursor[3].Position = Vector2.new(cp.holder.transparency_cursor[2].Position.X + 1, cp.holder.transparency_cursor[2].Position.Y + 1)
				cp.holder.transparency_cursor[3].Color = Color3.fromHSV(0, 0, 1 - cp.current[4])
				cpF.Transparency = 1 - cp.current[4]
				SeriousHook.Util:UpdateTransparency(cpF, 1 - cp.current[4])
				SeriousHook.Util:UpdateOffset(cp.holder.transparency_cursor[1], {Vector2.new((cp.holder.transparency.Size.X * (1 - cp.current[4])) - 3, -3), cp.holder.transparency})
				cp.holder.background.Color = Color3.fromHSV(cp.current[1], 1, 1)
			end
			cp:Set(cp.current)
		end

		SeriousHook._began[#SeriousHook._began + 1] = function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if not self.page.open or not self.window.isVisible then return end
			local m = SeriousHook.Util:MouseLocation()
			local baseX = self.section_frame.Size.X - (cp.index == 0 and 34 + 2 or 68 + 2)
			local baseY = cp.axis
			local hitClose = m.X >= self.section_frame.Position.X + baseX
				and m.X <= self.section_frame.Position.X + self.section_frame.Size.X
				and m.Y >= self.section_frame.Position.Y + baseY
				and m.Y <= self.section_frame.Position.Y + baseY + 15
			if cp.open and cp.holder.inline then
				local ix, iy = cp.holder.inline.Position.X, cp.holder.inline.Position.Y
				if m.X >= ix and m.X <= ix + cp.holder.inline.Size.X and m.Y >= iy and m.Y <= iy + cp.holder.inline.Size.Y then
					if cp.holder.picker and m.X >= cp.holder.picker.Position.X - 2 and m.X <= cp.holder.picker.Position.X + cp.holder.picker.Size.X + 2
						and m.Y >= cp.holder.picker.Position.Y - 2 and m.Y <= cp.holder.picker.Position.Y + cp.holder.picker.Size.Y + 2 then
						cp.holding.picker = true
					elseif cp.holder.huepicker and m.X >= cp.holder.huepicker.Position.X - 2 and m.X <= cp.holder.huepicker.Position.X + cp.holder.huepicker.Size.X + 2
						and m.Y >= cp.holder.huepicker.Position.Y - 2 and m.Y <= cp.holder.huepicker.Position.Y + cp.holder.huepicker.Size.Y + 2 then
						cp.holding.huepicker = true
					elseif cp.holder.transparency and m.X >= cp.holder.transparency.Position.X - 2 and m.X <= cp.holder.transparency.Position.X + cp.holder.transparency.Size.X + 2
						and m.Y >= cp.holder.transparency.Position.Y - 2 and m.Y <= cp.holder.transparency.Position.Y + cp.holder.transparency.Size.Y + 2 then
						cp.holding.transparency = true
					end
				elseif hitClose then
					if cp.open then
						cp.open = false
						for _, v in ipairs(cp.holder.drawings) do SeriousHook.Util:Remove(v) end
						cp.holder.drawings = {}
						cp.holder.inline = nil
						self.window.currentContent.frame = nil
						self.window.currentContent.colorpicker = nil
					end
				end
			elseif hitClose then
				if not cp.open then
					self.window:ClosePopups()
					cp.open = true
					local w = self.section_frame.Size.X - 8
					local panelH = transp and 219 or 200
					local panel = SeriousHook.Util:Create("Frame", Vector2.new(4, cp.axis + 19), self.section_frame, {
						Size      = Vector2.new(1, -8, 0, panelH, self.section_frame),
						Position  = Vector2.new(4, cp.axis + 19),
						Color     = Theme.border,
					}, cp.holder.drawings)
					cp.holder.inline = panel

					local pIn = SeriousHook.Util:Create("Frame", Vector2.one, panel, {
						Size      = Vector2.new(1, -2, 1, -2, panel),
						Position  = Vector2.one,
						Color     = Theme.borderMuted,
					}, cp.holder.drawings)

					local pF = SeriousHook.Util:Create("Frame", Vector2.one, pIn, {
						Size      = Vector2.new(1, -2, 1, -2, pIn),
						Position  = Vector2.one,
						Color     = Theme.surface0,
					}, cp.holder.drawings)

					local pAcc = SeriousHook.Util:Create("Frame", Vector2.zero, pF, {
						Size      = Vector2.new(1, 0, 0, 2, pF),
						Position  = Vector2.zero,
						Color     = Theme.accent,
					}, cp.holder.drawings)

					local pTitle = SeriousHook.Util:Create("TextLabel", Vector2.new(4, 2), pF, {
						Text         = cpinfo,
						Size         = Theme.textsize,
						Font         = Theme.font,
						Color        = Theme.textcolor,
						OutlineColor = Theme.textOutline,
						Position     = Vector2.new(4, 2),
					}, cp.holder.drawings)

					local pickerW = 1 - 27
					local pickerH = transp and -40 or -21
					local pickerOut = SeriousHook.Util:Create("Frame", Vector2.new(4, 17), pF, {
						Size      = Vector2.new(1, pickerW, 1, pickerH, pF),
						Position  = Vector2.new(4, 17),
						Color     = Theme.border,
					}, cp.holder.drawings)

					local pickerIn = SeriousHook.Util:Create("Frame", Vector2.one, pickerOut, {
						Size      = Vector2.new(1, -2, 1, -2, pickerOut),
						Position  = Vector2.one,
						Color     = Theme.borderMuted,
					}, cp.holder.drawings)

					cp.holder.background = SeriousHook.Util:Create("Frame", Vector2.one, pickerIn, {
						Size      = Vector2.new(1, -2, 1, -2, pickerIn),
						Position  = Vector2.one,
						Color     = Color3.fromHSV(cp.current[1], 1, 1),
					}, cp.holder.drawings)

					local pickerImg = SeriousHook.Util:Create("Image", nil, cp.holder.background, {
						Size      = Vector2.new(1, 0, 1, 0, cp.holder.background),
						Position  = Vector2.zero,
					}, cp.holder.drawings)
					cp.holder.picker = pickerImg
					SeriousHook.Util:LoadImage(pickerImg, "valsat", "https://i.imgur.com/wpDRqVH.png")

					local pcW = (pickerImg.Size.X * cp.current[2]) - 3
					local pcH = (pickerImg.Size.Y * (1 - cp.current[3])) - 3
					local pc = SeriousHook.Util:Create("Image", Vector2.new(pcW, pcH), pickerImg, {
						Size      = Vector2.new(0, 6, 0, 6, pickerImg),
						Position  = Vector2.new(cp.current[2], -3, 1 - cp.current[3], -3, pickerImg),
					}, cp.holder.drawings)
					cp.holder.picker_cursor = pc
					SeriousHook.Util:LoadImage(pc, "cursor", "https://raw.githubusercontent.com/mvonwalk/splix-assets/main/Images-cursor.png")

					local hueOut = SeriousHook.Util:Create("Frame", Vector2.new(pF.Size.X - 19, 17), pF, {
						Size      = Vector2.new(0, 15, 1, pickerH, pF),
						Position  = Vector2.new(pF.Size.X - 19, 17),
						Color     = Theme.border,
					}, cp.holder.drawings)

					local hueIn = SeriousHook.Util:Create("Frame", Vector2.one, hueOut, {
						Size      = Vector2.new(1, -2, 1, -2, hueOut),
						Position  = Vector2.one,
						Color     = Theme.borderMuted,
					}, cp.holder.drawings)

					local hueImg = SeriousHook.Util:Create("Image", Vector2.one, hueIn, {
						Size      = Vector2.new(1, -2, 1, -2, hueIn),
						Position  = Vector2.one,
					}, cp.holder.drawings)
					cp.holder.huepicker = hueImg
					SeriousHook.Util:LoadImage(hueImg, "hue", "https://i.imgur.com/iEOsHFv.png")

					local hcX = -3
					local hcY = (hueImg.Size.Y * cp.current[1]) - 3
					cp.holder.huepicker_cursor[1] = SeriousHook.Util:Create("Frame", Vector2.new(hcX, hcY), hueImg, {
						Size      = Vector2.new(0, 6, 0, 6, hueImg),
						Position  = Vector2.new(0, -3, cp.current[1], -3, hueImg),
						Color     = Theme.border,
					}, cp.holder.drawings)

					cp.holder.huepicker_cursor[2] = SeriousHook.Util:Create("Frame", Vector2.one, cp.holder.huepicker_cursor[1], {
						Size      = Vector2.new(1, -2, 1, -2, cp.holder.huepicker_cursor[1]),
						Position  = Vector2.one,
						Color     = Theme.textcolor,
					}, cp.holder.drawings)

					cp.holder.huepicker_cursor[3] = SeriousHook.Util:Create("Frame", Vector2.one, cp.holder.huepicker_cursor[2], {
						Size      = Vector2.new(1, -2, 1, -2, cp.holder.huepicker_cursor[2]),
						Position  = Vector2.one,
						Color     = Color3.fromHSV(cp.current[1], 1, 1),
					}, cp.holder.drawings)

					if transp then
						local trOut = SeriousHook.Util:Create("Frame", Vector2.new(4, pF.Size.X - 19), pF, {
							Size      = Vector2.new(1, -27, 0, 15, pF),
							Position  = Vector2.new(4, pF.Size.X - 19),
							Color     = Theme.border,
						}, cp.holder.drawings)

						local trIn = SeriousHook.Util:Create("Frame", Vector2.one, trOut, {
							Size      = Vector2.new(1, -2, 1, -2, trOut),
							Position  = Vector2.one,
							Color     = Theme.borderMuted,
						}, cp.holder.drawings)

						cp.holder.transparencybg = SeriousHook.Util:Create("Frame", Vector2.one, trIn, {
							Size      = Vector2.new(1, -2, 1, -2, trIn),
							Position  = Vector2.one,
							Color     = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3]),
						}, cp.holder.drawings)

						local trImg = SeriousHook.Util:Create("Image", Vector2.one, trIn, {
							Size      = Vector2.new(1, -2, 1, -2, trIn),
							Position  = Vector2.one,
						}, cp.holder.drawings)
						cp.holder.transparency = trImg
						cp.holder.transparencybg = cp.holder.transparencybg
						SeriousHook.Util:LoadImage(trImg, "transp", "https://i.imgur.com/ncssKbH.png")

						local trcX = (trImg.Size.X * (1 - cp.current[4])) - 3
						local trcY = -3
						cp.holder.transparency_cursor[1] = SeriousHook.Util:Create("Frame", Vector2.new(trcX, trcY), trImg, {
							Size      = Vector2.new(0, 6, 1, 6, trImg),
							Position  = Vector2.new(1 - cp.current[4], -3, 0, -3, trImg),
							Color     = Theme.border,
						}, cp.holder.drawings)

						cp.holder.transparency_cursor[2] = SeriousHook.Util:Create("Frame", Vector2.one, cp.holder.transparency_cursor[1], {
							Size      = Vector2.new(1, -2, 1, -2, cp.holder.transparency_cursor[1]),
							Position  = Vector2.one,
							Color     = Theme.textcolor,
						}, cp.holder.drawings)

						cp.holder.transparency_cursor[3] = SeriousHook.Util:Create("Frame", Vector2.one, cp.holder.transparency_cursor[2], {
							Size      = Vector2.new(1, -2, 1, -2, cp.holder.transparency_cursor[2]),
							Position  = Vector2.one,
							Color     = Color3.fromHSV(0, 0, 1 - cp.current[4]),
						}, cp.holder.drawings)
					end

					self.window.currentContent.frame = pIn
					self.window.currentContent.colorpicker = cp
				else
					cp.open = false
					for _, v in ipairs(cp.holder.drawings) do SeriousHook.Util:Remove(v) end
					cp.holder.drawings = {}
					cp.holder.inline = nil
					self.window.currentContent.frame = nil
					self.window.currentContent.colorpicker = nil
				end
			end
		end

		SeriousHook._ended[#SeriousHook._ended + 1] = function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if cp.holding.picker then cp.holding.picker = false end
				if cp.holding.huepicker then cp.holding.huepicker = false end
				if cp.holding.transparency then cp.holding.transparency = false end
			end
		end

		SeriousHook._changed[#SeriousHook._changed + 1] = function()
			if cp.open and (cp.holding.picker or cp.holding.huepicker or cp.holding.transparency) then
				if cp.holding.picker or cp.holding.huepicker or cp.holding.transparency then
					cp:Refresh()
				end
			end
		end

		if flag2 then SeriousHook.Flags[tostring(flag2)] = cp end

		t.addedAxis = t.addedAxis + (cp.index == 0 and 34 or 68)
		t.colorpickers = t.colorpickers + 1
		self:Update()
		return cp, t
	end

	-- AddKeybind
	function t:AddKeybind(info2)
		info2 = info2 or {}
		local def2 = info2.def or info2.Def or info2.default or info2.Default or nil
		local flag2 = info2.flag or info2.Flag or info2.pointer or info2.Pointer or nil
		local mode = info2.mode or info2.Mode or "Always"
		local keybindName = info2.keybindName or info2.KeybindName or info2.Keybindname or nil
		local callback2 = info2.callback or info2.callBack or info2.Callback or function() end

		local kb = {
			keybindName = keybindName or name,
			axis = t.axis,
			current = {},
			selecting = false,
			mode = mode,
			open = false,
			modemenu = { buttons = {}, drawings = {} },
			active = mode == "Always",
		}
		t.keybind = kb

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

		local kbOut = SeriousHook.Util:Create("Frame", Vector2.new(self.section_frame.Size.X - 44, t.axis), self.section_frame, {
			Size      = Vector2.new(0, 40, 0, 17),
			Position  = Vector2.new(self.section_frame.Size.X - 44, t.axis),
			Color     = Theme.border,
			Visible   = false,
		}, self.visibleContent)
		t._kbOutlines = t._kbOutlines or {}
		t._kbOutlines[#t._kbOutlines + 1] = kbOut

		local kbIn = SeriousHook.Util:Create("Frame", Vector2.one, kbOut, {
			Size      = Vector2.new(1, -2, 1, -2, kbOut),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
			Visible   = false,
		})

		local kbF = SeriousHook.Util:Create("Frame", Vector2.one, kbIn, {
			Size      = Vector2.new(1, -2, 1, -2, kbIn),
			Position  = Vector2.one,
			Color     = Theme.surface1,
			Visible   = false,
		})

		local kbG = SeriousHook.Util:Create("Image", nil, kbF, {
			Size      = Vector2.new(1, 0, 1, 0, kbF),
			Position  = Vector2.zero,
			Transparency = 0.5,
			Visible   = false,
		})
		SeriousHook.Util:LoadImage(kbG, "gradient", "https://i.imgur.com/5hmlrjX.png")

		local kbVal = SeriousHook.Util:Create("TextLabel", Vector2.new(kbOut.Size.X / 2, 1), kbOut, {
			Text         = "...",
			Size         = Theme.textsize,
			Font         = Theme.font,
			Color        = Theme.textcolor,
			OutlineColor = Theme.textOutline,
			Center       = true,
			Position     = Vector2.new(kbOut.Size.X / 2, 1),
			Visible      = false,
		})

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
						kbVal.Text = #kb.current > 0 and kb:Shorten(kb.current[2]) or "..."
						return true
					end
				end
			end
			return false
		end

		function kb:Get() return kb.current end
		function kb:Set(tbl)
			kb.current = tbl
			kbVal.Text = #kb.current > 0 and kb:Shorten(kb.current[2]) or "..."
		end
		function kb:Active() return kb.active end
		function kb:Reset()
			for _, btn in ipairs(kb.modemenu.buttons) do
				btn.Color = btn.Text == kb.mode and Theme.accent or Theme.textcolor
			end
			kb.active = mode == "Always"
			if kb.current[1] and kb.current[2] then
				callback2(Enum[kb.current[1]][kb.current[2]], kb.active)
			end
		end

		if def2 then kb:Change(def2) end

		local function onPress(keycode, active)
			if mode == "Hold" then
				kb.active = self:Get()
				if kb.active then
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Add(kb.keybindName, kbVal.Text) end
				else
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
				end
				if active ~= kb.active then callback2(keycode, kb.active) end
			elseif mode == "Toggle" then
				local old = kb.active
				kb.active = not kb.active and self:Get() or false
				if kb.active then
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Add(kb.keybindName, kbVal.Text) end
				else
					if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
				end
				if kb.active ~= old then callback2(keycode, kb.active) end
			end
		end

		SeriousHook._began[#SeriousHook._began + 1] = function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if not self.page.open or not self.window.isVisible then return end
			local m = SeriousHook.Util:MouseLocation()
			local x1 = self.section_frame.Position.X + (self.section_frame.Size.X - 44 - 2)
			local y1 = kb.axis
			local x2 = self.section_frame.Position.X + self.section_frame.Size.X
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
					kbF.Color = Theme.surface0
				end
			end
			-- Keybind trigger
			if kb.current[1] and kb.current[2] then
				local kc = Enum[kb.current[1]][kb.current[2]]
				if input.KeyCode == kc or input.UserInputType == kc then
					onPress(kc, true)
				end
			end
			if kb.selecting then
				if input.KeyCode and input.KeyCode.Name ~= "Unknown" then
					if kb:Change(input.KeyCode) then
						kb.selecting = false
						kb.active = mode == "Always"
						kbF.Color = Theme.surface1
						if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
						callback2(Enum[kb.current[1]][kb.current[2]], kb.active)
					end
				elseif input.UserInputType then
					if kb:Change(input.UserInputType) then
						kb.selecting = false
						kb.active = mode == "Always"
						kbF.Color = Theme.surface1
						if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
						callback2(Enum[kb.current[1]][kb.current[2]], kb.active)
					end
				end
			end
		end

		SeriousHook._ended[#SeriousHook._ended + 1] = function(input)
			if kb.active and mode == "Hold" then
				if kb.current[1] and kb.current[2] then
					local kc = Enum[kb.current[1]][kb.current[2]]
					if input.KeyCode == kc or input.UserInputType == kc then
						kb.active = false
						if SeriousHook.overlays.keylist then SeriousHook.overlays.keylist:Remove(kb.keybindName) end
						callback2(kc, false)
					end
				end
			end
		end

		-- RMB opens mode menu
		SeriousHook._began[#SeriousHook._began + 1] = function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
			if not self.page.open or not self.window.isVisible then return end
			local m = SeriousHook.Util:MouseLocation()
			local x1 = self.section_frame.Position.X + (self.section_frame.Size.X - 44 - 2)
			local y1 = kb.axis
			local x2 = self.section_frame.Position.X + self.section_frame.Size.X
			local y2 = kb.axis + 17
			if m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2 then
				if self.window:IsOverPopup() then return end
				if not kb.selecting then
					self.window:ClosePopups()
					kb.open = true
					local mmF = SeriousHook.Util:Create("Frame", Vector2.new(kbOut.Size.X + 2, 0), kbOut, {
						Size      = Vector2.new(0, 64, 0, 49),
						Position  = Vector2.new(1, 2, 0, 0, kbOut),
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
						Size      = Vector2.new(1, 0, 1, 0, mmFrame),
						Position  = Vector2.zero,
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

		if flag2 then SeriousHook.Flags[tostring(flag2)] = kb end

		self.currentAxis = self.currentAxis + 17 + 4
		self:Update()
		return kb
	end

	return t
end

SectionProto.Toggle = Toggle
return Toggle
