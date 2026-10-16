# Architecture

Online Flutter + GetX against the Express API in `backend/`. The server is the
source of truth; the app reads and writes it directly, the same way the web
frontend does.

```
lib/
├── main.dart                       services awaited before the first frame
└── app/
    ├── core/                       theme, constants, utils
    │   └── widgets/                the shared kit — generic pieces
    │       └── domain/             …and the ones that know a bill from a sale
    ├── data/
    │   ├── models/                 domain objects, read from and written to JSON
    │   ├── dto/                    WireCodec — tolerant readers for the wire
    │   ├── enums/
    │   ├── providers/remote/       ApiClient, RetailApi, AuthApi
    │   └── repositories/           what a controller is allowed to call
    ├── services/                   GetxServices: auth, storage, change bus
    ├── routes/                     app_routes.dart + app_pages.dart
    ├── bindings/                   global DI
    └── modules/                    one folder per screen group
        └── <module>/{bindings,controllers,views}
```

## The rules that hold it together

**Controllers never touch the API.** They call repositories; repositories call
`RetailApi`. A path or a query parameter appears in exactly one layer.

**One vocabulary for both clients.** `RetailApi` mirrors the web app's
`frontend/src/lib/api/index.js` endpoint for endpoint, and `ApiClient` mirrors
its `http.js`. Two clients against one API drift apart the moment each invents
its own paths, and the drift is invisible until a field is renamed on one side.

**Derived numbers come from the server.** Party balances, a bill's paid total, a
sale's totals, every report figure — all derived from the documents by the
backend and read here, never recomputed. The arithmetic is simple enough to
repeat, and that is exactly the danger: two implementations of one sum are two
chances for the balance card and the ledger under it to disagree.

The exceptions are deliberate and local: the running balance down a supplier
statement, and the day book's split of takings by settlement mode. Both are
presentation of rows already fetched, and both are covered by tests.

**A date is a day, an instant is an instant.** Document dates are held as the
epoch millis of *UTC midnight*, which is what the API's `YYYY-MM-DD` parses to;
timestamps are local. `AppDateUtils` keeps the two apart, and the reason is
concrete: Kathmandu is UTC+05:45, so a local midnight read as UTC lands on the
previous day, and a bill dated the 17th would file itself under the 16th.

**Validation the form can answer, it answers.** An empty field or a zero amount
is refused before a request. Anything that needs the books to answer it — a
duplicate bill number, a supplier that still has history — is the server's to
refuse, and its message is written for a shopkeeper and shown as it is.
`ValidationException` carries the per-field messages; `NetworkException` means
try again.

**A write announces itself.** `BaseRepository.write` publishes to
`DataChangeService` once the server has accepted the change, and a controller
declares which entities it shows. This is the GetX equivalent of React Query
invalidating a key: it is what reloads the dashboard sitting behind the form
that just saved a bill.

**The widget kit has two halves, and only one of them knows the domain.**
`core/widgets/` is generic — a row, a badge, a sheet — and imports no model.
`core/widgets/domain/` is where a `Purchase` becomes a `PurchaseRow`. The split
keeps the generic half restyleable, and it mirrors the web app's `ui/` and
`domain/` folders so a change to one has an obvious counterpart in the other.

## Running it

```bash
flutter run                                                 # Android emulator
flutter run --dart-define=API_BASE_URL=https://…/api/v1     # anywhere else
flutter test                                                # no backend needed
```

`API_BASE_URL` includes the version prefix and defaults to
`http://10.0.2.2:4000/api/v1` — the Android emulator's route to a backend on the
development machine, so `flutter run` works the way `npm run dev` does for the
web app. On a physical device or the iOS simulator, pass the machine's LAN
address. Start the backend with `npm run dev` in `backend/`.

The tests need no backend: `test/helpers/fake_backend.dart` is a small in-memory
implementation of the API plugged in as Dio's transport, so every layer above it
— the client, the models, the repositories, the screens — is the shipping one.
See `test/screens_test.dart`, which mounts every screen against it.

Web is untested but no longer blocked: nothing in the app imports `dart:io` or a
platform database any more.
