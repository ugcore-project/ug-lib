--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---GlobalState keys. ug-lib writes `Config`. `CoreConfig` is written by ug-core and only read for `DebugMode.Auto`.
---@enum UgLibGlobalStateKey
UgLib.Enums.GlobalState = {
    Config = 'ug-lib:Config',
    CoreConfig = 'ug-core:Config',
}

---Values of `settings.debug`. `Auto` follows ug-core's `core.debug`, and is off without ug-core.
---@enum UgLibDebugMode
UgLib.Enums.DebugMode = {
    Auto = 'auto',
    On = 'on',
    Off = 'off',
}
