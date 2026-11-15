--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@class UgLib.Math
local Math = {}
UgLib.Math = Math

local Utils = UgLib.Internal.Utils

---@alias UgPoint2D { x: number, y: number }

---@param name string
---@param ... any
local function checkNumbers(name, ...)
    for index = 1, select('#', ...) do
        if type((select(index, ...))) ~= 'number' then
            Utils.Raise(3, '%s expects numbers, argument %d is %s', name, index, type((select(index, ...))))
        end
    end
end

---@param value number
---@param min number
---@param max number
---@return number
function Math.Clamp(value, min, max)
    checkNumbers('Math.Clamp', value, min, max)

    if min > max then
        Utils.Raise(2, 'Math.Clamp: min %s is greater than max %s', min, max)
    end

    if value < min then
        return min
    end

    if value > max then
        return max
    end

    return value
end

---Rounds half away from zero. With 0 decimals the result is an integer.
---@param value number
---@param decimals? integer 0 to 10, defaults to 0
---@return number
function Math.Round(value, decimals)
    checkNumbers('Math.Round', value)

    decimals = decimals or 0

    if math.type(decimals) ~= 'integer' or decimals < 0 or decimals > 10 then
        Utils.Raise(2, 'Math.Round: decimals MUST be an integer from 0 to 10')
    end

    local factor = 10 ^ decimals
    local rounded = value >= 0 and math.floor(value * factor + 0.5) / factor or -math.floor(-value * factor + 0.5) / factor

    if decimals == 0 then
        return math.tointeger(rounded) or rounded
    end

    return rounded
end

---`t` is not clamped, so values outside 0 to 1 extrapolate.
---@param a number
---@param b number
---@param t number
---@return number
function Math.Lerp(a, b, t)
    checkNumbers('Math.Lerp', a, b, t)

    return a + (b - a) * t
end

---Where `value` sits between `a` and `b`, 0 at `a` and 1 at `b`. Returns 0 when `a` equals `b`.
---@param a number
---@param b number
---@param value number
---@return number
function Math.InverseLerp(a, b, value)
    checkNumbers('Math.InverseLerp', a, b, value)

    if a == b then
        return 0
    end

    return (value - a) / (b - a)
end

---Maps `value` from one range to another. Not clamped.
---@param value number
---@param inMin number
---@param inMax number
---@param outMin number
---@param outMax number
---@return number
function Math.Remap(value, inMin, inMax, outMin, outMax)
    checkNumbers('Math.Remap', value, inMin, inMax, outMin, outMax)

    if inMin == inMax then
        return outMin
    end

    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin)
end

---Distance on the ground plane. Takes vectors or tables with `x` and `y`.
---@param a UgPoint2D|vector2|vector3|vector4
---@param b UgPoint2D|vector2|vector3|vector4
---@return number
function Math.Distance2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y

    return math.sqrt(dx * dx + dy * dy)
end

---Ray casting test on the ground plane. Points on an edge MAY count as either side.
---@param point UgPoint2D|vector2|vector3|vector4
---@param polygon (UgPoint2D|vector2|vector3|vector4)[] at least 3 points, in order
---@return boolean
function Math.PointInPolygon(point, polygon)
    if type(polygon) ~= 'table' or #polygon < 3 then
        Utils.Raise(2, 'Math.PointInPolygon expects a polygon of at least 3 points')
    end

    local inside = false
    local count = #polygon
    local previous = polygon[count]
    local x, y = point.x, point.y

    for index = 1, count do
        local current = polygon[index]

        if (current.y > y) ~= (previous.y > y)
            and x < (previous.x - current.x) * (y - current.y) / (previous.y - current.y) + current.x then
            inside = not inside
        end

        previous = current
    end

    return inside
end

---Unit direction of a rotation in degrees, such as `GetGameplayCamRot(2)`.
---@param rotation vector3
---@return vector3
function Math.RotationToDirection(rotation)
    local pitch = math.rad(rotation.x)
    local yaw = math.rad(rotation.z)
    local horizontal = math.abs(math.cos(pitch))

    return vector3(-math.sin(yaw) * horizontal, math.cos(yaw) * horizontal, math.sin(pitch))
end
