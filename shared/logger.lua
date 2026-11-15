--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Messages with extra arguments are formatted with `string.format`.
---Lines carry `[ug-lib]`, because the import prints them in the consumer's console too.
---@class UgLib.Internal.Logger
local Logger = {}
UgLib.Internal.Logger = Logger

local Utils = UgLib.Internal.Utils

local TAG_DEBUG = '^6[DEBUG]^7 [ug-lib]'
local TAG_INFO = '^5[INFO]^7 [ug-lib]'
local TAG_WARN = '^3[WARN]^7 [ug-lib]'
local TAG_ERROR = '^1[ERROR]^7 [ug-lib]'

local DebugMode = UgLib.Enums.DebugMode
local CORE_CONFIG_KEY = UgLib.Enums.GlobalState.CoreConfig

local debugMode = DebugMode.Auto
local coreDebug = false
local debugEnabled = false

local function refreshDebug()
    debugEnabled = debugMode == DebugMode.On or (debugMode == DebugMode.Auto and coreDebug)
end

---@param tag string
---@param message any
---@param ... any
local function write(tag, message, ...)
    local text = tostring(message)

    if select('#', ...) > 0 then
        text = text:format(...)
    end

    print(tag .. ' ' .. text)
end

---Printed only when debug is enabled.
---@param message any
---@param ... any
function Logger.Debug(message, ...)
    if debugEnabled then
        write(TAG_DEBUG, message, ...)
    end
end

---@param message any
---@param ... any
function Logger.Info(message, ...)
    write(TAG_INFO, message, ...)
end

---@param message any
---@param ... any
function Logger.Warn(message, ...)
    write(TAG_WARN, message, ...)
end

---@param message any
---@param ... any
function Logger.Error(message, ...)
    write(TAG_ERROR, message, ...)
end

---ug-lib's own mode wins. `Auto` follows ug-core's `core.debug`.
---@param mode UgLibDebugMode
function Logger.SetDebugMode(mode)
    Utils.CheckEnum('Logger.SetDebugMode', 'mode', mode, DebugMode)

    debugMode = mode
    refreshDebug()
end

---Applies `settings.debug` from the replicated config. A missing or unknown value means `Auto`.
---@param settings any
function Logger.SyncDebugMode(settings)
    local mode = type(settings) == 'table' and settings.debug or nil

    for _, known in pairs(DebugMode) do
        if known == mode then
            debugMode = known
            refreshDebug()
            return
        end
    end

    debugMode = DebugMode.Auto
    refreshDebug()
end

---@return UgLibDebugMode
function Logger.GetDebugMode()
    return debugMode
end

---@return boolean
function Logger.IsDebug()
    return debugEnabled
end

---ug-core replicates its shared config, `core.debug` included. Without ug-core the key stays nil.
---@param payload any
local function readCoreDebug(payload)
    local core = type(payload) == 'table' and payload.core or nil
    local values = type(core) == 'table' and core.values or nil

    coreDebug = type(values) == 'table' and values.debug == true
    refreshDebug()
end

readCoreDebug(GlobalState[CORE_CONFIG_KEY])

AddStateBagChangeHandler(CORE_CONFIG_KEY, 'global', function(_, _, value)
    readCoreDebug(value)
end)
