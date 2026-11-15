--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

local PED = 100

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

H.Test('Play loads the dictionary first', function()
    start()
    H.AddAsset('animDict', 'mp_player_inteat@burger')

    local thread = run(function()
        return UgLib.Animation.Play(PED, 'mp_player_inteat@burger', 'mp_player_int_eat_burger', {
            flag = 49,
        })
    end)

    H.Equal(thread.result, true)
    H.Equal(H.World.calls[1].name, 'TaskPlayAnim')
    H.Equal(H.World.calls[1].args, {
        PED,
        'mp_player_inteat@burger',
        'mp_player_int_eat_burger',
        8.0,
        -8.0,
        -1,
        49,
        0.0,
        false,
        false,
        false,
        n = 11,
    })

    local missing = run(function()
        return UgLib.Animation.Play(PED, 'nope', 'nope')
    end)

    H.Equal(missing.result, false)
    H.Equal(#H.World.calls, 1)
end)

H.Test('Stop and scenarios', function()
    start()

    UgLib.Animation.Stop(PED, 'dict', 'name')
    UgLib.Animation.Stop(PED)
    UgLib.Animation.Scenario(PED, 'WORLD_HUMAN_CLIPBOARD')

    H.Equal(H.CallNames(), { 'StopAnimTask', 'ClearPedTasks', 'TaskStartScenarioInPlace' })
end)

H.Test('Props attach to a bone and are deleted', function()
    start()
    H.AddAsset('model', 'prop_cs_burger_01')

    local thread = run(function()
        return UgLib.Animation.AttachProp(PED, {
            model = 'prop_cs_burger_01',
            offset = vector3(0.1, 0.0, 0.0),
        })
    end)

    local prop = thread.result
    local entity = H.World.entities[prop]

    H.Equal(entity.attachedTo, PED)
    H.Equal(entity.bone, 57005)
    H.Equal(entity.networked, false)
    H.Equal(H.World.released, { 'model:' .. GetHashKey('prop_cs_burger_01') }, 'the model is released once attached')

    H.Equal(UgLib.Animation.DetachProps(999), 0)
    H.Equal(UgLib.Animation.DetachProps(PED), 1)
    H.Equal(H.World.entities[prop], nil)
end)

H.Test('Props of a stopping resource are deleted', function()
    start()
    H.AddAsset('model', 'prop_cs_burger_01')

    local thread = run(function()
        return UgLib.Animation.AttachProp(PED, {
            model = 'prop_cs_burger_01',
            networked = true,
        })
    end)

    H.Equal(H.World.entities[thread.result].networked, true)

    H.TriggerEvent('onResourceStop', nil, 'ug-lib')

    H.Equal(H.World.entities[thread.result], nil)

    local missing = run(function()
        return UgLib.Animation.AttachProp(PED, {
            model = 'nope',
        })
    end)

    H.Equal(missing.result, nil)
end)

H.Test('Arguments are checked', function()
    start()

    H.Raises(function()
        UgLib.Animation.Play(H.Any('ped'), 'a', 'b')
    end, 'Animation.Play expects a ped handle, got string')

    H.Raises(function()
        UgLib.Animation.Play(PED, 'a', 'b')
    end, 'Animation.Play MUST run in a thread')

    H.Raises(function()
        UgLib.Animation.AttachProp(PED, H.Any({
            model = 'x',
            bones = 1,
        }))
    end, 'Animation.AttachProp: unknown option "bones". Did you mean "bone"?')

    H.Raises(function()
        UgLib.Animation.AttachProp(PED, H.Any({
            model = {},
        }))
    end, 'model MUST be a name or hash')
end)

H.Done()
