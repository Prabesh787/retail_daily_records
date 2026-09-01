import { prisma } from '../../database/prisma-client.js';

/**
 * Data access for suppliers. Every method takes an optional `db` so it can run
 * either on its own or inside a `prisma.$transaction` callback.
 */

/** @param {{ search?: string, isActive?: boolean }} query */
function buildWhere(query) {
  return {
    ...(query.isActive === undefined ? {} : { isActive: query.isActive }),
    ...(query.search
      ? {
          OR: [
            { name: { contains: query.search, mode: 'insensitive' } },
            { phone: { contains: query.search, mode: 'insensitive' } },
            { pan: { contains: query.search, mode: 'insensitive' } },
          ],
        }
      : {}),
  };
}

export const supplierRepository = {
  findMany(query, skip, take, db = prisma) {
    return db.supplier.findMany({ where: buildWhere(query), orderBy: { name: 'asc' }, skip, take });
  },

  count(query, db = prisma) {
    return db.supplier.count({ where: buildWhere(query) });
  },

  findById(id, db = prisma) {
    return db.supplier.findUnique({ where: { id } });
  },

  create(data, db = prisma) {
    return db.supplier.create({ data });
  },

  update(id, data, db = prisma) {
    return db.supplier.update({ where: { id }, data });
  },

  /** Checked before deletion: a supplier with history must never disappear. */
  async countTransactions(id, db = prisma) {
    const [purchases, payments] = await Promise.all([
      db.purchase.count({ where: { supplierId: id } }),
      db.supplierPayment.count({ where: { supplierId: id } }),
    ]);
    return purchases + payments;
  },

  delete(id, db = prisma) {
    return db.supplier.delete({ where: { id } });
  },
};
