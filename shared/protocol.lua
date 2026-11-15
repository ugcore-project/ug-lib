--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Names shared by ug-lib, the import and the NUI page. Consumers never use them directly.
---The `Nui` names MUST match `web/src/types/nui.ts`. `tests/nui.lua` checks it.
---@class UgLib.Internal.Protocol
UgLib.Internal.Protocol = {
    ---Local event to the owner of a request, `(id, result, reason, final)`. Formatted with the owner resource name.
    ResponseEvent = '__uglib:res:%s',
    ---Non-blocking exports of ug-lib's client runtime. The caller is the owner of the layer.
    Exports = {
        Open = 'UiOpen',
        Update = 'UiUpdate',
        Close = 'UiClose',
        RadialAdd = 'RadialAddItem',
        RadialRemove = 'RadialRemoveItem',
        RadialClear = 'RadialClearItems',
        RadialEnable = 'RadialSetEnabled',
        Copy = 'UiCopy',
        CloseAll = 'UiCloseAll',
        IsOpen = 'UiIsOpen',
        OpenSettings = 'UiOpenSettings',
    },
    ---Local event to the resource that added a global radial item, `(itemId)`. Formatted with the resource name.
    RadialEvent = '__uglib:radial:%s',
    ---Longest request id, in bytes.
    MaxIdLength = 32,
    Nui = {
        ---Message types. Each UI service is one type, `system` controls the page.
        Types = {
            System = 'system',
            Notify = 'notify',
            TextUI = 'textui',
            Progress = 'progress',
            SkillCheck = 'skillcheck',
            Dialog = 'dialog',
            Context = 'context',
            Menu = 'menu',
            Radial = 'radial',
            Settings = 'settings',
        },
        Actions = {
            Open = 'open',
            Update = 'update',
            Close = 'close',
            Config = 'config',
            CloseAll = 'closeAll',
            Clipboard = 'clipboard',
        },
        ---NUI callbacks, the page to Lua.
        Callbacks = {
            Ready = 'ug-lib:Nui:Ready',
            Resolve = 'ug-lib:Nui:Resolve',
            Event = 'ug-lib:Nui:Event',
            Close = 'ug-lib:Nui:Close',
        },
        ---Dialog payload variants.
        DialogVariants = {
            Alert = 'alert',
            Confirm = 'confirm',
            Input = 'input',
        },
        ---What a layer takes from the game while it is the top layer that wants input.
        Focus = {
            None = 'none',
            Keyboard = 'keyboard',
            Cursor = 'cursor',
        },
        ---Longest layer id the page sends back, in bytes: `<owner>/<id>`.
        MaxLayerIdLength = 100,
        ---Non-final events per layer per second. Extra events are dropped.
        EventsPerSecond = 20,
    },
}
