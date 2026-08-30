-- widgets/Colorpicker.lua
-- Section:Colorpicker{name, default, alpha, flag, callback}
-- + AddColor{default, alpha, flag, callback}

local function Colorpicker(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Colorpicker"
	local def = info.def or info.Def or info.default or info.Default or Color3.fromRGB(255, 0, 0)
	local transp = info.transparency or info.Transparency or info.transp or info.Transp or info.alpha or info.Alpha or nil
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback2 = info.callback or info.callBack or info.Callback or function() end
	local cpinfo = info.info or info.Info or name

	local cp = {
		open = false,
		current = { def:ToHSV() },
		holding = { picker = false, huepicker = false, transparency = false },
		holder = { drawings = {}, inline = nil },
		flag = flag,
	}

	if transp then cp.current[4] = transp end

	local outline = SeriousHook.Util:Create("Frame", Vector2.new(4, cp.axis), self.section_frame, {
		Size      = Vector2.new(0, 25, 0, 15, self.section_frame),
		Position  = Vector2.new(4, cp.axis),
		Color     = Theme.border,
		Visible   = false,
	}, self.visibleContent)
	cp.outline = outline

	local inline = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = def,
		Transparency = transp and 1 - transp or 1,
		Visible   = false,
	})
	cp.frame = frame

	local gradient = SeriousHook.Util:Create("Image", nil, frame, {
		Size        = Vector2.new(1, 0, 1, 0, frame),
		Position    = Vector2.zero,
		Transparency = 0.5,
		Visible     = false,
	})
	cp.gradient = gradient
	SeriousHook.Util:LoadImage(gradient, "gradient", "https://i.imgur.com/5hmlrjX.png")

	local transpImg
	if transp then
		transpImg = SeriousHook.Util:Create("Image", Vector2.one, inline, {
			Size      = Vector2.new(1, -2, 1, -2, inline),
			Position  = Vector2.one,
			Visible   = false,
		}, self.visibleContent)
		SeriousHook.Util:LoadImage(transpImg, "cptransp", "https://i.imgur.com/IIPee2A.png")
		cp.transpImg = transpImg
	end

	local nameLabel = SeriousHook.Util:Create("TextLabel", Vector2.new(28, cp.axis + (15/2) - 6), self.section_frame, {
		Text         = cpinfo,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(28, cp.axis + (15/2) - 6),
		Visible      = false,
	}, self.visibleContent)
	cp.nameLabel = nameLabel

	function cp:Get()
		return {
			Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3]),
			Transparency = cp.current[4] or 0,
		}
	end

	function cp:Set(color, transpVal)
		if typeof(color) == "table" then
			if color.Color and color.Transparency then
				local h, s, v = table.unpack(color.Color)
				cp.current = { h, s, v, color.Transparency }
			else
				cp.current = color
			end
		elseif typeof(color) == "Color3" then
			local h, s, v = color:ToHSV()
			cp.current = { h, s, v, transpVal or 0 }
		end
		cp.frame.Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3])
		cp.frame.Transparency = 1 - (cp.current[4] or 0)
		if flag then SeriousHook.Flags[tostring(flag)] = cp end
		callback2(Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3]), cp.current[4] or 0)
	end

	function cp:Refresh()
		if not cp.open then return end
		local m = SeriousHook.Util:MouseLocation()
		if cp.holding.picker then
			local picker = cp.holder.picker
			if picker then
				cp.current[2] = math.clamp(m.X - picker.Position.X, 0, picker.Size.X) / picker.Size.X
				cp.current[3] = 1 - math.clamp(m.Y - picker.Position.Y, 0, picker.Size.Y) / picker.Size.Y
				if cp.holder.picker_cursor then
					cp.holder.picker_cursor.Position = SeriousHook.Util:Position(cp.current[2], -3, 1 - cp.current[3], -3, picker)
					SeriousHook.Util:UpdateOffset(cp.holder.picker_cursor, {
						Vector2.new((picker.Size.X * cp.current[2]) - 3, (picker.Size.Y * (1 - cp.current[3])) - 3),
						picker,
					})
				end
				if cp.holder.transparencybg then
					cp.holder.transparencybg.Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3])
				end
			end
		elseif cp.holding.huepicker then
			local huepicker = cp.holder.huepicker
			if huepicker then
				cp.current[1] = math.clamp(m.Y - huepicker.Position.Y, 0, huepicker.Size.Y) / huepicker.Size.Y
				if cp.holder.huepicker_cursor then
					cp.holder.huepicker_cursor[1].Position = SeriousHook.Util:Position(0, -3, cp.current[1], -3, huepicker)
					SeriousHook.Util:UpdateOffset(cp.holder.huepicker_cursor[1], {
						Vector2.new(-3, (huepicker.Size.Y * cp.current[1]) - 3),
						huepicker,
					})
					for i = 2, 3 do
						local prev = cp.holder.huepicker_cursor[i - 1]
						if prev then
							cp.holder.huepicker_cursor[i].Position = Vector2.new(prev.Position.X + 1, prev.Position.Y + 1)
						end
					end
				end
				cp.holder.background.Color = Color3.fromHSV(cp.current[1], 1, 1)
				if cp.holder.transparency_cursor and cp.holder.transparency_cursor[3] then
					cp.holder.transparency_cursor[3].Color = Color3.fromHSV(0, 0, 1 - cp.current[4])
				end
				if cp.holder.transparencybg then
					cp.holder.transparencybg.Color = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3])
				end
			end
		elseif cp.holding.transparency then
			local transpBar = cp.holder.transparency
			if transpBar then
				cp.current[4] = 1 - math.clamp(m.X - transpBar.Position.X, 0, transpBar.Size.X) / transpBar.Size.X
				if cp.holder.transparency_cursor then
					cp.holder.transparency_cursor[1].Position = SeriousHook.Util:Position(1 - cp.current[4], -3, 0, -3, transpBar)
					SeriousHook.Util:UpdateOffset(cp.holder.transparency_cursor[1], {
						Vector2.new((transpBar.Size.X * (1 - cp.current[4])) - 3, -3),
						transpBar,
					})
					for i = 2, 3 do
						local prev = cp.holder.transparency_cursor[i - 1]
						if prev then
							cp.holder.transparency_cursor[i].Position = Vector2.new(prev.Position.X + 1, prev.Position.Y + 1)
						end
					end
				end
				cp.frame.Transparency = 1 - cp.current[4]
				SeriousHook.Util:UpdateTransparency(cp.frame, 1 - cp.current[4])
				cp.holder.background.Color = Color3.fromHSV(cp.current[1], 1, 1)
			end
		end
		cp:Set(cp.current)
	end

	local function closeColorpicker()
		cp.open = false
		for _, v in ipairs(cp.holder.drawings) do SeriousHook.Util:Remove(v) end
		cp.holder.drawings = {}
		cp.holder.inline = nil
		if cp.frame then cp.frame = nil end
	end

	local function openColorpicker()
		cp.open = true
		local W = self.section_frame.Size.X - 8
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
		cp.holder.background = pF

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

		local pickerBg = SeriousHook.Util:Create("Frame", Vector2.one, pickerIn, {
			Size      = Vector2.new(1, -2, 1, -2, pickerIn),
			Position  = Vector2.one,
			Color     = Color3.fromHSV(cp.current[1], 1, 1),
		}, cp.holder.drawings)
		cp.holder.background2 = pickerBg

		local pickerImg = SeriousHook.Util:Create("Image", nil, pickerBg, {
			Size      = Vector2.new(1, 0, 1, 0, pickerBg),
			Position  = Vector2.zero,
		}, cp.holder.drawings)
		cp.holder.picker = pickerImg
		SeriousHook.Util:LoadImage(pickerImg, "valsat", "https://i.imgur.com/wpDRqVH.png")

		local pcX = (pickerImg.Size.X * cp.current[2]) - 3
		local pcY = (pickerImg.Size.Y * (1 - cp.current[3])) - 3
		local pc = SeriousHook.Util:Create("Image", Vector2.new(pcX, pcY), pickerImg, {
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
		local hcCursor1 = SeriousHook.Util:Create("Frame", Vector2.new(hcX, hcY), hueImg, {
			Size      = Vector2.new(0, 6, 0, 6, hueImg),
			Position  = Vector2.new(0, -3, cp.current[1], -3, hueImg),
			Color     = Theme.border,
		}, cp.holder.drawings)
		cp.holder.huepicker_cursor = { hcCursor1 }

		local hcCursor2 = SeriousHook.Util:Create("Frame", Vector2.one, hcCursor1, {
			Size      = Vector2.new(1, -2, 1, -2, hcCursor1),
			Position  = Vector2.one,
			Color     = Theme.textcolor,
		}, cp.holder.drawings)
		cp.holder.huepicker_cursor[2] = hcCursor2

		local hcCursor3 = SeriousHook.Util:Create("Frame", Vector2.one, hcCursor2, {
			Size      = Vector2.new(1, -2, 1, -2, hcCursor2),
			Position  = Vector2.one,
			Color     = Color3.fromHSV(cp.current[1], 1, 1),
		}, cp.holder.drawings)
		cp.holder.huepicker_cursor[3] = hcCursor3

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

			local trBg = SeriousHook.Util:Create("Frame", Vector2.one, trIn, {
				Size      = Vector2.new(1, -2, 1, -2, trIn),
				Position  = Vector2.one,
				Color     = Color3.fromHSV(cp.current[1], cp.current[2], cp.current[3]),
			}, cp.holder.drawings)
			cp.holder.transparencybg = trBg

			local trImg = SeriousHook.Util:Create("Image", Vector2.one, trIn, {
				Size      = Vector2.new(1, -2, 1, -2, trIn),
				Position  = Vector2.one,
			}, cp.holder.drawings)
			cp.holder.transparency = trImg
			SeriousHook.Util:LoadImage(trImg, "transp", "https://i.imgur.com/ncssKbH.png")

			local trcX = (trImg.Size.X * (1 - cp.current[4])) - 3
			local trcY = -3
			local trCursor1 = SeriousHook.Util:Create("Frame", Vector2.new(trcX, trcY), trImg, {
				Size      = Vector2.new(0, 6, 1, 6, trImg),
				Position  = Vector2.new(1 - cp.current[4], -3, 0, -3, trImg),
				Color     = Theme.border,
			}, cp.holder.drawings)
			cp.holder.transparency_cursor = { trCursor1 }

			local trCursor2 = SeriousHook.Util:Create("Frame", Vector2.one, trCursor1, {
				Size      = Vector2.new(1, -2, 1, -2, trCursor1),
				Position  = Vector2.one,
				Color     = Theme.textcolor,
			}, cp.holder.drawings)
			cp.holder.transparency_cursor[2] = trCursor2

			local trCursor3 = SeriousHook.Util:Create("Frame", Vector2.one, trCursor2, {
				Size      = Vector2.new(1, -2, 1, -2, trCursor2),
				Position  = Vector2.one,
				Color     = Color3.fromHSV(0, 0, 1 - cp.current[4]),
			}, cp.holder.drawings)
			cp.holder.transparency_cursor[3] = trCursor3
		end

		self.window.currentContent.frame = pIn
		self.window.currentContent.colorpicker = cp
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if not self.page.open or not self.window.isVisible then return end
		if not cp.outline.Visible then return end
		local m = SeriousHook.Util:MouseLocation()
		local sf = self.section_frame
		local x1 = sf.Position.X + (sf.Size.X - 27 - 2)
		local y1 = cp.axis
		local x2 = sf.Position.X + sf.Size.X
		local y2 = cp.axis + 15
		if m.X >= x1 and m.X <= x2 and m.Y >= y1 and m.Y <= y2 then
			if self.window:IsOverPopup() then return end
			if cp.open and cp.holder.inline then
				local ix, iy = cp.holder.inline.Position.X, cp.holder.inline.Position.Y
				if m.X >= ix and m.X <= ix + cp.holder.inline.Size.X and m.Y >= iy and m.Y <= iy + cp.holder.inline.Size.Y then
					if cp.holding.picker or cp.holding.huepicker or cp.holding.transparency then
						-- still inside popup, check sub-regions
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
					end
				else
					closeColorpicker()
				end
			else
				if not cp.open then
					self.window:ClosePopups()
					openColorpicker()
				else
					closeColorpicker()
				end
			end
		end
	end

	SeriousHook._began[#SeriousHook._began + 1] = function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if cp.open then closeColorpicker() end
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

	if flag then SeriousHook.Flags[tostring(flag)] = cp end

	self.currentAxis = self.currentAxis + 15 + 4
	self:Update()
	return cp
end

-- AddColor attaches a second colorpicker inline to a toggle.
function SectionProto.AddColor(toggle, info)
	info = info or {}
	local def = info.def or info.Def or info.default or info.Default or Color3.fromRGB(255, 0, 0)
	local transp = info.transparency or info.Transparency or info.transp or info.Transp or info.alpha or info.Alpha or nil
	local flag = info.flag or info.Flag or info.pointer or info.Pointer or nil
	local callback = info.callback or info.callBack or info.Callback or function() end
	local cpinfo = info.info or info.Info or toggle.name or "Color"

	local cp = Colorpicker(addColorSection, info)
	return cp, toggle
end

SectionProto.Colorpicker = Colorpicker
return Colorpicker
