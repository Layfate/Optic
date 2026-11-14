local Capture = require(script.Parent.Capture)
local count = 0
local failures = {}
local function test(name, run)
    local ok, message = pcall(run)
    if not ok then table.insert(failures, name .. ": " .. tostring(message)) end
    count += 1; print(if ok then "PASS" else "FAIL", name)
end
local function fixture()
    local f = {timers = {}, running = true, starts = 0, stops = 0, requests = 0, player = {Name = "Local"}, disconnected = false, now = 0}
    f.adapter = {
        isRunning = function() return f.running end,
        timestamp = function() return f.now end,
        localPlayer = function() return f.player end,
        delay = function(seconds, callback) table.insert(f.timers, {seconds = seconds, run = callback}) end,
        subscribe = function(callback)
            f.emit = callback
            return {Disconnect = function() f.disconnected = true end}
        end,
        start = function(target, player)
            if f.startError then error("API denied") end
            f.starts += 1; f.startedTarget = target; f.startedPlayer = player
        end,
        stop = function()
            f.stops += 1
            if f.stopError then error("stop failed") end
        end,
        request = function() f.requests += 1 end,
        decode = function(data) return data end,
    }
    f.capture = Capture.new(f.adapter, function() end)
    return f
end
local data = {SessionStartTime = 0, SessionEndTime = 1000, Functions = {{Name = "work", TotalDuration = 2500}}}

test("capture requires Play and never starts the profiler in Edit", function()
    local f = fixture(); f.running = false
    assert(not f.capture:start("client") and f.starts == 0)
end)
test("client capture requires the actual local player", function()
    local f = fixture(); f.player = nil
    assert(not f.capture:start("client") and f.starts == 0)
end)
test("denied start cannot cause an unrelated profiler to be stopped", function()
    local f = fixture(); f.startError = true
    assert(not f.capture:start("server")); f.capture:destroy()
    assert(f.stops == 0 and f.disconnected)
end)
test("capture starts once with the requested client and refuses concurrent starts", function()
    local f = fixture()
    assert(f.capture:start("client"))
    assert(not f.capture:start("server") and f.starts == 1)
    assert(f.startedTarget == "client" and f.startedPlayer == f.player)
end)
test("stop requests one final snapshot and ignores another player's data", function()
    local f = fixture(); f.capture:start("client"); f.capture:stop()
    f.emit({}, data)
    assert(f.capture.state.status == "waiting")
    f.emit(f.player, data)
    assert(f.capture.state.status == "complete" and f.capture.state.rows[1].durationMs == 2.5)
    assert(f.stops == 1 and f.requests == 1)
end)
test("server reply has no player and is normalized", function()
    local f = fixture(); f.capture:start("server"); f.capture:stop(); f.emit(nil, data)
    assert(f.capture.state.status == "complete" and #f.capture.state.rows == 1)
end)
test("auto-stop is bounded and no stale auto-stop can cancel a new recording", function()
    local f = fixture(); f.capture:start("server")
    assert(f.timers[1].seconds == 15)
    f.capture:cancel(); f.capture:start("server")
    f.timers[1].run()
    assert(f.capture.state.status == "recording" and f.stops == 1)
end)
test("missing profiler reply times out and ignores late results", function()
    local f = fixture(); f.capture:start("server"); f.capture:stop()
    local timeout = f.timers[#f.timers]
    assert(timeout.seconds == 8); timeout.run()
    assert(f.capture.state.status == "error")
    f.emit(nil, data)
    assert(f.capture.state.status == "error")
end)
test("cancel invalidates pending replies and cleanup disconnects listener", function()
    local f = fixture(); f.capture:start("server"); f.capture:stop(); f.capture:cancel()
    f.emit(nil, data); assert(f.capture.state.status == "cancelled")
    f.capture:destroy(); assert(f.disconnected)
    for _, timer in f.timers do timer.run() end
    assert(f.capture.state.status == "cancelled")
end)
test("invalid snapshots surface a useful failure instead of empty success", function()
    local f = fixture(); f.capture:start("server"); f.capture:stop(); f.emit(nil, {})
    assert(f.capture.state.status == "error" and #f.capture.state.message > 0)
end)
test("failed stop retains ownership so destroy retries cleanup", function()
    local f = fixture(); f.capture:start("server"); f.stopError = true; f.capture:stop()
    assert(f.capture.state.status == "error")
    f.stopError = false; f.capture:destroy(); assert(f.stops == 2)
end)
test("a late reply from an older capture cannot complete the next capture", function()
    local f = fixture(); f.capture:start("server"); f.capture:stop()
    f.timers[#f.timers].run()
    f.now = 2000; f.capture:start("server"); f.capture:stop()
    f.emit(nil, data)
    assert(f.capture.state.status == "waiting")
    f.emit(nil, {SessionStartTime = 2000, SessionEndTime = 3000, Functions = {{Name = "new", TotalDuration = 4000}}})
    assert(f.capture.state.status == "complete" and f.capture.state.rows[1].name == "new")
end)
test("old session start is rejected even if its reply end time is later", function()
    local f = fixture(); f.now = 2000; f.capture:start("server"); f.capture:stop()
    f.emit(nil, {SessionStartTime = 0, SessionEndTime = 3000, Functions = {}})
    assert(f.capture.state.status == "waiting")
end)
test("snapshots without session timestamps cannot bypass capture identity checks", function()
    local f = fixture(); f.capture:start("server"); f.capture:stop()
    f.emit(nil, {Functions = {{Name = "unknown session", TotalDuration = 1000}}})
    assert(f.capture.state.status == "error")
end)
assert(#failures == 0, table.concat(failures, "\n"))
return count
