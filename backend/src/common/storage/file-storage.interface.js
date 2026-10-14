/**
 * Storage-agnostic contract for physical evidence (supplier bills, payment
 * vouchers, cheque copies).
 *
 * The database only ever holds the returned `storageKey` - never the bytes.
 * Swapping local disk for S3 or Cloudinary later means writing one more class
 * that satisfies this contract and changing STORAGE_DRIVER; no table, no
 * column and no service signature has to change.
 *
 * @typedef {object} StoredFile
 * @property {string} storageKey       Driver-relative id saved in `attachments.storage_key`.
 * @property {string} originalFileName Name the file had on the shopkeeper's device.
 * @property {string} mimeType
 * @property {number} fileSize         Bytes.
 *
 * @typedef {object} UploadFileInput
 * @property {Buffer} content           File contents. These are scans, not video.
 * @property {string} originalFileName
 * @property {string} mimeType
 * @property {string} folder            Logical folder, e.g. `purchases/<purchaseId>`.
 *
 * @typedef {object} FileStorageService
 * @property {string} driver
 *   Name of the concrete driver, recorded in `attachments.storage_driver` so
 *   rows written before a driver switch can still be resolved.
 * @property {(input: UploadFileInput) => Promise<StoredFile>} upload
 * @property {(storageKey: string) => Promise<void>} delete
 * @property {(storageKey: string) => Promise<boolean>} exists
 * @property {(storageKey: string, expiresInSeconds?: number) => Promise<string>} getDownloadUrl
 *   Address the client can fetch the file from. Async because object storage
 *   will return a time-limited signed URL here.
 */

export {};
