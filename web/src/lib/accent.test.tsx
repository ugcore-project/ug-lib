/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { render } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { accentStyle, backgroundStyle, hexToTriplet, textColorStyle } from "@/lib/accent";
import { LayerHost } from "@/components/LayerHost";
import { useLayerStore } from "@/store/layerStore";
import { Color } from "@/types/enums";

describe("accent", () => {
  it("converts hex to an HSL triplet with readable text", () => {
    expect(hexToTriplet("#ff0000")).toEqual({ color: "0 100% 50%", foreground: "210 40% 98%" });
    expect(hexToTriplet("#ffffff").foreground).toBe("222.2 47.4% 11.2%");
    expect(hexToTriplet("#3b82f6").color).toBe("217.2 91.2% 59.8%");
  });

  it("maps tokens to theme variables", () => {
    expect(accentStyle(Color.Success)).toEqual({
      "--ug-primary": "var(--ug-success)",
      "--ug-primary-foreground": "var(--ug-success-foreground)",
      "--ug-ring": "var(--ug-success)",
      "--ug-brand-to": "var(--ug-success)",
    });
    expect(textColorStyle(Color.Warning)).toEqual({ color: "hsl(var(--ug-warning))" });
    expect(backgroundStyle("#000000")).toEqual({ backgroundColor: "hsl(0 0% 0%)" });
  });

  it("rejects anything that is not a token or #rrggbb", () => {
    for (const value of ["red", "#fff", "#12345g", "url(https://x.test/a.png)", "var(--ug-primary)", "#ff0000; color: red", undefined]) {
      expect(accentStyle(value)).toBeUndefined();
      expect(textColorStyle(value)).toBeUndefined();
    }
  });

  it("applies a layer color to the whole layer", () => {
    useLayerStore.getState().open("shop/1", "textui", { text: "Hi", style: "pill", position: "bottom", color: "#ff0000" });

    const { container } = render(<LayerHost />);
    const wrapper = container.firstElementChild as HTMLElement;

    expect(wrapper.style.getPropertyValue("--ug-primary")).toBe("0 100% 50%");
  });
});
