/*

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { describe, expect, it } from "vitest";
import { render } from "@testing-library/react";
import { parseMarkup } from "@/lib/markup";
import { Markup } from "@/components/Markup";

describe("parseMarkup", () => {
  it("styles bold, italic and colors", () => {
    expect(parseMarkup("Paid **$500** to ~success~Bob~reset~ *today*")).toEqual([
      { text: "Paid ", bold: false, italic: false, color: null },
      { text: "$500", bold: true, italic: false, color: null },
      { text: " to ", bold: false, italic: false, color: null },
      { text: "Bob", bold: false, italic: false, color: "success" },
      { text: " ", bold: false, italic: false, color: null },
      { text: "today", bold: false, italic: true, color: null },
    ]);
  });

  it("keeps unknown tags and unbalanced markers as text", () => {
    expect(parseMarkup("~blink~ a ** b")).toEqual([{ text: "~blink~ a ** b", bold: false, italic: false, color: null }]);
  });

  it("caps very long text", () => {
    const segments = parseMarkup("a".repeat(10000));

    expect(segments[0]?.text).toHaveLength(4096);
  });
});

describe("Markup", () => {
  it("renders HTML in payloads as text", () => {
    const { container } = render(<Markup text={'<img src=x onerror="alert(1)"> **hi**'} />);

    expect(container.querySelector("img")).toBeNull();
    expect(container.textContent).toBe('<img src=x onerror="alert(1)"> hi');
    expect(container.querySelector(".font-semibold")?.textContent).toBe("hi");
  });
});
