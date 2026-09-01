import { Router } from 'express';
import { validate } from '../../common/middleware/validate.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { idParamSchema } from '../../common/schemas/common.schema.js';
import { userController } from './user.controller.js';
import {
  changePasswordSchema,
  createUserSchema,
  listUserQuerySchema,
  updateUserSchema,
} from './user.schema.js';

export const userRoutes = Router();

userRoutes.get('/', validate({ query: listUserQuerySchema }), asyncHandler(userController.list));

userRoutes.get('/:id', validate({ params: idParamSchema }), asyncHandler(userController.getById));

userRoutes.post('/', validate({ body: createUserSchema }), asyncHandler(userController.create));

userRoutes.patch(
  '/:id',
  validate({ params: idParamSchema, body: updateUserSchema }),
  asyncHandler(userController.update),
);

userRoutes.post(
  '/:id/change-password',
  validate({ params: idParamSchema, body: changePasswordSchema }),
  asyncHandler(userController.changePassword),
);

userRoutes.post(
  '/:id/deactivate',
  validate({ params: idParamSchema }),
  asyncHandler(userController.deactivate),
);
