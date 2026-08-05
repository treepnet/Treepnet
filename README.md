# TreepNet

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]
[![License: MIT][license_badge]][license_link]

**TreepNet** is a travel-first social network built with Flutter — share the
places you've been on a personal world map, post photos and stories tied to real
locations, and follow other travellers. It is **offline-first**: every core
feature keeps working with no connection and syncs the moment you're back online.

## 💫 About

TreepNet turns your travels into a living map. Every post and pinned story lights
up the region it was taken in, so your profile becomes a visual diary of where
you've been rather than just a grid of photos.

- 🗺️ **Travel map** — a pan/zoom world map where visited regions are shaded and
  each place you post from drops a pin. Tap a pin to open everything you shared
  there; open a region's full feed from *"See the whole region"*.
- 📸 **Feed & posts** — location-tagged photo posts in an Instagram-style feed.
- ⏱️ **Stories** — 24h stories with an archive, highlights, and the ability to
  pin a story to a place so it lives on the map after it expires.
- 💬 **Chat** — direct messaging with replies and shared posts.
- 🔒 **Public & private accounts** — private profiles reveal their posts, stories
  and travel map only to accepted followers.
- 🎁 **Invites & referrals** — invite friends and earn perks.
- 🔔 **Notifications**, saved posts, blocked users, account deletion, and more.

## ⚡️ Built with

- [Flutter](https://flutter.dev/) — cross-platform UI (Android & iOS)
- [Azure Database for PostgreSQL](https://azure.microsoft.com/products/postgresql) — primary datastore
- [PowerSync](https://www.powersync.com/) — offline-first sync engine (local SQLite ⇄ Postgres)
- [Microsoft Entra External ID](https://learn.microsoft.com/entra/external-id/) — native authentication (email + password, code-based sign-up, password reset)
- [Azure Blob Storage](https://azure.microsoft.com/products/storage/blobs) — media (images & videos)

## 🏗️ Architecture

TreepNet is a monorepo. The Flutter app in `lib/` is kept thin; the real work
lives in feature packages under `packages/`:

| Package | Responsibility |
| --- | --- |
| `app_ui` | Shared design system (widgets, colours, spacing) |
| `authentication_client` | Auth abstraction + Entra native-auth implementation |
| `database_client` | PowerSync-backed data layer (SQL + reactive `watch`) |
| `powersync_repository` | PowerSync + PostgREST connection |
| `storage` | Azure Blob upload/download |
| `user_repository`, `posts_repository`, `stories_repository`, `chats_repository`, `search_repository` | Domain repositories |
| `shared`, `env`, `form_fields` | Cross-cutting models, config, validation |

The app is **offline-first**: reads and writes hit a local SQLite database that
PowerSync mirrors to Azure Postgres, so the UI never blocks on the network.

## 🚀 Getting started

**Requirements**

- Flutter `3.35.7` (managed with [FVM](https://fvm.app/) — see `.fvmrc`)
- Dart `>= 3.9.0`

**Setup**

```bash
# 1. Install the pinned Flutter version
fvm install

# 2. Fetch dependencies
flutter pub get

# 3. Provide environment config
#    Create packages/env/.env.dev and .env.prod from .env.example
#    (POWERSYNC_URL, Entra client ids, etc.)
```

**Run**

The app ships with three flavors, each with its own entrypoint:

```bash
# Development
flutter run --flavor development -t lib/main_development.dart

# Staging
flutter run --flavor staging -t lib/main_staging.dart

# Production
flutter run --flavor production -t lib/main_production.dart
```

The Android application id is `com.treepnet.application`
(`com.treepnet.application.dev` for the development flavor).

**Backend SQL**

Database functions and policies live in `packages/database_client/*.sql` and
`sql/`. They target Azure Postgres and are applied directly (e.g. with `psql`),
not through Supabase migrations.

## ⭐️ Contributing

This is a private product repository. If you have access and want to propose a
change:

1. Create a feature branch (`git checkout -b feature/your-change`)
2. Commit your changes
3. Open a pull request against `main`

## 📝 License

Distributed under the MIT License. See [MIT License][license_link] for details.

## 💭 Contact

Project: [TreepNet-social-media](https://github.com/Hikmatbek-dev/TreepNet-social-media)

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
