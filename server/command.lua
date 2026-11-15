--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- `uglib` console command. Restricted: the server console and principals with `command.uglib` only.

local Loader = UgLib.Internal.Config.Loader
local Serializer = UgLib.Internal.Config.Serializer
local Validator = UgLib.Internal.Config.Validator

local USAGE = 'Usage: uglib <status|config <name>>'

---@param entry UgLibConfigEntry
---@return string
local function describeSources(entry)
    local counts = {
        file = 0,
        convar = 0,
    }

    for _, source in pairs(entry.sources or {}) do
        if counts[source] then
            counts[source] = counts[source] + 1
        end
    end

    return ('%s, %d from file, %d from convars'):format(entry.file or 'not loaded', counts.file, counts.convar)
end

local function status()
    local settings = UgLib.Internal.Config.Get('settings') or {}
    local theme = UgLib.Internal.Config.Get('theme') or {}

    print(('ug-lib v%s'):format(UgLib.Version.Get()))
    local debug = UgLib.Internal.Logger.IsDebug() and 'on' or 'off'

    print(('  locale %s, theme %s, debug %s (%s)'):format(tostring(settings.locale), tostring(theme.mode), tostring(settings.debug), debug))

    for _, entry in ipairs(Loader.GetEntries()) do
        print(('  config/%s.lua: %s'):format(entry.name, describeSources(entry)))
    end
end

---@param name string?
local function config(name)
    local entry = name and Loader.GetEntry(name)

    if not entry then
        local names = {}

        for _, known in ipairs(Loader.GetEntries()) do
            names[#names + 1] = known.name
        end

        print(('Unknown config "%s". Configs: %s.'):format(tostring(name), table.concat(names, ', ')))

        return
    end

    print(('config/%s.lua (%s)'):format(entry.name, entry.file or 'not loaded'))

    for _, option in ipairs(entry.definition.options) do
        local value = entry.values and entry.values[option.key]
        local source = entry.sources and entry.sources[option.key] or 'default'
        local suffix = source == 'convar' and (' (convar %s)'):format(Validator.ConvarName(entry.name, option.key)) or (' (%s)'):format(source)

        print(('  %s = %s%s'):format(option.key, Serializer.Inline(value), suffix))
    end
end

RegisterCommand('uglib', function(_, args)
    local subcommand = args[1]

    if subcommand == 'status' then
        status()
    elseif subcommand == 'config' then
        config(args[2])
    else
        print(USAGE)
    end
end, true)
