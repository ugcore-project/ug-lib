--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Timed actions with a bar, an animation and props. The calling resource owns the timer, the controls it
---disables and the cleanup. One progress at a time across resources: a second start returns `Busy`.
---The cancel key (`settings.cancelKey`, rebindable) is registered by ug-lib and cancels a progress with `canCancel`.
---@class UgLib.Progress
local Progress = {}
UgLib.Progress = Progress

local Utils = UgLib.Internal.Utils
local Config = UgLib.Internal.Config
local Controls = UgLib.Internal.Controls
local Enums = UgLib.Enums
local Requests = UgLib.Internal.Requests
local CloseReason = Enums.CloseReason

local KIND = UgLib.Internal.Protocol.Nui.Types.Progress
local IS_OWNER = GetCurrentResourceName() == 'ug-lib'
local OPTIONS = {
    duration = true, label = true, style = true, position = true, color = true, fixed = true, canCancel = true, cancelOnMove = true,
    disable = true, animation = true, props = true, allowDead = true,
}
local DISABLE_OPTIONS = {
    move = true,
    sprint = true,
    car = true,
    combat = true,
    mouse = true,
}
local ANIMATION_OPTIONS = {
    dict = true,
    name = true,
    flag = true,
    scenario = true,
}
local MIN_DURATION = 100
local MAX_DURATION = 600000
local MAX_LABEL = 128
local MAX_PROPS = 4
-- Upper body only, looped, so the player keeps the animation while standing still.
local DEFAULT_FLAG = 49

---@class UgProgressPayload
---@field label? string
---@field duration integer
---@field style UgProgressStyle
---@field position UgPosition
---@field color? UgLibColorValue
---@field fixed? boolean keeps `position` and `style` when the player chose others
---@field canCancel boolean
---@field stamp integer

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

---@param payload table
---@return string? problem
local function check(payload)
    if math.type(payload.duration) ~= 'integer' or payload.duration < MIN_DURATION or payload.duration > MAX_DURATION then
        return ('duration MUST be an integer from %d to %d ms'):format(MIN_DURATION, MAX_DURATION)
    end

    if payload.label ~= nil then
        local length = type(payload.label) == 'string' and utf8.len(payload.label)

        if not length or length < 1 or length > MAX_LABEL then
            return ('label MUST be UTF-8 text of 1 to %d characters'):format(MAX_LABEL)
        end
    end

    if not isValue(Enums.ProgressStyle, payload.style) then
        return ('style MUST be a UgLib.Enums.ProgressStyle value, got %s'):format(tostring(payload.style))
    end

    if not isValue(Enums.Position, payload.position) then
        return ('position MUST be a UgLib.Enums.Position value, got %s'):format(tostring(payload.position))
    end

    if payload.color ~= nil and not Utils.IsColor(payload.color) then
        return 'color MUST be a UgLib.Enums.Color value or a #rrggbb hex'
    end

    if payload.fixed ~= nil and type(payload.fixed) ~= 'boolean' then
        return 'fixed MUST be a boolean'
    end

    if type(payload.canCancel) ~= 'boolean' or math.type(payload.stamp) ~= 'integer' then
        return 'canCancel MUST be a boolean'
    end

    return nil
end

---@param source table
---@return UgProgressPayload
local function rebuild(source)
    return {
        label = source.label,
        duration = source.duration,
        style = source.style,
        position = source.position,
        color = source.color,
        fixed = source.fixed,
        canCancel = source.canCancel,
        stamp = source.stamp,
    }
end

---@class UgLibActiveProgress
---@field reason? UgCloseReason set once the progress ends early

---@type UgLibActiveProgress?
local active = nil

local stamp = 0

---@param options table
---@return string? problem
local function checkExtras(options)
    if options.disable ~= nil then
        if type(options.disable) ~= 'table' then
            return 'disable MUST be a table'
        end

        for key, value in pairs(options.disable) do
            if not DISABLE_OPTIONS[key] or type(value) ~= 'boolean' then
                return ('disable.%s is not a known control group or not a boolean'):format(tostring(key))
            end
        end
    end

    local animation = options.animation

    if animation ~= nil then
        if type(animation) ~= 'table' then
            return 'animation MUST be { dict, name, flag? } or { scenario }'
        end

        for key in pairs(animation) do
            if not ANIMATION_OPTIONS[key] then
                return ('animation has an unknown field "%s"'):format(tostring(key))
            end
        end

        local isScenario = type(animation.scenario) == 'string'
        local isAnim = type(animation.dict) == 'string' and type(animation.name) == 'string'

        if isScenario == isAnim then
            return 'animation MUST be { dict, name, flag? } or { scenario }'
        end
    end

    if options.props ~= nil and (type(options.props) ~= 'table' or #options.props > MAX_PROPS) then
        return ('props MUST be an array of at most %d props'):format(MAX_PROPS)
    end

    return nil
end

---@param ped integer
---@param animation table?
---@param props table?
---@return integer[] created props
local function startEffects(ped, animation, props)
    if animation then
        if animation.scenario then
            UgLib.Animation.Scenario(ped, animation.scenario)
        else
            UgLib.Animation.Play(ped, animation.dict, animation.name, {
                flag = animation.flag or DEFAULT_FLAG,
            })
        end
    end

    local created = {}

    for _, prop in ipairs(props or {}) do
        local handle = UgLib.Animation.AttachProp(ped, prop)

        if handle then
            created[#created + 1] = handle
        end
    end

    return created
end

---@param ped integer
---@param animation table?
---@param created integer[]
local function stopEffects(ped, animation, created)
    if animation then
        UgLib.Animation.Stop(ped, animation.dict, animation.name)
    end

    for _, prop in ipairs(created) do
        UgLib.Animation.RemoveProp(prop)
    end
end

---Runs a timed action and waits for it. MUST run in a thread.
---@param options { duration: integer, label?: string, style?: UgProgressStyle, position?: UgPosition, color?: UgLibColorValue, fixed?: boolean, canCancel?: boolean, cancelOnMove?: boolean, disable?: { move?: boolean, sprint?: boolean, car?: boolean, combat?: boolean, mouse?: boolean }, animation?: { dict?: string, name?: string, flag?: integer, scenario?: string }, props?: table[], allowDead?: boolean }
---@return boolean completed
---@return UgCloseReason? reason why it ended early: `Cancelled`, `Busy`, `Replaced` or `Closed`
function Progress.Start(options)
    Utils.CheckOptions('Progress.Start', options, OPTIONS)

    local _, isMain = coroutine.running()

    if isMain then
        Utils.Raise(2, 'UgLib.Progress.Start MUST run in a thread.')
    end

    stamp = stamp + 1

    local payload = rebuild({
        label = options.label,
        duration = options.duration,
        style = options.style or Enums.ProgressStyle.Bar,
        position = options.position or Config.Get('settings', 'progressPosition') or Enums.Position.Bottom,
        color = options.color,
        fixed = options.fixed,
        canCancel = options.canCancel ~= false,
        stamp = stamp,
    })

    local problem = check(payload) or checkExtras(options)

    if problem then
        Utils.Raise(2, 'Progress.Start: %s', problem)
    end

    if active then
        return false, CloseReason.Busy
    end

    ---@type UgLibActiveProgress
    local current = {}
    local finished = false
    local id, busy = Requests.Start(KIND, payload, {
        onClose = function(_, reason)
            if not finished then
                current.reason = reason or CloseReason.Closed
            end
        end,
    })

    if not id then
        return false, busy
    end

    active = current

    local disable = options.disable or {}
    local cancelOnMove = options.cancelOnMove == true
    local disableMove = disable.move ~= false and not cancelOnMove
    local ped = UgLib.Cache.Ped
    local created = startEffects(ped, options.animation, options.props)
    local deadline = GetGameTimer() + payload.duration
    local completed = false

    while true do
        if current.reason then
            break
        end

        if GetGameTimer() >= deadline then
            completed = true
            break
        end

        if not options.allowDead and IsEntityDead(ped) then
            current.reason = CloseReason.Cancelled
            break
        end

        if disableMove then
            Controls.Disable(Controls.Move)
        end

        if disable.sprint ~= false then
            Controls.Disable(Controls.Sprint)
        end

        if disable.car ~= false then
            Controls.Disable(Controls.Car)
        end

        if disable.combat ~= false then
            Controls.Disable(Controls.Combat)
        end

        if disable.mouse == true then
            Controls.Disable(Controls.Mouse)
        end

        if cancelOnMove and Controls.AnyPressed(Controls.MovePress) then
            current.reason = CloseReason.Cancelled
            break
        end

        Wait(0)
    end

    finished = true
    active = nil
    Requests.Close(id)
    stopEffects(ped, options.animation, created)

    if completed then
        return true, nil
    end

    return false, current.reason
end

---Cancels the calling resource's progress.
---@return boolean cancelled false when none is running
function Progress.Cancel()
    if not active or active.reason then
        return false
    end

    active.reason = CloseReason.Cancelled

    return true
end

---True while the calling resource runs a progress.
---@return boolean
function Progress.IsActive()
    return active ~= nil
end

if IS_OWNER then
    local Layers = UgLib.Internal.Layers

    Layers.RegisterType(KIND, {
        modal = false,
        exclusive = true,
        sanitize = function(payload)
            local clean = rebuild(payload)
            local problem = check(clean)

            if problem then
                error(problem, 0)
            end

            return clean
        end,
        validate = function()
            return false, nil
        end,
    })

    UgLib.Keybind.Register({
        name = 'cancel',
        label = 'Cancel the current action',
        defaultKey = Config.Get('settings', 'cancelKey') or 'X',
        disableWhileUi = false,
        onPressed = function()
            for _, layer in ipairs(Layers.GetAll()) do
                if layer.kind == KIND and layer.payload.canCancel then
                    Layers.Close(layer.owner, layer.id, CloseReason.Cancelled)
                end
            end
        end,
    })

    UgLib.Internal.Demos.Register('progress', function(args)
        local completed, reason = Progress.Start({
            duration = 5000,
            label = 'Repairing the engine',
            style = isValue(Enums.ProgressStyle, args[1]) and args[1] or Enums.ProgressStyle.Bar,
            position = isValue(Enums.Position, args[2]) and args[2] or nil,
        })

        print(('[ug-lib] progress completed %s, reason %s'):format(tostring(completed), tostring(reason)))
    end)
end
