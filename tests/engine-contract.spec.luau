local Studio = require(script.Parent.Studio)
local Profile = require(script.Parent.Profile)
local count, failures = 0, {}
local function test(name, run)
    local ok, message = pcall(run)
    count += 1
    print(if ok then "PASS" else "FAIL", name)
    if not ok then table.insert(failures, name .. ": " .. tostring(message)) end
end
test("native decoder boundary preserves raw microseconds instead of deserialized seconds", function()
    -- These two representations were observed from the SAME real Studio snapshot.
    local raw = {Version = 2, SessionStartTime = 1000, SessionEndTime = 16000,
        Functions = {{Flags = 0, Line = 4, Source = "Players.Test.PlayerScripts.OpticClientFixture", TotalDuration = 109692}}}
    local converted = {Version = 2, SessionStartTime = 1000, SessionEndTime = 16000,
        Functions = {{Line = 4, Source = "Players.Test.PlayerScripts.OpticClientFixture", TotalDuration = 0.109692}}}
    local signal = {Connect = function() return {Disconnect = function() end} end}
    local services = {
        RunService = {GetPropertyChangedSignal = function() return signal end},
        HttpService = {JSONDecode = function() return raw end},
        ScriptProfilerService = {OnNewData = signal, DeserializeJSON = function() return converted end},
        Stats = {}, Players = {}, Selection = {}, ScriptEditorService = {},
    }
    local originalGame = game
    game = {GetService = function(_, name) return services[name] end}
    local ok, problem = pcall(function()
        local studio = Studio.new(function() end)
        local data = studio.capture.adapter.decode("{real-json-fixture}")
        local profile = Profile.normalize(data)
        studio:destroy()
        assert(math.abs(profile.rows[1].durationMs - 109.692) < 0.000001)
    end)
    game = originalGame
    assert(ok, problem)
end)
test("known Studio plugin source paths are excluded when native flags are unset", function()
    local data = {Functions = {
        {Flags = 0, Source = "user_Optic.rbxmx.Optic.UI", TotalDuration = 2006},
        {Flags = 0, Source = "cloud_8813198599.ParticleEditor.ParticleEditor", TotalDuration = 7172},
        {Flags = 0, Source = "builtin_Test.rbxm.Test", TotalDuration = 5000},
        {Flags = 0, Source = "Workspace.Optic", TotalDuration = 9000},
    }}
    local result = Profile.normalize(data)
    assert(#result.rows == 1 and result.rows[1].path == "Workspace.Optic")
    assert(result.excludedPluginFunctions == 3)
end)
assert(#failures == 0, table.concat(failures, "\n"))
return count
