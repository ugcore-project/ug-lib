/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { Input } from "@/components/ui/Input";
import { Text } from "@/components/ui/Text";
import { Markup } from "@/components/Markup";
import { cn } from "@/lib/cn";
import { UG_ICONS } from "@/lib/icons";
import { FieldType } from "@/types/enums";
import type { DialogFieldDefinition, FieldValue } from "@/lib/dialogFields";

const BOX = "w-full rounded-md border border-input bg-background px-3 text-sm text-foreground placeholder:text-muted-foreground disabled:cursor-not-allowed disabled:opacity-50";

interface FieldProps {
  id: string;
  field: DialogFieldDefinition;
  value: FieldValue;
  problem: string | null;
  autoFocus: boolean;
  onChange: (value: FieldValue) => void;
}

function Control({ id, field, value, problem, autoFocus, onChange }: FieldProps) {
  const common = { id, disabled: field.disabled === true, autoFocus, "aria-invalid": problem ? true : undefined };

  switch (field.type) {
    case FieldType.Textarea:
      return (
        <textarea
          {...common}
          className={cn(BOX, "py-2", problem && "border-destructive")}
          rows={field.rows ?? 3}
          maxLength={field.maxLength}
          placeholder={field.placeholder}
          value={String(value ?? "")}
          onChange={(event) => onChange(event.target.value)}
        />
      );
    case FieldType.Number:
      return (
        <Input
          {...common}
          type="number"
          invalid={Boolean(problem)}
          min={field.min}
          max={field.max}
          step={field.step ?? "any"}
          placeholder={field.placeholder}
          value={value === undefined ? "" : String(value)}
          onChange={(event) => onChange(event.target.value)}
        />
      );
    case FieldType.Slider:
      return (
        <div className="flex items-center gap-3">
          <input
            {...common}
            type="range"
            className="h-1.5 flex-1 cursor-pointer accent-[hsl(var(--ug-primary))]"
            min={field.min}
            max={field.max}
            step={field.step ?? 1}
            value={Number(value ?? field.min ?? 0)}
            onChange={(event) => onChange(Number(event.target.value))}
          />
          <span className="w-12 text-right text-sm tabular-nums text-muted-foreground">{String(value ?? "")}</span>
        </div>
      );
    case FieldType.Select:
      return (
        <select
          {...common}
          className={cn(BOX, "h-9", problem && "border-destructive")}
          value={value === undefined || value === "" ? "" : String(value)}
          onChange={(event) => {
            const option = field.options?.find((entry) => String(entry.value) === event.target.value);

            onChange(option ? option.value : "");
          }}
        >
          <option value="">{field.placeholder ?? "—"}</option>
          {field.options?.map((option) => (
            <option key={String(option.value)} value={String(option.value)}>
              {option.label}
            </option>
          ))}
        </select>
      );
    case FieldType.MultiSelect: {
      const selected = Array.isArray(value) ? value : [];

      return (
        <div id={id} className="flex flex-wrap gap-1.5">
          {field.options?.map((option) => {
            const active = selected.includes(option.value);

            return (
              <button
                key={String(option.value)}
                type="button"
                disabled={field.disabled}
                aria-pressed={active}
                className={cn(
                  "rounded-full border px-3 py-1 text-xs transition-colors",
                  active ? "border-primary bg-primary text-primary-foreground" : "border-border text-muted-foreground hover:bg-accent",
                )}
                onClick={() => onChange(active ? selected.filter((entry) => entry !== option.value) : [...selected, option.value])}
              >
                {option.label}
              </button>
            );
          })}
        </div>
      );
    }
    case FieldType.Checkbox:
      return (
        <input
          {...common}
          type="checkbox"
          className="h-4 w-4 accent-[hsl(var(--ug-primary))]"
          checked={value === true}
          onChange={(event) => onChange(event.target.checked)}
        />
      );
    case FieldType.Toggle:
      return (
        <button
          {...common}
          type="button"
          role="switch"
          aria-checked={value === true}
          className={cn("relative h-5 w-9 rounded-full transition-colors", value === true ? "bg-primary" : "bg-secondary")}
          onClick={() => onChange(value !== true)}
        >
          <span className={cn("absolute top-0.5 h-4 w-4 rounded-full bg-foreground transition-all", value === true ? "left-[1.125rem]" : "left-0.5")} />
        </button>
      );
    case FieldType.Color:
      return (
        <input
          {...common}
          type="color"
          className="h-9 w-16 cursor-pointer rounded-md border border-input bg-background"
          value={typeof value === "string" && value !== "" ? value : "#000000"}
          onChange={(event) => onChange(event.target.value)}
        />
      );
    case FieldType.Date:
      return (
        <Input
          {...common}
          type="date"
          invalid={Boolean(problem)}
          min={typeof field.min === "string" ? field.min : undefined}
          max={typeof field.max === "string" ? field.max : undefined}
          value={String(value ?? "")}
          onChange={(event) => onChange(event.target.value)}
        />
      );
    default:
      return (
        <Input
          {...common}
          type={field.type === FieldType.Password ? "password" : "text"}
          invalid={Boolean(problem)}
          maxLength={field.maxLength}
          placeholder={field.placeholder}
          value={String(value ?? "")}
          onChange={(event) => onChange(event.target.value)}
        />
      );
  }
}

/** One labelled field with its description and problem. */
export function DialogField(props: FieldProps) {
  const { id, field, problem } = props;
  const IconComponent = field.icon ? UG_ICONS[field.icon] : undefined;
  const inline = field.type === FieldType.Checkbox || field.type === FieldType.Toggle;

  return (
    <div className={cn(inline && "flex items-center justify-between gap-3")}>
      {field.label && (
        <label htmlFor={id} className={cn("flex items-center gap-1.5 text-xs font-medium text-foreground", !inline && "mb-1")}>
          {IconComponent && <IconComponent size={14} className="text-muted-foreground" aria-hidden="true" />}
          <Markup text={field.label} />
          {field.required && <span className="text-destructive">*</span>}
        </label>
      )}
      <Control {...props} />
      {field.description && !inline && (
        <Text variant="small" className="mt-1 block text-muted-foreground">
          <Markup text={field.description} />
        </Text>
      )}
      {problem && (
        <Text variant="small" className="mt-1 block text-destructive">
          {problem}
        </Text>
      )}
    </div>
  );
}
