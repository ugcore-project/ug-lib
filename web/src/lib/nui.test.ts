/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { afterEach, describe, expect, it, vi } from "vitest";
import { browserLog, isEnvBrowser, sendClose, sendEvent, sendReady, sendResolve } from "@/lib/nui";
import { NuiCallback } from "@/types/nui";

afterEach(() => {
  delete window.GetParentResourceName;
  vi.unstubAllGlobals();
  browserLog.length = 0;
});

describe("in a browser", () => {
  it("logs callbacks instead of fetching", async () => {
    expect(isEnvBrowser()).toBe(true);
    expect(await sendResolve("a/1", 2)).toBe(true);
    expect(browserLog).toEqual([{ callback: NuiCallback.Resolve, data: { id: "a/1", result: 2 } }]);
  });
});

describe("in NUI", () => {
  it("posts to the resource and reads ok", async () => {
    window.GetParentResourceName = () => "ug-lib";

    const fetchMock = vi.fn().mockResolvedValue({ json: async () => ({ ok: true }) });

    vi.stubGlobal("fetch", fetchMock);

    expect(await sendEvent("a/1", { index: 1 })).toBe(true);
    expect(fetchMock).toHaveBeenCalledWith("https://ug-lib/ug-lib:Nui:Event", expect.objectContaining({ method: "POST" }));
    expect(JSON.parse(fetchMock.mock.calls[0]![1].body)).toEqual({ id: "a/1", data: { index: 1 } });
  });

  it("returns false when Lua rejects or the request fails", async () => {
    window.GetParentResourceName = () => "ug-lib";
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue({ json: async () => ({ ok: false }) }));

    expect(await sendClose("a/1")).toBe(false);

    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("down")));

    expect(await sendReady()).toBe(false);
  });
});
