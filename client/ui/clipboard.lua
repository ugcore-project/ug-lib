--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Copies text to the player's clipboard through the page.
---@class UgLib.Clipboard
local Clipboard = {}
UgLib.Clipboard = Clipboard

local Utils = UgLib.Internal.Utils
local Protocol = UgLib.Internal.Protocol

local LIB = 'ug-lib'
local IS_OWNER = GetCurrentResourceName() == LIB
local MAX_TEXT = 4096

---@param text any
---@return boolean
local function isText(text)
    local length = type(text) == 'string' and utf8.len(text)

    return length ~= nil and length ~= false and length >= 1 and length <= MAX_TEXT
end

---Copies `text` (1 to 4096 characters) to the clipboard.
---@param text string
function Clipboard.Copy(text)
    if not isText(text) then
        Utils.Raise(2, 'Clipboard.Copy expects UTF-8 text of 1 to %d characters', MAX_TEXT)
    end

    exports[LIB][Protocol.Exports.Copy](exports[LIB], text)
end

if IS_OWNER then
    local Nui = UgLib.Internal.Nui
    local Types, Actions = Protocol.Nui.Types, Protocol.Nui.Actions

    exports(Protocol.Exports.Copy, function(text)
        if not isText(text) then
            Utils.Raise(2, 'Clipboard.Copy expects UTF-8 text of 1 to %d characters', MAX_TEXT)
        end

        Nui.Send(Types.System, Actions.Clipboard, nil, text)
    end)
end
