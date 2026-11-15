--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Radial menus. `Radial.Open` shows a one-off radial and waits. The global radial opens with
---`settings.radialKey` and shows the items every resource added with `Radial.AddItem`; a choice runs the
---`onSelect` of the resource that added the item. The page answers a path of indexes that Lua checks.
---@class UgLib.Radial
local Radial = {}
UgLib.Radial = Radial

local Utils = UgLib.Internal.Utils
local Logger = UgLib.Internal.Logger
local Enums = UgLib.Enums
local Requests = UgLib.Internal.Requests
local Protocol = UgLib.Internal.Protocol

local LIB = 'ug-lib'
local KIND = Protocol.Nui.Types.Radial
local RESOURCE = GetCurrentResourceName()
local IS_OWNER = RESOURCE == LIB
local OPEN_OPTIONS = {
    items = true,
    title = true,
    timeout = true,
    color = true,
}
local ITEM = {
    id = true,
    label = true,
    icon = true,
    iconColor = true,
    disabled = true,
    items = true,
    onSelect = true,
}
local ID_PATTERN = '^[%w_%-%.:]+$'
local MAX_ID = 64
local MAX_LABEL = 64
local MAX_ITEMS = 50
local MAX_DEPTH = 3

---@class UgRadialItem
---@field id string unique in the tree of the calling resource
---@field label string
---@field icon? UgIcon
---@field iconColor? UgLibColorValue
---@field disabled? boolean
---@field items? UgRadialItem[] a submenu
---@field onSelect? fun(id: string) global radial leaves only

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

---Checks a shown tree: labels, icons, flags, size and depth.
---@param items any
---@param depth integer
---@return string? problem
local function checkShown(items, depth)
    if depth > MAX_DEPTH then
        return ('submenus MUST NOT be deeper than %d levels'):format(MAX_DEPTH)
    end

    if type(items) ~= 'table' or #items < 1 or #items > MAX_ITEMS then
        return ('a ring MUST have 1 to %d items'):format(MAX_ITEMS)
    end

    for index, item in ipairs(items) do
        if type(item) ~= 'table' or not isText(item.label, MAX_LABEL) then
            return ('item %d label MUST be UTF-8 text of 1 to %d characters'):format(index, MAX_LABEL)
        end

        if item.icon ~= nil and not isValue(Enums.Icon, item.icon) then
            return ('item %d icon MUST be a UgLib.Enums.Icon value'):format(index)
        end

        if item.iconColor ~= nil and not Utils.IsColor(item.iconColor) then
            return ('item %d iconColor MUST be a UgLib.Enums.Color value or a #rrggbb hex'):format(index)
        end

        if item.disabled ~= nil and type(item.disabled) ~= 'boolean' then
            return ('item %d disabled MUST be a boolean'):format(index)
        end

        if item.items ~= nil then
            local problem = checkShown(item.items, depth + 1)

            if problem then
                return problem
            end
        end
    end

    return nil
end

---@param items table
---@param keepIds? boolean true for the tree sent to ug-lib, which maps choices back to ids. The page never gets ids.
---@return table
local function shownTree(items, keepIds)
    local shown = {}

    for index, item in ipairs(items) do
        if type(item) ~= 'table' then
            shown[index] = item
        else
            shown[index] = {
                id = keepIds and item.id or nil,
                label = item.label,
                icon = item.icon,
                iconColor = item.iconColor,
                disabled = item.disabled,
                items = type(item.items) == 'table' and shownTree(item.items, keepIds) or item.items,
            }
        end
    end

    return shown
end

---Checks a definition tree from a caller: ids unique in `seen`, known options, and callbacks where needed.
---@param name string
---@param items any
---@param seen table<string, boolean>
---@param withCallbacks boolean
---@param depth integer
local function checkDefinition(name, items, seen, withCallbacks, depth)
    if type(items) ~= 'table' then
        Utils.Raise(3 + depth, '%s: items MUST be 1 to %d items', name, MAX_ITEMS)
    end

    for index, item in ipairs(items) do
        if type(item) ~= 'table' then
            Utils.Raise(3 + depth, '%s: item %d MUST be a table', name, index)
        end

        for key in pairs(item) do
            if not ITEM[key] then
                local names = {}

                for known in pairs(ITEM) do
                    names[#names + 1] = known
                end

                local suggestion = type(key) == 'string' and UgLib.String.Suggest(key, names) or nil

                Utils.Raise(3 + depth, '%s: item %d has an unknown option "%s".%s', name, index, tostring(key), suggestion and (' Did you mean "%s"?'):format(suggestion) or '')
            end
        end

        if type(item.id) ~= 'string' or #item.id > MAX_ID or not item.id:find(ID_PATTERN) then
            Utils.Raise(3 + depth, '%s: item %d id MUST be 1 to %d letters, digits, or _ - . :', name, index, MAX_ID)
        end

        if seen[item.id] then
            Utils.Raise(3 + depth, '%s: item id "%s" is used twice', name, item.id)
        end

        seen[item.id] = true

        if item.items ~= nil then
            if item.onSelect ~= nil then
                Utils.Raise(3 + depth, '%s: item "%s" has a submenu and onSelect. Put onSelect on its leaves.', name, item.id)
            end

            checkDefinition(name, item.items, seen, withCallbacks, depth + 1)
        elseif withCallbacks and type(item.onSelect) ~= 'function' then
            Utils.Raise(3 + depth, '%s: item "%s" MUST have an onSelect function', name, item.id)
        elseif not withCallbacks and item.onSelect ~= nil then
            Utils.Raise(3 + depth, '%s: item "%s" of a one-off radial MUST NOT have onSelect', name, item.id)
        end
    end
end

---Follows a path of 1-based indexes. Every step MUST exist and not be disabled, and the last MUST be a leaf.
---@param items table
---@param path any
---@return table? leaf
local function walk(items, path)
    if type(path) ~= 'table' or #path < 1 or #path > MAX_DEPTH then
        return nil
    end

    local node = nil
    local level = items

    for depth = 1, #path do
        local index = type(path[depth]) == 'number' and math.tointeger(path[depth]) or nil

        node = index and type(level) == 'table' and level[index] or nil

        if not node or node.disabled then
            return nil
        end

        level = node.items
    end

    if node and node.items then
        return nil
    end

    return node
end

---@param payload table
---@return string? problem
local function check(payload)
    if payload.title ~= nil and not isText(payload.title, MAX_LABEL) then
        return ('title MUST be UTF-8 text of 1 to %d characters'):format(MAX_LABEL)
    end

    if payload.color ~= nil and not Utils.IsColor(payload.color) then
        return 'color MUST be a UgLib.Enums.Color value or a #rrggbb hex'
    end

    return checkShown(payload.items, 1)
end

---@param payload table
---@return table
local function rebuild(payload)
    return {
        title = payload.title,
        color = payload.color,
        items = type(payload.items) == 'table' and shownTree(payload.items) or payload.items,
    }
end

---Shows a one-off radial and waits for a choice. Submenus go up to 3 levels. MUST run in a thread.
---@param options { items: UgRadialItem[], title?: string, timeout?: integer, color?: UgLibColorValue }
---@return string? id the chosen item, nil when closed
---@return UgCloseReason? reason
function Radial.Open(options)
    Utils.CheckOptions('Radial.Open', options, OPEN_OPTIONS)
    checkDefinition('Radial.Open', options.items, {}, false, 0)

    local payload = rebuild(options)
    local problem = check(payload)

    if problem then
        Utils.Raise(2, 'Radial.Open: %s', problem)
    end

    local path, reason = Requests.Await('Radial.Open', KIND, payload, {
        timeout = options.timeout,
    })
    local leaf = path and walk(options.items, path)

    if not leaf then
        return nil, reason or Enums.CloseReason.Cancelled
    end

    return leaf.id, nil
end

---@type table<string, fun(id: string)> leaf id -> onSelect, for this resource's global items
local handlers = {}

---@type table<string, string[]> top-level id -> leaf ids, to forget handlers on removal
local leavesOf = {}

---@param items UgRadialItem[]
---@param leaves string[]
local function collect(items, leaves)
    for _, item in ipairs(items) do
        if item.items then
            collect(item.items, leaves)
        else
            handlers[item.id] = item.onSelect
            leaves[#leaves + 1] = item.id
        end
    end
end

---@param id string
local function forget(id)
    for _, leaf in ipairs(leavesOf[id] or {}) do
        handlers[leaf] = nil
    end

    leavesOf[id] = nil
end

---@param name string
---@param ... any
---@return any
local function lib(name, ...)
    return exports[LIB][Protocol.Exports[name]](exports[LIB], ...)
end

---Adds an item, or replaces the item with the same id, to the global radial. Leaves MUST have `onSelect`,
---which runs in this resource. Ids are unique in the tree of the calling resource.
---@param item UgRadialItem
function Radial.AddItem(item)
    local seen = {}

    for top, leaves in pairs(leavesOf) do
        if top ~= (type(item) == 'table' and item.id) then
            for _, leaf in ipairs(leaves) do
                seen[leaf] = true
            end

            seen[top] = true
        end
    end

    checkDefinition('Radial.AddItem', { item }, seen, true, 0)

    local shown = shownTree({ item }, true)[1]
    local problem = checkShown({ shown }, 1)

    if problem then
        Utils.Raise(2, 'Radial.AddItem: %s', problem)
    end

    forget(item.id)

    local leaves = {}

    collect({ item }, leaves)
    leavesOf[item.id] = leaves
    lib('RadialAdd', shown)
end

---Removes one of this resource's global items.
---@param id string
---@return boolean removed
function Radial.RemoveItem(id)
    if not leavesOf[id] then
        return false
    end

    forget(id)

    return lib('RadialRemove', id)
end

---Removes every global item of this resource.
function Radial.ClearItems()
    for id in pairs(leavesOf) do
        forget(id)
    end

    lib('RadialClear')
end

---Allows or blocks the global radial key for this resource, such as while the player is dead.
---The radial is blocked while any resource blocks it.
---@param enabled boolean
function Radial.SetEnabled(enabled)
    if type(enabled) ~= 'boolean' then
        Utils.Raise(2, 'Radial.SetEnabled expects a boolean, got %s', type(enabled))
    end

    lib('RadialEnable', enabled)
end

AddEventHandler(Protocol.RadialEvent:format(RESOURCE), function(id)
    if GetInvokingResource() ~= LIB then
        return
    end

    local handler = handlers[id]

    if handler then
        local ok, err = pcall(handler, id)

        if not ok then
            Logger.Error('Radial onSelect for %s failed: %s', tostring(id), tostring(err))
        end
    end
end)

if IS_OWNER then
    local Layers = UgLib.Internal.Layers

    Layers.RegisterType(KIND, {
        modal = true,
        focus = Protocol.Nui.Focus.Cursor,
        sanitize = function(payload)
            local clean = rebuild(payload)
            local problem = check(clean)

            if problem then
                error(problem, 0)
            end

            return clean
        end,
        validate = function(payload, result)
            if not walk(payload.items, result) then
                return false, nil
            end

            local path = {}

            for index, step in ipairs(result) do
                path[index] = math.tointeger(step)
            end

            return true, path
        end,
    })

    ---@class UgLibGlobalRadialItem
    ---@field owner string
    ---@field item table shown tree with ids

    ---@type UgLibGlobalRadialItem[]
    local global = {}

    ---@type table<string, boolean> resources that block the radial
    local blocked = {}

    ---@type string? layer id of the open global radial
    local open = nil

    ---@param owner string
    ---@param id string
    ---@return integer?
    local function find(owner, id)
        for index, entry in ipairs(global) do
            if entry.owner == owner and entry.item.id == id then
                return index
            end
        end

        return nil
    end

    ---@param tree table
    ---@return table
    local function withIds(tree)
        return shownTree({ tree }, true)[1]
    end

    ---@return string
    local function owner()
        return GetInvokingResource() or RESOURCE
    end

    exports(Protocol.Exports.RadialAdd, function(item)
        ---@type string?
        local problem = 'item MUST be a table with an id'

        if type(item) == 'table' and type(item.id) == 'string' then
            problem = checkShown({ item }, 1)
        end

        if problem then
            Utils.Raise(2, 'Radial: invalid item: %s', problem)
        end

        local caller = owner()
        local entry = {
            owner = caller,
            item = withIds(item),
        }
        local index = find(caller, item.id)

        if index then
            global[index] = entry
        else
            global[#global + 1] = entry
        end
    end)

    exports(Protocol.Exports.RadialRemove, function(id)
        local index = find(owner(), id)

        if index then
            table.remove(global, index)
        end

        return index ~= nil
    end)

    exports(Protocol.Exports.RadialClear, function()
        local caller = owner()

        for index = #global, 1, -1 do
            if global[index].owner == caller then
                table.remove(global, index)
            end
        end
    end)

    exports(Protocol.Exports.RadialEnable, function(enabled)
        blocked[owner()] = enabled == false or nil
    end)

    AddEventHandler('onResourceStop', function(resource)
        blocked[resource] = nil

        for index = #global, 1, -1 do
            if global[index].owner == resource then
                table.remove(global, index)
            end
        end
    end)

    ---Opens the global radial, or closes it when it is open.
    local function toggle()
        if open then
            Requests.Close(open)

            return
        end

        if next(blocked) or #global == 0 then
            return
        end

        local snapshot = {}
        local items = {}

        for index, entry in ipairs(global) do
            snapshot[index] = entry
            items[index] = entry.item
        end

        local layer = nil

        layer = Requests.Start(KIND, rebuild({
            items = items,
        }), {
            onClose = function(result)
                if open == layer then
                    open = nil
                end

                local entry = type(result) == 'table' and snapshot[result[1]]
                local leaf = entry and walk({ entry.item }, { 1, table.unpack(result, 2) })

                if entry and leaf then
                    TriggerEvent(Protocol.RadialEvent:format(entry.owner), leaf.id)
                end
            end,
        })

        open = layer
    end

    local key = UgLib.Internal.Config.Get('settings', 'radialKey')

    if key ~= '' then
        -- While the radial has the cursor, keys reach the page, not the game: Escape and the backdrop close it there.
        UgLib.Keybind.Register({
            name = 'radial',
            label = 'Open the radial menu',
            defaultKey = key or 'F1',
            disableWhileUi = false,
            onPressed = toggle,
        })
    end

    ---@type UgLib.Internal.Radial
    UgLib.Internal.Radial = {
        Toggle = toggle,
        ---@return integer
        Count = function()
            return #global
        end,
    }

    UgLib.Internal.Demos.Register('radial', function(args)
        if args[1] == 'global' then
            toggle()

            return
        end

        local id, reason = Radial.Open({
            title = 'Interact',
            items = {
                {
                    id = 'wave',
                    label = 'Wave',
                    icon = Enums.Icon.User,
                },
                {
                    id = 'lock',
                    label = 'Lock',
                    icon = Enums.Icon.Lock,
                },
                { id = 'admin', label = 'Admin', icon = Enums.Icon.Settings, items = {
                    {
                        id = 'heal',
                        label = 'Heal',
                        icon = Enums.Icon.Plus,
                    },
                    {
                        id = 'kick',
                        label = 'Kick',
                        icon = Enums.Icon.Trash,
                        disabled = true,
                    },
                } },
            },
        })

        print(('[ug-lib] radial %s, reason %s'):format(tostring(id), tostring(reason)))
    end)
end

---@class UgLib.Internal.Radial
---@field Toggle fun()
---@field Count fun(): integer
