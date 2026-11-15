/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { LAYER_EXIT_MS, useLayerStore } from "@/store/layerStore";

beforeEach(() => {
  vi.useFakeTimers();
  useLayerStore.getState().clear();
});

afterEach(() => {
  vi.useRealTimers();
});

it("orders layers by open order", () => {
  const store = useLayerStore.getState();

  store.open("a/1", "dialog", {});
  store.open("a/2", "notify", {});

  const [first, second] = useLayerStore.getState().layers;

  expect(second!.order).toBeGreaterThan(first!.order);
});

it("reopening a closing layer cancels its removal", () => {
  const store = useLayerStore.getState();

  store.open("a/1", "textui", { text: "a" });
  store.close("a/1");
  store.open("a/1", "textui", { text: "b" });
  vi.advanceTimersByTime(LAYER_EXIT_MS * 2);

  expect(useLayerStore.getState().layers).toMatchObject([{ id: "a/1", exiting: false, payload: { text: "b" } }]);
});

it("closing an unknown or closing layer does nothing", () => {
  const store = useLayerStore.getState();

  store.close("nope");
  store.open("a/1", "notify", {});
  store.close("a/1");
  store.close("a/1");
  vi.advanceTimersByTime(LAYER_EXIT_MS - 1);

  expect(useLayerStore.getState().layers).toHaveLength(1);

  vi.advanceTimersByTime(1);

  expect(useLayerStore.getState().layers).toHaveLength(0);
});

it("updates skip closing layers", () => {
  const store = useLayerStore.getState();

  store.open("a/1", "notify", { text: "a" });
  store.close("a/1");
  store.update("a/1", { text: "b" });

  expect(useLayerStore.getState().layers[0]?.payload).toEqual({ text: "a" });
});
