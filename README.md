<div align="center">

# ⬢ ug-lib

**The UI and utility library of the UgCore Framework. Standalone, or next to ug-core.**

[![Documentation](https://img.shields.io/badge/Docs-ugcore.urging.ch-7C5CFF?logo=readthedocs&logoColor=white)](https://ugcore.urging.ch/ug-lib/introduction)
[![CI](https://img.shields.io/github/actions/workflow/status/ugcore-project/ug-lib/ci.yml?branch=dev&label=CI)](https://github.com/ugcore-project/ug-lib/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ugcore-project/ug-lib?label=Release&color=22D3EE)](https://github.com/ugcore-project/ug-lib/releases/latest)
[![License](https://img.shields.io/github/license/ugcore-project/ug-lib?color=brightgreen)](LICENSE)
[![Discord](https://img.shields.io/discord/1518308384900649021?label=Discord&logo=discord&logoColor=white&color=5865F2)](https://discord.gg/pCJUcyVw5X)

[**Documentation**](https://ugcore.urging.ch/ug-lib/introduction) · [**Installation**](https://ugcore.urging.ch/ug-lib/installation) · [**Importing**](https://ugcore.urging.ch/ug-lib/importing) · [**Configuration**](https://ugcore.urging.ch/ug-lib/configuration)

</div>

---

ug-lib gives your resources notifications, prompts, progress bars, dialogs, menus and radials, plus Lua helpers for
math, text, zones, entities and more. One shared script gives your resource `UgLib`.

It works with or without [ug-core](https://github.com/ugcore-project/ug-core). The two never depend on each other:
ug-core returns error codes and emits events, and your resource decides what the player sees through ug-lib.

## Features

- 🪟 **UI services.** Notify, TextUI, Progress, SkillCheck, Dialog, Context, Menu, Radial and Clipboard, on one themed page.
- 📍 **Client utilities.** Cache, Streaming, Entity, Raycast, Screen, Draw, Animation, Zone, Point, Npc and Keybind. They run in your resource.
- 🧰 **Shared utilities.** Math, Table, String, Format, Async, Locale and Version, on the server and on clients.
- 🎨 **Themes.** The owner sets colors, radius, font and scale. Each player picks theme, accent, size and positions with `/uisettings`.
- 🛡️ **The page is untrusted.** Lua checks every answer against what it sent: a dialog value against its field, a menu choice against its items.
- 🧭 **Mistakes raise at your line.** `Dialog.Input: field "plate" has an unknown option "maxLenght". Did you mean "maxLength"?`
- 📡 **No network.** ug-lib registers no net events and no callbacks.

## Requirements

- A FiveM server with a recent artifact.
- Nothing else. OneSync and ug-core are optional.

## Installation

Download `ug-lib.zip` from the [latest release](https://github.com/ugcore-project/ug-lib/releases/latest) and
extract it into your `resources` folder, for example `resources/[ug]/ug-lib`. The resource MUST be named `ug-lib`.
Start it before every resource that imports it:

```cfg
ensure ug-lib
ensure ug-core
ensure my-shop
```

On the first start, `config/settings.lua` and `config/theme.lua` are generated. Updates never overwrite them. The server
console prints `[ug-lib] v1.0.0 · config loaded · 2 files` and each client prints `[ug-lib] v1.0.0 ready (dark, en).` in F8.

## Usage

```lua
-- fxmanifest.lua
uglib_version '1.0.0'
dependency 'ug-lib'
shared_script '@ug-lib/import.lua'
```

```lua
-- client.lua: waiting calls MUST run in a thread, an event handler or a command.
RegisterCommand('sell', function()
    local confirmed = UgLib.Dialog.Confirm({
        title = 'Sell the car?',
        destructive = true,
    })

    if confirmed then
        UgLib.Notify.Show({
            message = 'Sold',
            type = UgLib.Enums.NotifyType.Success,
        })
    end
end, false)
```

`uglib_version` is optional. With it, your resource does not start against an older ug-lib. See
[Importing ug-lib](https://ugcore.urging.ch/ug-lib/importing) for what runs in your resource and what goes through ug-lib.

## Configuration

| File | Holds |
| --- | --- |
| `config/settings.lua` | Locale, debug, currency, positions and durations, keys, sounds, player settings and their command. |
| `config/theme.lua` | Mode, colors, radius, font and scale. |

Convars override both: `setr ug-lib:Locale de` for settings, `setr ug-lib:Theme:Mode light` for the theme. See [Configuration](https://ugcore.urging.ch/ug-lib/configuration)
and [Customization](https://ugcore.urging.ch/ug-lib/customization).

## Console commands

| Command | Where | Does |
| --- | --- | --- |
| `uglib status` | Server | Version and loaded config. |
| `uglib config <name>` | Server | Resolved values with their source: default, file or convar. |
| `uglib state` | F8, debug only | Open layers and focus. |
| `uglib close` | F8, debug only | Closes every layer. |
| `uglib demo <name>` | F8, debug only | Plays a demo of a UI service. |

## Project structure

```
ug-lib/
├── fxmanifest.lua
├── import.lua          shared_script '@ug-lib/import.lua' for other resources
├── import/             consumer side of the import
├── shared/             UgLib root, enums, Math, Table, String, Format, Async, Locale, Version
├── client/             client utilities, the NUI bridge, player settings
│   └── ui/             Notify, TextUI, Progress, SkillCheck, Dialog, Context, Menu, Radial, Clipboard
├── server/             config loader, schemas and the uglib command
├── locales/            player-facing text, one file per language
├── web/                React page, built to web/dist
├── config/             owner space, generated, git-ignored
├── types/              LuaLS types
└── tests/              plain Lua 5.4 tests with native mocks, never shipped
```

## Development

Every change MUST pass these checks. CI runs them on pull requests, and on pushes to `dev` and `main` before any build.

```bash
# 1. LuaLS strict check, zero problems
lua-language-server --check . --checklevel=Information --configpath=.luarc.json

# 2. Runtime tests
for suite in tests/*.lua; do [ "$suite" = tests/helpers.lua ] || lua5.4 "$suite" || exit 1; done

# 3. Manifest and license headers
lua5.4 .github/scripts/check-repository.lua
```

The page needs Node.js 20.19 or newer:

```bash
cd web
npm ci
npm run lint && npm run typecheck && npm test
npm run build && npm run budget   # web/dist, at most 400 KB gzipped
npm run dev                       # browser preview
```

For editor support, install the [Lua](https://marketplace.visualstudio.com/items?itemName=sumneko.lua) and [CfxLua](https://marketplace.visualstudio.com/items?itemName=overextended.cfxlua-vscode) VS Code extensions.

### Conventions

- Lua 5.4. Every file starts with the license header. Every function has LuaLS annotations.
- ug-lib MUST NOT depend on ug-core, and ug-core MUST NOT depend on ug-lib.
- No network, no state, no callbacks. Server messages reach the page through your own client script.
- Anything the page sends is untrusted. Lua checks it against what it sent.
- Magic values live in `UgLib.Enums`. Every player-facing text goes through `locales/`.

### Releases

Releases are automated. release-please keeps a `chore: release X.Y.Z` pull request open on `main` that bumps
`version` in `fxmanifest.lua` and `CHANGELOG.md` from Conventional Commits. Merging it tags `vX.Y.Z`, builds the page
and attaches `ug-lib.zip` with only what a server runs. Every push to `dev` replaces the `dev-build` pre-release.
Merge `dev` into `main` with a merge commit, never squash. Commit subjects become the changelog: write them for owners.

## Contributing

Contributions are welcome. Branch off `dev` and open a pull request to `dev`.

- Commits and PR titles follow [Conventional Commits](https://www.conventionalcommits.org): lowercase imperative subject, no trailing period, 72 characters at most. Scopes: `core`, `config`, `nui`, `web`, `notify`, `textui`, `progress`, `skillcheck`, `dialog`, `context`, `menu`, `radial`, `cache`, `zone`, `keybind`, `streaming`, `entity`, `draw`, `animation`, `utils`, `locale`, `import`, `ci`, `deps`.
- Add or extend a test for every change in behavior.
- Translations are welcome: copy `locales/en.json` to your language code and translate the values.

Read the [contributing guide](https://github.com/ugcore-project/.github/blob/main/CONTRIBUTING.md) and the [Code of Conduct](https://github.com/ugcore-project/.github/blob/main/CODE_OF_CONDUCT.md).

## Security

Never report a vulnerability in a public issue. [Report it privately](https://github.com/ugcore-project/ug-lib/security/advisories/new) and read the [Security Policy](https://github.com/ugcore-project/.github/blob/main/SECURITY.md).

## License

ug-lib is free software, licensed under the [GNU General Public License v3.0](LICENSE).

Copyright (C) 2026 UgCore Framework & Contributors.
