/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { fireEvent, render } from "@testing-library/react";
import { beforeEach, expect, it, vi } from "vitest";
import { Radial, type RadialPayload } from "@/components/Radial";
import { PAGE_SIZE, pageSlots } from "@/lib/radialPages";
import { Icon } from "@/types/enums";

const nui = vi.hoisted(() => ({ sendResolve: vi.fn(), sendClose: vi.fn(), isEnvBrowser: () => false }));

vi.mock("@/lib/nui", () => nui);

beforeEach(() => {
  nui.sendResolve.mockReset();
  nui.sendClose.mockReset();
});

const TREE: RadialPayload = {
  title: "Interact",
  items: [
    { label: "Wave", icon: Icon.User },
    { label: "Admin", items: [{ label: "Heal" }, { label: "Kick", disabled: true }] },
  ],
};

it("answers the path to a leaf", () => {
  const { getByLabelText } = render(<Radial id="shop/1" payload={TREE} exiting={false} />);

  fireEvent.click(getByLabelText("Admin"));
  fireEvent.click(getByLabelText("Kick"));
  fireEvent.click(getByLabelText("Heal"));

  expect(nui.sendResolve).toHaveBeenCalledTimes(1);
  expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", [2, 1]);
});

it("back returns to the parent ring, Escape closes", () => {
  const { getByLabelText, queryByLabelText } = render(<Radial id="shop/1" payload={TREE} exiting={false} />);

  fireEvent.click(getByLabelText("Admin"));
  fireEvent.click(getByLabelText("Back"));

  expect(queryByLabelText("Wave")).not.toBeNull();

  fireEvent.keyDown(window, { key: "Escape" });

  expect(nui.sendClose).toHaveBeenCalledWith("shop/1");
});

it("keyboard selects the highlighted item", () => {
  render(<Radial id="shop/1" payload={TREE} exiting={false} />);

  fireEvent.keyDown(window, { key: "ArrowRight" });
  fireEvent.keyDown(window, { key: "Enter" });
  fireEvent.keyDown(window, { key: "Enter" });

  expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", [2, 1]);
});

it("pages rings with more than eight items", () => {
  const items = Array.from({ length: 10 }, (_, index) => ({ label: `Item ${index + 1}` }));

  expect(pageSlots(items, 0)).toHaveLength(PAGE_SIZE);
  expect(pageSlots(items, 0)[PAGE_SIZE - 1]?.index).toBe(-1);
  expect(pageSlots(items, 1).map((slot) => slot.index)).toEqual([7, 8, 9, -1]);

  const { getByLabelText } = render(<Radial id="shop/1" payload={{ items }} exiting={false} />);

  fireEvent.click(getByLabelText("More"));
  fireEvent.click(getByLabelText("Item 9"));

  expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", [9]);
});
