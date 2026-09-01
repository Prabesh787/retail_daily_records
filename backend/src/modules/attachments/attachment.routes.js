import { Router } from 'express';
import { validate } from '../../common/middleware/validate.js';
import { uploadSingleFile } from '../../common/middleware/upload.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { idParamSchema } from '../../common/schemas/common.schema.js';
import { attachmentController } from './attachment.controller.js';
import { listAttachmentQuerySchema } from './attachment.schema.js';

export const attachmentRoutes = Router();

attachmentRoutes.get(
  '/',
  validate({ query: listAttachmentQuerySchema }),
  asyncHandler(attachmentController.list),
);

attachmentRoutes.get(
  '/:id',
  validate({ params: idParamSchema }),
  asyncHandler(attachmentController.getById),
);

attachmentRoutes.get(
  '/:id/download-url',
  validate({ params: idParamSchema }),
  asyncHandler(attachmentController.getDownloadUrl),
);

// multipart/form-data: one "file" part plus entityType, entityId, documentType.
attachmentRoutes.post('/', uploadSingleFile, asyncHandler(attachmentController.upload));

attachmentRoutes.delete(
  '/:id',
  validate({ params: idParamSchema }),
  asyncHandler(attachmentController.remove),
);
