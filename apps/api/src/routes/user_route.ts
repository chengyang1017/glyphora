import { Router } from 'express';
import { z } from 'zod';

import { prisma } from '../lib/prisma.js';
import { requireAuth } from '../middleware/require_auth.js';

export const userRouter = Router();

// ============================================================
// 类型
// ============================================================

type UserWithProfileRelations = {
  id: string;
  firebaseUid: string;

  username: string;
  email: string | null;

  nickname: string | null;
  avatarUrl: string | null;
  bio: string | null;

  birthday: Date | null;
  showAge: boolean;

  lastActiveAt: Date | null;
  createdAt: Date;

  tags: Array<{
    id: string;
    value: string;
    languageCode: string;
    scriptCode: string;

    translations: Array<{
      languageCode: string;
      scriptCode: string;
      value: string;
    }>;
  }>;

  languages: Array<{
    languageCode: string;
    scriptCode: string;
    level: number;
  }>;

  localizedNames: Array<{
    languageCode: string;
    scriptCode: string;
    name: string;
  }>;
};

// ============================================================
// Response 转换
//
// PostgreSQL 的字段结构
// ↓
// Flutter UserModel 能直接读取的结构
// ============================================================

function serializeUser(
  user: UserWithProfileRelations,
  options?: {
    includeBirthday?: boolean;
  },
) {
  const includeBirthday =
    options?.includeBirthday ?? true;

  return {
    databaseId: user.id,

    // Flutter 当前仍然使用 Firebase UID 作为 UserModel.id
    uid: user.firebaseUid,

    username: user.username,
    email: user.email,

    nickname: user.nickname,
    avatar: user.avatarUrl,
    bio: user.bio,

    birthday:
      includeBirthday && user.birthday != null
        ? user.birthday.toISOString()
        : null,

    showAge: user.showAge,

    createdAt: user.createdAt.toISOString(),

    lastActive:
      user.lastActiveAt?.toISOString() ?? null,

    tags: user.tags.map(
      (tag) => tag.value,
    ),

    tagDetails: user.tags.map(
      (tag) => ({
        id: tag.id,

        value: tag.value,

        languageCode:
          tag.languageCode,

        scriptCode:
          tag.scriptCode,

        translations:
          tag.translations.map(
            (translation) => ({
              languageCode:
                translation.languageCode,

              scriptCode:
                translation.scriptCode,

              value:
                translation.value,
            }),
          ),
      }),
    ),

    languages: user.languages.map(
      (language) => ({
        name: language.languageCode,

        ...(language.scriptCode.length > 0
          ? {
              scriptCode: language.scriptCode,
            }
          : {}),

        level: language.level,
      }),
    ),

    localizedNames: user.localizedNames.map(
      (localizedName) => ({
        languageCode: localizedName.languageCode,
        scriptCode: localizedName.scriptCode,
        name: localizedName.name,
      }),
    ),
  };
}

// ============================================================
// Prisma 错误 code
// ============================================================

function prismaErrorCode(
  error: unknown,
): string | null {
  if (
    typeof error !== 'object' ||
    error == null ||
    !('code' in error)
  ) {
    return null;
  }

  const code = (error as { code?: unknown }).code;

  return typeof code === 'string'
    ? code
    : null;
}

// ============================================================
// GET /api/v1/users/username-availability
//
// Registration happens before a Firebase session exists, so this endpoint is
// intentionally public. PostgreSQL is the authoritative username store.
// ============================================================

const usernameAvailabilitySchema = z.object({
  username: z
    .string()
    .trim()
    .min(1)
    .max(50),
});

userRouter.get(
  '/username-availability',
  async (request, response) => {
    const parsed = usernameAvailabilitySchema.safeParse(request.query);

    if (!parsed.success) {
      response.status(400).json({
        error: 'INVALID_USERNAME',
        message: 'Invalid username',
      });

      return;
    }

    try {
      const existingUser = await prisma.user.findUnique({
        where: {
          username: parsed.data.username,
        },
        select: {
          id: true,
        },
      });

      response.status(200).json({
        available: existingUser == null,
      });
    } catch (error) {
      console.error(
        'Check username availability failed:',
        error,
      );

      response.status(500).json({
        error: 'USERNAME_AVAILABILITY_FAILED',
        message: 'Unable to check username availability',
      });
    }
  },
);

// ============================================================
// PUT /api/v1/users/me
//
// 迁移阶段：
// Flutter 从旧 Firestore 用户同步到 PostgreSQL。
// 用户不存在 → create
// 用户已存在   → update
// ============================================================

const syncUserSchema = z.object({
  username: z
    .string()
    .trim()
    .min(1)
    .max(50),

  nickname: z
    .string()
    .trim()
    .max(100)
    .nullable()
    .optional(),

  avatarUrl: z
    .string()
    .trim()
    .url()
    .nullable()
    .optional(),

  bio: z
    .string()
    .max(5000)
    .nullable()
    .optional(),

  showAge: z
    .boolean()
    .optional(),
});

userRouter.put(
  '/me',
  requireAuth,
  async (request, response) => {
    //拿 request.body 去按照刚才那个 syncUserSchema 做校验。
    const parsed = syncUserSchema.safeParse(request.body);

    if (!parsed.success) {
      response.status(400).json({
        error: 'INVALID_REQUEST',
        message: 'Invalid user data',
      });

      return;
    }

    const auth = response.locals.auth;

    try {
      const user = await prisma.user.upsert({
        where: {
          firebaseUid: auth.firebaseUid,
        },

        update: {
          email: auth.email,

          username:
            parsed.data.username,

          nickname:
            parsed.data.nickname,

          avatarUrl:
            parsed.data.avatarUrl,

          bio:
            parsed.data.bio,

          showAge:
            parsed.data.showAge,
        },

        create: {
          firebaseUid:
            auth.firebaseUid,

          email:
            auth.email,

          username:
            parsed.data.username,

          nickname:
            parsed.data.nickname,

          avatarUrl:
            parsed.data.avatarUrl,

          bio:
            parsed.data.bio,

          showAge:
            parsed.data.showAge ?? true,
        },

        include: {
          tags: {
            include: {
              translations: true,
            },
          },
          languages: true,
          localizedNames: true,
        },
      });

      response.status(200).json({
        user: serializeUser(user),
      });
    } catch (error) {
      console.error(
        'Sync user failed:',
        error,
      );

      const code =
        prismaErrorCode(error);

      if (code === 'P2002') {
        response.status(409).json({
          error: 'USER_CONFLICT',
          message:
            'Username or email already exists',
        });

        return;
      }

      response.status(500).json({
        error: 'SYNC_USER_FAILED',
        message:
          'Unable to sync user',
      });
    }
  },
);

// ============================================================
// GET /api/v1/users/me
//
// 获取当前登录用户。
// 现在从 PostgreSQL 读取。
// ============================================================

userRouter.get(
  '/me',
  requireAuth,
  async (_request, response) => {
    const auth = response.locals.auth;

    try {
      const user =
        await prisma.user.findUnique({
          where: {
            firebaseUid:
              auth.firebaseUid,
          },

          include: {
            tags: {
              include: {
                translations: true,
              },
            },
            languages: true,
            localizedNames: true,
          },
        });

      if (user == null) {
        response.status(404).json({
          error: 'USER_NOT_FOUND',
          message:
            'Backend user does not exist',
        });

        return;
      }

      response.status(200).json({
        user: serializeUser(user),
      });
    } catch (error) {
      console.error(
        'Get current user failed:',
        error,
      );

      response.status(500).json({
        error: 'GET_USER_FAILED',
        message:
          'Unable to load user',
      });
    }
  },
);

const userTagTranslationSchema =
  z.object({
    languageCode: z
      .string()
      .trim()
      .min(1)
      .max(32),

    scriptCode: z
      .string()
      .trim()
      .max(32)
      .optional()
      .default(''),

    value: z
      .string()
      .trim()
      .min(1)
      .max(50),
  });

const structuredUserTagSchema =
  z.object({
    value: z
      .string()
      .trim()
      .min(1)
      .max(50),

    languageCode: z
      .string()
      .trim()
      .max(32)
      .optional()
      .default(''),

    scriptCode: z
      .string()
      .trim()
      .max(32)
      .optional()
      .default(''),

    translations: z
      .array(
        userTagTranslationSchema,
      )
      .optional()
      .default([]),
  });

const userTagInputSchema =
  z.union([
    // 舊 Flutter：
    // ["Flutter", "Python"]
    z
      .string()
      .trim()
      .min(1)
      .max(50)
      .transform(
        (value) => ({
          value,
          languageCode: '',
          scriptCode: '',
          translations: [],
        }),
      ),

    // 新 Flutter：
    // [{ value, languageCode, ... }]
    structuredUserTagSchema,
  ]);

// ============================================================
// PATCH /api/v1/users/me
//
// 修改当前用户资料。
// username / nickname / bio / avatar / birthday
// tags / languages
// 全部写 PostgreSQL。
// ============================================================

const updateUserSchema = z.object({
  username: z
    .string()
    .trim()
    .min(1)
    .max(50)
    .optional(),

  nickname: z
    .string()
    .trim()
    .max(100)
    .nullable()
    .optional(),

  avatarUrl: z
    .string()
    .trim()
    .url()
    .nullable()
    .optional(),

  bio: z
    .string()
    .max(5000)
    .nullable()
    .optional(),

  birthday: z
    .coerce
    .date()
    .nullable()
    .optional(),

  showAge: z
    .boolean()
    .optional(),

  tags: z
  .array(userTagInputSchema)
  .max(10)
  .optional(),

  languages: z
  .array(
    z.object({
      name: z
        .string()
        .trim()
        .min(1)
        .max(32),

      scriptCode: z
        .string()
        .trim()
        .max(32)
        .optional(),

      level: z
        .number()
        .int()
        .min(0)
        .max(100),
    }),
  )
  .optional(),

localizedNames: z
  .array(
    z.object({
      languageCode: z
        .string()
        .trim()
        .min(1)
        .max(32),

      scriptCode: z
        .string()
        .trim()
        .max(32)
        .optional(),

      name: z
        .string()
        .trim()
        .min(1)
        .max(100),
    }),
  )
  .optional(),
});

localizedNames: z
  .array(
    z.object({
      languageCode: z
        .string()
        .trim()
        .min(1)
        .max(32),

      scriptCode: z
        .string()
        .trim()
        .max(32)
        .optional(),

      name: z
        .string()
        .trim()
        .min(1)
        .max(100),
    }),
  )
  .optional(),

userRouter.patch(
  '/me',
  requireAuth,
  async (request, response) => {
    const parsed =
      updateUserSchema.safeParse(request.body);

    if (!parsed.success) {
      response.status(400).json({
        error: 'INVALID_REQUEST',
        message: 'Invalid user data',
        details: parsed.error.flatten(),
      });

      return;
    }

    const auth = response.locals.auth;

    const {
      tags,
      languages,
      localizedNames,
      ...profileData
    } = parsed.data;

    try {
      const user =
        await prisma.$transaction(
          async (transaction) => {
            // --------------------------------------------
            // 1. 更新 users 主表
            // --------------------------------------------

            const currentUser =
              await transaction.user.update({
                where: {
                  firebaseUid:
                    auth.firebaseUid,
                },

                data: profileData,

                select: {
                  id: true,
                },
              });

            // --------------------------------------------
            // 2. 如果请求带 tags
            //    就完整替换当前用户 tags
            // --------------------------------------------

            if (tags !== undefined) {
            // 刪除原 tags。
            // UserTagTranslation 因為 onDelete: Cascade
            // 也會一起刪除。
            await transaction.userTag.deleteMany({
              where: {
                userId:
                  currentUser.id,
              },
            });

            for (const tag of tags) {
              await transaction.userTag.create({
                data: {
                  userId:
                    currentUser.id,

                  value:
                    tag.value,

                  languageCode:
                    tag.languageCode,

                  scriptCode:
                    tag.scriptCode,

                  translations:
                    tag.translations.length > 0
                      ? {
                          create:
                            tag.translations.map(
                              (translation) => ({
                                languageCode:
                                  translation.languageCode,

                                scriptCode:
                                  translation.scriptCode,

                                value:
                                  translation.value,
                              }),
                            ),
                        }
                      : undefined,
                },
              });
            }
          }

            // --------------------------------------------
            // 3. 如果请求带 languages
            //    就完整替换当前用户 languages
            // --------------------------------------------

            if (languages !== undefined) {
              await transaction.userLanguage.deleteMany({
                where: {
                  userId:
                    currentUser.id,
                },
              });

              if (languages.length > 0) {
                await transaction.userLanguage.createMany({
                  data: languages.map(
                    (language) => ({
                      userId:
                        currentUser.id,

                      languageCode:
                        language.name,

                      scriptCode:
                        language.scriptCode ?? '',

                      level:
                        language.level,
                    }),
                  ),

                  skipDuplicates: true,
                });
              }
            }

            // --------------------------------------------
// 4. 如果请求带 localizedNames
//    就完整替换当前用户多语言名称
// --------------------------------------------

if (localizedNames !== undefined) {
  await transaction.userLocalizedName.deleteMany({
    where: {
      userId: currentUser.id,
    },
  });

  if (localizedNames.length > 0) {
    await transaction.userLocalizedName.createMany({
      data: localizedNames.map(
        (localizedName) => ({
          userId: currentUser.id,

          languageCode:
            localizedName.languageCode,

          scriptCode:
            localizedName.scriptCode ?? '',

          name:
            localizedName.name,
        }),
      ),

      skipDuplicates: true,
    });
  }
}


// --------------------------------------------
// 用户资料发生修改后，清除该用户的
// AI 标签翻译缓存。
//
// 下次观看者主动翻译时重新生成，
// 之后继续复用缓存。
// --------------------------------------------

await transaction.userTagAiTranslationCache.deleteMany({
  where: {
    userId: currentUser.id,
  },
});
            // --------------------------------------------
            // 5. 更新完成后重新读取完整 User
            // --------------------------------------------

            return transaction.user.findUniqueOrThrow({
              where: {
                firebaseUid:
                  auth.firebaseUid,
              },

              include: {
                tags: {
                  include: {
                    translations: true,
                  },
                },
                languages: true,
                localizedNames: true,
              },
            });
          },
        );

      response.status(200).json({
        user: serializeUser(user),
      });
    } catch (error) {
      console.error(
        'Update user failed:',
        error,
      );

      const code =
        prismaErrorCode(error);

      // username / email 唯一约束冲突
      if (code === 'P2002') {
        response.status(409).json({
          error: 'USER_CONFLICT',
          message:
            'Username or email already exists',
        });

        return;
      }

      // PostgreSQL 找不到该用户
      if (code === 'P2025') {
        response.status(404).json({
          error: 'USER_NOT_FOUND',
          message:
            'Backend user does not exist',
        });

        return;
      }

      response.status(500).json({
        error: 'UPDATE_USER_FAILED',
        message:
          'Unable to update user',
      });
    }
  },
);

// ============================================================
// GET /api/v1/users/:uid
//
// 获取任意用户公开资料。
// 注意：这个动态路由必须放在 /me 后面。
// ============================================================

userRouter.get(
  '/:uid',
  requireAuth,
  async (request, response) => {
    const uid = request.params.uid;

    // Express 5 类型里 params 可能不是单纯 string，
    // 所以必须先收窄。
    if (typeof uid !== 'string') {
      response.status(400).json({
        error: 'INVALID_USER_ID',
        message: 'Invalid user id',
      });

      return;
    }

    try {
      const user =
        await prisma.user.findUnique({
          where: {
            firebaseUid: uid,
          },

          include: {
            tags: {
              include: {
                translations: true,
              },
            },
            languages: true,
            localizedNames: true,
          },
        });

      if (user == null) {
        response.status(404).json({
          error: 'USER_NOT_FOUND',
          message:
            'User does not exist',
        });

        return;
      }

      const isSelf =
        response.locals.auth.firebaseUid ===
        user.firebaseUid;

      response.status(200).json({
        user: serializeUser(
          user,
          {
            // 自己可以看自己的生日；
            // 其他用户只有 showAge=true 才返回生日。
            includeBirthday:
              isSelf || user.showAge,
          },
        ),
      });
    } catch (error) {
      console.error(
        'Get user failed:',
        error,
      );

      response.status(500).json({
        error: 'GET_USER_FAILED',
        message:
          'Unable to load user',
      });
    }
  },
);