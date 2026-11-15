/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// The only file that calls `fetch`. NUI callbacks are POSTs to `https://<resource>/<callback>`.

import { NuiCallback } from "@/types/nui";

declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

/** True in a normal browser (`npm run dev`), where no NUI callback endpoint exists. */
export function isEnvBrowser(): boolean {
  return typeof window.GetParentResourceName !== "function";
}

function resourceName(): string {
  return window.GetParentResourceName?.() ?? "ug-lib";
}

/** Sent requests in a browser, for the dev panel and tests. */
export const browserLog: { callback: string; data: unknown }[] = [];

export async function postNui(callback: NuiCallback, data: unknown): Promise<boolean> {
  if (isEnvBrowser()) {
    browserLog.push({ callback, data });

    return true;
  }

  try {
    const response = await fetch(`https://${resourceName()}/${callback}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data),
    });
    const reply = (await response.json()) as { ok?: unknown };

    return reply.ok === true;
  } catch {
    return false;
  }
}

/** The page is mounted. Lua sends the config, then queued messages. */
export function sendReady(): Promise<boolean> {
  return postNui(NuiCallback.Ready, {});
}

/** Final answer of a layer. Lua validates it against the payload it holds. */
export function sendResolve(id: string, result: unknown): Promise<boolean> {
  return postNui(NuiCallback.Resolve, { id, result });
}

/** Non-final event of a layer, such as a menu selection that keeps it open. */
export function sendEvent(id: string, data: unknown): Promise<boolean> {
  return postNui(NuiCallback.Event, { id, data });
}

/** The player closed a layer without answering. */
export function sendClose(id: string): Promise<boolean> {
  return postNui(NuiCallback.Close, { id });
}
