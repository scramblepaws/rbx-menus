--[[
	Amnesia UI - Debug Version
	Copies full debug output to clipboard
]]

local LIBRARY_URL = "https://raw.githubusercontent.com/scramblepaws/rbx-menus/d9d3f9a/library.luau"

local function fetch(url)
	local content = nil
	if not content then
		local ok, result = pcall(game.HttpGet, game, url)
		if ok and result and #result > 100 then content = result end
	end
	if not content and request then
		local ok, result = pcall(request, { Url = url, Method = "GET" })
		if ok and result and result.Body and #result.Body > 100 then content = result.Body end
	end
	if not content and http_request then
		local ok, result = pcall(http_request, { Url = url, Method = "GET" })
		if ok and result and result.Body and #result.Body > 100 then content = result.Body end
	end
	if not content and syn and syn.request then
		local ok, result = pcall(syn.request, { Url = url, Method = "GET" })
		if ok and result and result.Body and #result.Body > 100 then content = result.Body end
	end
	return content
end

local function clip(text)
	if setclipboard then setclipboard(text)
	elseif toclipboard then toclipboard(text)
	end
end

local log = {}
local function out(msg)
	table.insert(log, msg)
end

out("[1] Fetching library...")
local librarySource = fetch(LIBRARY_URL)
if not librarySource then
	out("[FAIL] Could not fetch library")
	clip(table.concat(log, "\n"))
	return
end
out("[1] Fetched, length: " .. #librarySource)

out("[2] Loading library...")
local Library = loadstring(librarySource)()
if not Library then
	out("[FAIL] loadstring returned nil")
	clip(table.concat(log, "\n"))
	return
end
out("[2] Library loaded")

local keys = {}
for k, v in pairs(Library) do table.insert(keys, k) end
out("[2] Keys: " .. table.concat(keys, ", "))

out("[3] Creating window...")
local success, Window = pcall(function()
	return Library:CreateWindow({
		Title = "amnesia [v1.0] | developed by dutu1337",
		Size = Vector2.new(580, 420),
		Position = UDim2.fromOffset(100, 100),
	})
end)
if not success then
	out("[FAIL] CreateWindow error: " .. tostring(Window))
	clip(table.concat(log, "\n"))
	return
end
if not Window then
	out("[FAIL] CreateWindow returned nil")
	clip(table.concat(log, "\n"))
	return
end
out("[3] Window created")

out("[4] ScreenGui: " .. tostring(Window.ScreenGui))
out("[4] ScreenGui.Parent: " .. tostring(Window.ScreenGui and Window.ScreenGui.Parent))
out("[4] ScreenGui.Parent.Name: " .. tostring(Window.ScreenGui and Window.ScreenGui.Parent and Window.ScreenGui.Parent.Name))

out("[5] MainFrame: " .. tostring(Window.MainFrame))
out("[5] MainFrame.Parent: " .. tostring(Window.MainFrame and Window.MainFrame.Parent))
out("[5] MainFrame.Visible: " .. tostring(Window.MainFrame and Window.MainFrame.Visible))
out("[5] MainFrame.Size: " .. tostring(Window.MainFrame and Window.MainFrame.Size))
out("[5] MainFrame.Position: " .. tostring(Window.MainFrame and Window.MainFrame.Position))
out("[5] MainFrame.AbsoluteSize: " .. tostring(Window.MainFrame and Window.MainFrame.AbsoluteSize))
out("[5] MainFrame.BackgroundTransparency: " .. tostring(Window.MainFrame and Window.MainFrame.BackgroundTransparency))
out("[5] MainFrame.BackgroundColor3: " .. tostring(Window.MainFrame and Window.MainFrame.BackgroundColor3))
out("[5] MainFrame.BorderColor3: " .. tostring(Window.MainFrame and Window.MainFrame.BorderColor3))
out("[5] MainFrame.BorderSizePixel: " .. tostring(Window.MainFrame and Window.MainFrame.BorderSizePixel))

out("[6] Header: " .. tostring(Window.Header))
out("[6] Header.Parent: " .. tostring(Window.Header and Window.Header.Parent))

out("[7] Sidebar: " .. tostring(Window.Sidebar))
out("[7] Sidebar.Parent: " .. tostring(Window.Sidebar and Window.Sidebar.Parent))

out("[8] TabBar: " .. tostring(Window.TabBar))
out("[8] TabBar.Parent: " .. tostring(Window.TabBar and Window.TabBar.Parent))

out("[9] TabContent: " .. tostring(Window.TabContent))
out("[9] TabContent.Parent: " .. tostring(Window.TabContent and Window.TabContent.Parent))

-- Sidebar category
out("[10] Creating sidebar category...")
local ok1, cat = pcall(function()
	return Window:CreateSidebarCategory("aimbot")
end)
out("[10] ok: " .. tostring(ok1) .. " result: " .. tostring(cat))
if cat then
	out("[10] cat.Button: " .. tostring(cat.Button))
	out("[10] cat.Button.Parent: " .. tostring(cat.Button and cat.Button.Parent))
end

-- Tab
out("[11] Creating tab...")
local ok2, tab = pcall(function()
	return Window:CreateTab("legitbot")
end)
out("[11] ok: " .. tostring(ok2) .. " result: " .. tostring(tab))
if tab then
	out("[11] tab.Button: " .. tostring(tab.Button))
	out("[11] tab.Button.Parent: " .. tostring(tab.Button and tab.Button.Parent))
	out("[11] tab.Content: " .. tostring(tab.Content))
	out("[11] tab.Content.Parent: " .. tostring(tab.Content and tab.Content.Parent))
	out("[11] tab.Content.Visible: " .. tostring(tab.Content and tab.Content.Visible))
end

-- Groupbox
out("[12] Creating groupbox...")
local ok3, gb = pcall(function()
	return tab:CreateGroupbox("main", "Left")
end)
out("[12] ok: " .. tostring(ok3) .. " result: " .. tostring(gb))
if gb then
	out("[12] gb.Frame: " .. tostring(gb.Frame))
	out("[12] gb.Frame.Parent: " .. tostring(gb.Frame and gb.Frame.Parent))
end

-- Toggle
out("[13] Creating toggle...")
local ok4, tog = pcall(function()
	return gb:Toggle("enabled", false)
end)
out("[13] ok: " .. tostring(ok4) .. " result: " .. tostring(tog))
if tog then
	out("[13] tog.Frame: " .. tostring(tog.Frame))
	out("[13] tog.Frame.Parent: " .. tostring(tog.Frame and tog.Frame.Parent))
end

-- Slider
out("[14] Creating slider...")
local ok5, sli = pcall(function()
	return gb:Slider("fov", {Min=0, Max=100, Default=34})
end)
out("[14] ok: " .. tostring(ok5) .. " result: " .. tostring(sli))

-- Button
out("[15] Creating button...")
local ok6, btn = pcall(function()
	return gb:Button("save", function() end)
end)
out("[15] ok: " .. tostring(ok6) .. " result: " .. tostring(btn))

out("")
out("=== DEBUG COMPLETE ===")

local output = table.concat(log, "\n")
clip(output)
print(output)
