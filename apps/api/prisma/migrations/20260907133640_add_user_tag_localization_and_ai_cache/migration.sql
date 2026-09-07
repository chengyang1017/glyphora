-- AlterTable
ALTER TABLE "user_tags" ADD COLUMN     "languageCode" VARCHAR(32) NOT NULL DEFAULT '',
ADD COLUMN     "scriptCode" VARCHAR(32) NOT NULL DEFAULT '',
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- CreateTable
CREATE TABLE "user_tag_translations" (
    "id" UUID NOT NULL,
    "tagId" UUID NOT NULL,
    "languageCode" VARCHAR(32) NOT NULL,
    "scriptCode" VARCHAR(32) NOT NULL DEFAULT '',
    "value" VARCHAR(50) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_tag_translations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_tag_ai_translation_cache" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "languageCode" VARCHAR(32) NOT NULL,
    "scriptCode" VARCHAR(32) NOT NULL DEFAULT '',
    "translations" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_tag_ai_translation_cache_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "user_tag_translations_tagId_idx" ON "user_tag_translations"("tagId");

-- CreateIndex
CREATE INDEX "user_tag_translations_languageCode_scriptCode_idx" ON "user_tag_translations"("languageCode", "scriptCode");

-- CreateIndex
CREATE UNIQUE INDEX "user_tag_translations_tagId_languageCode_scriptCode_key" ON "user_tag_translations"("tagId", "languageCode", "scriptCode");

-- CreateIndex
CREATE INDEX "user_tag_ai_translation_cache_userId_idx" ON "user_tag_ai_translation_cache"("userId");

-- CreateIndex
CREATE INDEX "user_tag_ai_translation_cache_languageCode_scriptCode_idx" ON "user_tag_ai_translation_cache"("languageCode", "scriptCode");

-- CreateIndex
CREATE UNIQUE INDEX "user_tag_ai_translation_cache_userId_languageCode_scriptCod_key" ON "user_tag_ai_translation_cache"("userId", "languageCode", "scriptCode");

-- CreateIndex
CREATE INDEX "user_tags_userId_idx" ON "user_tags"("userId");

-- AddForeignKey
ALTER TABLE "user_tag_translations" ADD CONSTRAINT "user_tag_translations_tagId_fkey" FOREIGN KEY ("tagId") REFERENCES "user_tags"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_tag_ai_translation_cache" ADD CONSTRAINT "user_tag_ai_translation_cache_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
