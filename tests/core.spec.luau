local count = 0
local failures = {}
local function test(name, run)
    local ok, message = pcall(run)
    if not ok then table.insert(failures, name .. ": " .. tostring(message)) end
    count += 1
    print(if ok then "PASS" else "FAIL", name)
end
local Scanner = require(script.Parent.Scanner)
local Metrics = require(script.Parent.Metrics)
local Profile = require(script.Parent.Profile)
local Report = require(script.Parent.Report)
local Studio = require(script.Parent.Studio)
local function find(source, rule)
    for _, finding in Scanner.scan(source, "Workspace.Example") do
        if finding.rule == rule then return finding end
    end
    return nil
end

test("comments and all literal forms cannot manufacture findings", function()
    local source = [====[
-- while true do event:Connect(function() end) end
local a = "wait() event:Connect()"
local b = 'spawn(function() end)'
local c = [==[while true do x:GetDescendants() end]==]
--[=[ while true do x:Connect() end ]=]
local d = `wait() {value}`
]====]
    assert(#Scanner.scan(source, "Test") == 0)
end)
test("multiline comments preserve the connection's original line", function()
    local finding = find("--[=[\nignored\n]=]\nfor i = 1, 3 do\n x:Connect(function() end)\nend", "connection-loop")
    assert(finding and finding.line == 5)
    assert(finding.confidence == "medium" and finding.path == "Workspace.Example")
end)
test("connections in repeat loops need lifecycle review", function()
    assert(find("repeat event:Connect(function() end) until done", "connection-loop"))
end)
test("block tracking does not leak loop context past end", function()
    assert(not find("for i = 1, 3 do if ok then work() end end\nx:Connect(callback)", "connection-loop"))
end)
test("inline if expressions cannot retain loop context past end", function()
    assert(not find("for i = 1, 3 do local n = if ok then 1 else 2 end\nx:Connect(callback)", "connection-loop"))
end)
test("nested inline conditional branches do not create statement scopes", function()
    local source = "for i = 1, 3 do local n = if a then if b then 1 else 2 else 3 end\nx:Connect(callback)"
    assert(not find(source, "connection-loop"))
end)
test("nested interpolated strings cannot expose literal text as executable code", function()
    local source = 'local s = `outer {`wait()`}`'
    assert(#Scanner.scan(source, "Test") == 0)
end)
test("a one-off traversal is not diagnosed as a hot path", function()
    assert(not find("local objects = workspace:GetDescendants()", "traversal-hotpath"))
end)
test("traversal inside nested callback in a loop remains advisory", function()
    assert(find("while ready do local function f() return workspace:GetDescendants() end end", "traversal-hotpath"))
end)
test("frame callbacks expose repeated traversal and unmanaged connection", function()
    local source = "run.Heartbeat:Connect(function(dt)\n workspace:GetDescendants()\nend)"
    assert(find(source, "traversal-hotpath"))
    assert(find(source, "frame-connection"))
end)
test("retained frame connections avoid unmanaged warning", function()
    assert(not find("local connection = run.Heartbeat:Connect(function() end)", "frame-connection"))
end)
test("deprecated global wait is distinguished from methods and task.wait", function()
    assert(find("wait(1)", "legacy-scheduler"))
    assert(not find("task.wait(1)\nobject:wait()", "legacy-scheduler"))
end)
test("scanner caps repeated findings", function()
    local findings = Scanner.scan(string.rep("wait()\n", 200), "Test", 12)
    assert(#findings == 12)
end)
test("bounded samples report milliseconds and p95", function()
    local m = Metrics.new(3)
    for i = 1, 4 do m:push({time = i, frameMs = i * 10, memoryMb = 100 + i}) end
    local summary = m:summary()
    assert(#m.samples == 3 and summary.frameMs == 30 and summary.p95FrameMs == 40)
    assert(summary.memoryMb == 104)
end)
test("missing nonfinite and negative measurements remain unavailable", function()
    local m = Metrics.new(5)
    m:push({time = 0, frameMs = 0/0, memoryMb = -1, instances = math.huge})
    local s = m:summary()
    assert(s.frameMs == nil and s.memoryMb == nil and s.instances == nil)
end)
test("memory baseline compares only measured categories", function()
    local m = Metrics.new(10)
    m:push({time = 0, memoryMb = 100, categories = {LuaHeap = 10}})
    assert(m:baseline())
    m:push({time = 1, memoryMb = 112, categories = {LuaHeap = 14, Signals = 2}})
    local memory = m:memory()
    assert(memory.deltaMb == 12 and memory.categoryDeltas.LuaHeap == 4)
    assert(memory.categoryDeltas.Signals == nil)
end)
test("short memory traces never claim sustained growth", function()
    local m = Metrics.new(30)
    for i = 1, 12 do m:push({time = i / 10, memoryMb = i}) end
    assert(m:memory().growthMbPerMinute == nil)
end)
test("memory trend uses time and excludes unavailable observations", function()
    local m = Metrics.new(30)
    for i = 0, 10 do m:push({time = i, memoryMb = 100 + 2 * i}) end
    local memory = m:memory()
    assert(math.abs(memory.growthMbPerMinute - 120) < 0.001)
    assert(memory.observationSeconds == 10)
end)
test("falling memory is not described as growth", function()
    local m = Metrics.new(30)
    for i = 0, 10 do m:push({time = i, memoryMb = 100 - i}) end
    assert(m:memory().growthMbPerMinute == nil)
end)
test("out of order samples cannot distort the timeline", function()
    local m = Metrics.new(10)
    assert(m:push({time = 2, memoryMb = 10}))
    assert(not m:push({time = 1, memoryMb = 20}))
    assert(#m.samples == 1)
end)
test("profiler converts microseconds and uses session duration for percentage", function()
    local result = Profile.normalize({Version = 2, SessionStartTime = 1000, SessionEndTime = 2000,
        Functions = {{Name = "update", Source = "Workspace.A", Line = 12, TotalDuration = 250000, Flags = 0}}})
    assert(result.rows[1].durationMs == 250 and result.rows[1].percent == 25)
    assert(result.durationMs == 1000)
end)
test("plugin bit is excluded even when native bit is also set", function()
    local result = Profile.normalize({Functions = {
        {Name = "plugin", TotalDuration = 1000, Flags = 3},
        {Name = "native", TotalDuration = 2000, Flags = 1}}})
    assert(#result.rows == 1 and result.rows[1].name == "native" and result.rows[1].percent == nil)
end)
test("profiler rejects malformed snapshots without inventing success", function()
    local result, problem = Profile.normalize({Functions = "not a table"})
    assert(result == nil and type(problem) == "string")
    result, problem = Profile.normalize(nil)
    assert(result == nil and problem)
end)
test("profiler ignores invalid costs and sorts expensive functions first", function()
    local result = Profile.normalize({Functions = {
        {Name = "small", TotalDuration = 1000}, {Name = "bad", TotalDuration = -1},
        {Name = "big", TotalDuration = 5000}, {TotalDuration = math.huge}}})
    assert(#result.rows == 2 and result.rows[1].name == "big")
end)
test("zero duration and empty profiler sessions are valid without NaN percentages", function()
    local result = Profile.normalize({SessionStartTime = 1, SessionEndTime = 1, Functions = {}})
    assert(#result.rows == 0 and result.durationMs == nil)
end)
test("report whitelists serializable data and drops private source and instances", function()
    local snapshot = Report.snapshot({timestamp = "now", findings = {{rule = "test", path = "A", line = 1,
        title = "Test", severity = "info", confidence = "medium", source = "secret", instance = function() end}},
        metrics = {memoryMb = 100}, coverage = {scanned = 1}})
    assert(snapshot.schemaVersion == 1 and snapshot.findings[1].source == nil)
    assert(snapshot.findings[1].instance == nil and snapshot.metrics.memoryMb == 100)
end)
test("Markdown escapes table delimiters and line breaks in project names", function()
    local text = Report.markdown(Report.snapshot({timestamp = "now", context = "Studio", findings = {
        {path = "A|B\nC", line = 3, title = "Test", severity = "warning", recommendation = "Cache traversal"}}}))
    assert(string.find(text, "A\\|B<br>C", 1, true))
    assert(string.find(text, "Cache traversal", 1, true))
end)
test("in-progress scans are visibly partial in both report formats", function()
    local snapshot = Report.snapshot({scanning = true, coverage = {scanned = 2}})
    assert(snapshot.coverage.inProgress == true)
    assert(string.find(Report.markdown(snapshot), "Partial: true", 1, true))
end)
test("skipped or denied sources make Markdown coverage partial", function()
    local text = Report.markdown(Report.snapshot({coverage = {scanned = 1, unreadable = 1}}))
    assert(string.find(text, "Partial: true", 1, true))
end)
test("project scans exclude Studio internal trees before consuming script coverage", function()
    local workspaceRoot, userService = {Name = "Workspace"}, {Name = "ServerScriptService"}
    local roots = Studio.projectRoots({{Name = "CoreGui"}, workspaceRoot, {Name = "CorePackages"},
        {Name = "PluginDebugService"}, {Name = "RobloxPluginGuiService"}, userService})
    assert(#roots == 2 and roots[1] == workspaceRoot and roots[2] == userService)
end)
assert(#failures == 0, table.concat(failures, "\n"))
return count
