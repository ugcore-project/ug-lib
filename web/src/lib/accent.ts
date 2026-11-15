/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import type { CSSProperties } from "react";
import { Color } from "@/types/enums";

/** A `Color` token or a `#rrggbb` hex. Lua checked it; it is checked again before reaching CSS. */
export type ColorValue = Color | string;

interface Resolved {
  /** Usable inside `hsl()`: a triplet or a `var()` of one. */
  color: string;
  foreground: string;
}

const HEX = /^#[0-9a-fA-F]{6}$/;
const LIGHT_TEXT = "210 40% 98%";
const DARK_TEXT = "222.2 47.4% 11.2%";

const TOKENS: Record<Color, Resolved> = {
  [Color.Primary]: { color: "var(--ug-primary)", foreground: "var(--ug-primary-foreground)" },
  [Color.Success]: { color: "var(--ug-success)", foreground: "var(--ug-success-foreground)" },
  [Color.Warning]: { color: "var(--ug-warning)", foreground: "var(--ug-warning-foreground)" },
  [Color.Destructive]: { color: "var(--ug-destructive)", foreground: "var(--ug-destructive-foreground)" },
  [Color.Muted]: { color: "var(--ug-muted-foreground)", foreground: "var(--ug-background)" },
};

function isToken(value: string): value is Color {
  return Object.prototype.hasOwnProperty.call(TOKENS, value);
}

/** `#rrggbb` to an HSL triplet, with dark or light text picked by luminance. */
export function hexToTriplet(hex: string): Resolved {
  const r = parseInt(hex.slice(1, 3), 16) / 255;
  const g = parseInt(hex.slice(3, 5), 16) / 255;
  const b = parseInt(hex.slice(5, 7), 16) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const lightness = (max + min) / 2;
  const delta = max - min;
  let hue = 0;
  let saturation = 0;

  if (delta !== 0) {
    saturation = delta / (1 - Math.abs(2 * lightness - 1));

    if (max === r) {
      hue = ((g - b) / delta) % 6;
    } else if (max === g) {
      hue = (b - r) / delta + 2;
    } else {
      hue = (r - g) / delta + 4;
    }

    hue = (hue * 60 + 360) % 360;
  }

  const luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  const round = (value: number) => Math.round(value * 10) / 10;

  return {
    color: `${round(hue)} ${round(saturation * 100)}% ${round(lightness * 100)}%`,
    foreground: luminance > 0.55 ? DARK_TEXT : LIGHT_TEXT,
  };
}

function resolve(color: ColorValue | undefined): Resolved | undefined {
  if (typeof color !== "string") {
    return undefined;
  }

  if (isToken(color)) {
    return TOKENS[color];
  }

  return HEX.test(color) ? hexToTriplet(color) : undefined;
}

/** Replaces the primary color inside one layer, so every `primary` class in it follows. */
export function accentStyle(color: ColorValue | undefined): CSSProperties | undefined {
  const resolved = resolve(color);

  if (!resolved) {
    return undefined;
  }

  return {
    "--ug-primary": resolved.color,
    "--ug-primary-foreground": resolved.foreground,
    "--ug-ring": resolved.color,
    "--ug-brand-to": resolved.color,
  } as CSSProperties;
}

/** Text color for an icon. */
export function textColorStyle(color: ColorValue | undefined): CSSProperties | undefined {
  const resolved = resolve(color);

  return resolved ? { color: `hsl(${resolved.color})` } : undefined;
}

/** Background color for a bar. */
export function backgroundStyle(color: ColorValue | undefined): CSSProperties | undefined {
  const resolved = resolve(color);

  return resolved ? { backgroundColor: `hsl(${resolved.color})` } : undefined;
}
