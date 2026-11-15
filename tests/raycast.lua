--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

local function start()
    H.Reset()
    H.LoadManifest('client')
end

---@param fn fun(): any
---@return TestThread
local function run(fn)
    local thread = H.Thread(fn)

    H.Advance(0)

    return thread
end

H.Test('A hit returns coords, normal, entity and material', function()
    start()

    local wall = H.AddEntity('CObject', vector3(0.0, 5.0, 0.0))
    H.World.shapeTest = {
        hit = true,
        coords = vector3(0.0, 5.0, 0.0),
        normal = vector3(0.0, -1.0, 0.0),
        entity = wall,
        material = 42,
    }

    local thread = run(function()
        return UgLib.Raycast.FromCoords(vector3(0.0, 0.0, 0.0), vector3(0.0, 10.0, 0.0), {
            flags = 1,
            ignore = 100,
        })
    end)

    H.Equal(thread.result, {
        hit = true,
        coords = vector3(0.0, 5.0, 0.0),
        normal = vector3(0.0, -1.0, 0.0),
        entity = wall,
        material = 42,
    })
    H.Equal(H.World.probes[1], {
        0.0,
        0.0,
        0.0,
        0.0,
        10.0,
        0.0,
        1,
        100,
        7,
        n = 9,
    })
end)

H.Test('A miss and the world', function()
    start()

    local miss = run(function()
        return UgLib.Raycast.FromCoords(vector3(0.0, 0.0, 0.0), vector3(0.0, 1.0, 0.0))
    end)

    H.Equal(miss.result, {
        hit = false,
    })
    H.Equal(H.World.probes[1][7], 511, 'every flag by default')

    H.World.shapeTest = {
        hit = true,
        coords = vector3(0.0, 1.0, 0.0),
    }

    local ground = run(function()
        return UgLib.Raycast.FromCoords(vector3(0.0, 0.0, 0.0), vector3(0.0, 1.0, 0.0))
    end)

    H.Equal(ground.result.entity, nil)
end)

H.Test('From the camera, ignoring the local player', function()
    start()
    H.World.camCoord = vector3(1.0, 1.0, 1.0)
    H.World.camRot = vector3(0.0, 0.0, 0.0)

    run(function()
        return UgLib.Raycast.FromCamera(5.0)
    end)

    local probe = H.World.probes[1]

    H.Equal({ probe[4], probe[5], probe[6], probe[8] }, { 1.0, 6.0, 1.0, 100 })

    H.Raises(function()
        UgLib.Raycast.FromCamera(5.0)
    end, 'Raycast.FromCamera MUST run in a thread')

    H.Raises(function()
        UgLib.Raycast.FromCamera(-1)
    end, 'distance MUST be a positive number')
end)

H.Test('Screen helpers', function()
    start()

    H.Equal(table.pack(UgLib.Screen.WorldToScreen(vector3(0.0, 5.0, 0.0))), {
        true,
        0.5,
        0.5,
        n = 3,
    })
    H.Equal(UgLib.Screen.WorldToScreen(vector3(0.0, -5.0, 0.0)), false)
    H.Equal(table.pack(UgLib.Screen.GetResolution()), {
        1920,
        1080,
        n = 2,
    })
    H.Assert(math.abs(UgLib.Screen.GetAspectRatio() - 1.7777) < 0.001)

    H.Raises(function()
        UgLib.Screen.WorldToScreen(H.Any({
            x = 1,
        }))
    end, 'Screen.WorldToScreen expects a vector3, got table')
end)

H.Done()
