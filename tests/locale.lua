--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

---@param locale string
local function start(locale)
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = ("return { locale = '%s' }"):format(locale)
    H.LoadManifest('server')
end

H.Test('A translator reads the resource locale file', function()
    start('en')
    H.OtherFiles['my-shop'] = {
        ['locales/en.json'] = '{"shop":{"title":"Shop of {name}"},"flat.key":"Flat"}',
    }

    local t = UgLib.Locale.Create({
        resource = 'my-shop',
    })

    H.Equal(t('shop.title', {
        name = 'Bob',
    }), 'Shop of Bob')
    H.Equal(t('flat.key'), 'Flat')
    H.Equal(t('shop.title'), 'Shop of {name}')
    H.Equal(t('shop.title', {
        other = 1,
    }), 'Shop of {name}')
end)

H.Test('The language comes from settings.locale, with a fallback', function()
    start('pt')
    H.OtherFiles['my-shop'] = {
        ['locales/en.json'] = '{"hello":"Hello","bye":"Bye"}',
        ['locales/pt.json'] = '{"hello":"Olá"}',
    }

    local t = UgLib.Locale.Create({
        resource = 'my-shop',
    })

    H.Equal(UgLib.Locale.GetCode(), 'pt')
    H.Equal(t('hello'), 'Olá')
    H.Equal(t('bye'), 'Bye')
end)

H.Test('Missing keys return the key and log once at Debug', function()
    start('en')
    H.OtherFiles['my-shop'] = {
        ['locales/en.json'] = '{}',
    }
    UgLib.Internal.Logger.SetDebugMode(UgLib.Enums.DebugMode.On)

    local t = UgLib.Locale.Create({
        resource = 'my-shop',
    })
    local lines = H.Capture(function()
        H.Equal(t('nope'), 'nope')
        H.Equal(t('nope'), 'nope')
    end)

    H.Equal(lines, { '^6[DEBUG]^7 [ug-lib] Locale: my-shop has no text for "nope".' })

    UgLib.Internal.Logger.SetDebugMode(UgLib.Enums.DebugMode.Auto)
end)

H.Test('Invalid JSON logs an error', function()
    start('en')
    H.OtherFiles['my-shop'] = {
        ['locales/en.json'] = '{"broken":',
    }

    local t = UgLib.Locale.Create({
        resource = 'my-shop',
    })
    local lines = H.Capture(function()
        H.Equal(t('broken'), 'broken')
    end)

    H.Equal(lines, { '^1[ERROR]^7 [ug-lib] Locale: locales/en.json of my-shop is not valid JSON.' })
end)

H.Test('Create checks its options and keys', function()
    start('en')

    H.Raises(function()
        UgLib.Locale.Create({
            resorce = 'x',
        })
    end, 'Locale.Create: unknown option "resorce". Did you mean "resource"?')

    local t = UgLib.Locale.Create()

    H.Raises(function()
        t(H.Any(1))
    end, 'Locale: key MUST be a string, got number')
end)

H.Test('ug-lib labels and long durations use the locale', function()
    start('en')

    H.Equal(UgLib.Internal.Locale.Text('labels.confirm'), 'Confirm')
    H.Equal(UgLib.Format.Duration(3720000, {
        style = UgLib.Enums.DurationStyle.Long,
    }), '1 hour 2 minutes')
    H.Equal(UgLib.Format.Duration(1000, {
        style = UgLib.Enums.DurationStyle.Long,
    }), '1 second')
end)

H.Test('Every ug-lib locale file has the keys of en.json', function()
    local function keys(data, prefix, out)
        for key, value in pairs(data) do
            local path = prefix .. key

            if type(value) == 'table' then
                keys(value, path .. '.', out)
            else
                out[path] = true
            end
        end

        return out
    end

    local english = keys(json.decode(H.Any(LoadResourceFile('ug-lib', 'locales/en.json'))), '', {})
    local listing = package.config:sub(1, 1) == '\\' and 'dir /b locales' or 'ls locales'
    local pipe = io.popen(listing)

    H.Assert(pipe ~= nil)
    ---@cast pipe -nil

    for file in pipe:lines() do
        local data = json.decode(H.Any(LoadResourceFile('ug-lib', 'locales/' .. file)))
        local found = keys(data, '', {})

        for key in pairs(english) do
            H.Assert(found[key], ('%s has no "%s"'):format(file, key))
        end
    end

    pipe:close()
end)

H.Done()
