--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

H.LoadManifest('server')

local String = UgLib.String

H.Test('Trim', function()
    H.Equal(String.Trim('  a b \t\n'), 'a b')
    H.Equal(String.Trim(''), '')

    H.Raises(function()
        String.Trim(H.Any(1))
    end, 'String.Trim expects strings, argument 1 is number')
end)

H.Test('Split on a plain separator keeps empty parts', function()
    H.Equal(String.Split('a,,b', ','), { 'a', '', 'b' })
    H.Equal(String.Split('a.b', '.'), { 'a', 'b' })
    H.Equal(String.Split('abc', ','), { 'abc' })
    H.Equal(String.Split('a::b', '::'), { 'a', 'b' })

    H.Raises(function()
        String.Split('a', '')
    end, 'separator MUST NOT be empty')
end)

H.Test('StartsWith and EndsWith', function()
    H.Equal(String.StartsWith('ug-lib', 'ug-'), true)
    H.Equal(String.StartsWith('ug-lib', '.'), false)
    H.Equal(String.EndsWith('ug-lib', 'lib'), true)
    H.Equal(String.EndsWith('ug-lib', ''), true)
    H.Equal(String.EndsWith('lib', 'ug-lib'), false)
end)

H.Test('Capitalize', function()
    H.Equal(String.Capitalize('hello world'), 'Hello world')
    H.Equal(String.Capitalize('1st'), '1st')
end)

H.Test('Truncate counts UTF-8 characters', function()
    H.Equal(String.Truncate('hello', 10), 'hello')
    H.Equal(String.Truncate('hello world', 8), 'hello...')
    H.Equal(String.Truncate('héllo wörld', 6, '…'), 'héllo…')
    H.Equal(String.Truncate('abc', 2, '...'), '...')
    H.Equal(String.Truncate('\255\255\255\255', 3, '.'), '\255\255.')

    H.Raises(function()
        String.Truncate('a', 0)
    end, 'max MUST be a positive integer')
end)

H.Test('Random follows the pattern', function()
    for _ = 1, 50 do
        local value = String.Random('AAA-111 aa..')

        H.Assert(value:find('^%u%u%u%-%d%d%d %l%l%w%w$') ~= nil, value)
    end
end)

H.Test('Distance and Suggest', function()
    H.Equal(String.Distance('kitten', 'sitting'), 3)
    H.Equal(String.Distance('', 'abc'), 3)
    H.Equal(String.Suggest('TITEL', { 'title', 'timeout' }), 'title')
    H.Equal(String.Suggest('zzzzzz', { 'title' }), nil)
end)

H.Done()
