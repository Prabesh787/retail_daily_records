import { prisma } from '../../database/prisma-client.js';

/** @param {object} query */
function buildWhere(query) {
  return {
    ...(query.supplierId ? { supplierId: query.supplierId } : {}),
    ...(query.fiscalYearId ? { fiscalYearId: query.fiscalYearId } : {}),
    ...(query.from || query.to
      ? {
          billDate: {
            ...(query.from ? { gte: query.from } : {}),
            ...(query.to ? { lte: query.to } : {}),
          },
        }
      : {}),
    ...(query.search
      ? {
          OR: [
            { billNo: { contains: query.search, mode: 'insensitive' } },
            { description: { contains: query.search, mode: 'insensitive' } },
          ],
        }
      : {}),
  };
}

const listInclude = {
  supplier: { select: { id: true, name: true } },
  fiscalYear: { select: { id: true, name: true } },
};

export const purchaseRepository = {
  findMany(query, skip, take, db = prisma) {
    return db.purchase.findMany({
      where: buildWhere(query),
      include: listInclude,
      orderBy: [{ billDate: 'desc' }, { createdAt: 'desc' }],
      skip,
      take,
    });
  },

  count(query, db = prisma) {
    return db.purchase.count({ where: buildWhere(query) });
  },

  findById(id, db = prisma) {
    return db.purchase.findUnique({
      where: { id },
      include: {
        ...listInclude,
        payments: { orderBy: { paymentDate: 'asc' } },
      },
    });
  },

  create(data, db = prisma) {
    return db.purchase.create({ data });
  },

  update(id, data, db = prisma) {
    return db.purchase.update({ where: { id }, data });
  },

  delete(id, db = prisma) {
    return db.purchase.delete({ where: { id } });
  },

  countPayments(id, db = prisma) {
    return db.supplierPayment.count({ where: { purchaseId: id } });
  },

  /** Scanned copies of the physical bill. Polymorphic, hence no relation. */
  findAttachments(id, db = prisma) {
    return db.attachment.findMany({
      where: { entityType: 'PURCHASE', entityId: id },
      orderBy: { createdAt: 'desc' },
    });
  },
};
