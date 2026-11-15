/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// The only `message` listener for layers. Lua sends `{ type, action, id?, payload? }`.

import { NuiAction, NuiType, type NuiMessage } from "@/types/nui";
import { useLayerStore } from "@/store/layerStore";
import { readConfig, useConfigStore } from "@/store/configStore";

const MAX_ID_LENGTH = 100;
const MAX_CLIPBOARD = 4096;

function isMessage(data: unknown): data is NuiMessage {
  if (typeof data !== "object" || data === null) {
    return false;
  }

  const message = data as Record<string, unknown>;

  return typeof message.type === "string" && typeof message.action === "string";
}

function validId(id: unknown): id is string {
  return typeof id === "string" && id.length > 0 && id.length <= MAX_ID_LENGTH;
}

function copyToClipboard(text: unknown): void {
  if (typeof text !== "string" || text.length > MAX_CLIPBOARD) {
    return;
  }

  // CEF blocks navigator.clipboard without focus, so the copy goes through a hidden textarea.
  const area = document.createElement("textarea");

  area.value = text;
  area.setAttribute("readonly", "");
  area.style.position = "fixed";
  area.style.opacity = "0";
  document.body.appendChild(area);
  area.select();
  document.execCommand("copy");
  area.remove();
}

function handleSystem(message: NuiMessage): void {
  switch (message.action) {
    case NuiAction.Config:
      useConfigStore.getState().setConfig(readConfig(message.payload));
      break;
    case NuiAction.CloseAll:
      useLayerStore.getState().clear();
      break;
    case NuiAction.Clipboard:
      copyToClipboard(message.payload);
      break;
  }
}

/** Routes one message. Exported for tests. */
export function handleMessage(data: unknown): void {
  if (!isMessage(data)) {
    return;
  }

  if (data.type === NuiType.System) {
    handleSystem(data);

    return;
  }

  if (!validId(data.id)) {
    return;
  }

  const store = useLayerStore.getState();

  switch (data.action) {
    case NuiAction.Open:
      store.open(data.id, data.type, data.payload);
      break;
    case NuiAction.Update:
      store.update(data.id, data.payload);
      break;
    case NuiAction.Close:
      store.close(data.id);
      break;
  }
}

/** Installs the listener and returns its removal. */
export function installMessageBus(): () => void {
  const listener = (event: MessageEvent<unknown>) => handleMessage(event.data);

  window.addEventListener("message", listener);

  return () => window.removeEventListener("message", listener);
}
