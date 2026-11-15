/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { act, render } from "@testing-library/react";
import { beforeEach, expect, it } from "vitest";
import { LayerHost } from "@/components/LayerHost";
import { useLayerStore } from "@/store/layerStore";
import { Icon, Position, ProgressStyle, TextUIStyle } from "@/types/enums";
import { NuiType } from "@/types/nui";

beforeEach(() => {
  useLayerStore.getState().clear();
});

function open(type: string, payload: unknown) {
  act(() => useLayerStore.getState().open("shop/1", type, payload));
}

it("renders the keybind prompt with its key and markup", () => {
  const { container } = render(<LayerHost />);

  open(NuiType.TextUI, { text: "Open **shop**", key: "E", icon: Icon.Star, style: TextUIStyle.Keybind, position: Position.Bottom });

  expect(container.querySelector("kbd")?.textContent).toBe("E");
  expect(container.querySelector("span.font-semibold")?.textContent).toBe("shop");
  expect(container.querySelector("svg")).not.toBeNull();
});

it("falls back to a pill without a key", () => {
  const { container } = render(<LayerHost />);

  open(NuiType.TextUI, { text: "Hello", style: TextUIStyle.Keybind, position: Position.Bottom });

  expect(container.querySelector("kbd")).toBeNull();
  expect(container.textContent).toBe("Hello");
});

it("renders every progress style with its duration", () => {
  for (const style of Object.values(ProgressStyle)) {
    useLayerStore.getState().clear();

    const { container, unmount } = render(<LayerHost />);

    open(NuiType.Progress, { label: "Working", duration: 2500, style, position: Position.Bottom, canCancel: true, stamp: 1 });

    expect(container.textContent).toContain("Working");
    expect(container.innerHTML).toContain("2500ms");

    unmount();
  }
});
