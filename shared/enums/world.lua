--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@enum UgZoneShape
UgLib.Enums.ZoneShape = {
    Sphere = 'sphere',
    Box = 'box',
    Poly = 'poly',
    Point = 'point',
}

---Input devices of `RegisterKeyMapping`. Verify names against the Cfx input mapper list before adding one.
---@enum UgKeyMapper
UgLib.Enums.KeyMapper = {
    Keyboard = 'keyboard',
    MouseButton = 'mouse_button',
    MouseWheel = 'mouse_wheel',
    Gamepad = 'pad_digitalbuttonany',
}
