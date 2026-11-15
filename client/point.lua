--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Proximity points: spheres that know how far the player is. `nearby` runs every frame while inside,
---closest point first, so the closest point can show its prompt.
---@class UgLib.Point
local Point = {}
UgLib.Point = Point

local Utils = UgLib.Internal.Utils
local Zones = UgLib.Internal.Zones

local OPTIONS = {
    coords = true,
    distance = true,
    onEnter = true,
    onExit = true,
    nearby = true,
    debug = true,
    data = true,
}

---@param options { coords: vector3, distance: number, onEnter?: fun(point: UgZone), onExit?: fun(point: UgZone), nearby?: fun(point: UgZone), debug?: boolean, data?: any }
---@return UgZone point with `currentDistance` from the last check
function Point.Create(options)
    Utils.CheckOptions('Point.Create', options, OPTIONS)

    if type(options.coords) ~= 'vector3' then
        Utils.Raise(2, 'Point.Create: coords MUST be a vector3, got %s', type(options.coords))
    end

    if type(options.distance) ~= 'number' or options.distance <= 0 then
        Utils.Raise(2, 'Point.Create: distance MUST be a positive number')
    end

    local point = Zones.Add('Point.Create', options, OPTIONS, {
        shape = UgLib.Enums.ZoneShape.Point,
        coords = options.coords,
        radius = options.distance,
    })

    return point
end

---@param point UgZone|integer
---@return boolean removed
function Point.Remove(point)
    return UgLib.Zone.Remove(point)
end
