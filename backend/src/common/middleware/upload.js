import multer from 'multer';
import { env } from '../../config/env.js';
import { BusinessRuleError } from '../errors/index.js';

/**
 * Scans of bills, vouchers and cheque copies. Files are held in memory and
 * handed straight to the configured FileStorageService, so nothing depends on
 * where they finally get written.
 */
const ALLOWED_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/heic',
  'application/pdf',
]);

export const uploadSingleFile = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: env.maxUploadSizeBytes, files: 1 },
  fileFilter: (_req, file, cb) => {
    if (!ALLOWED_MIME_TYPES.has(file.mimetype)) {
      cb(
        new BusinessRuleError(
          `Unsupported file type "${file.mimetype}". Upload a PDF or an image.`,
        ),
      );
      return;
    }
    cb(null, true);
  },
}).single('file');
