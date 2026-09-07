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

## Feature Overview

Glyphora already contains several connected product systems rather than a single forum feed.

### Authentication & Accounts

- User registration and login
- Firebase Authentication session handling
- Authentication gate between signed-in and signed-out experiences
- Forgot-password flow
- Password reset email flow
- Password change screen
- Username availability checks backed by PostgreSQL
- Firebase user → PostgreSQL user synchronization
- Local history of previously used accounts
- Authentication failure mapping and user-facing error handling
- Protected API operations using authenticated Firebase identities

### User Profiles

- Personal profile screen
- Public user profile screen
- User directory / user listing
- Username and nickname
- Avatar upload and storage
- Biography
- Birthday
- Optional age visibility through `showAge`
- Created-at and last-active information
- User-linked post history
- Profile statistics and reusable profile header components

### Language Identity

Language information is stored as structured profile data instead of being treated as plain text.

Users can maintain:

- Languages they know
- Language codes
- Script codes
- Language proficiency levels
- Multiple language entries
- Script-aware language display
- Editable language profiles

This lets Glyphora represent language and writing-system identity directly in the user model.

### Localized Names

A user can maintain multiple localized forms of their name.

Each localized name contains:

```text
languageCode
scriptCode
name
```

This makes it possible for the same profile to present different names across different languages or writing systems.

### Multilingual Profile Tags

Profile tags are structured multilingual objects rather than only strings.

Supported fields include:

```text
value
languageCode
scriptCode
translations[]
```

Features include:

- Add and remove profile tags
- Edit profile tags
- Up to 10 tags per user
- Language-aware tags
- Script-aware tags
- Multiple translated versions of a tag
- Localized tag rendering
- Backward compatibility with legacy string-only tags
- AI-assisted tag translation through the backend

---

## Community & Posts

### Feed & Discovery

- Community feed
- Post cards
- Post detail navigation
- Public content browsing
- Language-channel browsing
- Category-based browsing
- Discover screen for finding users and content
- User-directory integration with social actions
- Loading and error states through feature-specific state management

### Content Categories

The home experience supports configurable content categories, including areas such as:

- Language learning
- Programming
- Other community categories defined by the application configuration

### Language Channels

Glyphora separates **interface language** from **community content language**.

A user can keep the application UI in one language while browsing another language's community channel.

The Flutter client includes:

- Dedicated language-channel selection
- Large language lists
- Alphabetic navigation
- Current channel state
- Script-aware language configuration

### Create Posts

- Create a new post
- Title
- Rich-text body
- Content category
- Primary content language
- Up to 9 images
- Local image selection
- Firebase Storage media upload
- PostgreSQL image metadata
- Stable post IDs during backend migration
- Idempotent retry protection to avoid accidental duplicate posts

Backend validation currently enforces limits such as:

```text
title   <= 300 characters
content <= 5000 characters
images  <= 9
```

### Rich-text Content

Posts store both rendered text content and structured editor data.

```text
content
bodyDelta
```

Rich-text editing and rendering use **Flutter Quill**.

### Post Media

- Multiple images per post
- Image preview UI
- Ordered image metadata
- Image upload abstraction
- Post-edit media cleanup planning
- Replacement of image sets during editing
- Firebase Storage for media files
- PostgreSQL for media URLs and ordering

### Post Detail

The post-detail experience brings together most community actions:

- View author information
- View rich-text content
- View post images
- View category and timestamps
- Like / unlike
- Comment
- Reply
- Bookmark / remove bookmark
- Report content
- View available language versions
- Switch between language versions
- Request AI translation
- Add a manual translation
- Edit owned posts
- Delete owned posts
- View post edit history

---

## Likes

Post likes are backed by server-side business logic.

Supported operations:

```text
PUT    /api/v1/posts/:id/like
DELETE /api/v1/posts/:id/like
```

The operations are designed to be idempotent so repeated network requests do not create duplicate likes or invalid unlike states.

---

## Comments & Replies

### Comments

- Load comments for a post
- Create text comments
- Create image comments
- Combine text and image content
- Author avatar and display name
- Localized author names
- Comment timestamps
- Server-maintained comment counts

### Replies

Glyphora currently supports a structured top-level comment + reply model.

```text
Post
 └── Comment
      ├── Reply
      ├── Reply
      └── Reply
```

Replies store their parent comment and the display name of the user being replied to.

---

## Bookmarks

- Bookmark a post
- Remove a bookmark
- Persist bookmarks in the backend
- Dedicated bookmarked-posts screen
- Load the current user's saved posts
- Track bookmark timestamps
- Show newest bookmarks first
- Idempotent bookmark and unbookmark operations

Backend endpoints include:

```text
POST   /api/v1/posts/:id/bookmark
DELETE /api/v1/posts/:id/bookmark
GET    /api/v1/users/me/bookmarks
```

---

## Multilingual Post Versions

A Glyphora post is not restricted to a single language representation.

```text
Post
 ├── Original language version
 ├── Manual translation
 ├── AI translation
 ├── AI-assisted translation
 └── Additional language versions
```

Each post keeps information such as:

```text
primaryLanguageCode
availableLanguageCodes
PostVersion[]
```

New versions can be added to an existing post without creating a separate unrelated post.

### Translation Provenance

Post versions distinguish how a translation was created:

```text
original
manual
ai
ai_assisted
```

This keeps human-written, machine-generated, and assisted translations distinguishable in the data model.

### Manual Translation

Users can create their own translated version of an existing post and publish it as a new language version.

### AI Translation

The Node.js backend contains dedicated post-translation routes and services.

The workflow supports:

- Choose a target language
- Translate the title
- Translate the post body
- Return a translated post version
- Persist translation provenance
- Surface AI translation failures to the client

Profile tags also have a separate AI translation service.

---

## Social Graph

Glyphora supports both **following** and **friendship** as separate concepts.

### Following

- Follow users
- Unfollow users
- Determine current follow state
- Followers
- Following
- Follow counts
- Follow statistics on profiles

### Friends

- Send friend requests
- View incoming friend requests
- Accept friend requests
- Maintain friendship relationship state
- Friends list
- Friend-specific state management

### Blocking

- Block users
- View blocked users
- Unblock users
- Use relationship state to restrict social interactions

---

## Real-time Chat

The Flutter client contains a full chat feature rather than a placeholder.

### Conversations

- Conversation list
- Chat threads
- Open a direct conversation
- Real-time message streams
- Chat-specific Cubit / repository layers

### Messages

- Send messages
- Receive messages
- Message bubbles
- Sender-aware presentation
- Message input bar
- Real-time updates
- Message previews

### Chat Media

- Dedicated chat-media repository
- Firebase-backed media uploads
- Image / media messages

### Emoji

- Built-in emoji picker
- Insert emoji into chat input

### Live Drafts

Chat contains a dedicated live-draft data layer:

```text
LiveDraft
LiveDraftRepository
FirebaseLiveDraftRepository
```

This provides infrastructure for synchronizing in-progress draft state separately from sent messages.

### Message Lifecycle & Cleanup

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

---

## Shared Notes

Chat participants can create longer-form shared notes for information that should outlive an individual message.

Available functionality includes:

- Notes overview
- User-specific shared-note screen
- Open a note editor
- Create and update notes
- Firebase persistence
- Rich-text note content
- Note image support
- Dedicated note-media repository

Use cases include:

- Conversation summaries
- Learning material
- Shared ideas
- Draft content
- Collaborative notes

Rich-text editing is powered by **Flutter Quill**.

---

## Post Editing & History

- Edit existing posts
- Replace post media
- Remove unused media
- Track update timestamps
- Store post edit-history entries
- Dedicated post edit-history screen
- Delete posts
- Cascade related database records such as versions and image metadata where appropriate

This gives Glyphora a lightweight revision-history capability in addition to normal social-post editing.

---

## Reporting & Moderation

### User Reporting

- Report posts
- Submit report reasons
- Persist reports in the backend
- View the current user's submitted reports
- Track report state

### Moderation

The API contains dedicated moderation routes under:

```text
/api/v1/admin/moderation
```

Moderation decisions influence normal content visibility. Posts whose reports have been actioned are filtered from regular post, comment, and bookmark queries.

---

## Administration

Glyphora includes a separate React administration application.

Current administration functionality includes:

- Administrator login
- Protected administration routes
- Dashboard
- Platform overview / statistics entry point
- Reports management
- Moderation workflows
- Backend admin APIs

The administration project is intentionally separated from the Flutter mobile client.

---

## User Interests

The Node.js API includes a dedicated interests subsystem:

```text
/api/v1/users/me/interests
```

This provides backend infrastructure for storing user interests and can support future personalization, discovery, and feed-ranking work.

---

## Settings & Security

The Flutter client includes dedicated settings and security screens.

Current areas include:

- General settings
- Security settings
- Password change
- Account-related operations
- Birthday editing
- Age visibility preferences
- Language and profile customization

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

The project also contains a dedicated `app_vi_Hani.arb` localization resource, allowing interface elements such as translation actions to be represented through the Vietnamese Han-script locale.

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

Glyphora currently uses a hybrid backend model.

```text
Firebase Authentication
        ↓
User identity / sessions

Firebase Storage
        ↓
Images and media

Firestore / Firebase services
        ↓
Real-time and still-migrating feature areas

Node.js / Express
        ↓
Server-side business logic

Prisma / PostgreSQL
        ↓
Users, posts, post versions, comments,
likes, bookmarks, reports, moderation,
interests and other migrated business data
```

A compatibility layer currently allows Flutter-era Firestore IDs and PostgreSQL UUIDs to coexist during the backend migration.

---

## Flutter Application Structure

The Flutter application is organized primarily by feature.

```text
lib/
├── app/
├── core/
├── data/
├── features/
│   ├── auth/
│   ├── chat/
│   ├── discover/
│   ├── feed/
│   ├── home/
│   ├── language/
│   ├── notes/
│   ├── post/
│   ├── profile/
│   ├── social/
│   └── translation/
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

## Backend API Areas

The current Node.js API is divided into focused route groups:

```text
account
auth
users
posts
comments
bookmarks
interests
reports
translations
admin
moderation
```

The API uses:

- Express routing
- Firebase-backed authentication middleware
- Zod request validation
- Prisma database access
- PostgreSQL transactions where multiple writes must remain consistent
- Idempotent write patterns for operations such as likes and bookmarks
- Helmet and CORS middleware

### Health Check

```text
GET /health
```

The endpoint performs a real PostgreSQL query (`SELECT 1`) and reports whether the database is connected.

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

## React Native Client

The repository also contains a React Native / Expo client that acts as a second mobile implementation and experiment.

Implemented areas currently include:

- Authentication context
- Auth gate
- Login
- Registration
- Feed
- Post cards
- Post detail
- Create post
- Post repository
- App navigation
- User and post models

The React Native client is not yet at feature parity with Flutter. Its messaging and profile areas currently remain placeholders, while Flutter is the main complete mobile client.

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

### Secondary Mobile Client

- React Native
- Expo
- TypeScript

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
 Multilingual versions
          ↓
      Conversation
          ↓
         Chat
          ↓
     Shared Notes
          ↓
Longer-term knowledge and community
```

Glyphora treats posts, chat, notes, languages, translation, and relationships as connected parts of the same community rather than unrelated features.

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
Translation
  +
Knowledge
  =
Glyphora
```

The project is especially interested in building useful infrastructure for languages and scripts that are often poorly supported in mainstream software.

---

## Status

**Active development.**

The repository currently contains:

- A feature-rich Flutter client
- A React Native secondary client / experiment
- A React administration application
- A Node.js / TypeScript API
- PostgreSQL + Prisma business data
- Firebase authentication, real-time services, and media storage
- Multilingual UI infrastructure
- Script-aware language identity
- Social relationships
- Real-time chat
- Shared notes
- Multilingual post versions
- Manual and AI-assisted translation flows
- Reporting and moderation
- Chữ Nôm-oriented language support

Current work focuses on architecture refinement, completing the Firebase → PostgreSQL migration, production readiness, and improving the overall product experience.
