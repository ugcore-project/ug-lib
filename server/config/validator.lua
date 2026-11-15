--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Checks config definitions, owner values and convars. Messages go to server logs only.
---@class UgLib.Internal.Config.Validator
local Validator = {}
UgLib.Internal.Config.Validator = Validator

local NAME_PATTERN = '^[a-z][%w]*$'
local SHORT_STRING = 32
local CUSTOM_FAILURE = 'failed custom validation'

local ARTICLES = {
    string = 'a string',
    number = 'a number',
    integer = 'an integer',
    boolean = 'a boolean',
    table = 'a table',
}

local CONVAR_BOOLEANS = {
    ['true'] = true,
    ['1'] = true,
    ['false'] = false,
    ['0'] = false,
}

local OPTION_FIELDS = { 'key', 'type', 'default', 'description', 'values', 'aliases', 'min', 'max', 'validate' }

---Short description for logs. Long strings are described by size.
---@param value any
---@return string
function Validator.Describe(value)
    local valueType = type(value)

    if valueType == 'string' then
        if #value <= SHORT_STRING then
            return ('%q'):format(value)
        end

        return ('a string of %d bytes'):format(#value)
    end

    if valueType == 'number' or valueType == 'boolean' or valueType == 'nil' then
        return tostring(value)
    end

    return 'a ' .. valueType
end

---`ug-lib:<Key>` for settings, `ug-lib:<Config>:<Key>` otherwise.
---@param configName string
---@param key string
---@return string
function Validator.ConvarName(configName, key)
    local pascalKey = key:sub(1, 1):upper() .. key:sub(2)

    if configName == 'settings' then
        return 'ug-lib:' .. pascalKey
    end

    return ('ug-lib:%s:%s'):format(configName:sub(1, 1):upper() .. configName:sub(2), pascalKey)
end

---@param value number
---@return boolean
local function isFinite(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

---@param option UgLibConfigOption
---@param value any
---@return number size
---@return string unit
local function measure(option, value)
    if option.type == 'string' then
        return utf8.len(value) or #value, ' characters'
    end

    if option.type == 'table' then
        return UgLib.Table.Count(value), ' entries'
    end

    return value, ''
end

---Checks a value against an option. Tables are returned as deep copies, integral floats as integers.
---@param option UgLibConfigOption
---@param value any
---@return boolean ok
---@return any value
---@return string? message
function Validator.CheckValue(option, value)
    if option.aliases and value ~= nil and option.aliases[value] ~= nil then
        value = option.aliases[value]
    end

    local expected = option.type
    local valueType = type(value)

    if expected == 'integer' or expected == 'number' then
        if valueType ~= 'number' then
            return false, nil, ('MUST be %s, got %s'):format(ARTICLES[expected], Validator.Describe(value))
        end

        if not isFinite(value) then
            return false, nil, 'MUST be a finite number'
        end

        if expected == 'integer' then
            local converted = math.tointeger(value)

            if not converted then
                return false, nil, ('MUST be an integer, got %s'):format(Validator.Describe(value))
            end

            value = converted
        end
    elseif valueType ~= expected then
        return false, nil, ('MUST be %s, got %s'):format(ARTICLES[expected], Validator.Describe(value))
    end

    if option.values then
        local allowed = false

        for index = 1, #option.values do
            if option.values[index] == value then
                allowed = true
                break
            end
        end

        if not allowed then
            local names = {}

            for index = 1, #option.values do
                names[index] = Validator.Describe(option.values[index])
            end

            return false, nil, ('MUST be one of %s, got %s'):format(table.concat(names, ', '), Validator.Describe(value))
        end
    end

    if option.min or option.max then
        local size, unit = measure(option, value)

        if option.min and size < option.min then
            return false, nil, ('MUST be at least %s%s, got %s'):format(option.min, unit, size)
        end

        if option.max and size > option.max then
            return false, nil, ('MUST be at most %s%s, got %s'):format(option.max, unit, size)
        end
    end

    if expected == 'table' then
        value = UgLib.Table.DeepCopy(value)
    end

    if option.validate then
        local called, passed, message = pcall(option.validate, value)

        if not called then
            return false, nil, CUSTOM_FAILURE .. ': ' .. tostring(passed)
        end

        if passed ~= true then
            return false, nil, type(message) == 'string' and message or CUSTOM_FAILURE
        end
    end

    return true, value, nil
end

---Convars are strings. Booleans take `true`, `false`, `1` or `0`. Tables cannot be set by convar.
---@param option UgLibConfigOption
---@param raw string
---@return boolean ok
---@return any value
---@return string? message
function Validator.ParseConvar(option, raw)
    local expected = option.type
    local value

    if expected == 'boolean' then
        value = CONVAR_BOOLEANS[raw]

        if value == nil then
            return false, nil, ('MUST be true, false, 1 or 0, got %s'):format(Validator.Describe(raw))
        end
    elseif expected == 'integer' or expected == 'number' then
        value = tonumber(raw)

        if value == nil then
            return false, nil, ('MUST be %s, got %s'):format(ARTICLES[expected], Validator.Describe(raw))
        end
    elseif expected == 'string' then
        value = raw
    else
        return false, nil, ('cannot be set by convar, type %s is not supported'):format(expected)
    end

    return Validator.CheckValue(option, value)
end

---@param option table
---@param label string
---@return string? problem
local function checkFields(option, label)
    for key in pairs(option) do
        local known = false

        for index = 1, #OPTION_FIELDS do
            if OPTION_FIELDS[index] == key then
                known = true
                break
            end
        end

        if not known then
            local name = tostring(key)
            local suggestion = type(key) == 'string' and UgLib.String.Suggest(name, OPTION_FIELDS) or nil
            local hint = suggestion and (' Did you mean "%s"?'):format(suggestion) or ''

            return ('%s has an unknown field "%s".%s'):format(label, name, hint)
        end
    end

    return nil
end

---@param option any
---@param index integer
---@param seen table<string, boolean>
---@return string? problem
local function checkOption(option, index, seen)
    if type(option) ~= 'table' then
        return ('option %d MUST be a table'):format(index)
    end

    local key = option.key

    if type(key) ~= 'string' or not key:find(NAME_PATTERN) then
        return ('option %d key MUST be camelCase'):format(index)
    end

    local label = ('option "%s"'):format(key)
    local problem = checkFields(option, label)

    if problem then
        return problem
    end

    if seen[key] then
        return ('%s is declared twice'):format(label)
    end

    seen[key] = true

    if not ARTICLES[option.type] then
        return ('%s type MUST be one of string, number, integer, boolean, table'):format(label)
    end

    if type(option.description) ~= 'string' or option.description == '' then
        return ('%s MUST have a description'):format(label)
    end

    if option.values ~= nil and (type(option.values) ~= 'table' or #option.values == 0) then
        return ('%s values MUST be a non-empty array'):format(label)
    end

    for _, bound in ipairs({ 'min', 'max' }) do
        local limit = option[bound]

        if limit ~= nil and (type(limit) ~= 'number' or not isFinite(limit)) then
            return ('%s %s MUST be a finite number'):format(label, bound)
        end
    end

    if option.aliases ~= nil then
        if type(option.aliases) ~= 'table' then
            return ('%s aliases MUST be a table'):format(label)
        end

        for alias, target in pairs(option.aliases) do
            local ok, _, message = Validator.CheckValue(option, target)

            if not ok then
                return ('%s alias %s: %s'):format(label, Validator.Describe(alias), message)
            end
        end
    end

    if option.validate ~= nil and type(option.validate) ~= 'function' then
        return ('%s validate MUST be a function'):format(label)
    end

    if option.default == nil then
        return ('%s MUST have a default'):format(label)
    end

    local ok, _, message = Validator.CheckValue(option, option.default)

    if not ok then
        return ('%s default fails its own validation: %s'):format(label, message)
    end

    return nil
end

---@param name any
---@param definition any
---@return string? problem first problem found, nil when valid
function Validator.CheckDefinition(name, definition)
    if type(name) ~= 'string' or not name:find(NAME_PATTERN) then
        return 'config names MUST be camelCase'
    end

    if type(definition) ~= 'table' or type(definition.options) ~= 'table' then
        return 'options MUST be an array'
    end

    for key in pairs(definition) do
        if key ~= 'options' then
            return ('definition has an unknown field "%s"'):format(tostring(key))
        end
    end

    local seen = {}

    for index = 1, #definition.options do
        local problem = checkOption(definition.options[index], index, seen)

        if problem then
            return problem
        end
    end

    return nil
end
