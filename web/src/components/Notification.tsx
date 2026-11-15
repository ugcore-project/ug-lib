/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { AlertTriangle, CheckCircle2, Info, XCircle } from "lucide-react";
import { Surface } from "@/components/ui/Surface";
import { Text } from "@/components/ui/Text";
import { Markup } from "@/components/Markup";
import { accentStyle, type ColorValue } from "@/lib/accent";
import { cn } from "@/lib/cn";
import { UG_ICONS } from "@/lib/icons";
import { NotifyStyle, NotifyType, type Icon, type Position } from "@/types/enums";

/** Built and checked by Lua: see client/ui/notify.lua. */
export interface NotifyPayload {
  message: string;
  title?: string;
  type: NotifyType;
  style: NotifyStyle;
  position: Position;
  /** Milliseconds, 0 stays until Lua closes it. Lua owns the timer: the bar only shows it. */
  duration: number;
  icon?: Icon;
  /** Replaces the color of `type`. */
  color?: ColorValue;
  /** Changes on every show, so the timer bar restarts. */
  stamp: number;
}

const TYPES = {
  [NotifyType.Info]: { Icon: Info, accent: "text-primary", bar: "bg-primary", tint: "bg-primary/15", edge: "bg-primary" },
  [NotifyType.Success]: { Icon: CheckCircle2, accent: "text-success", bar: "bg-success", tint: "bg-success/15", edge: "bg-success" },
  [NotifyType.Warning]: { Icon: AlertTriangle, accent: "text-warning", bar: "bg-warning", tint: "bg-warning/15", edge: "bg-warning" },
  [NotifyType.Error]: { Icon: XCircle, accent: "text-destructive", bar: "bg-destructive", tint: "bg-destructive/15", edge: "bg-destructive" },
} as const;

interface VariantProps {
  payload: NotifyPayload;
  look: (typeof TYPES)[NotifyType];
  IconComponent: typeof Info;
  animation: string;
}

function TimerBar({ duration, stamp, bar, className }: { duration: number; stamp: number; bar: string; className?: string }) {
  if (duration <= 0) {
    return null;
  }

  return (
    <div className={cn("h-0.5 w-full bg-white/5", className)}>
      <div key={stamp} className={cn("h-full origin-left", bar)} style={{ animation: `ug-notification-shrink ${duration}ms linear forwards` }} />
    </div>
  );
}

function Toast({ payload, look, IconComponent, animation }: VariantProps) {
  return (
    <Surface variant="glass" padding="none" className={cn("relative w-80 overflow-hidden", animation)}>
      <div className="flex gap-3 p-3">
        <IconComponent size={18} className={cn("mt-0.5 shrink-0", look.accent)} aria-hidden="true" />
        <div className="min-w-0 flex-1">
          {payload.title && (
            <Text as="div" variant="h3" className="truncate">
              <Markup text={payload.title} />
            </Text>
          )}
          <Text as="div" variant={payload.title ? "muted" : "body"} className="break-words">
            <Markup text={payload.message} />
          </Text>
        </div>
      </div>
      <TimerBar duration={payload.duration} stamp={payload.stamp} bar={look.bar} />
    </Surface>
  );
}

function Compact({ payload, look, IconComponent, animation }: VariantProps) {
  return (
    <Surface variant="glass" padding="none" className={cn("relative flex w-64 items-center gap-2 overflow-hidden pr-3", animation)}>
      <div className={cn("w-0.5 self-stretch", look.edge)} />
      <IconComponent size={14} className={cn("my-2 shrink-0", look.accent)} aria-hidden="true" />
      <Text as="div" variant="small" className="my-2 truncate">
        {payload.title && (
          <span className="font-semibold">
            <Markup text={payload.title} />:{" "}
          </span>
        )}
        <Markup text={payload.message} />
      </Text>
      <TimerBar duration={payload.duration} stamp={payload.stamp} bar={look.bar} className="absolute inset-x-0 bottom-0" />
    </Surface>
  );
}

function Banner({ payload, look, IconComponent, animation }: VariantProps) {
  return (
    <Surface variant="glass" padding="none" className={cn("relative max-w-[36rem] overflow-hidden", animation)}>
      <div className="flex items-center gap-3 px-4 py-2.5">
        <div className={cn("flex h-8 w-8 shrink-0 items-center justify-center rounded-full", look.tint)}>
          <IconComponent size={18} className={look.accent} aria-hidden="true" />
        </div>
        <div className="min-w-0 flex-1">
          {payload.title && (
            <Text as="div" variant="h3" className="truncate">
              <Markup text={payload.title} />
            </Text>
          )}
          <Text as="div" variant={payload.title ? "muted" : "body"} className="break-words">
            <Markup text={payload.message} />
          </Text>
        </div>
      </div>
      <TimerBar duration={payload.duration} stamp={payload.stamp} bar={look.bar} />
    </Surface>
  );
}

/** One notification. It never answers: Lua closes it when its timer ends. */
export function Notification({ payload, exiting }: { payload: NotifyPayload; exiting: boolean }) {
  const look = payload.color ? TYPES[NotifyType.Info] : (TYPES[payload.type] ?? TYPES[NotifyType.Info]);
  const IconComponent = (payload.icon && UG_ICONS[payload.icon]) || look.Icon;
  const props: VariantProps = { payload, look, IconComponent, animation: exiting ? "animate-ug-fade-out" : "animate-ug-slide-up" };

  const Variant = payload.style === NotifyStyle.Compact ? Compact : payload.style === NotifyStyle.Banner ? Banner : Toast;

  return (
    <div className="contents" style={accentStyle(payload.color)}>
      <Variant {...props} />
    </div>
  );
}
