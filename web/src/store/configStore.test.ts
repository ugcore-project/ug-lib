/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { beforeEach, expect, it } from "vitest";
import { applyTheme, DEFAULT_CONFIG, readConfig, useConfigStore } from "@/store/configStore";
import { ThemeMode } from "@/types/enums";

const root = document.documentElement;

beforeEach(() => {
  applyTheme(DEFAULT_CONFIG.theme);
});

it("applies mode, colors, radius, font and scale", () => {
  applyTheme({ mode: ThemeMode.Light, colors: { primary: "217 91% 60%" }, radius: "8px", font: "Inter", scale: 1.25 });

  expect(root.classList.contains("dark")).toBe(false);
  expect(root.style.getPropertyValue("--ug-primary")).toBe("217 91% 60%");
  expect(root.style.getPropertyValue("--ug-radius")).toBe("8px");
  expect(root.style.getPropertyValue("--ug-font-sans")).toContain("Inter Variable");
  expect(root.style.getPropertyValue("--ug-scale")).toBe("1.25");
});

it("drops values that are not tokens, triplets or sizes", () => {
  applyTheme({
    mode: ThemeMode.Dark,
    colors: { primary: "red; background: url(https://evil)", secondary: "1 2% 3%", unknown: "1 2% 3%" },
    radius: "calc(1px)",
    font: "Comic Sans",
    scale: 9,
  });

  expect(root.style.getPropertyValue("--ug-primary")).toBe("");
  expect(root.style.getPropertyValue("--ug-secondary")).toBe("1 2% 3%");
  expect(root.style.getPropertyValue("--ug-radius")).toBe("0.5rem");
  expect(root.style.getPropertyValue("--ug-scale")).toBe("1.5");
});

it("removes colors that are no longer set", () => {
  applyTheme({ ...DEFAULT_CONFIG.theme, colors: { primary: "1 2% 3%" } });
  applyTheme(DEFAULT_CONFIG.theme);

  expect(root.style.getPropertyValue("--ug-primary")).toBe("");
});

it("reads partial and broken payloads", () => {
  expect(readConfig(null)).toEqual(DEFAULT_CONFIG);
  expect(readConfig({ labels: { confirm: "Confirmar" }, locale: "pt" }).labels).toEqual({ ...DEFAULT_CONFIG.labels, confirm: "Confirmar" });
});

it("applies the player's accent over the theme, and drops anything but #rrggbb", () => {
  const root = document.documentElement;

  useConfigStore.getState().setConfig(readConfig({ accent: "#ff0000" }));
  expect(root.style.getPropertyValue("--ug-primary")).toBe("0 100% 50%");

  useConfigStore.getState().setConfig(readConfig({}));
  expect(root.style.getPropertyValue("--ug-primary")).toBe("");

  useConfigStore.getState().setConfig(readConfig({ accent: "url(https://x.test)" }));
  expect(root.style.getPropertyValue("--ug-primary")).toBe("");
});
