--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Key bindings players can change in their FiveM settings. They are registered in the calling resource,
---so FiveM lists them under that resource. FiveM cannot unregister a key mapping: `Remove` disables it.
---@class UgLib.Keybind
local Keybind = {}
UgLib.Keybind = Keybind

local Utils = UgLib.Internal.Utils
local Logger = UgLib.Internal.Logger
local UiEvents = UgLib.Enums.Events.Ui

local LIB = 'ug-lib'
local RESOURCE = GetCurrentResourceName()
local NAME_PATTERN = '^[%w_]+$'
local MAX_NAME = 32
local MAX_LABEL = 128
local OPTIONS = {
    name = true,
    label = true,
    defaultKey = true,
    defaultMapper = true,
    onPressed = true,
    onReleased = true,
    disableWhileUi = true,
}

---@class UgLibKeybind
---@field command string
---@field defaultKey? string
---@field onPressed? fun()
---@field onReleased? fun()
---@field disableWhileUi boolean
---@field enabled boolean
---@field removed boolean
---@field pressed boolean

---@type table<string, UgLibKeybind>
local bindings = {}

local openModals = 0

---@param binding UgLibKeybind
---@param name string
local function call(binding, name)
    local callback = binding[name]

    if callback then
        local ok, err = pcall(callback)

        if not ok then
            Logger.Error('Keybind %s %s failed: %s', binding.command, name, tostring(err))
        end
    end
end

---@param binding UgLibKeybind
---@return boolean
local function active(binding)
    return binding.enabled and not binding.removed and not (binding.disableWhileUi and openModals > 0)
end

---Registers `+<resource>-<name>` with a key mapping. Registering a removed name again reuses its mapping.
---@param options { name: string, label: string, defaultKey?: string, defaultMapper?: UgKeyMapper, onPressed?: fun(), onReleased?: fun(), disableWhileUi?: boolean }
---@return string command the command bound to the key, such as `+my-shop-open`
function Keybind.Register(options)
    Utils.CheckOptions('Keybind.Register', options, OPTIONS)

    local name = options.name

    if type(name) ~= 'string' or #name > MAX_NAME or not name:find(NAME_PATTERN) then
        Utils.Raise(2, 'Keybind.Register: name MUST be 1 to %d letters, digits or underscores', MAX_NAME)
    end

    if type(options.label) ~= 'string' or options.label == '' or #options.label > MAX_LABEL then
        Utils.Raise(2, 'Keybind.Register: label MUST be a string of 1 to %d bytes', MAX_LABEL)
    end

    if options.defaultKey ~= nil and (type(options.defaultKey) ~= 'string' or not options.defaultKey:find(NAME_PATTERN)) then
        Utils.Raise(2, 'Keybind.Register: defaultKey MUST be a key name such as "E" or "F6"')
    end

    Utils.CheckEnum('Keybind.Register', 'defaultMapper', options.defaultMapper, UgLib.Enums.KeyMapper, true)

    for _, key in ipairs({ 'onPressed', 'onReleased' }) do
        if options[key] ~= nil and type(options[key]) ~= 'function' then
            Utils.Raise(2, 'Keybind.Register: %s MUST be a function', key)
        end
    end

    local existing = bindings[name]

    if existing and not existing.removed then
        Utils.Raise(2, 'Keybind.Register: "%s" is already registered', name)
    end

    local command = ('%s-%s'):format(RESOURCE, name)
    local binding = existing or {
        command = '+' .. command,
        pressed = false,
    }

    binding.onPressed = options.onPressed
    binding.onReleased = options.onReleased
    binding.defaultKey = options.defaultKey
    binding.disableWhileUi = options.disableWhileUi ~= false
    binding.enabled = true
    binding.removed = false
    bindings[name] = binding

    if not existing then
        RegisterCommand('+' .. command, function()
            if active(binding) and not binding.pressed then
                binding.pressed = true
                call(binding, 'onPressed')
            end
        end, false)

        RegisterCommand('-' .. command, function()
            if binding.pressed then
                binding.pressed = false

                if active(binding) then
                    call(binding, 'onReleased')
                end
            end
        end, false)

        RegisterKeyMapping('+' .. command, options.label, options.defaultMapper or UgLib.Enums.KeyMapper.Keyboard, options.defaultKey or '')
    end

    return binding.command
end

---@param name string
---@return UgLibKeybind
local function find(name)
    local binding = bindings[name]

    if not binding or binding.removed then
        Utils.Raise(3, 'Keybind "%s" is not registered', tostring(name))
    end

    ---@cast binding -nil

    return binding
end

---Disables a binding for good. Its key stays listed in the FiveM settings until the game restarts.
---@param name string
---@return boolean removed false when it was not registered
function Keybind.Remove(name)
    local binding = bindings[name]

    if not binding or binding.removed then
        return false
    end

    binding.removed = true
    binding.pressed = false

    return true
end

---@param name string
---@param enabled boolean
function Keybind.SetEnabled(name, enabled)
    local binding = find(name)

    binding.enabled = enabled == true

    if not binding.enabled then
        binding.pressed = false
    end
end

---@param name string
---@return boolean
function Keybind.IsPressed(name)
    local binding = find(name)

    return binding.pressed and active(binding)
end

---The key the player has bound, such as `E` or `F6`. Keys the game shows as an icon, such as mouse buttons,
---return the default key. Read it each time it is shown: players MAY rebind at any moment.
---@param name string
---@return string? key nil without a key
function Keybind.GetKey(name)
    local binding = find(name)
    -- The mapping's instructional button: `t_E` for a text key, `b_<id>` for an icon.
    local button = GetControlInstructionalButton(0, GetHashKey(binding.command) | 0x80000000, true)

    if type(button) == 'string' and button:sub(1, 2) == 't_' and #button > 2 then
        return button:sub(3)
    end

    return binding.defaultKey
end

-- Modal UI (dialogs, context menus, radials) suspends bindings with `disableWhileUi`.
AddEventHandler(UiEvents.Opened, function()
    if GetInvokingResource() == LIB then
        openModals = openModals + 1
    end
end)

AddEventHandler(UiEvents.Closed, function()
    if GetInvokingResource() == LIB then
        openModals = math.max(openModals - 1, 0)
    end
end)
