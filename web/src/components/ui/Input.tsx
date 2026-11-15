/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { forwardRef, type InputHTMLAttributes } from "react";
import { cn } from "@/lib/cn";

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  /** Error border and ring. The caller renders the message. */
  invalid?: boolean;
}

/** Text entry for dialog fields. Label and error layout live in DialogField.tsx. */
export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className, invalid, ...props }, ref) => (
    <input
      ref={ref}
      className={cn(
        "h-9 w-full rounded-md border bg-background px-3 text-sm text-foreground placeholder:text-muted-foreground",
        "transition-colors focus-visible:outline-none disabled:cursor-not-allowed disabled:opacity-50",
        invalid ? "border-destructive focus-visible:ring-2 focus-visible:ring-destructive" : "border-input",
        className,
      )}
      aria-invalid={invalid || undefined}
      {...props}
    />
  ),
);

Input.displayName = "Input";
