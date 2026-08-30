-- widgets/Label.lua
-- Section:Label{name, centered?}
-- Returns a label with Set(text).

local function Label(self, info)
	info = info or {}
	local name = info.name or info.Name or info.title or info.Title or "Label"
	local centered = info.centered or info.Centered or false

	local tb = SeriousHook.Util:GetTextBounds(name, Theme.textsize, Theme.font)
	local lbl = SeriousHook.Util:Create("TextLabel", centered and Vector2.new(
		self.section_frame.Size.X / 2 - 0, self.currentAxis
	) or Vector2.new(4, self.currentAxis), self.section_frame, {
		Text         = name,
		Size         = Theme.textsize,
		Font         = Theme.font,
		Color        = Theme.textcolor,
		OutlineColor = Theme.textOutline,
		Center       = centered,
		Position     = centered
			and Vector2.new(self.section_frame.Size.X / 2, self.currentAxis)
			or  Vector2.new(4, self.currentAxis),
		Visible      = false,
	}, self.visibleContent)

	local label = {
		textLabel = lbl,
		axis = self.currentAxis,
		Set = function(text)
			lbl.Text = text
		end,
	}
	label.Set(name)

	self.currentAxis = self.currentAxis + (tb and tb.Y + 4 or 18)
	self:Update()

	return label
end

SectionProto.Label = Label
return Label
