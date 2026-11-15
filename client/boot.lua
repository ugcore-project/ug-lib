--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- Applies config once the server has replicated it. The server writes it again on every ug-lib restart.
-- The NUI prints the ready line once it has both the page and the config.

local Logger = UgLib.Internal.Logger

local STATE_KEY = UgLib.Enums.GlobalState.Config

---@param values any
local function apply(values)
    if type(values) ~= 'table' or type(values.settings) ~= 'table' or type(values.theme) ~= 'table' then
        return
    end

    Logger.SyncDebugMode(values.settings)
    UgLib.Internal.Nui.SetConfig(values)
    UgLib.Internal.Settings.Bind(values.settings)
end

AddStateBagChangeHandler(STATE_KEY, 'global', function(_, _, value)
    apply(value)
end)

if GlobalState[STATE_KEY] ~= nil then
    apply(GlobalState[STATE_KEY])
end
