--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@class UgLib.Internal.Utils
local Utils = {}
UgLib.Internal.Utils = Utils

local ERROR_PREFIX = '[ug-lib] '

---Raises a programmer error. `level` works like in `error`, counted from the function that calls Raise.
---Extra arguments are formatted into `message` with `string.format`.
---@param level integer
---@param message string
---@param ... any
function Utils.Raise(level, message, ...)
    if select('#', ...) > 0 then
        message = message:format(...)
    end

    error(ERROR_PREFIX .. message, level + 1)
end

---@param set table<string, any>
---@return string[]
local function sortedKeys(set)
    local keys = {}

    for key in pairs(set) do
        keys[#keys + 1] = key
    end

    table.sort(keys)

    return keys
end

---@param input string
---@param candidates string[]
---@return string
local function suggestion(input, candidates)
    local best = UgLib.String.Suggest(input, candidates)

    return best and (' Did you mean "%s"?'):format(best) or ''
end

---Checks an options table against the allowed keys. Raises at the caller of the public function,
---so it MUST be called directly from that function.
---@param name string API name for messages, such as `Dialog.Confirm`
---@param options any
---@param allowed table<string, true>
---@return table options
function Utils.CheckOptions(name, options, allowed)
    if type(options) ~= 'table' then
        Utils.Raise(3, '%s expects an options table, got %s', name, type(options))
    end

    for key in pairs(options) do
        if type(key) ~= 'string' or not allowed[key] then
            local text = tostring(key)
            Utils.Raise(3, '%s: unknown option "%s".%s', name, text, suggestion(text, sortedKeys(allowed)))
        end
    end

    return options
end

---Checks that `value` is a value of `enum`. `nil` passes when `optional` is true.
---Raises at the caller of the public function, so it MUST be called directly from that function.
---@param name string API name for messages
---@param field string option or argument name
---@param value any
---@param enum table<string, string>
---@param optional? boolean
function Utils.CheckEnum(name, field, value, enum, optional)
    if value == nil and optional then
        return
    end

    for _, entry in pairs(enum) do
        if entry == value then
            return
        end
    end

    local values = {}

    for _, entry in pairs(enum) do
        values[#values + 1] = entry
    end

    table.sort(values)

    local hint = type(value) == 'string' and suggestion(value, values) or ''

    Utils.Raise(3, '%s: %s MUST be one of %s, got %s.%s', name, field, table.concat(values, ', '), tostring(value), hint)
end

---A theme color token or a hex color, for per-call `color` and `iconColor`.
---@alias UgLibColorValue UgColor|string

---True for a `UgLib.Enums.Color` value or a `#rrggbb` hex. Raw CSS is never accepted.
---@param value any
---@return boolean
function Utils.IsColor(value)
    if type(value) ~= 'string' then
        return false
    end

    if value:find('^#%x%x%x%x%x%x$') then
        return true
    end

    for _, entry in pairs(UgLib.Enums.Color) do
        if entry == value then
            return true
        end
    end

    return false
end
