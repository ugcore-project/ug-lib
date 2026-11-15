/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import type { ComponentType } from "react";
import { NuiType } from "@/types/nui";
import { TextUI } from "@/components/TextUI";
import { Progress } from "@/components/Progress";
import { SkillCheck } from "@/components/SkillCheck";
import { Dialog } from "@/components/Dialog";
import { ContextMenu } from "@/components/ContextMenu";
import { Menu } from "@/components/Menu";
import { Radial } from "@/components/Radial";
import { Settings } from "@/components/Settings";

export interface LayerProps<TPayload = unknown> {
  /** `<owner>/<id>`, sent back with answers. */
  id: string;
  payload: TPayload;
  /** Closing: play the exit animation. */
  exiting: boolean;
}

/** Components by NUI type. Notifications render in NotificationStack instead. */
export const layerComponents: Partial<Record<string, ComponentType<LayerProps>>> = {
  [NuiType.TextUI]: TextUI,
  [NuiType.Progress]: Progress,
  [NuiType.SkillCheck]: SkillCheck,
  [NuiType.Dialog]: Dialog,
  [NuiType.Context]: ContextMenu,
  [NuiType.Menu]: Menu,
  [NuiType.Radial]: Radial,
  [NuiType.Settings]: Settings,
};
