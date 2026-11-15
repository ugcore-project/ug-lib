--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@type TestHelpers
local H = dofile('tests/helpers.lua')

---@type UgLib
local Consumer = H.Any(nil)

---@type UgLib.Enums
local Enums = H.Any(nil)

local function start()
    H.Reset()
    H.ResourceFiles['config/settings.lua'] = "return { debug = 'on' }"
    H.LoadManifest('server')
    H.LoadManifest('client')
    H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Ready, {})
    H.TakeNui()

    Enums = UgLib.Enums
    Consumer = H.ImportPrivate(H.LoadImport('my-shop', 'client')).UgLib
end

---@param difficulties table
---@param keys? string[]
---@return TestThread
local function run(difficulties, keys)
    return H.Thread(function()
        return table.pack(Consumer.SkillCheck.Start(difficulties, keys))
    end)
end

---@return table layer
local function check()
    for _, layer in ipairs(UgLib.Internal.Layers.GetAll()) do
        if layer.kind == 'skillcheck' then
            return layer
        end
    end

    error('no skill check open', 2)
end

---A press in the middle of the round's area.
---@param round table
---@return table
local function goodPress(round)
    return {
        hit = true,
        time = math.floor((round.start + round.areaSize / 2) / round.speed),
    }
end

---@param result any
local function answer(result)
    return H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Resolve, {
        id = check().key,
        result = result,
    })
end

H.Test('Lua picks the rounds', function()
    start()

    run({
        Enums.Difficulty.Easy,
        Enums.Difficulty.Hard,
        {
            areaSize = 20,
            speed = 0.5,
        },
    }, { 'e', 'q' })

    local rounds = check().payload.rounds

    H.Equal(#rounds, 3)
    H.Equal({ rounds[1].areaSize, rounds[1].speed }, { 60, 0.25 })
    H.Equal({ rounds[3].areaSize, rounds[3].speed }, { 20, 0.5 })

    for _, round in ipairs(rounds) do
        H.Assert(round.start >= 90 and round.start + round.areaSize <= 360, 'the area fits after 90 degrees')
        H.Assert(round.key == 'e' or round.key == 'q')
    end

    H.Equal(UgLib.Internal.Nui.GetFocus(), {
        focus = true,
        cursor = false,
        keepInput = false,
    })
end)

H.Test('Every round hit in its area succeeds', function()
    start()

    local thread = run({ Enums.Difficulty.Medium, Enums.Difficulty.Medium })
    local rounds = check().payload.rounds

    answer({ goodPress(rounds[1]), goodPress(rounds[2]) })

    H.Equal(thread.result, {
        true,
        nil,
        n = 2,
    })
    H.Equal(Consumer.SkillCheck.IsActive(), false)
end)

H.Test('A miss or a stop before the last round fails', function()
    start()

    local missed = run({ Enums.Difficulty.Easy, Enums.Difficulty.Easy })
    local rounds = check().payload.rounds

    answer({
        goodPress(rounds[1]),
        {
            hit = false,
            time = 100,
        },
    })
    H.Equal(missed.result, {
        false,
        nil,
        n = 2,
    })

    local stopped = run({ Enums.Difficulty.Easy, Enums.Difficulty.Easy })

    answer({
        {
            hit = false,
            time = 50,
        },
    })
    H.Equal(stopped.result, {
        false,
        nil,
        n = 2,
    })
end)

H.Test('A forged hit outside the area counts as a miss', function()
    start()

    local thread = run({ Enums.Difficulty.Hard })
    local round = check().payload.rounds[1]

    answer({
        {
            hit = true,
            time = 1,
        },
    })
    H.Equal(thread.result, {
        false,
        nil,
        n = 2,
    }, 'too early')

    local late = run({ Enums.Difficulty.Hard })
    local lateRound = check().payload.rounds[1]

    answer({
        {
            hit = true,
            time = math.ceil((lateRound.start + lateRound.areaSize) / lateRound.speed) + 500,
        },
    })
    H.Equal(late.result, {
        false,
        nil,
        n = 2,
    }, 'too late')

    H.Assert(round.speed > 0)
end)

H.Test('Malformed answers resolve as Cancelled', function()
    start()

    for _, result in ipairs({
        H.Any('win'),
        {},
        {
            {
                hit = 'yes',
                time = 1,
            },
        },
        {
            {
                hit = true,
            },
        },
        {
            {
                hit = true,
                time = 0 / 0,
            },
        },
    }) do
        local thread = run({ Enums.Difficulty.Easy })

        answer(result)
        H.Equal(thread.result, {
            false,
            Enums.CloseReason.Cancelled,
            n = 2,
        })
    end

    local tooMany = run({ Enums.Difficulty.Easy })
    local round = check().payload.rounds[1]

    answer({ goodPress(round), goodPress(round) })
    H.Equal(tooMany.result, {
        false,
        Enums.CloseReason.Cancelled,
        n = 2,
    })
end)

H.Test('Timeout, Cancel and Busy', function()
    start()

    local thread = run({ Enums.Difficulty.Easy })

    H.Advance(2000 + 1440 + 300)
    H.Equal(thread.result, {
        false,
        Enums.CloseReason.Timeout,
        n = 2,
    })

    local cancelled = run({ Enums.Difficulty.Easy })

    H.Equal(Consumer.SkillCheck.Cancel(), true)
    H.Equal(cancelled.result, {
        false,
        Enums.CloseReason.Closed,
        n = 2,
    })
    H.Equal(Consumer.SkillCheck.Cancel(), false)

    run({ Enums.Difficulty.Easy })

    local busy = run({ Enums.Difficulty.Easy })

    H.Equal(busy.result, {
        false,
        Enums.CloseReason.Busy,
        n = 2,
    })
end)

H.Test('Arguments are checked', function()
    start()

    H.Raises(function()
        Consumer.SkillCheck.Start({})
    end, 'SkillCheck.Start: difficulties MUST be 1 to 10 rounds')

    H.Raises(function()
        Consumer.SkillCheck.Start({ H.Any('impossible') })
    end, 'difficulty 1 MUST be a UgLib.Enums.Difficulty value or { areaSize, speed }')

    H.Raises(function()
        Consumer.SkillCheck.Start({
            {
                areaSize = 5,
                speed = 0.5,
            },
        })
    end, 'difficulty 1: areaSize MUST be from 10 to 120 degrees')

    H.Raises(function()
        Consumer.SkillCheck.Start({
            {
                size = 30,
                speed = 0.5,
            },
        })
    end, 'difficulty 1 has an unknown field "size"')

    H.Raises(function()
        Consumer.SkillCheck.Start({ Enums.Difficulty.Easy }, { 'E' })
    end, 'each key MUST be one lower-case letter or digit')

    local line = debug.getinfo(1, 'l').currentline + 2
    local message = H.Raises(function()
        Consumer.SkillCheck.Start({ Enums.Difficulty.Easy })
    end, 'UgLib.SkillCheck.Start MUST run in a thread.')

    H.Assert(message:find('tests/skillcheck.lua:' .. line .. ':', 1, true) ~= nil, message)
end)

H.Done()
