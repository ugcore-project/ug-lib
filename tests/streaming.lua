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

    for _ = 1, 3 do
        H.Advance(0)
    end

    return thread
end

H.Test('Assets that exist load and are tracked', function()
    start()
    H.AddAsset('model', 'prop_cs_burger_01')
    H.AddAsset('animDict', 'mp_player_inteat@burger')
    H.AddAsset('ptfxAsset', 'core')
    H.AddAsset('textureDict', 'commonmenu')
    H.AddAsset('animSet', 'move_m@drunk@verydrunk')

    local Streaming = UgLib.Streaming
    local thread = run(function()
        return {
            Streaming.Model('prop_cs_burger_01'),
            Streaming.Model(GetHashKey('prop_cs_burger_01')),
            Streaming.AnimDict('mp_player_inteat@burger'),
            Streaming.PtfxAsset('core'),
            Streaming.TextureDict('commonmenu'),
            Streaming.AnimSet('move_m@drunk@verydrunk'),
        }
    end)

    H.Equal(thread.result, { true, true, true, true, true, true })
end)

H.Test('Missing assets fail without waiting, unknown ones time out', function()
    start()

    local thread = H.Thread(function()
        return { UgLib.Streaming.Model('nope'), UgLib.Streaming.AnimDict('nope') }
    end)

    H.Equal(thread.result, { false, false }, 'models and dictionaries are checked first')

    local slow = H.Thread(function()
        return UgLib.Streaming.PtfxAsset('nope', 100)
    end)

    H.Advance(50)
    H.Equal(slow.done, false)
    H.Advance(50)
    H.Equal(slow.result, false)
end)

H.Test('Scaleform movies return their handle', function()
    start()
    H.AddAsset('scaleformMovie', 'MP_BIG_MESSAGE_FREEMODE')

    local thread = run(function()
        return table.pack(UgLib.Streaming.ScaleformMovie('MP_BIG_MESSAGE_FREEMODE'))
    end)

    H.Equal(thread.result, {
        true,
        '#MP_BIG_MESSAGE_FREEMODE',
        n = 2,
    })

    local missing = run(function()
        return table.pack(UgLib.Streaming.ScaleformMovie('NOPE', 0))
    end)

    H.Equal(missing.result, {
        false,
        nil,
        n = 2,
    })
end)

H.Test('Release and resource stop release what this runtime loaded', function()
    start()
    H.AddAsset('model', 'prop_cs_burger_01')
    H.AddAsset('animDict', 'anim@dict')

    local Asset = UgLib.Enums.Asset

    run(function()
        UgLib.Streaming.Model('prop_cs_burger_01')
        UgLib.Streaming.AnimDict('anim@dict')
    end)

    H.Equal(UgLib.Streaming.Release(Asset.Model, 'prop_cs_burger_01'), true)
    H.Equal(UgLib.Streaming.Release(Asset.Model, 'prop_cs_burger_01'), false)
    H.Equal(H.World.released, { 'model:' .. GetHashKey('prop_cs_burger_01') })

    H.TriggerEvent('onResourceStop', nil, 'ug-lib')

    H.Equal(H.World.released[2], 'animDict:anim@dict')
end)

H.Test('Loaders check their arguments and MUST run in a thread', function()
    start()

    H.Raises(function()
        UgLib.Streaming.AnimDict('anim@dict')
    end, 'Streaming.AnimDict MUST run in a thread')

    H.Raises(function()
        UgLib.Streaming.Model(H.Any({}))
    end, 'Streaming.Model expects a model name or hash, got table')

    H.Raises(function()
        UgLib.Streaming.AnimDict('')
    end, 'Streaming.AnimDict expects a name, got string')

    H.Raises(function()
        UgLib.Streaming.Release(H.Any('models'), 'x')
    end, 'Streaming.Release: kind MUST be one of')

    local invalid = H.Thread(function()
        UgLib.Streaming.AnimDict('anim@dict', -1)
    end)

    H.Assert(invalid.error:find('timeout MUST be a non-negative integer', 1, true) ~= nil, invalid.error)
end)

H.Done()
