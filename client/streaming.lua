--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Loads game assets and waits for them. Every loader MUST run in a thread.
---Assets loaded through this runtime are released when its resource stops.
---@class UgLib.Streaming
local Streaming = {}
UgLib.Streaming = Streaming

local Utils = UgLib.Internal.Utils
local Asset = UgLib.Enums.Asset

local RESOURCE = GetCurrentResourceName()
local DEFAULT_TIMEOUT = 10000

---@class UgLibAssetKind
---@field exists? fun(name: any): boolean
---@field request fun(name: any): any
---@field loaded fun(name: any, handle: any): boolean
---@field release fun(name: any, handle: any)

---@type table<UgAsset, UgLibAssetKind>
local KINDS = {
    [Asset.Model] = {
        exists = function(hash)
            return IsModelInCdimage(hash) and IsModelValid(hash)
        end,
        request = RequestModel,
        loaded = HasModelLoaded,
        release = SetModelAsNoLongerNeeded,
    },
    [Asset.AnimDict] = {
        exists = DoesAnimDictExist,
        request = RequestAnimDict,
        loaded = HasAnimDictLoaded,
        release = RemoveAnimDict,
    },
    [Asset.AnimSet] = {
        request = RequestAnimSet,
        loaded = HasAnimSetLoaded,
        release = RemoveAnimSet,
    },
    [Asset.PtfxAsset] = {
        request = RequestNamedPtfxAsset,
        loaded = HasNamedPtfxAssetLoaded,
        release = RemoveNamedPtfxAsset,
    },
    [Asset.TextureDict] = {
        request = function(name)
            RequestStreamedTextureDict(name, false)
        end,
        loaded = HasStreamedTextureDictLoaded,
        release = SetStreamedTextureDictAsNoLongerNeeded,
    },
    [Asset.ScaleformMovie] = {
        request = RequestScaleformMovie,
        loaded = function(_, handle)
            return HasScaleformMovieLoaded(handle)
        end,
        release = function(_, handle)
            SetScaleformMovieAsNoLongerNeeded(handle)
        end,
    },
}

---@type table<string, { kind: UgAsset, name: any, handle: any }> by `kind:name`
local loaded = {}

---@param name string
---@param kind UgAsset
---@param asset any
---@param timeout any
---@return boolean ok
---@return any handle
local function load(name, kind, asset, timeout)
    timeout = timeout or DEFAULT_TIMEOUT

    if math.type(timeout) ~= 'integer' or timeout < 0 then
        Utils.Raise(3, '%s: timeout MUST be a non-negative integer in ms', name)
    end

    local _, isMain = coroutine.running()

    if isMain then
        Utils.Raise(3, '%s MUST run in a thread', name)
    end

    local definition = KINDS[kind]

    if definition.exists and not definition.exists(asset) then
        return false, nil
    end

    local handle = definition.request(asset)
    local ok = UgLib.Async.WaitFor(function()
        return definition.loaded(asset, handle)
    end, timeout)

    if ok then
        loaded[kind .. ':' .. tostring(asset)] = {
            kind = kind,
            name = asset,
            handle = handle,
        }
    end

    return ok, handle
end

---@param name string
---@param value any
local function checkName(name, value)
    if type(value) ~= 'string' or value == '' then
        Utils.Raise(3, '%s expects a name, got %s', name, type(value))
    end
end

---Loads a model by name or hash. False when the model does not exist or does not load in time.
---@param model string|integer
---@param timeout? integer ms, defaults to 10000
---@return boolean ok
function Streaming.Model(model, timeout)
    if type(model) == 'string' and model ~= '' then
        model = GetHashKey(model)
    elseif math.type(model) ~= 'integer' then
        Utils.Raise(2, 'Streaming.Model expects a model name or hash, got %s', type(model))
    end

    local ok = load('Streaming.Model', Asset.Model, model, timeout)

    return ok
end

---@param dict string
---@param timeout? integer ms, defaults to 10000
---@return boolean ok
function Streaming.AnimDict(dict, timeout)
    checkName('Streaming.AnimDict', dict)

    local ok = load('Streaming.AnimDict', Asset.AnimDict, dict, timeout)

    return ok
end

---@param set string
---@param timeout? integer ms, defaults to 10000
---@return boolean ok
function Streaming.AnimSet(set, timeout)
    checkName('Streaming.AnimSet', set)

    local ok = load('Streaming.AnimSet', Asset.AnimSet, set, timeout)

    return ok
end

---@param asset string
---@param timeout? integer ms, defaults to 10000
---@return boolean ok
function Streaming.PtfxAsset(asset, timeout)
    checkName('Streaming.PtfxAsset', asset)

    local ok = load('Streaming.PtfxAsset', Asset.PtfxAsset, asset, timeout)

    return ok
end

---@param dict string
---@param timeout? integer ms, defaults to 10000
---@return boolean ok
function Streaming.TextureDict(dict, timeout)
    checkName('Streaming.TextureDict', dict)

    local ok = load('Streaming.TextureDict', Asset.TextureDict, dict, timeout)

    return ok
end

---@param movie string
---@param timeout? integer ms, defaults to 10000
---@return boolean ok
---@return integer? handle the scaleform handle when loaded
function Streaming.ScaleformMovie(movie, timeout)
    checkName('Streaming.ScaleformMovie', movie)

    local ok, handle = load('Streaming.ScaleformMovie', Asset.ScaleformMovie, movie, timeout)

    return ok, ok and handle or nil
end

---Releases one asset loaded through this runtime. Models take their name or hash.
---@param kind UgAsset
---@param name string|integer
---@return boolean released false when it was not loaded here
function Streaming.Release(kind, name)
    Utils.CheckEnum('Streaming.Release', 'kind', kind, Asset)

    if kind == Asset.Model and type(name) == 'string' then
        name = GetHashKey(name)
    end

    local key = kind .. ':' .. tostring(name)
    local entry = loaded[key]

    if not entry then
        return false
    end

    loaded[key] = nil
    KINDS[kind].release(entry.name, entry.handle)

    return true
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then
        return
    end

    for _, entry in pairs(loaded) do
        KINDS[entry.kind].release(entry.name, entry.handle)
    end

    loaded = {}
end)
