# Screen build plan

The data layer, the sync engine and the widget kit are done. What is left is
the app itself: twenty views, their controllers, the routes that reach them,
and five queries the screens need that no repository answers yet.

This is the order to build them in and the reasoning behind that order. It is
written against the web app in `frontend/`, which is the reference
implementation — every screen here has a counterpart there, and where the two
differ deliberately it is called out.

## Where things stand

| Layer | State |
|---|---|
| Models, DAOs, repositories | Complete. Filters, search, date windows, cheque register, derived balances. |
| Sync engine, outbox, conflict rules | Complete, 99 tests. |
| Theme, palette, widget kit | Complete, 25 tests. |
| Change bus, screen scaffold, loader base | Complete, 8 tests. |
| Screens | 23 of 23. All six phases built. |
| Routes | 18 of 22. The four remaining constants are tab lists, reached as shell tabs. |

Three pieces were added for the screens to share, and everything after Phase 1
is expected to use them:

* **`AppScreen`** — the frame: header, eyebrow, pinned filter row, scroll
  container, pull-to-refresh, bottom bar. The counterpart of the web's `Screen`.
* **`ErrorView`** — the fourth state, so a failed read never renders as an empty
  list that reads like "no records".
* **`LoaderController<T>`** — load / silent-reload / error / empty in one place,
  plus the change-bus subscription and its cancellation. A screen supplies
  `fetch()` and `watches`, and gets the convention for free.

## Three things to settle before the first screen

**All three are settled and implemented.** Kept here because they explain why
the code is shaped the way it is.

### 1. How a list learns that a write happened — DONE

The web gets this free: React Query invalidates `['suppliers']` after a payment
and every mounted list refetches. Nothing here does that. `BaseRepository.write`
already fires `_notifySync()` to keep the pending-count chip honest — but that
only updates the chip, not the screens.

**Do this:** broadcast the touched entity from `write()` onto a small
`DataChangeBus` service, and have each list controller subscribe to the entities
it shows. Roughly forty lines, and it solves the harder half of the problem for
free: rows arriving from a **sync pull** are writes too, so a list refreshes
when the server sends something new without any screen knowing sync exists.

The alternative — refreshing in `onInit` and after `Get.toNamed` returns — looks
simpler and then quietly fails in exactly the cases that matter: the dashboard
open in one tab while a bill is saved in another, and anything pulled by sync.

### 2. Where the list screens live — DONE

`HomeView` keeps its five tabs in an `IndexedStack`, so a half-filtered list
survives a trip to another tab. That means the four list views are **tab bodies,
not pushed routes**: `Routes.purchases` and friends stay as deep-link targets
that switch the tab rather than pushing a second copy of a screen the user is
already looking at.

Everything else is pushed. Sixteen `GetPage`s.

### 3. One missing route constant — DONE

`Routes.supplierStatement` does not exist. Add it next to `supplierDetail`.

## The build order

Six phases. Each one ends somewhere the app is usable, so the order is also a
demo order — not just a dependency graph.

### Phase 1 — Suppliers ✅ BUILT

**Why first:** it exercises every part of the kit exactly once (list, search,
balance card, detail with tabs, a form, a report), and it is the screen the
whole product is about. Everything after this is a variation on it.

| Screen | Web reference |
|---|---|
| `SuppliersView` — list, search, total payable | `SuppliersScreen.jsx` |
| `SupplierFormView` — create and edit | `SupplierFormScreen.jsx` |
| `SupplierDetailView` — balance, ledger/bills/payments tabs, date window | `SupplierDetailScreen.jsx` |
| `SupplierStatementView` — opening, movements, running balance, closing | `SupplierStatementScreen.jsx` |

**Data layer work (done):** the windowed statement. `SupplierRepository` could
answer "what is owed" all-time but not "what was owed on the morning of the
1st", which is the figure both the detail window and the statement are built on:

```
openingAsOf   = opening balance + bills before `from` − uncancelled payments before `from`
purchaseTotal = bills within [from, to]
paymentTotal  = uncancelled payments within [from, to]
closing       = openingAsOf + purchaseTotal − paymentTotal
```

Add it as `SupplierRepository.statement({id, fromMs, toMs, search})` returning
the window figures plus the interleaved movements. One method, two screens.

**Done when:** a supplier's outstanding on the list, on the detail card and at
the foot of a full-range statement are the same number, and narrowing the range
changes the window figures without changing the all-time balance above them.

### Phase 2 — Purchases ✅ BUILT

**Why second:** bills are what move a supplier balance, so this is what makes
Phase 1 do anything. The form is the simplest in the app — one whole bill, no
line items, because the shop does not track stock.

| Screen | Notes |
|---|---|
| `PurchasesView` | Newest first, grouped by day, day total on the header |
| `PurchaseFormView` | Supplier, amount, bill no., both dates, description |
| `PurchaseDetailView` | Amount / paid / still owed, supplier card, payments against it |

**Data layer work:** none. `PurchaseRepository.list` already takes supplier,
range, search and `onlyUnpaid`, and `paid_total` is computed in the DAO.

**Watch for:** the BS date field. Both calendars are captured — AD is what the
database sorts on, BS is what the paperwork says — and `NepaliDate` converts
either way, so the form should derive one from the other as it is typed rather
than making the shopkeeper key both.

**Done when:** saving a bill moves the supplier's outstanding on a list that was
already open (the Phase 0 decision, earning itself).

### Phase 3 — Payments and the cheque register ✅ BUILT

**Why third:** this closes the loop — bills go up, payments bring them down —
and it is where the product's one genuinely unusual idea lives: a cheque handed
over is recorded immediately but is not yet a bank transaction.

| Screen | Notes |
|---|---|
| `PaymentFormView` | Cheque fields appear only for a cheque; pre-fills supplier and bill when opened from one |
| `PaymentDetailView` | Clear and cancel actions, both confirmed |
| `ChequeRegisterView` | Bucketed overdue / next 7 days / later, ordered by the date on the cheque |

**Data layer work:** none. `chequeRegister`, `uncleared`, `markCleared` and
`markCancelled` all exist.

**Watch for:** cancelling is not deleting. A cancelled payment stays on the
statement for the audit trail and settles nothing — the ledger skips it in the
running balance rather than omitting the line.

**Done when:** issuing a cheque reduces what the supplier is owed while showing
up separately as "not cleared", and clearing it later moves nothing.

### Phase 4 — Sales ✅ BUILT

**Why fourth:** sales are independent of the supplier side, so they could come
earlier, but the itemised form is the biggest screen in the app and is better
built once the patterns are settled.

| Screen | Notes |
|---|---|
| `SalesView` | Grouped by day, filtered by type, header opens the day |
| `SaleFormView` | Two shapes: a total, or invoice lines that derive the total |
| `SaleDetailView` | Items, payments, totals |
| `SaleDayView` | One day: takings, how they were settled, same-day bills and payments |

**Data layer work:** extend `SaleRepository.dayBook`. It returns the day's sales
today; the screen also needs takings **by payment mode**, the same day's
purchases, and the same day's supplier payments.

**Watch for:** credit is not takings. A sale settled `CREDIT` is amber, not
green, and counting it as money received is how a day's till stops matching the
day book. `SaleRow` already does this; the day totals must agree.

**Done when:** a day's takings equals the sum of the sales listed under it —
there is no separate "day's takings" record anywhere in the system, by design.

### Phase 5 — Customers and settings ✅ BUILT

Small screens, and the app is not shippable without them: the More tab is
currently the only route to signing out, and sign-out is a temporary button in
the `HomeView` app bar.

| Screen | Notes |
|---|---|
| `CustomersView`, `CustomerFormView` | Invoice customers only; a walk-in is not a record |
| `MoreView` | Account, shop, links, fiscal years, theme, sync status, sign out |
| `ShopFormView` | Writes through `AuthApi.updateMe` and the local `StorageService` |
| `FiscalYearFormView` | Create and activate |

**Plumbing this phase must fix:**

- **The theme toggle does not work yet.** `main.dart` reads
  `storage.isDarkMode` once at build and offers no dark/light/system choice.
  Make theme mode reactive (`Get.changeThemeMode`, preference persisted) and
  give it the three-way control the web has.
- **`SyncStatusChip` is written but never mounted.** It belongs on the
  dashboard header and in the More screen.
- **Remove the temporary sign-out** from `HomeView`'s app bar once More exists.

### Phase 6 — Dashboard ✅ BUILT

**Why last:** it reads from every other screen's data. Built first it would be
mocked; built last it is assembled from queries that already exist.

One view, and one new `DashboardRepository` that composes what is already there:

| Card | Source |
|---|---|
| Sales today + 14-day trend | `sales.dayBook`, `sales.dailyTotals` |
| Payable to suppliers | `suppliers.topOutstanding` + a payable total |
| Cheques not cleared, next due | `payments.uncleared`, `payments.chequeRegister` |
| Quick actions | Navigation only |
| Owed the most, latest sales, latest bills | `suppliers.topOutstanding`, `sales.list`, `purchases.list` |

**Done when:** every figure on it can be reached by tapping through to the rows
that produced it, and the two agree.

## Conventions for every screen

Settle these once, in Phase 1, and copy them.

**One controller per screen, no DAOs.** Controllers hold `Rx` state and call
repositories. The rule from `ARCHITECTURE.md` holds: controllers never touch a
DAO.

**Four states, always.** Loading is `SkeletonRows`, not a spinner in the middle
of a blank page. Empty is `EmptyState` with the action that would fill it.
Error is a retry, not a toast that scrolls away. Loaded is the list. A screen
that only handles the fourth is a screen that looks broken on a slow phone.

**Rows do not navigate.** Every row in the kit takes `onTap`; the screen decides
what a tap means, because the same row appears in a list and in a picker.

**Arguments go through `RouteArgs`.** The constants exist and nothing uses them
yet. A screen reads `Get.arguments` once in its controller's `onInit` and never
again.

**Forms validate client-side and let the repository have the last word.** The
same rule the web follows: mirror the checks so the form cannot produce a write
the repository will reject, but do not treat the mirror as the authority.

**Pickers are sheets, not dropdowns.** `AppSheet.options` exists for this. A
supplier picker over a hundred rows needs search, so it gets a sheet with a
`SearchField`, not a `DropdownButton`.

## Deliberately not in this plan

- **Attachments.** The schema has `DocumentType` and the web shows scanned bills
  read-only, but there is no attachment model, DAO or upload path on the phone.
  It is a feature, not a gap in this port — decide separately.
- **Editing bills and payments.** They are append-only by design: a mistake is
  voided and re-issued. Only master data — parties, fiscal years, shop — is
  editable.
- **A web build of this app.** `dart:io` and `sqflite` do not compile there.

## Phase 1 as built

Four screens, one new query, and the three shared pieces above.

**`SupplierDao.window()`** answers what the all-time balance cannot — what was
owed on the morning a window opens — with inclusive, independently nullable
bounds. **`SupplierRepository.statement()`** wraps it with the movements and
hands back both orderings the screens need: `movements` newest-first for the
detail screen's ledger tab, `lines` oldest-first with a running balance for the
report. One query behind both, so the ledger and the statement cannot disagree.

Ten tests pin the arithmetic. The two that matter most are the cross-checks: an
unbounded window's closing balance equals the `outstanding` computed by the
entirely separate all-time query, and the last statement line equals the closing
figure in its own header.

**Deferred deliberately:** the web's **Call** button on the supplier detail
screen. Dialling needs `url_launcher`, which is not a dependency yet; the phone
number is on the detail list in the meantime. Add the package and the button
together, or drop the idea — but do not ship a button that does nothing.

## Phase 2 as built

Three screens, no new repository queries — the DAO already answered everything.
Three shared pieces were added on the way, and Phases 3 to 5 should use them
rather than growing their own:

* **`groupByDay`** (`core/domain/day_group.dart`) — buckets an already
  date-sorted list and sums each day from its own rows. Insertion order is
  preserved, so a list the DAO returned newest-first stays that way. Sales will
  use the same function.
* **`DateField`** — a date in both calendars, opening the Gregorian picker
  because that is what the device knows and the database sorts on, with the BS
  conversion underneath because that is what the shop reads.
* **`showPickerSheet<T>`** — the searchable picker every form needs. It
  re-queries per keystroke rather than filtering a list held in memory, so a
  picker can never offer a record the list would not, and it guards against a
  slow early query landing after a fast later one.

**The BS date rule, as implemented:** the bill's BS date is filled in from the
AD date and keeps tracking it — until the shopkeeper types in the BS field
themselves, at which point the picker stops overwriting it. What the bill says
wins over what the conversion says, and a bill that disagrees with the almanac
is exactly the case worth preserving rather than silently correcting.

**Saving replaces the form** rather than pushing over it (`Get.offNamed`), so
backing out of a bill you just saved does not land on a filled-in form inviting
a duplicate.

## Phase 3 as built

Three payment screens plus the **More** tab, which had to exist for the cheque
register to be reachable at all — a route with no way to it is not shipped. It
lists the Phase 5 destinations disabled rather than hiding them, so the menu
stays an honest map of what the app does.

**`PartyField`** joined the kit and the bill form was moved onto it, deleting
the near-identical private copy written in Phase 2. It is the slot a picked
record sits in, and its subtitle is the reason it exists: a picked supplier
shows what is currently owed, a picked bill shows what is left on it — the
context that decides whether the amount about to be typed is the right one.

**What the form does with mode:** cheque and reference fields are rendered only
for the mode that uses them, and are **nulled on save** for every other mode —
so switching from cheque to cash after typing cannot leave a stale cheque
number attached to a cash payment.

**What the form does with the bill:** only this supplier's *unpaid* bills are
offered, the amount pre-fills to what is left on the chosen bill, and changing
the supplier clears a bill belonging to the previous one. A payment filed
against another supplier's bill is not a mistake worth allowing.

**Both destructive actions state their consequence before it happens.**
Clearing says what you owe does not change, because it does not — an issued
cheque already counted. Cancelling says the amount goes *back* onto what you
owe, and that the line stays on the statement. Cancelling is not deleting.

## Phase 4 as built

Four screens and the one real data-layer extension left in the plan.

**`SaleRepository.dayBookFull`** returns a `DayBook`: the day's sales, the bills
dated that day, the supplier payments dated that day, and the figures derived
from all three. The three reads are assembled in the repository rather than the
controller — a join in the widget layer is one refactor away from disagreeing
with the lists beneath it.

**The credit rule, in one place.** `DayBook` exposes `salesTotal` (turnover,
credit included) and `received` (money, credit excluded) as separate figures,
and `onCredit` as the gap. The day card shows the second as its headline and
names the first in its caption, because a day that sold well on credit is a good
day and a bad till — the screen should not have to choose which of those to
report. `byMode` is built from **payment lines, not sale headers**: one sale can
be settled half cash and half on account, and a header-level split would have to
pick one and be wrong about the other.

**Ten tests** pin that arithmetic, including the invariant that `received +
onCredit` always reconstructs `salesTotal`, and that the mode split always sums
to exactly `received` — so the card cannot contradict itself.

**The itemised form derives its total and does not offer to override it.** The
lines total is displayed, not editable, and `SaleRepository.save` recomputes it
from the lines anyway. A line's amount goes through the same
`calculateLineAmount` the model and the backend use, so a line previewed on the
form and read back after saving cannot round differently.

**A credit sale writes a CREDIT payment line for the full amount** rather than
no line at all: "sold on credit" is a fact about the sale, and recording it as
an absence would make it indistinguishable from a sale nobody has settled yet.
A part-paid counter sale writes both lines, so the payments always add up to the
sale total.

## The Obx rule

`Obx` tracks only the observables read **inside its own closure, while that
closure runs**. A child widget's `build` runs later, outside that scope, so:

```dart
// Throws "improper use of a GetX" — the closure reads nothing.
bottomBar: Obx(() => _SaveBar(controller: controller)),

// Fine — the observables are read in the argument list, inside the closure.
Obx(() => _BillField(bill: controller.againstBill.value)),

// Fine — the widget owns its Obx, so the tracking closure is its own build.
bottomBar: _SaveBar(controller: controller),   // with Obx inside build()
```

The failure has two faces and the loud one is the lucky one. If the closure
reads *no* observable at all, GetX throws on sight. If it reads one but the
child reads *another* untracked, nothing throws and the child simply never
updates — which is how `_Actions` on the payment screen would have kept showing
an idle button while a cheque was being cleared.

So: a widget that reads `controller.something.value` either **wraps its own
content in `Obx`**, or **takes the value as a plain constructor argument** read
at a tracked call site. Passing just the controller and reading observables
inside is the shape to avoid.

## The screen test harness

`test/helpers/test_app.dart` mounts a real screen against a real database.
Nothing in it is a mock: the schema is `DbHelper.schemaStatements`, the
repositories are the real ones, and the storage service really runs — a screen
test whose data layer is fake mostly proves the fake works.

It exists because the Obx bug above shipped through a clean analyze, 165 green
tests and a successful APK build. Nothing had ever *run* a screen.

Five things were needed to make widget tests work against this stack, and each
was invisible until the one before it was fixed:

1. **path_provider has no implementation under `flutter test`**, and `GetStorage`
   asks it where to write. Mocked to a scratch directory.
2. **`pumpAndSettle` never returns**, because the loading skeleton shimmers on
   a `..repeat()` controller and there is always another frame scheduled. Use
   the bounded `settle()` helper instead.
3. **Real I/O does not progress inside the fake-async zone** `testWidgets` runs
   in. Both `settle()` and `seed()` step out through `runAsync`; a repository
   write called directly from a test body simply hangs.
4. **`Get.toNamed` completes when a route is *popped***, not when it is pushed,
   so awaiting it waits forever for the screen under test.
5. **`Get.deleteAll` leaves GetX's routing state behind.** The second test to
   navigate to the same route name gets a no-op, the screen never mounts, and
   every finder returns empty — which looks exactly like a broken screen.
   `Get.reset()` is what actually clears it.

Each screen is mounted empty and populated, because those are different code
paths and the empty one is the one nobody tries by hand.

## Phase 5 as built

Customers, fiscal years, shop details, and a More tab that is now a real screen
rather than a menu of promises. All three pieces of plumbing the phase owed are
done:

**The theme is a three-way choice and it applies immediately.** The stored
preference moved from a bool to the mode's name, because "dark: false" cannot
tell apart *chose light* from *never chose* — and those want different behaviour
when the phone switches to dark at sunset. Reads still accept the old boolean,
so an existing install keeps what it had. `Get.changeThemeMode` means the choice
lands under the user's finger rather than on next launch.

**`SyncStatusChip` is mounted** on the More header, and only when a sync service
is actually registered — the app runs local-only quite happily, and a status
chip in that state reports on something nobody switched on.

**The temporary sign-out is gone** from the tab placeholder now that More has a
real one, with a confirmation that says what happens to unsynced records.

Two things worth knowing about the screens themselves:

* **The customer form is also the customer's page.** A customer carries no
  derived balance — unlike a supplier, whose whole screen is arithmetic — so a
  separate read-only view would be the same six fields with an edit button on
  top. What they have bought appears above the fields when there is a history.
* **Fiscal years warns when no year covers today**, because that is the state in
  which every form in the app quietly refuses to save. The new-year sheet
  defaults to the Nepali year containing today and ends its range the day before
  the next one opens, so two years meet with no gap and no overlap.

**Shop details saves locally first and unconditionally**, then tries the server.
A failed push is reported as "saved on this device" rather than an error,
because the change *was* kept — an offline-first app whose shop cannot rename
itself offline would be a strange thing.

## Phase 6 as built

One view, one `DashboardRepository` that composes queries the other phases
already own, and no new SQL. That was the point of building it last.

**One method, one await point.** Seven separate loads would give the screen
seven chances to be half-drawn, and a dashboard that fills in piecemeal reads
as broken on exactly the slow phone this app is for.

**The trend fills its gaps.** The DAO returns only days that had sales;
plotting those alone draws a line that skips the quiet days and makes a bad
week look steady. The repository expands them to one point per day, zeros
included — the gaps are the information.

**`TrendPoint` moved to `core/domain/`.** A repository producing a fortnight of
them should not have to import the chart that draws them; the data layer
depending on the widget layer is the wrong way round.

### Two real bugs these tests caught

**Sale lines and payments were saved with an empty id.** `SaleRepository.save`
re-keyed each row to its sale but never gave it an id of its own, and a form has
no business inventing primary keys — so every row arrived with `id: ''`. That
inserts once and then violates the unique constraint: the app would have saved
exactly **one sale with a payment** and failed on the second, with the error
surfacing a long way from the mistake. Fixed in the repository, which already
stamps the sale's own id, and pinned by a test that saves two sales.

**`SyncStatusChip` threw when no sync service was registered.** Harmless in the
app as it stands, since `main` always registers one — but the More screen
guarded the chip and the dashboard did not, and an inconsistency like that is
one refactor away from a crash in the header of the first screen anyone sees.
The check now lives inside the chip, once.

Neither was reachable by any test that did not actually build a screen.
