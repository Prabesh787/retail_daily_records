import { validatedQuery } from '../../common/middleware/validate.js';
import { sendSuccess } from '../../common/utils/api-response.js';
import { reportService } from './report.service.js';

export const reportController = {
  async dashboard(req, res) {
    const report = await reportService.dashboard(validatedQuery(req));
    return sendSuccess(res, report, 'Dashboard fetched successfully');
  },

  async supplierOutstanding(req, res) {
    const report = await reportService.supplierOutstanding(validatedQuery(req));
    return sendSuccess(res, report, 'Supplier outstanding report fetched successfully');
  },
};
