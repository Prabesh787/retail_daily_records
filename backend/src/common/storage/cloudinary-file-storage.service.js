import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { v2 as cloudinary } from 'cloudinary';
import { env } from '../../config/env.js';
import { AppError, BusinessRuleError, ErrorCode, PayloadTooLargeError } from '../errors/index.js';
import { sanitizeFolder } from './storage-path.js';

/**
 * `private` keeps originals off the public CDN: reaching one takes a link signed
 * with the API secret, and that link can carry an expiry. Transformed versions
 * are a separate matter, so the account needs Strict Transformations switched on.
 */
const DELIVERY_TYPE = 'private';

/** Download links are bearer capabilities, so they are kept short-lived. */
const DEFAULT_URL_TTL_SECONDS = 5 * 60;

/**
 * Cloudinary driver. Its API addresses an asset by resource type + public id +
 * format, but the rest of the application holds a single string, so all three
 * are packed into the storage key:
 *
 *   image/retails_records/purchase/<id>/<name>.jpg
 *   raw/retails_records/purchase/<id>/<name>.pdf
 *
 * @implements {import('./file-storage.interface.js').FileStorageService}
 */
export class CloudinaryFileStorageService {
  driver = 'cloudinary';

  constructor() {
    if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
      throw new AppError(
        'Cloudinary credentials are not configured',
        500,
        ErrorCode.INTERNAL_ERROR,
      );
    }
    cloudinary.config({
      cloud_name: env.CLOUDINARY_CLOUD_NAME,
      api_key: env.CLOUDINARY_API_KEY,
      api_secret: env.CLOUDINARY_API_SECRET,
      secure: true,
    });
  }

  /**
   * PDFs go up as `raw`: these are records to hand back untouched, and accounts
   * block delivery of PDFs stored as images by default.
   *
   * @param {import('./file-storage.interface.js').UploadFileInput} input
   * @returns {Promise<import('./file-storage.interface.js').StoredFile>}
   */
  async upload(input) {
    if (input.content.byteLength > env.maxUploadSizeBytes) {
      throw new PayloadTooLargeError(
        `File exceeds the maximum upload size of ${env.MAX_UPLOAD_SIZE_MB}MB`,
      );
    }

    const isPdf = input.mimeType === 'application/pdf';
    const name = `${Date.now()}-${randomUUID()}`;
    const result = await uploadBuffer(input.content, {
      resource_type: isPdf ? 'raw' : 'image',
      type: DELIVERY_TYPE,
      // A raw asset's public id has to include its extension.
      public_id: path.posix.join(
        sanitizeFolder(env.CLOUDINARY_FOLDER),
        sanitizeFolder(input.folder),
        isPdf ? `${name}.pdf` : name,
      ),
      overwrite: false,
    });

    return {
      storageKey: isPdf ? `raw/${result.public_id}` : `image/${result.public_id}.${result.format}`,
      originalFileName: input.originalFileName,
      mimeType: input.mimeType,
      fileSize: input.content.byteLength,
    };
  }

  /** @param {string} storageKey */
  async delete(storageKey) {
    const { resourceType, publicId } = parseStorageKey(storageKey);
    try {
      const { result } = await cloudinary.uploader.destroy(publicId, {
        resource_type: resourceType,
        type: DELIVERY_TYPE,
        invalidate: true,
      });
      // Already gone is a success for our purposes.
      if (result !== 'ok' && result !== 'not found') {
        throw new Error(`Cloudinary could not delete the file: ${result}`);
      }
    } catch (error) {
      throw toError(error);
    }
  }

  /** @param {string} storageKey */
  async exists(storageKey) {
    const { resourceType, publicId } = parseStorageKey(storageKey);
    try {
      await cloudinary.api.resource(publicId, {
        resource_type: resourceType,
        type: DELIVERY_TYPE,
      });
      return true;
    } catch (error) {
      if (error?.error?.http_code === 404) return false;
      throw toError(error);
    }
  }

  /**
   * Signs locally without asking Cloudinary whether the file exists: that check
   * spends the hourly Admin API quota. A link to a missing file fails when it
   * is opened.
   *
   * @param {string} storageKey
   * @param {number} [expiresInSeconds]
   */
  async getDownloadUrl(storageKey, expiresInSeconds = DEFAULT_URL_TTL_SECONDS) {
    const { resourceType, publicId, format } = parseStorageKey(storageKey);
    return cloudinary.utils.private_download_url(publicId, format, {
      resource_type: resourceType,
      type: DELIVERY_TYPE,
      expires_at: Math.floor(Date.now() / 1000) + expiresInSeconds,
    });
  }
}

/** The SDK only offers a stream for in-memory content. */
function uploadBuffer(content, options) {
  return new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(options, (error, result) => {
      if (error) reject(toError(error));
      else resolve(result);
    });
    stream.end(content);
  });
}

/** The SDK rejects with plain objects, which the error handler cannot read. */
function toError(error) {
  if (error instanceof Error) return error;
  return new Error(`Cloudinary: ${error?.error?.message ?? error?.message ?? 'request failed'}`);
}

function parseStorageKey(storageKey) {
  const separator = storageKey.indexOf('/');
  const resourceType = storageKey.slice(0, separator);
  const rest = storageKey.slice(separator + 1);

  if (resourceType === 'raw') return { resourceType, publicId: rest };

  const dot = rest.lastIndexOf('.');
  if (resourceType !== 'image' || dot === -1) throw new BusinessRuleError('Invalid storage key');
  return { resourceType, publicId: rest.slice(0, dot), format: rest.slice(dot + 1) };
}
