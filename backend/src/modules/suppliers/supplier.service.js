import { BusinessRuleError, NotFoundError } from '../../common/errors/index.js';
import { buildPaginationMeta, resolvePagination } from '../../common/utils/pagination.js';
import { serializeSupplier } from '../../common/serializers/index.js';
import { prisma } from '../../database/prisma-client.js';
import { supplierRepository } from './supplier.repository.js';
import { buildSupplierBalances, buildSupplierWindow } from './supplier-balance.js';

/**
 * Suppliers are the ledger the whole system exists for. Every read here
 * attaches the derived balance, because a supplier without what is owed to
 * them is not an answer to any question the shop actually asks.
 */
export const supplierService = {
  /** Ordered by exposure - the supplier owed the most comes first. */
  async list(query) {
    const pagination = resolvePagination(query.page, query.limit);
    const [items, total] = await Promise.all([
      supplierRepository.findMany(query, pagination.skip, pagination.limit),
      supplierRepository.count(query),
    ]);

    const balances = await buildSupplierBalances(items);
    const rows = items
      .map((supplier) => serializeSupplier({ ...supplier, balance: balances.get(supplier.id) }))
      .sort((a, b) => Number(b.balance.outstanding) - Number(a.balance.outstanding));

    return { items: rows, meta: buildPaginationMeta(pagination, total) };
  },

  /**
   * The supplier, the all-time balance, and the ledger for one date window.
   *
   * `balance` is the position today and never moves with the filters; `window`
   * is the statement for the range being viewed. Both are returned because the
   * screen shows them side by side, and a statement that could not be tied back
   * to the running total would be worth very little.
   *
   * @param {string} id
   * @param {{ from?: Date, to?: Date, search?: string }} [query]
   */
  async getById(id, query = {}) {
    const supplier = await supplierRepository.findById(id);
    if (!supplier) throw new NotFoundError('Supplier', id);

    const { from, to, search } = query;
    const dateFilter = (field) =>
      from || to ? { [field]: { ...(from ? { gte: from } : {}), ...(to ? { lte: to } : {}) } } : {};
    const like = search ? { contains: search, mode: 'insensitive' } : undefined;

    const [balances, window, purchases, payments] = await Promise.all([
      buildSupplierBalances([supplier]),
      buildSupplierWindow(supplier, from, to),
      prisma.purchase.findMany({
        where: {
          supplierId: id,
          ...dateFilter('billDate'),
          ...(like ? { OR: [{ billNo: like }, { description: like }, { remarks: like }] } : {}),
        },
        orderBy: [{ billDate: 'desc' }, { createdAt: 'desc' }],
      }),
      prisma.supplierPayment.findMany({
        where: {
          supplierId: id,
          ...dateFilter('paymentDate'),
          ...(like
            ? {
                OR: [
                  { voucherNo: like },
                  { chequeNo: like },
                  { referenceNo: like },
                  { description: like },
                  // A payment is findable by the bill it settles.
                  { purchase: { billNo: like } },
                ],
              }
            : {}),
        },
        include: {
          purchase: { select: { id: true, billNo: true, billDate: true, amount: true } },
        },
        orderBy: [{ paymentDate: 'desc' }, { createdAt: 'desc' }],
      }),
    ]);

    return serializeSupplier({
      ...supplier,
      balance: balances.get(id),
      window,
      purchases,
      payments,
    });
  },

  async create(dto) {
    const supplier = await supplierRepository.create(dto);
    return this.getById(supplier.id);
  },

  async update(id, dto) {
    const existing = await supplierRepository.findById(id);
    if (!existing) throw new NotFoundError('Supplier', id);
    await supplierRepository.update(id, dto);
    return this.getById(id);
  },

  /**
   * A supplier that already carries purchases or payments is deactivated
   * rather than deleted - the transaction history has to stay auditable.
   */
  async remove(id) {
    const existing = await supplierRepository.findById(id);
    if (!existing) throw new NotFoundError('Supplier', id);

    const transactions = await supplierRepository.countTransactions(id);
    if (transactions > 0) {
      throw new BusinessRuleError(
        `This supplier has ${transactions} transaction record(s) and cannot be deleted. Deactivate it instead.`,
      );
    }
    await supplierRepository.delete(id);
  },
};
