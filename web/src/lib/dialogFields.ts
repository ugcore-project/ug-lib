/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Field values and checks for input dialogs. Lua checks every value again: see client/ui/dialog.lua.

import { FieldType, type Icon } from "@/types/enums";

export type FieldValue = string | number | boolean | (string | number)[] | undefined;

export interface FieldOption {
  value: string | number;
  label: string;
}

/** Built and checked by Lua: see client/ui/dialog.lua. */
export interface DialogFieldDefinition {
  name: string;
  type: FieldType;
  label?: string;
  description?: string;
  placeholder?: string;
  default?: FieldValue;
  required?: boolean;
  disabled?: boolean;
  icon?: Icon;
  maxLength?: number;
  rows?: number;
  min?: number | string;
  max?: number | string;
  step?: number;
  options?: FieldOption[];
}

/** The value a field starts with in the form. */
export function initialValue(field: DialogFieldDefinition): FieldValue {
  if (field.default !== undefined) {
    return field.default;
  }

  switch (field.type) {
    case FieldType.Checkbox:
    case FieldType.Toggle:
      return false;
    case FieldType.MultiSelect:
      return [];
    case FieldType.Slider:
      return typeof field.min === "number" ? field.min : 0;
    default:
      return "";
  }
}

const isEmpty = (value: FieldValue) => value === undefined || value === "" || (Array.isArray(value) && value.length === 0);

/** A first check for the player. Lua checks everything again. Returns a message, or null. */
export function fieldProblem(field: DialogFieldDefinition, value: FieldValue): string | null {
  if (field.disabled) {
    return null;
  }

  if (field.required && (isEmpty(value) || (field.type === FieldType.Checkbox && value !== true))) {
    return "Required.";
  }

  if ((field.type === FieldType.Number || field.type === FieldType.Slider) && !isEmpty(value)) {
    const number = Number(value);

    if (!Number.isFinite(number)) {
      return "Must be a number.";
    }

    if (typeof field.min === "number" && number < field.min) {
      return `At least ${field.min}.`;
    }

    if (typeof field.max === "number" && number > field.max) {
      return `At most ${field.max}.`;
    }
  }

  return null;
}

/** The value sent to Lua: numbers as numbers, empty values and disabled fields left out. */
export function answerValue(field: DialogFieldDefinition, value: FieldValue): FieldValue {
  if (field.disabled || isEmpty(value)) {
    return undefined;
  }

  if (field.type === FieldType.Number || field.type === FieldType.Slider) {
    return Number(value);
  }

  return value;
}
