import { prisma } from '../../database/prisma-client.js';
import { SupplierPaymentMode } from '../../database/generated/prisma/index.js';

function buildWhere(query) {
  return {
    ...(query.supplierId ? { supplierId: query.supplierId } : {}),
    ...(query.purchaseId ? { purchaseId: query.purchaseId } : {}),
    ...(query.fiscalYearId ? { fiscalYearId: query.fiscalYearId } : {}),
    ...(query.paymentMode ? { paymentMode: query.paymentMode } : {}),
    ...(query.status ? { status: query.status } : {}),
    ...(query.from || query.to
      ? {
          paymentDate: {
            ...(query.from ? { gte: query.from } : {}),
            ...(query.to ? { lte: query.to } : {}),
          },
        }
      : {}),
    ...(query.search
      ? {
          OR: [
            { voucherNo: { contains: query.search, mode: 'insensitive' } },
            { chequeNo: { contains: query.search, mode: 'insensitive' } },
            { referenceNo: { contains: query.search, mode: 'insensitive' } },
            { description: { contains: query.search, mode: 'insensitive' } },
          ],
        }
      : {}),
  };
}

const listInclude = {
  supplier: { select: { id: true, name: true } },
  purchase: { select: { id: true, billNo: true, billDate: true, amount: true } },
};

export const supplierPaymentRepository = {
  findMany(query, skip, take, db = prisma) {
    return db.supplierPayment.findMany({
      where: buildWhere(query),
      include: listInclude,
      orderBy: [{ paymentDate: 'desc' }, { createdAt: 'desc' }],
      skip,
      take,
    });
  },

  count(query, db = prisma) {
    return db.supplierPayment.count({ where: buildWhere(query) });
  },

  findById(id, db = prisma) {
    return db.supplierPayment.findUnique({ where: { id }, include: listInclude });
  },

  create(data, db = prisma) {
    return db.supplierPayment.create({ data });
  },

  update(id, data, db = prisma) {
    return db.supplierPayment.update({ where: { id }, data });
  },

  delete(id, db = prisma) {
    return db.supplierPayment.delete({ where: { id } });
  },

  /**
   * Cheques only, ordered by the date written on the cheque - that is the
   * order in which the shop needs the money to be in the bank.
   */
  findChequeRegister(query, skip, take, db = prisma) {
    const where = {
      paymentMode: SupplierPaymentMode.CHEQUE,
      ...(query.supplierId ? { supplierId: query.supplierId } : {}),
      ...(query.fiscalYearId ? { fiscalYearId: query.fiscalYearId } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.from || query.to
        ? {
            chequeDate: {
              ...(query.from ? { gte: query.from } : {}),
              ...(query.to ? { lte: query.to } : {}),
            },
          }
        : {}),
    };

    return Promise.all([
      db.supplierPayment.findMany({
        where,
        include: { supplier: { select: { id: true, name: true } } },
        orderBy: [{ chequeDate: 'asc' }],
        skip,
        take,
      }),
      db.supplierPayment.count({ where }),
    ]);
  },
};
