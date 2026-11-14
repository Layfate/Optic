--!strict
local Profile = require(script.Parent.Profile)
local Capture = {}
Capture.__index = Capture

function Capture.new(adapter, changed)
    local self = setmetatable({adapter = adapter, changed = changed, generation = 0,
        owned = false, destroyed = false, state = {status = "idle", message = "Start Play, then record a 15-second CPU sample.", rows = {}}}, Capture)
    local ok, connection = pcall(adapter.subscribe, function(player, data) self:_receive(player, data) end)
    if ok then self.connection = connection
    else self.state = {status = "unavailable", message = "Script profiler access is unavailable: " .. tostring(connection), rows = {}} end
    return self
end
function Capture:_status(status, message)
    self.state.status = status; self.state.message = message
    if not self.destroyed then self.changed() end
end
function Capture:start(target)
    if self.destroyed or not self.connection or self.owned or self.state.status == "waiting" then return false end
    if target ~= "client" and target ~= "server" then return false end
    if not self.adapter.isRunning() then self:_status("error", "Start a Studio Play test before recording CPU."); return false end
    local player = if target == "client" then self.adapter.localPlayer() else nil
    if target == "client" and not player then
        self:_status("error", "No local client is available in this Studio context. Try server capture or a client Play window.")
        return false
    end
    local startedAt = self.adapter.timestamp()
    local ok, problem = pcall(self.adapter.start, target, player)
    if not ok then self:_status("error", "Could not start CPU capture: " .. tostring(problem)); return false end
    self.generation += 1
    local generation = self.generation
    self.owned = true; self.player = player; self.target = target; self.startedAt = startedAt
    self.state = {status = "recording", target = target, message = "Recording " .. target .. " at 1 kHz · stops after 15 seconds.", rows = {}}
    self.changed()
    self.adapter.delay(15, function()
        if not self.destroyed and self.generation == generation and self.state.status == "recording" then self:stop() end
    end)
    return true
end
function Capture:stop()
    if self.destroyed or not self.owned or self.state.status ~= "recording" then return end
    local ok, problem = pcall(self.adapter.stop, self.target, self.player)
    if not ok then self:_status("error", "Could not stop the profiler: " .. tostring(problem)); return end
    self.owned = false
    self:_status("waiting", "Capture stopped. Waiting for the profiler snapshot…")
    local generation = self.generation
    ok, problem = pcall(self.adapter.request, self.target, self.player)
    if not ok then self:_status("error", "Could not request CPU results: " .. tostring(problem)); return end
    self.adapter.delay(8, function()
        if not self.destroyed and self.generation == generation and self.state.status == "waiting" then
            self:_status("error", "No profiler reply arrived within 8 seconds. Try another Play capture.")
        end
    end)
end
function Capture:_receive(player, raw)
    if self.destroyed or self.state.status ~= "waiting" then return end
    if self.target == "client" and player ~= self.player then return end
    if self.target == "server" and player ~= nil then return end
    local ok, decoded = pcall(self.adapter.decode, raw)
    if not ok then self:_status("error", "Could not decode the CPU snapshot: " .. tostring(decoded)); return end
    if type(decoded) ~= "table" or type(decoded.SessionStartTime) ~= "number" or type(decoded.SessionEndTime) ~= "number"
        or decoded.SessionStartTime ~= decoded.SessionStartTime or decoded.SessionEndTime ~= decoded.SessionEndTime
        or math.abs(decoded.SessionStartTime) == math.huge or math.abs(decoded.SessionEndTime) == math.huge then
        self:_status("error", "The CPU snapshot has no valid session timestamps; its recording cannot be identified.")
        return
    end
    if decoded.SessionStartTime < self.startedAt or decoded.SessionEndTime < self.startedAt then return end
    local result, problem = Profile.normalize(decoded)
    if not result then self:_status("error", problem); return end
    result.status = "complete"; result.target = self.target
    result.message = if #result.rows > 0 then "Measured CPU functions · inclusive sampled time." else "Capture returned no game functions. Exercise the workload while recording."
    self.state = result; self.changed()
end
function Capture:cancel()
    if self.destroyed then return end
    self.generation += 1
    if self.owned then
        local ok, problem = pcall(self.adapter.stop, self.target, self.player)
        if not ok then self:_status("error", "Profiler cleanup failed: " .. tostring(problem)); return end
        self.owned = false
    end
    if self.state.status == "recording" or self.state.status == "waiting" or self.state.status == "error" then
        self:_status("cancelled", "CPU capture cancelled. Start a new recording during Play.")
    end
end
function Capture:destroy()
    if self.destroyed then return end
    self:cancel(); self.destroyed = true
    if self.connection then self.connection:Disconnect(); self.connection = nil end
    self.changed = function() end
end
return Capture
