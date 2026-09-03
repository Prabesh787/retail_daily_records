import { Router } from 'express';
import { validate } from '../../common/middleware/validate.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { syncController } from './sync.controller.js';
import { pullQuerySchema, pushBodySchema } from './sync.schema.js';

/**
 * The two calls the offline app makes:
 *
 *   POST /sync/push
 *     { device_id, operations: [{ entity, entity_id, operation, updated_at,
 *       payload }] }
 *     -> { server_time, results: [{ entity_id, status, server_row?, message?,
 *          retryable? }] }
 *
 *   GET /sync/pull?entity=suppliers&cursor=<opaque>&limit=200
 *     -> { rows, next_cursor, has_more, server_time }
 *
 * Both sit behind the same bearer token as every other module; the mount in
 * routes/index.js is below the `authenticate` line.
 */
export const syncRoutes = Router();

syncRoutes.post('/push', validate({ body: pushBodySchema }), asyncHandler(syncController.push));

syncRoutes.get('/pull', validate({ query: pullQuerySchema }), asyncHandler(syncController.pull));
