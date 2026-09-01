const DEFAULT_PAGE = 1;
const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

/**
 * Normalises `?page=&limit=` into values that are safe to hand to Prisma.
 *
 * @param {number} [page]
 * @param {number} [limit]
 */
export function resolvePagination(page, limit) {
  const safePage = Math.max(page ?? DEFAULT_PAGE, 1);
  const safeLimit = Math.min(Math.max(limit ?? DEFAULT_LIMIT, 1), MAX_LIMIT);
  return { page: safePage, limit: safeLimit, skip: (safePage - 1) * safeLimit };
}

/**
 * @param {{ page: number, limit: number }} params
 * @param {number} total
 */
export function buildPaginationMeta(params, total) {
  return {
    page: params.page,
    limit: params.limit,
    total,
    totalPages: Math.max(Math.ceil(total / params.limit), 1),
  };
}
