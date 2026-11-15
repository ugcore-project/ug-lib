/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { create } from "zustand";
import type { Layer } from "@/types/nui";

/** Time a closing layer stays mounted for its exit animation. Matches the 150 ms exit animations. */
export const LAYER_EXIT_MS = 150;

const exitTimers = new Map<string, number>();
let order = 0;

function cancelExit(id: string): void {
  const timer = exitTimers.get(id);

  if (timer !== undefined) {
    window.clearTimeout(timer);
    exitTimers.delete(id);
  }
}

interface LayerStore {
  layers: Layer[];
  open: (id: string, type: string, payload: unknown) => void;
  update: (id: string, payload: unknown) => void;
  /** Starts the exit animation, then unmounts. */
  close: (id: string) => void;
  /** Unmounts everything at once, without animation. */
  clear: () => void;
}

export const useLayerStore = create<LayerStore>((set, get) => ({
  layers: [],

  open: (id, type, payload) => {
    cancelExit(id);
    order += 1;

    const layer: Layer = { id, type, payload, order, exiting: false };

    set((state) => ({ layers: [...state.layers.filter((entry) => entry.id !== id), layer] }));
  },

  update: (id, payload) =>
    set((state) => ({
      layers: state.layers.map((layer) => (layer.id === id && !layer.exiting ? { ...layer, payload } : layer)),
    })),

  close: (id) => {
    const layer = get().layers.find((entry) => entry.id === id);

    if (!layer || layer.exiting) {
      return;
    }

    set((state) => ({
      layers: state.layers.map((entry) => (entry.id === id ? { ...entry, exiting: true } : entry)),
    }));

    exitTimers.set(
      id,
      window.setTimeout(() => {
        exitTimers.delete(id);
        set((state) => ({ layers: state.layers.filter((entry) => entry.id !== id) }));
      }, LAYER_EXIT_MS),
    );
  },

  clear: () => {
    for (const id of [...exitTimers.keys()]) {
      cancelExit(id);
    }

    set({ layers: [] });
  },
}));
