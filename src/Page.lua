-- SeriousHook/src/Page.lua
-- Pages: pills in Window.tabHost at {4, 24}. Show toggles currentPage + section visibility.

SeriousHook.Page = function(window, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "New Page"

	local page = {
		window    = window,
		name      = name,
		open      = false,
		sections  = {},
		page_button       = nil,
		page_button_inline = nil,
		page_button_color  = nil,
		page_button_title  = nil,
	}

	local tb = SeriousHook.Util:GetTextBounds(name, Theme.textsize, Theme.font)

	-- x position accumulates previous pills
	local x = 4
	for _, prev in ipairs(window.pages) do
		local prevW = prev.page_button and prev.page_button.Size.X or 0
		x = x + prevW + 2
	end

	-- pill: outline > inline > color
	local pill = SeriousHook.Util:Create("Frame", Vector2.new(x, 4), window.tabHost, {
		Size     = Vector2.new(tb.X + 20, 21),
		Position = Vector2.new(x, 4),
		Color    = Theme.border,
		Visible  = false,
	})
	page.page_button = pill

	local pillInline = SeriousHook.Util:Create("Frame", Vector2.new(1, 1), pill, {
		Size     = Vector2.new(1, -2, 1, -1, pill),
		Position = Vector2.new(1, 1),
		Color    = Theme.borderMuted,
		Visible  = false,
	})
	page.page_button_inline = pillInline

	local pillColor = SeriousHook.Util:Create("Frame", Vector2.new(1, 1), pillInline, {
		Size     = Vector2.new(1, -2, 1, -1, pillInline),
		Position = Vector2.new(1, 1),
		Color    = Theme.surface0,  -- closed color
		Visible  = false,
	})
	page.page_button_color = pillColor

	local pillTitle = SeriousHook.Util:Create("TextLabel", Vector2.new(
		SeriousHook.Util:Position(0.5, 0, 0, 2, pillColor).X - tb.X/2,
		2
	), pillColor, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		Center       = true,
		OutlineColor = Theme.textOutline,
		Position     = Vector2.new(
			SeriousHook.Util:Position(0.5, 0, 0, 2, pillColor).X - tb.X/2,
			2
		),
		Visible      = false,
	})
	page.page_button_title = pillTitle

	window.pages[#window.pages + 1] = page

	function page:Show()
		if window.currentPage and window.currentPage ~= page then
			local prev = window.currentPage
			prev.page_button_color.Size = Vector2.new(
				prev.page_button_inline.Size.X - 2,
				prev.page_button_inline.Size.Y - 1
			)
			prev.page_button_color.Color = Theme.surface0
			prev.open = false
			-- hide prev sections
			for _, sec in ipairs(prev.sections) do
				for _, v in ipairs(sec.visibleContent) do
					v.Visible = false
				end
			end
			window:ClosePopups()
		end

		window.currentPage = page
		page.page_button_color.Size = Vector2.new(
			page.page_button_inline.Size.X - 2,
			page.page_button_inline.Size.Y
		)
		page.page_button_color.Color = Theme.surface1  -- open color
		page.open = true

		for _, sec in ipairs(page.sections) do
			for _, v in ipairs(sec.visibleContent) do
				v.Visible = true
			end
		end

		page:Update()
	end

	function page:Update()
		page.sectionOffset = page.sectionOffset or { left = 0, right = 0 }
		page.sectionOffset.left  = 0
		page.sectionOffset.right = 0
		for _, sec in ipairs(page.sections) do
			local side = sec.side or "left"
			local off = page.sectionOffset[side]
			if sec.section_inline then
				SeriousHook.Util:UpdateOffset(sec.section_inline, Vector2.new(
					side == "right" and (window.tabHost.Size.X/2 + 2) or 5,
					5 + off
				))
			end
			page.sectionOffset[side] = page.sectionOffset[side] + (sec.section_inline and sec.section_inline.Size.Y or 0) + 5
		end
		-- keep window centered (Section layers also reposition via Window:Move in drag, but pages/Sections do it here too)
		window:Move(window.mainFrame.Position)
	end

	page.sectionOffset = { left = 0, right = 0 }

	return setmetatable(page, { __index = page })
end

-- Page factory attached to Window for ergonomics: Win:Page{...}
do
	local origWindow = SeriousHook.Window
	SeriousHook.Window = function(...)
		local win = origWindow(...)
		function win:Page(info)
			local page = SeriousHook.Page(self, info)
			-- connect click on pill
			SeriousHook._began[#SeriousHook._began + 1] = function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					and win.isVisible
					and SeriousHook.Util:MouseOverDrawing({
						page.page_button.Position.X,
						page.page_button.Position.Y,
						page.page_button.Position.X + page.page_button.Size.X,
						page.page_button.Position.Y + page.page_button.Size.Y
					})
					and win.currentPage ~= page
				then
					page:Show()
				end
			end
			return page
		end
		return win
	end
end
