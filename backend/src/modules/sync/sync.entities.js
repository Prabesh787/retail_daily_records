import { PaymentStatus, SupplierPaymentMode } from '../../database/generated/prisma/index.js';
import {
  serializeCustomer,
  serializeFiscalYear,
  serializePayment,
  serializePurchase,
  serializeSale,
  serializeSupplier,
} from '../../common/serializers/index.js';
import { resolveTotals } from '../sales/sale.service.js';
import { syncEntityNames, syncPayloadSchemas } from './sync.schema.js';

/**
 * What the engine needs to know about one replicated table, and nothing more.
 *
 * The service owns the *when* - conflict rules, transactions, paging - and an
 * entry here owns the *what* for its own table. Adding an entity is one entry
 * plus one payload schema; the service does not change.
 *
 * Nothing spreads a payload straight into `data`. Every column is named on
 * purpose, so a key a client invents cannot become a column write, and the
 * fields the server owns - `subtotal`, `amount` on an invoice line, the sync
 * bookkeeping - are set here rather than accepted.
 */

const saleInclude = {
  // Position on the invoice is the shopkeeper's, and `createdAt` breaks a tie
  // between lines written in the same statement.
  items: { orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }] },
  payments: { orderBy: { createdAt: 'asc' } },
};

const definitions = {
  fiscal_years: {
    label: 'Fiscal year',
    delegate: (db) => db.fiscalYear,
    serialize: serializeFiscalYear,
    toData: (payload) => ({
      name: payload.name,
      startDate: payload.startDate,
      endDate: payload.endDate,
      startDateBs: payload.startDateBs,
      endDateBs: payload.endDateBs,
      isActive: payload.isActive,
    }),
    /**
     * Exactly one year may be active, enforced by a partial unique index. A
     * device that activates a year has already stood the others down in its
     * own copy, so the same has to happen here or the write hits the index
     * instead of landing.
     */
    beforeWrite: async (tx, { id, data }) => {
      if (data.isActive) {
        await tx.fiscalYear.updateMany({
          where: { isActive: true, NOT: { id } },
          data: { isActive: false },
        });
      }
    },
  },

  suppliers: {
    label: 'Supplier',
    delegate: (db) => db.supplier,
    serialize: serializeSupplier,
    toData: (payload) => ({
      name: payload.name,
      contactPerson: payload.contactPerson,
      phone: payload.phone,
      email: payload.email,
      address: payload.address,
      pan: payload.pan,
      openingBalance: payload.openingBalance,
      isActive: payload.isActive,
      remarks: payload.remarks,
    }),
  },

  customers: {
    label: 'Customer',
    delegate: (db) => db.customer,
    serialize: serializeCustomer,
    toData: (payload) => ({
      name: payload.name,
      phone: payload.phone,
      address: payload.address,
      pan: payload.pan,
      remarks: payload.remarks,
    }),
  },

  purchases: {
    label: 'Purchase',
    delegate: (db) => db.purchase,
    serialize: serializePurchase,
    tracksCreator: true,
    toData: (payload) => ({
      fiscalYearId: payload.fiscalYearId,
      supplierId: payload.supplierId,
      billNo: payload.billNo,
      billDate: payload.billDate,
      billDateBs: payload.billDateBs,
      description: payload.description,
      amount: payload.amount,
      remarks: payload.remarks,
    }),
  },

  supplier_payments: {
    label: 'Supplier payment',
    delegate: (db) => db.supplierPayment,
    serialize: serializePayment,
    tracksCreator: true,
    toData: (payload) => ({
      fiscalYearId: payload.fiscalYearId,
      supplierId: payload.supplierId,
      purchaseId: payload.purchaseId,
      voucherNo: payload.voucherNo,
      paymentDate: payload.paymentDate,
      paymentDateBs: payload.paymentDateBs,
      paymentMode: payload.paymentMode,
      amount: payload.amount,
      chequeNo: payload.chequeNo,
      chequeDate: payload.chequeDate,
      chequeDateBs: payload.chequeDateBs,
      referenceNo: payload.referenceNo,
      clearedDate: payload.clearedDate,
      // Cash is money that has moved; a cheque has only been handed over. Same
      // default the REST endpoint applies, so a payment means the same thing
      // whichever door it came in through.
      status:
        payload.status ??
        (payload.paymentMode === SupplierPaymentMode.CHEQUE
          ? PaymentStatus.ISSUED
          : PaymentStatus.CLEARED),
      description: payload.description,
      remarks: payload.remarks,
    }),
  },

  sales: {
    label: 'Sale',
    delegate: (db) => db.sale,
    serialize: serializeSale,
    include: saleInclude,
    tracksCreator: true,
    /**
     * The three money columns are derived, never accepted - the same rule the
     * REST endpoint runs, through the same function. A device that computed a
     * total differently gets the server's answer back on its next pull rather
     * than an invoice whose lines do not add up to its own total.
     */
    toData: (payload) => {
      const { subtotal, discount, totalAmount } = resolveTotals(payload);
      return {
        fiscalYearId: payload.fiscalYearId,
        invoiceNo: payload.invoiceNo,
        saleDate: payload.saleDate,
        saleDateBs: payload.saleDateBs,
        customerId: payload.customerId,
        saleType: payload.saleType,
        description: payload.description,
        subtotal,
        discount,
        totalAmount,
        remarks: payload.remarks,
      };
    },
    /**
     * Lines and settlement are replaced wholesale rather than merged. They
     * carry no identity the shopkeeper cares about, the payload is the whole
     * invoice by definition, and a merge would have to guess which of two
     * offline edits meant to remove a line.
     */
    writeChildren: async (tx, { id, payload }) => {
      const { lines } = resolveTotals(payload);

      await tx.saleItem.deleteMany({ where: { saleId: id } });
      await tx.salePayment.deleteMany({ where: { saleId: id } });

      if (lines.length > 0) {
        await tx.saleItem.createMany({
          data: lines.map((line, index) => ({
            id: line.id,
            saleId: id,
            description: line.description,
            quantity: line.quantity,
            unit: line.unit,
            unitPrice: line.unitPrice,
            discount: line.discount ?? 0,
            amount: line.amount,
            sortOrder: line.sortOrder ?? index,
          })),
        });
      }

      if (payload.payments.length > 0) {
        await tx.salePayment.createMany({
          data: payload.payments.map((payment) => ({
            id: payment.id,
            saleId: id,
            paymentMode: payment.paymentMode,
            amount: payment.amount,
            referenceNo: payment.referenceNo,
            chequeNo: payment.chequeNo,
            chequeDate: payment.chequeDate,
            clearedDate: payment.clearedDate,
            // CREDIT is money not received yet; everything else is in hand.
            status: payment.status ?? (payment.paymentMode === 'CREDIT' ? 'ISSUED' : 'CLEARED'),
            remarks: payment.remarks,
          })),
        });
      }
    },
  },
};

/** The registry the service runs on, keyed by wire name. */
export const syncEntities = Object.freeze(
  Object.fromEntries(
    syncEntityNames.map((name) => {
      const definition = definitions[name];
      if (!definition) throw new Error(`No sync entity definition for "${name}"`);
      return [name, Object.freeze({ name, payload: syncPayloadSchemas[name], ...definition })];
    }),
  ),
);

/** @param {string} name */
export function syncEntityFor(name) {
  return syncEntities[name] ?? null;
}

/**
 * A live row as the app reads it: the module's own serialisation, plus the four
 * sync keys.
 *
 * The internal columns are peeled off rather than left to ride along - and
 * `syncUpdatedAt` in particular *has* to be, because a BigInt cannot be
 * JSON-stringified at all.
 */
export function toWireRow(entity, row) {
  const {
    syncUpdatedAt,
    deviceId,
    createdAt,
    updatedAt: _serverUpdatedAt,
    ...domain
  } = entity.serialize(row);

  return {
    ...domain,
    created_at: createdAt ? new Date(createdAt).getTime() : null,
    updated_at: Number(syncUpdatedAt),
    is_deleted: false,
    device_id: deviceId ?? null,
  };
}

/**
 * A deleted row as the app reads it. Only the id and the metadata survive,
 * which is all a tombstone is: "this record is gone, as of this moment,
 * according to this device".
 */
export function toTombstoneRow(tombstone) {
  return {
    id: tombstone.entityId,
    created_at: null,
    updated_at: Number(tombstone.syncUpdatedAt),
    is_deleted: true,
    device_id: tombstone.deviceId ?? null,
  };
}
