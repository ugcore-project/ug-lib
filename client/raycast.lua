--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Line-of-sight shape tests. Results are asynchronous, so every test MUST run in a thread.
---@class UgLib.Raycast
local Raycast = {}
UgLib.Raycast = Raycast

local Utils = UgLib.Internal.Utils
local Cache = UgLib.Cache

-- Everything: world, vehicles, peds, ragdolls, objects, pickups, glass, rivers, foliage.
local ALL_FLAGS = 511
local DEFAULT_DISTANCE = 10.0
local RESULT_TIMEOUT = 1000
local STATUS_PENDING = 1
local OPTIONS = {
    flags = true,
    ignore = true,
}

---@class UgRaycastResult
---@field hit boolean
---@field coords vector3? where the ray hit
---@field normal vector3? surface normal at the hit
---@field entity integer? the entity hit, nil for the world
---@field material integer? material hash

---@param name string
---@param from vector3
---@param to vector3
---@param options table
---@return UgRaycastResult
local function cast(name, from, to, options)
    local _, isMain = coroutine.running()

    if isMain then
        Utils.Raise(3, '%s MUST run in a thread', name)
    end

    local flags = options.flags or ALL_FLAGS

    if math.type(flags) ~= 'integer' then
        Utils.Raise(3, '%s: flags MUST be an integer', name)
    end

    local handle = StartShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, flags, options.ignore or 0, 7)
    local deadline = GetGameTimer() + RESULT_TIMEOUT

    while true do
        local status, hit, coords, normal, material, entity = GetShapeTestResultIncludingMaterial(handle)

        if status ~= STATUS_PENDING then
            if status ~= 2 or hit ~= 1 and hit ~= true then
                return {
                    hit = false,
                }
            end

            return {
                hit = true,
                coords = coords,
                normal = normal,
                material = material,
                entity = entity ~= 0 and entity or nil,
            }
        end

        if GetGameTimer() >= deadline then
            return {
                hit = false,
            }
        end

        Wait(0)
    end
end

---@param name string
---@param options any
---@return table
local function checkOptions(name, options)
    return options and Utils.CheckOptions(name, options, OPTIONS) or {}
end

---@param from vector3
---@param to vector3
---@param options? { flags?: integer, ignore?: integer }
---@return UgRaycastResult
function Raycast.FromCoords(from, to, options)
    if type(from) ~= 'vector3' or type(to) ~= 'vector3' then
        Utils.Raise(2, 'Raycast.FromCoords expects two vector3')
    end

    options = checkOptions('Raycast.FromCoords', options)

    local result = cast('Raycast.FromCoords', from, to, options)

    return result
end

---Casts from the gameplay camera along its direction. Ignores the local player by default.
---@param distance? number defaults to 10
---@param options? { flags?: integer, ignore?: integer }
---@return UgRaycastResult
function Raycast.FromCamera(distance, options)
    distance = distance or DEFAULT_DISTANCE

    if type(distance) ~= 'number' or distance <= 0 then
        Utils.Raise(2, 'Raycast.FromCamera: distance MUST be a positive number')
    end

    options = checkOptions('Raycast.FromCamera', options)

    if options.ignore == nil then
        options = {
            flags = options.flags,
            ignore = Cache.Ped,
        }
    end

    local from = GetGameplayCamCoord()
    local direction = UgLib.Math.RotationToDirection(GetGameplayCamRot(2))
    local to = vector3(from.x + direction.x * distance, from.y + direction.y * distance, from.z + direction.z * distance)
    local result = cast('Raycast.FromCamera', from, to, options)

    return result
end
