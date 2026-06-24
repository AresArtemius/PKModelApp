# PK Management Web Cabinet

Flutter Web uses the same Supabase project as the mobile app, so auth, profiles,
castings, selections, chats, notifications and admin data stay synchronized
through the existing tables, storage buckets, policies and Edge Functions.

## Build

```bash
SUPABASE_URL=... SUPABASE_ANON_KEY=... bash scripts/web_build.sh
```

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
