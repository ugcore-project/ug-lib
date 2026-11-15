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

local function start()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { debug = 'on' }"
    H.LoadManifest('server')
    H.LoadManifest('client')
    H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Ready, {})
    H.TakeNui()

    Enums = UgLib.Enums
    Consumer = H.ImportPrivate(H.LoadImport('my-shop', 'client')).UgLib
end

---@return table
local function open()
    return UgLib.Internal.Layers.GetModal() or error('no context open', 2)
end

---@param result any
local function choose(result)
    return H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Resolve, {
        id = open().key,
        result = result,
    })
end

---@param log string[]
local function registerShop(log)
    Consumer.Context.Register({
        id = 'shop',
        title = 'Shop',
        items = {
            { title = 'Water', description = '**$5**', icon = Enums.Icon.Star, args = {
                item = 'water',
            }, onSelect = function(args)
                log[#log + 1] = 'water ' .. args.item
            end },
            { title = 'Sold out', disabled = true, onSelect = function()
                log[#log + 1] = 'sold out'
            end },
            {
                title = 'Info',
                readOnly = true,
                metadata = {
                    {
                        label = 'Owner',
                        value = 'Bob',
                    },
                    {
                        label = 'Stock',
                        value = 12,
                    },
                },
            },
            {
                title = 'Admin',
                menu = 'admin',
            },
        },
        onClose = function()
            log[#log + 1] = 'closed'
        end,
    })

    Consumer.Context.Register({
        id = 'admin',
        title = 'Admin',
        menu = 'shop',
        items = { { title = 'Restock', onSelect = function()
            log[#log + 1] = 'restock'
        end } },
        onBack = function()
            log[#log + 1] = 'back'
        end,
    })
end

H.Test('The page only receives what it shows', function()
    start()
    registerShop({})
    Consumer.Context.Open('shop')

    local payload = open().payload

    H.Equal(payload.title, 'Shop')
    H.Equal(payload.canBack, false)
    H.Equal(payload.canClose, true)
    H.Equal(payload.items[1], {
        title = 'Water',
        description = '**$5**',
        icon = Enums.Icon.Star,
        arrow = false,
        submenu = false,
    })
    H.Equal(payload.items[4].submenu, true)
    H.Equal(payload.items[4].arrow, true)
    H.Equal(Consumer.Context.GetOpen(), 'shop')
    H.Equal(UgLib.Internal.Nui.GetFocus().cursor, true)
end)

H.Test('Choosing runs onSelect in the resource with its args', function()
    start()

    local log = {}

    registerShop(log)
    Consumer.Context.Open('shop')
    choose(1)

    H.Equal(log, { 'water water' })
    H.Equal(Consumer.Context.GetOpen(), nil)
end)

H.Test('Submenus and the back button', function()
    start()

    local log = {}

    registerShop(log)
    Consumer.Context.Open('shop')
    choose(4)

    H.Equal(Consumer.Context.GetOpen(), 'admin')
    H.Equal(open().payload.canBack, true)

    choose(0)

    H.Equal(log, { 'back' })
    H.Equal(Consumer.Context.GetOpen(), 'shop')

    choose(4)
    choose(1)

    H.Equal(log, { 'back', 'restock' })
end)

H.Test('Disabled, read-only, out of range and back without a parent are rejected', function()
    start()

    local log = {}

    registerShop(log)

    for _, forged in ipairs({ 2, 3, 99, 0, H.Any('1'), 1.5 }) do
        Consumer.Context.Open('shop')
        choose(forged)
    end

    H.Equal(log, { 'closed', 'closed', 'closed', 'closed', 'closed', 'closed' }, 'each forged answer only closes it')
end)

H.Test('Escape closes and runs onClose', function()
    start()

    local log = {}

    registerShop(log)
    Consumer.Context.Open('shop')
    H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Close, {
        id = open().key,
    })

    H.Equal(log, { 'closed' })
end)

H.Test('Inline contexts wait and return the choice', function()
    start()

    local thread = H.Thread(function()
        return table.pack(Consumer.Context.Open({
            title = 'Pick',
            items = {
                {
                    title = 'A',
                    args = 'a',
                },
                {
                    title = 'B',
                    args = 'b',
                },
            },
        }))
    end)

    H.Equal(Consumer.Context.GetOpen(), '')
    choose(2)

    H.Equal(thread.result, {
        2,
        'b',
        nil,
        n = 3,
    })

    local closed = H.Thread(function()
        return table.pack(Consumer.Context.Open({
            title = 'Pick',
            items = {
                {
                    title = 'A',
                },
            },
        }))
    end)

    H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Close, {
        id = open().key,
    })

    H.Equal(closed.result, {
        nil,
        nil,
        Enums.CloseReason.Cancelled,
        n = 3,
    })
end)

H.Test('Opening again replaces the own context, but not another resource modal', function()
    start()
    registerShop({})
    Consumer.Context.Open('shop')
    Consumer.Context.Open('admin')

    H.Equal(Consumer.Context.GetOpen(), 'admin')

    Consumer.Context.Close()

    local other = H.ImportPrivate(H.LoadImport('my-bank', 'client')).UgLib

    H.Thread(function()
        other.Dialog.Confirm({
            title = 'Pay?',
        })
    end)

    Consumer.Context.Open('shop')

    H.Equal(Consumer.Context.GetOpen(), nil, 'Busy: another resource has a modal')
end)

H.Test('Definitions are checked at the caller', function()
    start()

    H.Raises(function()
        Consumer.Context.Register(H.Any({
            id = 'a b',
            title = 'x',
            items = {
                {
                    title = 'y',
                },
            },
        }))
    end, 'Context.Register: id MUST be')

    H.Raises(function()
        Consumer.Context.Register(H.Any({
            id = 'a',
            title = 'x',
            items = {
                {
                    title = 'y',
                    onSelected = function() end,
                },
            },
        }))
    end, 'Context.Register: item 1 has an unknown option "onSelected". Did you mean "onSelect"?')

    H.Raises(function()
        Consumer.Context.Register(H.Any({
            id = 'a',
            title = 'x',
            items = {
                {
                    title = 'y',
                    image = 'http://evil',
                },
            },
        }))
    end, 'item 1 image MUST be a nui:// or https:// URL')

    H.Raises(function()
        Consumer.Context.Register(H.Any({
            id = 'a',
            title = 'x',
            items = {
                {
                    title = 'y',
                    progress = 120,
                },
            },
        }))
    end, 'item 1 progress MUST be a number from 0 to 100')

    H.Raises(function()
        Consumer.Context.Open('nope')
    end, 'Context.Open: "nope" is not registered')

    H.Raises(function()
        Consumer.Context.Open({
            title = 'x',
            items = {
                {
                    title = 'y',
                    onSelect = function() end,
                },
            },
        })
    end, 'item 1 of an inline context MUST NOT have onSelect or menu')
end)

H.Done()
