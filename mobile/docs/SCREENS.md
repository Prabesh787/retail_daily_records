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
| Screens | 10 of 23 — splash, login, the shell, four supplier screens, three purchase screens. |
| Routes | 8 of 22 registered. The four tab lists are shell tabs, not routes. |

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

### Phase 3 — Payments and the cheque register

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

### Phase 4 — Sales

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

### Phase 5 — Customers and settings

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

### Phase 6 — Dashboard

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
