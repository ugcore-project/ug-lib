/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { useLayerStore } from "@/store/layerStore";
import { layerComponents } from "@/components/registry";
import { accentStyle } from "@/lib/accent";

/**
 * Renders every open layer with the component registered for its type, in open order. Unknown types render nothing.
 * A payload `color` replaces the primary color inside its layer.
 */
function colorOf(payload: unknown): string | undefined {
  const color = typeof payload === "object" && payload !== null ? (payload as { color?: unknown }).color : undefined;

  return typeof color === "string" ? color : undefined;
}

export function LayerHost() {
  const layers = useLayerStore((state) => state.layers);

  return (
    <>
      {layers.map((layer) => {
        const Component = layerComponents[layer.type];

        if (!Component) {
          return null;
        }

        return (
          <div key={layer.id} className="pointer-events-none fixed inset-0" style={{ zIndex: layer.order, ...accentStyle(colorOf(layer.payload)) }}>
            <Component id={layer.id} payload={layer.payload} exiting={layer.exiting} />
          </div>
        );
      })}
    </>
  );
}
