/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { useEffect, useRef, useState, type ReactNode } from "react";
import { Check, RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/Button";
import { Surface } from "@/components/ui/Surface";
import { Text } from "@/components/ui/Text";
import { Notification } from "@/components/Notification";
import { TextUIPreview } from "@/components/TextUI";
import { accentStyle } from "@/lib/accent";
import { cn } from "@/lib/cn";
import { horizontalOf, verticalOf } from "@/lib/position";
import { isEnvBrowser, sendClose, sendEvent, sendResolve } from "@/lib/nui";
import { useLayerStore } from "@/store/layerStore";
import { NotifyStyle, NotifyType, Position, ProgressStyle, TextUIStyle, ThemeMode } from "@/types/enums";
import type { LayerProps } from "@/components/registry";

/** Built by Lua only: see client/settings.lua. `values` holds the player's choices, `defaults` the server's. */
export interface SettingsPayload {
  keys: string[];
  values: Record<string, unknown>;
  defaults: Record<string, unknown>;
  labels: Record<string, string>;
  stamp: number;
}

/** Presets for the accent. Any `#rrggbb` is allowed: Lua checks it. */
const ACCENT_PRESETS = ["#8b5cf6", "#3b82f6", "#6366f1", "#a855f7", "#ec4899", "#ef4444", "#f97316", "#f59e0b", "#22c55e", "#14b8a6", "#06b6d4"];

const GRID: Position[] = [
  Position.TopLeft, Position.Top, Position.TopRight,
  Position.CenterLeft, Position.Center, Position.CenterRight,
  Position.BottomLeft, Position.Bottom, Position.BottomRight,
];

/** Each element: its position key, its style key and styles, and the label key. */
const ELEMENTS = [
  { label: "settings.notify", position: "notifyPosition", style: "notifyStyle", styles: Object.values(NotifyStyle) as string[] },
  { label: "settings.textUI", position: "textUIPosition", style: "textUIStyle", styles: Object.values(TextUIStyle) as string[] },
  { label: "settings.progress", position: "progressPosition", style: "progressStyle", styles: Object.values(ProgressStyle) as string[] },
  { label: "settings.menu", position: "menuPosition" },
  { label: "settings.context", position: "contextPosition" },
] as const;

/** Time to wait before sending a dragged color or size, so a drag sends one change. */
const DRAG_DELAY_MS = 150;
const HEX = /^#[0-9a-fA-F]{6}$/;

function Segmented({ options, value, onChange, label }: { options: { value: string; label: string }[]; value: string; onChange: (value: string) => void; label: string }) {
  return (
    <div role="radiogroup" aria-label={label} className="inline-flex flex-wrap gap-1 rounded-md bg-muted p-1">
      {options.map((option) => (
        <button
          key={option.value}
          type="button"
          role="radio"
          aria-checked={option.value === value}
          onClick={() => onChange(option.value)}
          className={cn(
            "rounded px-2.5 py-1 text-xs font-medium transition-colors",
            option.value === value ? "bg-primary text-primary-foreground shadow-ug-sm" : "text-muted-foreground hover:text-foreground",
          )}
        >
          {option.label}
        </button>
      ))}
    </div>
  );
}

function PositionGrid({ value, onChange, label, labels }: { value: string; onChange: (value: Position) => void; label: string; labels: Record<string, string> }) {
  return (
    <div role="radiogroup" aria-label={label} className="grid w-20 shrink-0 grid-cols-3 gap-1 rounded-md bg-muted p-1">
      {GRID.map((position) => (
        <button
          key={position}
          type="button"
          role="radio"
          aria-checked={position === value}
          aria-label={labels[`positions.${position}`] ?? position}
          title={labels[`positions.${position}`] ?? position}
          onClick={() => onChange(position)}
          className={cn("aspect-square rounded-sm transition-colors", position === value ? "bg-primary" : "bg-background/60 hover:bg-accent")}
        />
      ))}
    </div>
  );
}

function Row({ title, onDefault, isDefault, defaultLabel, children }: { title: string; onDefault: () => void; isDefault: boolean; defaultLabel: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-2 py-3">
      <div className="flex items-center justify-between gap-2">
        <Text variant="small" className="font-medium text-foreground">
          {title}
        </Text>
        <button
          type="button"
          onClick={onDefault}
          disabled={isDefault}
          className="text-xs text-muted-foreground hover:text-foreground disabled:cursor-default disabled:opacity-40"
        >
          {defaultLabel}
        </button>
      </div>
      {children}
    </div>
  );
}

const JUSTIFY = { top: "justify-start", center: "justify-center", bottom: "justify-end" } as const;
const ALIGN = { left: "items-start", center: "items-center", right: "items-end" } as const;

/** A small screen with every element at its anchor. */
function ScreenPreview({ placed, active, labels }: { placed: { key: string; position: Position; label: string }[]; active: string | undefined; labels: Record<string, string> }) {
  return (
    <div
      aria-label={labels["settings.preview"]}
      className="grid aspect-video w-full grid-cols-3 grid-rows-3 gap-1 overflow-hidden rounded-lg border border-border bg-gradient-to-br from-slate-700/40 via-slate-800/40 to-slate-950/60 p-1.5"
    >
      {GRID.map((position) => (
        <div key={position} className={cn("flex flex-col gap-0.5", JUSTIFY[verticalOf(position)], ALIGN[horizontalOf(position)])}>
          {placed
            .filter((entry) => entry.position === position)
            .map((entry) => (
              <span
                key={entry.key}
                className={cn(
                  "max-w-full truncate rounded px-1 py-0.5 text-[0.6rem] leading-none transition-colors",
                  entry.key === active ? "bg-primary text-primary-foreground" : "bg-card/90 text-muted-foreground",
                )}
              >
                {entry.label}
              </span>
            ))}
        </div>
      ))}
    </div>
  );
}

/** The player settings. Every change is sent at once; Lua checks and saves it, and the page follows. */
export function Settings({ id, payload, exiting }: LayerProps) {
  const settings = payload as SettingsPayload;
  const labels = settings.labels;
  const label = (key: string) => labels[key] ?? key;
  const [values, setValues] = useState<Record<string, unknown>>(settings.values);
  const [active, setActive] = useState<string>();
  const timers = useRef<Record<string, ReturnType<typeof setTimeout>>>({});
  const answered = useRef(false);

  // A reset from Lua sends a new payload.
  useEffect(() => setValues(settings.values), [settings.stamp, settings.values]);

  useEffect(() => {
    const pending = timers.current;

    return () => Object.values(pending).forEach(clearTimeout);
  }, []);

  const has = (key: string) => settings.keys.includes(key);
  const current = (key: string) => (values[key] ?? settings.defaults[key]) as string;

  const change = (key: string, value: unknown, delayed = false) => {
    setValues((previous) => ({ ...previous, [key]: value }));
    clearTimeout(timers.current[key]);

    const send = () => void sendEvent(id, value === undefined ? { key, clear: true } : { key, value });

    if (delayed) {
      timers.current[key] = setTimeout(send, DRAG_DELAY_MS);
    } else {
      send();
    }
  };

  const finish = (send: () => Promise<boolean>) => {
    if (answered.current) {
      return;
    }

    answered.current = true;
    void send();

    if (isEnvBrowser()) {
      useLayerStore.getState().close(id);
    }
  };

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        finish(() => sendClose(id));
      }
    };

    window.addEventListener("keydown", onKey);

    return () => window.removeEventListener("keydown", onKey);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const resetRow = (key: string) => ({ onDefault: () => change(key, undefined), isDefault: values[key] === undefined, defaultLabel: label("settings.default") });
  const accent = typeof values.accent === "string" && HEX.test(values.accent) ? values.accent : undefined;
  const scale = typeof values.scale === "number" ? values.scale : Number(settings.defaults.scale ?? 1);
  const placed = ELEMENTS.filter((element) => has(element.position)).map((element) => ({
    key: element.position as string,
    position: current(element.position) as Position,
    label: label(element.label),
  }));

  return (
    <div className="pointer-events-auto fixed inset-0 flex items-center justify-center p-4">
      <div className={cn("absolute inset-0 bg-background/60", exiting ? "animate-ug-fade-out" : "animate-ug-fade-in")} aria-hidden="true" />
      <Surface
        variant="solid"
        padding="none"
        role="dialog"
        aria-label={label("settings.title")}
        // The chosen accent shows here at once; Lua then restyles every other component.
        style={accentStyle(accent)}
        className={cn("relative flex max-h-[88vh] w-[54rem] max-w-full flex-col", exiting ? "animate-ug-scale-out" : "animate-ug-scale-in")}
      >
        <div className="h-0.5 rounded-t-lg bg-gradient-to-r from-primary to-brand-to" />
        <div className="flex items-center justify-between gap-3 border-b border-border px-5 py-3">
          <Text as="h2" variant="h3" className="text-foreground">
            {label("settings.title")}
          </Text>
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => void sendEvent(id, { resetAll: true })}>
              <RotateCcw size={14} aria-hidden="true" />
              {label("settings.reset")}
            </Button>
            <Button onClick={() => finish(() => sendResolve(id, true))}>
              <Check size={14} aria-hidden="true" />
              {label("settings.done")}
            </Button>
          </div>
        </div>

        <div className="grid min-h-0 flex-1 grid-cols-[1fr_18rem] gap-5 overflow-hidden px-5 py-4">
          <div className="min-h-0 divide-y divide-border overflow-y-auto pr-2">
            {(has("mode") || has("accent") || has("scale")) && (
              <Text variant="small" className="pb-1 font-semibold uppercase tracking-wide text-muted-foreground">
                {label("settings.appearance")}
              </Text>
            )}

            {has("mode") && (
              <Row title={label("settings.mode")} {...resetRow("mode")}>
                <Segmented
                  label={label("settings.mode")}
                  value={current("mode")}
                  onChange={(value) => change("mode", value)}
                  options={[ThemeMode.Dark, ThemeMode.Light].map((mode) => ({ value: mode, label: label(`modes.${mode}`) }))}
                />
              </Row>
            )}

            {has("accent") && (
              <Row title={label("settings.accent")} {...resetRow("accent")}>
                <div className="flex flex-wrap items-center gap-1.5">
                  {ACCENT_PRESETS.map((preset) => (
                    <button
                      key={preset}
                      type="button"
                      aria-label={preset}
                      aria-pressed={accent === preset}
                      onClick={() => change("accent", preset)}
                      className={cn(
                        "h-6 w-6 rounded-full border-2 transition-transform hover:scale-110",
                        accent === preset ? "border-foreground" : "border-transparent",
                      )}
                      style={{ backgroundColor: preset }}
                    />
                  ))}
                  <label className="ml-1 flex cursor-pointer items-center gap-1.5 rounded-md border border-border px-2 py-1 text-xs text-muted-foreground hover:text-foreground">
                    <input
                      type="color"
                      aria-label={label("settings.custom")}
                      value={accent ?? ACCENT_PRESETS[0]}
                      onChange={(event) => change("accent", event.target.value, true)}
                      className="h-5 w-5 cursor-pointer rounded border-0 bg-transparent p-0"
                    />
                    {accent && !ACCENT_PRESETS.includes(accent) ? accent : label("settings.custom")}
                  </label>
                </div>
              </Row>
            )}

            {has("scale") && (
              <Row title={label("settings.scale")} {...resetRow("scale")}>
                <div className="flex items-center gap-3">
                  <input
                    type="range"
                    aria-label={label("settings.scale")}
                    min={75}
                    max={150}
                    step={5}
                    value={Math.round(scale * 100)}
                    onChange={(event) => change("scale", Number(event.target.value) / 100, true)}
                    className="flex-1 accent-[hsl(var(--ug-primary))]"
                  />
                  <span className="w-10 text-right text-xs tabular-nums text-muted-foreground">{Math.round(scale * 100)}%</span>
                </div>
              </Row>
            )}

            {placed.length > 0 && (
              <Text variant="small" className="pb-1 pt-4 font-semibold uppercase tracking-wide text-muted-foreground">
                {label("settings.elements")}
              </Text>
            )}

            {ELEMENTS.filter((element) => has(element.position) || ("style" in element && has(element.style))).map((element) => (
              <div key={element.position} onMouseEnter={() => setActive(element.position)} onMouseLeave={() => setActive(undefined)}>
                <Row
                  title={label(element.label)}
                  onDefault={() => {
                    change(element.position, undefined);

                    if ("style" in element) {
                      change(element.style, undefined);
                    }
                  }}
                  isDefault={values[element.position] === undefined && (!("style" in element) || values[element.style] === undefined)}
                  defaultLabel={label("settings.default")}
                >
                  <div className="flex items-start gap-4">
                    {has(element.position) && (
                      <PositionGrid
                        label={`${label(element.label)}: ${label("settings.position")}`}
                        labels={labels}
                        value={current(element.position)}
                        onChange={(value) => change(element.position, value)}
                      />
                    )}
                    {"style" in element && has(element.style) && (
                      <Segmented
                        label={`${label(element.label)}: ${label("settings.style")}`}
                        value={current(element.style)}
                        onChange={(value) => change(element.style, value)}
                        options={element.styles.map((style) => ({ value: style, label: label(`styles.${style}`) }))}
                      />
                    )}
                  </div>
                </Row>
              </div>
            ))}
          </div>

          <div className="flex min-h-0 flex-col gap-4 overflow-y-auto">
            <Text variant="small" className="font-semibold uppercase tracking-wide text-muted-foreground">
              {label("settings.preview")}
            </Text>
            <ScreenPreview placed={placed} active={active} labels={labels} />
            <div className="pointer-events-none flex flex-col items-center gap-3">
              <Notification
                exiting={false}
                payload={{
                  message: label("settings.previewNotify"),
                  type: NotifyType.Info,
                  style: current("notifyStyle") as NotifyStyle,
                  position: Position.TopRight,
                  duration: 0,
                  stamp: 0,
                }}
              />
              <TextUIPreview text={label("settings.previewTextUI")} style={current("textUIStyle") as TextUIStyle} keyCap="E" />
            </div>
          </div>
        </div>
      </Surface>
    </div>
  );
}
