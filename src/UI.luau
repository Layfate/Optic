--!strict
local Brand = require(script.Parent.Brand)
local UI = {}
UI.__index = UI

local C = {
    background = Color3.fromRGB(23, 24, 30),
    panel = Color3.fromRGB(31, 33, 41),
    raised = Color3.fromRGB(40, 42, 53),
    hover = Color3.fromRGB(49, 51, 64),
    border = Color3.fromRGB(54, 57, 70),
    text = Color3.fromRGB(241, 242, 247),
    muted = Color3.fromRGB(184, 188, 203),
    quiet = Color3.fromRGB(149, 155, 175),
    accent = Color3.fromRGB(192, 172, 255),
    accentFill = Color3.fromRGB(57, 47, 80),
    accentHover = Color3.fromRGB(208, 193, 255),
    green = Color3.fromRGB(149, 212, 182),
    warning = Color3.fromRGB(237, 196, 135),
    warningFill = Color3.fromRGB(62, 49, 36),
}
local F = {body = Enum.Font.BuilderSans, medium = Enum.Font.BuilderSansMedium,
    bold = Enum.Font.BuilderSansBold, mono = Enum.Font.RobotoMono}
local tabNames = {"Overview", "Findings", "CPU", "Memory", "Report"}

local function make(class, properties, parent)
    local object = Instance.new(class)
    for name, value in properties do object[name] = value end
    object.Parent = parent
    return object
end
local function round(object, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 12)}, object)
end
local function inset(object, amount)
    make("UIPadding", {PaddingLeft = UDim.new(0, amount), PaddingRight = UDim.new(0, amount),
        PaddingTop = UDim.new(0, amount), PaddingBottom = UDim.new(0, amount)}, object)
end
local function stack(object, gap)
    make("UIListLayout", {Padding = UDim.new(0, gap or 12), SortOrder = Enum.SortOrder.LayoutOrder}, object)
end
local function outline(object, color)
    return make("UIStroke", {Color = color or C.border, Thickness = 1, Transparency = 0.35,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, object)
end
local function label(parent, text, height, color, size, font)
    return make("TextLabel", {BackgroundTransparency = 1, Text = text, TextColor3 = color or C.text,
        TextSize = size or 15, Font = font or F.body, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, RichText = false,
        Size = UDim2.new(1, 0, 0, height or 0),
        AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y}, parent)
end
local function surface(parent, height, color)
    local frame = make("Frame", {BackgroundColor3 = color or C.panel, BorderSizePixel = 0,
        Size = UDim2.new(1, -6, 0, height or 0),
        AutomaticSize = if height then Enum.AutomaticSize.None else Enum.AutomaticSize.Y}, parent)
    round(frame); inset(frame, 18)
    if not height then stack(frame, 10) end
    return frame
end
local function paintButton(object, hovered, pressed, focused)
    local tone = object:GetAttribute("Tone")
    local selected = object:GetAttribute("Selected") == true
    if tone == "primary" then
        object.BackgroundColor3 = if pressed then C.accent elseif hovered then C.accentHover else C.accent
        object.TextColor3 = C.background
    elseif tone == "tab" then
        object.BackgroundColor3 = if selected then C.raised elseif hovered then C.hover else C.panel
        object.TextColor3 = if selected then C.text else C.muted
    else
        object.BackgroundColor3 = if pressed then C.hover elseif hovered then C.hover else C.raised
        object.TextColor3 = C.text
    end
    local stroke = object:FindFirstChildOfClass("UIStroke")
    if stroke then
        stroke.Color = if focused then C.accent else C.border
        stroke.Transparency = if focused then 0 else 0.5
    end
end
local function button(parent, text, width, callback, connections, tone)
    local object = make("TextButton", {Text = text, Size = UDim2.fromOffset(width or 120, 38),
        BackgroundColor3 = C.raised, BorderSizePixel = 0, TextColor3 = C.text,
        TextSize = 14, Font = F.medium, AutoButtonColor = false, Selectable = true}, parent)
    round(object, 9); outline(object)
    object:SetAttribute("Tone", tone or "secondary")
    local hovered, pressed, focused = false, false, false
    local function paint() paintButton(object, hovered, pressed, focused) end
    local function connect(signal, callback) table.insert(connections, signal:Connect(callback)) end
    connect(object.Activated, callback)
    connect(object.MouseEnter, function() hovered = true; paint() end)
    connect(object.MouseLeave, function() hovered = false; pressed = false; paint() end)
    connect(object.MouseButton1Down, function() pressed = true; paint() end)
    connect(object.MouseButton1Up, function() pressed = false; paint() end)
    connect(object.SelectionGained, function() focused = true; paint() end)
    connect(object.SelectionLost, function() focused = false; paint() end)
    connect(object:GetAttributeChangedSignal("Selected"), paint)
    paint()
    return object
end
local function numeric(value, suffix, decimals)
    return if type(value) == "number" then string.format("%." .. tostring(decimals or 1) .. "f%s", value, suffix or "") else "Unavailable"
end
local function signed(value, suffix)
    return if type(value) == "number" then string.format("%+.1f%s", value, suffix or "") else "No baseline"
end
local function section(parent, title, description)
    local frame = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, parent)
    stack(frame, 5)
    label(frame, title, nil, C.text, 20, F.bold)
    if description then label(frame, description, nil, C.muted, 14) end
    return frame
end

function UI.new(widget, actions)
    local self = setmetatable({widget = widget, actions = actions, connections = {}, pageConnections = {},
        pages = {}, tabs = {}, dynamic = {}, current = "Overview", search = "", severity = "all",
        reportPage = 1, reportChunks = {"Your report will appear here. Choose a format, then select Generate report."}}, UI)
    self.root = make("Frame", {Name = "Optic", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.background, BorderSizePixel = 0}, widget)
    local header = make("Frame", {Name = "Header", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 58)}, self.root)
    self.logo = make("ImageLabel", {Name = "BrandLogo", BackgroundTransparency = 1, Image = Brand.Logo,
        ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromOffset(56, 56)}, header)
    local name = label(header, "Optic", 34, C.text, 30, F.bold)
    name.Position = UDim2.fromOffset(68, 0); name.Size = UDim2.new(1, -210, 0, 36)
    local subtitle = label(header, "Roblox performance profiler", 20, C.muted, 14)
    subtitle.Position = UDim2.fromOffset(69, 37); subtitle.Size = UDim2.new(1, -72, 0, 20)
    local badge = make("Frame", {Name = "Context", BackgroundColor3 = C.panel, BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(122, 29)}, header)
    round(badge, 14)
    local dot = make("Frame", {BackgroundColor3 = C.green, BorderSizePixel = 0, Position = UDim2.fromOffset(12, 11), Size = UDim2.fromOffset(7, 7)}, badge)
    round(dot, 4)
    self.contextLabel = label(badge, "Live · Studio", 20, C.muted, 13, F.medium)
    self.contextLabel.Position = UDim2.fromOffset(26, 5); self.contextLabel.Size = UDim2.new(1, -30, 0, 20)

    local controls = make("Frame", {Name = "Actions", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 88), Size = UDim2.new(1, -40, 0, 38)}, self.root)
    make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, controls)
    self.scopeButton = button(controls, "Project", 100, function() actions.scope() end, self.connections)
    self.scanButton = button(controls, "Scan project", 130, function() actions.scan() end, self.connections, "primary")
    self.captureButton = button(controls, "Record CPU", 130, function() self:switch("CPU"); actions.capture() end, self.connections)
    self.baselineButton = button(controls, "Baseline", 100, function() actions.baseline() end, self.connections)
    for index, control in {self.scopeButton, self.scanButton, self.captureButton, self.baselineButton} do
        control.Size = UDim2.new(({0.22, 0.28, 0.28, 0.22})[index], -7.5, 0, 38)
    end

    local tabs = make("Frame", {Name = "Navigation", BackgroundColor3 = C.panel, BorderSizePixel = 0,
        Position = UDim2.fromOffset(20, 140), Size = UDim2.new(1, -40, 0, 42)}, self.root)
    round(tabs, 11)
    for index, tabName in tabNames do
        local tab = button(tabs, tabName, 80, function() self:switch(tabName) end, self.connections, "tab")
        tab.Position = UDim2.new((index - 1) / 5, 4, 0, 4)
        tab.Size = UDim2.new(1 / 5, -8, 1, -8)
        local stroke = tab:FindFirstChildOfClass("UIStroke")
        if stroke then stroke.Enabled = false end
        self.tabs[tabName] = tab
    end
    self.notice = label(self.root, "Ready when you are. Start with a project scan.", 30, C.muted, 13)
    self.notice.Name = "Status"
    self.notice.Position = UDim2.fromOffset(20, 194); self.notice.Size = UDim2.new(1, -40, 0, 30)
    self.body = make("Frame", {Name = "Content", BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 236), Size = UDim2.new(1, -40, 1, -254)}, self.root)
    for _, tabName in tabNames do
        local page = make("ScrollingFrame", {Name = tabName, BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 4, ScrollBarImageColor3 = C.border, ScrollingDirection = Enum.ScrollingDirection.Y,
            Visible = tabName == "Overview"}, self.body)
        stack(page, 14); self.pages[tabName] = page; self.pageConnections[tabName] = {}
    end
    self:_overview(); self:_findingsControls(); self:_cpuControls(); self:_memoryControls(); self:_reportControls()
    table.insert(self.connections, self.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:_layout() end))
    table.insert(self.connections, self.notice:GetPropertyChangedSignal("TextBounds"):Connect(function() self:_layout() end))
    self:_layout(); self:switch("Overview")
    return self
end

function UI:_layout()
    local width = self.root.AbsoluteSize.X
    local noticeHeight = math.clamp(self.notice.TextBounds.Y + 4, 24, 68)
    self.notice.Size = UDim2.new(1, -40, 0, noticeHeight)
    local top = 194 + noticeHeight + 14
    self.body.Position = UDim2.fromOffset(20, top)
    self.body.Size = UDim2.new(1, -40, 0, math.max(48, self.root.AbsoluteSize.Y - top - 18))
    if not self.metricGrid then return end
    local columns = if width >= 680 then 4 else 2
    self.metricGrid.Size = UDim2.new(1, -6, 0, if columns == 4 then 112 else 236)
    for index, tile in self.metricTiles do
        local column = (index - 1) % columns
        tile.Position = UDim2.new(column / columns, column * 12 / columns, 0, math.floor((index - 1) / columns) * 124)
        tile.Size = UDim2.new(1 / columns, -(columns - 1) * 12 / columns, 0, 112)
    end
end

function UI:switch(name)
    self.current = name
    for pageName, page in self.pages do
        page.Visible = pageName == name
        self.tabs[pageName]:SetAttribute("Selected", pageName == name)
    end
    if self.state then self:render(self.state) end
end
function UI:_clear(name)
    for _, connection in self.pageConnections[name] do connection:Disconnect() end
    self.pageConnections[name] = {}
    local parent = self.dynamic[name] or self.pages[name]
    for _, child in parent:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
end
function UI:_dynamic(name)
    local frame = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, self.pages[name])
    stack(frame, 12); self.dynamic[name] = frame
    return frame
end

function UI:_overview()
    self.metricValues, self.metricHints, self.metricTiles = {}, {}, {}
    self.metricGrid = make("Frame", {Name = "MetricGrid", BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 112)}, self.pages.Overview)
    for _, item in {{"frameMs", "Frame time", "Sampled mean"}, {"memoryMb", "Memory", "Studio session"},
        {"instances", "Instances", "Objects in memory"}, {"findings", "Findings", "Source suggestions"}} do
        local tile = make("Frame", {Name = item[1], BackgroundColor3 = C.panel, BorderSizePixel = 0, Size = UDim2.fromOffset(160, 112)}, self.metricGrid)
        round(tile); inset(tile, 16)
        label(tile, item[2], 18, C.muted, 14, F.medium)
        local value = label(tile, "—", 36, C.text, 28, F.medium)
        value.Position = UDim2.fromOffset(0, 25)
        local hint = label(tile, item[3], 19, C.quiet, 13)
        hint.Position = UDim2.fromOffset(0, 64)
        self.metricValues[item[1]] = value; self.metricHints[item[1]] = hint
        table.insert(self.metricTiles, tile)
    end
    local chart = surface(self.pages.Overview, 186)
    label(chart, "Frame history", 22, C.text, 17, F.medium)
    self.chartSummary = label(chart, "Waiting for samples", 20, C.muted, 13)
    self.chartSummary.Position = UDim2.fromOffset(0, 29)
    self.graph = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 68)}, chart)
    for index = 1, 3 do
        make("Frame", {BackgroundColor3 = C.border, BackgroundTransparency = 0.5, BorderSizePixel = 0,
            Position = UDim2.new(0, 0, index / 3, 0), Size = UDim2.new(1, 0, 0, 1)}, self.graph)
    end
    self.bars = {}
    for index = 1, 60 do
        local bar = make("Frame", {BorderSizePixel = 0, BackgroundColor3 = C.accent, BackgroundTransparency = 0.23,
            AnchorPoint = Vector2.new(0, 1), Position = UDim2.new((index - 1) / 60, 0, 1, 0),
            Size = UDim2.new(1 / 60, -3, 0, 0)}, self.graph)
        round(bar, 2); self.bars[index] = bar
    end
    self.graphNote = label(chart, "0.5s samples · Studio may slow frames when unfocused.", 20, C.quiet, 13)
    self.graphNote.Position = UDim2.fromOffset(0, 137)
    local guide = surface(self.pages.Overview)
    label(guide, "A good place to start", nil, C.text, 17, F.medium)
    label(guide, "Scan your scripts, record a slow moment, then compare memory to a baseline.", nil, C.muted, 15)
    label(guide, "Metrics include Studio and plugin activity. Source findings are suggestions to investigate.", nil, C.quiet, 13)
end

function UI:_findingsControls()
    section(self.pages.Findings, "Small changes. Smoother games.", "Review source patterns, then open a script to take a closer look.")
    self.searchBox = make("TextBox", {Name = "Search", PlaceholderText = "Search scripts or suggestions…", Text = "", ClearTextOnFocus = false,
        Size = UDim2.new(1, -6, 0, 42), BackgroundColor3 = C.panel, BorderSizePixel = 0,
        TextColor3 = C.text, PlaceholderColor3 = C.quiet, Font = F.body, TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left}, self.pages.Findings)
    round(self.searchBox, 10); inset(self.searchBox, 12); outline(self.searchBox)
    table.insert(self.connections, self.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        self.search = string.lower(self.searchBox.Text); self.lastFindings = nil
        if self.state then self:render(self.state) end
    end))
    local row = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 38)}, self.pages.Findings)
    self.filterButton = button(row, "All severities", 136, function()
        self.severity = if self.severity == "all" then "warning" elseif self.severity == "warning" then "info" else "all"
        self.filterButton.Text = if self.severity == "all" then "All severities" elseif self.severity == "warning" then "Warnings" else "Information"
        self.lastFindings = nil
        if self.state then self:render(self.state) end
    end, self.connections)
    self.findingCount = label(row, "No scan yet", 36, C.muted, 13)
    self.findingCount.Position = UDim2.fromOffset(150, 9); self.findingCount.Size = UDim2.new(1, -150, 0, 30)
    self.coverageLabel = label(self.pages.Findings, "Scan your project to see its coverage.", nil, C.quiet, 13)
    self:_dynamic("Findings")
end
function UI:_renderFindings(state)
    local coverage = state.coverage
    local revision = #state.findings + (coverage.scanned or 0) + (coverage.unreadable or 0) + (coverage.skipped or 0)
    if self.lastFindings == state.findings and self.lastScanning == state.scanning and self.lastFindingRevision == revision then return end
    self.lastFindings = state.findings; self.lastScanning = state.scanning; self.lastFindingRevision = revision
    self:_clear("Findings")
    local matched, shown = 0, 0
    for _, finding in state.findings do
        local haystack = string.lower(finding.path .. " " .. finding.title .. " " .. finding.rule .. " " .. finding.recommendation)
        if self.severity ~= "all" and finding.severity ~= self.severity then continue end
        if self.search ~= "" and not string.find(haystack, self.search, 1, true) then continue end
        matched += 1
        if shown >= 100 then continue end
        shown += 1
        local tile = surface(self.dynamic.Findings)
        local badge = make("Frame", {BackgroundColor3 = if finding.severity == "warning" then C.warningFill else C.accentFill,
            BorderSizePixel = 0, Size = UDim2.fromOffset(92, 26)}, tile)
        round(badge, 7)
        local badgeText = label(badge, if finding.severity == "warning" then "Review" else "Suggestion", 20,
            if finding.severity == "warning" then C.warning else C.accent, 13, F.medium)
        badgeText.Position = UDim2.fromOffset(10, 4); badgeText.Size = UDim2.new(1, -20, 0, 20)
        label(tile, finding.title, nil, C.text, 18, F.medium)
        label(tile, finding.path .. ":" .. finding.line, nil, C.muted, 13, F.mono)
        label(tile, finding.explanation, nil, C.muted, 15)
        local recommendation = surface(tile, nil, C.raised)
        label(recommendation, "Suggested improvement", nil, C.accent, 13, F.medium)
        label(recommendation, finding.recommendation, nil, C.text, 15)
        label(tile, finding.evidence .. " · " .. finding.confidence .. " confidence", nil, C.quiet, 13)
        button(tile, "Open script ↗", 132, function() self.actions.open(finding) end, self.pageConnections.Findings)
    end
    self.findingCount.Text = string.format("%d shown · %d matching", shown, matched)
    self.coverageLabel.Text = string.format("%d scripts read · %d unreadable · %d skipped%s", coverage.scanned or 0,
        coverage.unreadable or 0, coverage.skipped or 0, if coverage.truncated or coverage.cancelled then " · partial coverage" else "")
    if matched == 0 then
        local tile = surface(self.dynamic.Findings)
        label(tile, if state.scanning then "Looking through your scripts…" else "Nothing to review here yet", nil, C.text, 18, F.medium)
        label(tile, if self.search ~= "" or self.severity ~= "all" then "Try another search or show all severities."
            else "Start a scan to check common patterns. A clear scan covers these checks only; CPU and memory can tell you more.", nil, C.muted, 15)
    end
end

function UI:_cpuControls()
    section(self.pages.CPU, "Find your most expensive work", "Record while reproducing the part of your game that feels slow.")
    local intro = surface(self.pages.CPU)
    label(intro, "Start Play, then record", nil, C.text, 17, F.medium)
    label(intro, "Choose a target below. A recording runs for up to 15 seconds, or you can stop it early.", nil, C.muted, 15)
    self.targetButton = button(intro, "Client", 148, function() self.actions.target() end, self.connections)
    self.cpuStatus = label(self.pages.CPU, "Ready for your first capture.", nil, C.accent, 14)
    label(self.pages.CPU, "Times are sampled and inclusive. Functions can overlap, so their costs do not add up to total CPU usage.", nil, C.quiet, 13)
    self:_dynamic("CPU")
end
function UI:_renderCPU(state)
    self.targetButton.Text = if state.target == "client" then "Target: Client" else "Target: Server"
    self.cpuStatus.Text = state.cpu.message or "Ready for your first capture."
    if self.lastCPU == state.cpu.rows then return end
    self.lastCPU = state.cpu.rows; self:_clear("CPU")
    for index, row in state.cpu.rows or {} do
        local tile = surface(self.dynamic.CPU)
        label(tile, string.format("%02d   %s", index, row.name), nil, C.text, 17, F.medium)
        label(tile, numeric(row.durationMs, " ms") .. "  ·  " .. numeric(row.percent, "% of session"), nil, C.accent, 20, F.medium)
        label(tile, row.path .. ":" .. tostring(row.line or "?"), nil, C.muted, 13, F.mono)
        button(tile, "Open source ↗", 132, function() self.actions.open(row) end, self.pageConnections.CPU)
    end
    if #(state.cpu.rows or {}) == 0 then
        local tile = surface(self.dynamic.CPU)
        label(tile, "Your capture results will appear here", nil, C.text, 18, F.medium)
        label(tile, "Start a Play test and select Record CPU. If profiling is unavailable, its status will explain why.", nil, C.muted, 15)
    end
end

function UI:_memoryControls()
    section(self.pages.Memory, "Give memory a little context", "Take a baseline before your workload, then compare what changes.")
    local summary = surface(self.pages.Memory)
    label(summary, "Studio session memory", nil, C.muted, 14, F.medium)
    self.memoryTotal = label(summary, "Unavailable", nil, C.text, 30, F.medium)
    self.memoryDelta = label(summary, "Set a baseline to compare changes.", nil, C.accent, 15)
    self.memoryBaseline = label(summary, "", nil, C.muted, 14)
    local trend = surface(self.pages.Memory)
    label(trend, "Observed trend", nil, C.text, 17, F.medium)
    self.memoryTrend = label(trend, "Gathering observations…", nil, C.muted, 15)
    label(trend, "Growth can come from loading, caching, garbage collection or Studio. It is a signal to investigate, not proof of a leak. Trends need 10 samples spanning 10 seconds.", nil, C.quiet, 13)
    local categories = surface(self.pages.Memory)
    label(categories, "Where memory is tracked", nil, C.text, 17, F.medium)
    self.categoryRows, self.categoryValues, self.categoryDeltas = {}, {}, {}
    for _, name in {"LuaHeap", "Script", "Signals", "Instances", "GraphicsTexture", "PhysicsCollision"} do
        local row = make("Frame", {Name = name, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30)}, categories)
        local title = label(row, name, 28, C.muted, 14)
        title.Size = UDim2.new(0.43, 0, 1, 0)
        local value = label(row, "Unavailable", 28, C.text, 14, F.medium)
        value.Position = UDim2.fromScale(0.44, 0); value.Size = UDim2.new(0.28, 0, 1, 0)
        local delta = label(row, "—", 28, C.quiet, 13)
        delta.Position = UDim2.fromScale(0.74, 0); delta.Size = UDim2.new(0.26, 0, 1, 0)
        self.categoryRows[name] = row; self.categoryValues[name] = value; self.categoryDeltas[name] = delta
    end
    label(categories, "Categories use different accounting from process memory and are not expected to add up.", nil, C.quiet, 13)
end
function UI:_renderMemory(state)
    local memory = state.memory
    self.memoryTotal.Text = numeric(memory.totalMb, " MB")
    self.memoryDelta.Text = if memory.hasBaseline then signed(memory.deltaMb, " MB since baseline") else "Select Baseline above to start a comparison."
    self.memoryBaseline.Text = if memory.hasBaseline then "Baseline · " .. numeric(memory.baselineMb, " MB") else "No baseline captured yet."
    self.memoryTrend.Text = if memory.growthMbPerMinute then numeric(memory.growthMbPerMinute, " MB/min observed growth")
        .. " over " .. numeric(memory.observationSeconds, " seconds") else "No sustained positive growth signal in the available observations."
    self.memoryTrend.TextColor3 = if memory.growthMbPerMinute then C.warning else C.muted
    for name, value in self.categoryValues do
        value.Text = numeric(memory.categories[name], " MB")
        self.categoryDeltas[name].Text = if memory.categoryDeltas[name] then signed(memory.categoryDeltas[name], " MB") else "—"
    end
end

function UI:_reportControls()
    section(self.pages.Report, "Keep a useful snapshot", "Save what you found, with enough context to act on it later.")
    local intro = surface(self.pages.Report)
    label(intro, "Choose a format", nil, C.text, 17, F.medium)
    label(intro, "Generate a frozen report, then copy its text into a local file. Your script source is excluded.", nil, C.muted, 15)
    local row = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38)}, intro)
    self.formatButton = button(row, "JSON", 116, function() self.actions.format() end, self.connections)
    self.formatButton.Size = UDim2.new(0.4, -6, 0, 38)
    local generate = button(row, "Generate report", 160, function() self.actions.report() end, self.connections, "primary")
    generate.Position = UDim2.new(0.4, 6, 0, 0); generate.Size = UDim2.new(0.6, -6, 0, 38)
    label(intro, "Large reports use multiple pages. Copy each page in order without adding characters between them.", nil, C.quiet, 13)
    local navigation = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 38)}, self.pages.Report)
    button(navigation, "Previous", 84, function() self:_showReportPage(self.reportPage - 1) end, self.connections)
    button(navigation, "Next", 64, function() self:_showReportPage(self.reportPage + 1) end, self.connections).Position = UDim2.fromOffset(92, 0)
    button(navigation, "Select text", 96, function()
        self.reportBox:CaptureFocus(); self.reportBox.CursorPosition = 1; self.reportBox.SelectionStart = #self.reportBox.Text + 1
    end, self.connections).Position = UDim2.fromOffset(164, 0)
    self.reportPageLabel = label(navigation, "1 / 1", 25, C.muted, 13)
    self.reportPageLabel.Position = UDim2.fromOffset(272, 10); self.reportPageLabel.Size = UDim2.new(1, -272, 0, 25)
    self.reportBox = make("TextBox", {Name = "ReportText", Text = self.reportChunks[1], TextEditable = false, MultiLine = true,
        ClearTextOnFocus = false, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        BackgroundColor3 = C.panel, BorderSizePixel = 0, TextColor3 = C.text, Font = F.mono, TextSize = 14,
        Size = UDim2.new(1, -6, 0, 260), AutomaticSize = Enum.AutomaticSize.Y}, self.pages.Report)
    round(self.reportBox); inset(self.reportBox, 16); outline(self.reportBox)
end
function UI:setReport(text)
    self.reportChunks = {}
    local first = 1
    while first <= #text do
        local last = math.min(first + 23999, #text)
        while last < #text do
            local byte = string.byte(text, last + 1)
            if not byte or byte < 128 or byte >= 192 then break end
            last -= 1
        end
        table.insert(self.reportChunks, string.sub(text, first, last)); first = last + 1
    end
    if #self.reportChunks == 0 then self.reportChunks = {"Empty report"} end
    self:_showReportPage(1); self:switch("Report")
end
function UI:_showReportPage(page)
    self.reportPage = math.clamp(page, 1, #self.reportChunks)
    self.reportBox.Text = self.reportChunks[self.reportPage]
    self.reportPageLabel.Text = self.reportPage .. " / " .. #self.reportChunks
end

function UI:render(state)
    self.state = state
    self.contextLabel.Text = if string.sub(state.context, 1, 4) == "Play" then "Live · Play" else "Live · Edit"
    self.notice.Text = state.notice
    self.scopeButton.Text = if state.scope == "selection" then "Selection" else "Project"
    self.scanButton.Text = if state.scanning then "Cancel scan" else "Scan " .. state.scope
    self.captureButton.Text = if state.cpu.status == "recording" then "Stop CPU" elseif state.cpu.status == "waiting" then "Waiting…" else "Record CPU"
    self.formatButton.Text = if state.format == "json" then "JSON" else "Markdown"
    if self.current == "Overview" then
        for _, key in {"frameMs", "memoryMb", "instances"} do
            local value = state.metrics[key]
            local suffix = if key == "frameMs" then " ms" elseif key == "memoryMb" then " MB" else ""
            self.metricValues[key].Text = numeric(value, suffix, if key == "instances" then 0 else 1)
            self.metricValues[key].TextSize = if type(value) == "number" then 28 else 18
        end
        self.metricValues.findings.Text = tostring(#state.findings)
        self.metricHints.memoryMb.Text = if state.memory.hasBaseline then signed(state.memory.deltaMb, " MB change") else "Studio session"
        local maximum = 33.3
        local start = math.max(1, #state.samples - 59)
        for index = start, #state.samples do maximum = math.max(maximum, (state.samples[index].frameMs or 0) * 1.08) end
        for index, bar in self.bars do
            local sample = state.samples[start + index - 1]
            local value = if sample then sample.frameMs else nil
            bar.Size = UDim2.new(1 / 60, -3, 0, if value then math.max(2, value / maximum * 68) else 0)
        end
        self.chartSummary.Text = "p95 " .. numeric(state.metrics.p95FrameMs, " ms") .. "   ·   Scale 0–" .. numeric(maximum, " ms")
    elseif self.current == "Findings" then self:_renderFindings(state)
    elseif self.current == "CPU" then self:_renderCPU(state)
    elseif self.current == "Memory" then self:_renderMemory(state) end
    self:_layout()
end
function UI:destroy()
    for _, connection in self.connections do connection:Disconnect() end
    for _, connections in self.pageConnections do for _, connection in connections do connection:Disconnect() end end
    self.root:Destroy()
end
return UI
