--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Blocking dialogs: Alert, Confirm and Input. Every value the player enters is checked in Lua against the
---field definitions before the caller sees it. The page only shows the form.
---@class UgLib.Dialog
local Dialog = {}
UgLib.Dialog = Dialog

local Utils = UgLib.Internal.Utils
local Enums = UgLib.Enums
local Requests = UgLib.Internal.Requests
local FieldType = Enums.FieldType
local Variants = UgLib.Internal.Protocol.Nui.DialogVariants

local KIND = UgLib.Internal.Protocol.Nui.Types.Dialog
local IS_OWNER = GetCurrentResourceName() == 'ug-lib'

local COMMON = {
    title = true,
    message = true,
    icon = true,
    color = true,
    confirmLabel = true,
    cancelLabel = true,
    timeout = true,
    replace = true,
    size = true,
}
local CONFIRM = {
    destructive = true,
}
local INPUT = {
    fields = true,
}

local FIELD_COMMON = {
    name = true,
    type = true,
    label = true,
    description = true,
    placeholder = true,
    default = true,
    required = true,
    disabled = true,
    icon = true,
}

---@type table<UgFieldType, table<string, true>>
local FIELD_EXTRAS = {
    [FieldType.Text] = {
        maxLength = true,
    },
    [FieldType.Password] = {
        maxLength = true,
    },
    [FieldType.Textarea] = {
        maxLength = true,
        rows = true,
    },
    [FieldType.Number] = {
        min = true,
        max = true,
        step = true,
    },
    [FieldType.Slider] = {
        min = true,
        max = true,
        step = true,
    },
    [FieldType.Select] = {
        options = true,
    },
    [FieldType.MultiSelect] = {
        options = true,
        min = true,
        max = true,
    },
    [FieldType.Checkbox] = {},
    [FieldType.Toggle] = {},
    [FieldType.Color] = {},
    [FieldType.Date] = {
        min = true,
        max = true,
    },
}

local MAX_TITLE = 128
local MAX_MESSAGE = 1024
local MAX_LABEL = 128
local MAX_DESCRIPTION = 512
local MAX_FIELDS = 32
local MAX_OPTIONS = 100
local MAX_ROWS = 20
local TEXT_LIMIT = 1024
local TEXTAREA_LIMIT = 4096
local DEFAULT_TEXT = 256
local NAME_PATTERN = '^[%a_][%w_]*$'
local DATE_PATTERN = '^(%d%d%d%d)%-(%d%d)%-(%d%d)$'
local COLOR_PATTERN = '^#%x%x%x%x%x%x$'

---@class UgDialogField
---@field name string
---@field type UgFieldType
---@field label? string
---@field description? string
---@field placeholder? string
---@field default? any
---@field required? boolean
---@field disabled? boolean
---@field icon? UgIcon
---@field maxLength? integer
---@field rows? integer
---@field min? number|string
---@field max? number|string
---@field step? number
---@field options? { value: string|integer, label: string }[]

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

---@param value any
---@param max integer
---@return boolean
local function isText(value, max)
    local length = type(value) == 'string' and utf8.len(value)

    return length ~= nil and length ~= false and length >= 1 and length <= max
end

---@param value any
---@return boolean
local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---@param value number
---@return number
local function normalize(value)
    return math.tointeger(value) or value
end

---@param value string
---@return boolean
local function isDate(value)
    local year, month, day = value:match(DATE_PATTERN)

    if not year then
        return false
    end

    month, day = tonumber(month), tonumber(day)

    return month >= 1 and month <= 12 and day >= 1 and day <= 31
end

---@param field UgDialogField
---@return integer
local function textLimit(field)
    return field.maxLength or (field.type == FieldType.Textarea and TEXTAREA_LIMIT or DEFAULT_TEXT)
end

---@param field UgDialogField
---@param value any
---@return boolean
local function isOption(field, value)
    for _, option in ipairs(field.options) do
        if option.value == value then
            return true
        end
    end

    return false
end

---Checks one value against its field. Strings lose control characters (textarea keeps tab and line breaks).
---Empty strings and empty selections count as absent.
---@param field UgDialogField
---@param value any
---@return boolean ok
---@return any value the cleaned value, nil when absent
local function checkValue(field, value)
    local kind = field.type

    if value == nil then
        return true, nil
    end

    if kind == FieldType.Text or kind == FieldType.Password or kind == FieldType.Textarea then
        if type(value) ~= 'string' or not utf8.len(value) then
            return false, nil
        end

        local pattern = kind == FieldType.Textarea and '[%z\1-\8\11\12\14-\31\127]' or '[%z\1-\31\127]'
        local cleaned = value:gsub(pattern, '')

        if cleaned == '' then
            return true, nil
        end

        return utf8.len(cleaned) <= textLimit(field), cleaned
    end

    if kind == FieldType.Number or kind == FieldType.Slider then
        if not isFinite(value) then
            return false, nil
        end

        value = normalize(value)

        if field.min and value < field.min or field.max and value > field.max then
            return false, nil
        end

        if field.step then
            local steps = (value - (field.min or 0)) / field.step

            if math.abs(steps - math.floor(steps + 0.5)) > 1e-6 then
                return false, nil
            end
        end

        return true, value
    end

    if kind == FieldType.Select then
        value = type(value) == 'number' and normalize(value) or value

        return isOption(field, value), value
    end

    if kind == FieldType.MultiSelect then
        if type(value) ~= 'table' or #value > #field.options then
            return false, nil
        end

        local seen, list = {}, {}

        for index = 1, #value do
            local entry = type(value[index]) == 'number' and normalize(value[index]) or value[index]

            if not isOption(field, entry) or seen[entry] then
                return false, nil
            end

            seen[entry] = true
            list[index] = entry
        end

        if #list < (field.min or 0) or #list > (field.max or #field.options) then
            return false, nil
        end

        return true, #list > 0 and list or nil
    end

    if kind == FieldType.Checkbox or kind == FieldType.Toggle then
        return type(value) == 'boolean', value
    end

    if kind == FieldType.Color then
        return type(value) == 'string' and value:find(COLOR_PATTERN) ~= nil, type(value) == 'string' and value:lower() or nil
    end

    if type(value) ~= 'string' or not isDate(value) then
        return false, nil
    end

    if value == '' then
        return true, nil
    end

    return not (field.min and value < field.min or field.max and value > field.max), value
end

---@param field any
---@param index integer
---@return string? problem
local function checkFieldShape(field, index)
    if type(field) ~= 'table' then
        return ('field %d MUST be a table'):format(index)
    end

    if type(field.name) ~= 'string' or #field.name > 32 or not field.name:find(NAME_PATTERN) then
        return ('field %d name MUST be 1 to 32 letters, digits or underscores, not starting with a digit'):format(index)
    end

    local label = ('field "%s"'):format(field.name)
    local extras = FIELD_EXTRAS[field.type]

    if not extras then
        return ('%s type MUST be a UgLib.Enums.FieldType value, got %s'):format(label, tostring(field.type))
    end

    for key in pairs(field) do
        if not FIELD_COMMON[key] and not extras[key] then
            local names = {}

            for name in pairs(FIELD_COMMON) do
                names[#names + 1] = name
            end

            for name in pairs(extras) do
                names[#names + 1] = name
            end

            table.sort(names)

            local suggestion = type(key) == 'string' and UgLib.String.Suggest(key, names) or nil

            return ('%s has an unknown option "%s".%s'):format(label, tostring(key), suggestion and (' Did you mean "%s"?'):format(suggestion) or '')
        end
    end

    for key, max in pairs({
        label = MAX_LABEL,
        description = MAX_DESCRIPTION,
        placeholder = MAX_LABEL,
    }) do
        if field[key] ~= nil and not isText(field[key], max) then
            return ('%s %s MUST be UTF-8 text of 1 to %d characters'):format(label, key, max)
        end
    end

    for _, key in ipairs({ 'required', 'disabled' }) do
        if field[key] ~= nil and type(field[key]) ~= 'boolean' then
            return ('%s %s MUST be a boolean'):format(label, key)
        end
    end

    if field.icon ~= nil and not isValue(Enums.Icon, field.icon) then
        return ('%s icon MUST be a UgLib.Enums.Icon value'):format(label)
    end

    local limit = field.type == FieldType.Textarea and TEXTAREA_LIMIT or TEXT_LIMIT

    if field.maxLength ~= nil and (math.type(field.maxLength) ~= 'integer' or field.maxLength < 1 or field.maxLength > limit) then
        return ('%s maxLength MUST be an integer from 1 to %d'):format(label, limit)
    end

    if field.rows ~= nil and (math.type(field.rows) ~= 'integer' or field.rows < 1 or field.rows > MAX_ROWS) then
        return ('%s rows MUST be an integer from 1 to %d'):format(label, MAX_ROWS)
    end

    if field.type == FieldType.Date then
        for _, key in ipairs({ 'min', 'max' }) do
            if field[key] ~= nil and (type(field[key]) ~= 'string' or not isDate(field[key])) then
                return ('%s %s MUST be a date such as "2026-01-31"'):format(label, key)
            end
        end
    elseif field.type == FieldType.MultiSelect then
        for _, key in ipairs({ 'min', 'max' }) do
            if field[key] ~= nil and (math.type(field[key]) ~= 'integer' or field[key] < 0) then
                return ('%s %s MUST be a non-negative integer count'):format(label, key)
            end
        end
    else
        for _, key in ipairs({ 'min', 'max' }) do
            if field[key] ~= nil and not isFinite(field[key]) then
                return ('%s %s MUST be a finite number'):format(label, key)
            end
        end
    end

    if field.min ~= nil and field.max ~= nil and field.min > field.max then
        return ('%s min MUST NOT be greater than max'):format(label)
    end

    if field.step ~= nil and (not isFinite(field.step) or field.step <= 0) then
        return ('%s step MUST be a positive number'):format(label)
    end

    if field.type == FieldType.Slider and (field.min == nil or field.max == nil) then
        return ('%s MUST set min and max'):format(label)
    end

    if extras.options then
        local options = field.options

        if type(options) ~= 'table' or #options < 1 or #options > MAX_OPTIONS then
            return ('%s options MUST be 1 to %d { value, label } entries'):format(label, MAX_OPTIONS)
        end

        local seen = {}

        for position, option in ipairs(options) do
            local value = type(option) == 'table' and option.value or nil

            if value == nil or not (math.type(value) == 'integer' or isText(value, MAX_LABEL)) or not isText(option.label, MAX_LABEL) or seen[value] then
                return ('%s option %d MUST be { value, label } with a unique string or integer value'):format(label, position)
            end

            seen[value] = true
        end
    end

    if field.default ~= nil then
        local ok, value = checkValue(field, field.default)

        if not ok or value == nil then
            return ('%s default does not pass its own rules'):format(label)
        end
    end

    return nil
end

---@param field UgDialogField
---@return UgDialogField
local function rebuildField(field)
    local options = nil

    if field.options then
        options = {}

        for index, option in ipairs(field.options) do
            options[index] = {
                value = option.value,
                label = option.label,
            }
        end
    end

    return {
        name = field.name,
        type = field.type,
        label = field.label,
        description = field.description,
        placeholder = field.placeholder,
        default = field.default,
        required = field.required,
        disabled = field.disabled,
        icon = field.icon,
        maxLength = field.maxLength,
        rows = field.rows,
        min = field.min,
        max = field.max,
        step = field.step,
        options = options,
    }
end

---Every problem a payload can have, as a plain message. Used on both sides of the export.
---@param payload table
---@return string? problem
local function check(payload)
    if not isValue(Variants, payload.variant) then
        return 'variant MUST be alert, confirm or input'
    end

    if not isText(payload.title, MAX_TITLE) then
        return ('title MUST be UTF-8 text of 1 to %d characters'):format(MAX_TITLE)
    end

    if payload.message ~= nil and not isText(payload.message, MAX_MESSAGE) then
        return ('message MUST be UTF-8 text of 1 to %d characters'):format(MAX_MESSAGE)
    end

    for _, key in ipairs({ 'confirmLabel', 'cancelLabel' }) do
        if payload[key] ~= nil and not isText(payload[key], MAX_LABEL) then
            return ('%s MUST be UTF-8 text of 1 to %d characters'):format(key, MAX_LABEL)
        end
    end

    if payload.icon ~= nil and not isValue(Enums.Icon, payload.icon) then
        return ('icon MUST be a UgLib.Enums.Icon value, got %s'):format(tostring(payload.icon))
    end

    if not isValue(Enums.DialogSize, payload.size) then
        return ('size MUST be a UgLib.Enums.DialogSize value, got %s'):format(tostring(payload.size))
    end

    if payload.color ~= nil and not Utils.IsColor(payload.color) then
        return 'color MUST be a UgLib.Enums.Color value or a #rrggbb hex'
    end

    if payload.destructive ~= nil and type(payload.destructive) ~= 'boolean' then
        return 'destructive MUST be a boolean'
    end

    if payload.variant ~= Variants.Input then
        return payload.fields ~= nil and 'only input dialogs have fields' or nil
    end

    local fields = payload.fields

    if type(fields) ~= 'table' or #fields < 1 or #fields > MAX_FIELDS then
        return ('fields MUST be 1 to %d fields'):format(MAX_FIELDS)
    end

    local names = {}

    for index = 1, #fields do
        local problem = checkFieldShape(fields[index], index)

        if problem then
            return problem
        end

        if names[fields[index].name] then
            return ('field name "%s" is used twice'):format(fields[index].name)
        end

        names[fields[index].name] = true
    end

    return nil
end

---Copies the known top-level fields. Field definitions stay as given until `check` passes, so unknown
---field options are reported, then `rebuildFields` drops everything else.
---@param source table
---@return table
local function rebuild(source)
    local fields = nil

    if type(source.fields) == 'table' then
        fields = table.move(source.fields, 1, #source.fields, 1, {})
    end

    return {
        variant = source.variant,
        title = source.title,
        message = source.message,
        icon = source.icon,
        color = source.color,
        confirmLabel = source.confirmLabel,
        cancelLabel = source.cancelLabel,
        size = source.size,
        destructive = source.destructive,
        fields = fields,
    }
end

---@param payload table checked
---@return table payload with rebuilt field definitions
local function rebuildFields(payload)
    if payload.fields then
        for index, field in ipairs(payload.fields) do
            payload.fields[index] = rebuildField(field)
        end
    end

    return payload
end

---Checks the page's answer for an input dialog. Disabled fields keep their default.
---@param payload table
---@param result any
---@return boolean ok
---@return table? values
local function validateInput(payload, result)
    if type(result) ~= 'table' then
        return false, nil
    end

    local known = {}

    for _, field in ipairs(payload.fields) do
        known[field.name] = true
    end

    for key in pairs(result) do
        if not known[key] then
            return false, nil
        end
    end

    local values = {}

    for _, field in ipairs(payload.fields) do
        local raw = field.disabled and field.default or result[field.name]
        local ok, value = checkValue(field, raw)

        if not ok then
            return false, nil
        end

        local missing = value == nil or (field.type == FieldType.Checkbox and field.required and value ~= true)

        if field.required and missing then
            return false, nil
        end

        values[field.name] = value
    end

    return true, values
end

---@param payload table
---@param result any
---@return boolean ok
---@return any value
local function validate(payload, result)
    if payload.variant == Variants.Alert then
        return result == true, true
    end

    if payload.variant == Variants.Confirm then
        return type(result) == 'boolean', result
    end

    return validateInput(payload, result)
end

---@param name string
---@param options table
---@param variant string
---@return table payload
---@return { timeout?: integer, replace?: boolean } request
local function build(name, options, variant)
    local payload = rebuild(options)

    payload.variant = variant
    payload.size = payload.size or Enums.DialogSize.Medium

    if variant == Variants.Alert and payload.icon == nil then
        payload.icon = Enums.Icon.Info
    elseif variant == Variants.Confirm and payload.icon == nil then
        payload.icon = Enums.Icon.Question
    end

    local problem = check(payload)

    if problem then
        Utils.Raise(3, '%s: %s', name, problem)
    end

    return rebuildFields(payload), {
        timeout = options.timeout,
        replace = options.replace == true,
    }
end

---@param base table<string, true>
---@param extra table<string, true>
---@return table<string, true>
local function merge(base, extra)
    local merged = {}

    for key in pairs(base) do
        merged[key] = true
    end

    for key in pairs(extra) do
        merged[key] = true
    end

    return merged
end

local CONFIRM_OPTIONS = merge(COMMON, CONFIRM)
local INPUT_OPTIONS = merge(COMMON, INPUT)

---Shows a message with one button. MUST run in a thread.
---@param options { title: string, message?: string, icon?: UgIcon, color?: UgLibColorValue, confirmLabel?: string, size?: UgDialogSize, timeout?: integer, replace?: boolean }
---@return boolean acknowledged
---@return UgCloseReason? reason when closed without an answer
function Dialog.Alert(options)
    Utils.CheckOptions('Dialog.Alert', options, COMMON)

    local payload, request = build('Dialog.Alert', options, Variants.Alert)
    local result, reason = Requests.Await('Dialog.Alert', KIND, payload, request)

    return result == true, reason
end

---Asks a yes or no question. MUST run in a thread.
---@param options { title: string, message?: string, icon?: UgIcon, color?: UgLibColorValue, confirmLabel?: string, cancelLabel?: string, destructive?: boolean, size?: UgDialogSize, timeout?: integer, replace?: boolean }
---@return boolean confirmed false for no, for a close and for a timeout
---@return UgCloseReason? reason when closed without an answer
function Dialog.Confirm(options)
    Utils.CheckOptions('Dialog.Confirm', options, CONFIRM_OPTIONS)

    local payload, request = build('Dialog.Confirm', options, Variants.Confirm)
    local result, reason = Requests.Await('Dialog.Confirm', KIND, payload, request)

    return result == true, reason
end

---Asks for values. Returns them by field name, checked against each field. Empty optional fields are absent.
---MUST run in a thread.
---@param options { title: string, message?: string, icon?: UgIcon, color?: UgLibColorValue, confirmLabel?: string, cancelLabel?: string, fields: UgDialogField[], size?: UgDialogSize, timeout?: integer, replace?: boolean }
---@return table<string, any>? values nil when closed without an answer
---@return UgCloseReason? reason
function Dialog.Input(options)
    Utils.CheckOptions('Dialog.Input', options, INPUT_OPTIONS)

    local payload, request = build('Dialog.Input', options, Variants.Input)
    local result, reason = Requests.Await('Dialog.Input', KIND, payload, request)

    if type(result) ~= 'table' then
        return nil, reason or UgLib.Enums.CloseReason.Cancelled
    end

    return result, nil
end

if IS_OWNER then
    UgLib.Internal.Layers.RegisterType(KIND, {
        modal = true,
        focus = UgLib.Internal.Protocol.Nui.Focus.Cursor,
        sanitize = function(payload)
            local clean = rebuild(payload)
            local problem = check(clean)

            if problem then
                error(problem, 0)
            end

            return rebuildFields(clean)
        end,
        validate = validate,
    })

    UgLib.Internal.Demos.Register('dialog', function(args)
        local kind = args[1] or 'confirm'

        if kind == 'alert' then
            print(('[ug-lib] alert %s'):format(tostring(Dialog.Alert({
                title = 'Welcome',
                message = 'Read the **rules** before you play.',
            }))))
        elseif kind == 'input' then
            local values, reason = Dialog.Input({
                title = 'New vehicle',
                size = Enums.DialogSize.Large,
                fields = {
                    {
                        name = 'plate',
                        type = FieldType.Text,
                        label = 'Plate',
                        required = true,
                        maxLength = 8,
                        placeholder = 'ABC 123',
                    },
                    {
                        name = 'notes',
                        type = FieldType.Textarea,
                        label = 'Notes',
                        rows = 3,
                    },
                    {
                        name = 'price',
                        type = FieldType.Number,
                        label = 'Price',
                        min = 0,
                        max = 100000,
                        step = 100,
                        default = 5000,
                    },
                    {
                        name = 'fuel',
                        type = FieldType.Slider,
                        label = 'Fuel',
                        min = 0,
                        max = 100,
                        step = 5,
                        default = 50,
                    },
                    {
                        name = 'color',
                        type = FieldType.Color,
                        label = 'Color',
                        default = '#8b5cf6',
                    },
                    {
                        name = 'class',
                        type = FieldType.Select,
                        label = 'Class',
                        options = {
                            {
                                value = 'sport',
                                label = 'Sport',
                            },
                            {
                                value = 'suv',
                                label = 'SUV',
                            },
                        },
                    },
                    {
                        name = 'extras',
                        type = FieldType.MultiSelect,
                        label = 'Extras',
                        options = {
                            {
                                value = 1,
                                label = 'Spoiler',
                            },
                            {
                                value = 2,
                                label = 'Neon',
                            },
                        },
                    },
                    {
                        name = 'insured',
                        type = FieldType.Checkbox,
                        label = 'Insured',
                    },
                    {
                        name = 'locked',
                        type = FieldType.Toggle,
                        label = 'Locked',
                        default = true,
                    },
                    {
                        name = 'since',
                        type = FieldType.Date,
                        label = 'Registered on',
                    },
                    {
                        name = 'pin',
                        type = FieldType.Password,
                        label = 'PIN',
                        maxLength = 4,
                    },
                },
            })

            print(('[ug-lib] input %s, reason %s'):format(values and json.encode(values) or 'nil', tostring(reason)))
        else
            local confirmed, reason = Dialog.Confirm({
                title = 'Sell the car?',
                message = 'You get **$12,000**.',
                destructive = true,
                confirmLabel = 'Sell',
            })

            print(('[ug-lib] confirm %s, reason %s'):format(tostring(confirmed), tostring(reason)))
        end
    end)
end
