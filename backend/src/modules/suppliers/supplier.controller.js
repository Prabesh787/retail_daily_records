import { validatedQuery } from '../../common/middleware/validate.js';
import { sendCreated, sendNoContent, sendSuccess } from '../../common/utils/api-response.js';
import { supplierService } from './supplier.service.js';

export const supplierController = {
  async list(req, res) {
    const { items, meta } = await supplierService.list(validatedQuery(req));
    return sendSuccess(res, items, 'Suppliers fetched successfully', 200, meta);
  },

  async getById(req, res) {
    const supplier = await supplierService.getById(req.params.id, validatedQuery(req));
    return sendSuccess(res, supplier, 'Supplier fetched successfully');
  },

  async create(req, res) {
    const supplier = await supplierService.create(req.body);
    return sendCreated(res, supplier, 'Supplier created successfully');
  },

  async update(req, res) {
    const supplier = await supplierService.update(req.params.id, req.body);
    return sendSuccess(res, supplier, 'Supplier updated successfully');
  },

  async remove(req, res) {
    await supplierService.remove(req.params.id);
    return sendNoContent(res);
  },
};
