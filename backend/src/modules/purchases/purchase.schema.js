import { z } from 'zod';
import {
  adDate,
  bsDate,
  dateRangeQuerySchema,
  moneyAmount,
  optionalText,
  paginationQuerySchema,
  requiredText,
} from '../../common/schemas/common.schema.js';

/**
 * A purchase is always a LUMP-SUM whole bill: one supplier, one bill number,
 * one amount, one optional free-text description of what was bought. There are
 * deliberately no line items to validate.
 */
export const createPurchaseSchema = z.object({
  /** Optional - falls back to the active fiscal year. */
  fiscalYearId: z.uuid().optional(),
  supplierId: z.uuid('A supplier is required'),
  billNo: requiredText(60, 'Bill number is required'),
  billDate: adDate,
  billDateBs: bsDate,
  description: optionalText(500),
  amount: moneyAmount({ positive: true }),
  remarks: optionalText(2000),
});

export const updatePurchaseSchema = createPurchaseSchema.partial().omit({ fiscalYearId: true });

export const listPurchaseQuerySchema = paginationQuerySchema
  .extend({
    supplierId: z.uuid().optional(),
    fiscalYearId: z.uuid().optional(),
  })
  .merge(dateRangeQuerySchema);
