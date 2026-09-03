import { validatedQuery } from '../../common/middleware/validate.js';
import { sendSuccess } from '../../common/utils/api-response.js';
import { syncService } from './sync.service.js';

export const syncController = {
  /**
   * The response is a 200 whatever the individual operations did. A batch in
   * which one row was rejected is not a failed request - the client needs the
   * other forty-nine verdicts, and reading them out of an error body is not
   * something the app should have to do.
   */
  async push(req, res) {
    const result = await syncService.push(
      { deviceId: req.body.device_id, operations: req.body.operations },
      req.user?.id ?? null,
    );
    return sendSuccess(res, result, 'Sync push processed');
  },

  async pull(req, res) {
    const result = await syncService.pull(validatedQuery(req));
    return sendSuccess(res, result, 'Sync pull processed');
  },
};
