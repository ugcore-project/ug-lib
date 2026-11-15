--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

H.LoadManifest('server')

local Table = UgLib.Table

H.Test('DeepCopy copies nested tables and keeps cycles', function()
    local source = {
        a = {
            b = 1,
        },
        list = { 1, 2 },
    }
    source.self = source

    local copy = Table.DeepCopy(source)

    H.Assert(copy ~= source and copy.a ~= source.a)
    H.Equal(copy.a.b, 1)
    H.Assert(copy.self == copy)
    H.Equal(Table.DeepCopy(5), 5)
end)

H.Test('Merge deep merges maps and replaces arrays', function()
    local base = {
        a = 1,
        nested = {
            x = 1,
            y = 2,
        },
        list = { 1, 2, 3 },
    }
    local override = {
        b = 2,
        nested = {
            y = 20,
        },
        list = { 9 },
    }
    local merged = Table.Merge(base, override)

    H.Equal(merged, {
        a = 1,
        b = 2,
        nested = {
            x = 1,
            y = 20,
        },
        list = { 9 },
    })
    H.Equal(base.nested.y, 2)
    H.Assert(merged.nested ~= override.nested)

    H.Raises(function()
        Table.Merge(H.Any(nil), {})
    end, 'Table.Merge expects a table, got nil')
end)

H.Test('Count, Contains, Keys and Values', function()
    local map = {
        a = 1,
        b = 2,
        [1] = 'x',
    }

    H.Equal(Table.Count(map), 3)
    H.Equal(Table.Contains(map, 2), true)
    H.Equal(Table.Contains(map, 3), false)

    local keys = Table.Keys({
        a = true,
        b = true,
    })
    table.sort(keys)

    H.Equal(keys, { 'a', 'b' })
    H.Equal(Table.Values({ 'x', 'y', 'z' }), { 'x', 'y', 'z' })
    H.Equal(#Table.Values({
        a = 1,
        b = 2,
    }), 2)
end)

H.Test('Map keeps keys, Filter keeps order', function()
    H.Equal(Table.Map({
        a = 1,
        b = 2,
    }, function(value)
        return value * 10
    end), {
        a = 10,
        b = 20,
    })

    H.Equal(Table.Filter({ 1, 2, 3, 4 }, function(value)
        return value % 2 == 0
    end), { 2, 4 })

    H.Raises(function()
        Table.Map({}, H.Any('nope'))
    end, 'Table.Map expects a function, got string')
end)

H.Test('Find searches arrays in order, then other keys', function()
    local value, key = Table.Find({ 5, 6, 7 }, function(entry)
        return entry > 5
    end)

    H.Equal({ value, key }, { 6, 2 })

    value, key = Table.Find({
        name = 'a',
    }, function(entry)
        return entry == 'a'
    end)

    H.Equal({ value, key }, { 'a', 'name' })

    value, key = Table.Find({ 1 }, function()
        return false
    end)

    H.Equal({ value, key }, {})
end)

H.Test('Equals compares deeply', function()
    H.Equal(Table.Equals({
        a = { 1, 2 },
    }, {
        a = { 1, 2 },
    }), true)
    H.Equal(Table.Equals({
        a = { 1, 2 },
    }, {
        a = { 1, 3 },
    }), false)
    H.Equal(Table.Equals({
        a = 1,
    }, {
        a = 1,
        b = 2,
    }), false)
    H.Equal(Table.Equals(1, 1), true)
    H.Equal(Table.Equals({}, 1), false)
end)

H.Test('Freeze is read-only, nested included', function()
    local source = {
        name = 'x',
        nested = {
            value = 1,
        },
        list = { 1, 2, 3 },
    }
    local frozen = Table.Freeze(source)

    H.Equal(frozen.name, 'x')
    H.Equal(frozen.nested.value, 1)
    H.Equal(#frozen.list, 3)

    H.Raises(function()
        frozen.name = 'y'
    end, 'Table.Freeze: cannot set "name" on a frozen table')

    H.Raises(function()
        frozen.nested.value = 2
    end, 'cannot set "value"')

    local seen = {}

    for key, value in pairs(frozen) do
        seen[key] = type(value)
    end

    H.Equal(seen, {
        name = 'string',
        nested = 'table',
        list = 'table',
    })

    local sum = 0

    for _, value in ipairs(frozen.list) do
        sum = sum + value
    end

    H.Equal(sum, 6)
    H.Assert(Table.Freeze(source) == frozen, 'a table freezes to the same proxy')
    H.Equal(getmetatable(frozen), false)

    source.name = 'changed'
    H.Equal(frozen.name, 'changed')
end)

H.Done()
