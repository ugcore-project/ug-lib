--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- Loaded by other resources with `shared_script '@ug-lib/import.lua'`. Defines the global `UgLib`.
-- Utilities run in this runtime. UI calls wait here and reach ug-lib through non-blocking exports.
-- ug-lib files load into a private environment, so `UgLib.Internal` never reaches the consumer.

local LIB = 'ug-lib'

local SHARED_FILES = {
    'shared/init.lua',
    'shared/enums/init.lua',
    'shared/enums/ui.lua',
    'shared/enums/icons.lua',
    'shared/enums/events.lua',
    'shared/enums/cache.lua',
    'shared/enums/format.lua',
    'shared/enums/state.lua',
    'shared/enums/world.lua',
    'shared/utils.lua',
    'shared/logger.lua',
    'shared/version.lua',
    'shared/math.lua',
    'shared/table.lua',
    'shared/string.lua',
    'shared/format.lua',
    'shared/async.lua',
    'shared/config.lua',
    'shared/locale.lua',
    'shared/protocol.lua',
    'import/proxy.lua',
}

local SERVER_FILES = {}

local CLIENT_FILES = {
    'import/ui.lua',
    'client/cache.lua',
    'client/streaming.lua',
    'client/entity.lua',
    'client/raycast.lua',
    'client/screen.lua',
    'client/draw.lua',
    'client/animation.lua',
    'client/zone.lua',
    'client/point.lua',
    'client/npc.lua',
    'client/keybind.lua',
    'client/controls.lua',
    'client/ui/notify.lua',
    'client/ui/textui.lua',
    'client/ui/progress.lua',
    'client/ui/skillcheck.lua',
    'client/ui/dialog.lua',
    'client/ui/context.lua',
    'client/ui/menu.lua',
    'client/ui/radial.lua',
    'client/ui/clipboard.lua',
    'client/ui/ui.lua',
}

local private = setmetatable({}, {
    __index = _ENV,
})

---@param path string
local function run(path)
    local content = LoadResourceFile(LIB, path)

    if not content then
        error(('[ug-lib] import: cannot read %s. Start ug-lib before this resource.'):format(path), 0)
    end

    local chunk, syntaxError = load(content, ('@@%s/%s'):format(LIB, path), 't', private)

    if not chunk then
        error(syntaxError, 0)
    end

    chunk()
end

for _, path in ipairs(SHARED_FILES) do
    run(path)
end

for _, path in ipairs(IsDuplicityVersion() and SERVER_FILES or CLIENT_FILES) do
    run(path)
end

-- `uglib_version '1.2.0'` in the consumer's fxmanifest.lua stops it from starting against an older ug-lib.
local required = GetResourceMetadata(GetCurrentResourceName(), 'uglib_version', 0)

if required then
    private.UgLib.Version.Require(required)
end

UgLib = private.UgLib.Internal.Proxy.CreateRoot()
