--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Every open UI, across resources.
---@class UgLib.Ui
local Ui = {}
UgLib.Ui = Ui

local Utils = UgLib.Internal.Utils
local Protocol = UgLib.Internal.Protocol
local UiType = UgLib.Enums.UiType

local LIB = 'ug-lib'
local IS_OWNER = GetCurrentResourceName() == LIB

---Closes every layer of every resource. Waiting calls end with `Closed`.
function Ui.CloseAll()
    exports[LIB][Protocol.Exports.CloseAll](exports[LIB])
end

---True when a layer of `kind` is open, or with no `kind`, when a modal (dialog, context, radial, skill check) is open.
---@param kind? UgUiType
---@return boolean
function Ui.IsOpen(kind)
    Utils.CheckEnum('Ui.IsOpen', 'kind', kind, UiType, true)

    return exports[LIB][Protocol.Exports.IsOpen](exports[LIB], kind) == true
end

---Opens the player settings screen: theme, accent, size, positions and styles. Does nothing visible when the owner turned it off.
function Ui.OpenSettings()
    exports[LIB][Protocol.Exports.OpenSettings](exports[LIB])
end

if IS_OWNER then
    local Layers = UgLib.Internal.Layers

    exports(Protocol.Exports.CloseAll, function()
        Layers.CloseAll()
    end)

    exports(Protocol.Exports.IsOpen, function(kind)
        if kind == nil then
            return Layers.GetModal() ~= nil
        end

        for _, layer in ipairs(Layers.GetAll()) do
            if layer.kind == kind then
                return true
            end
        end

        return false
    end)
end
