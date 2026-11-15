--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@class UgLib.Table
local Table = {}
UgLib.Table = Table

local Utils = UgLib.Internal.Utils

---@param name string
---@param value any
local function checkTable(name, value)
    if type(value) ~= 'table' then
        Utils.Raise(3, '%s expects a table, got %s', name, type(value))
    end
end

---@param name string
---@param value any
local function checkFunction(name, value)
    if type(value) ~= 'function' then
        Utils.Raise(3, '%s expects a function, got %s', name, type(value))
    end
end

---@param value any
---@param seen table<table, table>
---@return any
local function deepCopy(value, seen)
    if type(value) ~= 'table' then
        return value
    end

    local existing = seen[value]

    if existing then
        return existing
    end

    local copy = {}
    seen[value] = copy

    for key, entry in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(entry, seen)
    end

    return copy
end

---Metatables are not copied. Cycles and shared references keep their shape in the copy.
---@generic T
---@param value T
---@return T
function Table.DeepCopy(value)
    return deepCopy(value, {})
end

---@param value table
---@return boolean
local function isArray(value)
    return value[1] ~= nil
end

---@param base table
---@param override table
---@return table
local function merge(base, override)
    local result = deepCopy(base, {})

    for key, value in pairs(override) do
        local current = result[key]

        if type(value) == 'table' and type(current) == 'table' and not isArray(value) and not isArray(current) then
            result[key] = merge(current, value)
        else
            result[key] = deepCopy(value, {})
        end
    end

    return result
end

---Deep merge into a new table. Neither argument changes. Arrays from `override` replace arrays in `base`.
---@param base table
---@param override table
---@return table
function Table.Merge(base, override)
    checkTable('Table.Merge', base)
    checkTable('Table.Merge', override)

    return merge(base, override)
end

---Counts every key, not only the array part.
---@param tbl table
---@return integer
function Table.Count(tbl)
    checkTable('Table.Count', tbl)

    local count = 0

    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

---@param tbl table
---@param value any
---@return boolean
function Table.Contains(tbl, value)
    checkTable('Table.Contains', tbl)

    for _, entry in pairs(tbl) do
        if entry == value then
            return true
        end
    end

    return false
end

---Order is not defined.
---@param tbl table
---@return any[]
function Table.Keys(tbl)
    checkTable('Table.Keys', tbl)

    local keys = {}

    for key in pairs(tbl) do
        keys[#keys + 1] = key
    end

    return keys
end

---Order is not defined for maps. Arrays keep their order.
---@param tbl table
---@return any[]
function Table.Values(tbl)
    checkTable('Table.Values', tbl)

    if isArray(tbl) then
        return table.move(tbl, 1, #tbl, 1, {})
    end

    local values = {}

    for _, value in pairs(tbl) do
        values[#values + 1] = value
    end

    return values
end

---Calls `fn(value, key)` for every entry and returns a new table with the same keys.
---@param tbl table
---@param fn fun(value: any, key: any): any
---@return table
function Table.Map(tbl, fn)
    checkTable('Table.Map', tbl)
    checkFunction('Table.Map', fn)

    local result = {}

    for key, value in pairs(tbl) do
        result[key] = fn(value, key)
    end

    return result
end

---Keeps the entries of an array for which `fn(value, index)` is truthy, in order.
---@param array any[]
---@param fn fun(value: any, index: integer): any
---@return any[]
function Table.Filter(array, fn)
    checkTable('Table.Filter', array)
    checkFunction('Table.Filter', fn)

    local result = {}

    for index, value in ipairs(array) do
        if fn(value, index) then
            result[#result + 1] = value
        end
    end

    return result
end

---First entry for which `fn(value, key)` is truthy. Arrays are searched in order.
---@param tbl table
---@param fn fun(value: any, key: any): any
---@return any value
---@return any key
function Table.Find(tbl, fn)
    checkTable('Table.Find', tbl)
    checkFunction('Table.Find', fn)

    local length = #tbl

    for index = 1, length do
        if fn(tbl[index], index) then
            return tbl[index], index
        end
    end

    for key, value in pairs(tbl) do
        local inArray = math.type(key) == 'integer' and key >= 1 and key <= length

        if not inArray and fn(value, key) then
            return value, key
        end
    end

    return nil, nil
end

---@param a any
---@param b any
---@param seen table<table, table>
---@return boolean
local function equals(a, b, seen)
    if a == b then
        return true
    end

    if type(a) ~= 'table' or type(b) ~= 'table' then
        return false
    end

    if seen[a] == b then
        return true
    end

    seen[a] = b

    for key, value in pairs(a) do
        if not equals(value, b[key], seen) then
            return false
        end
    end

    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end

---Deep equality. Metatables are ignored.
---@param a any
---@param b any
---@return boolean
function Table.Equals(a, b)
    return equals(a, b, {})
end

---@type table<table, table>
local frozen = setmetatable({}, {
    __mode = 'k',
})

---@param tbl table
---@return table
local function freeze(tbl)
    local existing = frozen[tbl]

    if existing then
        return existing
    end

    local proxy = setmetatable({}, {
        __index = function(_, key)
            local value = tbl[key]

            return type(value) == 'table' and freeze(value) or value
        end,
        __newindex = function(_, key)
            Utils.Raise(2, 'Table.Freeze: cannot set "%s" on a frozen table', tostring(key))
        end,
        __len = function()
            return #tbl
        end,
        __pairs = function()
            return function(_, key)
                local nextKey, value = next(tbl, key)

                if type(value) == 'table' then
                    value = freeze(value)
                end

                return nextKey, value
            end, nil, nil
        end,
        __metatable = false,
    })

    frozen[tbl] = proxy

    return proxy
end

---Read-only view of `tbl`, nested tables included. Writes raise. Changes to `tbl` show through.
---`ipairs` and `#` work. `rawget` and `next` see an empty table.
---@generic T: table
---@param tbl T
---@return T
function Table.Freeze(tbl)
    checkTable('Table.Freeze', tbl)

    return freeze(tbl)
end
