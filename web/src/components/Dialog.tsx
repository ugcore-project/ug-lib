/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { useEffect, useRef, useState, type FormEvent } from "react";
import { Button } from "@/components/ui/Button";
import { Surface } from "@/components/ui/Surface";
import { Text } from "@/components/ui/Text";
import { Markup } from "@/components/Markup";
import { DialogField } from "@/components/DialogField";
import { answerValue, fieldProblem, initialValue, type DialogFieldDefinition, type FieldValue } from "@/lib/dialogFields";
import type { ColorValue } from "@/lib/accent";
import { cn } from "@/lib/cn";
import { UG_ICONS } from "@/lib/icons";
import { isEnvBrowser, sendClose, sendResolve } from "@/lib/nui";
import { useConfigStore } from "@/store/configStore";
import { useLayerStore } from "@/store/layerStore";
import { DialogSize, Icon } from "@/types/enums";
import { DialogVariant } from "@/types/nui";
import type { LayerProps } from "@/components/registry";

/** Built and checked by Lua: see client/ui/dialog.lua. */
export interface DialogPayload {
  variant: DialogVariant;
  title: string;
  message?: string;
  icon?: Icon;
  color?: ColorValue;
  confirmLabel?: string;
  cancelLabel?: string;
  destructive?: boolean;
  size: DialogSize;
  fields?: DialogFieldDefinition[];
}

const SIZES = {
  [DialogSize.Small]: "max-w-sm",
  [DialogSize.Medium]: "max-w-md",
  [DialogSize.Large]: "max-w-lg",
} as const;

const ICON_COLORS: Partial<Record<Icon, string>> = {
  [Icon.Warning]: "text-warning",
  [Icon.Error]: "text-destructive",
  [Icon.Check]: "text-success",
};

/** Alert, Confirm and Input. Answers once; Escape and the backdrop close without an answer. */
export function Dialog({ id, payload, exiting }: LayerProps) {
  const dialog = payload as DialogPayload;
  const labels = useConfigStore((state) => state.config.labels);
  const fields = dialog.fields ?? [];
  const [values, setValues] = useState<Record<string, FieldValue>>(() => Object.fromEntries(fields.map((field) => [field.name, initialValue(field)])));
  const [problems, setProblems] = useState<Record<string, string | null>>({});
  const answered = useRef(false);
  const primary = useRef<HTMLButtonElement>(null);

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

  useEffect(() => {
    if (fields.length === 0) {
      primary.current?.focus();
    }

    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        close();
      }
    };

    window.addEventListener("keydown", onKey);

    return () => window.removeEventListener("keydown", onKey);
    // Runs once per dialog: `close` only reads refs and the stable id.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const submit = (event: FormEvent) => {
    event.preventDefault();

    const found: Record<string, string | null> = {};
    const answer: Record<string, FieldValue> = {};

    for (const field of fields) {
      found[field.name] = fieldProblem(field, values[field.name]);

      const value = answerValue(field, values[field.name]);

      if (value !== undefined) {
        answer[field.name] = value;
      }
    }

    setProblems(found);

    if (Object.values(found).every((problem) => problem === null)) {
      finish(() => sendResolve(id, answer));
    }
  };

  const IconComponent = dialog.icon ? UG_ICONS[dialog.icon] : undefined;
  const confirmLabel = dialog.confirmLabel ?? (dialog.variant === DialogVariant.Alert ? labels.ok : dialog.variant === DialogVariant.Input ? labels.submit : labels.confirm);
  const cancelLabel = dialog.cancelLabel ?? labels.cancel;

  return (
    <div className="pointer-events-auto fixed inset-0 flex items-center justify-center p-4">
      <div className={cn("absolute inset-0 bg-background/70", exiting ? "animate-ug-fade-out" : "animate-ug-fade-in")} onClick={close} aria-hidden="true" />
      <Surface
        variant="glass"
        padding="lg"
        role={dialog.variant === DialogVariant.Alert ? "alertdialog" : "dialog"}
        aria-modal="true"
        aria-labelledby={`${id}-title`}
        className={cn("relative z-10 max-h-[90vh] w-full overflow-y-auto", SIZES[dialog.size] ?? SIZES[DialogSize.Medium], exiting ? "animate-ug-scale-out" : "animate-ug-scale-in")}
      >
        <div className="flex items-start gap-3">
          {IconComponent && <IconComponent size={22} className={cn("mt-0.5 shrink-0", (dialog.icon && ICON_COLORS[dialog.icon]) ?? "text-primary")} aria-hidden="true" />}
          <div className="min-w-0 flex-1">
            <Text id={`${id}-title`} as="h2" variant="h2">
              <Markup text={dialog.title} />
            </Text>
            {dialog.message && (
              <Text variant="muted" className="mt-1">
                <Markup text={dialog.message} />
              </Text>
            )}
          </div>
        </div>

        <form className="mt-4 space-y-3" onSubmit={submit} noValidate>
          {fields.map((field, index) => (
            <DialogField
              key={field.name}
              id={`${id}-${field.name}`}
              field={field}
              value={values[field.name]}
              problem={problems[field.name] ?? null}
              autoFocus={index === 0}
              onChange={(value) => setValues((previous) => ({ ...previous, [field.name]: value }))}
            />
          ))}

          <div className="flex justify-end gap-2 pt-1">
            {dialog.variant === DialogVariant.Confirm && (
              <Button type="button" variant="outline" onClick={() => finish(() => sendResolve(id, false))}>
                {cancelLabel}
              </Button>
            )}
            {dialog.variant === DialogVariant.Input && (
              <Button type="button" variant="outline" onClick={close}>
                {cancelLabel}
              </Button>
            )}
            {dialog.variant === DialogVariant.Input ? (
              <Button type="submit">{confirmLabel}</Button>
            ) : (
              <Button
                ref={primary}
                type="button"
                variant={dialog.destructive ? "destructive" : "default"}
                onClick={() => finish(() => sendResolve(id, true))}
              >
                {confirmLabel}
              </Button>
            )}
          </div>
        </form>
      </Surface>
    </div>
  );
}
