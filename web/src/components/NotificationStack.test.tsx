/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { act, render } from "@testing-library/react";
import { beforeEach, expect, it } from "vitest";
import { NotificationStack } from "@/components/NotificationStack";
import type { NotifyPayload } from "@/components/Notification";
import { useLayerStore } from "@/store/layerStore";
import { DEFAULT_CONFIG, useConfigStore } from "@/store/configStore";
import { NotifyStyle, NotifyType, Position } from "@/types/enums";
import { NuiType } from "@/types/nui";

let next = 0;

function show(overrides: Partial<NotifyPayload> = {}): string {
  next += 1;

  const id = `shop/${next}`;
  const payload: NotifyPayload = {
    message: `message ${next}`,
    type: NotifyType.Info,
    style: NotifyStyle.Toast,
    position: Position.TopRight,
    duration: 5000,
    stamp: next,
    ...overrides,
  };

  act(() => useLayerStore.getState().open(id, NuiType.Notify, payload));

  return id;
}

beforeEach(() => {
  next = 0;
  useLayerStore.getState().clear();
  useConfigStore.getState().setConfig(DEFAULT_CONFIG);
});

it("groups notifications per anchor", () => {
  const { container } = render(<NotificationStack />);

  show();
  show();
  show({ position: Position.BottomLeft });

  const stacks = container.querySelectorAll('[role="status"] > div');

  expect(stacks).toHaveLength(2);
  expect(stacks[0]?.children).toHaveLength(2);
});

it("keeps the newest notifyMax per anchor", () => {
  act(() => useConfigStore.getState().setConfig({ ...DEFAULT_CONFIG, settings: { ...DEFAULT_CONFIG.settings, notifyMax: 2 } }));

  const { container } = render(<NotificationStack />);

  show();
  show();
  show();

  expect(container.textContent).not.toContain("message 1");
  expect(container.textContent).toContain("message 3");
});

it("renders markup as text and other layers not at all", () => {
  const { container } = render(<NotificationStack />);

  show({ message: "Paid **$500** <b>x</b>", title: "Bank", duration: 0 });
  act(() => useLayerStore.getState().open("shop/x", NuiType.Dialog, {}));

  expect(container.querySelector("b")).toBeNull();
  expect(container.querySelector("span.font-semibold")?.textContent).toBe("$500");
  expect(container.textContent).toContain("<b>x</b>");
  expect(container.textContent).toContain("Bank");
  expect(container.innerHTML).not.toContain("ug-notification-shrink");
});

it("shows a timer bar for timed notifications", () => {
  const { container } = render(<NotificationStack />);

  show({ duration: 3000, style: NotifyStyle.Compact });

  const bar = container.querySelector('[style*="ug-notification-shrink"]') as HTMLElement | null;

  expect(bar?.style.animation).toContain("3000ms");
});
