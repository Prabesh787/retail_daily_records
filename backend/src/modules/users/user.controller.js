import { validatedQuery } from '../../common/middleware/validate.js';
import { sendCreated, sendSuccess } from '../../common/utils/api-response.js';
import { userService } from './user.service.js';

export const userController = {
  async list(req, res) {
    const { items, meta } = await userService.list(validatedQuery(req));
    return sendSuccess(res, items, 'Users fetched successfully', 200, meta);
  },

  async getById(req, res) {
    const user = await userService.getById(req.params.id);
    return sendSuccess(res, user, 'User fetched successfully');
  },

  async create(req, res) {
    const user = await userService.create(req.body);
    return sendCreated(res, user, 'User created successfully');
  },

  async update(req, res) {
    const user = await userService.update(req.params.id, req.body);
    return sendSuccess(res, user, 'User updated successfully');
  },

  async changePassword(req, res) {
    const user = await userService.changePassword(req.params.id, req.body.password);
    return sendSuccess(res, user, 'Password updated successfully');
  },

  async deactivate(req, res) {
    const user = await userService.deactivate(req.params.id);
    return sendSuccess(res, user, 'User deactivated successfully');
  },
};
