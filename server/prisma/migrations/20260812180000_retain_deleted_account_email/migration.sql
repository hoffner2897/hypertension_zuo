ALTER TABLE "users"
ADD COLUMN "research_email" TEXT;

COMMENT ON COLUMN "users"."research_email" IS
'Original normalized email retained for approved research after account deletion. The active login email is anonymized so the address can register again.';
