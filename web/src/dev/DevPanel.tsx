/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { useState } from "react";
import { NuiAction, NuiType } from "@/types/nui";
import { ThemeMode } from "@/types/enums";
import { browserLog } from "@/lib/nui";
import { useLayerStore } from "@/store/layerStore";
import { DEFAULT_CONFIG } from "@/store/configStore";
import { demos, simulate } from "@/dev/demos";

/** Browser preview controls: theme, close all, and the demos of each component. Dev builds only. */
export default function DevPanel() {
  const [mode, setMode] = useState<ThemeMode>(ThemeMode.Dark);
  const layers = useLayerStore((state) => state.layers);

  const toggleMode = () => {
    const next = mode === ThemeMode.Dark ? ThemeMode.Light : ThemeMode.Dark;

    setMode(next);
    simulate({ type: NuiType.System, action: NuiAction.Config, payload: { ...DEFAULT_CONFIG, theme: { ...DEFAULT_CONFIG.theme, mode: next } } });
  };

  return (
    <div className="pointer-events-auto fixed bottom-4 left-4 z-[10000] w-64 space-y-2 rounded-lg border border-border bg-card p-3 text-xs text-card-foreground shadow-ug-lg">
      <div className="font-semibold">ug-lib dev panel</div>
      <div className="flex gap-2">
        <button className="rounded-md bg-secondary px-2 py-1" onClick={toggleMode}>
          Theme: {mode}
        </button>
        <button className="rounded-md bg-secondary px-2 py-1" onClick={() => simulate({ type: NuiType.System, action: NuiAction.CloseAll })}>
          Close all
        </button>
      </div>
      <div className="flex flex-wrap gap-1">
        {demos.length === 0 && <span className="text-muted-foreground">No demos yet.</span>}
        {demos.map((demo) => (
          <button key={demo.name} className="rounded-md bg-primary px-2 py-1 text-primary-foreground" onClick={demo.run}>
            {demo.name}
          </button>
        ))}
      </div>
      <div className="text-muted-foreground">
        {layers.length} layer(s), {browserLog.length} callback(s) sent
      </div>
    </div>
  );
}
