/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { useMemo } from "react";
import { cn } from "@/lib/cn";
import { parseMarkup, type MarkupColor } from "@/lib/markup";

const COLOR_CLASSES: Record<MarkupColor, string> = {
  primary: "text-primary",
  success: "text-success",
  warning: "text-warning",
  destructive: "text-destructive",
  muted: "text-muted-foreground",
};

export interface MarkupProps {
  text: string;
  className?: string;
}

/** Renders payload text with the safe markup. Text only: never HTML. */
export function Markup({ text, className }: MarkupProps) {
  const segments = useMemo(() => parseMarkup(text), [text]);

  return (
    <span className={className}>
      {segments.map((segment, index) => (
        <span
          key={index}
          className={cn(segment.bold && "font-semibold", segment.italic && "italic", segment.color && COLOR_CLASSES[segment.color])}
        >
          {segment.text}
        </span>
      ))}
    </span>
  );
}
