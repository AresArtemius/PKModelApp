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
- `Flutter Web Deploy` builds Flutter Web for GitHub Pages when Pages is available for the repository.

For a private repository, use Vercel or Netlify first. Both configs are included and use the same build script:

```bash
bash scripts/web_build.sh
```

Add these environment variables in the hosting provider settings:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The web output directory is `build/web`.

## Secrets

Do not commit service-role keys, SMS provider keys, hook secrets, or local `.env` files. Configure them in Supabase secrets or hosting environment variables.
