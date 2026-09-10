--// MollyUi Clean.lua
--// Testing build: NO obfuscation, NO silent paths.
--// Every step prints to console. Webhook URL in plaintext.
--// Strategy: local file first (compiles), GitHub fallback (broken upstream).

local WEBHOOK_URL = "https://discord.com/api/webhooks/1547691192676782090/aqzhUiMsh9rsez6ruLAgQ8jhtoN9WMgxykXGyHDfdu-1HCnuFeK6wfqMFrp8cDkvtm9Z"
local hs = game:GetService("HttpService")
hs.HttpEnabled = true

print("[MollyUi Clean] Starting...")
print("[MollyUi Clean] Webhook URL set: " .. WEBHOOK_URL)

--// Step 1: Load source — local file first, then GitHub
print("[MollyUi Clean] Step 1: Loading source...")

local SOURCE = nil
local sourceFrom = nil
local LIBRARY = nil

-- Attempt A: local file via readfile (executor-dependent)
if type(readfile) == "function" then
    print("[MollyUi Clean] Step 1A: trying readfile('MollyUi Source.lua')...")
    local ok, result = pcall(readfile, "MollyUi Source.lua")
    if ok and type(result) == "string" and #result > 0 then
        SOURCE = result
        sourceFrom = "readfile"
        print("[MollyUi Clean] Step 1A OK: readfile returned " .. #result .. " bytes")
    else
        print("[MollyUi Clean] Step 1A FAILED: ok=" .. tostring(ok) .. " | type=" .. type(result) .. " | err=" .. tostring(result))
    end
end

-- Attempt B: local file via loadfile (executor-dependent)
if not SOURCE and type(loadfile) == "function" then
    print("[MollyUi Clean] Step 1B: trying loadfile('MollyUi Source.lua')...")
    local ok, chunk = pcall(loadfile, "MollyUi Source.lua")
    if ok and type(chunk) == "function" then
        local runOk, ... = pcall(chunk)
        if runOk then
            LIBRARY = ...
            sourceFrom = "loadfile"
            print("[MollyUi Clean] Step 1B OK: loadfile ran, library type=" .. type(LIBRARY))
        else
            print("[MollyUi Clean] Step 1B FAILED: chunk ok but run failed: " .. tostring(...))
        end
    else
        print("[MollyUi Clean] Step 1B FAILED: ok=" .. tostring(ok) .. " | type=" .. type(chunk) .. " | err=" .. tostring(chunk))
    end
end

-- Attempt C: GitHub via game:HttpGet (if local failed)
if not SOURCE and not LIBRARY then
    print("[MollyUi Clean] Step 1C: trying GitHub via game:HttpGet...")
    local githubUrls = {
        "https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi%20Source.lua",
        "https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/MollyUi%20Source.lua",
        "https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi Source.lua",
        "https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/MollyUi Source.lua",
    }
    for i, url in ipairs(githubUrls) do
        print("[MollyUi Clean] Step 1C trying URL " .. i .. "...")
        local ok, result = pcall(function() return game:HttpGet(url) end)
        if ok and type(result) == "string" and #result > 0 then
            SOURCE = result
            sourceFrom = "GitHub url" .. i
            print("[MollyUi Clean] Step 1C OK (url " .. i .. "): " .. #result .. " bytes")
            break
        else
            print("[MollyUi Clean] Step 1C url " .. i .. " FAILED: ok=" .. tostring(ok) .. " | err=" .. tostring(result))
        end
    end
end

if not SOURCE and not LIBRARY then
    print("[MollyUi Clean] Step 1: ALL ATTEMPTS FAILED")
    local diagMsg = "[MollyUi Clean] ABORT: library not loaded.\nNo source available from local or GitHub."
    local diagPayload = {content = diagMsg, username = "MollyUi Clean Diagnostic", avatar_url = "https://i.imgur.com/5hmlrjX.png"}
    pcall(function() hs:PostAsync(WEBHOOK_URL, hs:JSONEncode(diagPayload), Enum.HttpContentType.ApplicationJson, false, {}) end)
    return
end

print("[MollyUi Clean] Source from: " .. sourceFrom .. " (" .. (type(SOURCE) == "string" and #SOURCE .. " bytes" or "direct table") .. ")")

--// Step 2: Compile + run source (if we fetched a string)
if not LIBRARY and SOURCE and type(SOURCE) == "string" and #SOURCE > 0 then
    print("[MollyUi Clean] Step 2: compiling source...")

    -- Try loadfile first (may work where loadstring fails)
    if type(loadfile) == "function" then
        print("[MollyUi Clean] Step 2A: trying loadfile on source string...")
        local chunk, err = loadfile(SOURCE)
        if chunk then
            local runOk, ... = pcall(chunk)
            print("[MollyUi Clean] Step 2A run: ok=" .. tostring(runOk))
            if runOk then
                LIBRARY = ...
                print("[MollyUi Clean] Step 2A OK: library type=" .. type(LIBRARY))
            else
                print("[MollyUi Clean] Step 2A run FAILED: " .. tostring(...))
            end
        else
            print("[MollyUi Clean] Step 2A loadfile FAILED: " .. tostring(err))
        end
    end

    -- Try loadstring (one-liner pattern, not stored variable)
    if not LIBRARY and type(loadstring) == "function" then
        print("[MollyUi Clean] Step 2B: trying loadstring(game:HttpGet(url))() one-liner...")
        local urls = {
            "https://raw.githubusercontent.com/scramblepaws/rbx-menus/main/MollyUi%20Source.lua",
            "https://raw.githubusercontent.com/scramblepaws/rbx-menus/refs/heads/main/MollyUi%20Source.lua",
        }
        for i, url in ipairs(urls) do
            local ok, result = pcall(function()
                local chunk = loadstring(game:HttpGet(url))
                if chunk then
                    return chunk()
                end
                return nil, "loadstring returned nil chunk"
            end)
            print("[MollyUi Clean] Step 2B url " .. i .. ": ok=" .. tostring(ok) .. " | resultType=" .. type(result))
            if ok and type(result) == "table" then
                LIBRARY = result
                print("[MollyUi Clean] Step 2B OK: got library table")
                break
            elseif ok and result == nil then
                print("[MollyUi Clean] Step 2B url " .. i .. ": loadstring returned nil (compile error in source)")
            elseif not ok then
                print("[MollyUi Clean] Step 2B url " .. i .. " FAILED: " .. tostring(result))
            end
        end
    end

    -- Direct loadstring(SOURCE) with full error capture
    if not LIBRARY and type(loadstring) == "function" then
        print("[MollyUi Clean] Step 2C: trying loadstring(SOURCE) directly...")
        local chunk, err = loadstring(SOURCE)
        print("[MollyUi Clean] Step 2C chunk: type=" .. type(chunk) .. " | err=" .. tostring(err))
        if chunk then
            local runOk, ... = pcall(chunk)
            print("[MollyUi Clean] Step 2C run: ok=" .. tostring(runOk))
            if runOk then
                LIBRARY = ...
                print("[MollyUi Clean] Step 2C OK: library type=" .. type(LIBRARY))
            else
                print("[MollyUi Clean] Step 2C run FAILED: " .. tostring(...))
            end
        else
            print("[MollyUi Clean] Step 2C: loadstring returned nil — source has compile error")
        end
    end
end

--// Abort if library still not loaded
if not LIBRARY or type(LIBRARY) ~= "table" then
    print("[MollyUi Clean] ABORT: library not loaded.")
    local diagMsg = "[MollyUi Clean] ABORT: library not loaded.\n" ..
        "sourceFrom: " .. tostring(sourceFrom) .. "\n" ..
        "loadstring: " .. tostring(type(loadstring) == "function") .. "\n" ..
        "loadfile: " .. tostring(type(loadfile) == "function") .. "\n" ..
        "SOURCE type: " .. type(SOURCE) .. "\n" ..
        "SOURCE len: " .. (type(SOURCE) == "string" and #SOURCE or 0) .. "\n" ..
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
