--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Spheres, boxes and polygons that call back when the local player enters or leaves.
---One thread per runtime checks every `settings.zoneInterval` ms, and every frame only while a zone
---with `inside`, a point with `nearby`, or a debug zone needs it.
---@class UgLib.Zone
local Zone = {}
UgLib.Zone = Zone

---@class UgLib.Internal.Zones
local Zones = {}
UgLib.Internal.Zones = Zones

local Utils = UgLib.Internal.Utils
local Logger = UgLib.Internal.Logger
local Shape = UgLib.Enums.ZoneShape

-- Checked every frame in fast mode: natives cached as locals.
local GetEntityCoords = GetEntityCoords
local DrawLine = DrawLine

local DEFAULT_INTERVAL = 250
local MAX_POINTS = 256
local COMMON_OPTIONS = {
    onEnter = true,
    onExit = true,
    inside = true,
    debug = true,
    data = true,
}
local DEBUG_COLOR = { 139, 92, 246, 200 }

---@class UgZone
---@field id integer
---@field shape UgZoneShape
---@field data any
---@field isInside boolean
---@field enabled boolean
---@field coords? vector3 sphere and box center, point position
---@field radius? number
---@field size? vector3
---@field heading? number
---@field points? vector2[]
---@field minZ? number
---@field maxZ? number
---@field currentDistance? number points only, from the last check
---@field onEnter? fun(zone: UgZone)
---@field onExit? fun(zone: UgZone)
---@field inside? fun(zone: UgZone) every frame while inside
---@field nearby? fun(zone: UgZone) points only, every frame while inside
---@field debug? boolean
---@field cos? number
---@field sin? number
local ZoneObject = {}
ZoneObject.__index = ZoneObject

---@type table<integer, UgZone>
local zones = {}

local nextId = 0
local running = false

---@param zone UgZone
---@param coords vector3
---@return boolean
local function contains(zone, coords)
    local shape = zone.shape

    if shape == Shape.Sphere or shape == Shape.Point then
        local distance = #(coords - zone.coords)

        zone.currentDistance = distance

        return distance <= zone.radius
    end

    if zone.minZ and coords.z < zone.minZ or zone.maxZ and coords.z > zone.maxZ then
        return false
    end

    if shape == Shape.Box then
        local dx, dy = coords.x - zone.coords.x, coords.y - zone.coords.y
        local x = dx * zone.cos + dy * zone.sin
        local y = -dx * zone.sin + dy * zone.cos

        return math.abs(x) <= zone.size.x / 2 and math.abs(y) <= zone.size.y / 2
    end

    return UgLib.Math.PointInPolygon(coords, zone.points)
end

---@param zone UgZone
---@param name string
local function call(zone, name)
    local callback = zone[name]

    if callback then
        local ok, err = pcall(callback, zone)

        if not ok then
            Logger.Error('Zone %d %s failed: %s', zone.id, name, tostring(err))
        end
    end
end

---@param zone UgZone
---@param inside boolean
local function setInside(zone, inside)
    if zone.isInside == inside then
        return
    end

    zone.isInside = inside
    call(zone, inside and 'onEnter' or 'onExit')
end

---@param a vector3
---@param b vector3
local function line(a, b)
    DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, DEBUG_COLOR[1], DEBUG_COLOR[2], DEBUG_COLOR[3], DEBUG_COLOR[4])
end

---@param corners vector2[]
---@param minZ number
---@param maxZ number
local function drawPrism(corners, minZ, maxZ)
    for index = 1, #corners do
        local a, b = corners[index], corners[index % #corners + 1]

        line(vector3(a.x, a.y, minZ), vector3(b.x, b.y, minZ))
        line(vector3(a.x, a.y, maxZ), vector3(b.x, b.y, maxZ))
        line(vector3(a.x, a.y, minZ), vector3(a.x, a.y, maxZ))
    end
end

---@param zone UgZone
---@param coords vector3
local function drawDebug(zone, coords)
    if zone.shape == Shape.Sphere or zone.shape == Shape.Point then
        local diameter = zone.radius * 2

        UgLib.Draw.Marker(28, zone.coords, {
            size = vector3(diameter, diameter, diameter),
            color = DEBUG_COLOR,
        })

        return
    end

    local minZ = zone.minZ or coords.z - 2.0
    local maxZ = zone.maxZ or coords.z + 2.0

    if zone.shape == Shape.Box then
        local halfX, halfY = zone.size.x / 2, zone.size.y / 2
        local corners = {}

        for index, sign in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local x, y = sign[1] * halfX, sign[2] * halfY

            corners[index] = vector2(zone.coords.x + x * zone.cos - y * zone.sin, zone.coords.y + x * zone.sin + y * zone.cos)
        end

        drawPrism(corners, minZ, maxZ)

        return
    end

    drawPrism(zone.points, minZ, maxZ)
end

---Runs every check. Returns true when the next check MUST run on the next frame.
---@return boolean fast
local function tick()
    local coords = GetEntityCoords(UgLib.Cache.Ped)
    local fast = false
    local nearby = {}

    for _, zone in pairs(zones) do
        if zone.enabled then
            setInside(zone, contains(zone, coords))

            if zone.isInside and (zone.inside or zone.nearby) then
                fast = true

                if zone.inside then
                    call(zone, 'inside')
                end

                if zone.nearby then
                    nearby[#nearby + 1] = zone
                end
            end

            if zone.debug then
                fast = true
                drawDebug(zone, coords)
            end
        end
    end

    table.sort(nearby, function(a, b)
        return a.currentDistance < b.currentDistance
    end)

    for _, point in ipairs(nearby) do
        call(point, 'nearby')
    end

    return fast
end

local function ensureThread()
    if running then
        return
    end

    running = true

    CreateThread(function()
        while next(zones) do
            local fast = tick()

            Wait(fast and 0 or (UgLib.Internal.Config.Get('settings', 'zoneInterval') or DEFAULT_INTERVAL))
        end

        running = false
    end)
end

---@param name string
---@param options table
---@param allowed table<string, true>
local function checkCommon(name, options, allowed)
    for _, key in ipairs({ 'onEnter', 'onExit', 'inside', 'nearby' }) do
        if allowed[key] and options[key] ~= nil and type(options[key]) ~= 'function' then
            Utils.Raise(4, '%s: %s MUST be a function', name, key)
        end
    end
end

---Adds a checked zone. MUST be called directly from the public function.
---@param name string
---@param options table
---@param allowed table<string, true>
---@param fields table shape fields
---@return UgZone
function Zones.Add(name, options, allowed, fields)
    checkCommon(name, options, allowed)

    nextId = nextId + 1

    local zone = setmetatable(fields, ZoneObject)

    zone.id = nextId
    zone.data = options.data
    zone.isInside = false
    zone.enabled = true
    zone.onEnter = options.onEnter
    zone.onExit = options.onExit
    zone.inside = options.inside
    zone.nearby = options.nearby
    zone.debug = options.debug == true
    zones[zone.id] = zone

    ensureThread()

    return zone
end

---@param zone UgZone
local function remove(zone)
    if zones[zone.id] ~= zone then
        return
    end

    zones[zone.id] = nil
    setInside(zone, false)
end

---Removes the zone. Calls `onExit` when the player was inside.
function ZoneObject:Remove()
    remove(self)
end

---@param coords vector3
---@return boolean
function ZoneObject:Contains(coords)
    if type(coords) ~= 'vector3' then
        Utils.Raise(2, 'zone:Contains expects a vector3, got %s', type(coords))
    end

    return contains(self, coords)
end

---A disabled zone is not checked. Disabling it while the player is inside calls `onExit`.
---@param enabled boolean
function ZoneObject:SetEnabled(enabled)
    self.enabled = enabled == true

    if not self.enabled then
        setInside(self, false)
    end
end

---@param name string
---@param value any
---@param field string
local function checkVector(name, value, field)
    if type(value) ~= 'vector3' then
        Utils.Raise(3, '%s: %s MUST be a vector3, got %s', name, field, type(value))
    end
end

---@param name string
---@param value any
---@param field string
---@param optional? boolean
local function checkNumber(name, value, field, optional)
    if value == nil and optional then
        return
    end

    if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then
        Utils.Raise(3, '%s: %s MUST be a finite number', name, field)
    end
end

local SPHERE_OPTIONS = {
    coords = true,
    radius = true,
}
local BOX_OPTIONS = {
    coords = true,
    size = true,
    heading = true,
    minZ = true,
    maxZ = true,
}
local POLY_OPTIONS = {
    points = true,
    minZ = true,
    maxZ = true,
}

for _, allowed in ipairs({ SPHERE_OPTIONS, BOX_OPTIONS, POLY_OPTIONS }) do
    for key in pairs(COMMON_OPTIONS) do
        allowed[key] = true
    end
end

---@param options { coords: vector3, radius: number, onEnter?: fun(zone: UgZone), onExit?: fun(zone: UgZone), inside?: fun(zone: UgZone), debug?: boolean, data?: any }
---@return UgZone
function Zone.Sphere(options)
    Utils.CheckOptions('Zone.Sphere', options, SPHERE_OPTIONS)
    checkVector('Zone.Sphere', options.coords, 'coords')
    checkNumber('Zone.Sphere', options.radius, 'radius')

    local zone = Zones.Add('Zone.Sphere', options, SPHERE_OPTIONS, {
        shape = Shape.Sphere,
        coords = options.coords,
        radius = options.radius,
    })

    return zone
end

---A box centered on `coords`. `size.x` is the width, `size.y` the length, `size.z` the height.
---`minZ` and `maxZ` replace the height when set.
---@param options { coords: vector3, size: vector3, heading?: number, minZ?: number, maxZ?: number, onEnter?: fun(zone: UgZone), onExit?: fun(zone: UgZone), inside?: fun(zone: UgZone), debug?: boolean, data?: any }
---@return UgZone
function Zone.Box(options)
    Utils.CheckOptions('Zone.Box', options, BOX_OPTIONS)
    checkVector('Zone.Box', options.coords, 'coords')
    checkVector('Zone.Box', options.size, 'size')
    checkNumber('Zone.Box', options.heading, 'heading', true)
    checkNumber('Zone.Box', options.minZ, 'minZ', true)
    checkNumber('Zone.Box', options.maxZ, 'maxZ', true)

    local heading = math.rad(options.heading or 0.0)
    local zone = Zones.Add('Zone.Box', options, BOX_OPTIONS, {
        shape = Shape.Box,
        coords = options.coords,
        size = options.size,
        heading = options.heading or 0.0,
        cos = math.cos(heading),
        sin = math.sin(heading),
        minZ = options.minZ or options.coords.z - options.size.z / 2,
        maxZ = options.maxZ or options.coords.z + options.size.z / 2,
    })

    return zone
end

---A polygon on the ground plane, unbounded in height unless `minZ` or `maxZ` is set.
---@param options { points: (vector2|vector3)[], minZ?: number, maxZ?: number, onEnter?: fun(zone: UgZone), onExit?: fun(zone: UgZone), inside?: fun(zone: UgZone), debug?: boolean, data?: any }
---@return UgZone
function Zone.Poly(options)
    Utils.CheckOptions('Zone.Poly', options, POLY_OPTIONS)

    local points = options.points

    if type(points) ~= 'table' or #points < 3 or #points > MAX_POINTS then
        Utils.Raise(2, 'Zone.Poly: points MUST be 3 to %d vectors', MAX_POINTS)
    end

    local flat = {}

    for index, point in ipairs(points) do
        if type(point) ~= 'vector2' and type(point) ~= 'vector3' then
            Utils.Raise(2, 'Zone.Poly: point %d MUST be a vector2 or vector3', index)
        end

        flat[index] = vector2(point.x, point.y)
    end

    checkNumber('Zone.Poly', options.minZ, 'minZ', true)
    checkNumber('Zone.Poly', options.maxZ, 'maxZ', true)

    local zone = Zones.Add('Zone.Poly', options, POLY_OPTIONS, {
        shape = Shape.Poly,
        points = flat,
        minZ = options.minZ,
        maxZ = options.maxZ,
    })

    return zone
end

---Removes a zone by object or id.
---@param zone UgZone|integer
---@return boolean removed
function Zone.Remove(zone)
    local found = type(zone) == 'table' and zones[zone.id] == zone and zone or zones[zone]

    if not found then
        return false
    end

    remove(found)

    return true
end

---Zones and points of this runtime.
---@return UgZone[]
function Zone.GetAll()
    local list = {}

    for _, zone in pairs(zones) do
        list[#list + 1] = zone
    end

    table.sort(list, function(a, b)
        return a.id < b.id
    end)

    return list
end
