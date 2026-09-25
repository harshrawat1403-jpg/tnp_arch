export const REVIEW_PAGE_SIZE = 20;
export const MAX_REVIEW_PAGE = 10_000;

export type PageRange = {
  from: number;
  to: number;
};

export function parsePageParameter(value: string | string[] | undefined): number {
  const parameter = Array.isArray(value) ? value[0] : value;
  if (!parameter || !/^[1-9]\d*$/.test(parameter)) return 1;

  const page = Number(parameter);
  if (!Number.isSafeInteger(page)) return 1;
  return Math.min(page, MAX_REVIEW_PAGE);
}

export function pageRange(page: number): PageRange {
  const safePage = Math.max(1, Math.min(page, MAX_REVIEW_PAGE));
  const from = (safePage - 1) * REVIEW_PAGE_SIZE;

  // Fetch one extra row to determine whether a next page exists without a count query.
  return { from, to: from + REVIEW_PAGE_SIZE };
}

export function pageItems<T>(rows: readonly T[]): { hasNext: boolean; items: T[] } {
  return {
    hasNext: rows.length > REVIEW_PAGE_SIZE,
    items: rows.slice(0, REVIEW_PAGE_SIZE),
  };
}
