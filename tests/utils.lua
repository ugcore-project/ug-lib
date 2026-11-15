--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

H.LoadManifest('server')

local Utils = UgLib.Internal.Utils
local Logger = UgLib.Internal.Logger

---@param options any
local function publicApi(options)
    Utils.CheckOptions('Demo.Open', options, {
        title = true,
        timeout = true,
    })
end

---@param value any
local function publicEnum(value)
    Utils.CheckEnum('Demo.Open', 'position', value, UgLib.Enums.Position, true)
end

H.Test('Raise prefixes the message and formats arguments', function()
    local message = H.Raises(function()
        Utils.Raise(1, 'bad %s %d', 'value', 3)
    end)

    H.Assert(message:find('[ug-lib] bad value 3', 1, true) ~= nil, message)
end)

H.Test('Raise points to the caller', function()
    local function api()
        Utils.Raise(2, 'wrong usage')
    end

    local line = debug.getinfo(1, 'l').currentline + 2
    local message = H.Raises(function()
        api()
    end)

    H.Assert(message:find(':' .. line .. ':', 1, true) ~= nil, message)
end)

H.Test('CheckOptions accepts known keys', function()
    publicApi({
        title = 'x',
        timeout = 5,
    })
    publicApi({})
end)

H.Test('CheckOptions rejects unknown keys with a suggestion', function()
    H.Raises(function()
        publicApi({
            titel = 'x',
        })
    end, 'Demo.Open: unknown option "titel". Did you mean "title"?')
end)

H.Test('CheckOptions rejects unknown keys without a close match', function()
    local message = H.Raises(function()
        publicApi({
            completelyDifferent = true,
        })
    end, 'unknown option "completelyDifferent".')

    H.Assert(not message:find('Did you mean', 1, true), message)
end)

H.Test('CheckOptions rejects non-string keys and non-tables', function()
    H.Raises(function()
        publicApi({ 'positional' })
    end, 'unknown option "1"')

    H.Raises(function()
        publicApi('title')
    end, 'Demo.Open expects an options table, got string')
end)

H.Test('CheckOptions points to the caller of the public function', function()
    local line = debug.getinfo(1, 'l').currentline + 2
    local message = H.Raises(function()
        publicApi({
            nope = true,
        })
    end)

    H.Assert(message:find(':' .. line .. ':', 1, true) ~= nil, message)
end)

H.Test('CheckEnum accepts values and optional nil', function()
    publicEnum(UgLib.Enums.Position.TopLeft)
    publicEnum(nil)
end)

H.Test('CheckEnum rejects other values with a suggestion', function()
    H.Raises(function()
        publicEnum('top-lef')
    end, 'Demo.Open: position MUST be one of bottom, bottom-left')

    H.Raises(function()
        publicEnum('top-lef')
    end, 'got top-lef. Did you mean "top-left"?')

    H.Raises(function()
        publicEnum(H.Any(5))
    end, 'got 5.')
end)

H.Test('Logger prints levels with the ug-lib tag', function()
    local lines = H.Capture(function()
        Logger.Info('hello %s', 'world')
        Logger.Warn('careful')
        Logger.Error('broken')
    end)

    H.Equal(lines, {
        '^5[INFO]^7 [ug-lib] hello world',
        '^3[WARN]^7 [ug-lib] careful',
        '^1[ERROR]^7 [ug-lib] broken',
    })
end)

H.Test('Logger prints Debug only when enabled', function()
    H.Equal(Logger.IsDebug(), false)
    H.Equal(H.Capture(function()
        Logger.Debug('hidden')
    end), {})

    Logger.SetDebugMode(UgLib.Enums.DebugMode.On)

    H.Equal(H.Capture(function()
        Logger.Debug('shown %d', 1)
    end), { '^6[DEBUG]^7 [ug-lib] shown 1' })

    Logger.SetDebugMode(UgLib.Enums.DebugMode.Auto)

    H.Raises(function()
        Logger.SetDebugMode(H.Any(true))
    end, 'Logger.SetDebugMode')
end)

H.Done()
