--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- `uglib` client command for F8. Available only when `settings.debug` is true.

---Demos of UI services for `uglib demo <name>`. Each service registers its own.
---@class UgLib.Internal.Demos
local Demos = {}
UgLib.Internal.Demos = Demos

local Layers = UgLib.Internal.Layers
local Nui = UgLib.Internal.Nui

local USAGE = 'Usage: uglib <state|close|demo <name>>'

---@type table<string, fun(args: string[])>
local demos = {}

---@param name string
---@param run fun(args: string[]) runs in a thread
function Demos.Register(name, run)
    demos[name] = run
end

---@return string[]
local function demoNames()
    local names = {}

    for name in pairs(demos) do
        names[#names + 1] = name
    end

    table.sort(names)

    return names
end

local function state()
    local focus = Nui.GetFocus()
    local modal = Layers.GetModal()

    print(('ug-lib v%s, NUI %s'):format(UgLib.Version.Get(), Nui.IsReady() and 'ready' or 'not ready'))
    print(('  focus %s, cursor %s, keep input %s'):format(tostring(focus.focus), tostring(focus.cursor), tostring(focus.keepInput)))
    print(('  modal %s'):format(modal and modal.key or 'none'))

    local open = Layers.GetAll()

    table.sort(open, function(a, b)
        return a.seq < b.seq
    end)

    print(('  layers %d'):format(#open))

    for _, layer in ipairs(open) do
        print(('    %s %s'):format(layer.kind, layer.key))
    end

    local Cache = UgLib.Cache

    print(('  cache ped %s, server id %s, vehicle %s, seat %s, weapon %s'):format(
        tostring(Cache.Ped), tostring(Cache.ServerId), tostring(Cache.Vehicle), tostring(Cache.Seat), tostring(Cache.Weapon)
    ))
end

---@param args string[]
local function demo(args)
    local run = demos[args[2] or '']

    if not run then
        local names = demoNames()

        print(('Demos: %s.'):format(#names > 0 and table.concat(names, ', ') or 'none yet'))

        return
    end

    CreateThread(function()
        run({ table.unpack(args, 3) })
    end)
end

RegisterCommand('uglib', function(_, args)
    if not UgLib.Internal.Logger.IsDebug() then
        print("uglib needs debug. Set debug = 'on' in config/settings.lua of ug-lib, or keep 'auto' and turn on ug-core debug.")

        return
    end

    local subcommand = args[1]

    if subcommand == 'state' then
        state()
    elseif subcommand == 'close' then
        Layers.CloseAll()
        print('Closed every layer.')
    elseif subcommand == 'demo' then
        demo(args)
    else
        print(USAGE)
    end
end, false)
