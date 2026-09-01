-- Shop identity moves out of the SHOP_* environment variables and onto the
-- user, so it can be edited from the app instead of by a redeploy.
-- Nullable, with no backfill: the values that were in .env belong to that
-- deployment, not to this schema, and the app prompts for them once.

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "shop_address" VARCHAR(255),
ADD COLUMN     "shop_name" VARCHAR(180),
ADD COLUMN     "shop_pan" VARCHAR(30),
ADD COLUMN     "shop_phone" VARCHAR(30);
