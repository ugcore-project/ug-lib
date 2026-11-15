/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Dev panel demos, by name. Each UI service adds its demos in its build step. Dev builds only.

import { handleMessage } from "@/lib/messageBus";
import { NuiAction, NuiType, type NuiMessage } from "@/types/nui";
import { Color, DialogSize, FieldType, Icon, NotifyStyle, NotifyType, Position, ProgressStyle, TextUIStyle } from "@/types/enums";
import { DialogVariant } from "@/types/nui";
import { useLayerStore } from "@/store/layerStore";

export interface Demo {
  name: string;
  run: () => void;
}

let demoId = 0;

function notify(payload: Record<string, unknown>): void {
  demoId += 1;

  const id = `dev/${demoId}`;
  const duration = typeof payload.duration === "number" ? payload.duration : 5000;

  simulate({ type: NuiType.Notify, action: NuiAction.Open, id, payload: { duration, stamp: demoId, ...payload } });

  if (duration > 0) {
    window.setTimeout(() => simulate({ type: NuiType.Notify, action: NuiAction.Close, id }), duration);
  }
}

export const demos: Demo[] = [
  {
    name: "notify",
    run: () => {
      for (const type of Object.values(NotifyType)) {
        notify({ type, style: NotifyStyle.Toast, position: Position.TopRight, title: type, message: `A **${type}** notification with ~primary~markup~reset~.` });
      }
    },
  },
  {
    name: "compact",
    run: () => notify({ type: NotifyType.Success, style: NotifyStyle.Compact, position: Position.BottomRight, title: "Bank", message: "+$500" }),
  },
  {
    name: "banner",
    run: () => notify({ type: NotifyType.Warning, style: NotifyStyle.Banner, position: Position.Top, title: "Storm", message: "Seek shelter.", duration: 0 }),
  },
  {
    name: "textui",
    run: () => {
      const id = "dev/textui";
      const open = useLayerStore.getState().layers.some((layer) => layer.id === id && !layer.exiting);

      simulate(
        open
          ? { type: NuiType.TextUI, action: NuiAction.Close, id }
          : { type: NuiType.TextUI, action: NuiAction.Open, id, payload: { text: "Open the shop", key: "E", icon: Icon.Star, style: TextUIStyle.Keybind, position: Position.Bottom } },
      );
    },
  },
  {
    name: "progress",
    run: () => {
      demoId += 1;

      const id = `dev/${demoId}`;
      const style = Object.values(ProgressStyle)[demoId % 4] ?? ProgressStyle.Bar;

      simulate({ type: NuiType.Progress, action: NuiAction.Open, id, payload: { label: `Repairing (${style})`, duration: 4000, style, position: Position.Bottom, canCancel: true, stamp: demoId } });
      window.setTimeout(() => simulate({ type: NuiType.Progress, action: NuiAction.Close, id }), 4000);
    },
  },
  {
    name: "confirm",
    run: () => {
      demoId += 1;
      simulate({
        type: NuiType.Dialog,
        action: NuiAction.Open,
        id: `dev/${demoId}`,
        payload: { variant: DialogVariant.Confirm, title: "Sell the car?", message: "You get **$12,000**.", icon: Icon.Question, destructive: true, confirmLabel: "Sell", size: DialogSize.Small },
      });
    },
  },
  {
    name: "input",
    run: () => {
      demoId += 1;
      simulate({
        type: NuiType.Dialog,
        action: NuiAction.Open,
        id: `dev/${demoId}`,
        payload: {
          variant: DialogVariant.Input,
          title: "New vehicle",
          size: DialogSize.Large,
          fields: [
            { name: "plate", type: FieldType.Text, label: "Plate", required: true, maxLength: 8, placeholder: "ABC 123" },
            { name: "notes", type: FieldType.Textarea, label: "Notes", rows: 3, description: "Visible to **mechanics** only." },
            { name: "price", type: FieldType.Number, label: "Price", min: 0, max: 100000, step: 100, default: 5000 },
            { name: "fuel", type: FieldType.Slider, label: "Fuel", min: 0, max: 100, step: 5, default: 50 },
            { name: "color", type: FieldType.Color, label: "Color", default: "#8b5cf6" },
            { name: "class", type: FieldType.Select, label: "Class", options: [{ value: "sport", label: "Sport" }, { value: "suv", label: "SUV" }] },
            { name: "extras", type: FieldType.MultiSelect, label: "Extras", options: [{ value: 1, label: "Spoiler" }, { value: 2, label: "Neon" }] },
            { name: "insured", type: FieldType.Checkbox, label: "Insured" },
            { name: "locked", type: FieldType.Toggle, label: "Locked", default: true },
            { name: "since", type: FieldType.Date, label: "Registered on" },
            { name: "pin", type: FieldType.Password, label: "PIN", maxLength: 4 },
          ],
        },
      });
    },
  },
  {
    name: "context",
    run: () => {
      demoId += 1;
      simulate({
        type: NuiType.Context,
        action: NuiAction.Open,
        id: `dev/${demoId}`,
        payload: {
          title: "Garage",
          canBack: true,
          canClose: true,
          items: [
            { title: "Sultan RS", description: "Plate **UG 001**", icon: Icon.Star, progress: 80, colorScheme: Color.Success, metadata: [{ label: "Fuel", value: "80%" }, { label: "Engine", value: 950 }] },
            { title: "Impounded", description: "Pay to release", icon: Icon.Lock, disabled: true },
            { title: "Info", description: "Read only", readOnly: true },
            { title: "Settings", icon: Icon.Settings, submenu: true, arrow: true },
          ],
        },
      });
    },
  },
  {
    name: "menu",
    run: () => {
      const id = "dev/menu";
      const layer = useLayerStore.getState().layers.find((entry) => entry.id === id && !entry.exiting);
      const items = [
        { label: "Engine", description: "Turn the engine on or off", checked: true, icon: Icon.Settings },
        { label: "Seat", values: ["Driver", "Passenger", "Rear left"] },
        { label: "Fuel", progress: 65 },
        { label: "Lock and leave", icon: Icon.Lock },
      ];

      if (!layer) {
        simulate({
          type: NuiType.Menu,
          action: NuiAction.Open,
          id,
          payload: { title: "Vehicle", position: Position.TopLeft, items, canClose: true, disableInput: false, state: { selected: 1, scroll: [0, 1, 0, 0], checked: [true, false, false, false] } },
        });

        return;
      }

      // Each click moves the selection, as Lua would on the down key.
      const payload = layer.payload as { state: { selected: number } };
      const selected = (payload.state.selected % items.length) + 1;

      simulate({ type: NuiType.Menu, action: NuiAction.Update, id, payload: { ...payload, state: { ...payload.state, selected } } });
    },
  },
  {
    name: "radial",
    run: () => {
      demoId += 1;

      const extra = Array.from({ length: 6 }, (_, index) => ({ label: `Emote ${index + 1}` }));

      simulate({
        type: NuiType.Radial,
        action: NuiAction.Open,
        id: `dev/${demoId}`,
        payload: {
          title: "Interact",
          items: [
            { label: "Wave", icon: Icon.User },
            { label: "Lock", icon: Icon.Lock },
            { label: "Admin", icon: Icon.Settings, items: [{ label: "Heal", icon: Icon.Plus }, { label: "Kick", icon: Icon.Trash, disabled: true }] },
            ...extra,
          ],
        },
      });
    },
  },
  {
    name: "settings",
    run: () => {
      demoId += 1;

      simulate({
        type: NuiType.Settings,
        action: NuiAction.Open,
        id: `dev/${demoId}`,
        payload: {
          keys: ["mode", "accent", "scale", "notifyPosition", "notifyStyle", "textUIPosition", "textUIStyle", "progressPosition", "progressStyle", "menuPosition", "contextPosition"],
          values: { accent: "#a855f7", notifyStyle: NotifyStyle.Compact },
          defaults: {
            mode: "dark",
            scale: 1,
            notifyPosition: Position.TopRight,
            notifyStyle: NotifyStyle.Toast,
            textUIPosition: Position.Bottom,
            textUIStyle: TextUIStyle.Pill,
            progressPosition: Position.Bottom,
            progressStyle: ProgressStyle.Bar,
            menuPosition: Position.TopLeft,
            contextPosition: Position.CenterRight,
          },
          // English labels from locales/en.json. Lua sends the configured language.
          labels: {
            "settings.title": "UI settings",
            "settings.done": "Done",
            "settings.reset": "Reset all",
            "settings.default": "Server default",
            "settings.custom": "Custom",
            "settings.appearance": "Appearance",
            "settings.elements": "Elements",
            "settings.preview": "Preview",
            "settings.position": "Position",
            "settings.style": "Style",
            "settings.disabled": "UI settings are turned off on this server.",
            "settings.previewNotify": "Notifications appear here.",
            "settings.previewTextUI": "Prompts appear here",
            "settings.mode": "Theme",
            "settings.accent": "Accent color",
            "settings.scale": "Size",
            "settings.notify": "Notifications",
            "settings.textUI": "Prompts",
            "settings.progress": "Progress bars",
            "settings.menu": "Menus",
            "settings.context": "Context menus",
            "modes.dark": "Dark",
            "modes.light": "Light",
            "positions.top-left": "Top left",
            "positions.top": "Top",
            "positions.top-right": "Top right",
            "positions.center-left": "Center left",
            "positions.center": "Center",
            "positions.center-right": "Center right",
            "positions.bottom-left": "Bottom left",
            "positions.bottom": "Bottom",
            "positions.bottom-right": "Bottom right",
            "styles.toast": "Toast",
            "styles.compact": "Compact",
            "styles.banner": "Banner",
            "styles.pill": "Pill",
            "styles.minimal": "Minimal",
            "styles.keybind": "Keybind",
            "styles.card": "Card",
            "styles.bar": "Bar",
            "styles.circle": "Circle",
            "styles.ring": "Ring"
          },
          stamp: demoId,
        },
      });
    },
  },
  {
    name: "skillcheck",
    run: () => {
      demoId += 1;

      const id = `dev/${demoId}`;
      const rounds = [0.25, 0.35, 0.45].map((speed, index) => ({ areaSize: 60 - index * 15, speed, start: 120 + index * 40, key: index === 1 ? "q" : "e" }));

      simulate({ type: NuiType.SkillCheck, action: NuiAction.Open, id, payload: { rounds } });
      window.setTimeout(() => simulate({ type: NuiType.SkillCheck, action: NuiAction.Close, id }), 8000);
    },
  },
];

/** Sends a message as Lua would. */
export function simulate(message: NuiMessage): void {
  handleMessage(message);
}
