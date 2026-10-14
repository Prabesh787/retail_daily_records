import { env } from '../../config/env.js';
import { AppError, ErrorCode } from '../errors/index.js';
import { LocalFileStorageService } from './local-file-storage.service.js';

export { LocalFileStorageService } from './local-file-storage.service.js';

/** @type {import('./file-storage.interface.js').FileStorageService | null} */
let instance = null;

/**
 * Resolves the driver named by STORAGE_DRIVER. Adding S3 or Cloudinary later
 * is one more `case` here plus a class satisfying FileStorageService - nothing
 * else in the application needs to know which driver is active.
 *
 * @returns {import('./file-storage.interface.js').FileStorageService}
 */
export function getFileStorage() {
  if (instance) return instance;

  switch (env.STORAGE_DRIVER) {
    case 'local':
      instance = new LocalFileStorageService();
      return instance;
    case 's3':
    case 'cloudinary':
      throw new AppError(
        `Storage driver "${env.STORAGE_DRIVER}" is not implemented yet`,
        501,
        ErrorCode.NOT_IMPLEMENTED,
      );
    default:
      throw new AppError('Unknown storage driver', 500, ErrorCode.INTERNAL_ERROR);
  }
}

/**
 * Test seam - lets a suite swap in a fake driver. Pass null to reset.
 *
 * @param {import('./file-storage.interface.js').FileStorageService | null} service
 */
export function setFileStorage(service) {
  instance = service;
}
