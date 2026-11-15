--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@class UgLib.String
local String = {}
UgLib.String = String

local Utils = UgLib.Internal.Utils

local SUGGEST_MAX_DISTANCE = 3
local DIGITS = '0123456789'
local UPPER = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
local LOWER = 'abcdefghijklmnopqrstuvwxyz'
local ALPHANUMERIC = DIGITS .. UPPER .. LOWER

---@type table<string, string>
local RANDOM_SETS = {
    ['1'] = DIGITS,
    ['A'] = UPPER,
    ['a'] = LOWER,
    ['.'] = ALPHANUMERIC,
}

---@param name string
---@param ... any
local function checkStrings(name, ...)
    for index = 1, select('#', ...) do
        if type((select(index, ...))) ~= 'string' then
            Utils.Raise(3, '%s expects strings, argument %d is %s', name, index, type((select(index, ...))))
        end
    end
end

---Removes leading and trailing whitespace.
---@param text string
---@return string
function String.Trim(text)
    checkStrings('String.Trim', text)

    return (text:match('^%s*(.-)%s*$'))
end

---Splits on a plain separator. Empty parts are kept: `Split('a,,b', ',')` returns `{ 'a', '', 'b' }`.
---@param text string
---@param separator string not empty
---@return string[]
function String.Split(text, separator)
    checkStrings('String.Split', text, separator)

    if separator == '' then
        Utils.Raise(2, 'String.Split: separator MUST NOT be empty')
    end

    local parts = {}
    local start = 1

    while true do
        local first, last = text:find(separator, start, true)

        if not first then
            parts[#parts + 1] = text:sub(start)

            return parts
        end

        parts[#parts + 1] = text:sub(start, first - 1)
        start = last + 1
    end
end

---@param text string
---@param prefix string
---@return boolean
function String.StartsWith(text, prefix)
    checkStrings('String.StartsWith', text, prefix)

    return text:sub(1, #prefix) == prefix
end

---@param text string
---@param suffix string
---@return boolean
function String.EndsWith(text, suffix)
    checkStrings('String.EndsWith', text, suffix)

    return suffix == '' or text:sub(-#suffix) == suffix
end

---Upper-cases the first letter. The rest is unchanged.
---@param text string
---@return string
function String.Capitalize(text)
    checkStrings('String.Capitalize', text)

    return (text:gsub('^%l', string.upper))
end

---Cuts `text` to at most `max` characters, `suffix` included. Counts UTF-8 characters,
---or bytes when `text` is not valid UTF-8.
---@param text string
---@param max integer at least 1
---@param suffix? string defaults to `...`
---@return string
function String.Truncate(text, max, suffix)
    suffix = suffix or '...'
    checkStrings('String.Truncate', text, suffix)

    if math.type(max) ~= 'integer' or max < 1 then
        Utils.Raise(2, 'String.Truncate: max MUST be a positive integer')
    end

    local length = utf8.len(text)
    local suffixLength = utf8.len(suffix) or #suffix

    if not length then
        if #text <= max then
            return text
        end

        return text:sub(1, math.max(max - #suffix, 0)) .. suffix
    end

    if length <= max then
        return text
    end

    local keep = math.max(max - suffixLength, 0)
    local cut = utf8.offset(text, keep + 1) or (#text + 1)

    return text:sub(1, cut - 1) .. suffix
end

---Random string from a pattern: `1` is a digit, `A` an upper-case letter, `a` a lower-case letter,
---`.` a letter or digit. Other characters are kept: `Random('AAA 111')` returns something like `QZT 042`.
---@param pattern string
---@return string
function String.Random(pattern)
    checkStrings('String.Random', pattern)

    return (pattern:gsub('[1Aa%.]', function(symbol)
        local set = RANDOM_SETS[symbol]
        local index = math.random(1, #set)

        return set:sub(index, index)
    end))
end

---Levenshtein distance in bytes. Callers SHOULD pass ASCII, such as option names.
---@param a string
---@param b string
---@return integer
function String.Distance(a, b)
    checkStrings('String.Distance', a, b)

    if a == b then
        return 0
    end

    local lengthA, lengthB = #a, #b

    if lengthA == 0 then
        return lengthB
    end

    if lengthB == 0 then
        return lengthA
    end

    local previous, current = {}, {}

    for column = 0, lengthB do
        previous[column] = column
    end

    for row = 1, lengthA do
        current[0] = row
        local byteA = a:byte(row)

        for column = 1, lengthB do
            local cost = byteA == b:byte(column) and 0 or 1
            current[column] = math.min(previous[column] + 1, current[column - 1] + 1, previous[column - 1] + cost)
        end

        previous, current = current, previous
    end

    return previous[lengthB]
end

---Returns the closest candidate within `maxDistance`, ignoring case. Ties go to the earliest candidate.
---@param input string
---@param candidates string[]
---@param maxDistance? integer defaults to 3
---@return string?
function String.Suggest(input, candidates, maxDistance)
    if type(input) ~= 'string' or type(candidates) ~= 'table' then
        Utils.Raise(2, 'String.Suggest expects a string and an array of strings')
    end

    local limit = maxDistance or SUGGEST_MAX_DISTANCE
    local lowered = input:lower()
    local best, bestDistance = nil, limit + 1

    for index = 1, #candidates do
        local candidate = candidates[index]
        local distance = String.Distance(lowered, candidate:lower())

        if distance < bestDistance then
            best, bestDistance = candidate, distance
        end
    end

    return best
end
