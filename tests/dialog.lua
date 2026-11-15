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

---@param fn fun(): ...
---@return TestThread
local function run(fn)
    return H.Thread(function()
        return table.pack(fn())
    end)
end

---@return table
local function dialog()
    return UgLib.Internal.Layers.GetModal() or error('no dialog open', 2)
end

---@param result any
---@return any reply
local function answer(result)
    return H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Resolve, {
        id = dialog().key,
        result = result,
    })
end

local function dismiss()
    H.PostNui(UgLib.Internal.Protocol.Nui.Callbacks.Close, {
        id = dialog().key,
    })
end

---@param fields table
---@return TestThread
local function input(fields)
    return run(function()
        return Consumer.Dialog.Input({
            title = 'Form',
            fields = fields,
        })
    end)
end

H.Test('Alert: acknowledged, or closed', function()
    start()

    local thread = run(function()
        return Consumer.Dialog.Alert({
            title = 'Hello',
            message = 'Read the **rules**.',
        })
    end)

    H.Equal(dialog().payload, {
        variant = 'alert',
        title = 'Hello',
        message = 'Read the **rules**.',
        icon = Enums.Icon.Info,
        size = Enums.DialogSize.Medium,
    })
    H.Equal(UgLib.Internal.Nui.GetFocus(), {
        focus = true,
        cursor = true,
        keepInput = false,
    })

    answer(true)
    H.Equal(thread.result, {
        true,
        nil,
        n = 2,
    })

    local closed = run(function()
        return Consumer.Dialog.Alert({
            title = 'Hello',
        })
    end)

    dismiss()
    H.Equal(closed.result, {
        false,
        Enums.CloseReason.Cancelled,
        n = 2,
    })
end)

H.Test('Confirm: yes, no, closed and forged', function()
    start()

    for _, case in ipairs({
        {
            true,
            {
                true,
                nil,
                n = 2,
            },
        },
        {
            false,
            {
                false,
                nil,
                n = 2,
            },
        },
        {
            'yes',
            {
                false,
                Enums.CloseReason.Cancelled,
                n = 2,
            },
        },
    }) do
        local thread = run(function()
            return Consumer.Dialog.Confirm({
                title = 'Sell?',
                destructive = true,
            })
        end)

        H.Equal(dialog().payload.icon, Enums.Icon.Question)
        answer(case[1])
        H.Equal(thread.result, case[2])
    end
end)

H.Test('Input returns checked values by name', function()
    start()

    local thread = input({
        {
            name = 'plate',
            type = Enums.FieldType.Text,
            required = true,
            maxLength = 8,
        },
        {
            name = 'notes',
            type = Enums.FieldType.Textarea,
        },
        {
            name = 'price',
            type = Enums.FieldType.Number,
            min = 0,
            max = 1000,
            step = 10,
        },
        {
            name = 'fuel',
            type = Enums.FieldType.Slider,
            min = 0,
            max = 100,
        },
        {
            name = 'class',
            type = Enums.FieldType.Select,
            options = {
                {
                    value = 'suv',
                    label = 'SUV',
                },
                {
                    value = 2,
                    label = 'Two',
                },
            },
        },
        {
            name = 'extras',
            type = Enums.FieldType.MultiSelect,
            options = {
                {
                    value = 'a',
                    label = 'A',
                },
                {
                    value = 'b',
                    label = 'B',
                },
            },
        },
        {
            name = 'insured',
            type = Enums.FieldType.Checkbox,
        },
        {
            name = 'color',
            type = Enums.FieldType.Color,
        },
        {
            name = 'since',
            type = Enums.FieldType.Date,
            min = '2020-01-01',
        },
        {
            name = 'empty',
            type = Enums.FieldType.Text,
        },
    })

    answer({
        plate = 'AB\0C\n12',
        notes = 'line one\nline\ttwo\1',
        price = 120.0,
        fuel = 55,
        class = 2.0,
        extras = { 'b', 'a' },
        insured = true,
        color = '#3B82F6',
        since = '2026-10-06',
        empty = '',
    })

    H.Equal(thread.result, {
        {
            plate = 'ABC12',
            notes = 'line one\nline\ttwo',
            price = 120,
            fuel = 55,
            class = 2,
            extras = { 'b', 'a' },
            insured = true,
            color = '#3b82f6',
            since = '2026-10-06',
        },
        nil,
        n = 2,
    })
    H.Equal(math.type(thread.result[1].price), 'integer')
end)

H.Test('Input rejects answers that break the field rules', function()
    start()

    local fields = {
        {
            name = 'plate',
            type = Enums.FieldType.Text,
            required = true,
            maxLength = 4,
        },
        {
            name = 'price',
            type = Enums.FieldType.Number,
            min = 0,
            max = 100,
            step = 5,
        },
        {
            name = 'class',
            type = Enums.FieldType.Select,
            options = {
                {
                    value = 'a',
                    label = 'A',
                },
            },
        },
        {
            name = 'terms',
            type = Enums.FieldType.Checkbox,
            required = true,
        },
    }

    local bad = {
        {
            terms = true,
        },
        {
            plate = 'TOOLONG',
            terms = true,
        },
        {
            plate = 'AB',
            price = 101,
            terms = true,
        },
        {
            plate = 'AB',
            price = 7,
            terms = true,
        },
        {
            plate = 'AB',
            class = 'gold',
            terms = true,
        },
        {
            plate = 'AB',
            terms = false,
        },
        {
            plate = 'AB',
            terms = true,
            admin = true,
        },
        {
            plate = 'AB',
            price = 0 / 0,
            terms = true,
        },
        H.Any('AB'),
    }

    for _, result in ipairs(bad) do
        local thread = input(fields)

        answer(result)
        H.Equal(thread.result, {
            nil,
            Enums.CloseReason.Cancelled,
            n = 2,
        })
    end

    local good = input(fields)

    answer({
        plate = 'AB',
        price = 10,
        terms = true,
    })
    H.Equal(good.result[1], {
        plate = 'AB',
        price = 10,
        terms = true,
    })
end)

H.Test('Disabled fields keep their default', function()
    start()

    local thread = input({
        {
            name = 'id',
            type = Enums.FieldType.Number,
            disabled = true,
            default = 42,
        },
        {
            name = 'name',
            type = Enums.FieldType.Text,
        },
    })

    answer({
        id = 999999,
        name = 'Bob',
    })

    H.Equal(thread.result[1], {
        id = 42,
        name = 'Bob',
    })
end)

H.Test('Field definitions are checked at the caller', function()
    start()

    local cases = {
        {
            {
                {
                    name = '1x',
                    type = 'text',
                },
            },
            'field 1 name MUST be',
        },
        {
            {
                {
                    name = 'a',
                    type = 'email',
                },
            },
            'field "a" type MUST be a UgLib.Enums.FieldType value',
        },
        {
            {
                {
                    name = 'a',
                    type = 'text',
                    maxLenght = 5,
                },
            },
            'field "a" has an unknown option "maxLenght". Did you mean "maxLength"?',
        },
        {
            {
                {
                    name = 'a',
                    type = 'number',
                    options = {},
                },
            },
            'field "a" has an unknown option "options"',
        },
        {
            {
                {
                    name = 'a',
                    type = 'slider',
                    min = 0,
                },
            },
            'field "a" MUST set min and max',
        },
        {
            {
                {
                    name = 'a',
                    type = 'select',
                    options = {
                        {
                            value = 'x',
                            label = 'X',
                        },
                        {
                            value = 'x',
                            label = 'Y',
                        },
                    },
                },
            },
            'option 2 MUST be { value, label } with a unique',
        },
        {
            {
                {
                    name = 'a',
                    type = 'number',
                    min = 10,
                    max = 0,
                },
            },
            'min MUST NOT be greater than max',
        },
        {
            {
                {
                    name = 'a',
                    type = 'number',
                    max = 5,
                    default = 9,
                },
            },
            'field "a" default does not pass its own rules',
        },
        {
            {
                {
                    name = 'a',
                    type = 'date',
                    min = '31/01/2026',
                },
            },
            'min MUST be a date such as "2026-01-31"',
        },
        {
            {
                {
                    name = 'a',
                    type = 'text',
                },
                {
                    name = 'a',
                    type = 'text',
                },
            },
            'field name "a" is used twice',
        },
        { {}, 'fields MUST be 1 to 32 fields' },
    }

    for _, case in ipairs(cases) do
        local thread = input(case[1])

        H.Assert(thread.error and thread.error:find(case[2], 1, true), ('expected "%s", got %s'):format(case[2], tostring(thread.error)))
    end

    local line = debug.getinfo(1, 'l').currentline + 2
    local thread = run(function()
        local confirmed = Consumer.Dialog.Confirm({
            title = '',
        })

        return confirmed
    end)

    H.Assert(thread.error:find('Dialog.Confirm: title MUST be UTF-8 text', 1, true), thread.error)
    H.Assert(thread.error:find('tests/dialog.lua:' .. line .. ':', 1, true), thread.error)

    H.Raises(function()
        Consumer.Dialog.Alert(H.Any({
            title = 'a',
            destructive = true,
        }))
    end, 'Dialog.Alert: unknown option "destructive"')

    H.Raises(function()
        Consumer.Dialog.Alert({
            title = 'a',
        })
    end, 'UgLib.Dialog.Alert MUST run in a thread.')
end)

H.Test('Timeout, Busy and replace', function()
    start()

    local first = run(function()
        return Consumer.Dialog.Confirm({
            title = 'One',
            timeout = 1000,
        })
    end)

    local busy = run(function()
        return Consumer.Dialog.Confirm({
            title = 'Two',
        })
    end)

    H.Equal(busy.result, {
        false,
        Enums.CloseReason.Busy,
        n = 2,
    })

    local replacing = run(function()
        return Consumer.Dialog.Alert({
            title = 'Three',
            replace = true,
        })
    end)

    H.Equal(first.result, {
        false,
        Enums.CloseReason.Replaced,
        n = 2,
    })

    H.Advance(60000)
    H.Equal(replacing.result, {
        false,
        Enums.CloseReason.Timeout,
        n = 2,
    })
end)

H.Test('Raw exports cannot open a malformed dialog', function()
    start()

    local raw = H.LoadImport('evil-resource', 'client')

    H.Raises(function()
        raw.exports['ug-lib']:UiOpen('1', 'dialog', {
            variant = 'input',
            title = 'x',
            size = 'md',
            fields = {
                {
                    name = 'a',
                    type = 'text',
                    onSubmit = 'x',
                },
            },
        })
    end, 'Layers: invalid dialog payload: field "a" has an unknown option "onSubmit"')
end)

H.Done()
