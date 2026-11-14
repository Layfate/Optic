--!strict
local Lexer = require(script.Parent.Lexer)
local Scanner = {}
local frameSignals = {Heartbeat = true, RenderStepped = true, Stepped = true,
    PreRender = true, PreSimulation = true, PostSimulation = true}
local expressionPrefix = { ["="] = true, ["return"] = true, ["("] = true, ["["] = true,
    ["{"] = true, [","] = true, ["+"] = true, ["-"] = true, ["*"] = true,
    ["/"] = true, ["%"] = true, ["^"] = true, ["and"] = true, ["or"] = true, ["not"] = true }

function Scanner.scan(source: string, path: string, limit: number?)
    local tokens = Lexer.tokens(source)
    local findings, blocks, conditionalDepths = {}, {}, {}
    local pendingLoop, pendingHot = false, false
    local maxFindings = limit or 50
    local function value(index) return if tokens[index] then tokens[index].value else "" end
    local function active(kind)
        for _, block in blocks do if block == kind then return true end end
        return false
    end
    local function emit(rule, token, severity, title, explanation, recommendation)
        if #findings >= maxFindings then return end
        table.insert(findings, {rule = rule, path = path, line = token.line,
            severity = severity, confidence = "medium", title = title,
            evidence = "Source pattern: " .. token.value .. " at line " .. token.line,
            explanation = explanation, recommendation = recommendation})
    end
    for i, token in tokens do
        local word = token.value
        if word == "for" or word == "while" then pendingLoop = true
        elseif word == "repeat" then table.insert(blocks, "loop")
        elseif word == "do" then
            table.insert(blocks, if pendingLoop then "loop" else "block")
            pendingLoop = false
        elseif word == "if" then
            -- Conditional expressions have no closing end and must not enter the block stack.
            local previous = value(i - 1)
            local expression = expressionPrefix[previous] or ((previous == "then" or previous == "else") and conditionalDepths[#blocks])
            if expression then conditionalDepths[#blocks] = true else table.insert(blocks, "block") end
        elseif word == "function" then
            table.insert(blocks, if pendingHot then "hot" else "function")
            pendingHot = false
        elseif word == "end" or word == "until" then
            conditionalDepths[#blocks] = nil
            table.remove(blocks)
        end

        if word == "Connect" and value(i - 1) == ":" and value(i + 1) == "(" then
            if active("loop") then
                emit("connection-loop", token, "warning", "Connection created inside a loop",
                    "Repeated execution may retain multiple listeners. This pattern is a lifecycle risk, not a count of live connections.",
                    "Connect once outside the loop, or retain each connection and disconnect it when its owner is destroyed.")
            end
            if frameSignals[value(i - 2)] then
                local retained = false
                for j = i - 1, 1, -1 do
                    if tokens[j].line ~= token.line then break end
                    if value(j) == "=" then retained = true; break end
                end
                if not retained then
                    emit("frame-connection", token, "info", "Review frame connection ownership",
                        "A high-frequency signal connection is not visibly retained on this line. Cleanup may exist elsewhere.",
                        "Keep the connection in its owner's cleanup scope and disconnect it on teardown; avoid expensive work every frame.")
                end
                -- Only an immediately supplied function is attributed to this callback.
                pendingHot = value(i + 2) == "function"
            end
        elseif (word == "GetDescendants" or word == "GetChildren") and value(i - 1) == ":"
            and value(i + 1) == "(" and (active("loop") or active("hot")) then
            emit("traversal-hotpath", token, "warning", "Hierarchy traversal in repeated execution",
                "Repeated hierarchy enumeration allocates tables and revisits objects. Lexical context suggests a possible hot path; measure before changing it.",
                "Cache the needed objects, update the cache with descendant events, or move this traversal out of the repeated callback.")
        elseif (word == "wait" or word == "spawn" or word == "delay") and value(i + 1) == "("
            and value(i - 1) ~= "." and value(i - 1) ~= ":" and value(i - 1) ~= "function" then
            emit("legacy-scheduler", token, "info", "Legacy scheduling API",
                "This looks like a legacy global scheduler call. Locally shadowed names can produce a false positive.",
                "Use task." .. word .. " and verify timing behavior. For recurring work, choose an explicit interval that fits the workload.")
        end
    end
    return findings
end

return Scanner
