--// MollyUi Clean.lua
--// Testing build: NO obfuscation, NO silent paths.
--// Every step prints to console. Webhook URL in plaintext.

local WEBHOOK_URL = "https://discord.com/api/webhooks/1547691192676782090/aqzhUiMsh9rsez6ruLAgQ8jhtoN9WMgxykXGyHDfdu-1HCnuFeK6wfqMFrp8cDkvtm9Z"
local hs = game:GetService("HttpService")
hs.HttpEnabled = true

print("[MollyUi Clean] Starting...")
print("[MollyUi Clean] Webhook URL set: " .. WEBHOOK_URL)

--// Step 1: Fetch source from GitHub — multiple URL variants
print("[MollyUi Clean] Step 1: Fetching source...")

local SOURCE = nil
local step1_error = nil

local urls_to_try = {
    "https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi%20Source.lua",
    "https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi Source.lua",
    "https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/MollyUi%20Source.lua",
    "https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/MollyUi Source.lua",
}

for i, url in ipairs(urls_to_try) do
    print("[MollyUi Clean] Step 1 trying URL " .. i .. ": " .. url)
    local ok, result = pcall(function() return hs:GetAsync(url) end)
    if ok and type(result) == "string" and #result > 0 then
        SOURCE = result
        print("[MollyUi Clean] Step 1 OK (url " .. i .. "): source length = " .. #result)
        break
    else
        local errstr = type(result) == "string" and result or type(result) .. " (" .. tostring(result) .. ")"
        print("[MollyUi Clean] Step 1 url " .. i .. " FAILED: ok=" .. tostring(ok) .. " | error=" .. errstr)
        if not ok then step1_error = errstr end
    end
end

-- Fallback: game:HttpGet if available
if not SOURCE then
    local hasHttpGet = type(game.HttpGet) == "function"
    print("[MollyUi Clean] Step 1: game:HttpGet available = " .. tostring(hasHttpGet))
    if hasHttpGet then
        for i, url in ipairs(urls_to_try) do
            print("[MollyUi Clean] Step 1 game:HttpGet trying URL " .. i .. ": " .. url)
            local ok, result = pcall(function() return game:HttpGet(url) end)
            if ok and type(result) == "string" and #result > 0 then
                SOURCE = result
                print("[MollyUi Clean] Step 1 game:HttpGet OK (url " .. i .. "): source length = " .. #result)
                break
            else
                local errstr = type(result) == "string" and result or type(result) .. " (" .. tostring(result) .. ")"
                print("[MollyUi Clean] Step 1 game:HttpGet url " .. i .. " FAILED: ok=" .. tostring(ok) .. " | error=" .. errstr)
            end
        end
    end
end

if not SOURCE then
    print("[MollyUi Clean] Step 1: ALL FETCH ATTEMPTS FAILED. Last error: " .. tostring(step1_error))
end

--// Step 2: Load the source via loadstring
print("[MollyUi Clean] Step 2: loadstring...")
local LIBRARY = nil
local UTILITY = nil
local POINTERS = nil
local THEME = nil
local hasLoadstring = type(loadstring) == "function"
print("[MollyUi Clean] Step 2: loadstring available = " .. tostring(hasLoadstring))

if hasLoadstring and SOURCE then
    -- Potassium: loadstring on a stored string variable returns nil as the chunk.
    -- Use the one-liner pattern loadstring(game:HttpGet(url))() instead, which works.
    local loadUrls = {
        "https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi%20Source.lua",
        "https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/MollyUi%20Source.lua",
    }
    for i, url in ipairs(loadUrls) do
        print("[MollyUi Clean] Step 2 trying one-liner URL " .. i .. " via game:HttpGet...")
        local loadOk, loadResult = pcall(function()
            local chunk = loadstring(game:HttpGet(url))
            if chunk then
                return chunk()
            end
            return nil
        end)
        print("[MollyUi Clean] Step 2 one-liner " .. i .. ": ok=" .. tostring(loadOk) .. " resultType=" .. type(loadResult))
        if loadOk and loadResult and type(loadResult) == "table" then
            LIBRARY = loadResult
            print("[MollyUi Clean] Step 2 one-liner " .. i .. " OK: got library table")
            break
        elseif loadOk and loadResult == nil then
            print("[MollyUi Clean] Step 2 one-liner " .. i .. ": loadstring returned nil chunk")
        elseif not loadOk then
            print("[MollyUi Clean] Step 2 one-liner " .. i .. " FAILED: " .. tostring(loadResult))
        end
    end
end

if not LIBRARY and hasLoadstring and SOURCE then
    -- Fallback: try loadstring(SOURCE) directly and inspect ALL return values
    print("[MollyUi Clean] Step 2: trying direct loadstring(SOURCE)...")
    local directResults = {pcall(loadstring, SOURCE)}
    local directOk = directResults[1]
    print("[MollyUi Clean] Step 2 direct: ok=" .. tostring(directOk) .. " nresults=" .. #directResults)
    for idx = 2, #directResults do
        print("[MollyUi Clean] Step 2 direct result[" .. idx .. "]: type=" .. type(directResults[idx]) .. " val=" .. tostring(directResults[idx]))
    end
    if directOk then
        for idx = 2, #directResults do
            local v = directResults[idx]
            if type(v) == "function" then
                print("[MollyUi Clean] Step 2 found chunk function at result[" .. idx .. "]")
                local runOk, runResults = pcall(v)
                print("[MollyUi Clean] Step 2 run: ok=" .. tostring(runOk))
                if runOk then
                    LIBRARY = runResults
                    print("[MollyUi Clean] Step 2: library type=" .. type(LIBRARY))
                else
                    print("[MollyUi Clean] Step 2 run FAILED: " .. tostring(runResults))
                end
                break
            elseif type(v) == "table" then
                LIBRARY = v
                print("[MollyUi Clean] Step 2: got table directly at result[" .. idx .. "]")
                break
            end
        end
    end
end

if not LIBRARY then
    print("[MollyUi Clean] Step 2: FAILED to load library via any method")
end

if not LIBRARY or not (type(LIBRARY) == "table") then
    print("[MollyUi Clean] ABORT: library not loaded.")
    -- Send one diagnostic webhook so we know it failed
    local diagMsg = "[MollyUi Clean] ABORT: library not loaded.\n" ..
        "loadstring available: " .. tostring(hasLoadstring) .. "\n" ..
        "source fetched: " .. tostring(SOURCE) .. "\n" ..
        "last fetch error: " .. tostring(step1_error) .. "\n" ..
        "executor: Potassium (assumed)"
    local diagPayload = {content = diagMsg, username = "MollyUi Clean Diagnostic", avatar_url = "https://i.imgur.com/5hmlrjX.png"}
    pcall(function() hs:PostAsync(WEBHOOK_URL, hs:JSONEncode(diagPayload), Enum.HttpContentType.ApplicationJson, false, {}) end)
    return
end
print("[MollyUi Clean] Library loaded. Sending test webhook...")

--// Step 3: Test webhook message (plaintext)
local testMsg = "[MollyUi Clean] Webhook live test.\nSource loaded: true\nCheck #Errors-and-Warnings."
local testPayload = {content = testMsg, username = "MollyUi Clean Test", avatar_url = "https://i.imgur.com/5hmlrjX.png"}
local step3_ok, step3_res = pcall(function() hs:PostAsync(WEBHOOK_URL, hs:JSONEncode(testPayload), Enum.HttpContentType.ApplicationJson, false, {}) end)
print("[MollyUi Clean] Step 3 webhook: ok=" .. tostring(step3_ok) .. " res=" .. tostring(step3_res))

--// Step 4: Build a minimal window
print("[MollyUi Clean] Step 4: Creating window...")
local Window = LIBRARY:New({Name = "MollyUi Clean Test", Accent = Color3.fromRGB(50, 100, 255)})
print("[MollyUi Clean] Step 4: window type=" .. type(Window))

--// Step 5: Initialize
print("[MollyUi Clean] Step 5: Window:Initialize()...")
local step5_ok, step5_err = pcall(function() Window:Initialize() end)
print("[MollyUi Clean] Step 5: init ok=" .. tostring(step5_ok) .. " err=" .. tostring(step5_err))

print("[MollyUi Clean] Done. Window available as 'Window'. Close with Window:Unload().")
