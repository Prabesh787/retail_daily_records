import {
  BusinessRuleError,
  DuplicateResourceError,
  NotFoundError,
} from '../../common/errors/index.js';
import { buildPaginationMeta, resolvePagination } from '../../common/utils/pagination.js';
import { Decimal, serializeMoney } from '../../common/utils/money.js';
import { serializeAttachment, serializePurchase } from '../../common/serializers/index.js';
import { prisma } from '../../database/prisma-client.js';
import { fiscalYearService } from '../fiscal-years/fiscal-year.service.js';
import { purchaseRepository } from './purchase.repository.js';

/**
 * A purchase is a LUMP-SUM whole bill: one supplier, one bill number, one
 * amount. There are deliberately no line items, no product master and no stock
 * - the shop records what it was billed, not what is on the shelf.
 *
 * Nothing here stores a balance. What is owed to a supplier is always derived
 * from these bills and the payments against them.
 */

/** Bill numbers are unique per supplier per fiscal year, not globally. */
function asDuplicateBill(error, billNo) {
  if (error?.code !== 'P2002') return error;
  return new DuplicateResourceError(
    `Bill number "${billNo}" is already recorded for this supplier in this fiscal year`,
    [{ field: 'billNo', message: 'Already used for this supplier this year' }],
  );
}

export const purchaseService = {
  async list(query) {
    const pagination = resolvePagination(query.page, query.limit);
    const [items, total] = await Promise.all([
      purchaseRepository.findMany(query, pagination.skip, pagination.limit),
      purchaseRepository.count(query),
    ]);
    return { items: items.map(serializePurchase), meta: buildPaginationMeta(pagination, total) };
  },

  /**
   * The bill plus what has been paid against it. `dueTotal` is the figure the
   * shopkeeper actually acts on, so it is derived here rather than left to the
   * client to subtract.
   */
  async getById(id) {
    const purchase = await purchaseRepository.findById(id);
    if (!purchase) throw new NotFoundError('Purchase', id);

    // A cancelled cheque settled nothing, so it does not count as paid.
    const settled = purchase.payments.filter((payment) => payment.status !== 'CANCELLED');
    const paidTotal = settled.reduce(
      (total, payment) => total.plus(payment.amount),
      new Decimal(0),
    );

    const attachments = await purchaseRepository.findAttachments(id);

    return {
      ...serializePurchase(purchase),
      paidTotal: serializeMoney(paidTotal),
      dueTotal: serializeMoney(new Decimal(purchase.amount).minus(paidTotal)),
      attachments: attachments.map(serializeAttachment),
    };
  },

  /**
   * Recording a bill. The supplier is checked first so a bad reference comes
   * back as "supplier not found" rather than as a foreign key error, and the
   * fiscal year falls back to the active one when the client does not name it.
   *
   * @param {object} dto
   * @param {string | null} [userId]
   */
  async create(dto, userId = null) {
    const { fiscalYearId: requestedFiscalYear, ...rest } = dto;

    const supplier = await prisma.supplier.findUnique({ where: { id: rest.supplierId } });
    if (!supplier) throw new NotFoundError('Supplier', rest.supplierId);
    if (!supplier.isActive) {
      throw new BusinessRuleError(
        `${supplier.name} is deactivated. Reactivate the supplier before recording a bill against it.`,
      );
    }

    const fiscalYearId = requestedFiscalYear ?? (await fiscalYearService.getActive()).id;

    try {
      const purchase = await purchaseRepository.create({
        ...rest,
        fiscalYearId,
        createdById: userId,
      });
      return serializePurchase(await purchaseRepository.findById(purchase.id));
    } catch (error) {
      throw asDuplicateBill(error, rest.billNo);
    }
  },

  /**
   * Amount, date and description stay editable - a bill gets keyed in wrong and
   * has to be corrected. Moving a bill to a different supplier does not, once
   * payments point at it: that would silently move money between two ledgers.
   */
  async update(id, dto) {
    const existing = await purchaseRepository.findById(id);
    if (!existing) throw new NotFoundError('Purchase', id);

    if (dto.supplierId && dto.supplierId !== existing.supplierId) {
      const settled = existing.payments.filter((payment) => payment.status !== 'CANCELLED');
      if (settled.length > 0) {
        throw new BusinessRuleError(
          `This bill has ${settled.length} payment(s) recorded against it, so it cannot be moved to another supplier. Cancel the payments first.`,
        );
      }
      const supplier = await prisma.supplier.findUnique({ where: { id: dto.supplierId } });
      if (!supplier) throw new NotFoundError('Supplier', dto.supplierId);
    }

    try {
      await purchaseRepository.update(id, dto);
    } catch (error) {
      throw asDuplicateBill(error, dto.billNo ?? existing.billNo);
    }
    return this.getById(id);
  },

  /**
   * A bill that has been paid against is never deleted - the payment would be
   * left pointing at nothing and the supplier's history would stop adding up.
   */
  async remove(id) {
    const existing = await purchaseRepository.findById(id);
    if (!existing) throw new NotFoundError('Purchase', id);

    const payments = await purchaseRepository.countPayments(id);
    if (payments > 0) {
      throw new BusinessRuleError(
        `This bill has ${payments} payment(s) recorded against it and cannot be deleted. Cancel or reassign the payments first.`,
      );
    }
    await purchaseRepository.delete(id);
  },
};
