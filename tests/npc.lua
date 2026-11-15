--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

local PED = 100
local CLERK = 's_f_y_shop_mid'
local SHOP = vector4(10.0, 0.0, 30.0, 90.0)

local function start()
    H.Reset()
    H.LoadManifest('client')
    H.AddAsset('model', CLERK)
end

---@param x number
---@param y number
local function moveTo(x, y)
    H.World.entities[PED].coords = vector3(x, y, 30.0)
end

---@return integer[] handles of every ped other than the player
local function peds()
    local list = {}

    for handle, entity in pairs(H.World.entities) do
        if entity.pool == 'CPed' and handle ~= PED then
            list[#list + 1] = handle
        end
    end

    table.sort(list)

    return list
end

H.Test('An NPC spawns near the player and is deleted when they leave', function()
    start()
    moveTo(500.0, 0.0)

    local spawned, gone = 0, 0
    local npc = UgLib.Npc.Create({
        model = CLERK,
        coords = SHOP,
        distance = 40.0,
        animation = {
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        },
        onSpawn = function()
            spawned = spawned + 1
        end,
        onDespawn = function()
            gone = gone + 1
        end,
    })

    H.Advance(250)
    H.Equal(peds(), {}, 'far away: nothing')
    H.Equal(UgLib.Npc.GetPed(npc), nil)

    moveTo(20.0, 0.0)
    H.Advance(250)
    H.Advance(0)

    local list = peds()

    H.Equal(#list, 1)

    local ped = H.World.entities[list[1]]

    H.Equal(ped.model, GetHashKey(CLERK))
    H.Equal(ped.coords, vector3(10.0, 0.0, 29.0), 'on the ground')
    H.Equal(ped.heading, 90.0)
    H.Equal(ped.frozen, true)
    H.Equal(ped.invincible, true)
    H.Equal(ped.networked, false, 'local only')
    H.Equal(UgLib.Npc.GetPed(npc), list[1])
    H.Equal(spawned, 1)
    H.Equal(H.CallNames(), { 'SetBlockingOfNonTemporaryEvents', 'SetPedCanRagdoll', 'TaskStartScenarioInPlace' })

    moveTo(500.0, 0.0)
    H.Advance(250)
    H.Equal(peds(), {})
    H.Equal(gone, 1)
end)

H.Test('Leaving while the model loads spawns nothing', function()
    start()
    moveTo(10.0, 0.0)

    local npc = UgLib.Npc.Create({
        model = CLERK,
        coords = SHOP,
        distance = 5.0,
    })

    UgLib.Npc.Remove(npc)
    H.Advance(250)
    H.Advance(0)

    H.Equal(peds(), {})
end)

H.Test('Remove, Clear and a stopping resource delete the peds', function()
    start()
    moveTo(10.0, 0.0)

    local first = UgLib.Npc.Create({
        model = CLERK,
        coords = SHOP,
    })

    UgLib.Npc.Create({
        model = CLERK,
        coords = vector4(12.0, 0.0, 30.0, 0.0),
    })
    H.Advance(250)
    H.Advance(100)
    H.Equal(#peds(), 2)

    H.Equal(UgLib.Npc.Remove(first), true)
    H.Equal(UgLib.Npc.Remove(first), false, 'already removed')
    H.Equal(#peds(), 1)

    H.TriggerEvent('onResourceStop', nil, 'ug-lib')
    H.Equal(peds(), {})
end)

H.Test('A model that does not load spawns nothing', function()
    start()
    moveTo(10.0, 0.0)

    UgLib.Npc.Create({
        model = 'nope',
        coords = SHOP,
    })
    H.Advance(0)
    H.Advance(5000)

    H.Equal(peds(), {})
end)

H.Test('Options are checked', function()
    start()

    H.Raises(function()
        UgLib.Npc.Create(H.Any({
            model = CLERK,
            coords = vector3(0.0, 0.0, 0.0),
        }))
    end, 'coords MUST be a vector4')

    H.Raises(function()
        UgLib.Npc.Create(H.Any({
            model = CLERK,
            coords = SHOP,
            distance = 0,
        }))
    end, 'distance MUST be')

    H.Raises(function()
        UgLib.Npc.Create(H.Any({
            model = CLERK,
            coords = SHOP,
            animation = {
                dict = 'a',
            },
        }))
    end, 'animation MUST be')

    H.Raises(function()
        UgLib.Npc.Create(H.Any({
            model = CLERK,
            coords = SHOP,
            heading = 1,
        }))
    end, 'heading')
end)

H.Done()
