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

---@param settings? string
local function start(settings)
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = settings or "return { debug = 'on' }"
    H.LoadManifest('server')
    H.LoadManifest('client')
    H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Ready, {})
    H.TakeNui()

    Enums = UgLib.Enums
    Consumer = H.ImportPrivate(H.LoadImport('my-shop', 'client')).UgLib
end

---@return table[] notify layers of the page, in open order
local function onPage()
    local list = {}

    for _, layer in ipairs(UgLib.Internal.Layers.GetAll()) do
        if layer.kind == 'notify' then
            list[#list + 1] = layer
        end
    end

    table.sort(list, function(a, b)
        return a.seq < b.seq
    end)

    return list
end

H.Test('Show sends a rebuilt payload with defaults', function()
    start()

    local id = Consumer.Notify.Show({
        message = 'Paid **$500**',
        title = 'Bank',
        type = Enums.NotifyType.Success,
    })
    local message = H.TakeNui()[1]

    H.Equal(id, '#1')
    H.Equal(message.type, 'notify')
    H.Equal(message.action, 'open')
    H.Equal(message.id, 'my-shop/1')
    H.Equal(message.payload, {
        message = 'Paid **$500**',
        title = 'Bank',
        type = Enums.NotifyType.Success,
        style = Enums.NotifyStyle.Toast,
        position = Enums.Position.TopRight,
        duration = 5000,
        stamp = 1,
    })
end)

H.Test('Defaults follow settings, banners default to the top', function()
    start("return { notifyPosition = 'bottom-left', notifyDuration = 2000 }")

    Consumer.Notify.Show({
        message = 'a',
    })
    Consumer.Notify.Show({
        message = 'b',
        style = Enums.NotifyStyle.Banner,
    })

    local messages = H.TakeNui()

    H.Equal({ messages[1].payload.position, messages[1].payload.duration }, { Enums.Position.BottomLeft, 2000 })
    H.Equal(messages[2].payload.position, Enums.Position.Top)
end)

H.Test('A notification lives exactly its duration', function()
    start()

    Consumer.Notify.Show({
        message = 'a',
        duration = 1000,
    })
    Consumer.Notify.Show({
        message = 'b',
        duration = 0,
    })

    H.Advance(999)
    H.Equal(#onPage(), 2)
    H.Advance(1)
    H.Equal(#onPage(), 1)

    H.Advance(600000)
    H.Equal(onPage()[1].payload.message, 'b', 'duration 0 stays')
end)

H.Test('Showing an id again updates it and restarts its timer', function()
    start()

    H.Equal(Consumer.Notify.Show({
        id = 'fuel',
        message = 'Fuel 50%',
        duration = 1000,
    }), 'fuel')
    H.Advance(800)
    H.Equal(Consumer.Notify.Show({
        id = 'fuel',
        message = 'Fuel 40%',
        duration = 1000,
    }), 'fuel')

    local messages = H.TakeNui()

    H.Equal(messages[2].action, 'update')
    H.Equal(messages[2].payload.stamp, 2)
    H.Equal(#onPage(), 1)

    H.Advance(800)
    H.Equal(#onPage(), 1, 'the timer restarted')
    H.Advance(200)
    H.Equal(#onPage(), 0)

    H.Equal(Consumer.Notify.Show({
        id = 'fuel',
        message = 'Fuel 30%',
    }), 'fuel', 'a closed id shows again')
end)

H.Test('Update, Dismiss and DismissAll', function()
    start()

    local id = Consumer.Notify.Show({
        message = 'Loading',
        duration = 0,
    })

    H.Equal(Consumer.Notify.Update(id, {
        message = 'Done',
        type = Enums.NotifyType.Success,
        duration = 1000,
    }), true)
    H.Equal(onPage()[1].payload.message, 'Done')
    H.Equal(onPage()[1].payload.type, Enums.NotifyType.Success)

    H.Advance(1000)
    H.Equal(#onPage(), 0)
    H.Equal(Consumer.Notify.Update(id, {
        message = 'x',
    }), false)
    H.Equal(Consumer.Notify.Dismiss(id), false)

    local other = Consumer.Notify.Show({
        message = 'a',
        duration = 0,
    })

    Consumer.Notify.Show({
        message = 'b',
        duration = 0,
    })
    UgLib.Notify.Show({
        message = 'from ug-lib itself',
        duration = 0,
    })

    H.Equal(Consumer.Notify.Dismiss(other), true)
    H.Equal(Consumer.Notify.DismissAll(), 1)
    H.Equal(#onPage(), 1, 'only the calling resource')
end)

H.Test('At most notifyMax per anchor, oldest first', function()
    start('return { notifyMax = 2 }')

    Consumer.Notify.Show({
        message = '1',
        duration = 0,
    })
    Consumer.Notify.Show({
        message = '2',
        duration = 0,
    })
    Consumer.Notify.Show({
        message = 'other anchor',
        duration = 0,
        position = Enums.Position.Bottom,
    })
    Consumer.Notify.Show({
        message = '3',
        duration = 0,
    })

    local messages = {}

    for _, layer in ipairs(onPage()) do
        messages[#messages + 1] = layer.payload.message
    end

    H.Equal(messages, { '2', 'other anchor', '3' })

    H.Equal(Consumer.Notify.DismissAll(), 3, 'closed ones are forgotten')
end)

H.Test('Options are checked at the caller', function()
    start()

    local line = debug.getinfo(1, 'l').currentline + 2
    local message = H.Raises(function()
        Consumer.Notify.Show({
            message = '',
        })
    end, 'Notify.Show: message MUST be UTF-8 text of 1 to 1024 characters')

    H.Assert(message:find('tests/notify.lua:' .. line .. ':', 1, true) ~= nil, message)

    H.Raises(function()
        Consumer.Notify.Show(H.Any({
            message = 'a',
            positon = 'top',
        }))
    end, 'Notify.Show: unknown option "positon". Did you mean "position"?')

    H.Raises(function()
        Consumer.Notify.Show({
            message = 'a',
            type = H.Any('fatal'),
        })
    end, 'Notify.Show: type MUST be a UgLib.Enums value, got fatal')

    H.Raises(function()
        Consumer.Notify.Show({
            message = 'a',
            duration = 600001,
        })
    end, 'duration MUST be an integer from 0 to 600000 ms')

    H.Raises(function()
        Consumer.Notify.Show({
            message = ('x'):rep(1025),
        })
    end, 'message MUST be UTF-8 text')

    H.Raises(function()
        Consumer.Notify.Show({
            message = 'a',
            id = '#1',
        })
    end, 'Notify.Show: id MUST be 1 to 32 letters')

    H.Raises(function()
        Consumer.Notify.Update('#1', H.Any({
            text = 'a',
        }))
    end, 'Notify.Update: unknown option "text"')
end)

H.Test('Raw exports cannot send a bad or oversized payload', function()
    start()

    local evil = H.LoadImport('evil-resource', 'client')

    H.Raises(function()
        evil.exports['ug-lib']:UiOpen('1', 'notify', {
            message = ('x'):rep(5000),
            type = 'info',
            style = 'toast',
            position = 'top',
            duration = 1,
            stamp = 1,
        })
    end, 'Layers: invalid notify payload: message MUST be UTF-8 text')

    evil.exports['ug-lib']:UiOpen('2', 'notify', {
        message = 'hi', type = 'info', style = 'toast', position = 'top', duration = 1, stamp = 1, extra = {
            huge = true,
        },
    })

    H.Equal(UgLib.Internal.Layers.Get('evil-resource', '2').payload.extra, nil, 'unknown fields are dropped')
end)

H.Test('The page cannot answer a notification', function()
    start()

    Consumer.Notify.Show({
        message = 'a',
        duration = 0,
    })

    H.Equal(H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Resolve, {
        id = 'my-shop/1',
        result = 1,
    }), {
        ok = true,
    })
    H.Equal(#onPage(), 0, 'a forged answer only closes it')
end)

H.Test('The notify demo shows every type', function()
    start()

    H.RunCommand('uglib', 0, { 'demo', 'notify', 'compact', 'bottom-right' })

    local pageLayers = onPage()

    H.Equal(#pageLayers, 4)
    H.Equal(pageLayers[1].payload.style, Enums.NotifyStyle.Compact)
    H.Equal(pageLayers[1].payload.position, Enums.Position.BottomRight)
end)

H.Done()
