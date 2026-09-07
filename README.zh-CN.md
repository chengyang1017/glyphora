# 万文社 / Glyphora

[English](README.md) | **简体中文**

**Vạn Văn Xã · Glyphora**

一个围绕 **人与人、语言、文字系统、交流与共享知识** 构建的多语言社区平台。

Glyphora 并不是一个简单的论坛克隆。它将社区帖子、内容发现、用户关系、实时聊天、共享笔记、多语言界面，以及对 **越南喃字（Chữ Nôm）** 等较少被主流软件支持的文字系统整合在同一个产品中。

项目采用 monorepo 结构开发，目前包含 Flutter 移动端、React 管理后台、Node.js API、PostgreSQL 与 Firebase 服务。

---

## 截图

> 这里暂时保留截图占位。准备好图片后，将文件放入 `docs/screenshots/`，再替换对应占位即可。

### 社区首页 / Feed

📸 **截图占位：** `docs/screenshots/feed.png`

### 帖子 / 内容详情

📸 **截图占位：** `docs/screenshots/post-detail.png`

### 实时聊天

📸 **截图占位：** `docs/screenshots/chat.png`

### 多语言界面

📸 **截图占位：** `docs/screenshots/multilingual-ui.png`

### 越南喃字

📸 **截图占位：** `docs/screenshots/chu-nom.png`

### 个人资料 / Discover

📸 **截图占位：** `docs/screenshots/profile-discover.png`

### 管理后台

📸 **截图占位：** `docs/screenshots/admin-dashboard.png`

---

## Glyphora 包含什么

### 社区功能

- 发布与浏览帖子
- 文字与图片帖子
- 多图片上传
- 帖子详情
- 点赞与评论
- 内容分类
- 公共 Feed
- Discover 内容发现

### 社交功能

- 用户资料
- 好友关系
- 用户之间的社交连接
- 与个人资料关联的帖子和活动

### 实时聊天

- 会话列表
- 私信
- 实时消息
- 图片消息
- 消息预览
- 消息可见状态
- 逻辑删除与延迟物理清理

聊天消息并不是在用户删除后立即从底层数据中彻底消失。

```text
Active Message
      ↓
User hides / deletes
      ↓
Logical deletion
      ↓
cleanupAt
      ↓
Scheduled Node.js cleanup job
      ↓
Physical deletion
```

定时清理任务还可以删除关联媒体，并重新维护会话中最新的有效消息预览。

### 共享笔记

聊天成员可以创建比单条消息更适合长期保存的信息型共享笔记。

适合用于：

- 对话总结
- 学习资料
- 共同想法
- 内容草稿
- 协作记录

富文本编辑基于 **Flutter Quill**。

### 管理后台

项目包含独立管理应用，用于平台数据管理与审核相关流程。

目前包括用户、帖子、平台统计以及受保护的管理员操作。

---

## 从架构层面支持多语言

Glyphora 的多语言支持并不是后期补上的 UI 翻译层，而是产品架构的一部分。

当前界面语言体系包括：

- 中文
- English
- 日本語
- 한국어
- Bahasa Melayu
- Tiếng Việt
- ไทย

Glyphora 还支持独立的越南语汉字 / 喃字脚本 Locale：

```text
vi-Hani
```

因此应用可以区分“语言”与“使用哪一种文字系统显示该语言”。

```text
Language
   +
Script
   ↓
Localized experience
```

---

## 越南喃字支持

Glyphora 一个较有辨识度的方向，是让越南喃字内容真正进入应用语言系统。

Flutter 客户端包含 **NomNaTong** 字体，并使用支持 script code 的 Locale。

例如：

```dart
Locale.fromSubtags(
  languageCode: 'vi',
  scriptCode: 'Hani',
)
```

这样喃字不只是某个页面里的特殊字符串，而可以作为实际语言 / 文字系统配置参与整个应用的本地化体验。

---

## 架构

Glyphora 使用 monorepo：

```text
glyphora/
│
├── apps/
│   ├── mobile-flutter/   # 主要 Flutter 客户端
│   ├── mobile-rn/        # React Native 客户端 / 实验
│   ├── admin/            # React 管理后台
│   └── api/              # Node.js / TypeScript API
│
├── docs/
├── firebase.json
└── README.md
```

### 高层系统结构

```text
┌──────────────────────────┐
│ Flutter Mobile Client    │
│ BLoC / Cubit             │
└────────────┬─────────────┘
             │
             ├───────────────┐
             │               │
             ▼               ▼
┌────────────────────┐   ┌─────────────────────┐
│ Firebase Services  │   │ Node.js / Express   │
│ Auth               │   │ TypeScript API      │
│ Firestore          │   └──────────┬──────────┘
│ Realtime Database  │              │
│ Storage            │              ▼
└────────────────────┘       ┌──────────────┐
                             │ Prisma       │
                             │ PostgreSQL   │
                             └──────────────┘
                                      ▲
                                      │
                           ┌──────────┴──────────┐
                           │ React Admin         │
                           │ Vite + TypeScript   │
                           └─────────────────────┘
```

Glyphora 采用混合后端模式：Firebase 负责认证以及偏实时、移动端导向的能力，Node.js API 则负责服务器端业务逻辑、迁移脚本、定时任务以及 PostgreSQL 相关功能。

---

## Flutter 应用结构

Flutter 应用主要按照 Feature 组织。

```text
lib/
├── app/
├── core/
├── data/
├── features/
│   ├── admin/
│   ├── auth/
│   ├── chat/
│   ├── discover/
│   ├── feed/
│   ├── home/
│   ├── notes/
│   ├── post/
│   ├── profile/
│   └── social/
└── shared/
```

核心功能逐步按照以下边界拆分：

```text
domain
application
data
presentation
```

目标是避免 UI、状态编排、Repository contract 与数据适配器全部挤在同一层中。

---

## 状态管理

Glyphora 使用 **BLoC / Cubit** 管理可变 UI 状态与业务编排。

例如：

```text
AppLanguageCubit
AuthCubit
ChatCubit
FriendCubit
DiscoverCubit
FeedCubit
PostCubit
ProfileCubit
```

项目同时使用 `Provider` 注入 Repository 与长生命周期依赖。这里使用 Provider 并不代表应用仍以 `ChangeNotifier` 作为主要状态管理架构。

典型数据流：

```text
UI
 ↓
Cubit
 ↓
Repository
 ↓
Firebase adapter / HTTP service
 ↓
Backend or data source
```

---

## 登录流程

```text
App launch
    ↓
Firebase initialization
    ↓
Auth state listener
    ↓
Logged in?
   /      \
 Yes      No
  ↓        ↓
App UI   Login
```

Firebase Authentication 维护用户登录状态，其余应用模块根据认证状态作出响应。

---

## Deep Links

Flutter 客户端通过共享 deep-link service 使用 `app_links`。

设计目标是让外部链接未来可以直接打开应用中的：

- 帖子
- 用户资料
- 聊天
- 其他社区内容

---

## 技术栈

### Mobile

- Flutter
- Dart
- Material 3
- BLoC / Cubit
- Provider（依赖注入）
- GoRouter
- Dio
- Flutter Quill

### Firebase

- Firebase Authentication
- Cloud Firestore
- Firebase Realtime Database
- Firebase Storage

### Backend

- Node.js
- TypeScript
- Express
- Prisma ORM
- PostgreSQL
- Firebase Admin SDK
- Zod
- Vitest / Supertest

### Admin

- React
- TypeScript
- Vite
- React Router
- TanStack Query
- Axios
- Ant Design

### Language & Localization

- Flutter Localizations
- Intl
- 支持 Script 的 Locale 处理
- NomNaTong 喃字字体
- Glyphora 共享语言配置包

---

## 后端定时任务

API 中包含聊天消息清理相关的定时维护任务。

例如：

```text
apps/api/src/jobs/
├── cleanup_expired_chat_messages.ts
└── run_cleanup_expired_chat_messages.ts
```

开发环境：

```bash
npm run job:cleanup-chat-messages:dev
```

生产构建后可运行：

```bash
npm run job:cleanup-chat-messages
```

部署平台可通过 Scheduler / Cron 定期触发该命令。

---

## 开始运行

### Clone

```bash
git clone https://github.com/chengyang1017/glyphora.git
cd glyphora
```

### Flutter 客户端

```bash
cd apps/mobile-flutter
flutter pub get
flutter run
```

移动端需要配置对应的 Firebase 项目。

### 管理后台

```bash
cd apps/admin
npm install
npm run dev
```

构建：

```bash
npm run build
```

### API

```bash
cd apps/api
npm install
npm run dev
```

类型检查：

```bash
npm run typecheck
```

构建：

```bash
npm run build
```

API 需要自行配置 PostgreSQL、Firebase Admin 等环境变量。真实密钥与环境文件不应提交到仓库。

---

## 主要产品流程

```text
Discover people and content
          ↓
        Posts
          ↓
      Conversation
          ↓
         Chat
          ↓
     Shared Notes
          ↓
Longer-term knowledge and community
```

Glyphora 将帖子、聊天、笔记、语言和用户关系视为同一个社区体系中互相连接的部分，而不是彼此无关的独立功能。

---

## 项目目标

Glyphora 探索的是：一个现代社交产品如何让语言与文字系统多样性真正获得一等支持。

长期方向不止是传统论坛：

```text
People
  +
Languages
  +
Writing Systems
  +
Conversation
  +
Knowledge
  =
Glyphora
```

项目尤其关注那些在主流软件中长期缺乏良好基础工具和显示支持的语言与文字系统。

---

## 状态

**持续开发中。**

当前仓库已经包含 Flutter 客户端、React 管理后台、Node.js API、Firebase 集成、多语言 UI 基础设施、社区 / 社交功能、实时聊天与喃字相关支持。

目前重点包括架构优化、后端迁移、生产环境准备以及整体产品体验提升。
