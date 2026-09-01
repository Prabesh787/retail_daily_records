/**
 * Enum values mirrored from the Prisma schema, each paired with the label and
 * the visual tone the UI should use for it. Keeping them in one file means a
 * new payment mode is added in exactly one place.
 */

/**
 * Both types are ONE sale to one customer. The difference is only how much
 * detail was written down:
 *
 *   SUMMARY  - the total was enough ("sold 3 shirts, Rs 4,050")
 *   DETAILED - the customer wanted an itemised invoice
 *
 * A day's takings is not a record here; it is the sum of the day's sales.
 */
export const SALE_TYPE = {
  SUMMARY: { label: 'Total only', short: 'Total', tone: 'neutral' },
  DETAILED: { label: 'Itemised', short: 'Itemised', tone: 'info' },
};

export const SUPPLIER_PAYMENT_MODE = {
  CASH: { label: 'Cash', tone: 'success' },
  CHEQUE: { label: 'Cheque', tone: 'warning' },
  BANK_TRANSFER: { label: 'Bank transfer', tone: 'info' },
  OTHER: { label: 'Other', tone: 'neutral' },
};

export const SALE_PAYMENT_MODE = {
  CASH: { label: 'Cash', tone: 'success' },
  BANK: { label: 'Bank', tone: 'info' },
  CHEQUE: { label: 'Cheque', tone: 'warning' },
  CREDIT: { label: 'Credit', tone: 'danger' },
  OTHER: { label: 'Other', tone: 'neutral' },
};

export const PAYMENT_STATUS = {
  ISSUED: { label: 'Issued', tone: 'warning', hint: 'Handed over, not cleared yet' },
  CLEARED: { label: 'Cleared', tone: 'success', hint: 'Money has actually moved' },
  CANCELLED: { label: 'Cancelled', tone: 'neutral', hint: 'Voided or bounced' },
};

export const DOCUMENT_TYPE = {
  PURCHASE_BILL: 'Purchase bill',
  SUPPLIER_PAYMENT_RECEIPT: 'Payment receipt',
  CHEQUE_COPY: 'Cheque copy',
  SALE_INVOICE: 'Sale invoice',
  OTHER: 'Other document',
};

/** Units offered on an invoice line. Free text is still allowed. */
export const SALE_UNITS = ['PCS', 'METER', 'SET', 'PAIR', 'DOZEN', 'KG'];

export const PAGE_SIZE = 20;
