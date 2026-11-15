--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@diagnostic disable: undefined-global

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'ug-lib'
author 'UgCore Framework & Contributors'
version '1.0.0' -- x-release-please-version
description 'UI and utility library of the UgCore Framework'
repository 'https://github.com/ugcore-project/ug-lib'

shared_scripts {
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
}

server_scripts {
    'server/config/validator.lua',
    'server/config/serializer.lua',
    'server/config/loader.lua',
    'server/config/schemas/settings.lua',
    'server/config/schemas/theme.lua',
    'server/command.lua',
    'server/boot.lua',
}

ui_page 'web/dist/index.html'

client_scripts {
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
    'client/nui.lua',
    'client/preferences.lua',
    'client/layers.lua',
    'client/exports.lua',
    'client/commands.lua',
    'import/ui.lua',
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
    'client/settings.lua',
    'client/boot.lua',
}

files {
    'import.lua',
    'import/*.lua',
    'client/*.lua',
    'client/ui/*.lua',
    'shared/*.lua',
    'shared/enums/*.lua',
    'locales/*.json',
    'web/dist/index.html',
    'web/dist/assets/*',
}
