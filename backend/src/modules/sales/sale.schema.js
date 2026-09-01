import { z } from 'zod';
import { PaymentStatus, SalePaymentMode, SaleType } from '../../database/generated/prisma/index.js';
import {
  adDate,
  bsDate,
  dateRangeQuerySchema,
  moneyAmount,
  optionalAdDate,
  optionalText,
  optionalUuid,
  paginationQuerySchema,
  quantityAmount,
  requiredText,
} from '../../common/schemas/common.schema.js';

const saleTypeEnum = z.enum(Object.values(SaleType));
const salePaymentModeEnum = z.enum(Object.values(SalePaymentMode));
const paymentStatusEnum = z.enum(Object.values(PaymentStatus));

/**
 * One invoice line. There is no product foreign key on purpose: the shopkeeper
 * types what was sold. `amount` is never accepted from the client - the server
 * computes quantity * unitPrice - discount.
 */
export const saleItemSchema = z.object({
  description: requiredText(255, 'Item description is required'),
  quantity: quantityAmount,
  unit: requiredText(20, 'Unit is required'),
  unitPrice: moneyAmount(),
  discount: moneyAmount().default(0),
});

export const salePaymentSchema = z.object({
  paymentMode: salePaymentModeEnum,
  amount: moneyAmount({ positive: true }),
  referenceNo: optionalText(100),
  chequeNo: optionalText(60),
  chequeDate: optionalAdDate,
  status: paymentStatusEnum.optional(),
  remarks: optionalText(2000),
});

/**
 * Sales come at two levels of detail:
 *
 *  SUMMARY  - one line for the day's takings ("Daily retail sales", Rs 65,500).
 *             `totalAmount` is supplied directly and no items are expected.
 *  DETAILED - a real invoice. Items are required and the totals are derived
 *             from them, so anything the client sends for subtotal/total is
 *             recomputed server-side.
 */
export const createSaleSchema = z
  .object({
    fiscalYearId: z.uuid().optional(),
    invoiceNo: optionalText(60),
    saleDate: adDate,
    saleDateBs: bsDate,
    customerId: optionalUuid,
    saleType: saleTypeEnum,
    description: optionalText(500),
    discount: moneyAmount().default(0),
    /** Only read for SUMMARY sales; ignored for DETAILED ones. */
    totalAmount: moneyAmount({ positive: true }).optional(),
    items: z.array(saleItemSchema).default([]),
    payments: z.array(salePaymentSchema).default([]),
    remarks: optionalText(2000),
  })
  .superRefine((data, ctx) => {
    if (data.saleType === SaleType.DETAILED) {
      if (data.items.length === 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['items'],
          message: 'A detailed sale needs at least one item',
        });
      }
    } else {
      if (data.items.length > 0) {
        ctx.addIssue({
          code: 'custom',
          path: ['items'],
          message: 'A summary sale cannot carry invoice items. Use saleType DETAILED instead.',
        });
      }
      if (data.totalAmount === undefined) {
        ctx.addIssue({
          code: 'custom',
          path: ['totalAmount'],
          message: 'A summary sale must state its total amount',
        });
      }
    }
  });

export const updateSaleSchema = z.object({
  invoiceNo: optionalText(60),
  saleDate: adDate.optional(),
  saleDateBs: bsDate,
  customerId: optionalUuid,
  description: optionalText(500),
  discount: moneyAmount().optional(),
  totalAmount: moneyAmount({ positive: true }).optional(),
  remarks: optionalText(2000),
});

export const listSaleQuerySchema = paginationQuerySchema
  .extend({
    fiscalYearId: z.uuid().optional(),
    customerId: z.uuid().optional(),
    saleType: saleTypeEnum.optional(),
  })
  .merge(dateRangeQuerySchema);

/** Day book: everything recorded on one date. */
export const dayBookQuerySchema = z.object({
  date: adDate,
});
