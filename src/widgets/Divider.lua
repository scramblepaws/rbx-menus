-- widgets/Divider.lua
-- Section:Divider{text?, color?}
-- A thin line with optional centered text.

local function Divider(self, info)
	info = info or {}
	local text  = info.text or info.Text or nil
	local color = info.color or info.Color or Theme.accent

	local div = {}

	local line = SeriousHook.Util:Create("Line", nil, self.section_frame, {
		Size      = Vector2.new(self.section_frame.Size.X - 8, 1),
		Position  = Vector2.new(4, self.currentAxis + 3),
		Color     = color,
		Thickness = 1,
		Visible   = false,
	}, self.visibleContent)
	div.line = line

	if text then
		local tb = SeriousHook.Util:GetTextBounds(text, Theme.textsize - 1, Theme.font)
		local tx = SeriousHook.Util:Create("TextLabel", nil, self.section_frame, {
			Text         = text,
			Size         = Theme.textsize - 1,
			Font         = Theme.font,
			Color        = Theme.textDim,
			OutlineColor = Theme.textOutline,
			Center       = true,
			Position     = Vector2.new(self.section_frame.Size.X / 2 - tb.X / 2, self.currentAxis + 5),
			Visible      = false,
		}, self.visibleContent)
		div.textLabel = tx
		self.currentAxis = self.currentAxis + 13
	else
		self.currentAxis = self.currentAxis + 8
	end

	self:Update()
	return div
end

SectionProto.Divider = Divider
return Divider
