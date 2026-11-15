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

local function start()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { debug = 'on' }"
    H.LoadManifest('server')
    H.LoadManifest('client')
    H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Ready, {})
    H.TakeNui()

    Enums = UgLib.Enums
    Consumer = H.ImportPrivate(H.LoadImport('my-shop', 'client')).UgLib
end

---@return table[]
local function prompts()
    local list = {}

    for _, layer in ipairs(UgLib.Internal.Layers.GetAll()) do
        if layer.kind == 'textui' then
            list[#list + 1] = layer
        end
    end

    return list
end

H.Test('The demo closes on E', function()
    start()

    H.RunCommand('uglib', 0, { 'demo', 'textui' })
    H.Advance(0)
    H.Equal(#prompts(), 1)

    H.World.pressed[38] = true

    local lines = H.Capture(function()
        H.Advance(0)
    end)

    H.World.pressed[38] = nil
    H.Equal(#prompts(), 0)
    H.Equal(lines, { '[ug-lib] textui demo: E pressed' })
end)

H.Test('Show sends once, repeats send nothing', function()
    start()

    for _ = 1, 60 do
        Consumer.TextUI.Show({
            text = 'Open the shop',
            key = 'E',
            style = Enums.TextUIStyle.Keybind,
        })
    end

    local messages = H.TakeNui()

    H.Equal(#messages, 1)
    H.Equal(messages[1].payload, {
        text = 'Open the shop',
        key = 'E',
        style = Enums.TextUIStyle.Keybind,
        position = Enums.Position.Bottom,
    })
    H.Equal(Consumer.TextUI.IsShown(), true)
end)

H.Test('A change updates in place', function()
    start()

    Consumer.TextUI.Show({
        text = 'Open',
    })
    Consumer.TextUI.Show({
        text = 'Close',
    })

    local messages = H.TakeNui()

    H.Equal({ messages[1].action, messages[2].action }, { 'open', 'update' })
    H.Equal(#prompts(), 1)
end)

H.Test('Hide closes it and the next show opens again', function()
    start()

    Consumer.TextUI.Show({
        text = 'Open',
    })
    Consumer.TextUI.Hide()

    H.Equal(Consumer.TextUI.IsShown(), false)
    H.Equal(#prompts(), 0)

    Consumer.TextUI.Show({
        text = 'Open',
    })

    H.Equal(#prompts(), 1)
    Consumer.TextUI.Hide()
    Consumer.TextUI.Hide()
end)

H.Test('One prompt across resources', function()
    start()

    local other = H.ImportPrivate(H.LoadImport('my-garage', 'client')).UgLib

    Consumer.TextUI.Show({
        text = 'Shop',
    })
    other.TextUI.Show({
        text = 'Garage',
    })

    H.Equal(#prompts(), 1)
    H.Equal(prompts()[1].payload.text, 'Garage')
    H.Equal(Consumer.TextUI.IsShown(), false, 'the replaced resource knows')

    Consumer.TextUI.Show({
        text = 'Shop',
    })

    H.Equal(prompts()[1].payload.text, 'Shop', 'showing again takes it back')
end)

H.Test('A stopped resource loses its prompt', function()
    start()

    Consumer.TextUI.Show({
        text = 'Shop',
    })
    H.TriggerEvent('onResourceStop', nil, 'my-shop')

    H.Equal(#prompts(), 0)
end)

H.Test('Options are checked', function()
    start()

    H.Raises(function()
        Consumer.TextUI.Show({
            text = '',
        })
    end, 'TextUI.Show: text MUST be UTF-8 text of 1 to 256 characters')

    H.Raises(function()
        Consumer.TextUI.Show(H.Any({
            text = 'a',
            keyCap = 'E',
        }))
    end, 'TextUI.Show: unknown option "keyCap". Did you mean "key"?')

    H.Raises(function()
        Consumer.TextUI.Show({
            text = 'a',
            style = H.Any('bubble'),
        })
    end, 'style MUST be a UgLib.Enums.TextUIStyle value, got bubble')
end)

H.Done()
