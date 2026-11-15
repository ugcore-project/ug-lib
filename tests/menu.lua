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

---@param name string
local function press(name)
    H.RunCommand('+ug-lib-' .. name, 0, {})
    H.RunCommand('-ug-lib-' .. name, 0, {})
end

---@return table?
local function menu()
    for _, layer in ipairs(UgLib.Internal.Layers.GetAll()) do
        if layer.kind == 'menu' then
            return layer
        end
    end

    return nil
end

---@param log string[]
---@param extra? table
local function register(log, extra)
    local definition = {
        id = 'vehicle',
        title = 'Vehicle',
        items = {
            {
                label = 'Engine',
                checked = true,
                args = 'engine',
            },
            {
                label = 'Seat',
                values = { 'Driver', 'Passenger' },
                args = 'seat',
            },
            {
                label = 'Livery',
                values = { 'Stock', 'Police', 'Taxi' },
                defaultIndex = 2,
                close = false,
                args = 'livery',
            },
            {
                label = 'Leave',
                args = 'leave',
            },
        },
        onSelect = function(index, scrollIndex, args)
            log[#log + 1] = ('select %d %s %s'):format(index, tostring(scrollIndex), tostring(args))
        end,
        onSelected = function(index)
            log[#log + 1] = 'move ' .. index
        end,
        onSideScroll = function(index, scrollIndex)
            log[#log + 1] = ('scroll %d %d'):format(index, scrollIndex)
        end,
        onCheck = function(index, checked)
            log[#log + 1] = ('check %d %s'):format(index, tostring(checked))
        end,
        onClose = function()
            log[#log + 1] = 'closed'
        end,
    }

    for key, value in pairs(extra or {}) do
        definition[key] = value
    end

    Consumer.Menu.Register(definition)
end

H.Test('A menu opens without focus, with its state', function()
    start()
    register({})
    Consumer.Menu.Open('vehicle')

    local payload = menu().payload

    H.Equal(payload.position, Enums.Position.TopLeft)
    H.Equal(payload.state, {
        selected = 1,
        scroll = { 0, 1, 2, 0 },
        checked = { true, false, false, false },
    })
    H.Equal(payload.items[4].args, nil, 'args stay in the resource')
    H.Equal(UgLib.Internal.Nui.GetFocus().focus, false)
    H.Equal(Consumer.Menu.GetOpen(), 'vehicle')
end)

H.Test('Keys move, scroll, check and select', function()
    start()

    local log = {}

    register(log)
    Consumer.Menu.Open('vehicle')

    press('menu_select')
    press('menu_down')
    press('menu_right')
    press('menu_right')
    press('menu_down')
    press('menu_left')
    press('menu_select')

    H.Equal(log, { 'check 1 false', 'move 2', 'scroll 2 2', 'scroll 2 1', 'move 3', 'scroll 3 1', 'select 3 1 livery' })
    H.Equal(menu().payload.state.checked[1], false)
    H.Equal(Consumer.Menu.GetOpen(), 'vehicle', 'close = false keeps it open')

    press('menu_down')
    press('menu_select')

    H.Equal(log[#log], 'select 4 nil leave')
    H.Equal(menu(), nil)
    H.Equal(Consumer.Menu.GetOpen(), nil)
end)

H.Test('The selection wraps around', function()
    start()

    local log = {}

    register(log)
    Consumer.Menu.Open('vehicle')
    press('menu_up')

    H.Equal(log, { 'move 4' })
end)

H.Test('Back closes unless canClose is false', function()
    start()

    local log = {}

    register(log)
    Consumer.Menu.Open('vehicle')
    press('menu_back')

    H.Equal(log, { 'closed' })

    register(log, {
        canClose = false,
    })
    Consumer.Menu.Open('vehicle')
    press('menu_back')

    H.Equal(menu() ~= nil, true)
end)

H.Test('SetItem updates an open menu and keeps the selection', function()
    start()

    local log = {}

    register(log)
    Consumer.Menu.Open('vehicle', 2)
    press('menu_right')
    Consumer.Menu.SetItem('vehicle', 4, {
        label = 'Exit',
        progress = 50,
    })

    local payload = menu().payload

    H.Equal(payload.items[4].label, 'Exit')
    H.Equal(payload.state.selected, 2)
    H.Equal(payload.state.scroll[2], 2)

    Consumer.Menu.SetItem('vehicle', 1, {
        checked = false,
    })

    H.Equal(menu().payload.state.checked[1], false)

    H.Raises(function()
        Consumer.Menu.SetItem('vehicle', 9, {
            label = 'x',
        })
    end, 'Menu.SetItem: 9 is not an item index of "vehicle"')

    H.Raises(function()
        Consumer.Menu.SetItem('vehicle', 2, {
            values = {},
        })
    end, 'item 2 values MUST be 1 to 50 labels')
end)

H.Test('One menu at a time: a new one replaces it', function()
    start()

    local log = {}

    register(log)
    Consumer.Menu.Open('vehicle')

    local other = H.ImportPrivate(H.LoadImport('my-garage', 'client')).UgLib

    other.Menu.Register({
        id = 'garage',
        title = 'Garage',
        items = {
            {
                label = 'Car',
            },
        },
    })
    other.Menu.Open('garage')

    H.Equal(log, { 'closed' })
    H.Equal(menu().owner, 'my-garage')
end)

H.Test('Keys do nothing while a dialog is open', function()
    start()

    local log = {}

    register(log)
    Consumer.Menu.Open('vehicle')
    H.Thread(function()
        Consumer.Dialog.Confirm({
            title = 'Sure?',
        })
    end)
    press('menu_down')

    H.Equal(log, {})
end)

H.Test('disableInput blocks movement', function()
    start()
    register({}, {
        disableInput = true,
    })
    Consumer.Menu.Open('vehicle')
    H.World.disabled = {}
    H.Advance(250)
    H.Advance(0)

    H.Assert((H.World.disabled[32] or 0) >= 1, 'movement is disabled')
end)

H.Test('Sounds follow settings.sounds', function()
    start('return { sounds = false }')
    register({})
    Consumer.Menu.Open('vehicle')
    press('menu_down')

    H.Equal(H.CallNames(), {})

    start()
    register({})
    Consumer.Menu.Open('vehicle')
    press('menu_down')

    H.Equal(H.World.calls[1].args, {
        -1,
        'NAV_UP_DOWN',
        'HUD_FRONTEND_DEFAULT_SOUNDSET',
        true,
        n = 4,
    })
end)

H.Test('Forged page answers', function()
    start()

    local log = {}

    register(log)
    Consumer.Menu.Open('vehicle')

    local Callbacks = UgLib.Internal.Protocol.Nui.Callbacks

    H.Equal(H.PostNui(Callbacks.Event, {
        id = menu().key,
        data = {
            action = 'select',
            index = 4,
        },
    }), {
        ok = false,
    })
    H.PostNui(Callbacks.Resolve, {
        id = menu().key,
        result = {
            index = 1,
        },
    })

    H.Equal(log, { 'closed' }, 'a checkbox cannot be selected')
end)

H.Test('Definitions are checked at the caller', function()
    start()

    H.Raises(function()
        Consumer.Menu.Register(H.Any({
            id = 'a',
            title = 'x',
            items = {
                {
                    label = 'y',
                    value = { 'a' },
                },
            },
        }))
    end, 'Menu.Register: item 1 has an unknown option "value". Did you mean "values"?')

    H.Raises(function()
        Consumer.Menu.Register(H.Any({
            id = 'a',
            title = 'x',
            items = {
                {
                    label = 'y',
                    values = { 'a' },
                    checked = true,
                },
            },
        }))
    end, 'item 1 cannot have both checked and values')

    H.Raises(function()
        Consumer.Menu.Register(H.Any({
            id = 'a',
            title = 'x',
            items = {
                {
                    label = 'y',
                    values = { 'a' },
                    defaultIndex = 3,
                },
            },
        }))
    end, 'item 1 defaultIndex MUST be an index of values')

    register({})

    H.Raises(function()
        Consumer.Menu.Open('vehicle', 9)
    end, 'Menu.Open: startIndex MUST be an item index')
end)

H.Done()
