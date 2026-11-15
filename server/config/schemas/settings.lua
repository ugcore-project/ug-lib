--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

local Enums = UgLib.Enums

---@param enum table<string, string>
---@return string[]
local function valuesOf(enum)
    local values = {}

    for _, value in pairs(enum) do
        values[#values + 1] = value
    end

    table.sort(values)

    return values
end

local POSITIONS = valuesOf(Enums.Position)
local DEBUG_MODES = valuesOf(Enums.DebugMode)
local CURRENCY_POSITIONS = valuesOf(Enums.CurrencyPosition)
local KEY_PATTERN = '^[%w_]+$'
local PREFERENCE_KEYS = valuesOf(Enums.PreferenceKey)

---@param value table
---@return boolean ok
---@return string? message
local function validateLocked(value)
    for index, key in pairs(value) do
        if math.type(index) ~= 'integer' then
            return false, 'MUST be an array of preference keys'
        end

        if not UgLib.Table.Contains(PREFERENCE_KEYS, key) then
            local suggestion = type(key) == 'string' and UgLib.String.Suggest(key, PREFERENCE_KEYS) or nil

            return false, ('has an unknown key "%s".%s'):format(tostring(key), suggestion and (' Did you mean "%s"?'):format(suggestion) or '')
        end
    end

    return true
end

local MENU_KEYS = { 'up', 'down', 'left', 'right', 'select', 'back' }

---@param value table
---@return boolean ok
---@return string? message
local function validateCurrency(value)
    for key in pairs(value) do
        if key ~= 'symbol' and key ~= 'position' then
            return false, ('has an unknown field "%s", expected symbol and position'):format(tostring(key))
        end
    end

    if type(value.symbol) ~= 'string' or #value.symbol < 1 or #value.symbol > 8 then
        return false, 'symbol MUST be a string of 1 to 8 bytes'
    end

    for _, position in ipairs(CURRENCY_POSITIONS) do
        if value.position == position then
            return true
        end
    end

    return false, ('position MUST be one of %s'):format(table.concat(CURRENCY_POSITIONS, ', '))
end

---@param value table
---@return boolean ok
---@return string? message
local function validateMenuKeys(value)
    for _, name in ipairs(MENU_KEYS) do
        local key = value[name]

        if type(key) ~= 'string' or not key:find(KEY_PATTERN) then
            return false, ('%s MUST be a key name such as "UP"'):format(name)
        end
    end

    for name in pairs(value) do
        if not UgLib.Table.Contains(MENU_KEYS, name) then
            return false, ('has an unknown field "%s", expected %s'):format(tostring(name), table.concat(MENU_KEYS, ', '))
        end
    end

    return true
end

---@param value string
---@return boolean ok
---@return string? message
local function validateKey(value)
    if value:find(KEY_PATTERN) then
        return true
    end

    return false, 'MUST be a key name such as "X" or "F1"'
end

UgLib.Internal.Config.Loader.Register('settings', {
    options = {
        {
            key = 'locale',
            type = 'string',
            default = 'en',
            min = 2,
            max = 10,
            description = 'Language of ug-lib labels, and the default language of UgLib.Locale. A file in locales/ of each resource.',
            validate = function(value)
                return value:find('^%a%a[%w%-]*$') ~= nil, 'MUST be a language code such as "en" or "pt-BR"'
            end,
        },
        {
            key = 'debug',
            type = 'string',
            default = Enums.DebugMode.Auto,
            values = DEBUG_MODES,
            aliases = {
                [true] = Enums.DebugMode.On,
                [false] = Enums.DebugMode.Off,
                ['true'] = Enums.DebugMode.On,
                ['false'] = Enums.DebugMode.Off,
                ['1'] = Enums.DebugMode.On,
                ['0'] = Enums.DebugMode.Off,
            },
            description = 'Debug logs on the server and in client F8, and the `uglib` client command. "auto" follows ug-core debug, off without ug-core. true and false also work.',
        },
        {
            key = 'currency',
            type = 'table',
            default = {
                symbol = '$',
                position = Enums.CurrencyPosition.Before,
            },
            description = 'Default currency of UgLib.Format.Money. position is "before" ($1,500) or "after" (1,500 €).',
            validate = validateCurrency,
        },
        {
            key = 'notifyPosition',
            type = 'string',
            default = Enums.Position.TopRight,
            values = POSITIONS,
            description = 'Default screen anchor of notifications.',
        },
        {
            key = 'notifyDuration',
            type = 'integer',
            default = 5000,
            min = 0,
            max = 600000,
            description = 'Default time a notification stays on screen, in ms. 0 keeps it until dismissed.',
        },
        {
            key = 'notifyMax',
            type = 'integer',
            default = 5,
            min = 1,
            max = 20,
            description = 'Notifications on screen per anchor. Older ones leave first.',
        },
        {
            key = 'textUIPosition',
            type = 'string',
            default = Enums.Position.Bottom,
            values = POSITIONS,
            description = 'Default screen anchor of the text prompt.',
        },
        {
            key = 'progressPosition',
            type = 'string',
            default = Enums.Position.Bottom,
            values = POSITIONS,
            description = 'Default screen anchor of progress bars.',
        },
        {
            key = 'menuPosition',
            type = 'string',
            default = Enums.Position.TopLeft,
            values = POSITIONS,
            description = 'Default screen anchor of keyboard menus.',
        },
        {
            key = 'contextPosition',
            type = 'string',
            default = Enums.Position.CenterRight,
            values = POSITIONS,
            description = 'Default screen anchor of context menus.',
        },
        {
            key = 'cancelKey',
            type = 'string',
            default = 'X',
            min = 1,
            max = 16,
            description = 'Key that cancels a progress action. Players MAY rebind it in their FiveM key settings.',
            validate = validateKey,
        },
        {
            key = 'radialKey',
            type = 'string',
            default = 'F1',
            max = 16,
            description = 'Key that opens the global radial menu. An empty string disables the global radial.',
            validate = function(value)
                return value == '' or validateKey(value)
            end,
        },
        {
            key = 'menuKeys',
            type = 'table',
            default = {
                up = 'UP',
                down = 'DOWN',
                left = 'LEFT',
                right = 'RIGHT',
                select = 'RETURN',
                back = 'BACK',
            },
            description = 'Keys of keyboard menus: up, down, left, right, select and back.',
            validate = validateMenuKeys,
        },
        {
            key = 'cacheInterval',
            type = 'integer',
            default = 100,
            min = 50,
            max = 1000,
            description = 'How often the client cache reads the local player, in ms.',
        },
        {
            key = 'zoneInterval',
            type = 'integer',
            default = 250,
            min = 50,
            max = 2000,
            description = 'How often zones check the player position, in ms.',
        },
        {
            key = 'sounds',
            type = 'boolean',
            default = true,
            description = 'Frontend sounds when menus select and close.',
        },
        {
            key = 'playerSettings',
            type = 'boolean',
            default = true,
            description = 'Players MAY change their own theme, accent, scale, positions and styles with the settings command. Saved on their PC.',
        },
        {
            key = 'lockedSettings',
            type = 'table',
            default = {},
            max = #PREFERENCE_KEYS,
            description = 'Preferences players MUST NOT change, such as { "accent", "mode" }.\nKeys: ' .. table.concat(PREFERENCE_KEYS, ', ') .. '.',
            validate = validateLocked,
        },
        {
            key = 'settingsCommand',
            type = 'string',
            default = 'uisettings',
            min = 1,
            max = 32,
            description = 'Chat command that opens the player settings.',
            validate = function(value)
                return value:find('^[%w_%-]+$') ~= nil, 'MUST be letters, digits, _ or -'
            end,
        },
    },
})
