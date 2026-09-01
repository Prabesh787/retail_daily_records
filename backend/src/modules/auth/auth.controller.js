import { sendSuccess } from '../../common/utils/api-response.js';
import { authService } from './auth.service.js';

export const authController = {
  async login(req, res) {
    const result = await authService.login(req.body);
    return sendSuccess(res, result, 'Logged in successfully');
  },

  async me(req, res) {
    const profile = await authService.me(req.user?.id);
    return sendSuccess(res, profile, 'Current user fetched successfully');
  },

  async updateMe(req, res) {
    const profile = await authService.updateProfile(req.user?.id, req.body);
    return sendSuccess(res, profile, 'Profile updated successfully');
  },
};
