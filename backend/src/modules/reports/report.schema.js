import { z } from 'zod';
import { adDate, blankAsAbsent } from '../../common/schemas/common.schema.js';

/**
 * Reports accept an optional AD window. Nothing is required: with no query at
 * all the dashboard reports the last 30 days ending today, which is what the
 * app asks for on load.
 *
 * The window is expressed in AD because that is what the database sorts and
 * range-queries on. Every date that comes *back* carries its BS twin.
 */
export const dashboardQuerySchema = z
  .object({
    from: blankAsAbsent(adDate.optional()),
    to: blankAsAbsent(adDate.optional()),
    /** Days in the sales trend line. */
    trendDays: blankAsAbsent(z.coerce.number().int().min(2).max(120).default(14)),
    /** How many suppliers appear in "owed the most". */
    topSuppliers: blankAsAbsent(z.coerce.number().int().min(1).max(20).default(4)),
  })
  .refine((query) => !query.from || !query.to || query.from <= query.to, {
    message: '"from" must not be after "to"',
    path: ['from'],
  });

export const supplierOutstandingQuerySchema = z.object({
  /** Hide suppliers that are fully settled. Defaults to showing them all. */
  onlyOutstanding: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => (value === undefined ? undefined : value === 'true')),
  isActive: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => (value === undefined ? undefined : value === 'true')),
});
