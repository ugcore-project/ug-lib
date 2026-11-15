--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

local LOCAL_PED = 100

---@param settings? string owner file content
local function start(settings)
    H.Reset()

    if settings then
        H.ResourceFiles['config/settings.lua'] = settings
        H.LoadManifest('server')
    end

    H.LoadManifest('client')
end

H.Test('Fields read the local player', function()
    start()
    H.World.entities[LOCAL_PED].coords = vector3(1.0, 2.0, 3.0)
    H.World.entities[LOCAL_PED].heading = 90.0

    local Cache = UgLib.Cache

    H.Equal(Cache.Ped, LOCAL_PED)
    H.Equal(Cache.PlayerId, 0)
    H.Equal(Cache.ServerId, 1)
    H.Equal(Cache.Vehicle, false)
    H.Equal(Cache.Seat, false)
    H.Equal(Cache.Weapon, false)
    H.Equal(Cache.Coords, vector3(1.0, 2.0, 3.0))
    H.Equal(Cache.Heading, 90.0)
    H.Equal(Cache.Get(UgLib.Enums.CacheKey.ServerId), 1)
    H.Equal(rawget(Cache, 'Nope'), nil)
end)

H.Test('ug-lib polls and every runtime follows the changes', function()
    start()

    local Keys = UgLib.Enums.CacheKey
    local consumer = H.ImportPrivate(H.LoadImport('my-shop', 'client')).UgLib
    local seen = {}

    UgLib.Cache.On(Keys.Vehicle, function(value, old)
        seen[#seen + 1] = { value, old }
    end)

    local vehicle = H.AddEntity('CVehicle', vector3(0.0, 0.0, 0.0), {
        seats = {
            [-1] = LOCAL_PED,
        },
    })
    H.World.entities[LOCAL_PED].vehicle = vehicle
    H.World.entities[LOCAL_PED].weapon = GetHashKey('WEAPON_PISTOL')

    H.Advance(99)
    H.Equal(UgLib.Cache.Vehicle, false, 'nothing changes before the interval')

    H.Advance(1)

    H.Equal(UgLib.Cache.Vehicle, vehicle)
    H.Equal(UgLib.Cache.Seat, -1)
    H.Equal(UgLib.Cache.Weapon, GetHashKey('WEAPON_PISTOL'))
    H.Equal(consumer.Cache.Vehicle, vehicle)
    H.Equal(consumer.Cache.Seat, -1)
    H.Equal(seen, { { vehicle, false } })

    H.World.entities[LOCAL_PED].vehicle = nil
    H.Advance(100)

    H.Equal(consumer.Cache.Vehicle, false)
    H.Equal(seen[2], { false, vehicle })
end)

H.Test('Changes from other resources are ignored', function()
    start()

    local Keys = UgLib.Enums.CacheKey
    local changed = UgLib.Enums.Events.Cache.Changed

    H.TriggerEvent(changed, 'evil-resource', Keys.Vehicle, 5, false)
    H.TriggerEvent(changed, nil, Keys.Vehicle, 5, false)
    H.TriggerEvent(changed, 'ug-lib', 'money', 5, false)

    H.Equal(UgLib.Cache.Vehicle, false)
end)

H.Test('The interval follows settings.cacheInterval', function()
    start('return { cacheInterval = 500 }')

    local vehicle = H.AddEntity('CVehicle', vector3(0.0, 0.0, 0.0))
    H.World.entities[LOCAL_PED].vehicle = vehicle

    H.Advance(100)
    H.Equal(UgLib.Cache.Vehicle, false)

    H.Advance(400)
    H.Equal(UgLib.Cache.Vehicle, vehicle)
    H.Equal(UgLib.Cache.Seat, false, 'a ped in no seat has no seat')
end)

H.Test('On and Off check their arguments', function()
    start()

    local Keys = UgLib.Enums.CacheKey
    local calls = 0
    local id = UgLib.Cache.On(Keys.Weapon, function()
        calls = calls + 1
    end)

    H.Equal(UgLib.Cache.Off(id), true)
    H.Equal(UgLib.Cache.Off(id), false)

    H.World.entities[LOCAL_PED].weapon = GetHashKey('WEAPON_PISTOL')
    H.Advance(100)

    H.Equal(calls, 0)

    H.Raises(function()
        UgLib.Cache.On(Keys.Coords, function() end)
    end, 'Cache.On: coords changes every frame and has no events.')

    H.Raises(function()
        UgLib.Cache.Get(H.Any('vehicel'))
    end, 'Cache.Get: key MUST be one of')

    H.Raises(function()
        UgLib.Cache.On(Keys.Ped, H.Any(nil))
    end, 'Cache.On expects a function, got nil')
end)

H.Test('A failing handler is logged and others still run', function()
    start()

    local Keys = UgLib.Enums.CacheKey
    local ran = false

    UgLib.Cache.On(Keys.Ped, function()
        error('boom')
    end)

    UgLib.Cache.On(Keys.Ped, function()
        ran = true
    end)

    local ped = H.AddEntity('CPed', vector3(0.0, 0.0, 0.0), {
        player = 0,
    })
    H.World.players[0].ped = ped

    local lines = H.Capture(function()
        H.Advance(100)
    end)

    H.Equal(ran, true)
    H.Assert(lines[1]:find('Cache.On handler for ped failed', 1, true) ~= nil, lines[1])
end)

H.Done()
