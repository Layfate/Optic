--!strict
local Profile = {}
local function finite(value)
    return type(value) == "number" and value == value and math.abs(value) < math.huge
end
local function text(value, fallback)
    return if type(value) == "string" and value ~= "" then string.sub(value, 1, 1024) else fallback
end
local function pluginSource(source)
    if type(source) ~= "string" then return false end
    return string.match(source, "^user_.-%.rbxmx?%.") ~= nil
        or string.match(source, "^cloud_%d+%.") ~= nil
        or string.match(source, "^builtin_.-%.rbxmx?%.") ~= nil
        or string.match(source, "^sabuiltin_.-%.rbxmx?%.") ~= nil
end
function Profile.normalize(data)
    if type(data) ~= "table" or type(data.Functions) ~= "table" then
        return nil, "The profiler snapshot has no supported Functions array."
    end
    local duration
    if finite(data.SessionStartTime) and finite(data.SessionEndTime)
        and data.SessionEndTime > data.SessionStartTime then
        duration = data.SessionEndTime - data.SessionStartTime
    end
    local rows, inspected, excluded = {}, 0, 0
    for _, fn in data.Functions do
        inspected += 1
        if inspected > 50000 then break end
        if type(fn) ~= "table" then continue end
        local flags = if finite(fn.Flags) and fn.Flags >= 0 then math.floor(fn.Flags) else 0
        if bit32.band(flags, 2) ~= 0 or pluginSource(fn.Source) then excluded += 1; continue end
        if not finite(fn.TotalDuration) or fn.TotalDuration < 0 then continue end
        local ms = fn.TotalDuration / 1000
        table.insert(rows, {name = text(fn.Name, "<anonymous>"), path = text(fn.Source, "<unavailable>"),
            line = if finite(fn.Line) and fn.Line >= 1 then math.floor(fn.Line) else nil,
            durationMs = ms, percent = if duration then ms / duration * 100 else nil})
    end
    table.sort(rows, function(a, b)
        if a.durationMs == b.durationMs then return a.path .. a.name < b.path .. b.name end
        return a.durationMs > b.durationMs
    end)
    local total = #rows
    while #rows > 100 do table.remove(rows) end
    return {rows = rows, durationMs = duration, functionCount = total,
        excludedPluginFunctions = excluded, truncated = total > 100 or inspected > 50000,
        semantics = "Inclusive sampled CPU time; function costs overlap and must not be summed."}
end
return Profile
