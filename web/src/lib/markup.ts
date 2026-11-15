/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Formatted text without HTML: `**bold**`, `*italic*`, and `~token~` to color the rest of the text
// with a theme color, until `~reset~` or another color. Anything else stays plain text.

export const MARKUP_COLORS = ["primary", "success", "warning", "destructive", "muted"] as const;

export type MarkupColor = (typeof MARKUP_COLORS)[number];

export interface MarkupSegment {
  text: string;
  bold: boolean;
  italic: boolean;
  color: MarkupColor | null;
}

const TOKEN = /(\*\*|\*|~[a-z]+~)/g;
const MAX_LENGTH = 4096;

function isColor(name: string): name is MarkupColor {
  return (MARKUP_COLORS as readonly string[]).includes(name);
}

/** Splits text into styled segments. Unknown `~tags~` and unbalanced markers stay as text. */
export function parseMarkup(input: string): MarkupSegment[] {
  const text = input.length > MAX_LENGTH ? input.slice(0, MAX_LENGTH) : input;
  const parts = text.split(TOKEN);
  const segments: MarkupSegment[] = [];
  let bold = false;
  let italic = false;
  let color: MarkupColor | null = null;

  const boldCount = parts.filter((part) => part === "**").length;
  const italicCount = parts.filter((part) => part === "*").length;
  let boldLeft = boldCount - (boldCount % 2);
  let italicLeft = italicCount - (italicCount % 2);

  const push = (value: string) => {
    if (value === "") {
      return;
    }

    const last = segments[segments.length - 1];

    if (last && last.bold === bold && last.italic === italic && last.color === color) {
      last.text += value;
    } else {
      segments.push({ text: value, bold, italic, color });
    }
  };

  for (const part of parts) {
    if (part === "**" && boldLeft > 0) {
      bold = !bold;
      boldLeft -= 1;
    } else if (part === "*" && italicLeft > 0) {
      italic = !italic;
      italicLeft -= 1;
    } else if (part.startsWith("~") && part.endsWith("~") && part.length > 2) {
      const name = part.slice(1, -1);

      if (name === "reset") {
        color = null;
      } else if (isColor(name)) {
        color = name;
      } else {
        push(part);
      }
    } else {
      push(part);
    }
  }

  return segments;
}
