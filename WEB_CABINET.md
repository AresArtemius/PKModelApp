# PK Management Web Cabinet

Flutter Web uses the same Supabase project as the mobile app, so auth, profiles,
castings, selections, chats, notifications and admin data stay synchronized
through the existing tables, storage buckets, policies and Edge Functions.

## Build

```bash
SUPABASE_URL=... SUPABASE_ANON_KEY=... bash scripts/web_build.sh
```

The script builds with `--no-web-resources-cdn`: the CanvasKit renderer and
fonts are copied into `build/web/canvaskit/` and served from our domain. After a
build, `grep -c gstatic build/web/flutter_bootstrap.js` must print `0`.

The deployable site is created in:

```text
build/web
```

For a quick local preview:

```bash
python3 -m http.server 8080 -d build/web
```

Then open:

```text
http://localhost:8080
```

The current local preview command is:

```bash
python3 -m http.server 8080 -d build/web
```

Keep this server only for local checking. Production should use static hosting.

## Hosting: Timeweb Cloud server

Production runs on a Timeweb Cloud server (Ubuntu, Novosibirsk, 31.130.133.87)
with Caddy; GitHub Pages is retired. Files: `deploy/Caddyfile` (site config: automatic HTTPS, SPA fallback,
precompressed Brotli/gzip, cache headers) and `deploy/setup-server.sh`
(one-time provisioning).

Repository secrets:

- `TIMEWEB_HOST` — server IP.
- `TIMEWEB_SSH_KEY` — private SSH key; its public half must be in root's
  `authorized_keys` on the server (add it when creating the server).

Workflows:

1. **Server Setup (Timeweb Cloud)** — run manually once: installs Caddy,
   creates the `deploy` user, `/var/www/app/{releases,current}`, firewall.
2. **Flutter Web Deploy** — on every push to `main` the `deploy-timeweb` job
   precompresses `build/web`, uploads it to `/var/www/app/releases/<sha>` and
   switches the `current` symlink (last 3 releases kept). The job is skipped
   when the secrets are not set.

Then point the DNS A record for `app.pk.management` to the server IP; Caddy
obtains the certificate automatically (if DNS changed after Caddy started,
`systemctl restart caddy` forces an immediate retry).

## Updates in open tabs

There is no service worker (`--pwa-strategy=none`; Flutter's SW loading is
deprecated). Instead the build writes `release.json` (`{"sha","builtAt"}`)
next to `index.html` and bakes the same sha into the bundle via
`--dart-define=APP_RELEASE_SHA`. `ReleaseUpdateBanner` (`lib/core/release_update.dart`)
re-fetches `release.json` every 10 minutes and when the tab becomes visible;
when the sha differs it shows «Доступна новая версия — Обновить», which
reloads the page. Local builds have no `APP_RELEASE_SHA`, so the check is off.

## URLs

The web build uses path URLs (`usePathUrlStrategy()` in `lib/main.dart`):
`/search`, `/model/<id>`, `/p/<id>`. Caddy serves `index.html` for every
path. Old links of the form `/#/castings` are rewritten to `/castings` by a
small script in `web/index.html` before the app starts. `PUBLIC_BASE_URL`
(used for PDF and share links) is `https://app.pk.management` — no `#`.

## Supabase Auth URLs

In Supabase Dashboard, open Authentication -> URL Configuration.

Set the production web cabinet URL as Site URL when the domain is ready, for
example:

```text
https://app.pkmanagement.ru
```

Add redirect URLs for web and keep the mobile deeplink:

```text
https://app.pkmanagement.ru
https://app.pkmanagement.ru/**
http://localhost:8080
http://localhost:*
modelapp://login-callback
```

For the first web cabinet, use:

```text
Site URL: http://localhost:8080
```

When the production domain is connected, change Site URL to:

```text
https://app.pkmanagement.ru
```

The Flutter code keeps `modelapp://login-callback` for iOS/Android and uses the
current web origin on Flutter Web. That lets email confirmation and email-linking
flows return to the web cabinet without breaking the mobile app.

## First Web Scope

- Internal cabinet first, not a public marketing site.
- Reuse the existing Flutter UI and Supabase backend.
- Deploy the compiled `build/web` to static hosting.
- Later, build a separate public SEO website if needed.

## Hosting Choice

Use static hosting first. The simplest path is Vercel with `build/web` as the
published folder. Netlify is also supported.

Recommended first production URL:

```text
https://app.pkmanagement.ru
```

Recommended public marketing site later:

```text
https://pkmanagement.ru
```

The web cabinet already includes SPA redirect configuration:

- `vercel.json` for Vercel.
- `netlify.toml` for Netlify.

After any change to files in `web/` or Flutter code, rebuild locally:

```bash
SUPABASE_URL=... SUPABASE_ANON_KEY=... bash scripts/web_build.sh
```

Then deploy the updated `build/web` folder. On Vercel or Netlify, add `SUPABASE_URL` and `SUPABASE_ANON_KEY` in project environment variables; the included config runs the same script automatically.
