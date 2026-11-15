--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

local OWNER = 'my-shop'

---@type UgLib.Internal.Layers
local Layers = H.Any(nil)

---@type table
local Protocol = H.Any(nil)

---@param result any
---@return boolean ok
---@return any value
local function pickIndex(_, result)
    return math.type(result) == 'integer' and result >= 1 and result <= 3, result
end

---@param settings? string
local function start(settings)
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = settings or "return { debug = 'on' }"
    H.LoadManifest('server')
    H.LoadManifest('client')

    Layers = UgLib.Internal.Layers
    Protocol = UgLib.Internal.Protocol.Nui
    Layers.RegisterType('dialog', {
        modal = true,
        focus = Protocol.Focus.Cursor,
        validate = pickIndex,
        validateEvent = pickIndex,
    })
    Layers.RegisterType('menu', {
        modal = false,
        focus = Protocol.Focus.Keyboard,
        keepInput = true,
    })
    Layers.RegisterType('notify', {
        modal = false,
    })
end

local function ready()
    H.PostNui(Protocol.Callbacks.Ready, {})
end

---@param text string
---@return table<string, string>
local function readConstants(text)
    local values = {}

    for key, value in text:gmatch('(%w+):%s*"([^"]+)"') do
        values[key] = value
    end

    return values
end

H.Test('the page sits above every frame and below a frame another resource focuses', function()
    start()
    H.Advance(0)

    H.Equal(H.Nui.zIndex, 100000)

    H.Nui.otherFocus = true
    H.Advance(500)
    H.Equal(H.Nui.zIndex, 9999)

    H.Nui.otherFocus = false
    H.Nui.zIndex = 0
    H.Advance(500)
    H.Equal(H.Nui.zIndex, 100000)

    -- Only a focus change sends it again, so an idle client posts nothing to the root page.
    H.Nui.zIndex = 0
    H.Advance(500)
    H.Equal(H.Nui.zIndex, 0)

    -- The frame exists once the page is ready: the value applied before MAY have been lost.
    ready()
    H.Equal(H.Nui.zIndex, 100000)
end)

H.Test('Protocol names match web/src/types/nui.ts', function()
    start()

    local source = assert(io.open('web/src/types/nui.ts', 'rb')):read('a')

    for name, group in pairs({
        NuiType = Protocol.Types,
        NuiAction = Protocol.Actions,
        NuiCallback = Protocol.Callbacks,
        DialogVariant = Protocol.DialogVariants,
    }) do
        local block = source:match('export const ' .. name .. ' = (%b{})')

        H.Assert(block ~= nil, name .. ' is missing in nui.ts')
        H.Equal(readConstants(block), group, name)
    end
end)

H.Test('Messages wait for the page, config first', function()
    start()

    Layers.Open(OWNER, '1', 'notify', {
        text = 'hi',
    })

    H.Equal(H.TakeNui(), {})

    local lines = H.Capture(ready)
    local messages = H.TakeNui()

    H.Equal(#messages, 2)
    H.Equal({ messages[1].type, messages[1].action }, { Protocol.Types.System, Protocol.Actions.Config })
    H.Equal(messages[2], {
        type = 'notify',
        action = Protocol.Actions.Open,
        id = 'my-shop/1',
        payload = {
            text = 'hi',
        },
    })
    H.Equal(lines, { '[ug-lib] v0.0.0-test ready (dark, en).' })

    H.Equal(H.Capture(ready), {}, 'a second Ready changes nothing')
end)

H.Test('The config carries theme, page settings and labels', function()
    start("return { locale = 'en', notifyPosition = 'top-left' }")
    ready()

    local config = H.Nui.messages[1].payload

    H.Equal(config.theme.mode, UgLib.Enums.ThemeMode.Dark)
    H.Equal(config.settings.notifyPosition, UgLib.Enums.Position.TopLeft)
    H.Equal(config.settings.cacheInterval, nil, 'only page settings')
    H.Equal(config.labels.confirm, 'Confirm')
    H.Equal(config.locale, 'en')

    H.TakeNui()
    GlobalState:set(UgLib.Enums.GlobalState.Config, {
        settings = {
            locale = 'en',
            debug = 'on',
        },
        theme = {
            mode = 'light',
        },
    }, true)

    H.Equal(H.Nui.messages[1].payload.theme.mode, 'light', 'a new config reaches a ready page at once')
end)

H.Test('Layers update and close on the page', function()
    start()
    ready()
    H.TakeNui()

    Layers.Open(OWNER, '1', 'notify', {
        text = 'a',
    })
    Layers.Update(OWNER, '1', {
        text = 'b',
    })
    Layers.Close(OWNER, '1', UgLib.Enums.CloseReason.Closed)

    local actions = {}

    for index, message in ipairs(H.TakeNui()) do
        actions[index] = message.action .. ' ' .. message.id
    end

    H.Equal(actions, { 'open my-shop/1', 'update my-shop/1', 'close my-shop/1' })
end)

H.Test('The top layer that wants input takes focus', function()
    start()
    ready()

    Layers.Open(OWNER, 'toast', 'notify', {})
    H.Equal(H.Nui.focus, {
        focus = false,
        cursor = false,
        keepInput = false,
    })
    H.Equal(H.Nui.focusCalls, 0, 'natives only run on change')

    Layers.Open(OWNER, 'dialog', 'dialog', {})
    H.Equal(H.Nui.focus, {
        focus = true,
        cursor = true,
        keepInput = false,
    })

    Layers.Open(OWNER, 'menu', 'menu', {})
    H.Equal(H.Nui.focus, {
        focus = true,
        cursor = false,
        keepInput = true,
    })

    Layers.Close(OWNER, 'menu', UgLib.Enums.CloseReason.Closed)
    H.Equal(H.Nui.focus, {
        focus = true,
        cursor = true,
        keepInput = false,
    })

    Layers.CloseAll()
    H.Equal(H.Nui.focus, {
        focus = false,
        cursor = false,
        keepInput = false,
    })
end)

H.Test('Answers from the page reach the owner validated', function()
    start()
    ready()

    local answers = {}

    AddEventHandler(UgLib.Internal.Protocol.ResponseEvent:format(OWNER), function(id, result, reason, final)
        answers[#answers + 1] = { id, result, reason, final }
    end)

    Layers.Open(OWNER, '1', 'dialog', {})

    H.Equal(H.PostNui(Protocol.Callbacks.Event, {
        id = 'my-shop/1',
        data = 2,
    }), {
        ok = true,
    })
    H.Equal(H.PostNui(Protocol.Callbacks.Resolve, {
        id = 'my-shop/1',
        result = 3,
    }), {
        ok = true,
    })
    H.Equal(answers, { { '1', 2, nil, false }, { '1', 3, nil, true } })
    H.Equal(H.Nui.focus.focus, false)

    Layers.Open(OWNER, '2', 'dialog', {})
    H.PostNui(Protocol.Callbacks.Resolve, {
        id = 'my-shop/2',
        result = 99,
    })

    H.Equal(answers[3], { '2', nil, UgLib.Enums.CloseReason.Cancelled, true })

    Layers.Open(OWNER, '3', 'dialog', {})
    H.PostNui(Protocol.Callbacks.Close, {
        id = 'my-shop/3',
    })

    H.Equal(answers[4], { '3', nil, UgLib.Enums.CloseReason.Cancelled, true })
end)

H.Test('Forged callbacks get a reply and change nothing', function()
    start()
    ready()

    Layers.Open(OWNER, '1', 'dialog', {})

    for _, data in ipairs({
        H.Any(nil),
        H.Any('my-shop/1'),
        {
            id = 5,
        },
        {
            id = ('x'):rep(101),
        },
        {
            id = 'other/1',
            result = 1,
        },
        {
            id = '',
        },
    }) do
        H.Equal(H.PostNui(Protocol.Callbacks.Resolve, data), {
            ok = false,
        })
        H.Equal(H.PostNui(Protocol.Callbacks.Event, data), {
            ok = false,
        })
        H.Equal(H.PostNui(Protocol.Callbacks.Close, data), {
            ok = false,
        })
    end

    H.Equal(Layers.Get(OWNER, '1') ~= nil, true)
end)

H.Test('Events are limited per layer per second', function()
    start()
    ready()

    local events = 0

    AddEventHandler(UgLib.Internal.Protocol.ResponseEvent:format(OWNER), function(_, _, _, final)
        if not final then
            events = events + 1
        end
    end)

    Layers.Open(OWNER, '1', 'dialog', {})

    for _ = 1, 30 do
        H.PostNui(Protocol.Callbacks.Event, {
            id = 'my-shop/1',
            data = 1,
        })
    end

    H.Equal(events, Protocol.EventsPerSecond)

    H.Advance(1000)
    H.PostNui(Protocol.Callbacks.Event, {
        id = 'my-shop/1',
        data = 1,
    })

    H.Equal(events, Protocol.EventsPerSecond + 1)
end)

H.Test('Stopping ug-lib clears the page and releases focus', function()
    start()
    ready()

    Layers.Open(OWNER, '1', 'dialog', {})
    H.TakeNui()
    H.TriggerEvent('onResourceStop', nil, 'ug-lib')

    H.Equal(H.TakeNui()[1], {
        type = Protocol.Types.System,
        action = Protocol.Actions.CloseAll,
    })
    H.Equal(H.Nui.focus.focus, false)
end)

H.Test('uglib state, close and demo', function()
    start()
    ready()

    Layers.Open(OWNER, '1', 'dialog', {})

    local state = H.RunCommand('uglib', 0, { 'state' })

    H.Equal(state[1], 'ug-lib v0.0.0-test, NUI ready')
    H.Equal(state[2], '  focus true, cursor true, keep input false')
    H.Equal(state[3], '  modal my-shop/1')
    H.Equal(state[5], '    dialog my-shop/1')
    H.Assert(state[6]:find('cache ped 100, server id 1, vehicle false', 1, true) ~= nil, state[6])

    H.Equal(H.RunCommand('uglib', 0, { 'close' }), { 'Closed every layer.' })
    H.Equal(Layers.GetAll(), {})
    local list = H.RunCommand('uglib', 0, { 'demo' })[1]

    H.Assert(list:find('^Demos: ') and list:find('notify', 1, true), list)

    local ran = nil

    UgLib.Internal.Demos.Register('test', function(args)
        ran = args
    end)

    H.RunCommand('uglib', 0, { 'demo', 'test', 'a', 'b' })

    H.Equal(ran, { 'a', 'b' })
    H.Equal(H.RunCommand('uglib', 0, { 'nope' }), { 'Usage: uglib <state|close|demo <name>>' })
end)

H.Test('uglib needs debug', function()
    start("return { debug = 'off' }")

    H.Equal(H.RunCommand('uglib', 0, {
        'state',
    }), {
        "uglib needs debug. Set debug = 'on' in config/settings.lua of ug-lib, or keep 'auto' and turn on ug-core debug.",
    })
end)

H.Done()
