--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Translations from a resource's own `locales/<code>.json`. The language comes from `settings.locale`.
---@class UgLib.Locale
local Locale = {}
UgLib.Locale = Locale

---@class UgLib.Internal.Locale
local InternalLocale = {}
UgLib.Internal.Locale = InternalLocale

local Utils = UgLib.Internal.Utils
local Logger = UgLib.Internal.Logger
local Config = UgLib.Internal.Config

local DEFAULT_CODE = 'en'
local CREATE_OPTIONS = {
    resource = true,
    fallback = true,
}

---@alias UgTranslator fun(key: string, vars?: table<string, any>): string

---@return string code such as `en`, from `settings.locale`. `en` until config is loaded.
function Locale.GetCode()
    return Config.Get('settings', 'locale') or DEFAULT_CODE
end

---@param text string
---@param vars? table<string, any>
---@return string
local function interpolate(text, vars)
    if not vars then
        return text
    end

    return (text:gsub('{(%w+)}', function(name)
        local value = vars[name]

        return value ~= nil and tostring(value) or '{' .. name .. '}'
    end))
end

---@param data table
---@param key string
---@return string?
local function lookup(data, key)
    local direct = data[key]

    if type(direct) == 'string' then
        return direct
    end

    local node = data

    for part in key:gmatch('[^%.]+') do
        if type(node) ~= 'table' then
            return nil
        end

        node = node[part]
    end

    return type(node) == 'string' and node or nil
end

---Returns a translator for `locales/<code>.json` of `resource`. Keys are flat (`"shop.title"`) or nested objects.
---A missing key falls back to the `fallback` language, then to the key itself, with one Debug log per key.
---Placeholders are `{name}`. Locale files MUST be listed in the resource's `files {}` to be read on clients.
---@param options? { resource?: string, fallback?: string }
---@return UgTranslator
function Locale.Create(options)
    options = options and Utils.CheckOptions('Locale.Create', options, CREATE_OPTIONS) or {}

    local resource = options.resource or GetCurrentResourceName()
    local fallback = options.fallback or DEFAULT_CODE

    if type(resource) ~= 'string' or type(fallback) ~= 'string' then
        Utils.Raise(2, 'Locale.Create: resource and fallback MUST be strings')
    end

    ---@type table<string, table|false>
    local files = {}

    ---@type table<string, boolean>
    local missing = {}

    ---@param code string
    ---@return table?
    local function load(code)
        if files[code] == nil then
            local path = ('locales/%s.json'):format(code)
            local content = LoadResourceFile(resource, path)
            local ok, data = false, nil

            if content then
                ok, data = pcall(json.decode, content)

                if not ok or type(data) ~= 'table' then
                    Logger.Error('Locale: %s of %s is not valid JSON.', path, resource)
                end
            end

            files[code] = ok and type(data) == 'table' and data or false
        end

        return files[code] or nil
    end

    return function(key, vars)
        if type(key) ~= 'string' then
            Utils.Raise(2, 'Locale: key MUST be a string, got %s', type(key))
        end

        local code = Locale.GetCode()
        local data = load(code)
        local text = data and lookup(data, key)

        if not text and code ~= fallback then
            local fallbackData = load(fallback)

            text = fallbackData and lookup(fallbackData, key)
        end

        if not text then
            if not missing[key] then
                missing[key] = true
                Logger.Debug('Locale: %s has no text for "%s".', resource, key)
            end

            return key
        end

        return interpolate(text, vars)
    end
end

---ug-lib's own labels, from `locales/<code>.json` of ug-lib.
InternalLocale.Text = Locale.Create({
    resource = 'ug-lib',
})
