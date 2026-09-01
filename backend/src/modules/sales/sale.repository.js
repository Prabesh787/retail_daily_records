import { prisma } from '../../database/prisma-client.js';

function buildWhere(query) {
  return {
    ...(query.fiscalYearId ? { fiscalYearId: query.fiscalYearId } : {}),
    ...(query.customerId ? { customerId: query.customerId } : {}),
    ...(query.saleType ? { saleType: query.saleType } : {}),
    ...(query.from || query.to
      ? {
          saleDate: {
            ...(query.from ? { gte: query.from } : {}),
            ...(query.to ? { lte: query.to } : {}),
          },
        }
      : {}),
    ...(query.search
      ? {
          OR: [
            { invoiceNo: { contains: query.search, mode: 'insensitive' } },
            { description: { contains: query.search, mode: 'insensitive' } },
          ],
        }
      : {}),
  };
}

const listInclude = {
  customer: { select: { id: true, name: true } },
  fiscalYear: { select: { id: true, name: true } },
};

export const saleRepository = {
  findMany(query, skip, take, db = prisma) {
    return db.sale.findMany({
      where: buildWhere(query),
      include: listInclude,
      orderBy: [{ saleDate: 'desc' }, { createdAt: 'desc' }],
      skip,
      take,
    });
  },

  count(query, db = prisma) {
    return db.sale.count({ where: buildWhere(query) });
  },

  findById(id, db = prisma) {
    return db.sale.findUnique({
      where: { id },
      include: {
        ...listInclude,
        items: { orderBy: { createdAt: 'asc' } },
        payments: { orderBy: { createdAt: 'asc' } },
      },
    });
  },

  create(data, db = prisma) {
    return db.sale.create({ data });
  },

  update(id, data, db = prisma) {
    return db.sale.update({ where: { id }, data });
  },

  delete(id, db = prisma) {
    return db.sale.delete({ where: { id } });
  },

  /**
   * The day book spans all three ledgers, so the two queries below reach past
   * sales on purpose: "what happened on this date" is one question, and
   * answering it from three separate round trips through three modules would
   * only spread it out.
   */

  /** Every sale recorded on one calendar day. */
  findByDate(date, db = prisma) {
    return db.sale.findMany({
      where: { saleDate: date },
      include: { ...listInclude, items: { orderBy: { createdAt: 'asc' } }, payments: true },
      orderBy: { createdAt: 'asc' },
    });
  },

  /** Every supplier bill dated that day. */
  findPurchasesByDate(date, db = prisma) {
    return db.purchase.findMany({
      where: { billDate: date },
      include: { supplier: { select: { id: true, name: true, phone: true } } },
      orderBy: { createdAt: 'asc' },
    });
  },

  /** Every payment made to a supplier that day, cancelled ones included so the
   * page can show that a cheque was voided rather than silently omitting it. */
  findPaymentsByDate(date, db = prisma) {
    return db.supplierPayment.findMany({
      where: { paymentDate: date },
      include: {
        supplier: { select: { id: true, name: true, phone: true } },
        purchase: { select: { id: true, billNo: true, billDate: true, amount: true } },
      },
      orderBy: { createdAt: 'asc' },
    });
  },
};
