/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { act, render } from "@testing-library/react";
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { ROUND_PAUSE_MS, SkillCheck, type SkillRound } from "@/components/SkillCheck";

const nui = vi.hoisted(() => ({ sendResolve: vi.fn(), sendClose: vi.fn() }));

vi.mock("@/lib/nui", () => nui);

let now = 0;

beforeEach(() => {
  vi.useFakeTimers();
  now = 0;
  vi.spyOn(performance, "now").mockImplementation(() => now);
  nui.sendResolve.mockReset();
  nui.sendClose.mockReset();
});

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

const ROUNDS: SkillRound[] = [
  { areaSize: 40, speed: 0.5, start: 100, key: "e" },
  { areaSize: 40, speed: 0.5, start: 200, key: "q" },
];

function press(key: string, at: number) {
  now = at;
  act(() => {
    window.dispatchEvent(new KeyboardEvent("keydown", { key }));
  });
}

function mount() {
  return render(<SkillCheck id="shop/1" payload={{ rounds: ROUNDS }} exiting={false} />);
}

it("reports every round after the last hit", () => {
  mount();

  press("e", 240);
  now = 240 + ROUND_PAUSE_MS;
  act(() => vi.advanceTimersByTime(ROUND_PAUSE_MS));
  press("Q", now + 440);

  expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", [
    { hit: true, time: 240 },
    { hit: true, time: 440 },
  ]);
});

it("stops at the first miss", () => {
  mount();

  press("e", 10);

  expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", [{ hit: false, time: 10 }]);
});

it("a wrong key is a miss", () => {
  mount();

  press("x", 240);

  expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", [{ hit: false, time: 240 }]);
});

it("a full turn without a press is a miss", () => {
  mount();

  act(() => vi.advanceTimersByTime(720));

  expect(nui.sendResolve).toHaveBeenCalledWith("shop/1", [{ hit: false, time: 720 }]);
});

it("Escape closes", () => {
  mount();

  press("Escape", 50);

  expect(nui.sendClose).toHaveBeenCalledWith("shop/1");
  expect(nui.sendResolve).not.toHaveBeenCalled();
});
