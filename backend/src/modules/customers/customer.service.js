import { BusinessRuleError, NotFoundError } from '../../common/errors/index.js';
import { buildPaginationMeta, resolvePagination } from '../../common/utils/pagination.js';
import { Decimal, serializeMoney } from '../../common/utils/money.js';
import { serializeCustomer } from '../../common/serializers/index.js';
import { prisma } from '../../database/prisma-client.js';

/**
 * Customers are optional. A walk-in retail sale carries `customerId = null`;
 * this module exists so an invoice can be addressed to someone when asked for,
 * not so every buyer has to be registered.
 *
 * What a customer has bought is derived from their sales, never stored, for the
 * same reason supplier balances are.
 */

/**
 * Sale count and value for many customers in one grouped query, rather than one
 * query per row.
 *
 * @param {string[]} customerIds
 */
async function buildSaleTotals(customerIds) {
  if (customerIds.length === 0) return new Map();
  const rows = await prisma.sale.groupBy({
    by: ['customerId'],
    where: { customerId: { in: customerIds } },
    _sum: { totalAmount: true },
    _count: { _all: true },
  });
  return new Map(
    rows.map((row) => [
      row.customerId,
      { saleCount: row._count._all, saleTotal: new Decimal(row._sum.totalAmount ?? 0) },
    ]),
  );
}

const withTotals = (customer, totals) =>
  serializeCustomer({
    ...customer,
    saleCount: totals?.saleCount ?? 0,
    saleTotal: serializeMoney(totals?.saleTotal ?? 0),
  });

export const customerService = {
  async list(query) {
    const pagination = resolvePagination(query.page, query.limit);
    const where = query.search
      ? {
          OR: [
            { name: { contains: query.search, mode: 'insensitive' } },
            { phone: { contains: query.search, mode: 'insensitive' } },
            { address: { contains: query.search, mode: 'insensitive' } },
          ],
        }
      : {};

    const [items, total] = await Promise.all([
      prisma.customer.findMany({
        where,
        orderBy: { name: 'asc' },
        skip: pagination.skip,
        take: pagination.limit,
      }),
      prisma.customer.count({ where }),
    ]);

    const totals = await buildSaleTotals(items.map((customer) => customer.id));

    return {
      items: items.map((customer) => withTotals(customer, totals.get(customer.id))),
      meta: buildPaginationMeta(pagination, total),
    };
  },

  /** The customer plus their recent invoices - what they bought and when. */
  async getById(id) {
    const customer = await prisma.customer.findUnique({ where: { id } });
    if (!customer) throw new NotFoundError('Customer', id);

    const [totals, sales] = await Promise.all([
      buildSaleTotals([id]),
      prisma.sale.findMany({
        where: { customerId: id },
        include: {
          items: { orderBy: { createdAt: 'asc' } },
          payments: { orderBy: { createdAt: 'asc' } },
        },
        orderBy: [{ saleDate: 'desc' }, { createdAt: 'desc' }],
        take: 30,
      }),
    ]);

    return serializeCustomer({
      ...customer,
      saleCount: totals.get(id)?.saleCount ?? 0,
      saleTotal: serializeMoney(totals.get(id)?.saleTotal ?? 0),
      sales,
    });
  },

  async create(dto) {
    const customer = await prisma.customer.create({ data: dto });
    return this.getById(customer.id);
  },

  async update(id, dto) {
    const existing = await prisma.customer.findUnique({ where: { id } });
    if (!existing) throw new NotFoundError('Customer', id);
    await prisma.customer.update({ where: { id }, data: dto });
    return this.getById(id);
  },

  async remove(id) {
    const existing = await prisma.customer.findUnique({ where: { id } });
    if (!existing) throw new NotFoundError('Customer', id);

    const sales = await prisma.sale.count({ where: { customerId: id } });
    if (sales > 0) {
      throw new BusinessRuleError(
        `This customer is referenced by ${sales} sale(s) and cannot be deleted.`,
      );
    }
    await prisma.customer.delete({ where: { id } });
  },
};
