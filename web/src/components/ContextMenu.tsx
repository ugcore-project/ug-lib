/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { useEffect, useRef } from "react";
import { ChevronLeft, ChevronRight, X } from "lucide-react";
import { Surface } from "@/components/ui/Surface";
import { Text } from "@/components/ui/Text";
import { Markup } from "@/components/Markup";
import { backgroundStyle, textColorStyle, type ColorValue } from "@/lib/accent";
import { cn } from "@/lib/cn";
import { UG_ICONS } from "@/lib/icons";
import { isEnvBrowser, sendClose, sendResolve } from "@/lib/nui";
import { positionClasses } from "@/lib/position";
import { useConfigStore } from "@/store/configStore";
import { useLayerStore } from "@/store/layerStore";
import type { Icon, Position } from "@/types/enums";
import type { LayerProps } from "@/components/registry";

/** Built and checked by Lua: see client/ui/context.lua. */
export interface ContextItem {
  title: string;
  description?: string;
  icon?: Icon;
  iconColor?: ColorValue;
  image?: string;
  disabled?: boolean;
  readOnly?: boolean;
  progress?: number;
  colorScheme?: ColorValue;
  arrow?: boolean;
  metadata?: { label: string; value: string | number }[];
  submenu?: boolean;
}

export interface ContextPayload {
  title: string;
  items: ContextItem[];
  canBack: boolean;
  canClose: boolean;
  position: Position;
  color?: ColorValue;
}

/** The answer for the back button. Items answer their 1-based index. */
export const BACK = 0;

function Item({ item, onChoose }: { item: ContextItem; onChoose: () => void }) {
  const IconComponent = item.icon ? UG_ICONS[item.icon] : undefined;
  const clickable = !item.disabled && !item.readOnly;

  return (
    <div className="group relative">
      <button
        type="button"
        disabled={item.disabled}
        aria-disabled={!clickable}
        onClick={clickable ? onChoose : undefined}
        className={cn(
          "flex w-full items-center gap-3 rounded-md px-3 py-2 text-left transition-colors",
          clickable && "hover:bg-accent",
          item.disabled && "cursor-not-allowed opacity-50",
          item.readOnly && "cursor-default",
        )}
      >
        {item.image && <img src={item.image} alt="" className="h-10 w-10 shrink-0 rounded object-cover" />}
        {IconComponent && <IconComponent size={18} className="shrink-0 text-primary" style={textColorStyle(item.iconColor)} aria-hidden="true" />}
        <div className="min-w-0 flex-1">
          <Text as="div" variant="small" className="font-medium text-foreground">
            <Markup text={item.title} />
          </Text>
          {item.description && (
            <Text as="div" variant="small" className="text-muted-foreground">
              <Markup text={item.description} />
            </Text>
          )}
          {item.progress !== undefined && (
            <div className="mt-1.5 h-1 w-full overflow-hidden rounded-full bg-white/10">
              <div className="h-full rounded-full bg-primary" style={{ ...backgroundStyle(item.colorScheme), width: `${Math.min(Math.max(item.progress, 0), 100)}%` }} />
            </div>
          )}
        </div>
        {item.arrow && <ChevronRight size={16} className="shrink-0 text-muted-foreground" aria-hidden="true" />}
      </button>
      {item.metadata && item.metadata.length > 0 && (
        <div className="pointer-events-none absolute right-full top-0 z-10 mr-2 hidden w-48 rounded-md border border-border bg-popover p-2 text-xs text-popover-foreground shadow-ug-md group-hover:block">
          {item.metadata.map((entry, index) => (
            <div key={index} className="flex justify-between gap-2">
              <span className="text-muted-foreground">{entry.label}</span>
              <span className="truncate font-medium">{String(entry.value)}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

/** A clickable menu with submenus. Answers once: an item index, 0 for back, or a close. */
export function ContextMenu({ id, payload, exiting }: LayerProps) {
  const menu = payload as ContextPayload;
  const labels = useConfigStore((state) => state.config.labels);
  const answered = useRef(false);

  const finish = (send: () => Promise<boolean>) => {
    if (answered.current) {
      return;
    }

    answered.current = true;
    void send();

    // Lua closes the layer in game. The browser preview has no Lua.
    if (isEnvBrowser()) {
      useLayerStore.getState().close(id);
    }
  };

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape" && menu.canClose) {
        event.preventDefault();
        finish(() => sendClose(id));
      }
    };

    window.addEventListener("keydown", onKey);

    return () => window.removeEventListener("keydown", onKey);
    // The menu does not change while open: a new one is a new layer.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className={cn(positionClasses(menu.position), "p-8")}>
      <Surface
        variant="glass"
        padding="sm"
        role="menu"
        aria-label={menu.title}
        className={cn("pointer-events-auto flex max-h-[80vh] w-80 flex-col", exiting ? "animate-ug-scale-out" : "animate-ug-scale-in")}
      >
        <div className="flex items-center gap-1 px-2 pb-2 pt-1">
          {menu.canBack && (
            <button type="button" aria-label={labels.back} className="rounded-md p-1 text-muted-foreground hover:bg-accent" onClick={() => finish(() => sendResolve(id, BACK))}>
              <ChevronLeft size={18} />
            </button>
          )}
          <Text as="h2" variant="h3" className="min-w-0 flex-1 truncate">
            <Markup text={menu.title} />
          </Text>
          {menu.canClose && (
            <button type="button" aria-label={labels.close} className="rounded-md p-1 text-muted-foreground hover:bg-accent" onClick={() => finish(() => sendClose(id))}>
              <X size={16} />
            </button>
          )}
        </div>
        <div className="overflow-y-auto">
          {menu.items.map((item, index) => (
            <Item key={index} item={item} onChoose={() => finish(() => sendResolve(id, index + 1))} />
          ))}
        </div>
      </Surface>
    </div>
  );
}
