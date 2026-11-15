--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Import side, in the consumer's runtime. Builds the public, read-only `UgLib` root.
---@class UgLib.Internal.Proxy
local Proxy = {}
UgLib.Internal.Proxy = Proxy

local Utils = UgLib.Internal.Utils
local Logger = UgLib.Internal.Logger

local IS_SERVER = IsDuplicityVersion()
local CONFIG_KEY = UgLib.Enums.GlobalState.Config

-- Public namespaces that exist on clients only. Each arrives with its build step.
local CLIENT_ONLY = {
    Cache = true, Streaming = true, Entity = true, Raycast = true, Screen = true, Draw = true, Animation = true,
    Zone = true, Point = true, Keybind = true,
    Notify = true, TextUI = true, Progress = true, SkillCheck = true, Dialog = true, Context = true, Menu = true,
    Radial = true, Clipboard = true, Ui = true,
}

---The consumer's `UgLib`: every public namespace of this runtime. Unknown and private names raise.
---@return table
function Proxy.CreateRoot()
    local namespaces = {}

    for name, value in pairs(UgLib) do
        if name ~= 'Internal' then
            namespaces[name] = value
        end
    end

    return setmetatable({}, {
        __index = function(_, name)
            local value = namespaces[name]

            if value ~= nil then
                return value
            end

            if name == 'Internal' then
                Utils.Raise(2, 'UgLib.Internal is private to ug-lib.')
            end

            if IS_SERVER and CLIENT_ONLY[name] then
                Utils.Raise(2, 'UgLib.%s exists on clients only.', tostring(name))
            end

            Utils.Raise(2, 'UgLib.%s is not a ug-lib namespace.', tostring(name))
        end,
        __newindex = function(_, name)
            Utils.Raise(2, 'UgLib is read-only. Cannot set UgLib.%s.', tostring(name))
        end,
        __metatable = false,
    })
end

---@param payload any
local function syncDebug(payload)
    Logger.SyncDebugMode(type(payload) == 'table' and payload.settings or nil)
end

syncDebug(GlobalState[CONFIG_KEY])

AddStateBagChangeHandler(CONFIG_KEY, 'global', function(_, _, value)
    syncDebug(value)
end)
