--!strict
local Report = {}
local function pick(input, keys)
    local result = {}
    for _, key in keys do
        local value = input[key]
        if type(value) == "string" or type(value) == "boolean" then result[key] = value
        elseif type(value) == "number" and value == value and math.abs(value) < math.huge then result[key] = value end
    end
    return result
end
function Report.snapshot(state)
    local report = {schemaVersion = 1, product = "Optic — Roblox Performance Profiler", version = "0.1.0",
        timestamp = state.timestamp or "Unavailable", context = state.context or "Current Studio session",
        limitations = {
            "Static findings are heuristics, not measured live connection counts or confirmed leaks.",
            "Session memory includes Studio/plugin overhead; it is not per-script memory.",
            "CPU function costs are inclusive and overlap; never sum them as total CPU usage.",
            "Memory growth is an observation requiring investigation, not proof of a leak."
        }, findings = {}, coverage = {}, metrics = {}, memory = {}, cpu = {}}
    for _, finding in state.findings or {} do
        if #report.findings >= 500 then break end
        table.insert(report.findings, pick(finding, {"rule", "path", "line", "severity", "confidence", "title", "evidence", "explanation", "recommendation"}))
    end
    report.coverage = pick(state.coverage or {}, {"scope", "scanned", "unreadable", "skipped", "candidates", "truncated", "cancelled", "sourceLimitBytes", "scriptLimit", "findingLimit", "scanContext", "scannedAt"})
    report.coverage.inProgress = state.scanning == true
    report.coverage.partial = report.coverage.inProgress or report.coverage.truncated == true or report.coverage.cancelled == true
        or (report.coverage.unreadable or 0) > 0 or (report.coverage.skipped or 0) > 0 or report.coverage.scope == nil
    report.metrics = pick(state.metrics or {}, {"sampleCount", "frameMs", "p95FrameMs", "fps", "memoryMb", "instances", "heartbeatMs", "physicsMs"})
    local memory = state.memory or {}
    report.memory = pick(memory, {"totalMb", "baselineMb", "baselineTime", "deltaMb", "hasBaseline", "growthMbPerMinute", "observationSeconds"})
    report.memory.categories = pick(memory.categories or {}, {"LuaHeap", "Script", "Signals", "Instances", "GraphicsTexture", "PhysicsCollision"})
    report.memory.categoryDeltas = pick(memory.categoryDeltas or {}, {"LuaHeap", "Script", "Signals", "Instances", "GraphicsTexture", "PhysicsCollision"})
    local cpu = state.cpu or {}
    report.cpu = pick(cpu, {"status", "message", "target", "durationMs", "functionCount", "excludedPluginFunctions", "truncated", "semantics"})
    report.cpu.rows = {}
    for _, row in cpu.rows or {} do
        if #report.cpu.rows >= 100 then break end
        table.insert(report.cpu.rows, pick(row, {"name", "path", "line", "durationMs", "percent"}))
    end
    return report
end
local function cell(value)
    local result = tostring(value or "Unavailable")
    result = string.gsub(result, "\\", "\\\\")
    result = string.gsub(result, "|", "\\|")
    result = string.gsub(result, "\r", "")
    return (string.gsub(result, "\n", "<br>"))
end
local function number(value, suffix)
    return if type(value) == "number" then string.format("%.2f%s", value, suffix or "") else "Unavailable"
end
function Report.markdown(report)
    local lines = {"# Optic — Roblox Performance Profiler", "", "Captured: " .. cell(report.timestamp),
        "Context: " .. cell(report.context), "", "## Coverage", ""}
    local coverage = report.coverage or {}
    table.insert(lines, string.format("Scope: %s · Scanned: %s · Unreadable: %s · Skipped: %s · Partial: %s",
        cell(coverage.scope), tostring(coverage.scanned or 0), tostring(coverage.unreadable or 0),
        tostring(coverage.skipped or 0), tostring(coverage.partial == true)))
    local m, memory = report.metrics or {}, report.memory or {}
    table.insert(lines, "\n## Session metrics\n")
    table.insert(lines, "| Metric | Value |\n| --- | --- |")
    for _, pair in {{"Mean frame time", number(m.frameMs, " ms")}, {"p95 frame time", number(m.p95FrameMs, " ms")},
        {"Session memory", number(m.memoryMb, " MB")}, {"Instances", number(m.instances)},
        {"Memory baseline delta", number(memory.deltaMb, " MB")}, {"Observed growth", number(memory.growthMbPerMinute, " MB/min")}} do
        table.insert(lines, "| " .. pair[1] .. " | " .. pair[2] .. " |")
    end
    table.insert(lines, "\n## Static findings (advisory)\n")
    table.insert(lines, "| Severity | Location | Finding | Recommendation |\n| --- | --- | --- | --- |")
    for _, finding in report.findings or {} do
        table.insert(lines, "| " .. cell(finding.severity) .. " | " .. cell(finding.path) .. ":" .. tostring(finding.line or 1)
            .. " | " .. cell(finding.title) .. " | " .. cell(finding.recommendation) .. " |")
    end
    if #(report.findings or {}) == 0 then table.insert(lines, "\nNo static findings in this report. Check coverage before drawing conclusions.") end
    table.insert(lines, "\n## CPU capture\n")
    table.insert(lines, cell(report.cpu.status or "idle") .. ": " .. cell(report.cpu.message or "No capture recorded."))
    table.insert(lines, "\nInclusive sampled times overlap; do not sum rows as total CPU usage.\n")
    table.insert(lines, "| Function | Location | Inclusive ms | Session % |\n| --- | --- | --- | --- |")
    for _, row in report.cpu.rows or {} do
        table.insert(lines, "| " .. cell(row.name) .. " | " .. cell(row.path) .. ":" .. tostring(row.line or 1)
            .. " | " .. number(row.durationMs) .. " | " .. number(row.percent, "%") .. " |")
    end
    table.insert(lines, "\n## Limitations\n")
    for _, limitation in report.limitations or {} do table.insert(lines, "- " .. limitation) end
    return table.concat(lines, "\n")
end
return Report
