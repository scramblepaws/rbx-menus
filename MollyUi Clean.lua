--// MollyUi Clean.lua
--// Testing build: NO obfuscation, NO silent paths.
--// Every step prints to console. Webhook URL in plaintext.
--// All if-then bodies on the same line as 'then' to avoid parser confusion.

local WEBHOOK_URL = "https://discord.com/api/webhooks/1547691192676782090/aqzhUiMsh9rsez6ruLAgQ8jhtoN9WMgxykXGyHDfdu-1HCnuFeK6wfqMFrp8cDkvtm9Z"
local hs = game:GetService("HttpService")
hs.HttpEnabled = true

print("[MollyUi Clean] Starting...")
print("[MollyUi Clean] Webhook URL set: " .. WEBHOOK_URL)

--// Step 1: Fetch source from GitHub
print("[MollyUi Clean] Step 1: Fetching source...")
local step1_ok, step1_result, step1_err = pcall(function()
    return hs:GetAsync("https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi%20Source.lua")
end)
local lenstr = "0"
if typeof(step1_result) == "string" then lenstr = #step1_result end
if step1_ok and typeof(step1_result) == "string" and #step1_result > 0 then
    print("[MollyUi Clean] Step 1 OK: source length = " .. lenstr)
else
    print("[MollyUi Clean] Step 1 FAILED: ok=" .. tostring(step1_ok) .. " err=" .. tostring(step1_err) .. " len=" .. lenstr)
end
local SOURCE = (step1_ok and typeof(step1_result) == "string" and #step1_result > 0) and step1_result or nil

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
    return
end
print("[MollyUi Clean] Library loaded. Sending test webhook...")

--// Step 3: Test webhook message (plaintext)
local testMsg = "[MollyUi Clean] Webhook live test.\nSource loaded: " .. ((LIBRARY ~= nil and typeof(LIBRARY) == "table" and LIBRARY.New ~= nil) and "true" or "false") .. "\nCheck #Errors-and-Warnings."
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
