--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Context menus: a list the player clicks, with submenus and a back button. Registered menus stay in the
---calling resource with their callbacks and `args`. The page only receives what it shows, and answers with
---an item index that Lua checks.
---@class UgLib.Context
local Context = {}
UgLib.Context = Context

local Utils = UgLib.Internal.Utils
local Logger = UgLib.Internal.Logger
local Config = UgLib.Internal.Config
local Enums = UgLib.Enums
local Requests = UgLib.Internal.Requests

local KIND = UgLib.Internal.Protocol.Nui.Types.Context
local IS_OWNER = GetCurrentResourceName() == 'ug-lib'
local DEFINITION = {
    id = true,
    title = true,
    items = true,
    menu = true,
    onBack = true,
    onClose = true,
    canClose = true,
    position = true,
    color = true,
    fixed = true,
}
local INLINE = {
    title = true,
    items = true,
    canClose = true,
    timeout = true,
    position = true,
    color = true,
    fixed = true,
}
local ITEM = {
    title = true, description = true, icon = true, iconColor = true, image = true, disabled = true, readOnly = true,
    progress = true, colorScheme = true, arrow = true, metadata = true, menu = true, onSelect = true, args = true,
}
local ID_PATTERN = '^[%w_%-%.:]+$'
local MAX_ID = 64
local MAX_ITEMS = 50
local MAX_TITLE = 128
local MAX_DESCRIPTION = 512
local MAX_METADATA = 10
local MAX_IMAGE = 512
-- The page answers 0 for the back button.
local BACK = 0

---@class UgContextItem
---@field title string
---@field description? string
---@field icon? UgIcon
---@field iconColor? UgLibColorValue
---@field image? string `nui://` or `https://` URL
---@field disabled? boolean
---@field readOnly? boolean
---@field progress? number 0 to 100
---@field colorScheme? UgLibColorValue progress bar color
---@field arrow? boolean defaults to true for items with `menu`
---@field metadata? { label: string, value: string|number }[] shown on hover
---@field menu? string id of a registered context to open
---@field onSelect? fun(args: any)
---@field args? any

---@class UgContextDefinition
---@field id string
---@field title string
---@field items UgContextItem[]
---@field menu? string parent context, shows a back button
---@field position? UgPosition defaults to `settings.contextPosition`
---@field color? UgLibColorValue
---@field fixed? boolean keeps `position` and `style` when the player chose others
---@field onBack? fun()
---@field onClose? fun()
---@field canClose? boolean defaults to true

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

---@param item table shown fields only
---@param index integer
---@return string? problem
local function checkShownItem(item, index)
    local label = ('item %d'):format(index)

    if not isText(item.title, MAX_TITLE) then
        return ('%s title MUST be UTF-8 text of 1 to %d characters'):format(label, MAX_TITLE)
    end

    if item.description ~= nil and not isText(item.description, MAX_DESCRIPTION) then
        return ('%s description MUST be UTF-8 text of 1 to %d characters'):format(label, MAX_DESCRIPTION)
    end

    if item.icon ~= nil and not isValue(Enums.Icon, item.icon) then
        return ('%s icon MUST be a UgLib.Enums.Icon value'):format(label)
    end

    for _, key in ipairs({ 'iconColor', 'colorScheme' }) do
        if item[key] ~= nil and not Utils.IsColor(item[key]) then
            return ('%s %s MUST be a UgLib.Enums.Color value or a #rrggbb hex'):format(label, key)
        end
    end

    if item.image ~= nil and (type(item.image) ~= 'string' or #item.image > MAX_IMAGE
        or not (item.image:find('^nui://') or item.image:find('^https://'))) then
        return ('%s image MUST be a nui:// or https:// URL of at most %d bytes'):format(label, MAX_IMAGE)
    end

    for _, key in ipairs({ 'disabled', 'readOnly', 'arrow', 'submenu' }) do
        if item[key] ~= nil and type(item[key]) ~= 'boolean' then
            return ('%s %s MUST be a boolean'):format(label, key)
        end
    end

    if item.progress ~= nil and (type(item.progress) ~= 'number' or item.progress ~= item.progress or item.progress < 0 or item.progress > 100) then
        return ('%s progress MUST be a number from 0 to 100'):format(label)
    end

    local metadata = item.metadata

    if metadata ~= nil then
        if type(metadata) ~= 'table' or #metadata > MAX_METADATA then
            return ('%s metadata MUST be at most %d { label, value } entries'):format(label, MAX_METADATA)
        end

        for _, entry in ipairs(metadata) do
            if type(entry) ~= 'table' or not isText(entry.label, 64) or not (isText(entry.value, MAX_TITLE) or type(entry.value) == 'number') then
                return ('%s metadata entries MUST be { label, value } with short text or a number'):format(label)
            end
        end
    end

    return nil
end

---@param payload table
---@return string? problem
local function check(payload)
    if not isText(payload.title, MAX_TITLE) then
        return ('title MUST be UTF-8 text of 1 to %d characters'):format(MAX_TITLE)
    end

    if type(payload.items) ~= 'table' or #payload.items < 1 or #payload.items > MAX_ITEMS then
        return ('items MUST be 1 to %d items'):format(MAX_ITEMS)
    end

    for index, item in ipairs(payload.items) do
        ---@type string?
        local problem = ('item %d MUST be a table'):format(index)

        if type(item) == 'table' then
            problem = checkShownItem(item, index)
        end

        if problem then
            return problem
        end
    end

    if type(payload.canBack) ~= 'boolean' or type(payload.canClose) ~= 'boolean' then
        return 'canBack and canClose MUST be booleans'
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

---@param item table
---@return table
local function shownItem(item)
    local metadata = nil

    if type(item.metadata) == 'table' then
        metadata = {}

        for index, entry in ipairs(item.metadata) do
            metadata[index] = type(entry) == 'table' and {
                label = entry.label,
                value = entry.value,
            } or entry
        end
    end

    local submenu = item.submenu

    if submenu == nil then
        submenu = item.menu ~= nil
    end

    local arrow = item.arrow

    if arrow == nil then
        arrow = submenu
    end

    return {
        title = item.title,
        description = item.description,
        icon = item.icon,
        iconColor = item.iconColor,
        image = item.image,
        disabled = item.disabled,
        readOnly = item.readOnly,
        progress = item.progress,
        colorScheme = item.colorScheme,
        arrow = arrow,
        metadata = metadata,
        submenu = submenu,
    }
end

---@param source table
---@return table
local function rebuild(source)
    local items = nil

    if type(source.items) == 'table' then
        items = {}

        for index, item in ipairs(source.items) do
            items[index] = type(item) == 'table' and shownItem(item) or item
        end
    end

    return {
        title = source.title,
        items = items,
        canBack = source.canBack,
        canClose = source.canClose,
        position = source.position,
        color = source.color,
        fixed = source.fixed,
    }
end

---The page answers an item index, or 0 for back. Disabled and read-only items cannot be chosen.
---@param payload table
---@param result any
---@return boolean ok
---@return integer? index
local function validate(payload, result)
    local index = type(result) == 'number' and math.tointeger(result) or nil

    if index == BACK then
        return payload.canBack, BACK
    end

    local item = index and payload.items[index]

    if not item or item.disabled or item.readOnly then
        return false, nil
    end

    return true, index
end

---@param name string
---@param items any
---@param inline boolean
local function checkItems(name, items, inline)
    if type(items) ~= 'table' then
        Utils.Raise(3, '%s: items MUST be 1 to %d items', name, MAX_ITEMS)
    end

    for index, item in ipairs(items) do
        if type(item) ~= 'table' then
            Utils.Raise(3, '%s: item %d MUST be a table', name, index)
        end

        for key in pairs(item) do
            if not ITEM[key] then
                local names = {}

                for known in pairs(ITEM) do
                    names[#names + 1] = known
                end

                local suggestion = type(key) == 'string' and UgLib.String.Suggest(key, names) or nil

                Utils.Raise(3, '%s: item %d has an unknown option "%s".%s', name, index, tostring(key), suggestion and (' Did you mean "%s"?'):format(suggestion) or '')
            end
        end

        if inline and (item.onSelect ~= nil or item.menu ~= nil) then
            Utils.Raise(3, '%s: item %d of an inline context MUST NOT have onSelect or menu. Register the context instead.', name, index)
        end

        if item.onSelect ~= nil and type(item.onSelect) ~= 'function' then
            Utils.Raise(3, '%s: item %d onSelect MUST be a function', name, index)
        end

        if item.menu ~= nil and type(item.menu) ~= 'string' then
            Utils.Raise(3, '%s: item %d menu MUST be a context id', name, index)
        end
    end
end

---@type table<string, UgContextDefinition>
local registered = {}

---@type { id: string, layer: string }?
local current = nil

---@param definition UgContextDefinition
---@return table payload
local function payloadOf(definition)
    return rebuild({
        title = definition.title,
        items = definition.items,
        canBack = definition.menu ~= nil,
        canClose = definition.canClose ~= false,
        position = definition.position or Config.Get('settings', 'contextPosition') or Enums.Position.CenterRight,
        color = definition.color,
        fixed = definition.fixed,
    })
end

---@param callback fun(...)?
---@param ... any
local function call(callback, ...)
    if callback then
        local ok, err = pcall(callback, ...)

        if not ok then
            Logger.Error('Context callback failed: %s', tostring(err))
        end
    end
end

local openRegistered

---@param definition UgContextDefinition
openRegistered = function(definition)
    local layer = nil

    layer = Requests.Start(KIND, payloadOf(definition), {
        onClose = function(result, reason)
            if current and current.layer == layer then
                current = nil
            end

            if result == BACK and reason == nil then
                call(definition.onBack)

                local parent = definition.menu and registered[definition.menu]

                if parent then
                    openRegistered(parent)
                end

                return
            end

            local item = type(result) == 'number' and definition.items[result] or nil

            if not item then
                call(definition.onClose)

                return
            end

            if item.menu then
                local child = registered[item.menu]

                if child then
                    openRegistered(child)
                else
                    Logger.Warn('Context "%s" opens "%s", which is not registered.', definition.id, item.menu)
                end
            end

            call(item.onSelect, item.args)
        end,
    }, {
        replace = current ~= nil,
    })

    if layer then
        current = {
            id = definition.id,
            layer = layer,
        }
    end
end

---Registers a context for `Context.Open(id)`. Registering an id again replaces it.
---@param definition UgContextDefinition
function Context.Register(definition)
    Utils.CheckOptions('Context.Register', definition, DEFINITION)

    if type(definition.id) ~= 'string' or #definition.id > MAX_ID or not definition.id:find(ID_PATTERN) then
        Utils.Raise(2, 'Context.Register: id MUST be 1 to %d letters, digits, or _ - . :', MAX_ID)
    end

    checkItems('Context.Register', definition.items, false)

    for _, key in ipairs({ 'onBack', 'onClose' }) do
        if definition[key] ~= nil and type(definition[key]) ~= 'function' then
            Utils.Raise(2, 'Context.Register: %s MUST be a function', key)
        end
    end

    local problem = check(payloadOf(definition))

    if problem then
        Utils.Raise(2, 'Context.Register: %s', problem)
    end

    registered[definition.id] = definition
end

---Opens a registered context and returns at once: callbacks run in this resource. It replaces the calling
---resource's open context, and is not shown when another resource has a modal open.
---With an inline `{ title, items, canClose?, timeout? }`, waits instead and returns the chosen item.
---Inline items MUST NOT have `onSelect` or `menu`. The inline form MUST run in a thread.
---@param idOrOptions string|{ title: string, items: UgContextItem[], canClose?: boolean, timeout?: integer, position?: UgPosition, color?: UgLibColorValue, fixed?: boolean }
---@return integer? index the chosen item, inline form only
---@return any args the `args` of the chosen item, inline form only
---@return UgCloseReason? reason when closed without a choice, inline form only
function Context.Open(idOrOptions)
    if type(idOrOptions) == 'string' then
        local definition = registered[idOrOptions]

        if not definition then
            Utils.Raise(2, 'Context.Open: "%s" is not registered', idOrOptions)
        end

        openRegistered(definition)

        return nil, nil, nil
    end

    Utils.CheckOptions('Context.Open', idOrOptions, INLINE)
    checkItems('Context.Open', idOrOptions.items, true)

    local payload = rebuild({
        title = idOrOptions.title,
        items = idOrOptions.items,
        canBack = false,
        canClose = idOrOptions.canClose ~= false,
        position = idOrOptions.position or Config.Get('settings', 'contextPosition') or Enums.Position.CenterRight,
        color = idOrOptions.color,
        fixed = idOrOptions.fixed,
    })
    local problem = check(payload)

    if problem then
        Utils.Raise(2, 'Context.Open: %s', problem)
    end

    local index, reason = Requests.Await('Context.Open', KIND, payload, {
        timeout = idOrOptions.timeout,
        replace = current ~= nil,
        onOpen = function(layer)
            current = {
                id = '',
                layer = layer,
            }
        end,
    })

    current = nil

    if type(index) ~= 'number' or index == BACK then
        return nil, nil, reason or Enums.CloseReason.Cancelled
    end

    return index, idOrOptions.items[index].args, nil
end

---Closes the calling resource's open context.
---@return boolean closed
function Context.Close()
    return current ~= nil and Requests.Close(current.layer)
end

---@return string? id the registered id of the open context, `''` for an inline one, nil when none is open
function Context.GetOpen()
    return current and current.id or nil
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

            return clean
        end,
        validate = validate,
    })

    UgLib.Internal.Demos.Register('context', function()
        Context.Register({
            id = 'ug-lib:demo:garage',
            title = 'Garage',
            items = {
                { title = 'Sultan RS', description = 'Plate **UG 001**', icon = Enums.Icon.Star, progress = 80, colorScheme = Enums.Color.Success,
                  metadata = {
                      {
                          label = 'Fuel',
                          value = '80%',
                      },
                      {
                          label = 'Engine',
                          value = 950,
                      },
                  }, args = 'sultan',
                  onSelect = function(args) print('[ug-lib] context selected ' .. tostring(args)) end },
                {
                    title = 'Impounded',
                    description = 'Pay to release',
                    icon = Enums.Icon.Lock,
                    disabled = true,
                },
                {
                    title = 'Settings',
                    icon = Enums.Icon.Settings,
                    menu = 'ug-lib:demo:settings',
                },
            },
        })

        Context.Register({
            id = 'ug-lib:demo:settings',
            title = 'Garage settings',
            menu = 'ug-lib:demo:garage',
            items = {
                {
                    title = 'Rename',
                    icon = Enums.Icon.Edit,
                    onSelect = function() print('[ug-lib] context rename') end,
                },
                {
                    title = 'Info',
                    description = 'Read only',
                    readOnly = true,
                },
            },
        })

        Context.Open('ug-lib:demo:garage')
    end)
end
