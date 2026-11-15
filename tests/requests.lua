--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

local CONSUMER = 'my-shop'

---@type UgLib.Internal.Layers
local Layers = H.Any(nil)

---@type UgLib.Internal.Requests
local Requests = H.Any(nil)

---@type UgLib.Enums
local Enums = H.Any(nil)

-- A test layer type: the answer is the index of an item, and the owner receives that item's label.
---@param payload table
---@param result any
---@return boolean ok
---@return any value
local function pickItem(payload, result)
    local item = math.type(result) == 'integer' and payload.items[result]

    if not item or item.disabled then
        return false, nil
    end

    return true, item.label
end

local function start()
    H.Reset()
    H.LoadManifest('client')

    Layers = UgLib.Internal.Layers
    Enums = UgLib.Enums
    Layers.RegisterType('test', {
        modal = true,
        validate = pickItem,
        validateEvent = pickItem,
    })
    Layers.RegisterType('toast', {
        modal = false,
    })

    local env = H.LoadImport(CONSUMER, 'client')

    Requests = H.ImportPrivate(env).UgLib.Internal.Requests
end

local PAYLOAD = {
    items = {
        {
            label = 'Water',
        },
        {
            label = 'Bread',
            disabled = true,
        },
    },
}

-- Stands in for a public function such as UgLib.Dialog.Confirm, which calls Requests.Await directly.
---@param options? table
---@return any result
---@return UgCloseReason? reason
local function publicOpen(options)
    local result, reason = Requests.Await('Test.Open', 'test', PAYLOAD, options)

    return result, reason
end

---@param options? table
---@return TestThread
local function ask(options)
    return H.Thread(function()
        return table.pack(Requests.Await('Test.Open', 'test', PAYLOAD, options))
    end)
end

H.Test('A request waits in the consumer and gets the validated value', function()
    start()

    local thread = ask()

    H.Equal(thread.done, false)
    H.Equal(Layers.Get(CONSUMER, '1').kind, 'test')

    Layers.Resolve(CONSUMER, '1', 1)

    H.Equal(thread.result, {
        'Water',
        nil,
        n = 2,
    })
    H.Equal(Layers.Get(CONSUMER, '1'), nil)
    H.Equal(Requests.CountPending(), 0)
end)

H.Test('Forged answers resolve as Cancelled', function()
    start()

    local disabled = ask()
    Layers.Resolve(CONSUMER, '1', 2)

    H.Equal(disabled.result, {
        nil,
        Enums.CloseReason.Cancelled,
        n = 2,
    })

    local outOfRange = ask()
    Layers.Resolve(CONSUMER, '2', 99)

    H.Equal(outOfRange.result, {
        nil,
        Enums.CloseReason.Cancelled,
        n = 2,
    })

    local wrongType = ask()
    Layers.Resolve(CONSUMER, '3', {
        value = 'Gold',
    })

    H.Equal(wrongType.result, {
        nil,
        Enums.CloseReason.Cancelled,
        n = 2,
    })
end)

H.Test('Answers only come from ug-lib, for pending ids', function()
    start()

    local thread = ask()
    local event = UgLib.Internal.Protocol.ResponseEvent:format(CONSUMER)

    H.TriggerEvent(event, 'evil-resource', '1', 'Gold', nil, true)
    H.TriggerEvent(event, nil, '1', 'Gold', nil, true)
    H.TriggerEvent(event, 'ug-lib', '42', 'Gold', nil, true)

    H.Equal(thread.done, false)

    Layers.Resolve(CONSUMER, '1', 1)

    H.Equal(thread.result[1], 'Water')
    H.Equal(Layers.Resolve(CONSUMER, '1', 1), false, 'a second answer is dropped')
end)

H.Test('Another resource cannot answer or close a layer it does not own', function()
    start()

    local thread = ask()
    local evil = H.LoadImport('evil-resource', 'client')

    H.Equal(evil.exports['ug-lib']:UiClose('1'), false)
    H.Equal(thread.done, false)
    H.Equal(Layers.Get(CONSUMER, '1') ~= nil, true)
end)

H.Test('A request MUST run in a thread', function()
    start()

    local line = debug.getinfo(1, 'l').currentline + 2
    local message = H.Raises(function()
        publicOpen()
    end, 'UgLib.Test.Open MUST run in a thread.')

    H.Assert(message:find('tests/requests.lua:' .. line .. ':', 1, true) ~= nil, message)
    H.Equal(Requests.CountPending(), 0)
end)

H.Test('The consumer owns the timeout', function()
    start()

    local thread = ask({
        timeout = 1000,
    })

    H.Advance(999)
    H.Equal(thread.done, false)
    H.Advance(1)

    H.Equal(thread.result, {
        nil,
        Enums.CloseReason.Timeout,
        n = 2,
    })
    H.Equal(Layers.Get(CONSUMER, '1'), nil, 'ug-lib closes the layer')
    H.Equal(Layers.Resolve(CONSUMER, '1', 1), false, 'late answers are ignored')

    local line = debug.getinfo(1, 'l').currentline + 2
    local invalid = H.Thread(function()
        publicOpen({
            timeout = -1,
        })
    end)

    H.Assert(invalid.error and invalid.error:find('timeout MUST be an integer from 0 to 3600000 ms', 1, true), invalid.error)
    H.Assert(invalid.error:find('tests/requests.lua:' .. line .. ':', 1, true), invalid.error)
end)

H.Test('One modal at a time, unless replace is set', function()
    start()

    local first = ask()
    local second = ask()

    H.Equal(second.result, {
        nil,
        Enums.CloseReason.Busy,
        n = 2,
    })
    H.Equal(first.done, false)

    local third = ask({
        replace = true,
    })

    H.Equal(first.result, {
        nil,
        Enums.CloseReason.Replaced,
        n = 2,
    })
    H.Equal(Layers.GetModal().id, '3')

    Layers.Resolve(CONSUMER, '3', 1)

    H.Equal(third.result[1], 'Water')
    H.Equal(Layers.GetModal(), nil)
end)

H.Test('Non-modal layers do not block modals', function()
    start()

    H.Equal(Requests.Send('toast', {
        text = 'hi',
    }), '1')

    local thread = ask()

    H.Equal(thread.done, false)
    H.Equal(#Layers.GetAll(), 2)
end)

H.Test('Started requests answer through callbacks', function()
    start()

    local events, closed = {}, nil
    local id = Requests.Start('test', PAYLOAD, {
        onEvent = function(data)
            events[#events + 1] = data
        end,
        onClose = function(result, reason)
            closed = { result, reason }
        end,
    })

    H.Equal(id, '1')
    H.Equal(Layers.Event(CONSUMER, '1', 1), true)
    H.Equal(Layers.Event(CONSUMER, '1', 2), false, 'invalid events are dropped')
    H.Equal(events, { 'Water' })

    H.Equal(Requests.Close('1'), true)
    H.Equal(closed, { nil, Enums.CloseReason.Closed })
end)

H.Test('Updates reach the open layer only', function()
    start()

    ask()

    H.Equal(Requests.Update('1', {
        items = {
            {
                label = 'Juice',
            },
        },
    }), true)

    Layers.Resolve(CONSUMER, '1', 1)

    H.Equal(Requests.Update('1', {}), false)
end)

H.Test('A stopped consumer loses its layers silently', function()
    start()

    ask()
    H.TriggerEvent('onResourceStop', nil, CONSUMER)

    H.Equal(Layers.Get(CONSUMER, '1'), nil)
    H.Equal(Layers.GetModal(), nil)
end)

H.Test('Stopping ug-lib resolves pending requests as Closed', function()
    start()

    local thread = ask()

    H.TriggerEvent('onResourceStop', nil, 'ug-lib')

    H.Equal(thread.result, {
        nil,
        Enums.CloseReason.Closed,
        n = 2,
    })
    H.Equal(Requests.CountPending(), 0)
end)

H.Test('Modals emit Ui.Opened and Ui.Closed', function()
    start()

    local seen = {}

    AddEventHandler(Enums.Events.Ui.Opened, function(kind, owner)
        seen[#seen + 1] = 'opened ' .. kind .. ' ' .. owner
    end)

    AddEventHandler(Enums.Events.Ui.Closed, function(kind, owner)
        seen[#seen + 1] = 'closed ' .. kind .. ' ' .. owner
    end)

    ask()
    Layers.Resolve(CONSUMER, '1', 1)

    H.Equal(seen, { 'opened test my-shop', 'closed test my-shop' })
end)

H.Test('Layers.Open checks its arguments', function()
    start()

    H.Raises(function()
        Layers.Open(CONSUMER, ('x'):rep(33), 'test', {})
    end, 'id MUST be a string of 1 to 32 bytes')

    H.Raises(function()
        Layers.Open(CONSUMER, 'a', 'nope', {})
    end, 'unknown layer type "nope"')

    Layers.Open(CONSUMER, 'a', 'toast', {})

    H.Raises(function()
        Layers.Open(CONSUMER, 'a', 'toast', {})
    end, 'my-shop already has an open layer with id "a"')
end)

H.Done()
