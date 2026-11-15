--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Notifications. Each one is a layer that never answers. The calling resource owns its timer, so a
---notification lives exactly `duration` ms, and showing an `id` again updates it and restarts its timer.
---ug-lib keeps at most `settings.notifyMax` per anchor: the oldest leave first.
---@class UgLib.Notify
local Notify = {}
UgLib.Notify = Notify

local Utils = UgLib.Internal.Utils
local Config = UgLib.Internal.Config
local Enums = UgLib.Enums

local KIND = UgLib.Internal.Protocol.Nui.Types.Notify
local IS_OWNER = GetCurrentResourceName() == 'ug-lib'
local OPTIONS = {
    message = true,
    title = true,
    type = true,
    style = true,
    position = true,
    duration = true,
    icon = true,
    color = true,
    fixed = true,
    id = true,
}
local UPDATE_OPTIONS = {
    message = true,
    title = true,
    type = true,
    style = true,
    position = true,
    duration = true,
    icon = true,
    color = true,
    fixed = true,
}
local MAX_MESSAGE = 1024
local MAX_TITLE = 128
local MAX_DURATION = 600000
local MAX_ID = 32
local ID_PATTERN = '^[%w_%-%.:]+$'
local DEFAULT_DURATION = 5000

---@class UgNotifyPayload
---@field message string
---@field title? string
---@field type UgNotifyType
---@field style UgNotifyStyle
---@field position UgPosition
---@field duration integer ms, 0 keeps it until dismissed
---@field icon? UgIcon
---@field color? UgLibColorValue replaces the color of `type`
---@field fixed? boolean keeps `position` and `style` when the player chose others
---@field stamp integer changes on every show, so the page restarts its timer bar

---@param enum table<string, string>
---@param value any
---@return boolean
local function isValue(enum, value)
    for _, entry in pairs(enum) do
        if entry == value then
            return true
        end
    end

    return false
end

---@param value any
---@param max integer
---@return boolean
local function isText(value, max)
    if type(value) ~= 'string' then
        return false
    end

    local length = utf8.len(value)

    return length ~= nil and length >= 1 and length <= max
end

---Every problem a payload can have, as a plain message. Used on both sides of the export.
---@param payload table
---@return string? problem
local function check(payload)
    if not isText(payload.message, MAX_MESSAGE) then
        return ('message MUST be UTF-8 text of 1 to %d characters'):format(MAX_MESSAGE)
    end

    if payload.title ~= nil and not isText(payload.title, MAX_TITLE) then
        return ('title MUST be UTF-8 text of 1 to %d characters'):format(MAX_TITLE)
    end

    for field, enum in pairs({
        type = Enums.NotifyType,
        style = Enums.NotifyStyle,
        position = Enums.Position,
    }) do
        if not isValue(enum, payload[field]) then
            return ('%s MUST be a UgLib.Enums value, got %s'):format(field, tostring(payload[field]))
        end
    end

    if payload.icon ~= nil and not isValue(Enums.Icon, payload.icon) then
        return ('icon MUST be a UgLib.Enums.Icon value, got %s'):format(tostring(payload.icon))
    end

    if payload.color ~= nil and not Utils.IsColor(payload.color) then
        return 'color MUST be a UgLib.Enums.Color value or a #rrggbb hex'
    end

    if payload.fixed ~= nil and type(payload.fixed) ~= 'boolean' then
        return 'fixed MUST be a boolean'
    end

    if math.type(payload.duration) ~= 'integer' or payload.duration < 0 or payload.duration > MAX_DURATION then
        return ('duration MUST be an integer from 0 to %d ms'):format(MAX_DURATION)
    end

    if math.type(payload.stamp) ~= 'integer' then
        return 'stamp MUST be an integer'
    end

    return nil
end

---Rebuilds a payload from known fields only.
---@param source table
---@return UgNotifyPayload
local function rebuild(source)
    return {
        message = source.message,
        title = source.title,
        type = source.type,
        style = source.style,
        position = source.position,
        duration = source.duration,
        icon = source.icon,
        color = source.color,
        fixed = source.fixed,
        stamp = source.stamp,
    }
end

---@param options table
---@param stamp integer
---@return UgNotifyPayload
local function build(options, stamp)
    local style = options.style or Enums.NotifyStyle.Toast
    local position = options.position

    if position == nil then
        position = style == Enums.NotifyStyle.Banner and Enums.Position.Top or Config.Get('settings', 'notifyPosition') or Enums.Position.TopRight
    end

    return rebuild({
        message = options.message,
        title = options.title,
        type = options.type or Enums.NotifyType.Info,
        style = style,
        position = position,
        duration = options.duration or Config.Get('settings', 'notifyDuration') or DEFAULT_DURATION,
        icon = options.icon,
        color = options.color,
        fixed = options.fixed,
        stamp = stamp,
    })
end

-- Requests exist in every client runtime that loads this file: consumers through the import, ug-lib itself.
local Requests = UgLib.Internal.Requests

---@class UgLibShownNotify
---@field layer string
---@field payload UgNotifyPayload
---@field cancelTimer? fun()

---@type table<string, UgLibShownNotify>
local shown = {}

local stamp = 0

---@param entry UgLibShownNotify
local function startTimer(entry)
    if entry.cancelTimer then
        entry.cancelTimer()
        entry.cancelTimer = nil
    end

    if entry.payload.duration > 0 then
        local layer = entry.layer

        entry.cancelTimer = UgLib.Async.Timeout(entry.payload.duration, function()
            Requests.Close(layer)
        end)
    end
end

---Shows a notification and returns its id. Showing an `id` that is on screen updates it in place.
---`message` and `title` take the markup: `**bold**`, `*italic*`, `~success~color~reset~`.
---@param options { message: string, title?: string, type?: UgNotifyType, style?: UgNotifyStyle, position?: UgPosition, duration?: integer, icon?: UgIcon, color?: UgLibColorValue, fixed?: boolean, id?: string }
---@return string id for `Update` and `Dismiss`
function Notify.Show(options)
    Utils.CheckOptions('Notify.Show', options, OPTIONS)

    local key = options.id

    if key ~= nil and (type(key) ~= 'string' or #key > MAX_ID or not key:find(ID_PATTERN) or key:sub(1, 1) == '#') then
        Utils.Raise(2, 'Notify.Show: id MUST be 1 to %d letters, digits, or _ - . :', MAX_ID)
    end

    stamp = stamp + 1

    local payload = build(options, stamp)
    local problem = check(payload)

    if problem then
        Utils.Raise(2, 'Notify.Show: %s', problem)
    end

    local existing = key and shown[key]

    if existing and Requests.Update(existing.layer, payload) then
        existing.payload = payload
        startTimer(existing)

        ---@cast key string

        return key
    end

    ---@type UgLibShownNotify
    local entry = {
        layer = '',
        payload = payload,
    }
    local layer = Requests.Start(KIND, payload, {
        onClose = function()
            if entry.cancelTimer then
                entry.cancelTimer()
            end

            for name, other in pairs(shown) do
                if other == entry then
                    shown[name] = nil
                end
            end
        end,
    })

    ---@cast layer string

    entry.layer = layer
    key = key or ('#' .. layer)
    shown[key] = entry
    startTimer(entry)

    return key
end

---Changes fields of a notification on screen and restarts its timer.
---@param id string from `Show`
---@param options { message?: string, title?: string, type?: UgNotifyType, style?: UgNotifyStyle, position?: UgPosition, duration?: integer, icon?: UgIcon }
---@return boolean ok false when it is no longer on screen
function Notify.Update(id, options)
    Utils.CheckOptions('Notify.Update', options, UPDATE_OPTIONS)

    local entry = shown[id]

    if not entry then
        return false
    end

    stamp = stamp + 1

    local payload = rebuild(entry.payload)

    for field, value in pairs(options) do
        payload[field] = value
    end

    payload.stamp = stamp

    local problem = check(payload)

    if problem then
        Utils.Raise(2, 'Notify.Update: %s', problem)
    end

    if not Requests.Update(entry.layer, payload) then
        return false
    end

    entry.payload = payload
    startTimer(entry)

    return true
end

---@param id string from `Show`
---@return boolean ok false when it is no longer on screen
function Notify.Dismiss(id)
    local entry = shown[id]

    return entry ~= nil and Requests.Close(entry.layer)
end

---Dismisses every notification of the calling resource.
---@return integer count
function Notify.DismissAll()
    local count = 0

    for _, entry in pairs(shown) do
        if Requests.Close(entry.layer) then
            count = count + 1
        end
    end

    return count
end

if IS_OWNER then
    local Focus = UgLib.Internal.Protocol.Nui.Focus

    UgLib.Internal.Layers.RegisterType(KIND, {
        modal = false,
        focus = Focus.None,
        sanitize = function(payload)
            local clean = rebuild(payload)
            local problem = check(clean)

            if problem then
                error(problem, 0)
            end

            return clean
        end,
        limit = {
            max = function()
                return Config.Get('settings', 'notifyMax') or 5
            end,
            group = function(payload)
                return payload.position
            end,
        },
        -- Notifications never answer: anything the page sends is rejected.
        validate = function()
            return false, nil
        end,
    })

    UgLib.Internal.Demos.Register('notify', function(args)
        local style = args[1] or Enums.NotifyStyle.Toast

        for _, kind in ipairs({
            Enums.NotifyType.Info,
            Enums.NotifyType.Success,
            Enums.NotifyType.Warning,
            Enums.NotifyType.Error,
        }) do
            Notify.Show({
                title = kind:sub(1, 1):upper() .. kind:sub(2),
                message = ('A **%s** notification with ~primary~markup~reset~.'):format(kind),
                type = kind,
                style = isValue(Enums.NotifyStyle, style) and style or Enums.NotifyStyle.Toast,
                position = isValue(Enums.Position, args[2]) and args[2] or nil,
            })
        end
    end)
end
