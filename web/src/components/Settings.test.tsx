/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { fireEvent, render } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { Settings, type SettingsPayload } from "@/components/Settings";
import { Position } from "@/types/enums";

const nui = vi.hoisted(() => ({ sendResolve: vi.fn(), sendClose: vi.fn(), sendEvent: vi.fn(), isEnvBrowser: () => false }));

vi.mock("@/lib/nui", () => nui);

beforeEach(() => {
  vi.useRealTimers();
  nui.sendResolve.mockReset();
  nui.sendClose.mockReset();
  nui.sendEvent.mockReset();
});

const PAYLOAD: SettingsPayload = {
  keys: ["mode", "accent", "scale", "notifyPosition", "notifyStyle", "menuPosition"],
  values: { accent: "#22c55e" },
  defaults: { mode: "dark", scale: 1, notifyPosition: Position.TopRight, notifyStyle: "toast", menuPosition: Position.TopLeft },
  labels: {
    "settings.title": "UI settings",
    "settings.done": "Done",
    "settings.reset": "Reset all",
    "settings.default": "Server default",
    "settings.mode": "Theme",
    "settings.accent": "Accent color",
    "settings.scale": "Size",
    "settings.notify": "Notifications",
    "settings.menu": "Menus",
    "settings.custom": "Custom",
    "modes.light": "Light",
    "modes.dark": "Dark",
    "positions.bottom-left": "Bottom left",
  },
  stamp: 1,
};

function open(payload: SettingsPayload = PAYLOAD) {
  return render(<Settings id="ug-lib/1" payload={payload} exiting={false} />);
}

describe("Settings", () => {
  it("sends one change per click, and clears a row back to the server default", () => {
    const { getByRole, getAllByText } = open();

    fireEvent.click(getByRole("radio", { name: "Light" }));
    expect(nui.sendEvent).toHaveBeenLastCalledWith("ug-lib/1", { key: "mode", value: "light" });

    fireEvent.click(getByRole("button", { name: "#ef4444" }));
    expect(nui.sendEvent).toHaveBeenLastCalledWith("ug-lib/1", { key: "accent", value: "#ef4444" });

    fireEvent.click(getAllByText("Server default")[1]!);
    expect(nui.sendEvent).toHaveBeenLastCalledWith("ug-lib/1", { key: "accent", clear: true });
  });

  it("places elements with the position grid", () => {
    const { getAllByRole } = open();

    fireEvent.click(getAllByRole("radio", { name: "Bottom left" })[0]!);
    expect(nui.sendEvent).toHaveBeenLastCalledWith("ug-lib/1", { key: "notifyPosition", value: Position.BottomLeft });
  });

  it("sends a dragged color once it settles", () => {
    vi.useFakeTimers();

    const { getByLabelText } = open();
    const picker = getByLabelText("Custom");

    fireEvent.change(picker, { target: { value: "#101010" } });
    fireEvent.change(picker, { target: { value: "#202020" } });
    expect(nui.sendEvent).not.toHaveBeenCalled();

    vi.advanceTimersByTime(200);
    expect(nui.sendEvent).toHaveBeenCalledTimes(1);
    expect(nui.sendEvent).toHaveBeenLastCalledWith("ug-lib/1", { key: "accent", value: "#202020" });
  });

  it("hides locked preferences", () => {
    const { queryByText } = open({ ...PAYLOAD, keys: ["notifyPosition"] });

    expect(queryByText("Theme")).toBeNull();
    expect(queryByText("Accent color")).toBeNull();
  });

  it("resets, finishes and closes", () => {
    const { getByRole } = open();

    fireEvent.click(getByRole("button", { name: "Reset all" }));
    expect(nui.sendEvent).toHaveBeenLastCalledWith("ug-lib/1", { resetAll: true });

    fireEvent.click(getByRole("button", { name: "Done" }));
    fireEvent.keyDown(window, { key: "Escape" });
    expect(nui.sendResolve).toHaveBeenCalledWith("ug-lib/1", true);
    expect(nui.sendClose).not.toHaveBeenCalled();
  });
});
