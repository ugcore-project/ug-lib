/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Mirrors the `UgLib.Enums` the page reads. tests/enums.lua checks every value against shared/enums/.

export const Position = {
  TopLeft: "top-left",
  Top: "top",
  TopRight: "top-right",
  CenterLeft: "center-left",
  Center: "center",
  CenterRight: "center-right",
  BottomLeft: "bottom-left",
  Bottom: "bottom",
  BottomRight: "bottom-right",
} as const;

export type Position = (typeof Position)[keyof typeof Position];

export const NotifyType = {
  Info: "info",
  Success: "success",
  Warning: "warning",
  Error: "error",
} as const;

export type NotifyType = (typeof NotifyType)[keyof typeof NotifyType];

export const NotifyStyle = {
  Toast: "toast",
  Compact: "compact",
  Banner: "banner",
} as const;

export type NotifyStyle = (typeof NotifyStyle)[keyof typeof NotifyStyle];

export const ProgressStyle = {
  Bar: "bar",
  Circle: "circle",
  Ring: "ring",
  Minimal: "minimal",
} as const;

export type ProgressStyle = (typeof ProgressStyle)[keyof typeof ProgressStyle];

export const TextUIStyle = {
  Pill: "pill",
  Minimal: "minimal",
  Keybind: "keybind",
  Card: "card",
} as const;

export type TextUIStyle = (typeof TextUIStyle)[keyof typeof TextUIStyle];

export const FieldType = {
  Text: "text",
  Textarea: "textarea",
  Number: "number",
  Password: "password",
  Select: "select",
  MultiSelect: "multi-select",
  Checkbox: "checkbox",
  Toggle: "toggle",
  Slider: "slider",
  Color: "color",
  Date: "date",
} as const;

export type FieldType = (typeof FieldType)[keyof typeof FieldType];

export const Difficulty = {
  Easy: "easy",
  Medium: "medium",
  Hard: "hard",
} as const;

export type Difficulty = (typeof Difficulty)[keyof typeof Difficulty];

export const Icon = {
  Info: "info",
  Settings: "settings",
  User: "user",
  Lock: "lock",
  Unlock: "unlock",
  Trash: "trash",
  Star: "star",
  Edit: "edit",
  Plus: "plus",
  Minus: "minus",
  Check: "check",
  Warning: "warning",
  Error: "error",
  Question: "question",
} as const;

export type Icon = (typeof Icon)[keyof typeof Icon];

export const Color = {
  Primary: "primary",
  Success: "success",
  Warning: "warning",
  Destructive: "destructive",
  Muted: "muted",
} as const;

export type Color = (typeof Color)[keyof typeof Color];

export const DialogSize = {
  Small: "sm",
  Medium: "md",
  Large: "lg",
} as const;

export type DialogSize = (typeof DialogSize)[keyof typeof DialogSize];

export const ThemeMode = {
  Dark: "dark",
  Light: "light",
} as const;

export type ThemeMode = (typeof ThemeMode)[keyof typeof ThemeMode];
