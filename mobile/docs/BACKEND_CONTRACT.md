# Sync contract

What the Bill Record app needs from the backend. It is deliberately
database-agnostic — Postgres, MySQL and Mongo all satisfy it, so this can be
implemented before the stack is finalised.

The app is **offline-first**: SQLite on the device is the source of truth for
the user, and sync reconciles it with the server in the background. Nothing in
the UI ever waits on the network.

---

## Entities

`parties`, `products`, `bills` (with nested `items`), `payments`.

Every row carries:

| Field | Type | Notes |
|---|---|---|
| `id` | string (UUID v4) | **Generated on the device.** Never reassign it. |
| `created_at` | int (epoch ms) | |
| `updated_at` | int (epoch ms) | Last-write-wins tiebreaker. |
| `is_deleted` | bool | Soft delete. Deleted rows still come back in pull. |
| `device_id` | string | Which device wrote it. Echoed back on pull. |

---

## `POST /sync/push`

```jsonc
{
  "device_id": "9f1c…",
  "operations": [
    {
      "entity": "bills",
      "entity_id": "3b7e…",          // the row's UUID
      "operation": "upsert",         // or "delete"
      "updated_at": 1735689600000,
      "payload": { /* the full row; bills include their items array */ }
    }
  ]
}
```

Response:

```jsonc
{
  "server_time": 1735689600123,
  "results": [
    { "entity_id": "3b7e…", "status": "accepted" },
    { "entity_id": "4c8f…", "status": "conflict", "server_row": { /* … */ } },
    { "entity_id": "5d9a…", "status": "error", "message": "…", "retryable": false }
  ]
}
```

Return **one result per operation, in the same order**. The client matches
positionally and falls back to matching by `entity_id`.

## `GET /sync/pull?entity=bills&cursor=<opaque>&limit=200`

```jsonc
{
  "rows": [ /* full rows, tombstones included */ ],
  "next_cursor": "…",
  "has_more": false,
  "server_time": 1735689600123
}
```

---

## Five requirements

1. **Accept client-generated UUIDs as primary keys.** A bill created with no
   signal must be valid immediately, and its line items already reference its
   id. Do not return "here is your real id".

2. **Upsert by that id, idempotently.** A push retried after a timeout must
   update the same row, never create a second bill.

3. **Soft-delete only.** A hard delete is invisible to the other clients, so
   they resurrect the row on their next push. Deleted rows must still be
   returned by `pull` with `is_deleted: true`.

4. **`pull` returns rows changed since the cursor, ordered by `updated_at`,
   including tombstones.** The cursor is opaque to the client — implement it as
   a timestamp, a sequence number or a keyset, whatever suits the database.

5. **Bills are atomic with their items.** A bill's `payload` contains its full
   `items` array; store them together. A header that lands without its lines is
   an accounting error, not a partial success.

---

## Two things the client handles, so the server does not have to

- **Conflicts.** Last-write-wins on `updated_at`. Bills and payments are
  append-only in the app — a mistake is voided and re-issued, never edited — so
  genuine conflicts are confined to master data.
- **Stock levels.** Stock is a *projection* of the bills, not an independent
  fact. The client adjusts its local cache as a delta and never pushes an
  absolute stock number; the server should recompute stock from the documents
  it receives.

---

## Wiring the app to a real backend

One line, in `lib/app/bindings/initial_binding.dart`:

```dart
Get.lazyPut<SyncApi>(() => RestSyncApi(ApiClient(baseUrl: '…'), deviceId: …));
```

Or at build time, with no code change at all:

```
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

Until then the app runs against `NoopSyncApi` and honestly reports
"Local only" in Settings. `FakeSyncApi` is an in-memory server used by the
tests, so the whole sync path is verifiable without any backend at all.
