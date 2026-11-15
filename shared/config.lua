--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Resolved config values. The server writes them to GlobalState once loaded, so every side reads the same values.
---@class UgLib.Internal.Config
---@field Validator UgLib.Internal.Config.Validator server only
---@field Serializer UgLib.Internal.Config.Serializer server only
---@field Loader UgLib.Internal.Config.Loader server only
local Config = {}
UgLib.Internal.Config = Config

local Utils = UgLib.Internal.Utils
local Table = UgLib.Table

local STATE_KEY = UgLib.Enums.GlobalState.Config

---@return table<string, table<string, any>>?
local function payload()
    local values = GlobalState[STATE_KEY]

    return type(values) == 'table' and values or nil
end

---@return boolean
function Config.IsLoaded()
    return payload() ~= nil
end

---A copy of one value, or of every value of a config. Nil until the server has loaded config.
---Raises for unknown names and keys once loaded.
---@param name string `settings` or `theme`
---@param key? string
---@return any
function Config.Get(name, key)
    local loaded = payload()

    if not loaded then
        return nil
    end

    local values = loaded[name]

    if type(values) ~= 'table' then
        Utils.Raise(2, 'Config.Get: unknown config "%s"', tostring(name))
    end

    if key == nil then
        return Table.DeepCopy(values)
    end

    local value = values[key]

    if value == nil then
        Utils.Raise(2, 'Config.Get: unknown option "%s.%s"', name, tostring(key))
    end

    return Table.DeepCopy(value)
end
