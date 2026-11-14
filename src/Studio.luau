--!strict
local Scanner = require(script.Parent.Scanner)
local Metrics = require(script.Parent.Metrics)
local Capture = require(script.Parent.Capture)
local Studio = {}
Studio.__index = Studio

local function safeNumber(callback)
    local ok, result = pcall(callback)
    return if ok and type(result) == "number" and result >= 0 and result == result and result < math.huge then result else nil
end
local limits = {scripts = 2000, source = 256 * 1024, findings = 500}
local internalRoots = {CoreGui = true, CorePackages = true, PluginDebugService = true,
    RobloxPluginGuiService = true, PluginGuiService = true}

function Studio.projectRoots(children)
    local roots = {}
    for _, child in children do
        if not internalRoots[child.Name] then table.insert(roots, child) end
    end
    return roots
end

function Studio.new(changed)
    local self = setmetatable({changed = changed, alive = true, scanId = 0, scanning = false,
        findings = {}, coverage = {scanned = 0}, notice = "Ready. Scan your project to find optimization opportunities.",
        metrics = Metrics.new(120), samplingGeneration = 0}, Studio)
    self.run = game:GetService("RunService")
    self.stats = game:GetService("Stats")
    self.players = game:GetService("Players")
    self.selection = game:GetService("Selection")
    self.editor = game:GetService("ScriptEditorService")
    self.http = game:GetService("HttpService")
    local ok, profiler = pcall(function() return game:GetService("ScriptProfilerService") end)
    local function available()
        assert(ok and profiler, "This Studio build does not expose ScriptProfilerService.")
        return profiler
    end
    self.capture = Capture.new({
        isRunning = function() return self.run:IsRunning() end,
        timestamp = function() return DateTime.now().UnixTimestampMillis end,
        localPlayer = function() return self.players.LocalPlayer end,
        delay = function(seconds, callback) task.delay(seconds, callback) end,
        subscribe = function(callback) return available().OnNewData:Connect(callback) end,
        start = function(target, player)
            if target == "client" then available():ClientStart(player, 1000) else available():ServerStart(1000) end
        end,
        stop = function(target, player)
            if target == "client" then available():ClientStop(player) else available():ServerStop() end
        end,
        request = function(target, player)
            if target == "client" then available():ClientRequestData(player) else available():ServerRequestData() end
        end,
        decode = function(raw)
            assert(type(raw) == "string" and #raw <= 16 * 1024 * 1024, "Snapshot exceeds the 16 MiB safety limit or is not JSON.")
            -- DeserializeJSON converts durations to seconds and removes Flags in Studio.
            -- Keep the documented export schema (microseconds + flags) end to end.
            return self.http:JSONDecode(raw)
        end,
    }, function() if self.alive then self.changed() end end)
    self.runConnection = self.run:GetPropertyChangedSignal("RunState"):Connect(function()
        if not self.run:IsRunning() then self.capture:cancel() end
        self.changed()
    end)
    return self
end

function Studio:context()
    local side = if self.run:IsRunning() then "Play" else "Edit"
    return side .. " · current Studio session (includes editor/plugin overhead)"
end
function Studio:sample()
    local categories = {}
    local trackingOk, tracking = pcall(function() return self.stats.MemoryTrackingEnabled end)
    if trackingOk and tracking then
        for _, name in {"LuaHeap", "Script", "Signals", "Instances", "GraphicsTexture", "PhysicsCollision"} do
            local value = safeNumber(function() return self.stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag[name]) end)
            if value then categories[name] = value end
        end
    end
    local frame = safeNumber(function() return self.stats.FrameTime end)
    self.metrics:push({time = os.clock(), memoryMb = safeNumber(function() return self.stats:GetTotalMemoryUsageMb() end),
        frameMs = if frame and frame > 0 then frame * 1000 else nil,
        heartbeatMs = safeNumber(function() return self.stats.HeartbeatTime * 1000 end),
        physicsMs = safeNumber(function() return self.stats.PhysicsStepTime * 1000 end),
        instances = safeNumber(function() return self.stats.InstanceCount end), categories = categories})
end
function Studio:setSampling(enabled)
    self.samplingGeneration += 1
    if not enabled or not self.alive then return end
    local generation = self.samplingGeneration
    task.spawn(function()
        while self.alive and generation == self.samplingGeneration do
            self:sample(); self.changed(); task.wait(0.5)
        end
    end)
end
function Studio:cancelScan()
    if not self.scanning then return end
    self.scanId += 1; self.scanning = false; self.coverage.cancelled = true
    self.notice = "Scan cancelled. Findings and coverage are partial."; self.changed()
end
function Studio:scan(scope)
    if self.scanning or not self.alive then return end
    self.scanId += 1
    local scanId = self.scanId
    local roots = if scope == "selection" then self.selection:Get() else Studio.projectRoots(game:GetChildren())
    if #roots == 0 then self.notice = "Select scripts or a container in Explorer before scanning the selection."; self.changed(); return end
    self.scanning = true; self.findings = {}
    local coverage = {scope = scope, scanned = 0, unreadable = 0, skipped = 0, candidates = 0, truncated = false,
        sourceLimitBytes = limits.source, scriptLimit = limits.scripts, findingLimit = limits.findings,
        scanContext = self:context(), scannedAt = DateTime.now():ToIsoDate()}
    self.coverage = coverage
    self.notice = "Scanning source locally…"; self.changed()
    task.spawn(function()
        -- Incremental traversal avoids materializing all descendants for a large place.
        local stack, seen, visited = table.clone(roots), {}, 0
        while #stack > 0 and self.alive and self.scanId == scanId do
            local instance = table.remove(stack)
            if seen[instance] then continue end
            seen[instance] = true; visited += 1
            local childrenOk, children = pcall(function() return instance:GetChildren() end)
            if childrenOk then
                for _, child in children do table.insert(stack, child) end
            end
            if instance:IsA("LuaSourceContainer") then
                coverage.candidates += 1
                if coverage.scanned + coverage.unreadable + coverage.skipped >= limits.scripts then
                    coverage.truncated = true; break
                end
                local sourceOk, source = pcall(function() return self.editor:GetEditorSource(instance) end)
                if not sourceOk then sourceOk, source = pcall(function() return instance.Source end) end
                if not sourceOk or type(source) ~= "string" then coverage.unreadable += 1
                elseif #source > limits.source then coverage.skipped += 1
                else
                    coverage.scanned += 1
                    local path = instance:GetFullName()
                    local remaining = limits.findings - #self.findings
                    local results = Scanner.scan(source, path, math.min(51, remaining + 1))
                    for _, finding in results do
                        if #self.findings >= limits.findings then coverage.truncated = true; break end
                        finding.instance = instance
                        table.insert(self.findings, finding)
                    end
                    if #results > 50 then coverage.truncated = true end
                    if #self.findings >= limits.findings then coverage.truncated = true; break end
                end
            end
            if visited % 20 == 0 then
                self.notice = string.format("Scanning… %d scripts checked · %d findings", coverage.scanned, #self.findings)
                self.changed(); task.wait()
            end
        end
        if not self.alive or self.scanId ~= scanId then return end
        self.scanning = false
        self.notice = string.format("Scan complete · %d scripts · %d advisory findings%s", coverage.scanned, #self.findings,
            if coverage.truncated or coverage.skipped > 0 or coverage.unreadable > 0 then " · partial coverage" else "")
        self.changed()
    end)
end
function Studio:open(finding)
    local instance = finding.instance
    if not instance or not instance.Parent then
        -- A CPU source is a display path, not an executable expression.
        local current = game
        for segment in string.gmatch(finding.path or "", "[^%.]+") do
            if current == game and segment == "game" then continue end
            current = current:FindFirstChild(segment)
            if not current then break end
        end
        instance = current
    end
    if not instance or not instance:IsA("LuaSourceContainer") then
        self.notice = "That script is unavailable in this DataModel. CPU source names may refer to another Play context."
        self.changed(); return
    end
    task.spawn(function()
        local ok, problem = pcall(function()
            local opened, message = self.editor:OpenScriptDocumentAsync(instance)
            assert(opened, tostring(message))
            local document = self.editor:FindScriptDocument(instance)
            if document then document:RequestSetSelectionAsync(math.max(1, finding.line or 1), 1) end
            self.selection:Set({instance})
        end)
        if not ok and self.alive then self.notice = "Could not open source: " .. tostring(problem); self.changed() end
    end)
end
function Studio:destroy()
    self.alive = false; self.scanId += 1; self.samplingGeneration += 1
    self.capture:destroy()
    if self.runConnection then self.runConnection:Disconnect() end
    self.changed = function() end
end
return Studio
