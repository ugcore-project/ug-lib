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

H.Test('Text3D draws at a world position, in range only', function()
    start()

    local options = {
        maxDistance = 10.0,
        color = { 255, 0, 0 },
    }

    UgLib.Draw.Text3D(vector3(0.0, 5.0, 0.0), 'Shop', options)

    H.Equal(H.CallNames(), {
        'SetDrawOrigin', 'SetTextScale', 'SetTextFont', 'SetTextColour', 'SetTextCentre', 'SetTextOutline',
        'BeginTextCommandDisplayText', 'AddTextComponentSubstringPlayerName', 'EndTextCommandDisplayText', 'ClearDrawOrigin',
    })
    H.Equal(H.World.calls[4].args, {
        255,
        0,
        0,
        215,
        n = 4,
    })
    H.Equal(H.World.calls[8].args, {
        'Shop',
        n = 1,
    })

    H.World.calls = {}
    UgLib.Draw.Text3D(vector3(0.0, 50.0, 0.0), 'Shop', options)

    H.Equal(H.World.calls, {}, 'out of range draws nothing')
end)

H.Test('Text2D and markers', function()
    start()

    UgLib.Draw.Text2D(0.5, 0.9, 'Hello', {
        outline = false,
        center = false,
    })

    H.Equal(H.CallNames(), {
        'SetTextScale', 'SetTextFont', 'SetTextColour', 'SetTextCentre', 'BeginTextCommandDisplayText',
        'AddTextComponentSubstringPlayerName', 'EndTextCommandDisplayText',
    })
    H.Equal(H.World.calls[7].args, {
        0.5,
        0.9,
        n = 2,
    })

    H.World.calls = {}
    UgLib.Draw.Marker(1, vector3(1.0, 2.0, 3.0), {
        size = vector3(2.0, 2.0, 0.5),
        bob = true,
    })

    local args = H.World.calls[1].args

    H.Equal(H.World.calls[1].name, 'DrawMarker')
    H.Equal({ args[1], args[2], args[3], args[4], args[11], args[13], args[18] }, { 1, 1.0, 2.0, 3.0, 2.0, 0.5, true })
end)

H.Test('Options are checked once per table', function()
    start()

    H.Raises(function()
        UgLib.Draw.Text3D(vector3(0.0, 0.0, 0.0), 'x', H.Any({
            colour = { 1, 2, 3 },
        }))
    end, 'Draw.Text3D: unknown option "colour". Did you mean "color"?')

    H.Raises(function()
        UgLib.Draw.Marker(1, vector3(0.0, 0.0, 0.0), H.Any({
            color = 'red',
        }))
    end, 'Draw.Marker: color MUST be { r, g, b, a? } from 0 to 255')

    local options = {
        scale = 0.5,
    }

    UgLib.Draw.Text2D(0.1, 0.1, 'x', options)
    options.font = 1
    UgLib.Draw.Text2D(0.1, 0.1, 'x', options)

    H.Equal(#H.World.calls, 16)
end)

H.Done()
