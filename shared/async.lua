--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@class UgLib.Async
local Async = {}
UgLib.Async = Async

local Utils = UgLib.Internal.Utils

local DEFAULT_TIMEOUT = 5000

---@param name string
---@param value any
local function checkFunction(name, value)
    if type(value) ~= 'function' then
        Utils.Raise(3, '%s expects a function, got %s', name, type(value))
    end
end

---@param name string
---@param value any
---@param field string
local function checkMs(name, value, field)
    if math.type(value) ~= 'integer' or value < 0 then
        Utils.Raise(3, '%s: %s MUST be a non-negative integer in ms', name, field)
    end
end

---Calls `check` every `interval` ms until it returns a truthy value. MUST run in a thread.
---@generic T
---@param check fun(): T?
---@param timeout? integer ms, defaults to 5000
---@param interval? integer ms between checks, defaults to 0 (every frame)
---@return boolean ok false on timeout
---@return T? value what `check` returned
function Async.WaitFor(check, timeout, interval)
    checkFunction('Async.WaitFor', check)
    timeout = timeout or DEFAULT_TIMEOUT
    interval = interval or 0
    checkMs('Async.WaitFor', timeout, 'timeout')
    checkMs('Async.WaitFor', interval, 'interval')

    local _, isMain = coroutine.running()

    if isMain then
        Utils.Raise(2, 'Async.WaitFor MUST run in a thread')
    end

    local deadline = GetGameTimer() + timeout

    while true do
        local value = check()

        if value then
            return true, value
        end

        if GetGameTimer() >= deadline then
            return false, nil
        end

        Wait(interval)
    end
end

---Runs `fn` after `ms`. Returns a function that cancels it.
---@param ms integer
---@param fn fun()
---@return fun() cancel
function Async.Timeout(ms, fn)
    checkMs('Async.Timeout', ms, 'ms')
    checkFunction('Async.Timeout', fn)

    local cancelled = false

    SetTimeout(ms, function()
        if not cancelled then
            fn()
        end
    end)

    return function()
        cancelled = true
    end
end

---Returns a function that runs `fn` once calls stop for `ms`, with the arguments of the last call.
---@param fn fun(...: any)
---@param ms integer
---@return fun(...: any)
function Async.Debounce(fn, ms)
    checkFunction('Async.Debounce', fn)
    checkMs('Async.Debounce', ms, 'ms')

    local generation = 0

    return function(...)
        generation = generation + 1

        local mine = generation
        local args = table.pack(...)

        SetTimeout(ms, function()
            if mine == generation then
                fn(table.unpack(args, 1, args.n))
            end
        end)
    end
end

---Returns a function that runs `fn` at most once per `ms`. Calls in between are dropped.
---The first call runs right away.
---@param fn fun(...: any): ...
---@param ms integer
---@return fun(...: any): ...
function Async.Throttle(fn, ms)
    checkFunction('Async.Throttle', fn)
    checkMs('Async.Throttle', ms, 'ms')

    local last = nil

    return function(...)
        local now = GetGameTimer()

        if last and now - last < ms then
            return
        end

        last = now

        return fn(...)
    end
end
