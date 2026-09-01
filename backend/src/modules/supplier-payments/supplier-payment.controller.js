import { validatedQuery } from '../../common/middleware/validate.js';
import { sendCreated, sendNoContent, sendSuccess } from '../../common/utils/api-response.js';
import { supplierPaymentService } from './supplier-payment.service.js';

export const supplierPaymentController = {
  async list(req, res) {
    const { items, meta } = await supplierPaymentService.list(validatedQuery(req));
    return sendSuccess(res, items, 'Supplier payments fetched successfully', 200, meta);
  },

  async chequeRegister(req, res) {
    const { items, meta } = await supplierPaymentService.chequeRegister(validatedQuery(req));
    return sendSuccess(res, items, 'Cheque register fetched successfully', 200, meta);
  },

  async getById(req, res) {
    const payment = await supplierPaymentService.getById(req.params.id);
    return sendSuccess(res, payment, 'Supplier payment fetched successfully');
  },

  async create(req, res) {
    const payment = await supplierPaymentService.create(req.body, req.user?.id ?? null);
    return sendCreated(res, payment, 'Supplier payment recorded successfully');
  },

  async update(req, res) {
    const payment = await supplierPaymentService.update(req.params.id, req.body);
    return sendSuccess(res, payment, 'Supplier payment updated successfully');
  },

  async clear(req, res) {
    const payment = await supplierPaymentService.clear(req.params.id, req.body);
    return sendSuccess(res, payment, 'Payment marked as cleared');
  },

  async cancel(req, res) {
    const payment = await supplierPaymentService.cancel(req.params.id, req.body);
    return sendSuccess(res, payment, 'Payment cancelled');
  },

  async remove(req, res) {
    await supplierPaymentService.remove(req.params.id);
    return sendNoContent(res);
  },
};
