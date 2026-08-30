-- Helper to wrap any function into a form that can be placed anywhere.
-- SeriousHook exposes a global SeriousHook namespace - each widget adds a
-- method to the Section prototype by closing over SectionProto.
local SectionProto = {}
SectionProto.__index = SectionProto
SeriousHook.SectionProto = SectionProto

-- Section constructor (must be defined before widgets use it)
SeriousHook.Section = function(page, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "New Section"
	local side = (info.side or info.Side or "left"):lower()

	local window = page.window
	local section = {
		window         = window,
		page           = page,
		name           = name,
		side           = side,
		visibleContent = {},
		currentAxis    = 20,
	}
	SeriousHook.Util:Create("Frame", Vector2.new(
		side == "right" and (window.tabHost.Size.X / 2 + 2) or 5,
		5 + (page.sectionOffset[side] or 0)
	), window.tabHost, {
		Size      = SeriousHook.Util:Size(0.5, -7, 0, 22, window.tabHost),
		Position  = Vector2.new(
			side == "right" and (window.tabHost.Size.X / 2 + 2) or 5,
			5 + (page.sectionOffset[side] or 0)
		),
		Color     = Theme.borderMuted,
		Visible   = false,
	}, section.visibleContent)
	section.section_inline = section.visibleContent[#section.visibleContent]

	local outline = SeriousHook.Util:Create("Frame", Vector2.one, section.section_inline, {
		Size      = Vector2.new(1, -2, 1, -2, section.section_inline),
		Position  = Vector2.one,
		Color     = Theme.border,
		Visible   = false,
	}, section.visibleContent)
	section.section_outline = outline

	local frame = SeriousHook.Util:Create("Frame", Vector2.one, outline, {
		Size      = Vector2.new(1, -2, 1, -2, outline),
		Position  = Vector2.one,
		Color     = Theme.surface0,
		Visible   = false,
	}, section.visibleContent)
	section.section_frame = frame

	local accent = SeriousHook.Util:Create("Frame", Vector2.zero, frame, {
		Size      = Vector2.new(1, 0, 0, 2, frame),
		Position  = Vector2.zero,
		Color     = Theme.accent,
		Visible   = false,
	}, section.visibleContent)
	section.section_accent = accent

	local title = SeriousHook.Util:Create("TextLabel", Vector2.new(3, 3), frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(3, 3),
		Visible      = false,
	}, section.visibleContent)
	section.section_title = title

	page.sections = page.sections or {}
	page.sections[#page.sections + 1] = section

	page.sectionOffset = page.sectionOffset or { left = 0, right = 0 }
	page.sectionOffset[side] = (page.sectionOffset[side] or 0) + 100 + 5

	-- Each widget's method will mutate section.currentAxis and call Update.
	function section:Update()
		local h = math.max(22, section.currentAxis + 4)
		self.section_inline.Size = SeriousHook.Util:Size(0.5, -7, 0, h, self.window.tabHost)
		self.section_outline.Size = Vector2.new(1, -2, 1, -2, self.section_inline)
		self.section_frame.Size = Vector2.new(1, -2, 1, -2, self.section_outline)
		self.section_accent.Size = Vector2.new(1, 0, 0, 2, self.section_frame)
		self.section_title.Position = Vector2.new(3, 3)
	end

	return setmetatable(section, SectionProto)
end

-- MultiSection: N tabs sharing one host; returns unpackable sections.
SeriousHook.MultiSection = function(page, info)
	info = info or {}
	local tabs = info.tabs or info.Tabs or {}
	local side = (info.side or info.Side or "left"):lower()
	local height = info.height or info.Height or 150

	local window = page.window
	local ms = {
		window        = window,
		page          = page,
		tabs          = tabs,
		side          = side,
		height        = height,
		current       = nil,
		backup        = {},
		visibleContent = {},
		sections      = {},
		headerHeight  = 17,
	}

	page.sections = page.sections or {}

	local xBase = side == "right" and (window.tabHost.Size.X / 2 + 2) or 5
	local yBase = 5 + (page.sectionOffset[side] or 0)

	local secInline = SeriousHook.Util:Create("Frame", Vector2.new(xBase, yBase), window.tabHost, {
		Size      = SeriousHook.Util:Size(0.5, -7, 0, height, window.tabHost),
		Position  = Vector2.new(xBase, yBase),
		Color     = Theme.borderMuted,
		Visible   = false,
	}, ms.visibleContent)

	local secOutline = SeriousHook.Util:Create("Frame", Vector2.one, secInline, {
		Size      = Vector2.new(1, -2, 1, -2, secInline),
		Position  = Vector2.one,
		Color     = Theme.border,
		Visible   = false,
	}, ms.visibleContent)

	local secFrame = SeriousHook.Util:Create("Frame", Vector2.one, secOutline, {
		Size      = Vector2.new(1, -2, 1, -2, secOutline),
		Position  = Vector2.one,
		Color     = Theme.surface0,
		Visible   = false,
	}, ms.visibleContent)

	local secAccent = SeriousHook.Util:Create("Frame", Vector2.zero, secFrame, {
		Size      = Vector2.new(1, 0, 0, 2, secFrame),
		Position  = Vector2.zero,
		Color     = Theme.accent,
		Visible   = false,
	}, ms.visibleContent)

	local backFrame = SeriousHook.Util:Create("Frame", Vector2.new(0, 2), secFrame, {
		Size      = Vector2.new(1, 0, 0, ms.headerHeight, secFrame),
		Position  = Vector2.new(0, 0, 0, 2),
		Color     = Theme.surface1,
		Visible   = false,
	}, ms.visibleContent)

	local bottomLine = SeriousHook.Util:Create("Frame", Vector2.new(0, ms.headerHeight - 1), secFrame, {
		Size      = Vector2.new(1, 0, 0, 1, secFrame),
		Position  = Vector2.new(0, ms.headerHeight - 1),
		Color     = Theme.border,
		Visible   = false,
	}, ms.visibleContent)

	local xAxis = 0
	for i, tabName in ipairs(tabs) do
		local tb = SeriousHook.Util:GetTextBounds(tabName, Theme.textsize, Theme.font)
		local tabFrame = SeriousHook.Util:Create("Frame", Vector2.new(xAxis, 0), backFrame, {
			Size      = SeriousHook.Util:Size(0, tb.X + 14, 1, -1, backFrame),
			Position  = Vector2.new(xAxis, 0),
			Color     = i == 1 and Theme.surface0 or Theme.surface1,
			Visible   = false,
		}, ms.visibleContent)
		local tabLine = SeriousHook.Util:Create("Frame", Vector2.new(tabFrame.Size.X, 0), tabFrame, {
			Size      = Vector2.new(0, 1, 1, 0, tabFrame),
			Position  = Vector2.new(tabFrame.Size.X, 0),
			Color     = Theme.outline,
			Visible   = false,
		}, ms.visibleContent)
		local tabTitle = SeriousHook.Util:Create("TextLabel", Vector2.new(
			tabFrame.Size.X / 2 - tb.X / 2, 1
		), tabFrame, {
			Text         = tabName,
			Size         = Theme.textsize,
			Font         = Theme.font,
			Color        = Theme.textcolor,
			OutlineColor = Theme.textOutline,
			Center       = true,
			Position     = Vector2.new(tabFrame.Size.X / 2 - tb.X / 2, 1),
			Visible      = false,
		}, ms.visibleContent)
		xAxis = xAxis + tb.X + 15

		-- Create a hidden section that widgets will be inserted into
		local sub = SeriousHook.Section(page, { name = tabName, side = side })
		sub.msection_frame    = tabFrame
		sub.msection_line     = tabLine
		sub.msection_title    = tabTitle
		sub.msection_bottomline = tabLine
		sub._msSection = true
		sub._msParent  = ms
		ms.sections[#ms.sections + 1] = sub

		if i == 1 then ms.current = sub end
	end

	for _, v in ipairs(ms.visibleContent) do
		ms.backup[#ms.backup + 1] = v
	end

	function ms:SetActive(section)
		if self.current == section then return end
		if self.current then
			for _, draw in ipairs(self.current.visibleContent) do
				draw.Visible = false
			end
		end
		self.current = section
		self.visibleContent = {}
		for _, draw in ipairs(self.backup) do
			draw.Visible = true
			self.visibleContent[#self.visibleContent + 1] = draw
		end
		for _, draw in ipairs(section.visibleContent) do
			draw.Visible = true
			self.visibleContent[#self.visibleContent + 1] = draw
		end
	end

	ms:SetActive(ms.current)

	page.sectionOffset = page.sectionOffset or { left = 0, right = 0 }
	page.sectionOffset[side] = (page.sectionOffset[side] or 0) + 100 + 5

	return table.unpack(ms.sections)
end

-- Click handling for MultiSection tabs
do
	local function AddTabClick(ms)
		SeriousHook._began[#SeriousHook._began + 1] = function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
			if not ms.window.isVisible then return end
			local page = ms.page
			if not (page.open and page.window.currentPage == page) then return end
			for _, sub in ipairs(ms.sections) do
				local m = SeriousHook.Util:MouseLocation()
				local frame = sub.msection_frame
				if frame
					and m.X >= frame.Position.X
					and m.X <= frame.Position.X + frame.Size.X
					and m.Y >= frame.Position.Y
					and m.Y <= frame.Position.Y + frame.Size.Y
				then
					if ms.current ~= sub then
						ms:SetActive(sub)
						return
					end
				end
			end
		end
	end

	function SectionProto:_attachMultiSectionClicks(ms)
		if not ms._clickAttached then
			AddTabClick(ms)
			ms._clickAttached = true
		end
	end
end
