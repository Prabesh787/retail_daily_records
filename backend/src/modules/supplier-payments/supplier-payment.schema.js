import { z } from 'zod';
import { PaymentStatus, SupplierPaymentMode } from '../../database/generated/prisma/index.js';
import {
  adDate,
  bsDate,
  dateRangeQuerySchema,
  moneyAmount,
  optionalAdDate,
  optionalText,
  paginationQuerySchema,
} from '../../common/schemas/common.schema.js';

const paymentModeEnum = z.enum(Object.values(SupplierPaymentMode));
const paymentStatusEnum = z.enum(Object.values(PaymentStatus));

const basePaymentShape = {
  /** Optional - falls back to the active fiscal year. */
  fiscalYearId: z.uuid().optional(),
  supplierId: z.uuid('A supplier is required'),
  /**
   * Optional on purpose. A payment may settle one specific bill, several older
   * bills, or simply the supplier's general outstanding balance.
   */
  purchaseId: z
    .uuid()
    .nullish()
    .transform((value) => value ?? null),
  voucherNo: optionalText(60),
  paymentDate: adDate,
  paymentDateBs: bsDate,
  paymentMode: paymentModeEnum,
  amount: moneyAmount({ positive: true }),
  chequeNo: optionalText(60),
  chequeDate: optionalAdDate,
  chequeDateBs: bsDate,
  referenceNo: optionalText(100),
  clearedDate: optionalAdDate,
  status: paymentStatusEnum.optional(),
  description: optionalText(500),
  remarks: optionalText(2000),
};

/**
 * Cross-field rules that make a future-dated cheque a first-class record:
 *
 *  - CHEQUE requires both a cheque number and a cheque date.
 *  - Non-cheque modes must not carry cheque fields.
 *  - An ISSUED payment has not cleared yet, so it cannot carry a cleared date.
 *  - A CLEARED cheque must say when it cleared.
 *  - Cash defaults to CLEARED; a cheque with no explicit status defaults to
 *    ISSUED (applied in the service, not here, so the default stays in one place).
 */
function applyPaymentRules(data, ctx) {
  const status =
    data.status ?? (data.paymentMode === SupplierPaymentMode.CHEQUE ? 'ISSUED' : 'CLEARED');

  if (data.paymentMode === SupplierPaymentMode.CHEQUE) {
    if (!data.chequeNo) {
      ctx.addIssue({
        code: 'custom',
        path: ['chequeNo'],
        message: 'Cheque number is required for a cheque payment',
      });
    }
    if (!data.chequeDate) {
      ctx.addIssue({
        code: 'custom',
        path: ['chequeDate'],
        message: 'Cheque date is required for a cheque payment',
      });
    }
  } else if (data.chequeNo || data.chequeDate) {
    ctx.addIssue({
      code: 'custom',
      path: ['chequeNo'],
      message: 'Cheque details are only allowed when the payment mode is CHEQUE',
    });
  }

  if (status === PaymentStatus.ISSUED && data.clearedDate) {
    ctx.addIssue({
      code: 'custom',
      path: ['clearedDate'],
      message: 'An ISSUED payment has not cleared yet, so it cannot have a cleared date',
    });
  }

  if (
    status === PaymentStatus.CLEARED &&
    data.paymentMode === SupplierPaymentMode.CHEQUE &&
    !data.clearedDate
  ) {
    ctx.addIssue({
      code: 'custom',
      path: ['clearedDate'],
      message: 'A cleared cheque must record the date it cleared',
    });
  }

  if (data.clearedDate && data.clearedDate < data.paymentDate) {
    ctx.addIssue({
      code: 'custom',
      path: ['clearedDate'],
      message: 'Cleared date cannot be earlier than the payment date',
    });
  }
}

export const createSupplierPaymentSchema = z
  .object(basePaymentShape)
  .superRefine(applyPaymentRules);

export const updateSupplierPaymentSchema = z
  .object(basePaymentShape)
  .partial()
  .omit({ fiscalYearId: true, supplierId: true });

/** Marking a previously issued cheque as cleared at the bank. */
export const clearPaymentSchema = z.object({
  clearedDate: adDate,
  remarks: optionalText(2000),
});

export const listSupplierPaymentQuerySchema = paginationQuerySchema
  .extend({
    supplierId: z.uuid().optional(),
    purchaseId: z.uuid().optional(),
    fiscalYearId: z.uuid().optional(),
    paymentMode: paymentModeEnum.optional(),
    status: paymentStatusEnum.optional(),
  })
  .merge(dateRangeQuerySchema);

/**
 * Cheque register filter. Defaults to cheques only; `status` narrows it to the
 * uncleared ones the shopkeeper has to keep money aside for.
 */
export const chequeRegisterQuerySchema = paginationQuerySchema
  .extend({
    supplierId: z.uuid().optional(),
    fiscalYearId: z.uuid().optional(),
    status: paymentStatusEnum.optional(),
  })
  .merge(dateRangeQuerySchema);
