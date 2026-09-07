import { Router } from 'express';
import { z } from 'zod';

import { prisma } from '../lib/prisma.js';
import { requireAuth } from '../middleware/require_auth.js';

export const commentRouter = Router();

type CommentAuthor = {
  firebaseUid: string;
  username: string;
  nickname: string | null;
  avatarUrl: string | null;

  localizedNames: Array<{
    languageCode: string;
    scriptCode: string;
    name: string;
  }>;
};

type SerializedComment = {
  id: string;
  uid: string | null;
  user: string;
  avatarUrl: string | null;

  localizedNames: Array<{
    languageCode: string;
    scriptCode: string;
    name: string;
  }>;

  text: string;
  imageUrl: string | null;
  replyTo: string | null;
  timestamp: string;
  replies: SerializedComment[];
};

type CommentRecord = {
  id: string;
  authorName: string;
  text: string;
  imageUrl: string | null;
  replyTo: string | null;
  createdAt: Date;
  author: CommentAuthor | null;
  replies?: CommentRecord[];
};

const authorSelect = {
  firebaseUid: true,
  username: true,
  nickname: true,
  avatarUrl: true,

  localizedNames: {
    select: {
      languageCode: true,
      scriptCode: true,
      name: true,
    },
  },
} as const;

function authorDisplayName(
  author: CommentAuthor | null,
  fallback: string,
) {
  const nickname =
    author?.nickname?.trim();

  if (nickname != null && nickname.length > 0) {
    return nickname;
  }

  const username =
    author?.username?.trim();

  if (username != null && username.length > 0) {
    return username;
  }

  return fallback.trim().length > 0
    ? fallback
    : 'Guest';
}

function serializeComment(
  comment: CommentRecord,
): SerializedComment {
  return {
    id: comment.id,

    uid:
      comment.author?.firebaseUid ??
      null,

    user: authorDisplayName(
      comment.author,
      comment.authorName,
    ),

    avatarUrl:
      comment.author?.avatarUrl ??
      null,

    localizedNames:
      comment.author?.localizedNames.map(
        (localizedName) => ({
          languageCode:
            localizedName.languageCode,
          scriptCode:
            localizedName.scriptCode,
          name:
            localizedName.name,
        }),
      ) ?? [],

    text: comment.text,

    imageUrl: comment.imageUrl,
    replyTo: comment.replyTo,

    timestamp:
      comment.createdAt.toISOString(),

    replies:
      (comment.replies ?? []).map(
        (reply) =>
          serializeComment({
            ...reply,
            replies: [],
          }),
      ),
  };
}

async function findPost(
  id: string,
) {
  const isDatabaseId =
    z.string().uuid().safeParse(id).success;

  return prisma.post.findFirst({
    where: {
      ...(isDatabaseId
        ? {
            OR: [
              { firestoreId: id },
              { id },
            ],
          }
        : { firestoreId: id }),
      reports: {
        none: {
          status: 'actioned',
        },
      },
    },
    select: {
      id: true,
    },
  });
}

async function findCurrentUser(
  firebaseUid: string,
) {
  return prisma.user.findUnique({
    where: {
      firebaseUid,
    },
    select: {
      id: true,
      firebaseUid: true,
      username: true,
      nickname: true,
      avatarUrl: true,

      localizedNames: {
        select: {
          languageCode: true,
          scriptCode: true,
          name: true,
        },
      },
    },
  });
}

// ============================================================
// GET /api/v1/posts/:postId/comments
// ============================================================

commentRouter.get(
  '/:postId/comments',
  async (request, response) => {
    const postId =
      request.params.postId;

    if (typeof postId !== 'string') {
      response.status(400).json({
        error: 'INVALID_POST_ID',
        message: 'Invalid post id',
      });

      return;
    }

    try {
      const post =
        await findPost(postId);

      if (post == null) {
        response.status(404).json({
          error: 'POST_NOT_FOUND',
          message: 'Post does not exist',
        });

        return;
      }

      const comments =
        await prisma.postComment.findMany({
          where: {
            postId: post.id,
            parentId: null,
          },

          orderBy: {
            createdAt: 'desc',
          },

          include: {
            author: {
              select: authorSelect,
            },

            replies: {
              orderBy: {
                createdAt: 'asc',
              },

              include: {
                author: {
                  select: authorSelect,
                },
              },
            },
          },
        });

      response.status(200).json({
        comments:
          comments.map(
            (comment) =>
              serializeComment(comment),
          ),
      });
    } catch (error) {
      console.error(
        'Get comments failed:',
        error,
      );

      response.status(500).json({
        error: 'GET_COMMENTS_FAILED',
        message: 'Unable to load comments',
      });
    }
  },
);

// ============================================================
// POST /api/v1/posts/:postId/comments
// ============================================================

const createCommentSchema = z
  .object({
    text: z
      .string()
      .max(5000)
      .default(''),

    imageUrl: z
      .string()
      .url()
      .nullable()
      .optional(),
  })
  .refine(
    (value) =>
      value.text.trim().length > 0 ||
      value.imageUrl != null,
    {
      message:
        'Comment must contain text or image',
    },
  );

commentRouter.post(
  '/:postId/comments',
  requireAuth,
  async (request, response) => {
    const postId =
      request.params.postId;

    if (typeof postId !== 'string') {
      response.status(400).json({
        error: 'INVALID_POST_ID',
        message: 'Invalid post id',
      });

      return;
    }

    const parsed =
      createCommentSchema.safeParse(
        request.body,
      );

    if (!parsed.success) {
      response.status(400).json({
        error: 'INVALID_REQUEST',
        message: 'Invalid comment data',
        details:
          parsed.error.flatten(),
      });

      return;
    }

    const auth =
      response.locals.auth;

    try {
      const [post, author] =
        await Promise.all([
          findPost(postId),
          findCurrentUser(
            auth.firebaseUid,
          ),
        ]);

      if (post == null) {
        response.status(404).json({
          error: 'POST_NOT_FOUND',
          message: 'Post does not exist',
        });

        return;
      }

      if (author == null) {
        response.status(404).json({
          error: 'USER_NOT_FOUND',
          message:
            'Backend user does not exist',
        });

        return;
      }

      const authorName =
        authorDisplayName(
          author,
          'Guest',
        );

      const comment =
        await prisma.$transaction(
          async (transaction) => {
            const created =
              await transaction
                .postComment
                .create({
                  data: {
                    postId: post.id,
                    authorId: author.id,
                    authorName,

                    text:
                      parsed.data.text.trim(),

                    imageUrl:
                      parsed.data.imageUrl ??
                      null,
                  },

                  include: {
                    author: {
                      select:
                        authorSelect,
                    },
                  },
                });

            await transaction
              .post
              .update({
                where: {
                  id: post.id,
                },

                data: {
                  commentCount: {
                    increment: 1,
                  },
                },
              });

            return created;
          },
        );

      response.status(201).json({
        comment:
          serializeComment({
            ...comment,
            replies: [],
          }),
      });
    } catch (error) {
      console.error(
        'Create comment failed:',
        error,
      );

      response.status(500).json({
        error: 'CREATE_COMMENT_FAILED',
        message: 'Unable to create comment',
      });
    }
  },
);

// ============================================================
// POST /api/v1/posts/:postId/comments/:commentId/replies
// ============================================================

const createReplySchema = z.object({
  text: z
    .string()
    .trim()
    .min(1)
    .max(5000),
});

commentRouter.post(
  '/:postId/comments/:commentId/replies',
  requireAuth,
  async (request, response) => {
    const postId =
      request.params.postId;

    const commentId =
      request.params.commentId;

    if (
      typeof postId !== 'string' ||
      typeof commentId !== 'string'
    ) {
      response.status(400).json({
        error: 'INVALID_REQUEST',
        message:
          'Invalid post or comment id',
      });

      return;
    }

    const parsed =
      createReplySchema.safeParse(
        request.body,
      );

    if (!parsed.success) {
      response.status(400).json({
        error: 'INVALID_REQUEST',
        message: 'Invalid reply data',
        details:
          parsed.error.flatten(),
      });

      return;
    }

    const auth =
      response.locals.auth;

    try {
      const [post, author] =
        await Promise.all([
          findPost(postId),
          findCurrentUser(
            auth.firebaseUid,
          ),
        ]);

      if (post == null) {
        response.status(404).json({
          error: 'POST_NOT_FOUND',
          message: 'Post does not exist',
        });

        return;
      }

      if (author == null) {
        response.status(404).json({
          error: 'USER_NOT_FOUND',
          message:
            'Backend user does not exist',
        });

        return;
      }

      const parent =
        await prisma
          .postComment
          .findFirst({
            where: {
              id: commentId,
              postId: post.id,
              parentId: null,
            },

            include: {
              author: {
                select: authorSelect,
              },
            },
          });

      if (parent == null) {
        response.status(404).json({
          error: 'COMMENT_NOT_FOUND',
          message:
            'Comment does not exist',
        });

        return;
      }

      const authorName =
        authorDisplayName(
          author,
          'Guest',
        );

      const reply =
        await prisma
          .postComment
          .create({
            data: {
              postId: post.id,
              authorId: author.id,
              parentId: parent.id,

              authorName,

              text:
                parsed.data.text,

              replyTo:
                authorDisplayName(
                  parent.author,
                  parent.authorName,
                ),
            },

            include: {
              author: {
                select: authorSelect,
              },
            },
          });

      response.status(201).json({
        reply:
          serializeComment({
            ...reply,
            replies: [],
          }),
      });
    } catch (error) {
      console.error(
        'Create reply failed:',
        error,
      );

      response.status(500).json({
        error: 'CREATE_REPLY_FAILED',
        message: 'Unable to create reply',
      });
    }
  },
);
