--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

H.ResourceMetadata['ug-lib'] = {
    version = '1.2.3',
}

H.LoadManifest('server')

local Version = UgLib.Version

H.Test('Get reads the manifest', function()
    H.Equal(Version.Get(), '1.2.3')
end)

H.Test('IsAtLeast compares numerically', function()
    H.Equal(Version.IsAtLeast('1.2.3'), true)
    H.Equal(Version.IsAtLeast('1.2.10'), false)
    H.Equal(Version.IsAtLeast('1.1.99'), true)
    H.Equal(Version.IsAtLeast('1.2.3-beta'), true)

    H.Raises(function()
        Version.IsAtLeast('one')
    end, 'Version.IsAtLeast expects a version such as "1.2.0"')
end)

H.Test('Require raises for an older ug-lib', function()
    Version.Require('1.0.0')

    H.Raises(function()
        Version.Require('1.3.0')
    end, 'ug-lib requires ug-lib 1.3.0 or newer, found 1.2.3. Update ug-lib.')
end)

H.Test('Require warns for a newer major', function()
    H.ResourceMetadata['ug-lib'] = {
        version = '2.0.0',
    }

    local lines = H.Capture(function()
        Version.Require('1.0.0')
    end)

    H.Equal(#lines, 1)
    H.Assert(lines[1]:find('was built for ug-lib 1.x, found 2.0.0', 1, true) ~= nil, lines[1])
end)

H.Test('Compare orders versions', function()
    local Compare = UgLib.Internal.Version.Compare

    H.Equal(Compare('1.0.0', '1.0.1'), -1)
    H.Equal(Compare('2.0.0', '1.9.9'), 1)
    H.Equal(Compare('1.0.0', '1.0.0'), 0)
    H.Equal(Compare('x', '1.0.0'), nil)
end)

H.Done()
