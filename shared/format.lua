--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Number, money, duration and distance text. Translations of whole sentences belong to `UgLib.Locale`.
---@class UgLib.Format
local Format = {}
UgLib.Format = Format

local Utils = UgLib.Internal.Utils
local CurrencyPosition = UgLib.Enums.CurrencyPosition
local DurationStyle = UgLib.Enums.DurationStyle

local NUMBER_OPTIONS = {
    decimals = true,
    separator = true,
    decimalSeparator = true,
}
local MONEY_OPTIONS = {
    symbol = true,
    position = true,
    decimals = true,
    separator = true,
    decimalSeparator = true,
}
local DURATION_OPTIONS = {
    style = true,
}
local DISTANCE_OPTIONS = {
    decimals = true,
    imperial = true,
}
local CLOCK_OPTIONS = {
    twelveHour = true,
}

local DEFAULT_CURRENCY = {
    symbol = '$',
    position = CurrencyPosition.Before,
}
local FEET_PER_METER = 3.28084
local FEET_PER_MILE = 5280

-- Unit words come from ug-lib's locale files: `duration.<singular>` and `duration.<plural>`.
local LONG_UNITS = {
    {
        seconds = 86400,
        singular = 'day',
        plural = 'days',
    },
    {
        seconds = 3600,
        singular = 'hour',
        plural = 'hours',
    },
    {
        seconds = 60,
        singular = 'minute',
        plural = 'minutes',
    },
    {
        seconds = 1,
        singular = 'second',
        plural = 'seconds',
    },
}

---@param name string
---@param value any
local function checkNumber(name, value)
    if type(value) ~= 'number' then
        Utils.Raise(3, '%s expects a number, got %s', name, type(value))
    end
end

---@param name string
---@param decimals any
---@return integer
local function checkDecimals(name, decimals)
    if decimals == nil then
        return 0
    end

    if math.type(decimals) ~= 'integer' or decimals < 0 or decimals > 10 then
        Utils.Raise(3, '%s: decimals MUST be an integer from 0 to 10', name)
    end

    return decimals
end

---@param value number
---@param decimals integer
---@param separator string
---@param decimalSeparator string
---@return string
local function formatNumber(value, decimals, separator, decimalSeparator)
    if value ~= value or value == math.huge or value == -math.huge then
        return tostring(value)
    end

    local text = ('%.' .. decimals .. 'f'):format(math.abs(value))
    local whole, fraction = text:match('^(%d+)%.?(%d*)$')

    whole = whole:reverse():gsub('(%d%d%d)', '%1' .. separator:reverse():gsub('%%', '%%%%')):reverse()

    if whole:sub(1, #separator) == separator then
        whole = whole:sub(#separator + 1)
    end

    local result = whole

    if decimals > 0 then
        result = result .. decimalSeparator .. fraction
    end

    if value < 0 and tonumber(text) ~= 0 then
        result = '-' .. result
    end

    return result
end

---`1234567.891` with 2 decimals is `1,234,567.89`.
---@param value number
---@param options? { decimals?: integer, separator?: string, decimalSeparator?: string }
---@return string
function Format.Number(value, options)
    checkNumber('Format.Number', value)
    options = options and Utils.CheckOptions('Format.Number', options, NUMBER_OPTIONS) or {}

    return formatNumber(value, checkDecimals('Format.Number', options.decimals), options.separator or ',', options.decimalSeparator or '.')
end

---`$1,500` by default, or `settings.currency` once config is loaded.
---With `position = After`, the symbol follows after a space: `1,500 €`.
---@param amount number
---@param options? { symbol?: string, position?: UgCurrencyPosition, decimals?: integer, separator?: string, decimalSeparator?: string }
---@return string
function Format.Money(amount, options)
    checkNumber('Format.Money', amount)
    options = options and Utils.CheckOptions('Format.Money', options, MONEY_OPTIONS) or {}
    Utils.CheckEnum('Format.Money', 'position', options.position, CurrencyPosition, true)

    local currency = UgLib.Internal.Config.Get('settings', 'currency') or DEFAULT_CURRENCY
    local symbol = options.symbol or currency.symbol
    local position = options.position or currency.position
    local number = formatNumber(math.abs(amount), checkDecimals('Format.Money', options.decimals), options.separator or ',', options.decimalSeparator or '.')
    local sign = amount < 0 and '-' or ''

    if position == CurrencyPosition.After then
        return sign .. number .. ' ' .. symbol
    end

    return sign .. symbol .. number
end

---@param ms number
---@return integer
local function toSeconds(ms)
    return math.max(math.floor(ms / 1000), 0)
end

---@param seconds integer
---@return string
local function shortDuration(seconds)
    local days = seconds // 86400
    local hours = seconds % 86400 // 3600
    local minutes = seconds % 3600 // 60

    if days > 0 then
        return ('%dd %02dh'):format(days, hours)
    end

    if hours > 0 then
        return ('%dh %02dm'):format(hours, minutes)
    end

    if minutes > 0 then
        return ('%dm %02ds'):format(minutes, seconds % 60)
    end

    return ('%ds'):format(seconds)
end

---@param seconds integer
---@return string
local function clockDuration(seconds)
    local hours = seconds // 3600

    if hours > 0 then
        return ('%d:%02d:%02d'):format(hours, seconds % 3600 // 60, seconds % 60)
    end

    return ('%02d:%02d'):format(seconds // 60, seconds % 60)
end

---@param count integer
---@param unit { singular: string, plural: string }
---@return string
local function unitText(count, unit)
    return UgLib.Internal.Locale.Text('duration.' .. (count == 1 and unit.singular or unit.plural), {
        count = count,
    })
end

---@param seconds integer
---@return string
local function longDuration(seconds)
    local parts = {}
    local rest = seconds
    local first = nil

    for index, unit in ipairs(LONG_UNITS) do
        local count = rest // unit.seconds

        if count > 0 and not first then
            first = index
        end

        if count > 0 and index - first <= 1 then
            parts[#parts + 1] = unitText(count, unit)
        end

        rest = rest % unit.seconds
    end

    if #parts == 0 then
        return unitText(0, LONG_UNITS[#LONG_UNITS])
    end

    return table.concat(parts, ' ')
end

---Milliseconds as text. Negative durations count as 0.
---`Short` (default): `45s`, `3m 05s`, `1h 02m`, `2d 03h`. `Clock`: `03:05`, `1:02:30`.
---`Long`: the largest unit and the one below it, when not zero, in the configured language: `1 hour 2 minutes`, `1 day`.
---@param ms number
---@param options? { style?: UgDurationStyle }
---@return string
function Format.Duration(ms, options)
    checkNumber('Format.Duration', ms)
    options = options and Utils.CheckOptions('Format.Duration', options, DURATION_OPTIONS) or {}
    Utils.CheckEnum('Format.Duration', 'style', options.style, DurationStyle, true)

    local seconds = toSeconds(ms)

    if options.style == DurationStyle.Clock then
        return clockDuration(seconds)
    end

    if options.style == DurationStyle.Long then
        return longDuration(seconds)
    end

    return shortDuration(seconds)
end

---Meters as `120m` or `1.5km`. With `imperial`, as `394ft` or `1.2mi`.
---@param meters number
---@param options? { decimals?: integer, imperial?: boolean }
---@return string
function Format.Distance(meters, options)
    checkNumber('Format.Distance', meters)
    options = options and Utils.CheckOptions('Format.Distance', options, DISTANCE_OPTIONS) or {}

    local decimals = options.decimals == nil and 1 or checkDecimals('Format.Distance', options.decimals)
    local small, large, factor, unit, largeUnit = meters, meters / 1000, 1000, 'm', 'km'

    if options.imperial then
        small = meters * FEET_PER_METER
        large = small / FEET_PER_MILE
        factor, unit, largeUnit = FEET_PER_MILE, 'ft', 'mi'
    end

    if math.abs(small) >= factor then
        return ('%.' .. decimals .. 'f%s'):format(large, largeUnit)
    end

    return ('%.0f%s'):format(small, unit)
end

---A time of day: `14:05`, or `2:05 PM` with `twelveHour`.
---@param hour integer 0 to 23
---@param minute integer 0 to 59
---@param options? { twelveHour?: boolean }
---@return string
function Format.Clock(hour, minute, options)
    if math.type(hour) ~= 'integer' or hour < 0 or hour > 23 or math.type(minute) ~= 'integer' or minute < 0 or minute > 59 then
        Utils.Raise(2, 'Format.Clock expects an hour from 0 to 23 and a minute from 0 to 59')
    end

    options = options and Utils.CheckOptions('Format.Clock', options, CLOCK_OPTIONS) or {}

    if options.twelveHour then
        local displayHour = hour % 12 == 0 and 12 or hour % 12

        return ('%d:%02d %s'):format(displayHour, minute, hour < 12 and 'AM' or 'PM')
    end

    return ('%02d:%02d'):format(hour, minute)
end

---`count` with the right word: `1 item`, `3 items`, `1,200 items`.
---@param count number
---@param singular string
---@param plural? string defaults to `singular .. 's'`
---@return string
function Format.Plural(count, singular, plural)
    checkNumber('Format.Plural', count)

    if type(singular) ~= 'string' or (plural ~= nil and type(plural) ~= 'string') then
        Utils.Raise(2, 'Format.Plural expects string words')
    end

    local number = math.type(count) == 'integer' and formatNumber(count, 0, ',', '.') or tostring(count)

    return number .. ' ' .. (count == 1 and singular or plural or singular .. 's')
end
