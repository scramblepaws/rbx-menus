-- overlays/Keylist.lua
-- Window:Keylist{enabled, position}

local function Keylist(self, info)
	info = info or {}
	local enabled = info.enabled ~= false
	local pos = info.position or Vector2.new(10, 0.4)

	local kl = {
		enabled = enabled,
		visible = false,
		keys = {},          -- list of {name, keytext, outline, inline, frame, label, value}
		outline = nil,
		inline = nil,
		frame = nil,
		accent = nil,
		title = nil,
	}

	-- Build static container layers
	local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
	local x = pos.X
	local yFraction = pos.Y or 0.4
	local baseY = yFraction * (screenSize and screenSize.Y or 1080)

	local outline = Util:Create("Frame", Vector2.zero, self.outline or nil, {
		Size      = Vector2.new(150, 22),
		Position  = Vector2.new(x, baseY),
		Color     = Theme.border,
		Visible   = false,
		ZIndex    = 55,
	})
	kl.outline = outline

	local inline = Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.borderMuted,
		Visible   = false,
	})
	kl.inline = inline

	local frame = Util:Create("Frame", Vector2.one, inline, {
		Size      = Vector2.new(1, -2, 1, -2, inline),
		Position  = Vector2.one,
		Color     = Theme.surface0,
		Visible   = false,
	})
	kl.frame = frame

	local accent = Util:Create("Frame", Vector2.zero, frame, {
		Size      = Vector2.new(1, 0, 0, 1, frame),
		Position  = Vector2.zero,
		Color     = Theme.accent,
		Visible   = false,
	})
	kl.accent = accent

	local titleLabel = Util:Create("TextLabel", Vector2.zero, outline, {
		Text         = "- Keybinds -",
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Center       = true,
		Position     = Vector2.new(outline.Size.X / 2, 5),
		Visible      = false,
	})
	kl.titleLabel = titleLabel

	-- Internal storage mirror (so Remove works cleanly)
	local keyList = {}

	function kl:Add(keybindname, keybindtext)
		if not keybindname or not keybindtext then return end
		-- Avoid duplicates
		for _, existing in ipairs(keyList) do
			if existing.name == tostring(keybindname) then return end
		end

		local keyObj = {
			name = tostring(keybindname),
			keytext = tostring(keybindtext),
		}

		local idx = #keyList + 1
		local yPos = 1 + ((idx - 1) * 18)

		local keyOut = Util:Create("Frame", Vector2.zero, outline, {
			Size      = Vector2.new(outline.Size.X - 2, 0, 0, 18),
			Position  = Vector2.new(1, 1, 0, yPos),
			Color     = Theme.surface1,
			Visible   = false,
		})
		keyObj.outline = keyOut

		local keyIn = Util:Create("Frame", Vector2.one, keyOut, {
			Size      = Vector2.new(1, -2, 1, -2, keyOut),
			Position  = Vector2.one,
			Color     = Theme.borderMuted,
			Visible   = false,
		})
		keyObj.inline = keyIn

		local keyF = Util:Create("Frame", Vector2.one, keyIn, {
			Size      = Vector2.new(1, -2, 1, -2, keyIn),
			Position  = Vector2.one,
			Color     = Theme.surface0,
			Visible   = false,
		})
		keyObj.frame = keyF

		local kbTextBounds = Util:GetTextBounds(keybindname, Theme.textsize, Theme.font)
		local keyLabel = Util:Create("TextLabel", Vector2.zero, keyOut, {
			Text         = keybindname,
			Size         = Theme.textsize,
			Font         = Theme.font,
			Color        = Theme.textcolor,
			OutlineColor = Theme.textOutline,
			Position     = Vector2.new(4, 3),
			Visible      = false,
		})
		keyObj.label = keyLabel

		local valPosX = (keyOut.Size.X - (Util:GetTextBounds(keybindtext, Theme.textsize, Theme.font).X)) - 4
		local keyVal = Util:Create("TextLabel", Vector2.zero, keyOut, {
			Text         = keybindtext,
			Size         = Theme.textsize,
			Font         = Theme.font,
			Color        = Theme.textcolor,
			OutlineColor = Theme.textOutline,
			Position     = Vector2.new(valPosX, 3),
			Visible      = false,
		})
		keyObj.value = keyVal

		table.insert(keyList, keyObj)
		kl.keys = keyList

		-- Resize outline height based on count
		local newH = 22 + ((#keyList - 1) * 18)
		outline.Size = Vector2.new(150, newH)
		inline.Size  = Vector2.new(1, -2, 1, -2, outline)
		frame.Size   = Vector2.new(1, -2, 1, -2, inline)
		accent.Size  = Vector2.new(1, 0, 0, 1, frame)
		titleLabel.Position = Vector2.new(outline.Size.X / 2, 5)

		if enabled and kl.visible then
			keyOut.Visible = true
			keyIn.Visible  = true
			keyF.Visible   = true
			keyLabel.Visible = true
			keyVal.Visible = true
		end
	end

	function kl:Remove(keybindname)
		for i = #keyList, 1, -1 do
			if keyList[i].name == tostring(keybindname) then
				local k = keyList[i]
				if k.outline and k.outline.Remove then k.outline:Remove() end
				if k.inline  and k.inline.Remove  then k.inline.Remove() end
				if k.frame   and k.frame.Remove   then k.frame.Remove() end
				if k.label   and k.label.Remove   then k.label.Remove() end
				if k.value   and k.value.Remove   then k.value.Remove() end
				table.remove(keyList, i)
			end
		end
		kl.keys = keyList

		-- Shrink outline
		local newH = 22 + ((#keyList - 1) * 18)
		outline.Size = Vector2.new(150, math.max(22, newH))
		inline.Size  = Vector2.new(1, -2, 1, -2, outline)
		frame.Size   = Vector2.new(1, -2, 1, -2, inline)
		accent.Size  = Vector2.new(1, 0, 0, 1, frame)
		titleLabel.Position = Vector2.new(outline.Size.X / 2, 5)
	end

	function kl:Resort()
		-- Re-sort and reposition
		for i, k in ipairs(keyList) do
			local yPos = 1 + ((i - 1) * 18)
			if k.outline then k.outline.Position = Vector2.new(1, 1, 0, yPos) end
			if k.inline  then k.inline.Position  = Vector2.new(1, 1, 0, 0, k.outline) end
			if k.frame   then k.frame.Position   = Vector2.new(1, 1, 0, 0, k.inline) end
			if k.label   then k.label.Position   = Vector2.new(4, 3) end
			if k.value   then
				local valX = (k.outline.Size.X - (Util:GetTextBounds(k.keytext, Theme.textsize, Theme.font).X)) - 4
				k.value.Position = Vector2.new(valX, 3)
			end
		end
		local newH = 22 + ((#keyList - 1) * 18)
		outline.Size = Vector2.new(150, math.max(22, newH))
		inline.Size  = Vector2.new(1, -2, 1, -2, outline)
		frame.Size   = Vector2.new(1, -2, 1, -2, inline)
		accent.Size  = Vector2.new(1, 0, 0, 1, frame)
		titleLabel.Position = Vector2.new(outline.Size.X / 2, 5)
	end

	function kl:Visibility(vis)
		kl.visible = vis
		outline.Visible = vis
		inline.Visible  = vis
		frame.Visible   = vis
		accent.Visible  = vis
		titleLabel.Visible = vis
		for _, k in ipairs(keyList) do
			if k.outline then k.outline.Visible = vis end
			if k.inline  then k.inline.Visible  = vis end
			if k.frame   then k.frame.Visible   = vis end
			if k.label   then k.label.Visible   = vis end
			if k.value   then k.value.Visible   = vis end
		end
		if enabled and vis then
			SeriousHook.overlays.keylist = kl
		end
	end

	function kl:Update(updateType, updateValue)
		if updateType == "Visible" then
			kl:Visibility(updateValue)
		end
	end

	-- Attach to window
	self.overlays.keylist = kl

	if enabled then
		kl:Visibility(true)
	end

	return kl
end

SeriousHook.Window.Keylist = Keylist
return Keylist
