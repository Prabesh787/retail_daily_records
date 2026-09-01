import { z } from 'zod';
import {
  dateRangeQuerySchema,
  moneyAmount,
  optionalText,
  paginationQuerySchema,
  requiredText,
  searchTerm,
} from '../../common/schemas/common.schema.js';

export const createSupplierSchema = z.object({
  name: requiredText(180, 'Supplier name is required'),
  contactPerson: optionalText(120),
  phone: optionalText(30),
  email: z
    .email('Invalid email address')
    .max(180)
    .nullish()
    .transform((value) => value ?? null),
  address: optionalText(255),
  pan: optionalText(30),
  /**
   * Balance the shop already owed this supplier on the day the system went
   * live. It seeds the derived outstanding figure; it is never a running total.
   */
  openingBalance: moneyAmount().default(0),
  remarks: optionalText(2000),
});

export const updateSupplierSchema = createSupplierSchema.partial().extend({
  isActive: z.boolean().optional(),
});

/**
 * The ledger on the detail screen is filtered, so the detail endpoint takes a
 * window and a search term of its own. `q` is folded into `search` by
 * `validatedQuery()`.
 */
export const supplierDetailQuerySchema = z
  .object({ search: searchTerm(), q: searchTerm() })
  .merge(dateRangeQuerySchema);

export const listSupplierQuerySchema = paginationQuerySchema.extend({
  isActive: z
    .enum(['true', 'false'])
    .optional()
    .transform((value) => (value === undefined ? undefined : value === 'true')),
});
