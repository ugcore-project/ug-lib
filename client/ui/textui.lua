--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---The single on-screen text prompt, such as "[E] Open the shop". Callers usually show it every frame while
---near something, so a repeat call with the same options sends nothing. One prompt at a time across resources:
---a new prompt from another resource replaces the current one.
---@class UgLib.TextUI
local TextUI = {}
UgLib.TextUI = TextUI

local Utils = UgLib.Internal.Utils
local Config = UgLib.Internal.Config
local Enums = UgLib.Enums
local Requests = UgLib.Internal.Requests

local KIND = UgLib.Internal.Protocol.Nui.Types.TextUI
local IS_OWNER = GetCurrentResourceName() == 'ug-lib'
local OPTIONS = {
    text = true,
    icon = true,
    style = true,
    key = true,
    position = true,
    color = true,
    fixed = true,
}
local MAX_TEXT = 256
local MAX_KEY = 16

---@class UgTextUIPayload
---@field text string
---@field icon? UgIcon
---@field style UgTextUIStyle
---@field key? string
---@field position UgPosition
---@field color? UgLibColorValue
---@field fixed? boolean keeps `position` and `style` when the player chose others

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
    local length = type(payload.text) == 'string' and utf8.len(payload.text)

    if not length or length < 1 or length > MAX_TEXT then
        return ('text MUST be UTF-8 text of 1 to %d characters'):format(MAX_TEXT)
    end

    if payload.icon ~= nil and not isValue(Enums.Icon, payload.icon) then
        return ('icon MUST be a UgLib.Enums.Icon value, got %s'):format(tostring(payload.icon))
    end

    if not isValue(Enums.TextUIStyle, payload.style) then
        return ('style MUST be a UgLib.Enums.TextUIStyle value, got %s'):format(tostring(payload.style))
    end

    if payload.key ~= nil and (type(payload.key) ~= 'string' or #payload.key < 1 or #payload.key > MAX_KEY) then
        return ('key MUST be a key label of 1 to %d bytes'):format(MAX_KEY)
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

    return nil
end

---@param source table
---@return UgTextUIPayload
local function rebuild(source)
    return {
        text = source.text,
        icon = source.icon,
        style = source.style,
        key = source.key,
        position = source.position,
        color = source.color,
        fixed = source.fixed,
    }
end

---@type string? layer id while shown
local shown = nil

---@type UgTextUIPayload?
local last = nil

---@param a UgTextUIPayload
---@param b UgTextUIPayload
---@return boolean
local function same(a, b)
    return a.text == b.text and a.icon == b.icon and a.style == b.style and a.key == b.key and a.position == b.position and a.color == b.color and a.fixed == b.fixed
end

---Shows or changes the prompt. Safe to call every frame: unchanged options send nothing.
---@param options { text: string, icon?: UgIcon, style?: UgTextUIStyle, key?: string, position?: UgPosition, color?: UgLibColorValue, fixed?: boolean }
function TextUI.Show(options)
    Utils.CheckOptions('TextUI.Show', options, OPTIONS)

    local payload = rebuild(options)

    payload.style = payload.style or Enums.TextUIStyle.Pill
    payload.position = payload.position or Config.Get('settings', 'textUIPosition') or Enums.Position.Bottom

    if shown and last and same(last, payload) then
        return
    end

    local problem = check(payload)

    if problem then
        Utils.Raise(2, 'TextUI.Show: %s', problem)
    end

    last = payload

    if shown and Requests.Update(shown, payload) then
        return
    end

    local id = nil

    id = Requests.Start(KIND, payload, {
        onClose = function()
            if shown == id then
                shown = nil
                last = nil
            end
        end,
    })

    shown = id
end

---Hides the prompt of the calling resource.
function TextUI.Hide()
    if shown then
        Requests.Close(shown)
    end
end

---True while the calling resource's prompt is on screen. A prompt from another resource replaces it.
---@return boolean
function TextUI.IsShown()
    return shown ~= nil
end

if IS_OWNER then
    UgLib.Internal.Layers.RegisterType(KIND, {
        modal = false,
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
                return 1
            end,
            group = function()
                return KIND
            end,
        },
        validate = function()
            return false, nil
        end,
    })

    -- INPUT_PICKUP, E on keyboards. Control indices from the Cfx controls reference.
    local DEMO_CONTROL = 38

    UgLib.Internal.Demos.Register('textui', function(args)
        local style = isValue(Enums.TextUIStyle, args[1]) and args[1] or Enums.TextUIStyle.Keybind

        if args[1] == 'hide' then
            TextUI.Hide()

            return
        end

        TextUI.Show({
            text = 'Open the shop',
            key = 'E',
            icon = Enums.Icon.Star,
            style = style,
            position = isValue(Enums.Position, args[2]) and args[2] or nil,
        })

        local demo = shown

        CreateThread(function()
            while shown ~= nil and shown == demo do
                if IsControlJustReleased(0, DEMO_CONTROL) then
                    TextUI.Hide()
                    print('[ug-lib] textui demo: E pressed')

                    return
                end

                Wait(0)
            end
        end)
    end)
end
