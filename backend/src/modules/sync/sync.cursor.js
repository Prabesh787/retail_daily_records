/**
 * The pull bookmark.
 *
 * A page of changes is a keyset over `(changed at, id)` rather than an offset:
 * rows are written while a client is paging through them, and an offset would
 * skip or repeat whichever ones moved. The pair is encoded into one opaque
 * string because the app stores it verbatim and must never be tempted to
 * interpret it - which is what leaves this module free to change how it pages.
 *
 * The position is epoch millis, so that a live row (ordered by its `updated_at`
 * timestamp) and a tombstone (ordered by its `deleted_at_ms` integer) can be
 * merged into one stream and one bookmark.
 *
 * That "changed at" is the *server's* clock, deliberately not the client-stated
 * `sync_updated_at` the merge compares on. One phone with its date set a year
 * ahead would otherwise drag the cursor into the future and strand every row
 * written after it.
 */

/**
 * @param {{ ms: number, id: string }} position
 * @returns {string}
 */
export function encodeCursor(position) {
  return Buffer.from(JSON.stringify({ t: position.ms, id: position.id }), 'utf8').toString(
    'base64url',
  );
}

/**
 * Unreadable is treated as absent rather than as an error: the answer to a
 * corrupt bookmark is a full re-pull, which is safe - every row lands as an
 * upsert - and self-healing, which returning 422 to a phone in a shop is not.
 *
 * @param {string | undefined | null} cursor
 * @returns {{ ms: number, id: string } | null}
 */
export function decodeCursor(cursor) {
  if (!cursor) return null;
  try {
    const { t, id } = JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8'));
    if (typeof id !== 'string' || !Number.isFinite(t)) return null;
    return { ms: t, id };
  } catch {
    return null;
  }
}

/**
 * "Strictly after this position", as a Prisma filter.
 *
 * `cast` turns the position's millis into whatever the column being paged is -
 * a Date for a live row's `updated_at`, a BigInt for a tombstone's
 * `deleted_at_ms`.
 *
 * @param {{ ms: number, id: string } | null} after
 * @param {string} timeField
 * @param {string} idField
 * @param {(ms: number) => unknown} cast
 */
export function keysetAfter(after, timeField, idField, cast) {
  if (!after) return [];
  const at = cast(after.ms);
  return [
    {
      OR: [
        { [timeField]: { gt: at } },
        { AND: [{ [timeField]: at }, { [idField]: { gt: after.id } }] },
      ],
    },
  ];
}

/** Ascending by the same pair the cursor is built from. */
export function byPosition(a, b) {
  if (a.ms !== b.ms) return a.ms - b.ms;
  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}
