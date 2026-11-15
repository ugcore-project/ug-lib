--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

---@type UgLib
local Consumer = H.Any(nil)

---@type UgLib.Enums
local Enums = H.Any(nil)

local KVP_KEY = 'ug-lib:Preferences'
local Callbacks = H.Any(nil)

---@param settings? string owner config/settings.lua
---@param saved? table preferences already on the player's PC
local function start(settings, saved)
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = settings or "return { debug = 'on' }"

    if saved then
        H.Kvp[KVP_KEY] = json.encode(saved)
    end

    H.LoadManifest('server')
    H.LoadManifest('client')
    H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Ready, {})
    H.TakeNui()

    Enums = UgLib.Enums
    Callbacks = UgLib.Internal.Protocol.Nui.Callbacks
    Consumer = H.ImportPrivate(H.LoadImport('my-shop', 'client')).UgLib
end

---@param action string
---@return table[] payloads of page messages with this action, in order
local function sent(action)
    local list = {}

    for _, message in ipairs(H.TakeNui()) do
        if message.action == action then
            list[#list + 1] = message
        end
    end

    return list
end

---@param owner? string defaults to ug-lib
---@return table?
local function settingsScreen(owner)
    for _, layer in ipairs(UgLib.Internal.Layers.GetAll()) do
        if layer.kind == 'settings' and layer.owner == (owner or 'ug-lib') then
            return layer
        end
    end

    return nil
end

H.Test('Saved preferences replace positions and styles, unless fixed', function()
    start(nil, {
        notifyPosition = 'bottom-left',
        notifyStyle = 'compact',
        menuPosition = 'nowhere',
        bogus = true,
    })

    Consumer.Notify.Show({
        message = 'a',
        position = Enums.Position.Top,
    })
    Consumer.Notify.Show({
        message = 'b',
        position = Enums.Position.Top,
        fixed = true,
    })

    local opened = sent('open')

    H.Equal(opened[1].payload.position, Enums.Position.BottomLeft)
    H.Equal(opened[1].payload.style, Enums.NotifyStyle.Compact)
    H.Equal(opened[2].payload.position, Enums.Position.Top)
    H.Equal(opened[2].payload.style, Enums.NotifyStyle.Toast)

    H.Equal(UgLib.Internal.Preferences.GetSaved(Enums.PreferenceKey.MenuPosition), nil, 'invalid values are dropped')
end)

H.Test('Locked preferences and a disabled feature are ignored', function()
    local saved = {
        notifyPosition = 'bottom-left',
        notifyStyle = 'compact',
    }

    start("return { lockedSettings = { 'notifyPosition' } }", saved)
    Consumer.Notify.Show({
        message = 'a',
    })

    local payload = sent('open')[1].payload

    H.Equal(payload.position, Enums.Position.TopRight)
    H.Equal(payload.style, Enums.NotifyStyle.Compact)

    start('return { playerSettings = false }', saved)
    Consumer.Notify.Show({
        message = 'a',
    })

    payload = sent('open')[1].payload

    H.Equal(payload.position, Enums.Position.TopRight)
    H.Equal(payload.style, Enums.NotifyStyle.Toast)

    H.RunCommand('uisettings', 0, {})

    H.Equal(settingsScreen(), nil)
    H.Equal(sent('open')[1].payload.message, 'UI settings are turned off on this server.')
end)

H.Test('A change moves open layers and restyles the page at once', function()
    start()

    local Preferences = UgLib.Internal.Preferences
    local Key = Enums.PreferenceKey

    Consumer.TextUI.Show({
        text = 'Open',
    })
    H.TakeNui()

    Preferences.Set(Key.TextUIPosition, Enums.Position.Top)

    local updates = sent('update')

    H.Equal(#updates, 1)
    H.Equal(updates[1].payload.position, Enums.Position.Top)

    Preferences.Set(Key.Mode, Enums.ThemeMode.Light)
    Preferences.Set(Key.Accent, '#ff8800')
    Preferences.Set(Key.Scale, 1.25)

    local configs = sent('config')
    local last = configs[#configs].payload

    H.Equal(last.theme.mode, Enums.ThemeMode.Light)
    H.Equal(last.theme.scale, 1.25)
    H.Equal(last.accent, '#ff8800')
    H.Equal(json.decode(H.Kvp[KVP_KEY]), {
        textUIPosition = 'top',
        mode = 'light',
        accent = '#ff8800',
        scale = 1.25,
    })

    Preferences.Set(Key.TextUIPosition, nil)
    H.Equal(sent('update')[1].payload.position, Enums.Position.Bottom, 'back to what the caller asked for')

    H.Raises(function()
        Preferences.Set(Key.Accent, 'url(https://x.test)')
    end, 'Preferences.Set: invalid value')

    H.Raises(function()
        Preferences.Set(H.Any('sound'), true)
    end, 'Preferences.Set: unknown preference "sound"')
end)

H.Test('The settings screen lists unlocked preferences and saves checked changes', function()
    start("return { debug = 'on', lockedSettings = { 'scale' } }", {
        accent = '#112233',
    })

    H.RunCommand('uisettings', 0, {})

    local layer = assert(settingsScreen(), 'settings screen not open')
    local Key = Enums.PreferenceKey
    local Preferences = UgLib.Internal.Preferences

    H.Equal(layer.payload.keys[1], Key.Mode)
    H.Equal(layer.payload.keys[3], Key.NotifyPosition, 'locked scale is not listed')
    H.Equal(layer.payload.values.accent, '#112233')
    H.Equal(layer.payload.defaults.notifyPosition, Enums.Position.TopRight)
    H.Equal(layer.payload.labels['settings.title'], 'UI settings')
    H.Equal(layer.payload.labels['positions.top-left'], 'Top left')

    local function post(data)
        return H.PostNui(Callbacks.Event, {
            id = layer.key,
            data = data,
        })
    end

    H.Equal(post({
        key = Key.Mode,
        value = Enums.ThemeMode.Light,
    }), {
        ok = true,
    })
    H.Equal(post({
        key = Key.Accent,
        value = '#FF8800',
    }), {
        ok = true,
    })
    H.Equal(Preferences.GetSaved(Key.Mode), Enums.ThemeMode.Light)
    H.Equal(Preferences.GetSaved(Key.Accent), '#ff8800')

    -- Forged events change nothing.
    for _, data in ipairs({
        {
            key = Key.Scale,
            value = 1.25,
        },
        {
            key = Key.Accent,
            value = 'url(https://x.test)',
        },
        {
            key = Key.NotifyPosition,
            value = 'off-screen',
        },
        {
            key = 'sounds',
            value = true,
        },
        'reset',
    }) do
        H.Equal(post(data), {
            ok = false,
        })
    end

    H.Equal(Preferences.GetSaved(Key.Scale), nil)
    H.Equal(Preferences.GetSaved(Key.Accent), '#ff8800')

    H.Equal(post({
        key = Key.Accent,
        clear = true,
    }), {
        ok = true,
    })
    H.Equal(Preferences.GetSaved(Key.Accent), nil)

    H.TakeNui()
    H.Equal(post({
        resetAll = true,
    }), {
        ok = true,
    })
    H.Equal(Preferences.GetSaved(Key.Mode), nil, 'reset clears everything')
    H.Equal(sent('update')[1].payload.values, {}, 'the screen shows the reset')

    H.PostNui(Callbacks.Resolve, {
        id = layer.key,
        result = true,
    })
    H.Advance(0)
    H.Equal(settingsScreen(), nil)
end)

H.Test('Resources open the settings with Ui.OpenSettings, and a forged payload is replaced', function()
    start()

    Consumer.Ui.OpenSettings()

    local layer = assert(settingsScreen(), 'settings screen not open')

    H.Equal(layer.payload.keys[1], Enums.PreferenceKey.Mode)

    UgLib.Ui.CloseAll()

    local raw = H.LoadImport('evil-resource', 'client')

    raw.exports['ug-lib']:UiOpen('x1', 'settings', {
        keys = { 'everything' },
        labels = {
            ['settings.title'] = '<img src=x>',
        },
    })

    layer = assert(settingsScreen('evil-resource'), 'settings screen not open')

    H.Equal(layer.payload.keys[1], Enums.PreferenceKey.Mode)
    H.Equal(layer.payload.labels['settings.title'], 'UI settings')
end)

H.Done()
