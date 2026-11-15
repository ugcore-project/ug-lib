/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { AlertTriangle, Check, HelpCircle, Info, Lock, Minus, Pencil, Plus, Settings, Star, Trash2, Unlock, User, XCircle } from "lucide-react";
import type { Icon } from "@/types/enums";

/** The curated icon set, mirrored by `UgLib.Enums.Icon`. Add icons when a feature needs them. */
export const UG_ICONS: Record<Icon, typeof Info> = {
  info: Info,
  settings: Settings,
  user: User,
  lock: Lock,
  unlock: Unlock,
  trash: Trash2,
  star: Star,
  edit: Pencil,
  plus: Plus,
  minus: Minus,
  check: Check,
  warning: AlertTriangle,
  error: XCircle,
  question: HelpCircle,
};
