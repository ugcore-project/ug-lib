/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { useEffect, useRef, useState } from "react";
import { ChevronLeft, MoreHorizontal, X } from "lucide-react";
import { Text } from "@/components/ui/Text";
import { Markup } from "@/components/Markup";
import { textColorStyle, type ColorValue } from "@/lib/accent";
import { cn } from "@/lib/cn";
import { UG_ICONS } from "@/lib/icons";
import { isEnvBrowser, sendClose, sendResolve } from "@/lib/nui";
import { useConfigStore } from "@/store/configStore";
import { useLayerStore } from "@/store/layerStore";
import { pageCount, pageSlots, type RadialItem, type RadialSlot } from "@/lib/radialPages";
import type { LayerProps } from "@/components/registry";

export interface RadialPayload {
  title?: string;
  color?: ColorValue;
  items: RadialItem[];
}

const SIZE = 248;
const CENTER = SIZE / 2;
const ITEM_RADIUS = 88;
const ITEM_SIZE = 52;
const HUB_RADIUS = 52;

interface Level {
  label: string;
  items: RadialItem[];
  /** 1-based index of this level in its parent, empty for the root. */
  path: number[];
}

/** A radial menu. Answers once with the path of 1-based indexes to a leaf, or closes. */
export function Radial({ id, payload, exiting }: LayerProps) {
  const radial = payload as RadialPayload;
  const labels = useConfigStore((state) => state.config.labels);
  const [stack, setStack] = useState<Level[]>([{ label: radial.title ?? "", items: radial.items, path: [] }]);
  const [page, setPage] = useState(0);
  const [highlighted, setHighlighted] = useState(0);
  const answered = useRef(false);
  const level = stack[stack.length - 1] ?? stack[0]!;
  const slots = pageSlots(level.items, page);
  const pages = pageCount(level.items);

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

  const close = () => finish(() => sendClose(id));

  const back = () => {
    if (stack.length > 1) {
      setStack((previous) => previous.slice(0, -1));
      setPage(0);
      setHighlighted(0);
    }
  };

  const activate = (slot: RadialSlot | undefined) => {
    if (!slot) {
      return;
    }

    if (slot.index === -1) {
      setPage((previous) => (previous + 1) % pages);
      setHighlighted(0);

      return;
    }

    const item = slot.item;

    if (!item || item.disabled) {
      return;
    }

    const path = [...level.path, slot.index + 1];

    if (item.items) {
      setStack((previous) => [...previous, { label: item.label, items: item.items ?? [], path }]);
      setPage(0);
      setHighlighted(0);

      return;
    }

    finish(() => sendResolve(id, path));
  };

  const keyHandler = useRef<(event: KeyboardEvent) => void>(() => undefined);

  keyHandler.current = (event: KeyboardEvent) => {
    switch (event.key) {
      case "ArrowRight":
      case "ArrowDown":
        event.preventDefault();
        setHighlighted((previous) => (previous + 1) % slots.length);
        break;
      case "ArrowLeft":
      case "ArrowUp":
        event.preventDefault();
        setHighlighted((previous) => (previous - 1 + slots.length) % slots.length);
        break;
      case "Enter":
      case " ":
        event.preventDefault();
        activate(slots[highlighted]);
        break;
      case "Backspace":
        event.preventDefault();
        back();
        break;
      case "Escape":
        event.preventDefault();
        close();
        break;
    }
  };

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => keyHandler.current(event);

    window.addEventListener("keydown", onKey);

    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const hovered = slots[highlighted];
  const hubLabel = hovered?.index === -1 ? `${page + 1}/${pages}` : (hovered?.item?.label ?? level.label);

  return (
    <div className="pointer-events-auto fixed inset-0 flex items-center justify-center p-4">
      <div className={cn("absolute inset-0 bg-background/60", exiting ? "animate-ug-fade-out" : "animate-ug-fade-in")} onClick={close} aria-hidden="true" />
      <div className={cn("relative z-10 flex flex-col items-center gap-3", exiting ? "animate-ug-scale-out" : "animate-ug-scale-in")}>
        <div className="flex items-center gap-2">
          {stack.length > 1 && (
            <button type="button" onClick={back} aria-label={labels.back} className="rounded-full bg-card/90 p-2 text-muted-foreground shadow-ug-sm hover:bg-accent hover:text-foreground">
              <ChevronLeft size={16} />
            </button>
          )}
          {level.label && (
            <Text variant="h3" className="text-foreground/90">
              <Markup text={level.label} />
            </Text>
          )}
          <button type="button" onClick={close} aria-label={labels.close} className="rounded-full bg-card/90 p-2 text-muted-foreground shadow-ug-sm hover:bg-accent hover:text-foreground">
            <X size={16} />
          </button>
        </div>
        <div role="menu" aria-label={level.label || "Radial menu"} className="relative" style={{ width: SIZE, height: SIZE }}>
          <div className="absolute inset-0 rounded-full border border-white/10 bg-card/80 shadow-ug-lg" />
          {slots.map((slot, position) => {
            const angle = (2 * Math.PI * position) / slots.length - Math.PI / 2;
            const x = CENTER + ITEM_RADIUS * Math.cos(angle) - ITEM_SIZE / 2;
            const y = CENTER + ITEM_RADIUS * Math.sin(angle) - ITEM_SIZE / 2;
            const item = slot.item;
            const ItemIcon = item?.icon ? UG_ICONS[item.icon] : undefined;
            const active = position === highlighted && !item?.disabled;

            return (
              <button
                key={`${page}-${slot.index}`}
                type="button"
                role="menuitem"
                aria-label={item ? item.label : "More"}
                disabled={item?.disabled}
                onMouseEnter={() => setHighlighted(position)}
                onClick={() => activate(slot)}
                style={{
                  left: x,
                  top: y,
                  width: ITEM_SIZE,
                  height: ITEM_SIZE,
                  animation: exiting ? undefined : `ug-pop-in 220ms cubic-bezier(0.34, 1.56, 0.64, 1) ${position * 25}ms both`,
                }}
                className={cn(
                  "absolute flex items-center justify-center rounded-full border transition-colors disabled:cursor-not-allowed disabled:opacity-40",
                  active ? "border-primary bg-gradient-to-r from-primary to-brand-to text-primary-foreground" : "border-white/10 bg-card/90 text-foreground hover:bg-accent",
                )}
              >
                {!item ? (
                  <MoreHorizontal size={20} aria-hidden="true" />
                ) : ItemIcon ? (
                  <ItemIcon size={20} style={active ? undefined : textColorStyle(item.iconColor)} aria-hidden="true" />
                ) : (
                  <span className="text-xs font-medium">{item.label.slice(0, 1)}</span>
                )}
              </button>
            );
          })}
          <div className="absolute flex items-center justify-center rounded-full bg-card text-center shadow-ug-md" style={{ inset: CENTER - HUB_RADIUS }}>
            <Text variant="small" className="line-clamp-2 px-3 text-muted-foreground">
              <Markup text={hubLabel} />
            </Text>
          </div>
        </div>
      </div>
    </div>
  );
}
