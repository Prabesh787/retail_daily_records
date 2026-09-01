import { validatedQuery } from '../../common/middleware/validate.js';
import { sendCreated, sendNoContent, sendSuccess } from '../../common/utils/api-response.js';
import { purchaseService } from './purchase.service.js';

export const purchaseController = {
  async list(req, res) {
    const { items, meta } = await purchaseService.list(validatedQuery(req));
    return sendSuccess(res, items, 'Purchases fetched successfully', 200, meta);
  },

  async getById(req, res) {
    const purchase = await purchaseService.getById(req.params.id);
    return sendSuccess(res, purchase, 'Purchase fetched successfully');
  },

  async create(req, res) {
    const purchase = await purchaseService.create(req.body, req.user?.id ?? null);
    return sendCreated(res, purchase, 'Purchase recorded successfully');
  },

  async update(req, res) {
    const purchase = await purchaseService.update(req.params.id, req.body);
    return sendSuccess(res, purchase, 'Purchase updated successfully');
  },

  async remove(req, res) {
    await purchaseService.remove(req.params.id);
    return sendNoContent(res);
  },
};
