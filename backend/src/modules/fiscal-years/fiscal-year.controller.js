import { validatedQuery } from '../../common/middleware/validate.js';
import { sendCreated, sendNoContent, sendSuccess } from '../../common/utils/api-response.js';
import { fiscalYearService } from './fiscal-year.service.js';

export const fiscalYearController = {
  async list(req, res) {
    const { items, meta } = await fiscalYearService.list(validatedQuery(req));
    return sendSuccess(res, items, 'Fiscal years fetched successfully', 200, meta);
  },

  async getActive(_req, res) {
    const fiscalYear = await fiscalYearService.getActive();
    return sendSuccess(res, fiscalYear, 'Active fiscal year fetched successfully');
  },

  async getById(req, res) {
    const fiscalYear = await fiscalYearService.getById(req.params.id);
    return sendSuccess(res, fiscalYear, 'Fiscal year fetched successfully');
  },

  async create(req, res) {
    const fiscalYear = await fiscalYearService.create(req.body);
    return sendCreated(res, fiscalYear, 'Fiscal year created successfully');
  },

  async update(req, res) {
    const fiscalYear = await fiscalYearService.update(req.params.id, req.body);
    return sendSuccess(res, fiscalYear, 'Fiscal year updated successfully');
  },

  async activate(req, res) {
    const fiscalYear = await fiscalYearService.activate(req.params.id);
    return sendSuccess(res, fiscalYear, 'Fiscal year activated successfully');
  },

  async remove(req, res) {
    await fiscalYearService.remove(req.params.id);
    return sendNoContent(res);
  },
};
