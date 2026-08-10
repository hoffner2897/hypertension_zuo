-- Account deletion is implemented as an irreversible, anonymized deactivation.
-- Research records keep their existing pseudonymous user_id and are not cascaded.
ALTER TABLE "users" ADD COLUMN "deleted_at" TIMESTAMPTZ(3);

CREATE INDEX "users_deleted_at_idx" ON "users"("deleted_at");
