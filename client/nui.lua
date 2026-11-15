--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---The NUI page: messages to it, callbacks from it, and the game focus it takes.
---Everything the page sends is untrusted. Callbacks only reach `Layers`, which validates answers.
---@alias UgNuiFocus 'none'|'keyboard'|'cursor'

---@class UgLib.Internal.Nui
local Nui = {}
UgLib.Internal.Nui = Nui

local Logger = UgLib.Internal.Logger
local Protocol = UgLib.Internal.Protocol.Nui
local Types, Actions, Callbacks, Focus = Protocol.Types, Protocol.Actions, Protocol.Callbacks, Protocol.Focus

local LABELS = { 'ok', 'confirm', 'cancel', 'back', 'close', 'submit' }
-- The NUI root stacks frames in load order, so every resource that depends on ug-lib would cover its notifications.
-- Whenever any resource takes focus, the root resets every frame to its stack position and gives the focused one
-- 99999, which it keeps after losing focus. So the z-index is applied again when the focus changes: above a focused
-- frame of another resource it would take that frame's mouse, so ug-lib sits just below it then, and above everything
-- otherwise. Only the focus flag is polled: it is a plain getter, while SetNuiZindex posts a message to the root page.
local Z_INDEX_FOCUSED = 9999
local Z_INDEX_TOP = 100000
local Z_INDEX_INTERVAL = 500
local PAGE_SETTINGS = {
    'notifyPosition',
    'notifyDuration',
    'notifyMax',
    'textUIPosition',
    'progressPosition',
    'menuPosition',
    'sounds',
}

local ready = false
local announced = false

---@type table? the last config payload, sent first when the page is ready
local config = nil

---@type table[] messages sent before the page was ready
local queue = {}

---@type { focus: boolean, cursor: boolean, keepInput: boolean }
local focusState = {
    focus = false,
    cursor = false,
    keepInput = false,
}

---@type integer? the z-index last applied, nil to apply again
local zIndex = nil

---@type table<string, { second: integer, count: integer }>
local eventBudget = {}

---Applies the z-index for the current focus, unless it is already applied.
local function applyZIndex()
    local wanted = (IsNuiFocused() and not focusState.focus) and Z_INDEX_FOCUSED or Z_INDEX_TOP

    if wanted ~= zIndex then
        zIndex = wanted
        SetNuiZindex(wanted)
    end
end

---@param message table
local function post(message)
    if ready then
        SendNUIMessage(message)
    else
        queue[#queue + 1] = message
    end
end

---Sends a message to the page. Messages wait in order until the page is ready.
---@param kind string a `Protocol.Nui.Types` value
---@param action string a `Protocol.Nui.Actions` value
---@param id? string layer id `<owner>/<id>`
---@param payload? table
function Nui.Send(kind, action, id, payload)
    post({
        type = kind,
        action = action,
        id = id,
        payload = payload,
    })
end

---@return boolean
function Nui.IsReady()
    return ready
end

---@return { focus: boolean, cursor: boolean, keepInput: boolean }
function Nui.GetFocus()
    return {
        focus = focusState.focus,
        cursor = focusState.cursor,
        keepInput = focusState.keepInput,
    }
end

---Gives the game focus to the top layer that wants input, or releases it. Natives run only on change.
---@param focus UgNuiFocus a `Protocol.Nui.Focus` value
---@param keepInput boolean
function Nui.SetFocus(focus, keepInput)
    local wanted = {
        focus = focus ~= Focus.None,
        cursor = focus == Focus.Cursor,
        keepInput = focus ~= Focus.None and keepInput == true,
    }

    if wanted.focus ~= focusState.focus or wanted.cursor ~= focusState.cursor then
        SetNuiFocus(wanted.focus, wanted.cursor)
    end

    if wanted.keepInput ~= focusState.keepInput then
        SetNuiFocusKeepInput(wanted.keepInput)
    end

    focusState = wanted
end

local function announce()
    if announced or not ready or not config then
        return
    end

    announced = true
    print(('[ug-lib] v%s ready (%s, %s).'):format(UgLib.Version.Get(), tostring(config.theme.mode), tostring(config.locale)))
end

---@type { settings: table, theme: table }?
local lastValues = nil

---Builds the page config from replicated values: theme, page defaults and labels in the configured language.
---Player preferences replace the theme mode, accent and scale.
---@param values { settings: table, theme: table }
function Nui.SetConfig(values)
    lastValues = values

    local settings = {}

    for _, key in ipairs(PAGE_SETTINGS) do
        settings[key] = values.settings[key]
    end

    local labels = {}

    for _, key in ipairs(LABELS) do
        labels[key] = UgLib.Internal.Locale.Text('labels.' .. key)
    end

    local theme = UgLib.Table.DeepCopy(values.theme)
    local preferred = UgLib.Internal.Preferences.Theme()

    theme.mode = preferred.mode or theme.mode
    theme.scale = preferred.scale or theme.scale

    config = {
        theme = theme,
        accent = preferred.accent,
        settings = settings,
        labels = labels,
        locale = values.settings.locale,
    }

    if ready then
        SendNUIMessage({
            type = Types.System,
            action = Actions.Config,
            payload = config,
        })
    end

    announce()
end

---Sends the page config again, such as after a preference changed.
function Nui.RefreshConfig()
    if lastValues then
        Nui.SetConfig(lastValues)
    end
end

---@param data any
---@return string? id
local function layerIdOf(data)
    local id = type(data) == 'table' and data.id or nil

    if type(id) ~= 'string' or id == '' or #id > Protocol.MaxLayerIdLength then
        return nil
    end

    return id
end

---@param id string
---@return boolean
local function withinBudget(id)
    local second = GetGameTimer() // 1000
    local budget = eventBudget[id]

    if not budget or budget.second ~= second then
        budget = {
            second = second,
            count = 0,
        }
        eventBudget[id] = budget
    end

    budget.count = budget.count + 1

    return budget.count <= Protocol.EventsPerSecond
end

---Every callback replies, even on bad input: a callback that never replies hangs the page's fetch.
---@param name string
---@param handler fun(data: any): boolean
local function register(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local called, ok = pcall(handler, data)

        if not called then
            Logger.Error('NUI callback %s failed: %s', name, tostring(ok))
        end

        cb({
            ok = called and ok == true,
        })
    end)
end

register(Callbacks.Ready, function()
    if ready then
        return true
    end

    ready = true
    -- SetNuiZindex does nothing before the frame exists, so the value applied at load may be lost.
    zIndex = nil
    applyZIndex()

    if config then
        SendNUIMessage({
            type = Types.System,
            action = Actions.Config,
            payload = config,
        })
    end

    for _, message in ipairs(queue) do
        SendNUIMessage(message)
    end

    queue = {}
    announce()

    return true
end)

register(Callbacks.Resolve, function(data)
    local id = layerIdOf(data)

    if not id then
        Logger.Debug('NUI: Resolve without a valid id dropped.')

        return false
    end

    eventBudget[id] = nil

    return UgLib.Internal.Layers.ResolveById(id, data.result)
end)

register(Callbacks.Event, function(data)
    local id = layerIdOf(data)

    if not id or not withinBudget(id) then
        return false
    end

    return UgLib.Internal.Layers.EventById(id, data.data)
end)

register(Callbacks.Close, function(data)
    local id = layerIdOf(data)

    if not id then
        return false
    end

    eventBudget[id] = nil

    return UgLib.Internal.Layers.CloseById(id, UgLib.Enums.CloseReason.Cancelled)
end)

CreateThread(function()
    while true do
        applyZIndex()
        Wait(Z_INDEX_INTERVAL)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SendNUIMessage({
            type = Types.System,
            action = Actions.CloseAll,
        })
        Nui.SetFocus(Focus.None, false)
    end
end)
