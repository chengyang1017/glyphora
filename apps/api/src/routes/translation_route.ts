import { Router } from "express";
import { z } from "zod";

import { prisma } from "../lib/prisma.js";

import { requireAuth } from "../middleware/require_auth.js";

import { translatePostWithAi } from "../services/post_translation_service.js";

import { translateProfileTagsWithAi } from "../services/profile_tag_translation_service.js";

export const translationRouter = Router();

// ============================================================
// 通用输入
// ============================================================

const optionalText = z.preprocess(
  (value) => (typeof value === "string" ? value : ""),
  z.string().trim(),
);

const requiredText = z.preprocess(
  (value) => (typeof value === "string" ? value : ""),
  z.string().trim().min(1),
);

// ============================================================
// 帖子翻译 Schema
// ============================================================

const translatePostSchema = z.object({
  title: optionalText,

  content: requiredText,

  sourceLanguageCode: optionalText,

  targetLanguageCode: requiredText,

  targetLanguageName: optionalText,
});

// ============================================================
// 个人标签翻译 Schema
//
// 不再让客户端传 tags / bio。
// 服务端直接从 PostgreSQL 获取目标用户最新资料。
// ============================================================

const translateProfileTagsSchema = z.object({
  // Flutter UserModel.id
  // 当前对应 Firebase UID
  profileUserId: requiredText,

  targetLanguageCode: requiredText,

  targetLanguageName: optionalText,
});

// ============================================================
// BCP-47-ish language tag 解析
//
// zh-Hans →
// languageCode = zh
// scriptCode   = Hans
//
// vi-Hani →
// languageCode = vi
// scriptCode   = Hani
//
// en →
// languageCode = en
// scriptCode   = ''
// ============================================================

function parseLanguageTag(value: string): {
  languageCode: string;
  scriptCode: string;
} {
  const parts = value.trim().split("-").filter(Boolean);

  const languageCode = parts[0]?.toLowerCase() ?? "";

  const rawScript = parts.find(
    (part, index) => index > 0 && /^[A-Za-z]{4}$/.test(part),
  );

  const scriptCode = rawScript
    ? rawScript[0]!.toUpperCase() + rawScript.slice(1).toLowerCase()
    : "";

  return {
    languageCode,
    scriptCode,
  };
}

// ============================================================
// 查找标签作者自己提供的翻译
//
// 优先级：
// 1. language + script 精确匹配
// 2. 同语言、script 为空
// 3. 该语言只有唯一一个翻译
// 4. 没有 → null → 后面可交给 AI
// ============================================================

function authorTranslationFor(
  translations: Array<{
    languageCode: string;
    scriptCode: string;
    value: string;
  }>,
  targetLanguageCode: string,
  targetScriptCode: string,
): string | null {
  const targetLanguage = targetLanguageCode.trim().toLowerCase();

  const targetScript = targetScriptCode.trim().toLowerCase();

  // ----------------------------------------------------------
  // 1. language + script 精确匹配
  // ----------------------------------------------------------

  if (targetScript.length > 0) {
    const exact = translations.find(
      (translation) =>
        translation.languageCode.trim().toLowerCase() === targetLanguage &&
        translation.scriptCode.trim().toLowerCase() === targetScript,
    );

    if (exact != null && exact.value.trim().length > 0) {
      return exact.value.trim();
    }
  }

  // ----------------------------------------------------------
  // 2. 同语言，无 script
  // ----------------------------------------------------------

  const noScript = translations.find(
    (translation) =>
      translation.languageCode.trim().toLowerCase() === targetLanguage &&
      translation.scriptCode.trim().length === 0,
  );

  if (noScript != null && noScript.value.trim().length > 0) {
    return noScript.value.trim();
  }

  // ----------------------------------------------------------
  // 3. 同语言只有一个翻译
  // ----------------------------------------------------------

  const sameLanguage = translations.filter(
    (translation) =>
      translation.languageCode.trim().toLowerCase() === targetLanguage,
  );

  if (sameLanguage.length === 1) {
    const value = sameLanguage[0]!.value.trim();

    if (value.length > 0) {
      return value;
    }
  }

  return null;
}

// ============================================================
// POST /api/v1/translations/posts
//
// 翻译帖子内容。
// 必须登录。
// ============================================================

translationRouter.post("/posts", requireAuth, async (request, response) => {
  const parsed = translatePostSchema.safeParse(request.body);

  if (!parsed.success) {
    response.status(400).json({
      error: "INVALID_REQUEST",

      message: "Translation parameters are incomplete",

      details: parsed.error.flatten(),
    });

    return;
  }

  try {
    const translated = await translatePostWithAi(parsed.data);

    response.status(200).json(translated);
  } catch (error) {
    console.error("Translate post failed:", error);

    response.status(500).json({
      error: "TRANSLATION_FAILED",

      message: "Unable to translate post",
    });
  }
});

// ============================================================
// POST /api/v1/translations/profile-tags
//
// 观看者主动要求翻译某个用户的标签。
//
// 流程：
//
// 1. 服务端读取目标用户最新资料
// 2. 查 PostgreSQL 永久缓存
// 3. 有缓存 → 直接返回，0 AI
// 4. 没缓存 → 作者自己的翻译优先
// 5. 作者没有提供的标签才交给 AI
// 6. 整组结果写进 PostgreSQL cache
//
// User 资料发生修改时，
// user_route.ts 会删除该用户全部标签 AI cache。
// ============================================================

translationRouter.post(
  "/profile-tags",
  requireAuth,
  async (request, response) => {
    const parsed = translateProfileTagsSchema.safeParse(request.body);

    if (!parsed.success) {
      response.status(400).json({
        error: "INVALID_REQUEST",

        message: "Profile tag translation parameters are incomplete",

        details: parsed.error.flatten(),
      });

      return;
    }

    const { languageCode, scriptCode } = parseLanguageTag(
      parsed.data.targetLanguageCode,
    );

    if (languageCode.length === 0) {
      response.status(400).json({
        error: "INVALID_TARGET_LANGUAGE",

        message: "Invalid target language",
      });

      return;
    }

    try {
      // ======================================================
      // 1. 从 PostgreSQL 获取目标用户真正的最新资料
      // ======================================================

      const profile = await prisma.user.findUnique({
        where: {
          firebaseUid: parsed.data.profileUserId,
        },

        select: {
          id: true,
          username: true,
          nickname: true,
          bio: true,

          tags: {
            orderBy: {
              createdAt: "asc",
            },

            include: {
              translations: true,
            },
          },
        },
      });

      if (profile == null) {
        response.status(404).json({
          error: "USER_NOT_FOUND",

          message: "Profile user does not exist",
        });

        return;
      }

      // ======================================================
      // 没有标签
      //
      // 不需要 AI，也不需要创建无意义缓存。
      // ======================================================

      if (profile.tags.length === 0) {
        response.status(200).json({
          translations: [],
          cached: false,
        });

        return;
      }

      // ======================================================
      // 2. 查询 PostgreSQL 永久缓存
      // ======================================================

      const cached = await prisma.userTagAiTranslationCache.findUnique({
        where: {
          userId_languageCode_scriptCode: {
            userId: profile.id,

            languageCode,

            scriptCode,
          },
        },
      });

      if (cached != null && Array.isArray(cached.translations)) {
        response.status(200).json({
          translations: cached.translations,

          cached: true,
        });

        return;
      }

      // ======================================================
      // 3. 作者自己提供的翻译优先
      // ======================================================

      const finalTranslations = new Map<string, string>();

      const needsAi: string[] = [];

      for (const tag of profile.tags) {
        const authorTranslation = authorTranslationFor(
          tag.translations,
          languageCode,
          scriptCode,
        );

        if (authorTranslation != null && authorTranslation.length > 0) {
          finalTranslations.set(tag.value, authorTranslation);

          continue;
        }

        // 作者没有该语言翻译
        // 才交给 AI
        needsAi.push(tag.value);
      }

      // ======================================================
      // 4. 只有缺少作者翻译的标签才调用 AI
      // ======================================================

      if (needsAi.length > 0) {
        // 服务端自己生成上下文。
        //
        // 客户端不再传 profileContext，
        // 避免使用过期或伪造资料。
        const profileContext = [
          profile.username.trim().length > 0
            ? `Username: ${profile.username.trim()}`
            : "",

          profile.nickname?.trim()
            ? `Nickname: ${profile.nickname.trim()}`
            : "",

          profile.bio?.trim() ? `Bio: ${profile.bio.trim()}` : "",
        ]
          .filter((value) => value.length > 0)
          .join("\n");

        const aiResult = await translateProfileTagsWithAi({
          tags: needsAi,

          targetLanguageCode: parsed.data.targetLanguageCode,

          targetLanguageName: parsed.data.targetLanguageName,

          profileContext,
        });

        for (const item of aiResult.translations) {
          const original = item.original.trim();

          const translated = item.translated.trim();

          if (original.length === 0) {
            continue;
          }

          finalTranslations.set(
            original,
            translated.length > 0 ? translated : original,
          );
        }
      }

      // ======================================================
      // 5. 恢复数据库原标签顺序
      // ======================================================

      const translations = profile.tags.map((tag) => {
        const translated = finalTranslations.get(tag.value);

        return {
          original: tag.value,

          translated: translated?.trim().length ? translated.trim() : tag.value,
        };
      });

      // ======================================================
      // 6. 永久写入 PostgreSQL Cache
      //
      // 一个用户 + 一个目标语言/文字系统
      // 只有一份整组标签缓存。
      // ======================================================

      await prisma.userTagAiTranslationCache.upsert({
        where: {
          userId_languageCode_scriptCode: {
            userId: profile.id,

            languageCode,

            scriptCode,
          },
        },

        update: {
          translations,
        },

        create: {
          userId: profile.id,

          languageCode,

          scriptCode,

          translations,
        },
      });

      // ======================================================
      // 7. 返回
      //
      // cached=false 表示这次是新生成的。
      // ======================================================

      response.status(200).json({
        translations,
        cached: false,
      });
    } catch (error) {
      console.error("Translate profile tags failed:", error);

      response.status(500).json({
        error: "PROFILE_TAG_TRANSLATION_FAILED",

        message: "Unable to translate profile tags",
      });
    }
  },
);
