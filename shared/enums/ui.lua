--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Screen anchors shared by every positioned component.
---@enum UgPosition
UgLib.Enums.Position = {
    TopLeft = 'top-left',
    Top = 'top',
    TopRight = 'top-right',
    CenterLeft = 'center-left',
    Center = 'center',
    CenterRight = 'center-right',
    BottomLeft = 'bottom-left',
    Bottom = 'bottom',
    BottomRight = 'bottom-right',
}

---@enum UgNotifyType
UgLib.Enums.NotifyType = {
    Info = 'info',
    Success = 'success',
    Warning = 'warning',
    Error = 'error',
}

---@enum UgNotifyStyle
UgLib.Enums.NotifyStyle = {
    Toast = 'toast',
    Compact = 'compact',
    Banner = 'banner',
}

---@enum UgProgressStyle
UgLib.Enums.ProgressStyle = {
    Bar = 'bar',
    Circle = 'circle',
    Ring = 'ring',
    Minimal = 'minimal',
}

---@enum UgTextUIStyle
UgLib.Enums.TextUIStyle = {
    Pill = 'pill',
    Minimal = 'minimal',
    Keybind = 'keybind',
    Card = 'card',
}

---Field types of `Dialog.Input`.
---@enum UgFieldType
UgLib.Enums.FieldType = {
    Text = 'text',
    Textarea = 'textarea',
    Number = 'number',
    Password = 'password',
    Select = 'select',
    MultiSelect = 'multi-select',
    Checkbox = 'checkbox',
    Toggle = 'toggle',
    Slider = 'slider',
    Color = 'color',
    Date = 'date',
}

---Why a UI request ended without an answer.
---@enum UgCloseReason
UgLib.Enums.CloseReason = {
    Cancelled = 'cancelled',
    Timeout = 'timeout',
    Busy = 'busy',
    Replaced = 'replaced',
    Closed = 'closed',
}

---@enum UgDifficulty
UgLib.Enums.Difficulty = {
    Easy = 'easy',
    Medium = 'medium',
    Hard = 'hard',
}

---UI services, for `UgLib.Ui.IsOpen`.
---@enum UgUiType
UgLib.Enums.UiType = {
    Notify = 'notify',
    TextUI = 'textui',
    Progress = 'progress',
    SkillCheck = 'skillcheck',
    Dialog = 'dialog',
    Context = 'context',
    Menu = 'menu',
    Radial = 'radial',
}

---Theme colors for icons, progress bars and markup.
---@enum UgColor
UgLib.Enums.Color = {
    Primary = 'primary',
    Success = 'success',
    Warning = 'warning',
    Destructive = 'destructive',
    Muted = 'muted',
}

---Width of a dialog.
---@enum UgDialogSize
UgLib.Enums.DialogSize = {
    Small = 'sm',
    Medium = 'md',
    Large = 'lg',
}

---@enum UgThemeMode
UgLib.Enums.ThemeMode = {
    Dark = 'dark',
    Light = 'light',
}

---Player preferences, saved on the player's PC. Owners lock them by these names in `settings.lockedSettings`.
---@enum UgPreferenceKey
UgLib.Enums.PreferenceKey = {
    Mode = 'mode',
    Accent = 'accent',
    Scale = 'scale',
    NotifyPosition = 'notifyPosition',
    NotifyStyle = 'notifyStyle',
    TextUIPosition = 'textUIPosition',
    TextUIStyle = 'textUIStyle',
    ProgressPosition = 'progressPosition',
    ProgressStyle = 'progressStyle',
    MenuPosition = 'menuPosition',
    ContextPosition = 'contextPosition',
}
