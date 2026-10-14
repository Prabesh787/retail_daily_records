import { Router } from 'express';
import { getFileStorage } from './index.js';

/**
 * Serves files written by the local driver at LOCAL_STORAGE_BASE_URL. Sits
 * outside the API's `authenticate` line on purpose: access is granted by the
 * signed, expiring link that the authenticated
 * `GET /attachments/:id/download-url` hands out, not by a bearer token.
 */
export const localFileRoutes = Router();

localFileRoutes.get('/*key', async (req, res) => {
  const storageKey = req.params.key.join('/');
  const absolutePath = await getFileStorage().resolveSignedDownload(
    storageKey,
    req.query.expires,
    req.query.signature,
  );

  const secondsLeft = Math.max(0, Number(req.query.expires) - Math.floor(Date.now() / 1000));
  res.set({
    // helmet defaults this to same-origin, which would stop the web frontend
    // (a different port/host) from showing the bill in an <img>.
    'Cross-Origin-Resource-Policy': 'cross-origin',
    'Cache-Control': `private, max-age=${secondsLeft}`,
  });
  res.sendFile(absolutePath);
});
