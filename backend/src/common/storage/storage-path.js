import { createHash } from 'node:crypto';

/** Strips anything that could turn a folder name into a path traversal. */
export function sanitizeFolder(folder) {
  const cleaned = folder
    .split('/')
    .map((segment) => segment.replace(/[^a-zA-Z0-9._-]/g, ''))
    .filter((segment) => segment.length > 0 && segment !== '.' && segment !== '..')
    .join('/');
  return cleaned.length > 0
    ? cleaned
    : createHash('sha1').update(folder).digest('hex').slice(0, 12);
}
