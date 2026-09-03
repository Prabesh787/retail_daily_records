import { logger } from '../../config/index.js';
import { AppError } from '../../common/errors/index.js';
import { prisma } from '../../database/prisma-client.js';
import { byPosition, decodeCursor, encodeCursor, keysetAfter } from './sync.cursor.js';
import { syncEntityFor, toTombstoneRow, toWireRow } from './sync.entities.js';

/**
 * Reconciliation for the offline mobile app.
 *
 * The phone owns a complete copy of the shop's books and works with no signal
 * at all, so this module is not a write API with extra steps - it is a merge.
 * Three rules decide everything below:
 *
 *  1. **The client names the row.** Ids are uuids generated on the device, and
 *     a push is an upsert by that id. A bill written on a phone with no signal
 *     is addressable immediately, and its payments can reference it before the
 *     server has ever heard of it.
 *  2. **Newest wins, on the client's clock.** `sync_updated_at` holds epoch
 *     millis as stated by whoever last wrote the row, and an incoming change
 *     older than what is stored comes back as a conflict carrying the server's
 *     copy, so the device can settle it without a second round trip. Comparing
 *     a phone's clock against the server's would make every push from a device
 *     that runs slow look stale forever.
 *  3. **Deletes leave a trace.** They are recorded in `sync_tombstones` by a
 *     database trigger and travel in the pull stream as `is_deleted: true`. A
 *     row that simply vanished would be pushed straight back by the next
 *     device that had not heard.
 *
 * Retries are safe throughout: pushing the same operation twice is recognised
 * by its timestamp and changes nothing, and every pulled row is an upsert.
 */

/**
 * How far behind "now" a pull stops.
 *
 * A row's `updated_at` is set when the statement runs, but it only becomes
 * visible when the transaction commits a moment later. Without this lag a pull
 * that reads between those two instants would move its cursor past a row it
 * could not yet see, and nothing would ever bring that row back. Two seconds
 * is far longer than any write here takes, and against a sync that runs every
 * fifteen minutes the staleness is not observable.
 */
const PULL_VISIBILITY_LAG_MS = 2000;

const accepted = (entityId) => ({ entity_id: entityId, status: 'accepted' });

const conflict = (entityId, serverRow, message) => ({
  entity_id: entityId,
  status: 'conflict',
  server_row: serverRow,
  message,
});

const rejected = (entityId, message, retryable) => ({
  entity_id: entityId,
  status: 'error',
  message,
  retryable,
});

/** The first thing a Zod error has to say, which is the useful part on a phone. */
function firstIssue(error) {
  const issue = error.issues[0];
  if (!issue) return 'The record did not pass validation';
  const field = issue.path.map(String).join('.');
  return field ? `${field}: ${issue.message}` : issue.message;
}

/**
 * Turns a database refusal into something a shopkeeper can act on, and says
 * whether trying again could ever help.
 *
 * `retryable: false` matters: the outbox retries on a timer, and a row that can
 * never be accepted should stop consuming attempts and be reported instead.
 */
function describeWriteFailure(error, entity, isDelete) {
  if (error instanceof AppError) return { message: error.message, retryable: false };

  const target = Array.isArray(error?.meta?.target)
    ? error.meta.target.join(', ')
    : (error?.meta?.target ?? null);

  switch (error?.code) {
    case 'P2002':
      return {
        message: target
          ? `Another ${entity.label.toLowerCase()} already uses that ${target}`
          : `Another ${entity.label.toLowerCase()} already exists with those details`,
        retryable: false,
      };
    case 'P2003':
      return isDelete
        ? {
            message: `This ${entity.label.toLowerCase()} still has records against it on the server and cannot be deleted. Deactivate it instead.`,
            retryable: false,
          }
        : {
            message: `This ${entity.label.toLowerCase()} refers to a record the server does not have yet${
              error.meta?.field_name ? ` (${error.meta.field_name})` : ''
            }`,
            // The record it points at may simply be later in the queue.
            retryable: true,
          };
    case 'P2000':
      return { message: 'A value is longer than the column allows', retryable: false };
    case 'P2004':
      return {
        message: `The database refused this ${entity.label.toLowerCase()}: ${
          error.meta?.database_error ?? 'a constraint failed'
        }`,
        retryable: false,
      };
    default:
      return { message: 'The server could not apply this change', retryable: true };
  }
}

/**
 * Writes one row and, for a sale, the lines and settlement that belong to it.
 *
 * `syncUpdatedAt` and `deviceId` are set from the operation, which is what
 * stops the database trigger from stamping server time over the client's own
 * clock - see the `20260903120000_sync_engine` migration.
 */
async function writeRow(tx, entity, { id, payload, meta, userId }) {
  const data = entity.toData(payload);
  await entity.beforeWrite?.(tx, { id, data, payload });

  const stamp = { deviceId: meta.deviceId, syncUpdatedAt: BigInt(meta.updatedAt) };

  const row = await entity.delegate(tx).upsert({
    where: { id },
    create: {
      id,
      ...data,
      ...stamp,
      // The device's own creation time, so history synced from a phone that
      // has been offline for a week is not all dated the day it reconnected.
      ...(meta.createdAt ? { createdAt: new Date(meta.createdAt) } : {}),
      ...(entity.tracksCreator ? { createdById: userId } : {}),
    },
    // `createdById` is deliberately not touched on update: the account that
    // recorded a bill is not changed by whoever edits it later.
    update: { ...data, ...stamp },
    include: entity.include,
  });

  if (entity.writeChildren) {
    await entity.writeChildren(tx, { id, payload });
    return entity.delegate(tx).findUnique({ where: { id }, include: entity.include });
  }

  return row;
}

/** One operation, inside its own transaction. */
async function runOperation(tx, { entity, operation, payload, meta, isDelete, userId }) {
  const id = operation.entity_id;
  const existing = await entity.delegate(tx).findUnique({ where: { id }, include: entity.include });

  if (existing) {
    const stored = Number(existing.syncUpdatedAt);
    if (stored > meta.updatedAt) {
      return conflict(
        id,
        toWireRow(entity, existing),
        'The server has a newer version of this record',
      );
    }
    // A retry of an upsert already applied. Writing it again would only bump
    // the row's clock and send it back round the loop to every device. A delete
    // is exempt: an equal timestamp there is a different request, not a repeat.
    if (!isDelete && stored === meta.updatedAt) return accepted(id);
  } else {
    // Deleting a row that is already gone is the outcome that was wanted.
    if (isDelete) return accepted(id);

    // Deleted more recently than this change was made: the deletion wins, and
    // the tombstone goes back so the device stops offering the row.
    const tombstone = await tx.syncTombstone.findUnique({
      where: { entity_entityId: { entity: entity.name, entityId: id } },
    });
    if (tombstone && Number(tombstone.syncUpdatedAt) > meta.updatedAt) {
      return conflict(id, toTombstoneRow(tombstone), 'This record was deleted on the server');
    }
  }

  if (isDelete) {
    await entity.delegate(tx).delete({ where: { id } });
    // The trigger has already written a tombstone; this restates it with the
    // clock and the device of the change that actually asked for the delete.
    // An upsert rather than an update so this transaction does not depend on a
    // trigger having fired - the tombstone is the whole point of the delete.
    const stamp = {
      deviceId: meta.deviceId,
      syncUpdatedAt: BigInt(meta.updatedAt),
      // The position this tombstone takes in the pull stream, on the same
      // clock as a live row's `updated_at` - which is this process's, since
      // that is the clock Prisma stamps rows with.
      deletedAtMs: BigInt(Date.now()),
    };
    await tx.syncTombstone.upsert({
      where: { entity_entityId: { entity: entity.name, entityId: id } },
      create: { entity: entity.name, entityId: id, ...stamp },
      update: stamp,
    });
    return accepted(id);
  }

  await writeRow(tx, entity, { id, payload, meta, userId });
  return accepted(id);
}

/** @param {{ entity: string, entity_id: string, operation: string, updated_at: number, payload: object }} operation */
async function applyOperation(operation, { deviceId, userId }) {
  const entity = syncEntityFor(operation.entity);
  if (!entity) return rejected(operation.entity_id, `Unknown entity "${operation.entity}"`, false);

  const parsed = entity.payload.safeParse(operation.payload);
  if (!parsed.success) {
    return rejected(operation.entity_id, firstIssue(parsed.error), false);
  }

  const payload = parsed.data;
  const meta = {
    updatedAt: operation.updated_at,
    createdAt: payload.created_at ?? null,
    // The payload's own device wins over the batch's: a phone can be relaying
    // a row it accepted from somewhere else.
    deviceId: payload.device_id ?? deviceId ?? null,
  };
  // A soft delete on the device and an explicit delete operation are the same
  // request; the app sends both together, and either alone is enough.
  const isDelete = operation.operation === 'delete' || payload.is_deleted === true;

  try {
    return await prisma.$transaction((tx) =>
      runOperation(tx, { entity, operation, payload, meta, isDelete, userId }),
    );
  } catch (error) {
    // Deleting a row that is already gone is the outcome that was wanted.
    if (isDelete && error?.code === 'P2025') return accepted(operation.entity_id);

    const { message, retryable } = describeWriteFailure(error, entity, isDelete);
    logger.warn(
      { entity: entity.name, entityId: operation.entity_id, code: error?.code, err: error },
      `sync push rejected: ${message}`,
    );
    return rejected(operation.entity_id, message, retryable);
  }
}

export const syncService = {
  /**
   * Applies a batch of queued changes, in order, one transaction each.
   *
   * Sequential on purpose. The queue is ordered, and that order carries
   * meaning twice over: a supplier has to land before the bill that names it,
   * and two edits to the same row have to arrive in the order they were made.
   *
   * Every operation gets its own verdict rather than the batch sharing one, so
   * a single bad row is reported and dropped instead of blocking the forty-nine
   * behind it.
   *
   * @param {{ deviceId: string | null, operations: object[] }} request
   * @param {string | null} userId
   */
  async push({ deviceId, operations }, userId = null) {
    const results = [];
    for (const operation of operations) {
      results.push(await applyOperation(operation, { deviceId, userId }));
    }

    const conflicts = results.filter((result) => result.status === 'conflict').length;
    const errors = results.filter((result) => result.status === 'error').length;
    logger.info(
      { deviceId, operations: operations.length, conflicts, errors },
      'sync push processed',
    );

    return { server_time: Date.now(), results };
  },

  /**
   * One page of everything that has changed since the client's bookmark,
   * live rows and tombstones interleaved.
   *
   * Both streams are ordered by the same `(changed at, id)` pair - epoch
   * millis on the server's clock - so merging them and cutting at `limit`
   * gives a correct prefix; taking one row more than the page from each is
   * what guarantees the merge is not short.
   *
   * A live row is paged on its `updatedAt` timestamp and a tombstone on its
   * `deletedAtMs` integer. The two are the same clock in different columns;
   * see the tombstone table's own comment for why one of them is not a
   * timestamp.
   *
   * @param {{ entity: string, cursor?: string, limit: number }} query
   */
  async pull({ entity: name, cursor, limit }) {
    const entity = syncEntityFor(name);
    const after = decodeCursor(cursor);
    const horizonMs = Date.now() - PULL_VISIBILITY_LAG_MS;
    const take = limit + 1;

    const [rows, tombstones] = await Promise.all([
      entity.delegate(prisma).findMany({
        where: {
          AND: [
            ...keysetAfter(after, 'updatedAt', 'id', (ms) => new Date(ms)),
            { updatedAt: { lte: new Date(horizonMs) } },
          ],
        },
        orderBy: [{ updatedAt: 'asc' }, { id: 'asc' }],
        include: entity.include,
        take,
      }),
      prisma.syncTombstone.findMany({
        where: {
          entity: name,
          AND: [
            ...keysetAfter(after, 'deletedAtMs', 'entityId', BigInt),
            { deletedAtMs: { lte: BigInt(horizonMs) } },
          ],
        },
        orderBy: [{ deletedAtMs: 'asc' }, { entityId: 'asc' }],
        take,
      }),
    ]);

    const merged = [
      ...rows.map((row) => ({
        ms: row.updatedAt.getTime(),
        id: row.id,
        row: toWireRow(entity, row),
      })),
      ...tombstones.map((tombstone) => ({
        ms: Number(tombstone.deletedAtMs),
        id: tombstone.entityId,
        row: toTombstoneRow(tombstone),
      })),
    ].sort(byPosition);

    const page = merged.slice(0, limit);
    const last = page.at(-1);

    return {
      rows: page.map((entry) => entry.row),
      // An empty page leaves the bookmark where it was, rather than resetting
      // a client that is simply up to date.
      next_cursor: last ? encodeCursor(last) : (cursor ?? null),
      has_more: merged.length > page.length,
      server_time: Date.now(),
    };
  },
};
