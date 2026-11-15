/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { create } from "zustand";
import { accentStyle } from "@/lib/accent";
import { Position, ThemeMode } from "@/types/enums";

export interface ThemeConfig {
  mode: ThemeMode;
  colors: Record<string, string>;
  radius: string;
  font: string;
  scale: number;
}

export interface PageSettings {
  notifyPosition: Position;
  notifyDuration: number;
  notifyMax: number;
  textUIPosition: Position;
  progressPosition: Position;
  menuPosition: Position;
  sounds: boolean;
}

export interface Labels {
  ok: string;
  confirm: string;
  cancel: string;
  back: string;
  close: string;
  submit: string;
}

export interface PageConfig {
  theme: ThemeConfig;
  /** The player's accent, `#rrggbb`. It replaces the primary color of the theme. */
  accent?: string;
  settings: PageSettings;
  labels: Labels;
  locale: string;
}

/** Used until Lua sends the config, and in the browser preview. Matches the schema defaults. */
export const DEFAULT_CONFIG: PageConfig = {
  theme: { mode: ThemeMode.Dark, colors: {}, radius: "0.5rem", font: "Inter", scale: 1 },
  settings: {
    notifyPosition: Position.TopRight,
    notifyDuration: 5000,
    notifyMax: 5,
    textUIPosition: Position.Bottom,
    progressPosition: Position.Bottom,
    menuPosition: Position.TopLeft,
    sounds: true,
  },
  labels: { ok: "OK", confirm: "Confirm", cancel: "Cancel", back: "Back", close: "Close", submit: "Submit" },
  locale: "en",
};

/** Theme tokens owners MAY override, mapped to their CSS variable. */
export const THEME_TOKENS: Record<string, string> = {
  background: "--ug-background",
  foreground: "--ug-foreground",
  card: "--ug-card",
  cardForeground: "--ug-card-foreground",
  popover: "--ug-popover",
  popoverForeground: "--ug-popover-foreground",
  primary: "--ug-primary",
  primaryForeground: "--ug-primary-foreground",
  secondary: "--ug-secondary",
  secondaryForeground: "--ug-secondary-foreground",
  muted: "--ug-muted",
  mutedForeground: "--ug-muted-foreground",
  accent: "--ug-accent",
  accentForeground: "--ug-accent-foreground",
  destructive: "--ug-destructive",
  destructiveForeground: "--ug-destructive-foreground",
  success: "--ug-success",
  successForeground: "--ug-success-foreground",
  warning: "--ug-warning",
  warningForeground: "--ug-warning-foreground",
  border: "--ug-border",
  input: "--ug-input",
  ring: "--ug-ring",
};

const HSL_TRIPLET = /^\d+(\.\d+)? \d+(\.\d+)?% \d+(\.\d+)?%$/;
const SIZE = /^\d*\.?\d+(rem|px)$/;
const HEX = /^#[0-9a-fA-F]{6}$/;
const FONTS: Record<string, string> = {
  Inter: '"Inter Variable", ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
};

/** Applies theme values to `<html>`. Values were checked by Lua; they are checked again before reaching CSS. */
export function applyTheme(theme: ThemeConfig): void {
  const root = document.documentElement;

  root.classList.toggle("dark", theme.mode !== ThemeMode.Light);

  for (const [token, cssVar] of Object.entries(THEME_TOKENS)) {
    const value = theme.colors[token];

    if (typeof value === "string" && HSL_TRIPLET.test(value)) {
      root.style.setProperty(cssVar, value);
    } else {
      root.style.removeProperty(cssVar);
    }
  }

  // An owner primary color replaces the whole brand gradient, so it never ends in the default blue.
  const primary = theme.colors.primary;

  if (typeof primary === "string" && HSL_TRIPLET.test(primary)) {
    root.style.setProperty("--ug-brand-to", primary);
  } else {
    root.style.removeProperty("--ug-brand-to");
  }

  if (SIZE.test(theme.radius)) {
    root.style.setProperty("--ug-radius", theme.radius);
  }

  const font = FONTS[theme.font];

  if (font) {
    root.style.setProperty("--ug-font-sans", font);
  }

  const scale = Number.isFinite(theme.scale) ? Math.min(Math.max(theme.scale, 0.75), 1.5) : 1;

  root.style.setProperty("--ug-scale", String(scale));
}

/** Sets the player's accent over the theme. Runs after `applyTheme`, which resets the primary color. */
export function applyAccent(accent: string | undefined): void {
  const style = accent && HEX.test(accent) ? accentStyle(accent) : undefined;

  for (const [property, value] of Object.entries(style ?? {})) {
    document.documentElement.style.setProperty(property, String(value));
  }
}

interface ConfigStore {
  config: PageConfig;
  setConfig: (config: PageConfig) => void;
}

export const useConfigStore = create<ConfigStore>((set) => ({
  config: DEFAULT_CONFIG,
  setConfig: (config) => {
    applyTheme(config.theme);
    applyAccent(config.accent);
    set({ config });
  },
}));

/** Merges a config from Lua over the defaults, so a missing field never breaks a component. */
export function readConfig(payload: unknown): PageConfig {
  const input = (typeof payload === "object" && payload !== null ? payload : {}) as Partial<PageConfig>;

  return {
    theme: { ...DEFAULT_CONFIG.theme, ...input.theme, colors: { ...input.theme?.colors } },
    settings: { ...DEFAULT_CONFIG.settings, ...input.settings },
    labels: { ...DEFAULT_CONFIG.labels, ...input.labels },
    locale: typeof input.locale === "string" ? input.locale : DEFAULT_CONFIG.locale,
    ...(typeof input.accent === "string" ? { accent: input.accent } : {}),
  };
}

applyTheme(DEFAULT_CONFIG.theme);
