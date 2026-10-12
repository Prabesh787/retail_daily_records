-- Lets the shopkeeper pin the suppliers they deal with most above the rest.
-- Defaults to false, so every existing supplier starts unpinned.

-- AlterTable
ALTER TABLE "suppliers" ADD COLUMN     "is_top" BOOLEAN NOT NULL DEFAULT false;
