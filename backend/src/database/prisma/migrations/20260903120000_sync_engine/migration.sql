-- ---------------------------------------------------------------------------
-- Offline sync support for the mobile app (see src/modules/sync).
--
-- The phone owns a full SQLite copy of the shop's books and reconciles with
-- this database through POST /sync/push and GET /sync/pull. Three things have
-- to be true of every synced table for that to work, and none of them were:
--
--   1. Rows must carry the clock the *client* merges on. Last-write-wins is
--      decided by comparing timestamps, and comparing a phone's clock against
--      a server's would make every push from a device that runs thirty seconds
--      behind look stale - its edits would be rejected forever. So each row
--      keeps `sync_updated_at`: epoch millis as stated by whoever last wrote
--      it, on the same scale the app stores locally.
--   2. Rows must say which device wrote them, so a client can recognise its
--      own change echoing back and not clobber an edit made while the push
--      was in flight.
--   3. Deletions must leave something behind. A row that simply vanishes is
--      invisible to a client that was offline at the time, and that client
--      would push the row straight back on its next sync. `sync_tombstones`
--      is the trace, and a trigger writes it for *every* delete - the web
--      API's included - so no delete path can forget to.
-- ---------------------------------------------------------------------------

-- AlterTable
ALTER TABLE "fiscal_years"
    ADD COLUMN "device_id" VARCHAR(64),
    ADD COLUMN "sync_updated_at" BIGINT NOT NULL DEFAULT 0;

ALTER TABLE "suppliers"
    ADD COLUMN "device_id" VARCHAR(64),
    ADD COLUMN "sync_updated_at" BIGINT NOT NULL DEFAULT 0;

ALTER TABLE "customers"
    ADD COLUMN "device_id" VARCHAR(64),
    ADD COLUMN "sync_updated_at" BIGINT NOT NULL DEFAULT 0;

ALTER TABLE "purchases"
    ADD COLUMN "device_id" VARCHAR(64),
    ADD COLUMN "sync_updated_at" BIGINT NOT NULL DEFAULT 0;

ALTER TABLE "supplier_payments"
    ADD COLUMN "device_id" VARCHAR(64),
    ADD COLUMN "sync_updated_at" BIGINT NOT NULL DEFAULT 0;

ALTER TABLE "sales"
    ADD COLUMN "device_id" VARCHAR(64),
    ADD COLUMN "sync_updated_at" BIGINT NOT NULL DEFAULT 0;

-- Invoice lines are ordered by the shopkeeper, not by insertion time. The app
-- already sends a `sortOrder` with every line and falls back to array position
-- because the column did not exist; this is where it goes.
ALTER TABLE "sale_items"
    ADD COLUMN "sort_order" INTEGER NOT NULL DEFAULT 0;

-- Rows that predate sync get their real last-modified time rather than 0, so
-- the first pull hands the app history that is honestly dated.
UPDATE "fiscal_years"      SET "sync_updated_at" = (EXTRACT(epoch FROM "updated_at") * 1000)::bigint;
UPDATE "suppliers"         SET "sync_updated_at" = (EXTRACT(epoch FROM "updated_at") * 1000)::bigint;
UPDATE "customers"         SET "sync_updated_at" = (EXTRACT(epoch FROM "updated_at") * 1000)::bigint;
UPDATE "purchases"         SET "sync_updated_at" = (EXTRACT(epoch FROM "updated_at") * 1000)::bigint;
UPDATE "supplier_payments" SET "sync_updated_at" = (EXTRACT(epoch FROM "updated_at") * 1000)::bigint;
UPDATE "sales"             SET "sync_updated_at" = (EXTRACT(epoch FROM "updated_at") * 1000)::bigint;

-- Existing lines keep the order they were entered in.
WITH ordered AS (
    SELECT "id", ROW_NUMBER() OVER (PARTITION BY "sale_id" ORDER BY "created_at", "id") - 1 AS position
    FROM "sale_items"
)
UPDATE "sale_items" SET "sort_order" = ordered.position
FROM ordered WHERE ordered."id" = "sale_items"."id";

-- CreateTable
--
-- `deleted_at_ms` is epoch millis in a BIGINT rather than a timestamp, and
-- that is not a stylistic choice. This row is written by a trigger and read by
-- Prisma, and the two do not agree about what a `timestamptz` means on a
-- connection whose session timezone is not UTC: Prisma reads the stored
-- wall-clock digits as UTC, so a value the database generated comes back
-- shifted by the session offset. An integer has no such reading. It also has
-- to be directly comparable with a live row's `updated_at`, since a pull
-- merges the two streams into one ordering.
CREATE TABLE "sync_tombstones" (
    "entity" VARCHAR(40) NOT NULL,
    "entity_id" UUID NOT NULL,
    "device_id" VARCHAR(64),
    "sync_updated_at" BIGINT NOT NULL DEFAULT 0,
    "deleted_at_ms" BIGINT NOT NULL DEFAULT 0,

    CONSTRAINT "sync_tombstones_pkey" PRIMARY KEY ("entity","entity_id")
);

-- CreateIndex
CREATE INDEX "sync_tombstones_entity_deleted_at_ms_entity_id_idx" ON "sync_tombstones"("entity", "deleted_at_ms", "entity_id");

-- The pull cursor is a keyset over (updated_at, id) - the server's own clock,
-- not the client's, so one device with a wrong date cannot push the cursor
-- into the future and strand every row written after it.
CREATE INDEX "fiscal_years_updated_at_id_idx" ON "fiscal_years"("updated_at", "id");
CREATE INDEX "suppliers_updated_at_id_idx" ON "suppliers"("updated_at", "id");
CREATE INDEX "customers_updated_at_id_idx" ON "customers"("updated_at", "id");
CREATE INDEX "purchases_updated_at_id_idx" ON "purchases"("updated_at", "id");
CREATE INDEX "supplier_payments_updated_at_id_idx" ON "supplier_payments"("updated_at", "id");
CREATE INDEX "sales_updated_at_id_idx" ON "sales"("updated_at", "id");

-- ---------------------------------------------------------------------------
-- Triggers. Deliberately in the database rather than in the services: the web
-- API, the seed script and a hand-run UPDATE all have to leave a synced table
-- in a state the phone can reconcile with, and only the database sees all of
-- them.
-- ---------------------------------------------------------------------------

-- Stamps the merge clock. A writer that supplies its own value keeps it - that
-- is the sync endpoint relaying the client's timestamp - and everyone else
-- gets server time, which is what makes an edit from the web app visible to
-- the phone as a newer version.
CREATE OR REPLACE FUNCTION sync_stamp_updated_at() RETURNS trigger AS $fn$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW."sync_updated_at" IS NULL OR NEW."sync_updated_at" = 0 THEN
            NEW."sync_updated_at" := (EXTRACT(epoch FROM clock_timestamp()) * 1000)::bigint;
        END IF;
    ELSIF NEW."sync_updated_at" IS NOT DISTINCT FROM OLD."sync_updated_at" THEN
        NEW."sync_updated_at" := (EXTRACT(epoch FROM clock_timestamp()) * 1000)::bigint;
    END IF;
    RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

-- Records the tombstone a client needs in order to learn about a deletion it
-- was offline for. Fires on every delete, the cascade from a sale included.
CREATE OR REPLACE FUNCTION sync_record_tombstone() RETURNS trigger AS $fn$
BEGIN
    INSERT INTO "sync_tombstones" ("entity", "entity_id", "device_id", "sync_updated_at", "deleted_at_ms")
    VALUES (
        TG_ARGV[0],
        OLD."id",
        OLD."device_id",
        (EXTRACT(epoch FROM clock_timestamp()) * 1000)::bigint,
        (EXTRACT(epoch FROM clock_timestamp()) * 1000)::bigint
    )
    ON CONFLICT ("entity", "entity_id") DO UPDATE SET
        "device_id" = EXCLUDED."device_id",
        "sync_updated_at" = EXCLUDED."sync_updated_at",
        "deleted_at_ms" = EXCLUDED."deleted_at_ms";
    RETURN OLD;
END;
$fn$ LANGUAGE plpgsql;

-- A row created again after being deleted is a legitimate outcome of two
-- devices working offline, so the tombstone steps aside rather than shadowing
-- the new row forever.
CREATE OR REPLACE FUNCTION sync_clear_tombstone() RETURNS trigger AS $fn$
BEGIN
    DELETE FROM "sync_tombstones" WHERE "entity" = TG_ARGV[0] AND "entity_id" = NEW."id";
    RETURN NEW;
END;
$fn$ LANGUAGE plpgsql;

CREATE TRIGGER "fiscal_years_sync_stamp" BEFORE INSERT OR UPDATE ON "fiscal_years"
    FOR EACH ROW EXECUTE FUNCTION sync_stamp_updated_at();
CREATE TRIGGER "suppliers_sync_stamp" BEFORE INSERT OR UPDATE ON "suppliers"
    FOR EACH ROW EXECUTE FUNCTION sync_stamp_updated_at();
CREATE TRIGGER "customers_sync_stamp" BEFORE INSERT OR UPDATE ON "customers"
    FOR EACH ROW EXECUTE FUNCTION sync_stamp_updated_at();
CREATE TRIGGER "purchases_sync_stamp" BEFORE INSERT OR UPDATE ON "purchases"
    FOR EACH ROW EXECUTE FUNCTION sync_stamp_updated_at();
CREATE TRIGGER "supplier_payments_sync_stamp" BEFORE INSERT OR UPDATE ON "supplier_payments"
    FOR EACH ROW EXECUTE FUNCTION sync_stamp_updated_at();
CREATE TRIGGER "sales_sync_stamp" BEFORE INSERT OR UPDATE ON "sales"
    FOR EACH ROW EXECUTE FUNCTION sync_stamp_updated_at();

CREATE TRIGGER "fiscal_years_sync_tombstone" AFTER DELETE ON "fiscal_years"
    FOR EACH ROW EXECUTE FUNCTION sync_record_tombstone('fiscal_years');
CREATE TRIGGER "suppliers_sync_tombstone" AFTER DELETE ON "suppliers"
    FOR EACH ROW EXECUTE FUNCTION sync_record_tombstone('suppliers');
CREATE TRIGGER "customers_sync_tombstone" AFTER DELETE ON "customers"
    FOR EACH ROW EXECUTE FUNCTION sync_record_tombstone('customers');
CREATE TRIGGER "purchases_sync_tombstone" AFTER DELETE ON "purchases"
    FOR EACH ROW EXECUTE FUNCTION sync_record_tombstone('purchases');
CREATE TRIGGER "supplier_payments_sync_tombstone" AFTER DELETE ON "supplier_payments"
    FOR EACH ROW EXECUTE FUNCTION sync_record_tombstone('supplier_payments');
CREATE TRIGGER "sales_sync_tombstone" AFTER DELETE ON "sales"
    FOR EACH ROW EXECUTE FUNCTION sync_record_tombstone('sales');

CREATE TRIGGER "fiscal_years_sync_untombstone" AFTER INSERT ON "fiscal_years"
    FOR EACH ROW EXECUTE FUNCTION sync_clear_tombstone('fiscal_years');
CREATE TRIGGER "suppliers_sync_untombstone" AFTER INSERT ON "suppliers"
    FOR EACH ROW EXECUTE FUNCTION sync_clear_tombstone('suppliers');
CREATE TRIGGER "customers_sync_untombstone" AFTER INSERT ON "customers"
    FOR EACH ROW EXECUTE FUNCTION sync_clear_tombstone('customers');
CREATE TRIGGER "purchases_sync_untombstone" AFTER INSERT ON "purchases"
    FOR EACH ROW EXECUTE FUNCTION sync_clear_tombstone('purchases');
CREATE TRIGGER "supplier_payments_sync_untombstone" AFTER INSERT ON "supplier_payments"
    FOR EACH ROW EXECUTE FUNCTION sync_clear_tombstone('supplier_payments');
CREATE TRIGGER "sales_sync_untombstone" AFTER INSERT ON "sales"
    FOR EACH ROW EXECUTE FUNCTION sync_clear_tombstone('sales');
