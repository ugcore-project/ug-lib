--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

H.Test('The server side declares UgLib and UgLib.Internal', function()
    H.LoadManifest('server')

    H.Equal(type(UgLib), 'table')
    H.Equal(type(UgLib.Internal), 'table')
end)

H.Test('The client side declares UgLib and UgLib.Internal', function()
    H.LoadManifest('client')

    H.Equal(type(UgLib), 'table')
    H.Equal(type(UgLib.Internal), 'table')
end)

H.Test('A reload starts from a fresh root', function()
    H.LoadManifest('server')
    rawset(H.Any(UgLib), 'Leftover', true)

    H.LoadManifest('server')

    H.Equal(rawget(H.Any(UgLib), 'Leftover'), nil)
end)

H.Done()
