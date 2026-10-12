import { z } from 'zod';
import { SaleType } from '../../database/generated/prisma/index.js';
import {
  adDate,
  blankAsAbsent,
  bsDate,
  moneyAmount,
  optionalAdDate,
  optionalText,
  optionalUuid,
  requiredText,
} from '../../common/schemas/common.schema.js';
import {
  applyPaymentRules,
  basePaymentShape,
} from '../supplier-payments/supplier-payment.schema.js';
import { saleItemSchema, salePaymentSchema } from '../sales/sale.schema.js';

/**
 * The wire contract between the mobile app and this module.
 *
 * Two conventions are worth stating once, because they look inconsistent and
 * are deliberate on both counts:
 *
 *  * Domain fields are camelCase - the same names the REST modules already
 *    publish, so the app's DTOs read one shape whichever endpoint produced it.
 *  * The four sync metadata keys are snake_case (`created_at`, `updated_at`,
 *    `is_deleted`, `device_id`) because the app's sync engine reads them
 *    straight off a row without going through a DTO.
 *
 * Dates are AD `YYYY-MM-DD` with the BS string beside them, money is a
 * fixed-precision string, and timestamps are epoch millis - all exactly as the
 * rest of the API already does it.
 */

/**
 * A flag as it arrives from a client. Dart, JSON and SQLite each have their own
 * idea of a boolean, so `1` and `"true"` are read the way they are meant -
 * while `"false"` stays false, which a bare `z.coerce.boolean()` would not.
 *
 * @param {boolean} fallback
 */
const wireBoolean = (fallback) =>
  z.preprocess((value) => {
    if (typeof value === 'string') return value === 'true' || value === '1';
    if (typeof value === 'number') return value !== 0;
    return value;
  }, z.boolean().default(fallback));

/** Entities that replicate, in dependency order: parents before children. */
export const syncEntityNames = Object.freeze([
  'fiscal_years',
  'suppliers',
  'customers',
  'purchases',
  'supplier_payments',
  'sales',
]);

const entityName = z.enum(syncEntityNames);

/**
 * Metadata every payload carries.
 *
 * `updated_at` is repeated here and on the operation itself; the operation's
 * copy is the one the merge uses, since that is the version the client
 * actually queued. `sync_status` is deliberately absent - it is a device's
 * private opinion about a row, not a fact about it.
 */
const syncMetaShape = {
  created_at: z.coerce.number().int().nonnegative().optional(),
  updated_at: z.coerce.number().int().nonnegative().optional(),
  is_deleted: wireBoolean(false),
  device_id: z
    .string()
    .max(64)
    .nullish()
    .transform((value) => value ?? null),
};

/** Blank is the same as absent for an optional email, as it is for a filter. */
const optionalEmail = z.preprocess(
  (value) => (typeof value === 'string' && value.trim() === '' ? null : value),
  z
    .email('Invalid email address')
    .max(180)
    .nullish()
    .transform((value) => value ?? null),
);

const fiscalYearPayloadSchema = z.object({
  name: requiredText(20, 'A fiscal year needs a name'),
  startDate: adDate,
  endDate: adDate,
  startDateBs: bsDate,
  endDateBs: bsDate,
  isActive: wireBoolean(false),
  ...syncMetaShape,
});

const supplierPayloadSchema = z.object({
  name: requiredText(180, 'Supplier name is required'),
  contactPerson: optionalText(120),
  phone: optionalText(30),
  email: optionalEmail,
  address: optionalText(255),
  pan: optionalText(30),
  openingBalance: moneyAmount().default(0),
  isActive: wireBoolean(true),
  remarks: optionalText(2000),
  ...syncMetaShape,
});

const customerPayloadSchema = z.object({
  name: requiredText(180, 'Customer name is required'),
  phone: optionalText(30),
  address: optionalText(255),
  pan: optionalText(30),
  remarks: optionalText(2000),
  ...syncMetaShape,
});

const purchasePayloadSchema = z.object({
  fiscalYearId: z.uuid('A fiscal year is required'),
  supplierId: z.uuid('A supplier is required'),
  billNo: requiredText(60, 'A bill number is required'),
  billDate: adDate,
  billDateBs: bsDate,
  description: optionalText(500),
  amount: moneyAmount({ positive: true }),
  remarks: optionalText(2000),
  ...syncMetaShape,
});

/**
 * The cheque and clearing rules are the ones the REST endpoint enforces,
 * imported rather than restated: a payment that the web app would refuse must
 * not be creatable by syncing it in through the side door.
 */
const supplierPaymentPayloadSchema = z
  .object({
    ...basePaymentShape,
    fiscalYearId: z.uuid('A fiscal year is required'),
    ...syncMetaShape,
  })
  .superRefine(applyPaymentRules);

/**
 * A sale travels whole - header, invoice lines and settlement in one payload.
 * The children carry the client's own ids so the row that comes back is the
 * row the device already has, rather than the same invoice with every line
 * renumbered.
 */
const salePayloadSchema = z
  .object({
    fiscalYearId: z.uuid('A fiscal year is required'),
    invoiceNo: optionalText(60),
    saleDate: adDate,
    saleDateBs: bsDate,
    customerId: optionalUuid,
    saleType: z.enum(Object.values(SaleType)),
    description: optionalText(500),
    discount: moneyAmount().default(0),
    /** Read for SUMMARY sales only; a detailed sale's total comes from its lines. */
    totalAmount: moneyAmount().optional(),
    items: z
      .array(
        saleItemSchema.extend({
          id: z.uuid().optional(),
          sortOrder: z.coerce.number().int().min(0).optional(),
        }),
      )
      .default([]),
    payments: z
      .array(
        salePaymentSchema.extend({
          id: z.uuid().optional(),
          /**
           * Absent from the REST schema, which has no way to settle a cheque
           * after the fact - it has a dedicated endpoint for that. A synced
           * sale carries whatever the device already knows.
           */
          clearedDate: optionalAdDate,
        }),
      )
      .default([]),
    remarks: optionalText(2000),
    ...syncMetaShape,
  })
  .superRefine((data, ctx) => {
    if (data.saleType === SaleType.DETAILED && data.items.length === 0) {
      ctx.addIssue({
        code: 'custom',
        path: ['items'],
        message: 'A detailed sale needs at least one item',
      });
    }
    if (data.saleType === SaleType.SUMMARY && data.items.length > 0) {
      ctx.addIssue({
        code: 'custom',
        path: ['items'],
        message: 'A summary sale records one amount and carries no items',
      });
    }
  });

/** Payload schema per entity, keyed by wire name. */
export const syncPayloadSchemas = Object.freeze({
  fiscal_years: fiscalYearPayloadSchema,
  suppliers: supplierPayloadSchema,
  customers: customerPayloadSchema,
  purchases: purchasePayloadSchema,
  supplier_payments: supplierPaymentPayloadSchema,
  sales: salePayloadSchema,
});

/**
 * One queued change. The payload is validated per operation inside the
 * service, not here: a single malformed row has to come back as one rejected
 * operation, not as a 422 that fails the other forty-nine with it.
 */
const syncOperationSchema = z.object({
  entity: entityName,
  entity_id: z.uuid('A client-generated uuid is required'),
  operation: z.enum(['upsert', 'delete']).default('upsert'),
  updated_at: z.coerce.number().int().nonnegative(),
  payload: z.record(z.string(), z.unknown()).default({}),
});

export const pushBodySchema = z.object({
  device_id: z
    .string()
    .max(64)
    .nullish()
    .transform((value) => value ?? null),
  operations: z.array(syncOperationSchema).max(500).default([]),
});

export const pullQuerySchema = z.object({
  entity: entityName,
  /** Opaque to the client; this module's own bookmark. See sync.cursor.js. */
  cursor: blankAsAbsent(z.string().max(500).optional()),
  limit: blankAsAbsent(z.coerce.number().int().min(1).max(500).default(200)),
  /** Recorded for logging only - a device is never sent a shorter answer. */
  device_id: blankAsAbsent(z.string().max(64).optional()),
});
