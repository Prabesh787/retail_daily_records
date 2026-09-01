import { BusinessRuleError } from '../../common/errors/index.js';
import { validatedQuery } from '../../common/middleware/validate.js';
import { sendCreated, sendNoContent, sendSuccess } from '../../common/utils/api-response.js';
import { attachmentService } from './attachment.service.js';
import { uploadAttachmentSchema } from './attachment.schema.js';

export const attachmentController = {
  async list(req, res) {
    const { items, meta } = await attachmentService.list(validatedQuery(req));
    return sendSuccess(res, items, 'Attachments fetched successfully', 200, meta);
  },

  async getById(req, res) {
    const attachment = await attachmentService.getById(req.params.id);
    return sendSuccess(res, attachment, 'Attachment fetched successfully');
  },

  async getDownloadUrl(req, res) {
    const attachment = await attachmentService.getDownloadUrl(req.params.id);
    return sendSuccess(res, attachment, 'Download URL generated successfully');
  },

  /**
   * Multipart, so the metadata fields arrive as text parts alongside the file
   * and are validated here rather than by the `validate()` middleware.
   */
  async upload(req, res) {
    if (!req.file) throw new BusinessRuleError('A file is required under the "file" field');

    const dto = uploadAttachmentSchema.parse(req.body);
    const attachment = await attachmentService.upload(dto, req.file, req.user?.id ?? null);
    return sendCreated(res, attachment, 'Attachment uploaded successfully');
  },

  async remove(req, res) {
    await attachmentService.remove(req.params.id);
    return sendNoContent(res);
  },
};
