/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { Surface } from "@/components/ui/Surface";
import { Text } from "@/components/ui/Text";
import { Markup } from "@/components/Markup";
import type { ColorValue } from "@/lib/accent";
import { cn } from "@/lib/cn";
import { UG_ICONS } from "@/lib/icons";
import { positionClasses, verticalOf } from "@/lib/position";
import { TextUIStyle, type Icon, type Position } from "@/types/enums";
import type { LayerProps } from "@/components/registry";

/** Built and checked by Lua: see client/ui/textui.lua. */
export interface TextUIPayload {
  text: string;
  icon?: Icon;
  style: TextUIStyle;
  key?: string;
  position: Position;
  color?: ColorValue;
}

interface VariantProps {
  text: string;
  keyCap: string | undefined;
  IconComponent: (typeof UG_ICONS)[Icon] | undefined;
  animation: string;
}

function Pill({ text, IconComponent, animation }: VariantProps) {
  return (
    <Surface variant="glass" padding="sm" className={cn("flex items-center gap-2 rounded-full px-4", animation)}>
      {IconComponent && <IconComponent size={16} className="shrink-0 text-primary" aria-hidden="true" />}
      <Text variant="small" className="whitespace-nowrap text-foreground">
        <Markup text={text} />
      </Text>
    </Surface>
  );
}

function Minimal({ text, IconComponent, animation }: VariantProps) {
  return (
    <div className={cn("flex items-center gap-2 drop-shadow-[0_1px_3px_rgba(0,0,0,0.9)]", animation)}>
      {IconComponent && <IconComponent size={16} className="shrink-0 text-primary" aria-hidden="true" />}
      <Text variant="small" className="whitespace-nowrap font-medium text-foreground">
        <Markup text={text} />
      </Text>
    </div>
  );
}

function Keybind(props: VariantProps) {
  const { text, keyCap, IconComponent, animation } = props;

  if (!keyCap) {
    return <Pill {...props} />;
  }

  return (
    <Surface variant="glass" padding="none" className={cn("flex items-center gap-2.5 rounded-full py-1.5 pl-1.5 pr-4", animation)}>
      <kbd className="flex h-7 min-w-[1.75rem] items-center justify-center rounded-full bg-primary px-2 font-sans text-xs font-semibold uppercase text-primary-foreground">
        {keyCap}
      </kbd>
      {IconComponent && <IconComponent size={16} className="shrink-0 text-primary" aria-hidden="true" />}
      <Text variant="small" className="whitespace-nowrap text-foreground">
        <Markup text={text} />
      </Text>
    </Surface>
  );
}

function Card({ text, keyCap, IconComponent, animation }: VariantProps) {
  return (
    <Surface variant="solid" padding="none" className={cn("flex items-center gap-3 overflow-hidden pr-4", animation)}>
      <div className="w-1 self-stretch bg-gradient-to-b from-primary to-brand-to" />
      {IconComponent && <IconComponent size={18} className="my-3 shrink-0 text-primary" aria-hidden="true" />}
      <Text variant="small" className="my-3 whitespace-nowrap text-foreground">
        <Markup text={text} />
      </Text>
      {keyCap && (
        <kbd className="rounded border border-border bg-secondary px-1.5 py-0.5 font-sans text-[0.65rem] font-semibold uppercase text-secondary-foreground">
          {keyCap}
        </kbd>
      )}
    </Surface>
  );
}

const VARIANTS = {
  [TextUIStyle.Pill]: Pill,
  [TextUIStyle.Minimal]: Minimal,
  [TextUIStyle.Keybind]: Keybind,
  [TextUIStyle.Card]: Card,
} as const;

/** A prompt drawn in place, for the settings preview. */
export function TextUIPreview({ text, style, keyCap }: { text: string; style: TextUIStyle; keyCap?: string }) {
  const Variant = VARIANTS[style] ?? Pill;

  return <Variant text={text} keyCap={keyCap} IconComponent={undefined} animation="" />;
}

/** The single text prompt. It never answers. */
export function TextUI({ payload, exiting }: LayerProps) {
  const prompt = payload as TextUIPayload;
  const Variant = VARIANTS[prompt.style] ?? Pill;

  return (
    <div className={cn(positionClasses(prompt.position), "px-8 py-28")}>
      <Variant
        text={prompt.text}
        keyCap={prompt.key}
        IconComponent={prompt.icon ? UG_ICONS[prompt.icon] : undefined}
        animation={exiting ? "animate-ug-fade-out" : verticalOf(prompt.position) === "top" ? "animate-ug-drop-in" : "animate-ug-rise-in"}
      />
    </div>
  );
}
