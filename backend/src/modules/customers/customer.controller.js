import { validatedQuery } from '../../common/middleware/validate.js';
import { sendCreated, sendNoContent, sendSuccess } from '../../common/utils/api-response.js';
import { customerService } from './customer.service.js';

export const customerController = {
  async list(req, res) {
    const { items, meta } = await customerService.list(validatedQuery(req));
    return sendSuccess(res, items, 'Customers fetched successfully', 200, meta);
  },

  async getById(req, res) {
    const customer = await customerService.getById(req.params.id);
    return sendSuccess(res, customer, 'Customer fetched successfully');
  },

  async create(req, res) {
    const customer = await customerService.create(req.body);
    return sendCreated(res, customer, 'Customer created successfully');
  },

  async update(req, res) {
    const customer = await customerService.update(req.params.id, req.body);
    return sendSuccess(res, customer, 'Customer updated successfully');
  },

  async remove(req, res) {
    await customerService.remove(req.params.id);
    return sendNoContent(res);
  },
};
