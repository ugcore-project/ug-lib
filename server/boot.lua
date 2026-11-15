--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- Last server script: every config schema is registered.

local Loader = UgLib.Internal.Config.Loader
local Logger = UgLib.Internal.Logger

local errors = Loader.Load()

Logger.SyncDebugMode(UgLib.Internal.Config.Get('settings'))

local summary = ('[ug-lib] v%s · config loaded · %d files'):format(UgLib.Version.Get(), #Loader.GetEntries())

if errors > 0 then
    summary = summary .. (' · %d error(s), defaults used'):format(errors)
end

print(summary)
