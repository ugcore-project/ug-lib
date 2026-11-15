--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Per-frame drawing. Callers MUST call these every frame while the text or marker is wanted.
---@class UgLib.Draw
local Draw = {}
UgLib.Draw = Draw

local Utils = UgLib.Internal.Utils
local Cache = UgLib.Cache

-- Called every frame: natives cached as locals.
local SetTextScale = SetTextScale
local SetTextFont = SetTextFont
local SetTextColour = SetTextColour
local SetTextCentre = SetTextCentre
local SetTextOutline = SetTextOutline
local BeginTextCommandDisplayText = BeginTextCommandDisplayText
local AddTextComponentSubstringPlayerName = AddTextComponentSubstringPlayerName
local EndTextCommandDisplayText = EndTextCommandDisplayText
local SetDrawOrigin = SetDrawOrigin
local ClearDrawOrigin = ClearDrawOrigin
local DrawMarker = DrawMarker
local GetEntityCoords = GetEntityCoords

local TEXT_OPTIONS = {
    scale = true,
    font = true,
    color = true,
    maxDistance = true,
    outline = true,
    center = true,
}
local MARKER_OPTIONS = {
    size = true,
    color = true,
    direction = true,
    rotation = true,
    bob = true,
    faceCamera = true,
    rotate = true,
    maxDistance = true,
}

local WHITE = { 255, 255, 255, 215 }
local MARKER_COLOR = { 139, 92, 246, 160 }
local DEFAULT_SIZE = vector3(1.0, 1.0, 1.0)
local ZERO = vector3(0.0, 0.0, 0.0)

-- Options tables already checked. Callers usually pass the same table every frame.
---@type table<table, boolean>
local checked = setmetatable({}, {
    __mode = 'k',
})

local EMPTY = {}

---@param options any
---@return boolean
local function needsCheck(options)
    return options ~= nil and not checked[options]
end

---MUST be called directly from the public function.
---@param name string
---@param options any
local function check(name, options)
    local color = options.color

    if color ~= nil and (type(color) ~= 'table' or #color < 3) then
        Utils.Raise(3, '%s: color MUST be { r, g, b, a? } from 0 to 255', name)
    end

    checked[options] = true
end

---@param options table
local function prepareText(options)
    local color = options.color or WHITE

    SetTextScale(0.0, options.scale or 0.35)
    SetTextFont(options.font or 4)
    SetTextColour(color[1], color[2], color[3], color[4] or 215)
    SetTextCentre(options.center ~= false)

    if options.outline ~= false then
        SetTextOutline()
    end

    BeginTextCommandDisplayText('STRING')
end

---@param coords vector3
---@param maxDistance number?
---@return boolean
local function inRange(coords, maxDistance)
    return maxDistance == nil or #(GetEntityCoords(Cache.Ped) - coords) <= maxDistance
end

---Text at a world position.
---@param coords vector3
---@param text string
---@param options? { scale?: number, font?: integer, color?: integer[], maxDistance?: number, outline?: boolean, center?: boolean }
function Draw.Text3D(coords, text, options)
    if needsCheck(options) then
        Utils.CheckOptions('Draw.Text3D', options, TEXT_OPTIONS)
        check('Draw.Text3D', options)
    end

    options = options or EMPTY

    if not inRange(coords, options.maxDistance) then
        return
    end

    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    prepareText(options)
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

---Text at a screen position, from 0 to 1 on each axis.
---@param x number
---@param y number
---@param text string
---@param options? { scale?: number, font?: integer, color?: integer[], outline?: boolean, center?: boolean }
function Draw.Text2D(x, y, text, options)
    if needsCheck(options) then
        Utils.CheckOptions('Draw.Text2D', options, TEXT_OPTIONS)
        check('Draw.Text2D', options)
    end

    options = options or EMPTY

    prepareText(options)
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

---A marker of a game marker type, such as 1 for a cylinder or 2 for a chevron.
---@param markerType integer
---@param coords vector3
---@param options? { size?: vector3, color?: integer[], direction?: vector3, rotation?: vector3, bob?: boolean, faceCamera?: boolean, rotate?: boolean, maxDistance?: number }
function Draw.Marker(markerType, coords, options)
    if needsCheck(options) then
        Utils.CheckOptions('Draw.Marker', options, MARKER_OPTIONS)
        check('Draw.Marker', options)
    end

    options = options or EMPTY

    if not inRange(coords, options.maxDistance) then
        return
    end

    local size = options.size or DEFAULT_SIZE
    local direction = options.direction or ZERO
    local rotation = options.rotation or ZERO
    local color = options.color or MARKER_COLOR

    DrawMarker(
        markerType,
        coords.x, coords.y, coords.z,
        direction.x, direction.y, direction.z,
        rotation.x, rotation.y, rotation.z,
        size.x, size.y, size.z,
        color[1], color[2], color[3], color[4] or 160,
        options.bob == true, options.faceCamera == true, 2, options.rotate == true,
        nil, nil, false
    )
end
