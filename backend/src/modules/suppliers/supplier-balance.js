import { Decimal, serializeMoney } from '../../common/utils/money.js';
import { toIsoDate } from '../../common/utils/nepali-date.js';
import { prisma } from '../../database/prisma-client.js';

/**
 * The one calculation the whole system is built around: what the shop still
 * owes a supplier.
 *
 *   outstanding = opening balance + purchases - payments that are not cancelled
 *
 * It is derived from the transactions every time it is asked for and never
 * stored, which is why there is no "current balance" column anywhere in the
 * schema. A stored total can drift away from the rows that produced it; this
 * cannot.
 *
 * A cheque that has been handed over but not yet debited is counted as paid -
 * the shop has parted with it - while still being reported separately as
 * `unclearedTotal`, because that money has not actually left the bank yet.
 * CANCELLED payments are excluded outright: a bounced cheque settled nothing.
 *
 * Everything here is aggregated in three grouped queries rather than per
 * supplier, so a dashboard covering every supplier is a fixed cost, not one
 * that grows with the supplier list.
 */

const ZERO = () => new Decimal(0);

/** @param {Decimal} value */
const asMoney = (value) => serializeMoney(value);

/**
 * @typedef {object} SupplierBalance
 * @property {string} openingBalance
 * @property {string} purchaseTotal
 * @property {string} paidTotal       Cleared plus issued-but-uncleared.
 * @property {string} clearedTotal
 * @property {string} unclearedTotal  Cheques handed over, not yet debited.
 * @property {string} outstanding
 * @property {number} billCount
 * @property {number} paymentCount
 */

/**
 * Balances for many suppliers at once.
 *
 * @param {Array<{ id: string, openingBalance: unknown }>} suppliers
 * @param {import('@prisma/client').PrismaClient} [db]
 * @returns {Promise<Map<string, SupplierBalance>>}
 */
export async function buildSupplierBalances(suppliers, db = prisma) {
  const supplierIds = suppliers.map((supplier) => supplier.id);
  if (supplierIds.length === 0) return new Map();

  const scope = { supplierId: { in: supplierIds } };

  const [purchaseTotals, paymentTotals] = await Promise.all([
    db.purchase.groupBy({
      by: ['supplierId'],
      where: scope,
      _sum: { amount: true },
      _count: { _all: true },
    }),
    db.supplierPayment.groupBy({
      by: ['supplierId', 'status'],
      where: { ...scope, status: { not: 'CANCELLED' } },
      _sum: { amount: true },
      _count: { _all: true },
    }),
  ]);

  const purchasesBySupplier = new Map(purchaseTotals.map((row) => [row.supplierId, row]));

  const paymentsBySupplier = new Map();
  for (const row of paymentTotals) {
    const entry = paymentsBySupplier.get(row.supplierId) ?? {
      cleared: ZERO(),
      uncleared: ZERO(),
      count: 0,
    };
    const amount = new Decimal(row._sum.amount ?? 0);
    // ISSUED is the only other status left after CANCELLED is filtered out.
    if (row.status === 'CLEARED') entry.cleared = entry.cleared.plus(amount);
    else entry.uncleared = entry.uncleared.plus(amount);
    entry.count += row._count._all;
    paymentsBySupplier.set(row.supplierId, entry);
  }

  const balances = new Map();

  for (const supplier of suppliers) {
    const purchased = purchasesBySupplier.get(supplier.id);
    const paid = paymentsBySupplier.get(supplier.id);

    const opening = new Decimal(supplier.openingBalance ?? 0);
    const purchaseTotal = new Decimal(purchased?._sum.amount ?? 0);
    const clearedTotal = paid?.cleared ?? ZERO();
    const unclearedTotal = paid?.uncleared ?? ZERO();
    const paidTotal = clearedTotal.plus(unclearedTotal);

    balances.set(supplier.id, {
      openingBalance: asMoney(opening),
      purchaseTotal: asMoney(purchaseTotal),
      paidTotal: asMoney(paidTotal),
      clearedTotal: asMoney(clearedTotal),
      unclearedTotal: asMoney(unclearedTotal),
      outstanding: asMoney(opening.plus(purchaseTotal).minus(paidTotal)),
      billCount: purchased?._count._all ?? 0,
      paymentCount: paid?.count ?? 0,
    });
  }

  return balances;
}

/**
 * Every supplier, each with its balance attached, ordered by what is owed -
 * largest exposure first. Backs GET /reports/supplier-outstanding and the
 * payable section of the dashboard.
 *
 * @param {{ onlyOutstanding?: boolean, isActive?: boolean }} [options]
 * @param {import('@prisma/client').PrismaClient} [db]
 */
export async function listSuppliersWithBalance(options = {}, db = prisma) {
  const suppliers = await db.supplier.findMany({
    where: options.isActive === undefined ? {} : { isActive: options.isActive },
    orderBy: { name: 'asc' },
  });

  const balances = await buildSupplierBalances(suppliers, db);

  return suppliers
    .map((supplier) => ({
      ...supplier,
      openingBalance: serializeMoney(supplier.openingBalance),
      balance: balances.get(supplier.id),
    }))
    .filter((row) => !options.onlyOutstanding || Number(row.balance.outstanding) > 0)
    .sort((a, b) => Number(b.balance.outstanding) - Number(a.balance.outstanding));
}

/**
 * The same arithmetic narrowed to one date window - a statement rather than a
 * position.
 *
 * `openingAsOf` is what was carried into `from`: the supplier's opening balance
 * plus every movement before that date. Without it the window's closing figure
 * would be a total of the window alone and would not reconcile with the
 * all-time balance, which is the one number the shopkeeper checks it against.
 *
 * @param {{ id: string, openingBalance: unknown }} supplier
 * @param {Date} [from]
 * @param {Date} [to]
 * @param {import('@prisma/client').PrismaClient} [db]
 */
export async function buildSupplierWindow(supplier, from, to, db = prisma) {
  const settled = { supplierId: supplier.id, status: { not: 'CANCELLED' } };
  const inWindow = (field) =>
    from || to ? { [field]: { ...(from ? { gte: from } : {}), ...(to ? { lte: to } : {}) } } : {};

  const [priorPurchases, priorPayments, windowPurchases, windowPayments] = await Promise.all([
    // Nothing is "before" an unbounded window, so these stay zero and
    // `openingAsOf` collapses to the opening balance.
    from
      ? db.purchase.aggregate({
          where: { supplierId: supplier.id, billDate: { lt: from } },
          _sum: { amount: true },
        })
      : { _sum: { amount: 0 } },
    from
      ? db.supplierPayment.aggregate({
          where: { ...settled, paymentDate: { lt: from } },
          _sum: { amount: true },
        })
      : { _sum: { amount: 0 } },
    db.purchase.aggregate({
      where: { supplierId: supplier.id, ...inWindow('billDate') },
      _sum: { amount: true },
      _count: { _all: true },
    }),
    db.supplierPayment.groupBy({
      by: ['status'],
      where: { ...settled, ...inWindow('paymentDate') },
      _sum: { amount: true },
      _count: { _all: true },
    }),
  ]);

  const openingAsOf = new Decimal(supplier.openingBalance ?? 0)
    .plus(priorPurchases._sum.amount ?? 0)
    .minus(priorPayments._sum.amount ?? 0);

  const purchaseTotal = new Decimal(windowPurchases._sum.amount ?? 0);

  let clearedTotal = ZERO();
  let unclearedTotal = ZERO();
  let paymentCount = 0;
  for (const row of windowPayments) {
    const amount = new Decimal(row._sum.amount ?? 0);
    if (row.status === 'CLEARED') clearedTotal = clearedTotal.plus(amount);
    else unclearedTotal = unclearedTotal.plus(amount);
    paymentCount += row._count._all;
  }
  const paymentTotal = clearedTotal.plus(unclearedTotal);

  return {
    from: toIsoDate(from),
    to: toIsoDate(to),
    openingAsOf: asMoney(openingAsOf),
    purchaseTotal: asMoney(purchaseTotal),
    paymentTotal: asMoney(paymentTotal),
    clearedTotal: asMoney(clearedTotal),
    unclearedTotal: asMoney(unclearedTotal),
    closing: asMoney(openingAsOf.plus(purchaseTotal).minus(paymentTotal)),
    billCount: windowPurchases._count._all,
    paymentCount,
  };
}
