--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@enum UgCacheEvent
UgLib.Enums.Events.Cache = {
    Changed = 'ug-lib:Cache:Changed',
}

---@enum UgUiEvent
UgLib.Enums.Events.Ui = {
    Opened = 'ug-lib:Ui:Opened',
    Closed = 'ug-lib:Ui:Closed',
}

---@alias UgLibEvent UgCacheEvent|UgUiEvent
