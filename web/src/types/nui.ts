/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Mirrors `UgLib.Internal.Protocol.Nui` in shared/protocol.lua. tests/nui.lua checks both sides match.

export const NuiType = {
  System: "system",
  Notify: "notify",
  TextUI: "textui",
  Progress: "progress",
  SkillCheck: "skillcheck",
  Dialog: "dialog",
  Context: "context",
  Menu: "menu",
  Radial: "radial",
  Settings: "settings",
} as const;

export type NuiType = (typeof NuiType)[keyof typeof NuiType];

export const NuiAction = {
  Open: "open",
  Update: "update",
  Close: "close",
  Config: "config",
  CloseAll: "closeAll",
  Clipboard: "clipboard",
} as const;

export type NuiAction = (typeof NuiAction)[keyof typeof NuiAction];

export const NuiCallback = {
  Ready: "ug-lib:Nui:Ready",
  Resolve: "ug-lib:Nui:Resolve",
  Event: "ug-lib:Nui:Event",
  Close: "ug-lib:Nui:Close",
} as const;

export type NuiCallback = (typeof NuiCallback)[keyof typeof NuiCallback];

export const DialogVariant = {
  Alert: "alert",
  Confirm: "confirm",
  Input: "input",
} as const;

export type DialogVariant = (typeof DialogVariant)[keyof typeof DialogVariant];

/** Every message from Lua. `id` is `<owner>/<id>` for layer messages. */
export interface NuiMessage {
  type: string;
  action: string;
  id?: string;
  payload?: unknown;
}

/** A component instance on screen. */
export interface Layer {
  id: string;
  type: string;
  payload: unknown;
  /** Open order, used as z-index. */
  order: number;
  /** Closing but still mounted for its exit animation. */
  exiting: boolean;
}
