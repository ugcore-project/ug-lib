--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Keyboard menus: a list the player moves through with keys while the game stays playable. ug-lib owns the
---keys (`settings.menuKeys`, rebindable) and the selection, and sends each step to the resource that opened
---the menu, where callbacks and `args` stay. One menu at a time: a new one replaces the open one.
---@class UgLib.Menu
local Menu = {}
UgLib.Menu = Menu

local Utils = UgLib.Internal.Utils
local Logger = UgLib.Internal.Logger
local Config = UgLib.Internal.Config
local Enums = UgLib.Enums
local Requests = UgLib.Internal.Requests

local KIND = UgLib.Internal.Protocol.Nui.Types.Menu
local IS_OWNER = GetCurrentResourceName() == 'ug-lib'
local DEFINITION = {
    id = true, title = true, position = true, color = true, fixed = true, items = true, onSelect = true, onSelected = true, onSideScroll = true,
    onCheck = true, onClose = true, canClose = true, disableInput = true,
}
local ITEM = {
    label = true, description = true, icon = true, iconColor = true, values = true, defaultIndex = true, checked = true,
    progress = true, close = true, args = true,
}
local SET_ITEM = {
    label = true,
    description = true,
    icon = true,
    iconColor = true,
    values = true,
    checked = true,
    progress = true,
}
local ID_PATTERN = '^[%w_%-%.:]+$'
local MAX_ID = 64
local MAX_ITEMS = 100
local MAX_VALUES = 50
local MAX_LABEL = 128
local MAX_DESCRIPTION = 512

---Steps sent by ug-lib to the menu's resource.
local Actions = {
    Move = 'move',
    Scroll = 'scroll',
    Check = 'check',
    Select = 'select',
}

---@class UgMenuItem
---@field label string
---@field description? string
---@field icon? UgIcon
---@field iconColor? UgLibColorValue
---@field values? string[] side-scroll values, moved with left and right
---@field defaultIndex? integer starting value index
---@field checked? boolean makes the item a checkbox
---@field progress? number 0 to 100
---@field close? boolean selecting closes the menu, defaults to true
---@field args? any

---@class UgMenuDefinition
---@field id string
---@field title string
---@field position? UgPosition
---@field color? UgLibColorValue
---@field fixed? boolean keeps `position` and `style` when the player chose others
---@field items UgMenuItem[]
---@field onSelect? fun(index: integer, scrollIndex: integer?, args: any) the select key on an item without `checked`
---@field onSelected? fun(index: integer, scrollIndex: integer?, args: any) the selection moved
---@field onSideScroll? fun(index: integer, scrollIndex: integer, args: any)
---@field onCheck? fun(index: integer, checked: boolean, args: any)
---@field onClose? fun() closed without a closing selection
---@field canClose? boolean the back key closes, defaults to true
---@field disableInput? boolean blocks movement while open

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

---@param item table
---@param index integer
---@return string? problem
local function checkItem(item, index)
    local label = ('item %d'):format(index)

    if not isText(item.label, MAX_LABEL) then
        return ('%s label MUST be UTF-8 text of 1 to %d characters'):format(label, MAX_LABEL)
    end

    if item.description ~= nil and not isText(item.description, MAX_DESCRIPTION) then
        return ('%s description MUST be UTF-8 text of 1 to %d characters'):format(label, MAX_DESCRIPTION)
    end

    if item.icon ~= nil and not isValue(Enums.Icon, item.icon) then
        return ('%s icon MUST be a UgLib.Enums.Icon value'):format(label)
    end

    if item.iconColor ~= nil and not Utils.IsColor(item.iconColor) then
        return ('%s iconColor MUST be a UgLib.Enums.Color value or a #rrggbb hex'):format(label)
    end

    if item.values ~= nil then
        if type(item.values) ~= 'table' or #item.values < 1 or #item.values > MAX_VALUES then
            return ('%s values MUST be 1 to %d labels'):format(label, MAX_VALUES)
        end

        for _, value in ipairs(item.values) do
            if not isText(value, MAX_LABEL) then
                return ('%s values MUST be text of 1 to %d characters'):format(label, MAX_LABEL)
            end
        end
    end

    if item.defaultIndex ~= nil and (math.type(item.defaultIndex) ~= 'integer' or not item.values or item.defaultIndex < 1 or item.defaultIndex > #item.values) then
        return ('%s defaultIndex MUST be an index of values'):format(label)
    end

    for _, key in ipairs({ 'checked', 'close' }) do
        if item[key] ~= nil and type(item[key]) ~= 'boolean' then
            return ('%s %s MUST be a boolean'):format(label, key)
        end
    end

    if item.checked ~= nil and item.values ~= nil then
        return ('%s cannot have both checked and values'):format(label)
    end

    if item.progress ~= nil and (type(item.progress) ~= 'number' or item.progress ~= item.progress or item.progress < 0 or item.progress > 100) then
        return ('%s progress MUST be a number from 0 to 100'):format(label)
    end

    return nil
end

---@class UgMenuState
---@field selected integer
---@field scroll integer[] value index per item, 0 for items without values
---@field checked boolean[] per item, false for items that are not checkboxes

---@param payload table
---@return string? problem
local function check(payload)
    if not isText(payload.title, MAX_LABEL) then
        return ('title MUST be UTF-8 text of 1 to %d characters'):format(MAX_LABEL)
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

    if type(payload.items) ~= 'table' or #payload.items < 1 or #payload.items > MAX_ITEMS then
        return ('items MUST be 1 to %d items'):format(MAX_ITEMS)
    end

    for index, item in ipairs(payload.items) do
        ---@type string?
        local problem = ('item %d MUST be a table'):format(index)

        if type(item) == 'table' then
            problem = checkItem(item, index)
        end

        if problem then
            return problem
        end
    end

    if type(payload.canClose) ~= 'boolean' or type(payload.disableInput) ~= 'boolean' then
        return 'canClose and disableInput MUST be booleans'
    end

    local state = payload.state

    if type(state) ~= 'table' or math.type(state.selected) ~= 'integer' or state.selected < 1 or state.selected > #payload.items
        or type(state.scroll) ~= 'table' or type(state.checked) ~= 'table' then
        return 'state MUST be { selected, scroll, checked } with a valid selection'
    end

    return nil
end

---@param item table
---@return table
local function shownItem(item)
    return {
        label = item.label,
        description = item.description,
        icon = item.icon,
        iconColor = item.iconColor,
        values = type(item.values) == 'table' and table.move(item.values, 1, #item.values, 1, {}) or item.values,
        defaultIndex = item.defaultIndex,
        checked = item.checked,
        progress = item.progress,
        close = item.close,
    }
end

---@param items table
---@param source table?
---@return UgMenuState
local function stateOf(items, source)
    local state = {
        selected = 1,
        scroll = {},
        checked = {},
    }

    if type(source) == 'table' and math.type(source.selected) == 'integer' then
        state.selected = source.selected
    end

    -- Dense arrays: sparse tables do not encode to JSON reliably.
    for index, item in ipairs(items) do
        state.scroll[index] = 0
        state.checked[index] = false

        if type(item) == 'table' and type(item.values) == 'table' then
            local wanted = type(source) == 'table' and type(source.scroll) == 'table' and math.tointeger(source.scroll[index]) or nil

            if wanted and wanted >= 1 and wanted <= #item.values then
                state.scroll[index] = wanted
            else
                state.scroll[index] = item.defaultIndex or 1
            end
        end

        if type(item) == 'table' and type(item.checked) == 'boolean' then
            local wanted = type(source) == 'table' and type(source.checked) == 'table' and source.checked[index] or nil

            if type(wanted) == 'boolean' then
                state.checked[index] = wanted
            else
                state.checked[index] = item.checked
            end
        end
    end

    return state
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
        position = source.position,
        color = source.color,
        fixed = source.fixed,
        items = items,
        canClose = source.canClose,
        disableInput = source.disableInput,
        state = items and stateOf(items, source.state) or source.state,
    }
end

---@type table<string, UgMenuDefinition>
local registered = {}

---@type { id: string, layer: string }?
local current = nil

---@param callback fun(...)?
---@param ... any
local function call(callback, ...)
    if callback then
        local ok, err = pcall(callback, ...)

        if not ok then
            Logger.Error('Menu callback failed: %s', tostring(err))
        end
    end
end

---@param definition UgMenuDefinition
---@param startIndex integer
---@return table
local function payloadOf(definition, startIndex)
    return rebuild({
        title = definition.title,
        position = definition.position or Config.Get('settings', 'menuPosition') or Enums.Position.TopLeft,
        color = definition.color,
        fixed = definition.fixed,
        items = definition.items,
        canClose = definition.canClose ~= false,
        disableInput = definition.disableInput == true,
        state = {
            selected = startIndex,
        },
    })
end

---@param definition UgMenuDefinition
---@param data any
local function onStep(definition, data)
    if type(data) ~= 'table' then
        return
    end

    local index = data.index
    local item = math.type(index) == 'integer' and definition.items[index]

    if not item then
        return
    end

    -- 0 means the item has no values.
    local scrollIndex = data.scrollIndex ~= 0 and data.scrollIndex or nil

    if data.action == Actions.Move then
        call(definition.onSelected, index, scrollIndex, item.args)
    elseif data.action == Actions.Scroll then
        call(definition.onSideScroll, index, scrollIndex, item.args)
    elseif data.action == Actions.Check then
        item.checked = data.checked == true
        call(definition.onCheck, index, item.checked, item.args)
    elseif data.action == Actions.Select then
        call(definition.onSelect, index, scrollIndex, item.args)
    end
end

---Registers a menu for `Menu.Open(id)`. Registering an id again replaces it.
---@param definition UgMenuDefinition
function Menu.Register(definition)
    Utils.CheckOptions('Menu.Register', definition, DEFINITION)

    if type(definition.id) ~= 'string' or #definition.id > MAX_ID or not definition.id:find(ID_PATTERN) then
        Utils.Raise(2, 'Menu.Register: id MUST be 1 to %d letters, digits, or _ - . :', MAX_ID)
    end

    if type(definition.items) == 'table' then
        for index, item in ipairs(definition.items) do
            if type(item) == 'table' then
                for key in pairs(item) do
                    if not ITEM[key] then
                        local names = {}

                        for known in pairs(ITEM) do
                            names[#names + 1] = known
                        end

                        local suggestion = type(key) == 'string' and UgLib.String.Suggest(key, names) or nil

                        Utils.Raise(2, 'Menu.Register: item %d has an unknown option "%s".%s', index, tostring(key), suggestion and (' Did you mean "%s"?'):format(suggestion) or '')
                    end
                end
            end
        end
    end

    for _, key in ipairs({ 'onSelect', 'onSelected', 'onSideScroll', 'onCheck', 'onClose' }) do
        if definition[key] ~= nil and type(definition[key]) ~= 'function' then
            Utils.Raise(2, 'Menu.Register: %s MUST be a function', key)
        end
    end

    local problem = check(payloadOf(definition, 1))

    if problem then
        Utils.Raise(2, 'Menu.Register: %s', problem)
    end

    registered[definition.id] = definition
end

---Opens a registered menu and returns at once. It replaces any open menu.
---@param id string
---@param startIndex? integer the selected item, defaults to 1
function Menu.Open(id, startIndex)
    local definition = registered[id]

    if not definition then
        Utils.Raise(2, 'Menu.Open: "%s" is not registered', tostring(id))
    end

    ---@cast definition -nil

    startIndex = startIndex or 1

    if math.type(startIndex) ~= 'integer' or startIndex < 1 or startIndex > #definition.items then
        Utils.Raise(2, 'Menu.Open: startIndex MUST be an item index')
    end

    local layer = nil

    layer = Requests.Start(KIND, payloadOf(definition, startIndex), {
        onEvent = function(data)
            onStep(definition, data)
        end,
        onClose = function(result, reason)
            if current and current.layer == layer then
                current = nil
            end

            if reason == nil and type(result) == 'table' then
                onStep(definition, {
                    action = Actions.Select,
                    index = result.index,
                    scrollIndex = result.scrollIndex,
                })
            else
                call(definition.onClose)
            end
        end,
    })

    if layer then
        current = {
            id = id,
            layer = layer,
        }
    end
end

---Closes the calling resource's open menu. `onClose` runs.
---@return boolean closed
function Menu.Close()
    return current ~= nil and Requests.Close(current.layer)
end

---@return string? id of the calling resource's open menu
function Menu.GetOpen()
    return current and current.id or nil
end

---Changes an item of a registered menu. An open menu updates in place and keeps its selection.
---@param id string
---@param index integer
---@param fields { label?: string, description?: string, icon?: UgIcon, values?: string[], checked?: boolean, progress?: number }
function Menu.SetItem(id, index, fields)
    local definition = registered[id]

    if not definition then
        Utils.Raise(2, 'Menu.SetItem: "%s" is not registered', tostring(id))
    end

    ---@cast definition -nil

    local item = math.type(index) == 'integer' and definition.items[index]

    if not item then
        Utils.Raise(2, 'Menu.SetItem: %s is not an item index of "%s"', tostring(index), id)
    end

    ---@cast item UgMenuItem

    Utils.CheckOptions('Menu.SetItem', fields, SET_ITEM)

    local updated = {}

    for key, value in pairs(item) do
        updated[key] = value
    end

    for key, value in pairs(fields) do
        updated[key] = value
    end

    local problem = checkItem(updated, index)

    if problem then
        Utils.Raise(2, 'Menu.SetItem: %s', problem)
    end

    for key, value in pairs(fields) do
        item[key] = value
    end

    if current and current.id == id then
        Requests.Update(current.layer, payloadOf(definition, 1))
    end
end

if IS_OWNER then
    local Layers = UgLib.Internal.Layers
    local Nui = UgLib.Internal.Nui
    local NuiActions = UgLib.Internal.Protocol.Nui.Actions
    local Controls = UgLib.Internal.Controls

    local SOUND_SET = 'HUD_FRONTEND_DEFAULT_SOUNDSET'

    Layers.RegisterType(KIND, {
        modal = false,
        sanitize = function(payload)
            local clean = rebuild(payload)
            local problem = check(clean)

            if problem then
                error(problem, 0)
            end

            return clean
        end,
        -- An update keeps the player's selection and choices where the items still allow them.
        onUpdate = function(old, new)
            new.state = stateOf(new.items, old.state)
            new.state.selected = math.min(old.state.selected, #new.items)

            -- A checkbox changed by the resource wins over the player's last toggle.
            for index, item in ipairs(new.items) do
                local before = old.items[index]

                if item.checked ~= nil and before and before.checked ~= item.checked then
                    new.state.checked[index] = item.checked
                end
            end

            return new
        end,
        limit = {
            max = function()
                return 1
            end,
            group = function()
                return KIND
            end,
        },
        -- The page has no focus on a menu: ug-lib owns the keys. A forged final answer MUST name a real item.
        validate = function(payload, result)
            local index = type(result) == 'table' and math.tointeger(result.index) or nil

            if not index or not payload.items[index] or payload.items[index].checked ~= nil then
                return false, nil
            end

            local scrollIndex = payload.state.scroll[index]

            return true, {
                index = index,
                scrollIndex = scrollIndex ~= 0 and scrollIndex or nil,
            }
        end,
        validateEvent = function()
            return false, nil
        end,
    })

    ---@param name string
    local function sound(name)
        if Config.Get('settings', 'sounds') ~= false then
            PlaySoundFrontend(-1, name, SOUND_SET, true)
        end
    end

    ---@return UgLibLayer?
    local function openMenu()
        for _, layer in ipairs(Layers.GetAll()) do
            if layer.kind == KIND then
                return layer
            end
        end

        return nil
    end

    ---@param layer UgLibLayer
    local function push(layer)
        Nui.Send(KIND, NuiActions.Update, layer.key, layer.payload)
    end

    ---@param delta integer
    local function move(delta)
        local layer = openMenu()

        if not layer then
            return
        end

        local state = layer.payload.state
        local count = #layer.payload.items

        state.selected = (state.selected - 1 + delta) % count + 1
        push(layer)
        sound('NAV_UP_DOWN')
        Layers.Emit(layer.owner, layer.id, {
            action = Actions.Move,
            index = state.selected,
            scrollIndex = state.scroll[state.selected],
        })
    end

    ---@param delta integer
    local function scroll(delta)
        local layer = openMenu()

        if not layer then
            return
        end

        local state = layer.payload.state
        local index = state.selected
        local item = layer.payload.items[index]

        if not item or not item.values then
            return
        end

        state.scroll[index] = (state.scroll[index] - 1 + delta) % #item.values + 1
        push(layer)
        sound('NAV_LEFT_RIGHT')
        Layers.Emit(layer.owner, layer.id, {
            action = Actions.Scroll,
            index = index,
            scrollIndex = state.scroll[index],
        })
    end

    local function select()
        local layer = openMenu()

        if not layer then
            return
        end

        local state = layer.payload.state
        local index = state.selected
        local item = layer.payload.items[index]

        sound('SELECT')

        if item.checked ~= nil then
            state.checked[index] = not state.checked[index]
            push(layer)
            Layers.Emit(layer.owner, layer.id, {
                action = Actions.Check,
                index = index,
                checked = state.checked[index],
            })

            return
        end

        if item.close == false then
            Layers.Emit(layer.owner, layer.id, {
                action = Actions.Select,
                index = index,
                scrollIndex = state.scroll[index],
            })

            return
        end

        Layers.Resolve(layer.owner, layer.id, {
            index = index,
        })
    end

    local function back()
        local layer = openMenu()

        if layer and layer.payload.canClose then
            sound('BACK')
            Layers.Close(layer.owner, layer.id, Enums.CloseReason.Cancelled)
        end
    end

    local keys = Config.Get('settings', 'menuKeys') or {}
    local bindings = {
        {
            name = 'menu_up',
            label = 'Menu: up',
            key = keys.up or 'UP',
            handler = function() move(-1) end,
        },
        {
            name = 'menu_down',
            label = 'Menu: down',
            key = keys.down or 'DOWN',
            handler = function() move(1) end,
        },
        {
            name = 'menu_left',
            label = 'Menu: previous value',
            key = keys.left or 'LEFT',
            handler = function() scroll(-1) end,
        },
        {
            name = 'menu_right',
            label = 'Menu: next value',
            key = keys.right or 'RIGHT',
            handler = function() scroll(1) end,
        },
        {
            name = 'menu_select',
            label = 'Menu: select',
            key = keys.select or 'RETURN',
            handler = select,
        },
        {
            name = 'menu_back',
            label = 'Menu: back',
            key = keys.back or 'BACK',
            handler = back,
        },
    }

    for _, binding in ipairs(bindings) do
        UgLib.Keybind.Register({
            name = binding.name,
            label = binding.label,
            defaultKey = binding.key,
            onPressed = binding.handler,
        })
    end

    -- Blocks movement while a menu with `disableInput` is open. Idle checks are cheap and rare.
    CreateThread(function()
        while true do
            local layer = openMenu()

            if layer and layer.payload.disableInput then
                Controls.Disable(Controls.Move)
                Controls.Disable(Controls.Combat)
                Wait(0)
            else
                Wait(250)
            end
        end
    end)

    UgLib.Internal.Demos.Register('menu', function()
        Menu.Register({
            id = 'ug-lib:demo:menu',
            title = 'Vehicle',
            items = {
                {
                    label = 'Engine',
                    description = 'Turn the engine on or off',
                    checked = true,
                    icon = Enums.Icon.Settings,
                },
                {
                    label = 'Seat',
                    values = { 'Driver', 'Passenger', 'Rear left', 'Rear right' },
                },
                {
                    label = 'Livery',
                    values = { 'Stock', 'Police', 'Taxi' },
                    defaultIndex = 2,
                    close = false,
                },
                {
                    label = 'Fuel',
                    progress = 65,
                },
                {
                    label = 'Lock and leave',
                    icon = Enums.Icon.Lock,
                },
            },
            onSelect = function(index, scrollIndex)
                print(('[ug-lib] menu select %d %s'):format(index, tostring(scrollIndex)))
            end,
            onCheck = function(index, checked)
                print(('[ug-lib] menu check %d %s'):format(index, tostring(checked)))
            end,
            onClose = function()
                print('[ug-lib] menu closed')
            end,
        })

        Menu.Open('ug-lib:demo:menu')
    end)
end
