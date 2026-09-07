# 万文社 / Glyphora

**Vạn Văn Xã · Glyphora**

A multilingual community platform built around **people, languages, writing systems, conversation, and shared knowledge**.

Glyphora is not designed as a simple forum clone. It combines community posts, discovery, social relationships, real-time chat, shared notes, multilingual UI, and support for underrepresented writing systems such as **Vietnamese Chữ Nôm**.

The project is developed as a monorepo with a Flutter mobile client, React administration dashboard, Node.js API, PostgreSQL, and Firebase services.

---

## Screenshots

> Screenshot placeholders are intentionally kept here. Add the images under `docs/screenshots/` and replace each placeholder when ready.

### Community Feed

📸 **Screenshot placeholder:** `docs/screenshots/feed.png`

### Post / Content Detail

📸 **Screenshot placeholder:** `docs/screenshots/post-detail.png`

### Real-time Chat

📸 **Screenshot placeholder:** `docs/screenshots/chat.png`

### Multilingual UI

📸 **Screenshot placeholder:** `docs/screenshots/multilingual-ui.png`

### Vietnamese Chữ Nôm

📸 **Screenshot placeholder:** `docs/screenshots/chu-nom.png`

### Profile / Discover

📸 **Screenshot placeholder:** `docs/screenshots/profile-discover.png`

### Admin Dashboard

📸 **Screenshot placeholder:** `docs/screenshots/admin-dashboard.png`

---

## What Glyphora Includes

### Community

- Create and browse posts
- Text and image posts
- Multiple image uploads
- Post detail views
- Likes and comments
- Content categories
- Public feeds
- Discovery experience

### Social

- User profiles
- Friend relationships
- Social connections between users
- Profile-linked posts and activity

### Real-time Chat

- Conversation list
- Private messaging
- Real-time messages
- Image messages
- Message previews
- Message visibility state
- Logical deletion and delayed physical cleanup

The chat lifecycle is designed so that deleting a message does not always immediately destroy its underlying data.

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

The cleanup job can also remove associated media and maintain the latest valid conversation preview.

### Shared Notes

Chat participants can create longer-form shared notes for information that should outlive an individual message.

Use cases include:

- Conversation summaries
- Learning material
- Shared ideas
- Draft content
- Collaborative notes

Rich-text editing is powered by **Flutter Quill**.

### Administration

The project includes a separate administration application for managing platform data and moderation-oriented workflows.

Current administration areas include users, posts, platform statistics, and protected administrative operations.

---

## Multilingual by Design

Multilingual support is part of the application architecture rather than a late UI translation layer.

The localization system supports multiple interface languages, including:

- 中文
- English
- 日本語
- 한국어
- Bahasa Melayu
- Tiếng Việt
- ไทย

Glyphora also supports a dedicated Vietnamese Han-script locale:

```text
vi-Hani
```

This allows the application to distinguish between a language and the writing system used to display it.

```text
Language
   +
Script
   ↓
Localized experience
```

---

## Vietnamese Chữ Nôm Support

One of Glyphora's distinctive areas is support for Vietnamese Chữ Nôm content.

The Flutter client includes the **NomNaTong** font and script-aware locale handling.

Example:

```dart
Locale.fromSubtags(
  languageCode: 'vi',
  scriptCode: 'Hani',
)
```

This makes it possible to treat Chữ Nôm as part of the actual application language system instead of rendering it as an isolated special-case string.

---

## Architecture

Glyphora is organized as a monorepo:

```text
glyphora/
│
├── apps/
│   ├── mobile-flutter/   # Main Flutter client
│   ├── mobile-rn/        # React Native client / experiment
│   ├── admin/            # React administration dashboard
│   └── api/              # Node.js / TypeScript API
│
├── docs/
├── firebase.json
└── README.md
```

### High-level system

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

Glyphora uses a hybrid backend model: Firebase services handle authentication and real-time/mobile-oriented workloads, while the Node.js API provides server-side business logic, migrations, scheduled jobs, and PostgreSQL-backed functionality.

---

## Flutter Application Structure

The Flutter application is organized primarily by feature.

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

Core features progressively follow boundaries such as:

```text
domain
application
data
presentation
```

The goal is to keep UI, state orchestration, repository contracts, and data adapters from collapsing into a single layer.

---

## State Management

Glyphora uses **BLoC / Cubit** for mutable UI state and orchestration.

Examples include:

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

`Provider` is also used for dependency injection of repositories and long-lived dependencies. Its presence does not mean the application relies on `ChangeNotifier` as its main state-management architecture.

A typical flow looks like:

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

## Authentication Flow

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

Firebase Authentication maintains the user session while the rest of the application reacts to authentication state.

---

## Deep Links

The Flutter client uses `app_links` through a shared deep-link service.

The design allows external links to eventually resolve directly into application destinations such as:

- Posts
- Profiles
- Chats
- Other community content

---

## Tech Stack

### Mobile

- Flutter
- Dart
- Material 3
- BLoC / Cubit
- Provider for dependency injection
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
- Script-aware locale handling
- NomNaTong font for Chữ Nôm
- Shared Glyphora language configuration package

---

## Backend Jobs

The API contains scheduled maintenance jobs for chat-message cleanup.

Examples:

```text
apps/api/src/jobs/
├── cleanup_expired_chat_messages.ts
└── run_cleanup_expired_chat_messages.ts
```

Development command:

```bash
npm run job:cleanup-chat-messages:dev
```

Production builds can execute:

```bash
npm run job:cleanup-chat-messages
```

A deployment platform can trigger this command through a scheduler or cron service.

---

## Getting Started

### Clone

```bash
git clone https://github.com/chengyang1017/glyphora.git
cd glyphora
```

### Flutter client

```bash
cd apps/mobile-flutter
flutter pub get
flutter run
```

The mobile application requires a configured Firebase project.

### Admin dashboard

```bash
cd apps/admin
npm install
npm run dev
```

Build:

```bash
npm run build
```

### API

```bash
cd apps/api
npm install
npm run dev
```

Type-check:

```bash
npm run typecheck
```

Build:

```bash
npm run build
```

The API requires its own environment configuration for services such as PostgreSQL and Firebase Admin credentials. Real secrets and environment files should not be committed.

---

## Main Product Flow

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

Glyphora treats posts, chat, notes, languages, and relationships as connected parts of the same community rather than unrelated features.

---

## Project Goals

Glyphora explores how a modern social product can give language and writing-system diversity first-class support.

The long-term direction is broader than a conventional forum:

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

The project is especially interested in building useful infrastructure for languages and scripts that are often poorly supported in mainstream software.

---

## Status

**Active development.**

The repository currently contains the Flutter client, React administration application, Node.js API, Firebase integration, multilingual UI infrastructure, social/community features, real-time chat, and Chữ Nôm-oriented language support.

Current work focuses on architecture refinement, backend migration, production readiness, and improving the overall product experience.
