import { validatedQuery } from '../../common/middleware/validate.js';
import { sendCreated, sendNoContent, sendSuccess } from '../../common/utils/api-response.js';
import { saleService } from './sale.service.js';

export const saleController = {
  async list(req, res) {
    const { items, meta } = await saleService.list(validatedQuery(req));
    return sendSuccess(res, items, 'Sales fetched successfully', 200, meta);
  },

  async dayBook(req, res) {
    const report = await saleService.dayBook(validatedQuery(req).date);
    return sendSuccess(res, report, 'Day book fetched successfully');
  },

  async getById(req, res) {
    const sale = await saleService.getById(req.params.id);
    return sendSuccess(res, sale, 'Sale fetched successfully');
  },

  async create(req, res) {
    const sale = await saleService.create(req.body, req.user?.id ?? null);
    return sendCreated(res, sale, 'Sale recorded successfully');
  },

  async update(req, res) {
    const sale = await saleService.update(req.params.id, req.body);
    return sendSuccess(res, sale, 'Sale updated successfully');
  },

  async remove(req, res) {
    await saleService.remove(req.params.id);
    return sendNoContent(res);
  },
};
