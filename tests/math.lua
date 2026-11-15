--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

H.LoadManifest('server')

local Math = UgLib.Math

---@param actual number
---@param expected number
local function near(actual, expected)
    H.Assert(math.abs(actual - expected) < 1e-9, ('expected %s, got %s'):format(expected, actual))
end

H.Test('Clamp keeps values in range', function()
    H.Equal(Math.Clamp(5, 0, 10), 5)
    H.Equal(Math.Clamp(-1, 0, 10), 0)
    H.Equal(Math.Clamp(11, 0, 10), 10)

    H.Raises(function()
        Math.Clamp(1, 10, 0)
    end, 'Math.Clamp: min 10 is greater than max 0')

    H.Raises(function()
        Math.Clamp(H.Any('1'), 0, 1)
    end, 'Math.Clamp expects numbers, argument 1 is string')
end)

H.Test('Round rounds half away from zero', function()
    H.Equal(Math.Round(2.5), 3)
    H.Equal(Math.Round(-2.5), -3)
    H.Equal(Math.Round(2.4), 2)
    H.Equal(math.type(Math.Round(2.4)), 'integer')
    near(Math.Round(3.14159, 2), 3.14)
    near(Math.Round(-3.145, 1), -3.1)

    H.Raises(function()
        Math.Round(1, 11)
    end, 'decimals MUST be an integer from 0 to 10')

    H.Raises(function()
        Math.Round(1, H.Any(1.5))
    end, 'decimals MUST be an integer')
end)

H.Test('Lerp, InverseLerp and Remap', function()
    H.Equal(Math.Lerp(0, 10, 0.5), 5.0)
    H.Equal(Math.Lerp(0, 10, 1.5), 15.0)
    H.Equal(Math.InverseLerp(0, 10, 5), 0.5)
    H.Equal(Math.InverseLerp(3, 3, 5), 0)
    H.Equal(Math.Remap(5, 0, 10, 100, 200), 150.0)
    H.Equal(Math.Remap(5, 1, 1, 100, 200), 100)
end)

H.Test('Distance2D ignores height', function()
    H.Equal(Math.Distance2D(vector3(0, 0, 0), vector3(3, 4, 100)), 5.0)
    H.Equal(Math.Distance2D({
        x = 1,
        y = 1,
    }, {
        x = 1,
        y = 1,
    }), 0.0)
end)

H.Test('PointInPolygon', function()
    local square = { vector2(0, 0), vector2(10, 0), vector2(10, 10), vector2(0, 10) }

    H.Equal(Math.PointInPolygon(vector3(5, 5, 30), square), true)
    H.Equal(Math.PointInPolygon(vector2(15, 5), square), false)
    H.Equal(Math.PointInPolygon({
        x = -1,
        y = -1,
    }, square), false)

    local concave = { vector2(0, 0), vector2(10, 0), vector2(10, 10), vector2(5, 2), vector2(0, 10) }

    H.Equal(Math.PointInPolygon(vector2(5, 8), concave), false)
    H.Equal(Math.PointInPolygon(vector2(2, 2), concave), true)

    H.Raises(function()
        Math.PointInPolygon(vector2(0, 0), { vector2(0, 0), vector2(1, 1) })
    end, 'at least 3 points')
end)

H.Test('RotationToDirection', function()
    local forward = Math.RotationToDirection(vector3(0, 0, 0))

    near(forward.x, 0)
    near(forward.y, 1)
    near(forward.z, 0)

    local up = Math.RotationToDirection(vector3(90, 0, 0))

    near(up.z, 1)

    local west = Math.RotationToDirection(vector3(0, 0, 90))

    near(west.x, -1)
    near(west.y, 0)
end)

H.Done()
