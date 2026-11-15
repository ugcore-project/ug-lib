--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Test runner and native mocks. Suites run from the repo root with plain Lua 5.4.
---@class TestHelpers
---@field ResourceFiles table<string, string> in-memory files of the mocked resource
---@field Convars table<string, string>
---@field Clock integer mocked GetGameTimer value in ms
---@field IsServer boolean
---@field Kvp table<string, string> resource KVP, survives LoadManifest like a real reboot
---@field CurrentResource string what GetCurrentResourceName returns
---@field ResourceMetadata table<string, table<string, string>> manifest entries of other resources: resource -> key -> value
---@field OtherFiles table<string, table<string, string>> files of other resources: resource -> path -> content
local Helpers = {
    OtherFiles = {},
    ResourceMetadata = {},
    CurrentResource = 'ug-lib',
    ResourceFiles = {},
    Convars = {},
    Kvp = {},
    Clock = 0,
    IsServer = true,
}

local RESOURCE_NAME = 'ug-lib'
local MANIFEST_PATH = 'fxmanifest.lua'
local MANIFEST_VERSION = '0.0.0-test'

local passed, failed = 0, 0

---@param ... any
---@return string
local function concatArgs(...)
    local parts = {}

    for index = 1, select('#', ...) do
        parts[index] = tostring((select(index, ...)))
    end

    return table.concat(parts, '\t')
end

---@type fun(...: any)
local realPrint = print

---@type string[]?
local captured = nil

print = function(...)
    if captured then
        captured[#captured + 1] = concatArgs(...)
    else
        realPrint(...)
    end
end

---@return string
function GetCurrentResourceName()
    return Helpers.CurrentResource
end

---@return boolean
function IsDuplicityVersion()
    return Helpers.IsServer
end

---ug-lib files missing from ResourceFiles load from disk, so suites see the real source.
---@param resource string
---@param path string
---@return string?
function LoadResourceFile(resource, path)
    if resource ~= RESOURCE_NAME then
        return (Helpers.OtherFiles[resource] or {})[path]
    end

    local content = Helpers.ResourceFiles[path]

    if content == nil and not path:find('^config/') then
        local file = io.open(path, 'rb')

        if file then
            content = file:read('a')
            file:close()
        end
    end

    return content
end

---@param resource string
---@param path string
---@param data string
---@param length integer
---@return boolean
function SaveResourceFile(resource, path, data, length)
    if resource ~= RESOURCE_NAME then
        return false
    end

    Helpers.ResourceFiles[path] = data:sub(1, length)

    return true
end

---@param resource string
---@param key string
---@param index integer
---@return string?
function GetResourceMetadata(resource, key, index)
    local entries = Helpers.ResourceMetadata[resource]

    if resource == RESOURCE_NAME and key == 'version' and index == 0 then
        return entries and entries.version or MANIFEST_VERSION
    end

    return index == 0 and entries and entries[key] or nil
end

---@param name string
---@param default string
---@return string
function GetConvar(name, default)
    local value = Helpers.Convars[name]

    if value == nil then
        return default
    end

    return value
end

---@param key string
---@return string?
function GetResourceKvpString(key)
    return Helpers.Kvp[key]
end

---@param key string
---@param value string
function SetResourceKvp(key, value)
    Helpers.Kvp[key] = value
end

---@type table<string, fun(source: integer, args: string[], raw: string)>
local commands = {}

---@param name string
---@param handler fun(source: integer, args: string[], raw: string)
---@param restricted boolean
function RegisterCommand(name, handler, restricted)
    commands[name] = handler
end

---@return integer
function GetGameTimer()
    return Helpers.Clock
end

---@class TestStateBagHandler
---@field key string
---@field bag string
---@field handler fun(bagName: string, key: string, value: any)

---@type TestStateBagHandler[]
local stateBagHandlers = {}

---@param key string
---@param bagName string
---@param handler fun(bagName: string, key: string, value: any)
---@return integer
function AddStateBagChangeHandler(key, bagName, handler)
    stateBagHandlers[#stateBagHandlers + 1] = {
        key = key,
        bag = bagName,
        handler = handler,
    }

    return #stateBagHandlers
end

---Like FiveM, handlers run before the new value is readable from GlobalState.
GlobalState = {
    ---@param self table
    ---@param key string
    ---@param value any
    ---@param _ boolean?
    set = function(self, key, value, _)
        for _, entry in ipairs(stateBagHandlers) do
            if entry.key == key and entry.bag == 'global' then
                entry.handler('global', key, value)
            end
        end

        rawset(self, key, value)
    end,
}

---Minimal json like the CfxLua one: objects, arrays, strings, numbers, booleans. Empty tables encode as `[]`.
json = {}

---@param value any
---@return string
function json.encode(value)
    local kind = type(value)

    if kind == 'nil' then
        return 'null'
    end

    if kind == 'boolean' then
        return tostring(value)
    end

    if kind == 'number' then
        return math.type(value) == 'integer' and tostring(value) or ('%.17g'):format(value)
    end

    if kind == 'string' then
        return '"' .. value:gsub('[%c"\\]', function(char)
            return ('\\u%04x'):format(char:byte())
        end) .. '"'
    end

    if kind ~= 'table' then
        error('cannot encode a ' .. kind, 2)
    end

    local count = 0

    for _ in pairs(value) do
        count = count + 1
    end

    local parts = {}

    if count == #value then
        for index = 1, #value do
            parts[index] = json.encode(value[index])
        end

        return '[' .. table.concat(parts, ',') .. ']'
    end

    local keys = {}

    for key in pairs(value) do
        keys[#keys + 1] = tostring(key)
    end

    table.sort(keys)

    for index, key in ipairs(keys) do
        local entry = value[key]

        if entry == nil then
            entry = value[tonumber(key)]
        end

        parts[index] = json.encode(key) .. ':' .. json.encode(entry)
    end

    return '{' .. table.concat(parts, ',') .. '}'
end

---@param text string
---@return any
function json.decode(text)
    local position = 1

    local function skip()
        position = text:find('[^%s]', position) or #text + 1
    end

    local parse

    local function parseString()
        local result = {}

        position = position + 1

        while true do
            local char = text:sub(position, position)

            if char == '"' then
                position = position + 1
                return table.concat(result)
            end

            if char == '\\' then
                local escape = text:sub(position + 1, position + 1)

                if escape == 'u' then
                    result[#result + 1] = utf8.char(tonumber(text:sub(position + 2, position + 5), 16))
                    position = position + 6
                else
                    result[#result + 1] = ({
                        n = '\n',
                        t = '\t',
                        r = '\r',
                    })[escape] or escape
                    position = position + 2
                end
            else
                result[#result + 1] = char
                position = position + 1
            end
        end
    end

    parse = function()
        skip()

        local char = text:sub(position, position)

        if char == '{' then
            local result = {}

            position = position + 1
            skip()

            if text:sub(position, position) == '}' then
                position = position + 1
                return result
            end

            while true do
                skip()

                local key = parseString()

                skip()
                position = position + 1
                result[key] = parse()
                skip()

                local separator = text:sub(position, position)

                position = position + 1

                if separator == '}' then
                    return result
                end
            end
        end

        if char == '[' then
            local result = {}

            position = position + 1
            skip()

            if text:sub(position, position) == ']' then
                position = position + 1
                return result
            end

            while true do
                result[#result + 1] = parse()
                skip()

                local separator = text:sub(position, position)

                position = position + 1

                if separator == ']' then
                    return result
                end
            end
        end

        if char == '"' then
            return parseString()
        end

        for literal, value in pairs({
            ['true'] = true,
            ['false'] = false,
            ['null'] = json,
        }) do
            if text:sub(position, position + #literal - 1) == literal then
                position = position + #literal

                if value == json then
                    return nil
                end

                return value
            end
        end

        local number = text:match('^-?%d+%.?%d*[eE]?[-+]?%d*', position)

        position = position + #number

        return math.tointeger(tonumber(number)) or tonumber(number)
    end

    return parse()
end

---@class TestEventHandle
---@field key integer
---@field name string
---@field handler fun(...: any)
---@field removed boolean

---@type TestEventHandle[]
local eventHandlers = {}

local nextEventKey = 0

---@type string?
local invokingResource = nil

---@class TestTimer
---@field at integer
---@field callback fun()

---@type TestTimer[]
local timers = {}

---Fires on the first Helpers.Advance that reaches it, never during the Advance that created it.
---@param ms integer
---@param callback fun()
function SetTimeout(ms, callback)
    timers[#timers + 1] = {
        at = Helpers.Clock + ms,
        callback = callback,
    }
end

---@class TestPromise
---@field settled boolean
---@field value any
---@field waiting thread[]
local TestPromise = {}
TestPromise.__index = TestPromise

---@param value any
function TestPromise:resolve(value)
    if self.settled then
        return
    end

    self.settled = true
    self.value = value

    for index = 1, #self.waiting do
        local ok, err = coroutine.resume(self.waiting[index])

        if not ok then
            error(err, 0)
        end
    end
end

promise = {
    ---@return TestPromise
    new = function()
        return setmetatable({
            settled = false,
            waiting = {},
        }, TestPromise)
    end,
}

Citizen = {
    ---Yields the running thread until `p` settles.
    ---@param p TestPromise
    ---@return any
    Await = function(p)
        if p.settled then
            return p.value
        end

        local co, isMain = coroutine.running()

        if isMain then
            error('Citizen.Await called outside a thread', 2)
        end

        p.waiting[#p.waiting + 1] = co
        coroutine.yield()

        return p.value
    end,
}

---@param name string
---@param handler fun(...: any)
---@return TestEventHandle
function AddEventHandler(name, handler)
    nextEventKey = nextEventKey + 1

    local handle = {
        key = nextEventKey,
        name = name,
        handler = handler,
        removed = false,
    }
    eventHandlers[#eventHandlers + 1] = handle

    return handle
end

---@param handle TestEventHandle
function RemoveEventHandler(handle)
    handle.removed = true

    for index = #eventHandlers, 1, -1 do
        if eventHandlers[index] == handle then
            table.remove(eventHandlers, index)
        end
    end
end

---@return string?
function GetInvokingResource()
    return invokingResource
end

---Runs the handlers of `name` like FiveM: a snapshot of the current handlers, each as a thread, with the invoking resource set.
---@param name string
---@param invoker string?
---@param ... any
local function dispatch(name, invoker, ...)
    local snapshot = {}

    for index = 1, #eventHandlers do
        if eventHandlers[index].name == name then
            snapshot[#snapshot + 1] = eventHandlers[index]
        end
    end

    local previousInvoker = invokingResource
    invokingResource = invoker

    for index = 1, #snapshot do
        if not snapshot[index].removed then
            local co = coroutine.create(snapshot[index].handler)
            local ok, err = coroutine.resume(co, ...)

            if not ok then
                invokingResource = previousInvoker
                error(err, 0)
            end
        end
    end

    invokingResource = previousInvoker
end

---Local event from the current resource. Arguments are passed as-is, without msgpack copies.
---@param name string
---@param ... any
function TriggerEvent(name, ...)
    dispatch(name, Helpers.CurrentResource, ...)
end

---Event raised by FiveM itself or by another resource. `invoker` is nil for engine events.
---@param name string
---@param invoker string?
---@param ... any
function Helpers.TriggerEvent(name, invoker, ...)
    dispatch(name, invoker, ...)
end

---Runs `fn` as a coroutine right away, until its first Wait. Errors surface like in FiveM: printed, not raised.
---@param fn fun()
function CreateThread(fn)
    local co = coroutine.create(fn)
    local ok, err = coroutine.resume(co)

    if not ok then
        realPrint('thread error: ' .. tostring(err))
    end
end

---Yields the running thread until Helpers.Advance reaches `ms` from now.
---@param ms integer
function Wait(ms)
    local co, isMain = coroutine.running()

    if isMain then
        error('Wait(' .. tostring(ms) .. ') called outside a thread', 2)
    end

    SetTimeout(ms, function()
        local ok, err = coroutine.resume(co)

        if not ok then
            realPrint('thread error: ' .. tostring(err))
        end
    end)

    coroutine.yield()
end

---@type fun(value: any): string
local rawType = type

---@type table<table, string>
local vectorKinds = setmetatable({}, {
    __mode = 'k',
})

---Mocks the CfxLua `type`, which names vectors instead of returning "userdata".
---@param value any
---@return string
type = function(value)
    return rawType(value) == 'table' and vectorKinds[value] or rawType(value)
end

local VECTOR_KEYS = { 'x', 'y', 'z', 'w' }

local VectorMeta = {
    __sub = function(a, b)
        local result = {}

        for _, key in ipairs(VECTOR_KEYS) do
            if a[key] ~= nil then
                result[key] = a[key] - b[key]
            end
        end

        vectorKinds[result] = vectorKinds[a]

        return setmetatable(result, getmetatable(a))
    end,
    __len = function(a)
        local sum = 0

        for _, key in ipairs(VECTOR_KEYS) do
            if a[key] ~= nil then
                sum = sum + a[key] * a[key]
            end
        end

        return math.sqrt(sum)
    end,
}

---@param kind string
---@param components table
---@return table
local function newVector(kind, components)
    vectorKinds[components] = kind

    return setmetatable(components, VectorMeta)
end

---@param x number
---@param y number
---@return vector2
function vector2(x, y)
    return newVector('vector2', {
        x = x,
        y = y,
    })
end

---@param x number
---@param y number
---@param z number
---@return vector3
function vector3(x, y, z)
    return newVector('vector3', {
        x = x,
        y = y,
        z = z,
    })
end

---@param x number
---@param y number
---@param z number
---@param w number
---@return vector4
function vector4(x, y, z, w)
    return newVector('vector4', {
        x = x,
        y = y,
        z = z,
        w = w,
    })
end

---@type table<string, table<string, table<string, function>>> side -> resource -> export name -> function
local exported = {
    server = {},
    client = {},
}

---@return string
local function sideName()
    return Helpers.IsServer and 'server' or 'client'
end

---Like FiveM: `exports(name, fn)` registers for the running resource on this side,
---`exports[resource]:Name(...)` calls it with the running resource as invoking resource.
---@param running fun(): string the resource whose code uses this `exports`
---@return table
local function newExports(running)
    return setmetatable({}, {
        __call = function(_, name, fn)
            local bySide = exported[sideName()]
            local own = bySide[running()] or {}

            own[name] = fn
            bySide[running()] = own
        end,
        __index = function(_, resource)
            local caller = running()
            local side = sideName()

            return setmetatable({}, {
                __index = function(_, name)
                    return function(_, ...)
                        local fn = (exported[side][resource] or {})[name]

                        if not fn then
                            error(('No such export %s in resource %s'):format(name, resource), 2)
                        end

                        local previousResource, previousInvoker = Helpers.CurrentResource, invokingResource
                        Helpers.CurrentResource, invokingResource = resource, caller

                        local results = table.pack(pcall(fn, ...))

                        Helpers.CurrentResource, invokingResource = previousResource, previousInvoker

                        if not results[1] then
                            error(results[2], 0)
                        end

                        return table.unpack(results, 2, results.n)
                    end
                end,
            })
        end,
    })
end

exports = newExports(function()
    return Helpers.CurrentResource
end)

---Jenkins one-at-a-time over the lowercase name, as signed 32-bit, like GET_HASH_KEY.
---@param name string
---@return integer
function GetHashKey(name)
    local hash = 0

    for index = 1, #name do
        hash = (hash + name:lower():byte(index)) & 0xFFFFFFFF
        hash = (hash + (hash << 10)) & 0xFFFFFFFF
        hash = hash ~ (hash >> 6)
    end

    hash = (hash + (hash << 3)) & 0xFFFFFFFF
    hash = hash ~ (hash >> 11)
    hash = (hash + (hash << 15)) & 0xFFFFFFFF

    return hash >= 0x80000000 and hash - 0x100000000 or hash
end

---@class TestEntity
---@field pool 'CPed'|'CVehicle'|'CObject'
---@field coords vector3
---@field heading number
---@field model integer
---@field player? integer player id of a player ped
---@field weapon? integer selected weapon hash
---@field vehicle? integer vehicle the ped is in
---@field seats? table<integer, integer> seat -> ped, for vehicles
---@field maxPassengers? integer
---@field networked? boolean
---@field attachedTo? integer
---@field bone? integer
---@field dead? boolean
---@field frozen? boolean
---@field invincible? boolean

---@class TestShapeTest
---@field hit boolean
---@field coords? vector3
---@field normal? vector3
---@field entity? integer
---@field material? integer

---@class TestWorld
---@field localPlayer integer
---@field players table<integer, { serverId: integer, ped: integer }>
---@field entities table<integer, TestEntity>
---@field assets table<string, boolean> available assets as `kind:name`, models by hash
---@field requested table<string, boolean>
---@field released string[]
---@field calls { name: string, args: table }[] natives that only draw or change peds, in call order
---@field probes table[] arguments of StartShapeTestLosProbe
---@field shapeTest TestShapeTest result of the next shape test
---@field camCoord vector3
---@field camRot vector3
---@field nextHandle integer
---@field disabled table<integer, integer> control -> times disabled, cleared by tests
---@field pressed table<integer, boolean> controls held down
---@field mappings table[] arguments of every RegisterKeyMapping
---@field buttons table<integer, string> instructional button per control hash

---@return TestWorld
local function newWorld()
    return {
        localPlayer = 0,
        players = {
            [0] = {
                serverId = 1,
                ped = 100,
            },
        },
        entities = {
            [100] = {
                pool = 'CPed',
                coords = vector3(0.0, 0.0, 0.0),
                heading = 0.0,
                model = 0,
                player = 0,
            },
        },
        assets = {},
        requested = {},
        released = {},
        calls = {},
        probes = {},
        shapeTest = {
            hit = false,
        },
        camCoord = vector3(0.0, 0.0, 0.0),
        camRot = vector3(0.0, 0.0, 0.0),
        nextHandle = 1000,
        disabled = {},
        pressed = {},
        mappings = {},
        -- Instructional button per control hash, for GetControlInstructionalButton.
        buttons = {},
    }
end

Helpers.World = newWorld()

---Adds an entity and returns its handle.
---@param pool 'CPed'|'CVehicle'|'CObject'
---@param coords vector3
---@param fields? table extra TestEntity fields
---@return integer
function Helpers.AddEntity(pool, coords, fields)
    local world = Helpers.World
    world.nextHandle = world.nextHandle + 1

    local entity = {
        pool = pool,
        coords = coords,
        heading = 0.0,
        model = 0,
    }

    for key, value in pairs(fields or {}) do
        entity[key] = value
    end

    world.entities[world.nextHandle] = entity

    return world.nextHandle
end

---Adds another player with a ped and returns the ped.
---@param playerId integer
---@param serverId integer
---@param coords vector3
---@return integer ped
function Helpers.AddPlayer(playerId, serverId, coords)
    local ped = Helpers.AddEntity('CPed', coords, {
        player = playerId,
    })
    Helpers.World.players[playerId] = {
        serverId = serverId,
        ped = ped,
    }

    return ped
end

---Names of the recorded natives called so far, in order.
---@return string[]
function Helpers.CallNames()
    local names = {}

    for index, call in ipairs(Helpers.World.calls) do
        names[index] = call.name
    end

    return names
end

---@param name string
local function record(name)
    _G[name] = function(...)
        local calls = Helpers.World.calls
        calls[#calls + 1] = {
            name = name,
            args = table.pack(...),
        }
    end
end

for _, name in ipairs({
    'SetTextScale', 'SetTextFont', 'SetTextColour', 'SetTextCentre', 'SetTextOutline', 'BeginTextCommandDisplayText',
    'AddTextComponentSubstringPlayerName', 'EndTextCommandDisplayText', 'SetDrawOrigin', 'ClearDrawOrigin', 'DrawMarker',
    'TaskPlayAnim', 'StopAnimTask', 'ClearPedTasks', 'TaskStartScenarioInPlace', 'DrawLine', 'PlaySoundFrontend',
    'SetBlockingOfNonTemporaryEvents', 'SetPedCanRagdoll',
}) do
    record(name)
end

---@param entity integer
---@return TestEntity?
local function entityOf(entity)
    return Helpers.World.entities[entity]
end

---@return integer
function PlayerPedId()
    return Helpers.World.players[Helpers.World.localPlayer].ped
end

---@return integer
function PlayerId()
    return Helpers.World.localPlayer
end

---@param playerId integer
---@return integer
function GetPlayerServerId(playerId)
    local player = Helpers.World.players[playerId]

    return player and player.serverId or 0
end

---@param playerId integer
---@return integer
function GetPlayerPed(playerId)
    local player = Helpers.World.players[playerId]

    return player and player.ped or 0
end

---@return integer[]
function GetActivePlayers()
    local ids = {}

    for playerId in pairs(Helpers.World.players) do
        ids[#ids + 1] = playerId
    end

    table.sort(ids)

    return ids
end

---@param entity integer
---@return vector3
function GetEntityCoords(entity)
    local found = entityOf(entity)

    return found and found.coords or vector3(0.0, 0.0, 0.0)
end

---@param entity integer
---@return number
function GetEntityHeading(entity)
    local found = entityOf(entity)

    return found and found.heading or 0.0
end

---@param entity integer
---@return boolean
function DoesEntityExist(entity)
    return entityOf(entity) ~= nil
end

---@param ped integer
---@param _ boolean
---@return integer
function GetVehiclePedIsIn(ped, _)
    local found = entityOf(ped)

    return found and found.vehicle or 0
end

---@param vehicle integer
---@return integer
function GetVehicleMaxNumberOfPassengers(vehicle)
    local found = entityOf(vehicle)

    return found and found.maxPassengers or 3
end

---@param vehicle integer
---@param seat integer
---@return integer
function GetPedInVehicleSeat(vehicle, seat)
    local found = entityOf(vehicle)

    return found and found.seats and found.seats[seat] or 0
end

---@param ped integer
---@return integer
function GetSelectedPedWeapon(ped)
    local found = entityOf(ped)

    return found and found.weapon or GetHashKey('WEAPON_UNARMED')
end

---@param ped integer
---@return boolean
function IsPedAPlayer(ped)
    local found = entityOf(ped)

    return found ~= nil and found.player ~= nil
end

---@param pool string
---@return integer[]
function GetGamePool(pool)
    local handles = {}

    for handle, entity in pairs(Helpers.World.entities) do
        if entity.pool == pool then
            handles[#handles + 1] = handle
        end
    end

    table.sort(handles)

    return handles
end

---@param kind string
---@param name any
---@return string
local function assetKey(kind, name)
    return kind .. ':' .. tostring(name)
end

---Declares an asset that exists and loads.
---@param kind string such as `model`, `animDict`
---@param name string|integer
function Helpers.AddAsset(kind, name)
    if kind == 'model' and type(name) == 'string' then
        name = GetHashKey(name)
    end

    Helpers.World.assets[assetKey(kind, name)] = true
end

---@param kind string
---@return fun(name: any): boolean exists
---@return fun(name: any): nil request
---@return fun(name: any): boolean loaded
---@return fun(name: any) release
local function assetNatives(kind)
    return function(name)
        return Helpers.World.assets[assetKey(kind, name)] == true
    end, function(name)
        Helpers.World.requested[assetKey(kind, name)] = true

        return nil
    end, function(name)
        local key = assetKey(kind, name)

        return Helpers.World.requested[key] == true and Helpers.World.assets[key] == true
    end, function(name)
        local released = Helpers.World.released
        released[#released + 1] = assetKey(kind, name)
    end
end

local modelExists
modelExists, RequestModel, HasModelLoaded, SetModelAsNoLongerNeeded = assetNatives('model')

---@param hash integer
---@return boolean
function IsModelInCdimage(hash)
    return modelExists(hash)
end

---@param hash integer
---@return boolean
function IsModelValid(hash)
    return modelExists(hash)
end

DoesAnimDictExist, RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict = assetNatives('animDict')

local _
_, RequestAnimSet, HasAnimSetLoaded, RemoveAnimSet = assetNatives('animSet')
_, RequestNamedPtfxAsset, HasNamedPtfxAssetLoaded, RemoveNamedPtfxAsset = assetNatives('ptfxAsset')
_, RequestStreamedTextureDict, HasStreamedTextureDictLoaded, SetStreamedTextureDictAsNoLongerNeeded = assetNatives('textureDict')

---The handle of a scaleform movie is its name with `#` in front, so tests can read it.
---@param name string
---@return string
function RequestScaleformMovie(name)
    Helpers.World.requested[assetKey('scaleformMovie', name)] = true

    return '#' .. name
end

---@param handle string
---@return boolean
function HasScaleformMovieLoaded(handle)
    return Helpers.World.assets[assetKey('scaleformMovie', handle:sub(2))] == true
end

---@param handle string
function SetScaleformMovieAsNoLongerNeeded(handle)
    local released = Helpers.World.released
    released[#released + 1] = assetKey('scaleformMovie', handle:sub(2))
end

---@type table<integer, integer> shape test handle -> results read so far
local shapeTests = {}

---@return integer
function StartShapeTestLosProbe(...)
    local probes = Helpers.World.probes
    probes[#probes + 1] = table.pack(...)
    shapeTests[#probes] = 0

    return #probes
end

---Pending on the first read, like a test that needs a frame. Then the result of `Helpers.World.shapeTest`.
---@param handle integer
---@return integer status
---@return boolean hit
---@return vector3 coords
---@return vector3 normal
---@return integer material
---@return integer entity
function GetShapeTestResultIncludingMaterial(handle)
    local zero = vector3(0.0, 0.0, 0.0)

    shapeTests[handle] = (shapeTests[handle] or 0) + 1

    if shapeTests[handle] == 1 then
        return 1, false, zero, zero, 0, 0
    end

    local result = Helpers.World.shapeTest

    return 2, result.hit, result.coords or zero, result.normal or zero, result.material or 0, result.entity or 0
end

---@return vector3
function GetGameplayCamCoord()
    return Helpers.World.camCoord
end

---@param _ integer
---@return vector3
function GetGameplayCamRot(_)
    return Helpers.World.camRot
end

---On screen when not behind the camera on the y axis, at the screen center.
---@param x number
---@param y number
---@param z number
---@return boolean onScreen
---@return number screenX
---@return number screenY
function GetScreenCoordFromWorldCoord(x, y, z)
    if y < Helpers.World.camCoord.y then
        return false, -1.0, -1.0
    end

    return true, 0.5, 0.5
end

---@return integer width
---@return integer height
function GetActiveScreenResolution()
    return 1920, 1080
end

---@param _ boolean
---@return number
function GetAspectRatio(_)
    return 1920 / 1080
end

---@param hash integer
---@param x number
---@param y number
---@param z number
---@param networked boolean
---@return integer
function CreateObject(hash, x, y, z, networked)
    return Helpers.AddEntity('CObject', vector3(x, y, z), {
        model = hash,
        networked = networked,
    })
end

---@param entity integer
function DeleteEntity(entity)
    Helpers.World.entities[entity] = nil
end

---@param _ integer
---@param hash integer
---@param x number
---@param y number
---@param z number
---@param heading number
---@param networked boolean
---@return integer
function CreatePed(_, hash, x, y, z, heading, networked)
    return Helpers.AddEntity('CPed', vector3(x, y, z), {
        model = hash,
        heading = heading,
        networked = networked,
    })
end

---@param entity integer
---@param heading number
function SetEntityHeading(entity, heading)
    local found = Helpers.World.entities[entity]

    if found then
        found.heading = heading
    end
end

---@param entity integer
---@param frozen boolean
function FreezeEntityPosition(entity, frozen)
    local found = Helpers.World.entities[entity]

    if found then
        found.frozen = frozen
    end
end

---@param entity integer
---@param invincible boolean
function SetEntityInvincible(entity, invincible)
    local found = Helpers.World.entities[entity]

    if found then
        found.invincible = invincible
    end
end

---@param padIndex integer
---@param control integer
---@param disable boolean
function DisableControlAction(padIndex, control, disable)
    Helpers.World.disabled[control] = (Helpers.World.disabled[control] or 0) + 1
end

---@param _ integer
---@param control integer
---@return boolean
function IsControlPressed(_, control)
    return Helpers.World.pressed[control] == true
end

---Edges are not modeled: a held control counts as just released.
---@param _ integer
---@param control integer
---@return boolean
function IsControlJustReleased(_, control)
    return Helpers.World.pressed[control] == true
end

---@param _ integer
---@param control integer
---@return boolean
function IsDisabledControlPressed(_, control)
    return Helpers.World.pressed[control] == true
end

---@param _ integer
---@param control integer
---@return string
function GetControlInstructionalButton(_, control)
    return Helpers.World.buttons[control] or ''
end

---@param ... any
function RegisterKeyMapping(...)
    local mappings = Helpers.World.mappings
    mappings[#mappings + 1] = table.pack(...)
end

---@param entity integer
---@return boolean
function IsEntityDead(entity)
    local found = entityOf(entity)

    return found ~= nil and found.dead == true
end

---@param _ integer
---@param bone integer
---@return integer
function GetPedBoneIndex(_, bone)
    return bone
end

---@param entity integer
---@param target integer
---@param boneIndex integer
function AttachEntityToEntity(entity, target, boneIndex, ...)
    local found = entityOf(entity)

    if found then
        found.attachedTo = target
        found.bone = boneIndex
    end
end

---@class TestNui
---@field messages table[] every SendNUIMessage, oldest first
---@field focus { focus: boolean, cursor: boolean, keepInput: boolean }
---@field focusCalls integer SetNuiFocus and SetNuiFocusKeepInput calls
---@field zIndex? integer the last SetNuiZindex value
---@field otherFocus boolean another resource holds NUI focus
---@field callbacks table<string, fun(data: any, cb: fun(result: any))>

---@return TestNui
local function newNui()
    return {
        messages = {},
        focus = {
            focus = false,
            cursor = false,
            keepInput = false,
        },
        focusCalls = 0,
        otherFocus = false,
        callbacks = {},
    }
end

Helpers.Nui = newNui()

---@param message table
function SendNUIMessage(message)
    local messages = Helpers.Nui.messages
    messages[#messages + 1] = message
end

---@param focus boolean
---@param cursor boolean
function SetNuiFocus(focus, cursor)
    Helpers.Nui.focus.focus = focus
    Helpers.Nui.focus.cursor = cursor
    Helpers.Nui.focusCalls = Helpers.Nui.focusCalls + 1
end

---@return boolean
function IsNuiFocused()
    return Helpers.Nui.focus.focus or Helpers.Nui.otherFocus
end

---@param zIndex integer
function SetNuiZindex(zIndex)
    Helpers.Nui.zIndex = zIndex
end

---@param keepInput boolean
function SetNuiFocusKeepInput(keepInput)
    Helpers.Nui.focus.keepInput = keepInput
    Helpers.Nui.focusCalls = Helpers.Nui.focusCalls + 1
end

---@param name string
---@param handler fun(data: any, cb: fun(result: any))
function RegisterNUICallback(name, handler)
    Helpers.Nui.callbacks[name] = handler
end

---Posts to a NUI callback like the page, or like an executor forging a request. Returns what the callback replied.
---@param name string
---@param data any
---@return any reply nil when the callback never replied
function Helpers.PostNui(name, data)
    local handler = Helpers.Nui.callbacks[name]

    if not handler then
        error(('NUI callback %s is not registered'):format(name), 2)
    end

    local reply = nil

    handler(data, function(result)
        reply = result
    end)

    return reply
end

---Messages sent to the page since the last call, then forgets them.
---@return table[]
function Helpers.TakeNui()
    local messages = Helpers.Nui.messages
    Helpers.Nui.messages = {}

    return messages
end

---Forgets owner files, convars, KVP, other resources and GlobalState, like a fresh server.
function Helpers.Reset()
    Helpers.ResourceFiles = {}
    Helpers.Convars = {}
    Helpers.Kvp = {}
    Helpers.OtherFiles = {}
    Helpers.ResourceMetadata = {}
    Helpers.World = newWorld()
    Helpers.Nui = newNui()

    for key in pairs(GlobalState) do
        if key ~= 'set' then
            GlobalState[key] = nil
        end
    end
end

---Loads `@ug-lib/import.lua` as another resource would, in its own global environment.
---@param resource string
---@param side 'server'|'client'
---@return table env the consumer's globals, with `UgLib`
---@return string[] lines printed while loading
function Helpers.LoadImport(resource, side)
    local previousResource, previousServer = Helpers.CurrentResource, Helpers.IsServer
    local env = setmetatable({}, {
        __index = _G,
    })

    -- The consumer's runtime: exports and local events come from `resource`, whatever runs at the time.
    env.exports = newExports(function()
        return resource
    end)

    env.GetCurrentResourceName = function()
        return resource
    end

    env.TriggerEvent = function(name, ...)
        dispatch(name, resource, ...)
    end

    Helpers.CurrentResource, Helpers.IsServer = resource, side == 'server'

    local chunk, err = loadfile('import.lua', 't', env)

    if not chunk then
        error(err, 0)
    end

    local ok, lines = pcall(Helpers.Capture, chunk)

    Helpers.CurrentResource, Helpers.IsServer = previousResource, previousServer

    if not ok then
        error(lines, 0)
    end

    return env, lines
end

---The private environment of an import, with `UgLib.Internal`. Tests only: the consumer root hides it.
---@param env table from Helpers.LoadImport
---@return table private
function Helpers.ImportPrivate(env)
    local index = debug.getmetatable(env.UgLib).__index
    local position = 1

    while true do
        local name, value = debug.getupvalue(index, position)

        if name == nil then
            error('the import root has no _ENV upvalue', 2)
        end

        if name == '_ENV' then
            return value
        end

        position = position + 1
    end
end

---Runs a registered command and returns everything it printed.
---@param name string
---@param source integer
---@param args string[]
---@return string[]
function Helpers.RunCommand(name, source, args)
    local handler = commands[name]

    if not handler then
        error('command "' .. name .. '" is not registered', 2)
    end

    return Helpers.Capture(function()
        handler(source, args, name .. ' ' .. table.concat(args, ' '))
    end)
end

---Runs `fn` and returns everything it printed, one entry per print call.
---@param fn fun()
---@return string[]
function Helpers.Capture(fn)
    local previous = captured
    local lines = {}
    captured = lines

    local ok, err = pcall(fn)
    captured = previous

    if not ok then
        error(err, 0)
    end

    return lines
end

---Hides the type of `value`, so a test can pass a wrong type on purpose.
---@param value any
---@return any
function Helpers.Any(value)
    return value
end

---Moves the clock by `ms` and runs one frame: timers due now fire in order.
---Timers they create wait for the next Advance, like Wait(0).
---@param ms integer
function Helpers.Advance(ms)
    Helpers.Clock = Helpers.Clock + ms

    local due, pending = {}, {}

    for _, timer in ipairs(timers) do
        if timer.at <= Helpers.Clock then
            due[#due + 1] = timer
        else
            pending[#pending + 1] = timer
        end
    end

    timers = pending

    table.sort(due, function(a, b)
        return a.at < b.at
    end)

    for _, timer in ipairs(due) do
        timer.callback()
    end
end

---@class TestThread
---@field done boolean
---@field result any
---@field error string?

---Runs `fn` as a coroutine, like a FiveM thread. Citizen.Await yields it until the promise settles.
---@param fn fun(): any
---@return TestThread
function Helpers.Thread(fn)
    local thread = {
        done = false,
    }
    local co = coroutine.create(function()
        thread.result = fn()
        thread.done = true
    end)

    local ok, err = coroutine.resume(co)

    if not ok then
        thread.error = tostring(err)
        thread.done = true
    end

    return thread
end

---Reads the manifest and returns the script list for one side, shared scripts first.
---@param side 'server'|'client'
---@return string[]
local function readManifestScripts(side)
    local lists = {
        shared = {},
        server = {},
        client = {},
    }

    local env = setmetatable({}, {
        __index = function(_, directive)
            return function(value)
                local scope = rawType(directive) == 'string' and directive:match('^(%a+)_scripts?$')

                if not scope or not lists[scope] then
                    return
                end

                local entries = rawType(value) == 'table' and value or { value }

                for index = 1, #entries do
                    table.insert(lists[scope], entries[index])
                end
            end
        end,
    })

    local chunk, err = loadfile(MANIFEST_PATH, 't', env)

    if not chunk then
        error('cannot read manifest: ' .. tostring(err), 0)
    end

    chunk()

    local scripts = {}

    for _, scope in ipairs({ 'shared', side }) do
        for _, path in ipairs(lists[scope]) do
            if path:find('*', 1, true) then
                error('manifest globs are not supported in tests: ' .. path, 0)
            end

            if path:sub(1, 1) ~= '@' then
                scripts[#scripts + 1] = path
            end
        end
    end

    return scripts
end

---Loads ug-lib scripts in manifest order for one side, like a resource start. Everything printed while loading is returned.
---@param side 'server'|'client'
---@return string[]
function Helpers.LoadManifest(side)
    Helpers.IsServer = side == 'server'
    Helpers.CurrentResource = RESOURCE_NAME
    rawset(_G, 'UgLib', nil)
    exported[side] = {}
    eventHandlers = {}
    timers = {}
    commands = {}
    stateBagHandlers = {}

    local scripts = readManifestScripts(side)

    return Helpers.Capture(function()
        for index = 1, #scripts do
            dofile(scripts[index])
        end
    end)
end

---@param name string
---@param fn fun()
function Helpers.Test(name, fn)
    local ok, err = xpcall(fn, function(message)
        return debug.traceback(tostring(message), 2)
    end)

    if ok then
        passed = passed + 1
        realPrint('  ok    ' .. name)
    else
        failed = failed + 1
        realPrint('  FAIL  ' .. name .. '\n        ' .. tostring(err):gsub('\n', '\n        '))
    end
end

---@param condition any
---@param message? string
function Helpers.Assert(condition, message)
    if not condition then
        error(message or 'assertion failed', 2)
    end
end

---@param actual any
---@param expected any
---@param path string
---@param seen table<table, table>
---@return string?
local function compare(actual, expected, path, seen)
    if type(actual) ~= type(expected) then
        return ('%s: expected %s, got %s'):format(path, type(expected), type(actual))
    end

    if rawType(expected) ~= 'table' then
        if actual ~= expected and not (actual ~= actual and expected ~= expected) then
            return ('%s: expected %s, got %s'):format(path, tostring(expected), tostring(actual))
        end

        return nil
    end

    if seen[actual] == expected then
        return nil
    end

    seen[actual] = expected

    for key, value in pairs(expected) do
        local problem = compare(actual[key], value, ('%s.%s'):format(path, tostring(key)), seen)

        if problem then
            return problem
        end
    end

    for key in pairs(actual) do
        if expected[key] == nil then
            return ('%s.%s: unexpected key'):format(path, tostring(key))
        end
    end

    return nil
end

---Deep comparison. Tables are equal when they hold equal keys and values.
---@param actual any
---@param expected any
---@param message? string
function Helpers.Equal(actual, expected, message)
    local problem = compare(actual, expected, 'value', {})

    if problem then
        error((message and message .. ': ' or '') .. problem, 2)
    end
end

---Asserts that `fn` raises. When `pattern` is given, the message MUST contain it as plain text.
---@param fn fun(): any
---@param pattern? string
---@return string message
function Helpers.Raises(fn, pattern)
    local ok, err = pcall(fn)

    if ok then
        error('expected an error, none was raised', 2)
    end

    local message = tostring(err)

    if pattern and not message:find(pattern, 1, true) then
        error(('expected an error containing "%s", got "%s"'):format(pattern, message), 2)
    end

    return message
end

---Prints the summary and exits with code 1 if any test failed.
function Helpers.Done()
    realPrint(('\n%d passed, %d failed'):format(passed, failed))
    os.exit(failed == 0 and 0 or 1)
end

return Helpers
