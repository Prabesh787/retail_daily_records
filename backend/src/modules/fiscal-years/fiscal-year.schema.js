import { z } from 'zod';
import {
  adDate,
  bsDate,
  paginationQuerySchema,
  requiredText,
} from '../../common/schemas/common.schema.js';

export const createFiscalYearSchema = z
  .object({
    /** Nepali fiscal year label, e.g. "2082/83". */
    name: requiredText(20, 'Fiscal year name is required'),
    startDate: adDate,
    endDate: adDate,
    startDateBs: bsDate,
    endDateBs: bsDate,
    isActive: z.boolean().default(false),
  })
  .refine((data) => data.endDate > data.startDate, {
    message: 'End date must be after the start date',
    path: ['endDate'],
  });

export const updateFiscalYearSchema = z
  .object({
    name: requiredText(20).optional(),
    startDate: adDate.optional(),
    endDate: adDate.optional(),
    startDateBs: bsDate,
    endDateBs: bsDate,
    isActive: z.boolean().optional(),
  })
  .refine((data) => !data.startDate || !data.endDate || data.endDate > data.startDate, {
    message: 'End date must be after the start date',
    path: ['endDate'],
  });

export const listFiscalYearQuerySchema = paginationQuerySchema;
