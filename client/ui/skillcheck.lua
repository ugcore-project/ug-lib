--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Timing checks: an indicator turns once around a circle, and the player presses the round's key while it
---is inside the target area. Lua picks every area, key and speed, and checks each reported press against
---them: a hit at a time when the indicator could not be in the area counts as a miss.
---@class UgLib.SkillCheck
local SkillCheck = {}
UgLib.SkillCheck = SkillCheck

local Utils = UgLib.Internal.Utils
local Enums = UgLib.Enums
local Requests = UgLib.Internal.Requests

local KIND = UgLib.Internal.Protocol.Nui.Types.SkillCheck
local IS_OWNER = GetCurrentResourceName() == 'ug-lib'
local MAX_ROUNDS = 10
local MAX_KEYS = 8
local KEY_PATTERN = '^[a-z0-9]$'
local CUSTOM_OPTIONS = {
    areaSize = true,
    speed = true,
}
local OPTIONS = {
    color = true,
    position = true,
}
-- Area in degrees, speed in degrees per ms. One turn takes 360 / speed ms.
local PRESETS = {
    [Enums.Difficulty.Easy] = {
        areaSize = 60,
        speed = 0.25,
    },
    [Enums.Difficulty.Medium] = {
        areaSize = 45,
        speed = 0.35,
    },
    [Enums.Difficulty.Hard] = {
        areaSize = 30,
        speed = 0.45,
    },
}
local AREA_RANGE = { 10, 120 }
local SPEED_RANGE = { 0.1, 1.0 }
-- The earliest start of an area, so the player sees it before the indicator gets there.
local MIN_START = 90
-- Tolerance for frame timing, in ms, on each side of the area.
local TOLERANCE_MS = 120
local ROUND_PAUSE_MS = 300

---@class UgSkillRound
---@field areaSize number degrees
---@field speed number degrees per ms
---@field start number degrees where the area starts
---@field key string

---@param round any
---@return string? problem
local function checkRound(round)
    if type(round) ~= 'table' then
        return 'round MUST be a table'
    end

    if type(round.areaSize) ~= 'number' or round.areaSize < AREA_RANGE[1] or round.areaSize > AREA_RANGE[2] then
        return ('areaSize MUST be from %d to %d degrees'):format(AREA_RANGE[1], AREA_RANGE[2])
    end

    if type(round.speed) ~= 'number' or round.speed < SPEED_RANGE[1] or round.speed > SPEED_RANGE[2] then
        return ('speed MUST be from %.1f to %.1f degrees per ms'):format(SPEED_RANGE[1], SPEED_RANGE[2])
    end

    if round.start ~= nil and (type(round.start) ~= 'number' or round.start < 0 or round.start + round.areaSize > 360) then
        return 'start MUST keep the area inside the circle'
    end

    if round.key ~= nil and (type(round.key) ~= 'string' or not round.key:find(KEY_PATTERN)) then
        return 'key MUST be one lower-case letter or digit'
    end

    return nil
end

---@class UgSkillCheckPayload
---@field rounds UgSkillRound[]
---@field position UgPosition
---@field color? UgLibColorValue

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
---@return UgSkillCheckPayload
local function rebuild(payload)
    local rounds = payload.rounds

    if type(rounds) ~= 'table' or #rounds < 1 or #rounds > MAX_ROUNDS then
        error(('rounds MUST be 1 to %d rounds'):format(MAX_ROUNDS), 0)
    end

    local clean = {}

    for index = 1, #rounds do
        local round = rounds[index]
        local problem = checkRound(round) or (round.start == nil or round.key == nil) and 'start and key are required' or nil

        if problem then
            error(('round %d: %s'):format(index, problem), 0)
        end

        clean[index] = {
            areaSize = round.areaSize,
            speed = round.speed,
            start = round.start,
            key = round.key,
        }
    end

    if not isValue(Enums.Position, payload.position) then
        error(('position MUST be a UgLib.Enums.Position value, got %s'):format(tostring(payload.position)), 0)
    end

    if payload.color ~= nil and not Utils.IsColor(payload.color) then
        error('color MUST be a UgLib.Enums.Color value or a #rrggbb hex', 0)
    end

    return {
        rounds = clean,
        position = payload.position,
        color = payload.color,
    }
end

---True when a press at `time` ms after the round started can be inside the area.
---@param round UgSkillRound
---@param time number
---@return boolean
local function inArea(round, time)
    local tolerance = TOLERANCE_MS * round.speed
    local angle = time * round.speed

    return angle >= round.start - tolerance and angle <= round.start + round.areaSize + tolerance
end

---Checks the page's answer: one `{ hit, time }` per round played, stopping at the first miss.
---@param payload UgSkillCheckPayload
---@param result any
---@return boolean ok
---@return boolean? success
local function validate(payload, result)
    if type(result) ~= 'table' or #result < 1 or #result > #payload.rounds then
        return false, nil
    end

    local success = #result == #payload.rounds

    for index = 1, #result do
        local entry = result[index]

        if type(entry) ~= 'table' or type(entry.hit) ~= 'boolean' or type(entry.time) ~= 'number' or entry.time ~= entry.time then
            return false, nil
        end

        if not entry.hit or not inArea(payload.rounds[index], entry.time) then
            success = false
        end
    end

    return true, success
end

---@param difficulty any
---@param index integer
---@return { areaSize: number, speed: number }
local function roundOf(difficulty, index)
    if type(difficulty) == 'string' then
        local preset = PRESETS[difficulty]

        if not preset then
            Utils.Raise(4, 'SkillCheck.Start: difficulty %d MUST be a UgLib.Enums.Difficulty value or { areaSize, speed }', index)
        end

        return preset
    end

    if type(difficulty) == 'table' then
        for key in pairs(difficulty) do
            if not CUSTOM_OPTIONS[key] then
                Utils.Raise(4, 'SkillCheck.Start: difficulty %d has an unknown field "%s"', index, tostring(key))
            end
        end

        local problem = checkRound(difficulty)

        if problem then
            Utils.Raise(4, 'SkillCheck.Start: difficulty %d: %s', index, problem)
        end

        return difficulty
    end

    Utils.Raise(4, 'SkillCheck.Start: difficulty %d MUST be a UgLib.Enums.Difficulty value or { areaSize, speed }', index)

    return PRESETS[Enums.Difficulty.Easy]
end

---@type string? layer id of the calling resource's check
local current = nil

---@param difficulties (UgDifficulty|{ areaSize: number, speed: number })[]
---@param keys string[]
---@return UgSkillRound[] rounds
---@return integer timeout ms
local function buildRounds(difficulties, keys)
    local rounds = {}
    local timeout = 2000

    for index, difficulty in ipairs(difficulties) do
        local base = roundOf(difficulty, index)
        local latest = math.max(MIN_START, math.floor(360 - base.areaSize - 10))

        rounds[index] = {
            areaSize = base.areaSize,
            speed = base.speed,
            start = math.random(MIN_START, latest),
            key = keys[math.random(1, #keys)],
        }
        timeout = timeout + math.ceil(360 / base.speed) + ROUND_PAUSE_MS
    end

    return rounds, timeout
end

---Runs one round per difficulty and waits. Every round MUST be hit. MUST run in a thread.
---@param difficulties (UgDifficulty|{ areaSize: number, speed: number })[] 1 to 10 rounds
---@param keys? string[] keys a round MAY ask for, one lower-case letter or digit each, defaults to `{ 'e' }`
---@param options? { color?: UgLibColorValue, position?: UgPosition }
---@return boolean success
---@return UgCloseReason? reason when it ended without an answer: `Busy`, `Timeout`, `Cancelled`, `Replaced` or `Closed`
function SkillCheck.Start(difficulties, keys, options)
    if type(difficulties) ~= 'table' or #difficulties < 1 or #difficulties > MAX_ROUNDS then
        Utils.Raise(2, 'SkillCheck.Start: difficulties MUST be 1 to %d rounds', MAX_ROUNDS)
    end

    keys = keys or { 'e' }

    if type(keys) ~= 'table' or #keys < 1 or #keys > MAX_KEYS then
        Utils.Raise(2, 'SkillCheck.Start: keys MUST be 1 to %d keys', MAX_KEYS)
    end

    for _, key in ipairs(keys) do
        if type(key) ~= 'string' or not key:find(KEY_PATTERN) then
            Utils.Raise(2, 'SkillCheck.Start: each key MUST be one lower-case letter or digit')
        end
    end

    options = options or {}
    Utils.CheckOptions('SkillCheck.Start', options, OPTIONS)
    Utils.CheckEnum('SkillCheck.Start', 'position', options.position, Enums.Position, true)

    if options.color ~= nil and not Utils.IsColor(options.color) then
        Utils.Raise(2, 'SkillCheck.Start: color MUST be a UgLib.Enums.Color value or a #rrggbb hex')
    end

    local rounds, timeout = buildRounds(difficulties, keys)
    local payload = {
        rounds = rounds,
        position = options.position or Enums.Position.Center,
        color = options.color,
    }
    local result, reason = Requests.Await('SkillCheck.Start', KIND, payload, {
        timeout = timeout,
        onOpen = function(id)
            current = id
        end,
    })

    current = nil

    if reason then
        return false, reason
    end

    return result == true, nil
end

---Stops the calling resource's check. It ends with `Closed`.
---@return boolean cancelled false when none is running
function SkillCheck.Cancel()
    return current ~= nil and Requests.Close(current)
end

---True while the calling resource runs a check.
---@return boolean
function SkillCheck.IsActive()
    return current ~= nil
end

if IS_OWNER then
    UgLib.Internal.Layers.RegisterType(KIND, {
        modal = true,
        focus = UgLib.Internal.Protocol.Nui.Focus.Keyboard,
        sanitize = rebuild,
        validate = validate,
    })

    UgLib.Internal.Demos.Register('skillcheck', function(args)
        local difficulty = PRESETS[args[1]] and args[1] or Enums.Difficulty.Medium
        local success, reason = SkillCheck.Start({ difficulty, difficulty, difficulty }, { 'e', 'q' })

        print(('[ug-lib] skill check success %s, reason %s'):format(tostring(success), tostring(reason)))
    end)
end
