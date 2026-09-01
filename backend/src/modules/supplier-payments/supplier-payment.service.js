import { PaymentStatus, SupplierPaymentMode } from '../../database/generated/prisma/index.js';
import {
  BusinessRuleError,
  DuplicateResourceError,
  NotFoundError,
} from '../../common/errors/index.js';
import { buildPaginationMeta, resolvePagination } from '../../common/utils/pagination.js';
import { serializePayment } from '../../common/serializers/index.js';
import { prisma } from '../../database/prisma-client.js';
import { fiscalYearService } from '../fiscal-years/fiscal-year.service.js';
import { supplierPaymentRepository } from './supplier-payment.repository.js';

/**
 * Payments live apart from purchases so that every settlement pattern the shop
 * actually uses is expressible: fully paid, partly paid, fully on credit, part
 * cash plus a future-dated cheque, or paid long after the bill.
 *
 * Status is what makes a future-dated cheque a real record rather than a note:
 *
 *   ISSUED    the cheque is written and handed over, the bank has not paid it
 *   CLEARED   the money has actually left the account (normal state for cash)
 *   CANCELLED voided or bounced - it settled nothing and is excluded from every
 *             total
 */

/** Voucher numbers are unique within a fiscal year. */
function asDuplicateVoucher(error, voucherNo) {
  if (error?.code !== 'P2002') return error;
  return new DuplicateResourceError(`Voucher number "${voucherNo}" is already used this year`, [
    { field: 'voucherNo', message: 'Already used this fiscal year' },
  ]);
}

/**
 * Cash is money already gone; a cheque is only a promise until the bank pays
 * it. That difference is the default, so the shopkeeper does not have to set a
 * status on an ordinary cash payment.
 */
function defaultStatus(paymentMode) {
  return paymentMode === SupplierPaymentMode.CHEQUE ? PaymentStatus.ISSUED : PaymentStatus.CLEARED;
}

export const supplierPaymentService = {
  async list(query) {
    const pagination = resolvePagination(query.page, query.limit);
    const [items, total] = await Promise.all([
      supplierPaymentRepository.findMany(query, pagination.skip, pagination.limit),
      supplierPaymentRepository.count(query),
    ]);
    return { items: items.map(serializePayment), meta: buildPaginationMeta(pagination, total) };
  },

  async getById(id) {
    const payment = await supplierPaymentRepository.findById(id);
    if (!payment) throw new NotFoundError('Supplier payment', id);
    return serializePayment(payment);
  },

  /**
   * Cheque register: every cheque handed to a supplier with its issue date,
   * the date written on the cheque, its clearance date and its status.
   */
  async chequeRegister(query) {
    const pagination = resolvePagination(query.page, query.limit);
    const [items, total] = await supplierPaymentRepository.findChequeRegister(
      query,
      pagination.skip,
      pagination.limit,
    );
    return { items: items.map(serializePayment), meta: buildPaginationMeta(pagination, total) };
  },

  /**
   * @param {object} dto
   * @param {string | null} [userId]
   */
  async create(dto, userId = null) {
    const { fiscalYearId: requestedFiscalYear, ...rest } = dto;

    const supplier = await prisma.supplier.findUnique({ where: { id: rest.supplierId } });
    if (!supplier) throw new NotFoundError('Supplier', rest.supplierId);

    // A payment may settle one named bill or just the running balance. When it
    // does name one, that bill has to belong to the supplier being paid.
    if (rest.purchaseId) {
      const purchase = await prisma.purchase.findUnique({ where: { id: rest.purchaseId } });
      if (!purchase) throw new NotFoundError('Purchase', rest.purchaseId);
      if (purchase.supplierId !== rest.supplierId) {
        throw new BusinessRuleError(
          `Bill ${purchase.billNo} belongs to a different supplier, so this payment cannot be applied to it.`,
        );
      }
    }

    const fiscalYearId = requestedFiscalYear ?? (await fiscalYearService.getActive()).id;
    const status = rest.status ?? defaultStatus(rest.paymentMode);

    // Cash handed over today cleared today; making the client state that twice
    // is how the two dates end up disagreeing.
    const clearedDate =
      status === PaymentStatus.CLEARED ? (rest.clearedDate ?? rest.paymentDate) : null;

    try {
      const payment = await supplierPaymentRepository.create({
        ...rest,
        fiscalYearId,
        status,
        clearedDate,
        createdById: userId,
      });
      return serializePayment(await supplierPaymentRepository.findById(payment.id));
    } catch (error) {
      throw asDuplicateVoucher(error, rest.voucherNo);
    }
  },

  async update(id, dto) {
    const existing = await supplierPaymentRepository.findById(id);
    if (!existing) throw new NotFoundError('Supplier payment', id);

    if (existing.status === PaymentStatus.CANCELLED) {
      throw new BusinessRuleError(
        'A cancelled payment is a historical record and cannot be edited.',
      );
    }

    if (dto.purchaseId && dto.purchaseId !== existing.purchaseId) {
      const purchase = await prisma.purchase.findUnique({ where: { id: dto.purchaseId } });
      if (!purchase) throw new NotFoundError('Purchase', dto.purchaseId);
      if (purchase.supplierId !== existing.supplierId) {
        throw new BusinessRuleError(
          `Bill ${purchase.billNo} belongs to a different supplier, so this payment cannot be applied to it.`,
        );
      }
    }

    try {
      await supplierPaymentRepository.update(id, dto);
    } catch (error) {
      throw asDuplicateVoucher(error, dto.voucherNo ?? existing.voucherNo);
    }
    return this.getById(id);
  },

  /**
   * ISSUED -> CLEARED, stamping the date the bank actually paid it out. This is
   * the entry the shopkeeper makes after checking the bank statement, so it is
   * a state change rather than an edit.
   */
  async clear(id, dto) {
    const payment = await supplierPaymentRepository.findById(id);
    if (!payment) throw new NotFoundError('Supplier payment', id);

    if (payment.status === PaymentStatus.CANCELLED) {
      throw new BusinessRuleError('A cancelled cheque cannot be cleared.');
    }
    if (payment.status === PaymentStatus.CLEARED) {
      throw new BusinessRuleError('This payment is already marked as cleared.');
    }
    if (dto.clearedDate < payment.paymentDate) {
      throw new BusinessRuleError('A payment cannot clear before the date it was made.', [
        { field: 'clearedDate', message: 'Earlier than the payment date' },
      ]);
    }

    await supplierPaymentRepository.update(id, {
      status: PaymentStatus.CLEARED,
      clearedDate: dto.clearedDate,
      ...(dto.remarks ? { remarks: dto.remarks } : {}),
    });
    return this.getById(id);
  },

  /**
   * Voided or bounced. The row stays - the fact that a cheque was written and
   * then failed is part of the history - but it settles nothing, so the cleared
   * date is dropped and every total stops counting it.
   */
  async cancel(id, dto = {}) {
    const payment = await supplierPaymentRepository.findById(id);
    if (!payment) throw new NotFoundError('Supplier payment', id);

    if (payment.status === PaymentStatus.CANCELLED) {
      throw new BusinessRuleError('This payment is already cancelled.');
    }

    await supplierPaymentRepository.update(id, {
      status: PaymentStatus.CANCELLED,
      clearedDate: null,
      ...(dto?.remarks ? { remarks: dto.remarks } : {}),
    });
    return this.getById(id);
  },

  /**
   * Deleting is for a row keyed in by mistake and noticed immediately. Once the
   * money has actually moved, cancelling is the honest record - so a cleared
   * payment is never removed.
   */
  async remove(id) {
    const payment = await supplierPaymentRepository.findById(id);
    if (!payment) throw new NotFoundError('Supplier payment', id);

    if (payment.status === PaymentStatus.CLEARED) {
      throw new BusinessRuleError(
        'This payment has already cleared the bank and cannot be deleted. Cancel it instead, so the history stays auditable.',
      );
    }
    await supplierPaymentRepository.delete(id);
  },
};
