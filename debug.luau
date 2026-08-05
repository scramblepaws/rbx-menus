--[[
	Amnesia UI - Debug Version
	Run this to find exactly where it breaks
]]

local LIBRARY_URL = "https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/library.luau"

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

warn("[1] Fetching library...")
local librarySource = fetch(LIBRARY_URL)
if not librarySource then
	warn("[FAIL] Could not fetch library")
	return
end
warn("[1] Fetched, length:", #librarySource)

warn("[2] Loading library...")
local Library = loadstring(librarySource)()
if not Library then
	warn("[FAIL] loadstring returned nil")
	return
end
warn("[2] Library loaded, type:", type(Library))
warn("[2] CreateWindow exists:", type(Library.CreateWindow))

warn("[3] Creating window...")
local success, Window = pcall(function()
	return Library:CreateWindow({
		Title = "amnesia [v1.0] | developed by dutu1337",
		Size = Vector2.new(580, 420),
		Position = UDim2.fromOffset(100, 100),
	})
end)
if not success then
	warn("[FAIL] CreateWindow error:", Window)
	return
end
if not Window then
	warn("[FAIL] CreateWindow returned nil")
	return
end
warn("[3] Window created")

warn("[4] Checking ScreenGui...")
warn("[4] ScreenGui:", Window.ScreenGui)
warn("[4] ScreenGui.Parent:", Window.ScreenGui and Window.ScreenGui.Parent)
warn("[4] ScreenGui.ClassName:", Window.ScreenGui and Window.ScreenGui.ClassName)

warn("[5] Checking MainFrame...")
warn("[5] MainFrame:", Window.MainFrame)
warn("[5] MainFrame.Parent:", Window.MainFrame and Window.MainFrame.Parent)
warn("[5] MainFrame.Visible:", Window.MainFrame and Window.MainFrame.Visible)
warn("[5] MainFrame.Size:", Window.MainFrame and Window.MainFrame.Size)
warn("[5] MainFrame.Position:", Window.MainFrame and Window.MainFrame.Position)
warn("[5] MainFrame.BackgroundColor3:", Window.MainFrame and Window.MainFrame.BackgroundColor3)
warn("[5] MainFrame.BorderColor3:", Window.MainFrame and Window.MainFrame.BorderColor3)

warn("[6] Checking Header...")
warn("[6] Header:", Window.Header)
warn("[6] Header.Parent:", Window.Header and Window.Header.Parent)

warn("[7] Checking Sidebar...")
warn("[7] Sidebar:", Window.Sidebar)
warn("[7] Sidebar.Parent:", Window.Sidebar and Window.Sidebar.Parent)

warn("[8] Checking TabBar...")
warn("[8] TabBar:", Window.TabBar)
warn("[8] TabBar.Parent:", Window.TabBar and Window.TabBar.Parent)

warn("[9] Checking TabContent...")
warn("[9] TabContent:", Window.TabContent)
warn("[9] TabContent.Parent:", Window.TabContent and Window.TabContent.Parent)

-- Try creating a sidebar category
warn("[10] Creating sidebar category...")
local ok1, cat = pcall(function()
	return Window:CreateSidebarCategory("aimbot")
end)
warn("[10] Result:", ok1, cat)

-- Try creating a tab
warn("[11] Creating tab...")
local ok2, tab = pcall(function()
	return Window:CreateTab("legitbot")
end)
warn("[11] Result:", ok2, tab)

if tab then
	warn("[12] Tab.Button:", tab.Button)
	warn("[12] Tab.Button.Parent:", tab.Button and tab.Button.Parent)
	warn("[12] Tab.Content:", tab.Content)
	warn("[12] Tab.Content.Visible:", tab.Content and tab.Content.Visible)
	warn("[12] Tab.LeftColumn:", tab.LeftColumn)
	warn("[12] Tab.RightColumn:", tab.RightColumn)

	-- Try creating a groupbox
	warn("[13] Creating groupbox...")
	local ok3, gb = pcall(function()
		return tab:CreateGroupbox("main", "Left")
	end)
	warn("[13] Result:", ok3, gb)

	if gb then
		warn("[14] Groupbox.Frame:", gb.Frame)
		warn("[14] Groupbox.Frame.Parent:", gb.Frame and gb.Frame.Parent)

		-- Try creating a toggle
		warn("[15] Creating toggle...")
		local ok4, tog = pcall(function()
			return gb:Toggle("enabled", false, function(v) warn("toggle:", v) end)
		end)
		warn("[15] Result:", ok4, tog)
		if tog then
			warn("[15] Toggle.Frame:", tog.Frame)
			warn("[15] Toggle.Frame.Parent:", tog.Frame and tog.Frame.Parent)
		end
	end
end

warn("=== DEBUG COMPLETE ===")
warn("If you see this, check the warnings above for FAIL messages")
