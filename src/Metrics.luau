--!strict
local Metrics = {}
Metrics.__index = Metrics

local function valid(value)
    return type(value) == "number" and value == value and value >= 0 and value < math.huge
end
local function cleanCategories(categories)
    local result = {}
    if type(categories) == "table" then
        for name, value in categories do
            if type(name) == "string" and valid(value) then result[name] = value end
        end
    end
    return result
end
function Metrics.new(limit: number?)
    return setmetatable({samples = {}, limit = math.max(1, limit or 120), baselineSample = nil}, Metrics)
end
function Metrics:push(input)
    if not valid(input.time) then return false end
    local previous = self.samples[#self.samples]
    if previous and input.time <= previous.time then return false end
    local sample = {time = input.time, categories = cleanCategories(input.categories)}
    for _, name in {"frameMs", "memoryMb", "instances", "heartbeatMs", "physicsMs"} do
        if valid(input[name]) then sample[name] = input[name] end
    end
    table.insert(self.samples, sample)
    if #self.samples > self.limit then table.remove(self.samples, 1) end
    return true
end
function Metrics:summary()
    local latest = self.samples[#self.samples]
    if not latest then return {sampleCount = 0} end
    local frames, sum = {}, 0
    for _, sample in self.samples do
        if sample.frameMs and sample.frameMs > 0 then
            table.insert(frames, sample.frameMs); sum += sample.frameMs
        end
    end
    table.sort(frames)
    local mean = if #frames > 0 then sum / #frames else nil
    return {sampleCount = #self.samples, frameMs = mean,
        p95FrameMs = if #frames > 0 then frames[math.ceil(#frames * 0.95)] else nil,
        fps = if mean and mean > 0 then 1000 / mean else nil,
        memoryMb = latest.memoryMb, instances = latest.instances,
        heartbeatMs = latest.heartbeatMs, physicsMs = latest.physicsMs}
end
function Metrics:baseline()
    local latest = self.samples[#self.samples]
    if not latest or not latest.memoryMb then return false end
    self.baselineSample = {time = latest.time, memoryMb = latest.memoryMb,
        categories = table.clone(latest.categories)}
    return true
end
function Metrics:memory()
    local latest = self.samples[#self.samples]
    local result = {categories = if latest then table.clone(latest.categories) else {},
        categoryDeltas = {}, hasBaseline = self.baselineSample ~= nil}
    if not latest then return result end
    result.totalMb = latest.memoryMb
    local baseline = self.baselineSample
    if baseline then
        result.baselineMb = baseline.memoryMb
        result.baselineTime = baseline.time
        if latest.memoryMb then result.deltaMb = latest.memoryMb - baseline.memoryMb end
        for name, value in latest.categories do
            if baseline.categories[name] then result.categoryDeltas[name] = value - baseline.categories[name] end
        end
    end
    local points = {}
    for _, sample in self.samples do if sample.memoryMb then table.insert(points, sample) end end
    if #points < 10 then return result end
    local first = points[1].time
    local duration = points[#points].time - first
    if duration < 10 then return result end
    local sumX, sumY = 0, 0
    for _, point in points do sumX += point.time - first; sumY += point.memoryMb end
    local meanX, meanY = sumX / #points, sumY / #points
    local numerator, denominator = 0, 0
    for _, point in points do
        local x = point.time - first - meanX
        numerator += x * (point.memoryMb - meanY); denominator += x * x
    end
    result.observationSeconds = duration
    if denominator > 0 then
        local slope = numerator / denominator * 60
        if slope > 0.1 then result.growthMbPerMinute = slope end
    end
    return result
end
return Metrics
