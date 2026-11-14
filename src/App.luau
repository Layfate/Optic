--!strict
local Studio = require(script.Parent.Studio)
local UI = require(script.Parent.UI)
local Report = require(script.Parent.Report)
local Brand = require(script.Parent.Brand)
local App = {}

function App.start(plugin)
    local function setting(name, fallback, allowed)
        local ok, value = pcall(function() return plugin:GetSetting("Optic." .. name) end)
        return if ok and allowed[value] then value else fallback
    end
    local scope = setting("Scope", "project", {project = true, selection = true})
    local target = setting("Target", "client", {client = true, server = true})
    local format = setting("Format", "json", {json = true, markdown = true})
    local function save(name, value) pcall(function() plugin:SetSetting("Optic." .. name, value) end) end
    local toolbar = plugin:CreateToolbar("Optic")
    local toggle = toolbar:CreateButton("Optic.Toggle", "Open Optic — Roblox Performance Profiler", Brand.Logo, "Optic")
    toggle.ClickableWhenViewportHidden = true
    -- A floating first launch avoids Studio squeezing a new right dock below Explorer.
    local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, false, 800, 740, 480, 440)
    local ok, widget = pcall(function() return plugin:CreateDockWidgetPluginGuiAsync("Optic.Profiler.v2", info) end)
    if not ok then widget = plugin:CreateDockWidgetPluginGui("Optic.Profiler.v2", info) end
    widget.Title = "Optic — Roblox Performance Profiler"
    local alive, ui, studio = true, nil, nil
    local queued = false
    local function state()
        return {timestamp = DateTime.now():ToIsoDate(), context = studio:context(), scope = scope, target = target,
            format = format, notice = studio.notice, scanning = studio.scanning, findings = studio.findings,
            coverage = studio.coverage, metrics = studio.metrics:summary(), memory = studio.metrics:memory(),
            samples = studio.metrics.samples, cpu = studio.capture.state}
    end
    local function render()
        if alive and ui and studio and widget.Enabled then ui:render(state()) end
    end
    local function changed()
        if not alive or queued then return end
        queued = true
        -- Scan batches can arrive every frame; cap automatic GUI refreshes at 2 Hz.
        task.delay(0.5, function() queued = false; render() end)
    end
    studio = Studio.new(changed)
    local reportSnapshot
    ui = UI.new(widget, {
        scope = function() scope = if scope == "project" then "selection" else "project"; save("Scope", scope); changed() end,
        scan = function() if studio.scanning then studio:cancelScan() else studio:scan(scope) end end,
        target = function()
            if studio.capture.state.status == "recording" or studio.capture.state.status == "waiting" then
                studio.notice = "Finish the current CPU capture before changing its target."; changed(); return
            end
            target = if target == "client" then "server" else "client"; save("Target", target); changed()
        end,
        capture = function()
            if studio.capture.state.status == "recording" then studio.capture:stop()
            elseif studio.capture.state.status ~= "waiting" then studio.capture:start(target) end
        end,
        baseline = function()
            studio:sample()
            studio.notice = if studio.metrics:baseline() then "Memory baseline set for the current Studio session." else "Memory is unavailable; a baseline could not be set."
            changed()
        end,
        open = function(finding) studio:open(finding) end,
        format = function()
            format = if format == "json" then "markdown" else "json"; save("Format", format)
            if reportSnapshot then
                ui:setReport(if format == "json" then studio.http:JSONEncode(reportSnapshot) else Report.markdown(reportSnapshot))
            end
            changed()
        end,
        report = function()
            reportSnapshot = Report.snapshot(state())
            ui:setReport(if format == "json" then studio.http:JSONEncode(reportSnapshot) else Report.markdown(reportSnapshot))
            studio.notice = "Report frozen. Copy pages in order into a local file; use Generate to refresh it."; changed()
        end,
    })
    local connections = {}
    local function visibility()
        toggle:SetActive(widget.Enabled)
        studio:setSampling(widget.Enabled)
        if not widget.Enabled then studio:cancelScan(); studio.capture:cancel() end
        render()
    end
    table.insert(connections, toggle.Click:Connect(function() widget.Enabled = not widget.Enabled end))
    table.insert(connections, widget:GetPropertyChangedSignal("Enabled"):Connect(visibility))
    widget:BindToClose(function() widget.Enabled = false end)
    local unload
    unload = plugin.Unloading:Connect(function()
        if not alive then return end
        alive = false; studio:destroy(); ui:destroy()
        for _, connection in connections do connection:Disconnect() end
        if unload then unload:Disconnect() end
        widget:Destroy(); toolbar:Destroy()
    end)
    visibility()
end
return App
