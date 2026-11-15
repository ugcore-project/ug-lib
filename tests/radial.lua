--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

---@type UgLib
local Consumer = H.Any(nil)

---@type UgLib.Enums
local Enums = H.Any(nil)

---@param settings? string
local function start(settings)
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = settings or "return { debug = 'on' }"
    H.LoadManifest('server')
    H.LoadManifest('client')
    H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Ready, {})
    H.TakeNui()

    Enums = UgLib.Enums
    Consumer = H.ImportPrivate(H.LoadImport('my-shop', 'client')).UgLib
end

---@return table?
local function radial()
    return UgLib.Internal.Layers.GetModal()
end

---@param path any
local function choose(path)
    return H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Resolve, {
        id = radial().key,
        result = path,
    })
end

local function pressKey()
    H.RunCommand('+ug-lib-radial', 0, {})
    H.RunCommand('-ug-lib-radial', 0, {})
end

local TREE = {
    {
        id = 'wave',
        label = 'Wave',
        icon = 'user',
    },
    { id = 'admin', label = 'Admin', items = {
        {
            id = 'heal',
            label = 'Heal',
        },
        {
            id = 'kick',
            label = 'Kick',
            disabled = true,
        },
    } },
}

---@return TestThread
local function openTree()
    return H.Thread(function()
        return table.pack(Consumer.Radial.Open({
            title = 'Interact',
            items = TREE,
        }))
    end)
end

H.Test('A one-off radial returns the chosen leaf id', function()
    start()

    local thread = openTree()

    H.Equal(radial().payload, {
        title = 'Interact',
        items = {
            {
                label = 'Wave',
                icon = 'user',
            },
            {
                label = 'Admin',
                items = {
                    {
                        label = 'Heal',
                    },
                    {
                        label = 'Kick',
                        disabled = true,
                    },
                },
            },
        },
    })

    choose({ 2, 1 })

    H.Equal(thread.result, {
        'heal',
        nil,
        n = 2,
    })
end)

H.Test('Paths to disabled items, submenus and nowhere are rejected', function()
    start()

    for _, path in ipairs({ { 2 }, { 2, 2 }, { 3 }, { 2, 1, 1 }, {}, H.Any(1), { 1.5 }, { 1, 1, 1, 1 } }) do
        local thread = openTree()

        choose(path)
        H.Equal(thread.result, {
            nil,
            Enums.CloseReason.Cancelled,
            n = 2,
        })
    end
end)

H.Test('The global radial runs onSelect in the resource that added the item', function()
    start()

    local log = {}
    local other = H.ImportPrivate(H.LoadImport('my-garage', 'client')).UgLib

    Consumer.Radial.AddItem({ id = 'shop', label = 'Shop', icon = Enums.Icon.Star, onSelect = function(id)
        log[#log + 1] = 'shop ' .. id
    end })

    other.Radial.AddItem({ id = 'garage', label = 'Garage', items = {
        { id = 'park', label = 'Park', onSelect = function(id)
            log[#log + 1] = 'garage ' .. id
        end },
    } })

    pressKey()

    H.Equal(#radial().payload.items, 2)
    H.Equal(radial().payload.items[1].id, nil, 'ids stay in Lua')

    choose({ 2, 1 })

    H.Equal(log, { 'garage park' })

    pressKey()
    choose({ 1 })

    H.Equal(log, { 'garage park', 'shop shop' })
end)

H.Test('The key toggles, and forged events from other resources are ignored', function()
    start()

    local log = {}

    Consumer.Radial.AddItem({ id = 'shop', label = 'Shop', onSelect = function()
        log[#log + 1] = 'shop'
    end })

    pressKey()
    H.Equal(radial() ~= nil, true)
    pressKey()
    H.Equal(radial(), nil)

    H.TriggerEvent(UgLib.Internal.Protocol.RadialEvent:format('my-shop'), 'evil-resource', 'shop')

    H.Equal(log, {})
end)

H.Test('Replace, remove, clear and resource stop', function()
    start()

    Consumer.Radial.AddItem({
        id = 'a',
        label = 'A',
        onSelect = function() end,
    })
    Consumer.Radial.AddItem({
        id = 'b',
        label = 'B',
        onSelect = function() end,
    })
    Consumer.Radial.AddItem({
        id = 'a',
        label = 'A2',
        onSelect = function() end,
    })

    H.Equal(UgLib.Internal.Radial.Count(), 2)

    H.Equal(Consumer.Radial.RemoveItem('a'), true)
    H.Equal(Consumer.Radial.RemoveItem('a'), false)
    H.Equal(UgLib.Internal.Radial.Count(), 1)

    Consumer.Radial.ClearItems()
    H.Equal(UgLib.Internal.Radial.Count(), 0)

    Consumer.Radial.AddItem({
        id = 'c',
        label = 'C',
        onSelect = function() end,
    })
    H.TriggerEvent('onResourceStop', nil, 'my-shop')
    H.Equal(UgLib.Internal.Radial.Count(), 0)
end)

H.Test('SetEnabled blocks the key while any resource blocks it', function()
    start()

    local other = H.ImportPrivate(H.LoadImport('my-garage', 'client')).UgLib

    Consumer.Radial.AddItem({
        id = 'a',
        label = 'A',
        onSelect = function() end,
    })
    Consumer.Radial.SetEnabled(false)
    other.Radial.SetEnabled(false)
    pressKey()
    H.Equal(radial(), nil)

    Consumer.Radial.SetEnabled(true)
    pressKey()
    H.Equal(radial(), nil, 'my-garage still blocks it')

    H.TriggerEvent('onResourceStop', nil, 'my-garage')
    pressKey()
    H.Equal(radial() ~= nil, true)
end)

H.Test('An empty radial key disables the global radial', function()
    start("return { radialKey = '' }")

    H.Raises(function()
        H.RunCommand('+ug-lib-radial', 0, {})
    end, 'command "+ug-lib-radial" is not registered')
end)

H.Test('Definitions are checked at the caller', function()
    start()

    local function raw(fn)
        return H.Thread(fn)
    end

    local cases = {
        {
            function() Consumer.Radial.Open({ items = { { id = 'a', label = 'A', onSelect = function() end } } }) end,
            'item "a" of a one-off radial MUST NOT have onSelect',
        },
        {
            function() Consumer.Radial.Open({ items = { { id = 'a', label = 'A' }, { id = 'a', label = 'B' } } }) end,
            'item id "a" is used twice',
        },
        {
            function() Consumer.Radial.Open({ items = { { id = 'a', label = 'A', icn = 'x' } } }) end,
            'unknown option "icn". Did you mean "icon"?',
        },
        {
            function() Consumer.Radial.Open({ items = { { id = 'a', label = 'A', items = { { id = 'b', label = 'B', items = { { id = 'c', label = 'C', items = { { id = 'd', label = 'D' } } } } } } } } }) end,
            'submenus MUST NOT be deeper than 3 levels',
        },
    }

    for _, case in ipairs(cases) do
        local thread = raw(case[1])

        H.Assert(thread.error and thread.error:find(case[2], 1, true), ('expected "%s", got %s'):format(case[2], tostring(thread.error)))
    end

    H.Raises(function()
        Consumer.Radial.AddItem({
            id = 'a',
            label = 'A',
        })
    end, 'Radial.AddItem: item "a" MUST have an onSelect function')

    H.Raises(function()
        Consumer.Radial.AddItem({
            id = 'a',
            label = 'A',
            items = {
                {
                    id = 'b',
                    label = 'B',
                    onSelect = function() end,
                },
            },
            onSelect = function() end,
        })
    end, 'item "a" has a submenu and onSelect')

    Consumer.Radial.AddItem({
        id = 'a',
        label = 'A',
        onSelect = function() end,
    })

    H.Raises(function()
        Consumer.Radial.AddItem({
            id = 'b',
            label = 'B',
            items = {
                {
                    id = 'a',
                    label = 'A',
                    onSelect = function() end,
                },
            },
        })
    end, 'item id "a" is used twice')

    local line = debug.getinfo(1, 'l').currentline + 2
    local message = H.Raises(function()
        Consumer.Radial.AddItem({
            id = 'x y',
            label = 'A',
            onSelect = function() end,
        })
    end, 'item 1 id MUST be 1 to 64 letters')

    H.Assert(message:find('tests/radial.lua:' .. line .. ':', 1, true) ~= nil, message)
end)

H.Done()
