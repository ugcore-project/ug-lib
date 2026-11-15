/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { useMemo } from "react";
import { Notification, type NotifyPayload } from "@/components/Notification";
import { positionClasses } from "@/lib/position";
import { useConfigStore } from "@/store/configStore";
import { useLayerStore } from "@/store/layerStore";
import { NuiType } from "@/types/nui";
import type { Position } from "@/types/enums";
import type { Layer } from "@/types/nui";

/** Notifications stack per anchor, newest last. One stack per anchor in use, above other layers. */
export function NotificationStack() {
  // Select the stable array and filter in a memo: a new array from the selector would re-render forever.
  const layers = useLayerStore((state) => state.layers);
  const max = useConfigStore((state) => state.config.settings.notifyMax);

  const stacks = useMemo(() => {
    const byAnchor = new Map<Position, Layer[]>();

    for (const layer of layers) {
      if (layer.type !== NuiType.Notify) {
        continue;
      }

      const position = (layer.payload as NotifyPayload).position;
      const stack = byAnchor.get(position);

      if (stack) {
        stack.push(layer);
      } else {
        byAnchor.set(position, [layer]);
      }
    }

    return [...byAnchor].map(([position, stack]) => [position, stack.slice(-Math.max(max, 1))] as const);
  }, [layers, max]);

  return (
    <div role="status" aria-live="polite">
      {stacks.map(([position, stack]) => (
        <div key={position} className={`${positionClasses(position)} z-[1000] gap-2`}>
          {stack.map((layer) => (
            <Notification key={layer.id} payload={layer.payload as NotifyPayload} exiting={layer.exiting} />
          ))}
        </div>
      ))}
    </div>
  );
}
