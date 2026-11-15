/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { fireEvent, render } from "@testing-library/react";
import { beforeEach, expect, it, vi } from "vitest";
import { Dialog, type DialogPayload } from "@/components/Dialog";
import { DialogSize, FieldType } from "@/types/enums";
import { DialogVariant } from "@/types/nui";

const nui = vi.hoisted(() => ({ sendResolve: vi.fn(), sendClose: vi.fn(), isEnvBrowser: () => false }));

vi.mock("@/lib/nui", () => nui);

beforeEach(() => {
  nui.sendResolve.mockReset();
  nui.sendClose.mockReset();
});

function mount(payload: Partial<DialogPayload>) {
  return render(<Dialog id="shop/1" payload={{ variant: DialogVariant.Confirm, title: "Title", size: DialogSize.Medium, ...payload }} exiting={false} />);
}

it("confirm answers true or false, once", () => {
  const { getByText } = mount({ confirmLabel: "Sell", cancelLabel: "Keep" });

  fireEvent.click(getByText("Sell"));
  fireEvent.click(getByText("Keep"));

  expect(nui.sendResolve).toHaveBeenCalledTimes(1);
  expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", true);
});

it("uses the configured labels by default", () => {
  const { getByText } = mount({ variant: DialogVariant.Alert });

  fireEvent.click(getByText("OK"));

  expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", true);
});

it("Escape closes without an answer", () => {
  mount({});

  fireEvent.keyDown(window, { key: "Escape" });

  expect(nui.sendClose).toHaveBeenCalledWith("shop/1");
  expect(nui.sendResolve).not.toHaveBeenCalled();
});

it("input sends typed values and leaves empty and disabled fields out", () => {
  const { container, getByText } = mount({
    variant: DialogVariant.Input,
    fields: [
      { name: "plate", type: FieldType.Text, required: true },
      { name: "price", type: FieldType.Number, default: 5 },
      { name: "notes", type: FieldType.Textarea },
      { name: "insured", type: FieldType.Checkbox },
      { name: "id", type: FieldType.Number, disabled: true, default: 42 },
      { name: "extras", type: FieldType.MultiSelect, options: [{ value: 1, label: "Spoiler" }, { value: 2, label: "Neon" }] },
    ],
  });

  fireEvent.change(container.querySelector("#shop\\/1-plate")!, { target: { value: "ABC" } });
  fireEvent.change(container.querySelector("#shop\\/1-price")!, { target: { value: "12" } });
  fireEvent.click(container.querySelector("#shop\\/1-insured")!);
  fireEvent.click(getByText("Neon"));
  fireEvent.click(getByText("Submit"));

  expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", { plate: "ABC", price: 12, insured: true, extras: [2] });
});

it("input blocks a missing required field and an out-of-range number", () => {
  const { container, getByText, getAllByText } = mount({
    variant: DialogVariant.Input,
    fields: [
      { name: "plate", type: FieldType.Text, required: true },
      { name: "price", type: FieldType.Number, max: 10 },
    ],
  });

  fireEvent.change(container.querySelector("#shop\\/1-price")!, { target: { value: "50" } });
  fireEvent.click(getByText("Submit"));

  expect(nui.sendResolve).not.toHaveBeenCalled();
  expect(getAllByText("Required.")).toHaveLength(1);
  expect(getByText("At most 10.")).toBeTruthy();
});

it("the input cancel button closes without an answer", () => {
  const { getByText } = mount({ variant: DialogVariant.Input, fields: [{ name: "a", type: FieldType.Text }] });

  fireEvent.click(getByText("Cancel"));

  expect(nui.sendClose).toHaveBeenCalledWith("shop/1");
});
