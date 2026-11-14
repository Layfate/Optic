--!strict
-- Lightweight lexical masking, not a Luau parser. Offsets and newlines survive masking.
local Lexer = {}

local function longOpen(source: string, index: number): (number?, number?)
    if string.byte(source, index) ~= 91 then return nil, nil end
    local cursor = index + 1
    while string.byte(source, cursor) == 61 do cursor += 1 end
    if string.byte(source, cursor) == 91 then return cursor - index - 1, cursor - index + 1 end
    return nil, nil
end

local function skipLong(source: string, index: number): number?
    local level, width = longOpen(source, index)
    if level == nil or not width then return nil end
    local _, finish = string.find(source, "]" .. string.rep("=", level) .. "]", index + width, true)
    return if finish then finish + 1 else #source + 1
end

local skipQuoted
skipQuoted = function(source: string, index: number, depth: number): number
    if depth > 64 then return #source + 1 end
    local quote, cursor = string.sub(source, index, index), index + 1
    while cursor <= #source do
        local ch = string.sub(source, cursor, cursor)
        if ch == "\\" then cursor += 2
        elseif ch == quote then return cursor + 1
        elseif quote == "`" and ch == "{" then
            local braces = 1
            cursor += 1
            while cursor <= #source and braces > 0 do
                local inner = string.sub(source, cursor, cursor)
                if string.sub(source, cursor, cursor + 1) == "--" then
                    cursor = skipLong(source, cursor + 2) or (string.find(source, "\n", cursor, true) or (#source + 1))
                elseif inner == '"' or inner == "'" or inner == "`" then cursor = skipQuoted(source, cursor, depth + 1)
                elseif inner == "[" then cursor = skipLong(source, cursor) or (cursor + 1)
                elseif inner == "{" then braces += 1; cursor += 1
                elseif inner == "}" then braces -= 1; cursor += 1
                else cursor += 1 end
            end
        else cursor += 1 end
    end
    return #source + 1
end

function Lexer.mask(source: string): string
    local pieces = {}
    local index, size = 1, #source
    local function blank(first: number, last: number)
        table.insert(pieces, (string.gsub(string.sub(source, first, last), "[^\n]", " ")))
    end
    while index <= size do
        local ch = string.sub(source, index, index)
        local comment = string.sub(source, index, index + 1) == "--"
        local start = if comment then index + 2 else index
        local longEnd = skipLong(source, start)
        if longEnd then
            blank(index, longEnd - 1)
            index = longEnd
        elseif comment then
            local finish = (string.find(source, "\n", index, true) or (size + 1)) - 1
            blank(index, finish)
            index = finish + 1
        elseif ch == '"' or ch == "'" or ch == "`" then
            -- Mask whole interpolations, including expressions and nested literals.
            local finish = skipQuoted(source, index, 0)
            blank(index, math.min(size, finish - 1))
            index = finish
        else
            table.insert(pieces, ch)
            index += 1
        end
    end
    return table.concat(pieces)
end

function Lexer.tokens(source: string)
    local masked = Lexer.mask(source)
    local tokens = {}
    local index, line = 1, 1
    while index <= #masked do
        local ch = string.sub(masked, index, index)
        if ch == "\n" then line += 1; index += 1
        elseif string.match(ch, "%s") then index += 1
        elseif string.match(ch, "[%a_]") then
            local finish = index + 1
            while finish <= #masked and string.match(string.sub(masked, finish, finish), "[%w_]") do finish += 1 end
            local value = string.sub(masked, index, finish - 1)
            table.insert(tokens, {value = value, line = line})
            index += #value
        else
            table.insert(tokens, {value = ch, line = line})
            index += 1
        end
    end
    return tokens
end

return Lexer
