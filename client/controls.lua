--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Control indices by group, from the Cfx controls reference. Verify an index there before adding it.
---@class UgLib.Internal.Controls
local Controls = {
    ---Move left/right, up/down, and the four single directions.
    Move = { 30, 31, 32, 33, 34, 35 },
    ---The four single directions, to detect a player trying to walk.
    MovePress = { 32, 33, 34, 35 },
    ---Sprint and jump.
    Sprint = { 21, 22 },
    ---Vehicle steering, accelerate, brake and exit.
    Car = { 59, 60, 63, 64, 71, 72, 75 },
    ---Attack, aim, weapon wheel, detonate, throw, melee and melee attacks.
    Combat = { 24, 25, 37, 47, 58, 140, 141, 142, 143, 257, 263, 264 },
    ---Camera look and the vehicle mouse override.
    Mouse = { 1, 2, 106 },
}
UgLib.Internal.Controls = Controls

-- Called every frame during a progress action: native cached as a local.
local DisableControlAction = DisableControlAction

---Disables a group of controls for this frame.
---@param group integer[]
function Controls.Disable(group)
    for index = 1, #group do
        DisableControlAction(0, group[index], true)
    end
end

---True when any control of the group is pressed this frame, disabled or not.
---@param group integer[]
---@return boolean
function Controls.AnyPressed(group)
    for index = 1, #group do
        if IsControlPressed(0, group[index]) or IsDisabledControlPressed(0, group[index]) then
            return true
        end
    end

    return false
end
