import { SaleType } from '../../database/generated/prisma/index.js';
import {
  BusinessRuleError,
  DuplicateResourceError,
  NotFoundError,
} from '../../common/errors/index.js';
import { buildPaginationMeta, resolvePagination } from '../../common/utils/pagination.js';
import {
  Decimal,
  calculateLineAmount,
  serializeMoney,
  sumMoney,
  toMoney,
} from '../../common/utils/money.js';
import { adToBs, toIsoDate } from '../../common/utils/nepali-date.js';
import {
  serializePayment,
  serializePurchase,
  serializeSale,
} from '../../common/serializers/index.js';
import { prisma } from '../../database/prisma-client.js';
import { fiscalYearService } from '../fiscal-years/fiscal-year.service.js';
import { saleRepository } from './sale.repository.js';

/**
 * Totals for a detailed sale. Kept here rather than in the controller so the
 * rule "amounts are computed, never accepted" has exactly one home.
 *
 * @param {Array<{quantity: number, unitPrice: number, discount?: number}>} items
 * @param {number} saleDiscount Invoice-level discount applied after the lines.
 */
export function calculateSaleTotals(items, saleDiscount = 0) {
  const lines = items.map((item) => ({
    ...item,
    amount: calculateLineAmount(item.quantity, item.unitPrice, item.discount ?? 0),
  }));
  const subtotal = sumMoney(lines.map((line) => line.amount));
  const discount = toMoney(saleDiscount);
  return { lines, subtotal, discount, totalAmount: toMoney(subtotal.minus(discount)) };
}

/**
 * The three money columns for a sale, whichever shape it arrives in.
 *
 * DETAILED is the straightforward direction: the lines are the truth, so the
 * subtotal is their sum and the total is that minus the invoice discount.
 *
 * SUMMARY runs the other way. `totalAmount` is what the customer actually
 * handed over - it is the figure on the screen and the one the shopkeeper
 * typed - so it is taken as the net total and the subtotal is reconstructed
 * from it. Subtracting the discount from it a second time would quietly
 * under-report every summary sale in the shop.
 *
 * @param {object} dto
 */
export function resolveTotals(dto) {
  if (dto.saleType === SaleType.DETAILED) {
    return calculateSaleTotals(dto.items, dto.discount ?? 0);
  }

  const discount = toMoney(dto.discount ?? 0);
  const totalAmount = toMoney(dto.totalAmount ?? 0);
  return { lines: [], subtotal: toMoney(totalAmount.plus(discount)), discount, totalAmount };
}

/** Invoice numbers are unique within a fiscal year. */
function asDuplicateInvoice(error, invoiceNo) {
  if (error?.code !== 'P2002') return error;
  return new DuplicateResourceError(`Invoice number "${invoiceNo}" is already used this year`, [
    { field: 'invoiceNo', message: 'Already used this fiscal year' },
  ]);
}

/**
 * A sale cannot be settled with more money than it is worth. Paying less is
 * perfectly normal - the remainder is credit - so only the upper bound is a
 * rule.
 *
 * @param {Array<{amount: number}>} payments
 * @param {Decimal} totalAmount
 */
function assertPaymentsFit(payments, totalAmount) {
  if (payments.length === 0) return;
  const paid = sumMoney(payments.map((payment) => payment.amount));
  if (paid.greaterThan(totalAmount)) {
    throw new BusinessRuleError(
      `The payments recorded (${serializeMoney(paid)}) come to more than the sale total (${serializeMoney(totalAmount)}).`,
      [{ field: 'payments', message: 'More than the sale total' }],
    );
  }
}

export const saleService = {
  async list(query) {
    const pagination = resolvePagination(query.page, query.limit);
    const [items, total] = await Promise.all([
      saleRepository.findMany(query, pagination.skip, pagination.limit),
      saleRepository.count(query),
    ]);
    return { items: items.map(serializeSale), meta: buildPaginationMeta(pagination, total) };
  },

  async getById(id) {
    const sale = await saleRepository.findById(id);
    if (!sale) throw new NotFoundError('Sale', id);
    return serializeSale(sale);
  },

  /**
   * The sale, its invoice lines and how it was settled are one unit of work:
   * an invoice whose lines failed to save is worse than no invoice at all.
   *
   * @param {object} dto
   * @param {string | null} [userId]
   */
  async create(dto, userId = null) {
    // `items` and `totalAmount` are not columns on `sales` - they are inputs to
    // the totals below - so they are peeled off before the row is built.
    const {
      fiscalYearId: requestedFiscalYear,
      items: _items,
      totalAmount: _net,
      payments,
      ...rest
    } = dto;

    if (rest.customerId) {
      const customer = await prisma.customer.findUnique({ where: { id: rest.customerId } });
      if (!customer) throw new NotFoundError('Customer', rest.customerId);
    }

    const fiscalYearId = requestedFiscalYear ?? (await fiscalYearService.getActive()).id;
    const { lines, subtotal, discount, totalAmount } = resolveTotals(dto);

    if (totalAmount.lessThan(0)) {
      throw new BusinessRuleError('The discount is larger than the sale itself.', [
        { field: 'discount', message: 'More than the sale total' },
      ]);
    }
    assertPaymentsFit(payments ?? [], totalAmount);

    try {
      const sale = await prisma.$transaction(async (tx) =>
        tx.sale.create({
          data: {
            ...rest,
            fiscalYearId,
            createdById: userId,
            subtotal,
            discount,
            totalAmount,
            items: {
              // The order the lines arrived in is the order they were typed
              // in, and it is the order the invoice has to print in.
              create: lines.map((line, index) => ({
                description: line.description,
                quantity: line.quantity,
                unit: line.unit,
                unitPrice: line.unitPrice,
                discount: line.discount ?? 0,
                amount: line.amount,
                sortOrder: index,
              })),
            },
            payments: {
              create: (payments ?? []).map((payment) => ({
                paymentMode: payment.paymentMode,
                amount: payment.amount,
                referenceNo: payment.referenceNo ?? null,
                chequeNo: payment.chequeNo ?? null,
                chequeDate: payment.chequeDate ?? null,
                // CREDIT is money not received yet; everything else is in hand.
                status: payment.status ?? (payment.paymentMode === 'CREDIT' ? 'ISSUED' : 'CLEARED'),
                remarks: payment.remarks ?? null,
              })),
            },
          },
        }),
      );
      return this.getById(sale.id);
    } catch (error) {
      throw asDuplicateInvoice(error, rest.invoiceNo);
    }
  },

  /**
   * Corrections to the header only. The totals of a detailed sale come from its
   * lines, so they are not editable here - changing the lines is what changes
   * the total.
   */
  async update(id, dto) {
    const existing = await saleRepository.findById(id);
    if (!existing) throw new NotFoundError('Sale', id);

    if (dto.customerId && dto.customerId !== existing.customerId) {
      const customer = await prisma.customer.findUnique({ where: { id: dto.customerId } });
      if (!customer) throw new NotFoundError('Customer', dto.customerId);
    }

    const { totalAmount, discount, ...rest } = dto;
    const data = { ...rest };

    if (totalAmount !== undefined || discount !== undefined) {
      if (existing.saleType === SaleType.DETAILED) {
        throw new BusinessRuleError(
          'The total of an itemised sale is derived from its lines. Edit the lines instead.',
          [{ field: 'totalAmount', message: 'Derived from the invoice lines' }],
        );
      }
      const nextTotal = toMoney(totalAmount ?? existing.totalAmount);
      const nextDiscount = toMoney(discount ?? existing.discount);
      data.totalAmount = nextTotal;
      data.discount = nextDiscount;
      data.subtotal = toMoney(nextTotal.plus(nextDiscount));

      const settled = existing.payments ?? [];
      assertPaymentsFit(
        settled.map((payment) => ({ amount: payment.amount })),
        nextTotal,
      );
    }

    try {
      await saleRepository.update(id, data);
    } catch (error) {
      throw asDuplicateInvoice(error, dto.invoiceNo ?? existing.invoiceNo);
    }
    return this.getById(id);
  },

  /** Items and payments are cascaded by the schema, so the sale goes as a whole. */
  async remove(id) {
    const sale = await saleRepository.findById(id);
    if (!sale) throw new NotFoundError('Sale', id);
    await saleRepository.delete(id);
  },

  /**
   * The day book: everything that happened on one date, in one answer.
   *
   * Sales are split by how they were settled, because "took Rs 40,000 today" and
   * "Rs 40,000 of that was on credit" are very different days. CREDIT is
   * reported alongside the rest rather than folded into it, so the cash figure
   * stays a cash figure.
   *
   * @param {Date} date
   */
  async dayBook(date) {
    const [sales, purchases, payments] = await Promise.all([
      saleRepository.findByDate(date),
      saleRepository.findPurchasesByDate(date),
      saleRepository.findPaymentsByDate(date),
    ]);

    const byMode = new Map();
    for (const sale of sales) {
      for (const payment of sale.payments ?? []) {
        const running = byMode.get(payment.paymentMode) ?? new Decimal(0);
        byMode.set(payment.paymentMode, running.plus(payment.amount));
      }
    }

    const settledPayments = payments.filter((payment) => payment.status !== 'CANCELLED');
    const iso = toIsoDate(date);

    return {
      date: iso,
      dateBs: adToBs(iso),
      sales: sales.map(serializeSale),
      purchases: purchases.map(serializePurchase),
      payments: payments.map(serializePayment),
      totals: {
        sales: serializeMoney(sumMoney(sales.map((sale) => sale.totalAmount))),
        saleCount: sales.length,
        purchases: serializeMoney(sumMoney(purchases.map((purchase) => purchase.amount))),
        purchaseCount: purchases.length,
        payments: serializeMoney(sumMoney(settledPayments.map((payment) => payment.amount))),
        paymentCount: settledPayments.length,
        byMode: Object.fromEntries(
          [...byMode].map(([mode, amount]) => [mode, serializeMoney(amount)]),
        ),
      },
    };
  },
};
