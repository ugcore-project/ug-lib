--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

H.LoadManifest('server')

local Format = UgLib.Format
local Enums = UgLib.Enums

H.Test('Number groups thousands', function()
    H.Equal(Format.Number(0), '0')
    H.Equal(Format.Number(999), '999')
    H.Equal(Format.Number(1000), '1,000')
    H.Equal(Format.Number(1234567.891, {
        decimals = 2,
    }), '1,234,567.89')
    H.Equal(Format.Number(-1234), '-1,234')
    H.Equal(Format.Number(-0.001, {
        decimals = 2,
    }), '0.00')
    H.Equal(Format.Number(1234567.5, {
        decimals = 1,
        separator = '.',
        decimalSeparator = ',',
    }), '1.234.567,5')
    H.Equal(Format.Number(1234567, {
        separator = ' ',
    }), '1 234 567')
    H.Equal(Format.Number(1/0), 'inf')

    H.Raises(function()
        Format.Number(1, H.Any({
            decimal = 2,
        }))
    end, 'Format.Number: unknown option "decimal". Did you mean "decimals"?')

    H.Raises(function()
        Format.Number(1, {
            decimals = 11,
        })
    end, 'Format.Number: decimals MUST be an integer from 0 to 10')
end)

H.Test('Money places the symbol', function()
    H.Equal(Format.Money(1500), '$1,500')
    H.Equal(Format.Money(-1500), '-$1,500')
    H.Equal(Format.Money(1500.5, {
        decimals = 2,
    }), '$1,500.50')
    H.Equal(Format.Money(1500, {
        symbol = '€',
        position = Enums.CurrencyPosition.After,
        separator = '.',
    }), '1.500 €')

    H.Raises(function()
        Format.Money(1, {
            position = H.Any('left'),
        })
    end, 'Format.Money: position MUST be one of after, before, got left.')
end)

H.Test('Duration short style', function()
    H.Equal(Format.Duration(45000), '45s')
    H.Equal(Format.Duration(185000), '3m 05s')
    H.Equal(Format.Duration(3720000), '1h 02m')
    H.Equal(Format.Duration(2 * 86400000 + 3 * 3600000), '2d 03h')
    H.Equal(Format.Duration(-5000), '0s')
    H.Equal(Format.Duration(999), '0s')
end)

H.Test('Duration clock and long styles', function()
    local Clock, Long = Enums.DurationStyle.Clock, Enums.DurationStyle.Long

    H.Equal(Format.Duration(185000, {
        style = Clock,
    }), '03:05')
    H.Equal(Format.Duration(3750000, {
        style = Clock,
    }), '1:02:30')
    H.Equal(Format.Duration(185000, {
        style = Long,
    }), '3 minutes 5 seconds')
    H.Equal(Format.Duration(3600000 + 1000, {
        style = Long,
    }), '1 hour')
    H.Equal(Format.Duration(86400000 + 60000, {
        style = Long,
    }), '1 day')
    H.Equal(Format.Duration(0, {
        style = Long,
    }), '0 seconds')

    H.Raises(function()
        Format.Duration(1, {
            style = H.Any('tiny'),
        })
    end, 'style MUST be one of clock, long, short')
end)

H.Test('Distance in metric and imperial', function()
    H.Equal(Format.Distance(120), '120m')
    H.Equal(Format.Distance(1500), '1.5km')
    H.Equal(Format.Distance(1500, {
        decimals = 0,
    }), '2km')
    H.Equal(Format.Distance(120, {
        imperial = true,
    }), '394ft')
    H.Equal(Format.Distance(2000, {
        imperial = true,
    }), '1.2mi')
end)

H.Test('Clock in 24 and 12 hours', function()
    H.Equal(Format.Clock(14, 5), '14:05')
    H.Equal(Format.Clock(0, 0, {
        twelveHour = true,
    }), '12:00 AM')
    H.Equal(Format.Clock(14, 5, {
        twelveHour = true,
    }), '2:05 PM')
    H.Equal(Format.Clock(12, 30, {
        twelveHour = true,
    }), '12:30 PM')

    H.Raises(function()
        Format.Clock(24, 0)
    end, 'Format.Clock expects an hour from 0 to 23')
end)

H.Test('Plural', function()
    H.Equal(Format.Plural(1, 'item'), '1 item')
    H.Equal(Format.Plural(3, 'item'), '3 items')
    H.Equal(Format.Plural(1200, 'person', 'people'), '1,200 people')
    H.Equal(Format.Plural(0, 'item'), '0 items')
end)

H.Done()
