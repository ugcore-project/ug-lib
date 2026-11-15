/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { handleMessage, installMessageBus } from "@/lib/messageBus";
import { LAYER_EXIT_MS, useLayerStore } from "@/store/layerStore";
import { DEFAULT_CONFIG, useConfigStore } from "@/store/configStore";
import { NuiAction, NuiType } from "@/types/nui";
import { Position, ThemeMode } from "@/types/enums";

beforeEach(() => {
  useLayerStore.getState().clear();
  useConfigStore.getState().setConfig(DEFAULT_CONFIG);
});

afterEach(() => {
  vi.useRealTimers();
});

describe("layer messages", () => {
  it("opens, updates and closes a layer", () => {
    vi.useFakeTimers();

    handleMessage({ type: NuiType.Notify, action: NuiAction.Open, id: "shop/1", payload: { text: "a" } });
    handleMessage({ type: NuiType.Notify, action: NuiAction.Update, id: "shop/1", payload: { text: "b" } });

    expect(useLayerStore.getState().layers).toMatchObject([{ id: "shop/1", type: NuiType.Notify, payload: { text: "b" }, exiting: false }]);

    handleMessage({ type: NuiType.Notify, action: NuiAction.Close, id: "shop/1" });

    expect(useLayerStore.getState().layers[0]?.exiting).toBe(true);

    vi.advanceTimersByTime(LAYER_EXIT_MS);

    expect(useLayerStore.getState().layers).toEqual([]);
  });

  it("ignores malformed messages and ids", () => {
    handleMessage(null);
    handleMessage("open");
    handleMessage({ type: NuiType.Notify });
    handleMessage({ type: NuiType.Notify, action: NuiAction.Open });
    handleMessage({ type: NuiType.Notify, action: NuiAction.Open, id: "x".repeat(101) });
    handleMessage({ type: NuiType.Notify, action: NuiAction.Open, id: 5 });

    expect(useLayerStore.getState().layers).toEqual([]);
  });
});

describe("system messages", () => {
  it("applies config with defaults for missing fields", () => {
    handleMessage({
      type: NuiType.System,
      action: NuiAction.Config,
      payload: { theme: { mode: ThemeMode.Light, colors: { primary: "1 2% 3%" } }, settings: { notifyPosition: Position.Top } },
    });

    const config = useConfigStore.getState().config;

    expect(config.theme.mode).toBe(ThemeMode.Light);
    expect(config.theme.radius).toBe(DEFAULT_CONFIG.theme.radius);
    expect(config.settings.notifyPosition).toBe(Position.Top);
    expect(config.settings.notifyMax).toBe(DEFAULT_CONFIG.settings.notifyMax);
    expect(config.labels.confirm).toBe("Confirm");
    expect(document.documentElement.classList.contains("dark")).toBe(false);
    expect(document.documentElement.style.getPropertyValue("--ug-primary")).toBe("1 2% 3%");
  });

  it("closes everything at once", () => {
    handleMessage({ type: NuiType.Dialog, action: NuiAction.Open, id: "a/1", payload: {} });
    handleMessage({ type: NuiType.Notify, action: NuiAction.Open, id: "b/1", payload: {} });
    handleMessage({ type: NuiType.System, action: NuiAction.CloseAll });

    expect(useLayerStore.getState().layers).toEqual([]);
  });
});

it("listens to window messages until removed", () => {
  const uninstall = installMessageBus();

  window.dispatchEvent(new MessageEvent("message", { data: { type: NuiType.Notify, action: NuiAction.Open, id: "a/1", payload: {} } }));

  expect(useLayerStore.getState().layers).toHaveLength(1);

  uninstall();
  window.dispatchEvent(new MessageEvent("message", { data: { type: NuiType.Notify, action: NuiAction.Open, id: "a/2", payload: {} } }));

  expect(useLayerStore.getState().layers).toHaveLength(1);
});
