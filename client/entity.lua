--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Searches entities around a position. `coords` defaults to the local player.
---@class UgLib.Entity
local Entity = {}
UgLib.Entity = Entity

local Utils = UgLib.Internal.Utils
local Cache = UgLib.Cache

-- Per-entity loops: natives cached as locals.
local GetGamePool = GetGamePool
local GetEntityCoords = GetEntityCoords
local IsPedAPlayer = IsPedAPlayer
local GetPlayerPed = GetPlayerPed

local PED_OPTIONS = {
    includePlayers = true,
    exclude = true,
}
local ENTITY_OPTIONS = {
    exclude = true,
}
local PLAYER_OPTIONS = {
    includeSelf = true,
}

---@class UgNearbyEntity
---@field entity integer
---@field distance number

---@class UgNearbyPlayer
---@field playerId integer
---@field serverId integer
---@field ped integer
---@field distance number

---@param name string
---@param coords any
---@param distance any
---@param required boolean
---@return vector3
local function checkArgs(name, coords, distance, required)
    if coords ~= nil and type(coords) ~= 'vector3' then
        Utils.Raise(3, '%s: coords MUST be a vector3, got %s', name, type(coords))
    end

    if (required or distance ~= nil) and (type(distance) ~= 'number' or distance <= 0) then
        Utils.Raise(3, '%s: distance MUST be a positive number', name)
    end

    return coords or Cache.Coords
end

---@param pool string
---@param origin vector3
---@param radius number
---@param skip fun(entity: integer): boolean
---@return UgNearbyEntity[]
local function scan(pool, origin, radius, skip)
    local found = {}

    for _, entity in ipairs(GetGamePool(pool)) do
        if not skip(entity) then
            local distance = #(GetEntityCoords(entity) - origin)

            if distance <= radius then
                found[#found + 1] = {
                    entity = entity,
                    distance = distance,
                }
            end
        end
    end

    table.sort(found, function(a, b)
        return a.distance < b.distance
    end)

    return found
end

---@param options table
---@return fun(entity: integer): boolean
local function pedFilter(options)
    local ped = Cache.Ped

    return function(entity)
        return entity == ped or entity == options.exclude or (not options.includePlayers and IsPedAPlayer(entity))
    end
end

---@param options table
---@return fun(entity: integer): boolean
local function entityFilter(options)
    return function(entity)
        return entity == options.exclude
    end
end

---@param found UgNearbyEntity[]
---@return integer? entity
---@return number? distance
local function first(found)
    local closest = found[1]

    if not closest then
        return nil, nil
    end

    return closest.entity, closest.distance
end

---Peds other than the local player. Player peds only with `includePlayers`.
---@param coords? vector3
---@param maxDistance? number unlimited when nil
---@param options? { includePlayers?: boolean, exclude?: integer }
---@return integer? entity
---@return number? distance
function Entity.GetClosestPed(coords, maxDistance, options)
    local origin = checkArgs('Entity.GetClosestPed', coords, maxDistance, false)
    options = options and Utils.CheckOptions('Entity.GetClosestPed', options, PED_OPTIONS) or {}

    return first(scan('CPed', origin, maxDistance or math.huge, pedFilter(options)))
end

---@param coords? vector3
---@param maxDistance? number unlimited when nil
---@param options? { exclude?: integer }
---@return integer? entity
---@return number? distance
function Entity.GetClosestVehicle(coords, maxDistance, options)
    local origin = checkArgs('Entity.GetClosestVehicle', coords, maxDistance, false)
    options = options and Utils.CheckOptions('Entity.GetClosestVehicle', options, ENTITY_OPTIONS) or {}

    return first(scan('CVehicle', origin, maxDistance or math.huge, entityFilter(options)))
end

---@param coords? vector3
---@param maxDistance? number unlimited when nil
---@param options? { exclude?: integer }
---@return integer? entity
---@return number? distance
function Entity.GetClosestObject(coords, maxDistance, options)
    local origin = checkArgs('Entity.GetClosestObject', coords, maxDistance, false)
    options = options and Utils.CheckOptions('Entity.GetClosestObject', options, ENTITY_OPTIONS) or {}

    return first(scan('CObject', origin, maxDistance or math.huge, entityFilter(options)))
end

---@param coords? vector3
---@param radius number
---@param options? { includePlayers?: boolean, exclude?: integer }
---@return UgNearbyEntity[] closest first
function Entity.GetNearbyPeds(coords, radius, options)
    local origin = checkArgs('Entity.GetNearbyPeds', coords, radius, true)
    options = options and Utils.CheckOptions('Entity.GetNearbyPeds', options, PED_OPTIONS) or {}

    return scan('CPed', origin, radius, pedFilter(options))
end

---@param coords? vector3
---@param radius number
---@param options? { exclude?: integer }
---@return UgNearbyEntity[] closest first
function Entity.GetNearbyVehicles(coords, radius, options)
    local origin = checkArgs('Entity.GetNearbyVehicles', coords, radius, true)
    options = options and Utils.CheckOptions('Entity.GetNearbyVehicles', options, ENTITY_OPTIONS) or {}

    return scan('CVehicle', origin, radius, entityFilter(options))
end

---@param coords? vector3
---@param radius number
---@param options? { exclude?: integer }
---@return UgNearbyEntity[] closest first
function Entity.GetNearbyObjects(coords, radius, options)
    local origin = checkArgs('Entity.GetNearbyObjects', coords, radius, true)
    options = options and Utils.CheckOptions('Entity.GetNearbyObjects', options, ENTITY_OPTIONS) or {}

    return scan('CObject', origin, radius, entityFilter(options))
end

---@param origin vector3
---@param radius number
---@param includeSelf boolean
---@return UgNearbyPlayer[]
local function scanPlayers(origin, radius, includeSelf)
    local found = {}
    local self = Cache.PlayerId

    for _, playerId in ipairs(GetActivePlayers()) do
        if includeSelf or playerId ~= self then
            local ped = GetPlayerPed(playerId)
            local distance = #(GetEntityCoords(ped) - origin)

            if distance <= radius then
                found[#found + 1] = {
                    playerId = playerId,
                    serverId = GetPlayerServerId(playerId),
                    ped = ped,
                    distance = distance,
                }
            end
        end
    end

    table.sort(found, function(a, b)
        return a.distance < b.distance
    end)

    return found
end

---Other players, the local one only with `includeSelf`.
---@param coords? vector3
---@param maxDistance? number unlimited when nil
---@param options? { includeSelf?: boolean }
---@return UgNearbyPlayer? player
function Entity.GetClosestPlayer(coords, maxDistance, options)
    local origin = checkArgs('Entity.GetClosestPlayer', coords, maxDistance, false)
    options = options and Utils.CheckOptions('Entity.GetClosestPlayer', options, PLAYER_OPTIONS) or {}

    return scanPlayers(origin, maxDistance or math.huge, options.includeSelf == true)[1]
end

---@param coords? vector3
---@param radius number
---@param options? { includeSelf?: boolean }
---@return UgNearbyPlayer[] closest first
function Entity.GetNearbyPlayers(coords, radius, options)
    local origin = checkArgs('Entity.GetNearbyPlayers', coords, radius, true)
    options = options and Utils.CheckOptions('Entity.GetNearbyPlayers', options, PLAYER_OPTIONS) or {}

    return scanPlayers(origin, radius, options.includeSelf == true)
end
