import { z } from 'zod';
import { AttachmentEntityType, DocumentType } from '../../database/generated/prisma/index.js';
import { paginationQuerySchema } from '../../common/schemas/common.schema.js';

export const entityTypeEnum = z.enum(Object.values(AttachmentEntityType));
export const documentTypeEnum = z.enum(Object.values(DocumentType));

/**
 * Metadata that accompanies a multipart upload. The file itself arrives as the
 * `file` part and never touches this schema.
 */
export const uploadAttachmentSchema = z.object({
  entityType: entityTypeEnum,
  entityId: z.uuid('A valid entity id is required'),
  documentType: documentTypeEnum,
});

export const listAttachmentQuerySchema = paginationQuerySchema.extend({
  entityType: entityTypeEnum.optional(),
  entityId: z.uuid().optional(),
  documentType: documentTypeEnum.optional(),
});
