-- SeriousHook/src/Theme.lua
-- Theme table with live-update via Theme:Set + registry for animated transitions.
-- Opts into type colors for Toasts; extended palette beyond Splix.

local TH = {
	accent      = Color3.fromRGB(105, 90, 255),  -- SeriousHook violet
	surface0    = Color3.fromRGB(20, 20, 22),    -- dark_contrast
	surface1    = Color3.fromRGB(28, 28, 30),    -- light_contrast
	surface2    = Color3.fromRGB(36, 36, 38),
	border      = Color3.fromRGB(0, 0, 0),       -- outline
	borderMuted = Color3.fromRGB(50, 50, 52),    -- inline
	text        = Color3.fromRGB(255, 255, 255), -- textcolor
	textDim     = Color3.fromRGB(180, 180, 180),
	textOutline  = Color3.fromRGB(0, 0, 0),      -- textborder
	success     = Color3.fromRGB(70, 200, 120),
	warn        = Color3.fromRGB(255, 180, 0),
	error       = Color3.fromRGB(255, 70, 70),
	cursorOuter = Color3.fromRGB(10, 10, 10),    -- cursoroutline
	font        = 2,     -- Drawing.Font.Monospace
	textsize    = 13,
}

TH._listeners = {}

function TH:Set(key, value)
	if TH[key] == value then return end
	TH[key] = value
	for _, cb in ipairs(TH._listeners) do
		local ok, err = pcall(cb, key, value)
		if not ok then warn("[SeriousHook] Theme listener error: " .. tostring(err)) end
	end
end

function TH:OnChanged(callback)
	table.insert(TH._listeners, callback)
	return #TH._listeners
end

function TH:Unsubscribe(handle)
	TH._listeners[handle] = nil
end

-- Optional theme override surface for ramp/dim/extra; kept for back-compat.
TH.light_contrast = TH.surface1
TH.dark_contrast  = TH.surface0
TH.outline        = TH.border
TH.inline         = TH.borderMuted
TH.textcolor     = TH.text
TH.textborder    = TH.textOutline
TH.cursoroutline = TH.cursorOuter

return TH
