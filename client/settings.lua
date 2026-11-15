--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---The player settings screen, in ug-lib's runtime. A mouse screen on the page: each change is a non-final event,
---checked here against the unlocked keys and `Preferences.IsValid`, then saved. Open UI follows at once.
---@class UgLib.Internal.Settings
local Settings = {}
UgLib.Internal.Settings = Settings

local Preferences = UgLib.Internal.Preferences
local Config = UgLib.Internal.Config
local Requests = UgLib.Internal.Requests
local Enums = UgLib.Enums
local Key = Enums.PreferenceKey
local Protocol = UgLib.Internal.Protocol
local Text = UgLib.Internal.Locale.Text

local KIND = Protocol.Nui.Types.Settings
local PREVIEW_ID = 'ug-lib-preview'
local PREVIEW_MS = 3000

---Screen order of the preferences.
local ORDER = {
    Key.Mode, Key.Accent, Key.Scale,
    Key.NotifyPosition, Key.NotifyStyle, Key.TextUIPosition, Key.TextUIStyle,
    Key.ProgressPosition, Key.ProgressStyle, Key.MenuPosition, Key.ContextPosition,
}

local LABEL_KEYS = {
    'settings.title', 'settings.done', 'settings.reset', 'settings.default', 'settings.custom', 'settings.appearance',
    'settings.elements', 'settings.preview', 'settings.position', 'settings.style', 'settings.previewNotify',
    'settings.previewTextUI', 'settings.mode', 'settings.accent', 'settings.scale', 'settings.notify', 'settings.textUI',
    'settings.progress', 'settings.menu', 'settings.context',
}

---@param result table<string, string>
---@param prefix string
---@param enum table<string, string>
local function addLabels(result, prefix, enum)
    for _, value in pairs(enum) do
        local key = ('%s.%s'):format(prefix, value)

        result[key] = Text(key)
    end
end

---@return table<string, string>
local function labels()
    local result = {}

    for _, key in ipairs(LABEL_KEYS) do
        result[key] = Text(key)
    end

    addLabels(result, 'modes', Enums.ThemeMode)
    addLabels(result, 'positions', Enums.Position)
    addLabels(result, 'styles', Enums.NotifyStyle)
    addLabels(result, 'styles', Enums.TextUIStyle)
    addLabels(result, 'styles', Enums.ProgressStyle)

    return result
end

---What each preference shows when the player keeps the server default.
---@return table<UgPreferenceKey, any>
local function defaults()
    local theme = Config.Get('theme') or {}
    local settings = Config.Get('settings') or {}

    return {
        [Key.Mode] = theme.mode or Enums.ThemeMode.Dark,
        [Key.Scale] = theme.scale or 1,
        [Key.NotifyPosition] = settings.notifyPosition or Enums.Position.TopRight,
        [Key.NotifyStyle] = Enums.NotifyStyle.Toast,
        [Key.TextUIPosition] = settings.textUIPosition or Enums.Position.Bottom,
        [Key.TextUIStyle] = Enums.TextUIStyle.Pill,
        [Key.ProgressPosition] = settings.progressPosition or Enums.Position.Bottom,
        [Key.ProgressStyle] = Enums.ProgressStyle.Bar,
        [Key.MenuPosition] = settings.menuPosition or Enums.Position.TopLeft,
        [Key.ContextPosition] = settings.contextPosition or Enums.Position.CenterRight,
    }
end

local stamp = 0

---Always built here: the page and other resources never choose what the screen holds.
---@return table
local function payloadOf()
    local keys, values = {}, {}

    for _, key in ipairs(ORDER) do
        if not Preferences.IsLocked(key) then
            keys[#keys + 1] = key
            values[key] = Preferences.GetSaved(key)
        end
    end

    stamp = stamp + 1

    return {
        keys = keys,
        values = values,
        defaults = defaults(),
        labels = labels(),
        stamp = stamp,
    }
end

local previewTimer = nil

local function stopPreview()
    if previewTimer then
        previewTimer()
        previewTimer = nil
    end

    UgLib.TextUI.Hide()
end

local function previewNotify()
    UgLib.Notify.Show({
        id = PREVIEW_ID,
        message = Text('settings.previewNotify'),
        duration = PREVIEW_MS,
    })
end

local function previewTextUI()
    stopPreview()
    UgLib.TextUI.Show({
        text = Text('settings.previewTextUI'),
        key = 'E',
        icon = Enums.Icon.Info,
    })
    previewTimer = UgLib.Async.Timeout(PREVIEW_MS, stopPreview)
end

---Real samples at the chosen place, around the screen.
---@type table<UgPreferenceKey, fun()>
local PREVIEWS = {
    [Key.NotifyPosition] = previewNotify,
    [Key.NotifyStyle] = previewNotify,
    [Key.TextUIPosition] = previewTextUI,
    [Key.TextUIStyle] = previewTextUI,
}

---@type string? layer id while open
local current = nil

local function open()
    if not Preferences.IsEnabled() then
        UgLib.Notify.Show({
            message = Text('settings.disabled'),
            type = Enums.NotifyType.Warning,
        })

        return
    end

    if current then
        return
    end

    current = Requests.Start(KIND, payloadOf(), {
        onEvent = function(data)
            if data.resetAll then
                Preferences.Reset()

                if current then
                    Requests.Update(current, payloadOf())
                end

                return
            end

            Preferences.Set(data.key, data.value)

            if PREVIEWS[data.key] then
                PREVIEWS[data.key]()
            end
        end,
        onClose = function()
            current = nil
            stopPreview()
        end,
    })
end

Settings.Open = open

UgLib.Internal.Layers.RegisterType(KIND, {
    modal = true,
    focus = Protocol.Nui.Focus.Cursor,
    -- Whatever a resource sends through the exports is replaced by ug-lib's own payload.
    sanitize = function()
        return payloadOf()
    end,
    validate = function()
        return true, true
    end,
    validateEvent = function(payload, data)
        if type(data) ~= 'table' then
            return false, nil
        end

        if data.resetAll == true then
            return true, {
                resetAll = true,
            }
        end

        if not UgLib.Table.Contains(payload.keys, data.key) then
            return false, nil
        end

        if data.clear == true then
            return true, {
                key = data.key,
            }
        end

        local value = data.value

        if data.key == Key.Accent and type(value) == 'string' then
            value = value:lower()
        end

        if not Preferences.IsValid(data.key, value) then
            return false, nil
        end

        return true, {
            key = data.key,
            value = value,
        }
    end,
})

local commandName = nil

---Registers the settings command once config arrives. FiveM cannot unregister a command, so a later rename needs a restart.
---@param settings table replicated `settings`
function Settings.Bind(settings)
    if commandName or type(settings.settingsCommand) ~= 'string' then
        return
    end

    commandName = settings.settingsCommand

    RegisterCommand(commandName, function()
        open()
    end, false)
end

exports(Protocol.Exports.OpenSettings, function()
    open()
end)
