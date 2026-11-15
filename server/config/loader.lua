--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Registers config definitions, generates missing owner files, runs them in a sandbox and resolves values.
---Precedence, lowest to highest: schema default, owner file, convar. ug-lib has no boot to abort,
---so an invalid value logs an Error and falls back to its default.
---@class UgLib.Internal.Config.Loader
local Loader = {}
UgLib.Internal.Config.Loader = Loader

local Utils = UgLib.Internal.Utils
local Logger = UgLib.Internal.Logger
local Validator = UgLib.Internal.Config.Validator
local Serializer = UgLib.Internal.Config.Serializer

local RESOURCE = GetCurrentResourceName()
local CONFIG_DIR = 'config/'
local KNOWN_KVP_PREFIX = 'ug-lib:Config:Known:'
local STATE_KEY = UgLib.Enums.GlobalState.Config
local CONVAR_UNSET = '__ug-lib:unset__'

---@type UgLibConfigEntry[]
local entries = {}

---@type table<string, UgLibConfigEntry>
local byName = {}

---Raises when the definition is invalid, including a default that fails its own validation.
---@param name string camelCase, also the file name `config/<name>.lua`
---@param definition UgLibConfigDefinition
function Loader.Register(name, definition)
    local problem = Validator.CheckDefinition(name, definition)

    if problem then
        Utils.Raise(2, 'Config.Register("%s"): %s', tostring(name), problem)
    end

    if byName[name] then
        Utils.Raise(2, 'Config.Register: "%s" is already registered', name)
    end

    local entry = {
        name = name,
        definition = definition,
    }
    entries[#entries + 1] = entry
    byName[name] = entry
end

---@param name string
---@return UgLibConfigEntry?
function Loader.GetEntry(name)
    return byName[name]
end

---In registration order.
---@return UgLibConfigEntry[]
function Loader.GetEntries()
    return entries
end

---@param tbl table
---@return table
local function shallowCopy(tbl)
    local copy = {}

    for key, value in pairs(tbl) do
        copy[key] = value
    end

    return copy
end

---Owner files get these globals only. Libraries are copies, so a file cannot change them for ug-lib.
---@return table
local function newSandbox()
    return {
        math = shallowCopy(math),
        string = shallowCopy(string),
        table = shallowCopy(table),
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        pairs = pairs,
        ipairs = ipairs,
    }
end

---@param name string
---@return string
local function pathOf(name)
    return CONFIG_DIR .. name .. '.lua'
end

---@param entry UgLibConfigEntry
---@return boolean generated
local function ensureFile(entry)
    local path = pathOf(entry.name)

    if LoadResourceFile(RESOURCE, path) ~= nil then
        return false
    end

    local content = Serializer.Generate(entry.name, entry.definition)

    if not SaveResourceFile(RESOURCE, path, content, #content) then
        Logger.Error('Config: cannot write %s. Using defaults.', path)

        return false
    end

    Logger.Info('Config: generated %s.', path)

    return true
end

---@param path string
---@return table? result
---@return string? message
local function runFile(path)
    local content = LoadResourceFile(RESOURCE, path)

    if content == nil then
        return nil, ('cannot read %s'):format(path)
    end

    local chunk, syntaxError = load(content, '@' .. path, 't', newSandbox())

    if not chunk then
        return nil, tostring(syntaxError)
    end

    local ok, result = pcall(chunk)

    if not ok then
        return nil, tostring(result)
    end

    if type(result) ~= 'table' then
        return nil, ('%s MUST return a table, got %s'):format(path, Validator.Describe(result))
    end

    return result, nil
end

---@param tbl table
---@return any[]
local function sortedKeys(tbl)
    local keys = {}

    for key in pairs(tbl) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)

    return keys
end

---Logs options added since the last start once. Known keys persist in resource KVP.
---@param entry UgLibConfigEntry
---@param owner table
---@param generated boolean
local function reportNewOptions(entry, owner, generated)
    local options = entry.definition.options
    local kvpKey = KNOWN_KVP_PREFIX .. entry.name
    local stored = GetResourceKvpString(kvpKey)
    local keys = {}

    for index = 1, #options do
        keys[index] = options[index].key
    end

    if stored and not generated then
        local known = {}

        for key in stored:gmatch('[^,]+') do
            known[key] = true
        end

        for index = 1, #options do
            local option = options[index]

            if not known[option.key] and owner[option.key] == nil then
                Logger.Info(
                    '%s.%s is new. Using default %s. Add it to %s to change it.',
                    entry.name, option.key, Serializer.Inline(option.default), pathOf(entry.name)
                )
            end
        end
    end

    local current = table.concat(keys, ',')

    if stored ~= current then
        SetResourceKvp(kvpKey, current)
    end
end

---@param entry UgLibConfigEntry
---@param owner table
---@return integer errors
local function resolve(entry, owner)
    local path = pathOf(entry.name)
    local options = entry.definition.options
    local byKey, keys = {}, {}
    local errors = 0

    for index = 1, #options do
        byKey[options[index].key] = options[index]
        keys[index] = options[index].key
    end

    for _, key in ipairs(sortedKeys(owner)) do
        if not byKey[key] then
            local name = tostring(key)
            local suggestion = type(key) == 'string' and UgLib.String.Suggest(name, keys) or nil
            local hint = suggestion and (' Did you mean "%s"?'):format(suggestion) or ''

            Logger.Warn('%s: unknown option "%s" is ignored.%s', path, name, hint)
        end
    end

    local values, sources = {}, {}

    for index = 1, #options do
        local option = options[index]
        local key = option.key
        local value, source = UgLib.Table.DeepCopy(option.default), 'default'
        local ownerValue = owner[key]

        if ownerValue ~= nil then
            local ok, checked, message = Validator.CheckValue(option, ownerValue)

            if ok then
                value, source = checked, 'file'
            else
                errors = errors + 1
                Logger.Error('%s: %s %s. Using default %s.', path, key, message, Serializer.Inline(option.default))
            end
        end

        local convar = Validator.ConvarName(entry.name, key)
        local raw = GetConvar(convar, CONVAR_UNSET)

        if raw ~= CONVAR_UNSET then
            local ok, parsed, message = Validator.ParseConvar(option, raw)

            if ok then
                value, source = parsed, 'convar'
            else
                errors = errors + 1
                Logger.Error('convar %s: %s. Ignored.', convar, message)
            end
        end

        values[key] = value
        sources[key] = source
    end

    entry.values = values
    entry.sources = sources

    return errors
end

---Resolves every registered config and replicates the values through `GlobalState['ug-lib:Config']`.
---Never raises. Every value falls back to its default when it cannot be read.
---@return integer errors
function Loader.Load()
    local errors = 0
    local payload = {}

    for _, entry in ipairs(entries) do
        local path = pathOf(entry.name)
        local generated = ensureFile(entry)
        local owner, message = runFile(path)

        if owner then
            entry.file = generated and 'generated' or 'loaded'
        else
            errors = errors + 1
            entry.file = 'failed'
            owner = {}

            if LoadResourceFile(RESOURCE, path) ~= nil then
                Logger.Error('Config: %s. Using defaults for %s.', message, entry.name)
            end
        end

        errors = errors + resolve(entry, owner)
        reportNewOptions(entry, owner, generated)
        payload[entry.name] = entry.values
    end

    GlobalState:set(STATE_KEY, payload, true)

    return errors
end
