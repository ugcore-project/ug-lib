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

H.Test('Clipboard.Copy sends the text to the page', function()
    start()

    Consumer.Clipboard.Copy('UG 001')

    H.Equal(H.TakeNui(), {
        {
            type = 'system',
            action = 'clipboard',
            payload = 'UG 001',
        },
    })

    H.Raises(function()
        Consumer.Clipboard.Copy('')
    end, 'Clipboard.Copy expects UTF-8 text of 1 to 4096 characters')

    H.Raises(function()
        Consumer.Clipboard.Copy(('x'):rep(4097))
    end, 'Clipboard.Copy expects UTF-8 text')

    local raw = H.LoadImport('evil-resource', 'client')

    H.Raises(function()
        raw.exports['ug-lib']:UiCopy({ 'not text' })
    end, 'Clipboard.Copy expects UTF-8 text')
end)

H.Test('Ui.IsOpen by type and for modals', function()
    start()

    H.Equal(Consumer.Ui.IsOpen(), false)

    Consumer.Notify.Show({
        message = 'hi',
        duration = 0,
    })

    H.Equal(Consumer.Ui.IsOpen(Enums.UiType.Notify), true)
    H.Equal(Consumer.Ui.IsOpen(Enums.UiType.Dialog), false)
    H.Equal(Consumer.Ui.IsOpen(), false, 'a notification is not a modal')

    H.Thread(function()
        Consumer.Dialog.Confirm({
            title = 'Sure?',
        })
    end)

    H.Equal(Consumer.Ui.IsOpen(), true)

    H.Raises(function()
        Consumer.Ui.IsOpen(H.Any('dialogue'))
    end, 'Ui.IsOpen: kind MUST be one of')
end)

H.Test('Ui.CloseAll closes every resource and ends waiting calls', function()
    start()

    local other = H.ImportPrivate(H.LoadImport('my-bank', 'client')).UgLib
    local thread = H.Thread(function()
        return table.pack(other.Dialog.Confirm({
            title = 'Pay?',
        }))
    end)

    Consumer.Notify.Show({
        message = 'hi',
        duration = 0,
    })
    Consumer.Ui.CloseAll()

    H.Equal(thread.result, {
        false,
        Enums.CloseReason.Closed,
        n = 2,
    })
    H.Equal(UgLib.Internal.Layers.GetAll(), {})
end)

H.Test('Per-call colors and positions reach the page, raw CSS never does', function()
    start()

    Consumer.Notify.Show({
        message = 'hi',
        color = '#ff8800',
    })
    Consumer.TextUI.Show({
        text = 'Open',
        color = Enums.Color.Success,
    })
    Consumer.Menu.Register({
        id = 'm',
        title = 'Menu',
        color = '#112233',
        items = {
            {
                label = 'A',
                iconColor = Enums.Color.Warning,
            },
        },
    })
    Consumer.Menu.Open('m')
    Consumer.Context.Register({
        id = 'c',
        title = 'Context',
        position = Enums.Position.TopLeft,
        items = {
            {
                title = 'A',
                iconColor = '#00ff00',
            },
        },
    })
    Consumer.Context.Open('c')

    local sent = {}

    local function collect()
        for _, message in ipairs(H.TakeNui()) do
            if message.action == 'open' then
                sent[message.type] = message.payload
            end
        end
    end

    collect()
    UgLib.Ui.CloseAll()

    CreateThread(function()
        Consumer.SkillCheck.Start({
            Enums.Difficulty.Easy,
        }, nil, {
            position = Enums.Position.Bottom,
            color = Enums.Color.Destructive,
        })
    end)

    H.Advance(0)
    collect()

    H.Equal(sent.notify.color, '#ff8800')
    H.Equal(sent.textui.color, Enums.Color.Success)
    H.Equal(sent.menu.color, '#112233')
    H.Equal(sent.menu.items[1].iconColor, Enums.Color.Warning)
    H.Equal(sent.context.position, Enums.Position.TopLeft)
    H.Equal(sent.context.items[1].iconColor, '#00ff00')
    H.Equal(sent.skillcheck.position, Enums.Position.Bottom)
    H.Equal(sent.skillcheck.color, Enums.Color.Destructive)

    for _, bad in ipairs({ 'red', '#fff', 'url(https://x.test/a.png)', '#ff0000; color: red' }) do
        H.Raises(function()
            Consumer.Notify.Show({
                message = 'hi',
                color = bad,
            })
        end, 'color MUST be a UgLib.Enums.Color value or a #rrggbb hex')
    end

    H.Raises(function()
        Consumer.Menu.Register({
            id = 'bad',
            title = 'Menu',
            items = {
                {
                    label = 'A',
                    iconColor = 'blue',
                },
            },
        })
    end, 'iconColor MUST be a UgLib.Enums.Color value or a #rrggbb hex')

    local raw = H.LoadImport('evil-resource', 'client')

    H.Raises(function()
        raw.exports['ug-lib']:UiOpen('x1', 'textui', {
            text = 'Hi',
            style = 'pill',
            position = 'bottom',
            color = 'url(https://x.test)',
        })
    end, 'color MUST be')
end)

H.Test('Every UiType is a NUI type', function()
    start()

    local types = {}

    for _, value in pairs(UgLib.Internal.Protocol.Nui.Types) do
        types[value] = true
    end

    for key, value in pairs(Enums.UiType) do
        H.Assert(types[value], key .. ' is not a NUI type')
    end
end)

H.Done()
