import { env } from '../../config/env.js';
import { AppError, ErrorCode } from '../errors/index.js';
import { CloudinaryFileStorageService } from './cloudinary-file-storage.service.js';
import { LocalFileStorageService } from './local-file-storage.service.js';

export { CloudinaryFileStorageService } from './cloudinary-file-storage.service.js';
export { LocalFileStorageService } from './local-file-storage.service.js';

/** @type {Map<string, import('./file-storage.interface.js').FileStorageService>} */
const instances = new Map();

/** @type {import('./file-storage.interface.js').FileStorageService | null} */
let override = null;

function createDriver(driver) {
  switch (driver) {
    case 'local':
      return new LocalFileStorageService();
    case 'cloudinary':
      return new CloudinaryFileStorageService();
    case 's3':
      throw new AppError(
        `Storage driver "${driver}" is not implemented yet`,
        501,
        ErrorCode.NOT_IMPLEMENTED,
      );
    default:
      throw new AppError('Unknown storage driver', 500, ErrorCode.INTERNAL_ERROR);
  }
}

/**
 * New uploads use the driver named by STORAGE_DRIVER. Anything touching an
 * existing file passes the `storage_driver` recorded on its row instead, so
 * files written before a switch keep working after it. Adding S3 later is one
 * more `case` above plus a class satisfying FileStorageService.
 *
 * @param {string} [driver]
 * @returns {import('./file-storage.interface.js').FileStorageService}
 */
export function getFileStorage(driver = env.STORAGE_DRIVER) {
  if (override) return override;

  if (!instances.has(driver)) instances.set(driver, createDriver(driver));
  return instances.get(driver);
}

/**
 * Test seam - lets a suite swap in a fake driver. Pass null to reset.
 *
 * @param {import('./file-storage.interface.js').FileStorageService | null} service
 */
export function setFileStorage(service) {
  override = service;
}
