import { BusinessRuleError, NotFoundError } from '../../common/errors/index.js';
import { buildPaginationMeta, resolvePagination } from '../../common/utils/pagination.js';
import { prisma } from '../../database/prisma-client.js';

/**
 * Fiscal years are plain data, deliberately not hard-coded anywhere. Every
 * transaction (purchase, supplier payment, sale) points at one, which is what
 * makes per-year reporting and per-year document numbering possible.
 */
export const fiscalYearService = {
  async list(query) {
    const pagination = resolvePagination(query.page, query.limit);
    const [items, total] = await Promise.all([
      prisma.fiscalYear.findMany({
        orderBy: { startDate: 'desc' },
        skip: pagination.skip,
        take: pagination.limit,
      }),
      prisma.fiscalYear.count(),
    ]);
    return { items, meta: buildPaginationMeta(pagination, total) };
  },

  async getById(id) {
    const fiscalYear = await prisma.fiscalYear.findUnique({ where: { id } });
    if (!fiscalYear) throw new NotFoundError('Fiscal year', id);
    return fiscalYear;
  },

  /** The year new transactions default to when the client does not name one. */
  async getActive() {
    const active = await prisma.fiscalYear.findFirst({ where: { isActive: true } });
    if (!active) {
      throw new BusinessRuleError(
        'No active fiscal year is configured. Create one and mark it active before recording transactions.',
      );
    }
    return active;
  },

  /**
   * Exactly one year may be active at a time. The switch happens inside a
   * transaction so the table is never observed with two active years; a
   * partial unique index enforces the same rule at the storage level.
   */
  async create(dto) {
    return prisma.$transaction(async (tx) => {
      if (dto.isActive) {
        await tx.fiscalYear.updateMany({ where: { isActive: true }, data: { isActive: false } });
      }
      return tx.fiscalYear.create({ data: dto });
    });
  },

  async update(id, dto) {
    await this.getById(id);
    return prisma.$transaction(async (tx) => {
      if (dto.isActive === true) {
        await tx.fiscalYear.updateMany({
          where: { isActive: true, NOT: { id } },
          data: { isActive: false },
        });
      }
      return tx.fiscalYear.update({ where: { id }, data: dto });
    });
  },

  async activate(id) {
    await this.getById(id);
    return prisma.$transaction(async (tx) => {
      await tx.fiscalYear.updateMany({
        where: { isActive: true, NOT: { id } },
        data: { isActive: false },
      });
      return tx.fiscalYear.update({ where: { id }, data: { isActive: true } });
    });
  },

  /** A fiscal year that already holds transactions is never removable. */
  async remove(id) {
    await this.getById(id);
    const [purchases, payments, sales] = await Promise.all([
      prisma.purchase.count({ where: { fiscalYearId: id } }),
      prisma.supplierPayment.count({ where: { fiscalYearId: id } }),
      prisma.sale.count({ where: { fiscalYearId: id } }),
    ]);
    const total = purchases + payments + sales;
    if (total > 0) {
      throw new BusinessRuleError(
        `This fiscal year holds ${total} transaction record(s) and cannot be deleted.`,
      );
    }
    await prisma.fiscalYear.delete({ where: { id } });
  },
};
