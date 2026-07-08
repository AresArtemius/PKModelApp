# Push notifications setup

This app stores device tokens in `public.push_device_tokens`, writes notification
events to `public.app_notifications`, and sends production push/email delivery
through the Supabase Edge Function `send-notifications`.

## 1. Apply SQL

Run:

```sql
supabase/sql/push_notifications.sql
```

It adds:

- push queue fields to `app_notifications`;
- optional email queue fields to `app_notifications`;
- server delivery status sync from `app_notifications` to `profile_action_logs`;
- notification triggers for chat messages, selection invitations, video intro
  requests, profile moderation, and casting-agent application moderation;
- RLS policies for notification and device-token tables.

## 2. Configure Firebase

Create or open a Firebase project and add iOS/Android/Web apps.

For iOS:

- upload APNs key/certificate in Firebase Console;
- add `GoogleService-Info.plist` to the iOS Runner target;
- enable Push Notifications and Background Modes in Xcode.

For Android:

- add `google-services.json` to `android/app`;
- configure the Gradle Google Services plugin if it is not already configured.

For Web/GitHub Pages:

- add a Web app in Firebase Console;
- create a Web Push certificate and copy the public VAPID key;
- add these GitHub Actions secrets:
  - `FIREBASE_WEB_API_KEY`
  - `FIREBASE_WEB_AUTH_DOMAIN`
  - `FIREBASE_WEB_PROJECT_ID`
  - `FIREBASE_WEB_STORAGE_BUCKET`
  - `FIREBASE_WEB_MESSAGING_SENDER_ID`
  - `FIREBASE_WEB_APP_ID`
  - `FIREBASE_WEB_MEASUREMENT_ID` (optional)
  - `FIREBASE_WEB_VAPID_KEY`

The Pages workflow writes `web/firebase-web-config.js` during build, so Firebase
Web keys do not need to be hardcoded in the repository.

## 3. Configure server delivery secrets

Set Supabase secrets from a Firebase service account:

```bash
supabase secrets set FCM_PROJECT_ID="your-firebase-project-id"
supabase secrets set FCM_CLIENT_EMAIL="firebase-adminsdk-...@your-project.iam.gserviceaccount.com"
supabase secrets set FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

For email delivery the production worker uses Resend:

```bash
supabase secrets set RESEND_API_KEY="re_..."
supabase secrets set EMAIL_FROM="PK Management <noreply@pk.management>"
supabase secrets set PUBLIC_APP_URL="https://app.pk.management/"
```

Email is not sent for every notification by default. It is queued only when
`enqueue_app_notification(..., p_data)` contains `"send_email": true`. The worker
uses `email_to` from `p_data` first, then falls back to `user_profiles.email`.

## 4. Deploy Edge Function

Deploy:

```bash
supabase functions deploy send-notifications --no-verify-jwt
```

The older `send-push-notifications` function can remain deployed for backward
compatibility, but `send-notifications` is the production worker for both push
and email status updates.

## 5. Trigger delivery

Production uses both immediate and fallback delivery:

- Store the service-role key in Supabase Vault as
  `send_notifications_service_role_key`. This key is used only by database
  webhook/cron calls to authenticate against the Edge Function.

  ```sql
  select vault.create_secret(
    '<SERVICE_ROLE_KEY>',
    'send_notifications_service_role_key',
    'Authorization token for the send-notifications worker cron/webhook'
  );
  ```

- Run `supabase/sql/send_notifications_production_delivery.sql`.
- The SQL installs a pg_net webhook trigger on `public.app_notifications`
  insert. It calls `/functions/v1/send-notifications` with the inserted record.
- The same SQL installs a pg_cron fallback every minute. It calls
  `/functions/v1/send-notifications` without a body, so the worker processes
  any pending queue items that were missed or left in `failed/pending`.

The function supports both modes.
