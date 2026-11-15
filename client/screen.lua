--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@class UgLib.Screen
local Screen = {}
UgLib.Screen = Screen

local Utils = UgLib.Internal.Utils

---Screen position of a world position, from 0 to 1 on each axis.
---@param coords vector3
---@return boolean onScreen
---@return number x
---@return number y
function Screen.WorldToScreen(coords)
    if type(coords) ~= 'vector3' then
        Utils.Raise(2, 'Screen.WorldToScreen expects a vector3, got %s', type(coords))
    end

    local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)

    return onScreen == true or onScreen == 1, x, y
end

---@return integer width
---@return integer height
function Screen.GetResolution()
    local width, height = GetActiveScreenResolution()

    return width, height
end

---@return number ratio such as 1.777 for 16:9
function Screen.GetAspectRatio()
    return GetAspectRatio(false)
end
