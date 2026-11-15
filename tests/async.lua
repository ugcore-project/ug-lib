--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

H.LoadManifest('server')

local Async = UgLib.Async

H.Test('WaitFor returns the value once check passes', function()
    local ready = nil
    local thread = H.Thread(function()
        return table.pack(Async.WaitFor(function()
            return ready
        end, 1000))
    end)

    H.Equal(thread.done, false)
    H.Advance(0)
    ready = 'loaded'
    H.Advance(0)

    H.Equal(thread.done, true)
    H.Equal(thread.result, {
        true,
        'loaded',
        n = 2,
    })
end)

H.Test('WaitFor times out', function()
    local thread = H.Thread(function()
        return table.pack(Async.WaitFor(function()
            return false
        end, 100, 50))
    end)

    H.Advance(50)
    H.Advance(50)

    H.Equal(thread.result, {
        false,
        nil,
        n = 2,
    })
end)

H.Test('WaitFor MUST run in a thread', function()
    H.Raises(function()
        Async.WaitFor(function()
            return true
        end)
    end, 'Async.WaitFor MUST run in a thread')

    H.Raises(function()
        Async.WaitFor(H.Any(nil))
    end, 'Async.WaitFor expects a function, got nil')

    H.Raises(function()
        Async.WaitFor(function() end, -1)
    end, 'timeout MUST be a non-negative integer in ms')
end)

H.Test('Timeout runs once and can be cancelled', function()
    local ran = 0

    Async.Timeout(100, function()
        ran = ran + 1
    end)

    local cancel = Async.Timeout(100, function()
        ran = ran + 10
    end)

    cancel()
    H.Advance(100)
    H.Advance(100)

    H.Equal(ran, 1)
end)

H.Test('Debounce runs once with the last arguments', function()
    local calls = {}
    local debounced = Async.Debounce(function(value)
        calls[#calls + 1] = value
    end, 100)

    debounced('a')
    H.Advance(50)
    debounced('b')
    H.Advance(60)

    H.Equal(calls, {})

    H.Advance(40)

    H.Equal(calls, { 'b' })
end)

H.Test('Throttle drops calls inside the window', function()
    local calls = 0
    local throttled = Async.Throttle(function()
        calls = calls + 1

        return calls
    end, 100)

    H.Equal(throttled(), 1)
    H.Equal(throttled(), nil)
    H.Advance(100)
    H.Equal(throttled(), 2)
    H.Equal(calls, 2)
end)

H.Done()
