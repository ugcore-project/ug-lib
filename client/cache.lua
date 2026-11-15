--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---The local player, read once for every resource. ug-lib's runtime polls and emits `Cache.Changed`.
---Every runtime, ug-lib included, keeps its values from those events. `Coords` and `Heading` change every
---frame, so they are read from natives on access and have no events.
---@class UgLib.Cache
---@field Ped integer
---@field PlayerId integer
---@field ServerId integer
---@field Vehicle integer|false
---@field Seat integer|false -1 for the driver
---@field Weapon integer|false hash of the selected weapon, false when unarmed
---@field Coords vector3
---@field Heading number
local Cache = {}
UgLib.Cache = Cache

local Utils = UgLib.Internal.Utils
local Keys = UgLib.Enums.CacheKey
local CHANGED = UgLib.Enums.Events.Cache.Changed

local LIB = 'ug-lib'
local IS_OWNER = GetCurrentResourceName() == LIB
local DEFAULT_INTERVAL = 100
local UNARMED = GetHashKey('WEAPON_UNARMED')

-- Discrete keys, polled and replicated. Field names on Cache match the enum key names.
local POLLED = { Keys.Ped, Keys.PlayerId, Keys.ServerId, Keys.Vehicle, Keys.Seat, Keys.Weapon }
local LIVE = {
    [Keys.Coords] = true,
    [Keys.Heading] = true,
}

---@type table<string, boolean>
local IS_POLLED = {}

for _, key in ipairs(POLLED) do
    IS_POLLED[key] = true
end

---@type table<string, any>
local values = {}

---@type table<integer, { key: UgCacheKey, handler: fun(value: any, oldValue: any) }>
local subscribers = {}

local nextId = 0

---@param ped integer
---@param vehicle integer
---@return integer|false
local function seatOf(ped, vehicle)
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if GetPedInVehicleSeat(vehicle, seat) == ped then
            return seat
        end
    end

    return false
end

---@return table<string, any>
local function snapshot()
    local ped = PlayerPedId()
    local playerId = PlayerId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local weapon = GetSelectedPedWeapon(ped)

    return {
        [Keys.Ped] = ped,
        [Keys.PlayerId] = playerId,
        [Keys.ServerId] = GetPlayerServerId(playerId),
        [Keys.Vehicle] = vehicle ~= 0 and vehicle or false,
        [Keys.Seat] = vehicle ~= 0 and seatOf(ped, vehicle) or false,
        [Keys.Weapon] = weapon ~= UNARMED and weapon ~= 0 and weapon or false,
    }
end

---@param key UgCacheKey
---@return any
local function read(key)
    if key == Keys.Coords then
        return GetEntityCoords(values[Keys.Ped])
    end

    if key == Keys.Heading then
        return GetEntityHeading(values[Keys.Ped])
    end

    return values[key]
end

-- `Cache.Ped` reads the `Ped` key: field names are the enum key names.
setmetatable(Cache, {
    __index = function(_, field)
        local key = Keys[field]

        if key then
            return read(key)
        end

        return nil
    end,
})

---@param key UgCacheKey
---@return any
function Cache.Get(key)
    Utils.CheckEnum('Cache.Get', 'key', key, Keys)

    return read(key)
end

---Calls `handler(value, oldValue)` when `key` changes. Coords and heading have no events: read them instead.
---@param key UgCacheKey
---@param handler fun(value: any, oldValue: any)
---@return integer id for `Cache.Off`
function Cache.On(key, handler)
    Utils.CheckEnum('Cache.On', 'key', key, Keys)

    if LIVE[key] then
        Utils.Raise(2, 'Cache.On: %s changes every frame and has no events. Read UgLib.Cache.Get(%q) instead.', key, key)
    end

    if type(handler) ~= 'function' then
        Utils.Raise(2, 'Cache.On expects a function, got %s', type(handler))
    end

    nextId = nextId + 1
    subscribers[nextId] = {
        key = key,
        handler = handler,
    }

    return nextId
end

---@param id integer
---@return boolean removed
function Cache.Off(id)
    if subscribers[id] == nil then
        return false
    end

    subscribers[id] = nil

    return true
end

---@param key UgCacheKey
---@param value any
local function apply(key, value)
    local old = values[key]

    if old == value then
        return
    end

    values[key] = value

    for _, subscriber in pairs(subscribers) do
        if subscriber.key == key then
            local ok, err = pcall(subscriber.handler, value, old)

            if not ok then
                UgLib.Internal.Logger.Error('Cache.On handler for %s failed: %s', key, tostring(err))
            end
        end
    end
end

values = snapshot()

AddEventHandler(CHANGED, function(key, value)
    if GetInvokingResource() ~= LIB or not IS_POLLED[key] then
        return
    end

    apply(key, value)
end)

if IS_OWNER then
    CreateThread(function()
        local last = snapshot()

        while true do
            Wait(UgLib.Internal.Config.Get('settings', 'cacheInterval') or DEFAULT_INTERVAL)

            local current = snapshot()

            for _, key in ipairs(POLLED) do
                if current[key] ~= last[key] then
                    TriggerEvent(CHANGED, key, current[key], last[key])
                end
            end

            last = current
        end
    end)
end
