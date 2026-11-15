--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Consumer side of UI requests. Waiting happens here, never inside an export: ug-lib shows the layer,
---then answers with a local event to this resource. Items, `args` and callbacks never leave this runtime.
---@class UgLib.Internal.Requests
local Requests = {}
UgLib.Internal.Requests = Requests

local Utils = UgLib.Internal.Utils
local Protocol = UgLib.Internal.Protocol
local CloseReason = UgLib.Enums.CloseReason

local LIB = 'ug-lib'
local RESOURCE = GetCurrentResourceName()
local DEFAULT_TIMEOUT = 60000
local MAX_TIMEOUT = 3600000

---@class UgLibPendingRequest
---@field promise? table resolved with `{ result, reason }` by a final answer
---@field onEvent? fun(data: any) non-final events
---@field onClose? fun(result: any, reason: UgCloseReason?) final answer of a non-blocking request
---@field cancelTimer? fun()

---@type table<string, UgLibPendingRequest>
local pending = {}

local counter = 0

---@return string
local function nextId()
    counter = counter + 1

    return tostring(counter)
end

---@param id string
---@param kind string
---@param payload table
---@param replace boolean
---@return boolean ok
---@return UgCloseReason? reason
local function open(id, kind, payload, replace)
    return exports[LIB][Protocol.Exports.Open](exports[LIB], id, kind, payload, {
        replace = replace,
    })
end

---@param timeout any
---@return integer
local function checkTimeout(timeout)
    if timeout == nil then
        return DEFAULT_TIMEOUT
    end

    if math.type(timeout) ~= 'integer' or timeout < 0 or timeout > MAX_TIMEOUT then
        Utils.Raise(4, 'timeout MUST be an integer from 0 to %d ms, 0 waits forever', MAX_TIMEOUT)
    end

    return timeout
end

---Opens a layer and waits for its answer. MUST be called directly from a public function, in a thread,
---and never as a tail call (`local result, reason = Requests.Await(...)`), so errors point to the caller's line.
---@param name string public function name for errors, such as `Dialog.Confirm`
---@param kind string layer type
---@param payload table rebuilt from known fields, never the caller's table
---@param options? { timeout?: integer, replace?: boolean, onOpen?: fun(id: string) } `onOpen` gets the layer id once open, to close it early
---@return any result nil when closed without an answer
---@return UgCloseReason? reason
function Requests.Await(name, kind, payload, options)
    local _, isMain = coroutine.running()

    if isMain then
        Utils.Raise(3, 'UgLib.%s MUST run in a thread.', name)
    end

    options = options or {}

    local timeout = checkTimeout(options.timeout)
    local id = nextId()
    local entry = {
        promise = promise.new(),
    }

    pending[id] = entry

    local ok, reason = open(id, kind, payload, options.replace == true)

    if not ok then
        pending[id] = nil

        return nil, reason
    end

    if options.onOpen then
        options.onOpen(id)
    end

    if timeout > 0 then
        entry.cancelTimer = UgLib.Async.Timeout(timeout, function()
            if pending[id] == entry then
                pending[id] = nil
                exports[LIB][Protocol.Exports.Close](exports[LIB], id, CloseReason.Timeout)
                entry.promise:resolve({ nil, CloseReason.Timeout })
            end
        end)
    end

    local answer = Citizen.Await(entry.promise)

    return answer[1], answer[2]
end

---Opens a layer that answers through callbacks, such as a registered menu. Returns at once.
---@param kind string
---@param payload table
---@param handlers { onEvent?: fun(data: any), onClose?: fun(result: any, reason: UgCloseReason?) }
---@param options? { replace?: boolean }
---@return string? id nil when the layer could not open
---@return UgCloseReason? reason
function Requests.Start(kind, payload, handlers, options)
    local id = nextId()

    pending[id] = {
        onEvent = handlers.onEvent,
        onClose = handlers.onClose,
    }

    local ok, reason = open(id, kind, payload, options ~= nil and options.replace == true)

    if not ok then
        pending[id] = nil

        return nil, reason
    end

    return id, nil
end

---Shows a layer that never answers, such as a notification.
---@param kind string
---@param payload table
---@return string? id
---@return UgCloseReason? reason
function Requests.Send(kind, payload)
    local id = nextId()
    local ok, reason = open(id, kind, payload, false)

    return ok and id or nil, reason
end

---@param id string
---@param payload table
---@return boolean ok false when the layer is closed
function Requests.Update(id, payload)
    return exports[LIB][Protocol.Exports.Update](exports[LIB], id, payload)
end

---Closes a layer. A pending request resolves with `Closed`.
---@param id string
---@return boolean ok false when the layer was already closed
function Requests.Close(id)
    return exports[LIB][Protocol.Exports.Close](exports[LIB], id, CloseReason.Closed)
end

---@return integer
function Requests.CountPending()
    local count = 0

    for _ in pairs(pending) do
        count = count + 1
    end

    return count
end

---@param entry UgLibPendingRequest
---@param result any
---@param reason UgCloseReason?
local function finish(entry, result, reason)
    if entry.cancelTimer then
        entry.cancelTimer()
    end

    if entry.promise then
        entry.promise:resolve({ result, reason })
    elseif entry.onClose then
        entry.onClose(result, reason)
    end
end

AddEventHandler(Protocol.ResponseEvent:format(RESOURCE), function(id, result, reason, final)
    if GetInvokingResource() ~= LIB then
        return
    end

    local entry = pending[id]

    if not entry then
        return
    end

    if not final then
        if entry.onEvent then
            entry.onEvent(result)
        end

        return
    end

    pending[id] = nil
    finish(entry, result, reason)
end)

-- Answers cannot arrive once ug-lib stops.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= LIB then
        return
    end

    local waiting = pending
    pending = {}

    for _, entry in pairs(waiting) do
        finish(entry, nil, CloseReason.Closed)
    end
end)
