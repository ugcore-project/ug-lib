--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

---@type UgLib.Enums
local Enums = H.Any(nil)

---@param lines string[]
---@param text string
---@return boolean
local function hasLine(lines, text)
    for _, line in ipairs(lines) do
        if line:find(text, 1, true) then
            return true
        end
    end

    return false
end

---@param lines string[]
---@param text string
local function expectLine(lines, text)
    H.Assert(hasLine(lines, text), ('no line contains "%s":\n  %s'):format(text, table.concat(lines, '\n  ')))
end

---@return string[]
local function start()
    local lines = H.LoadManifest('server')
    Enums = UgLib.Enums

    return lines
end

H.Test('First start generates both files and replicates defaults', function()
    H.Reset()

    local lines = start()

    expectLine(lines, 'Config: generated config/settings.lua.')
    expectLine(lines, 'Config: generated config/theme.lua.')
    expectLine(lines, '[ug-lib] v0.0.0-test · config loaded · 2 files')
    H.Assert(not hasLine(lines, 'error'), table.concat(lines, '\n'))

    local state = H.Any(GlobalState[UgLib.Enums.GlobalState.Config])

    H.Equal(state.settings.locale, 'en')
    H.Equal(state.settings.notifyPosition, Enums.Position.TopRight)
    H.Equal(state.theme.mode, Enums.ThemeMode.Dark)
    H.Equal(state.theme.colors, {})
end)

H.Test('Generated files load back to the same values', function()
    H.Reset()
    start()

    local defaults = UgLib.Internal.Config.Get('settings')
    local generated = H.ResourceFiles['config/settings.lua']

    H.Assert(generated:find('-- Convar: ug-lib:Locale.', 1, true) ~= nil, 'convar names are documented')
    H.Assert(generated:find("-- Values: 'bottom', 'bottom-left'", 1, true) ~= nil, 'allowed values are documented')

    local lines = start()

    H.Assert(not hasLine(lines, 'generated'), 'existing files are not generated again')
    H.Equal(UgLib.Internal.Config.Get('settings'), defaults)
    H.Equal(UgLib.Internal.Config.Loader.GetEntry('settings').file, 'loaded')
end)

H.Test('Owner values merge per key', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { locale = 'pt', notifyMax = 3.0 }"

    start()

    H.Equal(UgLib.Internal.Config.Get('settings', 'locale'), 'pt')
    H.Equal(math.type(UgLib.Internal.Config.Get('settings', 'notifyMax')), 'integer')
    H.Equal(UgLib.Internal.Config.Get('settings', 'notifyDuration'), 5000)
    H.Equal(UgLib.Internal.Config.Loader.GetEntry('settings').sources.locale, 'file')
end)

H.Test('Unknown owner keys warn with a suggestion', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { notifyPositon = 'top' }"

    local lines = start()

    expectLine(lines, 'config/settings.lua: unknown option "notifyPositon" is ignored. Did you mean "notifyPosition"?')
end)

H.Test('Invalid values log an error and fall back to the default', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { notifyPosition = 'middle', notifyMax = 50 }"
    H.ResourceFiles['config/theme.lua'] = "return { colors = { primry = '1 2% 3%' } }"

    local lines = start()

    expectLine(lines, 'config/settings.lua: notifyPosition MUST be one of')
    expectLine(lines, 'config/settings.lua: notifyMax MUST be at most 20, got 50. Using default 5.')
    expectLine(lines, 'config/theme.lua: colors has an unknown token "primry". Did you mean "primary"?')
    expectLine(lines, '· 3 error(s), defaults used')

    H.Equal(UgLib.Internal.Config.Get('settings', 'notifyPosition'), Enums.Position.TopRight)
    H.Equal(UgLib.Internal.Config.Get('theme', 'colors'), {})
end)

H.Test('Valid theme colors pass', function()
    H.Reset()
    H.ResourceFiles['config/theme.lua'] = "return { colors = { primary = '217 91% 60%', border = '0 0% 20.5%' }, mode = 'light', scale = 1.25 }"

    start()

    H.Equal(UgLib.Internal.Config.Get('theme'), {
        mode = Enums.ThemeMode.Light,
        colors = {
            primary = '217 91% 60%',
            border = '0 0% 20.5%',
        },
        radius = '0.5rem',
        font = 'Inter',
        scale = 1.25,
    })
end)

H.Test('Syntax errors and non-table files use defaults', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = 'return {'
    H.ResourceFiles['config/theme.lua'] = "return 'dark'"

    local lines = start()

    expectLine(lines, 'Using defaults for settings.')
    expectLine(lines, 'config/theme.lua MUST return a table, got "dark". Using defaults for theme.')
    H.Equal(UgLib.Internal.Config.Get('settings', 'locale'), 'en')
    H.Equal(UgLib.Internal.Config.Loader.GetEntry('settings').file, 'failed')
end)

H.Test('Owner files run in a sandbox', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "string.upper = nil\nreturn { locale = (os or print) and 'fr' or 'de' }"

    start()

    H.Equal(UgLib.Internal.Config.Get('settings', 'locale'), 'de')
    H.Assert(string.upper ~= nil, 'the sandbox copies libraries')
end)

H.Test('Convars override files', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { debug = 'off', locale = 'pt' }"
    H.Convars['ug-lib:Debug'] = 'on'
    H.Convars['ug-lib:Theme:Scale'] = '0.9'
    H.Convars['ug-lib:NotifyMax'] = 'many'

    local lines = start()

    H.Equal(UgLib.Internal.Config.Get('settings', 'debug'), 'on')
    H.Equal(UgLib.Internal.Config.Get('settings', 'locale'), 'pt')
    H.Equal(UgLib.Internal.Config.Get('theme', 'scale'), 0.9)
    H.Equal(UgLib.Internal.Logger.IsDebug(), true)
    expectLine(lines, 'convar ug-lib:NotifyMax: MUST be an integer, got "many". Ignored.')
end)

H.Test('New options are reported once', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = 'return {}'
    H.Kvp['ug-lib:Config:Known:settings'] = 'locale,debug'

    local lines = start()

    expectLine(lines, 'settings.notifyMax is new. Using default 5. Add it to config/settings.lua to change it.')

    lines = start()

    H.Assert(not hasLine(lines, 'is new'), 'reported once')
end)

H.Test('Config.Get returns copies and raises for unknown names', function()
    H.Reset()
    start()

    local menuKeys = UgLib.Internal.Config.Get('settings', 'menuKeys')
    menuKeys.up = 'W'

    H.Equal(UgLib.Internal.Config.Get('settings', 'menuKeys').up, 'UP')

    H.Raises(function()
        UgLib.Internal.Config.Get('colors')
    end, 'Config.Get: unknown config "colors"')

    H.Raises(function()
        UgLib.Internal.Config.Get('settings', 'nope')
    end, 'Config.Get: unknown option "settings.nope"')
end)

H.Test('Config.Get is nil before the server loads config', function()
    H.Reset()
    H.LoadManifest('client')

    H.Equal(UgLib.Internal.Config.IsLoaded(), false)
    H.Equal(UgLib.Internal.Config.Get('settings', 'locale'), nil)
end)

H.Test('Clients apply config when it arrives', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { debug = 'on' }"
    H.LoadManifest('server')

    local payload = GlobalState[UgLib.Enums.GlobalState.Config]

    H.Reset()
    H.LoadManifest('client')

    local lines = H.Capture(function()
        GlobalState:set(UgLib.Enums.GlobalState.Config, payload, true)
    end)

    H.Equal(lines, {}, 'the ready line waits for the page')
    H.Equal(UgLib.Internal.Logger.IsDebug(), true)
    H.Equal(UgLib.Internal.Config.Get('settings', 'debug'), 'on')

    lines = H.Capture(function()
        H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Ready, {})
    end)

    H.Equal(lines, { '[ug-lib] v0.0.0-test ready (dark, en).' })
end)

H.Test('Format.Money uses settings.currency', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { currency = { symbol = '€', position = 'after' } }"
    start()

    H.Equal(UgLib.Format.Money(1500), '1,500 €')
    H.Equal(UgLib.Format.Money(1500, {
        symbol = '$',
        position = Enums.CurrencyPosition.Before,
    }), '$1,500')
end)

H.Test('Currency and menu keys are checked', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { currency = { symbol = '€', side = 'after' }, menuKeys = { up = 'UP' }, radialKey = '' }"

    local lines = start()

    expectLine(lines, 'currency has an unknown field "side", expected symbol and position')
    expectLine(lines, 'menuKeys down MUST be a key name such as "UP"')
    H.Equal(UgLib.Internal.Config.Get('settings', 'radialKey'), '')
end)

H.Test('uglib status and uglib config', function()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { locale = 'pt' }"
    H.ResourceFiles['config/theme.lua'] = 'return {}'
    H.Convars['ug-lib:Theme:Mode'] = 'light'
    start()

    local status = H.RunCommand('uglib', 0, { 'status' })

    expectLine(status, 'ug-lib v0.0.0-test')
    expectLine(status, 'locale pt, theme light, debug auto (off)')
    expectLine(status, 'config/settings.lua: loaded, 1 from file, 0 from convars')
    expectLine(status, 'config/theme.lua: loaded, 0 from file, 1 from convars')

    local config = H.RunCommand('uglib', 0, { 'config', 'theme' })

    expectLine(config, "mode = 'light' (convar ug-lib:Theme:Mode)")
    expectLine(config, "radius = '0.5rem' (default)")

    expectLine(H.RunCommand('uglib', 0, { 'config', 'nope' }), 'Unknown config "nope". Configs: settings, theme.')
    expectLine(H.RunCommand('uglib', 0, {}), 'Usage: uglib <status|config <name>>')
end)

H.Done()
