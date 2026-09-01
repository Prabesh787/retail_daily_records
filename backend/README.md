# Retail Shop — Transaction Records (Backend)

Backend for a small retail clothing shop. It is a **digital recording and
reconciliation system**, not an ERP: it remembers who the shop owes, what it
bought, what it sold and which cheques have not cleared yet.

**Stage 1 (this repository):** database model, project structure, configuration,
migrations, API skeleton. Business logic for purchases, payments and sales is
deliberately left for the next stage. There is no frontend yet.

---

## Table of contents

1. [Business model](#business-model)
2. [Tech stack](#tech-stack)
3. [Setup](#setup)
4. [Environment variables](#environment-variables)
5. [Database commands](#database-commands)
6. [Development commands](#development-commands)
7. [Project structure](#project-structure)
8. [Database schema](#database-schema)
9. [API](#api)
10. [Conventions](#conventions)
11. [What is intentionally not here](#what-is-intentionally-not-here)
12. [Next stage](#next-stage)

---

## Business model

### Purchases are lump-sum whole bills

The shop buys from wholesale suppliers and records the bill as a single amount.

```
Supplier    : ABC Textile
Bill No     : 4521
Bill Date   : 2083-05-10 (BS)
Description : Clothing and textile materials
Amount      : Rs. 100,000
```

There are **no purchase line items**, no product master and no stock tracking.
The paper bill can be scanned and attached as evidence.

### Sales come at two levels of detail

| Type       | When it is used                      | Items        |
| ---------- | ------------------------------------ | ------------ |
| `SUMMARY`  | The day's takings as one figure      | none         |
| `DETAILED` | A customer asks for a proper invoice | `sale_items` |

A `sale_item` is a free-text invoice line ("Printed Cotton - Blue, 5 METER,
Rs. 800"). It is **not** an inventory record and points at no product table.

### Payments are separate records, never a column

A purchase is never stamped with `paid_amount`. Payments live in
`supplier_payments`, so every real settlement pattern is expressible:

```
Purchase              Rs. 100,000
  Payment  CASH       Rs.  20,000   status CLEARED
  Payment  CHEQUE     Rs.  30,000   status ISSUED   cheque date 2083-05-25
  -----------------------------------------------------------------------
  Open credit         Rs.  50,000
```

### Future-dated cheques are first-class

A cheque handed over today for a date three weeks out is recorded immediately,
but it is **not** a cleared bank transaction:

| Field          | At issue   | After it clears |
| -------------- | ---------- | --------------- |
| `status`       | `ISSUED`   | `CLEARED`       |
| `cheque_date`  | 2083-05-25 | 2083-05-25      |
| `cleared_date` | `NULL`     | actual date     |

This lets the reporting layer separate three different things:

- **open credit** — bills with nothing paid against them
- **issued but uncleared** — money promised, still in the account
- **cleared payments** — money actually gone

`GET /api/v1/supplier-payments/cheque-register` lists cheques ordered by the
date written on them, which is the order the money has to be available in.

### Supplier balance is derived, never stored

There is no `current_balance` column anywhere. Outstanding is computed:

```
opening_balance + purchases − recognised payments ± adjustments
```

Storing it would let the balance and the transactions disagree, and the whole
point of this system is that they cannot.

---

## Tech stack

| Concern       | Choice                                     |
| ------------- | ------------------------------------------ |
| Runtime       | Node.js 20.11+ (ES modules, no build step) |
| Language      | JavaScript, with JSDoc on shared helpers   |
| Web framework | Express 5                                  |
| Database      | PostgreSQL                                 |
| ORM           | Prisma 7 (via the `pg` driver adapter)     |
| Validation    | Zod 4                                      |
| Logging       | Pino                                       |
| Auth          | JWT + bcrypt                               |
| Tooling       | ESLint 9, Prettier 3                       |

---

## Setup

```bash
# 1. install
npm install

# 2. configure
cp .env.example .env
#    edit DATABASE_URL to point at your Postgres instance

# 3. create the database (once)
createdb retails_records

# 4. apply the schema
npm run prisma:migrate

# 5. optional: development data (admin user + active fiscal year)
npm run db:seed

# 6. run
npm run dev
```

The API is then at `http://localhost:4000/api/v1`, with a health check at
`http://localhost:4000/health`.

---

## Environment variables

Copy `.env.example` to `.env`. `.env` is git-ignored; `.env.example` is the
documented list. Every variable is validated at boot by `src/config/env.js` —
a missing or malformed value stops the process with a readable message instead
of failing at the first request that needs it.

| Variable                 | Default                       | Purpose                                             |
| ------------------------ | ----------------------------- | --------------------------------------------------- |
| `NODE_ENV`               | `development`                 | `development` \| `test` \| `production`             |
| `PORT`                   | `4000`                        | HTTP port                                           |
| `API_PREFIX`             | `/api/v1`                     | Mount point for every module router                 |
| `CORS_ORIGIN`            | `*`                           | `*` or a comma-separated list of origins            |
| `APP_TIMEZONE`           | `Asia/Kathmandu`              | Calendar day reports treat as "today"               |
| `DATABASE_URL`           | — (**required**)              | Postgres connection string                          |
| `JWT_SECRET`             | dev placeholder               | Token signing key — set a real one in production    |
| `JWT_EXPIRES_IN`         | `1d`                          | Token lifetime                                      |
| `BCRYPT_SALT_ROUNDS`     | `10`                          | Password hashing cost                               |
| `AUTH_DEV_FALLBACK`      | `false`                       | Serve tokenless requests as the first admin (dev)   |
| `STORAGE_DRIVER`         | `local`                       | `local` \| `s3` \| `cloudinary` (only local exists) |
| `LOCAL_STORAGE_PATH`     | `./storage`                   | Where the local driver writes files                 |
| `LOCAL_STORAGE_BASE_URL` | `http://localhost:4000/files` | Prefix for locally served file URLs                 |
| `MAX_UPLOAD_SIZE_MB`     | `10`                          | Rejected above this size                            |
| `LOG_LEVEL`              | `info`                        | `fatal` … `trace`                                   |

Shop identity — name, address, phone and PAN — is **not** configuration. It is
four columns on the `users` row, returned as `shop` by `GET /auth/me` and
`POST /auth/login`, and edited by the account holder through
`PATCH /auth/me`. It used to be `SHOP_*` variables here; a misspelt shop name
should not need a file edit and a restart to fix.

---

## Database commands

The Prisma schema lives at `src/database/prisma/schema.prisma` and migrations
at `src/database/prisma/migrations/`. Both paths are declared in
`prisma7.config.ts`.

```bash
npm run prisma:validate        # check the schema parses and is consistent
npm run prisma:format          # format schema.prisma
npm run prisma:generate        # regenerate the client after a schema change
npm run prisma:migrate         # create + apply a migration (development)
npm run prisma:migrate:create  # write the SQL but do not apply it
npm run prisma:migrate:deploy  # apply pending migrations (production)
npm run prisma:migrate:status  # what has and has not been applied
npm run prisma:studio          # browse the data in a GUI
npm run db:seed                # development records only
```

After editing `schema.prisma`, run `prisma:migrate` — it regenerates the
client as part of the same step.

Some constraints Prisma cannot express (CHECK constraints and the partial
unique index that keeps exactly one fiscal year active) are appended by hand
to the initial migration SQL. If you reset the database, they come back with
it; if you add similar rules later, use `prisma:migrate:create`, edit the SQL,
then apply.

---

## Development commands

```bash
npm run dev            # watch mode
npm start              # plain start
npm run lint           # ESLint
npm run lint:fix       # ESLint with autofix
npm run format         # Prettier, write
npm run format:check   # Prettier, check only
npm run check          # schema validate + lint + format check
```

---

## Project structure

```
src/
  app.js                     Express app assembly (importable by tests)
  server.js                  Boot, health of the DB, graceful shutdown

  config/
    env.js                   Zod-validated environment, fails fast at boot
    logger.js                Pino, pretty in dev and JSON elsewhere

  common/
    errors/                  AppError + typed subclasses
    middleware/
      validate.js            Zod request validation
      error-handler.js       The one place errors become HTTP responses
      request-context.js     Request id + per-request logging
      upload.js              Multipart handling for scanned evidence
    schemas/common.schema.js Shared field rules (money, dates, pagination)
    storage/                 FileStorageService contract + local driver
    utils/                   Response envelope, async wrapper, pagination, money

  database/
    prisma/schema.prisma     The data model
    prisma/migrations/       Generated SQL, checked into git
    prisma-client.js         Single shared client + adapter
    generated/prisma/        Generated client (git-ignored)
    seed.js                  Development-only records

  modules/
    auth/                    JWT login, password hashing
    users/
    fiscal-years/
    suppliers/
    purchases/
    supplier-payments/
    customers/
    sales/
    attachments/

  routes/index.js            Mounts every module under API_PREFIX
```

Each module holds `*.routes.js`, `*.controller.js`, `*.service.js`,
`*.schema.js` and — where queries are complex enough to be worth isolating —
`*.repository.js`. Modules whose queries are one-liners talk to Prisma from the
service directly; adding a repository there would be indirection without a
purpose.

**The layers:** routes declare the URL and the validation, controllers move
data between HTTP and the service, services hold the rules, repositories hold
the queries. Repository methods all accept an optional transaction client as
their last argument, so any of them can be composed into a larger
`prisma.$transaction` without changing a signature.

---

## Database schema

```
fiscal_years ──┬── purchases ──── supplier_payments (optional purchase_id)
               ├── supplier_payments
               └── sales ──┬── sale_items
                           └── sale_payments

suppliers ──┬── purchases
            └── supplier_payments

customers ───── sales (nullable)

users ──┬── purchases.created_by
        ├── supplier_payments.created_by
        ├── sales.created_by
        └── attachments.uploaded_by

attachments ──── polymorphic: PURCHASE | SUPPLIER_PAYMENT | SALE
```

### Tables

| Table               | Holds                                                      |
| ------------------- | ---------------------------------------------------------- |
| `users`             | Login accounts, `ADMIN` or `USER`                          |
| `fiscal_years`      | Nepali fiscal years, e.g. `2082/83`; exactly one active    |
| `suppliers`         | Wholesale vendors, with an opening balance                 |
| `customers`         | Optional — walk-in sales carry `customer_id = NULL`        |
| `purchases`         | Lump-sum bills, no line items                              |
| `supplier_payments` | Cash, cheque and transfer payments with a status lifecycle |
| `sales`             | `SUMMARY` or `DETAILED`                                    |
| `sale_items`        | Free-text invoice lines, `DETAILED` sales only             |
| `sale_payments`     | Cash / bank / cheque / credit split on one sale            |
| `attachments`       | Scanned evidence for any of the above                      |

### Enums

| Enum                     | Values                                                                              |
| ------------------------ | ----------------------------------------------------------------------------------- |
| `user_role`              | `ADMIN`, `USER`                                                                     |
| `supplier_payment_mode`  | `CASH`, `CHEQUE`, `BANK_TRANSFER`, `OTHER`                                          |
| `sale_payment_mode`      | `CASH`, `BANK`, `CHEQUE`, `CREDIT`, `OTHER`                                         |
| `payment_status`         | `ISSUED`, `CLEARED`, `CANCELLED`                                                    |
| `sale_type`              | `SUMMARY`, `DETAILED`                                                               |
| `attachment_entity_type` | `PURCHASE`, `SUPPLIER_PAYMENT`, `SALE`                                              |
| `document_type`          | `PURCHASE_BILL`, `SUPPLIER_PAYMENT_RECEIPT`, `CHEQUE_COPY`, `SALE_INVOICE`, `OTHER` |

`sale_payment_mode` includes `CREDIT` and `supplier_payment_mode` does not.
An unpaid purchase is simply a purchase with no payment rows against it —
"credit" is the absence of a payment, not a kind of payment.

### Uniqueness

| Constraint                                         | Why                                                                            |
| -------------------------------------------------- | ------------------------------------------------------------------------------ |
| `purchases (supplier_id, fiscal_year_id, bill_no)` | Bill numbers are **not** globally unique — two suppliers may both issue "4521" |
| `sales (fiscal_year_id, invoice_no)`               | Unique per year; multiple `NULL`s allowed, which `SUMMARY` sales need          |
| `supplier_payments (fiscal_year_id, voucher_no)`   | Voucher numbers restart each year                                              |
| `fiscal_years (name)`                              | One row per fiscal year                                                        |
| `users (email)`                                    | One account per address                                                        |
| partial unique on `fiscal_years (is_active)`       | At most one active year, enforced by the database                              |

### Indexes

`suppliers.name`, `purchases.supplier_id`, `purchases.bill_date`,
`purchases.fiscal_year_id`, `supplier_payments.supplier_id`,
`supplier_payments.payment_date`, `supplier_payments.status`,
`supplier_payments.cheque_date`, `sales.sale_date`, `sales.fiscal_year_id`,
`sales.customer_id`, plus foreign-key and `attachments (entity_type, entity_id)`
lookup indexes.

### Dates: AD and BS side by side

The shop works in Bikram Sambat, but a BS string cannot be sorted, compared or
range-queried by Postgres. So each document date is stored twice:

| Column         | Type          | Role                                          |
| -------------- | ------------- | --------------------------------------------- |
| `bill_date`    | `date` (AD)   | Canonical. Everything sorts and filters on it |
| `bill_date_bs` | `varchar(10)` | What the shopkeeper typed, for display        |

The same pairing exists on `sale_date`, `payment_date`, `cheque_date` and the
fiscal year boundaries. Converting between the two calendars is a frontend or
service concern; the database only stores what it is given.

### Money

Money is `numeric(14,2)` and quantities are `numeric(14,3)` — never floats.
On the wire, decimals are strings so nothing is lost to JavaScript's number
type. `src/common/utils/money.js` holds the arithmetic, including
`calculateLineAmount`, which is the only place a sale line's amount is ever
produced.

---

## API

Everything is mounted under `API_PREFIX` (default `/api/v1`).

| Method   | Path                                 | Status |
| -------- | ------------------------------------ | ------ |
| `GET`    | `/health`                            | done   |
| `POST`   | `/auth/login`                        | done   |
| `GET`    | `/auth/me`                           | done   |
| `PATCH`  | `/auth/me`                           | done   |
| `GET`    | `/users`                             | done   |
| `POST`   | `/users`                             | done   |
| `GET`    | `/users/:id`                         | done   |
| `PATCH`  | `/users/:id`                         | done   |
| `POST`   | `/users/:id/change-password`         | done   |
| `POST`   | `/users/:id/deactivate`              | done   |
| `GET`    | `/fiscal-years`                      | done   |
| `GET`    | `/fiscal-years/active`               | done   |
| `POST`   | `/fiscal-years`                      | done   |
| `GET`    | `/fiscal-years/:id`                  | done   |
| `PATCH`  | `/fiscal-years/:id`                  | done   |
| `POST`   | `/fiscal-years/:id/activate`         | done   |
| `DELETE` | `/fiscal-years/:id`                  | done   |
| `GET`    | `/suppliers`                         | done   |
| `POST`   | `/suppliers`                         | done   |
| `GET`    | `/suppliers/:id`                     | done   |
| `PATCH`  | `/suppliers/:id`                     | done   |
| `DELETE` | `/suppliers/:id`                     | done   |
| `GET`    | `/customers` … `/customers/:id`      | done   |
| `GET`    | `/purchases`                         | done   |
| `GET`    | `/purchases/:id`                     | done   |
| `POST`   | `/purchases`                         | done   |
| `PATCH`  | `/purchases/:id`                     | done   |
| `DELETE` | `/purchases/:id`                     | done   |
| `GET`    | `/supplier-payments`                 | done   |
| `GET`    | `/supplier-payments/cheque-register` | done   |
| `GET`    | `/supplier-payments/:id`             | done   |
| `POST`   | `/supplier-payments`                 | done   |
| `POST`   | `/supplier-payments/:id/clear`       | done   |
| `POST`   | `/supplier-payments/:id/cancel`      | done   |
| `PATCH`  | `/supplier-payments/:id`             | done   |
| `DELETE` | `/supplier-payments/:id`             | done   |
| `GET`    | `/sales`                             | done   |
| `GET`    | `/sales/day-book`                    | done   |
| `GET`    | `/sales/:id`                         | done   |
| `POST`   | `/sales`                             | done   |
| `PATCH`  | `/sales/:id`                         | done   |
| `DELETE` | `/sales/:id`                         | done   |
| `GET`    | `/attachments`                       | done   |
| `POST`   | `/attachments`                       | done   |
| `GET`    | `/attachments/:id/download-url`      | done   |
| `DELETE` | `/attachments/:id`                   | done   |
| `GET`    | `/reports/dashboard`                 | done   |
| `GET`    | `/reports/supplier-outstanding`      | done   |

**done** = implemented and usable. Nothing returns `501` any more.

`GET /health` and `POST /auth/login` are the only endpoints reachable without a
bearer token — everything else is behind `authenticate`, applied once in
`src/routes/index.js` so a module added later is protected by default rather
than by remembering to.

Derived figures are attached by the endpoint that owns them rather than left to
the client to compute: `/suppliers` and `/suppliers/:id` carry `balance` (and
the detail also carries `window`, the statement for the date range being
viewed), `/purchases/:id` carries `paidTotal` and `dueTotal`, and `/customers`
carries `saleCount` and `saleTotal`.

Free-text search is `?q=` on every list endpoint (`search` is accepted as the
long form).

### Dates in reports

Every date a report returns is a pair: the AD value the database sorts and
range-queries on, and the Bikram Sambat value the shop actually reads
(`billDate` / `billDateBs`, `date` / `dateBs`, and so on). The BS string stored
with a record wins, because it is what was written on the paperwork; only when
that column is empty is BS derived from the AD date, so a row saved without one
still reads correctly. `common/utils/nepali-date.js` holds the conversion — a
month-length table for BS 2000-2100 anchored on 1 Baishakh 2000 BS = 14 April
1943 AD, since BS month lengths follow no formula.

"Today" is the calendar day in `APP_TIMEZONE`, not the server's UTC date:
Kathmandu is UTC+05:45, so a UTC-derived day would still be reporting
yesterday's takings until a quarter past six every morning.

### Response envelope

Success:

```json
{
  "success": true,
  "message": "Suppliers fetched successfully",
  "data": [],
  "meta": { "page": 1, "limit": 20, "total": 0, "totalPages": 1 }
}
```

Failure:

```json
{
  "success": false,
  "message": "Request validation failed",
  "code": "VALIDATION_ERROR",
  "errors": [{ "field": "body.amount", "message": "Amount must be greater than 0" }]
}
```

| Code                      | HTTP | Raised when                                  |
| ------------------------- | ---- | -------------------------------------------- |
| `VALIDATION_ERROR`        | 422  | The request failed its Zod schema            |
| `NOT_FOUND`               | 404  | No such record, or no such route             |
| `DUPLICATE_RESOURCE`      | 409  | A unique constraint was violated             |
| `BUSINESS_RULE_VIOLATION` | 400  | Well-formed but against a rule of the domain |
| `UNAUTHORIZED`            | 401  | Missing or invalid credentials               |
| `FORBIDDEN`               | 403  | Authenticated but not allowed                |
| `PAYLOAD_TOO_LARGE`       | 413  | Upload over `MAX_UPLOAD_SIZE_MB`             |
| `DATABASE_ERROR`          | 500  | Prisma failed for a reason we do not map     |
| `NOT_IMPLEMENTED`         | 501  | Reserved for the next stage                  |
| `INTERNAL_ERROR`          | 500  | Everything else                              |

Every response carries an `X-Request-Id` header that matches the `requestId`
in the logs.

### File attachments

`POST /api/v1/attachments` takes `multipart/form-data`:

| Part           | Value                                          |
| -------------- | ---------------------------------------------- |
| `file`         | The scan — PDF, JPEG, PNG, WebP or HEIC        |
| `entityType`   | `PURCHASE` \| `SUPPLIER_PAYMENT` \| `SALE`     |
| `entityId`     | The uuid of that record                        |
| `documentType` | `PURCHASE_BILL`, `SUPPLIER_PAYMENT_RECEIPT`, … |

Bytes never enter Postgres. The file goes to whichever `FileStorageService` is
configured and the database keeps only the metadata and the driver's
`storage_key`. Moving to S3 or Cloudinary later means writing one class that
satisfies `src/common/storage/file-storage.interface.js` and adding a case to
`getFileStorage()` — no table, no column and no service signature changes.
Each row also records the `storage_driver` that wrote it, so files uploaded
before a switch stay resolvable afterwards.

---

## Conventions

- **Amounts are computed, never accepted.** A client may send `amount` on a
  sale line; the server recomputes it from quantity, price and discount and
  ignores what arrived.
- **Empty string is not a value.** Optional text fields normalise `""` to
  `NULL`, so "not filled in" has exactly one representation.
- **Nothing is deleted that has history.** Suppliers, customers and fiscal
  years with transactions refuse deletion; users are deactivated, never removed.
- **`req.user?.id` is already read** for `created_by` everywhere, so switching
  authentication on changes no controller.

---

## What is intentionally not here

Not oversights — decisions, and adding them would work against what this
system is for:

inventory · stock tracking · product or item master · purchase line items ·
warehouses · barcodes · SKUs · stock valuation · COGS · double-entry
accounting · general ledger · trial balance · balance sheet · profit and loss ·
VAT or tax computation · payroll · POS hardware · complex RBAC

---

## Next stage

1. Purchase creation as one transaction — bill, initial payments and the
   scanned bill's metadata together, or not at all.
2. Supplier payment recording, cheque clearing and cancelling.
3. Sale creation for both types, with totals derived server-side.
4. Editing the lines of an itemised sale after it is saved (the header is
   editable today; the lines are replaced only by re-recording the sale).
5. User management in the UI — the `/users` endpoints exist, but there is no
   screen for them, so a password reset is a database or API job today.
