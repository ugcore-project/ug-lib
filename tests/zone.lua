--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

local PED = 100

---@param settings? string
local function start(settings)
    H.Reset()

    if settings then
        H.ResourceFiles['config/settings.lua'] = settings
        H.LoadManifest('server')
    end

    H.LoadManifest('client')
end

---@param x number
---@param y number
---@param z? number
local function moveTo(x, y, z)
    H.World.entities[PED].coords = vector3(x, y, z or 0.0)
end

---@return table log, table options callbacks that write to the log
local function recorder()
    local log = {}

    return log, {
        onEnter = function(zone)
            log[#log + 1] = 'enter ' .. tostring(zone.data)
        end,
        onExit = function(zone)
            log[#log + 1] = 'exit ' .. tostring(zone.data)
        end,
    }
end

H.Test('Sphere enter and exit on the interval', function()
    start()
    moveTo(50.0, 0.0)

    local log, callbacks = recorder()

    UgLib.Zone.Sphere({
        coords = vector3(0.0, 0.0, 0.0),
        radius = 5.0,
        data = 'shop',
        onEnter = callbacks.onEnter,
        onExit = callbacks.onExit,
    })

    H.Equal(log, {}, 'outside on the first check')

    moveTo(1.0, 1.0)
    H.Advance(249)
    H.Equal(log, {})
    H.Advance(1)
    H.Equal(log, { 'enter shop' })

    moveTo(0.0, 10.0)
    H.Advance(250)
    H.Equal(log, { 'enter shop', 'exit shop' })
end)

H.Test('Box zones rotate with their heading', function()
    start()
    moveTo(0.0, 4.0)

    local zone = UgLib.Zone.Box({
        coords = vector3(0.0, 0.0, 0.0),
        size = vector3(2.0, 10.0, 4.0),
    })

    H.Equal(zone:Contains(vector3(0.0, 4.0, 0.0)), true)
    H.Equal(zone:Contains(vector3(4.0, 0.0, 0.0)), false)
    H.Equal(zone:Contains(vector3(0.0, 4.0, 3.0)), false, 'above the height')

    local turned = UgLib.Zone.Box({
        coords = vector3(0.0, 0.0, 0.0),
        size = vector3(2.0, 10.0, 4.0),
        heading = 90.0,
    })

    H.Equal(turned:Contains(vector3(4.0, 0.0, 0.0)), true)
    H.Equal(turned:Contains(vector3(0.0, 4.0, 0.0)), false)

    local tall = UgLib.Zone.Box({
        coords = vector3(0.0, 0.0, 0.0),
        size = vector3(2.0, 2.0, 1.0),
        minZ = -10.0,
        maxZ = 10.0,
    })

    H.Equal(tall:Contains(vector3(0.0, 0.0, 9.0)), true)
end)

H.Test('Poly zones are unbounded in height unless set', function()
    start()

    local points = { vector2(0.0, 0.0), vector2(10.0, 0.0), vector3(10.0, 10.0, 5.0), vector2(0.0, 10.0) }
    local zone = UgLib.Zone.Poly({
        points = points,
    })
    local bounded = UgLib.Zone.Poly({
        points = points,
        minZ = 0.0,
        maxZ = 5.0,
    })

    H.Equal(zone:Contains(vector3(5.0, 5.0, 500.0)), true)
    H.Equal(zone:Contains(vector3(15.0, 5.0, 0.0)), false)
    H.Equal(bounded:Contains(vector3(5.0, 5.0, 6.0)), false)
    H.Equal(bounded:Contains(vector3(5.0, 5.0, 4.0)), true)
end)

H.Test('inside runs every frame while inside', function()
    start()
    moveTo(0.0, 0.0)

    local frames = 0

    UgLib.Zone.Sphere({
        coords = vector3(0.0, 0.0, 0.0),
        radius = 2.0,
        inside = function()
            frames = frames + 1
        end,
    })

    H.Equal(frames, 1)
    H.Advance(0)
    H.Advance(0)
    H.Equal(frames, 3)

    moveTo(50.0, 0.0)
    H.Advance(0)
    H.Advance(100)

    H.Equal(frames, 3, 'back to the interval outside')
end)

H.Test('Remove, SetEnabled and GetAll', function()
    start()
    moveTo(0.0, 0.0)

    local log, callbacks = recorder()
    local zone = UgLib.Zone.Sphere({
        coords = vector3(0.0, 0.0, 0.0),
        radius = 5.0,
        data = 'a',
        onEnter = callbacks.onEnter,
        onExit = callbacks.onExit,
    })
    local other = UgLib.Zone.Sphere({
        coords = vector3(0.0, 0.0, 0.0),
        radius = 5.0,
    })

    H.Equal(log, { 'enter a' })
    H.Equal(#UgLib.Zone.GetAll(), 2)

    zone:SetEnabled(false)
    H.Equal(log, { 'enter a', 'exit a' })

    H.Advance(250)
    H.Equal(log, { 'enter a', 'exit a' }, 'disabled zones are not checked')

    zone:SetEnabled(true)
    H.Advance(250)
    H.Equal(log, { 'enter a', 'exit a', 'enter a' })

    zone:Remove()
    H.Equal(log[4], 'exit a', 'removing a zone the player is in calls onExit')
    H.Equal(UgLib.Zone.Remove(zone), false)
    H.Equal(UgLib.Zone.Remove(other.id), true)
    H.Equal(UgLib.Zone.GetAll(), {})
end)

H.Test('The interval follows settings.zoneInterval', function()
    start('return { zoneInterval = 1000 }')
    moveTo(50.0, 0.0)

    local log, callbacks = recorder()

    UgLib.Zone.Sphere({
        coords = vector3(0.0, 0.0, 0.0),
        radius = 5.0,
        data = 'z',
        onEnter = callbacks.onEnter,
    })
    moveTo(0.0, 0.0)

    H.Advance(250)
    H.Equal(log, {})
    H.Advance(750)
    H.Equal(log, { 'enter z' })
end)

H.Test('Debug zones draw every frame', function()
    start()
    moveTo(50.0, 0.0)

    UgLib.Zone.Box({
        coords = vector3(0.0, 0.0, 0.0),
        size = vector3(2.0, 2.0, 2.0),
        debug = true,
    })

    H.Equal(#H.World.calls, 12, 'four edges, three lines each')
    H.Equal(H.World.calls[1].name, 'DrawLine')

    H.World.calls = {}
    UgLib.Zone.Sphere({
        coords = vector3(0.0, 0.0, 0.0),
        radius = 1.0,
        debug = true,
    })
    H.Advance(0)

    H.Equal(H.CallNames()[13], 'DrawMarker')
end)

H.Test('A failing callback is logged', function()
    start()
    moveTo(0.0, 0.0)

    local lines = H.Capture(function()
        UgLib.Zone.Sphere({
            coords = vector3(0.0, 0.0, 0.0),
            radius = 1.0,
            onEnter = function()
                error('boom')
            end,
        })
    end)

    H.Assert(lines[1]:find('Zone 1 onEnter failed', 1, true) ~= nil, lines[1])
end)

H.Test('Options are checked', function()
    start()

    H.Raises(function()
        UgLib.Zone.Sphere(H.Any({
            coords = vector3(0.0, 0.0, 0.0),
            radius = 1.0,
            onEnterr = function() end,
        }))
    end, 'Zone.Sphere: unknown option "onEnterr". Did you mean "onEnter"?')

    H.Raises(function()
        UgLib.Zone.Sphere(H.Any({
            coords = { 0, 0, 0 },
            radius = 1.0,
        }))
    end, 'Zone.Sphere: coords MUST be a vector3, got table')

    H.Raises(function()
        UgLib.Zone.Box(H.Any({
            coords = vector3(0.0, 0.0, 0.0),
            size = vector3(1.0, 1.0, 1.0),
            heading = 0 / 0,
        }))
    end, 'Zone.Box: heading MUST be a finite number')

    H.Raises(function()
        UgLib.Zone.Poly(H.Any({
            points = { vector2(0.0, 0.0), vector2(1.0, 1.0) },
        }))
    end, 'Zone.Poly: points MUST be 3 to 256 vectors')

    local line = debug.getinfo(1, 'l').currentline + 2
    local message = H.Raises(function()
        UgLib.Zone.Sphere(H.Any({
            coords = vector3(0.0, 0.0, 0.0),
            radius = 1.0,
            onExit = 'nope',
        }))
    end, 'Zone.Sphere: onExit MUST be a function')

    H.Assert(message:find('tests/zone.lua:' .. line .. ':', 1, true) ~= nil, message)
end)

H.Test('Points call nearby for the closest first', function()
    start()
    moveTo(0.0, 0.0)

    local order = {}

    ---@param point UgZone
    local function nearby(point)
        order[#order + 1] = ('%s %.0f'):format(point.data, point.currentDistance)
    end

    UgLib.Point.Create({
        coords = vector3(3.0, 0.0, 0.0),
        distance = 5.0,
        data = 'far',
        nearby = nearby,
    })
    UgLib.Point.Create({
        coords = vector3(1.0, 0.0, 0.0),
        distance = 5.0,
        data = 'near',
        nearby = nearby,
    })

    order = {}
    H.Advance(0)

    H.Equal(order, { 'near 1', 'far 3' })

    H.Raises(function()
        UgLib.Point.Create(H.Any({
            coords = vector3(0.0, 0.0, 0.0),
            distance = 0,
        }))
    end, 'Point.Create: distance MUST be a positive number')

    H.Raises(function()
        UgLib.Point.Create(H.Any({
            coords = vector3(0.0, 0.0, 0.0),
            distance = 1.0,
            inside = function() end,
        }))
    end, 'Point.Create: unknown option "inside"')
end)

H.Test('Zones of a consumer run in its runtime', function()
    start()
    moveTo(0.0, 0.0)

    local consumer = H.ImportPrivate(H.LoadImport('my-shop', 'client')).UgLib
    local entered = false

    consumer.Zone.Sphere({
        coords = vector3(0.0, 0.0, 0.0),
        radius = 1.0,
        onEnter = function()
            entered = true
        end,
    })

    H.Equal(entered, true)
    H.Equal(#consumer.Zone.GetAll(), 1)
    H.Equal(#UgLib.Zone.GetAll(), 0, 'each runtime has its own zones')
end)

H.Done()
