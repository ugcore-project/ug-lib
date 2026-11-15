--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

---@type UgLib
local Consumer = H.Any(nil)

local function start()
    H.Reset()
    H.LoadManifest('client')
    Consumer = H.ImportPrivate(H.LoadImport('my-shop', 'client')).UgLib
end

---@return table log
---@return string command
local function register()
    local log = {}
    local command = Consumer.Keybind.Register({
        name = 'open',
        label = 'Open the shop',
        defaultKey = 'E',
        onPressed = function()
            log[#log + 1] = 'pressed'
        end,
        onReleased = function()
            log[#log + 1] = 'released'
        end,
    })

    return log, command
end

H.Test('Register maps a key in the consumer', function()
    start()

    local log, command = register()

    H.Equal(command, '+my-shop-open')
    H.Equal(H.World.mappings[#H.World.mappings], {
        '+my-shop-open',
        'Open the shop',
        'keyboard',
        'E',
        n = 4,
    })

    H.RunCommand('+my-shop-open', 0, {})
    H.Equal(Consumer.Keybind.IsPressed('open'), true)
    H.RunCommand('+my-shop-open', 0, {})
    H.RunCommand('-my-shop-open', 0, {})

    H.Equal(log, { 'pressed', 'released' })
    H.Equal(Consumer.Keybind.IsPressed('open'), false)
end)

H.Test('GetKey reads the bound key, and falls back to the default for icons', function()
    start()
    register()

    H.Equal(Consumer.Keybind.GetKey('open'), 'E')

    local control = GetHashKey('+my-shop-open') | 0x80000000

    H.World.buttons[control] = 't_G'
    H.Equal(Consumer.Keybind.GetKey('open'), 'G')

    H.World.buttons[control] = 'b_1015'
    H.Equal(Consumer.Keybind.GetKey('open'), 'E')
end)

H.Test('Modal UI suspends bindings', function()
    start()

    local log = register()
    local opened, closed = UgLib.Enums.Events.Ui.Opened, UgLib.Enums.Events.Ui.Closed

    H.TriggerEvent(opened, 'ug-lib', 'dialog', 'other-resource')
    H.RunCommand('+my-shop-open', 0, {})
    H.Equal(log, {})

    H.TriggerEvent(opened, 'evil-resource', 'dialog', 'other-resource')
    H.TriggerEvent(closed, 'ug-lib', 'dialog', 'other-resource')
    H.RunCommand('+my-shop-open', 0, {})

    H.Equal(log, { 'pressed' }, 'only ug-lib events count')

    local free = {}

    Consumer.Keybind.Register({
        name = 'radio',
        label = 'Radio',
        disableWhileUi = false,
        onPressed = function()
            free[#free + 1] = true
        end,
    })

    H.TriggerEvent(opened, 'ug-lib', 'dialog', 'other-resource')
    H.RunCommand('+my-shop-radio', 0, {})

    H.Equal(#free, 1)
end)

H.Test('SetEnabled and Remove', function()
    start()

    local log = register()
    local mappings = #H.World.mappings

    Consumer.Keybind.SetEnabled('open', false)
    H.RunCommand('+my-shop-open', 0, {})
    H.Equal(log, {})

    Consumer.Keybind.SetEnabled('open', true)
    H.Equal(Consumer.Keybind.Remove('open'), true)
    H.Equal(Consumer.Keybind.Remove('open'), false)
    H.RunCommand('+my-shop-open', 0, {})
    H.Equal(log, {})

    H.Raises(function()
        Consumer.Keybind.IsPressed('open')
    end, 'Keybind "open" is not registered')

    local again = {}

    Consumer.Keybind.Register({
        name = 'open',
        label = 'Open the shop',
        onPressed = function()
            again[#again + 1] = true
        end,
    })

    H.RunCommand('+my-shop-open', 0, {})

    H.Equal(#again, 1, 'a removed name registers again')
    H.Equal(#H.World.mappings, mappings, 'without a second key mapping')
end)

H.Test('Register checks its options', function()
    start()
    register()

    H.Raises(function()
        register()
    end, 'Keybind.Register: "open" is already registered')

    H.Raises(function()
        Consumer.Keybind.Register(H.Any({
            name = 'bad-name',
            label = 'x',
        }))
    end, 'name MUST be 1 to 32 letters, digits or underscores')

    H.Raises(function()
        Consumer.Keybind.Register(H.Any({
            name = 'x',
            label = '',
        }))
    end, 'label MUST be a string of 1 to 128 bytes')

    H.Raises(function()
        Consumer.Keybind.Register(H.Any({
            name = 'x',
            label = 'X',
            defaultMapper = 'keyboad',
        }))
    end, 'defaultMapper MUST be one of')

    H.Raises(function()
        Consumer.Keybind.Register(H.Any({
            name = 'x',
            label = 'X',
            onPress = function() end,
        }))
    end, 'unknown option "onPress". Did you mean "onPressed"?')
end)

H.Test('A failing handler is logged', function()
    start()

    Consumer.Keybind.Register({
        name = 'boom',
        label = 'Boom',
        onPressed = function()
            error('boom')
        end,
    })

    local lines = H.RunCommand('+my-shop-boom', 0, {})

    H.Assert(lines[1]:find('Keybind +my-shop-boom onPressed failed', 1, true) ~= nil, lines[1])
end)

H.Done()
