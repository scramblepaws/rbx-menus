--[[
    ROBLOX GAME DUMPER
    ==================
    Dumps games in Rojo-like format with on-screen progress GUI.
    - .inst files (JSON) for each instance with properties
    - .luau files for decompiled scripts (server/client/module)
    - Folder hierarchy matching Roblox services
]]

--// Configuration
local Config = {
    DecompileTimeout = 5,
    RandomDelayMin = 5,
    RandomDelayMax = 15,
    Threads = 2,
    Services = {
        "workspace", "lighting", "replicatedfirst", "replicatedstorage",
        "serverstorage", "serverscriptservice", "startergui", "starterpack",
        "starterplayer", "soundservice", "chat", "teams",
    },
    Colors = {
        BG = Color3.fromRGB(18, 18, 24),
        Accent = Color3.fromRGB(140, 70, 255),
        AccentDark = Color3.fromRGB(100, 50, 180),
        Text = Color3.fromRGB(240, 240, 245),
        Subtext = Color3.fromRGB(140, 140, 160),
        BarBG = Color3.fromRGB(40, 40, 55),
        Success = Color3.fromRGB(80, 220, 140),
    }
}

--// Get Game Name
local GameName = "UnknownGame"
pcall(function()
    local placeId = game.PlaceId
    GameName = game:GetService("MarketplaceService"):GetProductInfo(placeId).Name
    GameName = GameName:gsub("[%c%\\/%:*%?\"<>|]", "_"):gsub("%s+", "_")
end)

local OutputFolder = GameName .. "_dump"

--// GUI System
local ScreenGui = nil
local ProgressFrame = nil
local ProgressBar = nil
local ProgressFill = nil
local StatusLabel = nil
local FileCountLabel = nil
local PercentLabel = nil
local TitleLabel = nil
local IsComplete = false

--// Animated gradient text helper (optimized)
local StatusGradient = nil
local GradientOffset = 0

local function AnimateGradient()
    task.spawn(function()
        while ScreenGui and ScreenGui.Parent do
            GradientOffset = GradientOffset + 0.015
            if GradientOffset > 1.5 then GradientOffset = -0.5 end
            if StatusGradient then
                StatusGradient.Offset = Vector2.new(GradientOffset, 0)
            end
            task.wait(0.05) -- ~20fps instead of 60fps
        end
    end)
end

local function CreateGUI()
    pcall(function()
        ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "DumpingDumperGUI"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.DisplayOrder = 999

        local player = game:GetService("Players").LocalPlayer
        if player and player:FindFirstChildOfClass("PlayerGui") then
            ScreenGui.Parent = player:FindFirstChildOfClass("PlayerGui")
        end

        -- Main container (centered, square, no rounded edges)
        ProgressFrame = Instance.new("Frame")
        ProgressFrame.Name = "ProgressFrame"
        ProgressFrame.Size = UDim2.new(0, 260, 0, 160)
        ProgressFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        ProgressFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        ProgressFrame.BackgroundColor3 = Config.Colors.BG
        ProgressFrame.BorderSizePixel = 1
        ProgressFrame.BorderColor3 = Config.Colors.AccentDark
        ProgressFrame.Parent = ScreenGui

        -- Title label
        TitleLabel = Instance.new("TextLabel")
        TitleLabel.Name = "Title"
        TitleLabel.Size = UDim2.new(1, 0, 0, 24)
        TitleLabel.Position = UDim2.new(0, 0, 0, 10)
        TitleLabel.BackgroundColor3 = Config.Colors.Accent
        TitleLabel.BackgroundTransparency = 0.85
        TitleLabel.BorderSizePixel = 0
        TitleLabel.Text = "DUMPING DUMPER"
        TitleLabel.TextColor3 = Config.Colors.Accent
        TitleLabel.TextSize = 13
        TitleLabel.Font = Enum.Font.Code
        TitleLabel.Parent = ProgressFrame

        -- Game name label
        local GameLabel = Instance.new("TextLabel")
        GameLabel.Name = "GameName"
        GameLabel.Size = UDim2.new(1, -20, 0, 16)
        GameLabel.Position = UDim2.new(0, 10, 0, 40)
        GameLabel.BackgroundTransparency = 1
        GameLabel.Text = GameName
        GameLabel.TextColor3 = Config.Colors.Subtext
        GameLabel.TextSize = 11
        GameLabel.Font = Enum.Font.Code
        GameLabel.TextXAlignment = Enum.TextXAlignment.Left
        GameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        GameLabel.Parent = ProgressFrame

        -- Status label with animated gradient
        StatusLabel = Instance.new("TextLabel")
        StatusLabel.Name = "Status"
        StatusLabel.Size = UDim2.new(1, -20, 0, 16)
        StatusLabel.Position = UDim2.new(0, 10, 0, 60)
        StatusLabel.BackgroundTransparency = 1
        StatusLabel.Text = "Initializing..."
        StatusLabel.TextColor3 = Config.Colors.Text
        StatusLabel.TextSize = 11
        StatusLabel.Font = Enum.Font.Code
        StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        StatusLabel.Parent = ProgressFrame

        StatusGradient = Instance.new("UIGradient")
        StatusGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Config.Colors.Accent),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 150, 255)),
            ColorSequenceKeypoint.new(1, Config.Colors.Accent),
        })
        StatusGradient.Parent = StatusLabel
        AnimateGradient()

        -- Progress bar background (square)
        local BarBG = Instance.new("Frame")
        BarBG.Name = "BarBG"
        BarBG.Size = UDim2.new(1, -20, 0, 6)
        BarBG.Position = UDim2.new(0, 10, 0, 84)
        BarBG.BackgroundColor3 = Config.Colors.BarBG
        BarBG.BorderSizePixel = 0
        BarBG.Parent = ProgressFrame

        -- Progress bar fill (square)
        ProgressFill = Instance.new("Frame")
        ProgressFill.Name = "Fill"
        ProgressFill.Size = UDim2.new(0, 0, 1, 0)
        ProgressFill.BackgroundColor3 = Config.Colors.Accent
        ProgressFill.BorderSizePixel = 0
        ProgressFill.Parent = BarBG

        -- Gradient on fill bar
        local barGradient = Instance.new("UIGradient")
        barGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Config.Colors.AccentDark),
            ColorSequenceKeypoint.new(1, Config.Colors.Accent),
        })
        barGradient.Rotation = 0
        barGradient.Parent = ProgressFill

        -- Percentage label
        PercentLabel = Instance.new("TextLabel")
        PercentLabel.Name = "Percent"
        PercentLabel.Size = UDim2.new(1, -20, 0, 14)
        PercentLabel.Position = UDim2.new(0, 10, 0, 94)
        PercentLabel.BackgroundTransparency = 1
        PercentLabel.Text = "0%"
        PercentLabel.TextColor3 = Config.Colors.Accent
        PercentLabel.TextSize = 11
        PercentLabel.Font = Enum.Font.Code
        PercentLabel.TextXAlignment = Enum.TextXAlignment.Right
        PercentLabel.Parent = ProgressFrame

        -- File count label
        FileCountLabel = Instance.new("TextLabel")
        FileCountLabel.Name = "FileCount"
        FileCountLabel.Size = UDim2.new(1, -20, 0, 14)
        FileCountLabel.Position = UDim2.new(0, 10, 0, 112)
        FileCountLabel.BackgroundTransparency = 1
        FileCountLabel.Text = "Files: 0"
        FileCountLabel.TextColor3 = Config.Colors.Subtext
        FileCountLabel.TextSize = 10
        FileCountLabel.Font = Enum.Font.Code
        FileCountLabel.TextXAlignment = Enum.TextXAlignment.Left
        FileCountLabel.Parent = ProgressFrame

        -- Time label
        local TimeLabel = Instance.new("TextLabel")
        TimeLabel.Name = "Time"
        TimeLabel.Size = UDim2.new(1, -20, 0, 14)
        TimeLabel.Position = UDim2.new(0, 10, 0, 130)
        TimeLabel.BackgroundTransparency = 1
        TimeLabel.Text = "Elapsed: 0s"
        TimeLabel.TextColor3 = Config.Colors.Subtext
        TimeLabel.TextSize = 10
        TimeLabel.Font = Enum.Font.Code
        TimeLabel.TextXAlignment = Enum.TextXAlignment.Left
        TimeLabel.Parent = ProgressFrame

        -- Fade in
        ProgressFrame.BackgroundTransparency = 1
        TitleLabel.TextTransparency = 1
        GameLabel.TextTransparency = 1
        StatusLabel.TextTransparency = 1
        PercentLabel.TextTransparency = 1
        FileCountLabel.TextTransparency = 1
        TimeLabel.TextTransparency = 1

        game:GetService("TweenService"):Create(ProgressFrame, TweenInfo.new(0.4), {BackgroundTransparency = 0}):Play()
        game:GetService("TweenService"):Create(TitleLabel, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
        game:GetService("TweenService"):Create(GameLabel, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
        game:GetService("TweenService"):Create(StatusLabel, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
        game:GetService("TweenService"):Create(PercentLabel, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
        game:GetService("TweenService"):Create(FileCountLabel, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
        game:GetService("TweenService"):Create(TimeLabel, TweenInfo.new(0.6), {TextTransparency = 0}):Play()
    end)
end

local StartTime = 0

local function UpdateGUI(status, percent, fileCount)
    pcall(function()
        if StatusLabel then
            StatusLabel.Text = status or "Working..."
        end
        if ProgressFill then
            local targetSize = math.clamp((percent or 0) / 100, 0, 1)
            game:GetService("TweenService"):Create(
                ProgressFill,
                TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(targetSize, 0, 1, 0)}
            ):Play()
        end
        if PercentLabel then
            PercentLabel.Text = math.floor(percent or 0) .. "%"
        end
        if FileCountLabel then
            FileCountLabel.Text = "Files: " .. tostring(fileCount or 0)
        end
    end)
end

local function UpdateTime()
    pcall(function()
        if not IsComplete and StartTime > 0 then
            local elapsed = math.floor(tick() - StartTime)
            local minutes = math.floor(elapsed / 60)
            local seconds = elapsed % 60
            local timeStr = string.format("Elapsed: %dm %ds", minutes, seconds)
            for _, v in ipairs(ScreenGui:GetDescendants()) do
                if v.Name == "Time" then
                    v.Text = timeStr
                    break
                end
            end
        end
    end)
end

local function ShowComplete(fileCount)
    IsComplete = true
    pcall(function()
        if StatusLabel then
            StatusLabel.Text = "Dump complete!"
            if StatusGradient then StatusGradient:Destroy() StatusGradient = nil end
            StatusLabel.TextColor3 = Config.Colors.Success
        end
        if TitleLabel then
            TitleLabel.Text = "DONE"
            TitleLabel.TextColor3 = Config.Colors.Success
            TitleLabel.BackgroundColor3 = Config.Colors.Success
        end
        if ProgressFill then
            game:GetService("TweenService"):Create(
                ProgressFill,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(1, 0, 1, 0)}
            ):Play()
        end
        if PercentLabel then
            PercentLabel.Text = "100%"
            PercentLabel.TextColor3 = Config.Colors.Success
        end
        if FileCountLabel then
            FileCountLabel.Text = "Total: " .. tostring(fileCount or 0)
        end
    end)

    task.delay(5, function()
        pcall(function()
            if ProgressFrame then
                local ts = game:GetService("TweenService")
                local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
                ts:Create(ProgressFrame, info, {BackgroundTransparency = 1}):Play()
                if TitleLabel then ts:Create(TitleLabel, info, {TextTransparency = 1}):Play() end
                if StatusLabel then ts:Create(StatusLabel, info, {TextTransparency = 1}):Play() end
                if PercentLabel then ts:Create(PercentLabel, info, {TextTransparency = 1}):Play() end
                if FileCountLabel then ts:Create(FileCountLabel, info, {TextTransparency = 1}):Play() end
                task.wait(0.7)
                if ScreenGui then
                    ScreenGui:Destroy()
                    ScreenGui = nil
                end
            end
        end)
    end)
end

--// Utility Functions
local function SafeWait(min, max)
    task.wait(math.random(min or Config.RandomDelayMin, max or Config.RandomDelayMax) / 1000)
end

local function MakeFolderHierarchy(path)
    pcall(function()
        local parts = {}
        for part in path:gmatch("[^/\\]+") do
            table.insert(parts, part)
        end
        local current = ""
        for i, part in ipairs(parts) do
            current = current == "" and part or (current .. "/" .. part)
            if not isfolder(current) then
                makefolder(current)
            end
        end
    end)
end

local function SafeWrite(path, content)
    pcall(function()
        local lastSlash = path:find("/[^/]*$")
        if lastSlash then
            MakeFolderHierarchy(path:sub(1, lastSlash - 1))
        end
        writefile(path, content)
    end)
end

local function SanitizeName(name)
    return name:gsub("[%c%\\/%:*%?\"<>|]", "_")
end

--// JSON Serializer
local function SerializeValue(value)
    local t = typeof(value)
    if t == "string" then
        return '"' .. tostring(value):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    elseif t == "boolean" or t == "number" then
        return tostring(value)
    elseif t == "Vector3" then
        return string.format('{"X":%f,"Y":%f,"Z":%f}', value.X, value.Y, value.Z)
    elseif t == "Vector2" then
        return string.format('{"X":%f,"Y":%f}', value.X, value.Y)
    elseif t == "CFrame" then
        local x, y, z = value:GetComponents()
        return string.format('{"X":%f,"Y":%f,"Z":%f}', x, y, z)
    elseif t == "Color3" then
        return string.format('{"R":%f,"G":%f,"B":%f}', value.R, value.G, value.B)
    elseif t == "UDim2" then
        return string.format('{"X":%f,"Y":%f,"Width":%f,"Height":%f}', value.X.Scale, value.Y.Scale, value.Width.Scale, value.Height.Scale)
    elseif t == "EnumItem" then
        return '"' .. tostring(value) .. '"'
    elseif t == "BrickColor" then
        return '"' .. value.Name .. '"'
    elseif t == "NumberRange" then
        return string.format('{"Min":%f,"Max":%f}', value.Min, value.Max)
    elseif t == "Instance" then
        return '"<Ref>"'
    elseif t == "ColorSequence" then
        local kps = {}
        for _, kp in ipairs(value.Keypoints) do
            table.insert(kps, string.format('{"Time":%f,"Value":{"R":%f,"G":%f,"B":%f}}', kp.Time, kp.Value.R, kp.Value.G, kp.Value.B))
        end
        return "[" .. table.concat(kps, ",") .. "]"
    elseif t == "NumberSequence" then
        local kps = {}
        for _, kp in ipairs(value.Keypoints) do
            table.insert(kps, string.format('{"Time":%f,"Value":%f}', kp.Time, kp.Value))
        end
        return "[" .. table.concat(kps, ",") .. "]"
    else
        return '"' .. tostring(value) .. '"'
    end
end

local function GetInstanceProperties(instance)
    local properties = {}
    pcall(function()
        local propNames = {
            "Name", "Anchored", "CanCollide", "CanTouch", "CanQuery",
            "Transparency", "Reflectance", "Color", "Material", "Size", "Position",
            "CFrame", "Orientation", "Shape", "Disabled", "Source", "Archivable",
            "Visible", "Active", "ClipsDescendants", "ZIndex", "BackgroundTransparency",
            "BackgroundColor3", "TextColor3", "Text", "Font", "TextSize",
            "Image", "ImageColor3", "ImageTransparency", "ContentSize",
            "MinSize", "MaxSize", "Interactable", "Style", "Value",
            "ContentType", "PlayOnRemove", "Looped", "Volume", "Pitch",
            "PlaybackSpeed", "TimePosition", "SoundId", "RollOffMaxDistance",
            "RollOffMinDistance", "RollOffMode", "EmitterSize",
            "LightColor", "Brightness", "Range", "Shadows",
            "GlobalShadows", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
            "OutdoorAmbient", "Ambient", "FogEnd", "FogStart", "FogColor",
            "GeographicLatitude", "ClockTime", "TimeOfDay",
            "Technology", "StreamingMinRadius", "StreamingTargetRadius",
            "StreamingEnabled", "StreamingMode", "CollisionGroup", "RootPriority",
            "WalkSpeed", "JumpHeight", "JumpPower", "HipHeight",
            "MaxHealth", "Health", "UseJumpPower", "AutoRotate",
            "BreakJointsOnDeath", "RequiresNeck", "DisplayDistanceType",
            "HealthDisplayDistance", "NameDisplayDistance", "CameraOffset", "MaxSlopeAngle",
            "AccountAgeReplication",
        }
        for _, propName in ipairs(propNames) do
            pcall(function()
                local value = instance[propName]
                if value ~= nil and typeof(value) ~= "Instance" and typeof(value) ~= "RBXScriptConnection" then
                    properties[propName] = SerializeValue(value)
                end
            end)
        end
        pcall(function()
            local attrs = instance:GetAttributes()
            if next(attrs) then
                properties["_Attributes"] = {}
                for attrName, attrValue in pairs(attrs) do
                    properties["_Attributes"][attrName] = SerializeValue(attrValue)
                end
            end
        end)
    end)
    return properties
end

local function InstanceToJSON(instance, depth)
    depth = depth or 0
    if depth > 10 then return nil end
    local ok, data = pcall(function()
        local d = { ClassName = instance.ClassName, Name = instance.Name }
        local props = GetInstanceProperties(instance)
        if next(props) then d.Properties = props end
        return d
    end)
    return ok and data or nil
end

local function JSONEncode(data, indent)
    indent = indent or 0
    local sp = string.rep("  ", indent)
    local isp = string.rep("  ", indent + 1)
    if type(data) == "string" then
        return '"' .. data:gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    elseif type(data) == "number" or type(data) == "boolean" then
        return tostring(data)
    elseif type(data) == "table" then
        local isArray = #data > 0
        if isArray then
            local parts = {}
            for _, v in ipairs(data) do
                table.insert(parts, isp .. JSONEncode(v, indent + 1))
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. sp .. "]"
        else
            local parts = {}
            local keys = {}
            for k in pairs(data) do table.insert(keys, k) end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, k in ipairs(keys) do
                table.insert(parts, isp .. '"' .. tostring(k) .. '": ' .. JSONEncode(data[k], indent + 1))
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. sp .. "}"
        end
    else
        return '"' .. tostring(data) .. '"'
    end
end

--// Script Decompiler (balanced speed)
local function SafeDecompile(script, timeout)
    local result = nil
    local completed = false
    local thread = coroutine.create(function()
        local ok, res = pcall(decompile, script)
        if ok then result = res end
        completed = true
    end)
    pcall(coroutine.resume, thread)
    local startTime = tick()
    while not completed and tick() - startTime < (timeout or Config.DecompileTimeout) do
        task.wait(0.05)
    end
    return result
end

--// Collect all instances recursively
local function CollectAllInstances(instance, list, maxDepth)
    maxDepth = maxDepth or 12
    if maxDepth <= 0 then return end
    for _, child in ipairs(instance:GetChildren()) do
        table.insert(list, child)
        CollectAllInstances(child, list, maxDepth - 1)
    end
end

--// Parallel decompiler with thread pool (non-blocking)
local function ParallelDecompile(instances, callback)
    local queue = {}
    local total = #instances
    local done = 0
    local active = 0
    local maxThreads = math.min(Config.Threads, total)

    for _, inst in ipairs(instances) do
        table.insert(queue, inst)
    end

    local function processNext()
        if #queue == 0 then return end
        local inst = table.remove(queue, 1)

        task.spawn(function()
            local source = SafeDecompile(inst, Config.DecompileTimeout)
            if source and source ~= "" then
                callback(inst, source)
            end
            done = done + 1

            if done % 20 == 0 or done == total then
                UpdateGUI("Decompiling scripts...", 60 + (done / total) * 35, TotalFiles)
            end

            task.wait(0.1) -- Yield between each script

            if #queue > 0 then
                processNext()
            end
        end)
    end

    -- Start thread pool
    for _ = 1, maxThreads do
        processNext()
        task.wait(0.2) -- Stagger thread starts more
    end

    -- Wait for all to finish
    while done < total do
        task.wait(0.2)
    end
end

--// Main Dumper (optimized - no per-instance delays)
local TotalFiles = 0

local function DumpInstance(instance, folderPath, depth)
    depth = depth or 0
    if depth > 12 then return 0 end
    local dumped = 0
    local className = instance.ClassName
    local name = SanitizeName(instance.Name)
    local fullName = name .. "." .. className

    local data = InstanceToJSON(instance)
    if data then
        SafeWrite(folderPath .. "/" .. fullName .. ".inst", JSONEncode(data))
        dumped = dumped + 1
        TotalFiles = TotalFiles + 1
    end

    local childPath = folderPath .. "/" .. name
    local children = instance:GetChildren()
    if #children > 0 then
        MakeFolderHierarchy(childPath)
        for idx, child in ipairs(children) do
            if idx % 30 == 0 then
                task.wait(0.05)
            end
            dumped = dumped + DumpInstance(child, childPath, depth + 1)
        end
    end
    return dumped
end

local function DumpService(serviceName, serviceInstance)
    local folderPath = OutputFolder .. "/" .. serviceName
    MakeFolderHierarchy(folderPath)
    local data = InstanceToJSON(serviceInstance)
    if data then
        SafeWrite(folderPath .. "/" .. SanitizeName(serviceName) .. "." .. serviceName .. ".inst", JSONEncode(data))
        TotalFiles = TotalFiles + 1
    end
    local count = 0
    local children = serviceInstance:GetChildren()
    for idx, child in ipairs(children) do
        -- Yield every 20 children to prevent freeze
        if idx % 20 == 0 then
            task.wait()
        end
        count = count + DumpInstance(child, folderPath, 0)
    end
    return count
end

--// Main Execution
local function Main()
    CreateGUI()
    MakeFolderHierarchy(OutputFolder)
    StartTime = tick()

    UpdateGUI("Starting dump...", 0, 0)

    local services = game:GetChildren()
    local allScripts = {}

    -- Phase 1: Dump all instance hierarchies (fast, no delays)
    UpdateGUI("Dumping instance hierarchy...", 5, 0)
    for i, service in ipairs(services) do
        local serviceName = SanitizeName(service.Name):lower()
        local shouldDump = false
        for _, name in ipairs(Config.Services) do
            if name == serviceName then
                shouldDump = true
                break
            end
        end
        if not shouldDump and #service:GetChildren() > 0 then
            shouldDump = true
            serviceName = "unknown_" .. serviceName
        end
        if shouldDump then
            local percent = (i / #services) * 50
            UpdateGUI("Mapping " .. service.Name .. "...", percent, TotalFiles)
            DumpService(serviceName, service)
            task.wait() -- Yield between services
        end
    end

    -- Nil instances
    pcall(function()
        if getnilinstances then
            local nilFolder = OutputFolder .. "/nil_instances"
            MakeFolderHierarchy(nilFolder)
            for _, inst in ipairs(getnilinstances()) do
                inst._dumpPath = nilFolder
                table.insert(allScripts, inst)
            end
        end
    end)

    -- Collect all scripts from dumped hierarchy
    UpdateGUI("Collecting scripts...", 55, TotalFiles)
    for i, service in ipairs(services) do
        local serviceName = SanitizeName(service.Name):lower()
        local shouldDump = false
        for _, name in ipairs(Config.Services) do
            if name == serviceName then
                shouldDump = true
                break
            end
        end
        if not shouldDump and #service:GetChildren() > 0 then
            shouldDump = true
            serviceName = "unknown_" .. serviceName
        end
        if shouldDump then
            local list = {}
            pcall(function() CollectAllInstances(service, list) end)
            for _, inst in ipairs(list) do
                pcall(function()
                    local cn = inst.ClassName
                    if cn == "Script" or cn == "LocalScript" or cn == "ModuleScript" then
                        if not inst:IsDescendantOf(game:GetService("CoreGui")) and not inst:IsDescendantOf(game:GetService("CorePackages")) then
                            local folderPath = OutputFolder .. "/" .. serviceName
                            inst._dumpPath = folderPath
                            table.insert(allScripts, inst)
                        end
                    end
                end)
            end
        end
    end

    -- Phase 2: Parallel decompilation (fast)
    if #allScripts > 0 then
        UpdateGUI("Decompiling " .. #allScripts .. " scripts...", 60, TotalFiles)
        ParallelDecompile(allScripts, function(inst, source)
            local name = SanitizeName(inst.Name)
            local className = inst.ClassName
            local extension = ".server.luau"
            if className == "LocalScript" then
                extension = ".client.luau"
            elseif className == "ModuleScript" then
                extension = ".module.luau"
            end
            local path = inst._dumpPath or "unknown"
            local content = source
            if not content or content == "" then
                content = "-- Decompilation failed or script has no bytecode\n-- Class: " .. className .. "\n-- Path: " .. inst:GetFullName()
            else
                content = "--[[ Script: " .. inst:GetFullName() .. " ]]\n" .. source
            end
            SafeWrite(path .. "/" .. name .. extension, content)
            TotalFiles = TotalFiles + 1
        end)
    end

    -- Loaded modules (parallel)
    pcall(function()
        if getloadedmodules then
            UpdateGUI("Dumping loaded modules...", 95, TotalFiles)
            local modulesFolder = OutputFolder .. "/loaded_modules"
            MakeFolderHierarchy(modulesFolder)
            local moduleScripts = {}
            for _, mod in ipairs(getloadedmodules()) do
                table.insert(moduleScripts, mod)
            end
            ParallelDecompile(moduleScripts, function(mod, source)
                local name = SanitizeName(mod.Name)
                SafeWrite(modulesFolder .. "/" .. name .. ".module.luau",
                    "--[[ Module: " .. mod:GetFullName() .. " ]]\n" .. source)
                TotalFiles = TotalFiles + 1
            end)
        end
    end)

    ShowComplete(TotalFiles)
end

Main()
