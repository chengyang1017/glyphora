-- CreateTable
CREATE TABLE "user_localized_names" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "languageCode" VARCHAR(32) NOT NULL,
    "scriptCode" VARCHAR(32) NOT NULL DEFAULT '',
    "name" VARCHAR(100) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_localized_names_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "user_localized_names_userId_idx" ON "user_localized_names"("userId");

-- CreateIndex
CREATE INDEX "user_localized_names_languageCode_scriptCode_idx" ON "user_localized_names"("languageCode", "scriptCode");

-- CreateIndex
CREATE UNIQUE INDEX "user_localized_names_userId_languageCode_scriptCode_key" ON "user_localized_names"("userId", "languageCode", "scriptCode");

-- AddForeignKey
ALTER TABLE "user_localized_names" ADD CONSTRAINT "user_localized_names_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
