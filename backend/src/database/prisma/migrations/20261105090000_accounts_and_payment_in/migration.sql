-- ---------------------------------------------------------------------------
-- Cash and bank accounts, money received from customers, and movements with no
-- party (deposits, withdrawals, transfers, expenses).
--
-- Additive only. Every new column is nullable and no existing row is rewritten,
-- so builds of the app that know nothing about accounts keep working: a NULL
-- account reads as the cash box for cash, and as "not assigned" for the rest.
-- ---------------------------------------------------------------------------

-- CreateEnum
CREATE TYPE "account_type" AS ENUM ('CASH', 'BANK', 'WALLET');

-- CreateTable
CREATE TABLE "accounts" (
    "id" UUID NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "account_type" "account_type" NOT NULL DEFAULT 'BANK',
    "account_no" VARCHAR(60),
    "opening_balance" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "remarks" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "device_id" VARCHAR(64),
    "sync_updated_at" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_payments" (
    "id" UUID NOT NULL,
    "fiscal_year_id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "sale_id" UUID,
    "voucher_no" VARCHAR(60),
    "payment_date" DATE NOT NULL,
    "payment_date_bs" VARCHAR(10),
    "payment_mode" "supplier_payment_mode" NOT NULL,
    "amount" DECIMAL(14,2) NOT NULL,
    "account_id" UUID,
    "cheque_no" VARCHAR(60),
    "cheque_date" DATE,
    "cheque_date_bs" VARCHAR(10),
    "reference_no" VARCHAR(100),
    "cleared_date" DATE,
    "status" "payment_status" NOT NULL DEFAULT 'CLEARED',
    "remarks" TEXT,
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "device_id" VARCHAR(64),
    "sync_updated_at" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "customer_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "account_entries" (
    "id" UUID NOT NULL,
    "entry_date" DATE NOT NULL,
    "entry_date_bs" VARCHAR(10),
    "from_account_id" UUID,
    "to_account_id" UUID,
    "amount" DECIMAL(14,2) NOT NULL,
    "description" VARCHAR(255),
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,
    "device_id" VARCHAR(64),
    "sync_updated_at" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "account_entries_pkey" PRIMARY KEY ("id")
);

-- AlterTable
ALTER TABLE "supplier_payments" ADD COLUMN "account_id" UUID;
ALTER TABLE "sale_payments" ADD COLUMN "account_id" UUID;

-- CreateIndex
CREATE INDEX "accounts_updated_at_id_idx" ON "accounts"("updated_at", "id");
CREATE INDEX "customer_payments_customer_id_idx" ON "customer_payments"("customer_id");
CREATE INDEX "customer_payments_sale_id_idx" ON "customer_payments"("sale_id");
CREATE INDEX "customer_payments_account_id_idx" ON "customer_payments"("account_id");
CREATE INDEX "customer_payments_payment_date_idx" ON "customer_payments"("payment_date");
CREATE INDEX "customer_payments_status_idx" ON "customer_payments"("status");
CREATE INDEX "customer_payments_cheque_date_idx" ON "customer_payments"("cheque_date");
CREATE INDEX "customer_payments_fiscal_year_id_idx" ON "customer_payments"("fiscal_year_id");
CREATE INDEX "customer_payments_created_by_idx" ON "customer_payments"("created_by");
CREATE INDEX "customer_payments_updated_at_id_idx" ON "customer_payments"("updated_at", "id");
CREATE UNIQUE INDEX "customer_payments_fy_voucher_no_key" ON "customer_payments"("fiscal_year_id", "voucher_no");
CREATE INDEX "account_entries_entry_date_idx" ON "account_entries"("entry_date");
CREATE INDEX "account_entries_from_account_id_idx" ON "account_entries"("from_account_id");
CREATE INDEX "account_entries_to_account_id_idx" ON "account_entries"("to_account_id");
CREATE INDEX "account_entries_updated_at_id_idx" ON "account_entries"("updated_at", "id");
CREATE INDEX "supplier_payments_account_id_idx" ON "supplier_payments"("account_id");
CREATE INDEX "sale_payments_account_id_idx" ON "sale_payments"("account_id");

-- AddForeignKey
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_fiscal_year_id_fkey" FOREIGN KEY ("fiscal_year_id") REFERENCES "fiscal_years"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "sales"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "customer_payments" ADD CONSTRAINT "customer_payments_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "account_entries" ADD CONSTRAINT "account_entries_from_account_id_fkey" FOREIGN KEY ("from_account_id") REFERENCES "accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "account_entries" ADD CONSTRAINT "account_entries_to_account_id_fkey" FOREIGN KEY ("to_account_id") REFERENCES "accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "sale_payments" ADD CONSTRAINT "sale_payments_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- The rules the database already enforces on supplier_payments, in the other
-- direction. See the init migration for why each exists.
ALTER TABLE "accounts"
    ADD CONSTRAINT "accounts_opening_balance_check" CHECK ("opening_balance" >= 0);

ALTER TABLE "customer_payments"
    ADD CONSTRAINT "customer_payments_amount_check" CHECK ("amount" > 0);

ALTER TABLE "customer_payments"
    ADD CONSTRAINT "customer_payments_cheque_fields_check" CHECK (
        ("payment_mode" = 'CHEQUE' AND "cheque_no" IS NOT NULL AND "cheque_date" IS NOT NULL)
        OR ("payment_mode" <> 'CHEQUE' AND "cheque_no" IS NULL AND "cheque_date" IS NULL)
    );

ALTER TABLE "customer_payments"
    ADD CONSTRAINT "customer_payments_cleared_date_check" CHECK (
        ("status" = 'ISSUED' AND "cleared_date" IS NULL)
        OR ("status" = 'CLEARED' AND "cleared_date" IS NOT NULL)
        OR "status" = 'CANCELLED'
    );

ALTER TABLE "customer_payments"
    ADD CONSTRAINT "customer_payments_cleared_after_payment_check" CHECK (
        "cleared_date" IS NULL OR "cleared_date" >= "payment_date"
    );

-- An entry moves money somewhere, and a transfer moves it between two accounts.
ALTER TABLE "account_entries"
    ADD CONSTRAINT "account_entries_amount_check" CHECK ("amount" > 0);

ALTER TABLE "account_entries"
    ADD CONSTRAINT "account_entries_accounts_check" CHECK (
        ("from_account_id" IS NOT NULL OR "to_account_id" IS NOT NULL)
        AND "from_account_id" IS DISTINCT FROM "to_account_id"
    );

-- The same three triggers every synced table carries. The functions already
-- exist; see the 20260903120000_sync_engine migration for what each one is for.
CREATE TRIGGER "accounts_sync_stamp" BEFORE INSERT OR UPDATE ON "accounts"
    FOR EACH ROW EXECUTE FUNCTION sync_stamp_updated_at();
CREATE TRIGGER "customer_payments_sync_stamp" BEFORE INSERT OR UPDATE ON "customer_payments"
    FOR EACH ROW EXECUTE FUNCTION sync_stamp_updated_at();
CREATE TRIGGER "account_entries_sync_stamp" BEFORE INSERT OR UPDATE ON "account_entries"
    FOR EACH ROW EXECUTE FUNCTION sync_stamp_updated_at();

CREATE TRIGGER "accounts_sync_tombstone" AFTER DELETE ON "accounts"
    FOR EACH ROW EXECUTE FUNCTION sync_record_tombstone('accounts');
CREATE TRIGGER "customer_payments_sync_tombstone" AFTER DELETE ON "customer_payments"
    FOR EACH ROW EXECUTE FUNCTION sync_record_tombstone('customer_payments');
CREATE TRIGGER "account_entries_sync_tombstone" AFTER DELETE ON "account_entries"
    FOR EACH ROW EXECUTE FUNCTION sync_record_tombstone('account_entries');

CREATE TRIGGER "accounts_sync_untombstone" AFTER INSERT ON "accounts"
    FOR EACH ROW EXECUTE FUNCTION sync_clear_tombstone('accounts');
CREATE TRIGGER "customer_payments_sync_untombstone" AFTER INSERT ON "customer_payments"
    FOR EACH ROW EXECUTE FUNCTION sync_clear_tombstone('customer_payments');
CREATE TRIGGER "account_entries_sync_untombstone" AFTER INSERT ON "account_entries"
    FOR EACH ROW EXECUTE FUNCTION sync_clear_tombstone('account_entries');
