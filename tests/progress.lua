--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

local PED = 100

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

---@param options table
---@param ui? UgLib
---@return TestThread
local function run(options, ui)
    return H.Thread(function()
        return table.pack((ui or Consumer).Progress.Start(options))
    end)
end

---@return table?
local function bar()
    for _, layer in ipairs(UgLib.Internal.Layers.GetAll()) do
        if layer.kind == 'progress' then
            return layer
        end
    end

    return nil
end

H.Test('A progress completes after its duration', function()
    start()

    local thread = run({
        duration = 1000,
        label = 'Repairing',
    })

    H.Equal(bar().payload, {
        label = 'Repairing',
        duration = 1000,
        style = Enums.ProgressStyle.Bar,
        position = Enums.Position.Bottom,
        canCancel = true,
        stamp = 1,
    })
    H.Equal(Consumer.Progress.IsActive(), true)

    H.Advance(500)
    H.Equal(thread.done, false)
    H.Advance(500)
    H.Advance(0)

    H.Equal(thread.result, {
        true,
        nil,
        n = 2,
    })
    H.Equal(bar(), nil)
    H.Equal(Consumer.Progress.IsActive(), false)
end)

H.Test('Controls are disabled every frame', function()
    start()

    run({
        duration = 1000,
        disable = {
            mouse = true,
            car = false,
        },
    })
    H.World.disabled = {}
    H.Advance(0)

    H.Equal(H.World.disabled[32], 1, 'move')
    H.Equal(H.World.disabled[21], 1, 'sprint')
    H.Equal(H.World.disabled[24], 1, 'combat')
    H.Equal(H.World.disabled[1], 1, 'mouse when asked')
    H.Equal(H.World.disabled[71], nil, 'car when not')
end)

H.Test('Cancel paths', function()
    start()

    local cancelled = run({
        duration = 5000,
    })

    H.Equal(Consumer.Progress.Cancel(), true)
    H.Advance(0)
    H.Equal(cancelled.result, {
        false,
        Enums.CloseReason.Cancelled,
        n = 2,
    })
    H.Equal(Consumer.Progress.Cancel(), false)

    local moved = run({
        duration = 5000,
        cancelOnMove = true,
    })

    H.World.disabled = {}
    H.Advance(0)
    H.Equal(H.World.disabled[32], nil, 'cancelOnMove keeps movement')

    H.World.pressed[32] = true
    H.Advance(0)
    H.Equal(moved.result, {
        false,
        Enums.CloseReason.Cancelled,
        n = 2,
    })
    H.World.pressed[32] = nil

    local dead = run({
        duration = 5000,
    })

    H.World.entities[PED].dead = true
    H.Advance(0)
    H.Equal(dead.result, {
        false,
        Enums.CloseReason.Cancelled,
        n = 2,
    })

    local allowed = run({
        duration = 100,
        allowDead = true,
    })

    H.Advance(100)
    H.Advance(0)
    H.Equal(allowed.result[1], true)
end)

H.Test('The cancel key cancels a cancellable progress only', function()
    start()

    local thread = run({
        duration = 5000,
        canCancel = false,
    })

    H.RunCommand('+ug-lib-cancel', 0, {})
    H.RunCommand('-ug-lib-cancel', 0, {})
    H.Advance(0)
    H.Equal(thread.done, false)

    Consumer.Progress.Cancel()
    H.Advance(0)

    local cancellable = run({
        duration = 5000,
    })

    H.RunCommand('+ug-lib-cancel', 0, {})
    H.RunCommand('-ug-lib-cancel', 0, {})
    H.Advance(0)

    H.Equal(cancellable.result, {
        false,
        Enums.CloseReason.Cancelled,
        n = 2,
    })
    H.Equal(H.World.mappings[1], {
        '+ug-lib-cancel',
        'Cancel the current action',
        'keyboard',
        'X',
        n = 4,
    })
end)

H.Test('One progress at a time across resources', function()
    start()

    local other = H.ImportPrivate(H.LoadImport('my-garage', 'client')).UgLib
    local first = run({
        duration = 1000,
    })
    local second = run({
        duration = 1000,
    }, other)
    local own = run({
        duration = 1000,
    })

    H.Equal(second.result, {
        false,
        Enums.CloseReason.Busy,
        n = 2,
    })
    H.Equal(own.result, {
        false,
        Enums.CloseReason.Busy,
        n = 2,
    })

    H.Advance(1000)
    H.Advance(0)
    H.Equal(first.result[1], true)
end)

H.Test('Animations and props start and are cleaned up', function()
    start()
    H.AddAsset('animDict', 'mini@repair')
    H.AddAsset('model', 'prop_tool_wrench')

    local thread = run({
        duration = 1000,
        animation = {
            dict = 'mini@repair',
            name = 'fixing_a_ped',
        },
        props = {
            {
                model = 'prop_tool_wrench',
            },
        },
    })

    H.Advance(0)

    local prop = nil

    for handle, entity in pairs(H.World.entities) do
        if entity.pool == 'CObject' then
            prop = handle
        end
    end

    H.Assert(prop ~= nil, 'the prop exists while running')
    H.Equal(H.World.calls[1].name, 'TaskPlayAnim')
    H.Equal(H.World.calls[1].args[7], 49, 'upper body loop by default')

    Consumer.Progress.Cancel()
    H.Advance(0)

    H.Equal(thread.result[1], false)
    H.Equal(H.World.entities[prop], nil)
    H.Equal(H.CallNames()[2], 'StopAnimTask')
end)

H.Test('ug-lib closing the bar ends the progress', function()
    start()

    local thread = run({
        duration = 5000,
    })

    UgLib.Internal.Layers.CloseAll()
    H.Advance(0)

    H.Equal(thread.result, {
        false,
        Enums.CloseReason.Closed,
        n = 2,
    })
end)

H.Test('Options are checked', function()
    start()

    H.Raises(function()
        Consumer.Progress.Start({
            duration = 1000,
        })
    end, 'UgLib.Progress.Start MUST run in a thread.')

    local checks = {
        {
            {
                duration = 50,
            },
            'duration MUST be an integer from 100 to 600000 ms',
        },
        {
            {
                duration = 1000,
                style = 'pie',
            },
            'style MUST be a UgLib.Enums.ProgressStyle value',
        },
        {
            {
                duration = 1000,
                disable = {
                    walk = true,
                },
            },
            'disable.walk is not a known control group',
        },
        {
            {
                duration = 1000,
                animation = {
                    dict = 'a',
                },
            },
            'animation MUST be { dict, name, flag? } or { scenario }',
        },
        {
            {
                duration = 1000,
                animation = {
                    scenario = 'A',
                    dict = 'b',
                    name = 'c',
                },
            },
            'animation MUST be',
        },
        {
            {
                duration = 1000,
                props = { {}, {}, {}, {}, {} },
            },
            'props MUST be an array of at most 4 props',
        },
        {
            {
                duration = 1000,
                lable = 'x',
            },
            'unknown option "lable". Did you mean "label"?',
        },
    }

    for _, case in ipairs(checks) do
        local thread = run(case[1])

        H.Assert(thread.error and thread.error:find(case[2], 1, true), ('expected "%s", got %s'):format(case[2], tostring(thread.error)))
    end

    local raw = H.LoadImport('evil-resource', 'client')

    H.Raises(function()
        raw.exports['ug-lib']:UiOpen('1', 'progress', {
            duration = 1,
            style = 'bar',
            position = 'bottom',
            canCancel = true,
            stamp = 1,
        })
    end, 'Layers: invalid progress payload: duration MUST be')
end)

H.Done()
