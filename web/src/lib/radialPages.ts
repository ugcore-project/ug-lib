/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Paging of radial rings. Lua sends every item; the page splits a crowded ring.

import type { Icon } from "@/types/enums";

/** Built and checked by Lua: see client/ui/radial.lua. Ids stay in Lua. */
export interface RadialItem {
  label: string;
  icon?: Icon;
  iconColor?: string;
  disabled?: boolean;
  items?: RadialItem[];
}

/** Items shown per ring. A ring with more shows `PAGE_SIZE - 1` items and a "more" button. */
export const PAGE_SIZE = 8;

export interface RadialSlot {
  item: RadialItem | null;
  /** Index in the ring, -1 for the "more" button. */
  index: number;
}

/** The items of one page: all of them, or a slice and a "more" button. */
export function pageSlots(items: RadialItem[], page: number): RadialSlot[] {
  if (items.length <= PAGE_SIZE) {
    return items.map((item, index) => ({ item, index }));
  }

  const perPage = PAGE_SIZE - 1;
  const start = page * perPage;
  const slots: RadialSlot[] = items.slice(start, start + perPage).map((item, offset) => ({ item, index: start + offset }));

  slots.push({ item: null, index: -1 });

  return slots;
}

/** Number of pages of a ring. */
export function pageCount(items: RadialItem[]): number {
  return items.length > PAGE_SIZE ? Math.ceil(items.length / (PAGE_SIZE - 1)) : 1;
}
