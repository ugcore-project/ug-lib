--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Open UI layers in ug-lib's runtime, by owner resource. Answers go back to the owner as a local event.
---Each layer type validates what the NUI returns, so the owner only receives values built from its own payload.
---@class UgLib.Internal.Layers
local Layers = {}
UgLib.Internal.Layers = Layers

local Utils = UgLib.Internal.Utils
local Logger = UgLib.Internal.Logger
local Protocol = UgLib.Internal.Protocol
local Nui = UgLib.Internal.Nui
local Preferences = UgLib.Internal.Preferences
local Actions = Protocol.Nui.Actions
local Focus = Protocol.Nui.Focus
local CloseReason = UgLib.Enums.CloseReason
local UiEvents = UgLib.Enums.Events.Ui

local RESOURCE = GetCurrentResourceName()
local OPEN_OPTIONS = {
    replace = true,
}

---@class UgLibLayerType
---@field modal boolean one modal at a time: Dialog, Context, Radial
---@field focus? UgNuiFocus game focus while this layer is the top layer that wants input, defaults to none
---@field keepInput? boolean the game keeps receiving input while focused, such as a keyboard menu
---@field validate? fun(payload: table, result: any): boolean, any checks a final NUI answer, returns ok and the value for the owner
---@field validateEvent? fun(payload: table, data: any): boolean, any checks a non-final NUI event
---@field sanitize? fun(payload: table): table rebuilds a payload from known fields, raises with a plain message when invalid
---@field limit? UgLibLayerLimit
---@field exclusive? boolean one layer of this type at a time, a second open returns `Busy`, such as Progress
---@field onUpdate? fun(old: table, new: table): table merges an update into the open payload, such as a menu keeping its selection

---At most `max()` layers of a type per group, the oldest close as `Replaced`.
---@class UgLibLayerLimit
---@field max fun(): integer
---@field group fun(payload: table): string

---@class UgLibLayer
---@field owner string
---@field id string
---@field key string `<owner>/<id>`, the id the page knows
---@field kind string
---@field payload table
---@field modal boolean
---@field seq integer open order
---@field requested? table<string, any> the caller's own position and style, kept while preferences replace them

---@type table<string, UgLibLayerType>
local types = {}

---@type table<string, UgLibLayer> by `owner/id`
local layers = {}

---@type UgLibLayer?
local modal = nil

local seq = 0

---@param owner string
---@param id string
---@return string
local function keyOf(owner, id)
    return owner .. '/' .. id
end

---@param layer UgLibLayer
---@param result any
---@param reason UgCloseReason?
---@param final boolean
local function emit(layer, result, reason, final)
    TriggerEvent(Protocol.ResponseEvent:format(layer.owner), layer.id, result, reason, final)
end

---The top layer that wants input decides the game focus.
local function refocus()
    local top = nil

    for _, layer in pairs(layers) do
        local definition = types[layer.kind]

        if (definition.focus or Focus.None) ~= Focus.None and (not top or layer.seq > top.seq) then
            top = layer
        end
    end

    if not top then
        Nui.SetFocus(Focus.None, false)

        return
    end

    local definition = types[top.kind]

    Nui.SetFocus(definition.focus --[[@as UgNuiFocus]], definition.keepInput == true)
end

---@param layer UgLibLayer
local function remove(layer)
    layers[layer.key] = nil
    Nui.Send(layer.kind, Actions.Close, layer.key)
    refocus()

    if modal == layer then
        modal = nil
        TriggerEvent(UiEvents.Closed, layer.kind, layer.owner)
    end
end

---Payloads come through exports, so any resource can send one. Each type rebuilds it from known fields.
---@param definition UgLibLayerType
---@param kind string
---@param payload table
---@return table
local function sanitize(definition, kind, payload)
    if not definition.sanitize then
        return payload
    end

    local ok, clean = pcall(definition.sanitize, payload)

    if not ok then
        Utils.Raise(3, 'Layers: invalid %s payload: %s', kind, tostring(clean))
    end

    return clean
end

---Closes the oldest layers of the group of `layer` beyond the type's limit.
---@param layer UgLibLayer
---@param limit UgLibLayerLimit
local function enforceLimit(layer, limit)
    local group = limit.group(layer.payload)
    local same = {}

    for _, other in pairs(layers) do
        if other.kind == layer.kind and limit.group(other.payload) == group then
            same[#same + 1] = other
        end
    end

    table.sort(same, function(a, b)
        return a.seq < b.seq
    end)

    for index = 1, #same - limit.max() do
        Layers.Close(same[index].owner, same[index].id, CloseReason.Replaced)
    end
end

---Declares a layer type. Each UI service registers its own.
---@param kind string
---@param definition UgLibLayerType
function Layers.RegisterType(kind, definition)
    if type(kind) ~= 'string' or type(definition) ~= 'table' or type(definition.modal) ~= 'boolean' then
        Utils.Raise(2, 'Layers.RegisterType expects a name and { modal, focus?, keepInput?, validate?, validateEvent?, sanitize?, limit? }')
    end

    types[kind] = definition
end

---Shows a layer for `owner`. Returns false with `Busy` when another modal is open and `replace` is not set.
---@param owner string
---@param id string
---@param kind string
---@param payload table
---@param options? { replace?: boolean }
---@return boolean ok
---@return UgCloseReason? reason
function Layers.Open(owner, id, kind, payload, options)
    if type(id) ~= 'string' or id == '' or #id > Protocol.MaxIdLength then
        Utils.Raise(2, 'Layers.Open: id MUST be a string of 1 to %d bytes', Protocol.MaxIdLength)
    end

    local definition = types[kind]

    if not definition then
        Utils.Raise(2, 'Layers.Open: unknown layer type "%s"', tostring(kind))
    end

    if type(payload) ~= 'table' then
        Utils.Raise(2, 'Layers.Open: payload MUST be a table')
    end

    options = options and Utils.CheckOptions('Layers.Open', options, OPEN_OPTIONS) or {}
    payload = sanitize(definition, kind, payload)

    local requested = Preferences.RequestedOf(kind, payload)

    if requested then
        Preferences.Apply(kind, payload, requested)
    end

    if layers[keyOf(owner, id)] then
        Utils.Raise(2, 'Layers.Open: %s already has an open layer with id "%s"', owner, id)
    end

    if definition.exclusive then
        for _, other in pairs(layers) do
            if other.kind == kind then
                return false, CloseReason.Busy
            end
        end
    end

    if definition.modal and modal then
        if not options.replace then
            return false, CloseReason.Busy
        end

        Layers.Close(modal.owner, modal.id, CloseReason.Replaced)
    end

    seq = seq + 1

    local key = keyOf(owner, id)
    local layer = {
        owner = owner,
        id = id,
        key = key,
        kind = kind,
        payload = payload,
        modal = definition.modal,
        seq = seq,
        requested = requested,
    }
    layers[key] = layer

    Nui.Send(kind, Actions.Open, key, payload)
    refocus()

    if definition.modal then
        modal = layer
        TriggerEvent(UiEvents.Opened, kind, owner)
    end

    if definition.limit then
        enforceLimit(layer, definition.limit)
    end

    return true, nil
end

---Replaces the payload of an open layer.
---@param owner string
---@param id string
---@param payload table
---@return boolean ok false when the layer is not open
function Layers.Update(owner, id, payload)
    local layer = layers[keyOf(owner, id)]

    if not layer then
        return false
    end

    if type(payload) ~= 'table' then
        Utils.Raise(2, 'Layers.Update: payload MUST be a table')
    end

    local definition = types[layer.kind]
    local clean = sanitize(definition, layer.kind, payload)
    local requested = Preferences.RequestedOf(layer.kind, clean)

    if requested then
        Preferences.Apply(layer.kind, clean, requested)
        layer.requested = requested
    end

    layer.payload = definition.onUpdate and definition.onUpdate(layer.payload, clean) or clean
    Nui.Send(layer.kind, Actions.Update, layer.key, layer.payload)

    return true
end

---Applies the current preferences to every open layer and sends the changed ones to the page.
function Layers.Refresh()
    for _, layer in pairs(layers) do
        if layer.requested then
            local before = layer.payload.position .. '|' .. tostring(layer.payload.style)

            Preferences.Apply(layer.kind, layer.payload, layer.requested)

            if layer.payload.position .. '|' .. tostring(layer.payload.style) ~= before then
                Nui.Send(layer.kind, Actions.Update, layer.key, layer.payload)
            end
        end
    end
end

---Final answer from the NUI. Invalid answers resolve as `Cancelled`.
---@param owner string
---@param id string
---@param result any
---@return boolean ok false when the layer is not open
function Layers.Resolve(owner, id, result)
    local layer = layers[keyOf(owner, id)]

    if not layer then
        return false
    end

    remove(layer)

    local validate = types[layer.kind].validate
    local value = result

    if validate then
        local called, ok, checked = pcall(validate, layer.payload, result)

        if not called or not ok then
            Logger.Debug('Layers: invalid %s answer for %s, cancelled.', layer.kind, owner)
            emit(layer, nil, CloseReason.Cancelled, true)

            return true
        end

        value = checked
    end

    emit(layer, value, nil, true)

    return true
end

---Non-final event from the NUI, such as a menu selection that keeps the menu open. Invalid events are dropped.
---@param owner string
---@param id string
---@param data any
---@return boolean ok false when the layer is not open or the event is invalid
function Layers.Event(owner, id, data)
    local layer = layers[keyOf(owner, id)]
    local validate = layer and types[layer.kind].validateEvent

    if not layer or not validate then
        return false
    end

    local called, ok, checked = pcall(validate, layer.payload, data)

    if not called or not ok then
        Logger.Debug('Layers: invalid %s event for %s, dropped.', layer.kind, owner)

        return false
    end

    emit(layer, checked, nil, false)

    return true
end

---Sends a non-final event that ug-lib itself produced, such as a menu key press. It is not validated.
---@param owner string
---@param id string
---@param data any
---@return boolean ok false when the layer is not open
function Layers.Emit(owner, id, data)
    local layer = layers[keyOf(owner, id)]

    if not layer then
        return false
    end

    emit(layer, data, nil, false)

    return true
end

---Closes a layer without an answer. The owner receives `reason`.
---@param owner string
---@param id string
---@param reason UgCloseReason
---@return boolean ok false when the layer is not open
function Layers.Close(owner, id, reason)
    local layer = layers[keyOf(owner, id)]

    if not layer then
        return false
    end

    remove(layer)
    emit(layer, nil, reason, true)

    return true
end

---Closes every layer with `Closed`.
function Layers.CloseAll()
    for _, layer in pairs(layers) do
        Layers.Close(layer.owner, layer.id, CloseReason.Closed)
    end
end

---Answers by the id the page knows, `<owner>/<id>`. Unknown ids return false.
---@param key string
---@param result any
---@return boolean
function Layers.ResolveById(key, result)
    local layer = layers[key]

    return layer ~= nil and Layers.Resolve(layer.owner, layer.id, result)
end

---@param key string
---@param data any
---@return boolean
function Layers.EventById(key, data)
    local layer = layers[key]

    return layer ~= nil and Layers.Event(layer.owner, layer.id, data)
end

---@param key string
---@param reason UgCloseReason
---@return boolean
function Layers.CloseById(key, reason)
    local layer = layers[key]

    return layer ~= nil and Layers.Close(layer.owner, layer.id, reason)
end

---@param owner string
---@param id string
---@return UgLibLayer?
function Layers.Get(owner, id)
    return layers[keyOf(owner, id)]
end

---@return UgLibLayer?
function Layers.GetModal()
    return modal
end

---@return UgLibLayer[]
function Layers.GetAll()
    local list = {}

    for _, layer in pairs(layers) do
        list[#list + 1] = layer
    end

    return list
end

-- A stopped owner cannot receive answers, so its layers close silently.
AddEventHandler('onResourceStop', function(resource)
    if resource == RESOURCE then
        return
    end

    for _, layer in pairs(layers) do
        if layer.owner == resource then
            remove(layer)
        end
    end
end)
