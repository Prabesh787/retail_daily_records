-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "user_role" AS ENUM ('ADMIN', 'USER');

-- CreateEnum
CREATE TYPE "supplier_payment_mode" AS ENUM ('CASH', 'CHEQUE', 'BANK_TRANSFER', 'OTHER');

-- CreateEnum
CREATE TYPE "sale_payment_mode" AS ENUM ('CASH', 'BANK', 'CHEQUE', 'CREDIT', 'OTHER');

-- CreateEnum
CREATE TYPE "payment_status" AS ENUM ('ISSUED', 'CLEARED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "sale_type" AS ENUM ('SUMMARY', 'DETAILED');

-- CreateEnum
CREATE TYPE "attachment_entity_type" AS ENUM ('PURCHASE', 'SUPPLIER_PAYMENT', 'SALE');

-- CreateEnum
CREATE TYPE "document_type" AS ENUM ('PURCHASE_BILL', 'SUPPLIER_PAYMENT_RECEIPT', 'CHEQUE_COPY', 'SALE_INVOICE', 'OTHER');

-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "name" VARCHAR(120) NOT NULL,
    "email" VARCHAR(180) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "role" "user_role" NOT NULL DEFAULT 'USER',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "fiscal_years" (
    "id" UUID NOT NULL,
    "name" VARCHAR(20) NOT NULL,
    "start_date" DATE NOT NULL,
    "end_date" DATE NOT NULL,
    "start_date_bs" VARCHAR(10),
    "end_date_bs" VARCHAR(10),
    "is_active" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "fiscal_years_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "suppliers" (
    "id" UUID NOT NULL,
    "name" VARCHAR(180) NOT NULL,
    "contact_person" VARCHAR(120),
    "phone" VARCHAR(30),
    "email" VARCHAR(180),
    "address" VARCHAR(255),
    "pan" VARCHAR(30),
    "opening_balance" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "remarks" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "suppliers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customers" (
    "id" UUID NOT NULL,
    "name" VARCHAR(180) NOT NULL,
    "phone" VARCHAR(30),
    "address" VARCHAR(255),
    "pan" VARCHAR(30),
    "remarks" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "customers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "purchases" (
    "id" UUID NOT NULL,
    "fiscal_year_id" UUID NOT NULL,
    "supplier_id" UUID NOT NULL,
    "bill_no" VARCHAR(60) NOT NULL,
    "bill_date" DATE NOT NULL,
    "bill_date_bs" VARCHAR(10),
    "description" TEXT,
    "amount" DECIMAL(14,2) NOT NULL,
    "remarks" TEXT,
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "purchases_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "supplier_payments" (
    "id" UUID NOT NULL,
    "fiscal_year_id" UUID NOT NULL,
    "supplier_id" UUID NOT NULL,
    "purchase_id" UUID,
    "voucher_no" VARCHAR(60),
    "payment_date" DATE NOT NULL,
    "payment_date_bs" VARCHAR(10),
    "payment_mode" "supplier_payment_mode" NOT NULL,
    "amount" DECIMAL(14,2) NOT NULL,
    "cheque_no" VARCHAR(60),
    "cheque_date" DATE,
    "cheque_date_bs" VARCHAR(10),
    "reference_no" VARCHAR(100),
    "cleared_date" DATE,
    "status" "payment_status" NOT NULL DEFAULT 'CLEARED',
    "description" TEXT,
    "remarks" TEXT,
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "supplier_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sales" (
    "id" UUID NOT NULL,
    "fiscal_year_id" UUID NOT NULL,
    "invoice_no" VARCHAR(60),
    "sale_date" DATE NOT NULL,
    "sale_date_bs" VARCHAR(10),
    "customer_id" UUID,
    "sale_type" "sale_type" NOT NULL,
    "description" TEXT,
    "subtotal" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "discount" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "total_amount" DECIMAL(14,2) NOT NULL,
    "remarks" TEXT,
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "sales_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sale_items" (
    "id" UUID NOT NULL,
    "sale_id" UUID NOT NULL,
    "description" VARCHAR(255) NOT NULL,
    "quantity" DECIMAL(14,3) NOT NULL,
    "unit" VARCHAR(20) NOT NULL,
    "unit_price" DECIMAL(14,2) NOT NULL,
    "discount" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "amount" DECIMAL(14,2) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sale_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sale_payments" (
    "id" UUID NOT NULL,
    "sale_id" UUID NOT NULL,
    "payment_mode" "sale_payment_mode" NOT NULL,
    "amount" DECIMAL(14,2) NOT NULL,
    "reference_no" VARCHAR(100),
    "cheque_no" VARCHAR(60),
    "cheque_date" DATE,
    "cleared_date" DATE,
    "status" "payment_status" NOT NULL DEFAULT 'CLEARED',
    "remarks" TEXT,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "sale_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "attachments" (
    "id" UUID NOT NULL,
    "entity_type" "attachment_entity_type" NOT NULL,
    "entity_id" UUID NOT NULL,
    "document_type" "document_type" NOT NULL,
    "original_file_name" VARCHAR(255) NOT NULL,
    "storage_key" VARCHAR(500) NOT NULL,
    "storage_driver" VARCHAR(30) NOT NULL DEFAULT 'local',
    "mime_type" VARCHAR(150) NOT NULL,
    "file_size" INTEGER NOT NULL,
    "uploaded_by" UUID,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "attachments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "fiscal_years_name_key" ON "fiscal_years"("name");

-- CreateIndex
CREATE INDEX "fiscal_years_is_active_idx" ON "fiscal_years"("is_active");

-- CreateIndex
CREATE INDEX "suppliers_name_idx" ON "suppliers"("name");

-- CreateIndex
CREATE INDEX "suppliers_is_active_idx" ON "suppliers"("is_active");

-- CreateIndex
CREATE INDEX "customers_name_idx" ON "customers"("name");

-- CreateIndex
CREATE INDEX "customers_phone_idx" ON "customers"("phone");

-- CreateIndex
CREATE INDEX "purchases_supplier_id_idx" ON "purchases"("supplier_id");

-- CreateIndex
CREATE INDEX "purchases_bill_date_idx" ON "purchases"("bill_date");

-- CreateIndex
CREATE INDEX "purchases_fiscal_year_id_idx" ON "purchases"("fiscal_year_id");

-- CreateIndex
CREATE INDEX "purchases_created_by_idx" ON "purchases"("created_by");

-- CreateIndex
CREATE UNIQUE INDEX "purchases_supplier_fy_bill_no_key" ON "purchases"("supplier_id", "fiscal_year_id", "bill_no");

-- CreateIndex
CREATE INDEX "supplier_payments_supplier_id_idx" ON "supplier_payments"("supplier_id");

-- CreateIndex
CREATE INDEX "supplier_payments_payment_date_idx" ON "supplier_payments"("payment_date");

-- CreateIndex
CREATE INDEX "supplier_payments_status_idx" ON "supplier_payments"("status");

-- CreateIndex
CREATE INDEX "supplier_payments_cheque_date_idx" ON "supplier_payments"("cheque_date");

-- CreateIndex
CREATE INDEX "supplier_payments_purchase_id_idx" ON "supplier_payments"("purchase_id");

-- CreateIndex
CREATE INDEX "supplier_payments_fiscal_year_id_idx" ON "supplier_payments"("fiscal_year_id");

-- CreateIndex
CREATE INDEX "supplier_payments_created_by_idx" ON "supplier_payments"("created_by");

-- CreateIndex
CREATE UNIQUE INDEX "supplier_payments_fy_voucher_no_key" ON "supplier_payments"("fiscal_year_id", "voucher_no");

-- CreateIndex
CREATE INDEX "sales_sale_date_idx" ON "sales"("sale_date");

-- CreateIndex
CREATE INDEX "sales_fiscal_year_id_idx" ON "sales"("fiscal_year_id");

-- CreateIndex
CREATE INDEX "sales_customer_id_idx" ON "sales"("customer_id");

-- CreateIndex
CREATE INDEX "sales_sale_type_idx" ON "sales"("sale_type");

-- CreateIndex
CREATE INDEX "sales_created_by_idx" ON "sales"("created_by");

-- CreateIndex
CREATE UNIQUE INDEX "sales_fy_invoice_no_key" ON "sales"("fiscal_year_id", "invoice_no");

-- CreateIndex
CREATE INDEX "sale_items_sale_id_idx" ON "sale_items"("sale_id");

-- CreateIndex
CREATE INDEX "sale_payments_sale_id_idx" ON "sale_payments"("sale_id");

-- CreateIndex
CREATE INDEX "sale_payments_status_idx" ON "sale_payments"("status");

-- CreateIndex
CREATE INDEX "attachments_entity_type_entity_id_idx" ON "attachments"("entity_type", "entity_id");

-- CreateIndex
CREATE INDEX "attachments_document_type_idx" ON "attachments"("document_type");

-- CreateIndex
CREATE INDEX "attachments_uploaded_by_idx" ON "attachments"("uploaded_by");

-- AddForeignKey
ALTER TABLE "purchases" ADD CONSTRAINT "purchases_fiscal_year_id_fkey" FOREIGN KEY ("fiscal_year_id") REFERENCES "fiscal_years"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchases" ADD CONSTRAINT "purchases_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "suppliers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "purchases" ADD CONSTRAINT "purchases_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_fiscal_year_id_fkey" FOREIGN KEY ("fiscal_year_id") REFERENCES "fiscal_years"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "suppliers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_purchase_id_fkey" FOREIGN KEY ("purchase_id") REFERENCES "purchases"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "supplier_payments" ADD CONSTRAINT "supplier_payments_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales" ADD CONSTRAINT "sales_fiscal_year_id_fkey" FOREIGN KEY ("fiscal_year_id") REFERENCES "fiscal_years"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales" ADD CONSTRAINT "sales_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sales" ADD CONSTRAINT "sales_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sale_items" ADD CONSTRAINT "sale_items_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "sales"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "sale_payments" ADD CONSTRAINT "sale_payments_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "sales"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "attachments" ADD CONSTRAINT "attachments_uploaded_by_fkey" FOREIGN KEY ("uploaded_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- ---------------------------------------------------------------------------
-- Constraints Prisma cannot express in schema.prisma, added by hand.
-- Keep these in sync with the comments in schema.prisma.
-- ---------------------------------------------------------------------------

-- At most one fiscal year may be active at a time. A partial unique index is
-- the only way to say "unique among the rows where is_active is true".
CREATE UNIQUE INDEX "fiscal_years_single_active_key"
    ON "fiscal_years" ("is_active")
    WHERE "is_active" = true;

-- A fiscal year must be a real range.
ALTER TABLE "fiscal_years"
    ADD CONSTRAINT "fiscal_years_date_range_check" CHECK ("end_date" > "start_date");

-- Money is never negative, and a bill of zero is a data entry mistake.
ALTER TABLE "suppliers"
    ADD CONSTRAINT "suppliers_opening_balance_check" CHECK ("opening_balance" >= 0);

ALTER TABLE "purchases"
    ADD CONSTRAINT "purchases_amount_check" CHECK ("amount" > 0);

ALTER TABLE "supplier_payments"
    ADD CONSTRAINT "supplier_payments_amount_check" CHECK ("amount" > 0);

ALTER TABLE "sales"
    ADD CONSTRAINT "sales_amounts_check"
    CHECK ("subtotal" >= 0 AND "discount" >= 0 AND "total_amount" > 0);

ALTER TABLE "sale_items"
    ADD CONSTRAINT "sale_items_amounts_check"
    CHECK ("quantity" > 0 AND "unit_price" >= 0 AND "discount" >= 0 AND "amount" >= 0);

ALTER TABLE "sale_payments"
    ADD CONSTRAINT "sale_payments_amount_check" CHECK ("amount" > 0);

ALTER TABLE "attachments"
    ADD CONSTRAINT "attachments_file_size_check" CHECK ("file_size" > 0);

-- A cheque payment must carry cheque details; every other mode must not.
ALTER TABLE "supplier_payments"
    ADD CONSTRAINT "supplier_payments_cheque_fields_check" CHECK (
        ("payment_mode" = 'CHEQUE' AND "cheque_no" IS NOT NULL AND "cheque_date" IS NOT NULL)
        OR ("payment_mode" <> 'CHEQUE' AND "cheque_no" IS NULL AND "cheque_date" IS NULL)
    );

-- An ISSUED payment has not cleared yet, so it cannot carry a cleared date;
-- a CLEARED one must say when. This is what keeps a future-dated cheque from
-- being mistaken for money that has already left the account.
ALTER TABLE "supplier_payments"
    ADD CONSTRAINT "supplier_payments_cleared_date_check" CHECK (
        ("status" = 'ISSUED' AND "cleared_date" IS NULL)
        OR ("status" = 'CLEARED' AND "cleared_date" IS NOT NULL)
        OR "status" = 'CANCELLED'
    );

-- Money cannot clear before it was paid.
ALTER TABLE "supplier_payments"
    ADD CONSTRAINT "supplier_payments_cleared_after_payment_check" CHECK (
        "cleared_date" IS NULL OR "cleared_date" >= "payment_date"
    );

-- A DETAILED sale is an invoice and needs a number; a SUMMARY sale is the
-- day's takings and has no items, so it needs none.
ALTER TABLE "sales"
    ADD CONSTRAINT "sales_invoice_no_check" CHECK (
        "sale_type" = 'SUMMARY' OR "invoice_no" IS NOT NULL
    );
