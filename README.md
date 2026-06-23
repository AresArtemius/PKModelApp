# PK ModelApp

PK ModelApp is a casting and talent-management platform for models, actors, parents, agents, brands, and casting teams.

The app includes profile portfolios, catalog search, casting invitations, chats, selections, analytics, account roles, admin moderation, phone/email authentication, and a Flutter Web cabinet synchronized through the same Supabase backend.

## Stack

- Flutter / Dart
- Supabase Auth, Database, Storage and Edge Functions
- iOS, Android and Flutter Web

## Local Run

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

## Web Build

```bash
flutter build web \
  --pwa-strategy=none \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

More web cabinet notes are in `WEB_CABINET.md`.


## GitHub Actions and Web Deploy

The repository includes two workflows:

- `Flutter CI` runs `flutter analyze` and `flutter test` on pushes and pull requests to `main`.
- `Flutter Web Deploy` builds Flutter Web and deploys `build/web` to GitHub Pages.

For web deploy, add these repository secrets in GitHub:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Then enable GitHub Pages with **Source: GitHub Actions** in the repository settings. The default project Pages base path is `/PKModelApp/`.

## Secrets

Do not commit service-role keys, SMS provider keys, hook secrets, or local `.env` files. Configure them in Supabase secrets or hosting environment variables.
