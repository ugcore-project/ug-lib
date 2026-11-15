--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

H.Test('The import exposes shared namespaces and hides Internal', function()
    H.Reset()
    H.LoadManifest('server')

    local env = H.LoadImport('my-shop', 'server')
    local UgLib = env.UgLib

    H.Equal(UgLib.Math.Clamp(5, 0, 1), 1)
    H.Equal(UgLib.Format.Number(1000), '1,000')
    H.Equal(UgLib.Enums.Position.TopLeft, 'top-left')
    H.Equal(type(UgLib.Locale.Create), 'function')
    H.Assert(rawget(_G, 'UgLib') ~= UgLib, 'the consumer gets its own root')

    H.Raises(function()
        return UgLib.Internal
    end, 'UgLib.Internal is private to ug-lib.')

    H.Raises(function()
        return UgLib.Nope
    end, 'UgLib.Nope is not a ug-lib namespace.')

    H.Raises(function()
        return UgLib.Dialog
    end, 'UgLib.Dialog exists on clients only.')

    H.Raises(function()
        UgLib.Math = {}
    end, 'UgLib is read-only. Cannot set UgLib.Math.')

    H.Equal(getmetatable(UgLib), false)
end)

H.Test('Errors point to the consumer line', function()
    H.Reset()
    H.LoadManifest('server')

    local UgLib = H.LoadImport('my-shop', 'server').UgLib
    local line = debug.getinfo(1, 'l').currentline + 2
    local message = H.Raises(function()
        UgLib.Format.Number(1, {
            decimal = 2,
        })
    end)

    H.Assert(message:find('tests/import.lua:' .. line .. ':', 1, true) ~= nil, message)
end)

H.Test('uglib_version stops a consumer that needs a newer ug-lib', function()
    H.Reset()
    H.ResourceMetadata['ug-lib'] = {
        version = '1.2.0',
    }
    H.ResourceMetadata['my-shop'] = {
        uglib_version = '1.3.0',
    }
    H.LoadManifest('server')

    H.Raises(function()
        H.LoadImport('my-shop', 'server')
    end, 'my-shop requires ug-lib 1.3.0 or newer, found 1.2.0. Update ug-lib.')

    H.ResourceMetadata['my-shop'] = {
        uglib_version = '1.1.0',
    }
    H.LoadImport('my-shop', 'server')
end)

H.Test('The import loads the shared scripts of the manifest, in order', function()
    local manifest = {}
    local env = setmetatable({}, {
        __index = function(_, directive)
            return function(value)
                if directive == 'shared_scripts' then
                    manifest = value
                end
            end
        end,
    })

    assert(loadfile('fxmanifest.lua', 't', env))()

    local source = assert(io.open('import.lua', 'rb')):read('a')
    local listed = {}

    for path in source:match('local SHARED_FILES = (%b{})'):gmatch("'([^']+)'") do
        listed[#listed + 1] = path
    end

    table.insert(manifest, 'import/proxy.lua')

    H.Equal(listed, manifest)
end)

H.Test('Consumers follow the debug setting', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { debug = 'on' }"
    H.LoadManifest('server')

    local env = H.LoadImport('my-shop', 'server')
    local private = H.ImportPrivate(env)

    H.Equal(private.UgLib.Internal.Logger.IsDebug(), true)

    GlobalState:set(UgLib.Enums.GlobalState.Config, {
        settings = {
            debug = 'off',
        },
        theme = {},
    }, true)

    H.Equal(private.UgLib.Internal.Logger.IsDebug(), false)
end)

H.Test('Debug auto follows ug-core, and the ug-lib mode wins', function()
    H.Reset()
    H.LoadManifest('server')

    local Logger = UgLib.Internal.Logger
    local env = H.LoadImport('my-shop', 'server')
    local private = H.ImportPrivate(env)
    local CoreConfig = UgLib.Enums.GlobalState.CoreConfig

    H.Equal(Logger.GetDebugMode(), UgLib.Enums.DebugMode.Auto)
    H.Equal(Logger.IsDebug(), false, 'off without ug-core')

    GlobalState:set(CoreConfig, {
        core = {
            kind = 'settings',
            values = {
                debug = true,
            },
        },
    }, true)

    H.Equal(Logger.IsDebug(), true)
    H.Equal(private.UgLib.Internal.Logger.IsDebug(), true, 'consumers follow ug-core too')

    Logger.SetDebugMode(UgLib.Enums.DebugMode.Off)
    H.Equal(Logger.IsDebug(), false, 'off wins over ug-core')

    GlobalState:set(CoreConfig, {
        core = {
            kind = 'settings',
            values = {
                debug = false,
            },
        },
    }, true)
    Logger.SetDebugMode(UgLib.Enums.DebugMode.On)
    H.Equal(Logger.IsDebug(), true, 'on wins over ug-core')

    Logger.SetDebugMode(UgLib.Enums.DebugMode.Auto)
    H.Equal(Logger.IsDebug(), false)

    GlobalState:set(CoreConfig, 'garbage', true)
    H.Equal(Logger.IsDebug(), false)
end)

H.Test('Debug accepts booleans', function()
    for _, case in ipairs({ { 'true', 'on' }, { 'false', 'off' } }) do
        H.Reset()
        H.ResourceFiles['config/settings.lua'] = ('return { debug = %s }'):format(case[1])

        local lines = H.LoadManifest('server')

        for _, line in ipairs(lines) do
            H.Assert(not line:find('[ERROR]', 1, true), line)
        end

        H.Equal(UgLib.Internal.Config.Get('settings', 'debug'), case[2])
    end

    H.Reset()
    H.Convars['ug-lib:Debug'] = 'true'
    H.LoadManifest('server')
    H.Equal(UgLib.Internal.Config.Get('settings', 'debug'), 'on')
    H.Equal(UgLib.Internal.Logger.IsDebug(), true)
end)

H.Test('An invalid debug value falls back to auto', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { debug = 'yes' }"

    local lines = H.LoadManifest('server')
    local found = false

    for _, line in ipairs(lines) do
        found = found or line:find('debug', 1, true) ~= nil and line:find('[ERROR]', 1, true) ~= nil
    end

    H.Assert(found, "no error for debug = 'yes'")
    H.Equal(UgLib.Internal.Config.Get('settings', 'debug'), UgLib.Enums.DebugMode.Auto)
end)

H.Done()
