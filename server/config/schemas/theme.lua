--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

local Enums = UgLib.Enums

local TOKENS = {
    'background', 'foreground', 'card', 'cardForeground', 'popover', 'popoverForeground',
    'primary', 'primaryForeground', 'secondary', 'secondaryForeground', 'muted', 'mutedForeground',
    'accent', 'accentForeground', 'destructive', 'destructiveForeground', 'success', 'successForeground',
    'warning', 'warningForeground', 'border', 'input', 'ring',
}

local NUMBER = '%d+%.?%d*'
local HSL_PATTERN = ('^%s %s%%%% %s%%%%$'):format(NUMBER, NUMBER, NUMBER)

---@param value table
---@return boolean ok
---@return string? message
local function validateColors(value)
    for token, color in pairs(value) do
        if not UgLib.Table.Contains(TOKENS, token) then
            local suggestion = type(token) == 'string' and UgLib.String.Suggest(token, TOKENS) or nil
            local hint = suggestion and (' Did you mean "%s"?'):format(suggestion) or ''

            return false, ('has an unknown token "%s".%s'):format(tostring(token), hint)
        end

        if type(color) ~= 'string' or not color:find(HSL_PATTERN) then
            return false, ('%s MUST be an HSL triplet such as "258 90%% 66%%"'):format(token)
        end
    end

    return true
end

UgLib.Internal.Config.Loader.Register('theme', {
    options = {
        {
            key = 'mode',
            type = 'string',
            default = Enums.ThemeMode.Dark,
            values = { Enums.ThemeMode.Dark, Enums.ThemeMode.Light },
            description = 'Color mode of every component.',
        },
        {
            key = 'colors',
            type = 'table',
            default = {},
            max = #TOKENS,
            description = 'Color overrides as HSL triplets, such as primary = \'258 90% 66%\'.\nTokens: ' .. table.concat(TOKENS, ', ') .. '.',
            validate = validateColors,
        },
        {
            key = 'radius',
            type = 'string',
            default = '0.5rem',
            max = 16,
            description = 'Corner radius of panels and buttons, in rem or px.',
            validate = function(value)
                local ok = value:find('^%d*%.?%d+rem$') ~= nil or value:find('^%d*%.?%d+px$') ~= nil

                return ok, 'MUST be a size such as "0.5rem" or "8px"'
            end,
        },
        {
            key = 'font',
            type = 'string',
            default = 'Inter',
            values = { 'Inter' },
            description = 'Typeface. Only bundled fonts are available: ug-lib loads nothing from the network.',
        },
        {
            key = 'scale',
            type = 'number',
            default = 1.0,
            min = 0.75,
            max = 1.5,
            description = 'UI scale.',
        },
    },
})
