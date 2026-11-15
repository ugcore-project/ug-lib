--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

H.LoadManifest('server')

local Enums = UgLib.Enums

H.Test('Enum values are unique strings', function()
    for name, enum in pairs(Enums) do
        if name ~= 'Events' then
            local seen = {}

            for key, value in pairs(enum) do
                H.Assert(type(value) == 'string', ('%s.%s is not a string'):format(name, key))
                H.Assert(not seen[value], ('%s.%s and %s.%s share "%s"'):format(name, key, name, tostring(seen[value]), value))
                seen[value] = key
            end
        end
    end
end)

H.Test('Event names are ug-lib:<Group>:<Key>', function()
    for group, events in pairs(Enums.Events) do
        for key, name in pairs(events) do
            H.Equal(name, ('ug-lib:%s:%s'):format(group, key))
        end
    end
end)

H.Test('Positions are the nine anchors', function()
    local count = 0

    for _ in pairs(Enums.Position) do
        count = count + 1
    end

    H.Equal(count, 9)
end)

H.Test('Enums the page reads match web/src/types/enums.ts', function()
    local source = assert(io.open('web/src/types/enums.ts', 'rb')):read('a')
    local count = 0

    for name, block in source:gmatch('export const (%w+) = (%b{})') do
        local values = {}

        for key, value in block:gmatch('(%w+):%s*"([^"]+)"') do
            values[key] = value
        end

        H.Assert(Enums[name] ~= nil, name .. ' is in enums.ts but not in UgLib.Enums')
        H.Equal(values, Enums[name], name)
        count = count + 1
    end

    H.Assert(count >= 9, 'enums.ts has fewer enums than expected')
end)

H.Test('Enums load on the client', function()
    H.LoadManifest('client')

    H.Equal(UgLib.Enums.CloseReason.Timeout, 'timeout')
end)

H.Done()
