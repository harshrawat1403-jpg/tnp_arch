import { describe, expect, it } from "vitest";

import {
  MAX_REVIEW_PAGE,
  pageItems,
  pageRange,
  parsePageParameter,
  REVIEW_PAGE_SIZE,
} from "./pagination";

describe("review pagination", () => {
  it("parses positive page parameters and clamps unsafe input", () => {
    expect(parsePageParameter(undefined)).toBe(1);
    expect(parsePageParameter("0")).toBe(1);
    expect(parsePageParameter("2.5")).toBe(1);
    expect(parsePageParameter("2x")).toBe(1);
    expect(parsePageParameter(["3", "4"])).toBe(3);
    expect(parsePageParameter(String(MAX_REVIEW_PAGE + 1))).toBe(MAX_REVIEW_PAGE);
    expect(parsePageParameter("999999999999999999999999")).toBe(1);
  });

  it("calculates bounded database ranges with one-row lookahead", () => {
    expect(pageRange(1)).toEqual({ from: 0, to: REVIEW_PAGE_SIZE });
    expect(pageRange(2)).toEqual({ from: REVIEW_PAGE_SIZE, to: REVIEW_PAGE_SIZE * 2 });
    expect(pageRange(MAX_REVIEW_PAGE + 1)).toEqual({
      from: (MAX_REVIEW_PAGE - 1) * REVIEW_PAGE_SIZE,
      to: MAX_REVIEW_PAGE * REVIEW_PAGE_SIZE,
    });
  });

  it("returns only one page while retaining a deterministic next-page signal", () => {
    const rows = Array.from({ length: REVIEW_PAGE_SIZE + 1 }, (_, index) => index);

    expect(pageItems(rows)).toEqual({
      hasNext: true,
      items: Array.from({ length: REVIEW_PAGE_SIZE }, (_, index) => index),
    });
  });
});
