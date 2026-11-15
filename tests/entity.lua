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

H.Test('Closest ped skips the local player and player peds', function()
    start()

    local near = H.AddEntity('CPed', vector3(2.0, 0.0, 0.0))
    local far = H.AddEntity('CPed', vector3(8.0, 0.0, 0.0))
    local player = H.AddPlayer(1, 7, vector3(1.0, 0.0, 0.0))

    local entity, distance = UgLib.Entity.GetClosestPed()

    H.Equal({ entity, distance }, { near, 2.0 })
    H.Equal(UgLib.Entity.GetClosestPed(nil, nil, {
        includePlayers = true,
    }), player)
    H.Equal(UgLib.Entity.GetClosestPed(nil, nil, {
        exclude = near,
    }), far)
    H.Equal(UgLib.Entity.GetClosestPed(nil, 1.5), nil)
    H.Equal(UgLib.Entity.GetClosestPed(vector3(9.0, 0.0, 0.0)), far)
end)

H.Test('Vehicles and objects', function()
    start()

    local vehicle = H.AddEntity('CVehicle', vector3(3.0, 0.0, 0.0))
    local object = H.AddEntity('CObject', vector3(0.0, 4.0, 0.0))

    H.Equal(UgLib.Entity.GetClosestVehicle(), vehicle)
    H.Equal(UgLib.Entity.GetClosestVehicle(nil, nil, {
        exclude = vehicle,
    }), nil)
    H.Equal(UgLib.Entity.GetClosestObject(nil, 5.0), object)
    H.Equal(UgLib.Entity.GetNearbyVehicles(nil, 10.0), {
        {
            entity = vehicle,
            distance = 3.0,
        },
    })
    H.Equal(UgLib.Entity.GetNearbyObjects(nil, 3.0), {})
end)

H.Test('Nearby peds are sorted by distance', function()
    start()

    local far = H.AddEntity('CPed', vector3(5.0, 0.0, 0.0))
    local near = H.AddEntity('CPed', vector3(1.0, 0.0, 0.0))

    H.Equal(UgLib.Entity.GetNearbyPeds(nil, 10.0), {
        {
            entity = near,
            distance = 1.0,
        },
        {
            entity = far,
            distance = 5.0,
        },
    })
end)

H.Test('Players carry their ids', function()
    start()

    local ped = H.AddPlayer(3, 12, vector3(0.0, 6.0, 0.0))

    H.Equal(UgLib.Entity.GetClosestPlayer(), {
        playerId = 3,
        serverId = 12,
        ped = ped,
        distance = 6.0,
    })
    H.Equal(UgLib.Entity.GetClosestPlayer(nil, 5.0), nil)
    H.Equal(UgLib.Entity.GetClosestPlayer(nil, nil, {
        includeSelf = true,
    }).serverId, 1)
    H.Equal(#UgLib.Entity.GetNearbyPlayers(nil, 10.0), 1)
    H.Equal(#UgLib.Entity.GetNearbyPlayers(nil, 10.0, {
        includeSelf = true,
    }), 2)
end)

H.Test('Arguments are checked', function()
    start()

    H.Raises(function()
        UgLib.Entity.GetClosestPed(H.Any({
            x = 1,
            y = 2,
            z = 3,
        }))
    end, 'Entity.GetClosestPed: coords MUST be a vector3, got table')

    H.Raises(function()
        UgLib.Entity.GetNearbyPeds(nil, H.Any(nil))
    end, 'Entity.GetNearbyPeds: distance MUST be a positive number')

    H.Raises(function()
        UgLib.Entity.GetClosestVehicle(nil, nil, H.Any({
            includePlayers = true,
        }))
    end, 'Entity.GetClosestVehicle: unknown option "includePlayers"')
end)

H.Done()
