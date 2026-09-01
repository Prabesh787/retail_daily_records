import { prisma } from '../../database/prisma-client.js';

/**
 * Read side of the reports. Everything here is an aggregate or a small "top N"
 * slice - a dashboard must not load the whole ledger into memory to add it up,
 * so the summing happens in Postgres and only the rows actually rendered come
 * back as records.
 *
 * Every method takes an optional `db` so a report can be run inside a
 * transaction alongside other reads and see one consistent snapshot.
 */

const saleInclude = {
  customer: { select: { id: true, name: true, phone: true } },
  items: { orderBy: { createdAt: 'asc' } },
  payments: { orderBy: { createdAt: 'asc' } },
};

const purchaseInclude = {
  supplier: { select: { id: true, name: true, phone: true } },
};

const paymentInclude = {
  supplier: { select: { id: true, name: true, phone: true } },
  purchase: { select: { id: true, billNo: true, billDate: true, billDateBs: true, amount: true } },
};

/** Inclusive `[from, to]` on a `@db.Date` column. */
const between = (from, to) => ({ gte: from, lte: to });

export const reportRepository = {
  /**
   * Total and count of sales in a date window.
   *
   * @param {Date} from
   * @param {Date} to
   */
  async salesSummary(from, to, db = prisma) {
    const result = await db.sale.aggregate({
      where: { saleDate: between(from, to) },
      _sum: { totalAmount: true },
      _count: { _all: true },
    });
    return { total: result._sum.totalAmount ?? 0, count: result._count._all };
  },

  /**
   * @param {Date} from
   * @param {Date} to
   */
  async purchasesSummary(from, to, db = prisma) {
    const result = await db.purchase.aggregate({
      where: { billDate: between(from, to) },
      _sum: { amount: true },
      _count: { _all: true },
    });
    return { total: result._sum.amount ?? 0, count: result._count._all };
  },

  /**
   * @param {Date} from
   * @param {Date} to
   */
  async supplierPaymentsSummary(from, to, db = prisma) {
    const result = await db.supplierPayment.aggregate({
      where: { paymentDate: between(from, to), status: { not: 'CANCELLED' } },
      _sum: { amount: true },
      _count: { _all: true },
    });
    return { total: result._sum.amount ?? 0, count: result._count._all };
  },

  /**
   * One row per day that had sales, for the trend line. Days with no sales are
   * simply absent and are filled in as zero by the service - a gap in a bar
   * chart has to read as "nothing sold", not as "no data".
   *
   * @param {Date} from
   * @param {Date} to
   */
  salesPerDay(from, to, db = prisma) {
    return db.sale.groupBy({
      by: ['saleDate'],
      where: { saleDate: between(from, to) },
      _sum: { totalAmount: true },
      _count: { _all: true },
      orderBy: { saleDate: 'asc' },
    });
  },

  /**
   * Cheques handed to a supplier that the bank has not debited yet. Counted in
   * full but only the nearest few are returned as records, because the
   * dashboard shows the next one due and a total, nothing more.
   *
   * @param {number} take
   */
  async unclearedCheques(take, db = prisma) {
    const where = { status: 'ISSUED', paymentMode: 'CHEQUE' };
    const [summary, next] = await Promise.all([
      db.supplierPayment.aggregate({ where, _sum: { amount: true }, _count: { _all: true } }),
      db.supplierPayment.findMany({
        where,
        include: paymentInclude,
        // Ordered by the date written on the cheque: the order the money has
        // to be in the account.
        orderBy: [{ chequeDate: 'asc' }, { paymentDate: 'asc' }],
        take,
      }),
    ]);
    return { total: summary._sum.amount ?? 0, count: summary._count._all, next };
  },

  /** @param {number} take */
  recentSales(take, db = prisma) {
    return db.sale.findMany({
      include: saleInclude,
      orderBy: [{ saleDate: 'desc' }, { createdAt: 'desc' }],
      take,
    });
  },

  /** @param {number} take */
  recentPurchases(take, db = prisma) {
    return db.purchase.findMany({
      include: purchaseInclude,
      orderBy: [{ billDate: 'desc' }, { createdAt: 'desc' }],
      take,
    });
  },

  activeFiscalYear(db = prisma) {
    return db.fiscalYear.findFirst({ where: { isActive: true } });
  },
};
