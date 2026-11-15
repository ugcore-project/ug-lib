--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Local peds that stand somewhere, such as shop clerks. Each one spawns when the player comes within
---`distance` and is deleted when they leave, so far away NPCs cost nothing.
---@class UgLib.Npc
local Npc = {}
UgLib.Npc = Npc

local Utils = UgLib.Internal.Utils

local RESOURCE = GetCurrentResourceName()
local OPTIONS = {
    model = true, coords = true, distance = true, animation = true, invincible = true, frozen = true,
    onSpawn = true, onDespawn = true, data = true,
}
local ANIMATION_OPTIONS = {
    dict = true,
    name = true,
    flag = true,
    scenario = true,
}
local DEFAULT_DISTANCE = 50.0
local MAX_DISTANCE = 500.0

---@class UgNpc
---@field id integer
---@field model integer
---@field coords vector4 position and heading
---@field ped? integer the handle while spawned
---@field data any
---@field point? UgZone the zone, set right after creation
---@field generation integer
---@field options table

---@type table<integer, UgNpc>
local npcs = {}
local nextId = 0

---@param animation any
---@return boolean
local function isAnimation(animation)
    if type(animation) ~= 'table' then
        return false
    end

    for key in pairs(animation) do
        if not ANIMATION_OPTIONS[key] then
            return false
        end
    end

    if animation.scenario ~= nil then
        return type(animation.scenario) == 'string' and animation.dict == nil and animation.name == nil
    end

    return type(animation.dict) == 'string' and type(animation.name) == 'string'
        and (animation.flag == nil or math.type(animation.flag) == 'integer')
end

---@param npc UgNpc
local function despawn(npc)
    npc.generation = npc.generation + 1

    local ped = npc.ped

    if not ped then
        return
    end

    npc.ped = nil

    if npc.options.onDespawn then
        npc.options.onDespawn(npc)
    end

    if DoesEntityExist(ped) then
        DeleteEntity(ped)
    end
end

---@param npc UgNpc
local function spawn(npc)
    npc.generation = npc.generation + 1

    local generation = npc.generation

    CreateThread(function()
        if not UgLib.Streaming.Model(npc.model) then
            return
        end

        -- The player left, or the NPC was removed, while the model loaded.
        if npc.generation ~= generation or npcs[npc.id] ~= npc or npc.ped then
            UgLib.Streaming.Release(UgLib.Enums.Asset.Model, npc.model)

            return
        end

        local coords, options = npc.coords, npc.options
        local ped = CreatePed(4, npc.model, coords.x, coords.y, coords.z - 1.0, coords.w, false, false)

        UgLib.Streaming.Release(UgLib.Enums.Asset.Model, npc.model)
        SetEntityHeading(ped, coords.w)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, false)
        SetEntityInvincible(ped, options.invincible ~= false)
        FreezeEntityPosition(ped, options.frozen ~= false)
        npc.ped = ped

        local animation = options.animation

        if animation then
            if animation.scenario then
                UgLib.Animation.Scenario(ped, animation.scenario)
            else
                UgLib.Animation.Play(ped, animation.dict, animation.name, {
                    flag = animation.flag or 1,
                })
            end
        end

        if options.onSpawn then
            options.onSpawn(npc)
        end
    end)
end

---Places an NPC. It spawns while the player is within `distance`.
---@param options { model: string|integer, coords: vector4, distance?: number, animation?: { dict?: string, name?: string, flag?: integer, scenario?: string }, invincible?: boolean, frozen?: boolean, onSpawn?: fun(npc: UgNpc), onDespawn?: fun(npc: UgNpc), data?: any }
---@return UgNpc
function Npc.Create(options)
    Utils.CheckOptions('Npc.Create', options, OPTIONS)

    local model = options.model

    if type(model) == 'string' then
        model = GetHashKey(model)
    end

    if math.type(model) ~= 'integer' then
        Utils.Raise(2, 'Npc.Create: model MUST be a name or hash')
    end

    ---@cast model integer

    if type(options.coords) ~= 'vector4' then
        Utils.Raise(2, 'Npc.Create: coords MUST be a vector4, got %s', type(options.coords))
    end

    local distance = options.distance or DEFAULT_DISTANCE

    if type(distance) ~= 'number' or distance <= 0 or distance > MAX_DISTANCE then
        Utils.Raise(2, 'Npc.Create: distance MUST be a number above 0 and at most %d', MAX_DISTANCE)
    end

    if options.animation ~= nil and not isAnimation(options.animation) then
        Utils.Raise(2, 'Npc.Create: animation MUST be { dict, name, flag? } or { scenario }')
    end

    nextId = nextId + 1

    local coords = options.coords
    ---@type UgNpc
    local npc = {
        id = nextId,
        model = model,
        coords = coords,
        data = options.data,
        generation = 0,
        options = options,
    }

    -- Registered first: Point.Create checks the zone at once and MAY spawn before it returns.
    npcs[npc.id] = npc
    npc.point = UgLib.Point.Create({
        coords = vector3(coords.x, coords.y, coords.z),
        distance = distance,
        onEnter = function()
            spawn(npc)
        end,
        onExit = function()
            despawn(npc)
        end,
    })

    return npc
end

---Removes an NPC and deletes its ped.
---@param npc UgNpc|integer
---@return boolean removed false when unknown
function Npc.Remove(npc)
    local id = type(npc) == 'table' and npc.id or npc
    local found = npcs[id]

    if not found then
        return false
    end

    npcs[id] = nil
    UgLib.Point.Remove(found.point)
    despawn(found)

    return true
end

---The ped of an NPC, or nil while it is not spawned.
---@param npc UgNpc|integer
---@return integer?
function Npc.GetPed(npc)
    local id = type(npc) == 'table' and npc.id or npc
    local found = npcs[id]

    return found and found.ped or nil
end

---Removes every NPC created in this runtime.
---@return integer count
function Npc.Clear()
    local count = 0

    for id in pairs(npcs) do
        Npc.Remove(id)
        count = count + 1
    end

    return count
end

AddEventHandler('onResourceStop', function(resource)
    if resource == RESOURCE then
        Npc.Clear()
    end
end)
