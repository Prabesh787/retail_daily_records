import { z } from 'zod';

/**
 * A query string cannot express "absent" and "empty" differently - `?q=` and a
 * missing `q` mean the same thing to anyone typing a URL, and a UI that clears
 * a filter often leaves the key behind. So a blank value is read as absent
 * rather than rejected as too short.
 *
 * @template {import('zod').ZodType} T
 * @param {T} schema
 */
const blankAsAbsent = (schema) =>
  z.preprocess(
    (value) => (typeof value === 'string' && value.trim() === '' ? undefined : value),
    schema,
  );

/** Free-text search term, `?q=` or `?search=`. */
const searchTerm = () => blankAsAbsent(z.string().trim().min(1).max(120).optional());

/** `:id` route parameter, shared by every module. */
export const idParamSchema = z.object({
  id: z.uuid('A valid uuid is required'),
});

/**
 * Standard list query: `?page=2&limit=50&search=abc`.
 *
 * `q` is accepted as a short alias for `search` because that is what the
 * client sends. `validatedQuery()` folds it into `search`, so repositories
 * only ever see one name for it.
 */
export const paginationQuerySchema = z.object({
  page: blankAsAbsent(z.coerce.number().int().min(1).default(1)),
  limit: blankAsAbsent(z.coerce.number().int().min(1).max(100).default(20)),
  search: searchTerm(),
  q: searchTerm(),
});

/**
 * Free text that should land in the database as NULL rather than as an empty
 * string, so "not filled in" has exactly one representation.
 *
 * @param {number} max
 */
export const optionalText = (max) =>
  z
    .string()
    .trim()
    .max(max)
    .nullish()
    .transform((value) => (value == null || value.length === 0 ? null : value));

/**
 * @param {number} max
 * @param {string} [message]
 */
export const requiredText = (max, message = 'This field is required') =>
  z.string().trim().min(1, message).max(max);

/**
 * Money arriving from a client. Accepted either as a number or as a decimal
 * string so nothing is lost in transit, then re-checked and rounded on the
 * server before it reaches the database.
 *
 * @param {{ positive?: boolean }} [options]
 */
export const moneyAmount = (options = {}) => {
  const base = z
    .union([
      z.number(),
      z
        .string()
        .trim()
        .regex(/^-?\d+(\.\d{1,2})?$/, 'Invalid amount'),
    ])
    .transform((value) => Number(value))
    .refine((value) => Number.isFinite(value), 'Invalid amount')
    .refine((value) => Math.abs(value) <= 999_999_999_999, 'Amount is out of range');

  return options.positive
    ? base.refine((value) => value > 0, 'Amount must be greater than 0')
    : base.refine((value) => value >= 0, 'Amount cannot be negative');
};

/** Quantity with up to 3 decimal places, e.g. 2.5 METER. */
export const quantityAmount = z
  .union([
    z.number(),
    z
      .string()
      .trim()
      .regex(/^\d+(\.\d{1,3})?$/, 'Invalid quantity'),
  ])
  .transform((value) => Number(value))
  .refine((value) => Number.isFinite(value) && value > 0, 'Quantity must be greater than 0');

/**
 * Gregorian (AD) calendar date in `YYYY-MM-DD`. This is the value the database
 * stores, sorts and range-queries on.
 */
export const adDate = z
  .string()
  .trim()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Date must be in YYYY-MM-DD format')
  .refine((value) => {
    const date = new Date(`${value}T00:00:00.000Z`);
    // Round-tripping catches impossible dates such as 2024-02-31.
    return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
  }, 'Invalid calendar date')
  .transform((value) => new Date(`${value}T00:00:00.000Z`));

/**
 * An AD date that may legitimately be absent. A form clears a field by sending
 * `null` (a cheque date on a cash payment, say), so `.optional()` alone - which
 * only permits `undefined` - would reject the very payload the UI produces.
 */
export const optionalAdDate = adDate.nullish().transform((value) => value ?? null);

/**
 * Bikram Sambat date exactly as the shopkeeper typed it, e.g. "2083-05-10".
 * Stored as a string for display and printing only - never sorted or filtered
 * on, which is what the AD column above is for.
 */
export const bsDate = z
  .string()
  .trim()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'BS date must be in YYYY-MM-DD format')
  .refine((value) => {
    const [, month, day] = value.split('-').map(Number);
    return month >= 1 && month <= 12 && day >= 1 && day <= 32;
  }, 'Invalid BS date')
  .nullish()
  .transform((value) => value ?? null);

/** Inclusive `?from=&to=` filter used by list and report-style endpoints. */
export const dateRangeQuerySchema = z.object({
  from: blankAsAbsent(adDate.optional()),
  to: blankAsAbsent(adDate.optional()),
});

export { blankAsAbsent, searchTerm };

/** Optional uuid reference, e.g. `customerId` on a walk-in sale. */
export const optionalUuid = z
  .uuid('A valid uuid is required')
  .nullish()
  .transform((value) => value ?? null);
