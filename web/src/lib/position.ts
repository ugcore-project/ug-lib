/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import type { Position } from "@/types/enums";

/** Vertical half of an anchor. */
export function verticalOf(position: Position): "top" | "center" | "bottom" {
  if (position.startsWith("top")) {
    return "top";
  }

  if (position.startsWith("bottom")) {
    return "bottom";
  }

  return "center";
}

/** Horizontal half of an anchor. */
export function horizontalOf(position: Position): "left" | "center" | "right" {
  if (position.endsWith("-left")) {
    return "left";
  }

  if (position.endsWith("-right")) {
    return "right";
  }

  return "center";
}

// Full class names: Tailwind only generates classes it finds written out in source.
const JUSTIFY = { top: "justify-start", center: "justify-center", bottom: "justify-end" } as const;
const ALIGN = { left: "items-start", center: "items-center", right: "items-end" } as const;

/** A full-screen, click-through flex container that places its children at the anchor. */
export function positionClasses(position: Position): string {
  return `pointer-events-none fixed inset-0 flex flex-col p-6 ${JUSTIFY[verticalOf(position)]} ${ALIGN[horizontalOf(position)]}`;
}
