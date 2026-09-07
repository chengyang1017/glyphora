import express from "express";
import request from "supertest";

import { beforeEach, describe, expect, it, vi } from "vitest";

// ============================================================
// Hoisted mocks
// ============================================================

const mocks = vi.hoisted(() => ({
  verifyIdToken: vi.fn(),

  translatePostWithAi: vi.fn(),

  translateProfileTagsWithAi: vi.fn(),

  prisma: {
    user: {
      findUnique: vi.fn(),
    },

    userTagAiTranslationCache: {
      findUnique: vi.fn(),

      upsert: vi.fn(),
    },
  },
}));

// ============================================================
// Firebase Auth mock
// ============================================================

vi.mock("../src/lib/firebase_admin.js", () => ({
  firebaseAuth: {
    verifyIdToken: mocks.verifyIdToken,
  },
}));

// ============================================================
// Prisma mock
//
// 非常重要：
// translation_route.ts 现在 import prisma。
// 测试环境不能加载真实 prisma.ts，
// 否则会要求 DATABASE_URL。
// ============================================================

vi.mock("../src/lib/prisma.js", () => ({
  prisma: mocks.prisma,
}));

// ============================================================
// Post translation mock
// ============================================================

vi.mock("../src/services/post_translation_service.js", () => ({
  translatePostWithAi: mocks.translatePostWithAi,
}));

// ============================================================
// Profile tag translation mock
// ============================================================

vi.mock("../src/services/profile_tag_translation_service.js", () => ({
  translateProfileTagsWithAi: mocks.translateProfileTagsWithAi,
}));

// 必须放在 vi.mock 后面
import { translationRouter } from "../src/routes/translation_route.js";

// ============================================================
// Test app
// ============================================================

function createTestApp() {
  const app = express();

  app.use(express.json());

  app.use("/api/v1/translations", translationRouter);

  return app;
}

// ============================================================
// Tests
// ============================================================

describe("translation routes", () => {
  beforeEach(() => {
    vi.clearAllMocks();

    // --------------------------------------------------------
    // 默认：登录成功
    // --------------------------------------------------------

    mocks.verifyIdToken.mockResolvedValue({
      uid: "firebase-viewer",
      email: "viewer@example.com",
    });

    // --------------------------------------------------------
    // 默认：帖子翻译成功
    // --------------------------------------------------------

    mocks.translatePostWithAi.mockResolvedValue({
      title: "Xin chào",

      content: "Nội dung đã dịch",
    });

    // --------------------------------------------------------
    // 默认：没有标签 AI cache
    // --------------------------------------------------------

    mocks.prisma.userTagAiTranslationCache.findUnique.mockResolvedValue(null);

    mocks.prisma.userTagAiTranslationCache.upsert.mockResolvedValue({
      id: "cache-1",
    });

    // --------------------------------------------------------
    // 默认 AI 标签翻译
    // --------------------------------------------------------

    mocks.translateProfileTagsWithAi.mockResolvedValue({
      translations: [
        {
          original: "Башҡорт теле",

          translated: "巴什基尔语",
        },
      ],
    });
  });

  // ========================================================
  // POST /posts
  // ========================================================

  it("rejects unauthenticated requests", async () => {
    const response = await request(createTestApp())
      .post("/api/v1/translations/posts")
      .send({
        content: "Hello",

        targetLanguageCode: "vi",
      });

    expect(response.status).toBe(401);

    expect(response.body.error).toBe("UNAUTHORIZED");
  });

  it("rejects incomplete post translation input", async () => {
    const response = await request(createTestApp())
      .post("/api/v1/translations/posts")
      .set("Authorization", "Bearer valid-token")
      .send({
        title: "Hello",
      });

    expect(response.status).toBe(400);

    expect(response.body.error).toBe("INVALID_REQUEST");
  });

  it("returns translated post data", async () => {
    const response = await request(createTestApp())
      .post("/api/v1/translations/posts")
      .set("Authorization", "Bearer valid-token")
      .send({
        title: " Hello ",

        content: " World ",

        sourceLanguageCode: " en ",

        targetLanguageCode: " vi ",

        targetLanguageName: " Vietnamese ",
      });

    expect(response.status).toBe(200);

    expect(response.body).toEqual({
      title: "Xin chào",

      content: "Nội dung đã dịch",
    });

    expect(mocks.translatePostWithAi).toHaveBeenCalledWith({
      title: "Hello",

      content: "World",

      sourceLanguageCode: "en",

      targetLanguageCode: "vi",

      targetLanguageName: "Vietnamese",
    });
  });

  it("returns 500 when post translation fails", async () => {
    mocks.translatePostWithAi.mockRejectedValue(new Error("OpenAI failure"));

    const response = await request(createTestApp())
      .post("/api/v1/translations/posts")
      .set("Authorization", "Bearer valid-token")
      .send({
        content: "Hello",

        targetLanguageCode: "vi",
      });

    expect(response.status).toBe(500);

    expect(response.body.error).toBe("TRANSLATION_FAILED");
  });

  // ========================================================
  // POST /profile-tags
  // ========================================================

  it("rejects incomplete profile tag translation input", async () => {
    const response = await request(createTestApp())
      .post("/api/v1/translations/profile-tags")
      .set("Authorization", "Bearer valid-token")
      .send({
        targetLanguageCode: "zh-Hans",
      });

    expect(response.status).toBe(400);

    expect(response.body.error).toBe("INVALID_REQUEST");
  });

  it("returns 404 when profile user does not exist", async () => {
    mocks.prisma.user.findUnique.mockResolvedValue(null);

    const response = await request(createTestApp())
      .post("/api/v1/translations/profile-tags")
      .set("Authorization", "Bearer valid-token")
      .send({
        profileUserId: "missing-user",

        targetLanguageCode: "zh-Hans",

        targetLanguageName: "Chinese",
      });

    expect(response.status).toBe(404);

    expect(response.body.error).toBe("USER_NOT_FOUND");
  });

  it("returns empty translations when profile has no tags", async () => {
    mocks.prisma.user.findUnique.mockResolvedValue({
      id: "user-db-1",

      username: "alice",

      nickname: null,

      bio: null,

      tags: [],
    });

    const response = await request(createTestApp())
      .post("/api/v1/translations/profile-tags")
      .set("Authorization", "Bearer valid-token")
      .send({
        profileUserId: "firebase-alice",

        targetLanguageCode: "zh-Hans",

        targetLanguageName: "Chinese",
      });

    expect(response.status).toBe(200);

    expect(response.body).toEqual({
      translations: [],
      cached: false,
    });

    expect(mocks.translateProfileTagsWithAi).not.toHaveBeenCalled();

    expect(
      mocks.prisma.userTagAiTranslationCache.upsert,
    ).not.toHaveBeenCalled();
  });

  it("returns cached profile tag translations without calling AI", async () => {
    mocks.prisma.user.findUnique.mockResolvedValue({
      id: "user-db-1",

      username: "alice",

      nickname: "Alice",

      bio: "Language lover",

      tags: [
        {
          id: "tag-1",

          value: "Башҡорт теле",

          languageCode: "ba",

          scriptCode: "Cyrl",

          createdAt: new Date(),

          translations: [],
        },
      ],
    });

    mocks.prisma.userTagAiTranslationCache.findUnique.mockResolvedValue({
      id: "cache-1",

      userId: "user-db-1",

      languageCode: "zh",

      scriptCode: "Hans",

      translations: [
        {
          original: "Башҡорт теле",

          translated: "巴什基尔语",
        },
      ],
    });

    const response = await request(createTestApp())
      .post("/api/v1/translations/profile-tags")
      .set("Authorization", "Bearer valid-token")
      .send({
        profileUserId: "firebase-alice",

        targetLanguageCode: "zh-Hans",

        targetLanguageName: "Chinese",
      });

    expect(response.status).toBe(200);

    expect(response.body).toEqual({
      translations: [
        {
          original: "Башҡорт теле",

          translated: "巴什基尔语",
        },
      ],

      cached: true,
    });

    expect(mocks.translateProfileTagsWithAi).not.toHaveBeenCalled();

    expect(
      mocks.prisma.userTagAiTranslationCache.upsert,
    ).not.toHaveBeenCalled();
  });

  it("uses author translation without spending AI quota", async () => {
    mocks.prisma.user.findUnique.mockResolvedValue({
      id: "user-db-1",

      username: "alice",

      nickname: "Alice",

      bio: "Language lover",

      tags: [
        {
          id: "tag-1",

          value: "Башҡорт теле",

          languageCode: "ba",

          scriptCode: "Cyrl",

          createdAt: new Date(),

          translations: [
            {
              languageCode: "zh",

              scriptCode: "Hans",

              value: "巴什基尔语",
            },
          ],
        },
      ],
    });

    const response = await request(createTestApp())
      .post("/api/v1/translations/profile-tags")
      .set("Authorization", "Bearer valid-token")
      .send({
        profileUserId: "firebase-alice",

        targetLanguageCode: "zh-Hans",

        targetLanguageName: "Chinese",
      });

    expect(response.status).toBe(200);

    expect(response.body).toEqual({
      translations: [
        {
          original: "Башҡорт теле",

          translated: "巴什基尔语",
        },
      ],

      cached: false,
    });

    expect(mocks.translateProfileTagsWithAi).not.toHaveBeenCalled();

    expect(mocks.prisma.userTagAiTranslationCache.upsert).toHaveBeenCalledTimes(
      1,
    );
  });

  it("calls AI only for tags without author translations and stores cache", async () => {
    mocks.prisma.user.findUnique.mockResolvedValue({
      id: "user-db-1",

      username: "alice",

      nickname: "Alice",

      bio: "Programming and languages",

      tags: [
        {
          id: "tag-1",

          value: "Башҡорт теле",

          languageCode: "ba",

          scriptCode: "Cyrl",

          createdAt: new Date(),

          translations: [],
        },

        {
          id: "tag-2",

          value: "Rust",

          languageCode: "en",

          scriptCode: "Latn",

          createdAt: new Date(),

          translations: [
            {
              languageCode: "zh",

              scriptCode: "Hans",

              value: "Rust",
            },
          ],
        },
      ],
    });

    mocks.translateProfileTagsWithAi.mockResolvedValue({
      translations: [
        {
          original: "Башҡорт теле",

          translated: "巴什基尔语",
        },
      ],
    });

    const response = await request(createTestApp())
      .post("/api/v1/translations/profile-tags")
      .set("Authorization", "Bearer valid-token")
      .send({
        profileUserId: "firebase-alice",

        targetLanguageCode: "zh-Hans",

        targetLanguageName: "Chinese",
      });

    expect(response.status).toBe(200);

    expect(response.body).toEqual({
      translations: [
        {
          original: "Башҡорт теле",

          translated: "巴什基尔语",
        },

        {
          original: "Rust",

          translated: "Rust",
        },
      ],

      cached: false,
    });

    // 只把没有作者翻译的标签发给 AI
    expect(mocks.translateProfileTagsWithAi).toHaveBeenCalledWith({
      tags: ["Башҡорт теле"],

      targetLanguageCode: "zh-Hans",

      targetLanguageName: "Chinese",

      profileContext: [
        "Username: alice",
        "Nickname: Alice",
        "Bio: Programming and languages",
      ].join("\n"),
    });

    // AI 结果必须永久缓存
    expect(mocks.prisma.userTagAiTranslationCache.upsert).toHaveBeenCalledTimes(
      1,
    );

    expect(mocks.prisma.userTagAiTranslationCache.upsert).toHaveBeenCalledWith({
      where: {
        userId_languageCode_scriptCode: {
          userId: "user-db-1",

          languageCode: "zh",

          scriptCode: "Hans",
        },
      },

      update: {
        translations: [
          {
            original: "Башҡорт теле",

            translated: "巴什基尔语",
          },

          {
            original: "Rust",

            translated: "Rust",
          },
        ],
      },

      create: {
        userId: "user-db-1",

        languageCode: "zh",

        scriptCode: "Hans",

        translations: [
          {
            original: "Башҡорт теле",

            translated: "巴什基尔语",
          },

          {
            original: "Rust",

            translated: "Rust",
          },
        ],
      },
    });
  });

  it("returns 500 when profile tag AI translation fails", async () => {
    mocks.prisma.user.findUnique.mockResolvedValue({
      id: "user-db-1",

      username: "alice",

      nickname: null,

      bio: null,

      tags: [
        {
          id: "tag-1",

          value: "Башҡорт теле",

          languageCode: "ba",

          scriptCode: "Cyrl",

          createdAt: new Date(),

          translations: [],
        },
      ],
    });

    mocks.translateProfileTagsWithAi.mockRejectedValue(
      new Error("OpenAI failure"),
    );

    const response = await request(createTestApp())
      .post("/api/v1/translations/profile-tags")
      .set("Authorization", "Bearer valid-token")
      .send({
        profileUserId: "firebase-alice",

        targetLanguageCode: "zh-Hans",

        targetLanguageName: "Chinese",
      });

    expect(response.status).toBe(500);

    expect(response.body.error).toBe("PROFILE_TAG_TRANSLATION_FAILED");

    expect(
      mocks.prisma.userTagAiTranslationCache.upsert,
    ).not.toHaveBeenCalled();
  });
});
