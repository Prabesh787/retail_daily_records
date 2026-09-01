import { adToBs, toIsoDate } from '../utils/nepali-date.js';
import { serializeMoney, serializeQuantity } from '../utils/money.js';

/**
 * Every response body is assembled here rather than handed straight out of
 * Prisma, for two reasons.
 *
 * Money: `numeric(14,2)` reaches the client as a fixed 2dp *string*, never a
 * float, so nothing is rounded on the way through JSON.
 *
 * Dates: every date the API emits is a plain `YYYY-MM-DD` string carrying its
 * Bikram Sambat twin. The shop works in BS, so a response that only names AD is
 * one the shopkeeper has to translate by hand. The rule is the same everywhere:
 *
 *   the `*_bs` string stored with the record wins - it is what was actually
 *   typed on the paperwork - and only when it is empty is BS derived from the
 *   AD date, so a row saved without one still reads correctly.
 *
 * AD stays alongside BS in every case; it is what the printed paperwork and
 * the bank statement use.
 */

/**
 * @param {string | null | undefined} storedBs
 * @param {Date | string | null | undefined} adDate
 */
export function bsFor(storedBs, adDate) {
  return storedBs || adToBs(adDate);
}

/**
 * The pair every date in a response is expressed as. Returned as two fields so
 * callers can name them (`billDate` / `billDateBs`) exactly as the rest of the
 * API already does.
 *
 * @param {Date | string | null | undefined} adDate
 * @param {string | null | undefined} storedBs
 */
export function datePair(adDate, storedBs) {
  return { ad: toIsoDate(adDate), bs: bsFor(storedBs, adDate) };
}

/**
 * @param {object} supplier Optionally carrying the derived `balance` / `window`
 *   and the ledger rows the detail endpoint attaches.
 */
export function serializeSupplier(supplier) {
  if (!supplier) return null;
  return {
    ...supplier,
    ...(supplier.openingBalance === undefined
      ? {}
      : { openingBalance: serializeMoney(supplier.openingBalance) }),
    ...(supplier.purchases ? { purchases: supplier.purchases.map(serializePurchase) } : {}),
    ...(supplier.payments ? { payments: supplier.payments.map(serializePayment) } : {}),
  };
}

/** @param {object} purchase A purchase row, optionally with `supplier` included. */
export function serializePurchase(purchase) {
  if (!purchase) return null;
  return {
    ...purchase,
    billDate: toIsoDate(purchase.billDate),
    billDateBs: bsFor(purchase.billDateBs, purchase.billDate),
    amount: serializeMoney(purchase.amount),
    ...(purchase.supplier ? { supplier: serializeSupplier(purchase.supplier) } : {}),
  };
}

/** @param {object} payment A supplier payment, optionally with `supplier` / `purchase`. */
export function serializePayment(payment) {
  if (!payment) return null;
  return {
    ...payment,
    paymentDate: toIsoDate(payment.paymentDate),
    paymentDateBs: bsFor(payment.paymentDateBs, payment.paymentDate),
    // Null stays null: an uncleared cheque has no cleared date to show, in
    // either calendar.
    chequeDate: toIsoDate(payment.chequeDate),
    chequeDateBs: payment.chequeDate ? bsFor(payment.chequeDateBs, payment.chequeDate) : null,
    clearedDate: toIsoDate(payment.clearedDate),
    clearedDateBs: payment.clearedDate ? adToBs(payment.clearedDate) : null,
    amount: serializeMoney(payment.amount),
    ...(payment.supplier ? { supplier: serializeSupplier(payment.supplier) } : {}),
    ...(payment.purchase ? { purchase: serializePurchase(payment.purchase) } : {}),
  };
}

/** @param {object} sale A sale row, optionally with `customer` / `items` / `payments`. */
export function serializeSale(sale) {
  if (!sale) return null;
  return {
    ...sale,
    saleDate: toIsoDate(sale.saleDate),
    saleDateBs: bsFor(sale.saleDateBs, sale.saleDate),
    subtotal: serializeMoney(sale.subtotal),
    discount: serializeMoney(sale.discount),
    totalAmount: serializeMoney(sale.totalAmount),
    ...(sale.items
      ? {
          items: sale.items.map((item) => ({
            ...item,
            quantity: serializeQuantity(item.quantity),
            unitPrice: serializeMoney(item.unitPrice),
            discount: serializeMoney(item.discount),
            amount: serializeMoney(item.amount),
          })),
        }
      : {}),
    ...(sale.payments
      ? {
          payments: sale.payments.map((payment) => ({
            ...payment,
            amount: serializeMoney(payment.amount),
            chequeDate: toIsoDate(payment.chequeDate),
            chequeDateBs: payment.chequeDate ? adToBs(payment.chequeDate) : null,
            clearedDate: toIsoDate(payment.clearedDate),
            clearedDateBs: payment.clearedDate ? adToBs(payment.clearedDate) : null,
          })),
        }
      : {}),
  };
}

/** @param {object} fiscalYear */
export function serializeFiscalYear(fiscalYear) {
  if (!fiscalYear) return null;
  return {
    ...fiscalYear,
    startDate: toIsoDate(fiscalYear.startDate),
    startDateBs: bsFor(fiscalYear.startDateBs, fiscalYear.startDate),
    endDate: toIsoDate(fiscalYear.endDate),
    endDateBs: bsFor(fiscalYear.endDateBs, fiscalYear.endDate),
  };
}

/**
 * @param {object} customer Optionally carrying the derived `saleCount` /
 *   `saleTotal` the customer list attaches.
 */
export function serializeCustomer(customer) {
  if (!customer) return null;
  return {
    ...customer,
    ...(customer.saleTotal === undefined ? {} : { saleTotal: serializeMoney(customer.saleTotal) }),
    ...(customer.sales ? { sales: customer.sales.map(serializeSale) } : {}),
  };
}

/** @param {object} attachment */
export function serializeAttachment(attachment) {
  if (!attachment) return null;
  return { ...attachment };
}

/**
 * The shop the user trades as, as one nested object rather than four loose
 * `shop*` columns. It used to be built from SHOP_* environment variables, so
 * clients that already read `shop.name` did not have to change when it moved
 * onto the row - only where the value comes from did.
 *
 * Every field may be null: an account nobody has filled the form in for yet is
 * a normal state.
 *
 * @param {object} user A `users` row selected with the shop columns.
 */
export function serializeShop(user) {
  if (!user) return null;
  return {
    name: user.shopName ?? null,
    address: user.shopAddress ?? null,
    phone: user.shopPhone ?? null,
    pan: user.shopPan ?? null,
  };
}

/**
 * A user row as the API publishes it: `passwordHash` gone whatever the caller
 * selected, and the shop columns folded into `shop`.
 *
 * @param {object} user
 */
export function serializeUser(user) {
  if (!user) return null;
  const {
    passwordHash: _passwordHash,
    shopName: _shopName,
    shopAddress: _shopAddress,
    shopPhone: _shopPhone,
    shopPan: _shopPan,
    ...rest
  } = user;
  return { ...rest, shop: serializeShop(user) };
}
