/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { fireEvent, render } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { BACK, ContextMenu, type ContextPayload } from "@/components/ContextMenu";
import { Menu, type MenuPayload } from "@/components/Menu";
import { Color, Icon, Position } from "@/types/enums";

const nui = vi.hoisted(() => ({ sendResolve: vi.fn(), sendClose: vi.fn(), isEnvBrowser: () => false }));

vi.mock("@/lib/nui", () => nui);

beforeEach(() => {
  nui.sendResolve.mockReset();
  nui.sendClose.mockReset();
});

const CONTEXT: ContextPayload = {
  title: "Garage",
  canBack: true,
  canClose: true,
  position: Position.CenterRight,
  items: [
    { title: "Sultan", icon: Icon.Star, progress: 50, colorScheme: Color.Success, metadata: [{ label: "Fuel", value: 50 }] },
    { title: "Impounded", disabled: true },
    { title: "Info", readOnly: true },
  ],
};

describe("ContextMenu", () => {
  it("answers the 1-based index of a clicked item, once", () => {
    const { getByText } = render(<ContextMenu id="shop/1" payload={CONTEXT} exiting={false} />);

    fireEvent.click(getByText("Sultan"));
    fireEvent.click(getByText("Sultan"));

    expect(nui.sendResolve).toHaveBeenCalledTimes(1);
    expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", 1);
  });

  it("disabled and read-only items do not answer", () => {
    const { getByText } = render(<ContextMenu id="shop/1" payload={CONTEXT} exiting={false} />);

    fireEvent.click(getByText("Impounded"));
    fireEvent.click(getByText("Info"));

    expect(nui.sendResolve).not.toHaveBeenCalled();
  });

  it("back answers 0, close and Escape close", () => {
    const { getByLabelText } = render(<ContextMenu id="shop/1" payload={CONTEXT} exiting={false} />);

    fireEvent.click(getByLabelText("Back"));

    expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", BACK);

    const second = render(<ContextMenu id="shop/2" payload={CONTEXT} exiting={false} />);

    fireEvent.keyDown(window, { key: "Escape" });

    expect(nui.sendClose).toHaveBeenCalledWith("shop/2");
    second.unmount();
  });

  it("canClose false hides close and ignores Escape", () => {
    const { queryByLabelText } = render(<ContextMenu id="shop/1" payload={{ ...CONTEXT, canClose: false, canBack: false }} exiting={false} />);

    fireEvent.keyDown(window, { key: "Escape" });

    expect(queryByLabelText("Close")).toBeNull();
    expect(queryByLabelText("Back")).toBeNull();
    expect(nui.sendClose).not.toHaveBeenCalled();
  });

  it("shows metadata and the progress bar", () => {
    const { container, getByText } = render(<ContextMenu id="shop/1" payload={CONTEXT} exiting={false} />);

    expect(getByText("Fuel")).toBeTruthy();
    const bar = container.querySelector(".bg-primary.rounded-full[style]") as HTMLElement;

    expect(bar.style.width).toBe("50%");
    expect(bar.style.backgroundColor).toBe("hsl(var(--ug-success))");
  });
});

describe("Menu", () => {
  const MENU: MenuPayload = {
    title: "Vehicle",
    position: Position.TopLeft,
    canClose: true,
    disableInput: false,
    items: [
      { label: "Engine", checked: true, description: "Turn it on" },
      { label: "Seat", values: ["Driver", "Passenger"], description: "Pick a seat" },
      { label: "Leave" },
    ],
    state: { selected: 2, scroll: [0, 2, 0], checked: [false, false, false] },
  };

  it("draws the selection, values and checkboxes from the state", () => {
    const { container, getByText, queryByText } = render(<Menu id="shop/1" payload={MENU} exiting={false} />);

    expect(container.querySelector('[aria-selected="true"]')?.textContent).toContain("Seat");
    expect(getByText("Passenger")).toBeTruthy();
    expect(getByText("Pick a seat")).toBeTruthy();
    expect(queryByText("Turn it on")).toBeNull();
    expect(getByText("2/3")).toBeTruthy();
  });

  it("never answers on its own", () => {
    const { getByText } = render(<Menu id="shop/1" payload={MENU} exiting={false} />);

    fireEvent.click(getByText("Leave"));

    expect(nui.sendResolve).not.toHaveBeenCalled();
  });
});
