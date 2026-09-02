# Architecture

Offline-first Flutter + GetX. SQLite is the source of truth on the device;
sync is a background reconciliation with whatever backend gets chosen.

```
lib/
├── main.dart                       services awaited before the first frame
└── app/
    ├── core/                       theme, constants, utils, shared widgets
    ├── data/
    │   ├── models/                 local domain objects (+ their CREATE TABLE)
    │   ├── dto/                    wire format ⇄ model. The insulation layer.
    │   ├── enums/
    │   ├── providers/
    │   │   ├── local/              DAOs + schema. All SQL lives here.
    │   │   └── remote/             SyncApi contract + Rest/Fake/Noop adapters
    │   ├── repositories/           the only layer that writes
    │   └── sync/                   engine, conflict rules, entity syncers
    ├── services/                   GetxServices: db, storage, connectivity, sync
    ├── routes/                     app_routes.dart + app_pages.dart
    ├── bindings/                   global DI
    └── modules/                    one folder per screen group
        └── <module>/{bindings,controllers,views,widgets}
```

## The rules that hold it together

**Controllers never touch a DAO.** They call repositories; repositories call
DAOs. Swapping the local store or adding a server call touches one layer.

**Every write is a transaction containing the row *and* its outbox entry.**
`BaseRepository.write()` enforces this. It is the entire offline guarantee: if
the bill exists locally, the change to push exists too. A crash between the two
is impossible.

**Bills and payments are append-only.** A mistake is voided and re-issued, not
edited. That is correct accounting, and it is also why sync stays simple —
an immutable row cannot conflict. Genuine conflicts are limited to master data
(a party's phone number, an item's price), where last-write-wins is fine.

**Derived numbers are derived.** Party balances and every report figure are SQL
aggregates over the documents, never stored totals. A stored balance drifts the
moment a bill is voided or a row arrives out of order from sync.

**Ids are UUIDs generated on the device.** Not server auto-increments — an
offline-created bill has to be addressable, and its items have to reference it,
before it has ever seen a network.

**Deletes are soft.** A hard delete is invisible to other clients, which then
resurrect the row. Tombstones propagate; hard deletes do not.

## Sync in one paragraph

The user saves → SQLite commits → a row lands in `sync_queue` → the UI updates.
Later, `SyncService` triggers `SyncEngine` (on reconnect, app resume, manual
refresh, or a 15-minute backstop). The engine pushes the outbox oldest-first,
then pulls each entity's changes since its cursor, applying
`ConflictResolver`'s verdict per row. Failures increment a retry counter rather
than dropping work, and the dashboard chip always says what is outstanding.

See [BACKEND_CONTRACT.md](BACKEND_CONTRACT.md) for the server side.

## Running it

```bash
flutter run                                            # local only
flutter run --dart-define=API_BASE_URL=https://…       # with sync
flutter test                                           # 16 tests, no backend needed
```

Windows desktop works for development — `DbHelper` switches to the sqflite FFI
factory automatically. Web is not supported: `dart:io` and `sqflite` do not
compile there, so a web target would need `sqflite_common_ffi_web` and a guard
around the platform check.
