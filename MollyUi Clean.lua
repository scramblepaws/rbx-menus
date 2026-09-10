--// MollyUi Clean.lua
--// Testing build: NO obfuscation, NO silent paths.
--// Every step prints to console. Webhook URL in plaintext.
--// All if-then bodies on the same line as 'then' to avoid parser confusion.
--// Improved diagnostics: proper pcall destructuring, full error capture, fallback URLs, game:HttpGet fallback.

local WEBHOOK_URL = "https://discord.com/api/webhooks/1547691192676782090/aqzhUiMsh9rsez6ruLAgQ8jhtoN9WMgxykXGyHDfdu-1HCnuFeK6wfqMFrp8cDkvtm9Z"
local hs = game:GetService("HttpService")
local httpEnabledBefore = hs.HttpEnabled
hs.HttpEnabled = true
local httpEnabledNow = hs.HttpEnabled

print("[MollyUi Clean] Starting...")
print("[MollyUi Clean] Webhook URL set: " .. WEBHOOK_URL)
print("[MollyUi Clean] HttpService.HttpEnabled was=" .. tostring(httpEnabledBefore) .. " now=" .. tostring(httpEnabledNow))

--// Step 1: Fetch source from GitHub — try multiple URL variants
print("[MollyUi Clean] Step 1: Fetching source...")

local SOURCE = nil
local step1_error = nil

-- URL variant 1: raw.githubusercontent with %20
local urls_to_try = {
    "https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi%20Source.lua",
    "https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi Source.lua",
    "https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/MollyUi%20Source.lua",
    "https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/MollyUi Source.lua",
}

for i, url in ipairs(urls_to_try) do
    print("[MollyUi Clean] Step 1 trying URL " .. i .. ": " .. url)
    local ok, result = pcall(function() return hs:GetAsync(url) end)
    if ok and typeof(result) == "string" and #result > 0 then
        SOURCE = result
        print("[MollyUi Clean] Step 1 OK (url " .. i .. "): source length = " .. #result)
        break
    else
        local errstr = typeof(result) == "string" and result or typeof(result) .. " (" .. tostring(result) .. ")"
        print("[MollyUi Clean] Step 1 url " .. i .. " FAILED: ok=" .. tostring(ok) .. " | error=" .. errstr)
        if not ok then step1_error = errstr end
    end
end

-- Fallback: game:HttpGet if available
if SOURCE == nil then
    local hasHttpGet = (game:HttpGet ~= nil)
    print("[MollyUi Clean] Step 1: game:HttpGet available = " .. tostring(hasHttpGet))
    if hasHttpGet then
        for i, url in ipairs(urls_to_try) do
            print("[MollyUi Clean] Step 1 game:HttpGet trying URL " .. i .. ": " .. url)
            local ok, result = pcall(function() return game:HttpGet(url) end)
            if ok and typeof(result) == "string" and #result > 0 then
                SOURCE = result
                print("[MollyUi Clean] Step 1 game:HttpGet OK (url " .. i .. "): source length = " .. #result)
                break
            else
                local errstr = typeof(result) == "string" and result or typeof(result) .. " (" .. tostring(result) .. ")"
                print("[MollyUi Clean] Step 1 game:HttpGet url " .. i .. " FAILED: ok=" .. tostring(ok) .. " | error=" .. errstr)
            end
        end
    end
end

if SOURCE == nil then
    print("[MollyUi Clean] Step 1: ALL FETCH ATTEMPTS FAILED. Last error: " .. tostring(step1_error))
end

--// Step 2: Compile + run source
print("[MollyUi Clean] Step 2: loadstring...")
local LIBRARY = nil
local UTILITY = nil
local POINTERS = nil
local THEME = nil
local hasLoadstring = (loadstring ~= nil)
print("[MollyUi Clean] Step 2: loadstring available = " .. tostring(hasLoadstring))
if SOURCE ~= nil and hasLoadstring then
    local step2a_ok, step2a_chunk = pcall(loadstring, SOURCE)
    if step2a_ok and typeof(step2a_chunk) == "function" then
        print("[MollyUi Clean] Step 2a OK: compiled chunk is a function")
        local step2b_results = {pcall(step2a_chunk)}
        local step2b_ok = step2b_results[1]
        print("[MollyUi Clean] Step 2b run: ok=" .. tostring(step2b_ok))
        if step2b_ok then
            LIBRARY = step2b_results[2]
            UTILITY = step2b_results[3]
            POINTERS = step2b_results[4]
            THEME = step2b_results[5]
            local b_hasNew = false
            if LIBRARY ~= nil and typeof(LIBRARY) == "table" then if LIBRARY.New ~= nil then b_hasNew = true end end
            print("[MollyUi Clean] Step 2b OK: library type=" .. typeof(LIBRARY) .. " | has New=" .. tostring(b_hasNew))
        else
            print("[MollyUi Clean] Step 2b FAILED: " .. tostring(step2b_results[2]))
        end
    else
        print("[MollyUi Clean] Step 2a FAILED: compileOk=" .. tostring(step2a_ok) .. " chunkType=" .. typeof(step2a_chunk))
    end
else
    print("[MollyUi Clean] Step 2 SKIPPED: no source or no loadstring")
end

if LIBRARY == nil or typeof(LIBRARY) ~= "table" then
    print("[MollyUi Clean] ABORT: library not loaded.")
    -- Send one diagnostic webhook so we know it failed
    local diagMsg = "[MollyUi Clean] ABORT: library not loaded.\n" ..
        "loadstring available: " .. tostring(hasLoadstring) .. "\n" ..
        "source fetched: " .. tostring(SOURCE ~= nil) .. "\n" ..
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
print("[MollyUi Clean] Step 4: window type=" .. typeof(Window))

--// Step 5: Initialize
print("[MollyUi Clean] Step 5: Window:Initialize()...")
local step5_ok, step5_err = pcall(function() Window:Initialize() end)
print("[MollyUi Clean] Step 5: init ok=" .. tostring(step5_ok) .. " err=" .. tostring(step5_err))

print("[MollyUi Clean] Done. Window available as 'Window'. Close with Window:Unload().")
