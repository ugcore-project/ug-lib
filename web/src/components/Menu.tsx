/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { useEffect, useRef } from "react";
import { Check, ChevronLeft, ChevronRight } from "lucide-react";
import { Surface } from "@/components/ui/Surface";
import { Text } from "@/components/ui/Text";
import { Markup } from "@/components/Markup";
import { textColorStyle, type ColorValue } from "@/lib/accent";
import { cn } from "@/lib/cn";
import { UG_ICONS } from "@/lib/icons";
import { positionClasses } from "@/lib/position";
import type { Icon, Position } from "@/types/enums";
import type { LayerProps } from "@/components/registry";

/** Built and checked by Lua: see client/ui/menu.lua. */
export interface MenuItem {
  label: string;
  description?: string;
  icon?: Icon;
  iconColor?: ColorValue;
  values?: string[];
  checked?: boolean;
  progress?: number;
  close?: boolean;
}

/** Owned by ug-lib in Lua, which moves it on key presses. Arrays match the items. */
export interface MenuState {
  selected: number;
  /** 1-based value index, 0 for items without values. */
  scroll: number[];
  /** False for items that are not checkboxes. */
  checked: boolean[];
}

export interface MenuPayload {
  title: string;
  position: Position;
  color?: ColorValue;
  items: MenuItem[];
  canClose: boolean;
  disableInput: boolean;
  state: MenuState;
}

/** A keyboard menu. It only draws: Lua owns the keys, the selection and the answers. */
export function Menu({ payload, exiting }: LayerProps) {
  const menu = payload as MenuPayload;
  const selectedRef = useRef<HTMLLIElement>(null);
  const selected = menu.state.selected;
  const current = menu.items[selected - 1];

  useEffect(() => {
    selectedRef.current?.scrollIntoView?.({ block: "nearest" });
  }, [selected]);

  return (
    <div className={positionClasses(menu.position)}>
      <Surface variant="glass" padding="none" className={cn("w-80 overflow-hidden", exiting ? "animate-ug-fade-out" : "animate-ug-slide-up")}>
        <div className="h-0.5 bg-gradient-to-r from-primary to-brand-to" />
        <div className="flex items-center justify-between gap-3 border-b border-border px-4 py-3">
          <Text as="h2" variant="h3" className="truncate text-foreground">
            <Markup text={menu.title} />
          </Text>
          <span className="shrink-0 rounded-md bg-muted px-1.5 py-0.5 text-xs font-medium tabular-nums text-muted-foreground">
            {selected}/{menu.items.length}
          </span>
        </div>
        <ul role="listbox" aria-activedescendant={`menu-item-${selected}`} className="max-h-[60vh] overflow-y-auto py-1">
          {menu.items.map((item, index) => {
            const active = index + 1 === selected;
            const IconComponent = item.icon ? UG_ICONS[item.icon] : undefined;
            const valueIndex = menu.state.scroll[index] ?? 0;

            return (
              <li
                key={index}
                id={`menu-item-${index + 1}`}
                ref={active ? selectedRef : undefined}
                role="option"
                aria-selected={active}
                className={cn(
                  "flex items-center gap-3 px-4 py-2 text-sm",
                  active ? "bg-accent text-accent-foreground shadow-[inset_2px_0_0_hsl(var(--ug-primary))]" : "text-foreground",
                )}
              >
                {IconComponent && <IconComponent
                    size={16}
                    className={cn("shrink-0", active ? "text-primary" : "text-muted-foreground")}
                    style={textColorStyle(item.iconColor)}
                    aria-hidden="true"
                  />}
                <div className="min-w-0 flex-1">
                  <div className="truncate">
                    <Markup text={item.label} />
                  </div>
                  {item.progress !== undefined && (
                    <div className="mt-1 h-1 w-full overflow-hidden rounded-full bg-muted">
                      <div className="h-full rounded-full bg-primary" style={{ width: `${Math.min(Math.max(item.progress, 0), 100)}%` }} />
                    </div>
                  )}
                </div>
                {item.values && valueIndex > 0 && (
                  <span className="flex shrink-0 items-center gap-1 text-xs text-muted-foreground">
                    {active && <ChevronLeft size={14} aria-hidden="true" />}
                    <span className="text-foreground">{item.values[valueIndex - 1]}</span>
                    {active && <ChevronRight size={14} aria-hidden="true" />}
                  </span>
                )}
                {item.checked !== undefined && (
                  <span
                    className={cn(
                      "flex h-4 w-4 shrink-0 items-center justify-center rounded border",
                      menu.state.checked[index] ? "border-primary bg-primary text-primary-foreground" : "border-muted-foreground/70",
                    )}
                    aria-hidden="true"
                  >
                    {menu.state.checked[index] && <Check size={12} />}
                  </span>
                )}
              </li>
            );
          })}
        </ul>
        {current?.description && (
          <div className="border-t border-border px-4 py-2">
            <Text variant="small" className="text-muted-foreground">
              <Markup text={current.description} />
            </Text>
          </div>
        )}
      </Surface>
    </div>
  );
}
