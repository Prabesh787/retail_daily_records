import { createHash, createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import path from 'node:path';
import fs from 'node:fs/promises';
import { env } from '../../config/env.js';
import {
  BusinessRuleError,
  ForbiddenError,
  NotFoundError,
  PayloadTooLargeError,
} from '../errors/index.js';

/**
 * The extension is chosen from the (already allow-listed) MIME type, never from
 * the uploaded file name: files are served back from our own origin, and a
 * "bill.html" would otherwise come back as a page that runs script.
 */
const EXTENSION_BY_MIME_TYPE = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/heic': '.heic',
  'application/pdf': '.pdf',
};

/** Download links are bearer capabilities, so they are kept short-lived. */
const DEFAULT_URL_TTL_SECONDS = 5 * 60;

/**
 * Development / single-server driver: files live under LOCAL_STORAGE_PATH and
 * the storage key is the path relative to that root.
 *
 * @implements {import('./file-storage.interface.js').FileStorageService}
 */
export class LocalFileStorageService {
  driver = 'local';

  /** @param {string} [rootPath] */
  constructor(rootPath = env.LOCAL_STORAGE_PATH) {
    this.root = path.resolve(process.cwd(), rootPath);
  }

  /**
   * @param {import('./file-storage.interface.js').UploadFileInput} input
   * @returns {Promise<import('./file-storage.interface.js').StoredFile>}
   */
  async upload(input) {
    if (input.content.byteLength > env.maxUploadSizeBytes) {
      throw new PayloadTooLargeError(
        `File exceeds the maximum upload size of ${env.MAX_UPLOAD_SIZE_MB}MB`,
      );
    }

    const extension = EXTENSION_BY_MIME_TYPE[input.mimeType] ?? '';
    const storageKey = path.posix.join(
      sanitizeFolder(input.folder),
      `${Date.now()}-${randomUUID()}${extension}`,
    );
    const absolutePath = this.#resolveKey(storageKey);

    await fs.mkdir(path.dirname(absolutePath), { recursive: true });
    await fs.writeFile(absolutePath, input.content);

    return {
      storageKey,
      originalFileName: input.originalFileName,
      mimeType: input.mimeType,
      fileSize: input.content.byteLength,
    };
  }

  /** @param {string} storageKey */
  async delete(storageKey) {
    try {
      await fs.unlink(this.#resolveKey(storageKey));
    } catch (error) {
      // Already gone is a success for our purposes.
      if (error.code === 'ENOENT') return;
      throw error;
    }
  }

  /** @param {string} storageKey */
  async exists(storageKey) {
    try {
      await fs.access(this.#resolveKey(storageKey));
      return true;
    } catch {
      return false;
    }
  }

  /**
   * A time-limited signed link, the local equivalent of an S3 presigned URL:
   * the caller proved who they are when asking for it, so the link itself can
   * be opened by a plain <img> or browser tab that has no bearer token.
   *
   * @param {string} storageKey
   * @param {number} [expiresInSeconds]
   */
  async getDownloadUrl(storageKey, expiresInSeconds = DEFAULT_URL_TTL_SECONDS) {
    if (!(await this.exists(storageKey))) throw new NotFoundError('File', storageKey);
    const expires = Math.floor(Date.now() / 1000) + expiresInSeconds;
    const base = env.LOCAL_STORAGE_BASE_URL.replace(/\/+$/, '');
    const encodedKey = storageKey.split('/').map(encodeURIComponent).join('/');
    const query = new URLSearchParams({
      expires: String(expires),
      signature: signDownload(storageKey, expires),
    });
    return `${base}/${encodedKey}?${query}`;
  }

  /**
   * Checks a link produced by getDownloadUrl and returns the file's absolute
   * path. Every bad-link case is the same 403 so a caller cannot probe which
   * part was wrong.
   *
   * @param {string} storageKey
   * @param {unknown} expires
   * @param {unknown} signature
   */
  async resolveSignedDownload(storageKey, expires, signature) {
    const expiresAt = Number(expires);
    const valid =
      typeof signature === 'string' &&
      Number.isInteger(expiresAt) &&
      expiresAt >= Math.floor(Date.now() / 1000) &&
      safeEqual(signature, signDownload(storageKey, expiresAt));
    if (!valid) throw new ForbiddenError('This download link is invalid or has expired');

    if (!(await this.exists(storageKey))) throw new NotFoundError('File', storageKey);
    return this.#resolveKey(storageKey);
  }

  /** Absolute path for a key, refusing anything that escapes the root. */
  #resolveKey(storageKey) {
    const absolutePath = path.resolve(this.root, storageKey);
    if (absolutePath !== this.root && !absolutePath.startsWith(this.root + path.sep)) {
      throw new BusinessRuleError('Invalid storage key');
    }
    return absolutePath;
  }
}

/**
 * Keyed off JWT_SECRET (with its own prefix, so a signature can never double as
 * anything else), which means rotating that secret also kills old links.
 */
function signDownload(storageKey, expires) {
  return createHmac('sha256', `file-download:${env.JWT_SECRET}`)
    .update(`${storageKey}\n${expires}`)
    .digest('base64url');
}

function safeEqual(a, b) {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

/** Strips anything that could turn a folder name into a path traversal. */
function sanitizeFolder(folder) {
  const cleaned = folder
    .split('/')
    .map((segment) => segment.replace(/[^a-zA-Z0-9._-]/g, ''))
    .filter((segment) => segment.length > 0 && segment !== '.' && segment !== '..')
    .join('/');
  return cleaned.length > 0 ? cleaned : createHash('sha1').update(folder).digest('hex').slice(0, 12);
}
