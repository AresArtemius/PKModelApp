# Push notifications setup

This app stores device tokens in `public.push_device_tokens`, writes notification
events to `public.app_notifications`, and sends real push notifications through
the Supabase Edge Function `send-push-notifications`.

## 1. Apply SQL

Run:

```sql
supabase/sql/push_notifications.sql
```

It adds:

- push queue fields to `app_notifications`;
- notification triggers for chat messages, selection invitations, video intro
  requests, profile moderation, and casting-agent application moderation;
- RLS policies for notification and device-token tables.

## 2. Configure Firebase

Create or open a Firebase project and add iOS/Android apps.

For iOS:

- upload APNs key/certificate in Firebase Console;
- add `GoogleService-Info.plist` to the iOS Runner target;
- enable Push Notifications and Background Modes in Xcode.

For Android:

- add `google-services.json` to `android/app`;
- configure the Gradle Google Services plugin if it is not already configured.

## 3. Deploy Edge Function

Set Supabase secrets from a Firebase service account:

```bash
supabase secrets set FCM_PROJECT_ID="your-firebase-project-id"
supabase secrets set FCM_CLIENT_EMAIL="firebase-adminsdk-...@your-project.iam.gserviceaccount.com"
supabase secrets set FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

Deploy:

```bash
supabase functions deploy send-push-notifications --no-verify-jwt
```

## 4. Trigger delivery

Use one of these options:

- Database Webhook on `public.app_notifications` insert that calls
  `/functions/v1/send-push-notifications` with the inserted record.
- Scheduled Function/Cron every minute that calls
  `/functions/v1/send-push-notifications` without a body, so it processes all
  pending notifications.

The function supports both modes.
