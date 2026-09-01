import { AttachmentEntityType } from '../../database/generated/prisma/index.js';
import { BusinessRuleError, NotFoundError } from '../../common/errors/index.js';
import { buildPaginationMeta, resolvePagination } from '../../common/utils/pagination.js';
import { getFileStorage } from '../../common/storage/index.js';
import { prisma } from '../../database/prisma-client.js';
import { logger } from '../../config/index.js';

/**
 * Attachments are polymorphic: one table holds the scanned evidence for
 * purchases, supplier payments and sales alike. That means `entity_id` cannot
 * be a real foreign key, so the owning row is verified here instead.
 */
const ENTITY_LOADERS = {
  [AttachmentEntityType.PURCHASE]: (id) => prisma.purchase.findUnique({ where: { id } }),
  [AttachmentEntityType.SUPPLIER_PAYMENT]: (id) =>
    prisma.supplierPayment.findUnique({ where: { id } }),
  [AttachmentEntityType.SALE]: (id) => prisma.sale.findUnique({ where: { id } }),
};

async function assertEntityExists(entityType, entityId) {
  const loader = ENTITY_LOADERS[entityType];
  if (!loader) throw new BusinessRuleError(`Unsupported entity type "${entityType}"`);
  const entity = await loader(entityId);
  if (!entity) throw new NotFoundError(entityType.toLowerCase().replace('_', ' '), entityId);
  return entity;
}

export const attachmentService = {
  async list(query) {
    const pagination = resolvePagination(query.page, query.limit);
    const where = {
      ...(query.entityType ? { entityType: query.entityType } : {}),
      ...(query.entityId ? { entityId: query.entityId } : {}),
      ...(query.documentType ? { documentType: query.documentType } : {}),
    };

    const [items, total] = await Promise.all([
      prisma.attachment.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: pagination.skip,
        take: pagination.limit,
      }),
      prisma.attachment.count({ where }),
    ]);

    return { items, meta: buildPaginationMeta(pagination, total) };
  },

  async getById(id) {
    const attachment = await prisma.attachment.findUnique({ where: { id } });
    if (!attachment) throw new NotFoundError('Attachment', id);
    return attachment;
  },

  /**
   * Writes the bytes through the configured storage driver, then records the
   * metadata. If the metadata insert fails the just-written file is removed,
   * so storage and database do not drift apart.
   *
   * @param {{entityType: string, entityId: string, documentType: string}} dto
   * @param {{buffer: Buffer, originalname: string, mimetype: string}} file
   * @param {string | null} uploadedById
   */
  async upload(dto, file, uploadedById = null) {
    await assertEntityExists(dto.entityType, dto.entityId);

    const storage = getFileStorage();
    const stored = await storage.upload({
      content: file.buffer,
      originalFileName: file.originalname,
      mimeType: file.mimetype,
      folder: `${dto.entityType.toLowerCase()}/${dto.entityId}`,
    });

    try {
      return await prisma.attachment.create({
        data: {
          entityType: dto.entityType,
          entityId: dto.entityId,
          documentType: dto.documentType,
          originalFileName: stored.originalFileName,
          storageKey: stored.storageKey,
          storageDriver: storage.driver,
          mimeType: stored.mimeType,
          fileSize: stored.fileSize,
          uploadedById,
        },
      });
    } catch (error) {
      await storage.delete(stored.storageKey).catch((cleanupError) => {
        logger.error(
          { storageKey: stored.storageKey, err: cleanupError },
          'Failed to clean up an orphaned upload',
        );
      });
      throw error;
    }
  },

  /** Address the client can fetch the file from. Signed for object storage. */
  async getDownloadUrl(id) {
    const attachment = await this.getById(id);
    const url = await getFileStorage().getDownloadUrl(attachment.storageKey);
    return { ...attachment, url };
  },

  /**
   * The row goes first: a stored file with no row is invisible clutter, but a
   * row pointing at a missing file is a broken link the shopkeeper can see.
   */
  async remove(id) {
    const attachment = await this.getById(id);
    await prisma.attachment.delete({ where: { id } });
    await getFileStorage()
      .delete(attachment.storageKey)
      .catch((error) => {
        logger.error(
          { attachmentId: id, storageKey: attachment.storageKey, err: error },
          'Attachment row deleted but the stored file could not be removed',
        );
      });
  },
};
