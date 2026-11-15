--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Player preferences, in ug-lib's runtime only. Saved in client KVP on the player's PC, so they need no network.
---They replace the position and style of layers and the theme of the page. A payload with `fixed = true` keeps its own.
---@class UgLib.Internal.Preferences
local Preferences = {}
UgLib.Internal.Preferences = Preferences

local Utils = UgLib.Internal.Utils
local Config = UgLib.Internal.Config
local Enums = UgLib.Enums
local Key = Enums.PreferenceKey
local Types = UgLib.Internal.Protocol.Nui.Types

local KVP_KEY = 'ug-lib:Preferences'
local MIN_SCALE = 0.75
local MAX_SCALE = 1.5

---@param enum table<string, string>
---@return fun(value: any): boolean
local function oneOf(enum)
    return function(value)
        for _, entry in pairs(enum) do
            if entry == value then
                return true
            end
        end

        return false
    end
end

---@type table<UgPreferenceKey, fun(value: any): boolean>
local CHECKS = {
    [Key.Mode] = oneOf(Enums.ThemeMode),
    [Key.Accent] = function(value)
        return type(value) == 'string' and value:find('^#%x%x%x%x%x%x$') ~= nil
    end,
    [Key.Scale] = function(value)
        return type(value) == 'number' and value >= MIN_SCALE and value <= MAX_SCALE
    end,
    [Key.NotifyPosition] = oneOf(Enums.Position),
    [Key.NotifyStyle] = oneOf(Enums.NotifyStyle),
    [Key.TextUIPosition] = oneOf(Enums.Position),
    [Key.TextUIStyle] = oneOf(Enums.TextUIStyle),
    [Key.ProgressPosition] = oneOf(Enums.Position),
    [Key.ProgressStyle] = oneOf(Enums.ProgressStyle),
    [Key.MenuPosition] = oneOf(Enums.Position),
    [Key.ContextPosition] = oneOf(Enums.Position),
}

---Payload fields each preference replaces, per layer type.
---@type table<string, table<string, UgPreferenceKey>>
local LAYER_FIELDS = {
    [Types.Notify] = {
        position = Key.NotifyPosition,
        style = Key.NotifyStyle,
    },
    [Types.TextUI] = {
        position = Key.TextUIPosition,
        style = Key.TextUIStyle,
    },
    [Types.Progress] = {
        position = Key.ProgressPosition,
        style = Key.ProgressStyle,
    },
    [Types.Menu] = {
        position = Key.MenuPosition,
    },
    [Types.Context] = {
        position = Key.ContextPosition,
    },
}

---@type table<UgPreferenceKey, any>
local saved = {}

---Reads KVP. Unknown keys and invalid values are dropped: the file is on the player's PC.
local function load()
    saved = {}

    local raw = GetResourceKvpString(KVP_KEY)
    local ok, decoded = pcall(json.decode, raw or '{}')

    if not ok or type(decoded) ~= 'table' then
        return
    end

    for key, check in pairs(CHECKS) do
        if decoded[key] ~= nil and check(decoded[key]) then
            saved[key] = decoded[key]
        end
    end
end

local function save()
    SetResourceKvp(KVP_KEY, json.encode(saved))
end

local function refresh()
    UgLib.Internal.Layers.Refresh()
    UgLib.Internal.Nui.RefreshConfig()
end

---True when `value` is allowed for `key`. Unknown keys are never valid.
---@param key any
---@param value any
---@return boolean
function Preferences.IsValid(key, value)
    local check = CHECKS[key]

    return check ~= nil and check(value)
end

---@return boolean
function Preferences.IsEnabled()
    return Config.Get('settings', 'playerSettings') ~= false
end

---@param key UgPreferenceKey
---@return boolean
function Preferences.IsLocked(key)
    local locked = Config.Get('settings', 'lockedSettings')

    return type(locked) == 'table' and UgLib.Table.Contains(locked, key)
end

---The value in effect: nil when unset, locked, or when the owner turned preferences off.
---@param key UgPreferenceKey
---@return any
function Preferences.Get(key)
    if not Preferences.IsEnabled() or Preferences.IsLocked(key) then
        return nil
    end

    return saved[key]
end

---The saved value, even when locked. For the settings screen.
---@param key UgPreferenceKey
---@return any
function Preferences.GetSaved(key)
    return saved[key]
end

---Saves a preference and applies it to open layers and the page. `nil` returns to the server default.
---@param key UgPreferenceKey
---@param value any
function Preferences.Set(key, value)
    local check = CHECKS[key]

    if not check then
        Utils.Raise(2, 'Preferences.Set: unknown preference "%s"', tostring(key))
    end

    if value ~= nil and not check(value) then
        Utils.Raise(2, 'Preferences.Set: invalid value %s for "%s"', tostring(value), key)
    end

    saved[key] = value
    save()
    refresh()
end

---Clears every preference.
function Preferences.Reset()
    saved = {}
    save()
    refresh()
end

---Sets `position` and `style` of a payload from the player's choices, or back to what the caller asked for.
---@param kind string layer type
---@param payload table sanitized payload, changed in place
---@param requested table<string, any> the caller's own values of the replaced fields
function Preferences.Apply(kind, payload, requested)
    local fields = LAYER_FIELDS[kind]

    if not fields then
        return
    end

    for field, key in pairs(fields) do
        local wanted = payload.fixed ~= true and Preferences.Get(key) or nil

        if wanted ~= nil then
            payload[field] = wanted
        else
            payload[field] = requested[field]
        end
    end
end

---The caller's own values of the fields preferences replace.
---@param kind string
---@param payload table
---@return table<string, any>? nil for types without preferences
function Preferences.RequestedOf(kind, payload)
    local fields = LAYER_FIELDS[kind]

    if not fields then
        return nil
    end

    local requested = {}

    for field in pairs(fields) do
        requested[field] = payload[field]
    end

    return requested
end

---Theme values for the page. Nil fields keep the owner's theme.
---@return { mode?: UgThemeMode, accent?: string, scale?: number }
function Preferences.Theme()
    return {
        mode = Preferences.Get(Key.Mode),
        accent = Preferences.Get(Key.Accent),
        scale = Preferences.Get(Key.Scale),
    }
end

load()
