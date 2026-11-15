--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Animations, scenarios and props on peds. Props created through this runtime are deleted when its resource stops.
---@class UgLib.Animation
local Animation = {}
UgLib.Animation = Animation

local Utils = UgLib.Internal.Utils

local RESOURCE = GetCurrentResourceName()
local PLAY_OPTIONS = {
    flag = true,
    blendIn = true,
    blendOut = true,
    duration = true,
    playbackRate = true,
}
local PROP_OPTIONS = {
    model = true,
    bone = true,
    offset = true,
    rotation = true,
    networked = true,
}
local ZERO = vector3(0.0, 0.0, 0.0)
-- SKEL_R_Hand. Bone ids are not in the Cfx docs: verify on a live server.
local RIGHT_HAND = 57005

---@type table<integer, integer> prop -> ped
local props = {}

---@param name string
---@param ped any
local function checkPed(name, ped)
    if math.type(ped) ~= 'integer' then
        Utils.Raise(3, '%s expects a ped handle, got %s', name, type(ped))
    end
end

---Loads the dictionary and plays the animation. MUST run in a thread.
---@param ped integer
---@param dict string
---@param name string
---@param options? { flag?: integer, blendIn?: number, blendOut?: number, duration?: integer, playbackRate?: number }
---@return boolean ok false when the dictionary does not load
function Animation.Play(ped, dict, name, options)
    checkPed('Animation.Play', ped)

    if type(dict) ~= 'string' or type(name) ~= 'string' then
        Utils.Raise(2, 'Animation.Play expects a dictionary and an animation name')
    end

    options = options and Utils.CheckOptions('Animation.Play', options, PLAY_OPTIONS) or {}

    local _, isMain = coroutine.running()

    if isMain then
        Utils.Raise(2, 'Animation.Play MUST run in a thread')
    end

    if not UgLib.Streaming.AnimDict(dict) then
        return false
    end

    TaskPlayAnim(
        ped, dict, name,
        options.blendIn or 8.0, options.blendOut or -8.0,
        options.duration or -1, options.flag or 0, options.playbackRate or 0.0,
        false, false, false
    )

    return true
end

---Plays a scenario in place, such as `WORLD_HUMAN_CLIPBOARD`.
---@param ped integer
---@param scenario string
function Animation.Scenario(ped, scenario)
    checkPed('Animation.Scenario', ped)

    if type(scenario) ~= 'string' then
        Utils.Raise(2, 'Animation.Scenario expects a scenario name')
    end

    TaskStartScenarioInPlace(ped, scenario, 0, true)
end

---Stops one animation, or every task of the ped when `dict` and `name` are nil.
---@param ped integer
---@param dict? string
---@param name? string
function Animation.Stop(ped, dict, name)
    checkPed('Animation.Stop', ped)

    if dict and name then
        StopAnimTask(ped, dict, name, 1.0)
    else
        ClearPedTasks(ped)
    end
end

---Creates a prop and attaches it to a ped bone. MUST run in a thread.
---Props are local unless `networked` is true. Servers with `sv_entityLockdown` block networked client props.
---@param ped integer
---@param options { model: string|integer, bone?: integer, offset?: vector3, rotation?: vector3, networked?: boolean } `bone` defaults to the right hand
---@return integer? prop nil when the model does not load
function Animation.AttachProp(ped, options)
    checkPed('Animation.AttachProp', ped)
    Utils.CheckOptions('Animation.AttachProp', options, PROP_OPTIONS)

    local model = options.model
    local hash = type(model) == 'string' and GetHashKey(model) or model

    if math.type(hash) ~= 'integer' then
        Utils.Raise(2, 'Animation.AttachProp: model MUST be a name or hash')
    end

    local _, isMain = coroutine.running()

    if isMain then
        Utils.Raise(2, 'Animation.AttachProp MUST run in a thread')
    end

    if not UgLib.Streaming.Model(hash) then
        return nil
    end

    local coords = GetEntityCoords(ped)
    local networked = options.networked == true
    local prop = CreateObject(hash, coords.x, coords.y, coords.z, networked, networked, false)
    local offset = options.offset or ZERO
    local rotation = options.rotation or ZERO

    AttachEntityToEntity(
        prop, ped, GetPedBoneIndex(ped, options.bone or RIGHT_HAND),
        offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z,
        true, true, false, true, 1, true
    )

    UgLib.Streaming.Release(UgLib.Enums.Asset.Model, hash)
    props[prop] = ped

    return prop
end

---Deletes one prop created by `AttachProp` in this runtime.
---@param prop integer
---@return boolean removed false when it was not created here
function Animation.RemoveProp(prop)
    if props[prop] == nil then
        return false
    end

    props[prop] = nil

    if DoesEntityExist(prop) then
        DeleteEntity(prop)
    end

    return true
end

---Deletes props attached through this runtime: those of `ped`, or all when `ped` is nil.
---@param ped? integer
---@return integer count props deleted
function Animation.DetachProps(ped)
    local count = 0

    for prop, owner in pairs(props) do
        if ped == nil or owner == ped then
            props[prop] = nil
            count = count + 1

            if DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
        end
    end

    return count
end

AddEventHandler('onResourceStop', function(resource)
    if resource == RESOURCE then
        Animation.DetachProps()
    end
end)
