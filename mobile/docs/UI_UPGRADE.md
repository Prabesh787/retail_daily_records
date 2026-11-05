# UI upgrade: what changed and how to release it

## Navigation

| Tab | Shows |
|---|---|
| Home | To receive, To pay, Cash in hand, In bank, cheque reminder, eight shortcuts, today, recent |
| History | Sales, purchases and both payments in one list, with filters, search and dates |
| Parties | Customers and Suppliers behind one switch |
| Accounts | Total balance, each account, cheques not cleared, Move money |
| More | Day book, Sales by day, Purchase bills, Cheques, Bill gallery, shop, fiscal years, theme |

**The colour rule:** green is money coming in (Sale, Payment In), red is money
going out (Purchase, Payment Out). The sale, purchase and payment forms are built
from the same pieces in `core/widgets/domain/txn_form.dart`.

## How the money is worked out

A balance is never stored. It is the opening balance plus every cleared movement
naming the account, derived in `AccountDao.movementsSql`.

| Record | Effect on an account |
|---|---|
| Cash sale, cash payment | Moves the cash box straight away |
| Bank sale or payment | Moves the bank that was chosen |
| Credit sale | Moves nothing; adds to what the customer owes |
| Cheque, either direction | Moves nothing until marked cleared, then moves the chosen account |
| Bounced or cancelled cheque | Never moves an account; the amount is owed again |
| Move money | Transfer, money in or money out, with no party attached |

## Releasing it

**Order matters. Backend first, then the app.** A new app against the old server
asks to sync tables the server does not know, and those syncs fail until the
server is updated.

1. Back up the production database.
2. Deploy the backend from this branch.
3. Run `npx prisma migrate deploy` in `backend/`. The migration only adds tables,
   nullable columns, constraints and triggers; it does not rewrite existing rows.
4. Confirm `GET /sync/pull?entity=accounts` answers rather than returning 422.
5. Build and release the APK. Phones upgrade their local database on first open.

Older app versions keep working against the new server: they never ask for the
new tables, and a payment they push cannot clear its account link.

**After upgrading, each shop should enter opening balances** under Accounts.
Until then Cash in hand counts only recorded movements, and can show negative.
Older bank and cheque records have no bank named, so they appear on one line,
"Bank not named", which keeps the total correct.

## Known limits

- **Cheque reminders are in-app.** They appear on Home and in the register when
  overdue or due within 7 days. A phone notification needs a new package and
  permission, and is not included.
- **The web app is unchanged.** It keeps working, but shows no accounts, Payment
  In or customer balances.
- **Itemised sales with no invoice number are auto-numbered per phone.** Two
  phones working offline could pick the same number, and the server would refuse
  the second. Typing a number avoids it.
- **Purchases have no item lines.** That is unchanged; the system records a bill
  as a total.
- **Customers have no opening balance.** What a customer owed before the app was
  in use is not captured. Suppliers do have one.
- **Records are not separated by shop.** No table has a shop or owner column, and
  `/sync/pull` does not filter by user, so every account on one backend sees the
  same books. This predates the upgrade and should be settled before a second
  shop goes on the same server.

## Report: one party list, or separate customers and suppliers?

The requirement is that a supplier can also appear on a sale, and a customer on
a purchase. Today they cannot: `Sale.customerId` points only at customers, and
`Purchase.supplierId` only at suppliers.

| | A. Keep separate, link the pairs | B. One `parties` table (recommended) |
|---|---|---|
| Same person on both sides | Two rows joined by a link | One row |
| "What is the net balance with them?" | Add up across two tables | One figure |
| Entering a sale for a supplier | Create the customer twin first | Just pick them |
| For a new user | Must choose which list to look in | One search box |
| Change needed | Small, one new column | Large, touching every party query, sync, and the web app |
| Risk to existing data | Very low | Moderate; needs a careful migration |
| Duplicate names to clean up | Stay as they are | Must be merged, by a person |

**Recommendation: B, as its own release.** Shops in this trade really do buy from
and sell to the same people, and A only hides the two lists behind a link: every
balance, statement and picker would still have to combine them. A is cheaper now
and costs more on each feature after it.

It should not be bundled with this upgrade, which already changes how money is
counted. One large data change at a time is much easier to verify and roll back.

**How B would go:**

1. Add `parties`, reusing existing ids so current records keep pointing at the
   right row. Customer and supplier ids are uuids, so they cannot collide.
2. Keep the old tables and sync entities running alongside until every phone has
   updated.
3. Add an "is this the same person?" merge screen. Merging must stay a person's
   decision, because two shops with the same name may not be the same shop.
4. Move the forms and web app across, then retire the old tables.

The Parties tab already presents one place for both, so the screen barely changes
when this happens.
