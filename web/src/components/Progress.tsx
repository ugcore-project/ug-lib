/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import type { CSSProperties, ReactNode } from "react";
import { Surface } from "@/components/ui/Surface";
import { Text } from "@/components/ui/Text";
import { Markup } from "@/components/Markup";
import type { ColorValue } from "@/lib/accent";
import { cn } from "@/lib/cn";
import { positionClasses, verticalOf } from "@/lib/position";
import { ProgressStyle, type Position } from "@/types/enums";
import type { LayerProps } from "@/components/registry";

/** Built and checked by Lua: see client/ui/progress.lua. Lua owns the timer; the page only animates it. */
export interface ProgressPayload {
  label?: string;
  duration: number;
  style: ProgressStyle;
  position: Position;
  color?: ColorValue;
  canCancel: boolean;
  stamp: number;
}

const CIRCLE_RADIUS = 26;
const RING_RADIUS = 42;

const circumference = (radius: number) => 2 * Math.PI * radius;

interface VariantProps {
  label: string | undefined;
  duration: number;
  position: Position;
  exiting: boolean;
}

function fillStyle(keyframe: string, duration: number, radius?: number): CSSProperties {
  const style: Record<string, string | number> = { animation: `${keyframe} ${duration}ms linear forwards` };

  if (radius !== undefined) {
    style.strokeDashoffset = circumference(radius);
    style["--ug-progress-circumference"] = circumference(radius);
  }

  return style as CSSProperties;
}

function Slot({ position, children }: { position: Position; children: ReactNode }) {
  return <div className={cn(positionClasses(position), "px-8 py-12")}>{children}</div>;
}

function Label({ label, className }: { label: string | undefined; className?: string }) {
  if (!label) {
    return null;
  }

  return (
    <Text variant="small" className={cn("block text-center text-muted-foreground", className)}>
      <Markup text={label} />
    </Text>
  );
}

function Arc({ radius, strokeWidth, duration }: { radius: number; strokeWidth: number; duration: number }) {
  const size = (radius + strokeWidth) * 2;
  const center = size / 2;

  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="-rotate-90">
      <circle cx={center} cy={center} r={radius} strokeWidth={strokeWidth} className="fill-none stroke-white/10" />
      <circle
        cx={center}
        cy={center}
        r={radius}
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeDasharray={circumference(radius)}
        className="fill-none stroke-primary"
        style={fillStyle("ug-progress-circle-fill", duration, radius)}
      />
    </svg>
  );
}

function Bar({ label, duration, position, exiting }: VariantProps) {
  return (
    <Slot position={position}>
      <Surface variant="glass" padding="sm" className={cn("w-72", exiting ? "animate-ug-slide-down" : "animate-ug-slide-up")}>
        <Label label={label} className="mb-1.5" />
        <div className="h-1.5 w-full overflow-hidden rounded-full bg-white/10">
          <div className="h-full origin-left rounded-full bg-gradient-to-r from-primary to-brand-to" style={fillStyle("ug-progress-fill", duration)} />
        </div>
      </Surface>
    </Slot>
  );
}

function Circle({ label, duration, position, exiting }: VariantProps) {
  return (
    <Slot position={position}>
      <Surface variant="glass" padding="md" className={cn("flex flex-col items-center gap-2", exiting ? "animate-ug-slide-down" : "animate-ug-slide-up")}>
        <Arc radius={CIRCLE_RADIUS} strokeWidth={6} duration={duration} />
        <Label label={label} />
      </Surface>
    </Slot>
  );
}

function Ring({ label, duration, position, exiting }: VariantProps) {
  return (
    <div className={cn(positionClasses(position), "gap-2 px-8 py-12", exiting ? "animate-ug-fade-out" : "animate-ug-fade-in")}>
      <Arc radius={RING_RADIUS} strokeWidth={4} duration={duration} />
      <Label label={label} className="text-foreground drop-shadow-[0_1px_2px_rgba(0,0,0,0.9)]" />
    </div>
  );
}

function Minimal({ label, duration, position, exiting }: VariantProps) {
  const atTop = verticalOf(position) === "top";

  return (
    <div
      className={cn(
        "pointer-events-none fixed inset-x-0 flex flex-col",
        atTop ? "top-0 flex-col-reverse" : "bottom-0",
        exiting ? "animate-ug-fade-out" : "animate-ug-fade-in",
      )}
    >
      <Label label={label} className={cn("text-foreground drop-shadow-[0_1px_2px_rgba(0,0,0,0.9)]", atTop ? "mt-1" : "mb-1")} />
      <div className="h-0.5 w-full bg-white/10">
        <div className="h-full origin-left bg-gradient-to-r from-primary to-brand-to" style={fillStyle("ug-progress-fill", duration)} />
      </div>
    </div>
  );
}

const VARIANTS = {
  [ProgressStyle.Bar]: Bar,
  [ProgressStyle.Circle]: Circle,
  [ProgressStyle.Ring]: Ring,
  [ProgressStyle.Minimal]: Minimal,
} as const;

/** A progress indicator. It never answers. */
export function Progress({ payload, exiting }: LayerProps) {
  const progress = payload as ProgressPayload;
  const Variant = VARIANTS[progress.style] ?? Bar;

  return <Variant key={progress.stamp} label={progress.label} duration={Math.max(progress.duration, 0)} position={progress.position} exiting={exiting} />;
}
